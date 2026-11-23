//! Genuine trie/proof fixtures for immutable batch assembly, signed by the generation's origin
//! fallback keys, each at power 1, at every height, over L2 post-states whose staking proxy holds
//! scripted staking words.

use super::consensus::{
    FixtureCommittee, SigningKey, fallback_keys, pair_with_envelope, parameters,
};
use crate::{
    comet::{CometSource, CometStatus},
    error::{LanderError, Result},
    l1::{Deployment, LandingSource, ParentContext},
    types::{CertifiedBlock, LandingSnapshot},
};
use abci::{
    AccountWitness, AnchorState, AnchorWitness, ChainParams, EtnaEnvelope, ExecutionBlock,
    ForcedWitness, GenesisRecord, InboxFacts, ParentInfo, RawL1Header, StorageProof,
    fallback::FallbackKeys,
    forced::ForcedEntry,
    key::ConsensusKey,
    l1::layout::inbox,
    rules::{self, HeaderInputs},
    valstate::ValState,
};
use alloy_consensus::{EMPTY_OMMER_ROOT_HASH, EMPTY_ROOT_HASH, Header};
use alloy_eips::eip7685::EMPTY_REQUESTS_HASH;
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};
use async_trait::async_trait;
use std::{
    collections::BTreeMap,
    sync::atomic::{AtomicBool, AtomicUsize, Ordering},
};

/// A state trie of accounts with storage, whose EIP-1186 witnesses verify under `root`.
#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub(crate) struct State {
    accounts: BTreeMap<Address, (BTreeMap<B256, U256>, B256)>,
    pub(crate) root: B256,
}

fn trie(leaves: BTreeMap<B256, Vec<u8>>, targets: Vec<Nibbles>) -> (B256, ProofNodes) {
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(targets));
    for (key, value) in leaves {
        builder.add_leaf(Nibbles::unpack(key), &value);
    }
    let root = builder.root();
    (root, builder.take_proof_nodes())
}
/// `len` pseudorandom nonzero calldata bytes seeded by `height`, which the V6 payload's zlib
/// cannot shrink, so block sizes keep counting blobs.
fn incompressible(height: u64, len: usize) -> Bytes {
    let mut state = 0x9e37_79b9_7f4a_7c15 ^ height;
    (0..len)
        .map(|_| {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            (state >> 56) as u8 | u8::from(state >> 56 == 0)
        })
        .collect()
}
fn nodes(proofs: &ProofNodes, key: B256) -> Vec<Bytes> {
    proofs.matching_nodes_sorted(&Nibbles::unpack(key)).into_iter().map(|(_, node)| node).collect()
}
impl State {
    /// The state holding `accounts` and their nonzero storage words.
    pub(crate) fn new(accounts: Vec<(Address, Vec<(B256, U256)>)>) -> Self {
        let accounts = accounts
            .into_iter()
            .map(|(address, slots)| {
                let slots = slots
                    .into_iter()
                    .filter(|(_, value)| !value.is_zero())
                    .collect::<BTreeMap<_, _>>();
                let root = trie(
                    slots
                        .iter()
                        .map(|(slot, value)| (keccak256(slot), alloy_rlp::encode(value)))
                        .collect(),
                    vec![],
                )
                .0;
                (address, (slots, root))
            })
            .collect::<BTreeMap<_, _>>();
        let root = trie(Self::leaves(&accounts), vec![]).0;
        Self { accounts, root }
    }
    fn leaves(
        accounts: &BTreeMap<Address, (BTreeMap<B256, U256>, B256)>,
    ) -> BTreeMap<B256, Vec<u8>> {
        accounts
            .iter()
            .map(|(address, (_, root))| {
                (
                    keccak256(address),
                    alloy_rlp::encode(TrieAccount {
                        nonce: 0,
                        balance: U256::ZERO,
                        storage_root: *root,
                        code_hash: keccak256(b"test account"),
                    }),
                )
            })
            .collect()
    }
    /// An exact-slot witness of `address`, as `eth_getProof` returns it.
    pub(crate) fn witness(&self, address: Address, slots: &[B256]) -> AccountWitness {
        let (storage, root) = &self.accounts[&address];
        let (_, account_proofs) =
            trie(Self::leaves(&self.accounts), vec![Nibbles::unpack(keccak256(address))]);
        let (_, storage_proofs) = trie(
            storage
                .iter()
                .map(|(slot, value)| (keccak256(slot), alloy_rlp::encode(value)))
                .collect(),
            slots.iter().map(|slot| Nibbles::unpack(keccak256(slot))).collect(),
        );
        AccountWitness {
            address,
            nonce: 0,
            balance: U256::ZERO,
            storage_root: *root,
            code_hash: keccak256(b"test account"),
            account_proof: nodes(&account_proofs, keccak256(address)),
            storage: slots
                .iter()
                .map(|slot| StorageProof {
                    slot: *slot,
                    value: storage.get(slot).copied().unwrap_or_default(),
                    proof: nodes(&storage_proofs, keccak256(slot)),
                })
                .collect(),
        }
    }
}

/// The `maxBatchBlocks` the [`Fixture`] Inbox reports.
pub const MAX_BATCH_BLOCKS: u64 = 120;

pub struct Fixture {
    pub params: ChainParams,
    pub snapshot: LandingSnapshot,
    pub blocks: BTreeMap<u64, CertifiedBlock>,
    pub committees: BTreeMap<u64, FixtureCommittee>,
    pub anchors: BTreeMap<u64, AnchorState>,
    pub headers: BTreeMap<u64, Header>,
    pub l1_headers: BTreeMap<u64, RawL1Header>,
    /// The fallback key list generation 0's origin record and slot 278 hold the hash of; its
    /// keys sign every height of the generation, each at power 1.
    pub origin_keys: FallbackKeys,
    pub mismatch_statement: AtomicBool,
    pub starting_proof_mutation: Option<u8>,
    pub parent_anchor_override: Option<AnchorState>,
    /// The validator state after each height from the generation origin on, replayed
    /// independently of the lander ([`replay_val_states`]).
    pub val_states: BTreeMap<u64, ValState>,
    /// Answers that replace the replica's at their heights: `None` is a rejected query.
    pub val_state_answers: BTreeMap<u64, Option<Vec<u8>>>,
    /// The fallback key lists the fixture's L1 serves, by their hash; any other hash is
    /// unavailable.
    pub fallback_lists: BTreeMap<B256, abci::fallback::FallbackKeys>,
    /// How many fallback key lists the fixture's L1 has served.
    pub fallback_reads: AtomicUsize,
    states: BTreeMap<u64, State>,
    /// The L2 post-state after each height of the decided chain: the staking proxy holding its
    /// [`StakingScript`] words of that height. Each EL header's state root is its height's root,
    /// so a staking proof of a height verifies under that header.
    pub l2_states: BTreeMap<u64, State>,
}

/// The `EtnaStaking` words a fixture's L2 post-state holds after a height, given the height and
/// the origin fallback key list: `(slot, word)` pairs, every other word zero.
pub type StakingScript = fn(u64, &FallbackKeys) -> Vec<(B256, U256)>;

/// The default [`StakingScript`]: after `height`, a candidate snapshot taken at `height` with a
/// total stake of `1000 + height`, whose seat `i` holds origin key `i` at power `i + 1`, and each
/// origin key's live key-to-seat word naming its seat. Every fixture anchor proves a minimum total
/// stake of 2^256 − 1, so the candidate never signs and the origin keys sign every height.
pub fn staking_words(height: u64, keys: &FallbackKeys) -> Vec<(B256, U256)> {
    use abci::staking::{
        key_to_seat_slot, record_slots, snapshot_height_slot, snapshot_total_stake_slot,
    };
    let mut words = vec![
        (snapshot_height_slot(), U256::from(height)),
        (snapshot_total_stake_slot(), U256::from(1000 + height)),
    ];
    for (seat, key) in (0u8..).zip(keys.keys()) {
        let [x, packed] = record_slots(seat);
        words.extend([
            (x, U256::from_be_bytes(key.x().0)),
            (packed, U256::from(key.prefix()) | U256::from(u64::from(seat) + 1) << 8),
            (key_to_seat_slot(key.address()), U256::from(1) | U256::from(seat) << 8),
        ]);
    }
    words
}

