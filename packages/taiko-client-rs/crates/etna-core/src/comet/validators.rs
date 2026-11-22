//! Structurally validated native validator order and power, without registry authority.
use crate::key::{ConsensusKey, KeyError};
use alloc::{collections::BTreeSet, vec::Vec};
use tendermint::{Hash, account::Id};

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
/// Structurally checked native slots; registry and epoch authorization remain caller obligations.
#[derive(Clone, Debug)]
pub struct Validators {
    /// Validators in descending power and ascending Ethereum-address order.
    members: Vec<Validator>,
    /// Stock native protobuf validator Merkle commitment.
    hash: Hash,
    /// Total power of the members, at most `MAX_TOTAL_POWER` for a derived committee.
    total: u64,
}
impl Validators {
    /// Builds positive unique native slots with checked stock total-power bounds, from 1 to
    /// [`MAX_SET_MEMBERS`](crate::params::MAX_SET_MEMBERS) members.
    /// This validates keys/powers only, not registry provenance, stake mapping or epoch authority.
    pub fn from_members(members: &[crate::types::Member]) -> Result<Self, KeyError> {
        if members.is_empty() || members.len() > crate::params::MAX_SET_MEMBERS {
            return Err(KeyError);
        }
        let mut addresses = BTreeSet::new();
        let mut total = 0u64;
        for member in members {
            if member.power == 0 || !addresses.insert(member.pubkey.address()) {
                return Err(KeyError);
            }
            total = total
                .checked_add(member.power)
                .filter(|power| *power <= crate::committee::MAX_TOTAL_POWER)
                .ok_or(KeyError)?;
        }
        let mut validators = members
            .iter()
            .map(|member| Validator {
                address: Id::new(member.pubkey.address().into_array()),
                pub_key: member.pubkey,
                voting_power: member.power,
            })
            .collect::<Vec<_>>();
        validators.sort_by_key(|v| (core::cmp::Reverse(v.voting_power), v.address));
        let hash = crate::validator::validators_hash(members)?;
        Ok(Self { members: validators, hash: Hash::Sha256(hash.0), total })
    }
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{params::MAX_SET_MEMBERS, types::Member};
    use alloy_primitives::U256;

    /// `n` members with distinct keys, each at power 1.
    fn members(n: usize) -> Vec<Member> {
        (0..n as u64)
            .map(|seed| Member {
                pubkey: crate::test_utils::test_key(seed),
                eff_stake: U256::ZERO,
                power: 1,
            })
            .collect()
    }

    #[test]
    fn from_members_rejects_129_and_zero_members() {
        assert_eq!(Validators::from_members(&[]).unwrap_err(), KeyError);
        assert_eq!(Validators::from_members(&members(MAX_SET_MEMBERS + 1)).unwrap_err(), KeyError);
        let full = Validators::from_members(&members(MAX_SET_MEMBERS)).unwrap();
        assert_eq!(full.validators().len(), 128);
        assert_eq!(full.total_voting_power(), 128);
        assert_eq!(Validators::from_members(&members(1)).unwrap().total_voting_power(), 1);
    }
}
