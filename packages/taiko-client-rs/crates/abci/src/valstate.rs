//! Stock CometBFT v0.40.0 validator-set arithmetic.
//!
//! [`ValState`] holds what CometBFT keeps after committing a height: `State.Validators`, which
//! signs the next height, and `State.NextValidators`, which signs the one after, each with its
//! proposer priorities and the index of its stored proposer (`ValidatorSet.Proposer`). The
//! private helpers port `types/validator_set.go` one for one, including its int64 wrapping,
//! clipping and division semantics; [`ValState::genesis`] follows `state.MakeGenesisState` and
//! [`ValState::advance`] follows `state/execution.go` `updateState`.
//!
//! CometBFT's `/validators` RPC is not a reference for this state: away from the heights it
//! stores in full, it rebuilds a set with one `IncrementProposerPriority(k)`, which rescales
//! once where the live state rescales at every height.
//!
//! [`ValState::encode`] is the state's ENC-A-29a preimage, [`ValState::hash`] its
//! `valStateHash` and [`ValState::decode`] the inverse of `encode`.

use crate::{
    committee::{tag, word},
    key::ConsensusKey,
};
use alloy_primitives::{Address, B256, keccak256};
use serde::{Deserialize, Serialize};

/// CometBFT's `MaxTotalVotingPower`, `MaxInt64 / 8`: the largest power and total power.
const MAX_TOTAL_VOTING_POWER: i64 = i64::MAX / 8;

/// CometBFT's `PriorityWindowSizeFactor`: priorities are rescaled into `2 · total power`.
const PRIORITY_WINDOW_SIZE_FACTOR: i64 = 2;

/// `bytes32("ETNA_VAL_STATE_V1")`: the domain tag of the validator-state preimage.
const VAL_STATE_TAG: B256 = tag(b"ETNA_VAL_STATE_V1");

/// The preimage's head words: the tag, the height, and an offset and a proposer index per set.
const HEAD_WORDS: usize = 6;

/// The ABI words of one `ValEntry`: ckPrefix, ckX, votingPower and proposerPriority.
const ENTRY_WORDS: usize = 4;

/// One validator of a set: its key, voting power and proposer priority.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ValEntry {
    /// The validator's consensus key.
    pub key: ConsensusKey,
    /// CometBFT's int64 voting power, positive in every set.
    pub power: i64,
    /// CometBFT's int64 proposer priority.
    pub priority: i64,
}

/// A CometBFT validator set with its stored proposer.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ValSet {
    /// The validators in CometBFT order: power descending, then `key.address()` ascending.
    pub entries: Vec<ValEntry>,
    /// The index in `entries` of the set's stored proposer (`ValidatorSet.Proposer`).
    pub proposer: usize,
}

impl ValSet {
    /// The stock native keys/powers commitment used by Comet header validator hashes.
    /// This excludes proposer priorities and the stored proposer index.
    pub fn validators_hash(&self) -> Result<B256, crate::key::KeyError> {
        crate::wire::validators_hash(
            &self
                .entries
                .iter()
                .map(|entry| crate::types::Member {
                    pubkey: entry.key,
                    power: entry.power as u64,
                    eff_stake: alloy_primitives::U256::ZERO,
                })
                .collect::<Vec<_>>(),
        )
    }
}

/// The validator state stock CometBFT holds after committing `height`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ValState {
    /// The committed height.
    pub height: u64,
    /// `State.Validators`, which signs `height + 1`.
    pub current: ValSet,
    /// `State.NextValidators`, which signs `height + 2`.
    pub next: ValSet,
}

/// A change set or genesis CometBFT v0.40.0 rejects, or a preimage [`ValState::decode`]
/// rejects. CometBFT halts on each change-set and genesis error, so the caller, which produced
/// the updates, must treat them as safety halts.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ValStateError {
    /// Two changes name the same validator.
    #[error("duplicate validator update for {key}")]
    Duplicate {
        /// The repeated key.
        key: ConsensusKey,
    },
    /// A power is negative as CometBFT's int64, i.e. a `u64` power of 2^63 or more.
    #[error("validator {key} has negative power {power}")]
    NegativePower {
        /// The validator's key.
        key: ConsensusKey,
        /// The power as CometBFT reads it.
        power: i64,
    },
    /// A power exceeds `MaxTotalVotingPower`.
    #[error("validator {key} power {power} exceeds {MAX_TOTAL_VOTING_POWER}")]
    PowerOverflow {
        /// The validator's key.
        key: ConsensusKey,
        /// The power.
        power: i64,
    },
    /// A removal names a validator that is not in the set.
    #[error("removal of {key}, which is not in the set")]
    UnknownRemoval {
        /// The removed key.
        key: ConsensusKey,
    },
    /// The result would be an empty set.
    #[error("the validator set would be empty")]
    EmptySet,
    /// The total power would exceed `MaxTotalVotingPower`.
    #[error("the total voting power would exceed {MAX_TOTAL_VOTING_POWER}")]
    TotalOverflow,
    /// A genesis member has power zero, which `NewValidatorSet` refuses.
    #[error("genesis validator {key} has power zero")]
    ZeroGenesisPower {
        /// The member's key.
        key: ConsensusKey,
    },
    /// The bytes are not a preimage [`ValState::decode`] accepts; the text names the violation
    /// found.
    #[error("malformed validator-state preimage: {0}")]
    Malformed(&'static str),
}

