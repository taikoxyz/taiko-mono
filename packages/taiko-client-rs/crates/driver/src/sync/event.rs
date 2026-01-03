//! Event sync logic.

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alloy::{
    eips::{BlockNumberOrTag, merge::EPOCH_SLOTS},
    primitives::{Address, U256},
    sol_types::SolEvent,
};
use alloy_consensus::{TxEnvelope, transaction::Transaction as _};
use alloy_provider::Provider;
use alloy_rpc_types::{Log, Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_sol_types::SolCall;
use anyhow::anyhow;
use bindings::{anchor::Anchor::anchorV4Call, inbox::Inbox::Proposed};
use event_scanner::{EventFilter, ScannerMessage};
use metrics::{counter, gauge, histogram};
use tokio::{
    spawn,
    sync::{Mutex as AsyncMutex, mpsc, oneshot},
    time::timeout,
};
use tokio_retry::{Retry, strategy::ExponentialBackoff};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, warn};

use super::{SyncError, SyncStage};
use crate::{
    config::DriverConfig,
    derivation::ShastaDerivationPipeline,
    error::DriverError,
    metrics::DriverMetrics,
    production::{
        BlockProductionPath, CanonicalL1ProductionPath, PreconfPayload, PreconfirmationPath,
        ProductionInput, ProductionRouter,
    },
};

use rpc::{blob::BlobDataSource, client::Client};

/// Two Ethereum epochs as a buffer to avoid resuming on a block that can still be reorged.
const RESUME_REORG_CUSHION_SLOTS: u64 = 2 * EPOCH_SLOTS;
/// Default timeout for preconfirmation payload submission.
const PRECONFIRMATION_PAYLOAD_SUBMIT_TIMEOUT: Duration = Duration::from_secs(24);

/// Responsible for following inbox events and updating the L2 execution engine accordingly.
pub struct EventSyncer<P>
where
    P: Provider + Clone,
{
    /// RPC client shared with derivation pipeline.
    rpc: Client<P>,
    /// Static driver configuration.
    cfg: DriverConfig,
    /// Shared blob data source used for manifest fetches.
    blob_source: Arc<BlobDataSource>,
    /// Optional preconfirmation ingress sender for external producers.
    preconf_tx: Option<PreconfSender>,
    /// Optional preconfirmation ingress receiver consumed by the sync loop.
    preconf_rx: Option<Arc<AsyncMutex<PreconfReceiver>>>,
}

/// Maximum number of buffered preconfirmation payloads before backpressure applies.
const PRECONF_CHANNEL_CAPACITY: usize = 1024;

/// Type aliases for preconfirmation payload channels.
type PreconfSender = mpsc::Sender<PreconfJob>;
type PreconfReceiver = mpsc::Receiver<PreconfJob>;

/// A preconfirmation payload submission job.
pub struct PreconfJob {
    payload: Arc<PreconfPayload>,
    respond_to: oneshot::Sender<Result<(), DriverError>>,
}

