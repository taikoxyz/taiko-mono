//! Anchor transaction building for E2E tests.

use alloy_eips::{BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{B256, Bytes, U256};
use alloy_provider::Provider;
use anyhow::{Result, anyhow};
use driver::derivation::pipeline::shasta::anchor::{AnchorTxConstructor, AnchorV4Input};
use rpc::client::Client;

/// Constructs the anchor transaction bytes for a preconfirmation block.
///
/// The anchor transaction is the first transaction in every Taiko L2 block,
/// linking it to a specific L1 block for security.
///
/// This function:
/// 1. Fetches the current L1 block as the anchor.
/// 2. Uses `AnchorTxConstructor` to assemble a proper anchor_v4 transaction.
/// 3. Returns the RLP-encoded transaction bytes.
///
/// # Arguments
///
/// * `client` - Taiko client with L1 and L2 providers.
/// * `parent_hash` - Hash of the L2 parent block.
/// * `block_number` - Target L2 block number.
/// * `base_fee` - Expected base fee for the target block.
///
/// # Returns
///
/// Raw bytes of the signed anchor transaction, ready for inclusion in a txlist.
///
/// # Example
///
/// ```ignore
/// let anchor_tx = build_anchor_tx_bytes(
///     &client,
///     parent_block.header.hash,
///     100,
///     base_fee,
/// ).await?;
///
/// let mut txlist = vec![anchor_tx];
/// txlist.extend(transfer_txs);
/// ```
pub async fn build_anchor_tx_bytes<P>(
    client: &Client<P>,
    parent_hash: B256,
    block_number: u64,
    base_fee: u64,
) -> Result<Bytes>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let anchor_block_number = client.l1_provider.get_block_number().await?;
    let anchor_block = client
        .l1_provider
        .get_block_by_number(BlockNumberOrTag::Number(anchor_block_number))
        .await?
        .ok_or_else(|| anyhow!("missing L1 anchor block {anchor_block_number}"))?;

    let constructor = AnchorTxConstructor::new(client.clone()).await?;
    let tx = constructor
        .assemble_anchor_v4_tx(
            parent_hash,
            AnchorV4Input {
                anchor_block_number,
                anchor_block_hash: anchor_block.header.hash,
                anchor_state_root: anchor_block.header.inner.state_root,
                l2_height: block_number,
                base_fee: U256::from(base_fee),
            },
        )
        .await?;

    Ok(tx.encoded_2718().into())
}
