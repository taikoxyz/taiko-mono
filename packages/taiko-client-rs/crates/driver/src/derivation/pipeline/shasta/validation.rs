use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
use alloy_primitives::Address;
use protocol::shasta::{
    constants::{
        BLOCK_GAS_LIMIT_MAX_CHANGE, GAS_LIMIT_DENOMINATOR, MAX_ANCHOR_OFFSET, MAX_BLOCK_GAS_LIMIT,
        MIN_BLOCK_GAS_LIMIT, TIMESTAMP_MAX_OFFSET,
    },
    manifest::DerivationSourceManifest,
};
use thiserror::Error;

/// Input data required to validate metadata for a single derivation source.
#[derive(Debug, Clone, Copy)]
pub struct ValidationContext {
    /// Timestamp of the parent L2 block.
    pub parent_timestamp: u64,
    /// Gas limit of the parent L2 block (includes the anchor transaction gas when non-genesis).
    pub parent_gas_limit: u64,
    /// Number of the parent L2 block.
    pub parent_block_number: u64,
    /// Anchor block number used by the parent L2 block.
    pub parent_anchor_block_number: u64,
    /// Timestamp provided by the L1 proposal event.
    pub proposal_timestamp: u64,
    /// L1 block number in which the proposal was accepted.
    pub origin_block_number: u64,
    /// Indicates whether the proposal is a forced inclusion.
    pub is_forced_inclusion: bool,
    /// Activation timestamp of the Shasta fork.
    pub fork_timestamp: u64,
}

/// Parameters required to populate inherited metadata for forced/default manifests.
#[derive(Debug, Clone, Copy)]
pub struct InheritedMetadataInput {
    pub parent_timestamp: u64,
    pub proposal_timestamp: u64,
    pub fork_timestamp: u64,
    pub proposer: Address,
    pub anchor_block_number: u64,
    pub parent_block_number: u64,
    pub parent_gas_limit: u64,
}

/// Errors that can occur during manifest validation.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum ValidationError {
    /// Manifest contained no blocks.
    #[error("derivation source manifest contains no blocks")]
    EmptyManifest,
    /// Manifest failed validation and should be defaulted.
    #[error("derivation source manifest failed validation and should be defaulted")]
    DefaultManifest,
}

/// Validate a derivation source manifest according to the Shasta metadata rules.
pub fn validate_source_manifest(
    manifest: &DerivationSourceManifest,
    ctx: &ValidationContext,
) -> Result<(), ValidationError> {
    if block_count(manifest) == 0 {
        return Err(ValidationError::EmptyManifest);
    }

    if !validate_timestamps(
        manifest,
        ctx.parent_timestamp,
        ctx.proposal_timestamp,
        ctx.fork_timestamp,
    ) || !validate_anchor_numbers(
        manifest,
        ctx.origin_block_number,
        ctx.parent_anchor_block_number,
        ctx.is_forced_inclusion,
    ) || !validate_gas_limit(manifest, ctx.parent_block_number, ctx.parent_gas_limit)
    {
        return Err(ValidationError::DefaultManifest);
    }

    Ok(())
}

/// Return the total number of blocks contained in the derivation source.
pub fn block_count(manifest: &DerivationSourceManifest) -> usize {
    manifest.blocks.len()
}
/// Ensure every block timestamp falls within the allowed window derived from the parent block,
/// proposal timestamp, and fork activation point.
fn validate_timestamps(
    manifest: &DerivationSourceManifest,
    parent_timestamp: u64,
    proposal_timestamp: u64,
    fork_timestamp: u64,
) -> bool {
    let mut parent_ts = parent_timestamp;

    for block in &manifest.blocks {
        let lower_bound =
            compute_timestamp_lower_bound(parent_ts, proposal_timestamp, fork_timestamp);
        if lower_bound > proposal_timestamp {
            return false;
        }

        if block.timestamp < lower_bound || block.timestamp > proposal_timestamp {
            return false;
        }

        parent_ts = block.timestamp;
    }

    true
}

