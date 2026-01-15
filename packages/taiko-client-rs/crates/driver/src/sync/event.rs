//! Event sync logic.

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
    time::{Duration, Instant},
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::{
    eips::{BlockNumberOrTag, merge::EPOCH_SLOTS},
    primitives::{Address, B256, U256},
    sol_types::SolEvent,
};
use alloy_consensus::{TxEnvelope, transaction::Transaction as _};
use alloy_provider::Provider;
use alloy_rpc_types::{Filter, Log, Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_sol_types::SolCall;
use anyhow::anyhow;
use async_trait::async_trait;
use bindings::{anchor::Anchor::anchorV4Call, inbox::Inbox::Proposed};
use metrics::{counter, gauge, histogram};
use tokio::{
    spawn,
    sync::{Mutex as AsyncMutex, Notify, mpsc, oneshot},
    time::{MissedTickBehavior, interval, timeout},
};
use tokio_retry::{Retry, strategy::ExponentialBackoff};
use tracing::{debug, error, info, instrument, warn};

use super::{SyncError, SyncStage};
use crate::{
    config::DriverConfig,
    derivation::ShastaDerivationPipeline,
    error::DriverError,
    jsonrpc::DriverRpcApi,
    metrics::DriverMetrics,
    production::{
        BlockProductionPath, CanonicalL1ProductionPath, PreconfPayload, PreconfirmationPath,
        ProductionInput, ProductionRouter,
    },
};

use rpc::{RpcClientError, blob::BlobDataSource, client::Client};

/// Two Ethereum epochs worth of slots used as a reorg safety buffer.
///
/// When resuming event sync, the driver backs off by this many slots to ensure
/// the anchor block cannot still be reorganized on L1.
const RESUME_REORG_CUSHION_SLOTS: u64 = 2 * EPOCH_SLOTS;
/// Default timeout for preconfirmation payload submission.
///
/// Covers both the enqueue operation and awaiting the processing response.
const PRECONFIRMATION_PAYLOAD_SUBMIT_TIMEOUT: Duration = Duration::from_secs(12);
const L1_POLL_INTERVAL: Duration = Duration::from_secs(1);
const L1_LOG_POLL_MAX_BLOCK_RANGE: u64 = 1000;

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
    /// Tracks the highest canonical proposal id processed from L1 events.
    last_canonical_proposal_id: Arc<AtomicU64>,
    /// Indicates whether the preconfirmation ingress loop is ready to accept submissions.
    preconf_ingress_ready: Arc<AtomicBool>,
    /// Notifier signaled when the preconfirmation ingress loop becomes ready.
    preconf_ingress_notify: Arc<Notify>,
}

/// Maximum number of buffered preconfirmation payloads before backpressure applies.
///
/// When the channel is full, senders will block until space is available.
const PRECONF_CHANNEL_CAPACITY: usize = 1024;

/// Type aliases for preconfirmation payload channels.
type PreconfSender = mpsc::Sender<PreconfJob>;
type PreconfReceiver = mpsc::Receiver<PreconfJob>;