/// The L2 post-state whose staking proxy `params.staking` holds `words`.
pub(crate) fn l2_state(params: &ChainParams, words: Vec<(B256, U256)>) -> State {
    State::new(vec![(params.staking, words)])
}

/// A header's `app_hash` field holding appHash (ENC-A-29b) of the EL hash `block_hash` and
/// the validator state `state` after the same height.
pub fn app_hash(block_hash: B256, state: &ValState) -> tendermint::AppHash {
    let hash = abci::valstate::app_hash(block_hash, state.hash());
    tendermint::AppHash::try_from(hash.to_vec()).unwrap()
}

/// The validator states after heights `origin..=tip`, replayed as abci's app keeps them: the
/// genesis state of `initial`, keys with their powers, at `origin`, then one advance per height
/// by the empty update list every height returns.
pub fn replay_val_states(
    (origin, initial): (u64, &[(ConsensusKey, u64)]),
    tip: u64,
) -> BTreeMap<u64, ValState> {
    let mut states = BTreeMap::from([(origin, ValState::genesis(origin, initial).unwrap())]);
    for height in origin + 1..=tip {
        let next = states[&(height - 1)].advance(&[]).unwrap();
        states.insert(height, next);
    }
    states
}

fn l1_header(number: u64, state: &State, parent: B256) -> RawL1Header {
    RawL1Header::from_raw(
        alloy_rlp::encode(Header {
            number,
            parent_hash: parent,
            state_root: state.root,
            timestamp: number,
            ..Default::default()
        })
        .into(),
    )
    .unwrap()
}
/// The Inbox forced inclusion queue of one fixture L1 state.
#[derive(Clone, Debug)]
struct Queue {
    /// `head` at slot 281: the entries settled by the state's landed checkpoint.
    head: u64,
    /// `tail` at slot 281: the next free index.
    tail: u64,
    /// Entries planted in the `queue` mapping (slot 280), each at its own index.
    entries: Vec<ForcedEntry>,
}

/// The fixture's L1 state: the Inbox with last checkpoint `(height, hash)` and its three-word
/// landing record (`endpoint`: height, EL and Comet hashes), the genesis record `genesis`, the
/// fallback key list `fallback` (slot 278 and generation 0's origin record, with a minimum total
/// stake of 2^256 − 1 in slot 279) and the forced inclusion queue `queue` (slots 280–281).
fn state_with_queue(
    params: &ChainParams,
    fallback: &FallbackKeys,
    endpoint: (u64, B256, B256),
    genesis: &GenesisRecord,
    queue: &Queue,
) -> State {
    let (height, hash, comet_hash) = endpoint;
    let (fallback_keys_hash, min_total_stake) = fallback_words(fallback);
    let mut slots = vec![
        (inbox::slot(inbox::STATUS), U256::from(3)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HASH), hash.into()),
        (inbox::slot(inbox::FALLBACK_KEYS_HASH), fallback_keys_hash.into()),
        (inbox::slot(inbox::MIN_TOTAL_STAKE), min_total_stake),
    ];
    slots.extend([
        (inbox::slot(inbox::CONFIG_HASH), genesis.config_hash.into()),
        (inbox::slot(inbox::GENESIS_PACKED), U256::from(genesis.l1_0) << 48),
        (inbox::slot(inbox::START_BLOCK_HASH), genesis.genesis_hash.into()),
        (inbox::slot(inbox::START_STATE_ROOT), genesis.genesis_state_root.into()),
        (
            inbox::slot(inbox::FORCED_INCLUSION_CONFIG),
            U256::from(genesis.forced_inclusion_delay) | U256::from(genesis.max_anchor_age) << 48,
        ),
        (
            inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL),
            U256::from(queue.head) | U256::from(queue.tail) << 48,
        ),
    ]);
    let origin = inbox::origin_slots(0);
    slots.extend([
        (origin[0], U256::ZERO),
        (origin[1], U256::from(genesis.l1_0)),
        (origin[2], U256::from(genesis.l1_0)),
        (origin[3], fallback_keys_hash.into()),
    ]);
    let landing = inbox::landing_record_slots(height);
    slots.extend([
        (landing[0], U256::from(queue.head) << 96),
        (landing[1], hash.into()),
        (landing[2], comet_hash.into()),
    ]);
    for entry in &queue.entries {
        let [hash, metadata] = inbox::forced_inclusion_entry_slots(entry.index);
        slots.extend([
            (hash, entry.tx_hash.into()),
            (metadata, U256::from(entry.timestamp) | (U256::from(entry.l1_block) << 48)),
        ]);
    }
    State::new(vec![(params.inbox, slots)])
}

/// Forced inclusion entries planted into a fixture's L1 states, and the L2 heights whose blocks
/// consume them.
#[derive(Clone, Debug)]
pub struct ForcedPlan {
    /// The genesis forced inclusion delay `D`, in seconds.
    pub delay: u64,
    /// The queue in index (and so L1) order: `(l1, timestamp)` puts an entry submitted at
    /// `timestamp` into the state of L1 block `l1` and every later one. Its transaction is
    /// [`forced_transaction`]`(index)`.
    pub entries: Vec<(u64, u64)>,
    /// Heights of the forced inclusion blocks, each consuming its parent's cursor entry. Every
    /// other block whose anchor holds an entry carries its proof and exact bytes.
    pub consume_at: Vec<u64>,
}

impl Default for ForcedPlan {
    /// No forced inclusion entries, under the fixtures' 1 h delay.
    fn default() -> Self {
        Self { delay: 3_600, entries: Vec::new(), consume_at: Vec::new() }
    }
}

impl ForcedPlan {
    /// The planted queue entries with their first L1 block and transaction bytes.
    fn planted(&self) -> Vec<(u64, ForcedEntry, Bytes)> {
        assert!(self.entries.is_sorted_by_key(|(l1, _)| *l1), "entries are stored in L1 order");
        self.entries
            .iter()
            .zip(0..)
            .map(|(&(l1, timestamp), index)| {
                let (tx, tx_hash) = forced_transaction(index);
                let entry = ForcedEntry { index, tx_hash, l1_block: l1, timestamp };
                (l1, entry, tx)
            })
            .collect()
    }

    /// The queue in the state of L1 block `l1` whose landed checkpoint is `checkpoint`: the
    /// entries of `planted` (this plan's [`ForcedPlan::planted`]) planted by then, and the head
    /// the checkpoint's consumed entries moved.
    fn queue(&self, planted: &[(u64, ForcedEntry, Bytes)], l1: u64, checkpoint: u64) -> Queue {
        let entries = planted
            .iter()
            .filter(|(at, ..)| *at <= l1)
            .map(|(_, entry, _)| *entry)
            .collect::<Vec<_>>();
        let head = self.consume_at.iter().filter(|height| **height <= checkpoint).count() as u64;
        assert!(head <= entries.len() as u64, "plan consumes an entry before L1 {l1} holds it");
        Queue { head, tail: entries.len() as u64, entries }
    }
}

/// Canonical transaction bytes and their hash, with the nonce distinguishing each queue entry.
fn forced_transaction(index: u64) -> (Bytes, B256) {
    use alloy_consensus::{SignableTransaction, TxEnvelope, TxLegacy};
    use alloy_eips::eip2718::Encodable2718;
    let tx: Bytes = TxEnvelope::Legacy(
        TxLegacy {
            nonce: index,
            gas_limit: 21_000,
            gas_price: 1_000_000_000,
            ..Default::default()
        }
        .into_signed(alloy_primitives::Signature::new(U256::from(1), U256::from(1), false)),
    )
    .encoded_2718()
    .into();
    let hash = keccak256(&tx);
    (tx, hash)
}

/// The words `(fallback keys hash, minimum total stake)` that anchor witnesses prove at slots 278
/// and 279 of a [`state_with_queue`] state over `fallback`: the list's hash and 2^256 − 1, which
/// makes no candidate usable.
fn fallback_words(fallback: &FallbackKeys) -> (B256, U256) {
    (fallback.hash(), U256::MAX)
}