// Compute the minimum valid timestamp for the next block in the sequence.
fn compute_timestamp_lower_bound(
    parent_timestamp: u64,
    proposal_timestamp: u64,
    fork_timestamp: u64,
) -> u64 {
    let lower_bound = parent_timestamp.saturating_add(1);

    // Only tighten the bound when the proposal exceeds the offset.
    let lower_bound = if proposal_timestamp > TIMESTAMP_MAX_OFFSET {
        lower_bound.max(proposal_timestamp - TIMESTAMP_MAX_OFFSET)
    } else {
        lower_bound
    };

    lower_bound.max(fork_timestamp)
}

/// Ensure anchor numbers progress monotonically and remain within the protocol bounds.
fn validate_anchor_numbers(
    manifest: &DerivationSourceManifest,
    origin_block_number: u64,
    parent_anchor_block_number: u64,
    is_forced_inclusion: bool,
) -> bool {
    let mut parent_anchor = parent_anchor_block_number;
    let mut highest_anchor = parent_anchor_block_number;

    for block in &manifest.blocks {
        let anchor = block.anchor_block_number;

        if anchor < parent_anchor {
            return false;
        }

        if anchor > origin_block_number {
            return false;
        }

        if origin_block_number > MAX_ANCHOR_OFFSET {
            let min_allowed = origin_block_number - MAX_ANCHOR_OFFSET;
            if anchor < min_allowed {
                return false;
            }
        }

        if anchor > highest_anchor {
            highest_anchor = anchor;
        }

        parent_anchor = anchor;
    }

    if !is_forced_inclusion && highest_anchor <= parent_anchor_block_number {
        return false;
    }

    true
}

/// Ensure each block's gas limit respects both the per-block delta and absolute bounds.
fn validate_gas_limit(
    manifest: &DerivationSourceManifest,
    parent_block_number: u64,
    parent_gas_limit: u64,
) -> bool {
    let mut effective_parent_gas_limit =
        effective_parent_gas_limit(parent_block_number, parent_gas_limit);

    for block in &manifest.blocks {
        let (lower_bound, upper_bound) = gas_limit_bounds(effective_parent_gas_limit);
        if block.gas_limit < lower_bound || block.gas_limit > upper_bound {
            return false;
        }

        effective_parent_gas_limit = block.gas_limit;
    }

    true
}

// Compute the allowed gas limit bounds based on the parent gas limit.
fn gas_limit_bounds(parent_gas_limit: u64) -> (u64, u64) {
    let parent = u128::from(parent_gas_limit);
    let denominator = u128::from(GAS_LIMIT_DENOMINATOR);
    let change = u128::from(BLOCK_GAS_LIMIT_MAX_CHANGE);
    let upper = parent.saturating_mul(denominator.saturating_add(change)) / denominator;
    let upper = upper.min(u128::from(MAX_BLOCK_GAS_LIMIT)) as u64;
    let lower = parent.saturating_mul(denominator.saturating_sub(change)) / denominator;
    let lower = lower.max(u128::from(MIN_BLOCK_GAS_LIMIT)).min(u128::from(upper)) as u64;

    (lower, upper)
}

// Compute the effective parent gas limit by removing the anchor transaction gas when applicable.
fn effective_parent_gas_limit(parent_block_number: u64, parent_gas_limit: u64) -> u64 {
    if parent_block_number == 0 {
        parent_gas_limit
    } else {
        parent_gas_limit.saturating_sub(ANCHOR_V3_V4_GAS_LIMIT)
    }
}

