use super::*;
use crate::{
    l1::layout::registry,
    test_utils::{
        RegistryStorage, TestState, anchor_at, committee_witness, filler_accounts,
        registry_account, sample_entries, vectors,
    },
};
use alloy_primitives::{address, b256, keccak256};
use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;

/// L2 chain id of the pinned vectors.
const CHAIN: u64 = 167_001;
const REGISTRY: Address = address!("00000000000000000000000000000000E7A10002");
const OTHER: Address = address!("00000000000000000000000000000000E7A10001");
/// Cutoff used by the `derive` tests.
const C: u64 = 100;
/// Schedule of the `derive` tests: `L1_0 = 0` and 10 L1 blocks per epoch, so with the devnet
/// heartbeat window every heartbeat at or after L1 block 1 qualifies.
/// Runtime snapshot numbers are independent of the heartbeat schedule.
const SCHEDULE: Schedule = Schedule { l1_0: 0, epoch_len: 10, epoch_len_l1: 10, genesis_cutoff: 0 };

fn ether(n: u64) -> U256 {
    U256::from(n) * U256::from(10u64).pow(U256::from(18u64))
}

fn devnet() -> ChainParams {
    ChainParams::builtin(TAIKO_DEVNET_CHAIN_ID).expect("devnet is built in")
}

// ---------------------------------------------------------------------------------------------
// Pinned vectors. Every expected value below was computed independently with foundry's `cast`
// (`cast abi-encode` + `cast keccak`), not with this module.
// ---------------------------------------------------------------------------------------------

/// Shared vector entry `i` (`registry_entries` of `testdata/etna_vectors`): pubkey `0xa1 + i`
/// repeated, `(i + 1)` TAIKO, active from `10 + i`, exit at `1000 + i` for odd `i` (none for
/// even `i`), heartbeat at `20 + i` with sequence `30 + i`.
fn vector_entry(i: u8) -> RegistryEntry {
    vectors::registry_entry(usize::from(i))
}

/// The three set-root vector members, sorted by set key under [`CHAIN`]: that order is
/// `0x22.., 0x33.., 0x11..`.
fn vector_members() -> Vec<Member> {
    let mut members = vec![
        Member {
            reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
            pubkey: B256::repeat_byte(0x11),
            eff_stake: U256::from(3_000_000_000_000_000_000u64),
            power: 3_000_000_000,
        },
        Member {
            reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
            pubkey: B256::repeat_byte(0x22),
            eff_stake: U256::from(1_000_000_000_000_000_007u64),
            power: 1_000_000_000,
        },
        Member {
            reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
            pubkey: B256::repeat_byte(0x33),
            eff_stake: U256::from(2_000_000_000_000_000_000u64),
            power: 2_000_000_000,
        },
    ];
    members.sort_by_key(|m| set_key(CHAIN, m.pubkey));
    members
}

fn vector_record() -> CommitteeRecord {
    CommitteeRecord {
        target_epoch: 7,
        cutoff_l1_block: 1_234,
        checkpoint_index: 3,
        set_root: B256::repeat_byte(0x5e),
        total_stake: U256::from(6_000_000_000_000_000_007u64),
        total_power: 6_000_000_000,
        encoding_version: 1,
    }
}

#[test]
fn domain_tags_are_right_padded_ascii() {
    assert_eq!(REG_ENTRY_TAG, tag(b"ETNA_REG_ENTRY_V2"));
    assert_eq!(SET_KEY_TAG, tag(b"ETNA_SET_KEY"));
    assert_eq!(SET_LEAF_TAG, tag(b"ETNA_SET_LEAF_V2"));
    assert_eq!(SET_NODE_TAG, tag(b"ETNA_SET_NODE"));
    assert_eq!(RECORD_TAG, tag(b"ETNA_COMMITTEE_V2"));
}

/// The shared `registry_entries` vectors (`testdata/etna_vectors`, computed with `cast`; the
/// contracts' `LibEntriesTree` tests read them too): every leaf and the root of every prefix.
#[test]
fn entries_root_and_leaves_match_the_shared_vectors() {
    let entries = vectors::registry_entries();
    assert_eq!(entries.len(), 5);
    for (i, entry) in entries.iter().enumerate() {
        let leaf = vectors::b256_at(&format!("/registry_entries/leaves/{i}"));
        assert_eq!(entry_leaf(i, entry), leaf, "leaf {i}");
    }
    let roots = vectors::len_at("/registry_entries/roots");
    assert_eq!(roots, entries.len() + 1, "a root for every prefix");
    for k in 0..roots {
        let count = vectors::usize_at(&format!("/registry_entries/roots/{k}/count"));
        let root = vectors::b256_at(&format!("/registry_entries/roots/{k}/entries_root"));
        assert_eq!(entries_root(&entries[..count]), root, "count {count}");
    }
}

/// The committee witness slots of the shared `snapshot_slots` vectors, with and without the
/// next checkpoint, including the last index (whose successor slot wraps nothing).
#[test]
fn snapshot_slots_match_the_shared_vectors() {
    let cases = vectors::len_at("/layout/registry/snapshot_slots");
    assert!(cases >= 4);
    for k in 0..cases {
        let p = format!("/layout/registry/snapshot_slots/{k}");
        let index = vectors::u64_at(&format!("{p}/index"));
        let has_next = vectors::at(&format!("{p}/has_next")).as_bool().expect("a boolean");
        assert_eq!(
            snapshot_slots(index, has_next),
            vectors::b256s_at(&format!("{p}/slots")),
            "snapshot {index}, next {has_next}"
        );
    }
}

/// A registry whose snapshot words are packed per the shared layout vectors (at the vector's
/// slots, with the vector's checkpoint packing) verifies, and its checkpoint decodes to the
/// packed `l1Block` with the vector entries.
#[test]
fn verify_snapshot_decodes_the_shared_checkpoint_packing() {
    let case = (0..vectors::len_at("/layout/registry/snapshot_slots"))
        .map(|k| format!("/layout/registry/snapshot_slots/{k}"))
        .find(|p| {
            vectors::u64_at(&format!("{p}/index")) == 0 &&
                vectors::at(&format!("{p}/has_next")).as_bool() == Some(true)
        })
        .expect("a snapshot vector of checkpoint 0 with its successor");
    let slots = vectors::b256s_at(&format!("{case}/slots"));
    let packing = "/layout/registry/packing/checkpoint_head";
    let entries = vectors::registry_entries();
    let count = U256::from(entries.len());
    let root = vectors::b256_at(&format!("/registry_entries/roots/{}/entries_root", entries.len()));
    let (l1_block, next) = (0x0123_4567_89ab_cdef_u64, u64::MAX);
    let words = vec![
        (slots[0], U256::from(2)),
        (slots[1], vectors::pack(packing, &[("l1_block", U256::from(l1_block)), ("count", count)])),
        (slots[2], root.into()),
        (slots[3], vectors::pack(packing, &[("l1_block", U256::from(next)), ("count", count)])),
    ];
    let mut accounts = filler_accounts();
    accounts.push((REGISTRY, 1, U256::ZERO, keccak256(b"etna registry code"), words));
    let state = TestState::new(accounts);
    let w = CommitteeWitness {
        record: CommitteeRecord { checkpoint_index: 0, ..vector_record() },
        registry: state.witness(REGISTRY, &slots),
        entries: entries.clone(),
    };
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, next - 1),
        Ok(Snapshot { checkpoint_index: 0, l1_block, entries })
    );
}

