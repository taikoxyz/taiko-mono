//! Docker scenario 1 (spec §9.2): a one-validator devnet produces blocks, includes the
//! transactions sent to its EL, and every block follows the header rules of spec §4.2.

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use abci::{ChainParams, rules::decode_extra_data};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{U256, address};
use alloy_provider::Provider;
use anyhow::{Context, ensure};
use test_harness::{Devnet, DevnetSpec, dev_signer, finalized_number, send_transfer, wait_until};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn single_validator_produces_blocks_by_the_header_rules() -> anyhow::Result<()> {
    let started = Instant::now();
    let devnet = Devnet::start(DevnetSpec::default()).await?;
    devnet.wait_for_height(0, 1, Duration::from_secs(60)).await?;

    // Two EIP-1559 transfers into reth 0's pool; the EL selects them when the app builds.
    let l2 = devnet.l2_provider(0);
    let signer = dev_signer();
    let nonce = l2.get_transaction_count(signer.address()).await?;
    let to = address!("00000000000000000000000000000000000c0ffe");
    let mut txs = Vec::new();
    for i in 0..2 {
        txs.push(send_transfer(&l2, &signer, to, U256::from(1_000 + i), nonce + i).await?);
    }
    let l2_ref = &l2;
    let mut tx_blocks = BTreeSet::new();
    for tx in &txs {
        let receipt = wait_until(
            &format!("receipt of {tx}"),
            Duration::from_secs(60),
            Duration::from_millis(250),
            || async move { Ok(l2_ref.get_transaction_receipt(*tx).await?) },
        )
        .await?;
        ensure!(receipt.status(), "transfer {tx} failed");
        tx_blocks.insert(receipt.block_number.context("receipt without a block number")?);
    }
    eprintln!("transfers included in L2 blocks {tx_blocks:?} after {:?}", started.elapsed());
    ensure!(
        l2.get_balance(to).await? == U256::from(2_001),
        "the recipient did not receive both transfers"
    );

    // Every L2 block up to the head follows spec §4.2; CometBFT commits each block's hash. Run a
    // few blocks past the transfers so the anchor moves several times.
    let last_tx_block = tx_blocks.last().copied().unwrap_or_default();
    devnet.wait_for_height(0, (last_tx_block + 4).max(10), Duration::from_secs(60)).await?;
    let head = l2.get_block_number().await?;
    devnet.wait_for_height(0, head + 1, Duration::from_secs(30)).await?;
    let fee_vault = ChainParams::builtin(devnet.params().l2_chain_id)?.fee_vault;
    let gas_limit = devnet.params().block_gas_limit;
    let l1 = devnet.l1();
    let finalized = finalized_number(l1).await?;
    let genesis =
        l2.get_block_by_number(BlockNumberOrTag::Number(0)).await?.context("no L2 block 0")?;
    let mut prev_timestamp = genesis.header.timestamp;
    let mut prev_anchor = devnet.activation().l1_0;
    for h in 1..=head {
        let block =
            l2.get_block_by_number(BlockNumberOrTag::Number(h)).await?.context("missing block")?;
        let header = &block.header;
        assert_eq!(header.beneficiary, fee_vault, "block {h}: coinbase");
        let (pctg, generation, anchor) = decode_extra_data(&header.extra_data)?;
        assert_eq!((pctg, generation), (100, 0), "block {h}: extraData pctg / generation");
        assert!(anchor >= prev_anchor, "block {h}: anchor {anchor} below {prev_anchor}");
        assert!(anchor <= finalized, "block {h}: anchor {anchor} above L1 finalized {finalized}");
        let l1_block = l1
            .get_block_by_number(BlockNumberOrTag::Number(anchor))
            .await?
            .with_context(|| format!("no L1 block {anchor}"))?;
        assert_eq!(
            header.parent_beacon_block_root,
            Some(l1_block.header.state_root),
            "block {h}: parentBeaconBlockRoot is not the state root of L1 block {anchor}"
        );
        assert!(header.timestamp > prev_timestamp, "block {h}: timestamp not increasing");
        assert_eq!(header.gas_limit, gas_limit, "block {h}: gasLimit");
        if tx_blocks.contains(&h) {
            assert!(header.difficulty > U256::ZERO, "block {h}: zero zk gas with transactions");
        }
        let app_hash = devnet.cmt(0).header_app_hash(h + 1).await?;
        assert_eq!(app_hash, header.hash, "CometBFT header {} app_hash", h + 1);
        prev_timestamp = header.timestamp;
        prev_anchor = anchor;
    }
    eprintln!("checked L2 blocks 1..={head}; last anchor {prev_anchor}, L1 finalized {finalized}");
    assert!(prev_anchor > devnet.activation().l1_0, "the anchor never moved past L1_0");

    let status = devnet.abci_status(0).await?;
    let l2_head = l2.get_block_number().await?;
    assert!(status.head.abs_diff(l2_head) <= 1, "app head {} vs L2 head {l2_head}", status.head);
    assert_eq!(status.generation, 0);
    assert!(!status.superseded);
    assert_eq!(devnet.app_halt(0), None);

    devnet.stop().await?;
    eprintln!("scenario 1 done after {:?}", started.elapsed());
    Ok(())
}
