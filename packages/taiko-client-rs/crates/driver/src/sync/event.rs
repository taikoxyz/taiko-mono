//! Event sync logic.

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
    time::{Duration, Instant},
};

use alloy::{
    eips::{BlockId, BlockNumberOrTag, eip1898::RpcBlockHash},
    primitives::{Address, B256, U256},
    sol_types::SolEvent,
};
use alloy_consensus::{TxEnvelope, transaction::Transaction as _};
use alloy_provider::Provider;
use alloy_rpc_types::{Log, Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_sol_types::SolCall;
use anyhow::anyhow;
use bindings::{anchor::Anchor::anchorV4Call, inbox::Inbox::Proposed};
use event_scanner::{EventFilter, Notification, ScannerMessage};
use metrics::{counter, gauge, histogram};
use tokio::{
    spawn,
    sync::{Mutex as AsyncMutex, Notify, mpsc, oneshot, watch},
    time::timeout,
};
use tokio_retry::{Retry, strategy::ExponentialBackoff};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, warn};

use super::{
    AtomicCanonicalTip, CanonicalTipState, SyncError, SyncStage,
    checkpoint_resume_head::CheckpointResumeHead, is_stale_preconf,
};
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

use alloy_rpc_types_engine::PayloadId;
use rpc::{RpcClientError, blob::BlobDataSource, client::Client};

/// Default timeout for preconfirmation payload submission.
///
/// Covers both the enqueue operation and awaiting the processing response.
const PRECONFIRMATION_PAYLOAD_SUBMIT_TIMEOUT: Duration = Duration::from_secs(12);

/// Finalized L1 snapshot used to derive a fail-closed, non-reorgable resume target.
#[derive(Debug, Clone, Copy)]
struct FinalizedL1Snapshot {
    block_number: u64,
    block_hash: B256,
    finalized_safe_proposal_id: u64,
}

/// Bootstrap state produced while resolving the event scanner start point.
#[derive(Debug, Clone, Copy)]
struct EventStreamStartPoint {
    anchor_block_number: u64,
    initial_proposal_id: u64,
    bootstrap_canonical_tip: u64,
}

/// Decide whether the preconfirmation ingress loop can be started.
///
/// Strict safety gate:
/// - event scanner must be in live mode
/// - ingress must not have been spawned already
fn should_spawn_preconf_ingress(preconfirmation_enabled: bool, scanner_live: bool) -> bool {
    preconfirmation_enabled && scanner_live
}

/// Resolve the L2 block number that event sync should use as its resume source.
///
/// - Checkpoint mode: must use the checkpoint head that beacon sync actually caught up to.
/// - Non-checkpoint mode: must use local `head_l1_origin`.
///
/// Any missing source is treated as a hard error to avoid silently falling back to an unsafe
/// resume point such as `Latest`, which can include local preconfirmation-only blocks.
fn resolve_resume_head_block_number(
    checkpoint_configured: bool,
    checkpoint_synced_head: Option<u64>,
    head_l1_origin_block_id: Option<u64>,
) -> Result<u64, SyncError> {
    if checkpoint_configured {
        checkpoint_synced_head.ok_or(SyncError::MissingCheckpointResumeHead)
    } else {
        head_l1_origin_block_id.ok_or(SyncError::MissingHeadL1OriginResume)
    }
}

/// Return the smaller of the local resume proposal and finalized-safe proposal.
fn resolve_target_proposal_id(resume_proposal_id: u64, finalized_safe_proposal_id: u64) -> u64 {
    resume_proposal_id.min(finalized_safe_proposal_id)
}

/// Select scanner start block when the resolved target proposal id is zero.
///
/// - If finalized-safe proposal id is zero, scanner can safely start from finalized L1 block.
/// - Otherwise, keep genesis start to avoid skipping historical proposal events.
fn resolve_zero_target_start_block(
    finalized_safe_proposal_id: u64,
    finalized_block_number: u64,
) -> u64 {
    if finalized_safe_proposal_id == 0 { finalized_block_number } else { 0 }
}

/// Convert missing finalized block responses into an explicit fail-closed sync error.
fn require_finalized_block<T>(value: Option<T>) -> Result<T, SyncError> {
    value.ok_or(SyncError::MissingFinalizedL1Block)
}

