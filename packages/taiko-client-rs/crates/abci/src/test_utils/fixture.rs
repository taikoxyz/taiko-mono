//! A complete, mutually consistent genesis for app tests.
//!
//! [`Fixture::build`] plants an initialized Inbox in an L1 [`TestState`], whose generation 0
//! origin record and slot 278 hold the hash of a fallback key list of `n_validators` keys,
//! serves that list through the Inbox's `getFallbackKeys()`, builds the EL chain up to the Etna
//! start block, and assembles the genesis witness and the CometBFT `InitChain` request (the
//! list's keys, each at power 1) that start the chain. [`Fixture::l1`] and [`Fixture::engine`]
//! serve that L1 and EL; [`Fixture::expected_state`] is the `AppState` a correct `InitChain`
//! persists.
//!
//! For proposal tests, [`Fixture::plant_l1_block`] and [`Fixture::advance_l1`] add later L1
//! blocks with updated Inbox storage to a [`MockL1`], [`Fixture::anchor_witness`] and
//! [`Fixture::anchor_state`] read them back as an anchor, and [`Fixture::forced_witness`] proves
//! a forced inclusion queue entry there.

use crate::wire::request::InitChain;
use std::path::Path;

use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes, U256};
use tendermint::{Time, block::Height, vote};

use super::{
    InboxStorage, MockEngine, MockL1, TestState, fallback_list, filler_accounts, inbox_account,
    l1_header, serve_fallback_keys,
};
use crate::{
    app::{App, AppOptions},
    config::{ChainParams, ChainParamsExt},
    envelope::{AnchorWitness, ForcedWitness},
    fallback::FallbackKeys,
    genesis::{GenesisWitness, encode_app_state},
    key::ConsensusKey,
    l1::{header::RawL1Header, layout::inbox, verify_anchor_witness},
    rules::chain_id_for,
    store::{AppState, Store},
    types::{AnchorState, GenesisRecord, InboxFacts, ParentInfo},
    valstate::ValState,
};

/// The knobs of a [`Fixture`]; [`GenesisSpec::new`] gives a valid default.
#[derive(Clone, Debug)]
pub(crate) struct GenesisSpec {
    /// Number of origin fallback keys: the [`test_key`](super::test_key)s of seeds
    /// `1..=n_validators`.
    pub(crate) n_validators: usize,
    /// The Etna start S, the start block's L2 block number.
    pub(crate) genesis_height: u64,
    /// `L1_0`, the genesis's L1 block number.
    pub(crate) l1_0: u64,
    /// `forcedInclusionDelay`, in seconds.
    pub(crate) forced_inclusion_delay: u64,
    /// `maxAnchorAge`, in seconds.
    pub(crate) max_anchor_age: u64,
    /// The Inbox's `recoveryGeneration`; the `chain_id` uses the same generation.
    pub(crate) recovery_generation: u64,
    /// Overrides the fourth word of generation 0's origin record on L1 (default: the origin
    /// list's hash).
    pub(crate) origin_hash: Option<B256>,
    /// Overrides the origin fallback key list (default: the keys of seeds `1..=n_validators`,
    /// whose count then no longer matters).
    pub(crate) origin_keys: Option<FallbackKeys>,
    /// The chain parameters (default: devnet).
    pub(crate) params: ChainParams,
}

impl GenesisSpec {
    /// A valid genesis with `n_validators` origin fallback keys: `S = 0`, `L1_0 = 64`, forced
    /// inclusion delay 1 h, maximum anchor age 2 h, generation 0, devnet parameters with U = 12.
    pub(crate) fn new(n_validators: usize) -> Self {
        Self {
            n_validators,
            genesis_height: 0,
            l1_0: 64,
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
            recovery_generation: 0,
            origin_hash: None,
            origin_keys: None,
            params: ChainParams {
                unsettled_limit: 12,
                ..ChainParams::builtin(protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID).unwrap()
            },
        }
    }
}

/// A consistent genesis: L1 state, genesis witness, EL chain and `InitChain` request.
#[derive(Clone, Debug)]
pub(crate) struct Fixture {
    /// The chain parameters the app runs with.
    pub(crate) params: ChainParams,
    /// The genesis record planted in the Inbox.
    pub(crate) genesis: GenesisRecord,
    /// The Inbox storage at `L1_0`.
    pub(crate) inbox: InboxStorage,
    /// The L1 state at `L1_0` (filler accounts, Inbox).
    pub(crate) l1_state: TestState,
    /// The genesis witness (its `l1_header` is the raw block `L1_0` with `l1_state`'s root).
    pub(crate) witness: GenesisWitness,
    /// The origin fallback key list: its keys, each at power 1, are the genesis validators.
    pub(crate) fallback_keys: FallbackKeys,
    /// The EL's canonical chain: `[S − 1, S]` (just `[S]` when `S = 0`), S the Etna start.
    pub(crate) el_chain: Vec<Header>,
    /// The `InitChain` request CometBFT sends for this genesis.
    pub(crate) request: InitChain,
}

