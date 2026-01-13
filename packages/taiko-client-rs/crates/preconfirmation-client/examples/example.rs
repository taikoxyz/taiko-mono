//! Example preconfirmation client with mandatory lookahead resolver.
//!
//! This example demonstrates how to:
//! 1. Build a provider for the lookahead resolver
//! 2. Create a `PreconfirmationClientConfig` with the resolver
//! 3. Run the preconfirmation client
//! 4. Publish a txlist and commitment
//!
//! The lookahead resolver is mandatory and used to validate that commitment signers
//! match the expected slot signer and that submission_window_end values are correct.

use std::io::Write;

use alloy_primitives::{Address, U256};
use async_trait::async_trait;
use flate2::{Compression, write::ZlibEncoder};
use preconfirmation_client::{
    DriverClient, PreconfirmationClient, PreconfirmationClientConfig, PreconfirmationClientError,
    PreconfirmationInput, Result,
};
use preconfirmation_net::{NetworkCommand, P2pConfig};
use preconfirmation_types::{
    Bytes20, Bytes32, PreconfCommitment, Preconfirmation, RawTxListGossip, SignedCommitment,
    TxListBytes, keccak256_bytes, sign_commitment,
};
use protocol::subscription_source::SubscriptionSource;
use secp256k1::SecretKey;

/// Driver adapter used to forward inputs into the driver queue.
struct DriverAdapter;

#[async_trait]
impl DriverClient for DriverAdapter {
    /// Submit a preconfirmation input for ordered processing.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        // Forward the input to the driver for ordered processing.
        let _commitment = input.commitment;
        Ok(())
    }

    /// Await the driver event sync completion signal.
    async fn wait_event_sync(&self) -> Result<()> {
        // Block until the driver reports event sync completion.
        Ok(())
    }

    /// Return the latest event sync tip block number.
    async fn event_sync_tip(&self) -> Result<U256> {
        Ok(U256::ZERO)
    }

    /// Return the latest preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256> {
        Ok(U256::ZERO)
    }
}

/// Build example publish payloads: a compressed raw txlist gossip and a signed commitment.
fn build_publish_payloads() -> (RawTxListGossip, SignedCommitment) {
    // Build a minimal txlist payload (RLP empty list) and compress it.
    let rlp_payload = vec![0xC0];
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&rlp_payload).expect("zlib encode failed");
    let compressed = encoder.finish().expect("zlib encode failed");
    let txlist_bytes = TxListBytes::try_from(compressed).expect("txlist bytes error");
    let txlist_hash = keccak256_bytes(txlist_bytes.as_ref());
    let raw_tx_list_hash =
        Bytes32::try_from(txlist_hash.as_slice().to_vec()).expect("txlist hash error");
    let txlist =
        RawTxListGossip { raw_tx_list_hash: raw_tx_list_hash.clone(), txlist: txlist_bytes };

    // Build a signed commitment that references the txlist hash.
    let preconf = Preconfirmation {
        eop: false,
        raw_tx_list_hash: raw_tx_list_hash.clone(),
        ..Default::default()
    };
    let commitment = PreconfCommitment { preconf, slasher_address: Bytes20::default() };
    let sk = SecretKey::from_slice(&[1u8; 32]).expect("invalid secret key");
    let signature = sign_commitment(&commitment, &sk).expect("sign commitment failed");
    let signed_commitment = SignedCommitment { commitment, signature };

    (txlist, signed_commitment)
}

#[tokio::main]
async fn main() -> Result<()> {
    // Configure the RPC endpoint for the lookahead resolver.
    // In production, use your L1 execution client WebSocket endpoint.
    let rpc_url = std::env::var("L1_RPC_URL").unwrap_or_else(|_| "ws://localhost:8546".to_string());

    // Configure the inbox contract address for the lookahead resolver.
    let inbox_address: Address = std::env::var("INBOX_ADDRESS")
        .unwrap_or_else(|_| "0x0000000000000000000000000000000000000000".to_string())
        .parse()
        .expect("invalid inbox address");

    // Build the subscription source for event scanning.
    let source =
        SubscriptionSource::try_from(rpc_url.as_str()).expect("invalid subscription source");

    // Build the provider for lookahead resolution.
    let provider = source.to_provider().await.expect("provider error");

    // Build the client configuration with the mandatory lookahead resolver.
    let config =
        PreconfirmationClientConfig::new(P2pConfig::default(), inbox_address, provider).await?;
    // Construct the client with a driver adapter.
    let client = PreconfirmationClient::new(config, DriverAdapter)?;

    // Build example publish payloads.
    let (txlist, signed_commitment) = build_publish_payloads();
    let sender = client.command_sender();

    // Wait for driver event sync to complete and catch up to the latest preconfirmation tip.
    let event_loop = client.sync_and_catchup().await?;

    // Spawn the blocking event loop in a separate task.
    let _ = tokio::spawn(async move {
        if let Err(err) = event_loop.run_with_retry().await {
            eprintln!("event loop exited with error: {err}");
        }
    });

    // Publish a txlist and commitment.
    sender
        .send(NetworkCommand::PublishRawTxList(txlist))
        .await
        .map_err(|err| PreconfirmationClientError::Network(err.to_string()))?;
    sender
        .send(NetworkCommand::PublishCommitment(signed_commitment))
        .await
        .map_err(|err| PreconfirmationClientError::Network(err.to_string()))?;

    Ok(())
}
