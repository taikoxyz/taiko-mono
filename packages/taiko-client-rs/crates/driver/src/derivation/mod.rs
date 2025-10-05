//! Derivation pipeline abstractions shared across protocol forks.

use std::{borrow::Cow, sync::Arc};

use alloy::{
    primitives::{B256, U256},
    providers::Provider,
};
use alloy_consensus::{self, TxEnvelope};
use alloy_rpc_types::BlockNumberOrTag;
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState, ForkchoiceUpdated,
    PayloadAttributes, PayloadStatus, PayloadStatusEnum,
};
use async_trait::async_trait;
use event_indexer::indexer::ProposedEventPayload;
use metrics::gauge;
use thiserror::Error;
use tracing::{debug, info, warn};

use crate::metrics::DriverMetrics;
use manifest::{ManifestError, ManifestFetcher};
use rpc::blob::BlobDataError;

pub mod manifest;

/// Errors emitted by derivation stages.
#[derive(Debug, Error)]
pub enum DerivationError {
    /// RPC failure while talking to the execution engine.
    #[error(transparent)]
    Rpc(#[from] rpc::error::RpcClientError),
    /// The required L2 block has not been produced yet.
    #[error("l2 block {0} not yet available")]
    BlockUnavailable(u64),
    /// Missing metadata required to finalise the proposal.
    #[error("proposal metadata incomplete for id {0}")]
    IncompleteMetadata(u64),
    /// Generic error bucket.
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

/// Outcome of a derivation step for observability.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DerivationOutcome {
    /// Proposal was successfully applied to the execution engine.
    Applied { proposal_id: u64 },
    /// Proposal was skipped because it was already imported.
    Skipped { proposal_id: u64 },
    /// Proposal needs to wait for additional data (typically the L2 block or blob sidecar).
    Pending { proposal_id: u64 },
}

/// Trait implemented by derivation pipelines for different protocol forks.
#[async_trait]
pub trait DerivationPipeline: Send + Sync {
    /// Process the provided proposal payload, updating the execution engine state as needed.
    async fn process_proposal(
        &self,
        payload: &ProposedEventPayload,
    ) -> Result<DerivationOutcome, DerivationError>;
}

/// Shasta-specific derivation pipeline.
pub struct ShastaDerivationPipeline<P>
where
    P: Provider + Clone,
{
    rpc: rpc::client::Client<P>,
    manifest_fetcher: Arc<dyn ManifestFetcher>,
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone,
{
    /// Create a new derivation pipeline instance.
    pub fn new(rpc: rpc::client::Client<P>, manifest_fetcher: Arc<dyn ManifestFetcher>) -> Self {
        Self { rpc, manifest_fetcher }
    }

    async fn update_l1_origin(
        &self,
        proposal_id: u64,
        l2_block_hash: B256,
        l1_block_height: Option<u64>,
        l1_block_hash: Option<B256>,
        is_forced_inclusion: bool,
    ) -> Result<(), DerivationError> {
        use rpc::auth::L1Origin;

        let origin = L1Origin {
            block_id: U256::from(proposal_id),
            l2_block_hash,
            l1_block_height: l1_block_height.map(U256::from),
            l1_block_hash,
            build_payload_args_id: [0u8; 8],
            is_forced_inclusion,
            signature: [0u8; 65],
        };

        self.rpc.update_l1_origin(&origin).await?;
        self.rpc.set_head_l1_origin(U256::from(proposal_id)).await?;
        self.rpc.set_batch_to_last_block(U256::from(proposal_id), U256::from(proposal_id)).await?;

        Ok(())
    }
}

#[async_trait]
impl<P> DerivationPipeline for ShastaDerivationPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn process_proposal(
        &self,
        payload: &ProposedEventPayload,
    ) -> Result<DerivationOutcome, DerivationError> {
        let proposal_id = payload.proposal.id.to::<u64>();

        // Ignore the genesis proposal.
        if proposal_id == 0 {
            return Ok(DerivationOutcome::Skipped { proposal_id });
        }

        let block = match self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(proposal_id))
            .await
            .map_err(|err| DerivationError::Other(anyhow::Error::msg(err.to_string())))?
        {
            Some(block) => block,
            None => return Ok(DerivationOutcome::Pending { proposal_id }),
        };

        for (idx, _) in payload.derivation.sources.iter().enumerate() {
            match self.manifest_fetcher.fetch_manifest(payload, idx).await {
                Ok(manifest) => {
                    debug!(index = idx, blocks = manifest.blocks.len(), "decoded shasta manifest");
                }
                Err(ManifestError::Blob(BlobDataError::NotConfigured)) => {
                    debug!(index = idx, "blob source not configured; skipping manifest fetch");
                }
                Err(err) => {
                    warn!(index = idx, ?err, "failed to fetch shasta manifest");
                }
            }
        }

        let consensus_block: alloy_consensus::Block<TxEnvelope> = block.clone().into();
        let payload_field =
            ExecutionPayloadFieldV2::from_block_unchecked(block.hash(), &consensus_block);

        let (execution_payload, withdrawals) = match payload_field {
            ExecutionPayloadFieldV2::V1(v1) => (v1, None),
            ExecutionPayloadFieldV2::V2(v2) => (v2.payload_inner, Some(v2.withdrawals)),
        };

        let payload_input = ExecutionPayloadInputV2 { execution_payload, withdrawals };

        let versioned_hashes: Vec<B256> = Vec::new();
        let payload_status: PayloadStatus = self
            .rpc
            .l2_auth_provider
            .raw_request(
                Cow::Borrowed("engine_newPayloadV2"),
                (payload_input, versioned_hashes, None::<B256>),
            )
            .await
            .map_err(|err| DerivationError::Other(anyhow::Error::msg(err.to_string())))?;

        match payload_status.status {
            PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted => {}
            PayloadStatusEnum::Syncing => {
                return Ok(DerivationOutcome::Pending { proposal_id });
            }
            PayloadStatusEnum::Invalid { validation_error } => {
                return Err(DerivationError::Other(anyhow::anyhow!(
                    "engine_newPayloadV2 invalid: {validation_error:?}"
                )));
            }
        }

        let parent_hash = block.header.parent_hash;
        let forkchoice_state = ForkchoiceState {
            head_block_hash: block.hash(),
            safe_block_hash: block.hash(),
            finalized_block_hash: parent_hash,
        };

        let _: ForkchoiceUpdated = self
            .rpc
            .l2_auth_provider
            .raw_request(
                Cow::Borrowed("engine_forkchoiceUpdatedV2"),
                (forkchoice_state, Option::<PayloadAttributes>::None),
            )
            .await
            .map_err(|err| DerivationError::Other(anyhow::Error::msg(err.to_string())))?;

        let l2_block_hash = block.hash();
        let l1_block_height = payload.log.block_number;
        let l1_block_hash = payload.log.block_hash;
        let is_forced = payload.derivation.sources.iter().any(|source| source.isForcedInclusion);

        self.update_l1_origin(
            proposal_id,
            l2_block_hash,
            l1_block_height,
            l1_block_hash,
            is_forced,
        )
        .await?;

        gauge!(DriverMetrics::LAST_SEEN_PROPOSAL_ID).set(proposal_id as f64);
        info!(proposal_id, ?l2_block_hash, "applied shasta proposal guidance");

        Ok(DerivationOutcome::Applied { proposal_id })
    }
}
