//! In-memory [`L1Source`] and [`Engine`] implementations for tests.
//!
//! Both record every call ([`L1Call`], [`EngineCall`]) so tests can assert which I/O a handler
//! performed (e.g. that `FinalizeBlock` never touches L1), and expose their state behind a mutex
//! ([`MockL1::state`], [`MockEngine::state`]) for scripting.

use std::{
    collections::{BTreeMap, HashMap, VecDeque},
    sync::{Mutex, MutexGuard},
    time::Duration,
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::{EMPTY_OMMER_ROOT_HASH, EMPTY_ROOT_HASH, Header};
use alloy_eips::{BlockNumberOrTag, eip7685::EMPTY_REQUESTS_HASH};
use alloy_primitives::{Address, B64, B256, U256, keccak256};
use async_trait::async_trait;

use super::TestState;
use crate::{
    engine::{Engine, EngineError, PayloadVerdict},
    envelope::ExecutionBlock,
    l1::{
        header::RawL1Header,
        source::{L1Error, L1Source},
    },
    types::AccountWitness,
};

/// One call made to a [`MockL1`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum L1Call {
    Finalized,
    CanonicalHash(u64),
    Header(u64),
    AccountWitness { address: Address, slots: Vec<B256>, block: u64 },
    StorageAt { address: Address, slot: B256, block: u64 },
}

/// The scriptable state of a [`MockL1`].
#[derive(Debug, Default)]
pub(crate) struct MockL1State {
    /// What `finalized_number` returns.
    pub(crate) finalized: u64,
    /// Canonical raw headers by number (`header` and `canonical_hash` fail with
    /// `BlockNotFound` for others).
    pub(crate) headers: BTreeMap<u64, RawL1Header>,
    /// L1 state per block number, serving `account_witness` and `storage_at`.
    pub(crate) states: BTreeMap<u64, TestState>,
    /// When set, every call fails with this error.
    pub(crate) fail: Option<L1Error>,
    /// When set, every call first sleeps this long (tokio time), to exercise timeouts.
    pub(crate) delay: Option<Duration>,
    /// Every call, in order.
    pub(crate) calls: Vec<L1Call>,
}

/// An in-memory L1 node: canonical headers, per-block [`TestState`]s with real proofs, and a
/// settable `finalized` number.
#[derive(Debug, Default)]
pub(crate) struct MockL1 {
    state: Mutex<MockL1State>,
}

impl MockL1 {
    /// An L1 with no blocks whose `finalized` number is `finalized`.
    pub(crate) fn new(finalized: u64) -> Self {
        let l1 = Self::default();
        l1.state().finalized = finalized;
        l1
    }

    /// Locks the state for scripting or inspection.
    pub(crate) fn state(&self) -> MutexGuard<'_, MockL1State> {
        self.state.lock().expect("mock L1 lock")
    }

    /// Makes `header` canonical at its number.
    pub(crate) fn insert_header(&self, header: RawL1Header) {
        self.state().headers.insert(header.number(), header);
    }

    /// Makes `header` (with its `state_root` set to `state`'s root) canonical at its number and
    /// serves `state` at that block; returns the stored raw header.
    pub(crate) fn insert_block(&self, mut header: Header, state: TestState) -> RawL1Header {
        header.state_root = state.state_root();
        let raw = RawL1Header::from(&header);
        let mut guard = self.state();
        guard.headers.insert(header.number, raw.clone());
        guard.states.insert(header.number, state);
        raw
    }

    /// Sets the `finalized` number.
    pub(crate) fn set_finalized(&self, finalized: u64) {
        self.state().finalized = finalized;
    }

    /// Every call so far, in order.
    pub(crate) fn calls(&self) -> Vec<L1Call> {
        self.state().calls.clone()
    }

    /// Sleeps for the scripted `delay`, if any (the lock is not held while sleeping).
    async fn pause(&self) {
        let delay = self.state().delay;
        if let Some(delay) = delay {
            tokio::time::sleep(delay).await;
        }
    }

    /// Records `call` and returns the scripted failure, if any.
    fn record(&self, call: L1Call) -> Result<MutexGuard<'_, MockL1State>, L1Error> {
        let mut state = self.state();
        state.calls.push(call);
        match &state.fail {
            Some(err) => Err(err.clone()),
            None => Ok(state),
        }
    }

    /// The state at `block` holding `address`, or the error a node would give.
    fn state_at(state: &MockL1State, address: Address, block: u64) -> Result<&TestState, L1Error> {
        let at = state
            .states
            .get(&block)
            .ok_or(L1Error::BlockNotFound(BlockNumberOrTag::Number(block)))?;
        if at.has_account(address) {
            Ok(at)
        } else {
            Err(L1Error::Rpc(format!("mock L1: no account {address} at block {block}")))
        }
    }
}

