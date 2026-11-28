//! A block's LastCommit, checked against the validator-state replica, and the `missBitmap` it
//! gives.
//!
//! CometBFT hands each handler the block's LastCommit, its commit for the parent:
//! `PrepareProposal` its `local_last_commit`, `ProcessProposal` the proposed block's
//! `proposed_last_commit` and `FinalizeBlock` the decided block's `decided_last_commit`. Each
//! lists every validator of the set that signs the parent, in CometBFT order, with the address and
//! power CometBFT stores for it and the block's `block_id_flag` for it. Before an entry's flag is
//! paired with a validator by its position, the list must name exactly the replica's set that
//! signs the parent ([`AppState::parent_signers`]) entry by entry: another length, address or
//! power means CometBFT and the replica disagree about that set, a safety halt
//! ([`LastCommitError`]). A validator is committed only with `BLOCK_ID_FLAG_COMMIT`; an absent or
//! nil vote leaves it missing. A generation's first block has an empty LastCommit and no parent
//! signers.
//!
//! The `missBitmap` sets the seat of each missing validator: its live key-to-seat word in the
//! parent's post-state, read from the own EL at the committed parent's hash, never at the block
//! being judged. A failed read is a node-local fault the caller waits on or halts for, never a
//! zero word. The words read are kept by `(parent hash, address)` until `Commit`.

use std::collections::BTreeMap;

use alloy_primitives::Address;
use tendermint::{
    abci::types::{BlockSignatureInfo, ExtendedVoteInfo, Validator, VoteInfo},
    block::BlockIdFlag,
};

use super::{App, Rejection, deadline};
use crate::{
    engine::{Engine, staking::seat_words},
    l1::L1Source,
    store::AppState,
    valstate::ValEntry,
};

/// How a LastCommit disagrees with the replica's set that signs the parent
/// ([`Rejection::LastCommit`]). Each is a safety halt: CometBFT builds the list from its own
/// stored set, so it never differs from a correct replica.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum LastCommitError {
    /// The list has another number of entries than the set has validators.
    #[error("the LastCommit lists {got} validators, the set that signs the parent has {expected}")]
    Length {
        /// The number of validators in the set that signs the parent.
        expected: usize,
        /// The number of entries in the LastCommit.
        got: usize,
    },
    /// The entry at `index` names another address than the set's validator there.
    #[error("LastCommit entry {index} names another validator than the set that signs the parent")]
    Validator {
        /// The entry's position.
        index: usize,
    },
    /// The entry at `index` gives its validator another power than the set does.
    #[error("LastCommit entry {index} gives another power than the set that signs the parent")]
    Power {
        /// The entry's position.
        index: usize,
    },
    /// The entry at `index` carries no `block_id_flag`, only a signed-or-not bit.
    #[error("LastCommit entry {index} carries no block_id_flag")]
    Flag {
        /// The entry's position.
        index: usize,
    },
}

/// Whether each validator of `parent_signers`, the set that signs the parent in CometBFT order,
/// is committed in the LastCommit `votes`: `true` exactly for `BLOCK_ID_FLAG_COMMIT`. The i-th
/// entry must name the i-th validator with its power ([`LastCommitError`]).
pub(crate) fn committed_flags(
    parent_signers: &[ValEntry],
    votes: &[VoteInfo],
) -> Result<Vec<bool>, LastCommitError> {
    flags(parent_signers, votes.iter().map(|vote| (&vote.validator, vote.sig_info)))
}

/// [`committed_flags`] of `PrepareProposal`'s LastCommit, whose entries also carry vote
/// extensions.
pub(crate) fn extended_committed_flags(
    parent_signers: &[ValEntry],
    votes: &[ExtendedVoteInfo],
) -> Result<Vec<bool>, LastCommitError> {
    flags(parent_signers, votes.iter().map(|vote| (&vote.validator, vote.sig_info)))
}

