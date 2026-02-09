//! Transfer transaction building for E2E tests.

use alloy_consensus::{EthereumTypedTransaction, SignableTransaction, TxEip1559, TxEnvelope};
use alloy_eips::{BlockId, BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{Address, B256, Bytes, TxKind, U256};
use alloy_provider::Provider;
use alloy_signer::Signer;
use alloy_signer_local::PrivateKeySigner;
use anyhow::Result;

use super::compute_next_block_base_fee;
use crate::PRIORITY_FEE_GWEI;

/// A signed transfer transaction with expected hash and sender for assertions.
///
/// This struct captures everything needed to verify a transfer was included
/// in a block with the correct details.
#[derive(Clone, Debug)]
pub struct TransferPayload {
    /// The raw RLP-encoded transaction bytes.
    pub raw_bytes: Bytes,
    /// The transaction hash (for matching in block).
    pub hash: B256,
    /// The sender address (for signer verification).
    pub from: Address,
}

/// Builds and signs an EIP-1559 transfer transaction.
///
/// Creates a simple ETH transfer with:
/// - Gas limit of 21,000 (standard transfer).
/// - Max priority fee of `PRIORITY_FEE_GWEI`.
/// - Max fee calculated from base fee + priority fee.
///
/// # Arguments
///
/// * `provider` - Provider to fetch nonce and chain ID.
/// * `block_number` - Target block number (used to calculate base fee).
/// * `private_key` - Hex-encoded private key (with or without 0x prefix).
/// * `to` - Recipient address.
/// * `value` - Amount to transfer in wei.
///
/// # Returns
///
/// A `TransferPayload` containing the signed transaction bytes, hash, and sender.
///
/// # Example
///
/// ```ignore
/// let transfer = build_signed_transfer(
///     &provider,
///     100,
///     "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
///     Address::repeat_byte(0x11),
///     U256::from(1_000_000_000_000_000_000u128), // 1 ETH
/// ).await?;
///
/// assert_eq!(transfer.hash, expected_hash);
/// ```
pub async fn build_signed_transfer<P>(
    provider: &P,
    block_number: u64,
    private_key: &str,
    to: Address,
    value: U256,
) -> Result<TransferPayload>
where
    P: Provider + Send + Sync,
{
    let signer: PrivateKeySigner = private_key.parse()?;
    let from = signer.address();

    let nonce = provider
        .get_transaction_count(from)
        // Use on-chain nonce to avoid stale pending txs after L2 resets in tests.
        .block_id(BlockId::Number(BlockNumberOrTag::Latest))
        .await?;
    let chain_id = provider.get_chain_id().await?;
    let base_fee = compute_next_block_base_fee(provider, block_number.saturating_sub(1)).await?;

    let tx = TxEip1559 {
        chain_id,
        nonce,
        max_fee_per_gas: PRIORITY_FEE_GWEI + u128::from(base_fee),
        max_priority_fee_per_gas: PRIORITY_FEE_GWEI,
        gas_limit: 21_000,
        to: TxKind::Call(to),
        value,
        ..Default::default()
    };

    let signature = signer.sign_hash(&tx.signature_hash()).await?;
    let envelope = TxEnvelope::new_unhashed(EthereumTypedTransaction::Eip1559(tx), signature);

    Ok(TransferPayload { raw_bytes: envelope.encoded_2718().into(), hash: *envelope.hash(), from })
}