#[async_trait]
impl L1Source for MockL1 {
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        self.pause().await;
        Ok(self.record(L1Call::Finalized)?.finalized)
    }

    async fn canonical_hash(&self, number: u64) -> Result<B256, L1Error> {
        self.pause().await;
        let state = self.record(L1Call::CanonicalHash(number))?;
        state
            .headers
            .get(&number)
            .map(RawL1Header::hash)
            .ok_or(L1Error::BlockNotFound(BlockNumberOrTag::Number(number)))
    }

    async fn header(&self, number: u64) -> Result<RawL1Header, L1Error> {
        self.pause().await;
        let state = self.record(L1Call::Header(number))?;
        state
            .headers
            .get(&number)
            .cloned()
            .ok_or(L1Error::BlockNotFound(BlockNumberOrTag::Number(number)))
    }

    async fn account_witness(
        &self,
        address: Address,
        slots: &[B256],
        block: u64,
    ) -> Result<AccountWitness, L1Error> {
        self.pause().await;
        let state =
            self.record(L1Call::AccountWitness { address, slots: slots.to_vec(), block })?;
        Ok(Self::state_at(&state, address, block)?.witness(address, slots))
    }

    async fn storage_at(&self, address: Address, slot: B256, block: u64) -> Result<U256, L1Error> {
        self.pause().await;
        let state = self.record(L1Call::StorageAt { address, slot, block })?;
        Ok(Self::state_at(&state, address, block)?.storage(address, slot))
    }
}

/// One call made to a [`MockEngine`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum EngineCall {
    CheckCapabilities,
    BuildBlock { parent: B256, attrs: Box<TaikoPayloadAttributes> },
    NewPayload(B256),
    Forkchoice { head: B256, safe: B256, finalized: B256 },
    HeaderByNumber(u64),
}

/// The scriptable state of a [`MockEngine`].
///
/// Scripted queues are consumed first; when a queue is empty the mock behaves like a simple EL
/// (see each method on the [`Engine`] impl).
#[derive(Debug, Default)]
pub(crate) struct MockEngineState {
    /// The canonical chain served by `header_by_number`.
    pub(crate) chain: BTreeMap<u64, Header>,
    /// Every block the EL holds, canonical or not, by hash.
    pub(crate) known: HashMap<B256, Header>,
    /// Scripted `header_by_number` answers (before falling back to `chain`).
    pub(crate) header_script: VecDeque<Result<Option<Header>, EngineError>>,
    /// Scripted `build_block` answers (an empty queue builds [`simple_block`]).
    pub(crate) build_script: VecDeque<Result<ExecutionBlock, EngineError>>,
    /// Scripted `new_payload` answers (before the default `Valid`).
    pub(crate) new_payload_script: VecDeque<Result<PayloadVerdict, EngineError>>,
    /// Scripted `forkchoice` answers (before the default canonicalization).
    pub(crate) forkchoice_script: VecDeque<Result<PayloadVerdict, EngineError>>,
    /// What `check_capabilities` returns.
    pub(crate) capabilities: Option<EngineError>,
    /// When set, every call first sleeps this long (tokio time), to exercise timeouts.
    pub(crate) delay: Option<Duration>,
    /// Scripted per-call sleeps (tokio time), one popped per call before falling back to
    /// `delay`.
    pub(crate) delay_script: VecDeque<Duration>,
    /// Every call, in order.
    pub(crate) calls: Vec<EngineCall>,
}