impl ValState {
    /// CometBFT's genesis state at `height`: `Validators = NewValidatorSet(members)` and
    /// `NextValidators = NewValidatorSet(members).CopyIncrementProposerPriority(1)`.
    pub fn genesis(height: u64, members: &[(ConsensusKey, u64)]) -> Result<Self, ValStateError> {
        // NewValidatorSet(nil) is an empty set without a proposer, which CometBFT refuses to
        // start from.
        if members.is_empty() {
            return Err(ValStateError::EmptySet);
        }
        let mut current = ValidatorSet::default();
        current.update_with_change_set(members, false)?;
        let current_proposer = current.increment_proposer_priority();
        let mut next = current.clone();
        let next_proposer = next.increment_proposer_priority();
        Ok(Self {
            height,
            current: current.into_val_set(current_proposer),
            next: next.into_val_set(next_proposer),
        })
    }

    /// The state after `height + 1`, whose FinalizeBlock returned `updates`
    /// (`committee::validator_updates`; same-power entries and zero-power removals included).
    pub fn advance(&self, updates: &[(ConsensusKey, u64)]) -> Result<Self, ValStateError> {
        let mut next = ValidatorSet::from_val_set(&self.next);
        if !updates.is_empty() {
            next.update_with_change_set(updates, true)?;
        }
        // IncrementProposerPriority panics on an empty set; CometBFT never holds one.
        if next.validators.is_empty() {
            return Err(ValStateError::EmptySet);
        }
        let proposer = next.increment_proposer_priority();
        Ok(Self {
            height: self.height + 1,
            // Copy() keeps the stored proposer.
            current: self.next.clone(),
            next: next.into_val_set(proposer),
        })
    }

    /// The ENC-A-29a preimage: `abi.encode(bytes32("ETNA_VAL_STATE_V1"), uint256(height),
    /// current, uint256(current.proposer), next, uint256(next.proposer))`, each set an
    /// `(uint8 ckPrefix, bytes32 ckX, uint64 votingPower, int64 proposerPriority)[]`. A power
    /// is written as its 64 bits, so only states with positive powers, as [`Self::genesis`]
    /// and [`Self::advance`] build, decode back.
    pub fn encode(&self) -> Vec<u8> {
        let set_words = |set: &ValSet| 1 + ENTRY_WORDS * set.entries.len();
        let next_offset = 32 * (HEAD_WORDS + set_words(&self.current));
        let mut out = Vec::with_capacity(next_offset + 32 * set_words(&self.next));
        let mut push = |w: B256| out.extend_from_slice(w.as_slice());
        push(VAL_STATE_TAG);
        push(word(self.height));
        push(word(32 * HEAD_WORDS));
        push(word(self.current.proposer));
        push(word(next_offset));
        push(word(self.next.proposer));
        for set in [&self.current, &self.next] {
            push(word(set.entries.len()));
            for e in &set.entries {
                push(word(e.key.prefix()));
                push(e.key.x());
                push(word(e.power as u64));
                push(int64_word(e.priority));
            }
        }
        out
    }

    /// ENC-A-29a's `valStateHash`: the keccak256 of [`Self::encode`].
    pub fn hash(&self) -> B256 {
        keccak256(self.encode())
    }

    /// The state whose [`Self::encode`] is exactly `bytes`. Each key must be a valid
    /// compressed secp256k1 point and each power a positive int64; each set must be in
    /// CometBFT order, power descending and then address ascending, without a repeated
    /// validator, and its proposer index must lie within it. Anything else is
    /// [`ValStateError::Malformed`].
    pub fn decode(bytes: &[u8]) -> Result<Self, ValStateError> {
        let (words, []) = bytes.as_chunks::<32>() else {
            return Err(ValStateError::Malformed("not a whole number of words"));
        };
        let Some((head, mut rest)) = words.split_first_chunk::<HEAD_WORDS>() else {
            return Err(ValStateError::Malformed("truncated head"));
        };
        // The high bytes of every word, the tag and the offsets are checked by re-encoding.
        let state = Self {
            height: low_u64(&head[1]),
            current: decode_set(&mut rest, low_u64(&head[3]))?,
            next: decode_set(&mut rest, low_u64(&head[5]))?,
        };
        if state.encode() != bytes {
            return Err(ValStateError::Malformed("not the canonical encoding"));
        }
        Ok(state)
    }

    /// The height of the preimage `bytes`, checking only its frame: whole words, the tag, a
    /// height word holding a `u64`, and head offsets and set lengths that span exactly `bytes`.
    /// Unlike [`Self::decode`] it reads no entry, so it checks no key, power, order or proposer
    /// index and costs no key decompression; it suits bytes [`Self::encode`] wrote, such as the
    /// app's own sidecars, whose readers authenticate the hash anyway.
    pub fn framed_height(bytes: &[u8]) -> Result<u64, ValStateError> {
        let (words, []) = bytes.as_chunks::<32>() else {
            return Err(ValStateError::Malformed("not a whole number of words"));
        };
        let Some((head, rest)) = words.split_first_chunk::<HEAD_WORDS>() else {
            return Err(ValStateError::Malformed("truncated head"));
        };
        // The words of the set whose length word is `rest[at]`: that word and its entries.
        let span = |at: usize| {
            let length = rest.get(at)?;
            let entries = usize::try_from(low_u64(length)).ok()?;
            (word(entries).0 == *length)
                .then_some(entries)?
                .checked_mul(ENTRY_WORDS)?
                .checked_add(1)
        };
        let current = span(0).ok_or(ValStateError::Malformed("set runs past the end"))?;
        let next = span(current).ok_or(ValStateError::Malformed("set runs past the end"))?;
        let height = low_u64(&head[1]);
        if head[0] != VAL_STATE_TAG.0 ||
            head[1] != word(height).0 ||
            head[2] != word(32 * HEAD_WORDS).0 ||
            head[4] != word(32 * (HEAD_WORDS + current)).0 ||
            current.checked_add(next) != Some(rest.len())
        {
            return Err(ValStateError::Malformed("not a validator-state preimage frame"));
        }
        Ok(height)
    }
}

