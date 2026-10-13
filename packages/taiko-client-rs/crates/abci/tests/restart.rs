//! Docker scenario: stopping the `abci` app mid-chain and starting it again over the same store
//! recovers through the CometBFT handshake; the L2 chain below the old head is unchanged.
//!
//! The "restart before the first block" path (a re-sent `InitChain` over a persisted genesis
//! state) is not driven here: stopping the app between genesis and the first commit is racy
//! against a 1 s cadence, and the unit test `init_chain_is_idempotent_at_genesis` covers it.

use std::time::{Duration, Instant};

use alloy_eips::BlockNumberOrTag;
use alloy_provider::Provider;
use anyhow::Context;
use test_harness::{Devnet, DevnetSpec, wait_until};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn restart_recovers_through_the_handshake() -> anyhow::Result<()> {
    let started = Instant::now();
    let mut devnet = Devnet::start(DevnetSpec::default()).await?;
    // Include an autonomous switch in the persisted history before the crash.
    devnet.wait_for_height(0, devnet.schedule().h_first(1) + 5, Duration::from_secs(90)).await?;

    devnet.app_stop(0).await;
    assert!(!devnet.app_running(0));
    let l2 = devnet.l2_provider(0);
    let old_head = l2.get_block_number().await?;
    let old_hashes = devnet.l2_block_hashes(0, old_head).await?;
    eprintln!("app stopped at L2 head {old_head} after {:?}", started.elapsed());
    // CometBFT loses its ABCI connection and exits; nothing commits while the app is down.
    let devnet_ref = &devnet;
    wait_until(
        "CometBFT exit",
        Duration::from_secs(30),
        Duration::from_millis(250),
        || async move { Ok((!devnet_ref.cmt_running(0).await?).then_some(())) },
    )
    .await?;
    assert_eq!(l2.get_block_number().await?, old_head, "the EL moved without its app");

    devnet.app_start(0).await?;
    devnet.cmt_restart(0).await?;
    eprintln!("app and CometBFT restarted after {:?}", started.elapsed());

    let height = devnet.wait_for_height(0, old_head + 3, Duration::from_secs(60)).await?;
    let l2_ref = &l2;
    wait_until(
        "L2 head past the old head",
        Duration::from_secs(30),
        Duration::from_millis(250),
        || async move { Ok((l2_ref.get_block_number().await? >= old_head + 2).then_some(())) },
    )
    .await?;
    assert_eq!(
        devnet.l2_block_hashes(0, old_head).await?,
        old_hashes,
        "L2 chain changed below the old head"
    );
    for h in 1..=old_head {
        let app_hash = devnet.cmt(0).header_app_hash(h + 1).await?;
        assert_eq!(app_hash, old_hashes[h as usize - 1], "CometBFT header {} app_hash", h + 1);
    }

    let status = devnet.abci_status(0).await?;
    assert!(status.head > old_head, "app head {} not past {old_head}", status.head);
    assert_eq!(devnet.app_halt(0), None);
    eprintln!("CometBFT height {height}, app head {} after {:?}", status.head, started.elapsed());

    devnet.stop().await?;
    Ok(())
}

/// Missing app state is reconstructed from the intact CometBFT history, including committees.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn replay_recovers_after_app_state_is_lost() -> anyhow::Result<()> {
    let mut devnet = Devnet::start(DevnetSpec::default()).await?;
    // Cross an epoch so recovery must reconstruct more than the genesis committee.
    devnet.wait_for_height(0, 26, Duration::from_secs(90)).await?;
    let finalized = devnet
        .l2_provider(0)
        .get_block_by_number(BlockNumberOrTag::Finalized)
        .await?
        .context("missing EL finalized block")?;
    assert!(finalized.header.number > 0, "the EL checkpoint must have advanced");

    let (before, restored) = devnet.replay_after_state_loss(0).await?;
    assert!(restored.last_height >= before.last_height);
    assert_eq!(restored.genesis, before.genesis);
    assert_eq!(restored.committees, before.committees);
    assert_eq!(restored.generation, before.generation);
    assert_eq!(devnet.app_halt(0), None);
    devnet.stop().await?;
    Ok(())
}
