use super::*;
use crate::{
    fallback::FallbackKeys,
    params::UINT48_MAX,
    staking::{RECORD_COUNT, StakingWords},
    test_utils::test_key,
};
use alloy_primitives::hex;
use proptest::{collection::vec, prelude::*};
use std::sync::OnceLock;

/// The block every decision below is made at, unless a test names another.
const H: u64 = 1_000;

/// The compressed public key of private key 1: prefix 2 and the X of the secp256k1 generator.
const K1: [u8; 33] = hex!("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798");

fn k1() -> ConsensusKey {
    ConsensusKey::from_slice(&K1).unwrap()
}

/// `M`, the minimum total stake that H's anchor proves.
fn m() -> U256 {
    U256::from(1_000_000u64)
}

/// The two words of a seat record holding `key` at `power`: `ckX`, then `ckPrefix` in bits 0–7
/// and the power in bits 8–71.
fn record(key: ConsensusKey, power: u64) -> [U256; 2] {
    [U256::from_be_bytes(key.x().0), U256::from(key.prefix()) | (U256::from(power) << 8)]
}

/// The candidate snapshot that the block-start call of `height` wrote, with total stake `total`
/// and the given `(seat, record)` pairs; every other seat is empty.
fn words(height: u64, total: U256, records: &[(usize, [U256; 2])]) -> StakingWords {
    let mut words = StakingWords::header_only(U256::from(height), total);
    for (seat, record) in records {
        words.records[*seat] = *record;
    }
    words
}

/// Distinct valid keys in ascending order, one per seed.
fn sorted_keys(seeds: core::ops::Range<u64>) -> Vec<ConsensusKey> {
    let mut keys: Vec<_> = seeds.map(test_key).collect();
    keys.sort();
    keys
}

/// The fallback key set F that H's anchor proves: four keys, none of them K1.
fn fallback() -> &'static FallbackKeys {
    static FALLBACK: OnceLock<FallbackKeys> = OnceLock::new();
    FALLBACK.get_or_init(|| FallbackKeys::new(sorted_keys(100..104)).unwrap())
}

/// The set that signs H + 2 for the snapshot `words`, minimum total stake `min_total_stake` and
/// the fallback key set F.
fn decide_at(words: &StakingWords, min_total_stake: U256) -> SignerSet {
    decide(H, words, min_total_stake, fallback())
}

fn candidate(members: Vec<(ConsensusKey, u64)>) -> SignerSet {
    SignerSet { source: SignerSource::Candidate, members }
}

/// F, each key at power 1.
fn fallback_set() -> SignerSet {
    SignerSet { source: SignerSource::Fallback, members: fallback().validator_set() }
}

/// `members` in ascending key order, as a usable candidate lists them.
fn ascending(mut members: Vec<(ConsensusKey, u64)>) -> Vec<(ConsensusKey, u64)> {
    members.sort();
    members
}

#[test]
fn usable_at_m() {
    let snapshot = words(H, m(), &[(0, record(k1(), 5))]);
    assert!(needs_records(H, snapshot.snapshot_height, snapshot.total_stake, m()));
    assert_eq!(usable_candidate(H, &snapshot, m()), Some(vec![(k1(), 5)]));
    assert_eq!(decide_at(&snapshot, m()), candidate(vec![(k1(), 5)]));
}

#[test]
fn total_below_m_falls_back() {
    let snapshot = words(H, m() - U256::from(1), &[(0, record(k1(), 5))]);
    assert_eq!(decide_at(&snapshot, m()), fallback_set());
}

#[test]
fn snapshot_from_h_minus_1_falls_back() {
    // H's block-start call failed, so the snapshot is the one H − 1 wrote.
    let snapshot = words(H - 1, m(), &[(0, record(k1(), 5))]);
    assert_eq!(decide_at(&snapshot, m()), fallback_set());
}