#[test]
fn entries_root_pads_with_zero_leaves() {
    let entries: Vec<RegistryEntry> = (0..3).map(vector_entry).collect();
    let leaf = |i: usize| entry_leaf(i, &entries[i]);
    let node = |l: B256, r: B256| keccak256([l, r].concat());
    assert_eq!(entries_root(&entries[..1]), leaf(0));
    assert_eq!(entries_root(&entries[..2]), node(leaf(0), leaf(1)));
    assert_eq!(entries_root(&entries), node(node(leaf(0), leaf(1)), node(leaf(2), B256::ZERO)));
}

#[test]
fn entries_root_binds_the_index_order() {
    let entries: Vec<RegistryEntry> = (0..2).map(vector_entry).collect();
    let swapped = vec![entries[1].clone(), entries[0].clone()];
    assert_ne!(entries_root(&entries), entries_root(&swapped));
}

#[test]
fn set_key_vectors() {
    assert_eq!(
        set_key(CHAIN, B256::repeat_byte(0x11)),
        b256!("a5581acd643cd20c6fd564555da0c88b0560cec720cd6973d7725141e74a114a")
    );
    assert_eq!(
        set_key(CHAIN, B256::repeat_byte(0x22)),
        b256!("24206024eca4cb4247e197880a8a860b75453483aa18fe64cba043acc30b6d15")
    );
    assert_eq!(
        set_key(CHAIN, B256::repeat_byte(0x33)),
        b256!("301cead8dc3a4959efdd33e3a74dc8f65abc753257831a43ea5e3ca110d47254")
    );
}

#[test]
fn set_root_vectors() {
    for i in 0..vectors::len_at("/committee_sets") {
        let p = format!("/committee_sets/{i}");
        let members = (0..vectors::len_at(&format!("{p}/members")))
            .map(|j| {
                let f = |name: &str| format!("{p}/members/{j}/{name}");
                Member {
                    pubkey: vectors::b256_at(&f("pubkey")),
                    eff_stake: vectors::u256_at(&f("eff_stake")),
                    power: vectors::u64_at(&f("power")),
                    reward_recipient: vectors::address_at(&f("reward_recipient")),
                }
            })
            .collect::<Vec<_>>();
        let epoch = vectors::u64_at(&format!("{p}/target_epoch"));
        assert_eq!(set_root(CHAIN, epoch, &members), vectors::b256_at(&format!("{p}/set_root")));
        for (j, m) in members.iter().enumerate() {
            assert_eq!(
                set_leaf(CHAIN, epoch, j, m),
                vectors::b256_at(&format!("{p}/set_leaves/{j}"))
            );
        }
    }
}

#[test]
fn set_root_promotes_an_odd_last_node() {
    let mut members: Vec<Member> = sample_entries(5)
        .into_iter()
        .map(|e| Member {
            reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
            pubkey: e.pubkey,
            eff_stake: e.eff_stake,
            power: 1,
        })
        .collect();
    members.sort_by_key(|m| set_key(CHAIN, m.pubkey));
    let leaf = |i: usize| set_leaf(CHAIN, 2, i, &members[i]);
    let node = |l: B256, r: B256| set_node(CHAIN, 2, l, r);

    assert_eq!(set_root(CHAIN, 2, &members[..1]), leaf(0));
    assert_eq!(set_root(CHAIN, 2, &members[..3]), node(node(leaf(0), leaf(1)), leaf(2)));
    assert_eq!(
        set_root(CHAIN, 2, &members),
        node(node(node(leaf(0), leaf(1)), node(leaf(2), leaf(3))), leaf(4))
    );
}

#[test]
fn set_root_binds_chain_id_and_k() {
    let members = vector_members();
    let root = set_root(CHAIN, 1, &members);
    assert_ne!(set_root(CHAIN, 2, &members), root);
    let mut other_chain = members.clone();
    other_chain.sort_by_key(|m| set_key(CHAIN + 1, m.pubkey));
    assert_ne!(set_root(CHAIN + 1, 1, &other_chain), root);
}

#[test]
fn set_root_of_no_members_is_zero() {
    assert_eq!(set_root(CHAIN, 1, &[]), B256::ZERO);
}

#[test]
fn record_hash_vector() {
    for i in 0..vectors::len_at("/committee_sets") {
        let p = format!("/committee_sets/{i}");
        let f = |name: &str| format!("{p}/{name}");
        let record = CommitteeRecord {
            target_epoch: vectors::u64_at(&f("target_epoch")),
            cutoff_l1_block: vectors::u64_at(&f("cutoff_l1_block")),
            checkpoint_index: vectors::u64_at(&f("checkpoint_index")),
            set_root: vectors::b256_at(&f("set_root")),
            total_stake: vectors::u256_at(&f("total_stake")),
            total_power: vectors::u64_at(&f("total_power")),
            encoding_version: 2,
        };
        assert_eq!(record_hash(CHAIN, &record), vectors::b256_at(&f("record_hash")));
    }
}

#[test]
fn record_hash_binds_every_field() {
    let base = vector_record();
    let reference = record_hash(CHAIN, &base);
    let variants = [
        CommitteeRecord { target_epoch: 8, ..base.clone() },
        CommitteeRecord { cutoff_l1_block: 1_235, ..base.clone() },
        CommitteeRecord { checkpoint_index: 4, ..base.clone() },
        CommitteeRecord { set_root: B256::repeat_byte(0x5f), ..base.clone() },
        CommitteeRecord { total_stake: base.total_stake + U256::from(1), ..base.clone() },
        CommitteeRecord { total_power: 6_000_000_001, ..base.clone() },
        CommitteeRecord { encoding_version: 2, ..base.clone() },
    ];
    for variant in &variants {
        assert_ne!(record_hash(CHAIN, variant), reference, "{variant:?}");
    }
    assert_ne!(record_hash(CHAIN + 1, &base), reference);
}

// ---------------------------------------------------------------------------------------------
// cutoff / snapshot_slots
// ---------------------------------------------------------------------------------------------

#[test]
fn snapshot_slots_list_length_checkpoint_and_optional_next() {
    let [head, root] = registry::checkpoint_slots(5);
    assert_eq!(snapshot_slots(5, false), vec![registry::length_slot(), head, root]);
    assert_eq!(
        snapshot_slots(5, true),
        vec![registry::length_slot(), head, root, registry::checkpoint_slots(6)[0]]
    );
}

#[test]
fn snapshot_slots_do_not_overflow_at_the_last_index() {
    let [_, root] = registry::checkpoint_slots(u64::MAX);
    let next = B256::from(U256::from_be_bytes(root.0).wrapping_add(U256::from(1)));
    assert_eq!(snapshot_slots(u64::MAX, true)[3], next);
}

// ---------------------------------------------------------------------------------------------
// verify_snapshot
// ---------------------------------------------------------------------------------------------

/// Checkpoints at L1 blocks 10, 20 and 30 holding 2, 3 and 4 sample entries.
fn registry_storage() -> RegistryStorage {
    RegistryStorage {
        checkpoints: vec![
            (10, sample_entries(2)),
            (20, sample_entries(3)),
            (30, sample_entries(4)),
        ],
    }
}

