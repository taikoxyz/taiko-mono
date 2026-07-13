//! Helpers for materialising payload attributes into execution engine blocks.

use alethia_reth_primitives::{
    engine::types::TaikoExecutionDataSidecar, payload::attributes::TaikoPayloadAttributes,
};
use alloy::{eips::BlockNumberOrTag, primitives::B256, providers::Provider};
use alloy_consensus::{
    TxEnvelope,
    proofs::{calculate_withdrawals_root, ordered_trie_root_with_encoder},
};
use alloy_primitives::{U256, bytes::BufMut};
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
#[cfg(test)]
use alloy_rpc_types_engine::ExecutionPayloadV1;
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV2, ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState,
    ForkchoiceUpdated, PayloadId, PayloadStatus, PayloadStatusEnum,
};
use async_trait::async_trait;
use protocol::shasta::unzen_active_for_chain_timestamp;
use rpc::client::Client;
use tracing::{debug, info, instrument, warn};

use crate::sync::error::{EnginePayloadStatusStage, EngineSubmissionError};

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
    /// Submit a single payload to the execution engine while internally managing forkchoice
    /// state, returning the inserted-block outcome.
    async fn apply_payload(
        &self,
        payload: &TaikoPayloadAttributes,
        parent_hash: B256,
        finalized_block_hash: Option<B256>,
    ) -> Result<EngineBlockOutcome, EngineSubmissionError>;
}

#[async_trait]
impl PayloadApplier for Client {
    /// Submit a single payload to the execution engine while internally managing forkchoice
    /// state, returning the inserted-block outcome.
    #[instrument(skip(self, payload), fields(payload_id = tracing::field::Empty))]
    async fn apply_payload(
        &self,
        payload: &TaikoPayloadAttributes,
        parent_hash: B256,
        finalized_block_hash: Option<B256>,
    ) -> Result<EngineBlockOutcome, EngineSubmissionError> {
        let span = tracing::Span::current();
        let outcome =
            apply_payload_internal(self, payload, parent_hash, finalized_block_hash).await?;
        span.record("payload_id", format_args!("{}", outcome.payload_id));
        Ok(outcome)
    }
}

/// Minimal engine/provider surface used to materialise payload attributes into blocks, letting
/// the submission orchestration be exercised against a scripted engine in tests.
#[async_trait]
trait EnginePayloadRpc: Sync {
    /// Chain id used to normalise Unzen payload envelopes.
    fn chain_id(&self) -> u64;

    /// Send `engine_forkchoiceUpdatedV2`, optionally carrying payload attributes.
    async fn forkchoice_updated_v2(
        &self,
        state: ForkchoiceState,
        attrs: Option<TaikoPayloadAttributes>,
    ) -> Result<ForkchoiceUpdated, EngineSubmissionError>;

    /// Fetch a built payload envelope via `engine_getPayloadV2`.
    async fn get_payload_v2(
        &self,
        payload_id: PayloadId,
    ) -> Result<ExecutionPayloadEnvelopeV2, EngineSubmissionError>;

    /// Submit an execution payload via `engine_newPayloadV2`.
    async fn new_payload_v2(
        &self,
        payload: &ExecutionPayloadInputV2,
        sidecar: &TaikoExecutionDataSidecar,
    ) -> Result<PayloadStatus, EngineSubmissionError>;

    /// Fetch a block by number from the execution client's public RPC.
    async fn block_by_number(
        &self,
        number: u64,
    ) -> Result<Option<RpcBlock<TxEnvelope>>, EngineSubmissionError>;
}

#[async_trait]
impl EnginePayloadRpc for Client {
    /// Return the chain id cached on the client at construction time.
    fn chain_id(&self) -> u64 {
        self.chain_id
    }

    /// Delegate to `engine_forkchoiceUpdatedV2` on the authenticated engine endpoint,
    /// mapping RPC/transport failures into [`EngineSubmissionError::Rpc`].
    async fn forkchoice_updated_v2(
        &self,
        state: ForkchoiceState,
        attrs: Option<TaikoPayloadAttributes>,
    ) -> Result<ForkchoiceUpdated, EngineSubmissionError> {
        Ok(self.engine_forkchoice_updated_v2(state, attrs).await?)
    }

