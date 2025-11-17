use alethia_reth_consensus::validation::ANCHOR_V3_GAS_LIMIT;
use alloy_primitives::Address;
use protocol::shasta::{
    constants::{
        BLOCK_GAS_LIMIT_MAX_CHANGE, GAS_LIMIT_DENOMINATOR, MAX_ANCHOR_OFFSET, MAX_BLOCK_GAS_LIMIT,
        MIN_ANCHOR_OFFSET, MIN_BLOCK_GAS_LIMIT, TIMESTAMP_MAX_OFFSET,
    },
    manifest::DerivationSourceManifest,
};
use thiserror::Error;

/// Input data required to validate and normalise metadata for a single derivation source.
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
    /// Address of the proposer for this set of blocks.
    pub proposer: Address,
    /// Indicates whether the proposal is a forced inclusion.
    pub is_forced_inclusion: bool,
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

/// Validate a derivation source manifest in-place according to the Shasta metadata rules.
///
/// The manifest is mutated to clamp timestamps, anchor block numbers, coinbase values, and gas
/// limits. If the manifest cannot be repaired (for example when forced inclusion protection
/// triggers), [`ValidationError::DefaultManifest`] is returned and the caller should fall back to
/// the default manifest.
pub fn validate_source_manifest(
    manifest: &mut DerivationSourceManifest,
    ctx: &ValidationContext,
) -> Result<(), ValidationError> {
    if block_count(manifest) == 0 {
        return Err(ValidationError::EmptyManifest);
    }

    adjust_timestamps(manifest, ctx.parent_timestamp, ctx.proposal_timestamp);

    if !adjust_anchor_numbers(
        manifest,
        ctx.origin_block_number,
        ctx.parent_anchor_block_number,
        ctx.is_forced_inclusion,
    ) {
        return Err(ValidationError::DefaultManifest);
    }

    adjust_coinbase(manifest, ctx.proposer, ctx.is_forced_inclusion);
    adjust_gas_limit(manifest, ctx.parent_block_number, ctx.parent_gas_limit);

    Ok(())
}

/// Return the total number of blocks contained in the derivation source.
pub fn block_count(manifest: &DerivationSourceManifest) -> usize {
    manifest.blocks.len()
}

// Adjust block timestamps to be within valid bounds.
fn adjust_timestamps(
    manifest: &mut DerivationSourceManifest,
    parent_timestamp: u64,
    proposal_timestamp: u64,
) {
    let mut parent_ts = parent_timestamp;
    for block in &mut manifest.blocks {
        if block.timestamp > proposal_timestamp {
            block.timestamp = proposal_timestamp;
        }

        let lower_bound = parent_ts
            .saturating_add(1)
            .max(proposal_timestamp.saturating_sub(TIMESTAMP_MAX_OFFSET));
        if block.timestamp < lower_bound {
            block.timestamp = lower_bound;
        }

        parent_ts = block.timestamp;
    }
}

// Adjust anchor block numbers to be within valid bounds and ensure progression.
fn adjust_anchor_numbers(
    manifest: &mut DerivationSourceManifest,
    origin_block_number: u64,
    parent_anchor_block_number: u64,
    is_forced_inclusion: bool,
) -> bool {
    let mut parent_anchor = parent_anchor_block_number;
    let mut highest_anchor = parent_anchor_block_number;

    for block in &mut manifest.blocks {
        if block.anchor_block_number < parent_anchor {
            block.anchor_block_number = parent_anchor;
        }

        let future_reference_limit = origin_block_number.saturating_sub(MIN_ANCHOR_OFFSET);
        if block.anchor_block_number >= future_reference_limit {
            block.anchor_block_number = parent_anchor;
        }

        if origin_block_number > MAX_ANCHOR_OFFSET {
            let min_allowed = origin_block_number - MAX_ANCHOR_OFFSET;
            if block.anchor_block_number < min_allowed {
                block.anchor_block_number = parent_anchor;
            }
        }

        if block.anchor_block_number > highest_anchor {
            highest_anchor = block.anchor_block_number;
        }

        parent_anchor = block.anchor_block_number;
    }

    // Non-forced-inclusion proposals must advance the anchor block number to ensure
    // that each new proposal references a more recent anchor block, maintaining protocol
    // liveness and preventing replay or stalling attacks. Forced-inclusion proposals are
    // exempt from this rule to allow for exceptional cases.
    if !is_forced_inclusion && highest_anchor <= parent_anchor_block_number {
        return false;
    }

    true
}

// Adjust coinbase values to ensure they are set to the proposer when appropriate.
fn adjust_coinbase(
    manifest: &mut DerivationSourceManifest,
    proposer: Address,
    is_forced_inclusion: bool,
) {
    for block in &mut manifest.blocks {
        if is_forced_inclusion || block.coinbase == Address::ZERO {
            block.coinbase = proposer;
        }
    }
}

