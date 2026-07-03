//! Beacon sync logic.

use std::{borrow::Cow, sync::Arc, time::Duration};

use alethia_reth_primitives::engine::types::TaikoExecutionDataSidecar;
use alloy::providers::Provider;
use alloy_consensus::{self, Block, TxEnvelope};
use alloy_eips::BlockNumberOrTag;
use alloy_provider::RootProvider;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState, PayloadStatusEnum,
};
use anyhow::anyhow;
use rpc::{
    client::{Client, connect_http_with_timeout},
    error::RpcClientError,
    l1_origin::L1Origin,
};
use tokio::time::{MissedTickBehavior, interval};
use tracing::{debug, info, instrument, warn};

use super::{SyncError, SyncStage, checkpoint_resume_head::CheckpointResumeHead};
use crate::{config::DriverConfig, error::DriverError, metrics::DriverMetrics};

/// Default polling interval used when no retry interval is configured.
const DEFAULT_BEACON_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(12);

/// Handles triggering beacon syncs when the L2 execution engine lags behind the protocol head.
pub struct BeaconSyncer<P>
where
    P: Provider + Clone,
{
    /// Interval between beacon sync retries.
    retry_interval: Duration,
    /// RPC client used for local node engine and chain calls.
    rpc: Client<P>,
    /// Optional checkpoint provider used for remote catch-up blocks.
    checkpoint: Option<RootProvider>,
    /// Shared checkpoint head used to resume event sync after beacon sync.
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

    /// Query the checkpoint node for its head L1 origin block number.
    #[instrument(skip(self), level = "debug")]
    async fn checkpoint_head(&self) -> Result<Option<u64>, RpcClientError> {
        let Some(provider) = &self.checkpoint else {
            debug!("checkpoint provider not configured");
            return Ok(None);
        };

        let response: Option<L1Origin> = provider
            .raw_request(Cow::Borrowed("taiko_headL1Origin"), ())
            .await
            .map_err(RpcClientError::from)?;

        let head = response.map(|origin| origin.block_id.to::<u64>());
        debug!(?head, "queried checkpoint head");
        Ok(head)
    }

    /// Submit a block from the checkpoint node to the local execution engine, to start
    /// a beacon sync.
    #[instrument(skip(self, block), level = "debug")]
    async fn submit_remote_block(&self, block: RpcBlock<TxEnvelope>) -> Result<(), DriverError> {
        let block_number = block.header.number;
        let block_hash = block.hash();
        let tx_root = block.header.transactions_root;
        let header_difficulty = block.header.difficulty;
        let parent_hash = block.header.parent_hash;
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

        let forkchoice_state = ForkchoiceState {
            head_block_hash: block_hash,
            safe_block_hash: block_hash,
            finalized_block_hash: parent_hash,
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

/// Convert a checkpoint poll failure into either a fatal startup error or a retryable error.
///
/// Before the checkpoint node has answered successfully, poll failures indicate a misconfigured
/// or unreachable checkpoint endpoint and must fail fast. After the first successful answer the
/// same failures are transient, so the caller logs the returned error and retries on the next
/// tick instead of aborting a potentially hours-long catch-up.
fn resolve_checkpoint_poll_error(
    checkpoint_seen_once: bool,
    error: SyncError,
) -> Result<SyncError, SyncError> {
    if checkpoint_seen_once { Ok(error) } else { Err(error) }
}

#[async_trait::async_trait]
impl<P> SyncStage for BeaconSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Run the beacon sync stage, periodically checking the checkpoint node and submitting
    /// missing blocks to the local execution engine.
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

        // Flips once the checkpoint node has reported a head, gating fail-fast startup errors
        // from retryable mid-catch-up errors. The first tick fires immediately, so a
        // misconfigured endpoint still fails at startup.
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

            let checkpoint_head = match self.checkpoint_head().await {
                Ok(Some(head)) => {
                    checkpoint_seen_once = true;
                    head
                }
                Ok(None) => {
                    let err = resolve_checkpoint_poll_error(
                        checkpoint_seen_once,
                        SyncError::CheckpointNoOrigin,
                    )?;
                    warn!(error = %err, "checkpoint node reported no L1 origin; retrying");
                    continue;
                }
                Err(err) => {
                    let err = resolve_checkpoint_poll_error(
                        checkpoint_seen_once,
                        SyncError::CheckpointQuery(err),
                    )?;
                    warn!(error = %err, "failed to query checkpoint head; retrying");
                    continue;
                }
            };
            DriverMetrics::beacon_sync_checkpoint_head_block().set(checkpoint_head as f64);
            DriverMetrics::beacon_sync_head_lag_blocks()
                .set(checkpoint_head.saturating_sub(local_head) as f64);

            if checkpoint_head <= local_head {
                // Persist the checkpoint head we have confirmed local execution is synced to.
                // Event sync uses this exact value as its authoritative resume source when
                // checkpoint mode is enabled.
                self.checkpoint_resume_head.set(checkpoint_head);
                info!(checkpoint_head, local_head, "local engine at or ahead of checkpoint; done");
                break Ok(());
            }

            info!(checkpoint_head, local_head, "checkpoint head ahead of local engine; syncing");

            let block = match checkpoint_provider
                .get_block_by_number(BlockNumberOrTag::Number(checkpoint_head))
                .full()
                .await
            {
                Ok(Some(block)) => block.map_transactions(|tx: RpcTransaction| tx.into()),
                Ok(None) => {
                    warn!(checkpoint_head, "checkpoint node missing its own head block; retrying");
                    continue;
                }
                Err(err) => {
                    warn!(
                        checkpoint_head,
                        error = %err,
                        "failed to fetch checkpoint head block; retrying"
                    );
                    continue;
                }
            };

            match self.submit_remote_block(block).await {
                Ok(()) => DriverMetrics::beacon_sync_remote_submissions_total().inc(),
                // An INVALID verdict is not transient: the checkpoint served a block the local
                // engine rejects, which needs operator attention rather than retries.
                Err(err @ DriverError::EngineInvalidPayload(_)) => {
                    return Err(SyncError::RemoteBlockSubmit {
                        block_number: checkpoint_head,
                        error: err.into(),
                    });
                }
                Err(err) => {
                    warn!(
                        checkpoint_head,
                        error = %err,
                        "failed to submit checkpoint block; retrying"
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
        assert!(matches!(
            resolve_checkpoint_poll_error(false, SyncError::CheckpointNoOrigin),
            Err(SyncError::CheckpointNoOrigin)
        ));
        assert!(matches!(
            resolve_checkpoint_poll_error(true, SyncError::CheckpointNoOrigin),
            Ok(SyncError::CheckpointNoOrigin)
        ));
    }
}
