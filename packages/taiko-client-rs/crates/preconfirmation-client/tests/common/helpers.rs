#![allow(dead_code)]
//! Test-only helpers shared across preconfirmation-client integration tests.

use std::{
    io::Write as IoWrite,
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::Arc,
};

use alloy_primitives::{Address, U256};
use alloy_rlp::encode;
use anyhow::{Result, anyhow};
use flate2::{Compression, write::ZlibEncoder};
use preconfirmation_client::{driver_interface::DriverClient, subscription::PreconfirmationEvent};
use preconfirmation_net::{
    InMemoryStorage, LocalValidationAdapter, P2pConfig, P2pHandle, P2pNode, PreconfStorage,
    ValidationAdapter,
};
use preconfirmation_types::{
    Bytes20, Bytes32, PreconfCommitment, Preconfirmation, RawTxListGossip, SignedCommitment,
    TxListBytes, address_to_bytes20, keccak256_bytes, sign_commitment, u256_to_uint256,
};
use secp256k1::{PublicKey, Secp256k1, SecretKey};
use tokio::{sync::broadcast, task::JoinHandle};

// ============================================================================
// P2P Configuration
// ============================================================================

/// Creates a local-only P2P config for tests (ephemeral ports, discovery disabled).
pub fn test_p2p_config() -> P2pConfig {
    let localhost_ephemeral = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    let chain_id =
        std::env::var("L2_CHAIN_ID").ok().and_then(|v| v.parse().ok()).unwrap_or(167_001);

    P2pConfig {
        chain_id,
        listen_addr: localhost_ephemeral,
        discovery_listen: localhost_ephemeral,
        enable_discovery: false,
        ..P2pConfig::default()
    }
}

/// External P2P node with its handle, storage, and background task.
pub struct ExternalP2pNode {
    pub handle: P2pHandle,
    pub storage: Arc<dyn PreconfStorage>,
    pub task: JoinHandle<anyhow::Result<()>>,
}

impl ExternalP2pNode {
    /// Creates and spawns an external P2P node for testing with in-memory storage.
    pub fn spawn() -> Result<Self> {
        let validator: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
        let storage: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());
        let (handle, node) =
            P2pNode::new_with_validator_and_storage(test_p2p_config(), validator, storage.clone())?;
        let task = tokio::spawn(async move { node.run().await });
        Ok(Self { handle, storage, task })
    }

    /// Aborts the background task.
    pub fn abort(&self) {
        self.task.abort();
    }
}

// ============================================================================
// Signer Utilities
// ============================================================================

/// Derives an address from a deterministic secret key seed.
pub fn derive_signer(seed: u8) -> (SecretKey, Address) {
    let sk = SecretKey::from_slice(&[seed; 32]).expect("valid secret key");
    let pk = PublicKey::from_secret_key(&Secp256k1::new(), &sk);
    let addr = preconfirmation_types::public_key_to_address(&pk);
    (sk, addr)
}

// ============================================================================
// Payload Builders
// ============================================================================

/// Represents a prepared block for publishing (txlist + commitment).
pub struct PreparedBlock {
    pub txlist: RawTxListGossip,
    pub commitment: SignedCommitment,
}

/// Build a compressed txlist payload with deterministic contents based on block number.
pub fn build_txlist_bytes(block_number: u64) -> Result<TxListBytes> {
    let tx_payload = block_number.to_be_bytes().to_vec();
    let rlp_payload = encode(&vec![tx_payload]);
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(rlp_payload.as_ref())?;
    let compressed = encoder.finish()?;
    TxListBytes::try_from(compressed).map_err(|(_, err)| anyhow!("txlist bytes error: {err}"))
}

/// Build a minimal compressed txlist (empty RLP list).
pub fn build_empty_txlist() -> Result<TxListBytes> {
    let rlp_payload = vec![0xC0];
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&rlp_payload)?;
    let compressed = encoder.finish()?;
    TxListBytes::try_from(compressed).map_err(|(_, err)| anyhow!("txlist bytes error: {err}"))
}

/// Compute the raw tx list hash from txlist bytes.
pub fn compute_txlist_hash(txlist_bytes: &TxListBytes) -> Result<Bytes32> {
    Bytes32::try_from(keccak256_bytes(txlist_bytes.as_ref()).as_slice().to_vec())
        .map_err(|(_, err)| anyhow!("txlist hash error: {err}"))
}