impl Fixture {
    /// The default genesis ([`GenesisSpec::new`]) with `n_validators` validators.
    pub(crate) fn genesis(n_validators: usize) -> Self {
        Self::build(GenesisSpec::new(n_validators))
    }

    /// Builds the genesis described by `spec`.
    pub(crate) fn build(spec: GenesisSpec) -> Self {
        let params = spec.params.clone();

        let el_chain = el_chain(spec.genesis_height);
        let b_star = el_chain.last().expect("the EL chain holds the Etna start block");
        let genesis = GenesisRecord {
            config_hash: params.config_hash(),
            genesis_height: spec.genesis_height,
            l1_0: spec.l1_0,
            genesis_hash: b_star.hash_slow(),
            genesis_state_root: b_star.state_root,
            forced_inclusion_delay: spec.forced_inclusion_delay,
            max_anchor_age: spec.max_anchor_age,
        };

        let seeds: Vec<u64> = (1..=spec.n_validators as u64).collect();
        let fallback_keys = spec.origin_keys.clone().unwrap_or_else(|| fallback_list(&seeds));
        let inbox = InboxStorage {
            recovery_generation: spec.recovery_generation,
            origin_fallback_keys_hash: spec.origin_hash.unwrap_or(fallback_keys.hash()),
            ..InboxStorage::genesis(genesis.clone(), fallback_keys.hash())
        };
        let l1_state = l1_state_with(&params, &inbox);

        let mut header = l1_header(spec.l1_0, Self::l1_timestamp(spec.l1_0));
        header.state_root = l1_state.state_root();
        let witness = GenesisWitness {
            l1_header: RawL1Header::from(&header),
            inbox: l1_state.witness(params.inbox, &inbox::genesis_slots()),
        };

        let request = InitChain {
            time: Time::from_unix_timestamp(
                i64::try_from(witness.l1_header.timestamp()).expect("timestamp fits i64"),
                0,
            )
            .expect("valid genesis time"),
            chain_id: chain_id_for(&params, spec.recovery_generation).unwrap(),
            consensus_params: consensus_params(),
            validators: validator_updates(&fallback_keys.validator_set()),
            app_state_bytes: encode_app_state(&witness).into(),
            initial_height: Height::from(1u32),
        };

        Self { params, genesis, inbox, l1_state, witness, fallback_keys, el_chain, request }
    }

    /// An L1 whose canonical, finalized block `L1_0` is the witness header over `l1_state`, and
    /// whose Inbox answers `getFallbackKeys()` with the origin list.
    pub(crate) fn l1(&self) -> MockL1 {
        let l1 = MockL1::new(self.genesis.l1_0);
        l1.insert_header(self.witness.l1_header.clone());
        l1.state().states.insert(self.genesis.l1_0, self.l1_state.clone());
        serve_fallback_keys(&l1, self.params.inbox, &self.fallback_keys);
        l1
    }

    /// An EL whose canonical chain is [`Fixture::el_chain`].
    pub(crate) fn engine(&self) -> MockEngine {
        MockEngine::with_chain(self.el_chain.clone())
    }

    /// `(l1, engine, params, request)`: everything an `InitChain` test needs.
    pub(crate) fn parts(&self) -> (MockL1, MockEngine, ChainParams, InitChain) {
        (self.l1(), self.engine(), self.params.clone(), self.request.clone())
    }

    /// An app over the fixture's L1 and Engine with a store in `dir` and [`test_options`].
    pub(crate) fn app(&self, dir: &Path) -> App<MockL1, MockEngine> {
        App::new(
            self.l1(),
            self.engine(),
            self.params.clone(),
            Store::volatile(dir.to_path_buf()),
            test_options(),
        )
        .expect("the fixture app starts")
    }

    /// Replaces the genesis witness and re-encodes the request's `app_state` from it.
    pub(crate) fn set_witness(&mut self, witness: GenesisWitness) {
        self.request.app_state_bytes = encode_app_state(&witness).into();
        self.witness = witness;
    }