#[test]
fn snapshot_height_with_bit_48_set_is_unusable() {
    let mut snapshot = words(H, m(), &[(0, record(k1(), 5))]);
    snapshot.snapshot_height = (U256::from(1) << 48) | U256::from(H);
    // The low 48 bits are H, but the word is compared in all 256 bits.
    assert_eq!(snapshot.snapshot_height.wrapping_to::<u64>() & UINT48_MAX, H);
    assert!(!needs_records(H, snapshot.snapshot_height, snapshot.total_stake, m()));
    assert_eq!(decide_at(&snapshot, m()), fallback_set());
}

#[test]
fn m_max_makes_even_max_total_unusable() {
    let snapshot = words(H, U256::MAX, &[(0, record(k1(), 5))]);
    assert!(!needs_records(H, snapshot.snapshot_height, U256::MAX, U256::MAX));
    assert_eq!(decide_at(&snapshot, U256::MAX), fallback_set());
}

#[test]
fn m_max_minus_one_with_max_total_is_usable() {
    let snapshot = words(H, U256::MAX, &[(0, record(k1(), 5))]);
    assert_eq!(decide_at(&snapshot, U256::MAX - U256::from(1)), candidate(vec![(k1(), 5)]));
}

#[test]
fn record_at_or_above_n_max_is_a_member() {
    // Every one of the 128 records counts whatever the contract's seat limit is: with 64 seats,
    // a nonzero record 70 is still a member.
    let other = test_key(1);
    let snapshot = words(H, m(), &[(0, record(k1(), 5)), (70, record(other, 7))]);
    assert_eq!(decide_at(&snapshot, m()), candidate(ascending(vec![(k1(), 5), (other, 7)])));
    let only_70 = words(H, m(), &[(70, record(other, 7))]);
    assert_eq!(decide_at(&only_70, m()), candidate(vec![(other, 7)]));
}

#[test]
fn empty_seat_is_two_zero_words() {
    let other = test_key(1);
    let snapshot = words(H, m(), &[(0, record(k1(), 5)), (2, record(other, 7))]);
    assert_eq!(snapshot.records[1], [U256::ZERO; 2]);
    assert_eq!(decide_at(&snapshot, m()), candidate(ascending(vec![(k1(), 5), (other, 7)])));
    // A zero X beside a nonzero second word is not an empty seat but a member, and no compressed
    // key has X = 0.
    let zero_x = words(H, m(), &[(0, record(k1(), 5)), (1, [U256::ZERO, record(other, 7)[1]])]);
    assert_eq!(decide_at(&zero_x, m()), fallback_set());
}

#[test]
fn vector_record_decodes() {
    let x = U256::from_be_bytes(hex!(
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    ));
    // Prefix 2 in bits 0–7 and power 250,000 in bits 8–71.
    let packed = U256::from(0x3d09002u64);
    assert_eq!(record(k1(), 250_000), [x, packed]);
    let snapshot = words(H, m(), &[(0, [x, packed])]);
    assert_eq!(decide_at(&snapshot, m()), candidate(vec![(k1(), 250_000)]));
}

#[test]
fn unused_bit_in_word_2_is_unusable() {
    let [x, packed] = record(k1(), 250_000);
    let snapshot = words(H, m(), &[(0, [x, packed | (U256::from(1) << 72)])]);
    assert_eq!(decide_at(&snapshot, m()), fallback_set());
}

#[test]
fn prefix_zero_record_is_unusable() {
    let [x, _] = record(k1(), 5);
    let snapshot = words(H, m(), &[(0, [x, U256::ZERO])]);
    assert_eq!(decide_at(&snapshot, m()), fallback_set());
}

#[test]
fn zero_power_is_unusable() {
    // The zero-power member is not dropped to leave the other one usable.
    let snapshot = words(H, m(), &[(0, record(test_key(1), 7)), (1, record(k1(), 0))]);
    assert_eq!(decide_at(&snapshot, m()), fallback_set());
}