/// The block a simple EL builds on `parent_hash` from `attrs`: every attribute-derived field as
/// alethia-reth #248 assembles it (Etna body commitments included), no transactions, and
/// deterministic execution results.
pub(crate) fn simple_block(parent_hash: B256, attrs: &TaikoPayloadAttributes) -> ExecutionBlock {
    let eth = &attrs.payload_attributes;
    let number = attrs.l1_origin.block_id.to::<u64>();
    let header = Header {
        parent_hash,
        number,
        timestamp: eth.timestamp,
        beneficiary: eth.suggested_fee_recipient,
        extra_data: attrs.block_metadata.extra_data.clone(),
        parent_beacon_block_root: eth.parent_beacon_block_root,
        gas_limit: attrs.block_metadata.gas_limit,
        base_fee_per_gas: Some(attrs.base_fee_per_gas.to::<u64>()),
        mix_hash: eth.prev_randao,
        withdrawals_root: Some(EMPTY_ROOT_HASH),
        blob_gas_used: Some(0),
        excess_blob_gas: Some(0),
        requests_hash: Some(EMPTY_REQUESTS_HASH),
        ommers_hash: EMPTY_OMMER_ROOT_HASH,
        nonce: B64::ZERO,
        state_root: keccak256(parent_hash),
        transactions_root: EMPTY_ROOT_HASH,
        receipts_root: EMPTY_ROOT_HASH,
        gas_used: 0,
        difficulty: U256::from(1_000 + number % 1_000),
        ..Header::default()
    };
    ExecutionBlock { header, transactions: vec![] }
}

impl MockEngineState {
    /// Makes the known block `head` canonical: sets it and its known ancestors in `chain` and
    /// drops every canonical block above it.
    fn canonicalize(&mut self, head: &Header) {
        self.chain.retain(|number, _| *number <= head.number);
        let mut cursor = Some(head.clone());
        while let Some(header) = cursor {
            if self.chain.get(&header.number).is_some_and(|h| h.hash_slow() == header.hash_slow()) {
                break;
            }
            cursor = self.known.get(&header.parent_hash).cloned();
            self.chain.insert(header.number, header);
        }
    }
}

/// An in-memory execution engine with scripted answers and a simple canonical-chain model.
#[derive(Debug, Default)]
pub(crate) struct MockEngine {
    state: Mutex<MockEngineState>,
}

impl MockEngine {
    /// An engine with an empty chain.
    pub(crate) fn new() -> Self {
        Self::default()
    }

    /// An engine whose canonical chain (and known set) is `headers`.
    pub(crate) fn with_chain(headers: impl IntoIterator<Item = Header>) -> Self {
        let engine = Self::new();
        {
            let mut state = engine.state();
            for header in headers {
                state.known.insert(header.hash_slow(), header.clone());
                state.chain.insert(header.number, header);
            }
        }
        engine
    }

    /// The same EL after a process restart: its database (canonical chain and known blocks)
    /// survives; scripts, delay and the call log do not.
    pub(crate) fn reopen(&self) -> Self {
        let engine = Self::new();
        {
            let old = self.state();
            let mut state = engine.state();
            state.chain = old.chain.clone();
            state.known = old.known.clone();
        }
        engine
    }

    /// Adds `header` to the known (not canonical) blocks.
    pub(crate) fn insert_known(&self, header: Header) {
        self.state().known.insert(header.hash_slow(), header);
    }

    /// Locks the state for scripting or inspection.
    pub(crate) fn state(&self) -> MutexGuard<'_, MockEngineState> {
        self.state.lock().expect("mock engine lock")
    }

    /// Every call so far, in order.
    pub(crate) fn calls(&self) -> Vec<EngineCall> {
        self.state().calls.clone()
    }

    /// Sleeps for the next `delay_script` entry or else the scripted `delay`, if any (the lock
    /// is not held while sleeping).
    async fn pause(&self) {
        let delay = {
            let mut state = self.state();
            state.delay_script.pop_front().or(state.delay)
        };
        if let Some(delay) = delay {
            tokio::time::sleep(delay).await;
        }
    }
}