fn registry_state(storage: &RegistryStorage) -> TestState {
    let mut accounts = filler_accounts();
    accounts.push(registry_account(REGISTRY, storage));
    TestState::new(accounts)
}

fn witness_at(state: &TestState, storage: &RegistryStorage, index: u64) -> CommitteeWitness {
    let record = CommitteeRecord { checkpoint_index: index, ..vector_record() };
    committee_witness(state, REGISTRY, storage, index, record)
}

#[test]
fn verify_snapshot_accepts_a_checkpoint_followed_by_one_after_the_cutoff() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let w = witness_at(&state, &storage, 1);
    assert_eq!(w.registry.storage.len(), 4);
    for c in [20, 25, 29] {
        assert_eq!(
            verify_snapshot(state.state_root(), REGISTRY, &w, c),
            Ok(Snapshot { checkpoint_index: 1, l1_block: 20, entries: sample_entries(3) }),
            "cutoff {c}"
        );
    }
}

#[test]
fn verify_snapshot_accepts_the_last_checkpoint_without_a_next_proof() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let w = witness_at(&state, &storage, 2);
    assert_eq!(w.registry.storage.len(), 3);
    for c in [30, u64::MAX] {
        assert_eq!(
            verify_snapshot(state.state_root(), REGISTRY, &w, c),
            Ok(Snapshot { checkpoint_index: 2, l1_block: 30, entries: sample_entries(4) }),
            "cutoff {c}"
        );
    }
}

#[test]
fn verify_snapshot_accepts_an_empty_checkpoint() {
    let storage = RegistryStorage { checkpoints: vec![(5, vec![])] };
    let state = registry_state(&storage);
    let w = witness_at(&state, &storage, 0);
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 5),
        Ok(Snapshot { checkpoint_index: 0, l1_block: 5, entries: vec![] })
    );
}

#[test]
fn verify_snapshot_rejects_an_index_beyond_the_length() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let w = witness_at(&state, &storage, 3);
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 100),
        Err(CommitteeError::CheckpointOutOfRange { index: 3, length: U256::from(3) })
    );
}

#[test]
fn verify_snapshot_rejects_a_missing_next_proof() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let mut w = witness_at(&state, &storage, 1);
    w.registry.storage.truncate(3);
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 25),
        Err(CommitteeError::NextCheckpointMismatch {
            index: 1,
            length: U256::from(3),
            proven: false
        })
    );
}

#[test]
fn verify_snapshot_rejects_a_next_proof_past_the_end() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let mut w = witness_at(&state, &storage, 2);
    w.registry = state.witness(REGISTRY, &snapshot_slots(2, true));
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 35),
        Err(CommitteeError::NextCheckpointMismatch {
            index: 2,
            length: U256::from(3),
            proven: true
        })
    );
}

#[test]
fn verify_snapshot_rejects_a_checkpoint_after_the_cutoff() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let w = witness_at(&state, &storage, 1);
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 19),
        Err(CommitteeError::CheckpointAfterCutoff { l1_block: 20, cutoff: 19 })
    );
}

#[test]
fn verify_snapshot_rejects_a_next_checkpoint_at_or_before_the_cutoff() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let w = witness_at(&state, &storage, 0);
    for c in [20, 25] {
        assert_eq!(
            verify_snapshot(state.state_root(), REGISTRY, &w, c),
            Err(CommitteeError::NextCheckpointNotAfterCutoff { l1_block: 20, cutoff: c })
        );
    }
}

#[test]
fn verify_snapshot_rejects_an_entry_count_mismatch() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let mut w = witness_at(&state, &storage, 1);
    w.entries.pop();
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 25),
        Err(CommitteeError::EntryCountMismatch { expected: 3, got: 2 })
    );
    w.entries = sample_entries(4);
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 25),
        Err(CommitteeError::EntryCountMismatch { expected: 3, got: 4 })
    );
}

#[test]
fn verify_snapshot_rejects_entries_that_do_not_hash_to_the_root() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let mut w = witness_at(&state, &storage, 1);
    w.entries[2].last_heartbeat_seq += 1;
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 25),
        Err(CommitteeError::EntriesRootMismatch {
            expected: entries_root(&sample_entries(3)),
            got: entries_root(&w.entries),
        })
    );

    let mut w = witness_at(&state, &storage, 1);
    w.entries.swap(0, 1);
    assert!(matches!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 25),
        Err(CommitteeError::EntriesRootMismatch { .. })
    ));
}

#[test]
fn verify_snapshot_rejects_another_contract() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let w = witness_at(&state, &storage, 1);
    assert_eq!(
        verify_snapshot(state.state_root(), OTHER, &w, 25),
        Err(CommitteeError::WrongContract { expected: OTHER, got: REGISTRY })
    );
}

#[test]
fn verify_snapshot_rejects_a_bad_proof() {
    let storage = registry_storage();
    let state = registry_state(&storage);

    let mut w = witness_at(&state, &storage, 1);
    w.registry.storage[1].value = U256::from(19) | (U256::from(3) << 64);
    assert!(matches!(
        verify_snapshot(state.state_root(), REGISTRY, &w, 25),
        Err(CommitteeError::Mpt(MptError::Storage { .. }))
    ));

    let w = witness_at(&state, &storage, 1);
    assert!(matches!(
        verify_snapshot(B256::repeat_byte(0x01), REGISTRY, &w, 25),
        Err(CommitteeError::Mpt(MptError::Account(_)))
    ));
}

// ---------------------------------------------------------------------------------------------
// derive
// ---------------------------------------------------------------------------------------------

/// An entry eligible at any cutoff: pubkey `seed` repeated, no exit, one heartbeat at L1 block 1
/// (sequence 1).
fn entry(seed: u8, eff_stake: U256) -> RegistryEntry {
    RegistryEntry {
        reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
        pubkey: B256::repeat_byte(seed),
        eff_stake,
        active_from_l1: 0,
        exit_effective_l1: u64::MAX,
        last_heartbeat_at: 1,
        last_heartbeat_seq: 1,
    }
}

fn snapshot(entries: Vec<RegistryEntry>) -> Snapshot {
    Snapshot { checkpoint_index: 4, l1_block: 90, entries }
}

/// The member pubkeys (in member order) `derive` returns at cutoff [`C`], target epoch 1.
fn derived_pubkeys(
    entries: Vec<RegistryEntry>,
    params: &ChainParams,
) -> Result<Vec<B256>, CommitteeError> {
    derive(&snapshot(entries), C, 1, &SCHEDULE, params)
        .map(|(_, members)| members.iter().map(|m| m.pubkey).collect())
}

/// `pubkeys` sorted by set key under `params`' chain id.
fn key_sorted(params: &ChainParams, mut pubkeys: Vec<B256>) -> Vec<B256> {
    pubkeys.sort_by_key(|p| set_key(params.l2_chain_id, *p));
    pubkeys
}