/// The anchor a witness of `raw` proves: last checkpoint `(height, hash)`, the queue's head and
/// tail, and the [`fallback_words`] of slots 278 and 279.
fn anchor(
    raw: &RawL1Header,
    height: u64,
    hash: B256,
    queue: &Queue,
    (fallback_keys_hash, min_total_stake): (B256, U256),
) -> AnchorState {
    AnchorState {
        number: raw.number(),
        hash: raw.hash(),
        state_root: raw.state_root(),
        timestamp: raw.timestamp(),
        inbox: InboxFacts {
            rules_schedule: alloy_primitives::U256::ZERO,
            recovery_generation: 0,
            last_checkpoint_height: height,
            last_checkpoint_hash: hash,
            forced_inclusion_head: queue.head,
            forced_inclusion_tail: queue.tail,
            fallback_keys_hash,
            min_total_stake,
        },
    }
}

/// Optional anchor/checkpoint progress for genuinely authenticated multi-epoch batches.
struct EpochFixture {
    length: u64,
    advances: bool,
    /// The last checkpoint hash every L1 state above the genesis anchor (10) records instead of
    /// the EL header's: an own-L1 anchor that contradicts the EL ancestry.
    checkpoint_hash: Option<B256>,
}

impl Fixture {
    /// Exact trie proofs for checkpoint-import tests; no consensus source is exposed.
    pub fn import_witness(&self, address: Address, slots: &[B256], number: u64) -> AccountWitness {
        self.states[&number].witness(address, slots)
    }

