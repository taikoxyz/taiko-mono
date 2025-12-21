//! Production paths that materialise inputs into execution blocks.

use std::sync::Arc;

use super::{ProductionError, ProductionPathKind, kind::ProductionInput};
use crate::{
    derivation::DerivationPipeline,
    error::DriverError,
    sync::{
        engine::{EngineBlockOutcome, ExecutionPayloadInjector, PayloadApplier},
        error::SyncError,
    },
};
use async_trait::async_trait;

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

/// Path that materialises preconfirmation payloads directly into the execution engine.
pub struct PreconfirmationPath<I>
where
    I: ExecutionPayloadInjector,
{
    injector: I,
}

impl<I> PreconfirmationPath<I>
where
    I: ExecutionPayloadInjector,
{
    /// Construct a preconfirmation path backed by the given injector.
    pub fn new(injector: I) -> Self {
        Self { injector }
    }
}

#[async_trait]
impl<I> BlockProductionPath for PreconfirmationPath<I>
where
    I: ExecutionPayloadInjector + Send + Sync,
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
                let payload = preconf.execution_payload();
                let block_number = payload.execution_payload.block_number;
                let outcome =
                    self.injector.apply_execution_payload(payload, None).await.map_err(|err| {
                        DriverError::PreconfInjectionFailed { block_number, source: err }
                    })?;
                Ok(vec![outcome])
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
    use crate::{production::PreconfPayload, sync::error::EngineSubmissionError};
    use alloy::rpc::types::Log;
    use alloy_consensus::TxEnvelope;
    use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
    use alloy_rpc_types::eth::Block as RpcBlock;
    use alloy_rpc_types_engine::{ExecutionPayloadInputV2, ExecutionPayloadV1, PayloadId};
    use std::sync::{Arc, Mutex};
    use tokio::runtime::Runtime;

    fn sample_payload(block_number: u64) -> ExecutionPayloadInputV2 {
        ExecutionPayloadInputV2 {
            execution_payload: ExecutionPayloadV1 {
                parent_hash: B256::ZERO,
                fee_recipient: Address::ZERO,
                state_root: B256::ZERO,
                receipts_root: B256::ZERO,
                logs_bloom: Bloom::default(),
                prev_randao: B256::ZERO,
                block_number,
                gas_limit: 0,
                gas_used: 0,
                timestamp: 0,
                extra_data: Bytes::new(),
                base_fee_per_gas: U256::ZERO,
                block_hash: B256::ZERO,
                transactions: Vec::new(),
            },
            withdrawals: None,
        }
    }

    #[derive(Clone, Default)]
    struct MockInjector {
        calls: Arc<Mutex<u64>>,
    }

    impl MockInjector {
        fn calls(&self) -> u64 {
            *self.calls.lock().unwrap()
        }
    }

    #[async_trait]
    impl ExecutionPayloadInjector for MockInjector {
        async fn apply_execution_payload(
            &self,
            _payload: &ExecutionPayloadInputV2,
            _finalized_block_hash: Option<B256>,
        ) -> Result<EngineBlockOutcome, EngineSubmissionError> {
            let mut guard = self.calls.lock().unwrap();
            *guard += 1;
            let block: RpcBlock<TxEnvelope> = RpcBlock::<TxEnvelope>::default();
            let payload_id = PayloadId::new([0u8; 8]);
            Ok(EngineBlockOutcome { block, payload_id })
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
        let router = crate::production::ProductionRouter::new(vec![canonical.clone()]);
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
        let router = crate::production::ProductionRouter::new(vec![preconf.clone()]);
        let payload = Arc::new(PreconfPayload::new(sample_payload(0)));

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(router.produce(ProductionInput::Preconfirmation(payload)))
            .expect("router should route to preconfirmation path");

        assert_eq!(preconf.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    #[test]
    fn preconfirmation_path_delegates_to_injector() {
        let injector = MockInjector::default();
        let path = PreconfirmationPath::new(injector.clone());
        let payload = Arc::new(PreconfPayload::new(sample_payload(0)));

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(path.produce(ProductionInput::Preconfirmation(payload)))
            .expect("preconfirmation path should succeed");

        assert_eq!(injector.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }
}
