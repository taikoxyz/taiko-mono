//! A complete, mutually consistent genesis for app tests.
//!
//! [`Fixture::build`] plants an activated Inbox and a staking registry (one checkpoint holding
//! `n_validators` eligible entries) in an L1 [`TestState`], derives the `e_0` committee from it,
//! records its hash at `committee[e_0]`, builds the EL chain up to the genesis anchor `B*`, and
//! assembles the genesis witness and the CometBFT `InitChain` request that start the chain.
//! [`Fixture::l1`] and [`Fixture::engine`] serve that L1 and EL; [`Fixture::expected_state`] is
//! the `AppState` a correct `InitChain` persists.
//!
//! For proposal tests, [`Fixture::plant_l1_block`] and [`Fixture::advance_l1`] add later L1
//! blocks with updated Inbox/registry storage to a [`MockL1`], [`Fixture::anchor_witness`] and
//! [`Fixture::anchor_state`] read them back as an anchor, and [`Fixture::committee`] derives a
//! later epoch's committee from the genesis snapshot.

use std::{collections::BTreeMap, path::Path};

use alloy_consensus::Header;
use alloy_primitives::{Address, B256, U256};
use tendermint::{
    Time,
    abci::request::InitChain,
    block::{self, Height},
    consensus::{
        self,
        params::{AbciParams, ValidatorParams, VersionParams},
    },
    evidence, public_key, validator, vote,
};

use super::{
    InboxStorage, MockEngine, MockL1, RegistryStorage, TestState, committee_witness,
    filler_accounts, inbox_account, l1_header, registry_account, sample_entries,
};
use crate::{
    app::{App, AppOptions},
    committee::{self, Snapshot},
    config::ChainParams,
    envelope::AnchorWitness,
    genesis::{GenesisWitness, encode_app_state},
    l1::{header::RawL1Header, layout::inbox, verify_anchor_witness},
    rules::chain_id_for,
    schedule::Schedule,
    store::{AppState, CommitteeState, Store},
    types::{ActivationRecord, AnchorState, CommitteeRecord, InboxFacts, Member, ParentInfo},
};

/// The knobs of a [`Fixture`]; [`GenesisSpec::new`] gives a valid default.
#[derive(Clone, Debug)]
pub(crate) struct GenesisSpec {
    /// Number of registry entries, all eligible (see [`sample_entries`]).
    pub(crate) n_validators: usize,
    /// `B*`, the genesis anchor's L2 block number.
    pub(crate) genesis_height: u64,
    /// `L1_0`, the activation's L1 block number (the registry checkpoint is written there too).
    pub(crate) l1_0: u64,
    /// `L`, the epoch length in L2 blocks.
    pub(crate) epoch_len: u64,
    /// `EPOCH_LEN_L1`.
    pub(crate) epoch_len_l1: u64,
    /// The Inbox's `recoveryGeneration`; the `chain_id` uses the same generation.
    pub(crate) recovery_generation: u64,
    /// Overrides `committee[e_0]` on L1 (default: the derived record's hash).
    pub(crate) committee_e0: Option<B256>,
    /// The chain parameters (default: devnet).
    pub(crate) params: ChainParams,
}

impl GenesisSpec {
    /// A valid genesis with `n_validators` validators: `B* = 1000`, `L1_0 = 64`, `L = 20`,
    /// `EPOCH_LEN_L1 = 4`, generation 0, devnet parameters.
    pub(crate) fn new(n_validators: usize) -> Self {
        Self {
            n_validators,
            genesis_height: 1_000,
            l1_0: 64,
            epoch_len: 20,
            epoch_len_l1: 4,
            recovery_generation: 0,
            committee_e0: None,
            params: ChainParams::builtin(protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID)
                .expect("devnet parameters are built in"),
        }
    }
}

/// A consistent genesis: L1 state, genesis witness, EL chain and `InitChain` request.
#[derive(Clone, Debug)]
pub(crate) struct Fixture {
    /// The chain parameters the app runs with.
    pub(crate) params: ChainParams,
    /// The activation record planted in the Inbox.
    pub(crate) activation: ActivationRecord,
    /// The Inbox storage at `L1_0`.
    pub(crate) inbox: InboxStorage,
    /// The registry storage at `L1_0`.
    pub(crate) registry: RegistryStorage,
    /// The L1 state at `L1_0` (filler accounts, Inbox, registry).
    pub(crate) l1_state: TestState,
    /// The genesis witness (its `l1_header` is the raw block `L1_0` with `l1_state`'s root).
    pub(crate) witness: GenesisWitness,
    /// The derived `e_0` committee record.
    pub(crate) record: CommitteeRecord,
    /// The derived `e_0` members (MEM-08 order).
    pub(crate) members: Vec<Member>,
    /// The EL's canonical chain: `[B* − 1, B*]` (just `[B*]` when `B* = 0`).
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
        let b_star = el_chain.last().expect("the EL chain holds B*");
        let activation = ActivationRecord {
            genesis_height: spec.genesis_height,
            l1_0: spec.l1_0,
            epoch_len: spec.epoch_len,
            epoch_len_l1: spec.epoch_len_l1,
            genesis_hash: b_star.hash_slow(),
            genesis_state_root: b_star.state_root,
        };

