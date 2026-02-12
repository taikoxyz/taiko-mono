//! Production paths that materialise inputs into execution blocks.

use std::{sync::Arc, time::Instant};

use super::{ProductionError, ProductionInput, ProductionPathKind};
pub use crate::sync::engine::EngineBlockOutcome;
use crate::{
    derivation::DerivationPipeline,
    error::DriverError,
    metrics::DriverMetrics,
    sync::{
        AtomicCanonicalTip, CanonicalTipState, engine::PayloadApplier, error::SyncError,
        is_stale_preconf,
    },
};
use alloy::{eips::BlockNumberOrTag, primitives::B256, providers::Provider};
use async_trait::async_trait;
use metrics::{counter, histogram};
use rpc::{RpcClientError, client::Client};
use tracing::{debug, error, warn};

/// A block-production path capable of materialising the provided input into execution blocks.
///
/// Each path specialises on a `ProductionPathKind` and may reject unsupported inputs.
#[async_trait]
pub trait BlockProductionPath: Send + Sync {
    /// Identify this path (for routing/metrics).
    fn kind(&self) -> ProductionPathKind;

    /// Optional hook to initialise internal cursors or resources.
    async fn prepare(&self) -> Result<(), DriverError> {
        Ok(())
    }

    /// Turn the given production input into one or more execution engine blocks.
    async fn produce(&self, input: ProductionInput)
    -> Result<Vec<EngineBlockOutcome>, DriverError>;
}

/// Resolve a parent hash for a given block number.
#[async_trait]
pub trait BlockHashReader: Send + Sync {
    /// Fetch the block hash for the given block number.
    async fn block_hash_by_number(&self, block_number: u64) -> Result<B256, DriverError>;
}

#[async_trait]
impl<P> BlockHashReader for Client<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Fetch the parent hash for the given block number via RPC.
    async fn block_hash_by_number(&self, block_number: u64) -> Result<B256, DriverError> {
        let block = self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map_err(|err| DriverError::Rpc(RpcClientError::Provider(err.to_string())))?
            .ok_or(DriverError::BlockNotFound(block_number))?;
        Ok(block.hash())
    }
}

/// Path that materialises preconfirmation payload attributes into the execution engine.
pub struct PreconfirmationPath<A>
where
    A: PayloadApplier + BlockHashReader,
{
    applier: A,
    canonical_tip_state: Arc<AtomicCanonicalTip>,
}

impl<A> PreconfirmationPath<A>
where
    A: PayloadApplier + BlockHashReader,
{
    /// Construct a preconfirmation path with a canonical block tip boundary.
    ///
    /// Blocks at or below this tip are considered event-synced canonical history and must never be
    /// rewritten by preconfirmation payloads.
    pub fn new_with_canonical_tip_state(
        applier: A,
        canonical_tip_state: Arc<AtomicCanonicalTip>,
    ) -> Self {
        Self { applier, canonical_tip_state }
    }
}

