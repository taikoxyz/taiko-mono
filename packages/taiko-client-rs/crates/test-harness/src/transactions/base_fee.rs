//! Base fee calculation for E2E tests.

use alethia_reth_consensus::eip4396::{SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee};
use alloy_eips::BlockNumberOrTag;
use alloy_provider::Provider;
use anyhow::{Result, anyhow};
use protocol::shasta::constants::min_base_fee_for_chain;

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
    let parent_block = provider
        .get_block_by_number(BlockNumberOrTag::Number(parent_block_number))
        .await?
        .ok_or_else(|| anyhow!("missing block {parent_block_number}"))?;
    let parent_header = parent_block.header.inner;

    // Genesis block case: return initial base fee.
    if parent_header.number == 0 {
        return Ok(SHASTA_INITIAL_BASE_FEE);
    }

    let grandparent_block_number = parent_block_number.saturating_sub(1);
    let grandparent = provider
        .get_block_by_number(BlockNumberOrTag::Number(grandparent_block_number))
        .await?
        .ok_or_else(|| anyhow!("missing block {grandparent_block_number}"))?;
    let time_delta = parent_header.timestamp.saturating_sub(grandparent.header.inner.timestamp);
    let parent_base_fee_per_gas = parent_header
        .base_fee_per_gas
        .ok_or_else(|| anyhow!("parent block {parent_block_number} missing base fee"))?;
    let chain_id = provider.get_chain_id().await?;
    let min_base_fee = min_base_fee_for_chain(chain_id);
    Ok(calculate_next_block_eip4396_base_fee(
        &parent_header,
        time_delta,
        parent_base_fee_per_gas,
        min_base_fee,
    ))
}
