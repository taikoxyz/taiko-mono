//! Transaction list building utilities for preconfirmation E2E tests.
//!
//! This module provides helpers for building complete transaction lists:
//! - [`PreconfTxList`]: A complete transaction list ready for publishing.
//! - [`build_preconf_txlist`]: Builds anchor + test transfers in one call.
//! - [`build_preconf_txlist_with_transfers`]: Builds anchor + custom transfers.

use alloy_primitives::{B256, Bytes};
use alloy_provider::Provider;
use anyhow::Result;
use rpc::client::Client;

use super::{TransferPayload, build_anchor_tx_bytes, build_test_transfers};

/// A complete transaction list ready for preconfirmation publishing.
///
/// Contains the anchor transaction, any transfer transactions, and the
/// combined raw bytes for building the commitment.
#[derive(Clone, Debug)]
pub struct PreconfTxList {
    /// Raw bytes of all transactions (anchor + transfers).
    pub raw_tx_bytes: Vec<Bytes>,
    /// The transfer payloads (for verification after block production).
    pub transfers: Vec<TransferPayload>,
}

/// Builds a complete transaction list for a preconfirmation block.
///
/// This handles the common pattern of:
/// 1. Building the anchor transaction
/// 2. Ensuring test account is funded
/// 3. Building a test transfer
/// 4. Combining everything into raw bytes
///
/// # Arguments
///
/// * `client` - The Shasta client for L1/L2 access.
/// * `parent_hash` - Parent block hash for the anchor.
/// * `block_number` - Target block number.
/// * `base_fee` - Base fee for the block.
///
/// # Returns
///
/// A `PreconfTxList` containing raw bytes for the commitment and transfers for verification.
///
/// # Example
///
/// ```ignore
/// let txlist = build_preconf_txlist(
///     &env.client,
///     parent_block.header.hash,
///     commitment_block_num,
///     preconf_base_fee,
/// ).await?;
///
/// let (gossip, commitment) = build_publish_payloads_with_txs(
///     &signer_sk, signer, window_end, block_num, timestamp, gas_limit,
///     txlist.raw_tx_bytes,
/// )?;
///
/// // After block production, verify transfers:
/// for transfer in &txlist.transfers {
///     assert!(block_contains_tx(&block, transfer.hash));
/// }
/// ```
pub async fn build_preconf_txlist<P>(
    client: &Client<P>,
    parent_hash: B256,
    block_number: u64,
    base_fee: u64,
) -> Result<PreconfTxList>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let anchor_tx = build_anchor_tx_bytes(client, parent_hash, block_number, base_fee).await?;
    let transfers = build_test_transfers(&client.l2_provider, block_number).await?;

    let mut raw_tx_bytes = vec![anchor_tx];
    raw_tx_bytes.extend(transfers.iter().map(|t| t.raw_bytes.clone()));

    Ok(PreconfTxList { raw_tx_bytes, transfers })
}

/// Builds a transaction list with custom transfers (no automatic funding).
///
/// Use this when you need more control over the transfers included,
/// such as testing specific transaction types or custom amounts.
///
/// # Arguments
///
/// * `client` - The Shasta client for L1/L2 access.
/// * `parent_hash` - Parent block hash for the anchor.
/// * `block_number` - Target block number.
/// * `base_fee` - Base fee for the block.
/// * `transfers` - Custom transfer payloads to include.
///
/// # Example
///
/// ```ignore
/// let custom_transfer = build_signed_transfer(&provider, block, &key, to, amount).await?;
/// let txlist = build_preconf_txlist_with_transfers(
///     &client, parent_hash, block_num, base_fee, vec![custom_transfer]
/// ).await?;
/// ```
pub async fn build_preconf_txlist_with_transfers<P>(
    client: &Client<P>,
    parent_hash: B256,
    block_number: u64,
    base_fee: u64,
    transfers: Vec<TransferPayload>,
) -> Result<PreconfTxList>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let anchor_tx = build_anchor_tx_bytes(client, parent_hash, block_number, base_fee).await?;

    let mut raw_tx_bytes = vec![anchor_tx];
    raw_tx_bytes.extend(transfers.iter().map(|t| t.raw_bytes.clone()));

    Ok(PreconfTxList { raw_tx_bytes, transfers })
}
