//! Event sync logic.

use std::{
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

use alloy::{
    eips::{BlockId, BlockNumberOrTag, eip1898::RpcBlockHash},
    primitives::{Address, B256, U256},
    sol_types::SolEvent,
};
use alloy_consensus::TxEnvelope;
use alloy_provider::Provider;
use alloy_rpc_types::{Log, Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_sol_types::SolCall;
use anyhow::anyhow;
use bindings::{anchor::Anchor::anchorV4Call, inbox::Inbox::Proposed};
use event_scanner::{EventFilter, Notification, ScannerMessage};
use tokio::{
    spawn,
    sync::{Mutex as AsyncMutex, Notify, mpsc, oneshot},
    time::{sleep, timeout},
};
use tokio_retry::{RetryIf, strategy::ExponentialBackoff};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, warn};

use super::{
    FINALIZED_BLOCK_NOT_FOUND, SyncError, SyncStage,
    checkpoint_resume_head::CheckpointResumeHead,
    confirmed_sync::{ConfirmedSyncSnapshot, build_confirmed_sync_snapshot},
    error::EngineSubmissionError,
};
use crate::{
    config::DriverConfig,
    derivation::{DerivationError, ShastaDerivationPipeline},
    error::DriverError,
    metrics::DriverMetrics,
    production::{
        BlockProductionPath, CanonicalL1ProductionPath, PreconfPayload, PreconfSubmissionOutcome,
        PreconfirmationPath, ProductionInput, ProductionRouter, path::EngineBlockOutcome,
    },
};

use alloy_rpc_types_engine::PayloadId;
use rpc::{RpcClientError, blob::BlobDataSource, client::Client};

/// Result of processing a single proposal log inside `process_log_batch`.
enum ProposalLogResult {
    /// The proposal log derived successfully into one or more engine outcomes.
    Processed(Vec<EngineBlockOutcome>),
    /// The proposal log was proven orphaned by an L1 reorg and should be skipped.
    SkippedOrphaned,
}

/// Retry decision attached to a failed proposal-processing attempt.
///
/// The decision is made where the full context is available (error class plus the canonical
/// proof of the source log), so the retry predicate never has to re-derive it: only `Abort`
/// stops the retry loop.
enum ProposalRetryError {
    /// Deterministic failure on a proven-canonical log; retrying cannot change the outcome.
    Abort(DriverError),
    /// Transient or unproven failure; the attempt should be retried.
    Retry(DriverError),
}

impl ProposalRetryError {
    /// Unwrap the underlying driver error regardless of the retry decision.
    fn into_inner(self) -> DriverError {
        match self {
            ProposalRetryError::Abort(err) | ProposalRetryError::Retry(err) => err,
        }
    }
}

/// Default timeout for preconfirmation payload submission.
///
/// Covers both the enqueue operation and awaiting the processing response.
const PRECONFIRMATION_PAYLOAD_SUBMIT_TIMEOUT: Duration = Duration::from_secs(12);
/// Timeout for best-effort `head_l1_origin` reset after an event-scanner reorg.
const REORG_HEAD_L1_ORIGIN_RESET_TIMEOUT: Duration = Duration::from_secs(12);
/// Finalized L1 snapshot used to derive a fail-closed, non-reorgable resume target.
#[derive(Debug, Clone, Copy)]
struct FinalizedL1Snapshot {
    /// Finalized L1 block number.
    block_number: u64,
    /// Hash of the finalized L1 block.
    block_hash: B256,
    /// Proposal id considered finalized-safe at this snapshot.
    finalized_safe_proposal_id: u64,
}

/// Bootstrap state produced while resolving the event scanner start point.
#[derive(Debug, Clone, Copy)]
struct EventStreamStartPoint {
    /// L1 block number used as scanner start anchor.
    anchor_block_number: u64,
    /// Proposal id used to bootstrap derivation state.
    initial_proposal_id: u64,
    /// Confirmed L2 tip established before live scanning.
    bootstrap_confirmed_tip: u64,
}

/// Decide whether a confirmed-sync probe is still needed.
fn should_probe_confirmed_sync(
    preconfirmation_enabled: bool,
    preconf_ingress_spawned: bool,
    preconf_ingress_ready: bool,
    scanner_live: bool,
) -> bool {
    preconfirmation_enabled && scanner_live && (!preconf_ingress_spawned || !preconf_ingress_ready)
}

/// Resolve confirmed-sync probe readiness from a probe result.
///
/// Any probe error keeps ingress closed (fail-closed) until a later successful probe.
fn resolve_confirmed_sync_probe(
    confirmed_sync_probe: Result<ConfirmedSyncSnapshot, SyncError>,
) -> bool {
    match confirmed_sync_probe {
        Ok(snap) => snap.is_ready(),
        Err(_) => false,
    }
}

/// Resolve the L2 block number that event sync should use as its resume source, paired with a
/// static label naming the chosen source so the caller's log cannot diverge from the decision.
///
/// Any missing source is treated as a hard error to avoid silently falling back to an unsafe
/// resume point such as `Latest`, which can include local preconfirmation-only blocks.
fn resolve_resume_head_block_number(
    checkpoint_configured: bool,
    checkpoint_synced_head: Option<u64>,
    head_l1_origin_block_id: Option<u64>,
    rpc_l2_block_number: Option<u64>,
) -> Result<(u64, &'static str), SyncError> {
    if checkpoint_configured {
        return checkpoint_synced_head
            .map(|head| (head, "checkpoint-synced head"))
            .ok_or(SyncError::MissingCheckpointResumeHead);
    }
    match (head_l1_origin_block_id, rpc_l2_block_number) {
        (Some(origin), Some(rpc)) if rpc_head_is_safer_than_origin(rpc, origin) => {
            Ok((rpc, "lower rpc block number (instead of local head_l1_origin)"))
        }
        (Some(origin), _) => Ok((origin, "local head_l1_origin")),
        // Genesis fallback: no local origin yet and the RPC reports block 0, i.e. a brand-new
        // chain bootstrapped from genesis.
        (None, Some(0)) => Ok((0, "genesis fallback (head_l1_origin unavailable)")),
        (None, _) => Err(SyncError::MissingHeadL1OriginResume),
    }
}

/// A non-zero RPC head strictly behind the local origin pointer is a safer resume point (zero is
/// reserved for the genesis fallback path, and an equal/higher head offers no extra safety).
fn rpc_head_is_safer_than_origin(rpc_l2_block_number: u64, head_l1_origin_block_id: u64) -> bool {
    rpc_l2_block_number != 0 && rpc_l2_block_number < head_l1_origin_block_id
}

/// Resolve the target proposal id and finalized-safe proposal id, accounting for the
/// finalized snapshot being unavailable on fresh chains.
///
/// - When finalization is available, target is bounded by `min(resume, finalized_safe)`.
/// - When finalization is unavailable, both values reset to 0 so the caller can replay from the
///   inbox activation block. This is safe because derivation is idempotent (the engine skips
///   already-known blocks).
fn resolve_target_with_optional_finalization(
    resume_proposal_id: u64,
    finalized_safe_proposal_id: Option<u64>,
) -> (u64, u64) {
    match finalized_safe_proposal_id {
        Some(safe_id) => (resume_proposal_id.min(safe_id), safe_id),
        None => (0, 0),
    }
}

/// Fallback strategy when the execution engine has no batch mapping for the resume target.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum MissingBatchMappingFallback {
    /// Extract the scanner anchor from the resume head block itself.
    UseResumeHead,
    /// Restart derivation from proposal zero, scanning from the inbox activation block.
    ReplayFromActivation,
}

/// Decide how to bootstrap when no batch mapping exists for the target proposal.
///
/// Blocks reached via checkpoint/P2P sync bypass derivation, so the engine's custom tables hold
/// no rows for them and the lookup reports the match at head as uncertain. When the target is
/// the resume head's own proposal, the resume head block substitutes for the mapped target
/// block: it belongs to the target proposal, and every later proposal is included on L1 after
/// that proposal's anchor. This arm also covers the genesis bootstrap, where the zero target
/// resolves its anchor through the genesis block's activation fallback. When the finalized
/// bound rewound the target below the resume proposal, no local substitute exists and
/// derivation replays from the activation block instead — safe because derivation is
/// idempotent and no proposal events exist before activation.
fn resolve_missing_batch_mapping_fallback(
    target_proposal_id: u64,
    resume_proposal_id: u64,
) -> MissingBatchMappingFallback {
    if target_proposal_id == resume_proposal_id {
        MissingBatchMappingFallback::UseResumeHead
    } else {
        MissingBatchMappingFallback::ReplayFromActivation
    }
}

/// Resolve the reconnect start block after a scanner interruption.
///
/// - Rewind one block from the last seen height to cover partial delivery from the boundary block.
/// - If a finalized L1 block exists behind that overlap point, rewind all the way to finalized so
///   reconnect replays the entire reorg-unsafe window.
/// - If finalization is unavailable, fall back to the original startup anchor to avoid skipping
///   potentially replaced historical logs on fresh chains.
fn resolve_reconnect_start_block(
    last_seen_l1_block_number: u64,
    finalized_l1_block_number: Option<u64>,
    startup_anchor_block_number: u64,
) -> u64 {
    let overlap_start_block_number = last_seen_l1_block_number.saturating_sub(1);
    finalized_l1_block_number
        .map_or(startup_anchor_block_number, |finalized| overlap_start_block_number.min(finalized))
}

/// Return whether a preconfirmation target is at or below the confirmed tip.
#[inline]
fn is_stale_preconf(block_number: u64, confirmed_tip: u64) -> bool {
    block_number <= confirmed_tip
}

/// Return whether a proposal-processing failure is a deterministic engine verdict.
///
/// Only a newPayload `INVALID` qualifies: it is the engine's judgement on the payload content
/// itself, so resubmitting the identical payload cannot change the answer and retrying forever
/// would stall event sync silently. `ACCEPTED` is excluded because taiko-geth returns it while
/// the parent state is temporarily unavailable, and forkchoice `INVALID` is excluded because it
/// can reflect an unknown or unprocessable head rather than the payload content (the engine
/// layer keeps both away from `InvalidBlock`). RPC transport failures, engine syncing, and
/// missing data stay retryable.
fn is_fatal_proposal_processing_error(err: &DriverError) -> bool {
    matches!(
        err,
        DriverError::Sync(SyncError::Derivation(DerivationError::Engine(
            EngineSubmissionError::InvalidBlock(..)
        )))
    )
}