    /// Append an actual hash-linked L1 observation and MPT after a landing or same-generation
    /// verifier rollback. Retain old mapping leaves so their existence cannot stand in for
    /// membership of the newly selected frontier's parent chain.
    pub fn advance_import_frontier(&mut self, height: u64, parent: u64, recovery_nonce: u64) {
        let previous = self.snapshot.l1_block_number;
        let mut accounts = self.states[&previous]
            .accounts
            .iter()
            .map(|(a, (slots, _))| (*a, slots.clone()))
            .collect::<BTreeMap<_, _>>();
        let slots = accounts.get_mut(&self.params.inbox).unwrap();
        let el = self.headers[&height].hash_slow();
        let comet = B256::from_slice(self.blocks[&height].block.header.hash().as_bytes());
        slots.insert(inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height));
        slots.insert(inbox::slot(inbox::LAST_CHECKPOINT_HASH), el.into());
        slots.insert(inbox::slot(292), U256::from(recovery_nonce)); // STOR-B-15; not an anchor field.
        for (slot, word) in inbox::landing_record_slots(height).into_iter().zip([
            U256::from(parent),
            el.into(),
            comet.into(),
        ]) {
            slots.insert(slot, word);
        }
        let state =
            State::new(accounts.into_iter().map(|(a, s)| (a, s.into_iter().collect())).collect());
        let next = previous + 1;
        let header = l1_header(next, &state, self.l1_headers[&previous].hash());
        self.l1_headers.insert(next, header.clone());
        self.snapshot = crate::l1::decode_snapshot(
            header,
            state.witness(self.params.inbox, &crate::l1::snapshot_landing_slots(height)),
            self.params.l1_chain_id,
            self.params.l2_chain_id,
            &self.params,
        )
        .unwrap();
        self.states.insert(next, state);
    }

    /// Retain multiple landing records `(height, EL hash, Comet hash)` in the same finalized
    /// root, including deliberate hash-authenticated contradiction fixtures supplied by the
    /// caller. Each keeps its packed word and writes the three-word slot 285 record.
    pub fn import_landings(&mut self, records: &[(u64, B256, B256)]) {
        let number = self.snapshot.l1_block_number;
        let mut accounts = self.states[&number]
            .accounts
            .iter()
            .map(|(address, (slots, _))| (*address, slots.clone()))
            .collect::<BTreeMap<_, _>>();
        let slots = accounts.get_mut(&self.params.inbox).unwrap();
        for (height, el, comet) in records {
            if *height == self.snapshot.checkpoint_height {
                slots.insert(inbox::slot(inbox::LAST_CHECKPOINT_HASH), (*el).into());
            }
            let keys = inbox::landing_record_slots(*height);
            for (slot, value) in keys.into_iter().zip([
                slots.get(&keys[0]).copied().unwrap_or_default(),
                (*el).into(),
                (*comet).into(),
            ]) {
                slots.insert(slot, value);
            }
        }
        let state = State::new(
            accounts
                .into_iter()
                .map(|(address, slots)| (address, slots.into_iter().collect()))
                .collect(),
        );
        let header = l1_header(number, &state, self.l1_headers[&(number - 1)].hash());
        self.l1_headers.insert(number, header.clone());
        let recovery = self.snapshot.recovery.clone();
        let recovery_witness = self.snapshot.recovery_witness.clone();
        self.snapshot = crate::l1::decode_snapshot(
            header,
            state.witness(
                self.params.inbox,
                &crate::l1::snapshot_landing_slots(self.snapshot.checkpoint_height),
            ),
            self.params.l1_chain_id,
            self.params.l2_chain_id,
            &self.params,
        )
        .unwrap();
        self.snapshot.recovery = recovery;
        self.snapshot.recovery_witness = recovery_witness;
        self.states.insert(number, state);
    }
    /// The starting proof and the anchor of a new L1 block above every other whose Inbox is the
    /// state of block `number` with `words` written over it, as after a later setter call; the
    /// block joins the fixture's L1.
    pub fn starting_witness_with_inbox_words(
        &mut self,
        number: u64,
        words: impl IntoIterator<Item = (B256, U256)>,
    ) -> (AnchorWitness, AnchorState) {
        let mut accounts = self.states[&number].accounts.clone();
        accounts.get_mut(&self.params.inbox).unwrap().0.extend(words);
        let state = State::new(
            accounts
                .into_iter()
                .map(|(address, (slots, _))| (address, slots.into_iter().collect()))
                .collect(),
        );
        let next = *self.l1_headers.last_key_value().unwrap().0 + 1;
        let raw = l1_header(next, &state, self.l1_headers[&(next - 1)].hash());
        let anchor = abci::l1::verify_anchor_witness(
            &AnchorWitness {
                l1_header: raw.clone(),
                inbox: state.witness(self.params.inbox, &inbox::anchor_slots()),
            },
            self.params.inbox,
        )
        .unwrap();
        let witness = AnchorWitness {
            l1_header: raw.clone(),
            inbox: state.witness(self.params.inbox, &crate::l1::starting_slots(0)),
        };
        self.l1_headers.insert(next, raw);
        self.states.insert(next, state);
        (witness, anchor)
    }

    /// Replant exact Inbox words under a new authenticated root for decoder boundary tests.
    pub fn snapshot_with_inbox_words(
        &self,
        words: impl IntoIterator<Item = (B256, U256)>,
    ) -> LandingSnapshot {
        let mut accounts = self.states[&self.snapshot.l1_block_number].accounts.clone();
        let slots = &mut accounts.get_mut(&self.params.inbox).unwrap().0;
        slots.extend(words);
        let height =
            abci::l1::layout::word_u48(slots[&inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT)], 0);
        let state = State::new(
            accounts
                .into_iter()
                .map(|(address, (slots, _))| (address, slots.into_iter().collect()))
                .collect(),
        );
        let number = self.snapshot.l1_block_number;
        let raw = l1_header(number, &state, self.l1_headers[&(number - 1)].hash());
        LandingSnapshot {
            l1_block_hash: raw.hash(),
            l1_header: raw,
            inbox_witness: state
                .witness(self.params.inbox, &crate::l1::snapshot_landing_slots(height)),
            ..self.snapshot.clone()
        }
    }

    /// The landing snapshot re-planted with the genesis record `genesis` and the forced
    /// inclusion queue's `(head, tail)` at slot 281: the same checkpoint in a fresh snapshot block
    /// over the same parent, with its proof.
    pub fn snapshot_with_forced_queue(
        &self,
        genesis: GenesisRecord,
        head: u64,
        tail: u64,
    ) -> LandingSnapshot {
        let state = state_with_queue(
            &self.params,
            &self.origin_keys,
            (
                self.snapshot.checkpoint_height,
                self.snapshot.checkpoint_hash,
                self.snapshot.checkpoint_comet_hash,
            ),
            &genesis,
            &Queue { head, tail, entries: Vec::new() },
        );
        let number = self.snapshot.l1_block_number;
        let header = l1_header(number, &state, self.l1_headers[&(number - 1)].hash());
        LandingSnapshot {
            l1_block_hash: header.hash(),
            forced_inclusion_head: head,
            forced_inclusion_tail: tail,
            inbox_witness: state.witness(
                self.params.inbox,
                &crate::l1::snapshot_landing_slots(self.snapshot.checkpoint_height),
            ),
            l1_header: header,
            genesis,
            ..self.snapshot.clone()
        }
    }

    pub fn new(checkpoint: u64, tip: u64) -> Self {
        Self::with_calldata(checkpoint, tip, 0)
    }

    fn with_calldata(checkpoint: u64, tip: u64, bytes: usize) -> Self {
        Self::with_epoch(checkpoint, tip, bytes, 24)
    }

    /// As [`Fixture::with_calldata`], with all-zero calldata that the V6 payload compresses to
    /// almost nothing.
    fn with_zero_calldata(checkpoint: u64, tip: u64, bytes: usize) -> Self {
        Self::build(
            checkpoint,
            tip,
            bytes,
            true,
            EpochFixture { length: 24, advances: false, checkpoint_hash: None },
            7_200,
            &ForcedPlan::default(),
            2,
            staking_words,
        )
    }

    pub fn with_epoch(checkpoint: u64, tip: u64, bytes: usize, epoch_len: u64) -> Self {
        Self::build(
            checkpoint,
            tip,
            bytes,
            false,
            EpochFixture { length: epoch_len, advances: false, checkpoint_hash: None },
            7_200,
            &ForcedPlan::default(),
            2,
            staking_words,
        )
    }

    /// Advances authenticated anchor checkpoints often enough to cross multiple active epochs.
    pub fn with_progressing_epochs(checkpoint: u64, tip: u64) -> Self {
        Self::build(
            checkpoint,
            tip,
            0,
            false,
            EpochFixture { length: 12, advances: true, checkpoint_hash: None },
            7_200,
            &ForcedPlan::default(),
            2,
            staking_words,
        )
    }

    /// As [`Fixture::new`], with the forced inclusion entries and blocks of `plan`. Anchor `n` is
    /// at `n` s: L1 10 anchors every block of a genesis checkpoint; otherwise block 1 uses 10,
    /// blocks 2 to 21 use 11 and blocks 22 onwards use 12.
    pub fn with_forced(checkpoint: u64, tip: u64, plan: ForcedPlan) -> Self {
        Self::build(
            checkpoint,
            tip,
            0,
            false,
            EpochFixture { length: 24, advances: false, checkpoint_hash: None },
            7_200,
            &plan,
            2,
            staking_words,
        )
    }

    /// As [`Fixture::new`], but every L1 state above the genesis anchor records `hash` as the last
    /// checkpoint hash. The chain is built over those anchors, so only their checkpoint hash
    /// contradicts the EL ancestry.
    pub fn with_inherited_checkpoint_hash(checkpoint: u64, tip: u64, hash: B256) -> Self {
        Self::build(
            checkpoint,
            tip,
            0,
            false,
            EpochFixture { length: 24, advances: false, checkpoint_hash: Some(hash) },
            7_200,
            &ForcedPlan::default(),
            2,
            staking_words,
        )
    }

    /// As [`Fixture::new`], with the genesis `maxAnchorAge` set to `max_anchor_age` seconds.
    /// Block `h` is at `100 + h` s and anchor `n` at `n` s, so the blocks of a genesis
    /// checkpoint (all anchored at 10) are `90 + h` s younger than their anchor.
    pub fn with_max_anchor_age(checkpoint: u64, tip: u64, max_anchor_age: u64) -> Self {
        Self::build(
            checkpoint,
            tip,
            0,
            false,
            EpochFixture { length: 24, advances: false, checkpoint_hash: None },
            max_anchor_age,
            &ForcedPlan::default(),
            2,
            staking_words,
        )
    }

    /// As [`Fixture::new`], with `count` origin fallback keys (seeds 1 to `count`), each at
    /// power 1, signing every height.
    pub fn with_origin_keys(checkpoint: u64, tip: u64, count: u8) -> Self {
        Self::build(
            checkpoint,
            tip,
            0,
            false,
            EpochFixture { length: 24, advances: false, checkpoint_hash: None },
            7_200,
            &ForcedPlan::default(),
            count,
            staking_words,
        )
    }

    /// As [`Fixture::new`], with the L2 post-state after each height holding the staking words
    /// `script` gives for it.
    pub fn with_staking_script(checkpoint: u64, tip: u64, script: StakingScript) -> Self {
        Self::build(
            checkpoint,
            tip,
            0,
            false,
            EpochFixture { length: 24, advances: false, checkpoint_hash: None },
            7_200,
            &ForcedPlan::default(),
            2,
            script,
        )
    }

    /// Builds the decided chain up to `tip` over the genesis `maxAnchorAge` `max_anchor_age` and
    /// the forced inclusion entries and blocks of `plan`, signed by `origin_keys` origin fallback
    /// keys; each block carries one transaction with `bytes` of calldata (zeros if `zeros`)
    /// unless zero, and each height's L2 post-state holds the staking words `staking` gives.
    #[allow(clippy::too_many_arguments)]
    fn build(
        checkpoint: u64,
        tip: u64,
        bytes: usize,
        zeros: bool,
        epochs: EpochFixture,
        max_anchor_age: u64,
        plan: &ForcedPlan,
        origin_keys: u8,
        staking: StakingScript,
    ) -> Self {
        let epoch_len = epochs.length;
        assert!(checkpoint == 0 || checkpoint >= 6);
        let anchor_number = |height: u64| {
            if height <= 6 || (checkpoint == 0 && !epochs.advances) {
                10
            } else if height < epoch_len - 1 {
                11
            } else if epochs.advances {
                12 + (height - (epoch_len - 1)) / (epoch_len - 6)
            } else {
                12
            }
        };
        let mut params = parameters();
        params.unsettled_limit = 18;
        let keys = (1..=origin_keys)
            .map(|seed| SigningKey::from_slice(&[seed; 32]).unwrap())
            .collect::<Vec<_>>();
        // The keys are generation 0's origin fallback keys, so the set that signs every height
        // holds them all, each at power 1.
        let origin_keys = fallback_keys(&keys);
        let l2_states = (0..=tip)
            .map(|height| (height, l2_state(&params, staking(height, &origin_keys))))
            .collect::<BTreeMap<_, _>>();
        let genesis_header = Header {
            number: 0,
            state_root: l2_states[&0].root,
            timestamp: 100,
            gas_limit: params.block_gas_limit,
            base_fee_per_gas: Some(1_000_000),
            ..Default::default()
        };
        let genesis = GenesisRecord {
            config_hash: params.config_hash(),
            genesis_height: 0,
            l1_0: 10,
            genesis_hash: genesis_header.hash_slow(),
            genesis_state_root: genesis_header.state_root,
            forced_inclusion_delay: plan.delay,
            max_anchor_age,
        };
        let committees = BTreeMap::from([(0, FixtureCommittee::fallback(&origin_keys))]);
        let val_states = replay_val_states((0, &committees[&0].members), tip);
        let planted = plan.planted();
        let genesis_state = state_with_queue(
            &params,
            &origin_keys,
            (0, genesis.genesis_hash, B256::ZERO),
            &genesis,
            &plan.queue(&planted, 10, 0),
        );
        let raw10 = l1_header(10, &genesis_state, B256::repeat_byte(9));
        let words = fallback_words(&origin_keys);
        let anchor10 = anchor(&raw10, 0, genesis.genesis_hash, &plan.queue(&planted, 10, 0), words);
        let mut cursor = 0;
        let mut states = BTreeMap::from([(10, genesis_state)]);
        let mut l1_headers = BTreeMap::from([(10, raw10)]);
        let mut anchors = BTreeMap::from([(0, anchor10.clone())]);
        let mut headers = BTreeMap::from([(0, genesis_header)]);
        let mut blocks: BTreeMap<u64, CertifiedBlock> = BTreeMap::new();
        let mut parent = ParentInfo {
            number: 0,
            hash: genesis.genesis_hash,
            timestamp: 100,
            gas_limit: params.block_gas_limit,
            gas_used: 0,
            base_fee: 1_000_000,
            difficulty: U256::ZERO,
            grandparent_timestamp: 0,
        };
        for height in 1..=tip {
            let number = anchor_number(height);
            let cp = if number == 10 {
                0
            } else if number == 11 {
                6
            } else if epochs.advances {
                epoch_len - 6 + (number - 12) * (epoch_len - 6)
            } else {
                epoch_len - 6
            };
            if !l1_headers.contains_key(&number) {
                let state = state_with_queue(
                    &params,
                    &origin_keys,
                    (
                        cp,
                        epochs.checkpoint_hash.unwrap_or_else(|| headers[&cp].hash_slow()),
                        blocks.get(&cp).map_or(B256::ZERO, |pair| {
                            B256::from_slice(pair.block.header.hash().as_bytes())
                        }),
                    ),
                    &genesis,
                    &plan.queue(&planted, number, cp),
                );
                let raw = l1_header(number, &state, l1_headers[&(number - 1)].hash());
                states.insert(number, state);
                l1_headers.insert(number, raw);
            }
            let cp_hash = match epochs.checkpoint_hash {
                Some(hash) if number > 10 => hash,
                _ => headers[&cp].hash_slow(),
            };
            let forced = height == 1;
            let changing = anchors[&(height - 1)].number != number;
            let raw = &l1_headers[&number];
            let a = anchor(raw, cp, cp_hash, &plan.queue(&planted, number, cp), words);
            let witness = (forced || changing).then(|| AnchorWitness {
                l1_header: raw.clone(),
                inbox: states[&number].witness(params.inbox, &inbox::anchor_slots()),
            });
            // The entry at the cursor, while the anchor's queue holds one: consumed with its
            // transaction at a planned height, otherwise peeked at.
            let witness_forced = (cursor < a.inbox.forced_inclusion_tail).then(|| {
                let consume = plan.consume_at.contains(&height);
                let tx = planted[cursor as usize].2.clone();
                let w = ForcedWitness {
                    index: cursor,
                    entry: states[&number]
                        .witness(params.inbox, &inbox::forced_inclusion_entry_slots(cursor)),
                    tx,
                };
                cursor += u64::from(consume);
                w
            });
            assert!(
                witness_forced.as_ref().is_some_and(|w| !w.tx.is_empty()) ||
                    !plan.consume_at.contains(&height),
                "plan consumes at height {height} without a pending entry"
            );
            let expected = rules::expected_header(&HeaderInputs {
                height,
                beneficiary: super::consensus::BATCH_RECIPIENT,
                parent: &parent,
                anchor: &a,
                bft_time_secs: if max_anchor_age < 7200 { 1261 + height } else { 100 + height },
                generation: 0,
                miss_bitmap: 0,
                params: &params,
                min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(
                    params.l2_chain_id,
                ),
            })
            .unwrap();
            let mut transactions = if bytes == 0 {
                vec![]
            } else {
                use alloy::signers::SignerSync;
                use alloy_consensus::{SignableTransaction, TxEip1559, TxEnvelope};
                use alloy_eips::eip2718::Encodable2718;
                let tx = TxEip1559 {
                    chain_id: params.l2_chain_id,
                    nonce: height - 1,
                    gas_limit: 2_000_000,
                    max_fee_per_gas: 1_000_001,
                    max_priority_fee_per_gas: 1,
                    to: alloy_primitives::TxKind::Call(Address::repeat_byte(0x66)),
                    input: if zeros {
                        vec![0; bytes].into()
                    } else {
                        incompressible(height, bytes)
                    },
                    ..Default::default()
                };
                let signature =
                    super::runtime::signer().sign_hash_sync(&tx.signature_hash()).unwrap();
                vec![Bytes::from(TxEnvelope::Eip1559(tx.into_signed(signature)).encoded_2718())]
            };
            if plan.consume_at.contains(&height) {
                transactions.insert(0, witness_forced.as_ref().expect("pending").tx.clone());
            }
            let el = Header {
                transactions_root: alloy_trie::root::ordered_trie_root_encoded(&transactions),
                number: height,
                parent_hash: expected.parent_hash,
                state_root: l2_states[&height].root,
                timestamp: expected.timestamp,
                beneficiary: expected.beneficiary,
                extra_data: expected.extra_data,
                parent_beacon_block_root: Some(expected.parent_beacon_block_root),
                gas_limit: expected.gas_limit,
                base_fee_per_gas: Some(expected.base_fee),
                mix_hash: expected.mix_hash,
                withdrawals_root: Some(EMPTY_ROOT_HASH),
                blob_gas_used: Some(0),
                excess_blob_gas: Some(0),
                requests_hash: Some(EMPTY_REQUESTS_HASH),
                ommers_hash: EMPTY_OMMER_ROOT_HASH,
                ..Default::default()
            };
            let mut pair = pair_with_envelope(
                EtnaEnvelope {
                    block: ExecutionBlock { header: el.clone(), transactions },
                    anchor: witness,
                    forced: witness_forced,
                },
                &committees[&0],
                &keys,
                blocks.get(&(height - 1)),
            );
            if max_anchor_age < 7200 {
                pair.block.header.time =
                    tendermint::Time::from_unix_timestamp((1261 + height) as i64, 0).unwrap();
            }
            pair.block.header.next_validators_hash = committees[&0].validators.hash();
            // CONS-3.1-8: the app_hash the app returned for the parent, appHash of its EL hash
            // and the validator state after it.
            pair.block.header.app_hash = app_hash(parent.hash, &val_states[&(height - 1)]);
            super::consensus::resign(&mut pair, &committees[&0], &keys);
            parent = ParentInfo {
                number: height,
                hash: el.hash_slow(),
                timestamp: el.timestamp,
                gas_limit: el.gas_limit,
                gas_used: el.gas_used,
                base_fee: el.base_fee_per_gas.unwrap(),
                difficulty: el.difficulty,
                grandparent_timestamp: parent.timestamp,
            };
            anchors.insert(height, a);
            headers.insert(height, el);
            blocks.insert(height, pair);
        }
        let last = *l1_headers.last_key_value().unwrap().0;
        let root_state = states[&last].clone();
        let snapshot_number = last.max(12) + 3;
        for number in last + 1..=snapshot_number {
            let raw = l1_header(number, &root_state, l1_headers[&(number - 1)].hash());
            l1_headers.insert(number, raw);
        }
        let snapshot_queue = plan.queue(&planted, snapshot_number, checkpoint);
        let snapshot_state = state_with_queue(
            &params,
            &origin_keys,
            (
                checkpoint,
                headers[&checkpoint].hash_slow(),
                blocks.get(&checkpoint).map_or(B256::ZERO, |pair: &CertifiedBlock| {
                    B256::from_slice(pair.block.header.hash().as_bytes())
                }),
            ),
            &genesis,
            &snapshot_queue,
        );
        let snapshot_header =
            l1_header(snapshot_number, &snapshot_state, l1_headers[&(snapshot_number - 1)].hash());
        l1_headers.insert(snapshot_number, snapshot_header.clone());
        let landing = LandingSnapshot {
            l1_block_hash: snapshot_header.hash(),
            l1_block_number: snapshot_number,
            l1_chain_id: U256::from(1),
            l2_chain_id: params.l2_chain_id,
            inbox: params.inbox,
            recovery: None,
            recovery_witness: None,
            generation: 0,
            checkpoint_height: checkpoint,
            checkpoint_hash: headers[&checkpoint].hash_slow(),
            checkpoint_comet_hash: blocks
                .get(&checkpoint)
                .map_or(B256::ZERO, |pair: &CertifiedBlock| {
                    B256::from_slice(pair.block.header.hash().as_bytes())
                }),
            forced_inclusion_head: snapshot_queue.head,
            forced_inclusion_tail: snapshot_queue.tail,
            config_hash: genesis.config_hash,
            l1_header: snapshot_header,
            inbox_witness: snapshot_state
                .witness(params.inbox, &crate::l1::snapshot_landing_slots(checkpoint)),
            genesis,
        };
        states.insert(snapshot_number, snapshot_state);
        Self {
            params,
            snapshot: landing,
            blocks,
            committees,
            anchors,
            headers,
            l1_headers,
            fallback_lists: BTreeMap::from([(origin_keys.hash(), origin_keys.clone())]),
            origin_keys,
            mismatch_statement: AtomicBool::new(false),
            starting_proof_mutation: None,
            parent_anchor_override: None,
            val_states,
            val_state_answers: BTreeMap::new(),
            fallback_reads: AtomicUsize::new(0),
            states,
            l2_states,
        }
    }
}

