//! Genuine trie/proof and epoch-changing fixtures for immutable batch assembly.

use super::consensus::{pair_with_envelope, parameters};
use crate::{
    batch::verify_reference_chain,
    comet::{CometSource, CometStatus},
    committee::{AuthenticatedCommittee, authenticate},
    contracts::IEtnaInbox::LandInput,
    error::{LanderError, Result},
    l1::{LandingSource, ParentContext},
    statement,
    types::{CertifiedBlock, LandingSnapshot},
};
use abci::{
    AccountWitness, AnchorState, AnchorWitness, ChainParams, CommitteeState, CommitteeWitness,
    EtnaEnvelope, ExecutionBlock, ForcedWitness, GenesisRecord, InboxFacts, ParentInfo,
    RawL1Header, RegistryEntry, Schedule, StorageProof,
    committee::{
        Snapshot, committee_config_hash, derive, entries_root, record_hash, snapshot_slots,
    },
    forced::ForcedEntry,
    l1::layout::{inbox, registry},
    rules::{self, HeaderInputs},
};
use alloy_consensus::{EMPTY_OMMER_ROOT_HASH, EMPTY_ROOT_HASH, Header};
use alloy_eips::eip7685::EMPTY_REQUESTS_HASH;
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};
use async_trait::async_trait;
use ed25519_dalek::SigningKey;
use std::{
    collections::BTreeMap,
    sync::atomic::{AtomicBool, Ordering},
};

#[derive(Clone)]
struct State {
    accounts: BTreeMap<Address, (BTreeMap<B256, U256>, B256)>,
    root: B256,
}

fn trie(leaves: BTreeMap<B256, Vec<u8>>, targets: Vec<Nibbles>) -> (B256, ProofNodes) {
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(targets));
    for (key, value) in leaves {
        builder.add_leaf(Nibbles::unpack(key), &value);
    }
    let root = builder.root();
    (root, builder.take_proof_nodes())
}
/// `len` pseudorandom nonzero calldata bytes seeded by `height`, which payload V5's zlib cannot
/// shrink, so block sizes keep counting blobs.
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
    fn new(accounts: Vec<(Address, Vec<(B256, U256)>)>) -> Self {
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
    fn witness(&self, address: Address, slots: &[B256]) -> AccountWitness {
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

/// The fee recipient the test builders name in every batch's `LandInput`.
pub const FEE_RECIPIENT: Address = Address::repeat_byte(0xfe);

pub struct Fixture {
    pub params: ChainParams,
    pub snapshot: LandingSnapshot,
    pub blocks: BTreeMap<u64, CertifiedBlock>,
    pub committees: BTreeMap<u64, AuthenticatedCommittee>,
    pub anchors: BTreeMap<u64, AnchorState>,
    pub headers: BTreeMap<u64, Header>,
    pub l1_headers: BTreeMap<u64, RawL1Header>,
    pub mismatch_statement: AtomicBool,
    pub reject_committee_hints: bool,
    pub witness_mutation: Option<u8>,
    pub starting_proof_mutation: Option<u8>,
    pub parent_anchor_override: Option<AnchorState>,
    states: BTreeMap<u64, State>,
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

/// The fixture's L1 state: the Inbox with last checkpoint `(height, hash)`, the genesis record
/// `genesis` and the forced inclusion queue `queue` (slots 280–281), and the registry holding
/// `entries`.
fn state_with_queue(
    params: &ChainParams,
    entries: &[RegistryEntry],
    height: u64,
    hash: B256,
    committees: &BTreeMap<u64, AuthenticatedCommittee>,
    genesis: &GenesisRecord,
    queue: &Queue,
) -> State {
    let mut slots = vec![
        (inbox::slot(inbox::STATUS), U256::from(3)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HASH), hash.into()),
        (
            inbox::slot(inbox::GENESIS_COMMITTEE_HASH),
            record_hash(params.l2_chain_id, &committees[&0].state.record).into(),
        ),
    ];
    slots.extend([
        (inbox::slot(inbox::COMMITTEE_CONFIG_HASH), genesis.committee_config_hash.into()),
        (
            inbox::slot(inbox::GENESIS_PACKED),
            U256::from(genesis.l1_0) << 64 |
                U256::from(genesis.epoch_len) << 128 |
                U256::from(genesis.epoch_len_l1) << 192,
        ),
        (inbox::slot(inbox::GENESIS_BLOCK_HASH), genesis.genesis_hash.into()),
        (inbox::slot(inbox::GENESIS_STATE_ROOT), genesis.genesis_state_root.into()),
        (inbox::slot(inbox::GENESIS_CUTOFF), U256::from(genesis.genesis_cutoff)),
        (
            inbox::slot(inbox::FORCED_INCLUSION_CONFIG),
            U256::from(genesis.forced_inclusion_delay) | U256::from(genesis.max_anchor_age) << 64,
        ),
        (
            inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL),
            U256::from(queue.head) | U256::from(queue.tail) << 48,
        ),
    ]);
    for entry in &queue.entries {
        let [hash, metadata] = inbox::forced_inclusion_entry_slots(entry.index);
        slots.extend([
            (hash, entry.tx_hash.into()),
            (
                metadata,
                U256::from(entry.timestamp) |
                    (U256::from(entry.l1_block) << 48) |
                    (U256::from(1_000 + entry.index) << 112),
            ),
        ]);
    }
    let checkpoint = registry::checkpoint_slots(0);
    State::new(vec![
        (params.inbox, slots),
        (
            params.registry,
            vec![
                (registry::length_slot(), U256::from(1)),
                (checkpoint[0], U256::from(1) | (U256::from(entries.len()) << 64)),
                (checkpoint[1], entries_root(entries).into()),
            ],
        ),
    ])
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
        TxLegacy { nonce: index, gas_limit: 21_000, ..Default::default() }
            .into_signed(alloy_primitives::Signature::new(U256::from(1), U256::from(1), false)),
    )
    .encoded_2718()
    .into();
    let hash = keccak256(&tx);
    (tx, hash)
}