/// Responsible for following inbox events and updating the L2 execution engine accordingly.
pub struct EventSyncer {
    /// RPC client shared with derivation pipeline.
    rpc: Client,
    /// Static driver configuration.
    cfg: DriverConfig,
    /// Beacon-sync checkpoint head shared by the sync pipeline.
    checkpoint_resume_head: Arc<CheckpointResumeHead>,
    /// Shared blob data source used for manifest fetches.
    blob_source: Arc<BlobDataSource>,
    /// Optional preconfirmation ingress sender for external producers.
    preconf_tx: Option<PreconfSender>,
    /// Preconfirmation ingress receiver, moved exactly once into the ingress loop.
    preconf_rx: Mutex<Option<PreconfReceiver>>,
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
/// Sender side of the preconfirmation ingress queue.
type PreconfSender = mpsc::Sender<PreconfJob>;
/// Receiver side of the preconfirmation ingress queue.
type PreconfReceiver = mpsc::Receiver<PreconfJob>;

/// A preconfirmation payload submission job.
///
/// Wraps a payload and a oneshot channel for returning the processing result
/// back to the caller.
///
/// The channel indirection is deliberate and load-bearing: injections run inside the
/// ingress loop's own task, so a submitter whose future is dropped mid-await (for
/// example an axum handler cancelled by a client disconnect) cannot cancel an engine
/// injection already in flight. Do not replace this queue with direct router calls
/// from submitter tasks.
pub struct PreconfJob {
    /// The preconfirmation payload to be processed.
    payload: Arc<PreconfPayload>,
    /// Oneshot channel to send the processing result back to the caller.
    respond_to: oneshot::Sender<Result<PreconfSubmissionOutcome, DriverError>>,
}

/// Return the block hash of the local L2 block the provided preconfirmation payload already
/// materialized into, or `None` when it is not materialized.
///
/// Materialization requires both the per-block L1 origin record and the execution header to match
/// the payload attributes previously submitted to the engine. The returned hash is the one
/// observed by this check, so callers can bind their follow-up reads to the exact block that
/// satisfied the comparison rather than re-resolving by height.
async fn materialized_preconfirmation_block_hash(
    rpc: &Client,
    payload: &PreconfPayload,
) -> Result<Option<B256>, DriverError> {
    let block_number = payload.block_number();
    let expected_payload = payload.payload();
    let Some(origin) = rpc.l1_origin_by_id(U256::from(block_number)).await? else {
        return Ok(None);
    };
    // Treat a zero build-payload id as an uninitialized origin record so we fail closed and
    // re-submit rather than falsely acknowledging a materialized payload.
    if origin.build_payload_args_id == [0u8; 8] ||
        origin.build_payload_args_id != expected_payload.l1_origin.build_payload_args_id
    {
        return Ok(None);
    }

    let Some(block) = rpc
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Number(block_number))
        .await
        .map_err(|err| DriverError::Rpc(RpcClientError::Provider(err.to_string())))?
    else {
        return Ok(None);
    };
    let header = &block.header;

    if header.parent_hash != payload.expected_parent_hash() {
        return Ok(None);
    }
    if origin.l2_block_hash != B256::ZERO && header.hash != origin.l2_block_hash {
        return Ok(None);
    }
    if header.number != block_number {
        return Ok(None);
    }
    if header.beneficiary != expected_payload.payload_attributes.suggested_fee_recipient {
        return Ok(None);
    }
    if header.mix_hash != expected_payload.payload_attributes.prev_randao {
        return Ok(None);
    }
    if header.gas_limit != expected_payload.block_metadata.gas_limit {
        return Ok(None);
    }
    if header.timestamp != expected_payload.payload_attributes.timestamp {
        return Ok(None);
    }
    if header.extra_data != expected_payload.block_metadata.extra_data {
        return Ok(None);
    }

    let matches_base_fee = matches!(
        header.base_fee_per_gas,
        Some(base_fee) if U256::from(base_fee) == expected_payload.base_fee_per_gas
    );
    Ok(matches_base_fee.then_some(header.hash))
}

impl EventSyncer {
    /// Build the production router with the enabled paths.
    fn build_router(
        &self,
        derivation: Arc<ShastaDerivationPipeline>,
    ) -> Arc<AsyncMutex<ProductionRouter>> {
        let canonical_path: Arc<dyn BlockProductionPath + Send + Sync> = Arc::new(
            CanonicalL1ProductionPath::new(derivation.clone(), Arc::new(self.rpc.clone())),
        );

        // The preconfirmation path is only registered when preconfirmation is enabled.
        let preconf_path = self.cfg.preconfirmation_enabled.then(|| {
            Arc::new(PreconfirmationPath::new(self.rpc.clone()))
                as Arc<dyn BlockProductionPath + Send + Sync>
        });

        Arc::new(AsyncMutex::new(ProductionRouter::new(canonical_path, preconf_path)))
    }

    /// Spawn the preconfirmation ingress processing loop.
    fn spawn_preconf_ingress(
        &self,
        router: Arc<AsyncMutex<ProductionRouter>>,
        mut rx: PreconfReceiver,
        rpc: Client,
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
            // Signal that the ingress loop is ready to accept submissions.
            ready_flag.store(true, Ordering::Release);
            ready_notify.notify_waiters();
            while let Some(job) = rx.recv().await {
                // Track current backlog before processing this job.
                DriverMetrics::preconf_queue_depth().set(rx.len() as f64);
                let start = Instant::now();
                let block_number = job.payload.block_number();
                let router_guard = router.lock().await;
                // All checks below run while holding the router lock so event-sync updates and
                // sibling injections cannot race this preconfirmation submission.
                // On genesis chains head_l1_origin is not yet written; default to 0 so
                // the staleness check passes for any block_number >= 1.  This matches the
                // Go driver's `checkMessageBlockNumber` which skips the check when nil.
                let head_l1_origin_block_id = match rpc.head_l1_origin().await {
                    Ok(Some(origin)) => origin.block_id.to::<u64>(),
                    Ok(None) => 0,
                    Err(err) => {
                        error!(?err, block_number, "failed to read head_l1_origin in ingress loop");
                        let _ = job.respond_to.send(Err(DriverError::Rpc(err)));
                        DriverMetrics::preconf_queue_depth().set(rx.len() as f64);
                        continue;
                    }
                };
                if is_stale_preconf(block_number, head_l1_origin_block_id) {
                    DriverMetrics::preconf_stale_dropped_total().inc();
                    DriverMetrics::preconf_stale_dropped_ingress_total().inc();
                    warn!(
                        block_number,
                        head_l1_origin_block_id,
                        "dropping stale preconfirmation payload in ingress loop"
                    );
                    let _ = job.respond_to.send(Ok(PreconfSubmissionOutcome::Stale));
                    DriverMetrics::preconf_queue_depth().set(rx.len() as f64);
                    continue;
                }
                // Decide materialization inside the serialized section and bind the outcome to
                // the exact observed block hash: once the lock is released a same-height sibling
                // can become canonical, so callers must never re-resolve the block by height.
                match materialized_preconfirmation_block_hash(&rpc, job.payload.as_ref()).await {
                    Ok(Some(block_hash)) => {
                        debug!(
                            block_number,
                            build_payload_args_id = %PayloadId::new(job.payload.payload().l1_origin.build_payload_args_id),
                            %block_hash,
                            "preconfirmation payload is already materialized"
                        );
                        let _ = job
                            .respond_to
                            .send(Ok(PreconfSubmissionOutcome::AlreadyMaterialized { block_hash }));
                        DriverMetrics::preconf_queue_depth().set(rx.len() as f64);
                        continue;
                    }
                    Ok(None) => {}
                    Err(err) => {
                        error!(
                            ?err,
                            block_number, "failed to check preconfirmation materialization state"
                        );
                        let _ = job.respond_to.send(Err(err));
                        DriverMetrics::preconf_queue_depth().set(rx.len() as f64);
                        continue;
                    }
                }

                // Single-shot injection while holding router lock to avoid interleaving.
                let router_call = router_guard
                    .produce(ProductionInput::Preconfirmation(job.payload.clone()))
                    .await;

                let duration_secs = start.elapsed().as_secs_f64();
                DriverMetrics::preconf_injection_duration_seconds().observe(duration_secs);

                match router_call {
                    Ok(outcomes) => match outcomes.last() {
                        Some(outcome) => {
                            DriverMetrics::preconf_injection_success_total().inc();
                            let block_hash = outcome.block.header.hash;
                            info!(
                                block_number,
                                build_payload_args_id = %PayloadId::new(job.payload.payload().l1_origin.build_payload_args_id),
                                %block_hash,
                                duration_secs,
                                "preconfirmation payload injected"
                            );
                            // Return the produced block identity to the original sender.
                            let _ = job
                                .respond_to
                                .send(Ok(PreconfSubmissionOutcome::Inserted { block_hash }));
                        }
                        // The preconfirmation path always yields exactly one outcome; treat an
                        // empty result as a missing block rather than fabricating an identity.
                        None => {
                            DriverMetrics::preconf_injection_failures_total().inc();
                            error!(
                                block_number,
                                duration_secs, "preconfirmation injection returned no block"
                            );
                            let _ =
                                job.respond_to.send(Err(DriverError::BlockNotFound(block_number)));
                        }
                    },
                    Err(err) => {
                        DriverMetrics::preconf_injection_failures_total().inc();
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
                DriverMetrics::preconf_queue_depth().set(rx.len() as f64);
            }
        });
    }

    /// Return whether a failed proposal log is permanently orphaned because its source L1 block
    /// no longer exists on the provider.
    #[instrument(skip(self), level = "debug")]
    async fn is_permanently_orphaned_proposal_log(
        &self,
        block_hash: B256,
        log_block_number: Option<u64>,
    ) -> Result<bool, SyncError> {
        let block = self
            .rpc
            .l1_provider
            .get_block_by_hash(block_hash)
            .await
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?;

        // If the block is still resolvable, the failure came from downstream processing, not a
        // reorg that removed the source log.
        if block.is_some() {
            return Ok(false);
        }

        let Some(log_block_number) = log_block_number else {
            // We already proved the block hash is gone, and without a block number there is no
            // head-height guard we can apply before classifying it as orphaned.
            return Ok(true);
        };

        // A transiently lagging provider can return `None` for a block that has not yet reached
        // the provider's visible head. Only classify the log as orphaned once the head has caught
        // up to or passed the log's block number.
        let chain_head = self
            .rpc
            .l1_provider
            .get_block_number()
            .await
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?;

        Ok(chain_head >= log_block_number)
    }

    /// Prove that a proposal log's source block is canonical on L1.
    ///
    /// The proof compares the canonical block hash at the log's height against the log's block
    /// hash. It deliberately avoids by-hash lookups, whose semantics diverge between node
    /// families (geth keeps serving reorged-out blocks by hash while reth does not); the
    /// by-number canonical view is the one both answer identically. Missing data — no log
    /// height, or no canonical block at that height yet — leaves the proof unestablished.
    #[instrument(skip(self), level = "debug")]
    async fn is_proposal_log_proven_canonical(
        &self,
        block_hash: B256,
        log_block_number: Option<u64>,
    ) -> Result<bool, SyncError> {
        let Some(log_block_number) = log_block_number else {
            return Ok(false);
        };

        let canonical_block = self
            .rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Number(log_block_number))
            .await
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?;

