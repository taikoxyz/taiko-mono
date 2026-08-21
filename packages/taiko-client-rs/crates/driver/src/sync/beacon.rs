//! Checkpoint-assisted execution engine sync toward the proof-finalized L2 block.
//!
//! The sync target is read trustlessly from the L1 inbox core state
//! (`lastFinalizedProposalId` / `lastFinalizedBlockHash`) at the finalized L1 block whenever
//! the endpoint can serve it, so the target is final on both layers; degraded latest-block reads
//! import the target without the engine's finalized marking. The optional checkpoint node
//! only serves block bodies and is consulted only when the target body is not already stored
//! locally: every fetched block is verified against the L1-recorded hash before submission, and the
//! execution engine backfills its hash-linked ancestors over P2P.

use std::{sync::Arc, time::Duration};

use alethia_reth_primitives::engine::types::TaikoExecutionDataSidecar;
use alloy::providers::Provider;
use alloy_consensus::{self, Block, TxEnvelope};
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::B256;
use alloy_provider::RootProvider;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState, PayloadStatusEnum,
};
use anyhow::anyhow;
use rpc::{
    client::{Client, connect_http_with_timeout},
    error::RpcClientError,
};
use tokio::time::{MissedTickBehavior, interval};
use tracing::{debug, info, instrument, warn};

use super::{
    FINALIZED_BLOCK_NOT_FOUND, SyncError, SyncStage, checkpoint_resume_head::CheckpointResumeHead,
    is_historical_state_unavailable,
};
use crate::{config::DriverConfig, error::DriverError, metrics::DriverMetrics};

/// Default polling interval used when no retry interval is configured.
const DEFAULT_BEACON_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(12);

/// Proof-finalized sync target read from the L1 inbox core state.
#[derive(Debug, Clone, Copy)]
struct FinalizedSyncTarget {
    /// Last proposal id finalized by proof on L1.
    proposal_id: u64,
    /// L2 block hash recorded on L1 for that finalized proposal.
    block_hash: B256,
    /// Whether the core state was read at a finalized L1 block. Latest-read fallbacks clear
    /// this so checkpoint import withholds the engine's finalized advertisement (WLP-INV-001).
    l1_finalized: bool,
}

/// Forkchoice state advertised when importing a checkpoint block.
///
/// A target read at a finalized L1 block is final on both layers, so it is advertised as head,
/// safe, and finalized. A target from the degraded latest-block fallback is advertised as head
/// and safe only: the L1 transactions recording it are not yet final, and telling the engine it
/// is finalized would block the rewind event sync needs if an L1 reorg drops the target's
/// proposal.
///
/// The engine's finalized marking is then left for derivation to advance, via the promotion
/// forkchoice in [`crate::sync::engine`]. Note that is not guaranteed to happen promptly: the
/// finalized hint behind it is itself read from inbox core state at a proposal's own L1 block,
/// so on the same non-archive endpoints it stays unresolved for any proposal older than the
/// retained-state window, and already-canonical proposals submit no forkchoice at all. A zero
/// finalized marking is safe in both target execution clients — it costs freezer layout on geth
/// and nothing on reth, whose backfill targets the head — so the marking may simply stay unset
/// until derivation catches up to within that window.
fn checkpoint_forkchoice_state(block_hash: B256, l1_finalized: bool) -> ForkchoiceState {
    ForkchoiceState {
        head_block_hash: block_hash,
        safe_block_hash: block_hash,
        finalized_block_hash: if l1_finalized { block_hash } else { B256::ZERO },
    }
}

/// Tracks whether any sync target read in this stage fell back to the latest L1 block.
///
/// The read mode is recomputed every tick, and the trigger boundary (a finality lag past the
/// endpoint's retained-state window) sits close to the normal finality lag, so a marginal
/// finality incident would otherwise flap the engine's finalized advertisement tick by tick.
/// Execution clients expect that marking to be monotone — geth's skeleton records a finalized
/// height and never clears it — so once a read degrades, the stage stays degraded.
#[derive(Debug, Default)]
struct TargetReadMode {
    /// Whether any read so far fell back to the latest L1 block. Sticky for the stage's life.
    degraded: bool,
}

