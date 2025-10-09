use alloy::primitives::{Address, B256, Bytes};
use protocol::shasta::manifest::DerivationSourceManifest;

#[derive(Debug, Clone)]
pub(super) struct SourceManifestSegment {
    pub(super) manifest: DerivationSourceManifest,
    pub(super) is_forced_inclusion: bool,
}

#[derive(Debug, Clone)]
pub struct ShastaProposalBundle {
    pub(super) proposal_id: u64,
    pub(super) proposal_timestamp: u64,
    pub(super) origin_block_number: u64,
    pub(super) proposer: Address,
    pub(super) basefee_sharing_pctg: u8,
    pub(super) bond_instructions_hash: B256,
    pub(super) prover_auth_bytes: Bytes,
    pub(super) end_of_submission_window_timestamp: u64,
    pub(super) sources: Vec<SourceManifestSegment>,
}

#[derive(Debug, Clone)]
pub(super) struct BundleMeta {
    pub(super) proposal_id: u64,
    pub(super) proposal_timestamp: u64,
    pub(super) origin_block_number: u64,
    pub(super) proposer: Address,
    pub(super) basefee_sharing_pctg: u8,
    pub(super) bond_instructions_hash: B256,
    pub(super) prover_auth_bytes: Bytes,
}

impl ShastaProposalBundle {
    pub(super) fn into_meta_and_sources(self) -> (BundleMeta, Vec<SourceManifestSegment>) {
        let ShastaProposalBundle {
            proposal_id,
            proposal_timestamp,
            origin_block_number,
            proposer,
            basefee_sharing_pctg,
            bond_instructions_hash,
            prover_auth_bytes,
            end_of_submission_window_timestamp: _ignored,
            sources,
        } = self;

        (
            BundleMeta {
                proposal_id,
                proposal_timestamp,
                origin_block_number,
                proposer,
                basefee_sharing_pctg,
                bond_instructions_hash,
                prover_auth_bytes,
            },
            sources,
        )
    }
}
