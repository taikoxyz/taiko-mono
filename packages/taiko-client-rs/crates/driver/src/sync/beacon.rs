//! Checkpoint-assisted execution engine sync toward the proof-finalized L2 block.
//!
//! The sync target is read trustlessly from the L1 inbox core state
//! (`lastFinalizedProposalId` / `lastFinalizedBlockHash`) at the finalized L1 block, so the
//! target is final on both layers. The optional checkpoint node only serves block bodies:
//! every fetched block is verified against the L1-recorded hash before submission, and the
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
}

/// Drives the L2 execution engine toward the proof-finalized block recorded on L1.
pub struct BeaconSyncer<P>
where
    P: Provider + Clone,
{
    /// Interval between beacon sync retries.
    retry_interval: Duration,
    /// RPC client used for L1 inbox reads and local engine calls.
    rpc: Client<P>,
    /// Optional untrusted provider used to fetch catch-up block bodies.
    checkpoint: Option<RootProvider>,
    /// Shared resume head consumed by event sync after this stage completes.
    checkpoint_resume_head: Arc<CheckpointResumeHead>,
}

impl<P> BeaconSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new beacon syncer from the provided configuration and RPC client.
    #[instrument(skip(config, rpc))]
    pub fn new(
        config: &DriverConfig,
        rpc: Client<P>,
        checkpoint_resume_head: Arc<CheckpointResumeHead>,
    ) -> Self {
        let checkpoint =
            config.l2_checkpoint_url.as_ref().map(|url| connect_http_with_timeout(url.clone()));

        Self { retry_interval: config.retry_interval, rpc, checkpoint, checkpoint_resume_head }
    }

    /// Read the proof-finalized sync target from the L1 inbox core state.
    ///
    /// The core state is queried at the finalized L1 block so the returned checkpoint cannot be
    /// reorged away on either layer. Chains without L1 finality yet (fresh devnets) fall back to
    /// the latest block.
    #[instrument(skip(self), level = "debug")]
    async fn finalized_sync_target(&self) -> Result<FinalizedSyncTarget, SyncError> {
        let core_state = match self
            .rpc
            .shasta
            .inbox
            .getCoreState()
            .block(BlockId::Number(BlockNumberOrTag::Finalized))
            .call()
            .await
        {
            Ok(core_state) => core_state,
            Err(err) if err.to_string().contains(FINALIZED_BLOCK_NOT_FOUND) => self
                .rpc
                .shasta
                .inbox
                .getCoreState()
                .call()
                .await
                .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?,
            Err(err) => return Err(SyncError::Rpc(RpcClientError::Provider(err.to_string()))),
        };

        Ok(FinalizedSyncTarget {
            proposal_id: core_state.lastFinalizedProposalId.to::<u64>(),
            block_hash: core_state.lastFinalizedBlockHash,
        })
    }

    /// Submit a proof-finalized block body to the local execution engine, starting or advancing
    /// the engine's backfill toward it.
    #[instrument(skip(self, block), level = "debug")]
    async fn submit_remote_block(&self, block: RpcBlock<TxEnvelope>) -> Result<(), DriverError> {
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

        // The submitted block is proof-finalized on L1 and read at a finalized L1 block, so
        // advertising it as finalized to the engine is sound.
        let forkchoice_state = ForkchoiceState {
            head_block_hash: block_hash,
            safe_block_hash: block_hash,
            finalized_block_hash: block_hash,
        };

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

/// Convert a beacon-sync poll failure (L1 target read or checkpoint block fetch) into either a
/// fatal startup error or a retryable error.
///
/// Before the polled endpoint has answered successfully, failures indicate a misconfigured or
/// unreachable endpoint and must fail fast. After the first successful answer the same failures
/// are transient, so the caller logs the returned error and retries on the next tick instead of
/// aborting a potentially hours-long catch-up.
fn resolve_checkpoint_poll_error(
    seen_once: bool,
    error: SyncError,
) -> Result<SyncError, SyncError> {
    if seen_once { Ok(error) } else { Err(error) }
}

#[async_trait::async_trait]
impl<P> SyncStage for BeaconSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
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
                    let err = resolve_checkpoint_poll_error(target_seen_once, err)?;
                    warn!(error = %err, "failed to read finalized sync target from L1; retrying");
                    continue;
                }
            };

            // A zero hash means the inbox has finalized nothing and recorded no genesis
            // checkpoint yet; event sync will derive everything from the activation block.
            if target.block_hash == B256::ZERO {
                self.checkpoint_resume_head.set(0);
                info!("no proof-finalized checkpoint on L1 yet; skipping checkpoint catch-up");
                break Ok(());
            }

            let block = match checkpoint_provider.get_block_by_hash(target.block_hash).full().await
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
                    let err = resolve_checkpoint_poll_error(
                        checkpoint_seen_once,
                        SyncError::CheckpointQuery(RpcClientError::from(err)),
                    )?;
                    warn!(
                        error = %err,
                        "failed to fetch finalized target block from checkpoint node; retrying"
                    );
                    continue;
                }
            };

            // Never trust the checkpoint response: the body must hash to the L1-recorded value.
            // The engine re-checks this on newPayload, but verifying here keeps a lying
            // checkpoint node a retryable condition instead of a fatal INVALID.
            if block.header.inner.hash_slow() != target.block_hash {
                warn!(
                    target_proposal_id = target.proposal_id,
                    target_hash = ?target.block_hash,
                    "checkpoint node returned a block that does not hash to the L1 checkpoint; retrying"
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

            match self.submit_remote_block(block).await {
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
    use super::*;

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

    #[test]
    fn checkpoint_poll_errors_fail_fast_only_before_first_success() {
        let sample = || SyncError::CheckpointQuery(RpcClientError::Provider("unreachable".into()));
        assert!(matches!(
            resolve_checkpoint_poll_error(false, sample()),
            Err(SyncError::CheckpointQuery(_))
        ));
        assert!(matches!(
            resolve_checkpoint_poll_error(true, sample()),
            Ok(SyncError::CheckpointQuery(_))
        ));
    }
}
