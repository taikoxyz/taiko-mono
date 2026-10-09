use super::*;
use crate::{
    l1::layout::registry,
    test_utils::{
        RegistryStorage, TestState, committee_witness, filler_accounts, registry_account,
        sample_entries,
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

/// Vector entry `i`: pubkey `0xa1 + i` repeated, `(i + 1)` TAIKO, active from `10 + i`, exit at
/// `1000 + i` for odd `i` (none for even `i`), heartbeat at `20 + i`.
fn vector_entry(i: u8) -> RegistryEntry {
    RegistryEntry {
        pubkey: B256::repeat_byte(0xa1 + i),
        eff_stake: ether(u64::from(i) + 1),
        active_from_l1: 10 + u64::from(i),
        exit_effective_l1: if i % 2 == 1 { 1_000 + u64::from(i) } else { u64::MAX },
        last_heartbeat_at: 20 + u64::from(i),
    }
}

/// The three MEM-08 vector members, sorted by MEM-08 key under [`CHAIN`]: that order is
/// `0x22.., 0x33.., 0x11..`.
fn vector_members() -> Vec<Member> {
    let mut members = vec![
        Member {
            pubkey: B256::repeat_byte(0x11),
            eff_stake: U256::from(3_000_000_000_000_000_000u64),
            power: 3_000_000_000,
        },
        Member {
            pubkey: B256::repeat_byte(0x22),
            eff_stake: U256::from(1_000_000_000_000_000_007u64),
            power: 1_000_000_000,
        },
        Member {
            pubkey: B256::repeat_byte(0x33),
            eff_stake: U256::from(2_000_000_000_000_000_000u64),
            power: 2_000_000_000,
        },
    ];
    members.sort_by_key(|m| mem08_key(CHAIN, m.pubkey));
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
    assert_eq!(
        REG_ENTRY_TAG,
        b256!("45544e415f5245475f454e545259000000000000000000000000000000000000")
    );
    assert_eq!(
        SET_KEY_TAG,
        b256!("45544e415f5345545f4b45590000000000000000000000000000000000000000")
    );
    assert_eq!(
        SET_LEAF_TAG,
        b256!("45544e415f5345545f4c45414600000000000000000000000000000000000000")
    );
    assert_eq!(
        SET_NODE_TAG,
        b256!("45544e415f5345545f4e4f444500000000000000000000000000000000000000")
    );
    assert_eq!(
        RECORD_TAG,
        b256!("45544e415f434f4d4d49545445455f5631000000000000000000000000000000")
    );
}

#[test]
fn entries_root_vectors() {
    let entries: Vec<RegistryEntry> = (0..5).map(vector_entry).collect();
    let cases = [
        (0, B256::ZERO),
        (1, b256!("79d02e61db82f52d1f6a72c02f7f859cb3a3b8f220d2e9af5c121e32f10a6fe1")),
        (2, b256!("27270b36dd91e08ae8539fb23a46da6fd1d49aa9c8601d5e49b2b9a191e9262e")),
        (3, b256!("d5d58b6300f543970e7ac8bd634c54b49efce15accb3f3cbf56ed69a45940418")),
        (5, b256!("3dedf1650cbb3ebb87215bad5b2ef3639b7810cb76d1144f7e2aefd9bacbf11a")),
    ];
    for (count, expected) in cases {
        assert_eq!(entries_root(&entries[..count]), expected, "count {count}");
    }
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
fn mem08_key_vectors() {
    assert_eq!(
        mem08_key(CHAIN, B256::repeat_byte(0x11)),
        b256!("a5581acd643cd20c6fd564555da0c88b0560cec720cd6973d7725141e74a114a")
    );
    assert_eq!(
        mem08_key(CHAIN, B256::repeat_byte(0x22)),
        b256!("24206024eca4cb4247e197880a8a860b75453483aa18fe64cba043acc30b6d15")
    );
    assert_eq!(
        mem08_key(CHAIN, B256::repeat_byte(0x33)),
        b256!("301cead8dc3a4959efdd33e3a74dc8f65abc753257831a43ea5e3ca110d47254")
    );
}

#[test]
fn mem08_root_vectors() {
    let members = vector_members();
    let order: Vec<B256> = members.iter().map(|m| m.pubkey).collect();
    assert_eq!(order, [0x22, 0x33, 0x11].map(B256::repeat_byte));
    let cases = [
        (1, b256!("06745b6ce2a128a529dc81bbd7ae7e2ae78ed821e0a47b20fdb7dd1d114012e9")),
        (2, b256!("130657073f364f5178a54156feeee2e70af266897c9e356e141bd15dfd0179f1")),
        (3, b256!("4de8033b66bb70d6cfe7d01b17e3f374d9ebdebb4b12f4af66f620b4e5293a2f")),
    ];
    for (n, expected) in cases {
        assert_eq!(mem08_root(CHAIN, 1, &members[..n]), expected, "n = {n}");
    }
}

#[test]
fn mem08_root_promotes_an_odd_last_node() {
    let mut members: Vec<Member> = sample_entries(5)
        .into_iter()
        .map(|e| Member { pubkey: e.pubkey, eff_stake: e.eff_stake, power: 1 })
        .collect();
    members.sort_by_key(|m| mem08_key(CHAIN, m.pubkey));
    let leaf = |i: usize| set_leaf(CHAIN, 2, i, &members[i]);
    let node = |l: B256, r: B256| set_node(CHAIN, 2, l, r);

    assert_eq!(mem08_root(CHAIN, 2, &members[..1]), leaf(0));
    assert_eq!(mem08_root(CHAIN, 2, &members[..3]), node(node(leaf(0), leaf(1)), leaf(2)));
    assert_eq!(
        mem08_root(CHAIN, 2, &members),
        node(node(node(leaf(0), leaf(1)), node(leaf(2), leaf(3))), leaf(4))
    );
}

#[test]
fn mem08_root_binds_chain_id_and_k() {
    let members = vector_members();
    let root = mem08_root(CHAIN, 1, &members);
    assert_ne!(mem08_root(CHAIN, 2, &members), root);
    let mut other_chain = members.clone();
    other_chain.sort_by_key(|m| mem08_key(CHAIN + 1, m.pubkey));
    assert_ne!(mem08_root(CHAIN + 1, 1, &other_chain), root);
}

#[test]
fn mem08_root_of_no_members_is_zero() {
    assert_eq!(mem08_root(CHAIN, 1, &[]), B256::ZERO);
}

#[test]
fn record_hash_vector() {
    assert_eq!(
        record_hash(CHAIN, &vector_record()),
        b256!("07a050ff05bcfa6e1ce71cd6b9536bd68f38c23328ab34a8774fa50155ae484a")
    );
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
fn cutoff_rounds_the_lagged_anchor_down_to_the_grid() {
    assert_eq!(cutoff(100, 1, 0), Ok(100));
    assert_eq!(cutoff(100, 8, 0), Ok(96));
    assert_eq!(cutoff(96, 8, 0), Ok(96));
    assert_eq!(cutoff(100, 8, 5), Ok(88));
    assert_eq!(cutoff(5, 8, 5), Ok(0));
    assert_eq!(cutoff(u64::MAX, 1, 0), Ok(u64::MAX));
    assert_eq!(cutoff(u64::MAX, u64::MAX, 0), Ok(u64::MAX));
}

#[test]
fn cutoff_rejects_an_anchor_below_the_lag() {
    assert_eq!(cutoff(4, 8, 5), Err(CommitteeError::AnchorBelowLag { parent_anchor: 4, lag: 5 }));
}

#[test]
fn cutoff_rejects_a_zero_grid() {
    assert_eq!(cutoff(100, 0, 0), Err(CommitteeError::ZeroCutoffGrid));
}

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
    w.entries[2].last_heartbeat_at += 1;
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

/// An entry eligible at any cutoff: pubkey `seed` repeated, no exit, heartbeat at L1 block 1.
fn entry(seed: u8, eff_stake: U256) -> RegistryEntry {
    RegistryEntry {
        pubkey: B256::repeat_byte(seed),
        eff_stake,
        active_from_l1: 0,
        exit_effective_l1: u64::MAX,
        last_heartbeat_at: 1,
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
    derive(&snapshot(entries), C, 1, params)
        .map(|(_, members)| members.iter().map(|m| m.pubkey).collect())
}

/// `pubkeys` sorted by MEM-08 key under `params`' chain id.
fn key_sorted(params: &ChainParams, mut pubkeys: Vec<B256>) -> Vec<B256> {
    pubkeys.sort_by_key(|p| mem08_key(params.l2_chain_id, *p));
    pubkeys
}

#[test]
fn derive_builds_key_sorted_members_and_the_record() {
    let params = devnet();
    let entries = vec![entry(1, ether(3)), entry(2, ether(1) + U256::from(7)), entry(3, ether(2))];
    let (record, members) = derive(&snapshot(entries.clone()), C, 5, &params).unwrap();

    let mut expected: Vec<Member> =
        [(1u8, 3_000_000_000u64), (2, 1_000_000_000), (3, 2_000_000_000)]
            .into_iter()
            .zip(&entries)
            .map(|((seed, power), e)| Member {
                pubkey: B256::repeat_byte(seed),
                eff_stake: e.eff_stake,
                power,
            })
            .collect();
    expected.sort_by_key(|m| mem08_key(params.l2_chain_id, m.pubkey));
    assert_eq!(members, expected);
    assert_eq!(
        record,
        CommitteeRecord {
            target_epoch: 5,
            cutoff_l1_block: C,
            checkpoint_index: 4,
            set_root: mem08_root(params.l2_chain_id, 6, &expected),
            total_stake: ether(6) + U256::from(7),
            total_power: 6_000_000_000,
            encoding_version: ENCODING_VERSION,
        }
    );
}

#[test]
fn derive_uses_k_one_for_the_first_epoch() {
    let params = devnet();
    let (record, members) = derive(&snapshot(vec![entry(1, ether(1))]), C, 0, &params).unwrap();
    assert_eq!(record.set_root, mem08_root(params.l2_chain_id, 1, &members));
}

#[test]
fn derive_rejects_a_target_epoch_without_a_k() {
    assert_eq!(
        derive(&snapshot(vec![entry(1, ether(1))]), C, u64::MAX, &devnet()),
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

#[test]
fn heartbeat_must_be_within_the_window_at_the_cutoff() {
    let params = ChainParams { heartbeat_window: 10, ..devnet() };
    let edge = RegistryEntry { last_heartbeat_at: C - 10, ..entry(1, ether(1)) };
    let stale = RegistryEntry { last_heartbeat_at: C - 11, ..entry(2, ether(1)) };
    let future = RegistryEntry { last_heartbeat_at: C + 5, ..entry(3, ether(1)) };
    assert_eq!(
        derived_pubkeys(vec![edge.clone(), stale, future.clone()], &params),
        Ok(key_sorted(&params, vec![edge.pubkey, future.pubkey]))
    );
}

#[test]
fn heartbeat_window_addition_saturates() {
    // `10 + u64::MAX` would wrap to 9 < C; saturating it keeps the entry eligible.
    let params = ChainParams { heartbeat_window: u64::MAX, ..devnet() };
    let alive = RegistryEntry { last_heartbeat_at: 10, ..entry(1, ether(1)) };
    assert_eq!(derived_pubkeys(vec![alive.clone()], &params), Ok(vec![alive.pubkey]));
}

#[test]
fn an_entry_that_never_sent_a_heartbeat_is_ineligible() {
    let params = ChainParams { heartbeat_window: u64::MAX, ..devnet() };
    let never = RegistryEntry { last_heartbeat_at: 0, ..entry(1, ether(1)) };
    let alive = entry(2, ether(1));
    assert_eq!(derived_pubkeys(vec![never, alive.clone()], &params), Ok(vec![alive.pubkey]));
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
    let (_, members) = derive(&snapshot(vec![below, at.clone()]), C, 1, &params).unwrap();
    assert_eq!(members, vec![Member { pubkey: at.pubkey, eff_stake: at.eff_stake, power: 1 }]);
}

#[test]
fn duplicate_eligible_pubkeys_are_rejected() {
    let entries = vec![entry(1, ether(1)), entry(2, ether(1)), entry(1, ether(5))];
    assert_eq!(
        derived_pubkeys(entries, &devnet()),
        Err(CommitteeError::DuplicatePubkey(B256::repeat_byte(1)))
    );
}

#[test]
fn a_duplicate_of_an_ineligible_entry_is_ignored() {
    let exited = RegistryEntry { exit_effective_l1: C, ..entry(1, ether(1)) };
    let rejoined = entry(1, ether(2));
    assert_eq!(derived_pubkeys(vec![exited, rejoined], &devnet()), Ok(vec![B256::repeat_byte(1)]));
}

#[test]
fn n_max_keeps_the_largest_stakes_breaking_ties_by_key() {
    let params = ChainParams { n_max: 2, ..devnet() };
    let top = entry(1, ether(9));
    let (b, c) = (entry(2, ether(7)), entry(3, ether(7)));
    let low = entry(4, ether(3));
    let key = |e: &RegistryEntry| mem08_key(params.l2_chain_id, e.pubkey);
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
        derive(&snapshot(vec![entry(1, U256::from(MAX_TOTAL_POWER))]), C, 1, &params).unwrap();
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
// verify_committee_witness
// ---------------------------------------------------------------------------------------------

/// Devnet parameters with a coarse cutoff: `G = 4`, `LAG = 2`. A parent anchor of 27 gives
/// cutoff 24, whose snapshot is checkpoint 1 (L1 block 20) of [`registry_storage`].
fn grid_params() -> ChainParams {
    ChainParams { cutoff_grid: 4, cutoff_lag: 2, ..devnet() }
}

/// The record and members derived for target epoch 3 from checkpoint 1 at cutoff 24.
fn expected_committee(params: &ChainParams) -> (CommitteeRecord, Vec<Member>) {
    let snapshot = Snapshot { checkpoint_index: 1, l1_block: 20, entries: sample_entries(3) };
    derive(&snapshot, 24, 3, params).unwrap()
}

#[test]
fn verify_committee_witness_accepts_the_derived_record() {
    let params = grid_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (record, members) = expected_committee(&params);
    assert_eq!(record.cutoff_l1_block, 24);
    let w = committee_witness(&state, REGISTRY, &storage, 1, record.clone());
    assert_eq!(
        verify_committee_witness(state.state_root(), &params, &w, 27, 3),
        Ok((record, members))
    );
}

#[test]
fn verify_committee_witness_rejects_a_record_mismatch() {
    let params = grid_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (derived, _) = expected_committee(&params);
    let claims = [
        CommitteeRecord { set_root: B256::repeat_byte(0x01), ..derived.clone() },
        CommitteeRecord { total_power: derived.total_power + 1, ..derived.clone() },
        CommitteeRecord { total_stake: derived.total_stake + U256::from(1), ..derived.clone() },
        CommitteeRecord { target_epoch: 4, ..derived.clone() },
        CommitteeRecord { cutoff_l1_block: 23, ..derived.clone() },
        CommitteeRecord { encoding_version: 2, ..derived.clone() },
    ];
    for claimed in claims {
        let w = committee_witness(&state, REGISTRY, &storage, 1, claimed.clone());
        assert_eq!(
            verify_committee_witness(state.state_root(), &params, &w, 27, 3),
            Err(CommitteeError::RecordMismatch {
                claimed: Box::new(claimed),
                derived: Box::new(derived.clone()),
            })
        );
    }
}

#[test]
fn verify_committee_witness_requires_the_cutoff_snapshot() {
    let params = grid_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (derived, _) = expected_committee(&params);

    let early = CommitteeRecord { checkpoint_index: 0, ..derived.clone() };
    let w = committee_witness(&state, REGISTRY, &storage, 0, early);
    assert_eq!(
        verify_committee_witness(state.state_root(), &params, &w, 27, 3),
        Err(CommitteeError::NextCheckpointNotAfterCutoff { l1_block: 20, cutoff: 24 })
    );

    let late = CommitteeRecord { checkpoint_index: 2, ..derived };
    let w = committee_witness(&state, REGISTRY, &storage, 2, late);
    assert_eq!(
        verify_committee_witness(state.state_root(), &params, &w, 27, 3),
        Err(CommitteeError::CheckpointAfterCutoff { l1_block: 30, cutoff: 24 })
    );
}

#[test]
fn verify_committee_witness_rejects_a_parent_anchor_below_the_lag() {
    let params = grid_params();
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (record, _) = expected_committee(&params);
    let w = committee_witness(&state, REGISTRY, &storage, 1, record);
    assert_eq!(
        verify_committee_witness(state.state_root(), &params, &w, 1, 3),
        Err(CommitteeError::AnchorBelowLag { parent_anchor: 1, lag: 2 })
    );
}

#[test]
fn verify_committee_witness_rejects_another_registry() {
    let params = ChainParams { registry: OTHER, ..grid_params() };
    let storage = registry_storage();
    let state = registry_state(&storage);
    let (record, _) = expected_committee(&params);
    let w = committee_witness(&state, REGISTRY, &storage, 1, record);
    assert_eq!(
        verify_committee_witness(state.state_root(), &params, &w, 27, 3),
        Err(CommitteeError::WrongContract { expected: OTHER, got: REGISTRY })
    );
}

// ---------------------------------------------------------------------------------------------
// validator_updates
// ---------------------------------------------------------------------------------------------

fn member(seed: u8, power: u64) -> Member {
    Member { pubkey: B256::repeat_byte(seed), eff_stake: U256::from(power), power }
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
fn validator_updates_restate_unchanged_members() {
    let set = vec![member(1, 1)];
    assert_eq!(validator_updates(&set, &set), vec![(B256::repeat_byte(1), 1)]);
}
