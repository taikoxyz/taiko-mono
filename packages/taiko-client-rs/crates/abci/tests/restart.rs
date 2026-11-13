//! Docker scenario on one single-validator devnet, whose phases each need a history past the first
//! epoch switch:
//!
//! 1. the switch activated committee 1 from the committed parent anchor, with no committee
//!    publication on L1;
//! 2. stopping the `abci` app mid-chain and starting it again over the same store recovers through
//!    the CometBFT handshake, leaving the L2 chain below the old head unchanged;
//! 3. missing app state is reconstructed from the intact CometBFT history, including committees.
//!
//! The "restart before the first block" path (a re-sent `InitChain` over a persisted genesis
//! state) is not driven here: stopping the app between genesis and the first commit is racy
//! against a 1 s cadence, and the unit test `init_chain_is_idempotent_at_genesis` covers it.

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use abci::key::ConsensusKey;
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::B256;
use alloy_provider::Provider;
use anyhow::Context;
use test_harness::{Devnet, DevnetSpec, wait_until};

/// CometBFT node 0's validator set at `height` as `(pubkey, power)` pairs.
async fn validator_set(
    devnet: &Devnet,
    height: u64,
) -> anyhow::Result<BTreeSet<(ConsensusKey, u64)>> {
    let set = devnet.cmt(0).validators(Some(height)).await?;
    Ok(set.into_iter().map(|v| (v.pubkey, v.power)).collect())
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn first_switch_restart_and_state_loss_recover_on_one_devnet() -> anyhow::Result<()> {
    let started = Instant::now();
    let mut devnet = Devnet::start(DevnetSpec::default()).await?;
    let schedule = devnet.schedule();
    let h = schedule.h_first(1);
    // Include an autonomous switch in the persisted history before any crash.
    devnet.wait_for_height(0, (h + 5).max(26), Duration::from_secs(90)).await?;

    // 1. The first switch derived committee 1 at the committed parent's anchor.
    let committee = devnet.cmt(0).committee(1).await?.expect("switch derives committee 1");
    let parent = devnet
        .l2_provider(0)
        .get_block_by_number(BlockNumberOrTag::Number(
            schedule.derivation_parent_height(1).unwrap(),
        ))
        .await?
        .expect("committed derivation parent");
    let anchor = abci::rules::decode_extra_data(&parent.header.inner.extra_data)?;
    assert_eq!(committee.record.cutoff_l1_block, anchor.2);
    assert_eq!(validator_set(&devnet, h).await?.len(), 1);
    // Slot 278 remains the immutable genesis hash; no epoch mapping exists or is written.
    let bootstrap = devnet
        .planter()
        .inbox_word(abci::l1::layout::inbox::slot(abci::l1::layout::inbox::GENESIS_COMMITTEE_HASH))
        .await?;
    let initial =
        devnet.cmt(0).committee(0).await?.expect("genesis committee retained across first switch");
    assert_eq!(
        B256::from(bootstrap),
        abci::committee::record_hash(devnet.params().l2_chain_id, &initial.record)
    );
    for epoch in [1, 2, 3] {
        let legacy_mapping_slot = alloy_primitives::keccak256(
            [abci::l1::layout::inbox::slot(epoch), abci::l1::layout::inbox::slot(278)].concat(),
        );
        assert!(
            devnet.planter().inbox_word(legacy_mapping_slot).await?.is_zero(),
            "no future committee mapping output for epoch {epoch}"
        );
    }
    assert_eq!(devnet.app_halt(0), None);

    // 2. Stop the app mid-chain and recover through the handshake.
    devnet.app_stop(0).await;
    assert!(!devnet.app_running(0));
    let l2 = devnet.l2_provider(0);
    let old_head = l2.get_block_number().await?;
    let old_hashes = devnet.l2_block_hashes(0, old_head).await?;
    eprintln!("app stopped at L2 head {old_head} after {:?}", started.elapsed());
    // The app is already gone. Reap Comet explicitly: its socket client may hang after EOF.
    devnet.node_stop(0).await?;
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

    // 3. Lose the app state; replay reconstructs it, committees included.
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
    eprintln!("state-loss replay done after {:?}", started.elapsed());

    devnet.stop().await?;
    Ok(())
}
