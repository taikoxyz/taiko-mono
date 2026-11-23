//! The signing set decision: at every block H from a generation's start height + 1 on, which set
//! signs H + 2, and the validator updates that install it.
//!
//! The candidate is the snapshot that H's block-start call stored in the staking contract, read
//! from H's post-state ([`StakingWords`](crate::staking::StakingWords)). It signs H + 2 when it is
//! usable: the minimum total stake M that H's anchor proves is not `2^256 − 1`, its
//! `snapshotHeight` equals H in all 256 bits, its `snapshotTotalStake` is at least M and its
//! records form a valid set. Otherwise the fallback key set whose hash H's anchor proves signs in
//! its place, each key at power 1. The choice is made again at every block, with no hysteresis,
//! and an unusable candidate is never a fault: [`Unusable`] only names the condition it fails.
//!
//! A generation's first two blocks are signed by the fallback keys of its origin record whatever
//! the candidate is; callers apply that rule and authenticate every input themselves.

use crate::{
    fallback::FallbackKeys, key::ConsensusKey, params::MAX_SET_MEMBERS, staking::StakingWords,
};
use alloc::{collections::BTreeMap, vec::Vec};
use alloy_primitives::{B256, U256, ruint::UintTryFrom};
use serde::{Deserialize, Serialize};

/// Upper bound on a set's total voting power: CometBFT's `MaxTotalVotingPower`,
/// `(2^63 − 1) / 8`.
pub const MAX_TOTAL_POWER: u64 = (i64::MAX as u64) / 8;

/// Where the set that signs a block comes from.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SignerSource {
    /// The usable candidate snapshot, each member at the power its seat record stores.
    Candidate,
    /// The DAO fallback key set, each key at power 1.
    Fallback,
}

/// The set that signs a block, and where it comes from.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SignerSet {
    /// Whether the candidate or the fallback key set signs.
    pub source: SignerSource,
    /// The keys and their voting powers in ascending key order: 1 to [`MAX_SET_MEMBERS`]
    /// distinct keys, each at power 1 or more, together at most [`MAX_TOTAL_POWER`].
    pub members: Vec<(ConsensusKey, u64)>,
}

/// Why a candidate snapshot is not usable at a height: the first usability condition it fails,
/// in the order [`candidate_members`] checks them.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Unusable {
    /// The minimum total stake is `2^256 − 1`, with which the DAO hands every block to the
    /// fallback key set whatever the snapshot holds.
    MinTotalStakeMax,
    /// `snapshotHeight` differs from the height in some bit: the height's own block-start call
    /// did not write the snapshot, for example because it failed.
    StaleSnapshot,
    /// `snapshotTotalStake` is below the minimum total stake.
    BelowMinTotalStake,
    /// The records form no valid set: a malformed record, a power of 0, a repeated key, no
    /// member, or powers whose sum exceeds [`MAX_TOTAL_POWER`].
    InvalidSet,
}

/// Whether the candidate's header words leave it usable at `height`, so that its records decide:
/// the minimum total stake is not `2^256 − 1`, `snapshot_height` equals `height` in all 256 bits
/// and `total_stake` is at least the minimum. When this is false the candidate is unusable
/// whatever its records hold, and a caller need not read them.
pub fn needs_records(
    height: u64,
    snapshot_height: U256,
    total_stake: U256,
    min_total_stake: U256,
) -> bool {
    check_header(height, snapshot_height, total_stake, min_total_stake).is_ok()
}

/// The members of the candidate `words` when it is usable at `height` under the minimum total
/// stake `min_total_stake`, in ascending key order; `None` when it is not
/// ([`candidate_members`]).
pub fn usable_candidate(
    height: u64,
    words: &StakingWords,
    min_total_stake: U256,
) -> Option<Vec<(ConsensusKey, u64)>> {
    candidate_members(height, words, min_total_stake).ok()
}