    /// The start hash, the Etna start block's L2 block hash.
    pub(crate) fn genesis_hash(&self) -> B256 {
        self.genesis.genesis_hash
    }

    /// The timestamp of L1 block `number` in fixture L1s (12-second slots).
    pub(crate) fn l1_timestamp(number: u64) -> u64 {
        1_760_000_000 + number * 12
    }

    /// The genesis Inbox storage with the last checkpoint moved to `last_checkpoint_height`
    /// and the fallback keys unchanged. Its hash is the local chain's block there in tests
    /// that move the committed state with `jump`: the start hash at the Etna start S, a
    /// [`committed_block`] above it.
    pub(crate) fn inbox_with(&self, last_checkpoint_height: u64) -> InboxStorage {
        let hash = if last_checkpoint_height == self.genesis.genesis_height {
            self.genesis_hash()
        } else {
            committed_block(last_checkpoint_height).hash_slow()
        };
        self.inbox_at_checkpoint(last_checkpoint_height, hash)
    }

    /// The genesis Inbox storage with the last checkpoint moved to `(height, hash)` and the
    /// fallback keys unchanged.
    pub(crate) fn inbox_at_checkpoint(&self, height: u64, hash: B256) -> InboxStorage {
        let mut inbox = self.inbox.clone();
        inbox.last_checkpoint_height = height;
        inbox.last_checkpoint_hash = hash;
        inbox
    }

    /// Plants L1 block `number` holding `inbox` (plus the filler accounts) as canonical in `l1`,
    /// without moving its finalized block; returns the stored raw header.
    pub(crate) fn plant_l1_block(
        &self,
        l1: &MockL1,
        number: u64,
        inbox: &InboxStorage,
    ) -> RawL1Header {
        let state = l1_state_with(&self.params, inbox);
        l1.insert_block(l1_header(number, Self::l1_timestamp(number)), state)
    }

    /// Plants L1 block `number` (see [`Fixture::plant_l1_block`]) and moves `l1`'s finalized
    /// block to it, so that it is final: a proposer then anchors there.
    pub(crate) fn advance_l1(&self, l1: &MockL1, number: u64, inbox: &InboxStorage) -> RawL1Header {
        let header = self.plant_l1_block(l1, number, inbox);
        l1.set_finalized(number);
        header
    }

    /// The anchor witness of the L1 block `number` planted in `l1`, proving
    /// `anchor_slots()`.
    pub(crate) fn anchor_witness(&self, l1: &MockL1, number: u64) -> AnchorWitness {
        let guard = l1.state();
        let header = guard.headers.get(&number).expect("the L1 block is planted").clone();
        let state = guard.states.get(&number).expect("the L1 block has a state");
        AnchorWitness {
            l1_header: header,
            inbox: state.witness(self.params.inbox, &inbox::anchor_slots()),
        }
    }

    /// A forced inclusion witness for entry `index` of the Inbox in the L1 block `number`
    /// planted in `l1` (proofs of the entry's two slots), carrying exact transaction bytes.
    pub(crate) fn forced_witness(
        &self,
        l1: &MockL1,
        number: u64,
        index: u64,
        tx: Bytes,
    ) -> ForcedWitness {
        let guard = l1.state();
        let state = guard.states.get(&number).expect("the L1 block has a state");
        ForcedWitness {
            index,
            entry: state.witness(self.params.inbox, &inbox::forced_inclusion_entry_slots(index)),
            tx,
        }
    }

    /// The anchor a witness of the L1 block `number` planted in `l1` proves.
    pub(crate) fn anchor_state(&self, l1: &MockL1, number: u64) -> AnchorState {
        let w = self.anchor_witness(l1, number);
        verify_anchor_witness(&w, self.params.inbox).expect("planted anchor")
    }

