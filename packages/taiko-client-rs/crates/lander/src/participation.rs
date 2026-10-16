//! Per-epoch validator participation counted from the canonical commits a batch carries.
//!
//! Block `h + 1` carries the canonical commit of height `h` as its `last_commit`, bound by its
//! authenticated header; height 0 has none. A batch `(p, L]` therefore carries the commits of
//! `[c0, c1] = [max(p, 1), L - 1]`, and height `L`'s travels with the next batch, so each height's
//! signatures are counted exactly once. The terminal `/commit` certificate of `L` is never counted:
//! it is not canonical, and its signature set may differ from the one block `L + 1` carries.
//!
//! The output follows `EtnaInbox`'s participation shape and the reward pool's settlement rules:
//! one [`EpochParticipation`] per epoch from `epoch_of(c0)` to `epoch_of(c1)`, in order, counting
//! each member's verified `BlockIdFlagCommit` signatures in set-key member order, and the
//! [`CommitteeMember`] list of every epoch `e` the batch completes (`h_last(e) <= L - 1`), in
//! ascending order. Committee and participation hashes are Solidity `keccak256(abi.encode(x))`
//! of one dynamic array `x`, leading offset word included. Under the dummy verifier L1 checks only
//! the parts' shape and each settlement list against its part's committee hash; a future guest
//! must recompute the counts, scores and committees the same way.
//!
//! Each part also carries proposer scores, the reward pool's proposer bonus: block `h + 1` scores
//! `floor(10_000 * includedEffStake / totalEffStake)` with the committee of `h`'s epoch, where
//! `includedEffStake` sums the effective stake of the members its `last_commit` carries as
//! verified `BlockIdFlagCommit`s, for the member whose CometBFT address (the first 20 bytes of
//! SHA-256 of its Ed25519 key) is the block's certified `proposer_address`. A proposer outside
//! that committee, possible only for an epoch's first block, scores for nobody.

use std::collections::BTreeMap;

use abci::{ChainParams, Schedule, committee::member_bond_ids};
use alloy::sol_types::SolValue;
use alloy_primitives::{B256, U256, keccak256};
use tendermint::account;

use crate::{
    committee::AuthenticatedCommittee,
    contracts::IEtnaInbox::{CommitteeMember, EpochParticipation},
    error::{LanderError, Result},
};

/// The proposer score of a block whose `last_commit` carries the whole committee's stake.
pub const MAX_BLOCK_SCORE: u32 = 10_000;

/// The signers of one verified canonical commit and the proposer of the block carrying it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CommitSigners {
    /// The committed height: the carrying block's height minus one.
    pub height: u64,
    /// One flag per CometBFT validator slot of the signing committee (power descending, then
    /// address ascending): true iff the slot holds a verified `BlockIdFlagCommit` signature.
    pub signed: Vec<bool>,
    /// The `proposer_address` of the carrying block's certified header, block `height + 1`.
    pub proposer: account::Id,
}

/// One batch's validator participation and the committees of the epochs it completes.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Participation {
    /// One part per epoch of the batch's commit range, in ascending epoch order; empty when the
    /// batch carries no commit.
    pub parts: Vec<EpochParticipation>,
    /// The committee list, in set-key order, of each epoch the batch completes, in ascending
    /// epoch order:
    /// `land`'s settlements.
    pub settlements: Vec<Vec<CommitteeMember>>,
}

/// The authenticated committee's members as the reward pool settles them, in set-key order.
///
/// Each member's `bondId` and `activeFromL1` name the registry entry the committee was derived
/// from, recomputed from the committee's own registry witness ([`member_bond_ids`]); `effStake`
/// is the member's. The witness must be the one whose derivation authenticated this committee:
/// a missing witness, a witness record other than the committee's, or an entry whose key or stake
/// differs from the member at the same position is a safety error.
pub fn committee_members(
    committee: &AuthenticatedCommittee,
    schedule: &Schedule,
    params: &ChainParams,
) -> Result<Vec<CommitteeMember>> {
    let epoch = committee.state.record.target_epoch;
    let witness = &committee
        .provenance
        .as_ref()
        .ok_or_else(|| {
            LanderError::Safety(format!("committee {epoch} has no registry witness provenance"))
        })?
        .witness;
    if witness.record != committee.state.record {
        return Err(LanderError::Safety(format!(
            "committee {epoch} witness record differs from the authenticated record"
        )));
    }
    let ids = member_bond_ids(
        &witness.entries,
        witness.record.cutoff_l1_block,
        witness.record.target_epoch,
        schedule,
        params,
    )
    .map_err(|e| LanderError::Safety(format!("committee {epoch} bond ids: {e}")))?;
    let members = &committee.state.members;
    if ids.len() != members.len() {
        return Err(LanderError::Safety(format!(
            "committee {epoch} has {} members but its witness selects {}",
            members.len(),
            ids.len()
        )));
    }
    ids.into_iter()
        .zip(members)
        .map(|((bond_id, active_from_l1), member)| {
            let entry = usize::try_from(bond_id).ok().and_then(|index| witness.entries.get(index));
            if entry.is_none_or(|e| e.pubkey != member.pubkey || e.eff_stake != member.eff_stake) {
                return Err(LanderError::Safety(format!(
                    "committee {epoch} bond {bond_id} differs from its member {}",
                    member.pubkey
                )));
            }
            Ok(CommitteeMember {
                bondId: bond_id,
                activeFromL1: active_from_l1,
                effStake: member.eff_stake,
            })
        })
        .collect()
}

