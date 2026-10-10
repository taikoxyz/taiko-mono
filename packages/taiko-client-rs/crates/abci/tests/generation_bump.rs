//! Docker scenario: planting `recoveryGeneration = 1` into the Inbox supersedes the generation-0
//! chain. Once a proposal anchors at a final L1 block that carries the bump, the app sets
//! `/status.superseded` and refuses every proposal from then on: CometBFT stops.
//!
//! The fake lander writes only `lastCheckpoint` and `committee[·]`, so it never overwrites the
//! planted generation.

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use abci::l1::layout::inbox;
use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::Context;
use test_harness::{Devnet, DevnetSpec, InboxValues, extra_data_of, wait_until};

/// The `/status` halt reason of a superseded chain.
const SUPERSEDED: &str = "superseded";

/// Bound on the blocks committed after the planting: the bump lands in one L1 block and becomes
/// final two blocks later (~3 s), the next proposal then anchors on it; 1 s cadence.
const MAX_BLOCKS_AFTER_PLANT: u64 = 8;

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn generation_bump_supersedes_the_chain() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec::default();
    let devnet = Devnet::start(spec.clone()).await?;
    devnet.wait_for_height(0, 5, Duration::from_secs(60)).await?;

    let planted_at = devnet.cmt(0).latest_height().await?;
    let bump = devnet
        .planter()
        .plant_inbox(&InboxValues { recovery_generation: Some(1), ..Default::default() })
        .await?
        .context("the generation write was a no-op")?;
    eprintln!(
        "recoveryGeneration = 1 planted in L1 block {bump} at CometBFT height {planted_at}, \
         after {:?}",
        started.elapsed()
    );

    wait_until(
        "/status superseded",
        Duration::from_secs(30),
        Duration::from_millis(250),
        || async { Ok(devnet.abci_status(0).await?.superseded.then_some(())) },
    )
    .await?;

    // CometBFT stays put.
    let stop = devnet.cmt(0).latest_height().await?;
    let hold_end = Instant::now() + spec.stall_hold();
    let mut reasons = BTreeSet::new();
    while Instant::now() < hold_end {
        assert_eq!(devnet.cmt(0).latest_height().await?, stop, "CometBFT moved after supersession");
        reasons.extend(devnet.abci_status(0).await?.halt_reason);
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
    eprintln!("stopped at height {stop}; halt reasons seen: {reasons:?}");
    assert!(
        stop <= planted_at + MAX_BLOCKS_AFTER_PLANT,
        "{} blocks committed after the planting",
        stop - planted_at
    );
    let status = devnet.abci_status(0).await?;
    assert!(status.superseded);
    assert_eq!(status.halt_reason.as_deref(), Some(SUPERSEDED), "/status halt reason");
    assert_eq!(reasons, BTreeSet::from([SUPERSEDED.to_string()]), "/status halt reasons");
    assert_eq!(status.head, stop);
    assert_eq!(status.generation, 0);
    assert_eq!(devnet.app_halt(0), None, "supersession is a liveness halt, not a safety halt");

    // Every committed block is generation 0 and anchors below the bump.
    let l2 = devnet.l2_provider(0);
    assert_eq!(l2.get_block_number().await?, stop, "the EL moved past CometBFT");
    for h in 1..=stop {
        let (_, generation, anchor) = extra_data_of(&l2, h).await?;
        assert_eq!(generation, 0, "block {h}: extraData generation");
        assert!(anchor < bump, "block {h}: anchor {anchor} carries the bump (L1 block {bump})");
    }
    let generation = devnet.planter().inbox_word(inbox::slot(inbox::RECOVERY_GENERATION)).await?;
    assert_eq!(generation, U256::from(1), "the planted generation was overwritten");

    devnet.stop().await?;
    eprintln!("generation-bump scenario done after {:?}", started.elapsed());
    Ok(())
}
