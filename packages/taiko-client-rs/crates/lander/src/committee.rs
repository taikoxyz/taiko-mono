//! Authenticated CometBFT validator sets: the signature slots a certificate is verified against.

use abci::{
    Member,
    key::{ConsensusKey, KeyError},
    valstate::ValEntry,
};
use tendermint::{Hash, account::Id};

/// Native validator metadata in the exact ordered certificate slot.
#[derive(Clone, Debug)]
pub struct Validator {
    /// Ethereum address derived from the authorized compressed key.
    pub address: Id,
    /// Authorized native key, validated by the core key type.
    pub pub_key: ConsensusKey,
    /// Positive voting power of the member.
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
    /// Total power of the members, at most `MAX_TOTAL_POWER` for a derived committee.
    total: u64,
}
impl Validators {
    /// Build native commit slots from previously power-bounded members. Only keys/powers enter
    /// this representation; callers authenticate it against each native header before use.
    pub fn from_members(members: &[Member]) -> Result<Self, KeyError> {
        let mut validators = members
            .iter()
            .map(|member| Validator {
                address: Id::new(member.pubkey.address().into_array()),
                pub_key: member.pubkey,
                voting_power: member.power,
            })
            .collect::<Vec<_>>();
        validators.sort_by_key(|v| (std::cmp::Reverse(v.voting_power), v.address));
        let powers = members.iter().map(|member| (member.pubkey, member.power)).collect::<Vec<_>>();
        let hash = abci::wire::validators_hash(&powers)?;
        let total = validators.iter().map(|v| v.voting_power).sum();
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
    /// The set as CometBFT entries in its order, each at proposer priority 0 (the order
    /// `NewValidatorSet` holds them in): the signers a block's certified proposer is looked up in.
    pub fn entries(&self) -> Vec<ValEntry> {
        self.members
            .iter()
            .map(|v| ValEntry {
                key: v.pub_key,
                power: i64::try_from(v.voting_power).expect("a set's power fits CometBFT's int64"),
                priority: 0,
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use crate::test_utils::consensus::committee;

    #[test]
    fn orders_validators_by_descending_power() {
        let (_, valid, _) = committee(&[5, 3, 1], 0);
        assert_eq!(valid.validators.total_voting_power(), 9);
        let powers = valid.validators.validators().iter().map(|v| v.power()).collect::<Vec<_>>();
        assert_eq!(powers, [5, 3, 1]);
        let members = valid.state.members.iter().map(|m| (m.pubkey, m.power)).collect::<Vec<_>>();
        assert_eq!(
            valid.validators.hash(),
            tendermint::Hash::Sha256(abci::wire::validators_hash(&members).unwrap().0)
        );
    }

    /// The entries keep the slot order and are the set `comet_order` builds from the members.
    #[test]
    fn entries_are_the_comet_order_of_the_members() {
        let (_, valid, _) = committee(&[1, 5, 3], 0);
        let members = valid.state.members.iter().map(|m| (m.pubkey, m.power)).collect::<Vec<_>>();
        assert_eq!(valid.validators.entries(), abci::valstate::comet_order(&members).unwrap());
        let keys = valid.validators.validators().iter().map(|v| v.pub_key).collect::<Vec<_>>();
        assert_eq!(valid.validators.entries().iter().map(|e| e.key).collect::<Vec<_>>(), keys);
    }
}