#[test]
fn derive_builds_key_sorted_members_and_the_record() {
    let params = devnet();
    let entries = vec![entry(1, ether(3)), entry(2, ether(1) + U256::from(7)), entry(3, ether(2))];
    let (record, members) = derive(&snapshot(entries.clone()), C, 5, &SCHEDULE, &params).unwrap();

    let mut expected: Vec<Member> =
        [(1u8, 3_000_000_000u64), (2, 1_000_000_000), (3, 2_000_000_000)]
            .into_iter()
            .zip(&entries)
            .map(|((seed, power), e)| Member {
                reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
                pubkey: B256::repeat_byte(seed),
                eff_stake: e.eff_stake,
                power,
            })
            .collect();
    expected.sort_by_key(|m| set_key(params.l2_chain_id, m.pubkey));
    assert_eq!(members, expected);
    assert_eq!(
        record,
        CommitteeRecord {
            target_epoch: 5,
            cutoff_l1_block: C,
            checkpoint_index: 4,
            set_root: set_root(params.l2_chain_id, 6, &expected),
            total_stake: ether(6) + U256::from(7),
            total_power: 6_000_000_000,
            encoding_version: ENCODING_VERSION,
        }
    );
}

#[test]
fn derive_uses_k_one_for_the_first_epoch() {
    let params = devnet();
    let (record, members) =
        derive(&snapshot(vec![entry(1, ether(1))]), C, 0, &SCHEDULE, &params).unwrap();
    assert_eq!(record.set_root, set_root(params.l2_chain_id, 1, &members));
}

#[test]
fn derive_rejects_a_target_epoch_without_a_k() {
    assert_eq!(
        derive(&snapshot(vec![entry(1, ether(1))]), C, u64::MAX, &SCHEDULE, &devnet()),
        Err(CommitteeError::EpochOutOfRange(u64::MAX))
    );
}

#[test]
fn activation_at_the_cutoff_is_eligible() {
    let at = RegistryEntry { active_from_l1: C, ..entry(1, ether(1)) };
    let after = RegistryEntry { active_from_l1: C + 1, ..entry(2, ether(1)) };
    assert_eq!(derived_pubkeys(vec![at.clone(), after], &devnet()), Ok(vec![at.pubkey]));
}

#[test]
fn exit_at_the_cutoff_is_ineligible() {
    let at = RegistryEntry { exit_effective_l1: C, ..entry(1, ether(1)) };
    let after = RegistryEntry { exit_effective_l1: C + 1, ..entry(2, ether(1)) };
    assert_eq!(derived_pubkeys(vec![at, after.clone()], &devnet()), Ok(vec![after.pubkey]));
}

/// Heartbeat window of the heartbeat eligibility tests, in L1 blocks.
const W: u64 = 100;
/// Schedule of the heartbeat eligibility tests: `L1_0 = 200` and 30 L1 blocks per epoch, so
/// `L1_first(e) = 200 + 30·e` and the first filtered epoch 3 evaluates at
/// `I*(3) = floor(L1_first(1) / W) · W = floor(230 / 100) · 100 = 200`.
const HB_SCHEDULE: Schedule =
    Schedule { l1_0: 200, epoch_len: 10, epoch_len_l1: 30, genesis_cutoff: 199 };

/// The member pubkeys `derive` returns for `target` at `cutoff` under [`HB_SCHEDULE`] and
/// heartbeat window [`W`].
fn heartbeat_eligible(
    entries: Vec<RegistryEntry>,
    cutoff: u64,
    target: u64,
) -> Result<Vec<B256>, CommitteeError> {
    let params = ChainParams { heartbeat_window: W, ..devnet() };
    derive(&snapshot(entries), cutoff, target, &HB_SCHEDULE, &params)
        .map(|(_, members)| members.iter().map(|m| m.pubkey).collect())
}

/// The floor is `I*(e) − W` with `I*(e)` from the schedule and the target epoch, whatever the
/// cutoff once it has reached `I*(e)`: an entry whose last heartbeat named the window before
/// `I*(e)` stays eligible at a later cutoff (the review's case: `W = 100`, `I* = 200`,
/// cutoff 285, `lastHeartbeatAt = 100`).
#[test]
fn heartbeat_floor_follows_the_schedule_not_the_cutoff() {
    for cutoff in [200, 285, 299] {
        assert_eq!(heartbeat_floor(&HB_SCHEDULE, W, 3, cutoff), Ok(Some(100)), "{cutoff}");
    }
    // Epoch 5 evaluates at floor(L1_first(3) = 290) = 200, epoch 6 at floor(320) = 300.
    assert_eq!(heartbeat_floor(&HB_SCHEDULE, W, 5, 400), Ok(Some(100)));
    assert_eq!(heartbeat_floor(&HB_SCHEDULE, W, 6, 400), Ok(Some(200)));

    let named_previous = RegistryEntry { last_heartbeat_at: 100, ..entry(1, ether(1)) };
    let older = RegistryEntry { last_heartbeat_at: 99, ..entry(2, ether(1)) };
    let named_later = RegistryEntry { last_heartbeat_at: 200, ..entry(3, ether(1)) };
    let params = ChainParams { heartbeat_window: W, ..devnet() };
    assert_eq!(
        heartbeat_eligible(vec![named_previous.clone(), older, named_later.clone()], 285, 3),
        Ok(key_sorted(&params, vec![named_previous.pubkey, named_later.pubkey]))
    );
}

/// A cutoff before `I*(e)` caps the instant at the start of its own window, as the snapshot
/// holds no later heartbeat: the floor only drops, never below 0.
#[test]
fn heartbeat_floor_is_capped_at_the_cutoff_window() {
    // I*(6) = 300; a cutoff of 290 caps it at 200.
    assert_eq!(heartbeat_floor(&HB_SCHEDULE, W, 6, 290), Ok(Some(100)));
    assert_eq!(heartbeat_floor(&HB_SCHEDULE, W, 6, 300), Ok(Some(200)));
    assert_eq!(heartbeat_floor(&HB_SCHEDULE, W, 3, 50), Ok(Some(0)));

    let attested = RegistryEntry { last_heartbeat_at: 100, ..entry(1, ether(1)) };
    assert_eq!(heartbeat_eligible(vec![attested.clone()], 290, 6), Ok(vec![attested.pubkey]));
    assert_eq!(heartbeat_eligible(vec![attested], 300, 6), Err(CommitteeError::Empty));
}

/// Epoch `e_0` and the launch epochs `e_0 + 1`, `e_0 + 2` are not filtered: an entry
/// that never sent a heartbeat is a member, so a genesis of such entries derives.
#[test]
fn genesis_and_launch_epochs_are_not_heartbeat_filtered() {
    let never = RegistryEntry { last_heartbeat_at: 0, last_heartbeat_seq: 0, ..entry(1, ether(1)) };
    for target in [Schedule::E0, Schedule::E0 + 1, Schedule::E0 + LOOKAHEAD_EPOCHS] {
        assert_eq!(heartbeat_floor(&HB_SCHEDULE, W, target, C), Ok(None), "{target}");
        assert_eq!(heartbeat_eligible(vec![never.clone()], C, target), Ok(vec![never.pubkey]));
    }
    assert_eq!(heartbeat_eligible(vec![never], 300, 3), Err(CommitteeError::Empty));
}