fn anchor(raw: &RawL1Header, height: u64, hash: B256, queue: &Queue) -> AnchorState {
    AnchorState {
        number: raw.number(),
        hash: raw.hash(),
        state_root: raw.state_root(),
        timestamp: raw.timestamp(),
        inbox: InboxFacts {
            status: 3,
            recovery_generation: 0,
            last_checkpoint_height: height,
            last_checkpoint_hash: hash,
            forced_inclusion_head: queue.head,
            forced_inclusion_tail: queue.tail,
        },
    }
}

impl Fixture {
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
            &self.registry_entries(),
            self.snapshot.checkpoint_height,
            self.snapshot.checkpoint_hash,
            &self.committees,
            &genesis,
            &Queue { head, tail, entries: Vec::new() },
        );
        let number = self.snapshot.l1_block_number;
        let header = l1_header(number, &state, self.l1_headers[&(number - 1)].hash());
        LandingSnapshot {
            l1_block_hash: header.hash(),
            forced_inclusion_head: head,
            forced_inclusion_tail: tail,
            inbox_witness: state.witness(self.params.inbox, &crate::l1::snapshot_slots()),
            l1_header: header,
            genesis,
            ..self.snapshot.clone()
        }
    }

    fn registry_entries(&self) -> Vec<RegistryEntry> {
        [1u8, 2]
            .into_iter()
            .enumerate()
            .map(|(index, seed)| RegistryEntry {
                reward_recipient: super::consensus::member_recipient(B256::from(
                    SigningKey::from_bytes(&[seed; 32]).verifying_key().to_bytes(),
                )),
                pubkey: B256::from(SigningKey::from_bytes(&[seed; 32]).verifying_key().to_bytes()),
                eff_stake: U256::from(if index == 0 { 3 } else { 1 }),
                active_from_l1: if index == 0 { 1 } else { 10 },
                exit_effective_l1: u64::MAX,
                last_heartbeat_at: 1,
                last_heartbeat_seq: 1,
            })
            .collect()
    }
    pub fn new(checkpoint: u64, tip: u64) -> Self {
        Self::with_calldata(checkpoint, tip, 0)
    }

    fn with_calldata(checkpoint: u64, tip: u64, bytes: usize) -> Self {
        Self::with_epoch(checkpoint, tip, bytes, 23)
    }

    /// As [`Fixture::with_calldata`], with all-zero calldata that payload V4 compresses to almost
    /// nothing.
    fn with_zero_calldata(checkpoint: u64, tip: u64, bytes: usize) -> Self {
        Self::build(checkpoint, tip, bytes, true, 23, 7_200, &ForcedPlan::default())
    }

    pub fn with_epoch(checkpoint: u64, tip: u64, bytes: usize, epoch_len: u64) -> Self {
        Self::build(checkpoint, tip, bytes, false, epoch_len, 7_200, &ForcedPlan::default())
    }

    /// As [`Fixture::new`], with the forced inclusion entries and blocks of `plan`. Anchor `n` is
    /// at `n` s: L1 10 anchors every block of a genesis checkpoint; otherwise block 1 uses 10,
    /// blocks 2 to 21 use 11 and blocks 22 (the switch height of epoch 1) onwards use 12.
    pub fn with_forced(checkpoint: u64, tip: u64, plan: ForcedPlan) -> Self {
        Self::build(checkpoint, tip, 0, false, 23, 7_200, &plan)
    }

    /// As [`Fixture::new`], with the genesis `maxAnchorAge` set to `max_anchor_age` seconds.
    /// Block `h` is at `100 + h` s and anchor `n` at `n` s, so the blocks of a genesis
    /// checkpoint (all anchored at 10) are `90 + h` s younger than their anchor.
    pub fn with_max_anchor_age(checkpoint: u64, tip: u64, max_anchor_age: u64) -> Self {
        Self::build(checkpoint, tip, 0, false, 23, max_anchor_age, &ForcedPlan::default())
    }

    /// Builds the decided chain up to `tip` over the genesis `maxAnchorAge` `max_anchor_age` and
    /// the forced inclusion entries and blocks of `plan`; each block carries one transaction
    /// with `bytes` of calldata (zeros if `zeros`) unless zero.
    fn build(
        checkpoint: u64,
        tip: u64,
        bytes: usize,
        zeros: bool,
        epoch_len: u64,
        max_anchor_age: u64,
        plan: &ForcedPlan,
    ) -> Self {
        assert!(checkpoint == 0 || checkpoint >= epoch_len - 3);
        let mut params = parameters();
        params.d_max = epoch_len - 3;
        let genesis_header = Header {
            number: 0,
            state_root: B256::repeat_byte(7),
            timestamp: 100,
            gas_limit: params.block_gas_limit,
            base_fee_per_gas: Some(1_000_000),
            ..Default::default()
        };
        let genesis = GenesisRecord {
            committee_config_hash: committee_config_hash(&params),
            genesis_height: 0,
            l1_0: 10,
            epoch_len,
            epoch_len_l1: 1,
            genesis_cutoff: 1,
            genesis_hash: genesis_header.hash_slow(),
            genesis_state_root: genesis_header.state_root,
            forced_inclusion_delay: plan.delay,
            max_anchor_age,
        };
        let schedule = Schedule::from_genesis(&genesis);
        let keys = vec![SigningKey::from_bytes(&[1; 32]), SigningKey::from_bytes(&[2; 32])];
        let entries = keys
            .iter()
            .enumerate()
            .map(|(index, key)| RegistryEntry {
                reward_recipient: super::consensus::member_recipient(B256::from(
                    key.verifying_key().to_bytes(),
                )),
                pubkey: B256::from(key.verifying_key().to_bytes()),
                eff_stake: U256::from(if index == 0 { 3 } else { 1 }),
                active_from_l1: if index == 0 { 1 } else { 10 },
                exit_effective_l1: u64::MAX,
                last_heartbeat_at: 1,
                last_heartbeat_seq: 1,
            })
            .collect::<Vec<_>>();
        let snapshot = Snapshot { checkpoint_index: 0, l1_block: 1, entries: entries.clone() };
        let mut committees = BTreeMap::new();
        for epoch in 0..=3 {
            let cutoff = if epoch == 0 {
                genesis.genesis_cutoff
            } else if epoch == 1 {
                11
            } else {
                12
            };
            let (record, members) = derive(&snapshot, cutoff, epoch, &schedule, &params).unwrap();
            let hash = record_hash(params.l2_chain_id, &record);
            committees.insert(
                epoch,
                authenticate(CommitteeState { record, members }, epoch, hash, &params).unwrap(),
            );
        }
        let planted = plan.planted();
        let genesis_state = state_with_queue(
            &params,
            &entries,
            0,
            genesis.genesis_hash,
            &committees,
            &genesis,
            &plan.queue(&planted, 10, 0),
        );
        let raw10 = l1_header(10, &genesis_state, B256::repeat_byte(9));
        let anchor10 = anchor(&raw10, 0, genesis.genesis_hash, &plan.queue(&planted, 10, 0));
        let mut cursor = 0;
        let mut states = BTreeMap::from([(10, genesis_state)]);
        let mut l1_headers = BTreeMap::from([(10, raw10)]);
        let mut anchors = BTreeMap::from([(0, anchor10.clone())]);
        let mut headers = BTreeMap::from([(0, genesis_header)]);
        let mut blocks = BTreeMap::new();
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
            if checkpoint > 0 && height == 2 {
                let s = state_with_queue(
                    &params,
                    &entries,
                    1,
                    parent.hash,
                    &committees,
                    &genesis,
                    &plan.queue(&planted, 11, 1),
                );
                let raw = l1_header(11, &s, l1_headers[&10].hash());
                states.insert(11, s);
                l1_headers.insert(11, raw);
            }
            if checkpoint > 0 && height == epoch_len - 1 {
                let s = state_with_queue(
                    &params,
                    &entries,
                    epoch_len - 3,
                    headers[&(epoch_len - 3)].hash_slow(),
                    &committees,
                    &genesis,
                    &plan.queue(&planted, 12, epoch_len - 3),
                );
                let raw = l1_header(12, &s, l1_headers[&11].hash());
                states.insert(12, s);
                l1_headers.insert(12, raw);
            }
            let number = if checkpoint == 0 || height == 1 {
                10
            } else if height < epoch_len - 1 {
                11
            } else {
                12
            };
            let cp = if number == 10 {
                0
            } else if number == 11 {
                1
            } else {
                epoch_len - 3
            };
            let cp_hash = headers[&cp].hash_slow();
            let forced = height == 1;
            let changing = anchors[&(height - 1)].number != number;
            let raw = &l1_headers[&number];
            let a = anchor(raw, cp, cp_hash, &plan.queue(&planted, number, cp));
            let witness = (forced || changing).then(|| AnchorWitness {
                l1_header: raw.clone(),
                inbox: states[&number].witness(params.inbox, &inbox::anchor_slots()),
            });
            let committee = schedule.switch_target(height).map(|target| {
                let parent_anchor = &anchors[&(height - 1)];
                CommitteeWitness {
                    record: committees[&target].state.record.clone(),
                    registry: states[&parent_anchor.number]
                        .witness(params.registry, &snapshot_slots(0, false)),
                    entries: entries.clone(),
                }
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
                reward_recipient: rules::proposer_recipient(
                    &committees[&schedule.epoch_of(height)].state.members,
                    committees[&schedule.epoch_of(height)].validators.validators()[0].address,
                )
                .unwrap(),
                parent: &parent,
                anchor: &a,
                bft_time_secs: if max_anchor_age < 7200 { 1261 + height } else { 100 + height },
                generation: 0,
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
                    to: alloy_primitives::TxKind::Call(params.fee_vault),
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
                state_root: B256::from(U256::from(height + 100)),
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
                    committee,
                    forced: witness_forced,
                },
                &committees[&schedule.epoch_of(height)],
                &keys,
                blocks.get(&(height - 1)),
            );
            if max_anchor_age < 7200 {
                pair.block.header.time =
                    tendermint::Time::from_unix_timestamp((1261 + height) as i64, 0).unwrap();
            }
            pair.block.header.next_validators_hash =
                committees[&schedule.epoch_of(height + 1)].validators.hash();
            super::consensus::resign(&mut pair, &committees[&schedule.epoch_of(height)], &keys);
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
        for number in last + 1..=15 {
            let raw = l1_header(number, &root_state, l1_headers[&(number - 1)].hash());
            l1_headers.insert(number, raw);
        }
        let snapshot_queue = plan.queue(&planted, 15, checkpoint);
        let snapshot_state = state_with_queue(
            &params,
            &entries,
            checkpoint,
            headers[&checkpoint].hash_slow(),
            &committees,
            &genesis,
            &snapshot_queue,
        );
        let snapshot_header = l1_header(15, &snapshot_state, l1_headers[&14].hash());
        l1_headers.insert(15, snapshot_header.clone());
        let landing = LandingSnapshot {
            l1_block_hash: snapshot_header.hash(),
            l1_block_number: 15,
            l1_chain_id: U256::from(1),
            l2_chain_id: params.l2_chain_id,
            inbox: params.inbox,
            registry: params.registry,
            generation: 0,
            checkpoint_height: checkpoint,
            checkpoint_hash: headers[&checkpoint].hash_slow(),
            forced_inclusion_head: snapshot_queue.head,
            forced_inclusion_tail: snapshot_queue.tail,
            committee_config_hash: genesis.committee_config_hash,
            genesis_committee_record_hash: record_hash(
                params.l2_chain_id,
                &committees[&0].state.record,
            ),
            l1_header: snapshot_header,
            inbox_witness: snapshot_state.witness(params.inbox, &crate::l1::snapshot_slots()),
            genesis,
        };
        Self {
            params,
            snapshot: landing,
            blocks,
            committees,
            anchors,
            headers,
            l1_headers,
            mismatch_statement: AtomicBool::new(false),
            reject_committee_hints: false,
            witness_mutation: None,
            starting_proof_mutation: None,
            parent_anchor_override: None,
            states,
        }
    }
}

