//! Shared test-only fixtures and mocks used by driver unit tests.
//!
//! Hosts the payload/derivation-source samples, mocked RPC client constructors, and the
//! configurable [`MockProductionPath`] that individual test modules previously duplicated.

use std::{
    collections::HashSet,
    sync::{Arc, Mutex},
};

use alethia_reth_primitives::payload::attributes::{
    RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
};
use alloy::primitives::{
    Address, B256, Bytes, FixedBytes, U256,
    aliases::{U24, U48},
};
use alloy_consensus::TxEnvelope;
use alloy_provider::ProviderBuilder;
use alloy_rpc_types::eth::Block as RpcBlock;
use alloy_rpc_types_engine::PayloadId;
use alloy_rpc_types_engine_2::PayloadAttributes as EthPayloadAttributes;
use alloy_transport::mock::Asserter;
use anyhow::anyhow;
use async_trait::async_trait;
use bindings::{
    anchor::Anchor::AnchorInstance,
    inbox::{IInbox::DerivationSource, Inbox::InboxInstance, LibBlobs::BlobSlice},
};
use rpc::client::{Client, ShastaProtocolInstance};

use crate::{
    derivation::DerivationError,
    error::DriverError,
    production::{BlockProductionPath, ProductionInput},
    sync::{SyncError, engine::EngineBlockOutcome, error::EngineSubmissionError},
};

