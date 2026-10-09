//! Docker scenario 2 (spec §9.2): the epoch switch.
//!
//! [`epoch_switch_adds_the_joining_validator`]: four nodes, the first three forming the genesis
//! committee. A registry checkpoint planted after start adds validator 4; the first epoch `e`
//! whose `H_e` cutoff (the parent's anchor, `G = 1`, `LAG = 0`) covers it derives a four-member
//! committee `t = e + 1`; once the fake lander lands it (`lastCheckpoint ≥ H_e`,
//! `committee[t]`), `FinalizeBlock(h_first(t) − 2)` emits the update (D19, D20), CometBFT's set
//! at `h_first(t)` has four members, and validator 4 signs commits of epoch `t`.
//!
//! [`epoch_switch_halts_without_landing`]: one validator, the lander moving `lastCheckpoint` but
//! not planting `committee[1]`; the switch height `h_first(1) − 2` is refused (D19), so the chain
//! stays one block below it until the record lands.

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use abci::{RegistryEntry, l1::layout::inbox};
use alloy_primitives::{B256, U256};
use anyhow::ensure;
use test_harness::{Devnet, DevnetSpec, anchor_of, wait_until};

/// The `/status` halt reason of a switch height whose anchored `committee[t]` has not landed
/// (D19, `Rejection::RecordNotLanded`).
const RECORD_NOT_LANDED: &str = "record_not_landed";

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
    let keys = devnet.keys().to_vec();
    let stake = devnet.registry_entry(0).eff_stake;
    let power = u64::try_from(stake / devnet.params().vp_unit)?;
    devnet.wait_for_height(0, 1, Duration::from_secs(90)).await?;

    // Registry checkpoint 1: the genesis entries plus validator 4, active (and heartbeating) from
    // the checkpoint's own L1 block.
    let mut next = devnet.planter().next_block().await?;
    let joined = next.number();
    let mut entries: Vec<RegistryEntry> = (0..3).map(|i| devnet.registry_entry(i)).collect();
    entries.push(RegistryEntry {
        pubkey: keys[3].pubkey(),
        eff_stake: U256::from(10_000_000_000_000_000_000u128),
        active_from_l1: joined,
        exit_effective_l1: u64::MAX,
        last_heartbeat_at: joined,
    });
    let index = next.write_registry_checkpoint(&entries).await?;
    assert_eq!(index, 1, "registry checkpoint index");
    assert_eq!(next.commit().await?, joined);
    let planted_at = devnet.cmt(0).latest_height().await?;
    eprintln!("validator 4 planted in L1 block {joined} at CometBFT height {planted_at}");

    // The first epoch e whose H_e cutoff (the parent's anchor) covers the checkpoint.
    let l2 = devnet.l2_provider(0);
    let mut e = 1;
    let t = loop {
        ensure!(e <= 3, "no H_e cutoff covered L1 block {joined} by epoch 3");
        let h_e = schedule.h_first(e);
        devnet.wait_for_height(0, h_e, Duration::from_secs(90)).await?;
        let cutoff = anchor_of(&l2, h_e - 1).await?;
        eprintln!("H_{e} = {h_e}: cutoff (parent anchor) {cutoff}");
        if cutoff >= joined {
            break e + 1;
        }
        e += 1;
    };
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
    eprintln!("scenario 2 done after {:?}", started.elapsed());
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn epoch_switch_halts_without_landing() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec { land_committees: false, ..Default::default() };
    let devnet = Devnet::start(spec.clone()).await?;
    let schedule = devnet.schedule();
    let t = 1;
    let switch = schedule.h_first(t) - 2;

    // The chain runs up to the switch height and stops below it.
    let reached = devnet.wait_for_height(0, switch - 1, Duration::from_secs(60)).await?;
    assert_eq!(reached, switch - 1, "the chain passed the switch height without the record");
    let hold = Duration::from_millis(3 * spec.timeout_commit_ms) + Duration::from_secs(2);
    let hold_end = Instant::now() + hold;
    let mut reasons = BTreeSet::new();
    let mut status = devnet.abci_status(0).await?;
    while Instant::now() < hold_end {
        let height = devnet.cmt(0).latest_height().await?;
        assert_eq!(height, switch - 1, "CometBFT reached the switch height without the record");
        status = devnet.abci_status(0).await?;
        reasons.extend(status.halt_reason.clone());
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
    eprintln!("halt reasons seen while stalled: {reasons:?}; status {status:?}");
    // The checkpoint covers h_first(t − 1), so D19 fails on the missing committee[t] alone.
    assert!(
        status.last_checkpoint_height >= schedule.h_first(t - 1),
        "lastCheckpoint {} stopped moving",
        status.last_checkpoint_height
    );
    let record = devnet.planter().inbox_word(inbox::committee_slot(t)).await?;
    assert!(record.is_zero(), "committee[{t}] landed while landing was off");
    assert_eq!(status.halt_reason.as_deref(), Some(RECORD_NOT_LANDED), "/status halt reason");
    assert_eq!(reasons, BTreeSet::from([RECORD_NOT_LANDED.to_string()]), "/status halt reasons");
    assert_eq!(devnet.app_halt(0), None);

    // Landing the record lets the switch through.
    devnet.lander_land_committees(true);
    let resumed = Instant::now();
    devnet.wait_for_height(0, schedule.h_first(t) + 1, Duration::from_secs(30)).await?;
    eprintln!("past h_first({t}) {:?} after re-enabling the landing", resumed.elapsed());
    let record = devnet.planter().inbox_word(inbox::committee_slot(t)).await?;
    assert!(!record.is_zero(), "committee[{t}] not landed");
    let status = devnet.abci_status(0).await?;
    assert_eq!(status.epoch, t);
    assert_eq!(devnet.app_halt(0), None);

    devnet.stop().await?;
    eprintln!("negative scenario 2 done after {:?}", started.elapsed());
    Ok(())
}
