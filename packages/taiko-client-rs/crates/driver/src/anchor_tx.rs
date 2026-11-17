//! Shared helper for locating the anchor transaction inside a fetched L2 block.

use alloy_consensus::{TxEnvelope, transaction::Transaction as _};
use alloy_primitives::{Address, Bytes};
use alloy_rpc_types::eth::Block as RpcBlock;

/// Return the calldata of the block's first transaction after verifying it targets the anchor
/// contract.
///
/// Anchor transactions are injected as the first transaction of every non-genesis L2 block, so
/// this is the shared admission preamble for every decoder that recovers anchor call data from
/// a locally fetched block. On failure the static reason describes which structural expectation
/// broke; callers wrap it in their own error type.
pub(crate) fn first_anchor_tx_input(
    block: &RpcBlock<TxEnvelope>,
    anchor_address: Address,
) -> Result<&Bytes, &'static str> {
    let txs = block
        .transactions
        .as_transactions()
        .ok_or("block body returned only transaction hashes")?;
    let first_tx = txs.first().ok_or("block contains no transactions")?;
    let destination = first_tx.to().ok_or("unable to determine anchor transaction recipient")?;
    if destination != anchor_address {
        return Err("first transaction is not the anchor contract");
    }
    Ok(first_tx.input())
}
