use async_trait::async_trait;
use preconfirmation_client::{
    DriverSubmitter, PreconfirmationClient, PreconfirmationClientConfig, PreconfirmationInput,
    Result,
};

/// Driver adapter used to forward inputs into the driver queue.
struct DriverAdapter;

#[async_trait]
impl DriverSubmitter for DriverAdapter {
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        // Forward the input to the driver for ordered processing.
        let _commitment = input.commitment;
        Ok(())
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    // Build a default config and tweak as needed.
    let config = PreconfirmationClientConfig::default();
    // Construct the client with a driver adapter.
    let client = PreconfirmationClient::new(config, DriverAdapter)?;

    // Subscribe to SDK events before starting the client.
    let mut events = client.subscribe();

    // Provide a signal that completes once L2 sync finishes.
    let sync_done = async move {
        // Await L2 sync completion.
    };

    // Run the client after sync in a background task.
    let client_task = tokio::spawn(async move { client.run_after_sync(sync_done).await });

    // Consume events (example loop).
    while let Ok(event) = events.recv().await {
        // Handle event notifications.
        let _event = event;
    }

    // Await the client task if you want a clean shutdown path.
    let _ = client_task.await;
    Ok(())
}