    /// The `AppState` a correct `InitChain` persists for this genesis.
    pub(crate) fn expected_state(&self) -> AppState {
        let b_star = self.el_chain.last().expect("the EL chain holds the Etna start block");
        let grandparent_timestamp = if self.el_chain.len() > 1 {
            self.el_chain[self.el_chain.len() - 2].timestamp
        } else {
            0
        };
        AppState {
            schema_version: crate::store::STATE_SCHEMA_VERSION,
            recovery: None,
            app_version: crate::app::APP_VERSION,
            chain_id: self.request.chain_id.clone(),
            generation: self.inbox.recovery_generation,
            inbox: self.params.inbox,
            genesis: self.genesis.clone(),
            last_height: self.genesis.genesis_height,
            last_comet_hash: B256::ZERO,
            parent: ParentInfo {
                number: b_star.number,
                hash: b_star.hash_slow(),
                timestamp: b_star.timestamp,
                gas_limit: b_star.gas_limit,
                gas_used: b_star.gas_used,
                base_fee: b_star.base_fee_per_gas.expect("the Etna start block has a base fee"),
                difficulty: b_star.difficulty,
                grandparent_timestamp,
            },
            anchor: AnchorState {
                number: self.genesis.l1_0,
                hash: self.witness.l1_header.hash(),
                state_root: self.l1_state.state_root(),
                timestamp: self.witness.l1_header.timestamp(),
                inbox: InboxFacts {
                    rules_schedule: alloy_primitives::U256::ZERO,
                    recovery_generation: self.inbox.recovery_generation,
                    last_checkpoint_height: self.genesis.genesis_height,
                    last_checkpoint_hash: self.genesis.genesis_hash,
                    forced_inclusion_head: 0,
                    forced_inclusion_tail: 0,
                    // The genesis witness proves neither slot 278 nor 279: the genesis anchor
                    // names the origin list and makes no candidate usable.
                    fallback_keys_hash: self.inbox.origin_fallback_keys_hash,
                    min_total_stake: U256::MAX,
                },
            },
            forced_cursor: 0,
            val_state: ValState::genesis(
                self.genesis.genesis_height,
                &self.fallback_keys.validator_set(),
            )
            .expect("the origin keys are a CometBFT validator set"),
            signers: crate::store::Signers::origin(&self.fallback_keys),
            fallback_keys: [(self.fallback_keys.hash(), self.fallback_keys.clone())].into(),
            execution_floor: None,
        }
    }

    /// The state of a store a checkpoint import installed at `floor` and that has since
    /// committed up to `head` (`floor <= head`), and the EL chain serving it: the fixture chain
    /// up to the Etna start S, then a [`committed_block`] at every later height up to `head`. The
    /// execution floor names that chain's block at `floor`; the validator state advances
    /// without updates.
    pub(crate) fn imported_state(&self, floor: u64, head: u64) -> (AppState, Vec<Header>) {
        let mut chain = self.el_chain.clone();
        chain.extend((self.genesis.genesis_height + 1..=head).map(committed_block));
        let block = |number: u64| {
            chain.iter().find(|header| header.number == number).expect("a block of the chain")
        };
        let mut state = self.expected_state();
        state.parent =
            ParentInfo { number: head, hash: block(head).hash_slow(), ..state.parent.clone() };
        state.last_height = head;
        state.last_comet_hash = B256::repeat_byte(0xc0);
        while state.val_state.height < head {
            state.val_state = state.val_state.advance(&[]).expect("a nonempty set advances");
        }
        state.execution_floor =
            Some(crate::store::ExecutionFloor { number: floor, hash: block(floor).hash_slow() });
        (state, chain)
    }
}

/// The L1 state at `params`' addresses: the filler accounts and the Inbox holding `inbox`.
pub(crate) fn l1_state_with(params: &ChainParams, inbox: &InboxStorage) -> TestState {
    let mut accounts = filler_accounts();
    accounts.push(inbox_account(params.inbox, inbox));
    TestState::new(accounts)
}

/// The CometBFT validator updates of `validators` (key, power), in the given order.
pub(crate) fn validator_updates(
    validators: &[(ConsensusKey, u64)],
) -> Vec<crate::wire::ValidatorUpdate> {
    validators
        .iter()
        .map(|(key, power)| crate::wire::ValidatorUpdate {
            pub_key: *key,
            power: vote::Power::try_from(*power).expect("power fits i64"),
        })
        .collect()
}

/// A stand-in for the local chain's committed EL block `number` above genesis, for tests that
/// move the committed state there without building every block: its hash is the committed parent
/// hash at that height and, below the parent, the EL's canonical block there.
pub(crate) fn committed_block(number: u64) -> Header {
    Header { number, extra_data: Bytes::from_static(b"committed"), ..Header::default() }
}