/// In a filtered epoch an entry without a heartbeat (`lastHeartbeatSeq = 0`) is ineligible even
/// when the floor is 0, while one whose heartbeat named window 0 (`lastHeartbeatAt = 0`,
/// `lastHeartbeatSeq > 0`) is eligible: with the devnet window every L1 block is in window 0, so
/// the epoch-3 committee derives from such heartbeats alone.
#[test]
fn the_heartbeat_sequence_tells_a_window_0_heartbeat_from_none() {
    let params = devnet();
    assert_eq!(heartbeat_floor(&SCHEDULE, params.heartbeat_window, 3, C), Ok(Some(0)));
    let never = RegistryEntry { last_heartbeat_at: 0, last_heartbeat_seq: 0, ..entry(1, ether(1)) };
    let window_0 =
        RegistryEntry { last_heartbeat_at: 0, last_heartbeat_seq: 1, ..entry(2, ether(1)) };
    let (_, members) =
        derive(&snapshot(vec![never.clone(), window_0.clone()]), C, 3, &SCHEDULE, &params)
            .expect("derives");
    assert_eq!(members.iter().map(|m| m.pubkey).collect::<Vec<_>>(), vec![window_0.pubkey]);
    assert_eq!(
        derive(&snapshot(vec![never]), C, 3, &SCHEDULE, &params),
        Err(CommitteeError::Empty)
    );
}

#[test]
fn a_zero_heartbeat_window_is_rejected_for_filtered_epochs() {
    assert_eq!(heartbeat_floor(&HB_SCHEDULE, 0, 2, C), Ok(None));
    assert_eq!(heartbeat_floor(&HB_SCHEDULE, 0, 3, C), Err(CommitteeError::ZeroHeartbeatWindow));
}

#[test]
fn a_heartbeat_instant_past_u64_is_out_of_range() {
    let schedule = Schedule { epoch_len_l1: u64::MAX, ..HB_SCHEDULE };
    assert_eq!(heartbeat_floor(&schedule, W, 3, C), Err(CommitteeError::EpochOutOfRange(3)));
}

#[test]
fn stake_below_s_min_is_ineligible_when_s_min_dominates() {
    let params = devnet();
    assert!(params.s_min > params.vp_unit);
    let below = entry(1, params.s_min - U256::from(1));
    let at = entry(2, params.s_min);
    assert_eq!(derived_pubkeys(vec![below, at.clone()], &params), Ok(vec![at.pubkey]));
}

#[test]
fn stake_below_vp_unit_is_ineligible_when_vp_unit_dominates() {
    let params = ChainParams { s_min: U256::from(1), ..devnet() };
    let below = entry(1, params.vp_unit - U256::from(1));
    let at = entry(2, params.vp_unit);
    let (_, members) =
        derive(&snapshot(vec![below, at.clone()]), C, 1, &SCHEDULE, &params).unwrap();
    assert_eq!(
        members,
        vec![Member {
            reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
            pubkey: at.pubkey,
            eff_stake: at.eff_stake,
            power: 1
        }]
    );
}

/// Among eligible entries sharing a pubkey, the one with the lowest `bondId` (index) is the
/// member; the later ones are dropped.
#[test]
fn duplicate_eligible_pubkeys_keep_the_lowest_bond_id() {
    let params = devnet();
    let entries = vec![entry(1, ether(1)), entry(2, ether(1)), entry(1, ether(5))];
    let (_, members) = derive(&snapshot(entries), C, 1, &SCHEDULE, &params).expect("derives");
    assert_eq!(
        members.iter().map(|m| m.pubkey).collect::<Vec<_>>(),
        key_sorted(&params, vec![B256::repeat_byte(1), B256::repeat_byte(2)])
    );
    let first = members.iter().find(|m| m.pubkey == B256::repeat_byte(1)).unwrap();
    assert_eq!(first.eff_stake, ether(1), "bondId 0's stake, not bondId 2's");
}

/// A squatter registering a sitting validator's key (with any stake) changes nothing: the
/// committee and its record are the ones derived without the squatting entry, so the chain does
/// not halt at the next `H_e`.
#[test]
fn a_squatter_copying_a_sitting_validators_key_changes_nothing() {
    let params = devnet();
    let sitting = vec![entry(1, ether(3)), entry(2, ether(1)), entry(3, ether(2))];
    let honest = derive(&snapshot(sitting.clone()), C, 1, &SCHEDULE, &params).expect("derives");

    for copied in [1u8, 2, 3] {
        let mut squatted = sitting.clone();
        squatted.push(RegistryEntry { last_heartbeat_at: C, ..entry(copied, ether(1_000)) });
        assert_eq!(
            derive(&snapshot(squatted), C, 1, &SCHEDULE, &params),
            Ok(honest.clone()),
            "{copied}"
        );
    }
}

/// Duplicates are dropped before the `n_max` cap, so a squatter's large stake cannot push an
/// honest member out of the committee.
#[test]
fn duplicates_are_dropped_before_the_n_max_cap() {
    let params = ChainParams { n_max: 2, ..devnet() };
    let entries = vec![entry(1, ether(1)), entry(2, ether(2)), entry(1, ether(100))];
    assert_eq!(
        derived_pubkeys(entries, &params),
        Ok(key_sorted(&params, vec![B256::repeat_byte(1), B256::repeat_byte(2)]))
    );
}

/// The rule applies among ELIGIBLE entries only: an exited earlier entry does not shadow a later
/// eligible one with the same key.
#[test]
fn a_duplicate_of_an_ineligible_entry_is_ignored() {
    let exited = RegistryEntry { exit_effective_l1: C, ..entry(1, ether(1)) };
    let rejoined = entry(1, ether(2));
    let (_, members) =
        derive(&snapshot(vec![exited, rejoined]), C, 1, &SCHEDULE, &devnet()).unwrap();
    assert_eq!(
        members,
        vec![Member {
            reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
            pubkey: B256::repeat_byte(1),
            eff_stake: ether(2),
            power: 2_000_000_000
        }]
    );
}

#[test]
fn n_max_keeps_the_largest_stakes_breaking_ties_by_key() {
    let params = ChainParams { n_max: 2, ..devnet() };
    let top = entry(1, ether(9));
    let (b, c) = (entry(2, ether(7)), entry(3, ether(7)));
    let low = entry(4, ether(3));
    let key = |e: &RegistryEntry| set_key(params.l2_chain_id, e.pubkey);
    let tie_winner = if key(&b) < key(&c) { b.pubkey } else { c.pubkey };
    let expected = key_sorted(&params, vec![top.pubkey, tie_winner]);

    let mut entries = vec![low, c, top, b];
    assert_eq!(derived_pubkeys(entries.clone(), &params), Ok(expected.clone()));
    entries.reverse();
    assert_eq!(derived_pubkeys(entries, &params), Ok(expected));
}

#[test]
fn n_max_applies_after_eligibility() {
    let params = ChainParams { n_max: 1, ..devnet() };
    let exited = RegistryEntry { exit_effective_l1: C, ..entry(1, ether(100)) };
    let small = entry(2, ether(1));
    assert_eq!(derived_pubkeys(vec![exited, small.clone()], &params), Ok(vec![small.pubkey]));
}

#[test]
fn n_max_equal_to_the_eligible_count_keeps_everyone() {
    let params = ChainParams { n_max: 3, ..devnet() };
    let entries = vec![entry(1, ether(1)), entry(2, ether(2)), entry(3, ether(3))];
    let all = key_sorted(&params, entries.iter().map(|e| e.pubkey).collect());
    assert_eq!(derived_pubkeys(entries, &params), Ok(all));
}

#[test]
fn an_empty_committee_is_rejected() {
    assert_eq!(derived_pubkeys(vec![], &devnet()), Err(CommitteeError::Empty));
    let exited = RegistryEntry { exit_effective_l1: C, ..entry(1, ether(1)) };
    assert_eq!(derived_pubkeys(vec![exited], &devnet()), Err(CommitteeError::Empty));
}

