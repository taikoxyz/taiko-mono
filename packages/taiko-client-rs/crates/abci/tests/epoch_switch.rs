//! Docker scenario for autonomous parent-anchor epoch activation with joining and departing
//! validators. The single-validator activation checks share the restart scenario's devnet
//! (`restart.rs`).

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

    // Registry checkpoint 1 replaces validator 3 with validator 4 at its own L1 block.
    // Three equal-power members require all three signatures, exposing exact ownership.
    let mut next = devnet.planter().next_block().await?;
    let joined = next.number();
    let mut entries: Vec<RegistryEntry> = (0..3).map(|i| devnet.registry_entry(i)).collect();
    entries[2].exit_effective_l1 = joined;
    entries.push(RegistryEntry { active_from_l1: joined, ..devnet.registry_entry(3) });
    let index = next.write_registry_checkpoint(&entries).await?;
    assert_eq!(index, 1, "registry checkpoint index");
    assert_eq!(next.commit().await?, joined);
    let planted_at = devnet.cmt(0).latest_height().await?;
    eprintln!("validator 4 planted in L1 block {joined} at CometBFT height {planted_at}");

    // The joined entry is visible when the committed derivation parent covers its L1 block.
    let t = 1;
    // Literal canonical L=20 boundaries; never derive expected activation from the code under test.
    let (derivation, switch, h_first) = (18, 19, 21);
    assert_eq!(schedule.h_first(t), h_first);
    assert_eq!(schedule.derivation_parent_height(t), Some(derivation));
    assert_eq!(schedule.switch_target(switch), Some(t));
    devnet.wait_for_height(0, switch, Duration::from_secs(180)).await?;
    eprintln!("target epoch {t}: switch height {switch}, h_first {h_first}");

    let devnet_ref = &devnet;
    let committee = wait_until(
        &format!("/committee/{t} with the replacement members"),
        Duration::from_secs(30),
        Duration::from_millis(250),
        || async move {
            Ok(devnet_ref.cmt(0).committee(t).await?.filter(|c| c.members.len() == 3))
        },
    )
    .await?;
    let replacement: BTreeSet<(ConsensusKey, u64)> =
        [0, 1, 3].into_iter().map(|i| (keys[i].pubkey(), power)).collect();
    let three: BTreeSet<(ConsensusKey, u64)> =
        keys[..3].iter().map(|k| (k.pubkey(), power)).collect();
    let members: BTreeSet<(ConsensusKey, u64)> =
        committee.members.iter().map(|m| (m.pubkey, m.power)).collect();
    assert_eq!(members, replacement, "/committee/{t} members");
    assert_eq!(committee.record.target_epoch, t);
    assert_eq!(committee.record.checkpoint_index, 1);
    assert!(committee.record.cutoff_l1_block >= joined, "record cutoff below the checkpoint");
    assert_eq!(committee.record.total_power, 3 * power);

    // Past the switch height and h_first(t), with canonical commits for a few heights of epoch t.
    let last = h_first + 10;
    assert!(last < schedule.h_first(t + 1), "scan stays within epoch 1");
    devnet.wait_for_height(0, last, Duration::from_secs(120)).await?;
    eprintln!("height {last} after {:?}", started.elapsed());

    for h in 1..h_first {
        assert_eq!(validator_set(&devnet, h).await?, three, "CometBFT validators at height {h}");
    }
    for h in h_first..last {
        assert_eq!(
            validator_set(&devnet, h).await?,
            replacement,
            "CometBFT validators at height {h}"
        );
    }
    let joiner = keys[3].address();
    let departed = keys[2].address();
    for h in [19, 20] {
        let signers = devnet.cmt(0).commit_signers(h).await?;
        assert!(signers.contains(&departed), "outgoing validator must sign height {h}");
        assert!(!signers.contains(&joiner), "incoming validator signed height {h} early");
    }
    for h in [21, 22] {
        let signers = devnet.cmt(0).commit_signers(h).await?;
        assert!(signers.contains(&joiner), "incoming validator must sign height {h}");
        assert!(!signers.contains(&departed), "departed validator signed height {h}");
    }
    let parent = devnet
        .l2_provider(0)
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Number(18))
        .await?
        .unwrap();
    let (_, _, cutoff) = abci::rules::decode_extra_data(&parent.header.extra_data)?;
    assert_eq!(committee.record.cutoff_l1_block, cutoff, "D=18 commits the snapshot cutoff");
    eprintln!(
        "CANONICAL_H_PLUS_TWO D=18 S=19 outgoing=[19,20] H=21 incoming=[21,22] cutoff={cutoff}"
    );
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
