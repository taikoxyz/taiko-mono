//! Payload building utilities for preconfirmation integration tests.
//!
//! This module provides helpers for constructing P2P gossip payloads:
//! - [`PreparedBlock`]: A txlist + signed commitment pair ready for publishing.
//! - [`build_publish_payloads`]: Assembles a complete preconfirmation payload.
//! - [`build_publish_payloads_with_txs`]: Assembles a payload with actual transactions.
//! - [`build_commitment_chain`]: Builds linked commitments for catch-up tests.

use std::io::Write as IoWrite;

use alloy_primitives::{Address, Bytes, U256};
use alloy_rlp::encode as rlp_encode;
use anyhow::{Context, Result, anyhow, ensure};
use flate2::{Compression, write::ZlibEncoder};
use preconfirmation_client::codec::ZlibTxListCodec;
use preconfirmation_types::{
    Bytes20, Bytes32, MAX_TXLIST_BYTES, PreconfCommitment, Preconfirmation, RawTxListGossip,
    SignedCommitment, TxListBytes, address_to_bytes20, keccak256_bytes, sign_commitment,
    u256_to_uint256,
};
use secp256k1::SecretKey;

// ============================================================================
// Prepared Block
// ============================================================================

/// A prepared block containing a txlist and signed commitment for publishing.
///
/// This struct bundles everything needed to publish a preconfirmation
/// over P2P gossip.
#[derive(Clone, Debug)]
pub struct PreparedBlock {
    /// The compressed transaction list gossip message.
    pub txlist: RawTxListGossip,
    /// The signed commitment for this block.
    pub commitment: SignedCommitment,
}

// ============================================================================
// TxList Compression Utilities
// ============================================================================

/// Compresses raw bytes to TxListBytes using zlib.
fn compress_to_txlist_bytes(data: &[u8]) -> Result<TxListBytes> {
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(data)?;
    let compressed = encoder.finish()?;
    TxListBytes::try_from(compressed).map_err(|(_, err)| anyhow!("txlist bytes error: {err}"))
}

/// Builds a compressed txlist payload with deterministic contents based on block number.
///
/// Used for tests that need non-empty but deterministic transaction data.
pub fn build_txlist_bytes(block_number: u64) -> Result<TxListBytes> {
    let tx_payload = block_number.to_be_bytes().to_vec();
    let rlp_payload = rlp_encode(vec![tx_payload]);
    compress_to_txlist_bytes(&rlp_payload)
}

/// Builds a minimal compressed txlist (empty RLP list).
///
/// Used for tests that just need a valid but empty txlist.
pub fn build_empty_txlist() -> Result<TxListBytes> {
    compress_to_txlist_bytes(&[0xC0])
}

/// Computes the raw tx list hash from txlist bytes.
pub fn compute_txlist_hash(txlist_bytes: &TxListBytes) -> Result<Bytes32> {
    Bytes32::try_from(keccak256_bytes(txlist_bytes.as_ref()).as_slice().to_vec())
        .map_err(|(_, err)| anyhow!("txlist hash error: {err}"))
}

// ============================================================================
// Payload Builders
// ============================================================================

/// Assembles a compressed txlist and signed commitment for P2P gossip.
///
/// This is the simpler version that creates a deterministic txlist based on
/// the block number. Use [`build_publish_payloads_with_txs`] when you need
/// to include actual transaction bytes.
///
/// # Arguments
///
/// * `signer_sk` - Secret key to sign the commitment.
/// * `signer` - Address of the preconf signer (derived from signer_sk).
/// * `block_number` - Target block number for this preconfirmation.
/// * `timestamp` - Block timestamp.
/// * `gas_limit` - Block gas limit.
/// * `submission_window_end` - End of the submission window.
/// * `eop` - If true, includes deterministic payload; if false, uses empty txlist.
///
/// # Example
///
/// ```ignore
/// let (sk, addr) = derive_signer(1);
/// let block = build_publish_payloads(
///     &sk, addr, 100, 1000, 30_000_000, U256::from(1000), false
/// )?;
/// ext_handle.publish_raw_txlist(block.txlist).await?;
/// ext_handle.publish_commitment(block.commitment).await?;
/// ```
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
    build_prepared_block(
        signer_sk,
        signer,
        block_number,
        timestamp,
        gas_limit,
        submission_window_end,
        eop,
        txlist_bytes,
        None,
    )
}

