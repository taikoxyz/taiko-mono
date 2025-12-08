//! Helpers for materialising payload attributes into execution engine blocks.

use alethia_reth_primitives::{
    engine::types::TaikoExecutionDataSidecar, payload::attributes::TaikoPayloadAttributes,
};
use alloy::{eips::BlockNumberOrTag, primitives::B256, providers::Provider};
use alloy_consensus::{
    TxEnvelope,
    proofs::{calculate_withdrawals_root, ordered_trie_root_with_encoder},
};
use alloy_primitives::bytes::BufMut;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
#[cfg(test)]
use alloy_rpc_types_engine::ExecutionPayloadV1;
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV2, ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState,
    PayloadId, PayloadStatusEnum,
};
use async_trait::async_trait;
use rpc::client::Client;
use tracing::{debug, info, instrument, warn};

use crate::sync::error::EngineSubmissionError;

/// Description of a block inserted via the execution engine.
#[derive(Debug, Clone)]
pub struct EngineBlockOutcome {
    /// The L2 block materialised by the execution engine.
    pub block: RpcBlock<TxEnvelope>,
    /// Payload identifier returned by the engine API.
    pub payload_id: PayloadId,
}

impl EngineBlockOutcome {
    /// Return the number of the inserted block.
    pub fn block_number(&self) -> u64 {
        self.block.header.number
    }

    /// Return the hash of the inserted block.
    pub fn block_hash(&self) -> B256 {
        self.block.header.hash
    }
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

    /// Submit a single payload to the execution engine while internally managing forkchoice state.
    async fn apply_payload(
        &self,
        payload: &TaikoPayloadAttributes,
        parent_hash: B256,
        finalized_block_hash: Option<B256>,
    ) -> Result<AppliedPayload, EngineSubmissionError>;
}

/// Trait that injects already-constructed execution payloads into the engine.
#[async_trait]
pub trait ExecutionPayloadInjector {
    /// Submit a fully built execution payload to the engine and materialise the corresponding
    /// block. Implementations should preserve the same engine interaction semantics used by
    /// [`PayloadApplier`].
    async fn apply_execution_payload(
        &self,
        payload: &ExecutionPayloadInputV2,
        finalized_block_hash: Option<B256>,
    ) -> Result<EngineBlockOutcome, EngineSubmissionError>;
}

#[async_trait]
impl<P> PayloadApplier for Client<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Submit the provided payload attributes to the execution engine, building canonical L2
    /// blocks.
    #[instrument(skip(self, payloads))]
    async fn attributes_to_blocks(
        &self,
        payloads: &[TaikoPayloadAttributes],
    ) -> Result<Vec<EngineBlockOutcome>, EngineSubmissionError> {
        if payloads.is_empty() {
            return Ok(Vec::new());
        }

        let parent_block: RpcBlock<TxEnvelope> = self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| EngineSubmissionError::Provider(err.to_string()))?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or(EngineSubmissionError::MissingParent)?;
        debug!(
            parent_number = parent_block.header.number,
            parent_hash = ?parent_block.hash(),
            "fetched latest parent block for payload submission"
        );

        let mut outcomes = Vec::with_capacity(payloads.len());
        let mut parent_hash = parent_block.hash();
        debug!(
            head = ?parent_hash,
            payload_count = payloads.len(),
            "submitting batched payloads"
        );

        for payload in payloads {
            let applied = apply_payload_internal(self, payload, parent_hash, None).await?;
            parent_hash = applied.outcome.block_hash();
            outcomes.push(applied.outcome);
        }

        info!(inserted_blocks = outcomes.len(), "successfully applied payload batch");
        Ok(outcomes)
    }

    /// Submit a single payload to the execution engine while internally managing forkchoice state.
    #[instrument(skip(self, payload), fields(payload_id = tracing::field::Empty))]
    async fn apply_payload(
        &self,
        payload: &TaikoPayloadAttributes,
        parent_hash: B256,
        finalized_block_hash: Option<B256>,
    ) -> Result<AppliedPayload, EngineSubmissionError> {
        let span = tracing::Span::current();
        let applied =
            apply_payload_internal(self, payload, parent_hash, finalized_block_hash).await?;
        span.record("payload_id", format_args!("{}", applied.outcome.payload_id));
        Ok(applied)
    }
}

