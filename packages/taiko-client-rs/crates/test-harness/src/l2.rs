//! L2 (alethia-reth) helpers: transfers and the `extraData` of committed blocks.

use abci::rules::decode_extra_data;
use alloy::{
    consensus::{SignableTransaction, TxEip1559, TxEnvelope},
    signers::{SignerSync, local::PrivateKeySigner},
};
use alloy_eips::{BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{Address, B256, TxKind, U256, b256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result};

/// Private key of anvil's first dev account (`0xf39F…2266`), which the alethia-reth devnet
/// genesis funds.
pub const DEV_KEY: B256 = b256!("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");

/// Priority fee of [`send_transfer`]'s transactions: 1 gwei.
const PRIORITY_FEE: u128 = 1_000_000_000;

/// The signer of [`DEV_KEY`].
pub fn dev_signer() -> PrivateKeySigner {
    PrivateKeySigner::from_bytes(&DEV_KEY).expect("DEV_KEY is a valid secp256k1 key")
}

/// Signs an EIP-1559 transfer of `value` wei to `to` from `signer` with `nonce` (21 000 gas, a
/// max fee of twice the latest base fee plus [`PRIORITY_FEE`]) and sends it to `l2`; returns its
/// hash.
pub async fn send_transfer(
    l2: &RootProvider,
    signer: &PrivateKeySigner,
    to: Address,
    value: U256,
    nonce: u64,
) -> Result<B256> {
    let chain_id = l2.get_chain_id().await?;
    let latest = l2
        .get_block_by_number(BlockNumberOrTag::Latest)
        .await?
        .context("L2 has no latest block")?;
    let base_fee = u128::from(latest.header.base_fee_per_gas.context("no base fee")?);
    let tx = TxEip1559 {
        chain_id,
        nonce,
        gas_limit: 21_000,
        max_fee_per_gas: 2 * base_fee + PRIORITY_FEE,
        max_priority_fee_per_gas: PRIORITY_FEE,
        to: TxKind::Call(to),
        value,
        ..Default::default()
    };
    let signature = signer.sign_hash_sync(&tx.signature_hash())?;
    let envelope = TxEnvelope::Eip1559(tx.into_signed(signature));
    let pending = l2.send_raw_transaction(&envelope.encoded_2718()).await?;
    Ok(*pending.tx_hash())
}

/// `(basefee sharing pctg, generation, anchor L1 block number)` from the `extraData` of L2
/// block `h`.
pub async fn extra_data_of(l2: &RootProvider, h: u64) -> Result<(u8, u64, u64)> {
    let block = l2
        .get_block_by_number(BlockNumberOrTag::Number(h))
        .await?
        .with_context(|| format!("L2 block {h} missing"))?;
    Ok(decode_extra_data(&block.header.extra_data)?)
}

/// The anchor L1 block number in the `extraData` of L2 block `h`.
pub async fn anchor_of(l2: &RootProvider, h: u64) -> Result<u64> {
    Ok(extra_data_of(l2, h).await?.2)
}