#[async_trait]
impl CometSource for Fixture {
    async fn status(&self) -> Result<CometStatus> {
        Ok(CometStatus {
            chain_id: rules::chain_id_for(self.params.l2_chain_id, 0),
            height: *self.headers.last_key_value().unwrap().0,
        })
    }
    async fn block(&self, height: u64) -> Result<CertifiedBlock> {
        self.blocks
            .get(&height)
            .cloned()
            .ok_or_else(|| LanderError::Unavailable(format!("height {height} pruned")))
    }
    async fn committee(&self, epoch: u64) -> Result<CommitteeState> {
        assert!(!self.reject_committee_hints, "a Comet committee hint cannot be authority");
        self.committees
            .get(&epoch)
            .map(|committee| committee.state.clone())
            .ok_or_else(|| LanderError::Unavailable(format!("committee epoch {epoch}")))
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
            grandparent_timestamp: if snapshot.checkpoint_height == 0 {
                0
            } else {
                self.headers[&(snapshot.checkpoint_height - 1)].timestamp
            },
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
        if let Some(anchor) = &self.parent_anchor_override {
            return Ok(anchor.clone());
        }
        let number = if parent.header.number == 0 {
            snapshot.genesis.l1_0
        } else {
            let (_, generation, number) = rules::decode_extra_data(&parent.header.extra_data)
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
        let mut witness =
            self.states[&anchor.number].witness(self.params.inbox, &crate::l1::snapshot_slots());
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
    async fn committee_witness(
        &self,
        _: &LandingSnapshot,
        anchor: &AnchorState,
        _snapshot_number: u64,
        epoch: u64,
    ) -> Result<CommitteeWitness> {
        let mut witness = CommitteeWitness {
            record: self.committees[&epoch].state.record.clone(),
            registry: self.states[&anchor.number]
                .witness(self.params.registry, &snapshot_slots(0, false)),
            entries: self.registry_entries(),
        };
        match self.witness_mutation {
            Some(0) => witness.registry.address = Address::ZERO,
            Some(1) => witness.registry.storage_root = B256::ZERO,
            Some(2) => witness.entries[0].eff_stake += U256::from(1),
            Some(3) => witness.record.cutoff_l1_block += 1,
            _ => {}
        }
        Ok(witness)
    }
    async fn reference(
        &self,
        _snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> Result<Vec<RawL1Header>> {
        let min = anchors.iter().map(|anchor| anchor.number).min().unwrap();
        let headers =
            (min..=14).rev().map(|number| self.l1_headers[&number].clone()).collect::<Vec<_>>();
        verify_reference_chain(&headers, anchors)?;
        Ok(headers)
    }
    async fn statement_hash(
        &self,
        snapshot: &LandingSnapshot,
        input: &LandInput,
        reference: B256,
        blobs: &[B256],
    ) -> Result<B256> {
        Ok(if self.mismatch_statement.load(Ordering::Relaxed) {
            B256::ZERO
        } else {
            statement::hash(snapshot, input, reference, blobs)
        })
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
                fee_recipient: FEE_RECIPIENT,
                l2_reward_recipient: crate::test_utils::consensus::BATCH_RECIPIENT,
                engine: std::sync::Arc::new(test_harness::unavailable_engine::UnavailableEngine),
                engine_timeout: std::time::Duration::from_secs(1),
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
        // The current L1 state has advanced while the tip still consumes its older L1 anchor.
        let mut accounts = fixture.states.last_key_value().unwrap().1.accounts.clone();
        let slots = &mut accounts.get_mut(&fixture.params.inbox).unwrap().0;
        slots.insert(inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height));
        slots.insert(
            inbox::slot(inbox::LAST_CHECKPOINT_HASH),
            fixture.snapshot.checkpoint_hash.into(),
        );
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
            state.witness(fixture.params.inbox, &crate::l1::snapshot_slots());
        fixture.states.insert(number, state);
        fixture.l1_headers.insert(number, raw);
    }

    #[tokio::test]
    async fn no_backlog_has_no_publishable_blocks_or_urgent_flags() {
        for checkpoint in [0, 20] {
            let fixture = Arc::new(Fixture::new(checkpoint, checkpoint));
            let observed =
                builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await.unwrap();
            assert_eq!(observed.decided_height, checkpoint);
            assert_eq!(observed.publishable_blocks, 0);
            assert!(!observed.force_backpressure);
            assert!(!observed.force_epoch);
        }
    }

    #[tokio::test]
    async fn epoch_first_height_has_no_publication_urgency() {
        let mut fixture = Fixture::new(0, 3);
        fixture.l1_headers.remove(&14);
        fixture.mismatch_statement.store(true, Ordering::Relaxed);
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.decided_height, 3);
        assert_eq!(observed.publishable_blocks, 3);
        assert!(!observed.force_backpressure);
        assert!(!observed.force_epoch);
    }

    #[tokio::test]
    async fn pressure_uses_tip_authenticated_anchor_instead_of_latest_checkpoint() {
        let mut fixture = Fixture::new(20, 20);
        advance_checkpoint(&mut fixture, 19);
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.publishable_blocks, 1);
        // U=20, tip=20, tip anchor CP=1: depth 19 forces publication despite latest CP=19.
        assert!(observed.force_backpressure);
        assert!(!observed.force_epoch);
    }

