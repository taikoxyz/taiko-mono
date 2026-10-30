use super::*;
use crate::test_utils::{
    RegistryStorage, TestState, committee_witness, filler_accounts, key_from_seed,
    registry_account, sample_entries,
};
use alloy_primitives::address;
const CHAIN: u64 = 167001;
const REGISTRY: Address = address!("00000000000000000000000000000000E7A10002");
const OTHER: Address = address!("00000000000000000000000000000000E7A10001");
fn devnet() -> ChainParams {
    ChainParams::builtin(CHAIN).unwrap()
}
fn ether(n: u64) -> U256 {
    U256::from(n) * U256::from(10u64).pow(U256::from(18))
}
fn vector_record() -> CommitteeRecord {
    CommitteeRecord {
        target_epoch: 7,
        cutoff_l1_block: 100,
        checkpoint_index: 3,
        set_root: B256::repeat_byte(1),
        total_power: 10,
    }
}
fn vectors() -> serde_json::Value {
    serde_json::from_str(include_str!("../../../../../../testdata/etna_vectors/vectors.json"))
        .unwrap()
}
fn key(v: &serde_json::Value) -> ConsensusKey {
    let mut bytes = [0; 33];
    bytes[0] = v["ck_prefix"].as_str().unwrap().parse().unwrap();
    bytes[1..].copy_from_slice(v["ck_x"].as_str().unwrap().parse::<B256>().unwrap().as_slice());
    ConsensusKey::from_slice(&bytes).unwrap()
}
#[test]
fn v1_configuration_matches_seven_word_vector() {
    let v = vectors();
    let mut p = devnet();
    p.registry = v["deployment"]["registry"].as_str().unwrap().parse().unwrap();
    assert_eq!(
        committee_config_hash(&p),
        v["committee_config"]["hash"].as_str().unwrap().parse::<B256>().unwrap()
    );
    let original = committee_config_hash(&p);
    p.unsettled_limit += 6;
    assert_ne!(committee_config_hash(&p), original);
}
#[test]
fn v1_registry_and_committee_roots_match_schema4() {
    let v = vectors();
    let entries = crate::test_utils::vectors::registry_entries();
    for root in v["registry_entries"]["roots"].as_array().unwrap() {
        let count: usize = root["count"].as_str().unwrap().parse().unwrap();
        let mut subset = entries.clone();
        subset.resize(
            count,
            RegistryEntry {
                ck_prefix: 0,
                ck_x: B256::ZERO,
                eff_stake: U256::ZERO,
                active_from_l1: 0,
                exit_effective_l1: 0,
            },
        );
        subset.truncate(count);
        assert_eq!(
            entries_root(&subset),
            root["entries_root"].as_str().unwrap().parse::<B256>().unwrap()
        );
    }
    for case in v["committee_sets"].as_array().unwrap().iter().filter(|c| c["valid"] == true) {
        let members: Vec<Member> = case["members"]
            .as_array()
            .unwrap()
            .iter()
            .map(|m| Member {
                pubkey: key(m),
                eff_stake: m["eff_stake"].as_str().unwrap().parse().unwrap(),
                power: m["power"].as_str().unwrap().parse().unwrap(),
            })
            .collect();
        let k = case["set_version"].as_str().unwrap().parse().unwrap();
        assert_eq!(
            set_root(CHAIN, k, &members),
            case["set_root"].as_str().unwrap().parse::<B256>().unwrap()
        );
        let record = CommitteeRecord {
            target_epoch: case["target_epoch"].as_str().unwrap().parse().unwrap(),
            cutoff_l1_block: case["cutoff_l1_block"].as_str().unwrap().parse().unwrap(),
            checkpoint_index: case["checkpoint_index"].as_str().unwrap().parse().unwrap(),
            set_root: set_root(CHAIN, k, &members),
            total_power: members.iter().map(|m| m.power).sum(),
        };
        assert_eq!(
            record_hash(CHAIN, &record),
            case["record_hash"].as_str().unwrap().parse::<B256>().unwrap()
        );
    }
}
#[test]
fn v1_registry_entries_use_exact_five_field_rlp() {
    let raw = alloy_rlp::encode(&sample_entries(1)[0]);
    assert_eq!(alloy_rlp::decode_exact::<RegistryEntry>(&raw).unwrap(), sample_entries(1)[0]);
    let mut remaining = raw.as_slice();
    let alloy_rlp::PayloadView::List(fields) =
        alloy_rlp::Header::decode_raw(&mut remaining).unwrap()
    else {
        panic!()
    };
    assert_eq!(fields.len(), 5);
}
#[test]
fn direct_selection_checks_eligibility_duplicates_top_n_and_power() {
    let mut p = devnet();
    p.n_max = 2;
    let mut entries = sample_entries(5);
    entries[4].exit_effective_l1 = 100;
    entries[3].active_from_l1 = 101;
    let snapshot = Snapshot { checkpoint_index: 0, l1_block: 90, entries: entries.clone() };
    let (record, members) = derive(&snapshot, 100, 7, &p).unwrap();
    assert_eq!(members.len(), 2);
    assert_eq!(record.total_power, 5_000_000_000);
    assert!(members.iter().all(|m| m.eff_stake >= ether(2)));
    assert!(members.windows(2).all(|w| set_key(CHAIN, w[0].pubkey) < set_key(CHAIN, w[1].pubkey)));
    entries.push(entries[0].clone());
    assert_eq!(
        derive(&Snapshot { entries, ..snapshot }, 100, 7, &p),
        Err(CommitteeError::DuplicateKey)
    );
}
#[test]
fn invalid_key_and_empty_or_overpowered_committees_are_refused() {
    let p = devnet();
    let mut snapshot = Snapshot { checkpoint_index: 0, l1_block: 90, entries: sample_entries(1) };
    snapshot.entries[0].ck_prefix = 4;
    assert!(matches!(derive(&snapshot, 100, 0, &p), Err(CommitteeError::Key(_))));
    snapshot.entries.clear();
    assert_eq!(derive(&snapshot, 100, 0, &p), Err(CommitteeError::Empty));
    snapshot.entries = sample_entries(1);
    snapshot.entries[0].eff_stake = U256::MAX;
    assert!(matches!(derive(&snapshot, 100, 0, &p), Err(CommitteeError::PowerOverflow { .. })));
    snapshot.entries[0].eff_stake = U256::from(MAX_TOTAL_POWER + 1) * p.vp_unit;
    assert!(matches!(
        derive(&snapshot, 100, 0, &p),
        Err(CommitteeError::TotalPowerTooLarge { .. })
    ));
}
#[test]
fn native_updates_remove_add_and_leave_identical_sets_unchanged() {
    let member = |seed, power| Member {
        pubkey: key_from_seed(B256::repeat_byte(seed)),
        eff_stake: ether(1),
        power,
    };
    let old = vec![member(1, 2), member(2, 3)];
    let new = vec![member(2, 4), member(3, 5)];
    assert!(validator_updates(&old, &old).is_empty());
    let updates = validator_updates(&old, &new);
    assert!(updates.contains(&(old[0].pubkey, 0)));
    assert!(updates.contains(&(new[0].pubkey, 4)));
    assert_eq!(updates.len(), 3);
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
    w.entries[2].active_from_l1 += 1;
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

#[test]
fn direct_selection_stake_floor_activation_exit_and_ineligible_duplicates() {
    let params = devnet();
    let mut entries = sample_entries(3);
    entries[0].active_from_l1 = 100;
    entries[1].exit_effective_l1 = 100;
    entries[2].eff_stake = params.s_min - U256::from(1);
    let mut inactive_duplicate = entries[0].clone();
    inactive_duplicate.active_from_l1 = 101;
    entries.push(inactive_duplicate);
    let snapshot = Snapshot { checkpoint_index: 9, l1_block: 50, entries };
    let (record, members) = derive(&snapshot, 100, 0, &params).unwrap();
    assert_eq!(members.len(), 1);
    assert_eq!(members[0].pubkey, snapshot.entries[0].consensus_key().unwrap());
    assert_eq!(record.cutoff_l1_block, 100);
    assert_eq!(record.checkpoint_index, 9);
    assert_eq!(record.set_root, set_root(CHAIN, 1, &members));
    assert_eq!(
        derive(&snapshot, 100, u64::MAX, &params),
        Err(CommitteeError::EpochOutOfRange(u64::MAX))
    );
}

#[test]
fn direct_selection_ties_and_stake_rounding_are_deterministic() {
    let mut params = devnet();
    params.n_max = 2;
    let mut entries = sample_entries(4);
    for entry in &mut entries {
        entry.eff_stake = ether(2) + params.vp_unit - U256::from(1);
    }
    let mut all_keys: Vec<_> = entries.iter().map(|entry| entry.consensus_key().unwrap()).collect();
    all_keys.sort_by_key(|key| set_key(CHAIN, *key));
    for reverse in [false, true] {
        if reverse {
            entries.reverse();
        }
        let (_, members) = derive(
            &Snapshot { checkpoint_index: 0, l1_block: 1, entries: entries.clone() },
            100,
            7,
            &params,
        )
        .unwrap();
        assert_eq!(members.iter().map(|m| m.pubkey).collect::<Vec<_>>(), all_keys[..2]);
        assert!(members.iter().all(|m| m.power == 2_000_000_000));
    }
}

#[test]
fn record_and_config_hashes_bind_every_canonical_field() {
    let record = vector_record();
    let mut changes = vec![record.clone(); 5];
    changes[0].target_epoch += 1;
    changes[1].cutoff_l1_block += 1;
    changes[2].checkpoint_index += 1;
    changes[3].set_root = B256::ZERO;
    changes[4].total_power += 1;
    for changed in changes {
        assert_ne!(record_hash(CHAIN, &record), record_hash(CHAIN, &changed));
    }
    assert_ne!(record_hash(CHAIN, &record), record_hash(CHAIN + 1, &record));
    let p = devnet();
    let mut changes = vec![p.clone(); 6];
    changes[0].l2_chain_id += 1;
    changes[1].registry = OTHER;
    changes[2].vp_unit += U256::from(1);
    changes[3].s_min += U256::from(1);
    changes[4].n_max += 1;
    changes[5].unsettled_limit += 6;
    for changed in changes {
        assert_ne!(committee_config_hash(&p), committee_config_hash(&changed));
    }
}

#[test]
fn set_root_binds_chain_version_power_and_promotes_odd_nodes() {
    let mut members: Vec<_> = sample_entries(3)
        .iter()
        .map(|e| Member {
            pubkey: e.consensus_key().unwrap(),
            eff_stake: e.eff_stake,
            power: (e.eff_stake / devnet().vp_unit).to(),
        })
        .collect();
    members.sort_by_key(|m| set_key(CHAIN, m.pubkey));
    let root = set_root(CHAIN, 1, &members);
    assert_eq!(
        root,
        set_node(
            CHAIN,
            1,
            set_node(
                CHAIN,
                1,
                set_leaf(CHAIN, 1, 0, &members[0]),
                set_leaf(CHAIN, 1, 1, &members[1])
            ),
            set_leaf(CHAIN, 1, 2, &members[2])
        )
    );
    assert_ne!(root, set_root(CHAIN, 2, &members));
    members[0].power += 1;
    assert_ne!(root, set_root(CHAIN, 1, &members));
    assert_eq!(set_root(CHAIN, 1, &[]), B256::ZERO);
}

#[test]
fn derivation_checks_zero_unit_and_stake_overflow() {
    let mut params = devnet();
    let mut snapshot = Snapshot { checkpoint_index: 0, l1_block: 1, entries: sample_entries(2) };
    params.vp_unit = U256::ZERO;
    assert_eq!(derive(&snapshot, 100, 0, &params), Err(CommitteeError::ZeroVpUnit));
    params.vp_unit = U256::MAX / U256::from(2);
    params.s_min = params.vp_unit;
    for entry in &mut snapshot.entries {
        entry.eff_stake = U256::MAX;
    }
    assert_eq!(derive(&snapshot, 100, 0, &params), Err(CommitteeError::TotalStakeOverflow));
}

#[test]
fn native_committee_preserves_301_member_snapshot_capacity() {
    let params = ChainParams { n_max: 301, registry: REGISTRY, ..devnet() };
    params.validate().unwrap();
    let entries = sample_entries(301);
    let snapshot = Snapshot { checkpoint_index: 0, l1_block: 20, entries: entries.clone() };
    let (record, members) = derive(&snapshot, 25, 0, &params).unwrap();
    assert_eq!(members.len(), 301);
    let unique: std::collections::BTreeSet<_> = members.iter().map(|m| m.pubkey).collect();
    assert_eq!(unique.len(), 301);
    let storage = RegistryStorage { checkpoints: vec![(20, entries)] };
    let state = registry_state(&storage);
    let witness = committee_witness(&state, REGISTRY, &storage, 0, record.clone());
    assert_eq!(
        verify_committee_witness_at_cutoff(state.state_root(), 25, &params, &witness, 0).unwrap(),
        (record, members)
    );
}