/// `keccak256(abi.encode(members))`, the committee hash a participation part binds and the reward
/// pool checks a settlement list against.
pub fn committee_hash(members: &[CommitteeMember]) -> B256 {
    keccak256(members.abi_encode())
}

/// Count the participation of the batch `(parent_height, last_height]`.
///
/// `signers` must be the verified `last_commit`s of the batch's blocks, exactly heights
/// `max(parent_height, 1)..=last_height - 1` in order, each with one flag per slot of the
/// committee of its height's epoch, which `committees` must hold with its registry provenance.
/// Each slot is mapped to its member's index in set-key order by public key, and each carrying
/// block's proposer to its member's index by CometBFT address.
pub fn build(
    schedule: &Schedule,
    params: &ChainParams,
    parent_height: u64,
    last_height: u64,
    signers: &[CommitSigners],
    committees: &BTreeMap<u64, AuthenticatedCommittee>,
) -> Result<Participation> {
    if last_height <= parent_height {
        return Err(LanderError::Safety(format!(
            "batch ({parent_height}, {last_height}] lands no block"
        )));
    }
    let (c0, c1) = (parent_height.max(1), last_height - 1);
    let expected = if c0 > c1 { 0 } else { c1 - c0 + 1 };
    if signers.len() as u64 != expected ||
        signers.iter().zip(c0..).any(|(signer, height)| signer.height != height)
    {
        return Err(LanderError::Safety(format!(
            "batch ({parent_height}, {last_height}] must carry exactly the canonical commits of \
             heights {c0}..={c1}"
        )));
    }
    let mut result = Participation { parts: Vec::new(), settlements: Vec::new() };
    if expected == 0 {
        return Ok(result);
    }
    let len = schedule.epoch_len;
    if len == 0 {
        return Err(LanderError::Safety("zero epoch length".into()));
    }
    for epoch in schedule.epoch_of(c0)..=schedule.epoch_of(c1) {
        let committee = committees.get(&epoch).ok_or_else(|| {
            LanderError::Safety(format!(
                "missing authenticated committee {epoch} for participation"
            ))
        })?;
        let members = committee_members(committee, schedule, params)?;
        let index = committee
            .state
            .members
            .iter()
            .enumerate()
            .map(|(index, member)| (member.pubkey, index))
            .collect::<BTreeMap<_, _>>();
        let validators = committee.validators.validators();
        let slots = validators
            .iter()
            .map(|validator| {
                B256::try_from(validator.pub_key.to_bytes().as_slice())
                    .ok()
                    .and_then(|key| index.get(&key).copied())
                    .ok_or_else(|| {
                        LanderError::Safety(format!(
                            "committee {epoch} validator {} is not a member",
                            validator.address
                        ))
                    })
            })
            .collect::<Result<Vec<_>>>()?;
        if slots.len() != members.len() {
            return Err(LanderError::Safety(format!(
                "committee {epoch} has {} validators for {} members",
                slots.len(),
                members.len()
            )));
        }
        // The CometBFT address is derived from the key, never taken from the response.
        let proposers = validators
            .iter()
            .zip(&slots)
            .map(|(validator, slot)| (account::Id::from(validator.pub_key), *slot))
            .collect::<BTreeMap<_, _>>();
        let total_stake = members.iter().map(|member| member.effStake).sum::<U256>();
        if total_stake.is_zero() {
            return Err(LanderError::Safety(format!("committee {epoch} has no stake")));
        }
        // h_last(e) = (e + 1) * len <= c1, without overflow.
        let completed = epoch < c1 / len;
        let first = c0.max(epoch * len + 1);
        let last = if completed { (epoch + 1) * len } else { c1 };
        let mut counts = vec![0u32; members.len()];
        let mut scores = vec![0u32; members.len()];
        for signer in &signers[(first - c0) as usize..=(last - c0) as usize] {
            if signer.signed.len() != slots.len() {
                return Err(LanderError::Safety(format!(
                    "commit {} has {} slots for the {} validators of committee {epoch}",
                    signer.height,
                    signer.signed.len(),
                    slots.len()
                )));
            }
            let mut included = U256::ZERO;
            for (slot, _) in slots.iter().zip(&signer.signed).filter(|(_, signed)| **signed) {
                counts[*slot] = counts[*slot].checked_add(1).ok_or_else(|| {
                    LanderError::Safety(format!("committee {epoch} signed count overflow"))
                })?;
                included += members[*slot].effStake;
            }
            // A proposer outside this committee (an epoch's first block) scores for nobody.
            if let Some(&proposer) = proposers.get(&signer.proposer) {
                let score = block_score(included, total_stake)?;
                scores[proposer] = scores[proposer].checked_add(score).ok_or_else(|| {
                    LanderError::Safety(format!("committee {epoch} proposer score overflow"))
                })?;
            }
        }
        result.parts.push(EpochParticipation {
            epoch,
            committeeHash: committee_hash(&members),
            signedCounts: counts,
            proposerScores: scores,
        });
        if completed {
            result.settlements.push(members);
        }
    }
    verify_shape(&result.parts, parent_height, last_height, len)?;
    Ok(result)
}