/// Reads one set's array (its length, then its entries) from the front of `rest`, and checks
/// the entries and the `proposer` index as [`ValState::decode`] describes. Only the low eight
/// bytes of each integer word are read; the caller's re-encoding checks the rest.
fn decode_set(rest: &mut &[[u8; 32]], proposer: u64) -> Result<ValSet, ValStateError> {
    let (length, tail) = rest.split_first().ok_or(ValStateError::Malformed("truncated set"))?;
    let len = usize::try_from(low_u64(length))
        .ok()
        .filter(|&len| len <= tail.len() / ENTRY_WORDS)
        .ok_or(ValStateError::Malformed("set runs past the end"))?;
    let (entries, after) = tail.split_at(len * ENTRY_WORDS);
    *rest = after;
    let entries = entries
        .as_chunks::<ENTRY_WORDS>()
        .0
        .iter()
        .map(|[prefix, x, power, priority]| {
            let mut key = [0u8; 33];
            key[0] = prefix[31];
            key[1..].copy_from_slice(x);
            let key = ConsensusKey::from_slice(&key)
                .map_err(|_| ValStateError::Malformed("invalid consensus key"))?;
            let power = i64::from_be_bytes(low_bytes(power));
            if power <= 0 {
                return Err(ValStateError::Malformed("voting power is not a positive int64"));
            }
            Ok(ValEntry { key, power, priority: i64::from_be_bytes(low_bytes(priority)) })
        })
        .collect::<Result<Vec<_>, _>>()?;
    let mut addresses: Vec<Address> = entries.iter().map(|e| e.key.address()).collect();
    let in_order = entries
        .windows(2)
        .zip(addresses.windows(2))
        .all(|(e, a)| e[0].power > e[1].power || (e[0].power == e[1].power && a[0] < a[1]));
    if !in_order {
        return Err(ValStateError::Malformed("set is not in CometBFT order"));
    }
    addresses.sort_unstable();
    if addresses.windows(2).any(|a| a[0] == a[1]) {
        return Err(ValStateError::Malformed("repeated validator"));
    }
    let proposer = usize::try_from(proposer)
        .ok()
        .filter(|&p| p < entries.len())
        .ok_or(ValStateError::Malformed("proposer index outside the set"))?;
    Ok(ValSet { entries, proposer })
}

/// An `int64` ABI word: `value` sign-extended to 32 bytes, big-endian.
fn int64_word(value: i64) -> B256 {
    let mut out = [if value < 0 { 0xff } else { 0 }; 32];
    out[24..].copy_from_slice(&value.to_be_bytes());
    B256::new(out)
}

/// The low eight bytes of an ABI word.
fn low_bytes(word: &[u8; 32]) -> [u8; 8] {
    *word.last_chunk().expect("a word has 32 bytes")
}

/// The low eight bytes of an ABI word as an unsigned integer.
fn low_u64(word: &[u8; 32]) -> u64 {
    u64::from_be_bytes(low_bytes(word))
}

/// Go's `Validator` during the arithmetic, with the secp256k1eth address that orders sets and
/// breaks priority ties.
#[derive(Clone, Copy, Debug)]
struct Validator {
    /// `Address`.
    address: Address,
    /// `PubKey`.
    key: ConsensusKey,
    /// `VotingPower`.
    power: i64,
    /// `ProposerPriority`.
    priority: i64,
}

impl Validator {
    /// `NewValidator(key, power)`, with priority 0.
    fn new(key: ConsensusKey, power: i64) -> Self {
        Self { address: key.address(), key, power, priority: 0 }
    }
}

/// Go's `ValidatorSet` without its stored proposer, which only
/// [`ValidatorSet::increment_proposer_priority`] sets and the caller keeps as an index.
#[derive(Clone, Debug, Default)]
struct ValidatorSet {
    /// `Validators`.
    validators: Vec<Validator>,
}

impl ValidatorSet {
    /// The working copy of `set` (`Copy()`).
    fn from_val_set(set: &ValSet) -> Self {
        Self {
            validators: set
                .entries
                .iter()
                .map(|e| Validator {
                    address: e.key.address(),
                    key: e.key,
                    power: e.power,
                    priority: e.priority,
                })
                .collect(),
        }
    }

    /// The set with `proposer` as its stored proposer index.
    fn into_val_set(self, proposer: usize) -> ValSet {
        ValSet {
            entries: self
                .validators
                .into_iter()
                .map(|v| ValEntry { key: v.key, power: v.power, priority: v.priority })
                .collect(),
            proposer,
        }
    }

    /// `TotalVotingPower()`: the clipped sum of the powers (`updateTotalVotingPower`). Every
    /// set holds at most `MaxTotalVotingPower`, which `verifyUpdates` enforces.
    fn total_voting_power(&self) -> i64 {
        self.validators.iter().fold(0, |sum, v| safe_add_clip(sum, v.power))
    }