/// Resolve canonical tip for empty-outcome proposals with strict fallback policy.
///
/// Priority:
/// 1) proposal batch-to-last-block mapping
/// 2) caller-provided latest execution head fallback
fn resolve_empty_outcome_canonical_tip(
    proposal_mapped_block_number: Option<u64>,
    latest_block_number: Option<u64>,
) -> Option<u64> {
    proposal_mapped_block_number.or(latest_block_number)
}

/// Update the canonical block tip boundary and notify watchers when it changes.
///
/// Returns true when the published tip changed. The canonical tip may move either forward or
/// backward across reorgs, so this always tracks the latest observed canonical value.
fn update_canonical_tip_state(
    canonical_tip_state: &AtomicCanonicalTip,
    canonical_tip_state_tx: &watch::Sender<CanonicalTipState>,
    canonical_block_number: u64,
) -> bool {
    let next = CanonicalTipState::Known(canonical_block_number);
    let previous = canonical_tip_state.swap(next, Ordering::Relaxed);
    let changed = next != previous;
    if changed {
        let has_receivers = canonical_tip_state_tx.receiver_count() > 0;
        canonical_tip_state_tx.send_replace(next);
        if !has_receivers {
            debug!(
                canonical_block_number,
                "canonical block tip changed with no active watchers; updated stored tip for late subscribers"
            );
        }
    }
    gauge!(DriverMetrics::EVENT_LAST_CANONICAL_BLOCK_NUMBER).set(canonical_block_number as f64);
    changed
}

