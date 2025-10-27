use alloy::eips::BlockNumberOrTag;
use alloy_primitives::Address;
use event_indexer::{
    indexer::{ShastaEventIndexer, ShastaEventIndexerConfig},
    interface::ShastaProposeInputReader,
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = ShastaEventIndexerConfig {
        l1_subscription_connection_string: "ws://127.0.0.1:8546".to_string(),
        inbox_address: Address::ZERO,
    };

    // Create and spawn the indexer.
    let indexer = ShastaEventIndexer::new(config).await?;
    indexer.clone().spawn(BlockNumberOrTag::Number(0));
    indexer.wait_historical_indexing_finished().await;

    // Read cached input parameters from the indexer, for submitting a `propose` transaction to
    // Shasta inbox.
    let _ = indexer.read_shasta_propose_input();

    Ok(())
}
