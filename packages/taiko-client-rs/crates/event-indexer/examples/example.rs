use std::str::FromStr;

use alloy::transports::http::reqwest::Url;
use alloy_primitives::Address;
use event_indexer::{
    indexer::{ShastaEventIndexer, ShastaEventIndexerConfig, SubscriptionSource},
    interface::ShastaProposeInputReader,
};
use tokio::signal;
use tracing::error;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let indexer = ShastaEventIndexer::new(ShastaEventIndexerConfig {
        l1_subscription_source: SubscriptionSource::Ws(Url::from_str("ws://127.0.0.1:8546")?),
        inbox_address: Address::ZERO,
    })
    .await?;

    let _ = indexer.read_shasta_propose_input();

    let indexer_task = tokio::spawn(async move {
        let mut indexer = indexer;
        if let Err(err) = indexer.run().await {
            error!(?err, "Shasta event indexer error");
        }
    });

    signal::ctrl_c().await?;
    indexer_task.abort();
    let _ = indexer_task.await;

    Ok(())
}
