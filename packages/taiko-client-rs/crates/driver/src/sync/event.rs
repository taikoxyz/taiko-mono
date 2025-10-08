//! Event sync logic.

use std::{sync::Arc, time::Duration};

use alloy::{eips::BlockNumberOrTag, sol_types::SolEvent};
use alloy_provider::Provider;
use bindings::i_inbox::IInbox::Proposed;
use event_scanner::{EventFilter, types::ScannerMessage};
use tokio::spawn;
use tokio_retry::Retry;
use tokio_stream::StreamExt;
use tracing::info;

use super::{SyncError, SyncStage};
use crate::{
    config::DriverConfig,
    derivation::{DerivationPipeline, ShastaDerivationPipeline},
};
use event_indexer::indexer::{ShastaEventIndexer, ShastaEventIndexerConfig};
use protocol::shasta::manifest::ProposalManifest;
use rpc::{blob::BlobDataSource, client::Client};

/// Responsible for following inbox events and updating the L2 execution engine accordingly.
pub struct EventSyncer<P>
where
    P: Provider + Clone,
{
    rpc: Client<P>,
    cfg: DriverConfig,
    indexer: Arc<ShastaEventIndexer>,
}

impl<P> EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new event syncer from the provided configuration and RPC client.
    pub async fn new(cfg: &DriverConfig, rpc: Client<P>) -> Result<Self, SyncError> {
        let indexer_config = ShastaEventIndexerConfig {
            l1_subscription_source: cfg.client.l1_provider_source.clone(),
            inbox_address: cfg.client.inbox_address,
        };
        let indexer = ShastaEventIndexer::new(indexer_config)
            .await
            .map_err(|err| SyncError::IndexerInit(err.to_string()))?;

        indexer.clone().spawn();

        Ok(Self { rpc, cfg: cfg.clone(), indexer })
    }
}

#[async_trait::async_trait]
impl<P> SyncStage for EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn run(&self) -> Result<(), SyncError> {
        let blob_source = BlobDataSource::new(self.cfg.l1_beacon_endpoint.clone());
        let derivation: Arc<dyn DerivationPipeline<Manifest = ProposalManifest>> =
            Arc::new(ShastaDerivationPipeline::new(self.rpc.clone(), blob_source));

        // Wait for historical indexing to complete before starting the derivation loop.
        self.indexer.wait_historical_indexing_finished().await;

        let mut scanner =
            self.cfg.client.l1_provider_source.to_event_scanner().await.map_err(|err| {
                SyncError::Rpc(format!("failed to create event scanner: {}", err.to_string()))
            })?;
        let filter = EventFilter::new()
            .with_contract_address(self.cfg.client.inbox_address)
            .with_event(Proposed::SIGNATURE);

        let mut stream = scanner.create_event_stream(filter);

        // TODO: Choose appropriate `start` tag.
        spawn(async move { scanner.start_scanner(BlockNumberOrTag::Earliest, None).await });

        while let Some(ScannerMessage::Data(logs)) = stream.next().await {
            for log in logs {
                let retry_strategy = tokio_retry::strategy::ExponentialBackoff::from_millis(10)
                    .max_delay(Duration::from_secs(12))
                    .take(5);

                let derivation = derivation.clone();
                let result = Retry::spawn(retry_strategy, || async {
                    derivation.process_proposal(&log).await
                })
                .await
                .map_err(|err| SyncError::Derivation(err.to_string()))?;

                info!("successfully processed proposal payload attributes: {:#?}", result);
            }
        }
        Ok(())
    }
}
