//! Reconstruction of validator sets after independent parent-anchor registry derivation.

use abci::{
    ChainParams, CommitteeState,
    committee::{MAX_TOTAL_POWER, record_hash, set_key, set_root},
    key::ConsensusKey,
};
use alloy_primitives::{B256, U256};
use tendermint::{Hash, account::Id};

/// A malformed or unauthenticated committee response.
#[derive(Debug, thiserror::Error)]
pub enum CommitteeError {
    /// The response is not the requested target epoch.
    #[error("committee epoch {got} differs from requested {expected}")]
    Epoch {
        /// Epoch requested by the authenticated schedule.
        expected: u64,
        /// Epoch carried by the untrusted hint.
        got: u64,
    },
    /// A committee violates the member ordering, stake, power, or encoding rules.
    #[error("invalid committee: {0}")]
    Invalid(&'static str),
    /// The recomputed record differs from the independently derived commitment.
    #[error("committee record hash {got} differs from authenticated hash {expected}")]
    Hash {
        /// Landed or independently proven record hash.
        expected: B256,
        /// Hash reconstructed from the full returned record.
        got: B256,
    },
}

/// A committee with validated member commitment and a reconstructed CometBFT validator set.
#[derive(Clone, Debug)]
pub struct AuthenticatedCommittee {
    /// The exact full record and its members in canonical set-key order.
    pub state: CommitteeState,
    /// CometBFT orders its validators by descending power then ascending address.
    pub validators: Validators,
    /// Registry proof and authenticated derivation parent retained for independent derivation.
    pub provenance: Option<crate::types::CommitteeContext>,
}

impl AsRef<CommitteeState> for AuthenticatedCommittee {
    /// The committee record and members the validator set was built from.
    fn as_ref(&self) -> &CommitteeState {
        &self.state
    }
}

/// Native validator metadata in the exact ordered certificate slot.
#[derive(Clone, Debug)]
pub struct Validator {
    /// Ethereum address derived from the authorized compressed key.
    pub address: Id,
    /// Authorized native key, validated by the core key type.
    pub pub_key: ConsensusKey,
    /// Positive voting power admitted by the committee record.
    voting_power: u64,
}
impl Validator {
    /// Voting power contributed by a valid block vote.
    pub fn power(&self) -> u64 {
        self.voting_power
    }
}
/// Authenticated native validators; unlike evidence wire sets this retains a checked commitment.
#[derive(Clone, Debug)]
pub struct Validators {
    /// Validators in descending power and ascending Ethereum-address order.
    members: Vec<Validator>,
    /// Stock native protobuf validator Merkle commitment.
    hash: Hash,
    /// Checked total power, bounded by the core consensus limit.
    total: u64,
}
impl Validators {
    /// Ordered signature slots.
    pub fn validators(&self) -> &[Validator] {
        &self.members
    }
    /// Commitment used by Comet header validators_hash fields.
    pub fn hash(&self) -> Hash {
        self.hash
    }
    /// Total voting power of all slots.
    pub fn total_voting_power(&self) -> u64 {
        self.total
    }
}

/// Reconstructs the set-key order, set root and voting power against an independently derived
/// record hash.
///
/// Callers first independently derive registry eligibility under an authenticated L1 root.
/// This reconstruction then checks the complete record, members and voting power.
pub fn authenticate(
    state: CommitteeState,
    epoch: u64,
    expected_hash: B256,
    params: &ChainParams,
) -> Result<AuthenticatedCommittee, CommitteeError> {
    if state.record.target_epoch != epoch {
        return Err(CommitteeError::Epoch { expected: epoch, got: state.record.target_epoch });
    }
    if state.members.is_empty() || state.members.len() > params.n_max {
        return Err(CommitteeError::Invalid("empty or oversized member list"));
    }
    if params.vp_unit.is_zero() {
        return Err(CommitteeError::Invalid("zero voting-power unit"));
    }
    if !state.members.windows(2).all(|pair| {
        set_key(params.l2_chain_id, pair[0].pubkey) < set_key(params.l2_chain_id, pair[1].pubkey)
    }) {
        return Err(CommitteeError::Invalid("members are duplicated or not in set-key order"));
    }
    let mut stake = U256::ZERO;
    let mut power = 0u64;
    let mut validators = Vec::with_capacity(state.members.len());
    for member in &state.members {
        if member.eff_stake < params.s_min ||
            member.power == 0 ||
            U256::from(member.power) != member.eff_stake / params.vp_unit
        {
            return Err(CommitteeError::Invalid("member stake/power mapping mismatch"));
        }
        stake = stake
            .checked_add(member.eff_stake)
            .ok_or(CommitteeError::Invalid("total stake overflow"))?;
        power = power
            .checked_add(member.power)
            .filter(|total| *total <= MAX_TOTAL_POWER)
            .ok_or(CommitteeError::Invalid("total power overflow"))?;
        validators.push(Validator {
            address: Id::new(member.pubkey.address().into_array()),
            pub_key: member.pubkey,
            voting_power: member.power,
        });
    }
    if power != state.record.total_power {
        return Err(CommitteeError::Invalid("record power total mismatch"));
    }
    let k = epoch.checked_add(1).ok_or(CommitteeError::Invalid("epoch overflow"))?;
    if set_root(params.l2_chain_id, k, &state.members) != state.record.set_root {
        return Err(CommitteeError::Invalid("member root mismatch"));
    }
    let got = record_hash(params.l2_chain_id, &state.record);
    if got != expected_hash {
        return Err(CommitteeError::Hash { expected: expected_hash, got });
    }
    validators.sort_by_key(|v| (std::cmp::Reverse(v.voting_power), v.address));
    let hash = abci::wire::validators_hash(&state.members)
        .map_err(|_| CommitteeError::Invalid("native validator hash"))?;
    Ok(AuthenticatedCommittee {
        state,
        validators: Validators { members: validators, hash: Hash::Sha256(hash.0), total: power },
        provenance: None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::consensus::committee;

    #[test]
    fn authenticates_members_totals_root_record_hash_and_validator_order() {
        let (params, valid, _) = committee(&[5, 3, 1], 0);
        let expected = record_hash(params.l2_chain_id, &valid.state.record);
        let result = authenticate(valid.state.clone(), 0, expected, &params).unwrap();
        assert_eq!(result.validators.total_voting_power(), 9);
        assert_eq!(result.validators.validators()[0].power(), 5);
        assert!(authenticate(valid.state.clone(), 1, expected, &params).is_err());
        assert!(authenticate(valid.state.clone(), 0, B256::ZERO, &params).is_err());
        for mutation in 0..8 {
            let mut state = valid.state.clone();
            match mutation {
                0 => state.members.reverse(),
                1 => state.members[1] = state.members[0].clone(),
                2 => state.members[0].power += 1,
                3 => state.record.total_power += 1,
                4 => state.members[0].eff_stake += U256::from(1),
                5 => state.record.set_root = B256::ZERO,
                6 => state.record.cutoff_l1_block += 1,
                7 => state.members.clear(),
                _ => unreachable!(),
            }
            assert!(authenticate(state, 0, expected, &params).is_err(), "mutation {mutation}");
        }
    }
}
