//! Event sync logic.

use std::{sync::Arc, time::Duration};

use alloy::{eips::BlockNumberOrTag, sol_types::SolEvent};
use alloy_provider::Provider;
use bindings::i_inbox::IInbox::Proposed;
use event_scanner::{EventFilter, types::ScannerMessage};
use tokio::spawn;
use tokio_retry::{Retry, strategy::ExponentialBackoff};
use tokio_stream::StreamExt;
use tracing::{info, warn};

use super::{SyncError, SyncStage};
use crate::{
    config::DriverConfig,
    derivation::{DerivationPipeline, ShastaDerivationPipeline},
};
use event_indexer::indexer::{ShastaEventIndexer, ShastaEventIndexerConfig};
use rpc::{blob::BlobDataSource, client::Client};

/// Responsible for following inbox events and updating the L2 execution engine accordingly.
pub struct EventSyncer<P>
where
    P: Provider + Clone,
{
    /// RPC client shared with derivation pipeline.
    rpc: Client<P>,
    /// Static driver configuration.
    cfg: DriverConfig,
    /// Shared Shasta event indexer used to stream inbox proposals.
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
        let indexer = ShastaEventIndexer::new(indexer_config).await?;
        Ok(Self { rpc, cfg: cfg.clone(), indexer })
    }

    /// Determine the L1 block height used to resume event consumption after beacon sync.
    ///
    /// Mirrors the Go driver's `SetUpEventSync` behaviour by querying the execution engine's head,
    /// looking up the corresponding anchor state, and falling back to the cached head L1 origin
    /// if the anchor has not been set yet (e.g. genesis).
    async fn event_stream_start_block(&self) -> Result<Option<u64>, SyncError> {
        let latest_block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?;

        let Some(latest_block) = latest_block else {
            return Err(SyncError::MissingLatestExecutionBlock);
        };

        let anchor_state = self.rpc.shasta_anchor_state_by_hash(latest_block.hash()).await?;
        let anchor_block_number = anchor_state.anchorBlockNumber.to::<u64>();

        if anchor_block_number != 0 {
            return Ok(Some(anchor_block_number));
        }

        // If the anchor block number is zero, which indicates that the EE only has genesis state,
        // fall back to the head L1 origin height if available.
        let fallback = self
            .rpc
            .head_l1_origin()
            .await?
            .and_then(|origin| origin.l1_block_height.map(|height| height.to::<u64>()));

        if let Some(height) = fallback &&
            height != 0
        {
            warn!(
                anchor_block_number,
                fallback_height = height,
                "anchor block number unset; falling back to head L1 origin height"
            );
            return Ok(Some(height));
        }

        Ok(Some(anchor_block_number))
    }
}

#[async_trait::async_trait]
impl<P> SyncStage for EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Start the event syncer.
    async fn run(&self) -> Result<(), SyncError> {
        let start_block = self.event_stream_start_block().await?;
        let (start_tag, log_height) = match start_block {
            Some(height) => (BlockNumberOrTag::Number(height), height),
            None => (BlockNumberOrTag::Earliest, 0),
        };

        info!(start_block = log_height, "starting shasta event processing from L1 block");

        // Kick off the background indexer before waiting for its historical pass to finish.
        let indexer = self.indexer.clone();
        // TODO: change to fetch last X proposal when indexer supports it.
        indexer.spawn(start_tag);

        let blob_source = BlobDataSource::new(self.cfg.l1_beacon_endpoint.clone());
        let derivation_pipeline =
            ShastaDerivationPipeline::new(self.rpc.clone(), blob_source, self.indexer.clone())
                .await?;
        let derivation: Arc<
            dyn DerivationPipeline<
                Manifest = <ShastaDerivationPipeline<P> as DerivationPipeline>::Manifest,
            >,
        > = Arc::new(derivation_pipeline);

        // Wait for historical indexing to complete before starting the derivation loop.
        self.indexer.wait_historical_indexing_finished().await;

        let mut scanner = self
            .cfg
            .client
            .l1_provider_source
            .to_event_scanner()
            .await
            .map_err(|err| SyncError::EventScannerInit(err.to_string()))?;
        let filter = EventFilter::new()
            .with_contract_address(self.cfg.client.inbox_address)
            .with_event(Proposed::SIGNATURE);

        let mut stream = scanner.create_event_stream(filter);

        spawn(async move { scanner.start_scanner(start_tag, None).await });

        while let Some(ScannerMessage::Data(logs)) = stream.next().await {
            for log in logs {
                let retry_strategy =
                    ExponentialBackoff::from_millis(10).max_delay(Duration::from_secs(12));

                let derivation = derivation.clone();
                let rpc = self.rpc.clone();
                let proposal_log = log.clone();
                let outcomes = Retry::spawn(retry_strategy, move || {
                    let derivation = derivation.clone();
                    let rpc = rpc.clone();
                    let log = proposal_log.clone();
                    async move { derivation.process_proposal(&log, &rpc).await }
                })
                .await?;

                info!(
                    block_count = outcomes.len(),
                    last_block = outcomes.last().map(|outcome| outcome.block_number),
                    last_hash = ?outcomes.last().map(|outcome| outcome.block_hash),
                    "successfully processed proposal into L2 blocks",
                );
            }
        }
        Ok(())
    }
}