#[async_trait]
impl CometSource for Fixture {
    async fn status(&self) -> Result<CometStatus> {
        Ok(CometStatus {
            chain_id: rules::chain_id_for(&self.params, self.snapshot.generation).unwrap(),
            height: if self.snapshot.recovery.is_some() && self.blocks.is_empty() {
                0
            } else {
                *self.headers.last_key_value().unwrap().0
            },
        })
    }
    async fn block(&self, height: u64) -> Result<CertifiedBlock> {
        self.blocks
            .get(&height)
            .cloned()
            .ok_or_else(|| LanderError::Unavailable(format!("height {height} pruned")))
    }
    /// As the app answers `/val_state/<height>`: any height it has committed.
    async fn val_state(&self, height: u64) -> Result<Vec<u8>> {
        let answer = match self.val_state_answers.get(&height) {
            Some(answer) => answer.clone(),
            None => self.val_states.get(&height).map(ValState::encode),
        };
        answer.ok_or_else(|| {
            LanderError::Temporary(format!("the app rejects the validator state query at {height}"))
        })
    }
    /// As stock CometBFT answers `/validators` at a decided height: the set whose hash the
    /// height's header names as `validators_hash`.
    async fn archive_validators(&self, height: u64) -> Result<Vec<(ConsensusKey, u64)>> {
        let block = self.block(height).await?;
        self.committees
            .values()
            .find(|committee| committee.validators.hash() == block.block.header.validators_hash)
            .map(|committee| committee.members.clone())
            .ok_or_else(|| LanderError::Unavailable(format!("validators of height {height}")))
    }
}
#[async_trait]
impl LandingSource for Fixture {
    async fn snapshot(&self) -> Result<LandingSnapshot> {
        Ok(self.snapshot.clone())
    }
    async fn parent_header(&self, snapshot: &LandingSnapshot) -> Result<ParentContext> {
        Ok(ParentContext {
            header: self.headers[&snapshot.checkpoint_height].clone(),
            // The builder takes the grandparent from `execution_header`, so a fixture without it
            // leaves that read to report it missing.
            grandparent_timestamp: snapshot
                .checkpoint_height
                .checked_sub(1)
                .and_then(|below| self.headers.get(&below))
                .map_or(0, |header| header.timestamp),
        })
    }
    async fn execution_header(&self, number: u64) -> Result<Header> {
        self.headers.get(&number).cloned().ok_or_else(|| {
            LanderError::Unavailable(format!(
                "required execution history height {number} unavailable"
            ))
        })
    }
    async fn parent_anchor(
        &self,
        snapshot: &LandingSnapshot,
        parent: &ParentContext,
    ) -> Result<AnchorState> {
        if parent.header.number == snapshot.checkpoint_height &&
            let Some(anchor) = &self.parent_anchor_override
        {
            return Ok(anchor.clone());
        }
        let number = if parent.header.number == 0 {
            snapshot.genesis.l1_0
        } else {
            let rules::ExtraData { generation, anchor: number, .. } =
                rules::decode_extra_data(&parent.header.extra_data)
                    .map_err(|e| LanderError::Safety(e.to_string()))?;
            if generation != snapshot.generation {
                return Err(LanderError::Safety("anchor generation mismatch".into()));
            }
            number
        };
        let witness = AnchorWitness {
            l1_header: self.l1_headers[&number].clone(),
            inbox: self.states[&number].witness(self.params.inbox, &inbox::anchor_slots()),
        };
        let anchor = abci::l1::verify_anchor_witness(&witness, self.params.inbox)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        if parent.header.number != 0 &&
            parent.header.parent_beacon_block_root != Some(anchor.state_root)
        {
            return Err(LanderError::Safety("parent anchor root mismatch".into()));
        }
        Ok(anchor)
    }
    async fn starting_inbox_witness(&self, anchor: &AnchorState) -> Result<AnchorWitness> {
        let slots = crate::l1::starting_slots(anchor.inbox.recovery_generation);
        let mut witness = self.states[&anchor.number].witness(self.params.inbox, &slots);
        match self.starting_proof_mutation {
            Some(0) => {
                witness.storage.retain(|s| s.slot != inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT))
            }
            Some(1) => {
                if let Some(proof) = witness
                    .storage
                    .iter_mut()
                    .find(|s| s.slot == inbox::slot(inbox::LAST_CHECKPOINT_HASH))
                {
                    proof.value += U256::from(1);
                }
            }
            _ => {}
        }
        Ok(AnchorWitness { l1_header: self.l1_headers[&anchor.number].clone(), inbox: witness })
    }
    /// The served list with hash `hash`, at an L1 block of the fixture's.
    async fn fallback_keys(
        &self,
        hash: B256,
        at: B256,
        at_number: u64,
        _from_block: u64,
    ) -> Result<abci::fallback::FallbackKeys> {
        assert_eq!(self.l1_headers.get(&at_number).map(RawL1Header::hash), Some(at));
        self.fallback_reads.fetch_add(1, Ordering::SeqCst);
        self.fallback_lists
            .get(&hash)
            .cloned()
            .ok_or_else(|| LanderError::Temporary(format!("fallback key list {hash} unavailable")))
    }
    /// The staking proxy's proofs in the L2 post-state of the fixture block with hash
    /// `block_hash`; any other hash is unavailable, as for an L2 that never had the block.
    async fn staking_witness(&self, block_hash: B256, slots: &[B256]) -> Result<AccountWitness> {
        self.headers
            .iter()
            .find(|(_, header)| header.hash_slow() == block_hash)
            .and_then(|(height, _)| self.l2_states.get(height))
            .map(|state| state.witness(self.params.staking, slots))
            .ok_or_else(|| LanderError::Temporary(format!("L2 block {block_hash} unavailable")))
    }
    async fn reference(
        &self,
        _snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> Result<Vec<RawL1Header>> {
        let min = anchors.iter().map(|anchor| anchor.number).min().unwrap();
        Ok((min..self.snapshot.l1_block_number)
            .rev()
            .map(|number| self.l1_headers[&number].clone())
            .collect())
    }
    async fn deployment(&self, _: &LandingSnapshot) -> Result<Deployment> {
        if self.mismatch_statement.load(Ordering::Relaxed) {
            return Err(LanderError::Configuration("deployment configuration mismatch".into()));
        }
        Ok(Deployment { max_batch_blocks: MAX_BATCH_BLOCKS })
    }
    async fn canonical_hash(&self, number: u64) -> Result<B256> {
        Ok(self.l1_headers[&number].hash())
    }
    async fn validate_reference(
        &self,
        snapshot: &LandingSnapshot,
        number: u64,
        hash: B256,
    ) -> Result<()> {
        if number >= snapshot.l1_block_number || self.l1_headers[&number].hash() != hash {
            Err(LanderError::Safety("reference mismatch".into()))
        } else {
            Ok(())
        }
    }
}