// Adjust gas limits to be within valid bounds.
fn adjust_gas_limit(
    manifest: &mut DerivationSourceManifest,
    parent_block_number: u64,
    parent_gas_limit: u64,
) {
    let mut effective_parent_gas_limit = if parent_block_number == 0 {
        parent_gas_limit
    } else {
        parent_gas_limit.saturating_sub(ANCHOR_V3_GAS_LIMIT)
    };

    for block in &mut manifest.blocks {
        if block.gas_limit == 0 {
            block.gas_limit = effective_parent_gas_limit;
        }

        let parent = effective_parent_gas_limit as u128;
        let denominator = u128::from(GAS_LIMIT_DENOMINATOR);
        let change = u128::from(BLOCK_GAS_LIMIT_MAX_CHANGE);
        let lower_factor = denominator.saturating_sub(change);
        let lower_bound = parent.saturating_mul(lower_factor) / denominator;
        let lower_bound = lower_bound.max(MIN_BLOCK_GAS_LIMIT as u128) as u64;

        let upper_factor = denominator.saturating_add(change);
        let upper_bound = parent.saturating_mul(upper_factor) / denominator;
        let upper_bound = upper_bound.min(MAX_BLOCK_GAS_LIMIT as u128) as u64;

        if block.gas_limit < lower_bound {
            block.gas_limit = lower_bound;
        }

        if block.gas_limit > upper_bound {
            block.gas_limit = upper_bound;
        }

        effective_parent_gas_limit = block.gas_limit;
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
    fn adjust_timestamp_bounds() {
        let parent_timestamp = 1_000;
        let proposal_timestamp = 2_000;
        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            timestamp: proposal_timestamp + 100,
            coinbase: Address::ZERO,
            anchor_block_number: 0,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);

        adjust_timestamps(&mut manifest, parent_timestamp, proposal_timestamp);
        assert_eq!(manifest.blocks[0].timestamp, proposal_timestamp);

        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            timestamp: parent_timestamp,
            coinbase: Address::ZERO,
            anchor_block_number: 0,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);
        adjust_timestamps(&mut manifest, parent_timestamp, proposal_timestamp);
        let lower_bound =
            (parent_timestamp + 1).max(proposal_timestamp.saturating_sub(TIMESTAMP_MAX_OFFSET));
        assert_eq!(manifest.blocks[0].timestamp, lower_bound);
    }

    #[test]
    fn adjust_anchor_numbers_checks_progression() {
        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            anchor_block_number: 50,
            timestamp: 0,
            coinbase: Address::ZERO,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);

        let ok = adjust_anchor_numbers(&mut manifest, 100, 60, false);
        assert!(!ok);
        assert_eq!(manifest.blocks[0].anchor_block_number, 60);

        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            anchor_block_number: 80,
            timestamp: 0,
            coinbase: Address::ZERO,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);

        let ok = adjust_anchor_numbers(&mut manifest, 100, 60, false);
        assert!(ok);
        assert_eq!(manifest.blocks[0].anchor_block_number, 80);
    }

    #[test]
    fn coinbase_assignment_prioritises_proposer() {
        let proposer = Address::from([1u8; 20]);
        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            coinbase: Address::ZERO,
            timestamp: 0,
            anchor_block_number: 0,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);

        adjust_coinbase(&mut manifest, proposer, false);
        assert_eq!(manifest.blocks[0].coinbase, proposer);

        let other = Address::from([2u8; 20]);
        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            coinbase: other,
            timestamp: 0,
            anchor_block_number: 0,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);

        adjust_coinbase(&mut manifest, proposer, true);
        assert_eq!(manifest.blocks[0].coinbase, proposer);
    }

    #[test]
    fn gas_limit_is_clamped_within_bounds() {
        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            gas_limit: 0,
            timestamp: 0,
            anchor_block_number: 0,
            coinbase: Address::ZERO,
            transactions: Vec::new(),
        }]);

        adjust_gas_limit(&mut manifest, 10, 20_000_000);
        assert_eq!(manifest.blocks[0].gas_limit, 19_000_000);

        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            gas_limit: 1,
            timestamp: 0,
            anchor_block_number: 0,
            coinbase: Address::ZERO,
            transactions: Vec::new(),
        }]);

        adjust_gas_limit(&mut manifest, 0, 20_000_000);
        assert!(manifest.blocks[0].gas_limit >= MIN_BLOCK_GAS_LIMIT);
    }

    #[test]
    fn validate_manifest_returns_default_on_anchor_failure() {
        let mut manifest = manifest_with_blocks(vec![BlockManifest {
            anchor_block_number: 1,
            coinbase: Address::ZERO,
            timestamp: 0,
            gas_limit: 0,
            transactions: Vec::new(),
        }]);

        let ctx = ValidationContext {
            parent_timestamp: 0,
            parent_gas_limit: 20_000_000,
            parent_block_number: 1,
            parent_anchor_block_number: 10,
            proposal_timestamp: 100,
            origin_block_number: 20,
            proposer: Address::from([3u8; 20]),
            is_forced_inclusion: false,
        };

        let err = validate_source_manifest(&mut manifest, &ctx).unwrap_err();
        assert_eq!(err, ValidationError::DefaultManifest);
    }
}
