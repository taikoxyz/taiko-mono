//! CometBFT validator sets of committees derived from authenticated registry snapshots.

use abci::{CommitteeState, key::KeyError};

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

/// Shared checked native validator slots and metadata.
pub use etna_core::comet::validators::{Validator, Validators};

impl AuthenticatedCommittee {
    /// Builds the CometBFT validator set of a committee that
    /// [`abci::committee::verify_committee_witness_at_cutoff`] derived, which already guarantees
    /// its epoch, member order, stake/power mapping, totals and set root. This constructor
    /// only checks native key/power shape and does not establish that provenance itself.
    pub fn new(state: CommitteeState) -> Result<Self, KeyError> {
        let validators = Validators::from_members(&state.members)?;
        Ok(Self { state, validators, provenance: None })
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
