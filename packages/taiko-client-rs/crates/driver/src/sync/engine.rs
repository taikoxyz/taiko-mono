//! Helpers for materialising payload attributes into execution engine blocks.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::{eips::BlockNumberOrTag, primitives::B256, providers::Provider};
use alloy_consensus::TxEnvelope;
use alloy_primitives::U256;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV5, ExecutionPayloadV3, ForkchoiceState, ForkchoiceUpdated, PayloadId,
    PayloadStatus, PayloadStatusEnum,
};
use async_trait::async_trait;
use protocol::shasta::{
    etna_fork_timestamp_for_chain, is_etna_at, unzen_active_for_chain_timestamp,
};
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
    /// Chain id used to resolve the fork schedule of a target block.
    fn chain_id(&self) -> u64;

    /// Etna activation time of the chain (`None` while Etna is not scheduled), used to decide
    /// the beacon-root rule of a target block.
    fn etna_fork_timestamp(&self) -> Result<Option<u64>, EngineSubmissionError>;

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
    /// Return the chain id cached on the client at construction time.
    fn chain_id(&self) -> u64 {
        self.chain_id
    }

    /// Resolve the Etna activation time of the client's chain, mapping an unresolvable schedule
    /// into [`EngineSubmissionError::EtnaScheduleUnresolved`].
    fn etna_fork_timestamp(&self) -> Result<Option<u64>, EngineSubmissionError> {
        etna_fork_timestamp_for_chain(self.chain_id).map_err(|source| {
            EngineSubmissionError::EtnaScheduleUnresolved { chain_id: self.chain_id, source }
        })
    }

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
///
/// Every fork takes the same Osaka path: `engine_forkchoiceUpdatedV3` with the attributes,
/// `engine_getPayloadV5`, `engine_newPayloadV4` with the root the attributes carried, then a
/// promotion `engine_forkchoiceUpdatedV3` without attributes.
#[instrument(skip(rpc, payload), fields(payload_id = tracing::field::Empty))]
async fn apply_payload_internal<R: EnginePayloadRpc>(
    rpc: &R,
    payload: &TaikoPayloadAttributes,
    parent_hash: B256,
    finalized_block_hash: Option<B256>,
) -> Result<EngineBlockOutcome, EngineSubmissionError> {
    let block_number = payload.l1_origin.block_id.to::<u64>();
    let timestamp = payload.payload_attributes.timestamp;
    ensure_unzen_target(rpc.chain_id(), block_number, timestamp)?;
    // `newPayloadV4` must carry the root sent with the forkchoice update that started the build.
    let parent_beacon_block_root = ensure_fork_beacon_root(
        rpc.etna_fork_timestamp()?,
        block_number,
        timestamp,
        payload.payload_attributes.parent_beacon_block_root,
    )?;

    // Advertise the next payload attributes so the execution engine can build the block body.
    let forkchoice_state = ForkchoiceState {
        head_block_hash: parent_hash,
        safe_block_hash: parent_hash,
        finalized_block_hash: B256::ZERO,
    };
    let fc_response = rpc.forkchoice_updated_v3(forkchoice_state, Some(payload.clone())).await?;
    ensure_valid_forkchoice_status(block_number, fc_response.payload_status.status)?;

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

    // Fetch the constructed payload; Taiko's `blockValue` carries the block's zk gas, which
    // `newPayloadV4` takes back as the header difficulty.
    let envelope = rpc.get_payload_v5(payload_id).await?;
    let execution_payload = envelope.execution_payload;
    let block_hash = execution_payload.payload_inner.payload_inner.block_hash;
    let block_number = execution_payload.payload_inner.payload_inner.block_number;
    let header_difficulty = header_difficulty_from_block_value(block_number, envelope.block_value)?;

    debug!(
        block_number,
        block_hash = ?block_hash,
        header_difficulty,
        payload_id = %payload_id,
        "engine accepted execution payload"
    );

    let outcome = submit_payload_to_engine(
        rpc,
        &execution_payload,
        header_difficulty,
        parent_beacon_block_root,
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

/// Reject a target before Unzen, before any engine call.
///
/// The Osaka Engine API methods build and import only Unzen and later blocks, so pre-Unzen
/// history can only come from P2P sync or a snapshot. A fork schedule that cannot be resolved for
/// the chain is rejected the same way.
fn ensure_unzen_target(
    chain_id: u64,
    block_number: u64,
    timestamp: u64,
) -> Result<(), EngineSubmissionError> {
    match unzen_active_for_chain_timestamp(chain_id, timestamp) {
        Ok(true) => Ok(()),
        Ok(false) | Err(_) => {
            Err(EngineSubmissionError::PreUnzenTarget { block_number, timestamp, chain_id })
        }
    }
}

/// Enforce the fork's beacon-root rule before any engine call, returning the root that
/// `engine_newPayloadV4` must repeat.
///
/// Every `engine_forkchoiceUpdatedV3` with attributes needs a root, so a missing one is refused
/// for every fork. An Etna target must carry a nonzero root (the L1 state root of its anchor
/// block); a target before Etna must carry exactly the zero root. The execution engine rejects
/// each mismatch, so refusing it here keeps a wrong root from ever reaching it.
fn ensure_fork_beacon_root(
    etna_fork_timestamp: Option<u64>,
    block_number: u64,
    timestamp: u64,
    parent_beacon_block_root: Option<B256>,
) -> Result<B256, EngineSubmissionError> {
    let Some(root) = parent_beacon_block_root else {
        return Err(EngineSubmissionError::MissingBeaconRoot { block_number, timestamp });
    };
    match (is_etna_at(etna_fork_timestamp, timestamp), root.is_zero()) {
        (true, true) => {
            Err(EngineSubmissionError::EtnaTargetWithoutBeaconRoot { block_number, timestamp })
        }
        (false, false) => Err(EngineSubmissionError::PreEtnaTargetWithBeaconRoot {
            block_number,
            timestamp,
            root,
        }),
        _ => Ok(root),
    }
}

/// Convert `engine_getPayloadV5`'s `blockValue`, which Taiko uses for the block's finalized zk
/// gas, into the u64 `headerDifficulty` of the matching `engine_newPayloadV4` call.
fn header_difficulty_from_block_value(
    block_number: u64,
    block_value: U256,
) -> Result<u64, EngineSubmissionError> {
    u64::try_from(block_value)
        .map_err(|_| EngineSubmissionError::HeaderDifficultyOverflow { block_number, block_value })
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
fn ensure_valid_forkchoice_status(
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

/// Common flow to submit a payload to the engine, promote forkchoice, and read back the block.
async fn submit_payload_to_engine<R: EnginePayloadRpc>(
    rpc: &R,
    execution_payload: &ExecutionPayloadV3,
    header_difficulty: u64,
    parent_beacon_block_root: B256,
    finalized_block_hash: Option<B256>,
    payload_id: PayloadId,
) -> Result<EngineBlockOutcome, EngineSubmissionError> {
    let block_hash = execution_payload.payload_inner.payload_inner.block_hash;
    let block_number = execution_payload.payload_inner.payload_inner.block_number;

    let status =
        rpc.new_payload_v4(execution_payload, header_difficulty, parent_beacon_block_root).await?;
    ensure_valid_payload_status(block_number, status.status)?;

    let promoted_state = promotion_forkchoice_state(block_hash, finalized_block_hash);
    let promotion = rpc.forkchoice_updated_v3(promoted_state, None).await?;
    ensure_valid_forkchoice_status(block_number, promotion.payload_status.status)?;

    let block = fetch_block_by_number(rpc, block_number).await?;
    ensure_inserted_block_hash(block_number, block_hash, block.header.hash)?;

    Ok(EngineBlockOutcome { block, payload_id })
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, B256, Bloom, Bytes, U256};
    use alloy_eips::eip7685::Requests;
    use alloy_rpc_types_engine::{BlobsBundleV2, ExecutionPayloadV1, ExecutionPayloadV2};
    use alloy_transport::mock::Asserter;
    use protocol::shasta::{
        PayloadAttributesInput, build_payload_attributes,
        constants::{TAIKO_DEVNET_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID},
    };

    use crate::test_support::mock_client_with_l1_asserter;

    /// zk gas the scripted engine reports through `getPayloadV5.blockValue`.
    const SAMPLE_ZK_GAS: u64 = 1234;

    fn sample_payload(timestamp: u64) -> ExecutionPayloadV3 {
        ExecutionPayloadV3 {
            payload_inner: ExecutionPayloadV2 {
                payload_inner: ExecutionPayloadV1 {
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
                },
                withdrawals: vec![],
            },
            blob_gas_used: 0,
            excess_blob_gas: 0,
        }
    }

    fn sample_envelope(block_value: U256) -> ExecutionPayloadEnvelopeV5 {
        ExecutionPayloadEnvelopeV5 {
            execution_payload: sample_payload(1),
            block_value,
            blobs_bundle: BlobsBundleV2::default(),
            should_override_builder: false,
            execution_requests: Requests::default(),
        }
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
    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    enum EngineCall {
        ForkchoiceWithAttributes {
            head: B256,
            safe: B256,
            finalized: B256,
            attrs_block_number: u64,
            attrs_payload_id: [u8; 8],
            attrs_parent_beacon_block_root: Option<B256>,
        },
        GetPayload {
            payload_id: PayloadId,
        },
        NewPayload {
            block_hash: B256,
            block_number: u64,
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
        /// Chain id reported to the fork checks; `None` means the internal devnet, whose Unzen
        /// fork is active from genesis.
        chain_id: Option<u64>,
        /// Etna activation time reported to the root guard; `None` leaves Etna unscheduled.
        etna_fork_timestamp: Option<u64>,
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
        fn chain_id(&self) -> u64 {
            self.chain_id.unwrap_or(TAIKO_DEVNET_CHAIN_ID)
        }

        fn etna_fork_timestamp(&self) -> Result<Option<u64>, EngineSubmissionError> {
            Ok(self.etna_fork_timestamp)
        }

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
                    attrs_parent_beacon_block_root: attrs
                        .payload_attributes
                        .parent_beacon_block_root,
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
                block_hash: payload.payload_inner.payload_inner.block_hash,
                block_number: payload.payload_inner.payload_inner.block_number,
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

    /// Unzen payload attributes for block 7 at `timestamp`, matching [`sample_payload`]'s block
    /// number and carrying the zero root every pre-Etna build sends.
    fn sample_attributes_at(timestamp: u64) -> TaikoPayloadAttributes {
        sample_attributes_with_root(timestamp, Some(B256::ZERO))
    }

    /// Payload attributes for block 7 at `timestamp` carrying `parent_beacon_block_root`.
    fn sample_attributes_with_root(
        timestamp: u64,
        parent_beacon_block_root: Option<B256>,
    ) -> TaikoPayloadAttributes {
        let mut attributes = build_payload_attributes(PayloadAttributesInput {
            beneficiary: Address::from([1u8; 20]),
            timestamp,
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
            parent_beacon_block_root,
            anchor_transaction: None,
        });
        attributes.l1_origin.build_payload_args_id = *expected_payload_id().0;
        attributes
    }

    /// Devnet Unzen payload attributes for block 7.
    fn sample_attributes() -> TaikoPayloadAttributes {
        sample_attributes_at(1)
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
            attrs_parent_beacon_block_root: Some(B256::ZERO),
        }
    }

    /// Expected getPayload log entry: the id handed back by the attribute forkchoice.
    fn get_payload_call() -> EngineCall {
        EngineCall::GetPayload { payload_id: engine_payload_id() }
    }

    /// Expected newPayload log entry: the block advertised by getPayload, its `blockValue` as
    /// the header difficulty, and the zero root the Unzen attributes carried.
    fn new_payload_call() -> EngineCall {
        EngineCall::NewPayload {
            block_hash: sample_block_hash(),
            block_number: 7,
            header_difficulty: SAMPLE_ZK_GAS,
            parent_beacon_block_root: B256::ZERO,
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
            envelope: Some(sample_envelope(U256::from(SAMPLE_ZK_GAS))),
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
    }

    /// An Unzen target goes through FCUv3 with its attributes, getPayloadV5, newPayloadV4 with
    /// the zero root those attributes carried and `blockValue` as the difficulty, then a
    /// promotion FCUv3 without attributes.
    #[tokio::test]
    async fn apply_payload_drives_unzen_target_through_osaka_methods() {
        let engine = scripted_happy_engine();

        apply_payload_internal(
            &engine,
            &sample_attributes(),
            sample_parent_hash(),
            Some(sample_finalized_hash()),
        )
        .await
        .expect("valid Unzen sequence must succeed");

        assert_eq!(
            engine.calls(),
            vec![
                EngineCall::ForkchoiceWithAttributes {
                    head: sample_parent_hash(),
                    safe: sample_parent_hash(),
                    finalized: B256::ZERO,
                    attrs_block_number: 7,
                    attrs_payload_id: *expected_payload_id().0,
                    attrs_parent_beacon_block_root: Some(B256::ZERO),
                },
                EngineCall::GetPayload { payload_id: engine_payload_id() },
                EngineCall::NewPayload {
                    block_hash: sample_block_hash(),
                    block_number: 7,
                    header_difficulty: SAMPLE_ZK_GAS,
                    parent_beacon_block_root: B256::ZERO,
                },
                EngineCall::PromotionForkchoice {
                    head: sample_block_hash(),
                    safe: sample_finalized_hash(),
                    finalized: sample_finalized_hash(),
                },
                readback_call(),
            ]
        );
    }

    #[tokio::test]
    async fn apply_payload_rejects_block_value_beyond_u64_before_new_payload() {
        let block_value = U256::from(u64::MAX) + U256::from(1u64);
        let engine = ScriptedEngine {
            envelope: Some(sample_envelope(block_value)),
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
            EngineSubmissionError::HeaderDifficultyOverflow { block_number: 7, block_value: value }
                if value == block_value
        ));
        assert_eq!(
            engine.calls(),
            vec![attrs_call(), get_payload_call()],
            "no newPayload may be sent with a truncated header difficulty"
        );
    }

    /// The Osaka methods reject targets before Unzen, so the driver refuses them before any
    /// engine call; an unresolvable fork schedule is refused the same way.
    #[tokio::test]
    async fn apply_payload_rejects_pre_unzen_target_without_engine_calls() {
        let mainnet_unzen =
            protocol::shasta::unzen_fork_timestamp_for_chain(TAIKO_MAINNET_CHAIN_ID)
                .expect("mainnet schedules Unzen");
        for (chain_id, timestamp) in [(TAIKO_MAINNET_CHAIN_ID, mainnet_unzen - 1), (u64::MAX, 1)] {
            let engine = ScriptedEngine { chain_id: Some(chain_id), ..scripted_happy_engine() };

            let err = apply_payload_internal(
                &engine,
                &sample_attributes_at(timestamp),
                sample_parent_hash(),
                Some(sample_finalized_hash()),
            )
            .await
            .unwrap_err();

            assert!(
                matches!(
                    err,
                    EngineSubmissionError::PreUnzenTarget { block_number: 7, timestamp: t, .. }
                        if t == timestamp
                ),
                "chain {chain_id}: unexpected error {err:?}"
            );
            assert!(engine.calls().is_empty(), "chain {chain_id}: no engine call may be made");
        }
    }

    /// Etna activation used by the root-guard tests (the devnet activates Unzen at genesis).
    const SAMPLE_ETNA_TIMESTAMP: u64 = 100;

    /// Nonzero root an Etna target carries: the L1 state root of its anchor block.
    fn sample_etna_root() -> B256 {
        B256::with_last_byte(0xaa)
    }

    /// An Etna target takes the same Osaka path, and `newPayloadV4` carries the exact nonzero
    /// root its attributes carried and `blockValue` as the difficulty, including the zero zk gas
    /// of an empty Etna block.
    #[tokio::test]
    async fn apply_payload_drives_etna_target_with_its_root_through_osaka_methods() {
        for zk_gas in [0, SAMPLE_ZK_GAS] {
            let engine = ScriptedEngine {
                etna_fork_timestamp: Some(SAMPLE_ETNA_TIMESTAMP),
                envelope: Some(sample_envelope(U256::from(zk_gas))),
                ..scripted_happy_engine()
            };

            apply_payload_internal(
                &engine,
                &sample_attributes_with_root(SAMPLE_ETNA_TIMESTAMP, Some(sample_etna_root())),
                sample_parent_hash(),
                Some(sample_finalized_hash()),
            )
            .await
            .expect("valid Etna sequence must succeed");

            assert_eq!(
                engine.calls(),
                vec![
                    EngineCall::ForkchoiceWithAttributes {
                        head: sample_parent_hash(),
                        safe: sample_parent_hash(),
                        finalized: B256::ZERO,
                        attrs_block_number: 7,
                        attrs_payload_id: *expected_payload_id().0,
                        attrs_parent_beacon_block_root: Some(sample_etna_root()),
                    },
                    EngineCall::GetPayload { payload_id: engine_payload_id() },
                    EngineCall::NewPayload {
                        block_hash: sample_block_hash(),
                        block_number: 7,
                        header_difficulty: zk_gas,
                        parent_beacon_block_root: sample_etna_root(),
                    },
                    promotion_call(),
                    readback_call(),
                ],
                "zk gas {zk_gas}"
            );
        }
    }

    /// An Etna target without a nonzero root is refused before any engine call: a zero root
    /// breaks the Etna rule and a missing root breaks every fork's rule.
    #[tokio::test]
    async fn apply_payload_rejects_etna_target_without_root_before_engine_calls() {
        for root in [None, Some(B256::ZERO)] {
            let engine = ScriptedEngine {
                etna_fork_timestamp: Some(SAMPLE_ETNA_TIMESTAMP),
                ..scripted_happy_engine()
            };

            let err = apply_payload_internal(
                &engine,
                &sample_attributes_with_root(SAMPLE_ETNA_TIMESTAMP, root),
                sample_parent_hash(),
                Some(sample_finalized_hash()),
            )
            .await
            .unwrap_err();

            let expected = if root.is_some() {
                matches!(
                    err,
                    EngineSubmissionError::EtnaTargetWithoutBeaconRoot {
                        block_number: 7,
                        timestamp: SAMPLE_ETNA_TIMESTAMP,
                    }
                )
            } else {
                matches!(
                    err,
                    EngineSubmissionError::MissingBeaconRoot {
                        block_number: 7,
                        timestamp: SAMPLE_ETNA_TIMESTAMP,
                    }
                )
            };
            assert!(expected, "root {root:?}: unexpected error {err:?}");
            assert!(engine.calls().is_empty(), "root {root:?}: no engine call may be made");
        }
    }

    /// A pre-Etna target without a root is refused before any engine call, whether Etna is
    /// unscheduled or scheduled later: `forkchoiceUpdatedV3` needs the explicit zero root.
    #[tokio::test]
    async fn apply_payload_rejects_unzen_target_without_root_before_engine_calls() {
        for etna_fork_timestamp in [None, Some(SAMPLE_ETNA_TIMESTAMP)] {
            let engine = ScriptedEngine { etna_fork_timestamp, ..scripted_happy_engine() };
            let timestamp = SAMPLE_ETNA_TIMESTAMP - 1;

            let err = apply_payload_internal(
                &engine,
                &sample_attributes_with_root(timestamp, None),
                sample_parent_hash(),
                Some(sample_finalized_hash()),
            )
            .await
            .unwrap_err();

            assert!(
                matches!(
                    err,
                    EngineSubmissionError::MissingBeaconRoot { block_number: 7, timestamp: t }
                        if t == timestamp
                ),
                "Etna at {etna_fork_timestamp:?}: unexpected error {err:?}"
            );
            assert!(
                engine.calls().is_empty(),
                "Etna at {etna_fork_timestamp:?}: no engine call may be made"
            );
        }
    }

    /// A pre-Etna target with a nonzero root is refused before any engine call, whether Etna is
    /// unscheduled or scheduled later.
    #[tokio::test]
    async fn apply_payload_rejects_unzen_target_with_root_before_engine_calls() {
        for etna_fork_timestamp in [None, Some(SAMPLE_ETNA_TIMESTAMP)] {
            let engine = ScriptedEngine { etna_fork_timestamp, ..scripted_happy_engine() };
            let timestamp = SAMPLE_ETNA_TIMESTAMP - 1;

            let err = apply_payload_internal(
                &engine,
                &sample_attributes_with_root(timestamp, Some(sample_etna_root())),
                sample_parent_hash(),
                Some(sample_finalized_hash()),
            )
            .await
            .unwrap_err();

            assert!(
                matches!(
                    err,
                    EngineSubmissionError::PreEtnaTargetWithBeaconRoot {
                        block_number: 7,
                        timestamp: t,
                        root,
                    } if t == timestamp && root == sample_etna_root()
                ),
                "Etna at {etna_fork_timestamp:?}: unexpected error {err:?}"
            );
            assert!(
                engine.calls().is_empty(),
                "Etna at {etna_fork_timestamp:?}: no engine call may be made"
            );
        }
    }

    /// The client resolves the Etna time from its chain id; a chain without a fork schedule is
    /// refused instead of being treated as pre-Etna.
    #[test]
    fn client_etna_fork_timestamp_follows_the_chain_schedule() {
        let mut client = mock_client_with_l1_asserter(Asserter::new());
        assert!(matches!(
            EnginePayloadRpc::etna_fork_timestamp(&client),
            Err(EngineSubmissionError::EtnaScheduleUnresolved { chain_id: 0, .. })
        ));

        client.chain_id = TAIKO_MAINNET_CHAIN_ID;
        assert_eq!(EnginePayloadRpc::etna_fork_timestamp(&client).unwrap(), None);
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