#[test]
fn power_that_does_not_fit_u64_is_rejected() {
    let params = ChainParams { vp_unit: U256::from(1), s_min: U256::from(1), ..devnet() };
    let huge = entry(1, U256::from(u64::MAX) + U256::from(1));
    assert_eq!(
        derived_pubkeys(vec![huge], &params),
        Err(CommitteeError::PowerOverflow { pubkey: B256::repeat_byte(1) })
    );
}

#[test]
fn total_power_is_capped_at_max_total_power() {
    let params = ChainParams { vp_unit: U256::from(1), s_min: U256::from(1), ..devnet() };
    let (record, _) =
        derive(&snapshot(vec![entry(1, U256::from(MAX_TOTAL_POWER))]), C, 1, &SCHEDULE, &params)
            .unwrap();
    assert_eq!(record.total_power, MAX_TOTAL_POWER);

    let half = U256::from(MAX_TOTAL_POWER / 2 + 1);
    assert_eq!(
        derived_pubkeys(vec![entry(1, half), entry(2, half)], &params),
        Err(CommitteeError::TotalPowerTooLarge {
            total: 2 * (u128::from(MAX_TOTAL_POWER / 2) + 1)
        })
    );
    assert_eq!(
        derived_pubkeys(
            vec![entry(1, U256::from(u64::MAX)), entry(2, U256::from(u64::MAX))],
            &params
        ),
        Err(CommitteeError::TotalPowerTooLarge { total: 2 * u128::from(u64::MAX) })
    );
}

#[test]
fn total_stake_overflow_is_rejected() {
    let unit = U256::from(1) << 255;
    let params = ChainParams { vp_unit: unit, s_min: unit, ..devnet() };
    assert_eq!(
        derived_pubkeys(vec![entry(1, unit), entry(2, unit)], &params),
        Err(CommitteeError::TotalStakeOverflow)
    );
}

#[test]
fn a_zero_vp_unit_is_rejected() {
    let params = ChainParams { vp_unit: U256::ZERO, ..devnet() };
    assert_eq!(derived_pubkeys(vec![entry(1, ether(1))], &params), Err(CommitteeError::ZeroVpUnit));
}

// ---------------------------------------------------------------------------------------------
// member_bond_ids
// ---------------------------------------------------------------------------------------------

/// Each id names the entry of the member at the same position: an exited lower-id duplicate, a
/// stake below `S_min`, a missing heartbeat in a filtered epoch and the `n_max` cut all leave
/// out the same entries as in `derive`.
#[test]
fn member_bond_ids_align_with_derived_members() {
    let params = ChainParams { n_max: 2, ..devnet() };
    let target = 3;
    assert_eq!(heartbeat_floor(&SCHEDULE, params.heartbeat_window, target, C), Ok(Some(0)));
    let entries = vec![
        // 0: exited at the cutoff; its pubkey reappears as bond 3.
        RegistryEntry { exit_effective_l1: C, active_from_l1: 1, ..entry(3, ether(9)) },
        // 1: below S_min.
        RegistryEntry { active_from_l1: 2, ..entry(2, params.s_min - U256::from(1)) },
        // 2: eligible.
        RegistryEntry { active_from_l1: 7, ..entry(1, ether(2)) },
        // 3: eligible: the only eligible entry of pubkey 3.
        RegistryEntry { active_from_l1: 11, ..entry(3, ether(3)) },
        // 4: eligible, but cut by n_max = 2 as the smallest stake despite the lowest key.
        RegistryEntry { active_from_l1: 13, ..entry(4, ether(1)) },
        // 5: no heartbeat in a filtered epoch, despite the largest stake.
        RegistryEntry { active_from_l1: 17, last_heartbeat_seq: 0, ..entry(5, ether(50)) },
    ];

    let (_, members) =
        derive(&snapshot(entries.clone()), C, target, &SCHEDULE, &params).expect("derives");
    let ids = member_bond_ids(&entries, C, target, &SCHEDULE, &params).expect("bond ids");

    assert_eq!(ids.len(), members.len());
    for (i, ((id, active_from_l1), member)) in ids.iter().zip(&members).enumerate() {
        let e = &entries[*id as usize];
        assert_eq!(e.pubkey, member.pubkey, "{i}");
        assert_eq!(e.eff_stake, member.eff_stake, "{i}");
        assert_eq!(e.active_from_l1, *active_from_l1, "{i}");
    }
    // Set-key order, which here runs against bond id order.
    let key = |seed: u8| set_key(params.l2_chain_id, B256::repeat_byte(seed));
    assert!(key(3) < key(1));
    assert_eq!(ids, vec![(3, 11), (2, 7)]);
}

/// Among eligible entries sharing a pubkey, the member's id is the lowest one, not the one with
/// the largest stake or the earliest activation.
#[test]
fn member_bond_ids_pick_the_lowest_eligible_bond_id() {
    let params = devnet();
    let entries = vec![
        RegistryEntry { active_from_l1: 3, ..entry(1, ether(1)) },
        RegistryEntry { active_from_l1: 5, ..entry(2, ether(1)) },
        RegistryEntry { active_from_l1: 9, ..entry(2, ether(5)) },
        RegistryEntry { active_from_l1: 4, ..entry(2, ether(7)) },
    ];
    let ids = member_bond_ids(&entries, C, 1, &SCHEDULE, &params).expect("bond ids");
    // Set-key order, which here runs against bond id order.
    let key = |seed: u8| set_key(params.l2_chain_id, B256::repeat_byte(seed));
    assert!(key(2) < key(1));
    assert_eq!(ids, vec![(1, 5), (0, 3)]);
}

/// `member_bond_ids` fails exactly where `derive` fails, with the same error.
#[test]
fn member_bond_ids_fail_where_derive_fails() {
    let unit = ChainParams { vp_unit: U256::from(1), s_min: U256::from(1), ..devnet() };
    let wide = U256::from(1) << 255;
    let cases: Vec<(Vec<RegistryEntry>, u64, ChainParams)> = vec![
        (vec![entry(1, ether(1))], 1, ChainParams { vp_unit: U256::ZERO, ..devnet() }),
        (vec![entry(1, ether(1))], u64::MAX, devnet()),
        (vec![entry(1, ether(1))], 3, ChainParams { heartbeat_window: 0, ..devnet() }),
        (vec![], 1, devnet()),
        (vec![RegistryEntry { exit_effective_l1: C, ..entry(1, ether(1)) }], 1, devnet()),
        (vec![entry(1, U256::from(u64::MAX) + U256::from(1))], 1, unit.clone()),
        (vec![entry(1, U256::from(u64::MAX)), entry(2, U256::from(u64::MAX))], 1, unit),
        (
            vec![entry(1, wide), entry(2, wide)],
            1,
            ChainParams { vp_unit: wide, s_min: wide, ..devnet() },
        ),
    ];
    for (i, (entries, target, params)) in cases.into_iter().enumerate() {
        let derived = derive(&snapshot(entries.clone()), C, target, &SCHEDULE, &params)
            .expect_err("derive fails");
        assert_eq!(
            member_bond_ids(&entries, C, target, &SCHEDULE, &params),
            Err(derived),
            "case {i}"
        );
    }
}