/// `floor(MAX_BLOCK_SCORE * included / total)`: the proposer score of a block whose
/// `last_commit` carries `included` of the committee's `total` effective stake.
pub fn block_score(included: U256, total: U256) -> Result<u32> {
    if total.is_zero() || included > total {
        return Err(LanderError::Safety(format!(
            "included stake {included} is not a part of the committee's {total}"
        )));
    }
    let scaled = included
        .checked_mul(U256::from(MAX_BLOCK_SCORE))
        .ok_or_else(|| LanderError::Safety(format!("included stake {included} overflows")))?;
    // At most MAX_BLOCK_SCORE, since included <= total.
    Ok((scaled / total).to::<u32>())
}

/// Check the shape `EtnaInbox.land` requires of the participation of the batch
/// `(parent_height, last_height]`: no part when the commit range `[max(p, 1), L - 1]` is empty,
/// otherwise one part per epoch of the range in ascending order, each signed count at most the
/// range's heights in the part's epoch, as many proposer scores as signed counts, and the part's
/// scores summing to at most [`MAX_BLOCK_SCORE`] per such height. The Inbox reverts
/// `InvalidParticipation` otherwise.
pub fn verify_shape(
    parts: &[EpochParticipation],
    parent_height: u64,
    last_height: u64,
    epoch_len: u64,
) -> Result<()> {
    let invalid = |reason: String| {
        Err(LanderError::Safety(format!(
            "participation of ({parent_height}, {last_height}] has the wrong shape: {reason}"
        )))
    };
    if epoch_len == 0 {
        return invalid("zero epoch length".into());
    }
    let first = parent_height.max(1);
    let Some(last) = last_height.checked_sub(1).filter(|last| *last >= first) else {
        return if parts.is_empty() { Ok(()) } else { invalid("an empty range has parts".into()) };
    };
    let epochs = (first - 1) / epoch_len..=(last - 1) / epoch_len;
    if parts.len() as u64 != epochs.end() - epochs.start() + 1 {
        return invalid(format!("{} parts for epochs {epochs:?}", parts.len()));
    }
    for (part, epoch) in parts.iter().zip(epochs) {
        if part.epoch != epoch {
            return invalid(format!("part for epoch {} where {epoch} belongs", part.epoch));
        }
        let heights = last.min((epoch + 1) * epoch_len) - first.max(epoch * epoch_len + 1) + 1;
        if part.signedCounts.iter().any(|count| u64::from(*count) > heights) {
            return invalid(format!("epoch {epoch} counts exceed its {heights} heights"));
        }
        if part.proposerScores.len() != part.signedCounts.len() {
            return invalid(format!(
                "epoch {epoch} has {} scores for {} counts",
                part.proposerScores.len(),
                part.signedCounts.len()
            ));
        }
        let sum = part.proposerScores.iter().map(|score| u128::from(*score)).sum::<u128>();
        if sum > u128::from(heights) * u128::from(MAX_BLOCK_SCORE) {
            return invalid(format!("epoch {epoch} scores {sum} exceed its {heights} heights"));
        }
    }
    Ok(())
}