/// The members of the candidate `words` when it is usable at `height` under the minimum total
/// stake `min_total_stake`, in ascending key order, or the first condition it fails.
///
/// Beyond [`needs_records`], every record must be an empty seat (both words zero) or hold a
/// member: its second word packs `ckPrefix` in bits 0–7 and a power of at least 1 in bits 8–71
/// with every other bit zero, and `ckPrefix ‖ ckX` is a valid compressed key. All 128 records
/// count, whatever the contract's seat limit is. The members' keys are distinct, there are 1 to
/// [`MAX_SET_MEMBERS`] of them, and their powers' exact sum is at most [`MAX_TOTAL_POWER`].
/// Powers are used as stored; no record is dropped or rescaled to make the set valid.
pub fn candidate_members(
    height: u64,
    words: &StakingWords,
    min_total_stake: U256,
) -> Result<Vec<(ConsensusKey, u64)>, Unusable> {
    check_header(height, words.snapshot_height, words.total_stake, min_total_stake)?;
    let mut members = Vec::new();
    for [x, packed] in &words.records {
        if x.is_zero() && packed.is_zero() {
            continue;
        }
        members.push(decode_member(*x, *packed).ok_or(Unusable::InvalidSet)?);
    }
    members.sort_unstable();
    let distinct = members.windows(2).all(|pair| pair[0].0 != pair[1].0);
    // At most 128 powers below 2^64 each: the exact sum fits a u128.
    let total: u128 = members.iter().map(|(_, power)| u128::from(*power)).sum();
    if distinct &&
        (1..=MAX_SET_MEMBERS).contains(&members.len()) &&
        total <= u128::from(MAX_TOTAL_POWER)
    {
        Ok(members)
    } else {
        Err(Unusable::InvalidSet)
    }
}

/// The first header condition of usability at `height` that the snapshot words fail, in the
/// order of [`Unusable`]'s variants.
fn check_header(
    height: u64,
    snapshot_height: U256,
    total_stake: U256,
    min_total_stake: U256,
) -> Result<(), Unusable> {
    if min_total_stake == U256::MAX {
        Err(Unusable::MinTotalStakeMax)
    } else if snapshot_height != U256::from(height) {
        Err(Unusable::StaleSnapshot)
    } else if total_stake < min_total_stake {
        Err(Unusable::BelowMinTotalStake)
    } else {
        Ok(())
    }
}

/// The set that signs `height + 2`, decided at `height` from the candidate snapshot `words` that
/// `height`'s block-start call stored, and the minimum total stake and fallback key list that
/// `height`'s anchor proves: the usable candidate ([`usable_candidate`]), otherwise `fallback`
/// with each key at power 1.
pub fn decide(
    height: u64,
    words: &StakingWords,
    min_total_stake: U256,
    fallback: &FallbackKeys,
) -> SignerSet {
    match usable_candidate(height, words, min_total_stake) {
        Some(members) => SignerSet { source: SignerSource::Candidate, members },
        None => SignerSet { source: SignerSource::Fallback, members: fallback.validator_set() },
    }
}

/// The native key/power updates that turn `old`, the set that signs H + 1, into `new`, the set
/// that signs H + 2, sorted by key: a key that leaves is returned with power 0, a new key or one
/// whose power changes with its new power, and a key whose power stays the same is not returned.
/// A key in both sets at different powers, such as a fallback key that is also a candidate
/// member, is re-weighted by one entry and never removed. Equal sets give no updates.
pub fn validator_updates(
    old: &[(ConsensusKey, u64)],
    new: &[(ConsensusKey, u64)],
) -> Vec<(ConsensusKey, u64)> {
    let (old, new): (BTreeMap<_, _>, BTreeMap<_, _>) =
        (old.iter().copied().collect(), new.iter().copied().collect());
    let mut updates: BTreeMap<ConsensusKey, u64> =
        old.keys().filter(|key| !new.contains_key(*key)).map(|key| (*key, 0)).collect();
    updates.extend(new.into_iter().filter(|(key, power)| old.get(key) != Some(power)));
    updates.into_iter().collect()
}

/// The member a seat record that is not empty holds, or `None` when the record is malformed: a
/// second word other than `ckPrefix | power << 8`, a power of 0, or a `ckPrefix ‖ ckX` that is no
/// valid compressed key.
fn decode_member(x: U256, packed: U256) -> Option<(ConsensusKey, u64)> {
    let prefix = packed.byte(0);
    let power = (packed >> 8usize).wrapping_to::<u64>();
    if packed != U256::from(prefix) | (U256::from(power) << 8usize) || power == 0 {
        return None;
    }
    let mut bytes = [0u8; 33];
    bytes[0] = prefix;
    bytes[1..].copy_from_slice(&x.to_be_bytes::<32>());
    Some((ConsensusKey::from_slice(&bytes).ok()?, power))
}

/// One `abi.encode` word: the unsigned integer `value` left-padded to 32 bytes, big-endian.
pub fn word<T>(value: T) -> B256
where
    U256: UintTryFrom<T>,
{
    B256::from(U256::from(value))
}

/// A `bytes32` domain tag: the ASCII `name`, right-padded with zero bytes (at most 32 bytes).
pub const fn tag(name: &[u8]) -> B256 {
    let mut out = [0u8; 32];
    let mut i = 0;
    while i < name.len() {
        out[i] = name[i];
        i += 1;
    }
    B256::new(out)
}

#[cfg(test)]
#[path = "committee_tests.rs"]
mod tests;
