use alethia_reth_consensus::{
    eip4396::{SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee},
    validation::SHASTA_INITIAL_BASE_FEE_BLOCKS,
};
use alloy::primitives::B256;
use alloy_consensus::Header;
use alloy_rpc_types_engine::ExecutionPayloadInputV2;
use protocol::shasta::manifest::BlockManifest;

use super::{super::validation::ValidationContext, bundle::BundleMeta};
use crate::derivation::DerivationError;

/// Rolling view of the parent block used when deriving successive payloads.
#[derive(Debug, Clone)]
pub(super) struct ParentState {
    /// Header of the latest block that has been materialised.
    pub(super) header: Header,
    /// Hash of the bond instructions accumulated up to the parent block.
    pub(super) bond_instructions_hash: B256,
    /// Anchor block number advertised by the parent block.
    pub(super) anchor_block_number: u64,
    /// Time delta between the parent and grandparent blocks.
    pub(super) parent_block_time: u64,
}

impl ParentState {
    /// Return an updated view of the parent state after committing `manifest_block` via the
    /// provided execution payload.
    pub(super) fn advance(
        &self,
        manifest_block: &BlockManifest,
        payload: &ExecutionPayloadInputV2,
        next_bond_instructions_hash: B256,
    ) -> Result<Self, DerivationError> {
        let execution_payload = payload.execution_payload.clone();
        let header = execution_payload
            .clone()
            .into_block_raw()
            .map_err(|err| DerivationError::HeaderConversion { reason: err.to_string() })?
            .into_header();

        let expected_number = self.header.number.saturating_add(1);
        if execution_payload.block_number != expected_number {
            return Err(DerivationError::UnexpectedBlockNumber {
                expected: expected_number,
                actual: execution_payload.block_number,
            });
        }

        Ok(Self {
            parent_block_time: header.timestamp.saturating_sub(self.header.timestamp),
            header,
            bond_instructions_hash: next_bond_instructions_hash,
            anchor_block_number: manifest_block.anchor_block_number,
        })
    }

    /// Return the height assigned to the next payload derived from this parent.
    pub(super) fn next_block_number(&self) -> u64 {
        self.header.number.saturating_add(1)
    }

    /// Compute the target base fee for the next payload, falling back to the fixed
    /// Shasta base fee while the fork warm-up window is active.
    pub(super) fn compute_block_base_fee(&self, block_number: u64, shasta_fork_height: u64) -> u64 {
        if block_number < shasta_fork_height + SHASTA_INITIAL_BASE_FEE_BLOCKS {
            SHASTA_INITIAL_BASE_FEE
        } else {
            calculate_next_block_eip4396_base_fee(&self.header, self.parent_block_time)
        }
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
            proposer: meta.proposer,
            is_forced_inclusion,
        }
    }
}
