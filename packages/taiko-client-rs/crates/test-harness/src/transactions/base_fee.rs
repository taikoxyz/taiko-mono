//! Base fee calculation for E2E tests.

use alethia_reth_consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy_eips::BlockNumberOrTag;
use alloy_provider::Provider;
use anyhow::{Result, anyhow};

/// Computes the expected base fee for the next block using EIP-4396 rules.
///
/// This function implements the Shasta base fee calculation:
/// - For block 1 (parent is genesis), returns `SHASTA_INITIAL_BASE_FEE`.
/// - For other blocks, calculates based on parent header and time delta.
///
/// # Arguments
///
/// * `provider` - An Ethereum provider to fetch block data.
/// * `parent_block_number` - The parent block number to calculate from.
///
/// # Returns
///
/// The expected base fee in wei for the next block.
///
/// # Example
///
/// ```ignore
/// let base_fee = compute_next_block_base_fee(&provider, 99).await?;
/// // base_fee is what block 100 should have
/// ```
pub async fn compute_next_block_base_fee<P>(provider: &P, parent_block_number: u64) -> Result<u64>
where
    P: Provider + Send + Sync,
{
    let get_block = |n| async move {
        provider
            .get_block_by_number(BlockNumberOrTag::Number(n))
            .await?
            .ok_or_else(|| anyhow!("missing block {n}"))
    };

    let parent_block = get_block(parent_block_number).await?;
    let parent_header = parent_block.header.inner;

    // Genesis block case: return initial base fee.
    if parent_header.number == 0 {
        return Ok(SHASTA_INITIAL_BASE_FEE);
    }

    let grandparent = get_block(parent_block_number.saturating_sub(1)).await?;
    let time_delta = parent_header.timestamp.saturating_sub(grandparent.header.inner.timestamp);
    Ok(calculate_next_block_eip4396_base_fee(&parent_header, time_delta))
}
