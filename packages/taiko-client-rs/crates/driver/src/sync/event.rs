//! Event sync logic.

use std::{sync::Arc, time::Duration};

use alloy::{eips::BlockNumberOrTag, sol_types::SolEvent};
use alloy_provider::Provider;
use bindings::i_inbox::IInbox::Proposed;
use event_scanner::{EventFilter, ScannerMessage};
use protocol::shasta::constants::BOND_PROCESSING_DELAY;
use tokio::spawn;
use tokio_retry::{Retry, strategy::ExponentialBackoff};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, warn};

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
    /// Shared blob data source used for manifest fetches.
    blob_source: Arc<BlobDataSource>,
}

impl<P> EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new event syncer from the provided configuration and RPC client.
    #[instrument(skip(cfg, rpc))]
    pub async fn new(cfg: &DriverConfig, rpc: Client<P>) -> Result<Self, SyncError> {
        let indexer_config = ShastaEventIndexerConfig {
            l1_subscription_source: cfg.client.l1_provider_source.clone(),
            inbox_address: cfg.client.inbox_address,
        };
        let indexer = ShastaEventIndexer::new(indexer_config).await?;
        let blob_source = Arc::new(
            BlobDataSource::new(
                Some(cfg.l1_beacon_endpoint.clone()),
                cfg.blob_server_endpoint.clone(),
            )
            .await
            .map_err(|err| SyncError::Other(err.into()))?,
        );
        Ok(Self { rpc, cfg: cfg.clone(), indexer, blob_source })
    }

    /// Determine the L1 block height used to resume event consumption after beacon sync.
    ///
    /// Mirrors the Go driver's `SetUpEventSync` behaviour by querying the execution engine's head,
    /// looking up the corresponding anchor state, and falling back to the cached head L1 origin
    /// if the anchor has not been set yet (e.g. genesis).
    #[instrument(skip(self), level = "debug")]
    async fn event_stream_start_block(&self) -> Result<u64, SyncError> {
        let latest_block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
            .ok_or(SyncError::MissingLatestExecutionBlock)?;

        let target_block = if latest_block.number() > BOND_PROCESSING_DELAY {
            let target_number = latest_block.number() - BOND_PROCESSING_DELAY;
            self.rpc
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(target_number))
                .await
                .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
                .ok_or(SyncError::MissingExecutionBlock { number: target_number })?
        } else {
            latest_block
        };

        let anchor_state = self.rpc.shasta_anchor_state_by_hash(target_block.hash()).await?;
        let anchor_block_number = anchor_state.anchor_block_number;
        info!(
            anchor_block_number,
            latest_hash = ?target_block.hash(),
            latest_number = target_block.number(),
            "queried anchor state for target execution block",
        );

        if anchor_block_number != 0 {
            return Ok(anchor_block_number);
        }

        // If the anchor block number is zero, which indicates that the EE only has genesis state,
        // fall back to the head L1 origin height if available.
        let fallback = self
            .rpc
            .head_l1_origin()
            .await?
            .and_then(|origin| origin.l1_block_height.map(|height| height.to::<u64>()));

        if let Some(height) = fallback.filter(|height| *height != 0) {
            warn!(
                anchor_block_number,
                fallback_height = height,
                "anchor block number unset; falling back to head L1 origin height"
            );
            info!(
                anchor_block_number,
                fallback_height = height,
                "using cached head L1 origin height as stream start"
            );
            return Ok(height);
        }

        // If both the anchor block number and head L1 origin height are unset (e.g. genesis),
        // return block zero.
        warn!(
            "anchor block number and head L1 origin height unset; starting event stream from block zero"
        );
        debug!("defaulting event stream start to block zero");
        Ok(0)
    }
}

#[async_trait::async_trait]
impl<P> SyncStage for EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Start the event syncer.
    #[instrument(skip(self), name = "event_syncer_run")]
    async fn run(&self) -> Result<(), SyncError> {
        let start_tag = BlockNumberOrTag::Number(self.event_stream_start_block().await?);

        info!(start_tag = ?start_tag, "starting shasta event processing from L1 block");
        debug!(start_tag = ?start_tag, "event syncer run invoked");

        // Kick off the background indexer before waiting for its historical pass to finish.
        let indexer = self.indexer.clone();
        indexer.spawn();
        debug!("spawned shasta event indexer");

        let derivation_pipeline = ShastaDerivationPipeline::new(
            self.rpc.clone(),
            self.blob_source.clone(),
            self.indexer.clone(),
        )
        .await?;
        let derivation: Arc<
            dyn DerivationPipeline<
                Manifest = <ShastaDerivationPipeline<P> as DerivationPipeline>::Manifest,
            >,
        > = Arc::new(derivation_pipeline);

        // Wait for historical indexing to complete before starting the derivation loop.
        debug!("waiting for historical event indexing to finish");
        self.indexer.wait_historical_indexing_finished().await;

        info!("historical event indexing completed; starting proposal processing");
        debug!("historical indexing finished; proceeding to live stream");

        let mut scanner = self
            .cfg
            .client
            .l1_provider_source
            .to_event_scanner_from_tag(start_tag)
            .await
            .map_err(|err| SyncError::EventScannerInit(err.to_string()))?;
        let filter = EventFilter::new()
            .contract_address(self.cfg.client.inbox_address)
            .event(Proposed::SIGNATURE);

        let mut stream = scanner.subscribe(filter);
        debug!("subscribed to inbox proposal event filter");

        spawn(async move {
            if let Err(err) = scanner.start().await {
                error!(?err, "event scanner terminated unexpectedly");
            }
        });

        info!("event scanner started; listening for inbox proposals");
        debug!("event scanner task started");

        while let Some(message) = stream.next().await {
            info!(?message, "received inbox proposal message from event scanner");
            debug!(?message, "processing scanner message");
            let logs = match message {
                ScannerMessage::Data(logs) => logs,
                ScannerMessage::Error(err) => {
                    error!(?err, "error receiving proposal logs from event scanner");
                    continue;
                }
                ScannerMessage::Status(status) => {
                    info!(?status, "event scanner status update");
                    continue;
                }
            };

            debug!(log_batch_size = logs.len(), "processing proposal log batch");
            for log in logs {
                debug!(
                    block_number = log.block_number,
                    transaction_hash = ?log.transaction_hash,
                    "dispatching proposal log to derivation pipeline"
                );
                let retry_strategy =
                    ExponentialBackoff::from_millis(10).max_delay(Duration::from_secs(12));

                let derivation = derivation.clone();
                let rpc = self.rpc.clone();
                let proposal_log = log.clone();
                let outcomes = Retry::spawn(retry_strategy, move || {
                    let derivation = derivation.clone();
                    let rpc = rpc.clone();
                    let log = proposal_log.clone();
                    async move {
                        derivation.process_proposal(&log, &rpc).await.map_err(|err| {
                            warn!(
                                ?err,
                                tx_hash = ?log.transaction_hash,
                                block_number = log.block_number,
                                "proposal derivation failed; retrying"
                            );
                            err
                        })
                    }
                })
                .await?;

                info!(
                    block_count = outcomes.len(),
                    last_block = outcomes.last().map(|outcome| outcome.block_number()),
                    last_hash = ?outcomes.last().map(|outcome| outcome.block_hash()),
                    "successfully processed proposal into L2 blocks",
                );
                debug!(
                    block_count = outcomes.len(),
                    last_block = outcomes.last().map(|outcome| outcome.block_number()),
                    "proposal derivation outcomes recorded"
                );
            }
        }
        Ok(())
    }
}