#[cfg(test)]
mod readiness {
    use super::*;
    use crate::{
        batch::{BatchBuilder, BatchSource},
        blob, codec,
        types::{Limits, SidecarMode},
    };
    use std::sync::Arc;

    fn limits(blocks: usize) -> Limits {
        Limits {
            max_blocks: blocks,
            max_blobs: 2,
            max_payload_bytes: 240_000,
            max_message_bytes: 200_000,
            max_decompressed_bytes: 2_000_000,
        }
    }

    fn builder(fixture: Arc<Fixture>, limits: Limits) -> BatchBuilder<Fixture, Fixture> {
        BatchBuilder::new(
            fixture.clone(),
            fixture.clone(),
            crate::batch::BatchBuilderConfig {
                params: fixture.params.clone(),
                limits,
                mode: SidecarMode::Eip4844,
                engine: std::sync::Arc::new(test_harness::unavailable_engine::UnavailableEngine),
                engine_timeout: std::time::Duration::from_secs(1),
                max_batch_blocks: MAX_BATCH_BLOCKS,
            },
        )
        .unwrap()
    }

    /// RLP list lengths of the prefixes of `fixture`'s blocks `1..=tip`.
    fn prefix_lists(fixture: &Fixture, limits: &Limits, tip: u64) -> Vec<usize> {
        let mut list = codec::PayloadList::new(limits).unwrap();
        (1..=tip)
            .map(|height| {
                list.push(&fixture.blocks[&height]).unwrap();
                list.list_len()
            })
            .collect()
    }

