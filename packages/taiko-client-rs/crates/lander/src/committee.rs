//! Authentication of untrusted ABCI committee hints against the landed record hash.

use abci::{
    ChainParams, CommitteeState,
    committee::{ENCODING_VERSION, MAX_TOTAL_POWER, mem08_key, mem08_root, record_hash},
};
use alloy_primitives::{B256, U256};
use tendermint::{PublicKey, validator};

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
    /// The recomputed record differs from the authenticated L1 mapping.
    #[error("committee record hash {got} differs from landed hash {expected}")]
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
    /// The exact full record and canonical MEM-08 ordered members.
    pub state: CommitteeState,
    /// CometBFT orders its validators by descending power then ascending address.
    pub validators: validator::Set,
}

/// Reconstructs MEM-08 and voting power before trusting any committee query.
///
/// A hint is useful only after its complete record hashes to `expected_hash` from an L1
/// mapping or an independently proven epoch-start derivation. This check applies to both.
pub fn authenticate(
    state: CommitteeState,
    epoch: u64,
    expected_hash: B256,
    params: &ChainParams,
) -> Result<AuthenticatedCommittee, CommitteeError> {
    if state.record.target_epoch != epoch {
        return Err(CommitteeError::Epoch { expected: epoch, got: state.record.target_epoch });
    }
    if state.record.encoding_version != ENCODING_VERSION {
        return Err(CommitteeError::Invalid("unsupported record encoding"));
    }
    if state.members.is_empty() || state.members.len() > params.n_max {
        return Err(CommitteeError::Invalid("empty or oversized member list"));
    }
    if params.vp_unit.is_zero() {
        return Err(CommitteeError::Invalid("zero voting-power unit"));
    }
    if !state.members.windows(2).all(|pair| {
        mem08_key(params.l2_chain_id, pair[0].pubkey) <
            mem08_key(params.l2_chain_id, pair[1].pubkey)
    }) {
        return Err(CommitteeError::Invalid("members are duplicated or not in MEM-08 order"));
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
        let key = PublicKey::from_raw_ed25519(member.pubkey.as_slice())
            .ok_or(CommitteeError::Invalid("invalid Ed25519 public key"))?;
        let power =
            member.power.try_into().map_err(|_| CommitteeError::Invalid("invalid voting power"))?;
        validators.push(validator::Info::new(key, power));
    }
    if stake != state.record.total_stake || power != state.record.total_power {
        return Err(CommitteeError::Invalid("record stake/power totals mismatch"));
    }
    let k = epoch.checked_add(1).ok_or(CommitteeError::Invalid("epoch overflow"))?;
    if mem08_root(params.l2_chain_id, k, &state.members) != state.record.set_root {
        return Err(CommitteeError::Invalid("member root mismatch"));
    }
    let got = record_hash(params.l2_chain_id, &state.record);
    if got != expected_hash {
        return Err(CommitteeError::Hash { expected: expected_hash, got });
    }
    Ok(AuthenticatedCommittee { state, validators: validator::Set::without_proposer(validators) })
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
        assert_eq!(result.validators.total_voting_power().value(), 9);
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
                4 => state.record.total_stake += U256::from(1),
                5 => state.record.set_root = B256::ZERO,
                6 => state.record.encoding_version = 2,
                7 => state.members.clear(),
                _ => unreachable!(),
            }
            assert!(authenticate(state, 0, expected, &params).is_err(), "mutation {mutation}");
        }
    }
}
