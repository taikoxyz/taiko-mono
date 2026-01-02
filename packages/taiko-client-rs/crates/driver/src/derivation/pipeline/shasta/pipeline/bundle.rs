use alloy::primitives::{Address, B256, Bytes};
use protocol::shasta::manifest::DerivationSourceManifest;

/// A single manifest segment bundled with its forced-inclusion flag.
#[derive(Debug, Clone)]
pub(super) struct SourceManifestSegment {
    pub(super) manifest: DerivationSourceManifest,
    pub(super) is_forced_inclusion: bool,
}

/// Fully decoded proposal payload containing all derivation sources.
#[derive(Debug, Clone)]
pub struct ShastaProposalBundle {
    pub(super) meta: BundleMeta,
    pub(super) sources: Vec<SourceManifestSegment>,
}

/// Metadata extracted from a proposal bundle that is required throughout
/// payload construction.
#[derive(Debug, Clone)]
pub(super) struct BundleMeta {
    pub(super) proposal_id: u64,
    pub(super) last_finalized_proposal_id: u64,
    pub(super) proposal_timestamp: u64,
    /// L1 block number that emitted the proposal event.
    pub(super) l1_block_number: u64,
    /// L1 block hash that emitted the proposal event.
    pub(super) l1_block_hash: B256,
    /// L1 origin block number used for Shasta proposal derivation.
    pub(super) origin_block_number: u64,
    pub(super) proposer: Address,
    pub(super) basefee_sharing_pctg: u8,
    pub(super) prover_auth_bytes: Bytes,
}