        let registry =
            RegistryStorage { checkpoints: vec![(spec.l1_0, sample_entries(spec.n_validators))] };
        let (record, members) = genesis_committee(&params, spec.l1_0, &registry, Schedule::E0);
        let committee_e0 = spec
            .committee_e0
            .unwrap_or_else(|| committee::record_hash(params.l2_chain_id, &record));

        let inbox = InboxStorage {
            recovery_generation: spec.recovery_generation,
            ..InboxStorage::genesis(activation.clone(), committee_e0)
        };
        let l1_state = l1_state_with(&params, &inbox, &registry);

        let mut header = l1_header(spec.l1_0, Self::l1_timestamp(spec.l1_0));
        header.state_root = l1_state.state_root();
        let witness = GenesisWitness {
            l1_header: RawL1Header::from(&header),
            inbox: l1_state.witness(params.inbox, &inbox::genesis_slots(Schedule::E0)),
            committee: committee_witness(&l1_state, params.registry, &registry, 0, record.clone()),
        };

        let request = InitChain {
            time: Time::from_unix_timestamp(
                i64::try_from(witness.l1_header.timestamp()).expect("timestamp fits i64"),
                0,
            )
            .expect("valid genesis time"),
            chain_id: chain_id_for(params.l2_chain_id, spec.recovery_generation),
            consensus_params: consensus_params(),
            validators: validator_updates(&members),
            app_state_bytes: encode_app_state(&witness).into(),
            initial_height: Height::try_from(spec.genesis_height + 1).expect("height fits i64"),
        };