/// Check that `settlements` are exactly the committees of the epochs a batch ending at
/// `last_height` completes among `parts`, in order: one list per part whose epoch `e` has
/// `(e + 1) * epoch_len <= last_height - 1`, hashing to that part's committee hash.
pub fn verify_settlements(
    parts: &[EpochParticipation],
    settlements: &[Vec<CommitteeMember>],
    last_height: u64,
    epoch_len: u64,
) -> Result<()> {
    if epoch_len == 0 {
        return Err(LanderError::Safety("zero epoch length".into()));
    }
    let end = last_height.saturating_sub(1) / epoch_len;
    let completed = parts.iter().filter(|part| part.epoch < end).collect::<Vec<_>>();
    if completed.len() != settlements.len() ||
        completed
            .iter()
            .zip(settlements)
            .any(|(part, list)| committee_hash(list) != part.committeeHash)
    {
        return Err(LanderError::Safety(format!(
            "settlements differ from the committees of the {} epochs the batch completes",
            completed.len()
        )));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        error::LanderError,
        test_utils::{
            consensus::{committee, nil_vote, pair},
            vectors,
        },
        validate::verify_commit,
    };
    use alloy_primitives::U256;
    use std::ops::RangeInclusive;
    use tendermint::block::CommitSig;

    /// A schedule of `epoch_len`-block epochs.
    fn schedule(epoch_len: u64) -> Schedule {
        Schedule { l1_0: 10, epoch_len, epoch_len_l1: 1, genesis_cutoff: 1 }
    }

    /// The commits of `heights`, each signed by every slot of its epoch's committee and carried
    /// by a block that committee's first CometBFT slot proposed.
    fn all_signed(
        schedule: &Schedule,
        committees: &BTreeMap<u64, AuthenticatedCommittee>,
        heights: RangeInclusive<u64>,
    ) -> Vec<CommitSigners> {
        heights
            .map(|height| {
                let validators =
                    committees[&schedule.epoch_of(height.max(1))].validators.validators();
                CommitSigners {
                    height,
                    signed: vec![true; validators.len()],
                    proposer: validators[0].address,
                }
            })
            .collect()
    }

    /// The CometBFT address of the validator with signing key `key`.
    fn address_of(key: &ed25519_dalek::SigningKey) -> account::Id {
        account::Id::from(
            tendermint::PublicKey::from_raw_ed25519(key.verifying_key().as_bytes()).unwrap(),
        )
    }

    /// The registry-backed committee list of `committee`, in set-key order.
    fn members(committee: &AuthenticatedCommittee, schedule: &Schedule) -> Vec<CommitteeMember> {
        committee_members(committee, schedule, &crate::test_utils::consensus::parameters()).unwrap()
    }

    #[test]
    fn participation_counts_only_verified_commit_flags() {
        let (params, committee, keys) = committee(&[5, 1, 1], 0);
        let mut block = pair(1, B256::ZERO, &committee, &keys, None);
        block.commit.signatures[1] = CommitSig::BlockIdFlagAbsent;
        block.commit.signatures[2] = nil_vote(&block, &committee, &keys, 2);
        let signed =
            verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
                .unwrap();
        assert_eq!(signed, [true, false, false], "absent and nil slots are not commit signatures");
        assert_eq!(committee.validators.validators()[0].power(), 5);

        let schedule = schedule(10);
        let committees = BTreeMap::from([(0, committee.clone())]);
        let proposer = block.block.header.proposer_address;
        let result = build(
            &schedule,
            &params,
            0,
            2,
            &[CommitSigners { height: 1, signed, proposer }],
            &committees,
        )
        .unwrap();
        let five = committee.state.members.iter().position(|m| m.power == 5).unwrap();
        let mut expected = vec![0; 3];
        expected[five] = 1;
        // The power-5 member proposed and its own signature is 5 of the 7 staked: 7142.
        let mut scores = vec![0; 3];
        scores[five] = 7142;
        assert_eq!(
            result.parts,
            [EpochParticipation {
                epoch: 0,
                committeeHash: committee_hash(&members(&committee, &schedule)),
                signedCounts: expected,
                proposerScores: scores,
            }]
        );
        assert!(result.settlements.is_empty());
    }

    #[test]
    fn participation_maps_cometbft_slots_to_set_key_indices() {
        let powers = [3, 4, 1, 2];
        let (params, committee, keys) = committee(&powers, 0);
        let seed_of = |key: &[u8]| {
            keys.iter().position(|k| k.verifying_key().as_bytes().as_slice() == key).unwrap() + 1
        };
        // CometBFT orders the slots by descending power.
        let slot_seeds = committee
            .validators
            .validators()
            .iter()
            .map(|v| seed_of(&v.pub_key.to_bytes()))
            .collect::<Vec<_>>();
        assert_eq!(slot_seeds, [2, 1, 4, 3]);
        let member_seeds = committee
            .state
            .members
            .iter()
            .map(|m| seed_of(m.pubkey.as_slice()))
            .collect::<Vec<_>>();
        assert_ne!(member_seeds, slot_seeds, "set-key order must differ from CometBFT order");
        assert_ne!(member_seeds, [1, 2, 3, 4], "set-key order must differ from bond id order");

        // Seed s signs the first s of the four commits; seed 3 proposes every block.
        let signers = (1..=4)
            .map(|height| CommitSigners {
                height,
                signed: slot_seeds.iter().map(|seed| height <= *seed as u64).collect(),
                proposer: address_of(&keys[2]),
            })
            .collect::<Vec<_>>();
        let schedule = schedule(10);
        let committees = BTreeMap::from([(0, committee.clone())]);
        let result = build(&schedule, &params, 0, 5, &signers, &committees).unwrap();
        assert_eq!(
            result.parts[0].signedCounts,
            member_seeds.iter().map(|seed| *seed as u32).collect::<Vec<_>>()
        );
        // Seed 3's set-key index takes the scores, mapped by address: height 1 carries all 10
        // staked, height 2 seeds 2 to 4 (7 of 10), height 3 seeds 3 and 4 (3 of 10) and height 4
        // seed 4 alone (2 of 10).
        let proposer = member_seeds.iter().position(|seed| *seed == 3).unwrap();
        assert_eq!(member_seeds, [4, 3, 2, 1]);
        // Set-key index 1, CometBFT slot 3 and bond id 2 all differ.
        assert_eq!(proposer, 1);
        assert_eq!(slot_seeds.iter().position(|seed| *seed == 3), Some(3));
        let mut scores = vec![0; 4];
        scores[proposer] = 10_000 + 7000 + 3000 + 2000;
        assert_eq!(result.parts[0].proposerScores, scores);
        // The committee list names each member's own registry entry (bond id = seed - 1).
        let listed = members(&committee, &schedule);
        for (member, seed) in listed.iter().zip(&member_seeds) {
            assert_eq!(member.bondId as usize, seed - 1);
            assert_eq!(member.activeFromL1, 1);
            assert_eq!(member.effStake, U256::from(powers[seed - 1]));
        }
    }

    #[test]
    fn block_score_floors_the_included_share_of_the_committee_stake() {
        let score =
            |included: u64, total: u64| block_score(U256::from(included), U256::from(total));
        assert_eq!(score(7, 7).unwrap(), MAX_BLOCK_SCORE);
        assert_eq!(score(0, 7).unwrap(), 0);
        // 50,000 / 7 = 7142.86 and 60,000 / 7 = 8571.43, rounded down.
        assert_eq!(score(5, 7).unwrap(), 7142);
        assert_eq!(score(6, 7).unwrap(), 8571);
        assert_eq!(score(2, 3).unwrap(), 6666);
        // Stakes in wei: 67 of 100 TAIKO.
        let taiko = U256::from(10u64).pow(U256::from(18));
        assert_eq!(block_score(taiko * U256::from(67), taiko * U256::from(100)).unwrap(), 6700);
        // Out of range: no committee stake, more than the committee, or an overflowing product.
        for (included, total) in [(1, 0), (8, 7)] {
            assert!(
                matches!(score(included, total), Err(LanderError::Safety(_))),
                "{included}/{total}"
            );
        }
        assert!(matches!(
            block_score(U256::MAX / U256::from(2), U256::MAX),
            Err(LanderError::Safety(_))
        ));
    }

    /// The proposer of block `h + 1` that leaves a signer's precommit out of its `last_commit`
    /// scores the stake it kept, so omitting costs the omitter its own score.
    #[test]
    fn a_proposer_omitting_a_signer_scores_less() {
        // Stakes 30, 37 and 33: A omits C, and A with B still clears 2/3.
        let (params, committee, keys) = committee(&[30, 37, 33], 0);
        let schedule = schedule(10);
        let committees = BTreeMap::from([(0, committee.clone())]);
        let slot_of = |key: &ed25519_dalek::SigningKey| {
            committee
                .validators
                .validators()
                .iter()
                .position(|v| v.address == address_of(key))
                .unwrap()
        };
        let index_of = |key: &ed25519_dalek::SigningKey| {
            committee
                .state
                .members
                .iter()
                .position(|m| m.pubkey.as_slice() == key.verifying_key().as_bytes())
                .unwrap()
        };
        let (a, c) = (&keys[0], &keys[2]);
        let commit = |omit_c: bool| {
            let mut signed = vec![true; 3];
            if omit_c {
                signed[slot_of(c)] = false;
            }
            CommitSigners { height: 1, signed, proposer: address_of(a) }
        };
        let honest = build(&schedule, &params, 0, 2, &[commit(false)], &committees).unwrap();
        let omitting = build(&schedule, &params, 0, 2, &[commit(true)], &committees).unwrap();
        assert_eq!(honest.parts[0].proposerScores[index_of(a)], 10_000);
        assert_eq!(omitting.parts[0].proposerScores[index_of(a)], 6700);
        assert_eq!(omitting.parts[0].signedCounts[index_of(c)], 0);
        assert_eq!(omitting.parts[0].proposerScores.iter().sum::<u32>(), 6700, "A's score only");
    }

    /// Block `h_last(e) + 1` is the first block of epoch `e + 1` but carries epoch `e`'s last
    /// commit: its score counts for epoch `e` only if its proposer is a member of committee `e`.
    #[test]
    fn a_boundary_block_proposed_outside_the_committee_scores_for_nobody() {
        let schedule = schedule(10);
        let (params, first, first_keys) = committee(&[1, 1], 0);
        // Seeds 1 and 2 again, plus seed 3, which committee 0 does not have.
        let (_, second, second_keys) = committee(&[1, 1, 1], 1);
        let committees = BTreeMap::from([(0, first.clone()), (1, second)]);
        let mut signers = all_signed(&schedule, &committees, 9..=10);
        for signer in &mut signers {
            signer.proposer = address_of(&first_keys[0]);
        }
        let outsider = address_of(&second_keys[2]);
        assert!(first.validators.validators().iter().all(|v| v.address != outsider));
        let proposer = first
            .state
            .members
            .iter()
            .position(|m| m.pubkey.as_slice() == first_keys[0].verifying_key().as_bytes())
            .unwrap();

        // Block 11, which carries height 10's commit, proposed by a member of both committees.
        let both = build(&schedule, &params, 9, 11, &signers, &committees).unwrap();
        assert_eq!(both.parts[0].proposerScores[proposer], 20_000);
        // Proposed by the new committee's outsider: height 10's score is dropped.
        signers[1].proposer = outsider;
        let dropped = build(&schedule, &params, 9, 11, &signers, &committees).unwrap();
        assert_eq!(dropped.parts[0].proposerScores[proposer], 10_000);
        assert_eq!(dropped.parts[0].proposerScores.iter().sum::<u32>(), 10_000);
        assert_eq!(dropped.parts[0].signedCounts, both.parts[0].signedCounts, "counts unchanged");
        assert_eq!(dropped.settlements, both.settlements);
    }

    /// [`verify_shape`] accepts what [`build`] reports and rejects exactly what `EtnaInbox`'s
    /// shape check reverts `InvalidParticipation` for, including scores that are each in bound
    /// but sum past 10,000 per height.
    #[test]
    fn participation_shape_matches_the_inbox_bounds() {
        let schedule = schedule(10);
        let committees = (0..=2)
            .map(|epoch| (epoch, committee(&[epoch + 1, 1], epoch).1))
            .collect::<BTreeMap<_, _>>();
        let (params, _, _) = committee(&[1], 0);
        // (8, 30]: 3 heights of epoch 0, 10 of epoch 1 and 9 of epoch 2.
        let signers = all_signed(&schedule, &committees, 8..=29);
        let parts = build(&schedule, &params, 8, 30, &signers, &committees).unwrap().parts;
        let scored = parts.iter().map(|p| p.proposerScores.iter().sum::<u32>()).collect::<Vec<_>>();
        assert_eq!(scored, [30_000, 100_000, 90_000], "every block scores the whole committee");
        verify_shape(&parts, 8, 30, 10).unwrap();
        verify_shape(&[], 0, 1, 10).unwrap();

        let mut cases: Vec<(&str, Vec<EpochParticipation>)> = Vec::new();
        let mut short = parts.clone();
        short[1].proposerScores.pop();
        cases.push(("fewer scores than counts", short));
        let mut long = parts.clone();
        long[1].proposerScores.push(0);
        cases.push(("more scores than counts", long));
        let mut over = parts.clone();
        over[0].proposerScores = vec![20_000, 10_001];
        cases.push(("scores each in bound sum past 30,000", over));
        let mut count = parts.clone();
        count[2].signedCounts[0] = 10;
        cases.push(("count past the range's heights", count));
        let mut epoch = parts.clone();
        epoch[1].epoch = 3;
        cases.push(("wrong epoch", epoch));
        cases.push(("missing part", parts[..2].to_vec()));
        for (name, broken) in cases {
            let error = verify_shape(&broken, 8, 30, 10).unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{name}: {error}");
        }
        let mut exact = parts.clone();
        exact[0].proposerScores = vec![20_000, 10_000];
        verify_shape(&exact, 8, 30, 10).unwrap();
        assert!(verify_shape(&parts[..1], 0, 1, 10).is_err(), "an empty range has no part");
    }

    #[test]
    fn participation_first_batch_skips_height_zero() {
        let (params, committee, _) = committee(&[1, 1, 1], 0);
        let schedule = schedule(10);
        let committees = BTreeMap::from([(0, committee.clone())]);
        let signed = |heights| all_signed(&schedule, &committees, heights);

        // The batch (0, 1] carries no commit: block 1 has none, height 1's is in block 2.
        let empty = build(&schedule, &params, 0, 1, &[], &committees).unwrap();
        assert_eq!(empty, Participation { parts: vec![], settlements: vec![] });
        for heights in [0..=0, 1..=1] {
            assert!(build(&schedule, &params, 0, 1, &signed(heights), &committees).is_err());
        }

        // The batch (0, 3] carries the commits of heights 1 and 2, never one of height 0.
        let first = build(&schedule, &params, 0, 3, &signed(1..=2), &committees).unwrap();
        assert_eq!(first.parts.len(), 1);
        assert_eq!(first.parts[0].epoch, 0);
        assert_eq!(first.parts[0].signedCounts, [2, 2, 2]);
        assert!(first.settlements.is_empty());
        assert!(build(&schedule, &params, 0, 3, &signed(0..=2), &committees).is_err());

        // From checkpoint 1 the batch carries height 1's commit itself, in block 2.
        assert_eq!(build(&schedule, &params, 1, 3, &signed(1..=2), &committees).unwrap(), first);
    }

    #[test]
    fn participation_settles_every_completed_epoch_in_order() {
        let schedule = schedule(10);
        let powers: [&[u64]; 4] = [&[1, 1], &[2, 3, 4], &[5], &[6, 7]];
        let (params, _, _) = committee(&[1], 0);
        let committees = powers
            .iter()
            .zip(0..)
            .map(|(powers, epoch)| (epoch, committee(powers, epoch).1))
            .collect::<BTreeMap<_, _>>();
        let listed = |epoch: u64| members(&committees[&epoch], &schedule);
        let signed = |heights| all_signed(&schedule, &committees, heights);

        // (8, 30] carries heights 8..=29: 3 heights of epoch 0, 10 of epoch 1 and 9 of epoch 2.
        let result = build(&schedule, &params, 8, 30, &signed(8..=29), &committees).unwrap();
        assert_eq!(result.parts.iter().map(|p| p.epoch).collect::<Vec<_>>(), [0, 1, 2]);
        assert_eq!(result.parts[0].signedCounts, [3, 3]);
        assert_eq!(result.parts[1].signedCounts, [10, 10, 10]);
        assert_eq!(result.parts[2].signedCounts, [9]);
        for part in &result.parts {
            assert_eq!(part.committeeHash, committee_hash(&listed(part.epoch)));
        }
        assert_eq!(result.settlements, [listed(0), listed(1)], "epoch 2 ends at height 30");
        assert_ne!(listed(0), listed(1));

        // Height 30's commit, in block 31, completes epoch 2.
        let result = build(&schedule, &params, 8, 31, &signed(8..=30), &committees).unwrap();
        assert_eq!(result.parts[2].signedCounts, [10]);
        assert_eq!(result.settlements, [listed(0), listed(1), listed(2)]);

        // A one-height range at an epoch's last height completes that epoch alone.
        let result = build(&schedule, &params, 10, 11, &signed(10..=10), &committees).unwrap();
        assert_eq!(result.parts.iter().map(|p| p.epoch).collect::<Vec<_>>(), [0]);
        assert_eq!(result.settlements, [listed(0)]);

        // The range's last epoch stays open until its last height's commit lands.
        let result = build(&schedule, &params, 21, 30, &signed(21..=29), &committees).unwrap();
        assert_eq!(result.parts.iter().map(|p| p.epoch).collect::<Vec<_>>(), [2]);
        assert!(result.settlements.is_empty());

        // Every epoch of the range needs its authenticated committee.
        let mut missing = committees.clone();
        missing.remove(&1);
        let error = build(&schedule, &params, 8, 30, &signed(8..=29), &missing).unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "{error}");
    }

    #[test]
    fn participation_rejects_a_gap_in_commit_heights() {
        let (params, committee, _) = committee(&[1, 1], 0);
        let schedule = schedule(10);
        let committees = BTreeMap::from([(0, committee.clone())]);
        let full = all_signed(&schedule, &committees, 1..=4);
        build(&schedule, &params, 0, 5, &full, &committees).unwrap();

        let mut cases = Vec::new();
        let mut gap = full.clone();
        gap.remove(2);
        cases.push(("gap", gap));
        cases.push(("missing first", full[1..].to_vec()));
        cases.push(("missing last", full[..3].to_vec()));
        cases.push(("extra", all_signed(&schedule, &committees, 1..=5)));
        let mut swapped = full.clone();
        swapped.swap(1, 2);
        cases.push(("out of order", swapped));
        let mut duplicate = full.clone();
        duplicate[2] = duplicate[1].clone();
        cases.push(("duplicate", duplicate));
        let mut short = full.clone();
        short[1].signed.pop();
        cases.push(("slot count", short));
        for (name, signers) in cases {
            let error = build(&schedule, &params, 0, 5, &signers, &committees).unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{name}: {error}");
        }
        assert!(build(&schedule, &params, 5, 5, &[], &committees).is_err(), "no progress");
    }

    /// The shared `committee_hashes` vectors (`testdata/etna_vectors`), which the reward pool
    /// settles in `EtnaRewardPool.t.sol`: `cast abi-encode 'f((uint32,uint64,uint256)[])'`, the
    /// encoding of one dynamic array argument, leading offset word included, and its hash. Two
    /// members, one member with every field at its maximum, and none.
    #[test]
    fn committee_hash_matches_the_solidity_encoding() {
        assert_eq!(vectors::len_at("/committee_hashes"), 3);
        for k in 0..3 {
            let case = format!("/committee_hashes/{k}");
            let committee = vectors::committee_at(&format!("{case}/members"));
            assert_eq!(
                committee.abi_encode(),
                vectors::bytes_at(&format!("{case}/encoding")).to_vec(),
                "{case}"
            );
            assert_eq!(
                committee_hash(&committee),
                vectors::b256_at(&format!("{case}/hash")),
                "{case}"
            );
        }
        let committee = vectors::committee_at("/committee_hashes/0/members");
        assert_eq!(committee.len(), 2);
        assert_eq!(vectors::committee_at("/committee_hashes/1/members")[0].effStake, U256::MAX);
        assert!(vectors::committee_at("/committee_hashes/2/members").is_empty());
        let reversed = [committee[1].clone(), committee[0].clone()];
        assert_ne!(committee_hash(&reversed), committee_hash(&committee), "order is bound");
    }

    #[test]
    fn committee_members_require_matching_registry_provenance() {
        let (params, committee, _) = committee(&[1, 2, 3], 0);
        let schedule = schedule(10);
        let listed = committee_members(&committee, &schedule, &params).unwrap();
        assert_eq!(listed.len(), 3);

        let mut missing = committee.clone();
        missing.provenance = None;
        let mut record = committee.clone();
        record.provenance.as_mut().unwrap().witness.record.total_power += 1;
        let mut key = committee.clone();
        let entries = &mut key.provenance.as_mut().unwrap().witness.entries;
        entries[0].pubkey = B256::repeat_byte(0x42);
        let mut stake = committee.clone();
        stake.state.members[0].eff_stake += U256::from(1);
        for (name, broken) in
            [("missing", missing), ("record", record), ("key", key), ("stake", stake)]
        {
            let error = committee_members(&broken, &schedule, &params).unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{name}: {error}");
        }
    }

    #[test]
    fn settlements_must_be_the_completed_epochs_committees() {
        let schedule = schedule(10);
        let (params, _, _) = committee(&[1], 0);
        let committees = (0..=2)
            .map(|epoch| (epoch, committee(&[epoch + 1, 1], epoch).1))
            .collect::<BTreeMap<_, _>>();
        let signers = all_signed(&schedule, &committees, 8..=29);
        let result = build(&schedule, &params, 8, 30, &signers, &committees).unwrap();
        verify_settlements(&result.parts, &result.settlements, 30, 10).unwrap();

        let mut fewer = result.settlements.clone();
        fewer.pop();
        let mut more = result.settlements.clone();
        more.push(more[0].clone());
        let mut swapped = result.settlements.clone();
        swapped.swap(0, 1);
        for (name, settlements, last_height) in [
            ("fewer", fewer, 30),
            ("more", more, 30),
            ("swapped", swapped, 30),
            ("epoch 2 completed", result.settlements.clone(), 31),
        ] {
            let error =
                verify_settlements(&result.parts, &settlements, last_height, 10).unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{name}: {error}");
        }
    }
}