impl TargetReadMode {
    /// Record one target read and return whether the engine may still be told the target is
    /// finalized.
    fn observe(&mut self, l1_finalized: bool) -> bool {
        self.degraded |= !l1_finalized;
        !self.degraded
    }
}

/// Drives the L2 execution engine toward the proof-finalized block recorded on L1.
pub struct BeaconSyncer {
    /// Interval between beacon sync retries.
    retry_interval: Duration,
    /// RPC client used for L1 inbox reads and local engine calls.
    rpc: Client,
    /// Optional untrusted provider used to fetch catch-up block bodies.
    checkpoint: Option<RootProvider>,
    /// Shared resume head consumed by event sync after this stage completes.
    checkpoint_resume_head: Arc<CheckpointResumeHead>,
}

impl BeaconSyncer {
    /// Construct a new beacon syncer from the provided configuration and RPC client.
    #[instrument(skip(config, rpc))]
    pub fn new(
        config: &DriverConfig,
        rpc: Client,
        checkpoint_resume_head: Arc<CheckpointResumeHead>,
    ) -> Self {
        let checkpoint =
            config.l2_checkpoint_url.as_ref().map(|url| connect_http_with_timeout(url.clone()));

        Self { retry_interval: config.retry_interval, rpc, checkpoint, checkpoint_resume_head }
    }

    /// Read the proof-finalized sync target from the L1 inbox core state.
    ///
    /// The core state is queried at the finalized L1 block so the returned checkpoint cannot be
    /// reorged away on either layer. Two degraded cases fall back to the latest block instead:
    /// chains without L1 finality yet (fresh devnets), and endpoints that cannot serve state at
    /// the finalized block (non-archive nodes once L1 finality lags beyond their retained-state
    /// window). The target itself stays a proof-finalized proposal recorded on L1 either way;
    /// only the read loses its reorg-proof anchoring, which the returned `l1_finalized` flag
    /// records so checkpoint import can withhold the engine's finalized advertisement.
    #[instrument(skip(self), level = "debug")]
    async fn finalized_sync_target(&self) -> Result<FinalizedSyncTarget, SyncError> {
        let (core_state, l1_finalized) =
            match self
                .rpc
                .shasta
                .inbox
                .getCoreState()
                .block(BlockId::Number(BlockNumberOrTag::Finalized))
                .call()
                .await
            {
                Ok(core_state) => (core_state, true),
                Err(err)
                    if err.to_string().contains(FINALIZED_BLOCK_NOT_FOUND) ||
                        is_historical_state_unavailable(&err.to_string()) =>
                {
                    let message = err.to_string();
                    if is_historical_state_unavailable(&message) {
                        warn!(
                            error = %message,
                            "L1 endpoint cannot serve state at the finalized block; reading the \
                             sync target from the latest core state"
                        );
                    }
                    let core_state =
                        self.rpc.shasta.inbox.getCoreState().call().await.map_err(|err| {
                            SyncError::Rpc(RpcClientError::Provider(err.to_string()))
                        })?;
                    (core_state, false)
                }
                Err(err) => return Err(SyncError::Rpc(RpcClientError::Provider(err.to_string()))),
            };

        Ok(FinalizedSyncTarget {
            proposal_id: core_state.lastFinalizedProposalId.to::<u64>(),
            block_hash: core_state.lastFinalizedBlockHash,
            l1_finalized,
        })
    }

