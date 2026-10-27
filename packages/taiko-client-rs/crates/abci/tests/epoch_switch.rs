//! Docker scenario for autonomous parent-anchor epoch activation with a joining validator. The
//! single-validator activation checks share the restart scenario's devnet (`restart.rs`).

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use abci::{RegistryEntry, key::ConsensusKey};
use alloy_provider::Provider;
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
async fn epoch_switch_adds_the_joining_validator() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec {
        validators: 4,
        initial_validators: 3,
        epoch_len: 20,
        unsettled_limit: 12,
        ..Default::default()
    };
    let devnet = Devnet::start(spec.clone()).await?;
    eprintln!("devnet {} up after {:?}", devnet.id(), started.elapsed());
    let schedule = devnet.schedule();
    let keys = devnet.keys();
    let stake = devnet.registry_entry(0).eff_stake;
    let power = u64::try_from(stake / devnet.params().vp_unit)?;
    devnet.wait_for_height(0, 1, Duration::from_secs(90)).await?;
    // Capture before retention can prune it; each height uses its own authenticated committee.
    let initial = devnet.cmt(0).committee(0).await?.expect("genesis committee");
    assert_eq!(keys.iter().map(|key| key.beneficiary()).collect::<BTreeSet<_>>().len(), 4);

    // Registry checkpoint 1: the genesis entries plus validator 4, active from the checkpoint's own
    // L1 block.
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
    let four: BTreeSet<(ConsensusKey, u64)> = keys.iter().map(|k| (k.pubkey(), power)).collect();
    let three: BTreeSet<(ConsensusKey, u64)> =
        keys[..3].iter().map(|k| (k.pubkey(), power)).collect();
    let members: BTreeSet<(ConsensusKey, u64)> =
        committee.members.iter().map(|m| (m.pubkey, m.power)).collect();
    assert_eq!(members, four, "/committee/{t} members");
    assert_eq!(committee.record.target_epoch, t);
    assert_eq!(committee.record.checkpoint_index, 1);
    assert!(committee.record.cutoff_l1_block >= joined, "record cutoff below the checkpoint");
    assert_eq!(committee.record.total_power, 4 * power);

    // Past the switch height and h_first(t), with canonical commits for a few heights of epoch t.
    let last = h_first + 10;
    assert!(last < schedule.h_first(t + 1), "scan stays within epoch 1");
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

    let mut proposers = Vec::new();
    let mut produced = Vec::new();
    for height in 1..last {
        let proposer = devnet.cmt(0).proposer_address(height).await?;
        let active = if height < h_first { &initial } else { &committee };
        let member = active
            .members
            .iter()
            .find(|member| abci::genesis::validator_address(member.pubkey) == proposer)
            .unwrap_or_else(|| {
                panic!("height {height}: proposer {proposer} absent from active committee")
            });
        let block = devnet
            .l2_provider(0)
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Number(height))
            .await?
            .expect("committed EL block");
        assert_eq!(
            block.header.beneficiary,
            member.pubkey.address(),
            "height {height}: native proposer {proposer} payout"
        );
        let envelope = devnet.cmt(0).envelope(height).await?;
        assert_eq!(
            envelope.block.header.hash_slow(),
            block.header.hash,
            "height {height}: certified envelope matches EL"
        );
        if height >= h_first {
            if proposer == joiner {
                produced.push(height);
            }
            proposers.push((height, proposer));
        }
    }
    assert!(!produced.is_empty(), "joiner produced no block; scanned proposers: {proposers:?}");
    eprintln!("validator 4 produced heights {produced:?}; scanned proposers: {proposers:?}");

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