/// A bond id is the registry's `uint32`: an entry index above `u32::MAX` is rejected.
#[test]
fn bond_ids_above_u32_max_are_rejected() {
    let max = usize::try_from(u32::MAX).expect("u32 fits usize");
    assert_eq!(bond_id(max), Ok(u32::MAX));
    assert_eq!(bond_id(max + 1), Err(CommitteeError::BondIdOutOfRange(max + 1)));
}

// ---------------------------------------------------------------------------------------------
// verify_committee_witness, verify_committee_witness_at_cutoff
// ---------------------------------------------------------------------------------------------

/// A parent of 27 selects checkpoint 1 (L1 block 20) of [`registry_storage`].
const WITNESS_SCHEDULE: Schedule = Schedule { l1_0: 17, ..SCHEDULE };

fn witness_params() -> ChainParams {
    devnet()
}

/// The record and members derived for target epoch 3 from checkpoint 1 at parent 27.
fn expected_committee(params: &ChainParams) -> (CommitteeRecord, Vec<Member>) {
    let snapshot = Snapshot { checkpoint_index: 1, l1_block: 20, entries: sample_entries(3) };
    derive(&snapshot, 27, 3, &WITNESS_SCHEDULE, params).unwrap()
}

#[test]
fn verify_committee_witness_accepts_the_derived_record() {
    let params = witness_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (record, members) = expected_committee(&params);
    assert_eq!(record.cutoff_l1_block, 27);
    let w = committee_witness(&state, REGISTRY, &storage, 1, record.clone());
    assert_eq!(
        verify_committee_witness(
            &anchor_at(27, state.state_root()),
            &WITNESS_SCHEDULE,
            &params,
            &w,
            3
        ),
        Ok((record, members))
    );
}

#[test]
fn verify_committee_witness_rejects_a_record_mismatch() {
    let params = witness_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (derived, _) = expected_committee(&params);
    let claims = [
        CommitteeRecord { set_root: B256::repeat_byte(0x01), ..derived.clone() },
        CommitteeRecord { total_power: derived.total_power + 1, ..derived.clone() },
        CommitteeRecord { total_stake: derived.total_stake + U256::from(1), ..derived.clone() },
        CommitteeRecord { target_epoch: 4, ..derived.clone() },
        CommitteeRecord { cutoff_l1_block: 23, ..derived.clone() },
        CommitteeRecord { encoding_version: 1, ..derived.clone() },
    ];
    for claimed in claims {
        let w = committee_witness(&state, REGISTRY, &storage, 1, claimed.clone());
        assert_eq!(
            verify_committee_witness(
                &anchor_at(27, state.state_root()),
                &WITNESS_SCHEDULE,
                &params,
                &w,
                3
            ),
            Err(CommitteeError::RecordMismatch {
                claimed: Box::new(claimed),
                derived: Box::new(derived.clone()),
            })
        );
    }
}

#[test]
fn verify_committee_witness_requires_the_cutoff_snapshot() {
    let params = witness_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (derived, _) = expected_committee(&params);

    let early = CommitteeRecord { checkpoint_index: 0, ..derived.clone() };
    let w = committee_witness(&state, REGISTRY, &storage, 0, early);
    assert_eq!(
        verify_committee_witness(
            &anchor_at(27, state.state_root()),
            &WITNESS_SCHEDULE,
            &params,
            &w,
            3
        ),
        Err(CommitteeError::NextCheckpointNotAfterCutoff { l1_block: 20, cutoff: 27 })
    );

    let late = CommitteeRecord { checkpoint_index: 2, ..derived };
    let w = committee_witness(&state, REGISTRY, &storage, 2, late);
    assert_eq!(
        verify_committee_witness(
            &anchor_at(27, state.state_root()),
            &WITNESS_SCHEDULE,
            &params,
            &w,
            3
        ),
        Err(CommitteeError::CheckpointAfterCutoff { l1_block: 30, cutoff: 27 })
    );
}

#[test]
fn verify_committee_witness_rejects_another_registry() {
    let params = ChainParams { registry: OTHER, ..witness_params() };
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (record, _) = expected_committee(&params);
    let w = committee_witness(&state, REGISTRY, &storage, 1, record);
    assert_eq!(
        verify_committee_witness(
            &anchor_at(27, state.state_root()),
            &WITNESS_SCHEDULE,
            &params,
            &w,
            3
        ),
        Err(CommitteeError::WrongContract { expected: OTHER, got: REGISTRY })
    );
}

/// Explicit snapshot 25 still verifies under a later root; runtime parent 27 rejects its record.
#[test]
fn verify_committee_witness_at_cutoff_takes_the_cutoff_as_is() {
    let params = witness_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let snapshot = Snapshot { checkpoint_index: 1, l1_block: 20, entries: sample_entries(3) };
    let (record, members) = derive(&snapshot, 25, 3, &WITNESS_SCHEDULE, &params).unwrap();
    assert_eq!(record.cutoff_l1_block, 25);
    let w = committee_witness(&state, REGISTRY, &storage, 1, record.clone());
    assert_eq!(
        verify_committee_witness_at_cutoff(
            state.state_root(),
            25,
            &WITNESS_SCHEDULE,
            &params,
            &w,
            3
        ),
        Ok((record.clone(), members))
    );

    let (derived, _) = expected_committee(&params);
    assert_eq!(
        verify_committee_witness(
            &anchor_at(27, state.state_root()),
            &WITNESS_SCHEDULE,
            &params,
            &w,
            3
        ),
        Err(CommitteeError::RecordMismatch {
            claimed: Box::new(record),
            derived: Box::new(derived)
        })
    );
}

/// The explicit cutoff selects the snapshot like a derived one: a checkpoint after it, or one
/// followed by a checkpoint at or before it, is rejected.
#[test]
fn verify_committee_witness_at_cutoff_requires_the_cutoff_snapshot() {
    let params = witness_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (record, _) = expected_committee(&params);
    let w = committee_witness(&state, REGISTRY, &storage, 1, record);
    let root = state.state_root();
    assert_eq!(
        verify_committee_witness_at_cutoff(root, 19, &WITNESS_SCHEDULE, &params, &w, 3),
        Err(CommitteeError::CheckpointAfterCutoff { l1_block: 20, cutoff: 19 })
    );
    assert_eq!(
        verify_committee_witness_at_cutoff(root, 30, &WITNESS_SCHEDULE, &params, &w, 3),
        Err(CommitteeError::NextCheckpointNotAfterCutoff { l1_block: 30, cutoff: 30 })
    );
}

// ---------------------------------------------------------------------------------------------
// validator_updates
// ---------------------------------------------------------------------------------------------

fn member(seed: u8, power: u64) -> Member {
    Member {
        reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
        pubkey: B256::repeat_byte(seed),
        eff_stake: U256::from(power),
        power,
    }
}

#[test]
fn validator_updates_remove_add_and_change() {
    let old = vec![member(3, 3), member(1, 1), member(2, 2)];
    let new = vec![member(4, 4), member(2, 2), member(3, 5)];
    assert_eq!(
        validator_updates(&old, &new),
        vec![
            (B256::repeat_byte(1), 0),
            (B256::repeat_byte(2), 2),
            (B256::repeat_byte(3), 5),
            (B256::repeat_byte(4), 4),
        ]
    );
}

