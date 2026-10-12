//! Docker scenarios for autonomous parent-anchor epoch activation.

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use abci::RegistryEntry;
use alloy_primitives::B256;
use alloy_provider::Provider;
use test_harness::{Devnet, DevnetSpec, wait_until};

/// CometBFT node 0's validator set at `height` as `(pubkey, power)` pairs.
async fn validator_set(devnet: &Devnet, height: u64) -> anyhow::Result<BTreeSet<(B256, u64)>> {
    let set = devnet.cmt(0).validators(Some(height)).await?;
    Ok(set.into_iter().map(|v| (v.pubkey, v.power)).collect())
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn epoch_switch_adds_the_joining_validator() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec {
        validators: 4,
        initial_validators: 3,
        epoch_len: 20,
        epoch_len_l1: 10,
        d_max: 12,
        margin_v: 2,
        ..Default::default()
    };
    let devnet = Devnet::start(spec.clone()).await?;
    eprintln!("devnet {} up after {:?}", devnet.id(), started.elapsed());
    let schedule = devnet.schedule();
    let keys = devnet.keys();
    let stake = devnet.registry_entry(0).eff_stake;
    let power = u64::try_from(stake / devnet.params().vp_unit)?;
    devnet.wait_for_height(0, 1, Duration::from_secs(90)).await?;

    // Registry checkpoint 1: the genesis entries plus validator 4, active from the checkpoint's own
    // L1 block and heartbeating there (window 0 under the devnet window: start 0, sequence 1, as
    // every planted entry).
    let mut next = devnet.planter().next_block().await?;
    let joined = next.number();
    let mut entries: Vec<RegistryEntry> = (0..3).map(|i| devnet.registry_entry(i)).collect();
    entries.push(RegistryEntry { active_from_l1: joined, ..devnet.registry_entry(3) });
    let index = next.write_registry_checkpoint(&entries).await?;
    assert_eq!(index, 1, "registry checkpoint index");
    assert_eq!(next.commit().await?, joined);
    let planted_at = devnet.cmt(0).latest_height().await?;
    eprintln!("validator 4 planted in L1 block {joined} at CometBFT height {planted_at}");

    // The joined entry is visible when the committed derivation parent covers its L1 block.
    let t = 1;
    devnet.wait_for_height(0, schedule.h_first(t) - 2, Duration::from_secs(180)).await?;
    let h_first = schedule.h_first(t);
    let switch = h_first - 2;
    eprintln!("target epoch {t}: switch height {switch}, h_first {h_first}");

    let devnet_ref = &devnet;
    let committee = wait_until(
        &format!("/committee/{t} with four members"),
        Duration::from_secs(30),
        Duration::from_millis(250),
        || async move {
            Ok(devnet_ref.cmt(0).committee(t).await?.filter(|c| c.members.len() == 4))
        },
    )
    .await?;
    let four: BTreeSet<(B256, u64)> = keys.iter().map(|k| (k.pubkey(), power)).collect();
    let three: BTreeSet<(B256, u64)> = keys[..3].iter().map(|k| (k.pubkey(), power)).collect();
    let members: BTreeSet<(B256, u64)> =
        committee.members.iter().map(|m| (m.pubkey, m.power)).collect();
    assert_eq!(members, four, "/committee/{t} members");
    assert_eq!(committee.record.target_epoch, t);
    assert_eq!(committee.record.checkpoint_index, 1);
    assert!(committee.record.cutoff_l1_block >= joined, "record cutoff below the checkpoint");
    assert_eq!(committee.record.total_power, 4 * power);

    // Past the switch height and h_first(t), with canonical commits for a few heights of epoch t.
    let last = h_first + 6;
    devnet.wait_for_height(0, last, Duration::from_secs(120)).await?;
    eprintln!("height {last} after {:?}", started.elapsed());

    for h in 1..h_first {
        assert_eq!(validator_set(&devnet, h).await?, three, "CometBFT validators at height {h}");
    }
    for h in h_first..last {
        assert_eq!(validator_set(&devnet, h).await?, four, "CometBFT validators at height {h}");
    }
    let joiner = keys[3].address();
    for h in switch..h_first {
        let signers = devnet.cmt(0).commit_signers(h).await?;
        assert!(!signers.contains(&joiner), "validator 4 signed height {h} before joining");
    }
    let mut signed = Vec::new();
    for h in h_first + 1..last {
        if devnet.cmt(0).commit_signers(h).await?.contains(&joiner) {
            signed.push(h);
        }
    }
    eprintln!("validator 4 signed the commits of heights {signed:?}");
    assert!(!signed.is_empty(), "validator 4 signed no commit in {}..{last}", h_first + 1);

    for i in 0..spec.validators {
        let status = devnet.abci_status(i).await?;
        assert!(status.head >= h_first, "app {i} head {}", status.head);
        assert_eq!(status.epoch, t, "app {i} epoch");
        assert_eq!(devnet.app_halt(i), None, "app {i} halted");
    }

    devnet.stop().await?;
    eprintln!("epoch-switch scenario done after {:?}", started.elapsed());
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn epoch_switch_activates_without_committee_publication() -> anyhow::Result<()> {
    let devnet = Devnet::start(DevnetSpec::default()).await?;
    let schedule = devnet.schedule();
    let h = schedule.h_first(1);
    devnet.wait_for_height(0, h + 2, Duration::from_secs(90)).await?;
    let committee = devnet.cmt(0).committee(1).await?.expect("switch derives committee 1");
    let parent = devnet
        .l2_provider(0)
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Number(
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
    devnet.stop().await?;
    Ok(())
}