        Self {
            params,
            activation,
            inbox,
            registry,
            l1_state,
            witness,
            record,
            members,
            el_chain,
            request,
        }
    }

    /// An L1 whose canonical, finalized block `L1_0` is the witness header over `l1_state`.
    pub(crate) fn l1(&self) -> MockL1 {
        let l1 = MockL1::new(self.activation.l1_0 + self.params.l1_finality_extra_depth);
        l1.insert_header(self.witness.l1_header.clone());
        l1.state().states.insert(self.activation.l1_0, self.l1_state.clone());
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

    /// An app over [`Fixture::l1`], [`Fixture::engine`] and a store in `dir`, with default
    /// options.
    pub(crate) fn app(&self, dir: &Path) -> App<MockL1, MockEngine> {
        App::new(
            self.l1(),
            self.engine(),
            self.params.clone(),
            Store::new(dir.to_path_buf()),
            AppOptions::default(),
        )
        .expect("the fixture app starts")
    }

    /// Replaces the genesis witness and re-encodes the request's `app_state` from it.
    pub(crate) fn set_witness(&mut self, witness: GenesisWitness) {
        self.request.app_state_bytes = encode_app_state(&witness).into();
        self.witness = witness;
    }

    /// `H*`, the genesis anchor's L2 block hash.
    pub(crate) fn genesis_hash(&self) -> B256 {
        self.activation.genesis_hash
    }

    /// The timestamp of L1 block `number` in fixture L1s (12-second slots).
    pub(crate) fn l1_timestamp(number: u64) -> u64 {
        1_760_000_000 + number * 12
    }

    /// The genesis Inbox storage with the last checkpoint moved to `last_checkpoint_height`
    /// (hash derived from the height) and `committee` entries appended to the mapping.
    pub(crate) fn inbox_with(
        &self,
        last_checkpoint_height: u64,
        committee: &[(u64, B256)],
    ) -> InboxStorage {
        let mut inbox = self.inbox.clone();
        inbox.last_checkpoint_height = last_checkpoint_height;
        inbox.last_checkpoint_hash = B256::from(U256::from(last_checkpoint_height) + U256::from(1));
        inbox.committee.extend_from_slice(committee);
        inbox
    }

    /// Plants L1 block `number` holding `inbox` and `registry` (plus the filler accounts) as
    /// canonical in `l1`, without moving its finalized block; returns the stored raw header.
    pub(crate) fn plant_l1_block(
        &self,
        l1: &MockL1,
        number: u64,
        inbox: &InboxStorage,
        registry: &RegistryStorage,
    ) -> RawL1Header {
        let state = l1_state_with(&self.params, inbox, registry);
        l1.insert_block(l1_header(number, Self::l1_timestamp(number)), state)
    }

    /// Plants L1 block `number` (see [`Fixture::plant_l1_block`]) and moves `l1`'s finalized
    /// block so that it is final with the chain's extra depth: a proposer then anchors there.
    pub(crate) fn advance_l1(
        &self,
        l1: &MockL1,
        number: u64,
        inbox: &InboxStorage,
        registry: &RegistryStorage,
    ) -> RawL1Header {
        let header = self.plant_l1_block(l1, number, inbox, registry);
        l1.set_finalized(number + self.params.l1_finality_extra_depth);
        header
    }

    /// The anchor witness of the L1 block `number` planted in `l1`, proving
    /// `anchor_slots(committee_epoch)`.
    pub(crate) fn anchor_witness(
        &self,
        l1: &MockL1,
        number: u64,
        committee_epoch: Option<u64>,
    ) -> AnchorWitness {
        let guard = l1.state();
        let header = guard.headers.get(&number).expect("the L1 block is planted").clone();
        let state = guard.states.get(&number).expect("the L1 block has a state");
        AnchorWitness {
            l1_header: header,
            inbox: state.witness(self.params.inbox, &inbox::anchor_slots(committee_epoch)),
        }
    }

    /// The anchor a witness of the L1 block `number` planted in `l1` proves.
    pub(crate) fn anchor_state(
        &self,
        l1: &MockL1,
        number: u64,
        committee_epoch: Option<u64>,
    ) -> AnchorState {
        let w = self.anchor_witness(l1, number, committee_epoch);
        verify_anchor_witness(&w, self.params.inbox, committee_epoch).expect("planted anchor")
    }

    /// The committee of `target_epoch` derived from the genesis registry snapshot with the
    /// genesis cutoff (the members equal epoch `e_0`'s; the record differs in its target and
    /// set root).
    pub(crate) fn committee(&self, target_epoch: u64) -> CommitteeState {
        let (record, members) =
            genesis_committee(&self.params, self.activation.l1_0, &self.registry, target_epoch);
        CommitteeState { record, members }
    }

    /// The `AppState` a correct `InitChain` persists for this genesis.
    pub(crate) fn expected_state(&self) -> AppState {
        let b_star = self.el_chain.last().expect("the EL chain holds B*");
        let grandparent_timestamp = if self.el_chain.len() > 1 {
            self.el_chain[self.el_chain.len() - 2].timestamp
        } else {
            0
        };
        let committee_e0 = self.inbox.committee[0].1;
        AppState {
            chain_id: self.request.chain_id.clone(),
            generation: self.inbox.recovery_generation,
            activation: self.activation.clone(),
            schedule: Schedule::from_activation(&self.activation),
            last_height: self.activation.genesis_height,
            parent: ParentInfo {
                number: b_star.number,
                hash: b_star.hash_slow(),
                timestamp: b_star.timestamp,
                gas_limit: b_star.gas_limit,
                gas_used: b_star.gas_used,
                base_fee: b_star.base_fee_per_gas.expect("B* has a base fee"),
                difficulty: b_star.difficulty,
                grandparent_timestamp,
            },
            anchor: AnchorState {
                number: self.activation.l1_0,
                hash: self.witness.l1_header.hash(),
                state_root: self.l1_state.state_root(),
                timestamp: self.witness.l1_header.timestamp(),
                inbox: InboxFacts {
                    migration_state: inbox::ETNA_ACTIVE,
                    recovery_generation: self.inbox.recovery_generation,
                    last_checkpoint_height: self.activation.genesis_height,
                    last_checkpoint_hash: self.activation.genesis_hash,
                    committee: Some((Schedule::E0, committee_e0)),
                },
            },
            committees: BTreeMap::from([(
                Schedule::E0,
                CommitteeState { record: self.record.clone(), members: self.members.clone() },
            )]),
        }
    }
}

/// The committee of `target_epoch` derived from `registry`'s first checkpoint (the genesis
/// snapshot) with the cutoff of the activation block `l1_0`.
fn genesis_committee(
    params: &ChainParams,
    l1_0: u64,
    registry: &RegistryStorage,
    target_epoch: u64,
) -> (CommitteeRecord, Vec<Member>) {
    let cutoff =
        committee::cutoff(l1_0, params.cutoff_grid, params.cutoff_lag).expect("L1_0 has a cutoff");
    let snapshot = Snapshot {
        checkpoint_index: 0,
        l1_block: l1_0,
        entries: registry.checkpoints[0].1.clone(),
    };
    committee::derive(&snapshot, cutoff, target_epoch, params)
        .expect("the genesis snapshot derives a committee")
}

