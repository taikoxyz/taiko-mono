//! Transaction list building utilities for preconfirmation E2E tests.
//!
//! This module provides helpers for building complete transaction lists:
//! - [`PreconfTxList`]: A complete transaction list ready for publishing.
//! - [`build_preconf_txlist`]: Builds anchor + test transfers in one call.
//! - [`build_mixed_preconf_txlist`]: Builds anchor + one legacy and one EIP-1559 transfer in one
//!   call.

use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_signer_local::PrivateKeySigner;
use anyhow::Result;
use rpc::client::Client;

use super::{
    TransferPayload, build_anchor_tx_bytes, build_signed_legacy_transfer, build_signed_transfer,
    build_test_transfers, funding::DEFAULT_FUND_AMOUNT,
};

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
pub async fn build_preconf_txlist(
    client: &Client,
    parent_hash: B256,
    block_number: u64,
    base_fee: u64,
) -> Result<PreconfTxList> {
    let anchor_tx = build_anchor_tx_bytes(client, parent_hash, block_number, base_fee).await?;
    let transfers = build_test_transfers(&client.l2_provider, block_number).await?;

    let mut raw_tx_bytes = vec![anchor_tx];
    raw_tx_bytes.extend(transfers.iter().map(|t| t.raw_bytes.clone()));

    Ok(PreconfTxList { raw_tx_bytes, transfers })
}

/// Builds a preconfirmation txlist whose transfer set mixes transaction types.
///
/// Identical to [`build_preconf_txlist`] (anchor first, same assembly into a
/// [`PreconfTxList`]) except the transfer set is exactly two transfers of
/// distinct types: one legacy (type-0) and one EIP-1559. This exercises the
/// PR #21906 regression path where a txlist decoder must accept legacy
/// transactions gossiped by Go peers alongside EIP-1559 ones.
///
/// The two transfers come from two distinct accounts, mirroring how
/// [`build_test_transfers`] allocates accounts and nonces — each builder reads
/// its own account's on-chain nonce, so the two transactions get distinct,
/// valid nonces without any manual sequencing:
/// 1. A legacy funder → test-account transfer (from `PRIVATE_KEY`), which also keeps the test
///    account solvent. Unlike [`build_test_transfers`], this funding transfer is always emitted so
///    the txlist deterministically holds exactly two transfers.
/// 2. An EIP-1559 test-account → burn-address transfer (from `TEST_ACCOUNT_PRIVATE_KEY`).
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
/// A `PreconfTxList` containing raw bytes for the commitment and both transfers
/// (legacy first, then EIP-1559) for verification.
///
/// # Example
///
/// ```ignore
/// let txlist = build_mixed_preconf_txlist(
///     &env.client,
///     parent_block.header.hash,
///     commitment_block_num,
///     preconf_base_fee,
/// ).await?;
///
/// // After block production, verify both transfers landed:
/// for transfer in &txlist.transfers {
///     assert!(block_contains_tx(&block, transfer.hash));
/// }
/// ```
pub async fn build_mixed_preconf_txlist(
    client: &Client,
    parent_hash: B256,
    block_number: u64,
    base_fee: u64,
) -> Result<PreconfTxList> {
    let anchor_tx = build_anchor_tx_bytes(client, parent_hash, block_number, base_fee).await?;

    let funder_key = std::env::var("PRIVATE_KEY")?;
    let test_key = std::env::var("TEST_ACCOUNT_PRIVATE_KEY")?;
    let test_address: Address = test_key.parse::<PrivateKeySigner>()?.address();

    // Legacy funder -> test-account transfer (also keeps the test account funded).
    let legacy_transfer = build_signed_legacy_transfer(
        &client.l2_provider,
        block_number,
        &funder_key,
        test_address,
        U256::from(DEFAULT_FUND_AMOUNT),
    )
    .await?;

    // EIP-1559 test-account -> burn-address transfer.
    let eip1559_transfer = build_signed_transfer(
        &client.l2_provider,
        block_number,
        &test_key,
        Address::repeat_byte(0x11),
        U256::from(1u64),
    )
    .await?;

    let transfers = vec![legacy_transfer, eip1559_transfer];

    let mut raw_tx_bytes = vec![anchor_tx];
    raw_tx_bytes.extend(transfers.iter().map(|t| t.raw_bytes.clone()));

    Ok(PreconfTxList { raw_tx_bytes, transfers })
}