#[async_trait]
impl<P> ExecutionPayloadInjector for Client<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Submit a fully built execution payload to the engine and materialise the corresponding
    /// block. Implementations should preserve the same engine interaction semantics used by
    /// [`PayloadApplier`].
    #[instrument(skip(self, payload))]
    async fn apply_execution_payload(
        &self,
        payload: &ExecutionPayloadInputV2,
        finalized_block_hash: Option<B256>,
    ) -> Result<EngineBlockOutcome, EngineSubmissionError> {
        let parent_hash = payload.execution_payload.parent_hash;
        let block_hash = payload.execution_payload.block_hash;
        let block_number = payload.execution_payload.block_number;

        let outcome = submit_payload_to_engine(
            self,
            payload,
            block_hash,
            block_number,
            finalized_block_hash,
            // We keep the payload ID as zeroed since we won't check if it's known by the engine
            // later.
            PayloadId::new([0u8; 8]),
        )
        .await?;

        info!(
            block_number,
            block_hash = ?block_hash,
            parent_hash = ?parent_hash,
            "inserted l2 block via execution payload injector",
        );

        Ok(outcome)
    }
}

/// Description of a payload inserted into the execution engine, including the constructed
/// execution payload.
#[derive(Debug, Clone)]
pub struct AppliedPayload {
    /// Outcome metadata describing the inserted block.
    pub outcome: EngineBlockOutcome,
    /// The execution payload returned by the engine when building the block.
    pub payload: ExecutionPayloadInputV2,
}

/// Submit the provided payload attributes to the execution engine, building canonical L2
/// blocks.
#[instrument(skip(rpc, payload), fields(payload_id = tracing::field::Empty))]
async fn apply_payload_internal<P>(
    rpc: &Client<P>,
    payload: &TaikoPayloadAttributes,
    parent_hash: B256,
    finalized_block_hash: Option<B256>,
) -> Result<AppliedPayload, EngineSubmissionError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    // Advertise the next payload attributes so the execution engine can build the block body.
    let forkchoice_state = ForkchoiceState {
        head_block_hash: parent_hash,
        safe_block_hash: parent_hash,
        finalized_block_hash: B256::ZERO,
    };
    let fc_response =
        rpc.engine_forkchoice_updated_v2(forkchoice_state, Some(payload.clone())).await?;

    let payload_id = fc_response.payload_id.ok_or(EngineSubmissionError::MissingPayloadId)?;
    tracing::Span::current().record("payload_id", format_args!("{}", payload_id));

    let expected_payload_id = PayloadId::new(payload.l1_origin.build_payload_args_id);
    if expected_payload_id != payload_id {
        warn!(
            expected = %expected_payload_id,
            received = %payload_id,
            "payload id mismatch between derivation and engine response",
        );
    }

    // Fetch the constructed payload and normalise it into the `engine_newPayloadV2` input shape.
    let envelope = rpc.engine_get_payload_v2(payload_id).await?;
    let (payload_input, block_hash, block_number) = envelope_into_submission(envelope);

    debug!(
        block_number,
        block_hash = ?block_hash,
        payload_id = %payload_id,
        "engine accepted execution payload"
    );

    let outcome = submit_payload_to_engine(
        rpc,
        &payload_input,
        block_hash,
        block_number,
        finalized_block_hash,
        payload_id,
    )
    .await?;

    info!(
        block_number,
        block_hash = ?outcome.block.hash(),
        payload_id = %outcome.payload_id,
        "inserted l2 block via payload applier",
    );

    Ok(AppliedPayload { outcome, payload: payload_input })
}

/// Derive the Taiko-specific execution data sidecar from the provided execution payload.
fn derive_payload_sidecar(payload: &ExecutionPayloadInputV2) -> TaikoExecutionDataSidecar {
    let tx_hash =
        ordered_trie_root_with_encoder(&payload.execution_payload.transactions, |tx, buf| {
            buf.put_slice(tx)
        });
    let withdrawals_hash =
        payload.withdrawals.as_ref().map(|withdrawals| calculate_withdrawals_root(withdrawals));

    TaikoExecutionDataSidecar { tx_hash, withdrawals_hash, taiko_block: Some(true) }
}

/// Convert an execution payload envelope into the submission format expected by the engine.
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

