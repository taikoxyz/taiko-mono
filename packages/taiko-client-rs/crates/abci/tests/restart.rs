//! Docker scenario on one single-validator devnet, whose one key is the Inbox's fallback key list
//! and whose `minTotalStake` of 2^256 − 1 makes no candidate usable:
//!
//! 1. the fallback key signs every block alone at power 1, each set decided per block from the
//!    planted L1 state with no publication;
//! 2. stopping the `abci` app mid-chain and starting it again over the same store recovers through
//!    the CometBFT handshake, leaving the L2 chain below the old head unchanged;
//! 3. missing app state is reconstructed from the intact CometBFT history, its signing set
//!    included.
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
async fn fallback_signer_restart_and_state_loss_recover_on_one_devnet() -> anyhow::Result<()> {
    let started = Instant::now();
    let mut devnet = Devnet::start(DevnetSpec::default()).await?;
    // A height well past the generation's first two blocks, which the origin record's list signs.
    let h = 21;
    devnet.wait_for_height(0, (h + 5).max(26), Duration::from_secs(90)).await?;

    // 1. Every block decides the fallback key alone at power 1, for the reason that the minimum
    //    total stake is 2^256 − 1.
    let key = devnet.keys()[0].pubkey();
    for height in 1..=h {
        assert_eq!(
            validator_set(&devnet, height).await?,
            BTreeSet::from([(key, 1)]),
            "the set that signs {height}"
        );
    }
    let signers = devnet.cmt(0).abci_signers().await?;
    assert_eq!(signers.after.fallback_reason, Some(abci::FallbackReason::MinTotalStakeMax));
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
    // Header h + 1 commits the app hash of h's EL block and validator state. Every block decides
    // the same fallback key set, so no FinalizeBlock returns an update and the validator state
    // after h is the genesis one advanced h times.
    let genesis_set: Vec<_> = validator_set(&devnet, 1).await?.into_iter().collect();
    assert_eq!(genesis_set.len(), 1);
    let mut val_state = abci::valstate::ValState::genesis(0, &genesis_set)?;
    for h in 1..=old_head {
        val_state = val_state.advance(&[])?;
        let app_hash = devnet.cmt(0).header_app_hash(h + 1).await?;
        let expected = abci::valstate::app_hash(old_hashes[h as usize - 1], val_state.hash());
        assert_eq!(app_hash, expected, "CometBFT header {} app_hash", h + 1);
    }

    let status = devnet.abci_status(0).await?;
    assert!(status.head > old_head, "app head {} not past {old_head}", status.head);
    assert_eq!(devnet.app_halt(0), None);
    eprintln!("CometBFT height {height}, app head {} after {:?}", status.head, started.elapsed());

    // 3. Lose the app state; replay reconstructs it, its signing set included.
    let finalized = devnet
        .l2_provider(0)
        .get_block_by_number(BlockNumberOrTag::Finalized)
        .await?
        .context("missing EL finalized block")?;
    assert!(finalized.header.number > 0, "the EL checkpoint must have advanced");

    let (before, restored) = devnet.replay_after_state_loss(0).await?;
    assert!(restored.last_height >= before.last_height);
    assert_eq!(restored.genesis, before.genesis);
    assert_eq!(restored.val_state.current.members(), before.val_state.current.members());
    assert_eq!(restored.generation, before.generation);
    assert_eq!(devnet.app_halt(0), None);
    eprintln!("state-loss replay done after {:?}", started.elapsed());

    devnet.stop().await?;
    Ok(())
}
