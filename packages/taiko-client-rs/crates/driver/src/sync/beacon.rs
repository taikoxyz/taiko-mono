//! Beacon sync logic.

use std::{borrow::Cow, marker::PhantomData, time::Duration};

use alloy::{
    primitives::B256,
    providers::Provider,
    rpc::types::{Block, Transaction},
};
use alloy_consensus::{self, TxEnvelope};
use alloy_provider::{ProviderBuilder, RootProvider};
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState, ForkchoiceUpdated,
    PayloadAttributes, PayloadStatus, PayloadStatusEnum,
};
use metrics::gauge;
use tokio::time::{MissedTickBehavior, interval};
use tracing::{debug, info, warn};

use super::{SyncError, SyncStage};
use crate::{config::DriverConfig, error::DriverError, metrics::DriverMetrics};

/// Handles triggering beacon syncs when the execution engine lags behind the protocol head.
pub struct BeaconSyncer<P>
where
    P: Provider + Clone,
{
    retry_interval: Duration,
    rpc: rpc::client::Client<P>,
    checkpoint: Option<RootProvider>,
    _marker: PhantomData<P>,
}

impl<P> BeaconSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    pub fn new(config: &DriverConfig, rpc: rpc::client::Client<P>) -> Self {
        let checkpoint = config
            .l2_checkpoint_url
            .as_ref()
            .map(|url| ProviderBuilder::default().connect_http(url.clone()));

        Self { retry_interval: config.retry_interval, rpc, checkpoint, _marker: PhantomData }
    }

    async fn check_head(&self) -> Result<Option<u64>, DriverError> {
        match self.rpc.head_l1_origin().await? {
            Some(origin) => {
                let block_id = origin.block_id.to::<u64>();
                info!(block_id, "execution engine head l1 origin");
                Ok(Some(block_id))
            }
            None => {
                debug!("execution engine does not expose head_l1_origin yet");
                Ok(None)
            }
        }
    }

    async fn checkpoint_head(&self) -> Result<Option<u64>, DriverError> {
        let Some(provider) = &self.checkpoint else {
            return Ok(None);
        };

        let response: Option<rpc::auth::L1Origin> = provider
            .raw_request(Cow::Borrowed("taiko_headL1Origin"), ())
            .await
            .map_err(|err| DriverError::Other(anyhow::Error::msg(err.to_string())))?;

        Ok(response.map(|origin| origin.block_id.to::<u64>()))
    }

    async fn submit_remote_block(
        &self,
        provider: &RootProvider,
        block_number: u64,
    ) -> Result<(), DriverError> {
        let block: Option<Block<Transaction>> = provider
            .raw_request(
                Cow::Borrowed("eth_getBlockByNumber"),
                (format!("0x{block_number:x}"), true),
            )
            .await
            .map_err(|err| DriverError::Other(anyhow::Error::msg(err.to_string())))?;

        let Some(block) = block else {
            return Err(DriverError::Other(anyhow::anyhow!(
                "checkpoint node missing block {block_number}"
            )));
        };

        let consensus_block: alloy_consensus::Block<TxEnvelope> = block.clone().into();
        let payload_field =
            ExecutionPayloadFieldV2::from_block_unchecked(block.hash(), &consensus_block);

        let (execution_payload, withdrawals) = match payload_field {
            ExecutionPayloadFieldV2::V1(v1) => (v1, None),
            ExecutionPayloadFieldV2::V2(v2) => (v2.payload_inner, Some(v2.withdrawals)),
        };

        let payload_input = ExecutionPayloadInputV2 { execution_payload, withdrawals };

        let payload_status: PayloadStatus = self
            .rpc
            .l2_auth_provider
            .raw_request(
                Cow::Borrowed("engine_newPayloadV2"),
                (payload_input, Vec::<B256>::new(), None::<B256>),
            )
            .await
            .map_err(|err| DriverError::Other(anyhow::Error::msg(err.to_string())))?;

        match payload_status.status {
            PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted => {}
            PayloadStatusEnum::Syncing => {
                return Err(DriverError::Other(anyhow::anyhow!(
                    "engine_newPayloadV2 returned SYNCING for block {block_number}"
                )));
            }
            PayloadStatusEnum::Invalid { validation_error } => {
                return Err(DriverError::Other(anyhow::anyhow!(
                    "checkpoint payload invalid: {validation_error}"
                )));
            }
        }

        let forkchoice_state = ForkchoiceState {
            head_block_hash: block.hash(),
            safe_block_hash: block.hash(),
            finalized_block_hash: block.header.parent_hash,
        };

        let _: ForkchoiceUpdated = self
            .rpc
            .l2_auth_provider
            .raw_request(
                Cow::Borrowed("engine_forkchoiceUpdatedV2"),
                (forkchoice_state, Option::<PayloadAttributes>::None),
            )
            .await
            .map_err(|err| DriverError::Other(anyhow::Error::msg(err.to_string())))?;

        Ok(())
    }
}

#[async_trait::async_trait]
impl<P> SyncStage for BeaconSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn run(&self) -> Result<(), SyncError> {
        let poll_interval = if self.retry_interval.is_zero() {
            Duration::from_secs(5)
        } else {
            self.retry_interval
        };

        let mut ticker = interval(poll_interval);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);

        info!(interval_secs = poll_interval.as_secs(), "beacon sync stage started");

        loop {
            ticker.tick().await;

            let local_head = match self.check_head().await {
                Ok(Some(block_id)) => {
                    gauge!(DriverMetrics::BEACON_HEAD_BLOCK_ID).set(block_id as f64);
                    Some(block_id)
                }
                Ok(None) => None,
                Err(err) => {
                    warn!(?err, "failed to query execution engine head");
                    None
                }
            };

            match self.checkpoint_head().await {
                Ok(Some(remote)) => match local_head {
                    Some(local) if remote > local => {
                        if let Some(provider) = &self.checkpoint {
                            for block_number in (local + 1)..=remote {
                                if let Err(err) =
                                    self.submit_remote_block(provider, block_number).await
                                {
                                    warn!(block_number, ?err, "failed to ingest checkpoint block");
                                    break;
                                } else {
                                    info!(
                                        block_number,
                                        "ingested checkpoint block via beacon sync"
                                    );
                                }
                            }
                        } else {
                            warn!(remote, local, "checkpoint head ahead but no provider available");
                        }
                    }
                    None => {
                        info!(remote, "checkpoint head observed while local engine has no origin");
                    }
                    _ => {}
                },
                Ok(None) => {}
                Err(err) => warn!(?err, "failed to query checkpoint execution engine"),
            }
        }
    }
}