    #[tokio::test]
    async fn pressure_below_unsettled_cap_minus_one_allows_waiting() {
        let mut fixture = Fixture::new(20, 20);
        fixture.blocks.remove(&20);
        fixture.headers.remove(&20);
        advance_checkpoint(&mut fixture, 18);
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await.unwrap();
        // U=20, tip=19, tip anchor CP=1: depth 18 stays below the urgent threshold.
        assert_eq!(observed.decided_height, 19);
        assert_eq!(observed.publishable_blocks, 1);
        assert!(!observed.force_backpressure);
        assert!(!observed.force_epoch);
    }

    #[tokio::test]
    async fn epoch_first_height_outside_blob_prefix_forces_publication_without_pressure() {
        let fixture = Arc::new(Fixture::with_calldata(20, 26, 70_000));
        let mut bound = limits(6);
        bound.max_blobs = 1;
        let observed = builder(fixture.clone(), bound).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.decided_height, 26);
        assert_eq!(observed.publishable_blocks, 1);
        assert!(observed.force_epoch); // h_first(1)=24 is beyond the single-block prefix at 21.
        assert!(!observed.force_backpressure); // The tip anchor CP=20 gives depth 6 < 19.
        let request = builder(fixture.clone(), bound)
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(request.batch.input.lastHeight, 21);
    }

    #[tokio::test]
    async fn observation_counts_the_same_blob_and_codec_bounded_prefix_as_prepare() {
        let fixture = Arc::new(Fixture::with_calldata(0, 3, 70_000));
        let mut bound = limits(3);
        bound.max_blobs = 1;
        let observed = builder(fixture.clone(), bound).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.publishable_blocks, 1);
        let first = codec::encode(&[fixture.blocks[&1].clone()], &bound).unwrap();
        assert_eq!(blob::required_blobs(first.len()), 1);
        let list = abci::compression::zlib_inflate_exact(&first[1..], usize::MAX).unwrap();
        let best_size = abci::compression::zlib_compress_best(&list).len() + 1;
        bound.max_payload_bytes = first.len().min(best_size) - 1;
        assert!(matches!(
            builder(fixture.clone(), bound).observe(&fixture.snapshot).await,
            Err(LanderError::Capacity(_))
        ));
        bound = limits(3);
        bound.max_blocks = 2;
        assert_eq!(
            builder(fixture.clone(), bound)
                .observe(&fixture.snapshot)
                .await
                .unwrap()
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
            Fixture::new(0, 3),
            Fixture::with_calldata(0, 3, 70_000),
            Fixture::with_zero_calldata(0, 3, 150_000),
        ] {
            let fixture = Arc::new(fixture);
            for (max_blobs, max_payload_bytes) in [(1, 240_000), (2, 240_000), (2, 140_000)] {
                let bound = Limits { max_blobs, max_payload_bytes, ..limits(3) };
                let expected = scan_every_prefix(&fixture, &bound, 3);
                let observed = builder(fixture.clone(), bound).observe(&fixture.snapshot).await;
                if expected == 0 {
                    assert!(matches!(observed, Err(LanderError::Capacity(_))), "{bound:?}");
                } else {
                    assert_eq!(observed.unwrap().publishable_blocks, expected, "{bound:?}");
                }
            }
        }
    }

    #[tokio::test]
    async fn selection_stops_at_the_list_budget() {
        let fixture = Arc::new(Fixture::with_zero_calldata(0, 3, 150_000));
        let bound = Limits { max_blobs: 1, ..limits(3) };
        let lists = prefix_lists(&fixture, &bound, 3);
        for (budget, expected) in [
            (usize::MAX, 3),
            (lists[2], 3),
            (lists[2] - 1, 2),
            (lists[1], 2),
            (lists[1] - 1, 1),
            (lists[0], 1),
        ] {
            let observed = builder(fixture.clone(), bound)
                .with_selection_budgets(budget, usize::MAX)
                .observe(&fixture.snapshot)
                .await
                .unwrap();
            assert_eq!(observed.publishable_blocks, expected, "list budget {budget}");
        }
        let error = builder(fixture.clone(), bound)
            .with_selection_budgets(lists[0] - 1, usize::MAX)
            .observe(&fixture.snapshot)
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Capacity(_)), "{error}");
        assert!(error.to_string().contains("block 1"), "{error}");
        let request = builder(fixture.clone(), bound)
            .with_selection_budgets(lists[1], usize::MAX)
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(request.batch.blocks.len(), 2);
        let payload = blob::decode(request.batch.blobs.sidecar.blobs(), &bound).unwrap();
        assert_eq!(
            codec::decode(&payload, &bound).unwrap(),
            request.batch.blocks.iter().map(codec::PublishedBlock::from).collect::<Vec<_>>()
        );
    }

    #[tokio::test]
    async fn selection_stops_at_the_deflate_budget() {
        // Every prefix of these blocks exceeds one blob uncompressed, so each is deflated.
        let fixture = Arc::new(Fixture::with_zero_calldata(0, 3, 150_000));
        let bound = Limits { max_blobs: 1, ..limits(3) };
        let lists = prefix_lists(&fixture, &bound, 3);
        assert!(codec::payload_bound(lists[0]) > blob::PAYLOAD_BYTES_PER_BLOB);
        let two = lists[0] + lists[1];
        let three = two + lists[2];
        // Sizing the first block is never refused.
        for (budget, expected) in
            [(0, 1), (two - 1, 1), (two, 2), (three - 1, 2), (three, 3), (usize::MAX, 3)]
        {
            let observed = builder(fixture.clone(), bound)
                .with_selection_budgets(usize::MAX, budget)
                .observe(&fixture.snapshot)
                .await
                .unwrap();
            assert_eq!(observed.publishable_blocks, expected, "deflate budget {budget}");
        }
        // Prefixes whose worst-case payload fits are accepted without deflating anything.
        let fixture = Arc::new(Fixture::with_calldata(0, 3, 70_000));
        let lists = prefix_lists(&fixture, &limits(3), 3);
        assert!(codec::payload_bound(lists[2]) <= limits(3).max_payload_bytes);
        let observed = builder(fixture.clone(), limits(3))
            .with_selection_budgets(usize::MAX, 0)
            .observe(&fixture.snapshot)
            .await
            .unwrap();
        assert_eq!(observed.publishable_blocks, 3);
    }

    #[tokio::test]
    async fn tip_body_and_certificate_are_authenticated_beyond_selected_prefix() {
        let mut fixture = Fixture::new(20, 26);
        fixture.blocks.get_mut(&26).unwrap().block.data[0].push(0);
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
        let mut fixture = Fixture::new(20, 26);
        fixture
            .blocks
            .get_mut(&26)
            .unwrap()
            .commit
            .signatures
            .fill(tendermint::block::CommitSig::BlockIdFlagAbsent);
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
    }

    #[tokio::test]
    async fn observation_rejects_certified_rpc_block_from_another_height() {
        let mut fixture = Fixture::new(20, 26);
        fixture.blocks.insert(21, fixture.blocks[&22].clone());
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
        let mut fixture = Fixture::new(20, 20);
        advance_checkpoint(&mut fixture, 19);
        let state = fixture.states[&10].clone();
        fixture.states.insert(11, state.clone());
        fixture.l1_headers.insert(11, l1_header(11, &state, fixture.l1_headers[&10].hash()));
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
    }
}