/// A preconfirmation payload submission job.
///
/// Wraps a payload and a oneshot channel for returning the processing result
/// back to the caller.
pub struct PreconfJob {
    /// The preconfirmation payload to be processed.
    payload: Arc<PreconfPayload>,
    /// Oneshot channel to send the processing result back to the caller.
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
        ready_flag: Arc<AtomicBool>,
        ready_notify: Arc<Notify>,
    ) {
        spawn(async move {
            // Start consuming externally supplied preconfirmation payloads.
            info!(
                queue_capacity = PRECONF_CHANNEL_CAPACITY,
                "started preconfirmation ingress loop"
            );
            let mut rx = rx.lock().await;
            // Signal that the ingress loop is ready to accept submissions.
            ready_flag.store(true, Ordering::Release);
            ready_notify.notify_waiters();
            while let Some(job) = rx.recv().await {
                // Track current backlog before processing this job.
                gauge!(DriverMetrics::PRECONF_QUEUE_DEPTH).set(rx.len() as f64);
                let router = router.clone();
                let start = Instant::now();
                let block_number = job.payload.block_number();

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
                            build_payload_args_id = ?job.payload.payload().l1_origin.build_payload_args_id,
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
                            build_payload_args_id = ?job.payload.payload().l1_origin.build_payload_args_id,
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

    /// Process a batch of proposal logs from L1.
    async fn process_log_batch(
        &self,
        router: Arc<AsyncMutex<ProductionRouter>>,
        logs: Vec<Log>,
    ) -> Result<(), SyncError> {
        debug!(log_batch_size = logs.len(), "processing proposal log batch");
        for log in logs {
            let proposal_id = Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())
                .map(|event| event.id.to::<u64>())
                .map_err(|e| SyncError::InvalidProposalLog {
                    reason: e.to_string(),
                    tx_hash: log.transaction_hash,
                    block_number: log.block_number,
                })?;

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

            self.last_canonical_proposal_id.store(proposal_id, Ordering::Relaxed);
            gauge!(DriverMetrics::EVENT_LAST_CANONICAL_PROPOSAL_ID).set(proposal_id as f64);
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
        Ok(Self {
            rpc,
            cfg: cfg.clone(),
            blob_source,
            preconf_tx,
            preconf_rx,
            last_canonical_proposal_id: Arc::new(AtomicU64::new(0)),
            preconf_ingress_ready: Arc::new(AtomicBool::new(false)),
            preconf_ingress_notify: Arc::new(Notify::new()),
        })
    }

    /// Return the latest canonical proposal id processed from L1 events.
    pub fn last_canonical_proposal_id(&self) -> u64 {
        self.last_canonical_proposal_id.load(Ordering::Relaxed)
    }

    /// Sender handle for feeding preconfirmation payloads into the router (if enabled).
    pub fn preconfirmation_sender(&self) -> Option<PreconfSender> {
        self.preconf_tx.clone()
    }

    /// Wait until the preconfirmation ingress loop is ready to accept submissions.
    ///
    /// Returns `None` if preconfirmation is disabled.
    pub async fn wait_preconf_ingress_ready(&self) -> Option<()> {
        self.preconf_tx.as_ref()?;
        loop {
            let notified = self.preconf_ingress_notify.notified();
            if self.preconf_ingress_ready.load(Ordering::Acquire) {
                return Some(());
            }
            notified.await;
        }
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
        let tx = self.preconf_tx.as_ref().ok_or(DriverError::PreconfirmationDisabled)?;

        // Reject early if ingress loop is not ready yet.
        if !self.preconf_ingress_ready.load(Ordering::Acquire) {
            return Err(DriverError::PreconfIngressNotReady);
        }

        let block_number = payload.block_number();

        debug!(block_number, "submitting preconfirmation payload to queue");

        // Create oneshot channel for receiving the processing result.
        let (resp_tx, resp_rx) = oneshot::channel();
        // Enqueue the preconfirmation job with timeout.
        let enqueue_result = timeout(
            timeout_duration,
            tx.send(PreconfJob { payload: Arc::new(payload), respond_to: resp_tx }),
        )
        .await;

        match enqueue_result {
            Err(_) => {
                counter!(DriverMetrics::PRECONF_ENQUEUE_TIMEOUTS_TOTAL).increment(1);
                error!(
                    block_number,
                    timeout_ms = timeout_duration.as_millis() as u64,
                    "preconfirmation enqueue timed out"
                );
                return Err(DriverError::PreconfEnqueueTimeout { waited: timeout_duration });
            }
            Ok(Err(err)) => {
                counter!(DriverMetrics::PRECONF_ENQUEUE_FAILURES_TOTAL).increment(1);
                error!(block_number, ?err, "preconfirmation enqueue failed");
                return Err(DriverError::PreconfEnqueueFailed(err.to_string()));
            }
            Ok(Ok(())) => {
                debug!(block_number, "preconfirmation payload enqueued successfully");
            }
        }

        // Await the processing result with timeout.
        let response_result = timeout(timeout_duration, resp_rx).await;

        match response_result {
            Err(_) => {
                counter!(DriverMetrics::PRECONF_RESPONSE_TIMEOUTS_TOTAL).increment(1);
                error!(
                    block_number,
                    timeout_ms = timeout_duration.as_millis() as u64,
                    "preconfirmation response timed out"
                );
                return Err(DriverError::PreconfResponseTimeout { waited: timeout_duration });
            }
            Ok(Err(err)) => {
                counter!(DriverMetrics::PRECONF_RESPONSE_DROPPED_TOTAL).increment(1);
                error!(block_number, ?err, "preconfirmation response channel closed");
                return Err(DriverError::PreconfResponseDropped { recv_error: err });
            }
            Ok(Ok(inner_result)) => {
                if let Err(ref err) = inner_result {
                    warn!(block_number, ?err, "preconfirmation processing returned error");
                }
                inner_result?;
            }
        }

        debug!(block_number, "preconfirmation payload processed successfully");
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
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?
            .ok_or(SyncError::MissingLatestExecutionBlock)?
            .map_transactions(|tx: RpcTransaction| tx.into());

        let anchor_address = *self.rpc.shasta.anchor.address();
        let latest_proposal_id = decode_anchor_proposal_id(&latest_block)?;

        // Determine the target block to extract the anchor block number from.
        // Back off two epochs worth of proposals to survive L1 reorgs.
        let target_proposal_id = latest_proposal_id.saturating_sub(RESUME_REORG_CUSHION_SLOTS);
        info!(
            latest_proposal_id,
            target_proposal_id,
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
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?
            .ok_or(SyncError::MissingExecutionBlockForBatch { proposal_id: target_proposal_id })?;
        let target_block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(target_block_number.to()))
            .full()
            .await
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?
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

#[async_trait]
impl<P> DriverRpcApi for EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Submit a preconfirmation payload built by the client for injection.
    async fn submit_execution_payload_v2(
        &self,
        payload: TaikoPayloadAttributes,
    ) -> Result<(), DriverError> {
        self.submit_preconfirmation_payload(PreconfPayload::new(payload)).await
    }

    /// Return the last canonical proposal id processed by the event syncer.
    fn last_canonical_proposal_id(&self) -> u64 {
        self.last_canonical_proposal_id()
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
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?
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

        let mut next_block = anchor_block_number;
        let mut last_head_number: Option<u64> = None;
        let mut last_head_hash: Option<B256> = None;
        let mut poller = interval(L1_POLL_INTERVAL);
        poller.set_missed_tick_behavior(MissedTickBehavior::Delay);

        info!(
            start_block = next_block,
            poll_interval_secs = L1_POLL_INTERVAL.as_secs_f64(),
            "starting L1 proposal log polling"
        );

        // Spawn preconfirmation ingress loop if enabled.
        if let Some(rx) = self.preconf_rx.clone() {
            self.spawn_preconf_ingress(
                router.clone(),
                rx,
                self.preconf_ingress_ready.clone(),
                self.preconf_ingress_notify.clone(),
            );
        }

        loop {
            poller.tick().await;

            let latest_block =
                match self.rpc.l1_provider.get_block_by_number(BlockNumberOrTag::Latest).await {
                    Ok(Some(block)) => block,
                    Ok(None) => {
                        counter!(DriverMetrics::EVENT_SCANNER_ERRORS_TOTAL).increment(1);
                        warn!("missing latest L1 block; retrying");
                        continue;
                    }
                    Err(err) => {
                        counter!(DriverMetrics::EVENT_SCANNER_ERRORS_TOTAL).increment(1);
                        error!(?err, "failed to fetch latest L1 block");
                        continue;
                    }
                };
            let latest = latest_block.number();
            let latest_hash = latest_block.hash();

            if let (Some(last_number), Some(last_hash)) = (last_head_number, last_head_hash) {
                if latest == last_number && latest_hash != last_hash {
                    let rewind_to = latest.saturating_sub(RESUME_REORG_CUSHION_SLOTS);
                    warn!(
                        latest,
                        next_block,
                        rewind_to,
                        last_head_hash = ?last_hash,
                        latest_head_hash = ?latest_hash,
                        "L1 head hash changed; rewinding proposal scan"
                    );
                    if rewind_to < next_block {
                        next_block = rewind_to;
                    }
                }
                if latest == last_number.saturating_add(1) && 
                   latest_block.header.parent_hash != last_hash
                {
                    let rewind_to = latest.saturating_sub(RESUME_REORG_CUSHION_SLOTS);
                    warn!(
                        latest,
                        next_block,
                        rewind_to,
                        last_head_hash = ?last_hash,
                        parent_hash = ?latest_block.header.parent_hash,
                        "L1 head parent hash changed; rewinding proposal scan"
                    );
                    if rewind_to < next_block {
                        next_block = rewind_to;
                    }
                }
            }
            last_head_number = Some(latest);
            last_head_hash = Some(latest_hash);

            let latest_plus_one = latest.saturating_add(1);
            if latest_plus_one < next_block {
                let rewind_to = latest.saturating_sub(RESUME_REORG_CUSHION_SLOTS);
                warn!(latest, next_block, rewind_to, "L1 head regressed; rewinding proposal scan");
                next_block = rewind_to;
                continue;
            }
            if latest_plus_one == next_block {
                continue;
            }

            let mut from_block = next_block;
            while from_block <= latest {
                let to_block = from_block
                    .saturating_add(L1_LOG_POLL_MAX_BLOCK_RANGE.saturating_sub(1))
                    .min(latest);
                let filter = Filter::new()
                    .from_block(BlockNumberOrTag::Number(from_block))
                    .to_block(BlockNumberOrTag::Number(to_block))
                    .address(self.cfg.client.inbox_address)
                    .event(Proposed::SIGNATURE);

                let logs = match self.rpc.l1_provider.get_logs(&filter).await {
                    Ok(logs) => logs,
                    Err(err) => {
                        counter!(DriverMetrics::EVENT_SCANNER_ERRORS_TOTAL).increment(1);
                        error!(?err, from_block, to_block, "failed to fetch proposal logs from L1");
                        break;
                    }
                };

                counter!(DriverMetrics::EVENT_SCANNER_BATCHES_TOTAL).increment(1);
                counter!(DriverMetrics::EVENT_PROPOSALS_TOTAL).increment(logs.len() as u64);

                if !logs.is_empty() {
                    self.process_log_batch(router.clone(), logs).await?;
                }

                from_block = to_block.saturating_add(1);
                next_block = from_block;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;
    use alethia_reth_primitives::payload::attributes::{RpcL1Origin, TaikoBlockMetadata};
    use alloy::{
        primitives::{Address, B256, Bytes, U256},
        transports::http::reqwest::Url,
    };
    use alloy_provider::{ProviderBuilder, RootProvider};
    use alloy_rpc_types_engine::PayloadAttributes as EthPayloadAttributes;
    use alloy_transport::mock::Asserter;
    use bindings::{anchor::Anchor::AnchorInstance, inbox::Inbox::InboxInstance};
    use rpc::{
        SubscriptionSource,
        blob::BlobDataSource,
        client::{Client, ClientConfig, ShastaProtocolInstance},
    };

    fn sample_payload(block_number: u64) -> TaikoPayloadAttributes {
        let payload_attributes = EthPayloadAttributes {
            timestamp: 0,
            prev_randao: B256::ZERO,
            suggested_fee_recipient: Address::ZERO,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root: None,
        };
        let block_metadata = TaikoBlockMetadata {
            beneficiary: Address::ZERO,
            gas_limit: 0,
            timestamp: U256::ZERO,
            mix_hash: B256::ZERO,
            tx_list: Bytes::new(),
            extra_data: Bytes::new(),
        };
        let l1_origin = RpcL1Origin {
            block_id: U256::from(block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: None,
            l1_block_hash: None,
            build_payload_args_id: [0u8; 8],
            is_forced_inclusion: false,
            signature: [0u8; 65],
        };

        TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: U256::ZERO,
            block_metadata,
            l1_origin,
        }
    }

    fn mock_client() -> Client<RootProvider> {
        let l1_provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_mocked_client(Asserter::new());
        let l2_provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_mocked_client(Asserter::new());
        let l2_auth_provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_mocked_client(Asserter::new());
        let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
        let anchor = AnchorInstance::new(Address::ZERO, l2_auth_provider.clone());
        let shasta = ShastaProtocolInstance { inbox, anchor };

        Client { l1_provider, l2_provider, l2_auth_provider, shasta }
    }

    async fn build_syncer() -> EventSyncer<RootProvider> {
        let client_config = ClientConfig {
            l1_provider_source: SubscriptionSource::Http(
                Url::parse("http://localhost:8546").expect("valid http url"),
            ),
            l2_provider_url: Url::parse("http://localhost:8545").expect("valid http url"),
            l2_auth_provider_url: Url::parse("http://localhost:8551").expect("valid http url"),
            jwt_secret: PathBuf::from("/dev/null"),
            inbox_address: Address::ZERO,
        };
        let mut cfg = DriverConfig::new(
            client_config,
            Duration::from_secs(1),
            Url::parse("http://localhost:5052").expect("valid beacon url"),
            None,
            None,
        );
        cfg.preconfirmation_enabled = true;

        let (preconf_tx, preconf_rx) = mpsc::channel(PRECONF_CHANNEL_CAPACITY);
        let blob_source =
            BlobDataSource::new(None, None, true).await.expect("blob data source should build");

        EventSyncer {
            rpc: mock_client(),
            cfg,
            blob_source: Arc::new(blob_source),
            preconf_tx: Some(preconf_tx),
            preconf_rx: Some(Arc::new(AsyncMutex::new(preconf_rx))),
            last_canonical_proposal_id: Arc::new(AtomicU64::new(0)),
            preconf_ingress_ready: Arc::new(AtomicBool::new(false)),
            preconf_ingress_notify: Arc::new(Notify::new()),
        }
    }

    #[tokio::test]
    async fn preconf_submit_rejected_when_ingress_not_ready() {
        let syncer = build_syncer().await;
        let payload = PreconfPayload::new(sample_payload(1));
        let err = syncer
            .submit_preconfirmation_payload_with_timeout(payload, Duration::from_millis(10))
            .await
            .expect_err("expected ingress not ready error");

        assert!(matches!(err, DriverError::PreconfIngressNotReady));
    }

    #[test]
    fn preconfirmation_submit_timeout_defaults_to_12_seconds() {
        assert_eq!(
            PRECONFIRMATION_PAYLOAD_SUBMIT_TIMEOUT,
            Duration::from_secs(12),
            "preconfirmation submit timeout should default to 12 seconds"
        );
    }
}
