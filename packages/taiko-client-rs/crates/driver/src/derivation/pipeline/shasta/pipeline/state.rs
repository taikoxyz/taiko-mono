use super::{
    super::validation::{InheritedMetadataInput, ValidationContext, apply_inherited_metadata},
    bundle::BundleMeta,
};
use crate::derivation::DerivationError;
use alethia_reth_consensus::eip4396::SHASTA_INITIAL_BASE_FEE;
use alloy_consensus::Header;
use protocol::shasta::{
    constants::calculate_next_block_eip4396_base_fee_from_parent_values, is_etna_at,
};

/// Rolling view of the parent block used when deriving successive payloads.
#[derive(Debug, Clone)]
pub(super) struct ParentState {
    /// Header of the latest block that has been materialised.
    pub(super) header: Header,
    /// Anchor block number advertised by the parent block.
    pub(super) anchor_block_number: u64,
    /// Time delta between the parent and grandparent blocks.
    pub(super) parent_block_time_delta_secs: u64,
    /// Timestamp when the Shasta fork is expected to activate.
    pub(super) shasta_fork_timestamp: u64,
    /// Chain-specific minimum base fee used by EIP-4396 clamping.
    pub(super) min_base_fee_to_clamp: u64,
    /// L2 chain ID used by chain-aware Shasta validation bounds.
    pub(super) chain_id: u64,
    /// Etna activation timestamp on this chain, or `None` while Etna is not scheduled.
    pub(super) etna_fork_timestamp: Option<u64>,
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
        let expected_block_number = self.next_block_number();
        if header.number != expected_block_number {
            return Err(DerivationError::UnexpectedBlockNumber {
                expected: expected_block_number,
                actual: header.number,
            });
        }

        Ok(Self {
            parent_block_time_delta_secs: header.timestamp.saturating_sub(self.header.timestamp),
            header,
            anchor_block_number,
            shasta_fork_timestamp: self.shasta_fork_timestamp,
            min_base_fee_to_clamp: self.min_base_fee_to_clamp,
            chain_id: self.chain_id,
            etna_fork_timestamp: self.etna_fork_timestamp,
        })
    }

    /// Return whether the parent block itself is an Etna block (decided by its own timestamp).
    pub(super) fn is_etna(&self) -> bool {
        is_etna_at(self.etna_fork_timestamp, self.header.timestamp)
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

        if self.header.number == 0 {
            return Ok(SHASTA_INITIAL_BASE_FEE);
        }

        let parent_base_fee_per_gas =
            self.header.base_fee_per_gas.ok_or(DerivationError::MissingParentBaseFee {
                parent_block_number: self.header.number,
            })?;
        // Use cached parent/grandparent delta with chain-specific clamp to mirror proposer logic.
        Ok(calculate_next_block_eip4396_base_fee_from_parent_values(
            self.header.number,
            self.header.gas_limit,
            self.header.gas_used,
            self.parent_block_time_delta_secs,
            parent_base_fee_per_gas,
            self.min_base_fee_to_clamp,
        ))
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
            chain_id: self.chain_id,
            parent_is_etna: self.is_etna(),
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
                chain_id: self.chain_id,
                parent_is_etna: self.is_etna(),
            },
        );
    }
}

#[cfg(test)]
mod tests {
    use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
    use protocol::shasta::{
        constants::{TAIKO_DEVNET_CHAIN_ID, min_base_fee_for_chain},
        manifest::{BlockManifest, DerivationSourceManifest},
    };

    use super::{super::sample_meta, *};

    /// Etna activation used by the parent-state tests.
    const ETNA_TIMESTAMP: u64 = 1_000;

    /// Non-genesis devnet parent block 6 at `timestamp` with a 30M header gas limit, on a chain
    /// that activates Etna at [`ETNA_TIMESTAMP`].
    fn parent_at(timestamp: u64) -> ParentState {
        ParentState {
            header: Header {
                number: 6,
                timestamp,
                gas_limit: 30_000_000,
                base_fee_per_gas: Some(10_000_000),
                ..Default::default()
            },
            anchor_block_number: 50,
            parent_block_time_delta_secs: 12,
            shasta_fork_timestamp: 0,
            min_base_fee_to_clamp: min_base_fee_for_chain(TAIKO_DEVNET_CHAIN_ID),
            chain_id: TAIKO_DEVNET_CHAIN_ID,
            etna_fork_timestamp: Some(ETNA_TIMESTAMP),
        }
    }

    /// The validation context marks the parent as Etna by the parent's own timestamp, so the
    /// gas-limit check measures against a parent without the anchor reserve.
    #[test]
    fn validation_context_marks_an_etna_parent_by_its_timestamp() {
        let meta = sample_meta();

        assert!(parent_at(ETNA_TIMESTAMP).build_validation_context(&meta, false).parent_is_etna);
        assert!(
            !parent_at(ETNA_TIMESTAMP - 1).build_validation_context(&meta, false).parent_is_etna
        );
    }

    /// A default manifest inherits an Etna parent's whole gas limit, but a pre-Etna parent's
    /// gas limit minus its anchor reserve.
    #[test]
    fn inherited_metadata_strips_the_anchor_reserve_only_from_a_pre_etna_parent() {
        let inherited_gas_limit = |parent: ParentState| {
            let mut manifest = DerivationSourceManifest { blocks: vec![BlockManifest::default()] };
            parent.apply_inherited_metadata(&mut manifest, &sample_meta());
            manifest.blocks[0].gas_limit
        };

        assert_eq!(inherited_gas_limit(parent_at(ETNA_TIMESTAMP)), 30_000_000);
        assert_eq!(
            inherited_gas_limit(parent_at(ETNA_TIMESTAMP - 1)),
            30_000_000 - ANCHOR_V3_V4_GAS_LIMIT
        );
    }
}
