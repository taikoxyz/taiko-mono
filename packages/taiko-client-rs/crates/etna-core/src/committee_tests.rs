use super::*;
use crate::test_utils::{key_from_seed, test_key};
pub(crate) fn sample_entries(n: usize) -> Vec<RegistryEntry> {
    (0..n)
        .map(|i| {
            let pubkey = test_key(i as u64 + 1);
            RegistryEntry {
                ck_prefix: pubkey.prefix(),
                ck_x: pubkey.x(),
                eff_stake: U256::from(i + 1) * U256::from(10u64).pow(U256::from(18u64)),
                active_from_l1: 0,
                exit_effective_l1: (1 << 48) - 1,
            }
        })
        .collect()
}
const CHAIN: u64 = 167001;
fn devnet() -> ChainParams {
    crate::test_utils::params()
}
fn ether(n: u64) -> U256 {
    U256::from(n) * U256::from(10u64).pow(U256::from(18))
}
fn vectors() -> serde_json::Value {
    serde_json::from_str(include_str!("../../../../../testdata/etna_vectors/vectors.json")).unwrap()
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
fn v1_registry_and_committee_roots_match_schema5() {
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
fn displaced_and_reused_entries_hash_the_slot_instead_of_the_permanent_bond_id() {
    for case in vectors()["registry_entries"]["bond_slots"].as_array().unwrap() {
        let raw = &case["entry"];
        let consensus_key = key(raw);
        let entry = RegistryEntry {
            ck_prefix: consensus_key.prefix(),
            ck_x: consensus_key.x(),
            eff_stake: raw["eff_stake"].as_str().unwrap().parse().unwrap(),
            active_from_l1: raw["active_from_l1"].as_str().unwrap().parse().unwrap(),
            exit_effective_l1: raw["exit_effective_l1"].as_str().unwrap().parse().unwrap(),
        };
        let slot: usize = case["slot"].as_str().unwrap().parse().unwrap();
        let bond: usize = case["bond_id"].as_str().unwrap().parse().unwrap();
        let expected: B256 = case["leaf"].as_str().unwrap().parse().unwrap();
        assert_eq!(entry_leaf(slot, &entry), expected);
        assert_ne!(entry_leaf(bond, &entry), expected);
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