/// [`committed_flags`] of `votes`, each entry's validator with its signature information.
fn flags<'a>(
    parent_signers: &[ValEntry],
    votes: impl ExactSizeIterator<Item = (&'a Validator, BlockSignatureInfo)>,
) -> Result<Vec<bool>, LastCommitError> {
    if votes.len() != parent_signers.len() {
        return Err(LastCommitError::Length { expected: parent_signers.len(), got: votes.len() });
    }
    parent_signers
        .iter()
        .zip(votes)
        .enumerate()
        .map(|(index, (entry, (validator, sig_info)))| {
            if validator.address != entry.key.address().into_array() {
                return Err(LastCommitError::Validator { index });
            }
            if u64::try_from(entry.power) != Ok(validator.power.value()) {
                return Err(LastCommitError::Power { index });
            }
            match sig_info {
                BlockSignatureInfo::Flag(flag) => Ok(flag == BlockIdFlag::Commit),
                BlockSignatureInfo::LegacySigned => Err(LastCommitError::Flag { index }),
            }
        })
        .collect()
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// The `missBitmap` of the block on top of `state` whose LastCommit marks `committed`, one
    /// flag per validator of [`AppState::parent_signers`] ([`committed_flags`]): each missing
    /// validator's key-to-seat word in the staking contract, read whole in the post-state of the
    /// committed parent `state.parent.hash` within the engine deadline, sets its seat's bit
    /// ([`etna_core::miss::miss_bitmap`]). Nobody missing reads nothing; words already read at
    /// that hash are reused from the preparation cache.
    ///
    /// Flags of another count than the parent signers are [`Rejection::LastCommit`]. A read
    /// that fails with a retryable engine error, or misses the deadline, is
    /// [`Rejection::ElState`], naming the parent hash and the cause: it waits in
    /// `ProcessProposal` and `FinalizeBlock` and proposes a placeholder in `PrepareProposal`.
    /// Any other failure is the engine's [`Rejection::Engine`]; a malformed reply needs repair.
    pub(super) async fn miss_bitmap(
        &self,
        state: &AppState,
        committed: &[bool],
    ) -> Result<u128, Rejection> {
        let signers = &state.parent_signers;
        let addresses: Vec<Address> = signers.iter().map(|entry| entry.key.address()).collect();
        let missing = etna_core::miss::missing_addresses(&addresses, committed)
            .ok_or(LastCommitError::Length { expected: signers.len(), got: committed.len() })?;
        let parent = state.parent.hash;
        let (mut words, unread) = {
            let cache = self.preparation_cache();
            let mut words = BTreeMap::new();
            let mut unread = Vec::new();
            for &address in &missing {
                match cache.seat_words.get(&(parent, address)) {
                    Some(&word) => {
                        words.insert(address, word);
                    }
                    None => unread.push(address),
                }
            }
            (words, unread)
        };
        let limit = self.opts.engine_timeout;
        let read = match deadline(
            "seat word read",
            limit,
            seat_words(self.engine(), self.params.staking, parent, &unread),
        )
        .await
        {
            Ok(read) => read,
            Err(Rejection::Engine(error)) if error.is_retryable() => {
                return Err(Rejection::ElState(format!(
                    "the key-to-seat words at the parent {parent}: {error}"
                )));
            }
            Err(Rejection::Timeout(what)) => {
                return Err(Rejection::ElState(format!(
                    "{what} at the parent {parent} timed out after {limit:?}"
                )));
            }
            Err(other) => return Err(other),
        };
        self.preparation_cache()
            .seat_words
            .extend(read.iter().map(|(&address, &word)| ((parent, address), word)));
        words.extend(read);
        // Every missing address was cached or just read: `seat_words` answers each address it
        // is given or fails.
        Ok(etna_core::miss::miss_bitmap(&missing, |address| words[&address]))
    }
}

#[cfg(test)]
mod tests {
    use tendermint::abci::types::CommitInfo;

    use super::*;
    use crate::{
        test_utils::{commit_info, extended_commit_info, fallback_list},
        valstate::comet_order,
    };

    /// A three-key set in CometBFT order.
    fn signers() -> Vec<ValEntry> {
        comet_order(&fallback_list(&[1, 2, 3]).validator_set()).unwrap()
    }

    /// Only a commit counts as committed, in both request shapes; an absent and a nil vote are
    /// missing. A signed-or-not bit without its flag is refused.
    #[test]
    fn only_a_commit_counts_and_a_bare_signed_bit_is_refused() {
        let signers = signers();
        let commit: CommitInfo =
            commit_info(&signers, &[BlockIdFlag::Commit, BlockIdFlag::Absent, BlockIdFlag::Nil]);
        let extended = extended_commit_info(&commit);
        assert_eq!(committed_flags(&signers, &commit.votes), Ok(vec![true, false, false]));
        assert_eq!(
            extended_committed_flags(&signers, &extended.votes),
            Ok(vec![true, false, false])
        );
        assert_eq!(committed_flags(&[], &[]), Ok(vec![]));

        let mut legacy = commit.clone();
        legacy.votes[2].sig_info = BlockSignatureInfo::LegacySigned;
        assert_eq!(
            committed_flags(&signers, &legacy.votes),
            Err(LastCommitError::Flag { index: 2 })
        );
        let mut legacy = extended_commit_info(&commit);
        legacy.votes[0].sig_info = BlockSignatureInfo::LegacySigned;
        assert_eq!(
            extended_committed_flags(&signers, &legacy.votes),
            Err(LastCommitError::Flag { index: 0 })
        );
    }

    /// The first mismatching entry is reported, the length before any entry.
    #[test]
    fn the_first_disagreement_is_reported() {
        let signers = signers();
        let commit = commit_info(&signers, &[BlockIdFlag::Commit; 3]);
        let mut both = commit.clone();
        both.votes[1].validator.power = tendermint::vote::Power::from(5u32);
        both.votes[2].validator.address = [7; 20];
        assert_eq!(
            committed_flags(&signers, &both.votes),
            Err(LastCommitError::Power { index: 1 })
        );
        both.votes.pop();
        assert_eq!(
            committed_flags(&signers, &both.votes),
            Err(LastCommitError::Length { expected: 3, got: 2 })
        );
    }
}