#[async_trait]
impl Engine for MockEngine {
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        self.pause().await;
        let mut state = self.state();
        state.calls.push(EngineCall::CheckCapabilities);
        state.capabilities.clone().map_or(Ok(()), Err)
    }

    /// Pops `build_script`, defaulting to [`simple_block`]; a built block becomes known.
    async fn build_block(
        &self,
        parent_hash: B256,
        attrs: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError> {
        self.pause().await;
        let mut state = self.state();
        let built =
            state.build_script.pop_front().unwrap_or_else(|| Ok(simple_block(parent_hash, &attrs)));
        state.calls.push(EngineCall::BuildBlock { parent: parent_hash, attrs: Box::new(attrs) });
        let built = built?;
        state.known.insert(built.header.hash_slow(), built.header.clone());
        Ok(built)
    }

    /// Pops `new_payload_script`, defaulting to `Valid`; a `Valid` block becomes known.
    async fn new_payload(&self, block: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        self.pause().await;
        let mut state = self.state();
        let hash = block.header.hash_slow();
        state.calls.push(EngineCall::NewPayload(hash));
        let verdict = state.new_payload_script.pop_front().unwrap_or(Ok(PayloadVerdict::Valid))?;
        if verdict == PayloadVerdict::Valid {
            state.known.insert(hash, block.header.clone());
        }
        Ok(verdict)
    }

    /// Pops `forkchoice_script`; when empty, a known `head` becomes canonical (`Valid`) and an
    /// unknown one answers `Syncing`. A scripted `Valid` for a known head also canonicalizes it.
    async fn forkchoice(
        &self,
        head: B256,
        safe: B256,
        finalized: B256,
    ) -> Result<PayloadVerdict, EngineError> {
        self.pause().await;
        let mut state = self.state();
        state.calls.push(EngineCall::Forkchoice { head, safe, finalized });
        let known = state.known.get(&head).cloned();
        let verdict = match state.forkchoice_script.pop_front() {
            Some(scripted) => scripted?,
            None if known.is_some() => PayloadVerdict::Valid,
            None => PayloadVerdict::Syncing,
        };
        if let (PayloadVerdict::Valid, Some(header)) = (&verdict, known) {
            state.canonicalize(&header);
        }
        Ok(verdict)
    }

    /// Pops `header_script`, falling back to the canonical `chain`.
    async fn header_by_number(&self, number: u64) -> Result<Option<Header>, EngineError> {
        self.pause().await;
        let mut state = self.state();
        state.calls.push(EngineCall::HeaderByNumber(number));
        match state.header_script.pop_front() {
            Some(scripted) => scripted,
            None => Ok(state.chain.get(&number).cloned()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{l1::mpt::verify_account_witness, test_utils::l1_header};

    #[tokio::test]
    async fn mock_l1_serves_real_proofs_and_records_calls() {
        let address = Address::repeat_byte(0xaa);
        let slot = B256::with_last_byte(1);
        let state =
            TestState::new(vec![(address, 1, U256::ZERO, B256::ZERO, vec![(slot, U256::from(9))])]);
        let l1 = MockL1::new(5);
        let header = l1.insert_block(l1_header(5, 50), state);

        let witness = l1.account_witness(address, &[slot], 5).await.unwrap();
        let verified = verify_account_witness(header.state_root(), &witness, &[slot]).unwrap();
        assert_eq!(verified.get(slot), Some(U256::from(9)));
        assert_eq!(l1.storage_at(address, slot, 5).await, Ok(U256::from(9)));
        assert!(matches!(l1.storage_at(Address::ZERO, slot, 5).await, Err(L1Error::Rpc(_))));
        assert_eq!(
            l1.account_witness(address, &[slot], 6).await,
            Err(L1Error::BlockNotFound(BlockNumberOrTag::Number(6)))
        );

        l1.state().fail = Some(L1Error::Rpc("down".into()));
        assert_eq!(l1.finalized_number().await, Err(L1Error::Rpc("down".into())));
        assert_eq!(l1.calls().len(), 5);
    }

    #[tokio::test]
    async fn mock_engine_canonicalizes_known_heads() {
        let a = Header { number: 1, ..Header::default() };
        let b1 = Header { number: 2, parent_hash: a.hash_slow(), ..Header::default() };
        let b2 =
            Header { number: 2, parent_hash: a.hash_slow(), timestamp: 1, ..Header::default() };
        let c2 = Header { number: 3, parent_hash: b2.hash_slow(), ..Header::default() };
        let engine = MockEngine::with_chain([a.clone(), b1]);
        engine.insert_known(b2.clone());
        engine.insert_known(c2.clone());

        assert_eq!(
            engine.forkchoice(B256::repeat_byte(9), B256::ZERO, B256::ZERO).await,
            Ok(PayloadVerdict::Syncing)
        );
        assert_eq!(
            engine.forkchoice(c2.hash_slow(), B256::ZERO, B256::ZERO).await,
            Ok(PayloadVerdict::Valid)
        );
        assert_eq!(engine.header_by_number(2).await, Ok(Some(b2)));
        assert_eq!(engine.header_by_number(3).await, Ok(Some(c2)));

        assert_eq!(
            engine.forkchoice(a.hash_slow(), B256::ZERO, B256::ZERO).await,
            Ok(PayloadVerdict::Valid)
        );
        assert_eq!(engine.header_by_number(2).await, Ok(None), "blocks above the head drop");
    }
}
