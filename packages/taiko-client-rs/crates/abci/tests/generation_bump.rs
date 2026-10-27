//! Docker scenario: planting `recoveryGeneration = 1` into the Inbox supersedes the generation-0
//! chain. Once a proposal anchors at a final L1 block that carries the bump, the app sets
//! terminal private trust and the supervisor durably stops Comet and its signer.
//!
//! The fake lander advances only `lastCheckpoint`; committee bootstrap is immutable and runtime
//! activation needs no publication, so settlement never overwrites the planted generation.

use std::time::{Duration, Instant};

use abci::l1::layout::inbox;
use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::Context;
use test_harness::{Devnet, DevnetSpec, InboxValues, extra_data_of, wait_until};

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

    let latch = devnet.app_data_dir(0).join("validator-supervisor.halted");
    wait_until(
        "terminal generation latch",
        Duration::from_secs(30),
        Duration::from_millis(100),
        || async { Ok(latch.is_file().then_some(())) },
    )
    .await?;
    let stop = devnet.l2_provider(0).get_block_number().await?;
    let state = devnet.signer_state(0)?;
    let delegated = devnet.signer_authorizations(0)?;
    let hold_end = Instant::now() + spec.stall_hold();
    while Instant::now() < hold_end {
        assert_eq!(devnet.l2_provider(0).get_block_number().await?, stop);
        assert_eq!(devnet.signer_state(0)?, state);
        assert_eq!(devnet.signer_authorizations(0)?, delegated);
        let trust = devnet.trust_control(0, "unregistered-observer").await?;
        assert_eq!(trust["trust_ready"], false);
        assert_eq!(trust["phase"], "halted");
        assert!(latch.is_file());
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
    assert!(stop <= planted_at + MAX_BLOCKS_AFTER_PLANT);
    eprintln!("generation bump durably latched at {stop}; no signatures or restarts");

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
