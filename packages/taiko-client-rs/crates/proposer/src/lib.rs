use std::str::FromStr;

use alloy::{primitives::Address, transports::http::reqwest::Url};
use event_indexer::indexer::{ShastaEventIndexer, ShastaEventIndexerConfig, SubscriptionSource};

// Proposer keep proposing new transactions from L2 execution engine's tx pool at a fixed interval.
pub struct Proposer {
    _event_indexer: ShastaEventIndexer,
}

impl Proposer {
    /// Creates a new proposer instance.
    pub async fn new() -> anyhow::Result<Self> {
        let indexer = ShastaEventIndexer::new(ShastaEventIndexerConfig {
            l1_subscription_source: SubscriptionSource::Ws(Url::from_str("s")?),
            inbox_address: Address::ZERO,
        })
        .await?;
        Ok(Self { _event_indexer: indexer })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn proposer_initializes() {}
}
