//! Docker smoke test: a one-validator Etna PoS devnet produces blocks and CometBFT commits the
//! EL's block hashes as app hashes.

use std::time::{Duration, Instant};

use alloy_eips::BlockNumberOrTag;
use alloy_provider::Provider;
use anyhow::Context;
use test_harness::{CmtValidator, Devnet, DevnetSpec};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn devnet_smoke() -> anyhow::Result<()> {
    let started = Instant::now();
    let devnet = Devnet::start(DevnetSpec::default()).await?;
    eprintln!("devnet {} up after {:?}", devnet.id(), started.elapsed());

    let height = devnet.wait_for_height(0, 5, Duration::from_secs(90)).await?;
    eprintln!("CometBFT height {height} after {:?}", started.elapsed());

    let l2 = devnet.l2_provider(0);
    let head = l2.get_block_number().await?;
    assert!(head >= 5, "EL head {head} behind CometBFT height {height}");

    let block1 =
        l2.get_block_by_number(BlockNumberOrTag::Number(1)).await?.context("EL block 1 missing")?;
    let app_hash = devnet.cmt(0).header_app_hash(2).await?;
    assert_eq!(app_hash, block1.header.hash, "CometBFT header 2 app_hash != EL block 1 hash");

    let status = devnet.cmt_status(0).await?;
    let key = devnet.keys()[0].pubkey();
    assert_eq!(status.validators, vec![CmtValidator { pubkey: key, power: 10_000_000_000 }]);

    let app = devnet.abci_status(0).await?;
    assert!(app.head >= 5, "app head {}", app.head);
    assert_eq!(app.generation, 0);
    assert!(!app.superseded);
    assert_eq!(devnet.app_halt(0), None);

    devnet.stop().await?;
    eprintln!("smoke test done after {:?}", started.elapsed());
    Ok(())
}