    /// `GetByAddressMut`: the validator with `address`.
    fn get_by_address(&self, address: Address) -> Option<&Validator> {
        self.validators.iter().find(|v| v.address == address)
    }

    /// `IncrementProposerPriority(1)`: rescales the priorities into `2 · total`, centres them
    /// on their average and runs one proposer round. Returns the proposer's index. The set
    /// must not be empty.
    fn increment_proposer_priority(&mut self) -> usize {
        let diff_max = PRIORITY_WINDOW_SIZE_FACTOR.wrapping_mul(self.total_voting_power());
        self.rescale_priorities(diff_max);
        self.shift_by_avg_proposer_priority();
        self.increment_once()
    }

    /// `RescalePriorities`: when the priorities spread wider than `diff_max`, divides each
    /// (truncating) by `ceil(diff / diff_max)`.
    fn rescale_priorities(&mut self, diff_max: i64) {
        if diff_max <= 0 {
            return;
        }
        let diff = self.compute_max_min_priority_diff();
        // Go's `(diff + diffMax - 1) / diffMax`, int64 wrapping; diff_max > 0.
        let ratio = diff.wrapping_add(diff_max).wrapping_sub(1) / diff_max;
        if diff > diff_max {
            // diff > diff_max > 0 makes ratio nonzero (at least 1, or negative after a wrap).
            for v in &mut self.validators {
                v.priority = v.priority.wrapping_div(ratio);
            }
        }
    }

    /// The unexported `incrementProposerPriority`: every priority gains its power, then the
    /// highest loses the total power and becomes the proposer, whose index is returned.
    fn increment_once(&mut self) -> usize {
        for v in &mut self.validators {
            v.priority = safe_add_clip(v.priority, v.power);
        }
        let most = self.get_val_with_most_priority();
        let total = self.total_voting_power();
        let proposer = &mut self.validators[most];
        proposer.priority = safe_sub_clip(proposer.priority, total);
        most
    }

    /// `computeAvgProposerPriority`: the big-integer sum divided by the size with
    /// `big.Int.Div`, which is Euclidean (the floor, for a positive size).
    fn compute_avg_proposer_priority(&self) -> i64 {
        let n = self.validators.len() as i128;
        let sum: i128 = self.validators.iter().map(|v| i128::from(v.priority)).sum();
        // The floor of a mean of int64 values lies between their minimum and maximum.
        sum.div_euclid(n) as i64
    }

    /// `computeMaxMinPriorityDiff`: `max - min` with int64 wrapping, negated (also wrapping)
    /// when negative.
    fn compute_max_min_priority_diff(&self) -> i64 {
        let max = self.validators.iter().map(|v| v.priority).max().unwrap_or(i64::MIN);
        let min = self.validators.iter().map(|v| v.priority).min().unwrap_or(i64::MAX);
        let diff = max.wrapping_sub(min);
        if diff < 0 { diff.wrapping_neg() } else { diff }
    }

    /// `getValWithMostPriority`: the index of the highest priority; of equal priorities, the
    /// smaller address wins (`CompareProposerPriority`).
    fn get_val_with_most_priority(&self) -> usize {
        let mut most = 0;
        for (i, v) in self.validators.iter().enumerate().skip(1) {
            let best = &self.validators[most];
            if v.priority > best.priority ||
                (v.priority == best.priority && v.address < best.address)
            {
                most = i;
            }
        }
        most
    }

    /// `shiftByAvgProposerPriority`: subtracts the average priority from each, clipping.
    fn shift_by_avg_proposer_priority(&mut self) {
        let avg = self.compute_avg_proposer_priority();
        for v in &mut self.validators {
            v.priority = safe_sub_clip(v.priority, avg);
        }
    }

    /// `updateWithChangeSet`: validates `changes`, prices new members, merges updates and
    /// removals in address order, rescales and centres the priorities and re-sorts the set by
    /// power, then address. On an error the set is unchanged. `allow_deletes` is false for
    /// `NewValidatorSet`, which refuses zero powers.
    fn update_with_change_set(
        &mut self,
        changes: &[(ConsensusKey, u64)],
        allow_deletes: bool,
    ) -> Result<(), ValStateError> {
        if changes.is_empty() {
            return Ok(());
        }
        let (mut updates, deletes) = process_changes(changes)?;
        if let Some(zero) = deletes.first().filter(|_| !allow_deletes) {
            return Err(ValStateError::ZeroGenesisPower { key: zero.key });
        }
        if num_new_validators(&updates, self) == 0 && self.validators.len() == deletes.len() {
            return Err(ValStateError::EmptySet);
        }
        let removed_power = verify_removals(&deletes, self)?;
        let tvp_after_updates_before_removals = verify_updates(&updates, self, removed_power)?;
        compute_new_priorities(&mut updates, self, tvp_after_updates_before_removals);
        self.apply_updates(&updates);
        self.apply_removals(&deletes);
        // Go's updateTotalVotingPower cannot fail here: verify_updates bounded the total.
        let diff_max = PRIORITY_WINDOW_SIZE_FACTOR.wrapping_mul(self.total_voting_power());
        self.rescale_priorities(diff_max);
        self.shift_by_avg_proposer_priority();
        self.validators.sort_by(|a, b| b.power.cmp(&a.power).then(a.address.cmp(&b.address)));
        Ok(())
    }

