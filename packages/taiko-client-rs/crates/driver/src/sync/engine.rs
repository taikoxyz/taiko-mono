//! Helpers for materialising payload attributes into execution engine blocks.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::{eips::BlockNumberOrTag, primitives::B256, providers::Provider};
use alloy_consensus::TxEnvelope;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV2, ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState,
    PayloadId, PayloadStatusEnum,
};
use async_trait::async_trait;
use rpc::client::Client;
use tracing::{info, warn};

use crate::sync::error::EngineSubmissionError;

/// Description of a block inserted via the execution engine.
#[derive(Debug, Clone)]
pub struct EngineBlockOutcome {
    /// Block number of the inserted L2 block.
    pub block_number: u64,
    /// Hash of the inserted L2 block.
    pub block_hash: B256,
    /// Payload identifier returned by the engine API.
    pub payload_id: PayloadId,
}

/// Trait that converts derivation payload attributes into concrete execution engine blocks.
#[async_trait]
pub trait PayloadApplier {
    /// Submit the provided payload attributes to the execution engine, building canonical L2
    /// blocks.
    ///
    /// Callers should supply the payloads in chain order as returned by the derivation pipeline.
    /// The implementation queries the current engine head, advances forkchoice, and finally
    /// materialises the payloads into blocks.
    async fn attributes_to_blocks(
        &self,
        payloads: &[TaikoPayloadAttributes],
    ) -> Result<Vec<EngineBlockOutcome>, EngineSubmissionError>;
}

#[async_trait]
impl<P> PayloadApplier for Client<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn attributes_to_blocks(
        &self,
        payloads: &[TaikoPayloadAttributes],
    ) -> Result<Vec<EngineBlockOutcome>, EngineSubmissionError> {
        if payloads.is_empty() {
            return Ok(Vec::new());
        }

        let parent_block = self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| EngineSubmissionError::Provider(err.to_string()))?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or(EngineSubmissionError::MissingParent)?;

        submit_payloads_to_engine(self, &parent_block, payloads).await
    }
}

async fn submit_payloads_to_engine<P>(
    rpc: &Client<P>,
    parent_block: &RpcBlock<TxEnvelope>,
    payloads: &[TaikoPayloadAttributes],
) -> Result<Vec<EngineBlockOutcome>, EngineSubmissionError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let mut outcomes = Vec::with_capacity(payloads.len());

    // Track forkchoice hashes as we build a contiguous chain starting from the provided parent.
    let mut head_hash = parent_block.hash();
    let mut safe_hash = parent_block.hash();
    let mut finalized_hash = parent_block.header.parent_hash;

    for payload in payloads {
        // Advertise the next payload attributes so the execution engine can build the block body.
        let fc_state = ForkchoiceState {
            head_block_hash: head_hash,
            safe_block_hash: safe_hash,
            finalized_block_hash: finalized_hash,
        };

        let fc_response = rpc.engine_forkchoice_updated_v2(fc_state, Some(payload.clone())).await?;

        let payload_id = fc_response.payload_id.ok_or(EngineSubmissionError::MissingPayloadId)?;

        let expected_payload_id = PayloadId::new(payload.l1_origin.build_payload_args_id);
        if expected_payload_id != payload_id {
            warn!(
                expected = %expected_payload_id,
                received = %payload_id,
                "payload id mismatch between derivation and engine response",
            );
        }

        // Fetch the constructed payload and normalise it into the `engine_newPayloadV2` input
        // shape.
        let envelope = rpc.engine_get_payload_v2(payload_id).await?;
        let (payload_input, block_hash, block_number) = envelope_into_submission(envelope);

        // Submit the new block to the execution engine and bail out on unrecoverable statuses.
        let payload_status = rpc.engine_new_payload_v2(payload_input, Vec::new(), None).await?;

        match payload_status.status {
            PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted => {}
            PayloadStatusEnum::Syncing => {
                return Err(EngineSubmissionError::EngineSyncing(block_number));
            }
            PayloadStatusEnum::Invalid { validation_error } => {
                return Err(EngineSubmissionError::InvalidBlock(block_number, validation_error));
            }
        }

        // Update forkchoice to promote the freshly inserted block as the new head and safe block.
        let fc_state = ForkchoiceState {
            head_block_hash: block_hash,
            safe_block_hash: head_hash,
            finalized_block_hash: safe_hash,
        };
        rpc.engine_forkchoice_updated_v2(fc_state, None).await?;

        head_hash = block_hash;
        safe_hash = block_hash;
        finalized_hash = payload.l1_origin.l1_block_hash.unwrap_or(block_hash);

        info!(
            block_number,
            block_hash = ?block_hash,
            payload_id = %payload_id,
            "inserted l2 block via payload applier",
        );

        outcomes.push(EngineBlockOutcome { block_number, block_hash, payload_id });
    }

    Ok(outcomes)
}

fn envelope_into_submission(
    envelope: ExecutionPayloadEnvelopeV2,
) -> (ExecutionPayloadInputV2, B256, u64) {
    match envelope.execution_payload {
        ExecutionPayloadFieldV2::V1(payload) => (
            ExecutionPayloadInputV2 { execution_payload: payload.clone(), withdrawals: None },
            payload.block_hash,
            payload.block_number,
        ),
        ExecutionPayloadFieldV2::V2(payload) => (
            ExecutionPayloadInputV2 {
                execution_payload: payload.payload_inner.clone(),
                withdrawals: Some(payload.withdrawals.clone()),
            },
            payload.payload_inner.block_hash,
            payload.payload_inner.block_number,
        ),
    }
}
