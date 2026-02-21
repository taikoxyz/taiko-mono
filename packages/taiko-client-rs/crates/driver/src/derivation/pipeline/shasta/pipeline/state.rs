use super::{
    super::validation::{InheritedMetadataInput, ValidationContext, apply_inherited_metadata},
    bundle::BundleMeta,
};
use crate::derivation::DerivationError;
use alethia_reth_consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy_consensus::Header;

/// Rolling view of the parent block used when deriving successive payloads.
#[derive(Debug, Clone)]
pub(super) struct ParentState {
    /// Header of the latest block that has been materialised.
    pub(super) header: Header,
    /// Anchor block number advertised by the parent block.
    pub(super) anchor_block_number: u64,
    /// Time delta between the parent and grandparent blocks.
    pub(super) parent_block_time: u64,
    /// Timestamp when the Shasta fork is expected to activate.
    pub(super) shasta_fork_timestamp: u64,
}

impl ParentState {
    /// Advance the parent state using an explicit consensus header.
    ///
    /// The header may come either from a freshly inserted execution payload or from an existing
    /// canonical block detected by the proposal fast-path.
    pub(super) fn advance(
        &self,
        header: Header,
        anchor_block_number: u64,
    ) -> Result<Self, DerivationError> {
        if header.number != self.next_block_number() {
            return Err(DerivationError::UnexpectedBlockNumber {
                expected: self.next_block_number(),
                actual: header.number,
            });
        }

        Ok(Self {
            parent_block_time: header.timestamp.saturating_sub(self.header.timestamp),
            header,
            anchor_block_number,
            shasta_fork_timestamp: self.shasta_fork_timestamp,
        })
    }

    /// Return the height assigned to the next payload derived from this parent.
    pub(super) fn next_block_number(&self) -> u64 {
        self.header.number.saturating_add(1)
    }

    /// Compute the target base fee for the next payload, ensuring the Shasta hardfork is active
    /// before applying the EIP-4396 rule (with the warm-up block 0 fallback).
    pub(super) fn compute_block_base_fee(&self) -> Result<u64, DerivationError> {
        if self.header.timestamp < self.shasta_fork_timestamp {
            return Err(DerivationError::ShastaForkInactive {
                activation_timestamp: self.shasta_fork_timestamp,
                parent_timestamp: self.header.timestamp,
            });
        }

        Ok(if self.header.number == 0 {
            SHASTA_INITIAL_BASE_FEE
        } else {
            calculate_next_block_eip4396_base_fee(&self.header, self.parent_block_time)
        })
    }

    /// Build the validation context used to sanity-check manifest contents.
    pub(super) fn build_validation_context(
        &self,
        meta: &BundleMeta,
        is_forced_inclusion: bool,
    ) -> ValidationContext {
        ValidationContext {
            parent_timestamp: self.header.timestamp,
            parent_gas_limit: self.header.gas_limit,
            parent_block_number: self.header.number,
            parent_anchor_block_number: self.anchor_block_number,
            proposal_timestamp: meta.proposal_timestamp,
            origin_block_number: meta.origin_block_number,
            is_forced_inclusion,
            fork_timestamp: self.shasta_fork_timestamp,
        }
    }

    /// Populate the provided manifest with inherited metadata (timestamp, coinbase, anchor,
    /// gas limit) based on the current parent state so forced/default manifests have usable fields.
    pub(super) fn apply_inherited_metadata(
        &self,
        manifest: &mut protocol::shasta::manifest::DerivationSourceManifest,
        meta: &BundleMeta,
    ) {
        apply_inherited_metadata(
            manifest,
            InheritedMetadataInput {
                parent_timestamp: self.header.timestamp,
                proposal_timestamp: meta.proposal_timestamp,
                fork_timestamp: self.shasta_fork_timestamp,
                proposer: meta.proposer,
                anchor_block_number: self.anchor_block_number,
                parent_block_number: self.header.number,
                parent_gas_limit: self.header.gas_limit,
            },
        );
    }
}
