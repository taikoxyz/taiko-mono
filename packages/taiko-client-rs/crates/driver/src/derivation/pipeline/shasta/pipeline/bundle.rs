use alloy::primitives::{Address, B256};
use protocol::shasta::manifest::DerivationSourceManifest;

/// A single manifest segment bundled with its forced-inclusion flag.
#[derive(Debug, Clone)]
pub(super) struct SourceManifestSegment {
    /// Decoded derivation manifest for one source entry.
    pub(super) manifest: DerivationSourceManifest,
    /// Whether this source is marked as forced inclusion.
    pub(super) is_forced_inclusion: bool,
}

/// Fully decoded proposal payload containing all derivation sources.
#[derive(Debug, Clone)]
pub struct ShastaProposalBundle {
    /// Proposal-wide metadata derived from the log and L1 block.
    pub(super) meta: BundleMeta,
    /// Ordered source manifests included in the proposal.
    pub(super) sources: Vec<SourceManifestSegment>,
}

/// Metadata extracted from a proposal bundle that is required throughout
/// payload construction.
#[derive(Debug, Clone)]
pub(super) struct BundleMeta {
    /// Proposal id emitted by the inbox event.
    pub(super) proposal_id: u64,
    /// Last finalized proposal id from proposal core state, if the lookup succeeded.
    pub(super) last_finalized_proposal_id: Option<u64>,
    /// Proposal timestamp sourced from the emitting L1 block.
    pub(super) proposal_timestamp: u64,
    /// L1 block number that emitted the proposal event.
    pub(super) l1_block_number: u64,
    /// L1 block hash that emitted the proposal event.
    pub(super) l1_block_hash: B256,
    /// L1 origin block number used for Shasta proposal derivation.
    pub(super) origin_block_number: u64,
    /// L1 proposer address from proposal metadata.
    pub(super) proposer: Address,
    /// Basefee sharing percentage configured in proposal core state.
    pub(super) basefee_sharing_pctg: u8,
}