    /// `applyUpdates`: sorts the set by address and merges `updates` (sorted by address, with
    /// their priorities computed) into it; an update replaces the validator with its address.
    fn apply_updates(&mut self, updates: &[Validator]) {
        let mut existing = std::mem::take(&mut self.validators);
        existing.sort_by_key(|v| v.address);
        let mut merged = Vec::with_capacity(existing.len() + updates.len());
        let (mut i, mut j) = (0, 0);
        while i < existing.len() && j < updates.len() {
            if existing[i].address < updates[j].address {
                merged.push(existing[i]);
                i += 1;
            } else {
                if existing[i].address == updates[j].address {
                    i += 1;
                }
                merged.push(updates[j]);
                j += 1;
            }
        }
        merged.extend_from_slice(&existing[i..]);
        merged.extend_from_slice(&updates[j..]);
        self.validators = merged;
    }

    /// `applyRemovals`: drops the verified `deletes` (sorted by address) from the set, which
    /// `apply_updates` left sorted by address.
    fn apply_removals(&mut self, deletes: &[Validator]) {
        let mut next = 0;
        self.validators.retain(|v| {
            let removed = deletes.get(next).is_some_and(|d| d.address == v.address);
            next += usize::from(removed);
            !removed
        });
    }
}

/// `safeAddClip`: `a + b`, clipped to the int64 range.
fn safe_add_clip(a: i64, b: i64) -> i64 {
    a.saturating_add(b)
}

/// `safeSubClip`: `a - b`, clipped to the int64 range.
fn safe_sub_clip(a: i64, b: i64) -> i64 {
    a.saturating_sub(b)
}

/// `processChanges`: sorts copies of the changes by address, scans them for a repeated
/// address, a negative power or one above `MaxTotalVotingPower`, and splits the rest into
/// updates and zero-power removals. A `u64` power reaches CometBFT as protobuf int64, the same
/// 64 bits, so 2^63 and above are negative. Go's `sort.Sort` is not stable, so when a repeated
/// address also carries an invalid power, Go may report a different one of these errors; both
/// reject the change set.
fn process_changes(
    changes: &[(ConsensusKey, u64)],
) -> Result<(Vec<Validator>, Vec<Validator>), ValStateError> {
    let mut changes: Vec<Validator> =
        changes.iter().map(|&(key, power)| Validator::new(key, power as i64)).collect();
    changes.sort_by_key(|v| v.address);
    let mut updates = Vec::with_capacity(changes.len());
    let mut removals = Vec::with_capacity(changes.len());
    let mut prev: Option<Address> = None;
    for change in changes {
        if prev == Some(change.address) {
            return Err(ValStateError::Duplicate { key: change.key });
        }
        match change.power {
            power if power < 0 => {
                return Err(ValStateError::NegativePower { key: change.key, power });
            }
            power if power > MAX_TOTAL_VOTING_POWER => {
                return Err(ValStateError::PowerOverflow { key: change.key, power });
            }
            0 => removals.push(change),
            _ => updates.push(change),
        }
        prev = Some(change.address);
    }
    Ok((updates, removals))
}

/// `verifyUpdates`: applies the power deltas in ascending order to the total after removals
/// and rejects any running total above `MaxTotalVotingPower`. Returns the total after the
/// updates but before the removals, which prices new members.
fn verify_updates(
    updates: &[Validator],
    vals: &ValidatorSet,
    removed_power: i64,
) -> Result<i64, ValStateError> {
    let mut deltas: Vec<i64> = updates
        .iter()
        .map(|u| match vals.get_by_address(u.address) {
            Some(v) => u.power.wrapping_sub(v.power),
            None => u.power,
        })
        .collect();
    deltas.sort_unstable();
    let mut tvp_after_removals = vals.total_voting_power().wrapping_sub(removed_power);
    for delta in deltas {
        tvp_after_removals = tvp_after_removals.wrapping_add(delta);
        if tvp_after_removals > MAX_TOTAL_VOTING_POWER {
            return Err(ValStateError::TotalOverflow);
        }
    }
    Ok(tvp_after_removals.wrapping_add(removed_power))
}

/// `numNewValidators`: how many updates name validators outside `vals`.
fn num_new_validators(updates: &[Validator], vals: &ValidatorSet) -> usize {
    updates.iter().filter(|u| vals.get_by_address(u.address).is_none()).count()
}

/// `computeNewPriorities`: a new member starts at `-(P + (P >> 3))`, P being the total after
/// the updates and before the removals; an existing validator keeps its priority.
fn compute_new_priorities(updates: &mut [Validator], vals: &ValidatorSet, updated_total: i64) {
    for update in updates {
        update.priority = match vals.get_by_address(update.address) {
            Some(existing) => existing.priority,
            None => updated_total.wrapping_add(updated_total >> 3).wrapping_neg(),
        };
    }
}