#[test]
fn repeated_key_is_unusable() {
    let snapshot = words(H, m(), &[(0, record(k1(), 5)), (9, record(k1(), 6))]);
    assert_eq!(decide_at(&snapshot, m()), fallback_set());
    let same_power = words(H, m(), &[(0, record(k1(), 5)), (9, record(k1(), 5))]);
    assert_eq!(decide_at(&same_power, m()), fallback_set());
}

#[test]
fn invalid_key_is_unusable() {
    let p = U256::from_be_bytes(hex!(
        "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
    ));
    let mut one = [0u8; 33];
    one[0] = 2;
    one[32] = 1;
    // X = 1 is a valid key's, so X = p + 1 is refused for being at or above p, not reduced to 1.
    assert!(ConsensusKey::from_slice(&one).is_ok());
    let power = U256::from(5u64) << 8;
    for (name, x, prefix) in [
        ("prefix 4", U256::from_be_bytes(k1().x().0), 4u8),
        ("X at or above p", p + U256::from(1), 2),
        ("X of no curve point", U256::from(5), 2),
    ] {
        let snapshot = words(H, m(), &[(0, [x, power | U256::from(prefix)])]);
        assert_eq!(decide_at(&snapshot, m()), fallback_set(), "{name}");
    }
}

#[test]
fn empty_candidate_is_unusable() {
    let snapshot = words(H, m(), &[]);
    assert!(needs_records(H, snapshot.snapshot_height, snapshot.total_stake, m()));
    assert_eq!(usable_candidate(H, &snapshot, m()), None);
    assert_eq!(decide_at(&snapshot, m()), fallback_set());
}

#[test]
fn exact_sum_max_is_usable_and_max_plus_one_is_not() {
    let other = test_key(1);
    let at_max = words(H, m(), &[(0, record(k1(), MAX_TOTAL_POWER - 1)), (1, record(other, 1))]);
    assert_eq!(
        decide_at(&at_max, m()),
        candidate(ascending(vec![(k1(), MAX_TOTAL_POWER - 1), (other, 1)]))
    );
    let above = words(H, m(), &[(0, record(k1(), MAX_TOTAL_POWER)), (1, record(other, 1))]);
    assert_eq!(decide_at(&above, m()), fallback_set());
}

#[test]
fn sum_that_wraps_u64_is_unusable() {
    let keys = sorted_keys(0..128);
    let at = |power: u64| -> Vec<(usize, [U256; 2])> {
        keys.iter().enumerate().map(|(seat, key)| (seat, record(*key, power))).collect()
    };
    // 128 powers of 2^57 sum to 2^64, which wrapping u64 arithmetic makes 0.
    assert_eq!(keys.iter().fold(0u64, |sum, _| sum.wrapping_add(1 << 57)), 0);
    assert_eq!(decide_at(&words(H, m(), &at(1 << 57)), m()), fallback_set());
    // The same 128 members at power 1 are a valid set.
    let full = decide_at(&words(H, m(), &at(1)), m());
    assert_eq!(full, candidate(keys.iter().map(|key| (*key, 1)).collect()));
    assert_eq!(full.members.len(), RECORD_COUNT);
}

#[test]
fn fallback_signs_with_power_one() {
    let set = decide_at(&words(H, m() - U256::from(1), &[(0, record(k1(), 5))]), m());
    assert_eq!(set.source, SignerSource::Fallback);
    assert_eq!(set.members.len(), 4);
    assert!(set.members.iter().all(|(_, power)| *power == 1));
    let keys: Vec<_> = set.members.iter().map(|(key, _)| *key).collect();
    assert_eq!(keys, fallback().keys());
}

#[test]
fn fallback_of_128_keys_is_allowed() {
    // A contract seat limit of 16 does not bound the fallback key set.
    let keys = FallbackKeys::new(sorted_keys(200..328)).unwrap();
    let set = decide(H, &words(H - 1, m(), &[(0, record(k1(), 5))]), m(), &keys);
    assert_eq!(set, SignerSet { source: SignerSource::Fallback, members: keys.validator_set() });
    assert_eq!(set.members.len(), 128);
}

