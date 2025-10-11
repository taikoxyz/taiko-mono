use alethia_reth_consensus::{
    eip4396::{SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee},
    validation::SHASTA_INITIAL_BASE_FEE_BLOCKS,
};
use alloy::primitives::B256;
use alloy_consensus::Header;
use alloy_rpc_types_engine::ExecutionPayloadInputV2;
use anyhow::anyhow;
use protocol::shasta::manifest::BlockManifest;

use super::{super::validation::ValidationContext, bundle::BundleMeta};
use crate::derivation::DerivationError;

/// Rolling view of the parent block used when deriving successive payloads.
#[derive(Debug, Clone)]
pub(super) struct ParentState {
    pub(super) header: Header,
    /// Hash of the latest parent block committed to the execution engine.
    pub(super) block_hash: B256,
    /// Hash of the bond instructions accumulated up to the parent block.
    pub(super) bond_instructions_hash: B256,
    pub(super) timestamp: u64,
    pub(super) gas_limit: u64,
    pub(super) block_number: u64,
    pub(super) anchor_block_number: u64,
    pub(super) prev_randao: B256,
}

impl ParentState {
    /// Advance the cached block number before deriving the next payload.
    pub(super) fn advance_block_number(&mut self) -> u64 {
        self.block_number = self.block_number.saturating_add(1);
        self.block_number
    }

    /// Compute the target base fee for the next payload, falling back to the fixed
    /// Shasta base fee while the fork warm-up window is active.
    pub(super) fn compute_block_base_fee(
        &self,
        block_number: u64,
        block_time: u64,
        shasta_fork_height: u64,
    ) -> u64 {
        if block_number < shasta_fork_height + SHASTA_INITIAL_BASE_FEE_BLOCKS {
            SHASTA_INITIAL_BASE_FEE
        } else {
            calculate_next_block_eip4396_base_fee(&self.header, block_time)
        }
    }

    /// Update the cached parent header after committing a derived block using the execution
    /// payload returned by the engine.
    pub(super) fn apply_execution_payload(
        &mut self,
        manifest_block: &BlockManifest,
        payload: &ExecutionPayloadInputV2,
        next_bond_instructions_hash: B256,
    ) -> Result<(), DerivationError> {
        let execution_payload = payload.execution_payload.clone();
        let header = execution_payload
            .clone()
            .into_block_raw()
            .map_err(|err| {
                DerivationError::Other(anyhow!(
                    "failed to convert execution payload into header: {err}"
                ))
            })?
            .into_header();

        if execution_payload.block_number != self.block_number {
            return Err(DerivationError::Other(anyhow!(
                "engine returned block {} but derivation expected {}",
                execution_payload.block_number,
                self.block_number,
            )));
        }

        self.header = header;
        self.block_hash = execution_payload.block_hash;
        self.bond_instructions_hash = next_bond_instructions_hash;
        self.timestamp = execution_payload.timestamp;
        self.gas_limit = execution_payload.gas_limit;
        self.block_number = execution_payload.block_number;
        self.anchor_block_number = manifest_block.anchor_block_number;
        self.prev_randao = execution_payload.prev_randao;

        Ok(())
    }

    /// Build the validation context used to sanity-check manifest contents.
    pub(super) fn build_validation_context(
        &self,
        meta: &BundleMeta,
        is_forced_inclusion: bool,
    ) -> ValidationContext {
        ValidationContext {
            parent_timestamp: self.timestamp,
            parent_gas_limit: self.gas_limit,
            parent_block_number: self.block_number,
            parent_anchor_block_number: self.anchor_block_number,
            proposal_timestamp: meta.proposal_timestamp,
            origin_block_number: meta.origin_block_number,
            proposer: meta.proposer,
            is_forced_inclusion,
        }
    }
}
