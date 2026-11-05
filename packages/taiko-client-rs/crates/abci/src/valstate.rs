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

use crate::key::ConsensusKey;
use alloy_primitives::Address;
use serde::{Deserialize, Serialize};

/// CometBFT's `MaxTotalVotingPower`, `MaxInt64 / 8`: the largest power and total power.
const MAX_TOTAL_VOTING_POWER: i64 = i64::MAX / 8;

/// CometBFT's `PriorityWindowSizeFactor`: priorities are rescaled into `2 · total power`.
const PRIORITY_WINDOW_SIZE_FACTOR: i64 = 2;

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

/// A change set or genesis CometBFT v0.40.0 rejects. CometBFT halts on each of these, so the
/// caller, which produced the updates, must treat them as safety halts.
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

/// `processChanges`: sorts copies of the changes by address (stably), rejects a repeated
/// address, a negative power or one above `MaxTotalVotingPower` in that order, and splits the
/// rest into updates and zero-power removals. A `u64` power reaches CometBFT as protobuf int64,
/// the same 64 bits, so 2^63 and above are negative.
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
