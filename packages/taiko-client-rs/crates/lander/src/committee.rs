//! Authenticated CometBFT validator sets: the signature slots a certificate is verified against.

use abci::{
    key::{ConsensusKey, KeyError},
    valstate::ValEntry,
};
use tendermint::{Hash, account::Id};

/// Why keys with powers form no validator set.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum SetError {
    /// A key is invalid, or a power does not fit CometBFT's int64.
    #[error(transparent)]
    Key(#[from] KeyError),
    /// The powers sum past CometBFT's total voting power bound, possibly past a u64.
    #[error("the powers' total voting power exceeds CometBFT's bound")]
    TotalPower,
}

/// Native validator metadata in the exact ordered certificate slot.
#[derive(Clone, Debug, PartialEq, Eq)]
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
///
/// Two sets are equal exactly when they hold the same keys at the same powers: the members stay
/// in CometBFT's canonical order, so equality compares (key, power) multisets.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Validators {
    /// Validators in descending power and ascending Ethereum-address order.
    members: Vec<Validator>,
    /// Stock native protobuf validator Merkle commitment.
    hash: Hash,
    /// Total power of the members, at most `MAX_TOTAL_POWER`.
    total: u64,
}
impl Validators {
    /// Build native commit slots from keys with their powers, such as a fallback key list's
    /// keys, each at power 1, or a Comet node's untrusted `/validators` answer. Powers summing
    /// past CometBFT's total voting power bound form no set. Only keys/powers enter this
    /// representation; callers authenticate it against each native header before use.
    pub fn from_powers(powers: &[(ConsensusKey, u64)]) -> Result<Self, SetError> {
        let total = powers
            .iter()
            .try_fold(0u64, |total, (_, power)| total.checked_add(*power))
            .filter(|total| *total <= abci::committee::MAX_TOTAL_POWER)
            .ok_or(SetError::TotalPower)?;
        let mut validators = powers
            .iter()
            .map(|(key, power)| Validator {
                address: Id::new(key.address().into_array()),
                pub_key: *key,
                voting_power: *power,
            })
            .collect::<Vec<_>>();
        validators.sort_by_key(|v| (std::cmp::Reverse(v.voting_power), v.address));
        let hash = abci::wire::validators_hash(powers)?;
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
    /// The members' keys and powers, in CometBFT's order.
    pub(crate) fn members(&self) -> Vec<(ConsensusKey, u64)> {
        self.members.iter().map(|v| (v.pub_key, v.voting_power)).collect()
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
        let (_, valid, _) = committee(&[5, 3, 1]);
        assert_eq!(valid.validators.total_voting_power(), 9);
        let powers = valid.validators.validators().iter().map(|v| v.power()).collect::<Vec<_>>();
        assert_eq!(powers, [5, 3, 1]);
        assert_eq!(
            valid.validators.hash(),
            tendermint::Hash::Sha256(abci::wire::validators_hash(&valid.members).unwrap().0)
        );
    }

    /// Powers whose sum exceeds CometBFT's total voting power bound form no set, also when the
    /// sum overflows a u64, as an untrusted `/validators` answer can hold; powers summing to the
    /// bound do.
    #[test]
    fn powers_past_the_total_bound_form_no_set() {
        let (_, valid, _) = committee(&[1, 1, 1]);
        let with = |powers: [u64; 3]| {
            valid.members.iter().map(|(key, _)| *key).zip(powers).collect::<Vec<_>>()
        };
        let max = abci::committee::MAX_TOTAL_POWER;
        let bound = super::Validators::from_powers(&with([max - 2, 1, 1])).unwrap();
        assert_eq!(bound.total_voting_power(), max);
        for powers in [[max - 1, 1, 1], [i64::MAX as u64; 3]] {
            let error = super::Validators::from_powers(&with(powers)).unwrap_err();
            assert_eq!(error, super::SetError::TotalPower);
            assert!(error.to_string().contains("total voting power"), "{error}");
        }
    }

    /// The entries keep the slot order and are the set `comet_order` builds from the members.
    #[test]
    fn entries_are_the_comet_order_of_the_members() {
        let (_, valid, _) = committee(&[1, 5, 3]);
        assert_eq!(
            valid.validators.entries(),
            abci::valstate::comet_order(&valid.members).unwrap()
        );
        let keys = valid.validators.validators().iter().map(|v| v.pub_key).collect::<Vec<_>>();
        assert_eq!(valid.validators.entries().iter().map(|e| e.key).collect::<Vec<_>>(), keys);
    }
}
