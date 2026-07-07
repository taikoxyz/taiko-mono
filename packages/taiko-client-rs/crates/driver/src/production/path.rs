//! Production paths that materialise inputs into execution blocks.

use std::{sync::Arc, time::Instant};

use super::{ProductionInput, UnsupportedInputError};
pub use crate::sync::engine::EngineBlockOutcome;
use crate::{
    derivation::ShastaDerivationPipeline,
    error::DriverError,
    metrics::DriverMetrics,
    sync::{engine::PayloadApplier, error::SyncError},
};
use alloy::{eips::BlockNumberOrTag, primitives::B256, providers::Provider};
use async_trait::async_trait;
use rpc::{RpcClientError, client::Client};
use tracing::{debug, error};

/// A block-production path capable of materialising the provided input into execution blocks.
///
/// Each path specialises on one `ProductionInput` variant and rejects the others.
#[async_trait]
pub trait BlockProductionPath: Send + Sync {
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
impl BlockHashReader for Client {
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
    /// Payload applier used for parent-hash lookup and engine submission.
    applier: A,
}

impl<A> PreconfirmationPath<A>
where
    A: PayloadApplier + BlockHashReader,
{
    /// Construct a preconfirmation path backed by a payload applier.
    pub fn new(applier: A) -> Self {
        Self { applier }
    }
}

#[async_trait]
impl<A> BlockProductionPath for PreconfirmationPath<A>
where
    A: PayloadApplier + BlockHashReader + Send + Sync,
{
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

                // Measure parent hash lookup duration.
                let lookup_start = Instant::now();
                let parent_hash_result = self.applier.block_hash_by_number(parent_number).await;
                let lookup_duration_secs = lookup_start.elapsed().as_secs_f64();
                DriverMetrics::preconf_parent_hash_lookup_duration_seconds()
                    .observe(lookup_duration_secs);

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
                        DriverMetrics::preconf_parent_hash_lookup_failures_total().inc();
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

                let outcome =
                    self.applier.apply_payload(payload, parent_hash, None).await.map_err(
                        |err| DriverError::PreconfInjectionFailed { block_number, source: err },
                    )?;
                Ok(vec![outcome])
            }
            ProductionInput::L1ProposalLog(_) => Err(UnsupportedInputError.into()),
        }
    }
}

/// `BlockProductionPath` implementation for canonical L1 proposal logs.
pub struct CanonicalL1ProductionPath {
    /// Derivation pipeline used to decode L1 proposal logs.
    derivation: Arc<ShastaDerivationPipeline>,
    /// Engine payload applier shared with the canonical path.
    applier: Arc<dyn PayloadApplier + Send + Sync>,
}

impl CanonicalL1ProductionPath {
    /// Construct a new canonical path backed by the provided derivation pipeline.
    pub fn new(
        derivation: Arc<ShastaDerivationPipeline>,
        applier: Arc<dyn PayloadApplier + Send + Sync>,
    ) -> Self {
        Self { derivation, applier }
    }
}

#[async_trait]
impl BlockProductionPath for CanonicalL1ProductionPath {
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
            ProductionInput::Preconfirmation(_) => Err(UnsupportedInputError.into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        production::{PreconfPayload, ProductionRouter},
        sync::error::EngineSubmissionError,
    };
    use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
    use alloy::rpc::types::Log;
    use alloy_consensus::TxEnvelope;
    use alloy_primitives::B256;
    use alloy_rpc_types::eth::Block as RpcBlock;
    use alloy_rpc_types_engine::PayloadId;
    use std::sync::{Arc, Mutex};

    #[derive(Clone, Default)]
    struct MockApplier {
        calls: Arc<Mutex<u64>>,
        expected_parent: u64,
        parent_hash: B256,
        /// When set, `apply_payload` returns this engine rejection.
        fail_invalid: bool,
    }

    impl MockApplier {
        fn new(expected_parent: u64, parent_hash: B256) -> Self {
            Self {
                calls: Arc::new(Mutex::new(0)),
                expected_parent,
                parent_hash,
                fail_invalid: false,
            }
        }
        fn calls(&self) -> u64 {
            *self.calls.lock().unwrap()
        }
    }

    #[async_trait]
    impl PayloadApplier for MockApplier {
        async fn apply_payload(
            &self,
            _payload: &TaikoPayloadAttributes,
            _parent_hash: B256,
            _finalized_block_hash: Option<B256>,
        ) -> Result<EngineBlockOutcome, EngineSubmissionError> {
            {
                let mut guard = self.calls.lock().unwrap();
                *guard += 1;
            }
            if self.fail_invalid {
                // Carry a sentinel block number distinct from any payload number a test would
                // use, so `PreconfInjectionFailed.block_number` asserting on the payload's number
                // proves that number flows from the PAYLOAD, not from this engine error.
                return Err(EngineSubmissionError::InvalidBlock(u64::MAX, "mock reject".into()));
            }
            let block: RpcBlock<TxEnvelope> = RpcBlock::<TxEnvelope>::default();
            let payload_id = PayloadId::new([0u8; 8]);
            Ok(EngineBlockOutcome { block, payload_id })
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
        calls: Arc<Mutex<u64>>,
    }