/// Assembles a compressed txlist and signed commitment with actual transaction bytes.
///
/// This version takes raw transaction bytes (e.g., anchor tx + transfer txs)
/// and compresses them into the txlist. Use this for E2E tests that need
/// real transactions to be executed.
///
/// # Arguments
///
/// * `signer_sk` - Secret key to sign the commitment.
/// * `signer` - Address of the preconf signer.
/// * `submission_window_end` - End of the submission window.
/// * `block_number` - Target block number (as U256 for flexibility).
/// * `timestamp` - Block timestamp.
/// * `gas_limit` - Block gas limit.
/// * `raw_tx_bytes` - Vector of raw transaction bytes to include.
///
/// # Example
///
/// ```ignore
/// let anchor_tx = build_anchor_tx_bytes(...).await?;
/// let transfer = build_signed_transfer(...).await?;
/// let txs = vec![anchor_tx, transfer.raw_bytes];
///
/// let (txlist, commitment) = build_publish_payloads_with_txs(
///     &sk, signer, submission_window_end, U256::from(100), 1000, 30_000_000, txs
/// )?;
/// ```
pub fn build_publish_payloads_with_txs(
    signer_sk: &SecretKey,
    signer: Address,
    submission_window_end: U256,
    block_number: U256,
    timestamp: u64,
    gas_limit: u64,
    raw_tx_bytes: Vec<Bytes>,
) -> Result<(RawTxListGossip, SignedCommitment)> {
    let txlist_bytes = compress_transactions(&raw_tx_bytes)?;
    let block = build_prepared_block(
        signer_sk,
        signer,
        block_number.to::<u64>(),
        timestamp,
        gas_limit,
        submission_window_end,
        false,
        txlist_bytes,
        None,
    )?;
    Ok((block.txlist, block.commitment))
}

/// Compresses raw transaction bytes into a TxListBytes.
///
/// Encodes transactions as an RLP list and compresses with zlib.
/// Verifies round-trip decoding to catch encoding issues early.
fn compress_transactions(raw_tx_bytes: &[Bytes]) -> Result<TxListBytes> {
    let tx_list_items: Vec<Vec<u8>> = raw_tx_bytes.iter().map(|tx| tx.to_vec()).collect();
    let tx_list = rlp_encode(&tx_list_items);

    let first_byte = *tx_list.first().ok_or_else(|| anyhow!("empty tx list encoding"))?;
    ensure!(first_byte >= 0xc0, "tx list is not an RLP list (first byte 0x{first_byte:02x})");

    let txlist_bytes = compress_to_txlist_bytes(&tx_list)?;

    // Verify round-trip decoding to catch encoding issues early.
    let codec = ZlibTxListCodec::new(MAX_TXLIST_BYTES);
    let decoded = codec.decode(txlist_bytes.as_ref()).context("decode txlist before publishing")?;
    ensure!(decoded.len() == raw_tx_bytes.len(), "decoded txlist length mismatch");

    Ok(txlist_bytes)
}

/// Internal helper to build a PreparedBlock with optional parent hash.
#[allow(clippy::too_many_arguments)]
fn build_prepared_block(
    signer_sk: &SecretKey,
    signer: Address,
    block_number: u64,
    timestamp: u64,
    gas_limit: u64,
    submission_window_end: U256,
    eop: bool,
    txlist_bytes: TxListBytes,
    parent_hash: Option<Bytes32>,
) -> Result<PreparedBlock> {
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
        parent_preconfirmation_hash: parent_hash
            .unwrap_or_else(|| Bytes32::try_from(vec![0u8; 32]).expect("zero hash")),
        ..Default::default()
    };

    let commitment = PreconfCommitment { preconf, slasher_address: Bytes20::default() };
    let signature = sign_commitment(&commitment, signer_sk)?;

    Ok(PreparedBlock { txlist, commitment: SignedCommitment { commitment, signature } })
}