/// The L1 state at `params`' addresses: the filler accounts, the Inbox holding `inbox` and the
/// staking registry holding `registry`.
pub(crate) fn l1_state_with(
    params: &ChainParams,
    inbox: &InboxStorage,
    registry: &RegistryStorage,
) -> TestState {
    let mut accounts = filler_accounts();
    accounts.push(inbox_account(params.inbox, inbox));
    accounts.push(registry_account(params.registry, registry));
    TestState::new(accounts)
}

/// The CometBFT validator updates of `members` (Ed25519 key, power), in member order.
pub(crate) fn validator_updates(members: &[Member]) -> Vec<validator::Update> {
    members
        .iter()
        .map(|m| validator::Update {
            pub_key: public_key::PublicKey::from_raw_ed25519(m.pubkey.as_slice())
                .expect("32-byte Ed25519 key"),
            power: vote::Power::try_from(m.power).expect("power fits i64"),
        })
        .collect()
}

/// The EL chain up to `B* = genesis_height`: `[B* − 1, B*]`, or `[B*]` when `B* = 0`. `B*`
/// links to its parent and carries a base fee and zk gas (difficulty).
pub(crate) fn el_chain(genesis_height: u64) -> Vec<Header> {
    let block = |number: u64, parent_hash: B256| Header {
        parent_hash,
        beneficiary: Address::repeat_byte(0xfe),
        state_root: B256::with_last_byte(u8::try_from(number % 251).expect("fits u8") + 1),
        number,
        gas_limit: 45_000_000,
        gas_used: 21_000 * (number % 7 + 1),
        timestamp: 1_760_000_000 + number * 2,
        base_fee_per_gas: Some(10_000_000 + number),
        difficulty: U256::from(243_000 + number),
        ..Header::default()
    };
    match genesis_height.checked_sub(1) {
        None => vec![block(0, B256::ZERO)],
        Some(parent) => {
            let parent = block(parent, B256::repeat_byte(0x99));
            let b_star = block(genesis_height, parent.hash_slow());
            vec![parent, b_star]
        }
    }
}

/// CometBFT consensus parameters as the genesis builder writes them.
pub(crate) fn consensus_params() -> consensus::Params {
    consensus::Params {
        block: block::Size { max_bytes: 22_020_096, max_gas: -1, time_iota_ms: 1_000 },
        evidence: evidence::Params {
            max_age_num_blocks: 100_000,
            max_age_duration: evidence::Duration(std::time::Duration::from_secs(172_800)),
            max_bytes: 1_048_576,
        },
        validator: ValidatorParams { pub_key_types: vec![public_key::Algorithm::Ed25519] },
        version: Some(VersionParams { app: 0 }),
        abci: AbciParams::default(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{committee::verify_committee_witness, l1::witness::verify_genesis_inbox};

    #[test]
    fn fixture_witness_verifies_against_its_own_l1_state() {
        let fx = Fixture::genesis(3);
        let root = fx.witness.l1_header.state_root();
        assert_eq!(root, fx.l1_state.state_root());
        let (activation, facts, committee_e0) =
            verify_genesis_inbox(root, &fx.witness.inbox, fx.params.inbox).expect("inbox verifies");
        assert_eq!(activation, fx.activation);
        assert_eq!(facts.recovery_generation, 0);
        assert_eq!(committee_e0, committee::record_hash(fx.params.l2_chain_id, &fx.record));
        assert_eq!(
            verify_committee_witness(
                &fx.expected_state().anchor,
                &fx.params,
                &fx.witness.committee,
                0
            ),
            Ok((fx.record.clone(), fx.members.clone()))
        );
        assert_eq!(fx.registry.checkpoints, vec![(fx.activation.l1_0, sample_entries(3))]);
        assert_eq!(fx.members.len(), 3);
        assert_eq!(fx.request.validators.len(), 3);
        assert_eq!(fx.request.initial_height.value(), fx.activation.genesis_height + 1);
    }

    #[test]
    fn fixture_el_chain_links_b_star_to_its_parent() {
        let chain = el_chain(1_000);
        assert_eq!(chain.len(), 2);
        assert_eq!(chain[1].parent_hash, chain[0].hash_slow());
        assert_eq!(chain[1].number, 1_000);
        assert_eq!(el_chain(0).len(), 1);
    }
}