    /// The longest prefix of blocks `1..=tip` every prefix of which encodes within `limits`'s
    /// payload and blob bounds, found by encoding each candidate prefix in turn.
    fn scan_every_prefix(fixture: &Fixture, limits: &Limits, tip: u64) -> usize {
        let mut blocks = Vec::new();
        for height in 1..=tip {
            blocks.push(fixture.blocks[&height].clone());
            match codec::encode(&blocks, limits) {
                Ok(payload) if blob::required_blobs(payload.len()) <= limits.max_blobs => {}
                _ => return blocks.len() - 1,
            }
        }
        blocks.len()
    }

    fn advance_checkpoint(fixture: &mut Fixture, height: u64) {
        fixture.snapshot.checkpoint_height = height;
        fixture.snapshot.checkpoint_hash = fixture.headers[&height].hash_slow();
        fixture.snapshot.checkpoint_comet_hash =
            B256::from_slice(fixture.blocks[&height].block.header.hash().as_bytes());
        // The current L1 state has advanced while the tip still consumes its older L1 anchor.
        let mut accounts = fixture.states.last_key_value().unwrap().1.accounts.clone();
        let slots = &mut accounts.get_mut(&fixture.params.inbox).unwrap().0;
        slots.insert(inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height));
        slots.insert(
            inbox::slot(inbox::LAST_CHECKPOINT_HASH),
            fixture.snapshot.checkpoint_hash.into(),
        );
        let landing = inbox::landing_record_slots(height);
        slots.insert(landing[0], U256::from(fixture.snapshot.forced_inclusion_head) << 96);
        slots.insert(landing[1], fixture.snapshot.checkpoint_hash.into());
        slots.insert(landing[2], fixture.snapshot.checkpoint_comet_hash.into());
        let state = State::new(
            accounts
                .into_iter()
                .map(|(address, (slots, _))| (address, slots.into_iter().collect()))
                .collect(),
        );
        let number = fixture.snapshot.l1_block_number;
        let raw = l1_header(number, &state, fixture.l1_headers[&(number - 1)].hash());
        fixture.snapshot.l1_block_hash = raw.hash();
        fixture.snapshot.l1_header = raw.clone();
        fixture.snapshot.inbox_witness =
            state.witness(fixture.params.inbox, &crate::l1::snapshot_landing_slots(height));
        fixture.states.insert(number, state);
        fixture.l1_headers.insert(number, raw);
    }

    #[tokio::test]
    async fn no_backlog_has_no_publishable_blocks_or_urgent_flags() {
        for checkpoint in [0, 18] {
            let fixture = Arc::new(Fixture::new(checkpoint, checkpoint));
            let observed =
                builder(fixture.clone(), limits(12)).observe(&fixture.snapshot).await.unwrap();
            assert_eq!(observed.observation.decided_height, checkpoint);
            assert_eq!(observed.observation.publishable_blocks, 0);
            assert!(!observed.observation.force_back_pressure);
        }
    }

    #[tokio::test]
    async fn pressure_uses_tip_authenticated_anchor_instead_of_latest_checkpoint() {
        let mut fixture = Fixture::new(0, 17);
        advance_checkpoint(&mut fixture, 6);
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(12)).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.observation.publishable_blocks, 11);
        // U=20, tip=20, tip anchor CP=1: depth 19 forces publication despite latest CP=19.
        assert!(observed.observation.force_back_pressure);
    }

    #[tokio::test]
    async fn pressure_below_unsettled_limit_minus_one_allows_waiting() {
        let mut fixture = Fixture::new(0, 16);
        advance_checkpoint(&mut fixture, 6);
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(12)).observe(&fixture.snapshot).await.unwrap();
        // U=20, tip=19, tip anchor CP=1: depth 18 stays below the urgent threshold.
        assert_eq!(observed.observation.decided_height, 16);
        assert_eq!(observed.observation.publishable_blocks, 10);
        assert!(!observed.observation.force_back_pressure);
    }

    /// A prefix the blob bound cuts to one block lands that one block, without back-pressure.
    #[tokio::test]
    async fn a_one_block_prefix_lands_without_pressure() {
        let fixture = Arc::new(Fixture::with_calldata(18, 30, 70_000));
        let mut bound = limits(6);
        bound.max_blobs = 1;
        let observed = builder(fixture.clone(), bound).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.observation.decided_height, 30);
        assert_eq!(observed.observation.publishable_blocks, 1);
        assert!(!observed.observation.force_back_pressure); // The tip anchor CP=18 gives depth 12 < 17.
        let request = builder(fixture.clone(), bound)
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .expect("the single block above the checkpoint lands");
        assert_eq!(request.batch.blocks.len(), 1);
        assert!(request.batch.leaves.is_empty());
    }

    #[tokio::test]
    async fn observation_counts_the_same_blob_and_codec_bounded_prefix_as_prepare() {
        let fixture = Arc::new(Fixture::with_calldata(0, 12, 70_000));
        let mut bound = limits(12);
        bound.max_blobs = 1;
        let observed = builder(fixture.clone(), bound).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.observation.publishable_blocks, 1);
        let request = builder(fixture.clone(), bound)
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .expect("one block fits one blob");
        assert_eq!(request.batch.blocks.len(), 1);
        let first = codec::encode(&[fixture.blocks[&1].clone()], &bound).unwrap();
        assert_eq!(blob::required_blobs(first.len()), 1);
        bound.max_payload_bytes = first.len() - 1;
        assert!(matches!(
            builder(fixture.clone(), bound).observe(&fixture.snapshot).await,
            Err(LanderError::Capacity(_))
        ));
        bound = limits(12);
        bound.max_blocks = 2;
        assert_eq!(
            builder(fixture.clone(), bound)
                .observe(&fixture.snapshot)
                .await
                .unwrap()
                .observation
                .publishable_blocks,
            2
        );
        bound.max_message_bytes = 1;
        assert!(matches!(
            builder(fixture.clone(), bound).observe(&fixture.snapshot).await,
            Err(LanderError::Capacity(_))
        ));
    }

    /// Below the selection budgets, the incremental selection equals encoding every candidate
    /// prefix, whether a prefix is accepted by its worst-case bound or by deflating it.
    #[tokio::test]
    async fn selection_within_budgets_matches_encoding_every_prefix() {
        for fixture in [
            Fixture::new(0, 12),
            Fixture::with_calldata(0, 12, 70_000),
            Fixture::with_zero_calldata(0, 12, 120_000),
        ] {
            let fixture = Arc::new(fixture);
            for (max_blobs, max_payload_bytes) in [(1, 240_000), (2, 240_000), (2, 140_000)] {
                let bound = Limits { max_blobs, max_payload_bytes, ..limits(12) };
                let expected = scan_every_prefix(&fixture, &bound, 12);
                let observed = builder(fixture.clone(), bound).observe(&fixture.snapshot).await;
                if expected == 0 {
                    assert!(matches!(observed, Err(LanderError::Capacity(_))), "{bound:?}");
                } else {
                    assert_eq!(
                        observed.unwrap().observation.publishable_blocks,
                        expected,
                        "{bound:?}"
                    );
                }
            }
        }
    }

    #[tokio::test]
    async fn selection_stops_at_the_list_budget() {
        let fixture = Arc::new(Fixture::with_zero_calldata(0, 12, 120_000));
        let bound = Limits { max_blobs: 1, ..limits(12) };
        let lists = prefix_lists(&fixture, &bound, 12);
        for (budget, expected) in [
            (usize::MAX, 12),
            (lists[11], 12),
            (lists[11] - 1, 11),
            (lists[5], 6),
            (lists[5] - 1, 5),
            (lists[0], 1),
        ] {
            let observed = builder(fixture.clone(), bound)
                .with_selection_budgets(budget, usize::MAX)
                .observe(&fixture.snapshot)
                .await
                .unwrap();
            assert_eq!(observed.observation.publishable_blocks, expected, "list budget {budget}");
        }
        let error = builder(fixture.clone(), bound)
            .with_selection_budgets(lists[0] - 1, usize::MAX)
            .observe(&fixture.snapshot)
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Capacity(_)), "{error}");
        assert!(error.to_string().contains("block 1"), "{error}");
        let request = builder(fixture.clone(), bound)
            .with_selection_budgets(lists[5], usize::MAX)
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(request.batch.blocks.len(), 6);
        let payload = blob::decode(request.batch.blobs.sidecar.blobs(), &bound).unwrap();
        assert_eq!(
            codec::decode(&payload, &bound).unwrap(),
            request
                .batch
                .blocks
                .iter()
                .map(|pair| codec::PublishedBlock::try_from(pair).unwrap())
                .collect::<Vec<_>>()
        );
    }

    #[tokio::test]
    async fn selection_stops_at_the_deflate_budget() {
        // Every prefix of these blocks exceeds one blob uncompressed, so each is deflated.
        let fixture = Arc::new(Fixture::with_zero_calldata(0, 12, 120_000));
        let bound = Limits { max_blobs: 1, ..limits(12) };
        let lists = prefix_lists(&fixture, &bound, 12);
        assert!(codec::payload_bound(lists[1]) > blob::PAYLOAD_BYTES_PER_BLOB);
        let six: usize = lists[1..6].iter().sum();
        let twelve: usize = lists[1..].iter().sum();
        for (budget, expected) in
            [(0, 1), (six - 1, 5), (six, 6), (twelve - 1, 11), (twelve, 12), (usize::MAX, 12)]
        {
            let observed = builder(fixture.clone(), bound)
                .with_selection_budgets(usize::MAX, budget)
                .observe(&fixture.snapshot)
                .await
                .unwrap();
            assert_eq!(
                observed.observation.publishable_blocks, expected,
                "deflate budget {budget}"
            );
        }
        // Prefixes whose worst-case payload fits are accepted without deflating anything.
        let fixture = Arc::new(Fixture::with_calldata(0, 12, 10_000));
        let lists = prefix_lists(&fixture, &limits(12), 12);
        assert!(codec::payload_bound(lists[11]) <= limits(12).max_payload_bytes);
        let observed = builder(fixture.clone(), limits(12))
            .with_selection_budgets(usize::MAX, 0)
            .observe(&fixture.snapshot)
            .await
            .unwrap();
        assert_eq!(observed.observation.publishable_blocks, 12);
        let b = builder(fixture.clone(), bound).with_selection_budgets(usize::MAX, twelve);
        let preview = b.observe(&fixture.snapshot).await.unwrap();
        let observed =
            b.prepare_observed(fixture.snapshot.clone(), preview).await.unwrap().unwrap();
        let independent = b.prepare(fixture.snapshot.clone()).await.unwrap().unwrap();
        assert_eq!(observed, independent);
    }

    /// A malformed body or an unsigned certificate past the selected prefix leaves observation
    /// to succeed, and preparation refuses it once its batch reaches it. An undecodable block
    /// above the newest anchor witness counts pressure from the checkpoint's anchor (CP=6, depth
    /// 24); a block that decodes keeps the tip's anchor at block 23 (CP=18, depth 12).
    #[tokio::test]
    async fn tip_body_and_certificate_beyond_the_prefix_are_left_to_preparation() {
        let mut malformed = Fixture::new(18, 30);
        malformed.blocks.get_mut(&26).unwrap().block.data[0].push(0);
        let mut unsigned = Fixture::new(18, 30);
        unsigned
            .blocks
            .get_mut(&26)
            .unwrap()
            .commit
            .signatures
            .fill(crate::native::CommitSig::BlockIdFlagAbsent);
        for (fixture, pressure) in [(malformed, true), (unsigned, false)] {
            let fixture = Arc::new(fixture);
            let observed =
                builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await.unwrap();
            assert_eq!(observed.observation.publishable_blocks, 1);
            assert_eq!(observed.observation.force_back_pressure, pressure);
            assert!(matches!(
                builder(fixture.clone(), limits(12)).prepare(fixture.snapshot.clone()).await,
                Err(LanderError::Safety(_))
            ));
        }
    }

    #[tokio::test]
    async fn observation_rejects_certified_rpc_block_from_another_height() {
        let mut fixture = Fixture::new(18, 30);
        fixture.blocks.insert(19, fixture.blocks[&20].clone());
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
        assert!(matches!(
            builder(fixture.clone(), limits(1)).prepare(fixture.snapshot.clone()).await,
            Err(LanderError::Safety(_))
        ));
    }

    #[tokio::test]
    async fn pressure_rejects_anchor_mpt_root_that_differs_from_certified_tip() {
        let mut fixture = Fixture::new(18, 24);
        advance_checkpoint(&mut fixture, 18);
        let state = fixture.states[&10].clone();
        fixture.states.insert(11, state.clone());
        fixture.l1_headers.insert(11, l1_header(11, &state, fixture.l1_headers[&10].hash()));
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(12)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
    }
}

