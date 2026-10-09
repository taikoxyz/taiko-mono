//! Shared test builders (compiled only under `cfg(test)`).
//!
//! [`TestState`] is an in-memory L1 state: it builds real storage tries and a real account trie
//! with `alloy_trie::HashBuilder`, so the [`AccountWitness`]es it hands out carry genuine
//! EIP-1186 proofs (inclusion proofs for non-zero slots, exclusion proofs for zero/absent ones).
//!
//! [`InboxStorage`] packs Inbox facts into storage words exactly as spec §6.2 lays them out, and
//! [`anchor_witness`] / [`genesis_inbox_witness`] turn it into witnesses with real proofs.
//! [`RegistryStorage`] does the same for the staking registry's checkpoints (and the last
//! checkpoint's entries), and [`committee_witness`] proves one checkpoint of it.
//!
//! [`MockL1`] and [`MockEngine`] are in-memory [`L1Source`](crate::l1::source::L1Source) and
//! [`Engine`](crate::engine::Engine) implementations with scripted answers and call logs.
//! [`Fixture`] combines all of them into a complete genesis for app tests.

use std::collections::BTreeMap;

use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};

use crate::{
    committee::{entries_root, snapshot_slots},
    envelope::{AnchorWitness, CommitteeWitness},
    l1::layout::{inbox, registry},
    schedule::Schedule,
    types::{AccountWitness, ActivationRecord, CommitteeRecord, RegistryEntry, StorageProof},
};

/// A complete, consistent genesis (L1 state, witness, EL chain, `InitChain` request).
mod fixture;
/// In-memory L1 and execution-engine mocks.
mod mocks;

pub(crate) use fixture::{Fixture, GenesisSpec, validator_updates};
pub(crate) use mocks::{EngineCall, L1Call, MockEngine, MockL1, simple_block};

/// One account of a [`TestState`]: `(address, nonce, balance, code_hash, storage)`, where
/// `storage` lists `(slot, value)` pairs (zero values are the same as absent slots; on duplicate
/// slots the last pair wins).
pub(crate) type AccountSpec = (Address, u64, U256, B256, Vec<(B256, U256)>);

/// One account with its non-zero storage and the derived storage root.
#[derive(Clone, Debug)]
struct TestAccount {
    nonce: u64,
    balance: U256,
    code_hash: B256,
    storage: BTreeMap<B256, U256>,
    storage_root: B256,
}

impl TestAccount {
    fn trie_account(&self) -> TrieAccount {
        TrieAccount {
            nonce: self.nonce,
            balance: self.balance,
            storage_root: self.storage_root,
            code_hash: self.code_hash,
        }
    }

    /// Storage-trie leaves: `keccak256(slot) -> rlp(value)` for every non-zero slot.
    fn storage_leaves(&self) -> BTreeMap<B256, Vec<u8>> {
        self.storage
            .iter()
            .map(|(slot, value)| (keccak256(slot), alloy_rlp::encode(value)))
            .collect()
    }
}

/// An in-memory L1 state with real MPT roots and proofs.
#[derive(Clone, Debug)]
pub(crate) struct TestState {
    accounts: BTreeMap<Address, TestAccount>,
    state_root: B256,
}

impl TestState {
    /// Builds the storage tries and the account trie for `accounts`.
    pub(crate) fn new(accounts: Vec<AccountSpec>) -> Self {
        let accounts: BTreeMap<Address, TestAccount> = accounts
            .into_iter()
            .map(|(address, nonce, balance, code_hash, slots)| {
                let mut storage = BTreeMap::new();
                for (slot, value) in slots {
                    if value.is_zero() {
                        storage.remove(&slot);
                    } else {
                        storage.insert(slot, value);
                    }
                }
                let mut account =
                    TestAccount { nonce, balance, code_hash, storage, storage_root: B256::ZERO };
                account.storage_root = build_trie(&account.storage_leaves(), vec![]).0;
                (address, account)
            })
            .collect();
        let state_root = build_trie(&account_leaves(&accounts), vec![]).0;
        Self { accounts, state_root }
    }

