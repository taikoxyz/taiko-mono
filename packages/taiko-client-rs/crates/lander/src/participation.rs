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
//! each member's verified `BlockIdFlagCommit` signatures in MEM-08 member order, and the
//! [`CommitteeMember`] list of every epoch `e` the batch completes (`h_last(e) <= L - 1`), in
//! ascending order. Committee and participation hashes are Solidity `keccak256(abi.encode(x))`
//! of one dynamic array `x`, leading offset word included. Under the dummy verifier L1 checks only
//! the parts' shape and each settlement list against its part's committee hash; a future guest
//! must recompute the counts and committees the same way.

use std::collections::BTreeMap;

use abci::{ChainParams, Schedule, committee::member_bond_ids};
use alloy::sol_types::SolValue;
use alloy_primitives::{B256, keccak256};

use crate::{
    committee::AuthenticatedCommittee,
    contracts::IEtnaInbox::{CommitteeMember, EpochParticipation},
    error::{LanderError, Result},
};

/// The signers of one verified canonical commit.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CommitSigners {
    /// The committed height: the carrying block's height minus one.
    pub height: u64,
    /// One flag per CometBFT validator slot of the signing committee (power descending, then
    /// address ascending): true iff the slot holds a verified `BlockIdFlagCommit` signature.
    pub signed: Vec<bool>,
}

/// One batch's validator participation and the committees of the epochs it completes.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Participation {
    /// One part per epoch of the batch's commit range, in ascending epoch order; empty when the
    /// batch carries no commit.
    pub parts: Vec<EpochParticipation>,
    /// The MEM-08 committee list of each epoch the batch completes, in ascending epoch order:
    /// `land`'s settlements.
    pub settlements: Vec<Vec<CommitteeMember>>,
}

/// The authenticated committee's members as the reward pool settles them, in MEM-08 order.
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
/// Each slot is mapped to its member's MEM-08 index by public key.
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
        let slots = committee
            .validators
            .validators()
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
        // h_last(e) = (e + 1) * len <= c1, without overflow.
        let completed = epoch < c1 / len;
        let first = c0.max(epoch * len + 1);
        let last = if completed { (epoch + 1) * len } else { c1 };
        let mut counts = vec![0u32; members.len()];
        for signer in &signers[(first - c0) as usize..=(last - c0) as usize] {
            if signer.signed.len() != slots.len() {
                return Err(LanderError::Safety(format!(
                    "commit {} has {} slots for the {} validators of committee {epoch}",
                    signer.height,
                    signer.signed.len(),
                    slots.len()
                )));
            }
            for (slot, _) in slots.iter().zip(&signer.signed).filter(|(_, signed)| **signed) {
                counts[*slot] = counts[*slot].checked_add(1).ok_or_else(|| {
                    LanderError::Safety(format!("committee {epoch} signed count overflow"))
                })?;
            }
        }
        result.parts.push(EpochParticipation {
            epoch,
            committeeHash: committee_hash(&members),
            signedCounts: counts,
        });
        if completed {
            result.settlements.push(members);
        }
    }
    Ok(result)
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
        test_utils::consensus::{committee, nil_vote, pair},
        validate::verify_commit,
    };
    use alloy_primitives::{U256, b256};
    use std::ops::RangeInclusive;
    use tendermint::block::CommitSig;

    /// A schedule of `epoch_len`-block epochs.
    fn schedule(epoch_len: u64) -> Schedule {
        Schedule { l1_0: 10, epoch_len, epoch_len_l1: 1, genesis_cutoff: 1 }
    }

    /// The commits of `heights`, each signed by every slot of its epoch's committee.
    fn all_signed(
        schedule: &Schedule,
        committees: &BTreeMap<u64, AuthenticatedCommittee>,
        heights: RangeInclusive<u64>,
    ) -> Vec<CommitSigners> {
        heights
            .map(|height| CommitSigners {
                height,
                signed: vec![
                    true;
                    committees[&schedule.epoch_of(height.max(1))]
                        .validators
                        .validators()
                        .len()
                ],
            })
            .collect()
    }

    /// The registry-backed MEM-08 committee list of `committee`.
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
        let result =
            build(&schedule, &params, 0, 2, &[CommitSigners { height: 1, signed }], &committees)
                .unwrap();
        let mut expected = vec![0; 3];
        expected[committee.state.members.iter().position(|m| m.power == 5).unwrap()] = 1;
        assert_eq!(
            result.parts,
            [EpochParticipation {
                epoch: 0,
                committeeHash: committee_hash(&members(&committee, &schedule)),
                signedCounts: expected,
            }]
        );
        assert!(result.settlements.is_empty());
    }

    #[test]
    fn participation_maps_cometbft_slots_to_mem08_indices() {
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
        assert_ne!(member_seeds, slot_seeds, "MEM-08 order must differ from CometBFT order");
        assert_ne!(member_seeds, [1, 2, 3, 4], "MEM-08 order must differ from bond id order");

        // Seed s signs the first s of the four commits.
        let signers = (1..=4)
            .map(|height| CommitSigners {
                height,
                signed: slot_seeds.iter().map(|seed| height <= *seed as u64).collect(),
            })
            .collect::<Vec<_>>();
        let schedule = schedule(10);
        let committees = BTreeMap::from([(0, committee.clone())]);
        let result = build(&schedule, &params, 0, 5, &signers, &committees).unwrap();
        assert_eq!(
            result.parts[0].signedCounts,
            member_seeds.iter().map(|seed| *seed as u32).collect::<Vec<_>>()
        );
        // The committee list names each member's own registry entry (bond id = seed - 1).
        let listed = members(&committee, &schedule);
        for (member, seed) in listed.iter().zip(&member_seeds) {
            assert_eq!(member.bondId as usize, seed - 1);
            assert_eq!(member.activeFromL1, 1);
            assert_eq!(member.effStake, U256::from(powers[seed - 1]));
        }
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

    /// Pinned with `cast keccak $(cast abi-encode 'f((uint32,uint64,uint256)[])' '[…]')`: the
    /// encoding of one dynamic array argument, leading offset word included.
    #[test]
    fn committee_hash_matches_the_solidity_encoding() {
        let member = |bond_id, active_from_l1, eff_stake| CommitteeMember {
            bondId: bond_id,
            activeFromL1: active_from_l1,
            effStake: eff_stake,
        };
        let committee =
            [member(3, 11, U256::from(5_000_000_000_000_000_000u64)), member(0, 1, U256::from(1))];
        assert_eq!(
            committee_hash(&committee),
            b256!("c5d98d1cfa968f2527daf15aaad61595e64a2e1592a8c4e986d67580e1dc8dc4")
        );
        assert_eq!(
            committee_hash(&[member(u32::MAX, u64::MAX, U256::MAX)]),
            b256!("a4a34338a6b83143412cb16880595ab12ae5b35b7f703f869abdb88c4c4b23e0")
        );
        assert_eq!(
            committee_hash(&[]),
            b256!("569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd")
        );
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
