//! Helpers for materialising payload attributes into execution engine blocks.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::{eips::BlockNumberOrTag, primitives::B256, providers::Provider};
use alloy_consensus::TxEnvelope;

use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
#[cfg(test)]
use alloy_rpc_types_engine::ExecutionPayloadV1;
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV5, ExecutionPayloadV3, ForkchoiceState, ForkchoiceUpdated, PayloadId,
    PayloadStatus, PayloadStatusEnum,
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
    /// Send `engine_forkchoiceUpdatedV3`, optionally carrying payload attributes.
    async fn forkchoice_updated_v3(
        &self,
        state: ForkchoiceState,
        attrs: Option<TaikoPayloadAttributes>,
    ) -> Result<ForkchoiceUpdated, EngineSubmissionError>;

    /// Fetch a built payload envelope via `engine_getPayloadV5`.
    async fn get_payload_v5(
        &self,
        payload_id: PayloadId,
    ) -> Result<ExecutionPayloadEnvelopeV5, EngineSubmissionError>;

    /// Submit an execution payload via `engine_newPayloadV4`.
    async fn new_payload_v4(
        &self,
        payload: &ExecutionPayloadV3,
        header_difficulty: u64,
        parent_beacon_block_root: B256,
    ) -> Result<PayloadStatus, EngineSubmissionError>;

    /// Fetch a block by number from the execution client's public RPC.
    async fn block_by_number(
        &self,
        number: u64,
    ) -> Result<Option<RpcBlock<TxEnvelope>>, EngineSubmissionError>;
}

#[async_trait]
impl EnginePayloadRpc for Client {
    /// Delegate to `engine_forkchoiceUpdatedV3` on the authenticated engine endpoint,
    /// mapping RPC/transport failures into [`EngineSubmissionError::Rpc`].
    async fn forkchoice_updated_v3(
        &self,
        state: ForkchoiceState,
        attrs: Option<TaikoPayloadAttributes>,
    ) -> Result<ForkchoiceUpdated, EngineSubmissionError> {
        Ok(self.engine_forkchoice_updated_v3(state, attrs).await?)
    }

    /// Delegate to `engine_getPayloadV5` on the authenticated engine endpoint, mapping
    /// RPC/transport failures into [`EngineSubmissionError::Rpc`].
    async fn get_payload_v5(
        &self,
        payload_id: PayloadId,
    ) -> Result<ExecutionPayloadEnvelopeV5, EngineSubmissionError> {
        Ok(self.engine_get_payload_v5(payload_id).await?)
    }

    /// Delegate to `engine_newPayloadV4` on the authenticated engine endpoint, mapping
    /// RPC/transport failures into [`EngineSubmissionError::Rpc`].
    async fn new_payload_v4(
        &self,
        payload: &ExecutionPayloadV3,
        header_difficulty: u64,
        parent_beacon_block_root: B256,
    ) -> Result<PayloadStatus, EngineSubmissionError> {
        Ok(self.engine_new_payload_v4(payload, header_difficulty, parent_beacon_block_root).await?)
    }