#[test]
fn no_hysteresis() {
    let total_at = [(H, m()), (H + 1, m() - U256::from(1)), (H + 2, m())];
    let sources: Vec<_> = total_at
        .iter()
        .map(|(height, total)| {
            decide(*height, &words(*height, *total, &[(0, record(k1(), 5))]), m(), fallback())
                .source
        })
        .collect();
    assert_eq!(sources, [SignerSource::Candidate, SignerSource::Fallback, SignerSource::Candidate]);
}

#[test]
fn signer_source_serializes_in_lowercase() {
    assert_eq!(serde_json::to_value(SignerSource::Candidate).unwrap(), "candidate");
    assert_eq!(serde_json::to_value(SignerSource::Fallback).unwrap(), "fallback");
    assert!(serde_json::from_value::<SignerSource>("Candidate".into()).is_err());
}

/// Eight distinct keys for the records of generated snapshots.
fn pool() -> &'static [ConsensusKey] {
    static POOL: OnceLock<Vec<ConsensusKey>> = OnceLock::new();
    POOL.get_or_init(|| (1..9).map(test_key).collect())
}

fn any_word() -> impl Strategy<Value = U256> {
    any::<[u8; 32]>().prop_map(U256::from_be_bytes)
}

/// `value`, its neighbours, the extremes and an arbitrary word.
fn near(value: U256) -> impl Strategy<Value = U256> {
    prop_oneof![
        Just(value),
        Just(value.wrapping_sub(U256::from(1))),
        Just(value.wrapping_add(U256::from(1))),
        Just(U256::ZERO),
        Just(U256::MAX),
        any_word(),
    ]
}

/// A height with snapshot header words around it and a minimum total stake, near the
/// boundaries of the header check.
fn header() -> impl Strategy<Value = (u64, U256, U256, U256)> {
    let min_total_stake = prop_oneof![
        Just(U256::MAX),
        Just(U256::MAX - U256::from(1)),
        Just(U256::ZERO),
        Just(U256::from(1_000_000u64)),
        any_word(),
    ];
    (0..=UINT48_MAX, min_total_stake).prop_flat_map(|(height, min_total_stake)| {
        let at = U256::from(height);
        let snapshot_height = prop_oneof![near(at), Just(at | (U256::from(1) << 48))];
        (Just(height), snapshot_height, near(min_total_stake), Just(min_total_stake))
    })
}

proptest! {
    /// When the header words already make the candidate unusable, the records are never
    /// consulted: the decision equals the one for the same header with every seat empty.
    #[test]
    fn decide_ignores_records_when_the_header_already_rules_out_the_candidate(
        (height, snapshot_height, total_stake, min_total_stake) in header(),
        powers in vec(prop::option::of(1u64..=1_000), 8),
        last in prop::option::of((any_word(), any_word())),
    ) {
        prop_assume!(!needs_records(height, snapshot_height, total_stake, min_total_stake));
        let header_only = StakingWords::header_only(snapshot_height, total_stake);
        let mut snapshot = header_only.clone();
        for (seat, (key, power)) in pool().iter().zip(&powers).enumerate() {
            if let Some(power) = power {
                snapshot.records[seat] = record(*key, *power);
            }
        }
        if let Some((x, packed)) = last {
            snapshot.records[RECORD_COUNT - 1] = [x, packed];
        }
        prop_assert_eq!(
            decide(height, &snapshot, min_total_stake, fallback()),
            decide(height, &header_only, min_total_stake, fallback())
        );
    }
}

/// The set of keys `test_key(seed)` at the given powers.
fn set(members: &[(u64, u64)]) -> Vec<(ConsensusKey, u64)> {
    members.iter().map(|(seed, power)| (test_key(*seed), *power)).collect()
}

