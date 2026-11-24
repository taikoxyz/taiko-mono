//! L2 (alethia-reth) helpers: transfers and the `extraData` of committed blocks.

use std::{
    sync::atomic::{AtomicU64, Ordering},
    time::Duration,
};

use abci::rules::{ExtraData, decode_extra_data};
use alloy::{
    consensus::{SignableTransaction, TxEip1559, TxEnvelope},
    signers::{SignerSync, local::PrivateKeySigner},
};
use alloy_eips::{BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{Address, B256, TxKind, U256, b256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result};

use crate::{cometbft::CmtClient, wait::wait_until};

/// Private key of anvil's first dev account (`0xf39F…2266`), which the alethia-reth devnet
/// genesis funds.
pub const DEV_KEY: B256 = b256!("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");

/// Priority fee of [`sign_transfer`]'s transactions: 1 gwei.
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
    let envelope = sign_transfer(l2, signer, to, value, nonce).await?;
    let pending = l2.send_raw_transaction(&envelope.encoded_2718()).await?;
    Ok(*pending.tx_hash())
}

/// Signs an EIP-1559 transfer of `value` wei to `to` from `signer` with `nonce` for `l2`'s chain
/// (21 000 gas, a 1 gwei priority fee and a max fee of twice the latest base fee plus it) without
/// sending it.
pub async fn sign_transfer(
    l2: &RootProvider,
    signer: &PrivateKeySigner,
    to: Address,
    value: U256,
    nonce: u64,
) -> Result<TxEnvelope> {
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
    Ok(TxEnvelope::Eip1559(tx.into_signed(signature)))
}

/// The decoded `extraData` of L2 block `h`: its generation and anchor L1 block number.
pub async fn extra_data_of(l2: &RootProvider, h: u64) -> Result<ExtraData> {
    let block = l2
        .get_block_by_number(BlockNumberOrTag::Number(h))
        .await?
        .with_context(|| format!("L2 block {h} missing"))?;
    Ok(decode_extra_data(&block.header.extra_data)?)
}

/// The anchor L1 block number in the `extraData` of L2 block `h`.
pub async fn anchor_of(l2: &RootProvider, h: u64) -> Result<u64> {
    Ok(extra_data_of(l2, h).await?.anchor)
}

/// The first height above `from` whose anchor, carried or inherited, is L1 block `l1` or later:
/// heights are read in order once `cmt` has committed their successor, from `l2`. Fails after
/// `timeout`, naming the height it stopped at and the last error, if any, and at once when
/// `apps_running` fails with a [`Fatal`](crate::wait::Fatal) error, as
/// [`Devnet::check_apps`](crate::Devnet::check_apps) and
/// [`ContractConsensus::check_apps`](crate::ContractConsensus::check_apps) do for an app that
/// halted or stopped on its own.
pub async fn first_anchored_at(
    cmt: &CmtClient,
    l2: &RootProvider,
    from: u64,
    l1: u64,
    timeout: Duration,
    apps_running: impl Fn() -> Result<()>,
) -> Result<u64> {
    let next = AtomicU64::new(from + 1);
    let next = &next;
    let apps_running = &apps_running;
    wait_until(
        &format!("a block above {from} anchored at L1 block {l1} or later"),
        timeout,
        Duration::from_millis(250),
        || async move {
            apps_running()?;
            let h = next.load(Ordering::Relaxed);
            if cmt.latest_height().await? <= h {
                return Ok(None);
            }
            let anchor = anchor_of(l2, h).await?;
            if anchor >= l1 {
                return Ok(Some(h));
            }
            next.store(h + 1, Ordering::Relaxed);
            Ok(None)
        },
    )
    .await
    .with_context(|| format!("stopped at height {}", next.load(Ordering::Relaxed)))
}

#[cfg(test)]
mod tests {
    use std::time::Instant;

    use anyhow::anyhow;
    use rpc::client::connect_http_with_timeout;
    use url::Url;

    use super::*;
    use crate::wait::Fatal;

    #[tokio::test]
    async fn a_halted_app_ends_the_anchor_wait_at_once() {
        // Nothing serves this address; the halt is seen before any read.
        let unused: Url = "http://127.0.0.1:9".parse().expect("a valid URL");
        let cmt = CmtClient::new(unused.clone());
        let l2 = connect_http_with_timeout(unused, Duration::from_secs(1));
        let started = Instant::now();
        let err = first_anchored_at(&cmt, &l2, 5, 100, Duration::from_secs(60), || {
            Err(Fatal(anyhow!("app 0 halted: boom")).into())
        })
        .await
        .expect_err("a halted app fails the wait");
        assert!(started.elapsed() < Duration::from_secs(5), "waited {:?}", started.elapsed());
        let message = format!("{err:#}");
        assert!(message.contains("app 0 halted: boom"), "{message}");
        assert!(message.contains("stopped at height 6"), "{message}");
    }
}