/// Map engine payload status into submission errors, rejecting syncing/invalid statuses.
fn ensure_valid_payload_status(
    block_number: u64,
    status: PayloadStatusEnum,
) -> Result<(), EngineSubmissionError> {
    match status {
        PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted => Ok(()),
        PayloadStatusEnum::Syncing => Err(EngineSubmissionError::EngineSyncing(block_number)),
        PayloadStatusEnum::Invalid { validation_error } => {
            Err(EngineSubmissionError::InvalidBlock(block_number, validation_error))
        }
    }
}

/// Build a forkchoice state pointing head/safe/finalized to the provided hashes.
fn promotion_forkchoice_state(
    block_hash: B256,
    finalized_block_hash: Option<B256>,
) -> ForkchoiceState {
    let resolved_finalized_hash = finalized_block_hash.unwrap_or(B256::ZERO);
    ForkchoiceState {
        head_block_hash: block_hash,
        safe_block_hash: resolved_finalized_hash,
        finalized_block_hash: resolved_finalized_hash,
    }
}

/// Fetch the inserted block by number and map provider errors into submission errors.
async fn fetch_block_by_number<P>(
    rpc: &Client<P>,
    block_number: u64,
) -> Result<RpcBlock<TxEnvelope>, EngineSubmissionError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    rpc.l2_provider
        .get_block_by_number(BlockNumberOrTag::Number(block_number))
        .await
        .map_err(|err| EngineSubmissionError::Provider(err.to_string()))?
        .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
        .ok_or(EngineSubmissionError::MissingInsertedBlock(block_number))
}

/// Common flow to submit a payload to the engine, promote forkchoice, and read back the block.
async fn submit_payload_to_engine<P>(
    rpc: &Client<P>,
    payload_input: &ExecutionPayloadInputV2,
    block_hash: B256,
    block_number: u64,
    finalized_block_hash: Option<B256>,
    payload_id: PayloadId,
) -> Result<EngineBlockOutcome, EngineSubmissionError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let sidecar = derive_payload_sidecar(payload_input);
    let status = rpc.engine_new_payload_v2(payload_input, &sidecar).await?;
    ensure_valid_payload_status(block_number, status.status)?;

    let promoted_state = promotion_forkchoice_state(block_hash, finalized_block_hash);
    rpc.engine_forkchoice_updated_v2(promoted_state, None).await?;

    let block = fetch_block_by_number(rpc, block_number).await?;

    Ok(EngineBlockOutcome { block, payload_id })
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, B256, Bloom, Bytes, U256};
    use alloy_consensus::proofs::{calculate_withdrawals_root, ordered_trie_root_with_encoder};
    use alloy_eips::eip4895::Withdrawal;
    use alloy_primitives::bytes::BufMut;

    #[test]
    fn derive_payload_sidecar_matches_roots() {
        let transactions =
            vec![Bytes::from_static(&[0x01, 0x23]), Bytes::from_static(&[0x45, 0x67])];
        let withdrawals = vec![Withdrawal {
            index: 0,
            validator_index: 1,
            address: Address::from([2u8; 20]),
            amount: 3,
        }];

        let payload_v1 = ExecutionPayloadV1 {
            parent_hash: B256::from(U256::from(10u64)),
            fee_recipient: Address::from([1u8; 20]),
            state_root: B256::from(U256::from(2u64)),
            receipts_root: B256::from(U256::from(3u64)),
            logs_bloom: Bloom::default(),
            prev_randao: B256::from(U256::from(4u64)),
            block_number: 7,
            gas_limit: 30_000_000,
            gas_used: 0,
            timestamp: 123,
            extra_data: Bytes::new(),
            base_fee_per_gas: U256::from(1u64),
            block_hash: B256::from(U256::from(42u64)),
            transactions: transactions.clone(),
        };

        let payload_input = ExecutionPayloadInputV2 {
            execution_payload: payload_v1,
            withdrawals: Some(withdrawals.clone()),
        };

        let sidecar = derive_payload_sidecar(&payload_input);

        let expected_tx_root =
            ordered_trie_root_with_encoder(&transactions, |item, buf| buf.put_slice(item));
        assert_eq!(sidecar.tx_hash, expected_tx_root);

        let expected_withdrawals_root = calculate_withdrawals_root(&withdrawals);
        assert_eq!(sidecar.withdrawals_hash, Some(expected_withdrawals_root));
        assert_eq!(sidecar.taiko_block, Some(true));
    }
}