        Ok(canonical_block.is_some_and(|block| block.header.hash == block_hash))
    }

    /// Decide whether a failed attempt on a non-orphaned proposal log aborts or keeps retrying.
    ///
    /// Aborting requires both a deterministic engine verdict on the payload content and an
    /// explicit canonical proof of the source log. The orphan recheck alone cannot stand in for
    /// the proof: geth-like L1 nodes keep serving reorged-out blocks by hash, so a stale log can
    /// pass the recheck while no longer being canonical. Unproven canonicality and proof
    /// failures keep the attempt retryable.
    async fn classify_proposal_processing_failure(
        &self,
        err: DriverError,
        log: &Log,
        block_hash: B256,
    ) -> ProposalRetryError {
        if !is_fatal_proposal_processing_error(&err) {
            warn!(
                ?err,
                tx_hash = ?log.transaction_hash,
                block_number = log.block_number,
                "proposal derivation failed; retrying"
            );
            return ProposalRetryError::Retry(err);
        }

        match self.is_proposal_log_proven_canonical(block_hash, log.block_number).await {
            Ok(true) => {
                error!(
                    ?err,
                    tx_hash = ?log.transaction_hash,
                    block_number = log.block_number,
                    "proposal derivation hit a deterministic engine verdict on a \
                     proven-canonical log; aborting"
                );
                ProposalRetryError::Abort(err)
            }
            Ok(false) => {
                warn!(
                    ?err,
                    tx_hash = ?log.transaction_hash,
                    block_number = log.block_number,
                    "deterministic engine verdict but source log is not proven canonical; \
                     retrying"
                );
                ProposalRetryError::Retry(err)
            }
            Err(proof_err) => {
                warn!(
                    ?err,
                    ?proof_err,
                    tx_hash = ?log.transaction_hash,
                    block_number = log.block_number,
                    "deterministic engine verdict but the canonical proof errored; retrying"
                );
                ProposalRetryError::Retry(err)
            }
        }
    }

    /// Best-effort reset of `head_l1_origin` to the latest canonical proposal's last L2 block at
    /// the stable post-reorg boundary. If the L2 EE's confirmed boundary is left ahead of the
    /// post-reorg canonical chain, preconf and chain-syncer guards reject incoming blocks until
    /// the chain syncer rewinds. Lowering it here unblocks them immediately. All failures are
    /// non-fatal: log and return.
    async fn reset_head_l1_origin_after_reorg(&self, common_ancestor: u64) {
        let core_state = match self
            .rpc
            .shasta
            .inbox
            .getCoreState()
            .block(BlockId::Number(BlockNumberOrTag::Number(common_ancestor)))
            .call()
            .await
        {
            Ok(core_state) => core_state,
            Err(err) => {
                warn!(common_ancestor, %err, "failed to read core state for head_l1_origin reset");
                return;
            }
        };

        let next_proposal_id = core_state.nextProposalId.to::<u64>();
        if next_proposal_id <= 1 {
            info!(
                common_ancestor,
                next_proposal_id, "skipping head_l1_origin reset at genesis boundary"
            );
            return;
        }
        let proposal_id = next_proposal_id - 1;

        let block_id =
            match self.rpc.last_certain_block_id_by_batch_id(U256::from(proposal_id)).await {
                Ok(Some(block_id)) => block_id,
                Ok(None) => {
                    warn!(
                        common_ancestor,
                        proposal_id, "missing batch mapping; skipping head_l1_origin reset"
                    );
                    return;
                }
                Err(err) => {
                    warn!(
                        common_ancestor,
                        proposal_id,
                        ?err,
                        "failed to read batch mapping; skipping head_l1_origin reset"
                    );
                    return;
                }
            };

        match self.rpc.set_head_l1_origin(block_id).await {
            Ok(_) => info!(
                common_ancestor,
                proposal_id,
                %block_id,
                "reset head_l1_origin after reorg"
            ),
            Err(err) => warn!(
                common_ancestor,
                proposal_id,
                %block_id,
                ?err,
                "failed to reset head_l1_origin after reorg"
            ),
        }
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

            let Some(block_hash) = log.block_hash else {
                error!(
                    ?log.transaction_hash,
                    block_number = log.block_number,
                    "proposal log missing block hash"
                );
                return Err(SyncError::MissingProposalLogBlockHash {
                    tx_hash: log.transaction_hash,
                    block_number: log.block_number,
                });
            };

            // Retry proposal processing on transient errors; a deterministic engine verdict
            // aborts only once the source log is proven canonical on L1.
            let retry_strategy =
                ExponentialBackoff::from_millis(10).max_delay(Duration::from_secs(12));

            let syncer = self;
            let router = router.clone();
            let proposal_log = log.clone();
            let processing = RetryIf::spawn(
                retry_strategy,
                move || {
                    let router = router.clone();
                    let log = proposal_log.clone();
                    async move {
                        let router_call = {
                            // Lock router so L1 proposals and preconf inputs cannot interleave.
                            let router_guard = router.lock().await;
                            router_guard.produce(ProductionInput::L1ProposalLog(log.clone())).await
                        };

                        match router_call {
                            Ok(outcomes) => Ok(ProposalLogResult::Processed(outcomes)),
                            Err(err) => match syncer
                                .is_permanently_orphaned_proposal_log(block_hash, log.block_number)
                                .await
                            {
                                Ok(true) => {
                                    DriverMetrics::event_orphaned_proposal_logs_total().inc();
                                    warn!(
                                        ?err,
                                        block_number = log.block_number,
                                        block_hash = ?block_hash,
                                        transaction_hash = ?log.transaction_hash,
                                        "skipping permanently orphaned proposal log",
                                    );
                                    Ok(ProposalLogResult::SkippedOrphaned)
                                }
                                Ok(false) => Err(syncer
                                    .classify_proposal_processing_failure(err, &log, block_hash)
                                    .await),
                                Err(recheck_err) => {
                                    warn!(
                                        ?err,
                                        ?recheck_err,
                                        tx_hash = ?log.transaction_hash,
                                        block_number = log.block_number,
                                        "proposal derivation failed and orphaned-log recheck errored; retrying"
                                    );
                                    // Surface the retryable recheck error instead of the
                                    // original failure: a fatal verdict may only abort after
                                    // the log is proven canonical, never while orphanhood is
                                    // still unresolved.
                                    Err(ProposalRetryError::Retry(DriverError::Sync(recheck_err)))
                                }
                            },
                        }
                    }
                },
                |err: &ProposalRetryError| matches!(err, ProposalRetryError::Retry(_)),
            )
            .await
            .map_err(ProposalRetryError::into_inner)
            .map_err(|err| match err {
                DriverError::Sync(sync_err) => sync_err,
                DriverError::Rpc(rpc_err) => SyncError::Rpc(rpc_err),
                other => SyncError::Other(anyhow!(other)),
            })?;

            let ProposalLogResult::Processed(outcomes) = processing else {
                continue;
            };

            if let Some(last_outcome) = outcomes.last() {
                DriverMetrics::event_last_canonical_block_number()
                    .set(last_outcome.block_number() as f64);
            }

            info!(
                block_count = outcomes.len(),
                last_block = outcomes.last().map(|outcome| outcome.block_number()),
                last_hash = ?outcomes.last().map(|outcome| outcome.block_hash()),
                "successfully processed proposal into L2 blocks",
            );

            DriverMetrics::event_last_canonical_proposal_id().set(proposal_id as f64);
            DriverMetrics::event_derived_blocks_total().inc_by(outcomes.len() as u64);
        }
        Ok(())
    }

    /// Construct a new event syncer from the provided configuration and RPC client.
    #[instrument(skip(cfg, rpc))]
    pub async fn new(cfg: &DriverConfig, rpc: Client) -> Result<Self, SyncError> {
        Self::new_with_checkpoint_resume_head(cfg, rpc, Arc::new(CheckpointResumeHead::default()))
            .await
    }

    /// Construct a new event syncer with shared checkpoint resume-head state.
    #[instrument(skip(cfg, rpc, checkpoint_resume_head))]
    pub(crate) async fn new_with_checkpoint_resume_head(
        cfg: &DriverConfig,
        rpc: Client,
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
            (Some(tx), Some(rx))
        } else {
            (None, None)
        };
        DriverMetrics::event_last_canonical_block_number().set(0.0);
        Ok(Self {
            rpc,
            cfg: cfg.clone(),
            checkpoint_resume_head,
            blob_source,
            preconf_tx,
            preconf_rx: Mutex::new(preconf_rx),
            preconf_ingress_ready: Arc::new(AtomicBool::new(false)),
            preconf_ingress_notify: Arc::new(Notify::new()),
        })
    }

    /// Return strict confirmed-sync state from on-chain core state and custom execution tables.
    ///
    /// Readiness is strict and fail-closed:
    /// - target id is `nextProposalId.saturating_sub(1)`
    /// - `target == 0` is ready
    /// - otherwise readiness requires both:
    ///   - `last_block_id_by_batch_id(target)` exists
    ///   - `head_l1_origin` exists and `head >= target_block`
    pub async fn confirmed_sync_snapshot(&self) -> Result<ConfirmedSyncSnapshot, SyncError> {
        let core_state = self
            .rpc
            .shasta
            .inbox
            .getCoreState()
            .call()
            .await
            .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?;
        let target_proposal_id = core_state.nextProposalId.to::<u64>().saturating_sub(1);
        build_confirmed_sync_snapshot(
            target_proposal_id,
            |target| async move {
                Ok(self
                    .rpc
                    .last_block_id_by_batch_id(U256::from(target))
                    .await?
                    .map(|block_id| block_id.to::<u64>()))
            },
            || async {
                Ok(self.rpc.head_l1_origin().await?.map(|origin| origin.block_id.to::<u64>()))
            },
        )
        .await
    }

    /// Wait until strict preconfirmation ingress gating is satisfied and ingress accepts
    /// submissions.
    ///
    /// Readiness means:
    /// - event scanner has switched to live mode
    /// - confirmed-sync readiness check has passed against core state and custom tables
    /// - ingress loop is running
    pub async fn wait_preconf_ingress_ready(&self) -> Result<(), DriverError> {
        self.preconf_tx.as_ref().ok_or(DriverError::PreconfirmationDisabled)?;
        loop {
            let notified = self.preconf_ingress_notify.notified();
            if self.preconf_ingress_ready.load(Ordering::Acquire) {
                return Ok(());
            }
            notified.await;
        }
    }

    /// Returns whether preconfirmation ingress is currently ready.
    ///
    /// This mirrors the internal readiness signal used by the strict ingress gate.
    pub fn is_preconf_ingress_ready(&self) -> bool {
        self.preconf_ingress_ready.load(Ordering::Acquire)
    }

    /// Submit a preconfirmation payload and await the processing result.
    pub async fn submit_preconfirmation_payload(
        &self,
        payload: PreconfPayload,
    ) -> Result<PreconfSubmissionOutcome, DriverError> {
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
    ) -> Result<PreconfSubmissionOutcome, DriverError> {
        let tx = self.preconf_tx.as_ref().ok_or(DriverError::PreconfirmationDisabled)?;

        // Reject early if strict ingress gating is not satisfied yet.
        if !self.preconf_ingress_ready.load(Ordering::Acquire) {
            return Err(DriverError::PreconfIngressNotReady);
        }

        // Best-effort duplicate fast path outside the serialized loop: the returned outcome
        // carries the exact hash this check observed, so it stays self-consistent even if a
        // sibling becomes canonical afterwards.
        let materialized_block_hash =
            materialized_preconfirmation_block_hash(&self.rpc, &payload).await?;
        if let Some(block_hash) = materialized_block_hash {
            debug!(
                block_number = payload.block_number(),
                build_payload_args_id = %PayloadId::new(payload.payload().l1_origin.build_payload_args_id),
                %block_hash,
                "preconfirmation payload is already materialized"
            );
        }

        let block_number = payload.block_number();
        // On genesis chains head_l1_origin is not yet written; default to 0 so
        // the staleness check passes for any block_number >= 1.
        let head_l1_origin_block_id = match self.rpc.head_l1_origin().await? {
            Some(origin) => origin.block_id.to::<u64>(),
            None => 0,
        };
        if is_stale_preconf(block_number, head_l1_origin_block_id) {
            DriverMetrics::preconf_stale_dropped_total().inc();
            DriverMetrics::preconf_stale_dropped_before_enqueue_total().inc();
            warn!(
                block_number,
                head_l1_origin_block_id, "dropping stale preconfirmation payload before enqueue"
            );
            return Ok(PreconfSubmissionOutcome::Stale);
        }
        if let Some(block_hash) = materialized_block_hash {
            return Ok(PreconfSubmissionOutcome::AlreadyMaterialized { block_hash });
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
                DriverMetrics::preconf_enqueue_timeouts_total().inc();
                error!(
                    block_number,
                    timeout_ms = timeout_duration.as_millis() as u64,
                    "preconfirmation enqueue timed out"
                );
                return Err(DriverError::PreconfEnqueueTimeout { waited: timeout_duration });
            }
            Ok(Err(err)) => {
                DriverMetrics::preconf_enqueue_failures_total().inc();
                error!(block_number, ?err, "preconfirmation enqueue failed");
                return Err(DriverError::PreconfEnqueueFailed(err.to_string()));
            }
            Ok(Ok(())) => {
                debug!(block_number, "preconfirmation payload enqueued successfully");
            }
        }

        // Await the processing result with timeout.
        let response_result = timeout(timeout_duration, resp_rx).await;

        let outcome = match response_result {
            Err(_) => {
                DriverMetrics::preconf_response_timeouts_total().inc();
                error!(
                    block_number,
                    timeout_ms = timeout_duration.as_millis() as u64,
                    "preconfirmation response timed out"
                );
                return Err(DriverError::PreconfResponseTimeout { waited: timeout_duration });
            }
            Ok(Err(err)) => {
                DriverMetrics::preconf_response_dropped_total().inc();
                error!(block_number, ?err, "preconfirmation response channel closed");
                return Err(DriverError::PreconfResponseDropped { recv_error: err });
            }
            Ok(Ok(inner_result)) => {
                if let Err(ref err) = inner_result {
                    warn!(block_number, ?err, "preconfirmation processing returned error");
                }
                inner_result?
            }
        };

        debug!(block_number, ?outcome, "preconfirmation payload processed successfully");
        Ok(outcome)
    }

    /// Resolve the L2 execution block used as event-sync resume source.
    ///
    /// Important safety behavior:
    /// - If checkpoint mode is enabled, we require the exact checkpoint head that beacon sync
    ///   finished at. This avoids trusting stale local origin pointers.
    /// - Without checkpoint mode, we prefer local `head_l1_origin`. If missing on fresh genesis
    ///   chains (where local head is block 0), we fallback to resume from block 0. Otherwise we
    ///   fail fast instead of deriving proposal IDs from `Latest`, which may include local
    ///   preconfirmation-only blocks that were never event-confirmed.
    #[instrument(skip(self), level = "debug")]
    async fn resume_head_block_number(&self) -> Result<u64, SyncError> {
        let checkpoint_configured = self.cfg.l2_checkpoint_url.is_some();
        let (head_l1_origin_block_id, rpc_l2_block_number) = if checkpoint_configured {
            (None, None)
        } else {
            let head_l1_origin_block_id =
                self.rpc.head_l1_origin().await?.map(|origin| origin.block_id.to::<u64>());
            // Tolerate transient eth_blockNumber failures when we already have a safe
            // head_l1_origin to resume from; otherwise the error must propagate because we need
            // the RPC head to distinguish genesis fallback from a missing resume source.
            let rpc_l2_block_number = match self.rpc.l2_provider.get_block_number().await {
                Ok(block_number) => Some(block_number),
                Err(err) if head_l1_origin_block_id.is_some() => {
                    warn!(
                        head_l1_origin_block_id,
                        %err,
                        "failed to fetch rpc L2 block number; falling back to local head_l1_origin",
                    );
                    None
                }
                Err(err) => return Err(SyncError::Rpc(RpcClientError::Provider(err.to_string()))),
            };
            (head_l1_origin_block_id, rpc_l2_block_number)
        };

        let (resume_head_block_number, source) = resolve_resume_head_block_number(
            checkpoint_configured,
            self.checkpoint_resume_head.get(),
            head_l1_origin_block_id,
            rpc_l2_block_number,
        )?;

        info!(
            resume_head_block_number,
            head_l1_origin_block_id, rpc_l2_block_number, source, "resolved event resume source",
        );

        Ok(resume_head_block_number)
    }

    /// Try to resolve finalized L1 block metadata and finalized-safe proposal ID.
    ///
    /// Returns `None` when the L1 chain has not yet finalized (e.g. fresh devnets).
    #[instrument(skip(self), level = "debug")]
    async fn try_finalized_l1_snapshot(&self) -> Result<Option<FinalizedL1Snapshot>, SyncError> {
        let finalized_block =
            match self.rpc.l1_provider.get_block_by_number(BlockNumberOrTag::Finalized).await {
                Ok(block) => block,
                // Geth returns JSON-RPC error -32000 "finalized block not found" on fresh
                // devnets before the beacon chain has finalized its first block. Treat this
                // specific error as "not yet available" rather than a fatal failure.
                Err(err) if err.to_string().contains(FINALIZED_BLOCK_NOT_FOUND) => return Ok(None),
                Err(err) => return Err(SyncError::Rpc(RpcClientError::Provider(err.to_string()))),
            };

        let Some(finalized_block) = finalized_block else {
            return Ok(None);
        };

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

        Ok(Some(FinalizedL1Snapshot { block_number, block_hash, finalized_safe_proposal_id }))
    }

    /// Determine the L1 block height used to resume event consumption after beacon sync.
    #[instrument(skip(self), level = "debug")]
    async fn event_stream_start_block(&self) -> Result<EventStreamStartPoint, SyncError> {
        let resume_head_block_number = self.resume_head_block_number().await?;
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

        // Try to get finalized snapshot. When unavailable, replay proposal zero from the inbox
        // activation block, which is safe because derivation is idempotent.
        let finalized_snapshot = self.try_finalized_l1_snapshot().await?;

        let (target_proposal_id, finalized_safe_proposal_id) =
            resolve_target_with_optional_finalization(
                resume_proposal_id,
                finalized_snapshot.as_ref().map(|s| s.finalized_safe_proposal_id),
            );
        let (finalized_block_number, finalized_block_hash) =
            if let Some(snapshot) = finalized_snapshot {
                (Some(snapshot.block_number), Some(snapshot.block_hash))
            } else {
                (None, None)
            };

        info!(
            resume_proposal_id,
            finalized_safe_proposal_id,
            finalized_block_number,
            finalized_block_hash = ?finalized_block_hash,
            target_proposal_id,
            resume_hash = ?resume_head_block.hash(),
            resume_number = resume_head_block.number(),
            "selected finalized-bounded proposal id from resume-source anchor metadata",
        );
        // Batch zero is the genesis boundary: the engine has no mapping for it and looking it up
        // would trigger a full backward chain scan, so route it through the fallback arms below.
        let target_block_number = if target_proposal_id == 0 {
            None
        } else {
            self.rpc
                .last_block_id_by_batch_id(U256::from(target_proposal_id))
                .await
                .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?
                .map(|block_number| block_number.to::<u64>())
        };

        let (target_block, bootstrap_confirmed_tip) = match target_block_number {
            // The mapped target block usually is the resume head itself; skip the refetch.
            Some(block_number) if block_number == resume_head_block.header.number => {
                (resume_head_block, block_number)
            }
            Some(block_number) => {
                let block = self
                    .rpc
                    .l2_provider
                    .get_block_by_number(BlockNumberOrTag::Number(block_number))
                    .full()
                    .await
                    .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?
                    .ok_or(SyncError::MissingExecutionBlock { number: block_number })?
                    .map_transactions(|tx: RpcTransaction| tx.into());
                (block, block_number)
            }
            None => {
                match resolve_missing_batch_mapping_fallback(target_proposal_id, resume_proposal_id)
                {
                    MissingBatchMappingFallback::UseResumeHead => {
                        if target_proposal_id == 0 {
                            info!(
                                resume_number = resume_head_block.header.number,
                                "bootstrapping event sync from the genesis resume head",
                            );
                        } else {
                            warn!(
                                target_proposal_id,
                                resume_number = resume_head_block.header.number,
                                "batch mapping unavailable for resume-head proposal; extracting \
                                 anchor from the resume head block",
                            );
                        }
                        let resume_number = resume_head_block.header.number;
                        (resume_head_block, resume_number)
                    }
                    MissingBatchMappingFallback::ReplayFromActivation => {
                        let anchor_block_number = self.activation_block_number().await?;
                        if target_proposal_id == 0 {
                            info!(
                                resume_proposal_id,
                                anchor_block_number,
                                "no finalized proposal to resume from; replaying derivation from \
                                 the activation block",
                            );
                        } else {
                            warn!(
                                target_proposal_id,
                                resume_proposal_id,
                                anchor_block_number,
                                "batch mapping unavailable for finalized-bounded target; replaying \
                                 derivation from the activation block",
                            );
                        }
                        return Ok(EventStreamStartPoint {
                            anchor_block_number,
                            initial_proposal_id: 0,
                            bootstrap_confirmed_tip: 0,
                        });
                    }
                }
            }
        };

        let anchor_block_number =
            self.decode_anchor_block_number(&target_block, anchor_address).await?;
        info!(
            anchor_block_number,
            target_hash = ?target_block.hash(),
            target_number = target_block.number(),
            target_proposal_id,
            "derived anchor block number from target block",
        );
        Ok(EventStreamStartPoint {
            anchor_block_number,
            initial_proposal_id: target_proposal_id,
            bootstrap_confirmed_tip,
        })
    }
}