#[async_trait]
impl<A> BlockProductionPath for PreconfirmationPath<A>
where
    A: PayloadApplier + BlockHashReader + Send + Sync,
{
    /// Identify this path as preconfirmation.
    fn kind(&self) -> ProductionPathKind {
        ProductionPathKind::Preconfirmation
    }

    /// Produce blocks by injecting the preconfirmation payloads.
    async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        match input {
            ProductionInput::Preconfirmation(preconf) => {
                let payload = preconf.payload();
                let block_number = preconf.block_number();
                let parent_number = block_number.saturating_sub(1);

                match self.canonical_tip_state.load(std::sync::atomic::Ordering::Relaxed) {
                    CanonicalTipState::Unknown => {
                        warn!(
                            block_number,
                            "rejecting preconfirmation production: canonical tip unknown"
                        );
                        return Err(DriverError::PreconfIngressNotReady);
                    }
                    CanonicalTipState::Known(canonical_block_tip) => {
                        if is_stale_preconf(block_number, canonical_block_tip) {
                            counter!(DriverMetrics::PRECONF_STALE_DROPPED_TOTAL).increment(1);
                            counter!(DriverMetrics::PRECONF_STALE_DROPPED_PRODUCTION_TOTAL)
                                .increment(1);
                            warn!(
                                block_number,
                                canonical_block_tip,
                                "dropping stale preconfirmation at or below canonical event-sync tip"
                            );
                            return Ok(Vec::new());
                        }
                    }
                }

                // Measure parent hash lookup duration.
                let lookup_start = Instant::now();
                let parent_hash_result = self.applier.block_hash_by_number(parent_number).await;
                let lookup_duration_secs = lookup_start.elapsed().as_secs_f64();
                histogram!(DriverMetrics::PRECONF_PARENT_HASH_LOOKUP_DURATION_SECONDS)
                    .record(lookup_duration_secs);

                let parent_hash = match parent_hash_result {
                    Ok(hash) => {
                        debug!(
                            block_number,
                            parent_number,
                            ?hash,
                            lookup_duration_secs,
                            "parent hash lookup succeeded"
                        );
                        hash
                    }
                    Err(err) => {
                        counter!(DriverMetrics::PRECONF_PARENT_HASH_LOOKUP_FAILURES_TOTAL)
                            .increment(1);
                        error!(
                            block_number,
                            parent_number,
                            ?err,
                            lookup_duration_secs,
                            "parent hash lookup failed"
                        );
                        return Err(err);
                    }
                };

                let applied =
                    self.applier.apply_payload(payload, parent_hash, None).await.map_err(
                        |err| DriverError::PreconfInjectionFailed { block_number, source: err },
                    )?;
                Ok(vec![applied.outcome])
            }
            ProductionInput::L1ProposalLog(_) => Err(ProductionError::UnsupportedInput {
                path: ProductionPathKind::Preconfirmation,
                input: ProductionPathKind::L1Events,
            }
            .into()),
        }
    }
}

/// `BlockProductionPath` implementation for canonical L1 proposal logs.
pub struct CanonicalL1ProductionPath<D>
where
    D: DerivationPipeline + ?Sized,
{
    derivation: Arc<D>,
    applier: Arc<dyn PayloadApplier + Send + Sync>,
}

impl<D> CanonicalL1ProductionPath<D>
where
    D: DerivationPipeline + ?Sized,
{
    /// Construct a new canonical path backed by the provided derivation pipeline.
    pub fn new(derivation: Arc<D>, applier: Arc<dyn PayloadApplier + Send + Sync>) -> Self {
        Self { derivation, applier }
    }
}

