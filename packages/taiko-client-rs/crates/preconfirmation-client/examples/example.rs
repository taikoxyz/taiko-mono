//! Example preconfirmation client with mandatory lookahead resolver.
//!
//! This example demonstrates how to:
//! 1. Build a provider for the lookahead resolver
//! 2. Create a `PreconfirmationClientConfig` with the resolver
//! 3. Run the preconfirmation client
//!
//! The lookahead resolver is mandatory and used to validate that commitment signers
//! match the expected slot signer and that submission_window_end values are correct.

use alloy_primitives::Address;
use async_trait::async_trait;
use preconfirmation_client::{
    DriverSubmitter, PreconfirmationClient, PreconfirmationClientConfig, PreconfirmationInput,
    Result,
};
use preconfirmation_net::P2pConfig;
use protocol::subscription_source::SubscriptionSource;

/// Driver adapter used to forward inputs into the driver queue.
struct DriverAdapter;

#[async_trait]
impl DriverSubmitter for DriverAdapter {
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
    let source = SubscriptionSource::try_from(rpc_url.as_str())
        .expect("failed to parse subscription source");

    // Build the provider for lookahead resolution.
    let provider = source.to_provider().await.expect("failed to build provider");

    // Build the client configuration with the mandatory lookahead resolver.
    let config =
        PreconfirmationClientConfig::new(P2pConfig::default(), inbox_address, provider).await?;
    // Construct the client with a driver adapter.
    let client = PreconfirmationClient::new(config, DriverAdapter)?;

    // Subscribe to SDK events before starting the client.
    let mut events = client.subscribe();

    // Run the client after driver event sync completes in a background task.
    let client_task = tokio::spawn(async move { client.run_after_event_sync().await });

    // Consume events (example loop).
    while let Ok(event) = events.recv().await {
        // Handle event notifications.
        let _event = event;
    }

    // Await the client task if you want a clean shutdown path.
    let _ = client_task.await;
    Ok(())
}