impl EventSyncer {
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

    let input = crate::anchor_tx::first_anchor_tx_input(block, anchor_address).map_err(missing)?;
    anchorV4Call::abi_decode(input).map_err(|_| missing("failed to decode anchorV4 calldata"))
}

#[async_trait::async_trait]
impl SyncStage for EventSyncer {
    /// Start the event syncer.
    #[instrument(skip(self), name = "event_syncer_run")]
    async fn run(&self) -> Result<(), SyncError> {
        let start_point = self.event_stream_start_block().await?;
        let anchor_block_number = start_point.anchor_block_number;
        let initial_proposal_id = start_point.initial_proposal_id;
        let start_tag = BlockNumberOrTag::Number(anchor_block_number);

        DriverMetrics::event_last_canonical_proposal_id().set(initial_proposal_id as f64);
        DriverMetrics::event_last_canonical_block_number()
            .set(start_point.bootstrap_confirmed_tip as f64);
        info!(
            initial_proposal_id,
            bootstrap_confirmed_tip = start_point.bootstrap_confirmed_tip,
            "bootstrapped event sync state from finalized-bounded resume target",
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

        let mut reconnect_start_tag = start_tag;
        let startup_anchor_block_number = anchor_block_number;

        // Strict gate state for starting preconfirmation ingress.
        let mut preconf_ingress_spawned = false;
        let mut scanner_live = false;
        let mut scanner_started_once = false;

        loop {
            if !preconf_ingress_spawned {
                // A reconnect re-enters historical sync and must wait for a fresh
                // `SwitchingToLive` notification before probing ingress readiness.
                scanner_live = false;
            }
            let mut scanner = match self
                .cfg
                .client
                .l1_provider_source
                .to_event_scanner_from_tag(reconnect_start_tag)
                .await
            {
                Ok(scanner) => scanner,
                Err(err) => {
                    let err =
                        super::retryable_after_first_success(scanner_started_once, err.to_string())
                            .map_err(SyncError::EventScannerInit)?;
                    warn!(
                        error = %err,
                        start_tag = ?reconnect_start_tag,
                        retry_after_secs = self.cfg.retry_interval.as_secs_f64(),
                        "failed to initialize event scanner; retrying"
                    );
                    sleep(self.cfg.retry_interval).await;
                    continue;
                }
            };
            let filter = EventFilter::new()
                .contract_address(self.cfg.client.inbox_address)
                .event(Proposed::SIGNATURE);
            let subscription = scanner.subscribe(filter);
            let proof = match scanner.start().await {
                Ok(proof) => {
                    scanner_started_once = true;
                    proof
                }
                Err(err) => {
                    let err =
                        super::retryable_after_first_success(scanner_started_once, err.to_string())
                            .map_err(SyncError::EventScannerInit)?;
                    warn!(
                        error = %err,
                        start_tag = ?reconnect_start_tag,
                        retry_after_secs = self.cfg.retry_interval.as_secs_f64(),
                        "failed to start event scanner; retrying"
                    );
                    sleep(self.cfg.retry_interval).await;
                    continue;
                }
            };
            let mut stream = subscription.stream(&proof);

            info!(
                start_tag = ?reconnect_start_tag,
                "event scanner started; listening for inbox proposals"
            );

            let mut last_seen_l1_block_number = None;

            while let Some(message) = stream.next().await {
                debug!(?message, "received inbox proposal message from event scanner");
                match message {
                    Ok(ScannerMessage::Data(logs)) => {
                        if let Some(block_number) = logs.last().and_then(|log| log.block_number) {
                            last_seen_l1_block_number = Some(block_number);
                        }
                        DriverMetrics::event_scanner_batches_total().inc();
                        DriverMetrics::event_proposals_total().inc_by(logs.len() as u64);
                        self.process_log_batch(router.clone(), logs).await?;
                    }
                    Ok(ScannerMessage::Notification(notification)) => {
                        info!(?notification, "event scanner notification");
                        match notification {
                            Notification::SwitchingToLive => {
                                // Scanner live is necessary but not sufficient: confirmed-sync
                                // readiness must also pass before ingress
                                // opens.
                                scanner_live = true;
                            }
                            Notification::ReorgDetected { common_ancestor } => {
                                if timeout(
                                    REORG_HEAD_L1_ORIGIN_RESET_TIMEOUT,
                                    self.reset_head_l1_origin_after_reorg(common_ancestor),
                                )
                                .await
                                .is_err()
                                {
                                    warn!(
                                        common_ancestor,
                                        timeout_ms =
                                            REORG_HEAD_L1_ORIGIN_RESET_TIMEOUT.as_millis() as u64,
                                        "timed out resetting head_l1_origin after reorg"
                                    );
                                }
                            }
                            Notification::NoPastLogsFound => {}
                        }
                    }
                    Err(err) => {
                        DriverMetrics::event_scanner_errors_total().inc();
                        error!(?err, "error receiving proposal logs from event scanner");
                        continue;
                    }
                }

                if should_probe_confirmed_sync(
                    self.cfg.preconfirmation_enabled,
                    preconf_ingress_spawned,
                    self.preconf_ingress_ready.load(Ordering::Acquire),
                    scanner_live,
                ) {
                    let confirmed_sync_probe = self.confirmed_sync_snapshot().await;
                    if let Err(err) = &confirmed_sync_probe {
                        DriverMetrics::event_confirmed_sync_probe_errors_total().inc();
                        warn!(
                            ?err,
                            "confirmed-sync probe failed; keeping preconfirmation ingress closed"
                        );
                        continue;
                    }
                    let confirmed_sync_ready = resolve_confirmed_sync_probe(confirmed_sync_probe);
                    if confirmed_sync_ready {
                        let rx = self
                            .preconf_rx
                            .lock()
                            .expect("preconfirmation receiver lock should not be poisoned")
                            .take();
                        if let Some(rx) = rx {
                            self.spawn_preconf_ingress(
                                router.clone(),
                                rx,
                                self.rpc.clone(),
                                self.preconf_ingress_ready.clone(),
                                self.preconf_ingress_notify.clone(),
                            );
                            preconf_ingress_spawned = true;
                        } else if !self.preconf_ingress_ready.swap(true, Ordering::AcqRel) {
                            info!("re-opened preconfirmation ingress after scanner reconnect");
                            self.preconf_ingress_notify.notify_waiters();
                        }
                    }
                }
            }

            // A dropped scanner forces a historical replay window again, so close ingress until
            // the next live scanner transition and confirmed-sync probe re-open it.
            if self.preconf_ingress_ready.swap(false, Ordering::AcqRel) {
                info!("closing preconfirmation ingress during event scanner reconnect");
            }

            if let Some(block_number) = last_seen_l1_block_number {
                let reconnect_finalized_block_number = match self.try_finalized_l1_snapshot().await
                {
                    Ok(snapshot) => snapshot.map(|snapshot| snapshot.block_number),
                    Err(err) => {
                        warn!(
                            ?err,
                            fallback_start_block = startup_anchor_block_number,
                            "failed to resolve finalized reconnect anchor; rewinding to startup anchor"
                        );
                        None
                    }
                };
                reconnect_start_tag = BlockNumberOrTag::Number(resolve_reconnect_start_block(
                    block_number,
                    reconnect_finalized_block_number,
                    startup_anchor_block_number,
                ));
            }
            warn!(
                start_tag = ?reconnect_start_tag,
                retry_after_secs = self.cfg.retry_interval.as_secs_f64(),
                "event scanner stream ended; reconnecting"
            );
            sleep(self.cfg.retry_interval).await;
        }
    }
}

#[cfg(test)]
mod tests {
    use std::{
        collections::HashSet,
        path::PathBuf,
        sync::{Arc as StdArc, Mutex},
        time::Duration,
    };