#[test]
fn validator_updates_from_or_to_an_empty_set() {
    let set = vec![member(2, 7), member(1, 9)];
    assert_eq!(
        validator_updates(&[], &set),
        vec![(B256::repeat_byte(1), 9), (B256::repeat_byte(2), 7)]
    );
    assert_eq!(
        validator_updates(&set, &[]),
        vec![(B256::repeat_byte(1), 0), (B256::repeat_byte(2), 0)]
    );
    assert!(validator_updates(&[], &[]).is_empty());
}

#[test]
fn validator_updates_omit_unchanged_native_members() {
    let set = vec![member(1, 1)];
    assert!(validator_updates(&set, &set).is_empty());
}

/// The shared `committee_config` vector (`testdata/etna_vectors`, computed with `cast`; the
/// contracts' `EtnaInboxLand` test reads it too): the eleven `ETNA_PARENT_ANCHOR_V3` inputs hash
/// to the vector's configuration hash.
#[test]
fn committee_config_hash_matches_the_shared_vector() {
    let input = |name: &str| format!("/committee_config/inputs/{name}");
    assert_eq!(vectors::str_at(&input("tag")), "ETNA_PARENT_ANCHOR_V3");
    assert_eq!(vectors::u64_at(&input("lookahead_epochs")), LOOKAHEAD_EPOCHS);
    assert_eq!(vectors::u64_at(&input("encoding_version")), u64::from(ENCODING_VERSION));
    let params = ChainParams {
        l2_chain_id: vectors::u64_at(&input("l2_chain_id")),
        registry: vectors::address_at(&input("registry")),
        vp_unit: vectors::u256_at(&input("vp_unit")),
        s_min: vectors::u256_at(&input("s_min")),
        n_max: vectors::usize_at(&input("n_max")),
        heartbeat_window: vectors::u64_at(&input("heartbeat_window")),
        d_max: vectors::u64_at(&input("d_max")),
        margin_v: vectors::u64_at(&input("margin_v")),
        ..devnet()
    };
    assert_eq!(committee_config_hash(&params), vectors::b256_at("/committee_config/hash"));
}

#[test]
fn committee_config_hash_binds_each_config_opening_field() {
    let params = devnet();
    let mut variants = Vec::new();
    let mut p = params.clone();
    p.l2_chain_id += 1;
    variants.push(p);
    let mut p = params.clone();
    p.registry = OTHER;
    variants.push(p);
    let mut p = params.clone();
    p.vp_unit += U256::from(1);
    variants.push(p);
    let mut p = params.clone();
    p.s_min += U256::from(1);
    variants.push(p);
    let mut p = params.clone();
    p.n_max += 1;
    variants.push(p);
    let mut p = params.clone();
    p.heartbeat_window += 1;
    variants.push(p);
    let mut p = params.clone();
    p.d_max += 1;
    variants.push(p);
    let mut p = params.clone();
    p.margin_v += 1;
    variants.push(p);
    for changed in variants {
        assert_ne!(committee_config_hash(&changed), committee_config_hash(&params));
    }
}

#[test]
fn committed_parent_snapshot_changes_active_and_exit_eligibility() {
    let params = ChainParams { registry: REGISTRY, ..devnet() };
    let schedule = Schedule { l1_0: 1000, genesis_cutoff: 980, ..SCHEDULE };
    let mut entries = sample_entries(3);
    entries[0].exit_effective_l1 = 1015;
    entries[1].active_from_l1 = 1015;
    let storage = RegistryStorage { checkpoints: vec![(980, entries.clone())] };
    let state = registry_state(&storage);
    let snapshot = Snapshot { checkpoint_index: 0, l1_block: 980, entries };
    let mut selected = Vec::new();
    for number in [1010, 1020] {
        let (record, members) = derive(&snapshot, number, 1, &schedule, &params).unwrap();
        let w = committee_witness(&state, REGISTRY, &storage, 0, record.clone());
        let parent = anchor_at(number, state.state_root());
        assert_eq!(
            verify_committee_witness(&parent, &schedule, &params, &w, 1),
            Ok((record.clone(), members.clone()))
        );
        assert_eq!(
            verify_committee_witness(&parent, &schedule, &params, &w, 1),
            Ok((record, members.clone()))
        );
        selected.push(members.iter().map(|m| m.pubkey).collect::<std::collections::BTreeSet<_>>());
    }
    assert_ne!(selected[0], selected[1]);
    assert!(selected[0].contains(&sample_entries(3)[0].pubkey));
    assert!(!selected[1].contains(&sample_entries(3)[0].pubkey));
    assert!(!selected[0].contains(&sample_entries(3)[1].pubkey));
    assert!(selected[1].contains(&sample_entries(3)[1].pubkey));
}

#[test]
fn committee_format_and_capacity_support_payout_addresses() {
    assert_eq!(ENCODING_VERSION, 2);
    let params = ChainParams { n_max: 301, ..devnet() };
    params.validate().unwrap();
    let snapshot = Snapshot { checkpoint_index: 0, l1_block: C, entries: sample_entries(301) };
    let (_, members) = derive(&snapshot, C, 0, &SCHEDULE, &params).unwrap();
    assert_eq!(members.len(), 301);
}

#[test]
fn snapshot_authentication_binds_the_reward_recipient() {
    let storage = registry_storage();
    let state = registry_state(&storage);
    let mut witness = witness_at(&state, &storage, 1);
    witness.entries[0].reward_recipient = Address::repeat_byte(0x88);
    assert!(matches!(
        verify_snapshot(state.state_root(), REGISTRY, &witness, 25),
        Err(CommitteeError::EntriesRootMismatch { .. })
    ));
}

#[test]
fn snapshot_and_derivation_reject_zero_recipients() {
    let mut entries = sample_entries(1);
    entries[0].reward_recipient = Address::ZERO;
    let storage = RegistryStorage { checkpoints: vec![(10, entries.clone())] };
    let state = registry_state(&storage);
    let witness = witness_at(&state, &storage, 0);
    assert_eq!(
        verify_snapshot(state.state_root(), REGISTRY, &witness, 25),
        Err(CommitteeError::ZeroRecipient)
    );
    assert_eq!(
        derive(&snapshot(entries), C, 0, &SCHEDULE, &devnet()),
        Err(CommitteeError::ZeroRecipient)
    );
}

#[test]
fn payout_only_changes_bind_commitments_but_preserve_native_validators() {
    let old = sample_entries(3);
    let mut new = old.clone();
    new[0].reward_recipient = Address::repeat_byte(0x88);
    let (old_record, old_members) =
        derive(&snapshot(old.clone()), C, 0, &SCHEDULE, &devnet()).unwrap();
    let (new_record, new_members) =
        derive(&snapshot(new.clone()), C, 0, &SCHEDULE, &devnet()).unwrap();
    assert_ne!(entries_root(&old), entries_root(&new));
    assert_ne!(old_record.set_root, new_record.set_root);
    assert_ne!(record_hash(CHAIN, &old_record), record_hash(CHAIN, &new_record));
    let native_hash = |members: &[Member]| {
        tendermint::validator::Set::without_proposer(
            members
                .iter()
                .map(|m| {
                    tendermint::validator::Info::new(
                        tendermint::PublicKey::from_raw_ed25519(m.pubkey.as_slice()).unwrap(),
                        m.power.try_into().unwrap(),
                    )
                })
                .collect(),
        )
        .hash()
    };
    assert_eq!(native_hash(&old_members), native_hash(&new_members));
    assert!(validator_updates(&old_members, &new_members).is_empty());
}
