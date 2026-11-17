//! Native transport and MPT adapters for the canonical shared committee verifier.
use crate::{
    config::ChainParams,
    envelope::CommitteeWitness,
    l1::mpt::{MptError, verify_account_witness},
    store::CommitteeState,
    types::{CommitteeRecord, Member},
};
use alloy_primitives::{Address, B256, U256};
pub use etna_core::committee::{
    MAX_TOTAL_POWER, RegistryProof, Snapshot, committee_config_hash, entries_root, record_hash,
    set_key, set_root, snapshot_slots, tag, validator_updates, word,
};
/// Native committee failures retain the existing MPT error payload and matching semantics.
pub type CommitteeError = etna_core::committee::CommitteeError<MptError>;
/// Native evidence adapter; the existing engine owns proof authentication and unwind handling.
struct NodeRegistryProof<'a>(
    /// The original native transport evidence, authenticated by the existing MPT engine.
    &'a crate::types::AccountWitness,
);
impl RegistryProof for NodeRegistryProof<'_> {
    /// Preserve the native engine's exact error classification.
    type Error = MptError;
    /// Read the witnessed account rather than configured expectations.
    fn address(&self) -> Address {
        self.0.address
    }
    /// Read the actual proof-list shape for successor authentication.
    fn storage_proof_count(&self) -> usize {
        self.0.storage.len()
    }
    /// Authenticate through the unchanged engine and retain canonical requested-slot order.
    fn authenticate_storage(&self, root: B256, slots: &[B256]) -> Result<Vec<U256>, MptError> {
        let storage = verify_account_witness(root, self.0, slots)?;
        Ok(slots
            .iter()
            .map(|slot| storage.get(*slot).expect("slot belongs to the verified slot set"))
            .collect())
    }
}
/// Authenticate a transported snapshot using the shared selection and validation algorithm.
pub fn verify_snapshot(
    root: B256,
    registry: Address,
    w: &CommitteeWitness,
    cutoff: u64,
) -> Result<Snapshot, CommitteeError> {
    etna_core::committee::verify_snapshot(
        root,
        registry,
        w.record.checkpoint_index,
        &w.entries,
        &NodeRegistryProof(&w.registry),
        cutoff,
    )
}
/// Derive from plain snapshot data; authentication remains the caller's responsibility.
pub fn derive(
    snapshot: &Snapshot,
    cutoff: u64,
    target_epoch: u64,
    params: &ChainParams,
) -> Result<(CommitteeRecord, Vec<Member>), CommitteeError> {
    etna_core::committee::derive(snapshot, cutoff, target_epoch, params)
        .map_err(etna_core::committee::CommitteeError::with_backend_error)
}
/// Sum canonical committee stake and power with the shared checked arithmetic.
pub fn member_totals(members: &[Member]) -> Result<(u64, U256), CommitteeError> {
    etna_core::committee::member_totals(members)
        .map_err(etna_core::committee::CommitteeError::with_backend_error)
}
/// Authenticate, derive and compare the complete record through the shared verifier.
pub fn verify_committee_witness_at_cutoff(
    root: B256,
    cutoff: u64,
    params: &ChainParams,
    w: &CommitteeWitness,
    target_epoch: u64,
) -> Result<(CommitteeRecord, Vec<Member>), CommitteeError> {
    etna_core::committee::verify_committee_at_cutoff(
        root,
        cutoff,
        params,
        &w.record,
        &w.entries,
        &NodeRegistryProof(&w.registry),
        target_epoch,
    )
}
/// Test shorthand for [`verify_committee_witness_at_cutoff`] when the snapshot cutoff and
/// proving anchor are the same L1 block.
#[cfg(test)]
pub fn verify_committee_witness(
    parent_anchor: &crate::types::AnchorState,
    params: &ChainParams,
    w: &CommitteeWitness,
    target_epoch: u64,
) -> Result<(CommitteeRecord, Vec<Member>), CommitteeError> {
    verify_committee_witness_at_cutoff(
        parent_anchor.state_root,
        parent_anchor.number,
        params,
        w,
        target_epoch,
    )
}

/// A runtime committee witness verified once ([`verify_committee_witness_at_cutoff`]) for exactly
/// one context: the L1 state root its registry proofs verify under (COMM-4.3-12), the snapshot
/// cutoff (COMM-4.3-11) and the target epoch, with the committee derived there. Its fields are
/// private and [`VerifiedWitness::verify`] is its only constructor, so holding one means that
/// verification passed; callers check the context with [`VerifiedWitness::verified_under`]
/// instead of verifying the raw witness again. The chain parameters are not part of that
/// context: a node verifies every witness with its own fixed ones.
///
/// ```compile_fail,E0451
/// use abci::{committee::VerifiedWitness, envelope::CommitteeWitness, store::CommitteeState};
/// use alloy_primitives::B256;
///
/// fn forge(witness: CommitteeWitness, committee: CommitteeState) -> VerifiedWitness {
///     VerifiedWitness { witness, root: B256::ZERO, cutoff: 0, target_epoch: 0, committee }
/// }
/// ```
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VerifiedWitness {
    /// The verified witness.
    witness: CommitteeWitness,
    /// The L1 state root its registry proofs verify under.
    root: B256,
    /// The snapshot cutoff its checkpoint was selected at.
    cutoff: u64,
    /// The epoch whose committee it derives.
    target_epoch: u64,
    /// The committee derived from it, whose record equals the witness's.
    committee: CommitteeState,
}

impl VerifiedWitness {
    /// Verifies `witness` under `root` at `cutoff` for `target_epoch`
    /// ([`verify_committee_witness_at_cutoff`]) and keeps it with that context and its committee.
    pub fn verify(
        root: B256,
        cutoff: u64,
        params: &ChainParams,
        witness: CommitteeWitness,
        target_epoch: u64,
    ) -> Result<Self, CommitteeError> {
        let (record, members) =
            verify_committee_witness_at_cutoff(root, cutoff, params, &witness, target_epoch)?;
        Ok(Self {
            witness,
            root,
            cutoff,
            target_epoch,
            committee: CommitteeState { record, members },
        })
    }

    /// The verified witness.
    pub fn witness(&self) -> &CommitteeWitness {
        &self.witness
    }

    /// The verified witness, by value.
    pub fn into_witness(self) -> CommitteeWitness {
        self.witness
    }

    /// The committee derived from the witness.
    pub fn committee(&self) -> &CommitteeState {
        &self.committee
    }

    /// Whether the witness was verified under exactly `root`, `cutoff` and `target_epoch`.
    pub fn verified_under(&self, root: B256, cutoff: u64, target_epoch: u64) -> bool {
        (self.root, self.cutoff, self.target_epoch) == (root, cutoff, target_epoch)
    }
}

#[cfg(test)]
use crate::{key::ConsensusKey, l1::layout::registry};
#[cfg(test)]
mod tests;
