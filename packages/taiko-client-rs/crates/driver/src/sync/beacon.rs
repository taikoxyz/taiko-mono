//! Beacon sync logic.

use std::{borrow::Cow, marker::PhantomData, time::Duration};

use alloy::{primitives::B256, providers::Provider};
use alloy_consensus::{self, TxEnvelope};
use alloy_eips::BlockNumberOrTag;
use alloy_provider::{ProviderBuilder, RootProvider};
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState, ForkchoiceUpdated,
    PayloadStatusEnum,
};
use metrics::gauge;
use rpc::{auth::L1Origin, client::Client};
use tokio::time::{MissedTickBehavior, interval};
use tracing::{info, warn};

use super::{SyncError, SyncStage};
use crate::{config::DriverConfig, error::DriverError, metrics::DriverMetrics};

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
    pub fn new(config: &DriverConfig, rpc: Client<P>) -> Self {
        let checkpoint = config
            .l2_checkpoint_url
            .as_ref()
            .map(|url| ProviderBuilder::default().connect_http(url.clone()));

        Self { retry_interval: config.retry_interval, rpc, checkpoint, _marker: PhantomData }
    }

    /// Query the checkpoint node for its head L1 origin block number.
    async fn checkpoint_head(&self) -> Result<Option<u64>, DriverError> {
        let Some(provider) = &self.checkpoint else {
            return Ok(None);
        };

        let response: Option<L1Origin> = provider
            .raw_request(Cow::Borrowed("taiko_headL1Origin"), ())
            .await
            .map_err(|err| SyncError::Rpc(err.to_string()))?;

        Ok(response.map(|origin| origin.block_id.to::<u64>()))
    }

    /// Submit a block from the checkpoint node to the local execution engine, to start
    /// a beacon sync.
    async fn submit_remote_block(
        &self,
        provider: &RootProvider,
        block_number: u64,
    ) -> Result<(), DriverError> {
        let block = provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map_err(|err| SyncError::Rpc(err.to_string()))?;

        let Some(block) = block else {
            return Err(DriverError::BlockNotFound(block_number));
        };

        let consensus_block: alloy_consensus::Block<TxEnvelope> = block.clone().into();
        let payload_field =
            ExecutionPayloadFieldV2::from_block_unchecked(block.hash(), &consensus_block);

        let (execution_payload, withdrawals) = match payload_field {
            ExecutionPayloadFieldV2::V1(v1) => (v1, None),
            ExecutionPayloadFieldV2::V2(v2) => (v2.payload_inner, Some(v2.withdrawals)),
        };

        let payload_input = ExecutionPayloadInputV2 { execution_payload, withdrawals };

        let payload_status = self
            .rpc
            .engine_new_payload_v2(payload_input, Vec::<B256>::new(), None)
            .await
            .map_err(|err| SyncError::Rpc(err.to_string()))?;

        match payload_status.status {
            PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted => {}
            PayloadStatusEnum::Syncing => {
                return Err(DriverError::EngineSyncing(block_number));
            }
            PayloadStatusEnum::Invalid { validation_error } => {
                return Err(DriverError::EngineInvalidPayload(validation_error));
            }
        }

        let forkchoice_state = ForkchoiceState {
            head_block_hash: block.hash(),
            safe_block_hash: block.hash(),
            finalized_block_hash: block.header.parent_hash,
        };

        let _: ForkchoiceUpdated = self
            .rpc
            .engine_forkchoice_updated_v2(forkchoice_state, None)
            .await
            .map_err(|err| SyncError::Rpc(err.to_string()))?;

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
    async fn run(&self) -> Result<(), SyncError> {
        // If no checkpoint endpoint is configured, skip this stage.
        if self.checkpoint.is_none() {
            info!("no checkpoint endpoint configured; skip beacon sync stage");
            return Ok(());
        }

        // If the checkpoint node has no L1 origin, we cannot proceed.
        let Some(mut checkpoint_head) = self
            .checkpoint_head()
            .await
            .map_err(|err| SyncError::CheckpointQuery(err.to_string()))?
        else {
            return Err(SyncError::CheckpointNoOrigin);
        };

        info!(?checkpoint_head, "initial checkpoint head");

        let poll_interval = if self.retry_interval.is_zero() {
            Duration::from_secs(12)
        } else {
            self.retry_interval
        };

        let mut ticker = interval(poll_interval);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);

        info!(interval_secs = poll_interval.as_secs(), "beacon sync stage started");

        loop {
            ticker.tick().await;

            let local_head = match self.rpc.l2_provider.get_block_number().await {
                Ok(block_id) => {
                    gauge!(DriverMetrics::BEACON_HEAD_BLOCK_ID).set(block_id as f64);
                    block_id
                }
                Err(err) => {
                    warn!(?err, "failed to query execution engine head");
                    continue;
                }
            };

            checkpoint_head = self
                .checkpoint_head()
                .await
                .map_err(|err| SyncError::CheckpointQuery(err.to_string()))?
                .ok_or(SyncError::CheckpointNoOrigin)?;

            if checkpoint_head > local_head {
                info!(
                    checkpoint_head,
                    local_head, "checkpoint head ahead of local engine; attempting to sync"
                );
                self.submit_remote_block(&self.rpc.l2_auth_provider, checkpoint_head)
                    .await
                    .map_err(|err| SyncError::RemoteBlockSubmit {
                        block_number: checkpoint_head,
                        error: err.to_string(),
                    })?;
            } else {
                info!(
                    checkpoint_head,
                    local_head, "local engine at or ahead of checkpoint head; no action needed"
                );
                break Ok(());
            }
        }
    }
}