/// Assembles a compressed txlist and signed commitment for P2P gossip.
///
/// Use `eop = true` for end-of-period commitments, `eop = false` otherwise.
pub fn build_publish_payloads(
    signer_sk: &SecretKey,
    signer: Address,
    block_number: u64,
    timestamp: u64,
    gas_limit: u64,
    submission_window_end: U256,
    eop: bool,
) -> Result<PreparedBlock> {
    let txlist_bytes = if eop { build_txlist_bytes(block_number)? } else { build_empty_txlist()? };

    let raw_tx_list_hash = compute_txlist_hash(&txlist_bytes)?;
    let txlist =
        RawTxListGossip { raw_tx_list_hash: raw_tx_list_hash.clone(), txlist: txlist_bytes };

    let preconf = Preconfirmation {
        eop,
        block_number: u256_to_uint256(U256::from(block_number)),
        timestamp: u256_to_uint256(U256::from(timestamp)),
        gas_limit: u256_to_uint256(U256::from(gas_limit)),
        proposal_id: u256_to_uint256(U256::from(block_number)),
        coinbase: address_to_bytes20(signer),
        submission_window_end: u256_to_uint256(submission_window_end),
        raw_tx_list_hash,
        ..Default::default()
    };

    let commitment = PreconfCommitment { preconf, slasher_address: Bytes20::default() };
    let signature = sign_commitment(&commitment, signer_sk)?;

    Ok(PreparedBlock { txlist, commitment: SignedCommitment { commitment, signature } })
}

// ============================================================================
// Event Waiters
// ============================================================================

/// Wait for a peer connection event.
pub async fn wait_for_peer_connected(events: &mut broadcast::Receiver<PreconfirmationEvent>) {
    loop {
        match events.recv().await {
            Ok(PreconfirmationEvent::PeerConnected(_)) => return,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

/// Wait for a single commitment and its txlist to be received.
pub async fn wait_for_commitment_and_txlist(
    events: &mut broadcast::Receiver<PreconfirmationEvent>,
) {
    let mut saw_commitment = false;
    let mut saw_txlist = false;
    while !(saw_commitment && saw_txlist) {
        match events.recv().await {
            Ok(PreconfirmationEvent::NewCommitment(_)) => saw_commitment = true,
            Ok(PreconfirmationEvent::NewTxList(_)) => saw_txlist = true,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

/// Wait for multiple commitments and their txlists to be received.
pub async fn wait_for_commitments_and_txlists(
    events: &mut broadcast::Receiver<PreconfirmationEvent>,
    commitment_count: usize,
    txlist_count: usize,
) {
    let mut commitments_received = 0;
    let mut txlists_received = 0;

    while commitments_received < commitment_count || txlists_received < txlist_count {
        match events.recv().await {
            Ok(PreconfirmationEvent::NewCommitment(_)) => commitments_received += 1,
            Ok(PreconfirmationEvent::NewTxList(_)) => txlists_received += 1,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

/// Wait for the synced event.
pub async fn wait_for_synced(events: &mut broadcast::Receiver<PreconfirmationEvent>) {
    loop {
        match events.recv().await {
            Ok(PreconfirmationEvent::Synced) => return,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

// ============================================================================
// Test Setup Utilities
// ============================================================================

/// Computes the starting block number based on driver tips.
pub async fn compute_starting_block<D: DriverClient>(driver: &D) -> Result<u64> {
    let event_sync_tip = driver.event_sync_tip().await?;
    let preconf_tip = driver.preconf_tip().await?;
    let starting_block = event_sync_tip.max(preconf_tip) + U256::ONE;
    Ok(starting_block.to::<u64>())
}

// ============================================================================
// Commitment Chain Builder (for catch-up tests)
// ============================================================================

/// Build a contiguous commitment chain with parent hash linkage.
///
/// Each commitment's `parent_preconfirmation_hash` references the previous commitment,
/// forming a linked chain suitable for catch-up/backfill testing.
pub fn build_commitment_chain(
    signer_sk: &SecretKey,
    signer: Address,
    submission_window_end: U256,
    start_block: u64,
    count: usize,
) -> Result<Vec<PreparedBlock>> {
    use preconfirmation_types::preconfirmation_hash;

    let mut parent_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero parent hash");
    let mut chain = Vec::with_capacity(count);
    let gas_limit = 30_000_000u64;

    for i in 0..count {
        let block_number = start_block + i as u64;
        let txlist_bytes = build_txlist_bytes(block_number)?;
        let raw_tx_list_hash = compute_txlist_hash(&txlist_bytes)?;
        let txlist =
            RawTxListGossip { raw_tx_list_hash: raw_tx_list_hash.clone(), txlist: txlist_bytes };

        let preconf = Preconfirmation {
            eop: false,
            block_number: u256_to_uint256(U256::from(block_number)),
            timestamp: u256_to_uint256(U256::from(100 + i as u64)),
            gas_limit: u256_to_uint256(U256::from(gas_limit)),
            proposal_id: u256_to_uint256(U256::from(block_number)),
            coinbase: address_to_bytes20(signer),
            submission_window_end: u256_to_uint256(submission_window_end),
            raw_tx_list_hash,
            parent_preconfirmation_hash: parent_hash.clone(),
            ..Default::default()
        };

        let commitment = PreconfCommitment { preconf, slasher_address: Bytes20::default() };
        let signature = sign_commitment(&commitment, signer_sk)?;
        let signed = SignedCommitment { commitment, signature };

        let hash = preconfirmation_hash(&signed.commitment.preconf)
            .map_err(|err| anyhow!("preconfirmation hash error: {err}"))?;
        parent_hash = Bytes32::try_from(hash.as_slice().to_vec()).expect("parent hash bytes32");

        chain.push(PreparedBlock { txlist, commitment: signed });
    }

    Ok(chain)
}