    /// The state root over every account.
    pub(crate) fn state_root(&self) -> B256 {
        self.state_root
    }

    /// Whether `address` is part of the state.
    pub(crate) fn has_account(&self, address: Address) -> bool {
        self.accounts.contains_key(&address)
    }

    /// The storage word of `address` at `slot` (zero for an absent slot or account).
    pub(crate) fn storage(&self, address: Address, slot: B256) -> U256 {
        self.accounts
            .get(&address)
            .and_then(|account| account.storage.get(&slot).copied())
            .unwrap_or_default()
    }

    /// An EIP-1186 witness for `address` and `slots` (in the given order), as `eth_getProof`
    /// would return it. Panics if `address` is not part of the state.
    pub(crate) fn witness(&self, address: Address, slots: &[B256]) -> AccountWitness {
        let account = self.accounts.get(&address).expect("address is part of the test state");

        let account_key = keccak256(address);
        let (state_root, account_nodes) =
            build_trie(&account_leaves(&self.accounts), vec![Nibbles::unpack(account_key)]);
        assert_eq!(state_root, self.state_root, "account trie rebuilds deterministically");

        let storage_keys = slots.iter().map(|slot| Nibbles::unpack(keccak256(slot))).collect();
        let (storage_root, storage_nodes) = build_trie(&account.storage_leaves(), storage_keys);
        assert_eq!(storage_root, account.storage_root, "storage trie rebuilds deterministically");

        AccountWitness {
            address,
            nonce: account.nonce,
            balance: account.balance,
            storage_root: account.storage_root,
            code_hash: account.code_hash,
            account_proof: proof_for(&account_nodes, account_key),
            storage: slots
                .iter()
                .map(|slot| StorageProof {
                    slot: *slot,
                    value: account.storage.get(slot).copied().unwrap_or_default(),
                    proof: proof_for(&storage_nodes, keccak256(slot)),
                })
                .collect(),
        }
    }
}

/// Account-trie leaves: `keccak256(address) -> rlp(TrieAccount)`.
fn account_leaves(accounts: &BTreeMap<Address, TestAccount>) -> BTreeMap<B256, Vec<u8>> {
    accounts
        .iter()
        .map(|(address, account)| (keccak256(address), alloy_rlp::encode(account.trie_account())))
        .collect()
}

/// Builds a trie over `leaves` (sorted by hashed key) and retains the proof nodes on the paths to
/// `targets`.
fn build_trie(leaves: &BTreeMap<B256, Vec<u8>>, targets: Vec<Nibbles>) -> (B256, ProofNodes) {
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(targets));
    for (key, value) in leaves {
        builder.add_leaf(Nibbles::unpack(key), value);
    }
    let root = builder.root();
    (root, builder.take_proof_nodes())
}

/// The proof nodes on the path to `key`, root first.
fn proof_for(nodes: &ProofNodes, key: B256) -> Vec<Bytes> {
    nodes.matching_nodes_sorted(&Nibbles::unpack(key)).into_iter().map(|(_, node)| node).collect()
}

/// The Inbox's storage as spec §6.2 lays it out, before packing into words.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct InboxStorage {
    /// Slot 258, `uint8` at bits 0–7.
    pub(crate) migration_state: u8,
    /// Slot 268, `uint64` at bits 0–63.
    pub(crate) recovery_generation: u64,
    /// Slot 270, `uint64` at bits 0–63.
    pub(crate) last_checkpoint_height: u64,
    /// Slot 271, `bytes32`.
    pub(crate) last_checkpoint_hash: B256,
    /// Slots 272–274; `None` leaves them empty (not yet activated).
    pub(crate) activation: Option<ActivationRecord>,
    /// `committee[epoch] = record_hash` entries of the slot-276 mapping.
    pub(crate) committee: Vec<(u64, B256)>,
}