    use super::*;
    use alethia_reth_primitives::payload::attributes::{
        RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
    };
    use alloy::{
        primitives::{
            Address, B256, Bytes, FixedBytes, U256,
            aliases::{U24, U48},
        },
        transports::http::reqwest::Url,
    };
    use alloy_provider::ProviderBuilder;
    use alloy_rpc_types_engine::PayloadId;
    use alloy_rpc_types_engine_2::PayloadAttributes as EthPayloadAttributes;
    use alloy_transport::mock::Asserter;
    use async_trait::async_trait;
    use bindings::{
        anchor::Anchor::AnchorInstance,
        inbox::{
            IInbox::{CoreState, DerivationSource},
            Inbox::{InboxInstance, getCoreStateCall},
            LibBlobs::BlobSlice,
        },
    };
    use rpc::{
        SubscriptionSource,
        blob::BlobDataSource,
        client::{Client, ClientConfig, ShastaProtocolInstance},
    };

    use crate::{
        production::{BlockProductionPath, ProductionInput, ProductionRouter},
        sync::engine::EngineBlockOutcome,
    };

    fn sample_payload(block_number: u64) -> TaikoPayloadAttributes {
        let payload_attributes = EthPayloadAttributes {
            timestamp: 0,
            prev_randao: B256::ZERO,
            suggested_fee_recipient: Address::ZERO,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root: None,
            slot_number: None,
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

    fn mock_client() -> Client {
        mock_client_with_l1_asserter(Asserter::new())
    }

    async fn build_syncer() -> EventSyncer {
        let client_config = ClientConfig {
            l1_provider_source: SubscriptionSource::Http(
                Url::parse("http://localhost:8545").expect("valid http url"),
            ),
            l2_provider_url: Url::parse("http://localhost:8545").expect("valid http url"),
            l2_auth_provider_url: Url::parse("http://localhost:8551").expect("valid http url"),
            jwt_secret: PathBuf::from("/dev/null"),
            inbox_address: Address::ZERO,
        };
        let cfg = DriverConfig::new(
            client_config,
            Duration::from_secs(1),
            Url::parse("http://localhost:5052").expect("valid beacon url"),
            None,
            None,
            true,
        );

        let (preconf_tx, preconf_rx) = mpsc::channel(PRECONF_CHANNEL_CAPACITY);
        let blob_source =
            BlobDataSource::new(None, None, true).await.expect("blob data source should build");
        EventSyncer {
            rpc: mock_client(),
            cfg,
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
            blob_source: Arc::new(blob_source),
            preconf_tx: Some(preconf_tx),
            preconf_rx: Mutex::new(Some(preconf_rx)),
            preconf_ingress_ready: Arc::new(AtomicBool::new(false)),
            preconf_ingress_notify: Arc::new(Notify::new()),
        }
    }

    fn sample_event_log_with_block_hash(block_hash: B256) -> Log {
        Log {
            inner: alloy::primitives::Log::empty(),
            block_hash: Some(block_hash),
            block_number: Some(1),
            block_timestamp: None,
            transaction_hash: Some(B256::from([9u8; 32])),
            transaction_index: Some(0),
            log_index: Some(0),
            removed: false,
        }
    }

    fn sample_derivation_source() -> DerivationSource {
        DerivationSource {
            isForcedInclusion: false,
            blobSlice: BlobSlice {
                blobHashes: vec![FixedBytes::ZERO],
                offset: U24::ZERO,
                timestamp: U48::ZERO,
            },
        }
    }

    fn sample_proposed_log(proposal_id: u64, block_hash: B256, transaction_hash: B256) -> Log {
        let proposed = Proposed {
            id: U48::from(proposal_id),
            proposer: Address::from([proposal_id as u8; 20]),
            parentProposalHash: FixedBytes::from([proposal_id as u8; 32]),
            endOfSubmissionWindowTimestamp: U48::from(1u64),
            basefeeSharingPctg: 0,
            sources: vec![sample_derivation_source()],
        };

        Log {
            inner: alloy::primitives::Log::new_from_event_unchecked(Address::ZERO, proposed)
                .reserialize(),
            block_hash: Some(block_hash),
            block_number: Some(proposal_id),
            block_timestamp: None,
            transaction_hash: Some(transaction_hash),
            transaction_index: Some(0),
            log_index: Some(0),
            removed: false,
        }
    }

    fn sample_engine_outcome(block_number: u64) -> EngineBlockOutcome {
        let mut block = RpcBlock::<TxEnvelope>::default();
        block.header.number = block_number;
        block.header.hash = B256::from([block_number as u8; 32]);
        EngineBlockOutcome { block, payload_id: PayloadId::new([block_number as u8; 8]) }
    }

    fn sample_core_state(next_proposal_id: u64) -> CoreState {
        CoreState {
            nextProposalId: U48::from(next_proposal_id),
            lastProposalBlockId: U48::ZERO,
            lastFinalizedProposalId: U48::ZERO,
            lastFinalizedTimestamp: U48::ZERO,
            lastCheckpointTimestamp: U48::ZERO,
            lastFinalizedBlockHash: FixedBytes::ZERO,
        }
    }

    #[derive(Clone)]
    struct MockBatchPath {
        orphaned_tx_hashes: StdArc<HashSet<B256>>,
        seen_tx_hashes: StdArc<Mutex<Vec<B256>>>,
    }

    impl MockBatchPath {
        fn new(orphaned_tx_hashes: impl IntoIterator<Item = B256>) -> Self {
            Self {
                orphaned_tx_hashes: StdArc::new(orphaned_tx_hashes.into_iter().collect()),
                seen_tx_hashes: StdArc::new(Mutex::new(Vec::new())),
            }
        }

        fn seen_tx_hashes(&self) -> Vec<B256> {
            self.seen_tx_hashes.lock().expect("seen tx hashes mutex should not be poisoned").clone()
        }
    }

    #[async_trait]
    impl BlockProductionPath for MockBatchPath {
        async fn produce(
            &self,
            input: ProductionInput,
        ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
            let ProductionInput::L1ProposalLog(log) = input else {
                panic!("mock batch path only supports L1 proposal logs");
            };

            let tx_hash =
                log.transaction_hash.expect("test proposal log should always include tx hash");
            self.seen_tx_hashes
                .lock()
                .expect("seen tx hashes mutex should not be poisoned")
                .push(tx_hash);

            if self.orphaned_tx_hashes.contains(&tx_hash) {
                return Err(DriverError::Other(anyhow!("mock orphaned proposal failure")));
            }

            Ok(vec![sample_engine_outcome(
                log.block_number.expect("test proposal log should always include block number"),
            )])
        }
    }

    #[derive(Clone)]
    struct MockPreconfPath;

    #[async_trait]
    impl BlockProductionPath for MockPreconfPath {
        async fn produce(
            &self,
            input: ProductionInput,
        ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
            let ProductionInput::Preconfirmation(preconf) = input else {
                panic!("mock preconf path only supports preconfirmation inputs");
            };
            Ok(vec![sample_engine_outcome(preconf.block_number())])
        }
    }

    #[derive(Clone)]
    struct MockRetryBatchPath {
        fail_once_tx_hashes: StdArc<Mutex<HashSet<B256>>>,
        seen_tx_hashes: StdArc<Mutex<Vec<B256>>>,
    }

    impl MockRetryBatchPath {
        fn new(fail_once_tx_hashes: impl IntoIterator<Item = B256>) -> Self {
            Self {
                fail_once_tx_hashes: StdArc::new(Mutex::new(
                    fail_once_tx_hashes.into_iter().collect(),
                )),
                seen_tx_hashes: StdArc::new(Mutex::new(Vec::new())),
            }
        }

        fn seen_tx_hashes(&self) -> Vec<B256> {
            self.seen_tx_hashes.lock().expect("seen tx hashes mutex should not be poisoned").clone()
        }
    }

    #[async_trait]
    impl BlockProductionPath for MockRetryBatchPath {
        async fn produce(
            &self,
            input: ProductionInput,
        ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
            let ProductionInput::L1ProposalLog(log) = input else {
                panic!("mock retry batch path only supports L1 proposal logs");
            };

            let tx_hash =
                log.transaction_hash.expect("test proposal log should always include tx hash");
            self.seen_tx_hashes
                .lock()
                .expect("seen tx hashes mutex should not be poisoned")
                .push(tx_hash);

            if self
                .fail_once_tx_hashes
                .lock()
                .expect("fail-once tx hashes mutex should not be poisoned")
                .remove(&tx_hash)
            {
                return Err(DriverError::Other(anyhow!("mock retryable proposal failure")));
            }

            Ok(vec![sample_engine_outcome(
                log.block_number.expect("test proposal log should always include block number"),
            )])
        }
    }

    /// Production path that always fails with a deterministic engine verdict.
    #[derive(Clone)]
    struct MockFatalBatchPath {
        seen_tx_hashes: StdArc<Mutex<Vec<B256>>>,
    }

    impl MockFatalBatchPath {
        fn new() -> Self {
            Self { seen_tx_hashes: StdArc::new(Mutex::new(Vec::new())) }
        }

        fn seen_tx_hashes(&self) -> Vec<B256> {
            self.seen_tx_hashes.lock().expect("seen tx hashes mutex should not be poisoned").clone()
        }
    }

    #[async_trait]
    impl BlockProductionPath for MockFatalBatchPath {
        async fn produce(
            &self,
            input: ProductionInput,
        ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
            let ProductionInput::L1ProposalLog(log) = input else {
                panic!("mock fatal batch path only supports L1 proposal logs");
            };

            let tx_hash =
                log.transaction_hash.expect("test proposal log should always include tx hash");
            self.seen_tx_hashes
                .lock()
                .expect("seen tx hashes mutex should not be poisoned")
                .push(tx_hash);

            Err(DriverError::Sync(SyncError::Derivation(DerivationError::Engine(
                EngineSubmissionError::InvalidBlock(1, "mock invalid payload".to_string()),
            ))))
        }
    }

    fn mock_client_with_l1_asserter(l1_asserter: Asserter) -> Client {
        mock_client_with_asserters(l1_asserter, Asserter::new())
    }

    fn mock_client_with_asserters(l1_asserter: Asserter, l2_auth_asserter: Asserter) -> Client {
        mock_client_with_all_asserters(l1_asserter, Asserter::new(), l2_auth_asserter)
    }

    fn mock_client_with_all_asserters(
        l1_asserter: Asserter,
        l2_asserter: Asserter,
        l2_auth_asserter: Asserter,
    ) -> Client {
        let l1_provider = ProviderBuilder::new().connect_mocked_client(l1_asserter);
        let l2_provider =
            ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(l2_asserter);
        let l2_auth_provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_mocked_client(l2_auth_asserter);
        let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
        let anchor = AnchorInstance::new(Address::ZERO, l2_auth_provider.clone());
        let shasta = ShastaProtocolInstance { inbox, anchor };

        Client { chain_id: 0, l1_provider, l2_provider, l2_auth_provider, shasta }
    }

    #[tokio::test]
    async fn orphaned_proposal_log_is_permanent_when_l1_block_is_missing() {
        let asserter = Asserter::new();
        let syncer = EventSyncer {
            rpc: mock_client_with_l1_asserter(asserter.clone()),
            ..build_syncer().await
        };
        asserter.push_success(&Option::<RpcBlock<TxEnvelope>>::None);
        asserter.push_success(&1u64);

        let log = sample_event_log_with_block_hash(B256::from([1u8; 32]));
        let is_orphaned = syncer
            .is_permanently_orphaned_proposal_log(
                log.block_hash.expect("test log should include block hash"),
                log.block_number,
            )
            .await
            .expect("block lookup should succeed");

        assert!(is_orphaned);
    }

    #[tokio::test]
    async fn proposal_log_is_retryable_when_chain_head_is_behind_missing_block() {
        let asserter = Asserter::new();
        let syncer = EventSyncer {
            rpc: mock_client_with_l1_asserter(asserter.clone()),
            ..build_syncer().await
        };
        asserter.push_success(&Option::<RpcBlock<TxEnvelope>>::None);
        asserter.push_success(&0u64);

        let log = sample_event_log_with_block_hash(B256::from([5u8; 32]));
        let is_orphaned = syncer
            .is_permanently_orphaned_proposal_log(
                log.block_hash.expect("test log should include block hash"),
                log.block_number,
            )
            .await
            .expect("block lookup should succeed");

        assert!(!is_orphaned);
    }

    #[tokio::test]
    async fn proposal_log_is_retryable_when_l1_block_still_exists() {
        let asserter = Asserter::new();
        let syncer = EventSyncer {
            rpc: mock_client_with_l1_asserter(asserter.clone()),
            ..build_syncer().await
        };
        asserter.push_success(&Some(RpcBlock::<TxEnvelope>::default()));

        let log = sample_event_log_with_block_hash(B256::from([2u8; 32]));
        let is_orphaned = syncer
            .is_permanently_orphaned_proposal_log(
                log.block_hash.expect("test log should include block hash"),
                log.block_number,
            )
            .await
            .expect("block lookup should succeed");

        assert!(!is_orphaned);
    }

    #[tokio::test]
    async fn proposal_log_reorg_check_is_transient_on_rpc_error() {
        let asserter = Asserter::new();
        let syncer = EventSyncer {
            rpc: mock_client_with_l1_asserter(asserter.clone()),
            ..build_syncer().await
        };
        asserter.push_failure_msg("boom");

        let log = sample_event_log_with_block_hash(B256::from([3u8; 32]));
        let err = syncer
            .is_permanently_orphaned_proposal_log(
                log.block_hash.expect("test log should include block hash"),
                log.block_number,
            )
            .await
            .expect_err("rpc lookup failure should be surfaced");

        assert!(matches!(err, SyncError::Rpc(RpcClientError::Provider(_))));
    }

    #[tokio::test]
    async fn process_log_batch_skips_orphaned_proposal_log_and_continues_batch() {
        let orphaned_block_hash = B256::from([0x11; 32]);
        let orphaned_tx_hash = B256::from([0x21; 32]);
        let later_tx_hash = B256::from([0x22; 32]);
        let asserter = Asserter::new();
        asserter.push_success(&Option::<RpcBlock<TxEnvelope>>::None);
        asserter.push_success(&2u64);

        let syncer =
            EventSyncer { rpc: mock_client_with_l1_asserter(asserter), ..build_syncer().await };
        let path = MockBatchPath::new([orphaned_tx_hash]);
        let router = Arc::new(AsyncMutex::new(ProductionRouter::new(Arc::new(path.clone()), None)));

        let result = timeout(
            Duration::from_millis(250),
            syncer.process_log_batch(
                router,
                vec![
                    sample_proposed_log(1, orphaned_block_hash, orphaned_tx_hash),
                    sample_proposed_log(2, B256::from([0x12; 32]), later_tx_hash),
                ],
            ),
        )
        .await;

        assert!(
            matches!(result, Ok(Ok(()))),
            "orphaned log should be skipped so a later log in the same batch still processes",
        );
        assert_eq!(path.seen_tx_hashes(), vec![orphaned_tx_hash, later_tx_hash]);
    }

    #[tokio::test]
    async fn process_log_batch_fails_when_proposal_log_missing_block_hash() {
        let syncer = EventSyncer {
            rpc: mock_client_with_l1_asserter(Asserter::new()),
            ..build_syncer().await
        };
        let path = MockBatchPath::new([]);
        let router = Arc::new(AsyncMutex::new(ProductionRouter::new(Arc::new(path.clone()), None)));
        let mut log = sample_proposed_log(1, B256::from([0x31; 32]), B256::from([0x41; 32]));
        log.block_hash = None;

        let err = syncer
            .process_log_batch(router, vec![log])
            .await
            .expect_err("missing block hash should fail the batch");

        assert!(matches!(
            err,
            SyncError::MissingProposalLogBlockHash { tx_hash: Some(_), block_number: Some(1) }
        ));
        assert!(path.seen_tx_hashes().is_empty());
    }

    #[tokio::test]
    async fn process_log_batch_retries_when_orphan_recheck_errors() {
        let retry_block_hash = B256::from([0x51; 32]);
        let retry_tx_hash = B256::from([0x61; 32]);
        let asserter = Asserter::new();
        asserter.push_failure_msg("boom");

        let syncer =
            EventSyncer { rpc: mock_client_with_l1_asserter(asserter), ..build_syncer().await };
        let path = MockRetryBatchPath::new([retry_tx_hash]);
        let router = Arc::new(AsyncMutex::new(ProductionRouter::new(Arc::new(path.clone()), None)));

        let result = timeout(
            Duration::from_millis(250),
            syncer.process_log_batch(
                router,
                vec![sample_proposed_log(1, retry_block_hash, retry_tx_hash)],
            ),
        )
        .await;

        assert!(
            matches!(result, Ok(Ok(()))),
            "recheck rpc errors should keep the log retryable until a later attempt succeeds",
        );
        assert_eq!(path.seen_tx_hashes(), vec![retry_tx_hash, retry_tx_hash]);
    }

    /// Build an RPC block whose header hash matches the given hash, for canonical-proof stubs.
    fn rpc_block_with_hash(hash: B256) -> RpcBlock<TxEnvelope> {
        let mut block = RpcBlock::<TxEnvelope>::default();
        block.header.hash = hash;
        block
    }

    #[test]
    fn fatal_proposal_processing_errors_are_newpayload_invalid_only() {
        assert!(is_fatal_proposal_processing_error(&DriverError::Sync(SyncError::Derivation(
            DerivationError::Engine(EngineSubmissionError::InvalidBlock(1, "invalid".into()))
        ))));
        // ACCEPTED is transient on taiko-geth (returned while parent state is unavailable) and
        // forkchoice INVALID can reflect an unknown head; both must stay retryable.
        assert!(!is_fatal_proposal_processing_error(&DriverError::Sync(SyncError::Derivation(
            DerivationError::Engine(EngineSubmissionError::UnexpectedPayloadStatus(
                1,
                "ACCEPTED".into()
            ))
        ))));
        assert!(!is_fatal_proposal_processing_error(&DriverError::Sync(SyncError::Derivation(
            DerivationError::Engine(EngineSubmissionError::UnexpectedPayloadStatus(
                1,
                "forkchoice INVALID: bad head".into()
            ))
        ))));
        assert!(!is_fatal_proposal_processing_error(&DriverError::Sync(SyncError::Derivation(
            DerivationError::Engine(EngineSubmissionError::EngineSyncing(1))
        ))));
        assert!(!is_fatal_proposal_processing_error(&DriverError::Sync(SyncError::Rpc(
            RpcClientError::Provider("boom".into())
        ))));
        assert!(!is_fatal_proposal_processing_error(&DriverError::Other(anyhow!("boom"))));
    }

    #[tokio::test]
    async fn process_log_batch_aborts_without_retry_on_fatal_engine_verdict() {
        let fatal_block_hash = B256::from([0x71; 32]);
        let fatal_tx_hash = B256::from([0x81; 32]);
        let asserter = Asserter::new();
        // Orphan recheck (by hash) still resolves the source block, so the log is not skipped.
        asserter.push_success(&Some(RpcBlock::<TxEnvelope>::default()));
        // Canonical proof (by number) returns the log's own hash: the log is proven canonical,
        // so the deterministic engine verdict must abort instead of retrying forever.
        asserter.push_success(&Some(rpc_block_with_hash(fatal_block_hash)));

        let syncer =
            EventSyncer { rpc: mock_client_with_l1_asserter(asserter), ..build_syncer().await };
        let path = MockFatalBatchPath::new();
        let router = Arc::new(AsyncMutex::new(ProductionRouter::new(Arc::new(path.clone()), None)));

        let result = timeout(
            Duration::from_millis(250),
            syncer.process_log_batch(
                router,
                vec![sample_proposed_log(1, fatal_block_hash, fatal_tx_hash)],
            ),
        )
        .await;

        let err = result
            .expect("fatal verdict should abort immediately instead of exhausting the timeout")
            .expect_err("fatal engine verdict on a proven-canonical log should surface an error");
        assert!(matches!(
            err,
            SyncError::Derivation(DerivationError::Engine(EngineSubmissionError::InvalidBlock(..)))
        ));
        assert_eq!(
            path.seen_tx_hashes(),
            vec![fatal_tx_hash],
            "a deterministic engine verdict on a proven-canonical log must not be retried"
        );
    }

    #[tokio::test]
    async fn process_log_batch_keeps_retrying_fatal_verdict_without_canonical_proof() {
        let stale_block_hash = B256::from([0x72; 32]);
        let stale_tx_hash = B256::from([0x82; 32]);
        let asserter = Asserter::new();
        // Two attempts' worth of responses. The by-hash recheck resolves the block (geth-like
        // L1 nodes keep serving reorged-out blocks by hash), but the canonical block at the
        // log's height carries a different hash — the proof fails, so the fatal verdict must
        // keep retrying instead of terminating event sync on a possibly-reorged log.
        for _ in 0..2 {
            asserter.push_success(&Some(RpcBlock::<TxEnvelope>::default()));
            asserter.push_success(&Some(rpc_block_with_hash(B256::from([0x99; 32]))));
        }

        let syncer =
            EventSyncer { rpc: mock_client_with_l1_asserter(asserter), ..build_syncer().await };
        let path = MockFatalBatchPath::new();
        let router = Arc::new(AsyncMutex::new(ProductionRouter::new(Arc::new(path.clone()), None)));

        let result = timeout(
            Duration::from_millis(250),
            syncer.process_log_batch(
                router,
                vec![sample_proposed_log(1, stale_block_hash, stale_tx_hash)],
            ),
        )
        .await;

        assert!(
            result.is_err(),
            "an unproven fatal verdict must keep retrying rather than abort the batch"
        );
        assert!(
            path.seen_tx_hashes().len() >= 2,
            "the proposal should be retried while canonicality stays unproven"
        );
    }

    #[tokio::test]
    async fn preconf_submit_rejected_before_first_event_sync_gate() {
        let syncer = build_syncer().await;
        let payload = PreconfPayload::new(sample_payload(1), B256::ZERO);
        let err = syncer
            .submit_preconfirmation_payload_with_timeout(payload, Duration::from_millis(10))
            .await
            .expect_err("expected ingress not ready error");

        assert!(matches!(err, DriverError::PreconfIngressNotReady));
    }

    #[tokio::test]
    async fn materialized_preconfirmation_requires_expected_parent() {
        let l2_asserter = Asserter::new();
        let client =
            mock_client_with_all_asserters(Asserter::new(), l2_asserter.clone(), Asserter::new());
        let mut attributes = sample_payload(2);
        attributes.l1_origin.build_payload_args_id = [0x11; 8];
        let origin = attributes.l1_origin.clone();
        let expected_parent_hash = B256::from([0x22; 32]);
        let payload = PreconfPayload::new(attributes.clone(), expected_parent_hash);

        let mut block = RpcBlock::<TxEnvelope>::default();
        block.header.parent_hash = B256::from([0x33; 32]);
        block.header.number = 2;
        block.header.beneficiary = attributes.payload_attributes.suggested_fee_recipient;
        block.header.mix_hash = attributes.payload_attributes.prev_randao;
        block.header.gas_limit = attributes.block_metadata.gas_limit;
        block.header.timestamp = attributes.payload_attributes.timestamp;
        block.header.extra_data = attributes.block_metadata.extra_data.clone();
        block.header.base_fee_per_gas = Some(0);

        l2_asserter.push_success(&Some(origin));
        l2_asserter.push_success(&Some(block));

        assert!(
            materialized_preconfirmation_block_hash(&client, &payload)
                .await
                .expect("materialization lookup should succeed")
                .is_none()
        );
    }

    #[tokio::test]
    async fn materialized_preconfirmation_returns_observed_block_hash() {
        let l2_asserter = Asserter::new();
        let client =
            mock_client_with_all_asserters(Asserter::new(), l2_asserter.clone(), Asserter::new());
        let mut attributes = sample_payload(2);
        attributes.l1_origin.build_payload_args_id = [0x11; 8];
        let origin = attributes.l1_origin.clone();
        let expected_parent_hash = B256::from([0x22; 32]);
        let payload = PreconfPayload::new(attributes.clone(), expected_parent_hash);

        let observed_block_hash = B256::from([0x66; 32]);
        let mut block = RpcBlock::<TxEnvelope>::default();
        block.header.hash = observed_block_hash;
        block.header.parent_hash = expected_parent_hash;
        block.header.number = 2;
        block.header.beneficiary = attributes.payload_attributes.suggested_fee_recipient;
        block.header.mix_hash = attributes.payload_attributes.prev_randao;
        block.header.gas_limit = attributes.block_metadata.gas_limit;
        block.header.timestamp = attributes.payload_attributes.timestamp;
        block.header.extra_data = attributes.block_metadata.extra_data.clone();
        block.header.base_fee_per_gas = Some(0);

        l2_asserter.push_success(&Some(origin));
        l2_asserter.push_success(&Some(block));

        assert_eq!(
            materialized_preconfirmation_block_hash(&client, &payload)
                .await
                .expect("materialization lookup should succeed"),
            Some(observed_block_hash)
        );
    }

    #[tokio::test]
    async fn stale_materialized_preconfirmation_reports_stale() {
        let l2_asserter = Asserter::new();
        let client =
            mock_client_with_all_asserters(Asserter::new(), l2_asserter.clone(), Asserter::new());
        let syncer = EventSyncer { rpc: client, ..build_syncer().await };
        syncer.preconf_ingress_ready.store(true, Ordering::Release);

        let mut attributes = sample_payload(2);
        attributes.l1_origin.build_payload_args_id = [0x44; 8];
        let origin = attributes.l1_origin.clone();
        let expected_parent_hash = B256::from([0x55; 32]);
        let payload = PreconfPayload::new(attributes.clone(), expected_parent_hash);

        let mut block = RpcBlock::<TxEnvelope>::default();
        block.header.parent_hash = expected_parent_hash;
        block.header.number = 2;
        block.header.beneficiary = attributes.payload_attributes.suggested_fee_recipient;
        block.header.mix_hash = attributes.payload_attributes.prev_randao;
        block.header.gas_limit = attributes.block_metadata.gas_limit;
        block.header.timestamp = attributes.payload_attributes.timestamp;
        block.header.extra_data = attributes.block_metadata.extra_data.clone();
        block.header.base_fee_per_gas = Some(0);

        let mut confirmed_head = origin.clone();
        confirmed_head.block_id = U256::from(2u64);
        l2_asserter.push_success(&Some(origin));
        l2_asserter.push_success(&Some(block));
        l2_asserter.push_success(&Some(confirmed_head));

        let outcome = syncer
            .submit_preconfirmation_payload(payload)
            .await
            .expect("materialized payload should return a terminal outcome");

        assert_eq!(outcome, PreconfSubmissionOutcome::Stale);
    }

    #[test]
    fn stale_preconfirmation_boundary_is_inclusive() {
        assert!(is_stale_preconf(42, 42));
        assert!(!is_stale_preconf(43, 42));
    }

    #[tokio::test]
    async fn queued_preconfirmation_reports_stale_after_confirmed_tip_advances() {
        let l2_asserter = Asserter::new();
        let client =
            mock_client_with_all_asserters(Asserter::new(), l2_asserter.clone(), Asserter::new());
        let syncer = EventSyncer { rpc: client.clone(), ..build_syncer().await };
        let rx = syncer
            .preconf_rx
            .lock()
            .expect("preconfirmation receiver mutex should not be poisoned")
            .take()
            .expect("preconfirmation receiver should be available");
        let path = MockBatchPath::new([]);
        let router = Arc::new(AsyncMutex::new(ProductionRouter::new(
            Arc::new(path.clone()),
            Some(Arc::new(path)),
        )));
        syncer.spawn_preconf_ingress(
            router,
            rx,
            client,
            Arc::clone(&syncer.preconf_ingress_ready),
            Arc::clone(&syncer.preconf_ingress_notify),
        );
        syncer
            .wait_preconf_ingress_ready()
            .await
            .expect("preconfirmation ingress should become ready");

        let mut initial_head = sample_payload(0).l1_origin;
        initial_head.block_id = U256::ZERO;
        let mut advanced_head = initial_head.clone();
        advanced_head.block_id = U256::from(1u64);
        // Pre-enqueue: materialization origin miss, then non-stale head; ingress loop reads the
        // advanced head first (under the router lock) and short-circuits as stale before any
        // materialization lookup.
        l2_asserter.push_success(&Option::<RpcL1Origin>::None);
        l2_asserter.push_success(&Some(initial_head));
        l2_asserter.push_success(&Some(advanced_head));

        let outcome = syncer
            .submit_preconfirmation_payload(PreconfPayload::new(sample_payload(1), B256::ZERO))
            .await
            .expect("stale payload should return a terminal outcome");

        assert_eq!(outcome, PreconfSubmissionOutcome::Stale);
    }

    #[tokio::test]
    async fn queued_preconfirmation_binds_inserted_outcome_to_produced_block() {
        let l2_asserter = Asserter::new();
        let client =
            mock_client_with_all_asserters(Asserter::new(), l2_asserter.clone(), Asserter::new());
        let syncer = EventSyncer { rpc: client.clone(), ..build_syncer().await };
        let rx = syncer
            .preconf_rx
            .lock()
            .expect("preconfirmation receiver mutex should not be poisoned")
            .take()
            .expect("preconfirmation receiver should be available");
        let router = Arc::new(AsyncMutex::new(ProductionRouter::new(
            Arc::new(MockBatchPath::new([])),
            Some(Arc::new(MockPreconfPath)),
        )));
        syncer.spawn_preconf_ingress(
            router,
            rx,
            client,
            Arc::clone(&syncer.preconf_ingress_ready),
            Arc::clone(&syncer.preconf_ingress_notify),
        );
        syncer
            .wait_preconf_ingress_ready()
            .await
            .expect("preconfirmation ingress should become ready");

        let mut head = sample_payload(0).l1_origin;
        head.block_id = U256::ZERO;
        // Pre-enqueue: materialization origin miss + non-stale head; ingress loop: non-stale
        // head (under the router lock) + materialization origin miss, then injection.
        l2_asserter.push_success(&Option::<RpcL1Origin>::None);
        l2_asserter.push_success(&Some(head.clone()));
        l2_asserter.push_success(&Some(head));
        l2_asserter.push_success(&Option::<RpcL1Origin>::None);

        let outcome = syncer
            .submit_preconfirmation_payload(PreconfPayload::new(sample_payload(1), B256::ZERO))
            .await
            .expect("inserted payload should return a terminal outcome");

        // `MockPreconfPath` replies with `sample_engine_outcome(1)`, whose block hash is below.
        assert_eq!(
            outcome,
            PreconfSubmissionOutcome::Inserted { block_hash: B256::from([1u8; 32]) }
        );
    }

    #[test]
    fn confirmed_sync_ready_when_target_is_zero() {
        assert!(ConfirmedSyncSnapshot::new(0, None, None).is_ready());
    }

    #[test]
    fn confirmed_sync_ready_requires_head_l1_origin_for_nonzero_target() {
        assert!(!ConfirmedSyncSnapshot::new(7, Some(11), None).is_ready());
    }

    #[test]
    fn confirmed_sync_ready_requires_target_batch_mapping_for_nonzero_target() {
        assert!(!ConfirmedSyncSnapshot::new(7, None, Some(11)).is_ready());
    }

    #[test]
    fn confirmed_sync_ready_is_false_when_head_is_behind_target_block() {
        assert!(!ConfirmedSyncSnapshot::new(7, Some(12), Some(11)).is_ready());
    }

    #[test]
    fn confirmed_sync_ready_is_true_when_head_reaches_target_block() {
        assert!(ConfirmedSyncSnapshot::new(7, Some(12), Some(12)).is_ready());
        assert!(ConfirmedSyncSnapshot::new(7, Some(12), Some(15)).is_ready());
    }

    #[test]
    fn confirmed_sync_probe_rearms_when_ingress_gate_closes_after_spawn() {
        assert!(should_probe_confirmed_sync(true, true, false, true));
        assert!(!should_probe_confirmed_sync(true, true, true, true));
        assert!(should_probe_confirmed_sync(true, false, false, true));
        assert!(!should_probe_confirmed_sync(true, false, false, false));
        assert!(!should_probe_confirmed_sync(false, true, false, true));
    }

    #[test]
    fn confirmed_sync_probe_success_reflects_snapshot_readiness() {
        let ready = resolve_confirmed_sync_probe(Ok(ConfirmedSyncSnapshot::new(0, None, None)));
        assert!(ready, "successful probe should defer to snapshot readiness");
    }

    #[test]
    fn confirmed_sync_probe_error_keeps_ingress_closed() {
        let ready = resolve_confirmed_sync_probe(Err(SyncError::MissingCheckpointResumeHead));
        assert!(!ready, "probe errors must keep ingress closed until a later successful probe",);
    }

    #[tokio::test]
    async fn reset_head_l1_origin_after_reorg_lowers_head_to_latest_canonical_batch_tip() {
        let l1_asserter = Asserter::new();
        let l2_auth_asserter = Asserter::new();
        let syncer = EventSyncer {
            rpc: mock_client_with_asserters(l1_asserter.clone(), l2_auth_asserter.clone()),
            ..build_syncer().await
        };

        let core_state = sample_core_state(100);
        let encoded_core_state = Bytes::from(getCoreStateCall::abi_encode_returns(&core_state));
        l1_asserter.push_success(&encoded_core_state);
        l2_auth_asserter.push_success(&Some(U256::from(7_777u64))); // last_certain_block_id_by_batch_id
        l2_auth_asserter.push_success(&Some(U256::from(7_777u64))); // set_head_l1_origin

        syncer.reset_head_l1_origin_after_reorg(1_234).await;

        assert!(l1_asserter.read_q().is_empty());
        assert!(l2_auth_asserter.read_q().is_empty());
    }

    #[tokio::test]
    async fn reset_head_l1_origin_after_reorg_skips_when_batch_mapping_missing() {
        let l1_asserter = Asserter::new();
        let l2_auth_asserter = Asserter::new();
        let syncer = EventSyncer {
            rpc: mock_client_with_asserters(l1_asserter.clone(), l2_auth_asserter.clone()),
            ..build_syncer().await
        };

        let core_state = sample_core_state(100);
        let encoded_core_state = Bytes::from(getCoreStateCall::abi_encode_returns(&core_state));
        l1_asserter.push_success(&encoded_core_state);
        l2_auth_asserter.push_success(&Option::<U256>::None);

        syncer.reset_head_l1_origin_after_reorg(1_234).await;

        // No set_head_l1_origin call should be queued: missing mapping is a best-effort skip.
        assert!(l1_asserter.read_q().is_empty());
        assert!(l2_auth_asserter.read_q().is_empty());
    }

    #[test]
    fn resume_head_resolution_requires_checkpoint_state_in_checkpoint_mode() {
        let err = resolve_resume_head_block_number(true, None, Some(100), Some(99))
            .expect_err("checkpoint mode should require checkpoint resume state");
        assert!(matches!(err, SyncError::MissingCheckpointResumeHead));

        let resolved = resolve_resume_head_block_number(true, Some(420), None, None)
            .expect("checkpoint resume head should be used when present");
        assert_eq!(resolved, (420, "checkpoint-synced head"));
    }

    #[test]
    fn resume_head_resolution_requires_head_l1_origin_without_checkpoint() {
        let err = resolve_resume_head_block_number(false, Some(999), None, None)
            .expect_err("non-checkpoint mode should require head_l1_origin");
        assert!(matches!(err, SyncError::MissingHeadL1OriginResume));

        let resolved = resolve_resume_head_block_number(false, Some(999), Some(64), Some(80))
            .expect("head_l1_origin should drive resume when rpc head is not lower");
        assert_eq!(resolved, (64, "local head_l1_origin"));

        let resolved = resolve_resume_head_block_number(false, None, None, Some(0))
            .expect("genesis fallback when rpc reports block 0 and origin is missing");
        assert_eq!(resolved, (0, "genesis fallback (head_l1_origin unavailable)"));
    }

    #[test]
    fn resume_head_resolution_prefers_lower_non_zero_rpc_over_origin() {
        let resolved = resolve_resume_head_block_number(false, None, Some(64), Some(32))
            .expect("lower non-zero rpc block number should win");
        assert_eq!(resolved, (32, "lower rpc block number (instead of local head_l1_origin)"));

        let resolved = resolve_resume_head_block_number(false, None, Some(64), Some(0))
            .expect("zero rpc block number must not override origin");
        assert_eq!(resolved, (64, "local head_l1_origin"));
    }

    #[test]
    fn resume_head_resolution_falls_back_to_origin_when_rpc_missing() {
        let resolved = resolve_resume_head_block_number(false, None, Some(64), None)
            .expect("missing rpc block number should fall back to local origin");
        assert_eq!(resolved, (64, "local head_l1_origin"));
    }

    #[test]
    fn preconfirmation_submit_timeout_defaults_to_12_seconds() {
        assert_eq!(
            PRECONFIRMATION_PAYLOAD_SUBMIT_TIMEOUT,
            Duration::from_secs(12),
            "preconfirmation submit timeout should default to 12 seconds"
        );
    }

    // -- resolve_target_with_optional_finalization tests --

    #[test]
    fn without_finalization_resets_to_zero_target() {
        let (target, safe) = resolve_target_with_optional_finalization(0, None);
        assert_eq!(target, 0);
        assert_eq!(safe, 0);

        // Even with a non-zero resume, no finalization resets both to 0.
        let (target, safe) = resolve_target_with_optional_finalization(5, None);
        assert_eq!(target, 0);
        assert_eq!(safe, 0);
    }

    #[test]
    fn with_finalization_target_is_bounded_by_finalized_safe() {
        let (target, safe) = resolve_target_with_optional_finalization(120, Some(90));
        assert_eq!(target, 90);
        assert_eq!(safe, 90);
    }

    #[test]
    fn with_finalization_target_keeps_resume_when_behind() {
        let (target, safe) = resolve_target_with_optional_finalization(50, Some(120));
        assert_eq!(target, 50);
        assert_eq!(safe, 120);
    }

    #[test]
    fn reconnect_start_rewinds_to_finalized_when_finalized_is_behind_last_seen() {
        let reconnect_start = resolve_reconnect_start_block(120, Some(80), 10);
        assert_eq!(reconnect_start, 80);
    }

    #[test]
    fn reconnect_start_keeps_one_block_overlap_when_finalized_is_ahead() {
        let reconnect_start = resolve_reconnect_start_block(120, Some(240), 10);
        assert_eq!(reconnect_start, 119);
    }

    #[test]
    fn reconnect_start_falls_back_to_startup_anchor_without_finalization() {
        let reconnect_start = resolve_reconnect_start_block(120, None, 10);
        assert_eq!(reconnect_start, 10);
    }

    // -- resolve_missing_batch_mapping_fallback tests --

    #[test]
    fn missing_batch_mapping_uses_resume_head_for_resume_proposal() {
        assert_eq!(
            resolve_missing_batch_mapping_fallback(18_058, 18_058),
            MissingBatchMappingFallback::UseResumeHead
        );
    }

    #[test]
    fn missing_batch_mapping_replays_from_activation_for_rewound_target() {
        assert_eq!(
            resolve_missing_batch_mapping_fallback(18_045, 18_058),
            MissingBatchMappingFallback::ReplayFromActivation
        );
    }

    #[test]
    fn missing_batch_mapping_uses_resume_head_for_genesis_target() {
        assert_eq!(
            resolve_missing_batch_mapping_fallback(0, 0),
            MissingBatchMappingFallback::UseResumeHead
        );
    }

    #[test]
    fn missing_batch_mapping_replays_from_activation_for_zero_target_with_nonzero_resume() {
        assert_eq!(
            resolve_missing_batch_mapping_fallback(0, 7),
            MissingBatchMappingFallback::ReplayFromActivation
        );
    }
}