/// Exercises the former settlement-size boundary through the signature verifier: 301 members at
/// unit power, more than any signing set now holds, still certify with 201 commits, not 200.
#[test]
fn authenticates_301_unit_power_members_through_comet_certificate() {
    use super::consensus::{committee, pair};
    use crate::{
        native::CommitSig,
        validate::{ValidationError, verify_commit},
    };
    use std::collections::BTreeSet;

    const COUNT: usize = 301;
    const CHAIN_ID: &str = "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4";
    let (_, authenticated, keys) = committee(&[1; COUNT]);
    assert_eq!(keys.len(), COUNT);
    assert_eq!(authenticated.validators.validators().len(), COUNT);
    assert_eq!(authenticated.validators.total_voting_power(), 301);

    let mut block = pair(1, B256::ZERO, &authenticated, &keys, None);
    assert_eq!(block.commit.signatures.len(), COUNT);
    let signer_addresses = block
        .commit
        .signatures
        .iter()
        .map(|signature| match signature {
            CommitSig::BlockIdFlagCommit { validator_address, signature: Some(_), .. } => {
                *validator_address
            }
            _ => panic!("every member must supply a real commit signature"),
        })
        .collect::<BTreeSet<_>>();
    assert_eq!(signer_addresses.len(), COUNT);
    verify_commit(&block.commit, &block.block.header, &authenticated.validators, CHAIN_ID).unwrap();
    // With unit power, 201/301 is just above 2/3; 200/301 is below it.
    block.commit.signatures[201..].fill(CommitSig::BlockIdFlagAbsent);
    verify_commit(&block.commit, &block.block.header, &authenticated.validators, CHAIN_ID).unwrap();
    block.commit.signatures[200] = CommitSig::BlockIdFlagAbsent;
    assert!(matches!(
        verify_commit(&block.commit, &block.block.header, &authenticated.validators, CHAIN_ID),
        Err(ValidationError::Certificate(message)) if message.contains("insufficient commit power 200/301")
    ));
}

#[path = "recovery.rs"]
pub(crate) mod recovery;

/// Make the import metadata using the fixture's actual own-L1 genesis witnesses and landed state.
pub(crate) async fn import_package(
    fx: &Fixture,
    height: u64,
) -> crate::checkpoint_import::ImportPackage {
    use crate::checkpoint_import::ImportPackage;
    use abci::GenesisDoc;
    let witness = abci::GenesisWitness {
        l1_header: fx.l1_headers[&fx.snapshot.genesis.l1_0].clone(),
        inbox: fx.import_witness(
            fx.params.inbox,
            &abci::l1::layout::inbox::genesis_slots(),
            fx.snapshot.genesis.l1_0,
        ),
    };
    let validators = fx.origin_keys.validator_set();
    let genesis = GenesisDoc {
        genesis_time: tendermint::Time::from_unix_timestamp(
            witness.l1_header.timestamp() as i64,
            0,
        )
        .unwrap()
        .to_rfc3339(),
        chain_id: abci::rules::chain_id_for(&fx.params, 0).unwrap(),
        initial_height: "1".into(),
        consensus_params: abci::genesis::GenesisConsensusParams::etna(),
        validators: validators
            .iter()
            .map(|(key, power)| abci::genesis::GenesisValidator::new(*key, *power))
            .collect(),
        app_hash: abci::genesis::genesis_app_hash(0, fx.snapshot.genesis.genesis_hash, &validators)
            .unwrap(),
        app_state: abci::genesis::AppStateJson::from(&witness),
    };
    ImportPackage {
        schema: crate::checkpoint_import::IMPORT_SCHEMA,
        genesis,
        checkpoint_height: height,
        origin_header: Some(fx.headers[&0].clone()),
        recovery_bootstrap: None,
        boundary_header: None,
        // The preimage for s - 1 that header(s)'s app_hash commits (DATA-5.4-3).
        validator_state: if height == 0 {
            Bytes::new()
        } else {
            fx.val_states[&(height - 1)].encode().into()
        },
        execution_headers: vec![],
    }
}

#[cfg(test)]
#[path = "import_resources.rs"]
mod import_resources;
