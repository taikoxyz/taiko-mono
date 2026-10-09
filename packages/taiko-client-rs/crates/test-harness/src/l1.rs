//! Generic anvil (L1 dev node) helpers.

use std::borrow::Cow;

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256, U256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result};
use serde_json::{Value, json};

/// Sends the JSON-RPC request `method(params)` to anvil and decodes the result as `R`.
pub async fn anvil_request<R>(l1: &RootProvider, method: &'static str, params: Value) -> Result<R>
where
    R: serde::de::DeserializeOwned + std::fmt::Debug + Send + Sync + Unpin + 'static,
{
    l1.raw_request::<_, R>(Cow::Borrowed(method), params)
        .await
        .with_context(|| format!("anvil {method}"))
}

/// Mines `count` blocks at once (`anvil_mine`).
pub async fn mine_l1_blocks(l1: &RootProvider, count: u64) -> Result<()> {
    anvil_request::<Value>(l1, "anvil_mine", json!([count])).await.map(drop)
}

/// Moves L1 time forward by `seconds` and mines one block stamped with the new time.
pub async fn advance_l1_time(l1: &RootProvider, seconds: u64) -> Result<()> {
    anvil_request::<Value>(l1, "evm_increaseTime", json!([seconds])).await?;
    mine_l1_blocks(l1, 1).await
}

/// Sets anvil's interval mining to one block every `secs` seconds; 0 stops mining.
pub async fn set_interval_mining(l1: &RootProvider, secs: u64) -> Result<()> {
    anvil_request::<Value>(l1, "evm_setIntervalMining", json!([secs])).await.map(drop)
}

/// Writes `value` into the storage `slot` of `address` (`anvil_setStorageAt`); it takes effect
/// in the next mined block.
///
/// Out of band: anvil also leaks the write into the historical state of the latest block
/// (proofs at that block stop matching its `stateRoot`), and a zero value stays in the trie as
/// an explicit leaf. Use [`Planter`](crate::Planter) for state the node proves.
pub async fn set_storage(
    l1: &RootProvider,
    address: Address,
    slot: B256,
    value: U256,
) -> Result<()> {
    let ok: bool = anvil_request(
        l1,
        "anvil_setStorageAt",
        json!([address, U256::from_be_bytes(slot.0), B256::from(value)]),
    )
    .await?;
    anyhow::ensure!(ok, "anvil_setStorageAt({address}, {slot}) returned false");
    Ok(())
}

/// The latest block number.
pub async fn block_number(l1: &RootProvider) -> Result<u64> {
    l1.get_block_number().await.context("eth_blockNumber")
}

/// The number of the block under the `finalized` tag.
pub async fn finalized_number(l1: &RootProvider) -> Result<u64> {
    let block = l1
        .get_block_by_number(BlockNumberOrTag::Finalized)
        .await
        .context("eth_getBlockByNumber(finalized)")?
        .context("no finalized block")?;
    Ok(block.header.number)
}