impl InboxStorage {
    /// An Inbox right after activation: `ETNA_ACTIVE`, generation 0, last checkpoint = the
    /// genesis anchor `(B*, H*)`, and `committee[e_0] = committee_e0`.
    pub(crate) fn genesis(activation: ActivationRecord, committee_e0: B256) -> Self {
        Self {
            migration_state: inbox::ETNA_ACTIVE,
            recovery_generation: 0,
            last_checkpoint_height: activation.genesis_height,
            last_checkpoint_hash: activation.genesis_hash,
            activation: Some(activation),
            committee: vec![(Schedule::E0, committee_e0)],
        }
    }

    /// The `(slot, word)` pairs of this storage, packed low-order-first per spec §6.2. Zero words
    /// are included (the trie drops them, so they read back through exclusion proofs).
    pub(crate) fn slots(&self) -> Vec<(B256, U256)> {
        let mut slots = vec![
            (inbox::slot(inbox::MIGRATION_STATE), U256::from(self.migration_state)),
            (inbox::slot(inbox::RECOVERY_GENERATION), U256::from(self.recovery_generation)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(self.last_checkpoint_height)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HASH), self.last_checkpoint_hash.into()),
        ];
        if let Some(a) = &self.activation {
            let packed = U256::from(a.genesis_height) |
                (U256::from(a.l1_0) << 64) |
                (U256::from(a.epoch_len) << 128) |
                (U256::from(a.epoch_len_l1) << 192);
            slots.extend([
                (inbox::slot(inbox::ACTIVATION_PACKED), packed),
                (inbox::slot(inbox::ACTIVATION_GENESIS_HASH), a.genesis_hash.into()),
                (inbox::slot(inbox::ACTIVATION_GENESIS_STATE_ROOT), a.genesis_state_root.into()),
            ]);
        }
        slots.extend(
            self.committee
                .iter()
                .map(|(epoch, hash)| (inbox::committee_slot(*epoch), (*hash).into())),
        );
        slots
    }
}

/// A sample activation record with every field distinct and non-zero.
pub(crate) fn sample_activation() -> ActivationRecord {
    ActivationRecord {
        genesis_height: 1_000,
        l1_0: 64,
        epoch_len: 20,
        epoch_len_l1: 4,
        genesis_hash: B256::repeat_byte(0x48),
        genesis_state_root: B256::repeat_byte(0x53),
    }
}

/// An L1 header template with distinct non-default fields; its `state_root` is overwritten by
/// the witness builders.
pub(crate) fn l1_header(number: u64, timestamp: u64) -> Header {
    Header {
        parent_hash: B256::repeat_byte(0x01),
        beneficiary: Address::repeat_byte(0x02),
        number,
        timestamp,
        gas_limit: 36_000_000,
        gas_used: 21_000,
        base_fee_per_gas: Some(7),
        ..Header::default()
    }
}

/// The [`AccountSpec`] of an Inbox at `address` holding `storage`.
pub(crate) fn inbox_account(address: Address, storage: &InboxStorage) -> AccountSpec {
    (address, 1, U256::ZERO, keccak256(b"etna inbox code"), storage.slots())
}

/// Filler accounts so account proofs walk through branch nodes.
pub(crate) fn filler_accounts() -> Vec<AccountSpec> {
    (1..=16u8)
        .map(|i| {
            (
                Address::repeat_byte(0xf0 ^ i),
                u64::from(i),
                U256::from(i),
                keccak256([i]),
                vec![(B256::from(U256::from(i)), U256::from(i))],
            )
        })
        .collect()
}

/// An anchor witness for the Inbox at `inbox_address` in `state`: `header` with its `state_root`
/// set to `state`'s root, and proofs of `layout::inbox::anchor_slots(committee_epoch)`.
pub(crate) fn anchor_witness_in(
    state: &TestState,
    inbox_address: Address,
    mut header: Header,
    committee_epoch: Option<u64>,
) -> AnchorWitness {
    header.state_root = state.state_root();
    AnchorWitness {
        l1_header: header,
        inbox: state.witness(inbox_address, &inbox::anchor_slots(committee_epoch)),
    }
}