impl<P> EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build the production router with the enabled paths.
    fn build_router(
        &self,
        derivation: Arc<ShastaDerivationPipeline<P>>,
    ) -> Arc<AsyncMutex<ProductionRouter>> {
        let mut paths: Vec<Arc<dyn BlockProductionPath + Send + Sync>> = Vec::new();

        // Add canonical L1 proposal path.
        let canonical_path: Arc<dyn BlockProductionPath + Send + Sync> = Arc::new(
            CanonicalL1ProductionPath::new(derivation.clone(), Arc::new(self.rpc.clone())),
        );
        paths.push(canonical_path);

        // Add preconfirmation path if enabled.
        if self.cfg.preconfirmation_enabled {
            let preconf_path: Arc<dyn BlockProductionPath + Send + Sync> =
                Arc::new(PreconfirmationPath::new(self.rpc.clone()));
            paths.push(preconf_path);
        }

        Arc::new(AsyncMutex::new(ProductionRouter::new(paths)))
    }

    /// Spawn the preconfirmation ingress processing loop.
    fn spawn_preconf_ingress(
        &self,
        router: Arc<AsyncMutex<ProductionRouter>>,
        rx: Arc<AsyncMutex<PreconfReceiver>>,
    ) {
        spawn(async move {
            // Start consuming externally supplied preconfirmation payloads.
            info!(
                queue_capacity = PRECONF_CHANNEL_CAPACITY,
                "started preconfirmation ingress loop"
            );
            let mut rx = rx.lock().await;
            while let Some(payload) = rx.recv().await {
                // Track current backlog before processing this job.
                gauge!(DriverMetrics::PRECONF_QUEUE_DEPTH).set(rx.len() as f64);
                let router = router.clone();
                let job = payload;
                let start = Instant::now();
                let block_number = job.payload.execution_payload().execution_payload.block_number;
                let block_hash = job.payload.execution_payload().execution_payload.block_hash;

                // Single-shot injection; serialise via router lock to avoid interleaving.
                let router_call = router
                    .lock()
                    .await
                    .produce(ProductionInput::Preconfirmation(job.payload.clone()))
                    .await;

                let duration_secs = start.elapsed().as_secs_f64();
                histogram!(DriverMetrics::PRECONF_INJECTION_DURATION_SECONDS).record(duration_secs);

                match router_call {
                    Ok(_) => {
                        counter!(DriverMetrics::PRECONF_INJECTION_SUCCESS_TOTAL).increment(1);
                        info!(
                            block_number,
                            block_hash = ?block_hash,
                            duration_secs,
                            "preconfirmation payload injected"
                        );
                        // Return success to the original sender.
                        let _ = job.respond_to.send(Ok(()));
                    }
                    Err(err) => {
                        counter!(DriverMetrics::PRECONF_INJECTION_FAILURES_TOTAL).increment(1);
                        error!(
                            ?err,
                            block_number,
                            block_hash = ?block_hash,
                            duration_secs,
                            "preconfirmation processing failed"
                        );
                        // Surface the error to the original sender.
                        let _ = job.respond_to.send(Err(err));
                    }
                }
                gauge!(DriverMetrics::PRECONF_QUEUE_DEPTH).set(rx.len() as f64);
            }
        });
    }

    /// Process a batch of proposal logs from the event scanner.
    async fn process_log_batch(
        &self,
        router: Arc<AsyncMutex<ProductionRouter>>,
        logs: Vec<Log>,
    ) -> Result<(), SyncError> {
        debug!(log_batch_size = logs.len(), "processing proposal log batch");
        for log in logs {
            debug!(
                block_number = log.block_number,
                transaction_hash = ?log.transaction_hash,
                "dispatching proposal log to derivation pipeline"
            );
            // Retry proposal processing on transient errors.
            let retry_strategy =
                ExponentialBackoff::from_millis(10).max_delay(Duration::from_secs(12));

            let router = router.clone();
            let proposal_log = log.clone();
            let outcomes = Retry::spawn(retry_strategy, move || {
                let router = router.clone();
                let log = proposal_log.clone();
                async move {
                    router
                        // Lock router so L1 proposals and preconf inputs cannot interleave.
                        .lock()
                        .await
                        .produce(ProductionInput::L1ProposalLog(log.clone()))
                        .await
                        .map_err(|err| {
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
            .await
            .map_err(|err| match err {
                DriverError::Sync(sync_err) => sync_err,
                DriverError::Rpc(rpc_err) => SyncError::Rpc(rpc_err),
                other => SyncError::Other(anyhow!(other)),
            })?;

            info!(
                block_count = outcomes.len(),
                last_block = outcomes.last().map(|outcome| outcome.block_number()),
                last_hash = ?outcomes.last().map(|outcome| outcome.block_hash()),
                "successfully processed proposal into L2 blocks",
            );
            counter!(DriverMetrics::EVENT_DERIVED_BLOCKS_TOTAL).increment(outcomes.len() as u64);
        }
        Ok(())
    }

    /// Construct a new event syncer from the provided configuration and RPC client.
    #[instrument(skip(cfg, rpc))]
    pub async fn new(cfg: &DriverConfig, rpc: Client<P>) -> Result<Self, SyncError> {
        let blob_source = Arc::new(
            BlobDataSource::new(
                Some(cfg.l1_beacon_endpoint.clone()),
                cfg.blob_server_endpoint.clone(),
                false,
            )
            .await
            .map_err(|err| SyncError::Other(err.into()))?,
        );
        let (preconf_tx, preconf_rx) = if cfg.preconfirmation_enabled {
            let (tx, rx) = mpsc::channel(PRECONF_CHANNEL_CAPACITY);
            (Some(tx), Some(Arc::new(AsyncMutex::new(rx))))
        } else {
            (None, None)
        };
        Ok(Self { rpc, cfg: cfg.clone(), blob_source, preconf_tx, preconf_rx })
    }

    /// Sender handle for feeding preconfirmation payloads into the router (if enabled).
    pub fn preconfirmation_sender(&self) -> Option<PreconfSender> {
        self.preconf_tx.clone()
    }

    /// Submit a preconfirmation payload and await the processing result.
    pub async fn submit_preconfirmation_payload(
        &self,
        payload: PreconfPayload,
    ) -> Result<(), DriverError> {
        self.submit_preconfirmation_payload_with_timeout(
            payload,
            PRECONFIRMATION_PAYLOAD_SUBMIT_TIMEOUT,
        )
        .await
    }

    /// Submit a preconfirmation payload with a caller-provided timeout for enqueue + response.
    pub async fn submit_preconfirmation_payload_with_timeout(
        &self,
        payload: PreconfPayload,
        timeout_duration: Duration,
    ) -> Result<(), DriverError> {
        let tx = self.preconf_tx.as_ref().ok_or_else(|| {
            DriverError::Other(anyhow!("preconfirmation is not enabled in driver config"))
        })?;

        // Create oneshot channel for receiving the processing result.
        let (resp_tx, resp_rx) = oneshot::channel();
        // Enqueue the preconfirmation job with timeout.
        timeout(
            timeout_duration,
            tx.send(PreconfJob { payload: Arc::new(payload), respond_to: resp_tx }),
        )
        .await
        .map_err(|_| DriverError::PreconfEnqueueTimeout { waited: timeout_duration })?
        .map_err(|err| DriverError::PreconfEnqueueFailed(err.to_string()))?;

        // Await the processing result with timeout.
        timeout(timeout_duration, resp_rx)
            .await
            .map_err(|_| DriverError::PreconfResponseTimeout { waited: timeout_duration })?
            .map_err(|err| DriverError::PreconfResponseDropped { recv_error: err })??;
        Ok(())
    }

    /// Determine the L1 block height used to resume event consumption after beacon sync.
    ///
    /// Mirrors the Go driver's `SetUpEventSync` behaviour by querying the execution engine's head,
    /// looking up the corresponding anchor state, and falling back to the cached head L1 origin
    /// if the anchor has not been set yet (e.g. genesis).
    #[instrument(skip(self), level = "debug")]
    async fn event_stream_start_block(&self) -> Result<(u64, U256), SyncError> {
        let latest_block: RpcBlock<TxEnvelope> = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .full()
            .await
            .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
            .ok_or(SyncError::MissingLatestExecutionBlock)?
            .map_transactions(|tx: RpcTransaction| tx.into());

        let anchor_address = *self.rpc.shasta.anchor.address();
        let latest_proposal_id = decode_anchor_proposal_id(&latest_block)?;

        // Determine the target block to extract the anchor block number from.
        // Back off two epochs worth of proposals to survive L1 reorgs.
        let target_proposal_id = latest_proposal_id.saturating_sub(RESUME_REORG_CUSHION_SLOTS);
        info!(
            latest_proposal_id = latest_proposal_id,
            target_proposal_id = target_proposal_id,
            latest_hash = ?latest_block.hash(),
            latest_number = latest_block.number(),
            "derived proposal id from latest anchorV4 transaction",
        );
        if target_proposal_id == 0 {
            return Ok((0, U256::ZERO));
        }

        let target_block_number = self
            .rpc
            .last_block_id_by_batch_id(U256::from(target_proposal_id))
            .await
            .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
            .ok_or(SyncError::MissingExecutionBlockForBatch { proposal_id: target_proposal_id })?;
        let target_block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(target_block_number.to()))
            .full()
            .await
            .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
            .ok_or(SyncError::MissingExecutionBlock { number: target_block_number.to() })?
            .map_transactions(|tx: RpcTransaction| tx.into());

        info!(
            target_hash = ?target_block.hash(),
            target_block_number = target_block.number(),
            "determined target block for anchor extraction",
        );
        let anchor_block_number =
            self.decode_anchor_block_number(&target_block, anchor_address).await?;
        info!(
            anchor_block_number,
            latest_hash = ?target_block.hash(),
            latest_number = target_block.number(),
            target_proposal_id = target_proposal_id,
            "derived anchor block number from anchorV4 transaction",
        );
        Ok((anchor_block_number, U256::from(target_proposal_id)))
    }
}

impl<P> EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Resolve the activation block number by converting the inbox activation timestamp through
    /// the beacon endpoint.
    async fn activation_block_number(&self) -> Result<u64, SyncError> {
        let activation_time = self
            .rpc
            .shasta
            .inbox
            .activationTimestamp()
            .call()
            .await
            .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
            .to::<u64>();

        if activation_time == 0 {
            return Ok(0);
        }

        let block_number = self
            .blob_source
            .execution_block_number_by_timestamp(activation_time)
            .await
            .map_err(|err| SyncError::Other(err.into()))?;
        info!(
            activation_time,
            activation_block_number = block_number,
            "resolved activation timestamp to L1 block number via beacon"
        );
        Ok(block_number)
    }

    /// Parse the first transaction in `block` and recover the anchor block number from the
    /// `anchorV4` calldata emitted by the goldentouch transaction. Falls back to the activation
    /// block number when inspecting the genesis block.
    async fn decode_anchor_block_number(
        &self,
        block: &RpcBlock<TxEnvelope>,
        anchor_address: Address,
    ) -> Result<u64, SyncError> {
        if block.header.number == 0 {
            return self.activation_block_number().await;
        }
        Ok(decode_anchor_call(block, anchor_address)?._checkpoint.blockNumber.to::<u64>())
    }
}

/// Recover the proposal id from header extra data.
/// Byte layout: basefeeSharingPctg (byte 0), proposalId uint48 (bytes 1..6, big-endian).
fn decode_anchor_proposal_id(block: &RpcBlock<TxEnvelope>) -> Result<u64, SyncError> {
    if block.header.number == 0 {
        return Ok(0);
    }
    let extra_data = block.header.extra_data.as_ref();
    if extra_data.len() < 7 {
        return Err(SyncError::MissingAnchorTransaction {
            block_number: block.header.number,
            reason: "extra_data too short for proposal id",
        });
    }
    let mut buf = [0u8; 8];
    // Zero-pad the upper two bytes so the uint48 (bytes 1..6) becomes a big-endian u64.
    buf[2..8].copy_from_slice(&extra_data[1..7]);
    Ok(u64::from_be_bytes(buf))
}

/// Parse the first transaction in `block` and recover the `anchorV4` call data.
fn decode_anchor_call(
    block: &RpcBlock<TxEnvelope>,
    anchor_address: Address,
) -> Result<anchorV4Call, SyncError> {
    let block_number = block.header.number;
    let missing =
        |reason: &'static str| SyncError::MissingAnchorTransaction { block_number, reason };

    let txs = block
        .transactions
        .as_transactions()
        .ok_or_else(|| missing("block body returned only transaction hashes"))?;
    let first_tx = txs.first().ok_or_else(|| missing("block contains no transactions"))?;
    // Anchor transactions are injected as the first transaction for every non-genesis block.
    let destination =
        first_tx.to().ok_or_else(|| missing("unable to determine anchor transaction recipient"))?;
    if destination != anchor_address {
        return Err(missing("first transaction is not the anchor contract"));
    }

    anchorV4Call::abi_decode(first_tx.input())
        .map_err(|_| missing("failed to decode anchorV4 calldata"))
}

#[async_trait::async_trait]
impl<P> SyncStage for EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Start the event syncer.
    #[instrument(skip(self), name = "event_syncer_run")]
    async fn run(&self) -> Result<(), SyncError> {
        let (anchor_block_number, initial_proposal_id) = self.event_stream_start_block().await?;
        let start_tag = BlockNumberOrTag::Number(anchor_block_number);

        info!(start_tag = ?start_tag, "starting shasta event processing from L1 block");

        let derivation_pipeline = ShastaDerivationPipeline::new(
            self.rpc.clone(),
            self.blob_source.clone(),
            initial_proposal_id,
        )
        .await?;
        let derivation = Arc::new(derivation_pipeline);
        let router = self.build_router(derivation.clone());

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

        // Spawn preconfirmation ingress loop if enabled.
        if let Some(rx) = self.preconf_rx.clone() {
            self.spawn_preconf_ingress(router.clone(), rx);
        }

        while let Some(message) = stream.next().await {
            debug!(?message, "received inbox proposal message from event scanner");
            let logs = match message {
                Ok(ScannerMessage::Data(logs)) => {
                    counter!(DriverMetrics::EVENT_SCANNER_BATCHES_TOTAL).increment(1);
                    counter!(DriverMetrics::EVENT_PROPOSALS_TOTAL).increment(logs.len() as u64);
                    logs
                }
                Ok(ScannerMessage::Notification(notification)) => {
                    info!(?notification, "event scanner notification");
                    continue;
                }
                Err(err) => {
                    counter!(DriverMetrics::EVENT_SCANNER_ERRORS_TOTAL).increment(1);
                    error!(?err, "error receiving proposal logs from event scanner");
                    continue;
                }
            };

            self.process_log_batch(router.clone(), logs).await?;
        }
        Ok(())
    }
}