    /// Delegate to `engine_getPayloadV2` on the authenticated engine endpoint, mapping
    /// RPC/transport failures into [`EngineSubmissionError::Rpc`].
    async fn get_payload_v2(
        &self,
        payload_id: PayloadId,
    ) -> Result<ExecutionPayloadEnvelopeV2, EngineSubmissionError> {
        Ok(self.engine_get_payload_v2(payload_id).await?)
    }

    /// Delegate to `engine_newPayloadV2` on the authenticated engine endpoint, mapping
    /// RPC/transport failures into [`EngineSubmissionError::Rpc`].
    async fn new_payload_v2(
        &self,
        payload: &ExecutionPayloadInputV2,
        sidecar: &TaikoExecutionDataSidecar,
    ) -> Result<PayloadStatus, EngineSubmissionError> {
        Ok(self.engine_new_payload_v2(payload, sidecar).await?)
    }

    /// Fetch the block at the given height from the public L2 provider, converting its
    /// transactions into [`TxEnvelope`]s; provider failures map into
    /// [`EngineSubmissionError::Rpc`], while an unknown height yields `Ok(None)`.
    async fn block_by_number(
        &self,
        number: u64,
    ) -> Result<Option<RpcBlock<TxEnvelope>>, EngineSubmissionError> {
        Ok(self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(number))
            .await
            .map_err(EngineSubmissionError::from)?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into())))
    }
}

