//! Beacon sync logic.

use std::{borrow::Cow, marker::PhantomData, time::Duration};

use alethia_reth_primitives::engine::types::TaikoExecutionDataSidecar;
use alloy::providers::Provider;
use alloy_consensus::{self, Block, TxEnvelope};
use alloy_eips::BlockNumberOrTag;
use alloy_provider::{ProviderBuilder, RootProvider};
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState, PayloadStatusEnum,
};
use anyhow::anyhow;
use metrics::{counter, gauge};
use rpc::{client::Client, error::RpcClientError, l1_origin::L1Origin};
use tokio::time::{MissedTickBehavior, interval};
use tracing::{debug, info, instrument, warn};

use super::{SyncError, SyncStage};
use crate::{config::DriverConfig, error::DriverError, metrics::DriverMetrics};

/// Default polling interval used when no retry interval is configured.
const DEFAULT_BEACON_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(12);

/// Handles triggering beacon syncs when the L2 execution engine lags behind the protocol head.
pub struct BeaconSyncer<P>
where
    P: Provider + Clone,
{
    retry_interval: Duration,
    rpc: Client<P>,
    checkpoint: Option<RootProvider>,
    _marker: PhantomData<P>,
}

impl<P> BeaconSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new beacon syncer from the provided configuration and RPC client.
    #[instrument(skip(config, rpc))]
    pub fn new(config: &DriverConfig, rpc: Client<P>) -> Self {
        let checkpoint = config
            .l2_checkpoint_url
            .as_ref()
            .map(|url| ProviderBuilder::default().connect_http(url.clone()));

        Self { retry_interval: config.retry_interval, rpc, checkpoint, _marker: PhantomData }
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
        if forkchoice.payload_status.status != PayloadStatusEnum::Syncing {
            return Err(DriverError::Other(anyhow!(
                "unexpected forkchoice status {:?} for block {}",
                forkchoice.payload_status.status,
                block_number
            )));
        }

        info!(block_number, ?block_hash, "checkpoint block submitted");
        Ok(())
    }
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
        // If no checkpoint endpoint is configured, skip this stage.
        if self.checkpoint.is_none() {
            debug!("skipping beacon sync stage; checkpoint endpoint not configured");
            info!("no checkpoint endpoint configured; skip beacon sync stage");
            return Ok(());
        }

        // If the checkpoint node has no L1 origin, we cannot proceed.
        let Some(mut checkpoint_head) =
            self.checkpoint_head().await.map_err(SyncError::CheckpointQuery)?
        else {
            return Err(SyncError::CheckpointNoOrigin);
        };

        gauge!(DriverMetrics::BEACON_SYNC_CHECKPOINT_HEAD_BLOCK).set(checkpoint_head as f64);
        info!(?checkpoint_head, "initial checkpoint head");
        debug!(?checkpoint_head, "fetched initial checkpoint head");

        let poll_interval = if self.retry_interval.is_zero() {
            DEFAULT_BEACON_SYNC_POLL_INTERVAL
        } else {
            self.retry_interval
        };

        let mut ticker = interval(poll_interval);
        // Use MissedTickBehavior::Skip to prevent tick accumulation during slow operations.
        // This ensures that if the sync loop is delayed, we do not process multiple ticks at once.
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);

        info!(interval_secs = poll_interval.as_secs(), "beacon sync stage started");
        debug!(interval_secs = poll_interval.as_secs(), "beacon sync ticker initialised");

        loop {
            ticker.tick().await;

            let local_head =
                match self.rpc.l2_provider.get_block_number().await.map_err(RpcClientError::from) {
                    Ok(block_id) => {
                        gauge!(DriverMetrics::BEACON_SYNC_LOCAL_HEAD_BLOCK).set(block_id as f64);
                        block_id
                    }
                    Err(err) => {
                        warn!(error = %err, "failed to query execution engine head");
                        continue;
                    }
                };

            checkpoint_head = self
                .checkpoint_head()
                .await
                .map_err(SyncError::CheckpointQuery)?
                .ok_or(SyncError::CheckpointNoOrigin)?;
            gauge!(DriverMetrics::BEACON_SYNC_CHECKPOINT_HEAD_BLOCK).set(checkpoint_head as f64);
            gauge!(DriverMetrics::BEACON_SYNC_HEAD_LAG_BLOCKS)
                .set(checkpoint_head.saturating_sub(local_head) as f64);

            if checkpoint_head > local_head {
                info!(
                    checkpoint_head,
                    local_head, "checkpoint head ahead of local engine; attempting to sync"
                );
                debug!(checkpoint_head, local_head, "attempting remote block submission");
                let checkpoint_provider =
                    self.checkpoint.as_ref().ok_or(SyncError::CheckpointNoOrigin)?;

                let block = checkpoint_provider
                    .get_block_by_number(BlockNumberOrTag::Number(checkpoint_head))
                    .full()
                    .await
                    .map_err(RpcClientError::from)
                    .map_err(|err| SyncError::RemoteBlockSubmit {
                        block_number: checkpoint_head,
                        error: DriverError::from(err).into(),
                    })?
                    .ok_or_else(|| SyncError::RemoteBlockSubmit {
                        block_number: checkpoint_head,
                        error: DriverError::BlockNotFound(checkpoint_head).into(),
                    })?
                    .map_transactions(|tx: RpcTransaction| tx.into());

                self.submit_remote_block(block).await.map_err(|err| {
                    SyncError::RemoteBlockSubmit {
                        block_number: checkpoint_head,
                        error: err.into(),
                    }
                })?;
                counter!(DriverMetrics::BEACON_SYNC_REMOTE_SUBMISSIONS_TOTAL).increment(1);
            } else {
                info!(
                    checkpoint_head,
                    local_head, "local engine at or ahead of checkpoint head; no action needed"
                );
                debug!(checkpoint_head, local_head, "beacon sync up to date");
                break Ok(());
            }
        }
    }
}