/// Builds an L1 state holding the Inbox (`storage`) plus filler accounts, and returns an anchor
/// witness against it (see [`anchor_witness_in`]) together with the state.
pub(crate) fn anchor_witness(
    inbox_address: Address,
    storage: &InboxStorage,
    header: Header,
    committee_epoch: Option<u64>,
) -> (AnchorWitness, TestState) {
    let mut accounts = filler_accounts();
    accounts.push(inbox_account(inbox_address, storage));
    let state = TestState::new(accounts);
    (anchor_witness_in(&state, inbox_address, header, committee_epoch), state)
}

/// Builds an L1 state holding the Inbox (`storage`) plus filler accounts, and returns the
/// genesis Inbox witness (proofs of `layout::inbox::genesis_slots(E0)`) together with the state
/// (whose root the witness verifies against).
pub(crate) fn genesis_inbox_witness(
    inbox_address: Address,
    storage: &InboxStorage,
) -> (AccountWitness, TestState) {
    let mut accounts = filler_accounts();
    accounts.push(inbox_account(inbox_address, storage));
    let state = TestState::new(accounts);
    (state.witness(inbox_address, &inbox::genesis_slots(Schedule::E0)), state)
}

/// The staking registry's storage as spec §6.2 lays it out, before packing into words.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct RegistryStorage {
    /// `checkpoints[i] = (l1Block, entries)`, in index order; `count = entries.len()` and
    /// `entriesRoot = entries_root(entries)`.
    pub(crate) checkpoints: Vec<(u64, Vec<RegistryEntry>)>,
}

impl RegistryStorage {
    /// The `(slot, word)` pairs of this storage: `checkpoints.length` at `R`, then per
    /// checkpoint the packed `l1Block | count << 64` word and `entriesRoot`, then the `entries`
    /// array (amendment A1) holding the LAST checkpoint's entries: `entries.length` at `R + 1`
    /// and per entry its `pubkey`, `effStake` and packed
    /// `activeFromL1 | exitEffectiveL1 << 64 | lastHeartbeatAt << 128` words. Zero words are
    /// included (the trie drops them, so they read back through exclusion proofs).
    ///
    /// A state built from this storage is the registry as of the last checkpoint's L1 block, so
    /// a proposer reading entries there sees the last checkpoint's snapshot. Tests that need an
    /// earlier checkpoint's entries in storage must build one state per L1 block (a storage
    /// holding only the checkpoints up to that one).
    pub(crate) fn slots(&self) -> Vec<(B256, U256)> {
        let mut slots = vec![(registry::length_slot(), U256::from(self.checkpoints.len()))];
        for (i, (l1_block, entries)) in self.checkpoints.iter().enumerate() {
            let [head, root] = registry::checkpoint_slots(i as u64);
            let count = u32::try_from(entries.len()).expect("checkpoint count fits uint32");
            slots.push((head, U256::from(*l1_block) | (U256::from(count) << 64)));
            slots.push((root, entries_root(entries).into()));
        }
        let entries = self.checkpoints.last().map(|(_, entries)| entries.as_slice()).unwrap_or(&[]);
        slots.push((registry::entries_length_slot(), U256::from(entries.len())));
        for (j, entry) in entries.iter().enumerate() {
            let [pubkey, stake, packed] = registry::entry_slots(j as u64);
            slots.push((pubkey, entry.pubkey.into()));
            slots.push((stake, entry.eff_stake));
            slots.push((
                packed,
                U256::from(entry.active_from_l1) |
                    (U256::from(entry.exit_effective_l1) << 64) |
                    (U256::from(entry.last_heartbeat_at) << 128),
            ));
        }
        slots
    }
}

/// The [`AccountSpec`] of a staking registry at `address` holding `storage`.
pub(crate) fn registry_account(address: Address, storage: &RegistryStorage) -> AccountSpec {
    (address, 1, U256::ZERO, keccak256(b"etna registry code"), storage.slots())
}