/// Exercises the former settlement-size boundary through real MPT and signature verifiers.
#[test]
fn authenticates_301_members_from_registry_proof_through_comet_certificate() {
    use super::consensus::{committee, pair};
    use crate::validate::{ValidationError, verify_commit};
    use abci::committee::{CommitteeError, verify_committee_witness_at_cutoff, verify_snapshot};
    use std::collections::BTreeSet;
    use tendermint::block::CommitSig;

    const COUNT: usize = 301;
    const CHAIN_ID: &str = "taiko-etna-167001-g0";
    let (params, seeded, keys) = committee(&[1; COUNT], 0);
    let entries = seeded.provenance.unwrap().witness.entries;
    assert_eq!(entries.len(), COUNT);
    assert_eq!(keys.len(), COUNT);
    assert_eq!(entries.iter().map(|entry| entry.pubkey).collect::<BTreeSet<_>>().len(), COUNT);
    assert_eq!(
        entries.iter().map(|entry| entry.reward_recipient).collect::<BTreeSet<_>>().len(),
        COUNT
    );
    let schedule = Schedule { l1_0: 0, epoch_len: 10, epoch_len_l1: 10, genesis_cutoff: 1 };
    let snapshot = Snapshot { checkpoint_index: 0, l1_block: 1, entries: entries.clone() };
    let (record, expected_members) = derive(&snapshot, 1, 0, &schedule, &params).unwrap();
    let checkpoint = registry::checkpoint_slots(0);
    let state = State::new(vec![(
        params.registry,
        vec![
            (registry::length_slot(), U256::from(1)),
            (checkpoint[0], U256::from(1) | (U256::from(COUNT) << 64)),
            (checkpoint[1], entries_root(&entries).into()),
        ],
    )]);
    let witness = CommitteeWitness {
        record: record.clone(),
        registry: state.witness(params.registry, &snapshot_slots(0, false)),
        entries,
    };
    assert!(!witness.registry.account_proof.is_empty());
    assert_eq!(verify_snapshot(state.root, params.registry, &witness, 1).unwrap(), snapshot);
    let (verified_record, members) =
        verify_committee_witness_at_cutoff(state.root, 1, &schedule, &params, &witness, 0).unwrap();
    assert_eq!(verified_record, record);
    assert_eq!(members, expected_members);
    assert_eq!(members.len(), COUNT);
    assert_eq!(members.iter().map(|member| member.pubkey).collect::<BTreeSet<_>>().len(), COUNT);
    let hash = record_hash(params.l2_chain_id, &verified_record);
    let authenticated =
        authenticate(CommitteeState { record: verified_record, members }, 0, hash, &params)
            .unwrap();
    assert_eq!(authenticated.validators.validators().len(), COUNT);
    assert_eq!(authenticated.validators.total_voting_power().value(), 301);

    // The member beyond the old 300-member boundary is covered by the proven payout root.
    let mut tampered = witness.clone();
    tampered.entries[COUNT - 1].reward_recipient = Address::repeat_byte(0x88);
    assert!(matches!(
        verify_committee_witness_at_cutoff(state.root, 1, &schedule, &params, &tampered, 0),
        Err(CommitteeError::EntriesRootMismatch { .. })
    ));
    let mut tampered_set = authenticated.state.clone();
    tampered_set.members[COUNT - 1].reward_recipient = Address::repeat_byte(0x88);
    assert!(matches!(
        authenticate(tampered_set, 0, hash, &params),
        Err(crate::committee::CommitteeError::Invalid("member root mismatch"))
    ));

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
    verify_commit(&block.commit, &block.block.header, &authenticated, CHAIN_ID).unwrap();
    // With unit power, 201/301 is just above 2/3; 200/301 is below it.
    block.commit.signatures[201..].fill(CommitSig::BlockIdFlagAbsent);
    verify_commit(&block.commit, &block.block.header, &authenticated, CHAIN_ID).unwrap();
    block.commit.signatures[200] = CommitSig::BlockIdFlagAbsent;
    assert!(matches!(
        verify_commit(&block.commit, &block.block.header, &authenticated, CHAIN_ID),
        Err(ValidationError::Certificate(message)) if message.contains("insufficient commit power 200/301")
    ));
}