/// Responsible for following inbox events and updating the L2 execution engine accordingly.
pub struct EventSyncer<P>
where
    P: Provider + Clone,
{
    /// RPC client shared with derivation pipeline.
    rpc: Client<P>,
    /// Static driver configuration.
    cfg: DriverConfig,
    /// Beacon-sync checkpoint head shared by the sync pipeline.
    checkpoint_resume_head: Arc<CheckpointResumeHead>,
    /// Shared blob data source used for manifest fetches.
    blob_source: Arc<BlobDataSource>,
    /// Optional preconfirmation ingress sender for external producers.
    preconf_tx: Option<PreconfSender>,
    /// Optional preconfirmation ingress receiver consumed by the sync loop.
    preconf_rx: Option<Arc<AsyncMutex<PreconfReceiver>>>,
    /// Tracks the latest canonical proposal id processed from L1 events.
    last_canonical_proposal_id: Arc<AtomicU64>,
    /// Sender for notifying watchers when the canonical proposal ID changes.
    proposal_id_tx: watch::Sender<u64>,
    /// Tracks the current canonical L2 tip state from L1 event sync.
    canonical_tip_state: Arc<AtomicCanonicalTip>,
    /// Sender for notifying watchers when the canonical tip state changes.
    canonical_tip_state_tx: watch::Sender<CanonicalTipState>,
    /// Indicates whether strict preconfirmation ingress gating has been satisfied and
    /// the ingress loop is ready to accept submissions.
    preconf_ingress_ready: Arc<AtomicBool>,
    /// Notifier signaled when strict ingress gating is satisfied and the loop becomes ready.
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
                Arc::new(PreconfirmationPath::new_with_canonical_tip_state(
                    self.rpc.clone(),
                    self.canonical_tip_state.clone(),
                ));
            paths.push(preconf_path);
        }

        Arc::new(AsyncMutex::new(ProductionRouter::new(paths)))
    }

    /// Spawn the preconfirmation ingress processing loop.
    fn spawn_preconf_ingress(
        &self,
        router: Arc<AsyncMutex<ProductionRouter>>,
        rx: Arc<AsyncMutex<PreconfReceiver>>,
        canonical_tip_state: Arc<AtomicCanonicalTip>,
        ready_flag: Arc<AtomicBool>,
        ready_notify: Arc<Notify>,
    ) {
        spawn(async move {
            // Start consuming externally supplied preconfirmation payloads after strict event-sync
            // gating has allowed ingress to start.
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
                let start = Instant::now();
                let block_number = job.payload.block_number();
                let router_guard = router.lock().await;
                // Re-check after acquiring router lock so event-sync updates cannot race this
                // preconfirmation submission.
                match canonical_tip_state.load(Ordering::Relaxed) {
                    CanonicalTipState::Unknown => {
                        warn!(
                            block_number,
                            "rejecting preconfirmation payload in ingress loop: canonical tip unknown"
                        );
                        let _ = job.respond_to.send(Err(DriverError::PreconfIngressNotReady));
                        gauge!(DriverMetrics::PRECONF_QUEUE_DEPTH).set(rx.len() as f64);
                        continue;
                    }
                    CanonicalTipState::Known(canonical_block_tip) => {
                        if is_stale_preconf(block_number, canonical_block_tip) {
                            counter!(DriverMetrics::PRECONF_STALE_DROPPED_TOTAL).increment(1);
                            counter!(DriverMetrics::PRECONF_STALE_DROPPED_INGRESS_TOTAL)
                                .increment(1);
                            warn!(
                                block_number,
                                canonical_block_tip,
                                "dropping stale preconfirmation payload in ingress loop"
                            );
                            let _ = job.respond_to.send(Ok(()));
                            gauge!(DriverMetrics::PRECONF_QUEUE_DEPTH).set(rx.len() as f64);
                            continue;
                        }
                    }
                }

                // Single-shot injection while holding router lock to avoid interleaving.
                let router_call = router_guard
                    .produce(ProductionInput::Preconfirmation(job.payload.clone()))
                    .await;

                let duration_secs = start.elapsed().as_secs_f64();
                histogram!(DriverMetrics::PRECONF_INJECTION_DURATION_SECONDS).record(duration_secs);

                match router_call {
                    Ok(_) => {
                        counter!(DriverMetrics::PRECONF_INJECTION_SUCCESS_TOTAL).increment(1);
                        info!(
                            block_number,
                            build_payload_args_id = %PayloadId::new(job.payload.payload().l1_origin.build_payload_args_id),
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
                            build_payload_args_id = %PayloadId::new(job.payload.payload().l1_origin.build_payload_args_id),
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
            let canonical_tip_state = self.canonical_tip_state.clone();
            let canonical_tip_state_tx = self.canonical_tip_state_tx.clone();
            let outcomes = Retry::spawn(retry_strategy, move || {
                let router = router.clone();
                let log = proposal_log.clone();
                let canonical_tip_state = canonical_tip_state.clone();
                let canonical_tip_state_tx = canonical_tip_state_tx.clone();
                async move {
                    // Lock router so L1 proposals and preconf inputs cannot interleave.
                    let router_guard = router.lock().await;
                    let outcomes = router_guard
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
                        })?;

                    // Publish the canonical block boundary while still holding the router lock so
                    // preconfirmation processing cannot observe stale boundaries.
                    if let Some(last_outcome) = outcomes.last() {
                        let canonical_block_number = last_outcome.block_number();
                        update_canonical_tip_state(
                            canonical_tip_state.as_ref(),
                            &canonical_tip_state_tx,
                            canonical_block_number,
                        );
                    }

                    Ok(outcomes)
                }
            })
            .await
            .map_err(|err| match err {
                DriverError::Sync(sync_err) => sync_err,
                DriverError::Rpc(rpc_err) => SyncError::Rpc(rpc_err),
                other => SyncError::Other(anyhow!(other)),
            })?;

            // Some proposals can be valid but derive no fresh execution blocks
            // (e.g. proposal already represented by canonical chain state). In that case,
            // initialize canonical tip from engine state so ingress does not remain stuck
            // in Unknown after event-sync has processed a real proposal.
            if outcomes.is_empty() {
                let canonical_tip_state = self.canonical_tip_state.load(Ordering::Relaxed);
                if let Some(canonical_block_number) = self
                    .resolve_canonical_tip_for_proposal(proposal_id, canonical_tip_state)
                    .await?
                {
                    update_canonical_tip_state(
                        self.canonical_tip_state.as_ref(),
                        &self.canonical_tip_state_tx,
                        canonical_block_number,
                    );
                }
            }

            info!(
                block_count = outcomes.len(),
                last_block = outcomes.last().map(|outcome| outcome.block_number()),
                last_hash = ?outcomes.last().map(|outcome| outcome.block_hash()),
                "successfully processed proposal into L2 blocks",
            );

            self.last_canonical_proposal_id.store(proposal_id, Ordering::Relaxed);
            let _ = self.proposal_id_tx.send(proposal_id);
            gauge!(DriverMetrics::EVENT_LAST_CANONICAL_PROPOSAL_ID).set(proposal_id as f64);
            counter!(DriverMetrics::EVENT_DERIVED_BLOCKS_TOTAL).increment(outcomes.len() as u64);
        }
        Ok(())
    }

    /// Resolve canonical tip from execution state when a processed proposal yields no outcomes.
    ///
    /// Priority:
    /// 1) batch-to-last-block mapping for the proposal id
    /// 2) latest execution head block number as fallback, only while canonical tip is unknown
    async fn resolve_canonical_tip_for_proposal(
        &self,
        proposal_id: u64,
        canonical_tip_state: CanonicalTipState,
    ) -> Result<Option<u64>, SyncError> {
        let proposal_mapped_block_number = self
            .rpc
            .last_block_id_by_batch_id(U256::from(proposal_id))
            .await?
            .map(|block_id| block_id.to::<u64>());

        let latest_block_number = match canonical_tip_state {
            CanonicalTipState::Unknown => {
                let latest_block = self
                    .rpc
                    .l2_provider
                    .get_block_by_number(BlockNumberOrTag::Latest)
                    .await
                    .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?;
                latest_block.map(|block| block.header.number)
            }
            CanonicalTipState::Known(canonical_block_tip) => {
                if proposal_mapped_block_number.is_none() {
                    debug!(
                        proposal_id,
                        canonical_block_tip,
                        "empty outcome proposal has no canonical batch mapping; keeping canonical tip unchanged"
                    );
                }
                None
            }
        };

        Ok(resolve_empty_outcome_canonical_tip(proposal_mapped_block_number, latest_block_number))
    }

    /// Construct a new event syncer from the provided configuration and RPC client.
    #[instrument(skip(cfg, rpc))]
    pub async fn new(cfg: &DriverConfig, rpc: Client<P>) -> Result<Self, SyncError> {
        Self::new_with_checkpoint_resume_head(cfg, rpc, Arc::new(CheckpointResumeHead::default()))
            .await
    }

    /// Construct a new event syncer with shared checkpoint resume-head state.
    #[instrument(skip(cfg, rpc, checkpoint_resume_head))]
    pub(crate) async fn new_with_checkpoint_resume_head(
        cfg: &DriverConfig,
        rpc: Client<P>,
        checkpoint_resume_head: Arc<CheckpointResumeHead>,
    ) -> Result<Self, SyncError> {
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
        let (proposal_id_tx, _proposal_id_rx) = watch::channel(0u64);
        let (canonical_tip_state_tx, _canonical_tip_state_rx) =
            watch::channel(CanonicalTipState::Unknown);
        gauge!(DriverMetrics::EVENT_LAST_CANONICAL_BLOCK_NUMBER).set(0.0);
        Ok(Self {
            rpc,
            cfg: cfg.clone(),
            checkpoint_resume_head,
            blob_source,
            preconf_tx,
            preconf_rx,
            last_canonical_proposal_id: Arc::new(AtomicU64::new(0)),
            proposal_id_tx,
            canonical_tip_state: Arc::new(AtomicCanonicalTip::new(CanonicalTipState::Unknown)),
            canonical_tip_state_tx,
            preconf_ingress_ready: Arc::new(AtomicBool::new(false)),
            preconf_ingress_notify: Arc::new(Notify::new()),
        })
    }

    /// Return the latest canonical proposal id processed from L1 events.
    pub fn last_canonical_proposal_id(&self) -> u64 {
        self.last_canonical_proposal_id.load(Ordering::Relaxed)
    }

    /// Subscribe to proposal ID changes.
    ///
    /// Returns a watch::Receiver that receives the latest canonical proposal ID
    /// whenever it changes. Useful for event-driven test waits.
    pub fn subscribe_proposal_id(&self) -> watch::Receiver<u64> {
        self.proposal_id_tx.subscribe()
    }

    /// Return the current canonical L2 tip state.
    pub fn canonical_tip_state(&self) -> CanonicalTipState {
        self.canonical_tip_state.load(Ordering::Relaxed)
    }

    /// Subscribe to canonical tip state changes.
    pub fn subscribe_canonical_tip_state(&self) -> watch::Receiver<CanonicalTipState> {
        self.canonical_tip_state_tx.subscribe()
    }

    /// Sender handle for feeding preconfirmation payloads into the router (if enabled).
    pub fn preconfirmation_sender(&self) -> Option<PreconfSender> {
        self.preconf_tx.clone()
    }

    /// Wait until strict preconfirmation ingress gating is satisfied and ingress accepts
    /// submissions.
    ///
    /// Readiness means:
    /// - event scanner has switched to live mode
    /// - canonical sync state has been initialized (from bootstrap or events)
    /// - ingress loop is running
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

        // Reject early if strict ingress gating is not satisfied yet.
        if !self.preconf_ingress_ready.load(Ordering::Acquire) {
            return Err(DriverError::PreconfIngressNotReady);
        }

        let block_number = payload.block_number();
        let canonical_block_tip = match self.canonical_tip_state() {
            CanonicalTipState::Unknown => {
                warn!(
                    block_number,
                    "rejecting preconfirmation payload before enqueue: canonical tip unknown"
                );
                return Err(DriverError::PreconfIngressNotReady);
            }
            CanonicalTipState::Known(canonical_block_tip) => canonical_block_tip,
        };
        if is_stale_preconf(block_number, canonical_block_tip) {
            counter!(DriverMetrics::PRECONF_STALE_DROPPED_TOTAL).increment(1);
            counter!(DriverMetrics::PRECONF_STALE_DROPPED_BEFORE_ENQUEUE_TOTAL).increment(1);
            warn!(
                block_number,
                canonical_block_tip, "dropping stale preconfirmation payload before enqueue"
            );
            return Ok(());
        }

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

    /// Resolve the L2 execution block used as event-sync resume source.
    ///
    /// Important safety behavior:
    /// - If checkpoint mode is enabled, we require the exact checkpoint head that beacon sync
    ///   finished at. This avoids trusting stale local origin pointers.
    /// - Without checkpoint mode, we require local `head_l1_origin` and fail fast when missing.
    ///   This avoids deriving proposal IDs from `Latest`, which may include local preconf-only
    ///   blocks that were never event-confirmed.
    #[instrument(skip(self), level = "debug")]
    async fn resume_head_block_number(&self) -> Result<u64, SyncError> {
        let checkpoint_configured = self.cfg.l2_checkpoint_url.is_some();

        let head_l1_origin_block_id = if checkpoint_configured {
            None
        } else {
            self.rpc.head_l1_origin().await?.map(|origin| origin.block_id.to::<u64>())
        };

        let resume_head_block_number = resolve_resume_head_block_number(
            checkpoint_configured,
            self.checkpoint_resume_head.get(),
            head_l1_origin_block_id,
        )?;

        if checkpoint_configured {
            info!(resume_head_block_number, "using checkpoint-synced head as event resume source");
        } else {
            info!(resume_head_block_number, "using local head_l1_origin as event resume source");
        }

        Ok(resume_head_block_number)
    }

    /// Resolve finalized L1 block metadata and finalized-safe proposal ID.
    #[instrument(skip(self), level = "debug")]
    async fn finalized_l1_snapshot(&self) -> Result<FinalizedL1Snapshot, SyncError> {
        let finalized_block = require_finalized_block(
            self.rpc
                .l1_provider
                .get_block_by_number(BlockNumberOrTag::Finalized)
                .await
                .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?,
        )?;

        let block_hash = finalized_block.header.hash;
        let block_number = finalized_block.header.number;
        let core_state = self
            .rpc
            .shasta
            .inbox
            .getCoreState()
            .block(BlockId::Hash(RpcBlockHash { block_hash, require_canonical: Some(false) }))
            .call()
            .await
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?;
        let finalized_safe_proposal_id = core_state.nextProposalId.to::<u64>().saturating_sub(1);

        Ok(FinalizedL1Snapshot { block_number, block_hash, finalized_safe_proposal_id })
    }

    /// Determine the L1 block height used to resume event consumption after beacon sync.
    #[instrument(skip(self), level = "debug")]
    async fn event_stream_start_block(&self) -> Result<EventStreamStartPoint, SyncError> {
        let resume_head_block_number = self.resume_head_block_number().await?;
        let finalized_snapshot = self.finalized_l1_snapshot().await?;
        let resume_head_block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(resume_head_block_number))
            .full()
            .await
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?
            .ok_or(SyncError::MissingExecutionBlock { number: resume_head_block_number })?
            .map_transactions(|tx: RpcTransaction| tx.into());

        let anchor_address = *self.rpc.shasta.anchor.address();
        let resume_proposal_id = decode_anchor_proposal_id(&resume_head_block)?;
        let target_proposal_id = resolve_target_proposal_id(
            resume_proposal_id,
            finalized_snapshot.finalized_safe_proposal_id,
        );
        info!(
            resume_proposal_id,
            finalized_safe_proposal_id = finalized_snapshot.finalized_safe_proposal_id,
            finalized_block_number = finalized_snapshot.block_number,
            finalized_block_hash = ?finalized_snapshot.block_hash,
            target_proposal_id,
            resume_hash = ?resume_head_block.hash(),
            resume_number = resume_head_block.number(),
            "selected finalized-bounded proposal id from resume-source anchor metadata",
        );
        if target_proposal_id == 0 {
            let start_block = resolve_zero_target_start_block(
                finalized_snapshot.finalized_safe_proposal_id,
                finalized_snapshot.block_number,
            );
            info!(
                start_block,
                target_proposal_id,
                finalized_safe_proposal_id = finalized_snapshot.finalized_safe_proposal_id,
                finalized_block_number = finalized_snapshot.block_number,
                "resolved zero-target scanner start block",
            );
            return Ok(EventStreamStartPoint {
                anchor_block_number: start_block,
                initial_proposal_id: 0,
                bootstrap_canonical_tip: 0,
            });
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
            target_hash = ?target_block.hash(),
            target_number = target_block.number(),
            target_proposal_id,
            "derived anchor block number from anchorV4 transaction",
        );
        Ok(EventStreamStartPoint {
            anchor_block_number,
            initial_proposal_id: target_proposal_id,
            bootstrap_canonical_tip: target_block_number.to::<u64>(),
        })
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
        let start_point = self.event_stream_start_block().await?;
        let anchor_block_number = start_point.anchor_block_number;
        let initial_proposal_id = start_point.initial_proposal_id;
        let start_tag = BlockNumberOrTag::Number(anchor_block_number);

        self.last_canonical_proposal_id.store(initial_proposal_id, Ordering::Relaxed);
        gauge!(DriverMetrics::EVENT_LAST_CANONICAL_PROPOSAL_ID).set(initial_proposal_id as f64);
        update_canonical_tip_state(
            self.canonical_tip_state.as_ref(),
            &self.canonical_tip_state_tx,
            start_point.bootstrap_canonical_tip,
        );
        info!(
            initial_proposal_id,
            bootstrap_canonical_tip = start_point.bootstrap_canonical_tip,
            "bootstrapped canonical sync state from finalized-bounded resume target",
        );

        info!(start_tag = ?start_tag, "starting shasta event processing from L1 block");

        let derivation_pipeline = ShastaDerivationPipeline::new(
            self.rpc.clone(),
            self.blob_source.clone(),
            U256::from(initial_proposal_id),
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

        let mut stream = scanner.subscribe(filter).stream(
            &scanner.start().await.map_err(|err| SyncError::EventScannerInit(err.to_string()))?,
        );

        info!("event scanner started; listening for inbox proposals");

        // Strict gate state for starting preconfirmation ingress.
        let mut preconf_rx = self.preconf_rx.clone();
        let mut scanner_live = false;

        while let Some(message) = stream.next().await {
            debug!(?message, "received inbox proposal message from event scanner");
            match message {
                Ok(ScannerMessage::Data(logs)) => {
                    counter!(DriverMetrics::EVENT_SCANNER_BATCHES_TOTAL).increment(1);
                    counter!(DriverMetrics::EVENT_PROPOSALS_TOTAL).increment(logs.len() as u64);
                    self.process_log_batch(router.clone(), logs).await?;
                }
                Ok(ScannerMessage::Notification(notification)) => {
                    info!(?notification, "event scanner notification");
                    if matches!(notification, Notification::SwitchingToLive) {
                        // Open ingress only after scanner switches to live mode.
                        scanner_live = true;
                    }
                }
                Err(err) => {
                    counter!(DriverMetrics::EVENT_SCANNER_ERRORS_TOTAL).increment(1);
                    error!(?err, "error receiving proposal logs from event scanner");
                    continue;
                }
            }

            if should_spawn_preconf_ingress(self.cfg.preconfirmation_enabled, scanner_live) &&
                let Some(rx) = preconf_rx.take()
            {
                self.spawn_preconf_ingress(
                    router.clone(),
                    rx,
                    self.canonical_tip_state.clone(),
                    self.preconf_ingress_ready.clone(),
                    self.preconf_ingress_notify.clone(),
                );
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;
    use alethia_reth_primitives::payload::attributes::{
        RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
    };
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
            tx_list: Some(Bytes::new()),
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
            anchor_transaction: None,
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
            l1_provider_source: SubscriptionSource::Ws(
                Url::parse("ws://localhost:8546").expect("valid ws url"),
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
        let (proposal_id_tx, _proposal_id_rx) = watch::channel(0u64);
        let (canonical_tip_state_tx, _canonical_tip_state_rx) =
            watch::channel(CanonicalTipState::Unknown);

        EventSyncer {
            rpc: mock_client(),
            cfg,
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
            blob_source: Arc::new(blob_source),
            preconf_tx: Some(preconf_tx),
            preconf_rx: Some(Arc::new(AsyncMutex::new(preconf_rx))),
            last_canonical_proposal_id: Arc::new(AtomicU64::new(0)),
            proposal_id_tx,
            canonical_tip_state: Arc::new(AtomicCanonicalTip::new(CanonicalTipState::Unknown)),
            canonical_tip_state_tx,
            preconf_ingress_ready: Arc::new(AtomicBool::new(false)),
            preconf_ingress_notify: Arc::new(Notify::new()),
        }
    }

    #[tokio::test]
    async fn preconf_submit_rejected_before_first_event_sync_gate() {
        let syncer = build_syncer().await;
        let payload = PreconfPayload::new(sample_payload(1));
        let err = syncer
            .submit_preconfirmation_payload_with_timeout(payload, Duration::from_millis(10))
            .await
            .expect_err("expected ingress not ready error");

        assert!(matches!(err, DriverError::PreconfIngressNotReady));
    }

    #[tokio::test]
    async fn preconf_submit_noops_when_block_is_at_or_below_canonical_tip() {
        let syncer = build_syncer().await;
        syncer.preconf_ingress_ready.store(true, Ordering::Release);
        syncer.canonical_tip_state.store(CanonicalTipState::Known(5), Ordering::Relaxed);

        let payload = PreconfPayload::new(sample_payload(5));
        syncer
            .submit_preconfirmation_payload_with_timeout(payload, Duration::from_millis(10))
            .await
            .expect("stale payload should be treated as no-op");

        let rx = syncer.preconf_rx.as_ref().expect("preconf receiver").clone();
        assert_eq!(rx.lock().await.len(), 0, "stale payload should not be enqueued for processing");
    }

    #[tokio::test]
    async fn preconf_submit_rejected_when_canonical_tip_is_unknown() {
        let syncer = build_syncer().await;
        syncer.preconf_ingress_ready.store(true, Ordering::Release);
        syncer.canonical_tip_state.store(CanonicalTipState::Unknown, Ordering::Relaxed);

        let payload = PreconfPayload::new(sample_payload(6));
        let err = syncer
            .submit_preconfirmation_payload_with_timeout(payload, Duration::from_millis(10))
            .await
            .expect_err("unknown canonical tip should reject preconfirmation payload");

        assert!(matches!(err, DriverError::PreconfIngressNotReady));

        let rx = syncer.preconf_rx.as_ref().expect("preconf receiver").clone();
        assert_eq!(
            rx.lock().await.len(),
            0,
            "payload should not be enqueued when canonical tip is unknown",
        );
    }

    #[tokio::test]
    async fn canonical_tip_state_reports_unknown_until_event_sync_sets_it() {
        let syncer = build_syncer().await;
        assert_eq!(syncer.canonical_tip_state(), CanonicalTipState::Unknown);

        syncer.canonical_tip_state.store(CanonicalTipState::Known(42), Ordering::Relaxed);
        assert_eq!(syncer.canonical_tip_state(), CanonicalTipState::Known(42));
    }

    #[test]
    fn canonical_tip_state_update_tracks_latest_value_even_when_decreasing() {
        let canonical_tip_state = AtomicCanonicalTip::new(CanonicalTipState::Known(100));
        let (canonical_tip_state_tx, canonical_tip_state_rx) =
            watch::channel(CanonicalTipState::Known(100));

        let changed = update_canonical_tip_state(&canonical_tip_state, &canonical_tip_state_tx, 95);

        assert!(changed, "decreasing canonical tip should notify watchers");
        assert_eq!(canonical_tip_state.load(Ordering::Relaxed), CanonicalTipState::Known(95));
        assert_eq!(*canonical_tip_state_rx.borrow(), CanonicalTipState::Known(95));
    }

    #[test]
    fn canonical_tip_state_update_refreshes_watch_value_without_active_watchers() {
        let canonical_tip_state = AtomicCanonicalTip::new(CanonicalTipState::Unknown);
        let (canonical_tip_state_tx, canonical_tip_state_rx) =
            watch::channel(CanonicalTipState::Unknown);
        drop(canonical_tip_state_rx);

        let changed = update_canonical_tip_state(&canonical_tip_state, &canonical_tip_state_tx, 95);

        assert!(changed, "updated canonical tip should be reported as changed");
        assert_eq!(canonical_tip_state.load(Ordering::Relaxed), CanonicalTipState::Known(95));

        let late_subscriber = canonical_tip_state_tx.subscribe();
        assert_eq!(
            *late_subscriber.borrow(),
            CanonicalTipState::Known(95),
            "late subscribers should observe the latest canonical tip",
        );
    }

    #[test]
    fn empty_outcome_known_tip_uses_proposal_mapping() {
        let resolved = resolve_empty_outcome_canonical_tip(Some(210), Some(300));
        assert_eq!(resolved, Some(210));
    }

    #[test]
    fn empty_outcome_known_tip_does_not_fallback_to_latest_without_mapping() {
        let resolved = resolve_empty_outcome_canonical_tip(None, None);
        assert_eq!(resolved, None);
    }

    #[test]
    fn empty_outcome_unknown_tip_allows_latest_fallback_without_mapping() {
        let resolved = resolve_empty_outcome_canonical_tip(None, Some(300));
        assert_eq!(resolved, Some(300));
    }

    #[test]
    fn preconf_ingress_spawn_requires_live_scanner() {
        assert!(
            should_spawn_preconf_ingress(true, true),
            "ingress gate should open once scanner is live",
        );
        assert!(
            should_spawn_preconf_ingress(true, true),
            "ingress gate should open once scanner is live",
        );
        assert!(
            !should_spawn_preconf_ingress(false, true),
            "disabled preconfirmation must never open ingress gate",
        );
        assert!(
            !should_spawn_preconf_ingress(true, false),
            "scanner must be live before ingress gate opens",
        );
    }

    #[test]
    fn resume_head_resolution_requires_checkpoint_state_in_checkpoint_mode() {
        let err = resolve_resume_head_block_number(true, None, Some(100))
            .expect_err("checkpoint mode should require checkpoint resume state");
        assert!(matches!(err, SyncError::MissingCheckpointResumeHead));

        let resolved = resolve_resume_head_block_number(true, Some(420), None)
            .expect("checkpoint resume head should be used when present");
        assert_eq!(resolved, 420);
    }

    #[test]
    fn resume_head_resolution_requires_head_l1_origin_without_checkpoint() {
        let err = resolve_resume_head_block_number(false, Some(999), None)
            .expect_err("non-checkpoint mode should require head_l1_origin");
        assert!(matches!(err, SyncError::MissingHeadL1OriginResume));

        let resolved = resolve_resume_head_block_number(false, None, Some(64))
            .expect("head_l1_origin should drive resume without checkpoint");
        assert_eq!(resolved, 64);
    }

    #[test]
    fn preconfirmation_submit_timeout_defaults_to_12_seconds() {
        assert_eq!(
            PRECONFIRMATION_PAYLOAD_SUBMIT_TIMEOUT,
            Duration::from_secs(12),
            "preconfirmation submit timeout should default to 12 seconds"
        );
    }

    #[test]
    fn target_proposal_id_is_bounded_by_finalized_safe_id_when_resume_is_ahead() {
        let target = resolve_target_proposal_id(120, 90);
        assert_eq!(target, 90);
    }

    #[test]
    fn target_proposal_id_keeps_resume_id_when_resume_is_behind_finalized_safe() {
        let target = resolve_target_proposal_id(90, 120);
        assert_eq!(target, 90);
    }

    #[test]
    fn zero_target_uses_finalized_block_when_finalized_safe_is_zero() {
        let start_block = resolve_zero_target_start_block(0, 4_096);
        assert_eq!(start_block, 4_096);
    }

    #[test]
    fn zero_target_uses_genesis_when_finalized_safe_exists() {
        let start_block = resolve_zero_target_start_block(17, 4_096);
        assert_eq!(start_block, 0);
    }

    #[test]
    fn missing_finalized_block_is_fail_closed() {
        let err = require_finalized_block::<u64>(None)
            .expect_err("missing finalized block must fail closed with explicit sync error");
        assert!(matches!(err, SyncError::MissingFinalizedL1Block));
    }
}