/// Sample Taiko payload attributes whose L1 origin points at `block_number`.
pub(crate) fn sample_payload(block_number: u64) -> TaikoPayloadAttributes {
    let payload_attributes = EthPayloadAttributes {
        timestamp: 0,
        prev_randao: B256::ZERO,
        suggested_fee_recipient: Address::ZERO,
        withdrawals: Some(Vec::new()),
        parent_beacon_block_root: None,
        slot_number: None,
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

/// Sample engine outcome whose block number, hash, and payload id all derive from
/// `block_number`.
pub(crate) fn sample_engine_outcome(block_number: u64) -> EngineBlockOutcome {
    let mut block = RpcBlock::<TxEnvelope>::default();
    block.header.number = block_number;
    block.header.hash = B256::from([block_number as u8; 32]);
    EngineBlockOutcome { block, payload_id: PayloadId::new([block_number as u8; 8]) }
}

/// Sample derivation source carrying the given blob hashes and forced-inclusion flag.
pub(crate) fn sample_derivation_source(
    blob_hashes: Vec<FixedBytes<32>>,
    is_forced: bool,
) -> DerivationSource {
    DerivationSource {
        isForcedInclusion: is_forced,
        blobSlice: BlobSlice { blobHashes: blob_hashes, offset: U24::ZERO, timestamp: U48::ZERO },
    }
}

/// Mocked RPC client whose L1 provider replays `l1_asserter`; all other providers reply from
/// empty asserters and the anchor binds to `Address::ZERO`.
pub(crate) fn mock_client_with_l1_asserter(l1_asserter: Asserter) -> Client {
    mock_client_with_asserters(l1_asserter, Asserter::new(), Asserter::new(), Address::ZERO)
}

/// Mocked RPC client replaying the given per-provider asserters, with the anchor instance bound
/// to `anchor_address`.
pub(crate) fn mock_client_with_asserters(
    l1_asserter: Asserter,
    l2_asserter: Asserter,
    l2_auth_asserter: Asserter,
    anchor_address: Address,
) -> Client {
    let l1_provider = ProviderBuilder::new().connect_mocked_client(l1_asserter);
    let l2_provider =
        ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(l2_asserter);
    let l2_auth_provider = ProviderBuilder::new()
        .disable_recommended_fillers()
        .connect_mocked_client(l2_auth_asserter);
    let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
    let anchor = AnchorInstance::new(anchor_address, l2_auth_provider.clone());
    let shasta = ShastaProtocolInstance { inbox, anchor };

    Client { chain_id: 0, l1_provider, l2_provider, l2_auth_provider, shasta }
}

/// Behavior knob applied by [`MockProductionPath`] to L1 proposal-log inputs.
///
/// Preconfirmation inputs always succeed: failure injection is only exercised on the
/// proposal-log retry paths under test.
#[derive(Default)]
pub(crate) enum MockProductionBehavior {
    /// Succeed on every input.
    #[default]
    Succeed,
    /// Always fail (retryably) for proposal logs whose transaction hash is in the set.
    FailFor(HashSet<B256>),
    /// Fail (retryably) the first attempt for each transaction hash in the set, then succeed.
    FailOnceFor(Mutex<HashSet<B256>>),
    /// Always fail with a deterministic engine verdict.
    Fatal,
}

/// Configurable [`BlockProductionPath`] mock recording every input it produces.
///
/// Successful production replies with [`sample_engine_outcome`] for the input's block number.
/// Clones share their behavior and recording state, so a clone kept by the test observes the
/// calls made through the router-owned instance.
#[derive(Clone, Default)]
pub(crate) struct MockProductionPath {
    /// Behavior applied to proposal-log inputs.
    behavior: Arc<MockProductionBehavior>,
    /// Transaction hashes of the proposal logs seen, in production order.
    seen_tx_hashes: Arc<Mutex<Vec<B256>>>,
    /// Block numbers of the preconfirmation payloads produced, in production order.
    produced_blocks: Arc<Mutex<Vec<u64>>>,
    /// Total number of `produce` calls across both input kinds.
    calls: Arc<Mutex<u64>>,
}

impl MockProductionPath {
    /// Mock that always fails for proposal logs with the given transaction hashes.
    pub(crate) fn failing_for(tx_hashes: impl IntoIterator<Item = B256>) -> Self {
        Self::with_behavior(MockProductionBehavior::FailFor(tx_hashes.into_iter().collect()))
    }

    /// Mock that fails the first attempt for each given transaction hash, then succeeds.
    pub(crate) fn failing_once_for(tx_hashes: impl IntoIterator<Item = B256>) -> Self {
        Self::with_behavior(MockProductionBehavior::FailOnceFor(Mutex::new(
            tx_hashes.into_iter().collect(),
        )))
    }

    /// Mock that always fails proposal logs with a deterministic engine verdict.
    pub(crate) fn fatal() -> Self {
        Self::with_behavior(MockProductionBehavior::Fatal)
    }

    /// Mock with the given proposal-log behavior and fresh recording state.
    fn with_behavior(behavior: MockProductionBehavior) -> Self {
        Self { behavior: Arc::new(behavior), ..Self::default() }
    }

    /// Transaction hashes of the proposal logs produced so far.
    pub(crate) fn seen_tx_hashes(&self) -> Vec<B256> {
        self.seen_tx_hashes.lock().expect("seen tx hashes mutex should not be poisoned").clone()
    }

    /// Block numbers of the preconfirmation payloads produced so far.
    pub(crate) fn produced_blocks(&self) -> Vec<u64> {
        self.produced_blocks.lock().expect("produced blocks mutex should not be poisoned").clone()
    }

    /// Total number of `produce` calls observed so far.
    pub(crate) fn calls(&self) -> u64 {
        *self.calls.lock().expect("calls mutex should not be poisoned")
    }
}

#[async_trait]
impl BlockProductionPath for MockProductionPath {
    async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        *self.calls.lock().expect("calls mutex should not be poisoned") += 1;

        match input {
            ProductionInput::Preconfirmation(payload) => {
                let block_number = payload.block_number();
                self.produced_blocks
                    .lock()
                    .expect("produced blocks mutex should not be poisoned")
                    .push(block_number);

                Ok(vec![sample_engine_outcome(block_number)])
            }
            ProductionInput::L1ProposalLog(log) => {
                if let Some(tx_hash) = log.transaction_hash {
                    self.seen_tx_hashes
                        .lock()
                        .expect("seen tx hashes mutex should not be poisoned")
                        .push(tx_hash);
                }

                match self.behavior.as_ref() {
                    MockProductionBehavior::Succeed => {}
                    MockProductionBehavior::FailFor(tx_hashes) => {
                        if log.transaction_hash.is_some_and(|tx_hash| tx_hashes.contains(&tx_hash))
                        {
                            return Err(DriverError::Other(anyhow!(
                                "mock orphaned proposal failure"
                            )));
                        }
                    }
                    MockProductionBehavior::FailOnceFor(tx_hashes) => {
                        if let Some(tx_hash) = log.transaction_hash &&
                            tx_hashes
                                .lock()
                                .expect("fail-once tx hashes mutex should not be poisoned")
                                .remove(&tx_hash)
                        {
                            return Err(DriverError::Other(anyhow!(
                                "mock retryable proposal failure"
                            )));
                        }
                    }
                    MockProductionBehavior::Fatal => {
                        return Err(DriverError::Sync(SyncError::Derivation(
                            DerivationError::Engine(EngineSubmissionError::InvalidBlock(
                                1,
                                "mock invalid payload".to_string(),
                            )),
                        )));
                    }
                }

                Ok(vec![sample_engine_outcome(log.block_number.unwrap_or_default())])
            }
        }
    }
}
