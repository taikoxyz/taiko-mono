//! Block fetching utilities for E2E tests.
//!
//! This module provides helpers for fetching and waiting on blocks:
//! - [`fetch_block_by_number`]: Fetches a block with full transaction details.
//! - [`wait_for_block`]: Polls until a block appears or times out.

use std::time::Duration;

use alloy_consensus::TxEnvelope;
use alloy_eips::BlockNumberOrTag;
use alloy_provider::Provider;
use alloy_rpc_types::eth::Block as RpcBlock;
use anyhow::{Result, anyhow};
use tokio::time::{Instant, sleep};

/// Fetches a block by number with full transaction details.
///
/// Returns the block with transactions deserialized as `TxEnvelope`,
/// which allows inspecting transaction details like hash and signer.
///
/// # Arguments
///
/// * `provider` - An Ethereum provider.
/// * `block_number` - The block number to fetch.
///
/// # Returns
///
/// The block with full transaction details, or an error if not found.
///
/// # Example
///
/// ```ignore
/// let block = fetch_block_by_number(&provider, 100).await?;
/// let txs = block.transactions.as_transactions().unwrap();
/// for tx in txs {
///     println!("tx hash: {}", tx.hash());
/// }
/// ```
pub async fn fetch_block_by_number<P>(
    provider: &P,
    block_number: u64,
) -> Result<RpcBlock<TxEnvelope>>
where
    P: Provider + Send + Sync,
{
    provider
        .get_block_by_number(BlockNumberOrTag::Number(block_number))
        .full()
        .await?
        .map(|b| b.map_transactions(TxEnvelope::from))
        .ok_or_else(|| anyhow!("missing block {block_number}"))
}

/// Polls for a block until it appears or timeout expires.
///
/// This is useful in E2E tests where you need to wait for a block
/// to be produced after sending a preconfirmation.
///
/// # Arguments
///
/// * `provider` - An Ethereum provider.
/// * `block_number` - The block number to wait for.
/// * `timeout` - Maximum time to wait before giving up.
///
/// # Returns
///
/// The block once it appears, or an error if timeout is reached.
///
/// # Example
///
/// ```ignore
/// // Wait up to 30 seconds for block 100
/// let block = wait_for_block(&provider, 100, Duration::from_secs(30)).await?;
/// ```
pub async fn wait_for_block<P>(
    provider: &P,
    block_number: u64,
    timeout: Duration,
) -> Result<RpcBlock<TxEnvelope>>
where
    P: Provider + Send + Sync,
{
    let deadline = Instant::now() + timeout;

    loop {
        if Instant::now() >= deadline {
            return Err(anyhow!("timed out waiting for block {block_number}"));
        }

        if let Ok(Some(block)) =
            provider.get_block_by_number(BlockNumberOrTag::Number(block_number)).full().await
        {
            return Ok(block.map_transactions(TxEnvelope::from));
        }

        sleep(Duration::from_millis(200)).await;
    }
}
