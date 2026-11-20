use super::*;
use crate::test_utils::{key_from_seed, test_key};
use alloy_primitives::b256;
pub(crate) fn sample_entries(n: usize) -> Vec<RegistryEntry> {
    (0..n)
        .map(|i| {
            let pubkey = test_key(i as u64 + 1);
            RegistryEntry {
                ck_prefix: pubkey.prefix(),
                ck_x: pubkey.x(),
                eff_stake: ether(i as u64 + 1),
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
/// `n` fixture stake units of 4,700,000 TAIKO, the devnet minStake; one unit is 10^9 power.
fn ether(n: u64) -> U256 {
    U256::from(n) * U256::from(4_700_000u64) * U256::from(10u64).pow(U256::from(18))
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
    let inputs = &v["committee_config"]["inputs"];
    let number = |name: &str| inputs[name].as_str().unwrap().parse::<U256>().unwrap();
    let mut p = devnet();
    p.registry = inputs["registry"].as_str().unwrap().parse().unwrap();
    p.vp_unit = number("vp_unit");
    // The fifth word is the registry's minStake (ENC-A-36).
    p.min_stake = number("min_stake");
    p.n_max = number("n_max").to();
    p.unsettled_limit = number("unsettled_limit").to();
    assert_eq!(
        committee_config_hash(&p),
        v["committee_config"]["hash"].as_str().unwrap().parse::<B256>().unwrap()
    );
    // 36.e: the fifth word is minStake itself, not an independently chosen threshold.
    let mut other = p.clone();
    other.min_stake += U256::from(1);
    assert_ne!(committee_config_hash(&other), committee_config_hash(&p));
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
        // ENC-A-39a: the set hash over the members in set-key order at version k.
        let chain: u64 = case["l2_chain_id"].as_str().unwrap().parse().unwrap();
        let k: u64 = case["set_version"].as_str().unwrap().parse().unwrap();
        for (member, raw) in members.iter().zip(case["members"].as_array().unwrap()) {
            assert_eq!(
                set_key(chain, member.pubkey),
                raw["set_key"].as_str().unwrap().parse::<B256>().unwrap()
            );
        }
        let set = set_hash(chain, k, &members);
        assert_eq!(set, case["set_hash"].as_str().unwrap().parse::<B256>().unwrap());
        assert_eq!(
            set,
            keccak256(
                case["set_hash_preimage"]
                    .as_str()
                    .unwrap()
                    .parse::<alloy_primitives::Bytes>()
                    .unwrap()
            )
        );
        let record = CommitteeRecord {
            target_epoch: case["target_epoch"].as_str().unwrap().parse().unwrap(),
            cutoff_l1_block: case["cutoff_l1_block"].as_str().unwrap().parse().unwrap(),
            checkpoint_index: case["checkpoint_index"].as_str().unwrap().parse().unwrap(),
            set_hash: set,
            total_power: case["total_power"].as_str().unwrap().parse().unwrap(),
        };
        assert_eq!(record.total_power, members.iter().map(|m| m.power).sum::<u64>());
        assert_eq!(
            record_hash(CHAIN, &record),
            case["record_hash"].as_str().unwrap().parse::<B256>().unwrap()
        );
    }
}

#[test]
fn reused_slot_entries_hash_the_slot_instead_of_the_permanent_bond_id() {
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
    assert!(updates.contains(&(new[1].pubkey, 5)));
    assert_eq!(updates.len(), 3);
}

/// COMM-4.3-13 (vectors 13.d, 13.f, 13.g): the updates are the difference from the set in force.
/// A leaver is returned at power 0, a newcomer or changed power at its new power, and a member
/// whose key and power stay the same is not returned, even when its stake changed.
#[test]
fn native_updates_omit_members_whose_key_and_power_are_unchanged() {
    let member = |seed, stake, power| Member {
        pubkey: key_from_seed(B256::repeat_byte(seed)),
        eff_stake: ether(stake),
        power,
    };
    let old = vec![member(1, 1, 2), member(2, 1, 3), member(3, 1, 4)];
    // 1 keeps key and power with more stake, 2 changes power, 3 leaves, 4 joins.
    let new = vec![member(1, 9, 2), member(2, 1, 5), member(4, 1, 6)];
    let mut expected = vec![(new[1].pubkey, 5), (old[2].pubkey, 0), (new[2].pubkey, 6)];
    expected.sort();
    assert_eq!(validator_updates(&old, &new), expected);
    // 13.g: all keys and powers retained, stake changed: no update at all.
    let restaked = vec![member(1, 2, 2), member(2, 2, 3), member(3, 2, 4)];
    assert!(validator_updates(&old, &restaked).is_empty());
    // A lone power change returns that member only.
    let changed = vec![member(1, 1, 2), member(2, 1, 7), member(3, 1, 4)];
    assert_eq!(validator_updates(&old, &changed), vec![(old[1].pubkey, 7)]);
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

/// The compressed key of vectors 37.i, 39.a and 39a.a: prefix 2 and the x of the secp256k1
/// generator point.
fn generator_key() -> ConsensusKey {
    let mut bytes = [2; 33];
    bytes[1..].copy_from_slice(&alloy_primitives::hex!(
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    ));
    ConsensusKey::from_slice(&bytes).unwrap()
}

/// 250,000 TAIKO in base units: the stake of vectors 37.i, 39a.a and 42.a.
fn stake_250k() -> U256 {
    U256::from(250_000u64) * U256::from(10u64).pow(U256::from(18))
}

/// Appendix A hash vectors at 994960561 (ENC-A-5, 37.*, 39.*, 39a.*, 42.*): every tag is one
/// right-padded `bytes32` word, never a dynamic string.
#[test]
fn appendix_a_hash_vectors_use_bytes32_tags() {
    let zero = RegistryEntry {
        ck_prefix: 0,
        ck_x: B256::ZERO,
        eff_stake: U256::ZERO,
        active_from_l1: 0,
        exit_effective_l1: 0,
    };
    // 37.a: slot 1 with all-zero fields.
    let leaf = entry_leaf(1, &zero);
    assert_eq!(leaf, b256!("21d961646cf730220ee47cda213ec296eba41d18fc39f8f6cb1e1350f77c907d"));
    // 37.j: the same entry with the tag encoded as a dynamic string is another hash.
    let mut dynamic = [word(224u64), word(1u64)].concat();
    dynamic.extend([B256::ZERO; 5].concat());
    dynamic.extend_from_slice(word(17u64).as_slice());
    dynamic.extend_from_slice(tag(b"ETNA_REG_ENTRY_V1").as_slice());
    assert_eq!(dynamic.len(), 288);
    let dynamic = keccak256(&dynamic);
    assert_eq!(dynamic, b256!("6be6938b2da71c3451f504f138ac0f40a3402012cec0d51f5eb7d37d1fd574e7"));
    assert_ne!(leaf, dynamic);
    // 37.i: slot 0, the generator key, 250,000 TAIKO, active from 100, never exiting.
    let key = generator_key();
    let entry = RegistryEntry {
        ck_prefix: key.prefix(),
        ck_x: key.x(),
        eff_stake: stake_250k(),
        active_from_l1: 100,
        exit_effective_l1: (1 << 48) - 1,
    };
    assert_eq!(
        entry_leaf(0, &entry),
        b256!("e7283e6153912ee69d614724bff4c2c09b9d20287fa4e0840db13c883df21387")
    );
    // 39.a: the set key of that key on chain 167000.
    assert_eq!(
        set_key(167_000, key),
        b256!("7529ec50109faf073e202f03d7b4804a32a3571765e9749536cc42cc37acb437")
    );
    // 39a.a: one member at k = 1, a 288-byte preimage.
    let member = Member { pubkey: key, eff_stake: stake_250k(), power: 250_000_000_000_000 };
    let set = set_hash(167_000, 1, std::slice::from_ref(&member));
    assert_eq!(set, b256!("0c09cd574e795c943cf299b730422425455959f85c169641a97030f4d287566d"));
    // 42a.b: k = targetEpoch is another set.
    assert_ne!(set_hash(167_000, 0, std::slice::from_ref(&member)), set);
    // 42.a: committee 0's record over that set.
    let record = CommitteeRecord {
        target_epoch: 0,
        cutoff_l1_block: 100,
        checkpoint_index: 0,
        set_hash: set,
        total_power: 250_000_000_000_000,
    };
    assert_eq!(
        record_hash(167_000, &record),
        b256!("6fa2491c7f7f68e27ae6e55fa1a5cbcc0dfb095bef60d4a69ed7498417368634")
    );
}

/// ENC-A-39a (39a.b..f): one standard ABI hash commits the whole member list in set-key order,
/// with its chain id, version k, stakes and powers; an independent ABI encoder gives the same
/// preimage. Another order, a dynamic-string tag or a Merkle root over the members is another
/// hash.
#[test]
fn set_hash_is_one_abi_hash_over_the_sorted_members() {
    use alloy_sol_types::{
        SolType,
        sol_data::{Array, FixedBytes, Uint},
    };
    type Members = Array<(Uint<8>, FixedBytes<32>, Uint<256>, Uint<64>)>;
    type Preimage = (FixedBytes<32>, Uint<256>, Uint<256>, Members);
    let preimage = |chain: u64, k: u64, members: &[Member]| {
        Preimage::abi_encode_params(&(
            tag(b"ETNA_SET_V1"),
            U256::from(chain),
            U256::from(k),
            members
                .iter()
                .map(|m| (m.pubkey.prefix(), m.pubkey.x(), m.eff_stake, m.power))
                .collect::<Vec<_>>(),
        ))
    };
    let mut members: Vec<_> = sample_entries(3)
        .iter()
        .map(|e| Member {
            pubkey: e.consensus_key().unwrap(),
            eff_stake: e.eff_stake,
            power: (e.eff_stake / devnet().vp_unit).to(),
        })
        .collect();
    members.sort_by_key(|m| set_key(CHAIN, m.pubkey));
    let hash = set_hash(CHAIN, 1, &members);
    let encoded = preimage(CHAIN, 1, &members);
    assert_eq!(encoded.len(), (5 + 4 * 3) * 32);
    assert_eq!(hash, keccak256(&encoded));
    // 39a.c: the same members in another order.
    let mut reversed = members.clone();
    reversed.reverse();
    assert_ne!(hash, keccak256(preimage(CHAIN, 1, &reversed)));
    // 39a.d: chain id, version, stake and power are each bound. The set-key order depends on
    // the chain id, so another chain id is checked on the same list's preimage.
    assert_ne!(hash, keccak256(preimage(CHAIN + 1, 1, &members)));
    assert_ne!(hash, set_hash(CHAIN, 2, &members));
    let mut changed = members.clone();
    changed[0].power += 1;
    assert_ne!(hash, set_hash(CHAIN, 1, &changed));
    let mut changed = members.clone();
    changed[0].eff_stake += U256::from(1);
    assert_ne!(hash, set_hash(CHAIN, 1, &changed));
    // 39a.e: a Merkle root over per-member leaves is not the set hash.
    let leaves: Vec<B256> = members.chunks(1).map(|m| keccak256(preimage(CHAIN, 1, m))).collect();
    let merkle = keccak256([keccak256([leaves[0], leaves[1]].concat()), leaves[2]].concat());
    assert_ne!(hash, merkle);
    // 39a.f: the tag as a dynamic string.
    // Head: the tag's offset, chain id, k and the members' offset; then the tag's length and
    // bytes, then the same members.
    let mut dynamic =
        [word(128u64), word(CHAIN), word(1u64), word(192u64), word(11u64), tag(b"ETNA_SET_V1")]
            .concat();
    dynamic.extend_from_slice(&encoded[4 * 32..]);
    assert_ne!(hash, keccak256(&dynamic));
}
