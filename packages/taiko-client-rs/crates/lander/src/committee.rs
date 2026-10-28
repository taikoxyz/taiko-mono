//! CometBFT validator sets of committees derived from authenticated registry snapshots.

use abci::{
    CommitteeState,
    key::{ConsensusKey, KeyError},
};
use tendermint::{Hash, account::Id};

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
    /// Total power of the members, at most `MAX_TOTAL_POWER` for a derived committee.
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

impl AuthenticatedCommittee {
    /// Builds the CometBFT validator set of a committee that
    /// [`abci::committee::verify_committee_witness_at_cutoff`] derived, which already guarantees
    /// its epoch, member order, stake/power mapping, totals and set root. Fails only on a voting
    /// power outside CometBFT's `int64` range.
    pub fn new(state: CommitteeState) -> Result<Self, KeyError> {
        let mut validators = state
            .members
            .iter()
            .map(|member| Validator {
                address: Id::new(member.pubkey.address().into_array()),
                pub_key: member.pubkey,
                voting_power: member.power,
            })
            .collect::<Vec<_>>();
        validators.sort_by_key(|v| (std::cmp::Reverse(v.voting_power), v.address));
        let hash = abci::wire::validators_hash(&state.members)?;
        let total = validators.iter().map(|v| v.voting_power).sum();
        Ok(Self {
            state,
            validators: Validators { members: validators, hash: Hash::Sha256(hash.0), total },
            provenance: None,
        })
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
        assert_eq!(
            valid.validators.hash(),
            tendermint::Hash::Sha256(abci::wire::validators_hash(&valid.state.members).unwrap().0)
        );
    }
}