/// `verifyRemovals`: every removal names a validator of `vals`. Returns their total power.
fn verify_removals(deletes: &[Validator], vals: &ValidatorSet) -> Result<i64, ValStateError> {
    let mut removed_power: i64 = 0;
    for delete in deletes {
        let existing = vals
            .get_by_address(delete.address)
            .ok_or(ValStateError::UnknownRemoval { key: delete.key })?;
        removed_power = removed_power.wrapping_add(existing.power);
    }
    Ok(removed_power)
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::hex;
    use serde::Deserialize;

    #[derive(Deserialize)]
    #[serde(deny_unknown_fields)]
    struct Vectors {
        source: String,
        /// The fixture keys of seeds 1..255 (stock `GenPrivKeySecp256k1Eth`), so index i is
        /// seed i + 1.
        keys: Vec<ConsensusKey>,
        cases: Vec<Case>,
    }

    #[derive(Deserialize)]
    #[serde(deny_unknown_fields)]
    struct Case {
        name: String,
        steps: Vec<Step>,
        rpc_rebuild: Option<RpcRebuild>,
    }

    /// The state after one height, or the stock Go error its updates raise. `updates` holds
    /// comma-separated `key:power` items and each set comma-separated `key:power:priority`
    /// items in set order, `key` indexing [`Vectors::keys`].
    #[derive(Deserialize)]
    #[serde(deny_unknown_fields)]
    struct Step {
        updates: String,
        height: Option<u64>,
        current: Option<String>,
        current_proposer: Option<usize>,
        next: Option<String>,
        next_proposer: Option<usize>,
        error: Option<String>,
    }

    /// What `LoadValidators` returns for the live `next` at `step`.
    #[derive(Deserialize)]
    #[serde(deny_unknown_fields)]
    struct RpcRebuild {
        seed: u64,
        change_step: usize,
        step: usize,
        blocks: usize,
        bulk_priorities: String,
        bulk_proposer: usize,
    }

    fn vectors() -> Vectors {
        serde_json::from_str(include_str!("../testdata/cometbft-v0.40-valstate/vectors.json"))
            .unwrap()
    }

    /// The `N` colon-separated integers of each comma-separated item of `list`.
    fn items<const N: usize>(list: &str) -> Vec<[i64; N]> {
        if list.is_empty() {
            return Vec::new();
        }
        list.split(',')
            .map(|item| {
                let fields: Vec<i64> = item.split(':').map(|f| f.parse().unwrap()).collect();
                fields.try_into().unwrap()
            })
            .collect()
    }

    /// Go's int64 powers reach the `u64` API as the same 64 bits (`negative_power` holds -1).
    fn updates(keys: &[ConsensusKey], step: &Step) -> Vec<(ConsensusKey, u64)> {
        items(&step.updates)
            .into_iter()
            .map(|[k, power]| (keys[k as usize], power as u64))
            .collect()
    }

    fn set(keys: &[ConsensusKey], entries: &str, proposer: usize) -> ValSet {
        ValSet {
            entries: items(entries)
                .into_iter()
                .map(|[k, power, priority]| ValEntry { key: keys[k as usize], power, priority })
                .collect(),
            proposer,
        }
    }

    fn expected(keys: &[ConsensusKey], step: &Step) -> ValState {
        ValState {
            height: step.height.unwrap(),
            current: set(keys, step.current.as_ref().unwrap(), step.current_proposer.unwrap()),
            next: set(keys, step.next.as_ref().unwrap(), step.next_proposer.unwrap()),
        }
    }

    /// Genesis from the first step, then one `advance` per later step, stopping at an error.
    fn replay(keys: &[ConsensusKey], case: &Case) -> Vec<Result<ValState, ValStateError>> {
        let mut out: Vec<Result<ValState, ValStateError>> = Vec::new();
        for step in &case.steps {
            let updates = updates(keys, step);
            let result = match out.last() {
                None => ValState::genesis(step.height.unwrap_or_default(), &updates),
                Some(Ok(state)) => state.advance(&updates),
                Some(Err(_)) => break,
            };
            out.push(result);
        }
        out
    }

    /// Whether `err` is the variant of the stock Go error `go`, naming the same validator.
    fn matches_go_error(err: &ValStateError, go: &str) -> bool {
        let names = |key: &ConsensusKey| go.contains(&hex::encode_upper(key.address()));
        match err {
            ValStateError::Duplicate { key } => go.starts_with("duplicate entry") && names(key),
            ValStateError::NegativePower { power, .. } => {
                go == format!("voting power can't be negative: {power}")
            }
            ValStateError::PowerOverflow { power, .. } => {
                go.starts_with("to prevent clipping/overflow") && go.ends_with(&format!(" {power}"))
            }
            ValStateError::UnknownRemoval { key } => {
                go.starts_with("failed to find validator") && names(key)
            }
            ValStateError::EmptySet => {
                go == "applying the validator changes would result in empty set"
            }
            ValStateError::TotalOverflow => {
                go.starts_with("total voting power of resulting valset exceeds max")
            }
            ValStateError::ZeroGenesisPower { key } => {
                go.starts_with(
                    "Cannot create validator set: cannot process validators with voting power 0",
                ) && names(key)
            }
            ValStateError::Malformed(_) => false,
        }
    }

    #[test]
    fn every_go_vector_step_replays_exactly() {
        let vectors = vectors();
        assert!(vectors.source.starts_with("github.com/cometbft/cometbft v0.40.0 "));
        let mut names: Vec<&str> = vectors.cases.iter().map(|c| c.name.as_str()).collect();
        names.sort_unstable();
        let mut want = vec![
            "genesis_1",
            "genesis_4",
            "genesis_120",
            "added_member_ends_lowest",
            "stored_proposer_removed",
            "power_only_change",
            "same_power_update",
            "rescale_trigger",
            "priority_ties",
            "near_max_total",
            "full_replacement",
            "rpc_rebuild_diverges",
            "duplicate_update",
            "remove_unknown",
            "remove_all",
            "negative_power",
            "power_overflow",
            "total_overflow",
            "genesis_zero_power",
            "random_0",
            "random_1",
            "random_2",
            "random_3",
            "random_4",
            "random_5",
            "random_6",
            "random_7",
        ];
        want.sort_unstable();
        assert_eq!(names, want);

        let mut errors = 0;
        for case in &vectors.cases {
            let replayed = replay(&vectors.keys, case);
            assert_eq!(
                replayed.len(),
                case.steps.len(),
                "{}: an error ended the replay early",
                case.name
            );
            for (i, (step, result)) in case.steps.iter().zip(replayed).enumerate() {
                match (&step.error, result) {
                    (None, Ok(state)) => {
                        assert_eq!(state, expected(&vectors.keys, step), "{} step {i}", case.name)
                    }
                    (Some(go), Err(err)) => {
                        assert!(
                            matches_go_error(&err, go),
                            "{} step {i}: {err:?} vs {go}",
                            case.name
                        );
                        errors += 1;
                    }
                    (go, result) => panic!("{} step {i}: Go {go:?}, Rust {result:?}", case.name),
                }
            }
        }
        assert_eq!(errors, 7);
    }

    #[test]
    fn rpc_rebuild_is_not_the_live_state() {
        let vectors = vectors();
        let case = vectors.cases.iter().find(|c| c.name == "rpc_rebuild_diverges").unwrap();
        let rpc = case.rpc_rebuild.as_ref().unwrap();
        assert_eq!(rpc.step, rpc.change_step + rpc.blocks);
        assert!(!case.steps[rpc.change_step].updates.is_empty());
        assert!(case.steps[rpc.change_step + 1..=rpc.step].iter().all(|s| s.updates.is_empty()));

        let live = replay(&vectors.keys, case).swap_remove(rpc.step).unwrap();
        assert_eq!(live, expected(&vectors.keys, &case.steps[rpc.step]));
        let live_priorities: Vec<i64> = live.next.entries.iter().map(|e| e.priority).collect();
        let bulk: Vec<i64> = rpc.bulk_priorities.split(',').map(|p| p.parse().unwrap()).collect();
        assert_eq!(bulk.len(), live_priorities.len());
        assert_ne!(bulk, live_priorities, "seed {}: the rebuild matches the live state", rpc.seed);
        assert!(rpc.bulk_proposer < bulk.len());
    }

    #[test]
    fn entries_are_in_comet_order() {
        let vectors = vectors();
        for case in &vectors.cases {
            for state in replay(&vectors.keys, case).into_iter().flatten() {
                for set in [&state.current, &state.next] {
                    assert!(set.proposer < set.entries.len(), "{}", case.name);
                    for pair in set.entries.windows(2) {
                        let (a, b) = (&pair[0], &pair[1]);
                        assert!(
                            a.power > b.power ||
                                (a.power == b.power && a.key.address() < b.key.address()),
                            "{}: {a:?} before {b:?}",
                            case.name
                        );
                    }
                }
            }
        }
    }

    /// `validator_states[0]` (`ENC-A-29a.l`) in the protocol's schema-6 vectors
    /// (`testdata/etna_vectors/vectors.json`), read from the file, so a re-pin that changes the
    /// encoding fails here.
    const SHARED_VECTOR: &str = "/validator_states/0";

    /// The vector [`SHARED_VECTOR`]'s field `name`.
    fn shared_field(name: &str) -> String {
        format!("{SHARED_VECTOR}/{name}")
    }

    /// The state of [`SHARED_VECTOR`].
    fn shared_vector_state() -> ValState {
        use crate::test_utils::vectors::{b256_at, len_at, str_at, u64_at, usize_at};
        let set = |name: &str| ValSet {
            entries: (0..len_at(&shared_field(name)))
                .map(|i| {
                    let field = |field: &str| shared_field(&format!("{name}/{i}/{field}"));
                    let prefix = u8::try_from(u64_at(&field("ck_prefix"))).unwrap();
                    let x = b256_at(&field("ck_x"));
                    ValEntry {
                        key: ConsensusKey::from_slice(&[&[prefix][..], x.as_slice()].concat())
                            .unwrap(),
                        power: str_at(&field("voting_power")).parse().unwrap(),
                        priority: str_at(&field("proposer_priority")).parse().unwrap(),
                    }
                })
                .collect(),
            proposer: usize_at(&shared_field(&format!("{name}_proposer"))),
        };
        ValState {
            height: u64_at(&shared_field("height")),
            current: set("current"),
            next: set("next"),
        }
    }

    #[test]
    fn hash_matches_the_shared_enc_a_29a_vector() {
        use crate::test_utils::vectors::{b256_at, str_at};
        assert_eq!(str_at(&shared_field("name")), "ENC-A-29a.l");
        let mut state = shared_vector_state();
        let preimage = hex::decode(str_at(&shared_field("preimage"))).unwrap();
        assert_eq!(state.encode(), preimage);
        assert_eq!(ValState::decode(&preimage), Ok(state.clone()));
        assert_eq!(ValState::framed_height(&preimage), Ok(state.height));
        assert_eq!(state.hash(), b256_at(&shared_field("hash")));
        // The generator's proposer changes: current 0 with next 0, then current 1 with next 1.
        state.current.proposer = 0;
        state.next.proposer = 0;
        assert_eq!(state.hash(), b256_at(&shared_field("changed_current_proposer_hash")));
        state.current.proposer = 1;
        state.next.proposer = 1;
        assert_eq!(state.hash(), b256_at(&shared_field("changed_next_proposer_hash")));
    }

    #[test]
    fn encode_decode_round_trips_every_go_vector_state() {
        let vectors = vectors();
        let mut states = 0;
        for case in &vectors.cases {
            for state in replay(&vectors.keys, case).into_iter().flatten() {
                let bytes = state.encode();
                let entries = state.current.entries.len() + state.next.entries.len();
                assert_eq!(bytes.len(), 32 * (8 + 4 * entries), "{}", case.name);
                assert_eq!(ValState::decode(&bytes), Ok(state.clone()), "{}", case.name);
                assert_eq!(ValState::framed_height(&bytes), Ok(state.height), "{}", case.name);
                assert_eq!(state.hash(), keccak256(&bytes), "{}", case.name);
                states += 1;
            }
        }
        assert!(states > 100, "only {states} states");
    }

    /// [`ValState::decode`] rejects every non-canonical preimage; [`ValState::framed_height`]
    /// rejects those whose frame is broken and, reading no entry, accepts the others.
    #[test]
    fn decode_rejects_non_canonical_bytes() {
        let state = shared_vector_state();
        let k1 = state.current.entries[0].key;
        let bytes = state.encode();
        // Word indexes: the head is 0..6, the current length 6, current entry i's ckPrefix,
        // ckX, votingPower and proposerPriority 7 + 4i..11 + 4i.
        let with_word = |index: usize, value: B256| {
            let mut out = bytes.clone();
            out[32 * index..32 * (index + 1)].copy_from_slice(value.as_slice());
            out
        };
        let with_state = |edit: &dyn Fn(&mut ValState)| {
            let mut edited = state.clone();
            edit(&mut edited);
            edited.encode()
        };
        let mut trailing_byte = bytes.clone();
        trailing_byte.push(0);
        let trailing_word = [&bytes[..], &[0; 32]].concat();
        let mut height_above_u64 = word(state.height);
        height_above_u64.0[23] = 1;
        // (name, bytes, whether the frame is broken)
        let cases = [
            ("wrong tag", with_word(0, tag(b"ETNA_VAL_STATE_V2")), true),
            ("height above u64", with_word(1, height_above_u64), true),
            ("wrong current offset", with_word(2, word(0xe0)), true),
            ("wrong next offset", with_word(4, word(0x1e0 + 32)), true),
            ("trailing byte", trailing_byte, true),
            ("trailing word", trailing_word, true),
            ("truncated", bytes[..bytes.len() - 32].to_vec(), true),
            ("huge length", with_word(6, B256::repeat_byte(0xff)), true),
            ("unsorted pair", with_state(&|s| s.current.entries.swap(0, 1)), false),
            (
                "duplicate key",
                with_state(&|s| s.current.entries[1] = ValEntry { key: k1, power: 9, priority: 0 }),
                false,
            ),
            ("prefix byte 4", with_word(7, word(4)), false),
            ("power 0", with_state(&|s| s.current.entries[1].power = 0), false),
            ("power above int64", with_word(9, word(u64::MAX)), false),
            ("current proposer index = len", with_state(&|s| s.current.proposer = 2), false),
            ("next proposer index = len", with_state(&|s| s.next.proposer = 2), false),
            // current[0]'s priority -5 zero-extended, as a uint64 would be written.
            ("priority not sign-extended", with_word(10, word((-5i64) as u64)), false),
        ];
        for (name, bytes, frame) in cases {
            assert!(
                matches!(ValState::decode(&bytes), Err(ValStateError::Malformed(_))),
                "{name}: {:?}",
                ValState::decode(&bytes)
            );
            let framed = ValState::framed_height(&bytes);
            if frame {
                assert!(matches!(framed, Err(ValStateError::Malformed(_))), "{name}: {framed:?}");
            } else {
                assert_eq!(framed, Ok(state.height), "{name}");
            }
        }
    }

    #[test]
    fn clipping_helpers_saturate_like_go() {
        // safeAddClip: an overflow clips to MinInt64 for a negative b, else to MaxInt64.
        assert_eq!(safe_add_clip(i64::MAX, 1), i64::MAX);
        assert_eq!(safe_add_clip(i64::MAX - 1, 1), i64::MAX);
        assert_eq!(safe_add_clip(1, i64::MAX), i64::MAX);
        assert_eq!(safe_add_clip(i64::MIN, -1), i64::MIN);
        assert_eq!(safe_add_clip(i64::MIN + 1, -1), i64::MIN);
        assert_eq!(safe_add_clip(i64::MIN, i64::MIN), i64::MIN);
        assert_eq!(safe_add_clip(i64::MAX, i64::MIN), -1);
        // safeSubClip: an overflow clips to MinInt64 for a positive b, else to MaxInt64.
        assert_eq!(safe_sub_clip(i64::MIN, 1), i64::MIN);
        assert_eq!(safe_sub_clip(i64::MIN + 1, 1), i64::MIN);
        assert_eq!(safe_sub_clip(i64::MIN, i64::MAX), i64::MIN);
        assert_eq!(safe_sub_clip(i64::MAX, -1), i64::MAX);
        assert_eq!(safe_sub_clip(0, i64::MIN), i64::MAX);
        assert_eq!(safe_sub_clip(-1, i64::MIN), i64::MAX);
        assert_eq!(safe_sub_clip(i64::MIN, i64::MIN), 0);
    }
}