    /// Submit a proof-finalized block body (from either the local store or the checkpoint node)
    /// to the execution engine, starting or advancing the engine's backfill toward it.
    /// `l1_finalized` carries whether the target was read at a finalized L1 block; see
    /// [`checkpoint_forkchoice_state`].
    #[instrument(skip(self, block), level = "debug")]
    async fn submit_target_block(
        &self,
        block: RpcBlock<TxEnvelope>,
        l1_finalized: bool,
    ) -> Result<(), DriverError> {
        let block_number = block.header.number;
        let block_hash = block.hash();
        let tx_root = block.header.transactions_root;
        let header_difficulty = block.header.difficulty;
        let withdrawals_root = block.header.withdrawals_root;
        debug!(block_number, ?block_hash, "submitting checkpoint block to execution engine");

        let consensus_block: Block<TxEnvelope> = block.into();
        let payload_field =
            ExecutionPayloadFieldV2::from_block_unchecked(block_hash, &consensus_block);

        let (execution_payload, withdrawals) = match payload_field {
            ExecutionPayloadFieldV2::V1(v1) => (v1, None),
            ExecutionPayloadFieldV2::V2(v2) => (v2.payload_inner, Some(v2.withdrawals)),
        };

        let payload_input = ExecutionPayloadInputV2 { execution_payload, withdrawals };
        let sidecar = TaikoExecutionDataSidecar {
            tx_hash: tx_root,
            withdrawals_hash: withdrawals_root,
            // Checkpoint import bypasses the local getPayload/newPayload round trip, so preserve
            // the sealed block's header difficulty explicitly in the Taiko sidecar.
            header_difficulty: Some(header_difficulty),
            taiko_block: Some(true),
            block_access_list: None,
            slot_number: None,
        };

        let payload_status = self.rpc.engine_new_payload_v2(&payload_input, &sidecar).await?;
        match payload_status.status {
            PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted => {}
            PayloadStatusEnum::Syncing => {
                info!(
                    block_number,
                    "execution engine reported SYNCING for submitted payload; continuing beacon sync"
                );
            }
            PayloadStatusEnum::Invalid { validation_error } => {
                return Err(DriverError::EngineInvalidPayload(validation_error));
            }
        }

        let forkchoice_state = checkpoint_forkchoice_state(block_hash, l1_finalized);

        let forkchoice = self.rpc.engine_forkchoice_updated_v2(forkchoice_state, None).await?;
        resolve_checkpoint_forkchoice_status(&forkchoice.payload_status.status, block_number)?;

        info!(
            block_number,
            ?block_hash,
            forkchoice_status = ?forkchoice.payload_status.status,
            "checkpoint block submitted"
        );
        Ok(())
    }
}

/// Classify the forkchoice status returned while importing a checkpoint block.
///
/// `SYNCING` means the engine started backfilling toward the submitted head; `VALID` means the
/// head connected to the local chain immediately (small gap or final catch-up tick). Both are
/// successful imports. `INVALID` is a hard rejection, and `ACCEPTED` is never returned by
/// forkchoice updates per the engine API spec.
fn resolve_checkpoint_forkchoice_status(
    status: &PayloadStatusEnum,
    block_number: u64,
) -> Result<(), DriverError> {
    match status {
        PayloadStatusEnum::Valid | PayloadStatusEnum::Syncing => Ok(()),
        PayloadStatusEnum::Invalid { validation_error } => {
            Err(DriverError::EngineInvalidPayload(validation_error.clone()))
        }
        PayloadStatusEnum::Accepted => Err(DriverError::Other(anyhow!(
            "unexpected forkchoice status ACCEPTED for block {block_number}"
        ))),
    }
}

#[async_trait::async_trait]
impl SyncStage for BeaconSyncer {
    /// Run the beacon sync stage, steering the local execution engine toward the proof-finalized
    /// block recorded on L1 until the local canonical chain contains it.
    #[instrument(skip(self), name = "beacon_syncer_run")]
    async fn run(&self) -> Result<(), SyncError> {
        // Always clear stale state from previous attempts so event sync cannot accidentally
        // consume an old checkpoint head after a failed or skipped beacon sync run.
        self.checkpoint_resume_head.clear();

        let Some(checkpoint_provider) = &self.checkpoint else {
            info!("no checkpoint endpoint configured; skipping beacon sync stage");
            return Ok(());
        };

        let poll_interval = if self.retry_interval.is_zero() {
            DEFAULT_BEACON_SYNC_POLL_INTERVAL
        } else {
            self.retry_interval
        };

        let mut ticker = interval(poll_interval);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);

        info!(interval_secs = poll_interval.as_secs(), "beacon sync stage started");