/// Populate each block with inherited metadata (timestamp, anchor, gas limit, coinbase)
/// using the parent block’s values so forced-inclusion segments and default manifests have
/// consistent metadata prior to validation.
pub fn apply_inherited_metadata(
    manifest: &mut DerivationSourceManifest,
    input: InheritedMetadataInput,
) {
    let mut parent_ts = input.parent_timestamp;
    let parent_gas_limit =
        effective_parent_gas_limit(input.parent_block_number, input.parent_gas_limit);

    for block in &mut manifest.blocks {
        let lower_bound = compute_timestamp_lower_bound(
            parent_ts,
            input.proposal_timestamp,
            input.fork_timestamp,
        );
        block.timestamp = lower_bound;
        block.coinbase = input.proposer;
        block.anchor_block_number = input.anchor_block_number;
        block.gas_limit = parent_gas_limit;
        parent_ts = lower_bound;
    }
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Address, Bytes};
    use protocol::shasta::manifest::BlockManifest;

    use super::*;

    fn manifest_with_blocks(blocks: Vec<BlockManifest>) -> DerivationSourceManifest {
        DerivationSourceManifest { prover_auth_bytes: Bytes::new(), blocks }
    }

    #[test]
    fn validate_timestamp_bounds() {
        let parent_timestamp = 1_000;
        let proposal_timestamp = 2_000;
        let manifest = manifest_with_blocks(vec![BlockManifest {
            timestamp: proposal_timestamp + 100,
            coinbase: Address::ZERO,
            anchor_block_number: 0,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);
        assert!(!validate_timestamps(&manifest, parent_timestamp, proposal_timestamp, 0));

        let manifest = manifest_with_blocks(vec![BlockManifest {
            timestamp: parent_timestamp,
            coinbase: Address::ZERO,
            anchor_block_number: 0,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);
        assert!(!validate_timestamps(&manifest, parent_timestamp, proposal_timestamp, 0));

        let lower_bound =
            (parent_timestamp + 1).max(proposal_timestamp.saturating_sub(TIMESTAMP_MAX_OFFSET));
        let manifest = manifest_with_blocks(vec![BlockManifest {
            timestamp: lower_bound + 5,
            coinbase: Address::ZERO,
            anchor_block_number: 0,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);
        assert!(validate_timestamps(&manifest, parent_timestamp, proposal_timestamp, 0));
    }

    #[test]
    fn validate_anchor_numbers_checks_progression() {
        let manifest = manifest_with_blocks(vec![BlockManifest {
            anchor_block_number: 50,
            timestamp: 0,
            coinbase: Address::ZERO,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);
        assert!(!validate_anchor_numbers(&manifest, 100, 60, false));

        let manifest = manifest_with_blocks(vec![BlockManifest {
            anchor_block_number: 80,
            timestamp: 0,
            coinbase: Address::ZERO,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);
        assert!(validate_anchor_numbers(&manifest, 100, 60, false));

        let mut manifest = manifest_with_blocks(vec![BlockManifest::default()]);
        apply_inherited_metadata(
            &mut manifest,
            InheritedMetadataInput {
                parent_timestamp: 1_000,
                proposal_timestamp: 1_010,
                fork_timestamp: 500,
                proposer: Address::repeat_byte(0x22),
                anchor_block_number: 1_000 - MAX_ANCHOR_OFFSET,
                parent_block_number: 2,
                parent_gas_limit: 30_000_000,
            },
        );
        assert!(validate_anchor_numbers(&manifest, 1_000, 1_000 - MAX_ANCHOR_OFFSET, true));

        let mut manifest = manifest_with_blocks(vec![BlockManifest::default()]);
        apply_inherited_metadata(
            &mut manifest,
            InheritedMetadataInput {
                parent_timestamp: 1_000,
                proposal_timestamp: 1_010,
                fork_timestamp: 900,
                proposer: Address::repeat_byte(0x11),
                anchor_block_number: 60,
                parent_block_number: 2,
                parent_gas_limit: 30_000_000,
            },
        );
        assert!(validate_anchor_numbers(&manifest, 100, 60, true));
    }

    #[test]
    fn validate_gas_limit_bounds() {
        let parent_block_number = 1;
        let parent_gas_limit = 30_000_000;
        let manifest = manifest_with_blocks(vec![BlockManifest {
            gas_limit: parent_gas_limit * 2,
            timestamp: 0,
            coinbase: Address::ZERO,
            anchor_block_number: 0,
            transactions: Vec::new(),
        }]);
        assert!(!validate_gas_limit(&manifest, parent_block_number, parent_gas_limit));

        let manifest = manifest_with_blocks(vec![BlockManifest {
            gas_limit: 0,
            timestamp: 0,
            coinbase: Address::ZERO,
            anchor_block_number: 0,
            transactions: Vec::new(),
        }]);
        assert!(!validate_gas_limit(&manifest, parent_block_number, parent_gas_limit));

        let manifest = manifest_with_blocks(vec![BlockManifest {
            gas_limit: parent_gas_limit - ANCHOR_V3_V4_GAS_LIMIT,
            timestamp: 0,
            coinbase: Address::ZERO,
            anchor_block_number: 0,
            transactions: Vec::new(),
        }]);
        assert!(validate_gas_limit(&manifest, parent_block_number, parent_gas_limit));
    }

    #[test]
    fn validate_source_manifest_marks_default() {
        let ctx = ValidationContext {
            parent_timestamp: 1_000,
            parent_gas_limit: 30_000_000,
            parent_block_number: 0,
            parent_anchor_block_number: 0,
            proposal_timestamp: 1_010,
            origin_block_number: 1_000,
            is_forced_inclusion: false,
            fork_timestamp: 0,
        };

        let manifest = manifest_with_blocks(Vec::new());
        assert_eq!(validate_source_manifest(&manifest, &ctx), Err(ValidationError::EmptyManifest));

        let manifest = manifest_with_blocks(vec![BlockManifest {
            timestamp: ctx.parent_timestamp,
            coinbase: Address::ZERO,
            anchor_block_number: ctx.parent_anchor_block_number,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);
        assert_eq!(
            validate_source_manifest(&manifest, &ctx),
            Err(ValidationError::DefaultManifest)
        );
    }

    #[test]
    fn apply_inherited_metadata_sets_fields() {
        let mut manifest =
            manifest_with_blocks(vec![BlockManifest::default(), BlockManifest::default()]);
        apply_inherited_metadata(
            &mut manifest,
            InheritedMetadataInput {
                parent_timestamp: 1_000,
                proposal_timestamp: 2_000,
                fork_timestamp: 1_500,
                proposer: Address::repeat_byte(0x11),
                anchor_block_number: 900,
                parent_block_number: 10,
                parent_gas_limit: 30_000_000,
            },
        );

        for block in &manifest.blocks {
            assert_eq!(block.coinbase, Address::repeat_byte(0x11));
            assert_eq!(block.anchor_block_number, 900);
            assert_eq!(block.gas_limit, 30_000_000 - ANCHOR_V3_V4_GAS_LIMIT);
        }
        assert_eq!(
            manifest.blocks.first().unwrap().timestamp,
            compute_timestamp_lower_bound(1_000, 2_000, 1_500)
        );
    }

    #[test]
    fn apply_inherited_metadata_respects_fork_lower_bound() {
        let mut manifest = manifest_with_blocks(vec![BlockManifest::default()]);
        apply_inherited_metadata(
            &mut manifest,
            InheritedMetadataInput {
                parent_timestamp: 1_000,
                proposal_timestamp: 1_100,
                fork_timestamp: 1_200,
                proposer: Address::repeat_byte(0xAA),
                anchor_block_number: 50,
                parent_block_number: 10,
                parent_gas_limit: 30_000_000,
            },
        );

        assert_eq!(
            manifest.blocks[0].timestamp,
            compute_timestamp_lower_bound(1_000, 1_100, 1_200)
        );
        assert_eq!(manifest.blocks[0].coinbase, Address::repeat_byte(0xAA));
    }
}