// ============================================================================
// Commitment Chain Builder
// ============================================================================

/// Builds a contiguous commitment chain with parent hash linkage.
///
/// Each commitment's `parent_preconfirmation_hash` references the previous
/// commitment, forming a linked chain suitable for catch-up/backfill testing.
///
/// # Arguments
///
/// * `signer_sk` - Secret key to sign all commitments.
/// * `signer` - Address of the preconf signer.
/// * `submission_window_end` - End of the submission window for all commitments.
/// * `start_block` - First block number in the chain.
/// * `count` - Number of blocks to generate.
/// * `base_timestamp` - Base timestamp for the first block (typically parent timestamp + 1).
///
/// # Returns
///
/// A vector of `PreparedBlock`s, where each block's parent hash points
/// to the previous block's commitment hash.
///
/// # Example
///
/// ```ignore
/// let chain = build_commitment_chain(&sk, addr, window_end, 100, 5, 1000)?;
/// // chain[0] has parent_hash = 0x00..., timestamp = 1000
/// // chain[1] has parent_hash = hash(chain[0].commitment), timestamp = 1001
/// // etc.
/// ```
pub fn build_commitment_chain(
    signer_sk: &SecretKey,
    signer: Address,
    submission_window_end: U256,
    start_block: u64,
    count: usize,
    base_timestamp: u64,
) -> Result<Vec<PreparedBlock>> {
    use preconfirmation_types::preconfirmation_hash;

    let mut parent_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero parent hash");
    let mut chain = Vec::with_capacity(count);
    let gas_limit = 30_000_000u64;

    for i in 0..count {
        let block_number = start_block + i as u64;
        let timestamp = base_timestamp + i as u64;
        let txlist_bytes = build_txlist_bytes(block_number)?;

        let block = build_prepared_block(
            signer_sk,
            signer,
            block_number,
            timestamp,
            gas_limit,
            submission_window_end,
            false,
            txlist_bytes,
            Some(parent_hash),
        )?;

        let hash = preconfirmation_hash(&block.commitment.commitment.preconf)
            .map_err(|err| anyhow!("preconfirmation hash error: {err}"))?;
        parent_hash = Bytes32::try_from(hash.as_slice().to_vec()).expect("parent hash bytes32");

        chain.push(block);
    }

    Ok(chain)
}

// ============================================================================
// Signer Utilities
// ============================================================================

/// Derives a secret key and address from a deterministic seed byte.
///
/// The seed is repeated 32 times to form the private key bytes.
/// Each unique seed produces a distinct, reproducible keypair for testing.
///
/// # Example
///
/// ```ignore
/// let (sk, addr) = derive_signer(1);
/// // sk = SecretKey from [1, 1, 1, ..., 1]
/// // addr = corresponding Ethereum address
/// ```
pub fn derive_signer(seed: u8) -> (SecretKey, Address) {
    let sk = SecretKey::from_slice(&[seed; 32]).expect("valid secret key");
    let pk = secp256k1::PublicKey::from_secret_key(&secp256k1::Secp256k1::new(), &sk);
    let addr = preconfirmation_types::public_key_to_address(&pk);
    (sk, addr)
}

/// Computes the starting block number based on driver tips.
///
/// Returns the maximum of event_sync_tip and preconf_tip plus one,
/// which is the next block that should be preconfirmed.
pub async fn compute_starting_block<D: preconfirmation_client::DriverClient>(
    driver: &D,
) -> Result<u64> {
    let event_sync_tip = driver.event_sync_tip().await?;
    let preconf_tip = driver.preconf_tip().await?;
    let starting_block = event_sync_tip.max(preconf_tip) + U256::ONE;
    Ok(starting_block.to::<u64>())
}