/// The EL chain up to the Etna start `s`: a genesis header with a base fee and zk gas
/// (difficulty) at `s = 0`, else that header as block `s − 1` and its child `s`, two seconds later.
pub(crate) fn el_chain(s: u64) -> Vec<Header> {
    let genesis = Header {
        beneficiary: Address::repeat_byte(0xfe),
        state_root: B256::with_last_byte(1),
        number: 0,
        gas_limit: 45_000_000,
        gas_used: 21_000,
        timestamp: 1_760_000_000,
        base_fee_per_gas: Some(10_000_000),
        difficulty: U256::from(243_000),
        ..Header::default()
    };
    if s == 0 {
        return vec![genesis];
    }
    let parent = Header { number: s - 1, ..genesis };
    let start = Header {
        number: s,
        parent_hash: parent.hash_slow(),
        timestamp: parent.timestamp + 2,
        state_root: B256::with_last_byte(2),
        ..parent.clone()
    };
    vec![parent, start]
}

/// The `InitChain` request CometBFT sends for `doc`.
pub(crate) fn init_chain_request(doc: &crate::GenesisDoc) -> InitChain {
    InitChain {
        time: doc.genesis_time.parse().unwrap(),
        chain_id: doc.chain_id.clone(),
        consensus_params: abci_consensus_params(&doc.consensus_params),
        validators: doc
            .validators
            .iter()
            .map(|v| crate::wire::ValidatorUpdate {
                pub_key: v.pub_key.0,
                power: v.power.parse::<u64>().unwrap().try_into().unwrap(),
            })
            .collect(),
        app_state_bytes: serde_json::to_vec(&doc.app_state).unwrap().into(),
        initial_height: doc.initial_height.parse::<u64>().unwrap().try_into().unwrap(),
    }
}

/// CometBFT consensus parameters as the genesis builder writes them.
pub(crate) fn consensus_params() -> tendermint_proto::v0_38::types::ConsensusParams {
    crate::genesis::GenesisConsensusParams::abci()
}

/// The ABCI consensus parameters CometBFT passes to InitChain for a genesis file's
/// `consensus_params`: each decimal string parsed, the duration split from nanoseconds.
pub(crate) fn abci_consensus_params(
    p: &crate::genesis::GenesisConsensusParams,
) -> tendermint_proto::v0_38::types::ConsensusParams {
    use tendermint_proto::{google::protobuf::Duration, v0_38::types};
    let nanos: u64 = p.evidence.max_age_duration.parse().unwrap();
    types::ConsensusParams {
        block: Some(types::BlockParams {
            max_bytes: p.block.max_bytes.parse().unwrap(),
            max_gas: p.block.max_gas.parse().unwrap(),
        }),
        evidence: Some(types::EvidenceParams {
            max_age_num_blocks: p.evidence.max_age_num_blocks.parse().unwrap(),
            max_age_duration: Some(Duration {
                seconds: (nanos / 1_000_000_000) as i64,
                nanos: (nanos % 1_000_000_000) as i32,
            }),
            max_bytes: p.evidence.max_bytes.parse().unwrap(),
        }),
        validator: Some(types::ValidatorParams {
            pub_key_types: p.validator.pub_key_types.clone(),
        }),
        version: Some(types::VersionParams { app: p.version.app.parse().unwrap() }),
        abci: Some(types::AbciParams {
            vote_extensions_enable_height: p.abci.vote_extensions_enable_height.parse().unwrap(),
        }),
    }
}

/// The fallback key list the origin record of every [`recovery_fixture`] holds the hash of: the
/// keys of the old generation's two origin keys, so the fixture's proposer is one of them.
pub(crate) fn recovery_fallback_keys() -> crate::fallback::FallbackKeys {
    super::fallback_list(&[1, 2])
}

/// A proof-backed recovery with retained old-generation landing and a later checkpoint. The
/// origin record holds the hash of [`recovery_fallback_keys`], which the L1's
/// `getFallbackKeys()` returns. R is L1 block 100 and the finalized block 110.
pub(crate) fn recovery_fixture(
    generation: u64,
    c: u64,
    r_generation: u64,
) -> (Fixture, MockL1, MockEngine, crate::recovery::RecoveryWitness) {
    recovery_fixture_at(generation, c, r_generation, 100)
}

