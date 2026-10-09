//! Docker scenario 5 (spec §9.2): no block anchors above anvil's `finalized`, and entering an
//! epoch waits for L1 to reach the epoch's first L1 block `L1_first(e)` as `finalized`.
//!
//! `EPOCH_LEN_L1 = 30` makes epoch 1 need an anchor at `L1_0 + 30`, which anvil's `finalized`
//! (one block per second, two behind the tip) only reaches after the chain arrives at the epoch
//! boundary. `D_MAX = 19` gives the unsettled cap `U = 17` (the most `L = 20` allows), so the fake
//! lander's `lastCheckpoint`, frozen with L1 and trailing the head by a few blocks, never stops
//! the chain before the boundary does.

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use abci::l1::layout::inbox;
use alloy_eips::BlockId;
use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::ensure;
use test_harness::{Devnet, DevnetSpec, anchor_of, block_number, finalized_number, wait_until};

/// The `/status` halt reason of the epoch entry rule (`RuleViolation::EpochNotOpenOnL1`).
const EPOCH_RULE: &str = "epoch_not_open_on_l1";

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn anchor_finality_gates_epoch_entry() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec {
        epoch_len: 20,
        epoch_len_l1: 30,
        d_max: 19,
        margin_v: 2,
        ..Default::default()
    };
    let devnet = Devnet::start(spec.clone()).await?;
    let schedule = devnet.schedule();
    let boundary = schedule.h_first(1);
    let last = boundary - 1;
    let l1 = devnet.l1();
    let l2 = devnet.l2_provider(0);

    // Pause L1 a few blocks before the boundary, once committee[1] has landed in a final L1
    // block (the switch height `boundary - 2` proves it at the frozen anchor).
    let pause_at = boundary - 7;
    let inbox_address = devnet.params().inbox;
    wait_until("the pause point", Duration::from_secs(90), Duration::from_millis(250), || async {
        let height = devnet.cmt(0).latest_height().await?;
        let finalized = finalized_number(l1).await?;
        let landed = l1
            .get_storage_at(inbox_address, U256::from_be_bytes(inbox::committee_slot(1).0))
            .block_id(BlockId::number(finalized))
            .await?;
        Ok((height >= pause_at && !landed.is_zero()).then_some(()))
    })
    .await?;
    devnet.l1_pause().await?;
    tokio::time::sleep(Duration::from_millis(1500)).await;
    let frozen = finalized_number(l1).await?;
    let paused_at = devnet.cmt(0).latest_height().await?;
    eprintln!(
        "L1 paused at finalized {frozen}, CometBFT height {paused_at}, after {:?}",
        started.elapsed()
    );
    ensure!(paused_at < last, "the chain reached the boundary before L1 paused");
    let l1_first = schedule.l1_first(1);
    ensure!(l1_first > frozen, "L1_first(1) = {l1_first} is already final ({frozen})");

    // The chain keeps producing on the frozen anchor up to the boundary, then stops there.
    let reached = devnet.wait_for_height(0, last, Duration::from_secs(40)).await?;
    assert_eq!(reached, last, "the chain passed the epoch boundary with L1 paused");
    let hold = Duration::from_millis(3 * spec.timeout_commit_ms) + Duration::from_secs(2);
    let hold_end = Instant::now() + hold;
    let mut reasons = BTreeSet::new();
    let mut reason = None;
    while Instant::now() < hold_end {
        let height = devnet.cmt(0).latest_height().await?;
        assert_eq!(height, last, "CometBFT moved past the boundary with L1 paused");
        reason = devnet.abci_status(0).await?.halt_reason;
        reasons.extend(reason.clone());
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
    // `None` only between the last commit and the first refused build at the boundary.
    eprintln!("halt reasons seen while stalled: {reasons:?}");
    assert_eq!(reason.as_deref(), Some(EPOCH_RULE), "/status halt reason");
    assert_eq!(reasons, BTreeSet::from([EPOCH_RULE.to_string()]), "/status halt reasons");
    assert_eq!(finalized_number(l1).await?, frozen, "L1 finalized moved while paused");
    assert_eq!(l2.get_block_number().await?, last, "the EL moved past the boundary");
    for h in 1..=last {
        let anchor = anchor_of(&l2, h).await?;
        assert!(anchor <= frozen, "block {h}: anchor {anchor} above L1 finalized {frozen}");
    }
    assert_eq!(devnet.app_halt(0), None);

    // Once L1 finalizes L1_first(1), the chain enters epoch 1.
    devnet.l1_resume().await?;
    let tip = block_number(l1).await?;
    let wait = Duration::from_secs((l1_first + 2).saturating_sub(tip) + 30);
    let resumed = Instant::now();
    devnet.wait_for_height(0, boundary + 1, wait).await?;
    eprintln!("past the boundary {:?} after resuming L1", resumed.elapsed());
    let finalized = finalized_number(l1).await?;
    for h in 1..=boundary {
        let anchor = anchor_of(&l2, h).await?;
        assert!(anchor <= finalized, "block {h}: anchor {anchor} above L1 finalized {finalized}");
    }
    let entry = anchor_of(&l2, boundary).await?;
    assert!(entry >= l1_first, "block {boundary}: anchor {entry} below L1_first(1) = {l1_first}");
    assert_eq!(devnet.app_halt(0), None);

    devnet.stop().await?;
    eprintln!("scenario 5 done after {:?}", started.elapsed());
    Ok(())
}
