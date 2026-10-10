//! Docker scenario: with `lastCheckpoint` frozen on L1 the chain stops at the unsettled depth
//! `U = D_MAX − MARGIN_V` (HALT-03), and a planted advance resumes it.
//!
//! The defaults `D_MAX = 12`, `MARGIN_V = 2` give `U = 10`, comfortably above the ~5–6 blocks the
//! running fake lander's checkpoint trails the head by (its own lag plus L1 finality), so only
//! the paused lander can stop the chain.

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use abci::l1::layout::inbox;
use alloy_provider::Provider;
use test_harness::{Devnet, DevnetSpec};

/// The `/status` halt reason of HALT-03 (`RuleViolation::BackPressure`).
const BACK_PRESSURE: &str = "back_pressure";

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn back_pressure_stops_at_the_unsettled_cap() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec::default();
    let devnet = Devnet::start(spec.clone()).await?;
    let cap = devnet.params().unsettled_cap();
    assert_eq!(cap, spec.d_max - spec.margin_v);
    devnet.wait_for_height(0, 8, Duration::from_secs(60)).await?;

    // Freeze lastCheckpoint: pause the lander (waiting out a landing in flight).
    devnet.lander_pause().await;
    let slot = inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT);
    let frozen = u64::try_from(devnet.planter().inbox_word(slot).await?)?;
    let paused_at = devnet.cmt(0).latest_height().await?;
    eprintln!(
        "lander paused: lastCheckpoint {frozen}, CometBFT height {paused_at}, after {:?}",
        started.elapsed()
    );
    assert!(paused_at < frozen + cap, "the chain is already at the cap");

    // The chain runs up to `frozen + cap` and stops there.
    let stop = frozen + cap;
    let reached = devnet.wait_for_height(0, stop, Duration::from_secs(40)).await?;
    assert_eq!(reached, stop, "the chain passed the unsettled cap");
    let hold_end = Instant::now() + spec.stall_hold();
    let mut reasons = BTreeSet::new();
    let mut status = devnet.abci_status(0).await?;
    while Instant::now() < hold_end {
        let height = devnet.cmt(0).latest_height().await?;
        assert_eq!(height, stop, "CometBFT moved past the unsettled cap");
        status = devnet.abci_status(0).await?;
        reasons.extend(status.halt_reason.clone());
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
    eprintln!("halt reasons seen while stalled: {reasons:?}; status {status:?}");
    assert_eq!(status.halt_reason.as_deref(), Some(BACK_PRESSURE), "/status halt reason");
    assert_eq!(reasons, BTreeSet::from([BACK_PRESSURE.to_string()]), "/status halt reasons");
    assert_eq!(status.head, stop);
    assert_eq!(status.last_checkpoint_height, frozen, "the head's anchored lastCheckpoint");
    assert_eq!(status.head - status.last_checkpoint_height, cap, "unsettled depth at the stall");
    assert_eq!(devnet.l2_provider(0).get_block_number().await?, stop, "the EL moved");
    assert_eq!(devnet.app_halt(0), None);

    // A landed checkpoint lifts the cap.
    devnet.lander_resume();
    let resumed = Instant::now();
    devnet.wait_for_height(0, stop + 3, Duration::from_secs(30)).await?;
    eprintln!("past the cap {:?} after resuming the lander", resumed.elapsed());
    let status = devnet.abci_status(0).await?;
    assert!(status.last_checkpoint_height > frozen, "lastCheckpoint did not advance");
    assert_eq!(devnet.app_halt(0), None);

    devnet.stop().await?;
    eprintln!("back-pressure scenario done after {:?}", started.elapsed());
    Ok(())
}