#[async_trait]
impl<D> BlockProductionPath for CanonicalL1ProductionPath<D>
where
    D: DerivationPipeline + Send + Sync + ?Sized + 'static,
{
    /// Identify this path as canonical L1 events.
    fn kind(&self) -> ProductionPathKind {
        ProductionPathKind::L1Events
    }

    /// Produce blocks by processing L1 proposal logs via the derivation pipeline.
    async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        match input {
            ProductionInput::L1ProposalLog(log) => self
                .derivation
                .process_proposal(&log, self.applier.as_ref())
                .await
                .map_err(SyncError::from)
                .map_err(DriverError::from),
            ProductionInput::Preconfirmation(_) => Err(ProductionError::UnsupportedInput {
                path: ProductionPathKind::L1Events,
                input: ProductionPathKind::Preconfirmation,
            }
            .into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        production::{PreconfPayload, ProductionRouter},
        sync::{engine::AppliedPayload, error::EngineSubmissionError},
    };
    use alethia_reth_primitives::payload::attributes::{
        RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
    };
    use alloy::rpc::types::Log;
    use alloy_consensus::TxEnvelope;
    use alloy_primitives::{Address, B256, Bytes, U256};
    use alloy_rpc_types::eth::Block as RpcBlock;
    use alloy_rpc_types_engine::{
        ExecutionPayloadInputV2, ExecutionPayloadV1, PayloadAttributes as EthPayloadAttributes,
        PayloadId,
    };
    use std::sync::{Arc, Mutex};
    use tokio::runtime::Runtime;

    fn sample_payload(block_number: u64) -> TaikoPayloadAttributes {
        let payload_attributes = EthPayloadAttributes {
            timestamp: 0,
            prev_randao: B256::ZERO,
            suggested_fee_recipient: Address::ZERO,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root: None,
        };
        let block_metadata = TaikoBlockMetadata {
            beneficiary: Address::ZERO,
            gas_limit: 0,
            timestamp: U256::ZERO,
            mix_hash: B256::ZERO,
            tx_list: Some(Bytes::new()),
            extra_data: Bytes::new(),
        };
        let l1_origin = RpcL1Origin {
            block_id: U256::from(block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: None,
            l1_block_hash: None,
            build_payload_args_id: [0u8; 8],
            is_forced_inclusion: false,
            signature: [0u8; 65],
        };

        TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: U256::ZERO,
            block_metadata,
            l1_origin,
            anchor_transaction: None,
        }
    }

    #[derive(Clone, Default)]
    struct MockApplier {
        calls: Arc<Mutex<u64>>,
        expected_parent: u64,
        parent_hash: B256,
    }

    impl MockApplier {
        fn new(expected_parent: u64, parent_hash: B256) -> Self {
            Self { calls: Arc::new(Mutex::new(0)), expected_parent, parent_hash }
        }
        fn calls(&self) -> u64 {
            *self.calls.lock().unwrap()
        }
    }

    #[async_trait]
    impl PayloadApplier for MockApplier {
        async fn attributes_to_blocks(
            &self,
            _payloads: &[TaikoPayloadAttributes],
        ) -> Result<Vec<EngineBlockOutcome>, EngineSubmissionError> {
            Ok(Vec::new())
        }

        async fn apply_payload(
            &self,
            _payload: &TaikoPayloadAttributes,
            _parent_hash: B256,
            _finalized_block_hash: Option<B256>,
        ) -> Result<AppliedPayload, EngineSubmissionError> {
            let mut guard = self.calls.lock().unwrap();
            *guard += 1;
            let block: RpcBlock<TxEnvelope> = RpcBlock::<TxEnvelope>::default();
            let payload_id = PayloadId::new([0u8; 8]);
            Ok(AppliedPayload {
                outcome: EngineBlockOutcome { block, payload_id },
                payload: ExecutionPayloadInputV2 {
                    execution_payload: ExecutionPayloadV1 {
                        parent_hash: B256::ZERO,
                        fee_recipient: Address::ZERO,
                        state_root: B256::ZERO,
                        receipts_root: B256::ZERO,
                        logs_bloom: Default::default(),
                        prev_randao: B256::ZERO,
                        block_number: 0,
                        gas_limit: 0,
                        gas_used: 0,
                        timestamp: 0,
                        extra_data: Bytes::new(),
                        base_fee_per_gas: U256::ZERO,
                        block_hash: B256::ZERO,
                        transactions: Vec::new(),
                    },
                    withdrawals: None,
                },
            })
        }
    }

    #[async_trait]
    impl BlockHashReader for MockApplier {
        async fn block_hash_by_number(&self, block_number: u64) -> Result<B256, DriverError> {
            if block_number == self.expected_parent {
                Ok(self.parent_hash)
            } else {
                Err(DriverError::BlockNotFound(block_number))
            }
        }
    }

    #[derive(Clone)]
    struct MockPath {
        kind: ProductionPathKind,
        calls: Arc<Mutex<u64>>,
    }

    impl MockPath {
        fn new(kind: ProductionPathKind) -> Self {
            Self { kind, calls: Arc::new(Mutex::new(0)) }
        }
        fn calls(&self) -> u64 {
            *self.calls.lock().unwrap()
        }
    }

    #[async_trait]
    impl BlockProductionPath for MockPath {
        fn kind(&self) -> ProductionPathKind {
            self.kind
        }

        async fn produce(
            &self,
            _input: ProductionInput,
        ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
            let mut guard = self.calls.lock().unwrap();
            *guard += 1;
            let block: RpcBlock<TxEnvelope> = RpcBlock::<TxEnvelope>::default();
            let payload_id = PayloadId::new([0u8; 8]);
            Ok(vec![EngineBlockOutcome { block, payload_id }])
        }
    }

    #[test]
    fn router_routes_l1_to_canonical() {
        let canonical = Arc::new(MockPath::new(ProductionPathKind::L1Events));
        let router = ProductionRouter::new(vec![canonical.clone()]);
        let log = Log::default();

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(router.produce(ProductionInput::L1ProposalLog(log)))
            .expect("router should route to canonical path");

        assert_eq!(canonical.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    #[test]
    fn router_routes_preconf_to_preconf_path() {
        let preconf = Arc::new(MockPath::new(ProductionPathKind::Preconfirmation));
        let router = ProductionRouter::new(vec![preconf.clone()]);
        let payload = Arc::new(PreconfPayload::new(sample_payload(0)));

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(router.produce(ProductionInput::Preconfirmation(payload)))
            .expect("router should route to preconfirmation path");

        assert_eq!(preconf.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    #[test]
    fn preconfirmation_path_delegates_to_applier() {
        let parent_hash = B256::from([1u8; 32]);
        let applier = MockApplier::new(0, parent_hash);
        let canonical_tip = Arc::new(AtomicCanonicalTip::new(CanonicalTipState::Known(0)));
        let path =
            PreconfirmationPath::new_with_canonical_tip_state(applier.clone(), canonical_tip);
        let payload = Arc::new(PreconfPayload::new(sample_payload(1)));

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(path.produce(ProductionInput::Preconfirmation(payload)))
            .expect("preconfirmation path should succeed");

        assert_eq!(applier.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    #[test]
    fn preconfirmation_path_drops_block_at_or_below_canonical_tip() {
        let parent_hash = B256::from([1u8; 32]);
        let applier = MockApplier::new(0, parent_hash);
        let canonical_tip = Arc::new(AtomicCanonicalTip::new(CanonicalTipState::Known(1)));
        let path =
            PreconfirmationPath::new_with_canonical_tip_state(applier.clone(), canonical_tip);
        let payload = Arc::new(PreconfPayload::new(sample_payload(1)));

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(path.produce(ProductionInput::Preconfirmation(payload)))
            .expect("preconfirmation at canonical boundary should be dropped");

        assert_eq!(applier.calls(), 0);
        assert!(outcomes.is_empty());
    }

    #[test]
    fn preconfirmation_path_allows_reorg_above_canonical_tip() {
        let parent_hash = B256::from([1u8; 32]);
        let applier = MockApplier::new(1, parent_hash);
        let canonical_tip = Arc::new(AtomicCanonicalTip::new(CanonicalTipState::Known(1)));
        let path =
            PreconfirmationPath::new_with_canonical_tip_state(applier.clone(), canonical_tip);
        let payload = Arc::new(PreconfPayload::new(sample_payload(2)));

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(path.produce(ProductionInput::Preconfirmation(payload)))
            .expect("preconfirmation above canonical boundary should be allowed");

        assert_eq!(applier.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    #[test]
    fn preconfirmation_path_rejects_when_canonical_tip_unknown() {
        let parent_hash = B256::from([1u8; 32]);
        let applier = MockApplier::new(0, parent_hash);
        let canonical_tip = Arc::new(AtomicCanonicalTip::new(CanonicalTipState::Unknown));
        let path =
            PreconfirmationPath::new_with_canonical_tip_state(applier.clone(), canonical_tip);
        let payload = Arc::new(PreconfPayload::new(sample_payload(1)));

        let rt = Runtime::new().unwrap();
        let err = rt
            .block_on(path.produce(ProductionInput::Preconfirmation(payload)))
            .expect_err("unknown canonical tip should reject preconfirmation production");

        assert!(matches!(err, DriverError::PreconfIngressNotReady));
        assert_eq!(applier.calls(), 0);
    }
}