/// Submit the provided payload attributes to the execution engine, building canonical L2
/// blocks.
#[instrument(skip(rpc, payload), fields(payload_id = tracing::field::Empty))]
async fn apply_payload_internal<R: EnginePayloadRpc>(
    rpc: &R,
    payload: &TaikoPayloadAttributes,
    parent_hash: B256,
    finalized_block_hash: Option<B256>,
) -> Result<EngineBlockOutcome, EngineSubmissionError> {
    // Advertise the next payload attributes so the execution engine can build the block body.
    let forkchoice_state = ForkchoiceState {
        head_block_hash: parent_hash,
        safe_block_hash: parent_hash,
        finalized_block_hash: B256::ZERO,
    };
    let fc_response = rpc.forkchoice_updated_v2(forkchoice_state, Some(payload.clone())).await?;
    ensure_valid_payload_status(
        payload.l1_origin.block_id.to::<u64>(),
        EnginePayloadStatusStage::PayloadAttributesForkchoice,
        fc_response.payload_status.status,
    )?;

    let payload_id = fc_response.payload_id.ok_or(EngineSubmissionError::MissingPayloadId)?;
    tracing::Span::current().record("payload_id", format_args!("{payload_id}"));

    let expected_payload_id = PayloadId::new(payload.l1_origin.build_payload_args_id);
    if expected_payload_id != payload_id {
        warn!(
            expected = %expected_payload_id,
            received = %payload_id,
            "payload id mismatch between derivation and engine response",
        );
    }

    // Fetch the constructed payload and normalise it into the `engine_newPayloadV2` input shape.
    let envelope = rpc.get_payload_v2(payload_id).await?;
    let (payload_input, sidecar, block_hash, block_number) =
        envelope_into_submission(rpc.chain_id(), envelope);

    debug!(
        block_number,
        block_hash = ?block_hash,
        payload_id = %payload_id,
        "engine accepted execution payload"
    );

    let outcome = submit_payload_to_engine(
        rpc,
        &payload_input,
        &sidecar,
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

    Ok(outcome)
}

/// Derive the Taiko-specific execution data sidecar from the provided execution payload.
fn derive_payload_sidecar(
    payload: &ExecutionPayloadInputV2,
    header_difficulty: Option<U256>,
) -> TaikoExecutionDataSidecar {
    let tx_hash =
        ordered_trie_root_with_encoder(&payload.execution_payload.transactions, |tx, buf| {
            buf.put_slice(tx)
        });
    let withdrawals_hash =
        payload.withdrawals.as_ref().map(|withdrawals| calculate_withdrawals_root(withdrawals));

    TaikoExecutionDataSidecar {
        tx_hash,
        withdrawals_hash,
        header_difficulty,
        taiko_block: Some(true),
    }
}

/// Restore the hash-relevant header difficulty from a Taiko engine envelope when Unzen is active.
fn unzen_header_difficulty(chain_id: u64, timestamp: u64, block_value: U256) -> Option<U256> {
    unzen_active_for_chain_timestamp(chain_id, timestamp).unwrap_or(false).then_some(block_value)
}

/// Convert an execution payload envelope into the submission format expected by the engine.
fn envelope_into_submission(
    chain_id: u64,
    envelope: ExecutionPayloadEnvelopeV2,
) -> (ExecutionPayloadInputV2, TaikoExecutionDataSidecar, B256, u64) {
    let block_value = envelope.block_value;
    let (execution_payload, withdrawals) = match envelope.execution_payload {
        // Taiko chains are always post-Shanghai so withdrawals must be non-nil even when the
        // engine returns a V1 envelope (which omits the withdrawals field).
        ExecutionPayloadFieldV2::V1(payload) => (payload, Vec::new()),
        ExecutionPayloadFieldV2::V2(payload) => (payload.payload_inner, payload.withdrawals),
    };

    let block_hash = execution_payload.block_hash;
    let block_number = execution_payload.block_number;
    // Taiko Unzen reuses `getPayloadV2.blockValue` to transport the original
    // `header.difficulty` back into `newPayloadV2.headerDifficulty` so the
    // getPayload/newPayload round trip stays hash-stable without adding a new wire field.
    let header_difficulty =
        unzen_header_difficulty(chain_id, execution_payload.timestamp, block_value);

    let payload_input =
        ExecutionPayloadInputV2 { execution_payload, withdrawals: Some(withdrawals) };
    let sidecar = derive_payload_sidecar(&payload_input, header_difficulty);

    (payload_input, sidecar, block_hash, block_number)
}

/// Map engine payload status into submission errors, accepting only VALID.
///
/// ACCEPTED means the engine stored the block on a side chain without executing it, so treating
/// it as success would let the driver advance on a lineage the engine never validated.
fn ensure_valid_payload_status(
    block_number: u64,
    stage: EnginePayloadStatusStage,
    status: PayloadStatusEnum,
) -> Result<(), EngineSubmissionError> {
    match status {
        PayloadStatusEnum::Valid => Ok(()),
        PayloadStatusEnum::Accepted => Err(EngineSubmissionError::UnexpectedPayloadStatus {
            block_number,
            stage,
            status: PayloadStatusEnum::Accepted.as_str().to_string(),
        }),
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

/// Verify the canonical block read back after promotion matches the submitted payload hash.
///
/// A mismatch means the forkchoice update did not take effect (or another actor moved the head
/// between promotion and readback); advancing on the mismatched block would silently desync the
/// driver's parent state from the engine's canonical chain.
fn ensure_inserted_block_hash(
    block_number: u64,
    expected: B256,
    actual: B256,
) -> Result<(), EngineSubmissionError> {
    if actual == expected {
        Ok(())
    } else {
        Err(EngineSubmissionError::InsertedBlockHashMismatch { block_number, expected, actual })
    }
}

/// Fetch the inserted block by number, mapping absence into a submission error.
async fn fetch_block_by_number<R: EnginePayloadRpc>(
    rpc: &R,
    block_number: u64,
) -> Result<RpcBlock<TxEnvelope>, EngineSubmissionError> {
    rpc.block_by_number(block_number)
        .await?
        .ok_or(EngineSubmissionError::MissingInsertedBlock(block_number))
}

/// Common flow to submit a payload to the engine, promote forkchoice, and read back the block.
async fn submit_payload_to_engine<R: EnginePayloadRpc>(
    rpc: &R,
    payload_input: &ExecutionPayloadInputV2,
    sidecar: &TaikoExecutionDataSidecar,
    block_hash: B256,
    block_number: u64,
    finalized_block_hash: Option<B256>,
    payload_id: PayloadId,
) -> Result<EngineBlockOutcome, EngineSubmissionError> {
    let status = rpc.new_payload_v2(payload_input, sidecar).await?;
    ensure_valid_payload_status(block_number, EnginePayloadStatusStage::NewPayload, status.status)?;

    let promoted_state = promotion_forkchoice_state(block_hash, finalized_block_hash);
    let promotion = rpc.forkchoice_updated_v2(promoted_state, None).await?;
    ensure_valid_payload_status(
        block_number,
        EnginePayloadStatusStage::PromotionForkchoice,
        promotion.payload_status.status,
    )?;

    let block = fetch_block_by_number(rpc, block_number).await?;
    ensure_inserted_block_hash(block_number, block_hash, block.header.hash)?;

    Ok(EngineBlockOutcome { block, payload_id })
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, B256, Bloom, Bytes, U256};
    use alloy_consensus::proofs::{calculate_withdrawals_root, ordered_trie_root_with_encoder};
    use alloy_eips::eip4895::Withdrawal;
    use alloy_primitives::bytes::BufMut;
    use alloy_rpc_types_engine::ExecutionPayloadV2;
    use protocol::shasta::{
        PayloadAttributesInput, build_payload_attributes,
        constants::{TAIKO_DEVNET_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID},
    };

    fn sample_payload(timestamp: u64) -> ExecutionPayloadV1 {
        ExecutionPayloadV1 {
            parent_hash: B256::from(U256::from(10u64)),
            fee_recipient: Address::from([1u8; 20]),
            state_root: B256::from(U256::from(2u64)),
            receipts_root: B256::from(U256::from(3u64)),
            logs_bloom: Bloom::default(),
            prev_randao: B256::from(U256::from(4u64)),
            block_number: 7,
            gas_limit: 30_000_000,
            gas_used: 0,
            timestamp,
            extra_data: Bytes::new(),
            base_fee_per_gas: U256::from(1u64),
            block_hash: B256::from(U256::from(42u64)),
            transactions: vec![Bytes::from_static(&[0x01, 0x23])],
        }
    }

    fn sample_envelope_v1(timestamp: u64, block_value: U256) -> ExecutionPayloadEnvelopeV2 {
        ExecutionPayloadEnvelopeV2 {
            execution_payload: ExecutionPayloadFieldV2::V1(sample_payload(timestamp)),
            block_value,
        }
    }

    fn sample_envelope_v2(timestamp: u64, block_value: U256) -> ExecutionPayloadEnvelopeV2 {
        ExecutionPayloadEnvelopeV2 {
            execution_payload: ExecutionPayloadFieldV2::V2(ExecutionPayloadV2 {
                payload_inner: sample_payload(timestamp),
                withdrawals: vec![],
            }),
            block_value,
        }
    }

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

        let sidecar = derive_payload_sidecar(&payload_input, None);

        let expected_tx_root =
            ordered_trie_root_with_encoder(&transactions, |item, buf| buf.put_slice(item));
        assert_eq!(sidecar.tx_hash, expected_tx_root);

        let expected_withdrawals_root = calculate_withdrawals_root(&withdrawals);
        assert_eq!(sidecar.withdrawals_hash, Some(expected_withdrawals_root));
        assert_eq!(sidecar.header_difficulty, None);
        assert_eq!(sidecar.taiko_block, Some(true));
    }

    #[test]
    fn unzen_block_value_becomes_header_difficulty() {
        let envelope = sample_envelope_v1(0, U256::from(42u64));

        let (_, sidecar, _, _) = envelope_into_submission(TAIKO_DEVNET_CHAIN_ID, envelope);

        assert_eq!(sidecar.header_difficulty, Some(U256::from(42u64)));
    }

    #[test]
    fn pre_unzen_block_value_is_not_reused_as_header_difficulty() {
        let envelope = sample_envelope_v1(0, U256::from(42u64));

        let (_, sidecar, _, _) = envelope_into_submission(TAIKO_MAINNET_CHAIN_ID, envelope);

        assert_eq!(sidecar.header_difficulty, None);
    }

    #[test]
    fn unzen_block_value_becomes_header_difficulty_for_v2_envelope() {
        let envelope = sample_envelope_v2(0, U256::from(42u64));

        let (_, sidecar, _, _) = envelope_into_submission(TAIKO_DEVNET_CHAIN_ID, envelope);

        assert_eq!(sidecar.header_difficulty, Some(U256::from(42u64)));
    }

    #[test]
    fn valid_payload_status_is_ok() {
        assert!(
            ensure_valid_payload_status(
                7,
                EnginePayloadStatusStage::NewPayload,
                PayloadStatusEnum::Valid,
            )
            .is_ok()
        );
    }

    #[test]
    fn accepted_payload_status_is_rejected() {
        let err = ensure_valid_payload_status(
            7,
            EnginePayloadStatusStage::NewPayload,
            PayloadStatusEnum::Accepted,
        )
        .unwrap_err();
        assert!(matches!(
            err,
            EngineSubmissionError::UnexpectedPayloadStatus {
                block_number: 7,
                stage: EnginePayloadStatusStage::NewPayload,
                ref status,
            } if status == "ACCEPTED"
        ));
    }

    #[test]
    fn syncing_payload_status_maps_to_engine_syncing() {
        let err = ensure_valid_payload_status(
            7,
            EnginePayloadStatusStage::NewPayload,
            PayloadStatusEnum::Syncing,
        )
        .unwrap_err();
        assert!(matches!(err, EngineSubmissionError::EngineSyncing(7)));
    }

    #[test]
    fn invalid_payload_status_maps_to_invalid_block() {
        let err = ensure_valid_payload_status(
            7,
            EnginePayloadStatusStage::NewPayload,
            PayloadStatusEnum::Invalid { validation_error: "bad block".to_string() },
        )
        .unwrap_err();
        assert!(matches!(
            err,
            EngineSubmissionError::InvalidBlock(7, ref reason) if reason == "bad block"
        ));
    }

    /// Which engine RPC a scripted call hit, in production sequence order.
    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    enum EngineCall {
        ForkchoiceWithAttributes {
            head: B256,
            safe: B256,
            finalized: B256,
            attrs_block_number: u64,
            attrs_payload_id: [u8; 8],
        },
        GetPayload {
            payload_id: PayloadId,
        },
        NewPayload {
            block_hash: B256,
            block_number: u64,
            tx_hash: B256,
            withdrawals_hash: Option<B256>,
            header_difficulty: Option<U256>,
            taiko_block: Option<bool>,
        },
        PromotionForkchoice {
            head: B256,
            safe: B256,
            finalized: B256,
        },
        BlockByNumber {
            number: u64,
        },
    }

    /// Scripted [`EnginePayloadRpc`] double that records the call sequence and replays the
    /// configured responses; unscripted calls return an error so a regression that keeps
    /// calling after a failure surfaces as both a wrong call log and a wrong error.
    #[derive(Default)]
    struct ScriptedEngine {
        calls: std::sync::Mutex<Vec<EngineCall>>,
        attributes_forkchoice: Option<ForkchoiceUpdated>,
        envelope: Option<ExecutionPayloadEnvelopeV2>,
        new_payload: Option<PayloadStatus>,
        promotion_forkchoice: Option<ForkchoiceUpdated>,
        readback_block: Option<RpcBlock<TxEnvelope>>,
    }

    impl ScriptedEngine {
        fn record(&self, call: EngineCall) {
            self.calls.lock().expect("call log lock").push(call);
        }

        fn calls(&self) -> Vec<EngineCall> {
            self.calls.lock().expect("call log lock").clone()
        }

        fn unscripted(call: &str) -> EngineSubmissionError {
            EngineSubmissionError::Rpc(rpc::RpcClientError::RpcMessage(format!(
                "unscripted engine call: {call}"
            )))
        }
    }

    #[async_trait]
    impl EnginePayloadRpc for ScriptedEngine {
        fn chain_id(&self) -> u64 {
            TAIKO_DEVNET_CHAIN_ID
        }

        async fn forkchoice_updated_v2(
            &self,
            state: ForkchoiceState,
            attrs: Option<TaikoPayloadAttributes>,
        ) -> Result<ForkchoiceUpdated, EngineSubmissionError> {
            if let Some(attrs) = attrs {
                self.record(EngineCall::ForkchoiceWithAttributes {
                    head: state.head_block_hash,
                    safe: state.safe_block_hash,
                    finalized: state.finalized_block_hash,
                    attrs_block_number: attrs.l1_origin.block_id.to::<u64>(),
                    attrs_payload_id: attrs.l1_origin.build_payload_args_id,
                });
                self.attributes_forkchoice
                    .clone()
                    .ok_or_else(|| Self::unscripted("forkchoiceUpdated with attributes"))
            } else {
                self.record(EngineCall::PromotionForkchoice {
                    head: state.head_block_hash,
                    safe: state.safe_block_hash,
                    finalized: state.finalized_block_hash,
                });
                self.promotion_forkchoice
                    .clone()
                    .ok_or_else(|| Self::unscripted("promotion forkchoiceUpdated"))
            }
        }

        async fn get_payload_v2(
            &self,
            payload_id: PayloadId,
        ) -> Result<ExecutionPayloadEnvelopeV2, EngineSubmissionError> {
            self.record(EngineCall::GetPayload { payload_id });
            self.envelope.clone().ok_or_else(|| Self::unscripted("getPayload"))
        }

        async fn new_payload_v2(
            &self,
            payload: &ExecutionPayloadInputV2,
            sidecar: &TaikoExecutionDataSidecar,
        ) -> Result<PayloadStatus, EngineSubmissionError> {
            self.record(EngineCall::NewPayload {
                block_hash: payload.execution_payload.block_hash,
                block_number: payload.execution_payload.block_number,
                tx_hash: sidecar.tx_hash,
                withdrawals_hash: sidecar.withdrawals_hash,
                header_difficulty: sidecar.header_difficulty,
                taiko_block: sidecar.taiko_block,
            });
            self.new_payload.clone().ok_or_else(|| Self::unscripted("newPayload"))
        }

        async fn block_by_number(
            &self,
            number: u64,
        ) -> Result<Option<RpcBlock<TxEnvelope>>, EngineSubmissionError> {
            self.record(EngineCall::BlockByNumber { number });
            Ok(self.readback_block.clone())
        }
    }

    /// Payload attributes for block 7, matching [`sample_envelope_v1`]'s block number.
    fn sample_attributes() -> TaikoPayloadAttributes {
        let mut attributes = build_payload_attributes(PayloadAttributesInput {
            beneficiary: Address::from([1u8; 20]),
            timestamp: 1,
            mix_hash: B256::ZERO,
            gas_limit: 30_000_000,
            tx_list: Some(Bytes::new()),
            extra_data: Bytes::new(),
            base_fee_per_gas: U256::from(1u64),
            block_number: 7,
            l1_block_height: Some(U256::from(100u64)),
            l1_block_hash: Some(B256::ZERO),
            is_forced_inclusion: false,
            signature: [0; 65],
            parent_beacon_block_root: None,
            anchor_transaction: None,
        });
        attributes.l1_origin.build_payload_args_id = *expected_payload_id().0;
        attributes
    }

    fn forkchoice_response(
        status: PayloadStatusEnum,
        payload_id: Option<PayloadId>,
    ) -> ForkchoiceUpdated {
        ForkchoiceUpdated { payload_status: PayloadStatus::from_status(status), payload_id }
    }

    /// The block hash produced by [`sample_payload`], i.e. what getPayload advertises.
    fn sample_block_hash() -> B256 {
        B256::from(U256::from(42u64))
    }

    /// Parent hash supplied to the attribute forkchoice.
    fn sample_parent_hash() -> B256 {
        B256::from(U256::from(10u64))
    }

    /// Finalized hash supplied to the promotion forkchoice.
    fn sample_finalized_hash() -> B256 {
        B256::from(U256::from(20u64))
    }

    /// Payload id derived by the driver before contacting the engine.
    fn expected_payload_id() -> PayloadId {
        PayloadId::new([0x11; 8])
    }

    /// Distinct payload id returned by the engine and used for getPayload/outcome wiring.
    fn engine_payload_id() -> PayloadId {
        PayloadId::new([0x22; 8])
    }

    fn sample_readback_block(hash: B256) -> RpcBlock<TxEnvelope> {
        let mut block = RpcBlock::<TxEnvelope>::default();
        block.header.hash = hash;
        block.header.inner.number = 7;
        block
    }

    /// Expected attribute-forkchoice log entry for the sample sequence.
    fn attrs_call() -> EngineCall {
        EngineCall::ForkchoiceWithAttributes {
            head: sample_parent_hash(),
            safe: sample_parent_hash(),
            finalized: B256::ZERO,
            attrs_block_number: 7,
            attrs_payload_id: *expected_payload_id().0,
        }
    }

    /// Expected getPayload log entry: the id handed back by the attribute forkchoice.
    fn get_payload_call() -> EngineCall {
        EngineCall::GetPayload { payload_id: engine_payload_id() }
    }

    /// Expected newPayload log entry: the block hash advertised by getPayload.
    fn new_payload_call() -> EngineCall {
        let (_, sidecar, block_hash, block_number) =
            envelope_into_submission(TAIKO_DEVNET_CHAIN_ID, sample_envelope_v1(0, U256::ZERO));
        EngineCall::NewPayload {
            block_hash,
            block_number,
            tx_hash: sidecar.tx_hash,
            withdrawals_hash: sidecar.withdrawals_hash,
            header_difficulty: sidecar.header_difficulty,
            taiko_block: sidecar.taiko_block,
        }
    }

    /// Expected promotion log entry: head at the built hash, safe/finalized at the checkpoint.
    fn promotion_call() -> EngineCall {
        EngineCall::PromotionForkchoice {
            head: sample_block_hash(),
            safe: sample_finalized_hash(),
            finalized: sample_finalized_hash(),
        }
    }

    /// Expected readback log entry at the built block's height.
    fn readback_call() -> EngineCall {
        EngineCall::BlockByNumber { number: 7 }
    }

    /// A scripted engine primed for the full happy-path sequence.
    fn scripted_happy_engine() -> ScriptedEngine {
        ScriptedEngine {
            attributes_forkchoice: Some(forkchoice_response(
                PayloadStatusEnum::Valid,
                Some(engine_payload_id()),
            )),
            envelope: Some(sample_envelope_v1(0, U256::ZERO)),
            new_payload: Some(PayloadStatus::from_status(PayloadStatusEnum::Valid)),
            promotion_forkchoice: Some(forkchoice_response(PayloadStatusEnum::Valid, None)),
            readback_block: Some(sample_readback_block(sample_block_hash())),
            ..Default::default()
        }
    }

    #[tokio::test]
    async fn apply_payload_stops_when_attribute_forkchoice_is_not_valid() {
        let engine = ScriptedEngine {
            attributes_forkchoice: Some(forkchoice_response(PayloadStatusEnum::Syncing, None)),
            ..Default::default()
        };

        let err = apply_payload_internal(
            &engine,
            &sample_attributes(),
            sample_parent_hash(),
            Some(sample_finalized_hash()),
        )
        .await
        .unwrap_err();

        assert!(matches!(err, EngineSubmissionError::EngineSyncing(7)));
        assert_eq!(engine.calls(), vec![attrs_call()]);
    }

    #[tokio::test]
    async fn apply_payload_stops_when_new_payload_is_accepted() {
        let engine = ScriptedEngine {
            promotion_forkchoice: None,
            readback_block: None,
            new_payload: Some(PayloadStatus::from_status(PayloadStatusEnum::Accepted)),
            ..scripted_happy_engine()
        };

        let err = apply_payload_internal(
            &engine,
            &sample_attributes(),
            sample_parent_hash(),
            Some(sample_finalized_hash()),
        )
        .await
        .unwrap_err();

        assert!(matches!(
            err,
            EngineSubmissionError::UnexpectedPayloadStatus {
                block_number: 7,
                stage: EnginePayloadStatusStage::NewPayload,
                ..
            }
        ));
        assert_eq!(
            engine.calls(),
            vec![attrs_call(), get_payload_call(), new_payload_call()],
            "no promotion or readback may happen after a non-VALID newPayload"
        );
    }

    #[tokio::test]
    async fn apply_payload_stops_when_promotion_forkchoice_is_not_valid() {
        let engine = ScriptedEngine {
            readback_block: None,
            promotion_forkchoice: Some(forkchoice_response(
                PayloadStatusEnum::Invalid { validation_error: "bad head".to_string() },
                None,
            )),
            ..scripted_happy_engine()
        };

        let err = apply_payload_internal(
            &engine,
            &sample_attributes(),
            sample_parent_hash(),
            Some(sample_finalized_hash()),
        )
        .await
        .unwrap_err();

        assert!(matches!(
            err,
            EngineSubmissionError::InvalidBlock(7, ref reason) if reason == "bad head"
        ));
        assert_eq!(
            engine.calls(),
            vec![attrs_call(), get_payload_call(), new_payload_call(), promotion_call()],
            "no readback may happen after a failed promotion"
        );
    }

    #[tokio::test]
    async fn apply_payload_rejects_mismatched_readback_hash() {
        let engine = ScriptedEngine {
            readback_block: Some(sample_readback_block(B256::from(U256::from(43u64)))),
            ..scripted_happy_engine()
        };

        let err = apply_payload_internal(
            &engine,
            &sample_attributes(),
            sample_parent_hash(),
            Some(sample_finalized_hash()),
        )
        .await
        .unwrap_err();

        assert!(matches!(
            err,
            EngineSubmissionError::InsertedBlockHashMismatch { block_number: 7, .. }
        ));
        assert_eq!(
            engine.calls(),
            vec![
                attrs_call(),
                get_payload_call(),
                new_payload_call(),
                promotion_call(),
                readback_call(),
            ]
        );
    }

    #[tokio::test]
    async fn apply_payload_returns_hash_verified_outcome_for_valid_sequence() {
        let engine = scripted_happy_engine();

        let outcome = apply_payload_internal(
            &engine,
            &sample_attributes(),
            sample_parent_hash(),
            Some(sample_finalized_hash()),
        )
        .await
        .expect("valid sequence must succeed");

        assert_eq!(outcome.block_hash(), sample_block_hash());
        assert_eq!(outcome.block_number(), 7);
        assert_eq!(outcome.payload_id, engine_payload_id());
        assert_eq!(
            engine.calls(),
            vec![
                attrs_call(),
                get_payload_call(),
                new_payload_call(),
                promotion_call(),
                readback_call(),
            ]
        );
    }

    #[test]
    fn matching_readback_hash_is_ok() {
        let hash = B256::from(U256::from(1u64));
        assert!(ensure_inserted_block_hash(7, hash, hash).is_ok());
    }

    #[test]
    fn mismatched_readback_hash_is_rejected() {
        let expected = B256::from(U256::from(1u64));
        let actual = B256::from(U256::from(2u64));
        let err = ensure_inserted_block_hash(7, expected, actual).unwrap_err();
        assert!(matches!(
            err,
            EngineSubmissionError::InsertedBlockHashMismatch {
                block_number: 7,
                expected: e,
                actual: a,
            } if e == expected && a == actual
        ));
    }
}
