use std::{str::FromStr, sync::Arc};

use alloy::transports::http::reqwest::Url;
use alloy_primitives::Address;
use event_indexer::{
    indexer::{ShastaEventIndexer, ShastaEventIndexerConfig, SubscriptionSource},
    interface::ShastaProposeInputReader,
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = ShastaEventIndexerConfig {
        l1_subscription_source: SubscriptionSource::Ws(Url::from_str("ws://127.0.0.1:8546")?),
        inbox_address: Address::ZERO,
    };

    let indexer = Arc::new(ShastaEventIndexer::new(config).await?);
    indexer.clone().spawn();
    let _ = indexer.read_shasta_propose_input();

    Ok(())
}
