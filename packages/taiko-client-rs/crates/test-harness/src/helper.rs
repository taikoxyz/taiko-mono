use std::borrow::Cow;

use alloy::rpc::client::NoParams;
use alloy_provider::Provider;
use anyhow::Context;
use rpc::client::{Client, ClientWithWallet};

/// Default priority fee for test transactions (10 gwei).
pub const PRIORITY_FEE_GWEI: u128 = 10_000_000_000;

/// Mines a single empty L1 block via the connected execution engine.
pub async fn mine_l1_block<P>(client: &Client<P>) -> anyhow::Result<()>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    client
        .l1_provider
        .raw_request::<_, String>(Cow::Borrowed("evm_mine"), NoParams::default())
        .await
        .context("mining L1 block")?;
    Ok(())
}

/// Mines a single empty L1 block using a wallet-backed client.
pub async fn evm_mine(client: &ClientWithWallet) -> anyhow::Result<()> {
    mine_l1_block(client).await
}

/// Increases L1 time by the specified number of seconds.
pub(crate) async fn increase_l1_time<P>(client: &Client<P>, seconds: u64) -> anyhow::Result<()>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    client
        .l1_provider
        .raw_request::<_, i64>(Cow::Borrowed("evm_increaseTime"), (seconds,))
        .await
        .context("increasing L1 time via evm_increaseTime")?;
    Ok(())
}

/// Mines multiple L1 blocks at once using Anvil's batch mining.
///
/// This is more efficient than calling `mine_l1_block` in a loop.
pub(crate) async fn mine_l1_blocks<P>(client: &Client<P>, count: usize) -> anyhow::Result<()>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    client
        .l1_provider
        .raw_request::<_, ()>(Cow::Borrowed("anvil_mine"), (count,))
        .await
        .context("mining L1 blocks via anvil_mine")?;
    Ok(())
}
