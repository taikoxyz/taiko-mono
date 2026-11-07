//! Shasta protocol constants and limits.

use std::cmp::min;

pub use alethia_reth_chainspec::{TAIKO_DEVNET_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID};
use alethia_reth_consensus::eip4396::{
    BASE_FEE_MAX_CHANGE_DENOMINATOR, BLOCK_TIME_TARGET, ELASTICITY_MULTIPLIER,
    MAINNET_MIN_BASE_FEE, MAX_BASE_FEE, MAX_GAS_TARGET_PERCENT, MIN_BASE_FEE,
    SHASTA_INITIAL_BASE_FEE,
};

/// Returns the EIP-4396 minimum base-fee clamp for a Taiko chain.
///
/// Taiko mainnet uses a distinct clamp value; all other supported chains use the default.
pub const fn min_base_fee_for_chain(chain_id: u64) -> u64 {
    if chain_id == TAIKO_MAINNET_CHAIN_ID { MAINNET_MIN_BASE_FEE } else { MIN_BASE_FEE }
}

/// Calculate the next EIP-4396 base fee from a parent header and the grandparent timestamp.
///
/// Owns the wrapper logic shared by every fetching call site: a genesis parent yields
/// [`SHASTA_INITIAL_BASE_FEE`], the parent block time is `parent_timestamp -
/// grandparent_timestamp`, and a non-genesis parent missing `base_fee_per_gas` yields `None`
/// for the caller to map into its own error type.
pub fn calculate_next_block_eip4396_base_fee_for_parent(
    parent_number: u64,
    parent_gas_limit: u64,
    parent_gas_used: u64,
    parent_timestamp: u64,
    parent_base_fee_per_gas: Option<u64>,
    grandparent_timestamp: u64,
    min_base_fee_to_clamp: u64,
) -> Option<u64> {
    if parent_number == 0 {
        return Some(SHASTA_INITIAL_BASE_FEE);
    }

    Some(calculate_next_block_eip4396_base_fee_from_parent_values(
        parent_number,
        parent_gas_limit,
        parent_gas_used,
        parent_timestamp.saturating_sub(grandparent_timestamp),
        parent_base_fee_per_gas?,
        min_base_fee_to_clamp,
    ))
}

/// Calculate the next EIP-4396 base fee from parent-header values.
///
/// This mirrors alethia-reth's calculation while accepting raw values, so callers using the
/// workspace's Alloy 1 header type do not need to depend on alethia-reth's Alloy 2 header trait.
pub fn calculate_next_block_eip4396_base_fee_from_parent_values(
    parent_number: u64,
    parent_gas_limit: u64,
    parent_gas_used: u64,
    parent_block_time: u64,
    parent_base_fee_per_gas: u64,
    min_base_fee_to_clamp: u64,
) -> u64 {
    if parent_number == 0 {
        return SHASTA_INITIAL_BASE_FEE;
    }

    let parent_base_gas_target = parent_gas_limit / ELASTICITY_MULTIPLIER;
    let parent_adjusted_gas_target = min(
        parent_base_gas_target * parent_block_time / BLOCK_TIME_TARGET,
        parent_gas_limit * MAX_GAS_TARGET_PERCENT / 100,
    );
    let mut base_fee = parent_base_fee_per_gas;

    match parent_gas_used.cmp(&parent_adjusted_gas_target) {
        core::cmp::Ordering::Equal => {}
        core::cmp::Ordering::Greater => {
            let gas_used_delta = parent_gas_used - parent_adjusted_gas_target;
            let base_fee_per_gas_delta = core::cmp::max(
                parent_base_fee_per_gas as u128 * gas_used_delta as u128 /
                    parent_base_gas_target as u128 /
                    BASE_FEE_MAX_CHANGE_DENOMINATOR,
                1,
            ) as u64;
            base_fee = base_fee.saturating_add(base_fee_per_gas_delta);
        }
        core::cmp::Ordering::Less => {
            let gas_used_delta = parent_adjusted_gas_target - parent_gas_used;
            let base_fee_per_gas_delta = (parent_base_fee_per_gas as u128 * gas_used_delta as u128 /
                parent_base_gas_target as u128 /
                BASE_FEE_MAX_CHANGE_DENOMINATOR) as u64;
            base_fee = base_fee.saturating_sub(base_fee_per_gas_delta);
        }
    }

    base_fee.clamp(min_base_fee_to_clamp, MAX_BASE_FEE)
}