/// [`recovery_fixture`] with R at L1 block `r` (at least 100) and the finalized block `r + 10`.
pub(crate) fn recovery_fixture_at(
    generation: u64,
    c: u64,
    r_generation: u64,
    r: u64,
) -> (Fixture, MockL1, MockEngine, crate::recovery::RecoveryWitness) {
    use crate::recovery::{RECOVERY_WITNESS_VERSION, RecoveryWitness};
    let fx = Fixture::build(GenesisSpec::new(2));
    let l1 = fx.l1();
    let keys = recovery_fallback_keys();
    super::serve_fallback_keys(&l1, fx.params.inbox, &keys);
    let parent =
        Header { number: c.saturating_sub(1), timestamp: 1_760_000_060, ..Header::default() };
    let el = if c == 0 {
        fx.el_chain[0].clone()
    } else {
        Header {
            number: c,
            parent_hash: parent.hash_slow(),
            state_root: B256::repeat_byte(0x55),
            timestamp: 1_760_000_072,
            base_fee_per_gas: Some(1),
            gas_limit: 30_000_000,
            extra_data: crate::test_utils::extra_data(0, 64),
            parent_beacon_block_root: Some(fx.witness.l1_header.state_root()),
            withdrawals_root: Some(alloy_consensus::constants::EMPTY_ROOT_HASH),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            ..Header::default()
        }
    };
    let engine = MockEngine::with_chain(if c == 0 {
        vec![el.clone()]
    } else {
        vec![parent.clone(), el.clone()]
    });
    // `prepare` requires readable state at c, and recovery InitChain checks it again.
    engine.state().historical_state.insert(el.hash_slow());
    let mut storage = fx.inbox_with(c + 6);
    storage.recovery_generation = generation;
    storage.forced_inclusion_head = 8;
    storage.forced_inclusion_tail = 10;
    let mut words = storage.slots();
    words.extend(inbox::origin_slots(generation).into_iter().zip([
        U256::from(c),
        U256::from(r),
        U256::from(Fixture::l1_timestamp(r)),
        keys.hash().into(),
    ]));
    words.extend(inbox::landing_record_slots(c).into_iter().zip([
        U256::from(if c == 0 { 0 } else { 3 }) << 96,
        el.hash_slow().into(),
        if c == 0 { U256::ZERO } else { B256::repeat_byte(0xcc).into() },
    ]));
    // Same-block recoveries leave the end-of-R generation higher than the requested one.
    let state_for = |current: u64| {
        let mut words = words.clone();
        words.iter_mut().find(|(s, _)| *s == inbox::slot(inbox::RECOVERY_GENERATION)).unwrap().1 =
            U256::from(current);
        let mut accounts = filler_accounts();
        accounts.push((fx.params.inbox, 1, U256::ZERO, B256::repeat_byte(1), words));
        TestState::new(accounts)
    };
    let r_state = state_for(r_generation);
    let recovery_header = l1.insert_block(l1_header(r, Fixture::l1_timestamp(r)), r_state.clone());
    let final_state = state_for(generation);
    let finalized_header =
        l1.insert_block(l1_header(r + 10, Fixture::l1_timestamp(r + 10)), final_state.clone());
    l1.set_finalized(r + 10);
    let witness = RecoveryWitness {
        version: RECOVERY_WITNESS_VERSION,
        generation,
        genesis: fx.witness.clone(),
        finalized_header,
        finalized_inbox: final_state
            .witness(fx.params.inbox, &inbox::recovery_slots(generation, c)),
        recovery_header,
        recovery_inbox: r_state.witness(fx.params.inbox, &inbox::recovery_slots(generation, c)),
        el_header: el,
        parent_headers: if c == 0 { vec![] } else { vec![parent] },
    };
    (fx, l1, engine, witness)
}

/// [`AppOptions::default`] but with no proposer anchor hold (CONS-3.3-4): the proposer moves its
/// anchor as soon as its own L1 finalizes a newer block, which every test but the hold's own
/// expects.
pub(crate) fn test_options() -> AppOptions {
    AppOptions { anchor_hold: std::time::Duration::ZERO, ..AppOptions::default() }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::l1::witness::verify_genesis_inbox;

    #[test]
    fn fixture_witness_verifies_against_its_own_l1_state() {
        let fx = Fixture::genesis(3);
        let root = fx.witness.l1_header.state_root();
        assert_eq!(root, fx.l1_state.state_root());
        let (genesis, facts, origin) =
            verify_genesis_inbox(root, &fx.witness.inbox, fx.params.inbox).expect("inbox verifies");
        assert_eq!(genesis, fx.genesis);
        assert_eq!(facts.recovery_generation, 0);
        assert_eq!(origin.fallback_keys_hash, fx.fallback_keys.hash());
        assert_eq!(fx.fallback_keys, fallback_list(&[1, 2, 3]));
        assert_eq!(fx.request.validators, validator_updates(&fx.fallback_keys.validator_set()));
        assert!(fx.request.validators.iter().all(|v| v.power.value() == 1));
        assert_eq!(fx.request.initial_height.value(), fx.genesis.genesis_height + 1);
    }
}
