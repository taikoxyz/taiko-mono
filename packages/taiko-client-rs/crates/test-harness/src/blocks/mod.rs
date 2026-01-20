//! Block fetching utilities for E2E tests.
//!
//! This module provides helpers for fetching and waiting on blocks:
//! - [`fetch_block_by_number`]: Fetches a block with full transaction details.
//! - [`wait_for_block`]: Polls until a block appears or times out.
//! - [`wait_for_block_or_loop_error`]: Waits for block while monitoring event loop.
//! - [`wait_for_block_on_both`]: Waits for block on two providers with error handling.

use std::time::Duration;

use alloy_consensus::TxEnvelope;
use alloy_eips::BlockNumberOrTag;
use alloy_provider::Provider;
use alloy_rpc_types::eth::Block as RpcBlock;
use anyhow::{Result, anyhow};
use tokio::{
    sync::oneshot,
    time::{Instant, sleep},
};

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

/// Waits for a block while monitoring an event loop for errors.
///
/// This is a common pattern in E2E tests where we need to wait for block production
/// but also detect if the preconf event loop crashes during the wait.
///
/// # Arguments
///
/// * `provider` - L2 provider to poll for the block.
/// * `block_number` - The block number to wait for.
/// * `timeout` - Maximum time to wait.
/// * `event_loop_rx` - Oneshot receiver from the event loop task.
/// * `loop_name` - Name for error messages (e.g., "preconf event loop").
///
/// # Returns
///
/// The block once it appears, or an error if timeout/event loop failure.
///
/// # Example
///
/// ```ignore
/// let (tx, mut rx) = oneshot::channel();
/// let handle = tokio::spawn(async move { tx.send(event_loop.run().await) });
///
/// let block = wait_for_block_or_loop_error(
///     &provider,
///     100,
///     Duration::from_secs(30),
///     &mut rx,
///     "preconfirmation event loop",
/// ).await?;
/// ```
pub async fn wait_for_block_or_loop_error<P>(
    provider: &P,
    block_number: u64,
    timeout: Duration,
    event_loop_rx: &mut oneshot::Receiver<anyhow::Result<()>>,
    loop_name: &str,
) -> Result<RpcBlock<TxEnvelope>>
where
    P: Provider + Send + Sync,
{
    tokio::select! {
        block = wait_for_block(provider, block_number, timeout) => block,
        result = event_loop_rx => {
            match result {
                Ok(Ok(())) => Err(anyhow!("{loop_name} exited unexpectedly")),
                Ok(Err(err)) => Err(anyhow!("{loop_name} error: {err}")),
                Err(_) => Err(anyhow!("{loop_name} handle dropped")),
            }
        }
    }
}

/// Waits for a block on two providers while monitoring event loops.
///
/// Useful for dual-driver tests where we need to verify block appears on both L2 nodes.
/// Waits sequentially on each provider while monitoring both event loops.
///
/// # Arguments
///
/// * `provider1` - First L2 provider.
/// * `provider2` - Second L2 provider.
/// * `block_number` - The block number to wait for on both providers.
/// * `timeout` - Maximum time to wait per provider.
/// * `event_loop1_rx` - Oneshot receiver from the first event loop.
/// * `event_loop2_rx` - Oneshot receiver from the second event loop.
///
/// # Returns
///
/// A tuple of blocks from each provider.
///
/// # Example
///
/// ```ignore
/// let (block0, block1) = wait_for_block_on_both(
///     &provider0,
///     &provider1,
///     100,
///     Duration::from_secs(30),
///     &mut rx1,
///     &mut rx2,
/// ).await?;
/// ```
pub async fn wait_for_block_on_both<P1, P2>(
    provider1: &P1,
    provider2: &P2,
    block_number: u64,
    timeout: Duration,
    event_loop1_rx: &mut oneshot::Receiver<anyhow::Result<()>>,
    event_loop2_rx: &mut oneshot::Receiver<anyhow::Result<()>>,
) -> Result<(RpcBlock<TxEnvelope>, RpcBlock<TxEnvelope>)>
where
    P1: Provider + Send + Sync,
    P2: Provider + Send + Sync,
{
    let block1 = wait_for_block_or_loop_error(
        provider1,
        block_number,
        timeout,
        event_loop1_rx,
        "event loop 1",
    )
    .await?;

    let block2 = wait_for_block_or_loop_error(
        provider2,
        block_number,
        timeout,
        event_loop2_rx,
        "event loop 2",
    )
    .await?;

    Ok((block1, block2))
}