        // Fail-fast gates: each flips once its endpoint has answered successfully, so startup
        // misconfiguration still aborts while mid-catch-up blips retry. The first tick fires
        // immediately, preserving fail-fast timing at startup.
        let mut target_seen_once = false;
        let mut checkpoint_seen_once = false;
        let mut target_read_mode = TargetReadMode::default();

        loop {
            ticker.tick().await;

            let local_head =
                match self.rpc.l2_provider.get_block_number().await.map_err(RpcClientError::from) {
                    Ok(block_id) => {
                        DriverMetrics::beacon_sync_local_head_block().set(block_id as f64);
                        block_id
                    }
                    Err(err) => {
                        warn!(error = %err, "failed to query execution engine head");
                        continue;
                    }
                };

            let target = match self.finalized_sync_target().await {
                Ok(target) => {
                    target_seen_once = true;
                    target
                }
                Err(err) => {
                    let err = super::retryable_after_first_success(target_seen_once, err)?;
                    warn!(error = %err, "failed to read finalized sync target from L1; retrying");
                    continue;
                }
            };
            // Observed here rather than at the submission below, so a degraded read still
            // latches on ticks that bail out before reaching it.
            let advertise_finalized = target_read_mode.observe(target.l1_finalized);

            // A zero hash means the inbox has finalized nothing and recorded no genesis
            // checkpoint yet; event sync will derive everything from the activation block.
            if target.block_hash == B256::ZERO {
                self.checkpoint_resume_head.set(0);
                info!("no proof-finalized checkpoint on L1 yet; skipping checkpoint catch-up");
                break Ok(());
            }

            // Prefer a locally stored body: after a routine restart the target is usually
            // already canonical, and any locally available copy keeps this stage independent
            // of checkpoint availability. Trust comes from hashing to the L1-recorded value,
            // not from the body's source.
            let local_body =
                match self.rpc.l2_provider.get_block_by_hash(target.block_hash).full().await {
                    Ok(block) => {
                        block.map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
                    }
                    Err(err) => {
                        warn!(
                            target_hash = ?target.block_hash,
                            error = %err,
                            "failed to query local engine for the finalized target body; retrying"
                        );
                        continue;
                    }
                };

            let block = match local_body {
                Some(block) => block,
                None => match checkpoint_provider.get_block_by_hash(target.block_hash).full().await
                {
                    Ok(Some(block)) => {
                        checkpoint_seen_once = true;
                        block.map_transactions(|tx: RpcTransaction| tx.into())
                    }
                    Ok(None) => {
                        checkpoint_seen_once = true;
                        warn!(
                            target_proposal_id = target.proposal_id,
                            target_hash = ?target.block_hash,
                            "checkpoint node does not have the finalized target block; retrying"
                        );
                        continue;
                    }
                    Err(err) => {
                        let err = super::retryable_after_first_success(
                            checkpoint_seen_once,
                            SyncError::CheckpointQuery(RpcClientError::from(err)),
                        )?;
                        warn!(
                            error = %err,
                            "failed to fetch finalized target block from checkpoint node; retrying"
                        );
                        continue;
                    }
                },
            };

            // Never trust the body source: it must hash to the L1-recorded value. The engine
            // re-checks this on newPayload, but verifying here keeps a bad source a retryable
            // condition instead of a fatal INVALID.
            if block.header.inner.hash_slow() != target.block_hash {
                warn!(
                    target_proposal_id = target.proposal_id,
                    target_hash = ?target.block_hash,
                    "fetched target block does not hash to the L1 checkpoint; retrying"
                );
                continue;
            }

            let target_block_number = block.header.number;
            DriverMetrics::beacon_sync_checkpoint_head_block().set(target_block_number as f64);
            DriverMetrics::beacon_sync_head_lag_blocks()
                .set(target_block_number.saturating_sub(local_head) as f64);

            // Done once the local canonical chain contains the finalized target. Checking the
            // hash at the target height (rather than comparing heights) also catches a local
            // chain that diverges from the proof-finalized one.
            match self
                .rpc
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(target_block_number))
                .await
            {
                Ok(Some(local_block)) if local_block.header.hash == target.block_hash => {
                    // Persist the finalized block number event sync uses as its authoritative
                    // resume source when checkpoint mode is enabled.
                    self.checkpoint_resume_head.set(target_block_number);
                    info!(
                        target_proposal_id = target.proposal_id,
                        target_block_number,
                        target_hash = ?target.block_hash,
                        local_head,
                        "local engine contains the proof-finalized target; done"
                    );
                    break Ok(());
                }
                Ok(_) => {}
                Err(err) => {
                    warn!(
                        target_block_number,
                        error = %err,
                        "failed to query local block at finalized target height; retrying"
                    );
                    continue;
                }
            }

