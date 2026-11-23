//! Docker scenario: no block anchors above anvil's `finalized`, and the chain does not wait for
//! L1: with L1 paused, it keeps producing past a target height on anchors L1 already finalized,
//! each block's signing set decided from the anchor it inherits.
//!
//! A legal unsettled limit `U = 18` leaves room for the blocks past the pause, so the fake
//! lander's `lastCheckpoint`, frozen with L1 and trailing the head by a few blocks, does not stop
//! the chain before it passes the target.

use std::time::{Duration, Instant};

use anyhow::ensure;
use test_harness::{Devnet, DevnetSpec, anchor_of, finalized_number, wait_until};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn a_paused_l1_does_not_stop_the_chain() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec { unsettled_limit: 18, ..Default::default() };
    let devnet = Devnet::start(spec.clone()).await?;
    // The height the chain must pass while L1 is paused.
    let target = 21;
    let l1 = devnet.l1();
    let l2 = devnet.l2_provider(0);

    // Pause L1 before the target; each block decides its successor's successor from the anchor
    // it inherits and its own L2 state.
    let pause_at = target - 7;
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
    ensure!(status.head < target, "the chain reached the target before L1 paused");
    let limit = devnet.params().unsettled_limit;
    ensure!(
        status.last_checkpoint_height + limit > target,
        "back-pressure would stop the chain at {} before the target {target}",
        status.last_checkpoint_height + limit
    );

    // The chain keeps producing on the frozen anchor past the target.
    let past = target + 1;
    devnet.wait_for_height(0, past, Duration::from_secs(40)).await?;
    assert_eq!(finalized_number(l1).await?, frozen, "L1 finalized moved while paused");
    for h in 1..=past {
        let anchor = anchor_of(&l2, h).await?;
        assert!(anchor <= frozen, "block {h}: anchor {anchor} above L1 finalized {frozen}");
    }
    let status = devnet.abci_status(0).await?;
    assert!(status.head >= past, "the chain passed the target: {status:?}");
    assert_eq!(devnet.app_halt(0), None);

    devnet.l1_resume().await?;
    devnet.stop().await?;
    eprintln!("anchor-finality scenario done after {:?}", started.elapsed());
    Ok(())
}