/// Updates are sorted by key and list each key once.
fn assert_sorted(updates: &[(ConsensusKey, u64)]) {
    assert!(updates.windows(2).all(|pair| pair[0].0 < pair[1].0), "{updates:?}");
}

#[test]
fn validator_updates_return_a_leaving_key_at_power_zero() {
    let old = set(&[(1, 2), (2, 3)]);
    assert_eq!(validator_updates(&old, &set(&[(2, 3)])), set(&[(1, 0)]));
}

#[test]
fn validator_updates_return_new_and_repowered_keys_at_their_power() {
    let old = set(&[(1, 2), (2, 3)]);
    let updates = validator_updates(&old, &set(&[(1, 2), (2, 4), (3, 5)]));
    assert_eq!(updates, ascending(set(&[(2, 4), (3, 5)])));
}

#[test]
fn validator_updates_omit_an_unchanged_key() {
    let old = set(&[(1, 2), (2, 3), (3, 4)]);
    let updates = validator_updates(&old, &set(&[(1, 2), (2, 5), (4, 6)]));
    assert_eq!(updates, ascending(set(&[(2, 5), (3, 0), (4, 6)])));
    assert!(updates.iter().all(|(key, _)| *key != test_key(1)));
}

#[test]
fn validator_updates_of_equal_sets_are_empty() {
    let members = set(&[(1, 2), (2, 3)]);
    assert_eq!(validator_updates(&members, &members), []);
    let keys = fallback().validator_set();
    assert_eq!(validator_updates(&keys, &keys), []);
}

#[test]
fn validator_updates_replace_a_candidate_with_the_fallback_keys() {
    let members = set(&[(1, 2), (2, 3), (3, 4)]);
    let keys = fallback().validator_set();
    let updates = validator_updates(&members, &keys);
    let mut expected: Vec<_> = members.iter().map(|(key, _)| (*key, 0)).collect();
    expected.extend(keys.iter().copied());
    assert_eq!(updates, ascending(expected));
}

#[test]
fn validator_updates_replace_the_fallback_keys_with_a_candidate() {
    let keys = fallback().validator_set();
    let members = set(&[(1, 2), (2, 3), (3, 4)]);
    let updates = validator_updates(&keys, &members);
    let mut expected: Vec<_> = keys.iter().map(|(key, _)| (*key, 0)).collect();
    expected.extend(members.iter().copied());
    assert_eq!(updates, ascending(expected));
}

#[test]
fn validator_updates_reweights_a_shared_key() {
    // K1 is a fallback key at power 1 and a candidate member at 250,000.
    let fallback_keys = vec![(k1(), 1), (test_key(1), 1)];
    let members = vec![(k1(), 250_000), (test_key(2), 7)];
    let updates = validator_updates(&fallback_keys, &members);
    let shared: Vec<_> = updates.iter().filter(|(key, _)| *key == k1()).collect();
    assert_eq!(shared, [&(k1(), 250_000)]);
    assert_eq!(updates, ascending(vec![(k1(), 250_000), (test_key(1), 0), (test_key(2), 7)]));
    // And back: the key is re-weighted to 1, again never removed.
    let back = validator_updates(&members, &fallback_keys);
    assert_eq!(back, ascending(vec![(k1(), 1), (test_key(1), 1), (test_key(2), 0)]));
}

#[test]
fn validator_updates_replace_128_members_with_128_others() {
    let old: Vec<_> = sorted_keys(0..128).into_iter().map(|key| (key, 1)).collect();
    let new: Vec<_> = sorted_keys(128..256).into_iter().map(|key| (key, 2)).collect();
    let updates = validator_updates(&old, &new);
    assert_eq!(updates.len(), 256);
    assert_sorted(&updates);
    assert_eq!(updates.iter().filter(|(_, power)| *power == 0).count(), 128);
    assert!(old.iter().all(|(key, _)| updates.contains(&(*key, 0))));
    assert!(new.iter().all(|member| updates.contains(member)));
}