            info!(
                target_proposal_id = target.proposal_id,
                target_block_number, local_head, "syncing execution engine toward finalized target"
            );

            match self.submit_target_block(block, advertise_finalized).await {
                Ok(()) => DriverMetrics::beacon_sync_remote_submissions_total().inc(),
                // An INVALID verdict is not transient: the block hashes to the L1 checkpoint yet
                // the engine rejects it, which needs operator attention rather than retries.
                Err(err @ DriverError::EngineInvalidPayload(_)) => {
                    return Err(SyncError::RemoteBlockSubmit {
                        block_number: target_block_number,
                        error: err.into(),
                    });
                }
                Err(err) => {
                    warn!(
                        target_block_number,
                        error = %err,
                        "failed to submit finalized target block; retrying"
                    );
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use alloy::primitives::aliases::U48;
    use alloy_primitives::Bytes;
    use alloy_sol_types::SolCall;
    use alloy_transport::mock::Asserter;
    use bindings::inbox::{IInbox::CoreState, Inbox::getCoreStateCall};

    use super::*;
    use crate::test_support::mock_client_with_l1_asserter;

    /// Beacon syncer whose L1 reads replay `asserter`; no checkpoint endpoint is configured.
    fn build_beacon_syncer(asserter: Asserter) -> BeaconSyncer {
        BeaconSyncer {
            retry_interval: Duration::from_secs(1),
            rpc: mock_client_with_l1_asserter(asserter),
            checkpoint: None,
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
        }
    }

    /// Core state whose finalized checkpoint carries the given proposal id and block hash.
    fn core_state_with_finalized(proposal_id: u64, block_hash: B256) -> CoreState {
        CoreState {
            nextProposalId: U48::from(proposal_id + 1),
            lastProposalBlockId: U48::ZERO,
            lastFinalizedProposalId: U48::from(proposal_id),
            lastFinalizedTimestamp: U48::ZERO,
            lastCheckpointTimestamp: U48::ZERO,
            lastFinalizedBlockHash: block_hash,
        }
    }

    #[tokio::test]
    async fn finalized_sync_target_falls_back_to_latest_when_historical_state_unavailable() {
        let asserter = Asserter::new();
        // Path-scheme full nodes only serve ~128 recent blocks of state: when L1 finality lags
        // beyond that window, the finalized-block read fails with a historical-state error and
        // the target must be re-read at the latest block instead of aborting the stage.
        asserter.push_failure_msg("historical state 0xdeadbeef is not available");
        let core_state = core_state_with_finalized(7, B256::from([9u8; 32]));
        asserter.push_success(&Bytes::from(getCoreStateCall::abi_encode_returns(&core_state)));

        let target = build_beacon_syncer(asserter)
            .finalized_sync_target()
            .await
            .expect("historical-state error should fall back to the latest core state");

        assert_eq!(target.proposal_id, 7);
        assert_eq!(target.block_hash, B256::from([9u8; 32]));
        assert!(!target.l1_finalized, "latest-read targets must not claim finalized anchoring");
    }

    #[tokio::test]
    async fn finalized_sync_target_marks_target_finalized_when_read_at_finalized_block() {
        let asserter = Asserter::new();
        let core_state = core_state_with_finalized(5, B256::from([6u8; 32]));
        asserter.push_success(&Bytes::from(getCoreStateCall::abi_encode_returns(&core_state)));

        let target = build_beacon_syncer(asserter)
            .finalized_sync_target()
            .await
            .expect("finalized read should succeed");

        assert_eq!(target.proposal_id, 5);
        assert_eq!(target.block_hash, B256::from([6u8; 32]));
        assert!(target.l1_finalized);
    }

    #[tokio::test]
    async fn finalized_sync_target_falls_back_to_latest_before_first_l1_finality() {
        let asserter = Asserter::new();
        // Fresh devnets report "finalized block not found" until the first finalized epoch;
        // the target is read at the latest block instead.
        asserter.push_failure_msg(FINALIZED_BLOCK_NOT_FOUND);
        let core_state = core_state_with_finalized(3, B256::from([4u8; 32]));
        asserter.push_success(&Bytes::from(getCoreStateCall::abi_encode_returns(&core_state)));

        let target = build_beacon_syncer(asserter)
            .finalized_sync_target()
            .await
            .expect("pre-finality error should fall back to the latest core state");

        assert_eq!(target.proposal_id, 3);
        assert_eq!(target.block_hash, B256::from([4u8; 32]));
        assert!(!target.l1_finalized, "latest-read targets must not claim finalized anchoring");
    }

    #[test]
    fn target_read_mode_latches_degraded_across_later_finalized_reads() {
        let mut mode = TargetReadMode::default();

        // A marginal finality incident straddles the retained-state boundary, so reads alternate.
        assert!(mode.observe(true), "a finalized read may advertise finalized");
        assert!(!mode.observe(false), "a latest-read target must withhold it");
        assert!(
            !mode.observe(true),
            "the engine's finalized marking must stay monotone for the life of the stage, so a \
             recovered read must not re-advertise after a degraded one"
        );
        assert!(!mode.observe(false));
    }

    #[test]
    fn target_read_mode_advertises_finalized_while_every_read_is_finalized() {
        let mut mode = TargetReadMode::default();
        assert!(mode.observe(true));
        assert!(mode.observe(true));
    }

    #[test]
    fn checkpoint_forkchoice_advertises_finalized_target_on_finalized_read() {
        let hash = B256::from([8u8; 32]);
        let state = checkpoint_forkchoice_state(hash, true);
        assert_eq!(state.head_block_hash, hash);
        assert_eq!(state.safe_block_hash, hash);
        assert_eq!(state.finalized_block_hash, hash);
    }

    #[test]
    fn checkpoint_forkchoice_withholds_finalized_for_latest_read_target() {
        let hash = B256::from([8u8; 32]);
        let state = checkpoint_forkchoice_state(hash, false);
        assert_eq!(state.head_block_hash, hash);
        assert_eq!(state.safe_block_hash, hash);
        assert_eq!(state.finalized_block_hash, B256::ZERO);
    }

    #[tokio::test]
    async fn finalized_sync_target_surfaces_unrelated_rpc_errors() {
        let asserter = Asserter::new();
        asserter.push_failure_msg("boom");

        let err = build_beacon_syncer(asserter)
            .finalized_sync_target()
            .await
            .expect_err("unrelated rpc failures must stay fatal");

        assert!(matches!(err, SyncError::Rpc(RpcClientError::Provider(_))));
    }

    #[test]
    fn checkpoint_forkchoice_accepts_syncing_and_valid() {
        assert!(resolve_checkpoint_forkchoice_status(&PayloadStatusEnum::Syncing, 7).is_ok());
        assert!(resolve_checkpoint_forkchoice_status(&PayloadStatusEnum::Valid, 7).is_ok());
    }

    #[test]
    fn checkpoint_forkchoice_rejects_invalid_with_engine_error() {
        let status = PayloadStatusEnum::Invalid { validation_error: "bad state root".into() };
        assert!(matches!(
            resolve_checkpoint_forkchoice_status(&status, 7),
            Err(DriverError::EngineInvalidPayload(message)) if message == "bad state root"
        ));
    }

    #[test]
    fn checkpoint_forkchoice_rejects_accepted_as_unexpected() {
        assert!(resolve_checkpoint_forkchoice_status(&PayloadStatusEnum::Accepted, 7).is_err());
    }
}