/// A committee witness claiming `record` for checkpoint `index` of the registry at `registry` in
/// `state` (which must hold `storage` there).
///
/// Proves `committee::snapshot_slots(index, has_next)` with `has_next = index + 1 <
/// checkpoints.len()`, and carries the entries of `checkpoints[index]` (none if `index` is out
/// of range). `record.checkpoint_index` is left as given.
pub(crate) fn committee_witness(
    state: &TestState,
    registry: Address,
    storage: &RegistryStorage,
    index: u64,
    record: CommitteeRecord,
) -> CommitteeWitness {
    let len = storage.checkpoints.len() as u64;
    let has_next = index.checked_add(1).is_some_and(|next| next < len);
    let entries = usize::try_from(index)
        .ok()
        .and_then(|i| storage.checkpoints.get(i))
        .map(|(_, entries)| entries.clone())
        .unwrap_or_default();
    CommitteeWitness {
        record,
        registry: state.witness(registry, &snapshot_slots(index, has_next)),
        entries,
    }
}

/// `n` registry entries that are eligible at any cutoff below `2^63` under the devnet
/// parameters: deterministic, distinct pubkeys `keccak256("etna validator <i>")`, stake
/// `(i + 1)` TAIKO, active from L1 block 0, no exit, heartbeat at L1 block 1.
pub(crate) fn sample_entries(n: usize) -> Vec<RegistryEntry> {
    (0..n)
        .map(|i| RegistryEntry {
            pubkey: keccak256(format!("etna validator {i}")),
            eff_stake: U256::from(i + 1) * U256::from(10u64).pow(U256::from(18u64)),
            active_from_l1: 0,
            exit_effective_l1: u64::MAX,
            last_heartbeat_at: 1,
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::l1::layout::{word_u8, word_u32, word_u64};
    use alloy_primitives::{U256, b256};

    fn word(slots: &[(B256, U256)], slot: B256) -> U256 {
        slots.iter().find(|(s, _)| *s == slot).map(|(_, v)| *v).expect("slot is packed")
    }

    /// Pack, then decode with the layout readers: every field comes back.
    #[test]
    fn inbox_storage_packing_decodes_back() {
        let activation = ActivationRecord {
            genesis_height: u64::MAX,
            l1_0: 0x0102_0304_0506_0708,
            epoch_len: 1,
            epoch_len_l1: u64::MAX - 1,
            genesis_hash: B256::repeat_byte(0xa1),
            genesis_state_root: B256::repeat_byte(0xa2),
        };
        let storage = InboxStorage {
            migration_state: u8::MAX,
            recovery_generation: u64::MAX,
            last_checkpoint_height: u64::MAX - 7,
            last_checkpoint_hash: B256::repeat_byte(0xa3),
            activation: Some(activation.clone()),
            committee: vec![(0, B256::repeat_byte(0xa4)), (9, B256::repeat_byte(0xa5))],
        };
        let slots = storage.slots();
        let at = |n| word(&slots, inbox::slot(n));

        assert_eq!(word_u8(at(inbox::MIGRATION_STATE), 0), u8::MAX);
        assert_eq!(at(inbox::MIGRATION_STATE) >> 8, U256::ZERO);
        assert_eq!(word_u64(at(inbox::RECOVERY_GENERATION), 0), u64::MAX);
        assert_eq!(word_u64(at(inbox::LAST_CHECKPOINT_HEIGHT), 0), u64::MAX - 7);
        assert_eq!(B256::from(at(inbox::LAST_CHECKPOINT_HASH)), B256::repeat_byte(0xa3));

        let packed = at(inbox::ACTIVATION_PACKED);
        assert_eq!(word_u64(packed, 0), activation.genesis_height);
        assert_eq!(word_u64(packed, 64), activation.l1_0);
        assert_eq!(word_u64(packed, 128), activation.epoch_len);
        assert_eq!(word_u64(packed, 192), activation.epoch_len_l1);
        assert_eq!(B256::from(at(inbox::ACTIVATION_GENESIS_HASH)), activation.genesis_hash);
        assert_eq!(
            B256::from(at(inbox::ACTIVATION_GENESIS_STATE_ROOT)),
            activation.genesis_state_root
        );

        assert_eq!(B256::from(word(&slots, inbox::committee_slot(0))), B256::repeat_byte(0xa4));
        assert_eq!(B256::from(word(&slots, inbox::committee_slot(9))), B256::repeat_byte(0xa5));
        assert_eq!(slots.len(), 4 + 3 + 2);
    }

    /// Hand-written storage words (as a Solidity contract would write them) equal the packing.
    #[test]
    fn inbox_storage_packing_matches_hand_written_words() {
        let activation = ActivationRecord {
            genesis_height: 0x11,
            l1_0: 0x2222,
            epoch_len: 0x33_3333,
            epoch_len_l1: 0x4444_4444,
            genesis_hash: B256::repeat_byte(0x55),
            genesis_state_root: B256::repeat_byte(0x66),
        };
        let storage = InboxStorage {
            migration_state: 3,
            recovery_generation: 0x0102,
            last_checkpoint_height: 0x0a0b_0c0d,
            last_checkpoint_hash: B256::repeat_byte(0x77),
            activation: Some(activation),
            committee: vec![],
        };
        let slots = storage.slots();
        let at = |n| B256::from(word(&slots, inbox::slot(n)));

        assert_eq!(
            at(inbox::MIGRATION_STATE),
            b256!("0000000000000000000000000000000000000000000000000000000000000003")
        );
        assert_eq!(
            at(inbox::RECOVERY_GENERATION),
            b256!("0000000000000000000000000000000000000000000000000000000000000102")
        );
        assert_eq!(
            at(inbox::LAST_CHECKPOINT_HEIGHT),
            b256!("000000000000000000000000000000000000000000000000000000000a0b0c0d")
        );
        assert_eq!(
            at(inbox::ACTIVATION_PACKED),
            b256!("0000000044444444000000000033333300000000000022220000000000000011")
        );
        assert_eq!(slots.len(), 4 + 3);
    }

    #[test]
    fn inbox_storage_without_activation_leaves_activation_slots_out() {
        let storage = InboxStorage {
            activation: None,
            committee: vec![],
            ..InboxStorage::genesis(sample_activation(), B256::ZERO)
        };
        let slots: Vec<B256> = storage.slots().into_iter().map(|(s, _)| s).collect();
        assert_eq!(slots, [258u64, 268, 270, 271].map(inbox::slot));
    }

    #[test]
    fn genesis_storage_points_the_last_checkpoint_at_the_genesis_anchor() {
        let activation = sample_activation();
        let storage = InboxStorage::genesis(activation.clone(), B256::repeat_byte(0x99));
        assert_eq!(storage.migration_state, inbox::ETNA_ACTIVE);
        assert_eq!(storage.recovery_generation, 0);
        assert_eq!(storage.last_checkpoint_height, activation.genesis_height);
        assert_eq!(storage.last_checkpoint_hash, activation.genesis_hash);
        assert_eq!(storage.committee, vec![(Schedule::E0, B256::repeat_byte(0x99))]);
    }

    /// Pack, then decode with the layout readers: length, l1Block, count and entriesRoot.
    #[test]
    fn registry_storage_packing_decodes_back() {
        let storage =
            RegistryStorage { checkpoints: vec![(u64::MAX, sample_entries(3)), (7, vec![])] };
        let slots = storage.slots();
        // length + 2 words per checkpoint + entries.length (the last checkpoint has no entries).
        assert_eq!(slots.len(), 1 + 2 * 2 + 1);
        assert_eq!(word(&slots, registry::length_slot()), U256::from(2));
        assert_eq!(word(&slots, registry::entries_length_slot()), U256::ZERO);

        let [head0, root0] = registry::checkpoint_slots(0);
        assert_eq!(word_u64(word(&slots, head0), 0), u64::MAX);
        assert_eq!(word_u32(word(&slots, head0), 64), 3);
        assert_eq!(word(&slots, head0) >> 96, U256::ZERO);
        assert_eq!(B256::from(word(&slots, root0)), entries_root(&sample_entries(3)));

        let [head1, root1] = registry::checkpoint_slots(1);
        assert_eq!(word(&slots, head1), U256::from(7));
        assert_eq!(word(&slots, root1), U256::ZERO);
    }

    /// The entries array holds the LAST checkpoint's entries, packed per amendment A1.
    #[test]
    fn registry_storage_packs_the_last_checkpoint_entries() {
        let mut last = sample_entries(3);
        last[1].active_from_l1 = 0x0102;
        last[1].exit_effective_l1 = 0x0304;
        last[1].last_heartbeat_at = u64::MAX;
        let storage =
            RegistryStorage { checkpoints: vec![(5, sample_entries(5)), (9, last.clone())] };
        let slots = storage.slots();
        assert_eq!(slots.len(), 1 + 2 * 2 + 1 + 3 * 3);
        assert_eq!(word(&slots, registry::entries_length_slot()), U256::from(3));

        for (j, entry) in last.iter().enumerate() {
            let [pubkey, stake, packed] = registry::entry_slots(j as u64);
            assert_eq!(B256::from(word(&slots, pubkey)), entry.pubkey);
            assert_eq!(word(&slots, stake), entry.eff_stake);
            let packed = word(&slots, packed);
            assert_eq!(word_u64(packed, 0), entry.active_from_l1);
            assert_eq!(word_u64(packed, 64), entry.exit_effective_l1);
            assert_eq!(word_u64(packed, 128), entry.last_heartbeat_at);
            assert_eq!(packed >> 192, U256::ZERO);
        }
        assert!(slots.iter().all(|(slot, _)| *slot != registry::entry_slots(3)[0]));

        assert_eq!(
            B256::from(word(&slots, registry::entry_slots(1)[2])),
            b256!("0000000000000000ffffffffffffffff00000000000003040000000000000102")
        );
    }

    #[test]
    fn committee_witness_proves_the_next_checkpoint_only_when_it_exists() {
        let address = Address::repeat_byte(0xe8);
        let storage =
            RegistryStorage { checkpoints: vec![(10, sample_entries(1)), (20, sample_entries(2))] };
        let state = TestState::new(vec![registry_account(address, &storage)]);
        let record = CommitteeRecord {
            target_epoch: 1,
            cutoff_l1_block: 0,
            checkpoint_index: 0,
            set_root: B256::ZERO,
            total_stake: U256::ZERO,
            total_power: 0,
            encoding_version: 1,
        };

        let first = committee_witness(&state, address, &storage, 0, record.clone());
        let slots: Vec<B256> = first.registry.storage.iter().map(|p| p.slot).collect();
        assert_eq!(slots, snapshot_slots(0, true));
        assert_eq!(first.entries, sample_entries(1));

        let last = committee_witness(&state, address, &storage, 1, record.clone());
        let slots: Vec<B256> = last.registry.storage.iter().map(|p| p.slot).collect();
        assert_eq!(slots, snapshot_slots(1, false));
        assert_eq!(last.entries, sample_entries(2));

        let beyond = committee_witness(&state, address, &storage, u64::MAX, record);
        assert_eq!(beyond.registry.storage.len(), 3);
        assert!(beyond.entries.is_empty());
    }

    #[test]
    fn sample_entries_are_distinct_and_deterministic() {
        let entries = sample_entries(4);
        assert_eq!(entries, sample_entries(4));
        assert_eq!(entries[..2], sample_entries(2)[..]);
        let pubkeys: std::collections::BTreeSet<B256> = entries.iter().map(|e| e.pubkey).collect();
        assert_eq!(pubkeys.len(), 4);
        assert_eq!(entries[3].eff_stake, U256::from(4_000_000_000_000_000_000u64));
    }

    #[test]
    fn anchor_witness_sets_the_header_state_root() {
        let address = Address::repeat_byte(0xe7);
        let storage = InboxStorage::genesis(sample_activation(), B256::repeat_byte(0x99));
        let (witness, state) = anchor_witness(address, &storage, l1_header(70, 1_000), Some(0));
        assert_eq!(witness.l1_header.state_root, state.state_root());
        assert_eq!(witness.l1_header.number, 70);
        assert_eq!(witness.inbox.address, address);
        let slots: Vec<B256> = witness.inbox.storage.iter().map(|p| p.slot).collect();
        assert_eq!(slots, inbox::anchor_slots(Some(0)));
    }
}