    impl MockPath {
        fn new() -> Self {
            Self { calls: Arc::new(Mutex::new(0)) }
        }
        fn calls(&self) -> u64 {
            *self.calls.lock().unwrap()
        }
    }

    #[async_trait]
    impl BlockProductionPath for MockPath {
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

    #[tokio::test]
    async fn router_routes_l1_to_canonical() {
        let canonical = Arc::new(MockPath::new());
        let preconf = Arc::new(MockPath::new());
        let router = ProductionRouter::new(canonical.clone(), Some(preconf.clone()));
        let log = Log::default();

        let outcomes = router
            .produce(ProductionInput::L1ProposalLog(log))
            .await
            .expect("router should route to canonical path");

        assert_eq!(canonical.calls(), 1);
        assert_eq!(preconf.calls(), 0);
        assert_eq!(outcomes.len(), 1);
    }

    #[tokio::test]
    async fn router_routes_preconf_to_preconf_path() {
        let canonical = Arc::new(MockPath::new());
        let preconf = Arc::new(MockPath::new());
        let router = ProductionRouter::new(canonical.clone(), Some(preconf.clone()));
        let payload = Arc::new(PreconfPayload::new(crate::test_support::sample_payload(0)));

        let outcomes = router
            .produce(ProductionInput::Preconfirmation(payload))
            .await
            .expect("router should route to preconfirmation path");

        assert_eq!(preconf.calls(), 1);
        assert_eq!(canonical.calls(), 0);
        assert_eq!(outcomes.len(), 1);
    }

    #[tokio::test]
    async fn router_rejects_preconf_without_path() {
        let canonical = Arc::new(MockPath::new());
        let router = ProductionRouter::new(canonical.clone(), None);
        let payload = Arc::new(PreconfPayload::new(crate::test_support::sample_payload(0)));

        let err = router
            .produce(ProductionInput::Preconfirmation(payload))
            .await
            .expect_err("router should reject preconfirmation input without a path");

        assert!(matches!(err, DriverError::PreconfirmationDisabled));
        assert_eq!(canonical.calls(), 0);
    }

    #[tokio::test]
    async fn preconfirmation_path_delegates_to_applier() {
        let parent_hash = B256::from([1u8; 32]);
        let applier = MockApplier::new(0, parent_hash);
        let path = PreconfirmationPath::new(applier.clone());
        let payload = Arc::new(PreconfPayload::new(crate::test_support::sample_payload(1)));

        let outcomes = path
            .produce(ProductionInput::Preconfirmation(payload))
            .await
            .expect("preconfirmation path should succeed");

        assert_eq!(applier.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    #[tokio::test]
    async fn preconfirmation_path_produces_above_parent() {
        let parent_hash = B256::from([1u8; 32]);
        let applier = MockApplier::new(1, parent_hash);
        let path = PreconfirmationPath::new(applier.clone());
        let payload = Arc::new(PreconfPayload::new(crate::test_support::sample_payload(2)));

        let outcomes = path
            .produce(ProductionInput::Preconfirmation(payload))
            .await
            .expect("preconfirmation above canonical boundary should be allowed");

        assert_eq!(applier.calls(), 1);
        assert_eq!(outcomes.len(), 1);
    }

    /// An engine rejection must map to a per-payload injection error the ingress
    /// loop can isolate — not a panic, not a silent Ok — carrying the PAYLOAD's block
    /// number so the loop can report exactly which payload it dropped.
    #[tokio::test]
    async fn preconf_path_maps_engine_rejection_to_injection_error() {
        // Payload targets block 6; its parent is 5. `expected_parent: 5` makes the parent-hash
        // lookup succeed so the path reaches `apply_payload` (which then rejects). The mock's
        // engine error carries a sentinel number (u64::MAX), distinct from the payload's 6, so
        // pinning `block_number: 6` proves the number came from the payload, not the engine error.
        let applier =
            MockApplier { fail_invalid: true, expected_parent: 5, ..MockApplier::default() };
        let path = PreconfirmationPath::new(applier);
        let payload = Arc::new(PreconfPayload::new(crate::test_support::sample_payload(6)));
        let err = path
            .produce(ProductionInput::Preconfirmation(payload))
            .await
            .expect_err("engine rejection must surface");
        // The mapping at path.rs wraps the engine error in
        // `DriverError::PreconfInjectionFailed { block_number, source }`, so the
        // ingress loop can drop a single bad payload without freezing the head.
        assert!(
            matches!(err, DriverError::PreconfInjectionFailed { block_number: 6, .. }),
            "got {err:?}"
        );
    }
}
