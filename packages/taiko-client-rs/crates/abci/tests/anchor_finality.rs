//! Docker scenario: no block anchors above anvil's `finalized`, and an epoch boundary does not
//! wait for L1: with L1 paused, the chain enters the next epoch on anchors L1 already finalized.
//!
//! A legal independent unsettled cap `U = 18` leaves room across `L = 20`, so the fake
//! lander's `lastCheckpoint`, frozen with L1 and trailing the head by a few blocks, does not stop
//! the chain before it passes the boundary.

use std::time::{Duration, Instant};

use anyhow::ensure;
use test_harness::{Devnet, DevnetSpec, anchor_of, finalized_number, wait_until};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn an_epoch_boundary_does_not_wait_for_l1() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec { epoch_len: 20, unsettled_limit: 18, ..Default::default() };
    let devnet = Devnet::start(spec.clone()).await?;
    let schedule = devnet.schedule();
    let boundary = schedule.h_first(1);
    let l1 = devnet.l1();
    let l2 = devnet.l2_provider(0);

    // Pause L1 before the epoch boundary; switching requires only the embedded snapshot.
    let pause_at = boundary - 7;
    wait_until("the pause point", Duration::from_secs(90), Duration::from_millis(250), || async {
        Ok((devnet.cmt(0).latest_height().await? >= pause_at).then_some(()))
    })
    .await?;
    devnet.l1_pause().await?;
    tokio::time::sleep(Duration::from_millis(1500)).await;
    let frozen = finalized_number(l1).await?;
    let status = devnet.abci_status(0).await?;
    eprintln!(
        "L1 paused at finalized {frozen}, CometBFT height {}, after {:?}",
        status.head,
        started.elapsed()
    );
    ensure!(status.head < boundary, "the chain reached the boundary before L1 paused");
    let cap = devnet.params().unsettled_cap();
    ensure!(
        status.last_checkpoint_height + cap > boundary,
        "back-pressure would stop the chain at {} before the boundary {boundary}",
        status.last_checkpoint_height + cap
    );

    // The chain keeps producing on the frozen anchor through the boundary.
    let past = boundary + 1;
    devnet.wait_for_height(0, past, Duration::from_secs(40)).await?;
    assert_eq!(finalized_number(l1).await?, frozen, "L1 finalized moved while paused");
    for h in 1..=past {
        let anchor = anchor_of(&l2, h).await?;
        assert!(anchor <= frozen, "block {h}: anchor {anchor} above L1 finalized {frozen}");
    }
    let status = devnet.abci_status(0).await?;
    assert!(status.epoch >= 1, "the chain entered epoch 1: {status:?}");
    assert_eq!(devnet.app_halt(0), None);

    devnet.l1_resume().await?;
    devnet.stop().await?;
    eprintln!("anchor-finality scenario done after {:?}", started.elapsed());
    Ok(())
}
