//! Abstractions for multiple block-production paths.
//!
//! Canonical flow: `ProductionInput::L1ProposalLog` is fed by the event scanner and routed to
//! `CanonicalL1ProductionPath`, which delegates to the derivation pipeline.
//!
//! Preconfirmation flow: external components can inject prebuilt payloads via the
//! `preconfirmation_sender` exposed on `EventSyncer` when `DriverConfig.preconfirmation_enabled` is
//! true. These payloads enter the `ProductionRouter` as `ProductionInput::Preconfirmation` and are
//! applied through `PreconfirmationPath`, which wraps `ExecutionPayloadInjector` to submit the
//! payload directly to the engine.

use alloy::rpc::types::Log;
use alloy_rpc_types_engine::ExecutionPayloadInputV2;
use async_trait::async_trait;
use std::{fmt::Debug, sync::Arc};

use crate::{
    error::DriverError,
    sync::engine::{EngineBlockOutcome, ExecutionPayloadInjector, PayloadApplier},
};

/// Errors specific to the production routing layer.
#[derive(thiserror::Error, Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProductionError {
    /// Input was dispatched to a path that does not support it.
    #[error("{input:?} input is unsupported by {path:?} path")]
    UnsupportedInput { path: ProductionPathKind, input: ProductionPathKind },

    /// No registered path can handle the requested input kind.
    #[error("no production path registered for input {kind:?}")]
    MissingPath { kind: ProductionPathKind },
}

impl From<ProductionError> for DriverError {
    fn from(err: ProductionError) -> Self {
        DriverError::Other(err.into())
    }
}

/// Marker for the source of a block-production request.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ProductionPathKind {
    /// Blocks derived from canonical L1 proposal events (`Inbox::Proposed`).
    L1Events,
    /// Blocks injected via preconfirmation interfaces (e.g. HTTP).
    Preconfirmation,
}

/// Inputs that the driver can turn into L2 blocks.
#[derive(Debug)]
pub enum ProductionInput<'a> {
    /// Standard path: an L1 proposal log emitted by the inbox contract.
    L1ProposalLog(&'a Log),
    /// Preconfirmation path: an externally supplied payload.
    Preconfirmation(&'a (dyn PreconfPayload + Send + Sync)),
}

/// Anything that can be transformed into an execution payload suitable for engine submission.
pub trait PreconfPayload: Send + Sync + Debug {
    /// Convert the preconfirmation payload into an execution payload input.
    fn to_execution_payload(&self) -> ExecutionPayloadInputV2;
}

/// A block-production path capable of materialising the provided input into execution blocks.
#[async_trait]
pub trait BlockProductionPath: Send + Sync {
    /// Identify this path (for routing/metrics).
    fn kind(&self) -> ProductionPathKind;

    /// Optional hook to initialise internal cursors or resources.
    async fn prepare(&self) -> Result<(), DriverError> {
        Ok(())
    }

    /// Turn the given production input into one or more execution engine blocks.
    async fn produce(
        &self,
        input: ProductionInput<'_>,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DriverError>;
}

/// Router that forwards production inputs to the appropriate path implementation.
#[derive(Clone)]
pub struct ProductionRouter {
    paths: Vec<Arc<dyn BlockProductionPath + Send + Sync>>,
}

impl ProductionRouter {
    pub fn new(paths: Vec<Arc<dyn BlockProductionPath + Send + Sync>>) -> Self {
        Self { paths }
    }

    /// Route input to the first compatible path based on the variant.
    pub async fn produce(
        &self,
        input: ProductionInput<'_>,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        let target_kind = match input {
            ProductionInput::L1ProposalLog(_) => ProductionPathKind::L1Events,
            ProductionInput::Preconfirmation(_) => ProductionPathKind::Preconfirmation,
        };

        if let Some(path) = self.paths.iter().find(|path| path.kind() == target_kind) {
            return path.produce(input, applier).await;
        }

        Err(ProductionError::MissingPath { kind: target_kind }.into())
    }
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
    /// Create a new preconfirmation path with the given injector.
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
        input: ProductionInput<'_>,
        _applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        match input {
            ProductionInput::Preconfirmation(preconf) => {
                let payload = preconf.to_execution_payload();
                let outcome = self
                    .injector
                    .apply_execution_payload(&payload, None)
                    .await
                    .map_err(|err| DriverError::Other(err.into()))?;
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sync::{engine::AppliedPayload, error::EngineSubmissionError};
    use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
    use alloy::rpc::types::Log;
    use alloy_consensus::TxEnvelope;
    use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
    use alloy_rpc_types::eth::Block as RpcBlock;
    use alloy_rpc_types_engine::{ExecutionPayloadInputV2, ExecutionPayloadV1, PayloadId};
    use std::sync::{Arc, Mutex};
    use tokio::runtime::Runtime;

    #[derive(Default, Debug)]
    struct DummyPreconfPayload;

    impl PreconfPayload for DummyPreconfPayload {
        fn to_execution_payload(&self) -> ExecutionPayloadInputV2 {
            ExecutionPayloadInputV2 {
                execution_payload: ExecutionPayloadV1 {
                    parent_hash: B256::ZERO,
                    fee_recipient: Address::ZERO,
                    state_root: B256::ZERO,
                    receipts_root: B256::ZERO,
                    logs_bloom: Bloom::default(),
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
            }
        }
    }

    #[derive(Clone, Default)]
    struct NullApplier;

    #[async_trait]
    impl PayloadApplier for NullApplier {
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
            Err(EngineSubmissionError::MissingParent)
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
            _input: ProductionInput<'_>,
            _applier: &(dyn PayloadApplier + Send + Sync),
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
        let applier = NullApplier::default();

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(router.produce(ProductionInput::L1ProposalLog(&log), &applier))
            .expect("router should route to canonical path");

        assert_eq!(canonical.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    #[test]
    fn router_routes_preconf_to_preconf_path() {
        let preconf = Arc::new(MockPath::new(ProductionPathKind::Preconfirmation));
        let router = ProductionRouter::new(vec![preconf.clone()]);
        let payload = DummyPreconfPayload::default();
        let applier = NullApplier::default();

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(router.produce(ProductionInput::Preconfirmation(&payload), &applier))
            .expect("router should route to preconfirmation path");

        assert_eq!(preconf.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    #[test]
    fn preconfirmation_path_delegates_to_injector() {
        let injector = MockInjector::default();
        let path = PreconfirmationPath::new(injector.clone());
        let payload = DummyPreconfPayload::default();
        let applier = NullApplier::default();

        let rt = Runtime::new().unwrap();
        let outcomes = rt
            .block_on(path.produce(ProductionInput::Preconfirmation(&payload), &applier))
            .expect("preconfirmation path should succeed");

        assert_eq!(injector.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }
}