    /// Fetch the block at the given height from the public L2 provider, converting its
    /// transactions into [`TxEnvelope`]s; provider failures map into
    /// [`EngineSubmissionError::Provider`], while an unknown height yields `Ok(None)`.
    async fn block_by_number(
        &self,
        number: u64,
    ) -> Result<Option<RpcBlock<TxEnvelope>>, EngineSubmissionError> {
        Ok(self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(number))
            .await
            .map_err(|err| EngineSubmissionError::Provider(err.to_string()))?
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
    let fc_response = rpc.forkchoice_updated_v3(forkchoice_state, Some(payload.clone())).await?;
    ensure_valid_forkchoice_status(
        payload.l1_origin.block_id.to::<u64>(),
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

    // Fetch the constructed payload and normalise it into the `engine_newPayloadV4` input shape.
    let envelope = rpc.get_payload_v5(payload_id).await?;
    let header_difficulty = u64::try_from(envelope.block_value)
        .map_err(|_| EngineSubmissionError::Provider("engine blockValue exceeds u64".into()))?;
    let payload_input = envelope.execution_payload;
    let block_hash = payload_input.payload_inner.payload_inner.block_hash;
    let block_number = payload_input.payload_inner.payload_inner.block_number;
    let parent_beacon_block_root =
        payload.payload_attributes.parent_beacon_block_root.ok_or_else(|| {
            EngineSubmissionError::Provider("payload build omitted parent beacon block root".into())
        })?;

    debug!(
        block_number,
        block_hash = ?block_hash,
        payload_id = %payload_id,
        "engine accepted execution payload"
    );

    let status =
        rpc.new_payload_v4(&payload_input, header_difficulty, parent_beacon_block_root).await?;
    ensure_valid_payload_status(block_number, status.status)?;
    let promotion = rpc
        .forkchoice_updated_v3(promotion_forkchoice_state(block_hash, finalized_block_hash), None)
        .await?;
    ensure_valid_forkchoice_status(block_number, promotion.payload_status.status)?;
    let block = fetch_block_by_number(rpc, block_number).await?;
    ensure_inserted_block_hash(block_number, block_hash, block.header.hash)?;
    let outcome = EngineBlockOutcome { block, payload_id };

    info!(
        block_number,
        block_hash = ?outcome.block.hash(),
        payload_id = %outcome.payload_id,
        "inserted l2 block via payload applier",
    );

    Ok(outcome)
}

/// Map `engine_newPayloadV4` status into submission errors, accepting only VALID.
///
/// ACCEPTED means the engine stored the block on a side chain without executing it, so treating
/// it as success would let the driver advance on a lineage the engine never validated. Only this
/// mapping may produce [`EngineSubmissionError::InvalidBlock`]: a newPayload INVALID is the
/// engine's deterministic verdict on the payload content itself, which downstream retry policies
/// rely on when deciding to stop retrying.
fn ensure_valid_payload_status(
    block_number: u64,
    status: PayloadStatusEnum,
) -> Result<(), EngineSubmissionError> {
    match status {
        PayloadStatusEnum::Valid => Ok(()),
        PayloadStatusEnum::Accepted => Err(EngineSubmissionError::UnexpectedPayloadStatus(
            block_number,
            PayloadStatusEnum::Accepted.as_str().to_string(),
        )),
        PayloadStatusEnum::Syncing => Err(EngineSubmissionError::EngineSyncing(block_number)),
        PayloadStatusEnum::Invalid { validation_error } => {
            Err(EngineSubmissionError::InvalidBlock(block_number, validation_error))
        }
    }
}

/// Map `engine_forkchoiceUpdatedV3` status into submission errors, accepting only VALID.
///
/// Unlike [`ensure_valid_payload_status`], a non-VALID forkchoice status never maps to
/// [`EngineSubmissionError::InvalidBlock`]: forkchoice INVALID reflects the engine's view of the
/// referenced head (which can be unknown or temporarily unprocessable) rather than a
/// deterministic verdict on the submitted payload's content, so callers must remain free to
/// retry it.
pub(crate) fn ensure_valid_forkchoice_status(
    block_number: u64,
    status: PayloadStatusEnum,
) -> Result<(), EngineSubmissionError> {
    match status {
        PayloadStatusEnum::Valid => Ok(()),
        PayloadStatusEnum::Syncing => Err(EngineSubmissionError::EngineSyncing(block_number)),
        PayloadStatusEnum::Accepted => Err(EngineSubmissionError::UnexpectedPayloadStatus(
            block_number,
            "forkchoice ACCEPTED".to_string(),
        )),
        PayloadStatusEnum::Invalid { validation_error } => {
            Err(EngineSubmissionError::UnexpectedPayloadStatus(
                block_number,
                format!("forkchoice INVALID: {validation_error}"),
            ))
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

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, B256, Bloom, Bytes, U256};
    use alloy_eips::eip4895::Withdrawal;
    use alloy_rpc_types_engine::ExecutionPayloadV2;
    use protocol::shasta::{PayloadAttributesInput, build_payload_attributes};

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

    fn sample_envelope(block_value: U256) -> ExecutionPayloadEnvelopeV5 {
        ExecutionPayloadEnvelopeV5 {
            execution_payload: ExecutionPayloadV3 {
                payload_inner: ExecutionPayloadV2 {
                    payload_inner: sample_payload(123),
                    withdrawals: vec![Withdrawal {
                        index: 0,
                        validator_index: 1,
                        address: Address::from([2u8; 20]),
                        amount: 3,
                    }],
                },
                blob_gas_used: 6,
                excess_blob_gas: 7,
            },
            block_value,
            blobs_bundle: Default::default(),
            should_override_builder: false,
            execution_requests: Default::default(),
        }
    }

    #[tokio::test]
    async fn apply_payload_forwards_complete_payload_and_header_difficulty() {
        let envelope = sample_envelope(U256::from(u64::MAX));
        let engine = ScriptedEngine { envelope: Some(envelope.clone()), ..scripted_happy_engine() };

        apply_payload_internal(
            &engine,
            &sample_attributes(),
            sample_parent_hash(),
            Some(sample_finalized_hash()),
        )
        .await
        .expect("u64 header difficulty must be accepted");

        assert_eq!(
            engine.calls()[2],
            EngineCall::NewPayload {
                payload: Box::new(envelope.execution_payload),
                header_difficulty: u64::MAX,
                parent_beacon_block_root: sample_parent_beacon_block_root(),
            }
        );
    }

    #[tokio::test]
    async fn apply_payload_rejects_header_difficulty_overflow_before_submission() {
        let engine = ScriptedEngine {
            envelope: Some(sample_envelope(U256::from(u64::MAX) + U256::from(1))),
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

        assert!(matches!(err, EngineSubmissionError::Provider(reason)
            if reason == "engine blockValue exceeds u64"));
        assert_eq!(engine.calls(), vec![attrs_call(), get_payload_call()]);
    }

    #[tokio::test]
    async fn apply_payload_rejects_missing_parent_beacon_root_before_submission() {
        let engine = scripted_happy_engine();
        let mut attributes = sample_attributes();
        attributes.payload_attributes.parent_beacon_block_root = None;

        let err = apply_payload_internal(
            &engine,
            &attributes,
            sample_parent_hash(),
            Some(sample_finalized_hash()),
        )
        .await
        .unwrap_err();

        assert!(matches!(err, EngineSubmissionError::Provider(reason)
            if reason == "payload build omitted parent beacon block root"));
        assert_eq!(engine.calls(), vec![attrs_call(), get_payload_call()]);
    }

    #[test]
    fn valid_payload_status_is_ok() {
        assert!(ensure_valid_payload_status(7, PayloadStatusEnum::Valid).is_ok());
    }

    #[test]
    fn accepted_payload_status_is_rejected() {
        let err = ensure_valid_payload_status(7, PayloadStatusEnum::Accepted).unwrap_err();
        assert!(matches!(
            err,
            EngineSubmissionError::UnexpectedPayloadStatus(7, ref status) if status == "ACCEPTED"
        ));
    }

    #[test]
    fn syncing_payload_status_maps_to_engine_syncing() {
        let err = ensure_valid_payload_status(7, PayloadStatusEnum::Syncing).unwrap_err();
        assert!(matches!(err, EngineSubmissionError::EngineSyncing(7)));
    }

    #[test]
    fn invalid_payload_status_maps_to_invalid_block() {
        let err = ensure_valid_payload_status(
            7,
            PayloadStatusEnum::Invalid { validation_error: "bad block".to_string() },
        )
        .unwrap_err();
        assert!(matches!(
            err,
            EngineSubmissionError::InvalidBlock(7, ref reason) if reason == "bad block"
        ));
    }

    #[test]
    fn forkchoice_invalid_status_never_maps_to_invalid_block() {
        // Forkchoice INVALID can reflect an unknown or temporarily unprocessable head, so it
        // must not be conflated with the engine's deterministic newPayload content verdict.
        let err = ensure_valid_forkchoice_status(
            7,
            PayloadStatusEnum::Invalid { validation_error: "bad head".to_string() },
        )
        .unwrap_err();
        assert!(matches!(
            err,
            EngineSubmissionError::UnexpectedPayloadStatus(7, ref reason)
                if reason == "forkchoice INVALID: bad head"
        ));

        let err = ensure_valid_forkchoice_status(7, PayloadStatusEnum::Accepted).unwrap_err();
        assert!(matches!(
            err,
            EngineSubmissionError::UnexpectedPayloadStatus(7, ref reason)
                if reason == "forkchoice ACCEPTED"
        ));

        let err = ensure_valid_forkchoice_status(7, PayloadStatusEnum::Syncing).unwrap_err();
        assert!(matches!(err, EngineSubmissionError::EngineSyncing(7)));

        assert!(ensure_valid_forkchoice_status(7, PayloadStatusEnum::Valid).is_ok());
    }

    /// Which engine RPC a scripted call hit, in production sequence order.
    #[derive(Debug, Clone, PartialEq, Eq)]
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
            payload: Box<ExecutionPayloadV3>,
            header_difficulty: u64,
            parent_beacon_block_root: B256,
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
        envelope: Option<ExecutionPayloadEnvelopeV5>,
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
            EngineSubmissionError::Provider(format!("unscripted engine call: {call}"))
        }
    }

    #[async_trait]
    impl EnginePayloadRpc for ScriptedEngine {
        async fn forkchoice_updated_v3(
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

        async fn get_payload_v5(
            &self,
            payload_id: PayloadId,
        ) -> Result<ExecutionPayloadEnvelopeV5, EngineSubmissionError> {
            self.record(EngineCall::GetPayload { payload_id });
            self.envelope.clone().ok_or_else(|| Self::unscripted("getPayload"))
        }

        async fn new_payload_v4(
            &self,
            payload: &ExecutionPayloadV3,
            header_difficulty: u64,
            parent_beacon_block_root: B256,
        ) -> Result<PayloadStatus, EngineSubmissionError> {
            self.record(EngineCall::NewPayload {
                payload: Box::new(payload.clone()),
                header_difficulty,
                parent_beacon_block_root,
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

    /// Payload attributes for block 7, matching [`sample_envelope`]'s block number.
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
            parent_beacon_block_root: Some(sample_parent_beacon_block_root()),
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

    /// Beacon root supplied in payload attributes and forwarded with newPayload.
    fn sample_parent_beacon_block_root() -> B256 {
        B256::from(U256::from(30u64))
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
        EngineCall::NewPayload {
            payload: Box::new(sample_envelope(U256::ZERO).execution_payload),
            header_difficulty: 0,
            parent_beacon_block_root: sample_parent_beacon_block_root(),
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
            envelope: Some(sample_envelope(U256::ZERO)),
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

        assert!(matches!(err, EngineSubmissionError::UnexpectedPayloadStatus(7, _)));
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
            EngineSubmissionError::UnexpectedPayloadStatus(7, ref reason)
                if reason == "forkchoice INVALID: bad head"
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
