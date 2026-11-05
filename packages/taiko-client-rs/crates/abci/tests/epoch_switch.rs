//! Docker scenario for autonomous parent-anchor epoch activation with joining and departing
//! validators. The single-validator activation checks share the restart scenario's devnet
//! (`restart.rs`).

use std::{
    collections::{BTreeMap, BTreeSet},
    time::{Duration, Instant},
};

use abci::{GRID_INTERVAL, RegistryEntry, key::ConsensusKey, valstate::ValState};
use alloy_provider::Provider;
use test_harness::{CmtClient, Devnet, DevnetSpec, wait_until};
use tokio::task::JoinHandle;

/// CometBFT node 0's validator set at `height` as `(pubkey, power)` pairs.
async fn validator_set(
    devnet: &Devnet,
    height: u64,
) -> anyhow::Result<BTreeSet<(ConsensusKey, u64)>> {
    let set = devnet.cmt(0).validators(Some(height)).await?;
    Ok(set.into_iter().map(|v| (v.pubkey, v.power)).collect())
}

/// How long the app may refuse `/val_state/<g>` while its `/status` reports `g` retained
/// (`floor <= g <= head`) before [`read_grid_val_states`] fails with the app's reason.
const REFUSAL_DEADLINE: Duration = Duration::from_secs(10);

/// How long [`read_grid_val_states`] may take to read every grid state: several times the
/// scenario's usual minute, and under the integration profile's ten-minute kill, so a stalled
/// read fails with its own reason.
const READ_DEADLINE: Duration = Duration::from_secs(300);

/// Reads the app's `/val_state/<g>` for every grid height `g` up to `through` while the app
/// still retains it. Each checkpoint the fake lander lands raises the retention floor and
/// prunes the states below it, so the task reads each grid state as soon as it is committed
/// and fails if the floor passes one first, if a retained one stays refused for
/// [`REFUSAL_DEADLINE`], or if the reads outlast [`READ_DEADLINE`].
fn read_grid_val_states(
    cmt: CmtClient,
    through: u64,
) -> JoinHandle<anyhow::Result<BTreeMap<u64, ValState>>> {
    tokio::spawn(async move {
        let started = Instant::now();
        let mut served = BTreeMap::new();
        let mut next = GRID_INTERVAL;
        // Since when the app has refused `next` while reporting it retained.
        let mut refused_since = None;
        while next <= through {
            anyhow::ensure!(
                started.elapsed() < READ_DEADLINE,
                "/val_state/{next} was not read within {READ_DEADLINE:?}"
            );
            match cmt.abci_status().await {
                Ok(status) if next > status.head => refused_since = None,
                Ok(status) => {
                    let floor = status.last_checkpoint_height;
                    anyhow::ensure!(
                        next >= floor,
                        "/val_state/{next} was not served before the floor rose to {floor}"
                    );
                    match cmt.abci_answer(&format!("/val_state/{next}")).await {
                        Ok(Ok(preimage)) => {
                            let state = ValState::decode(&preimage)?;
                            anyhow::ensure!(
                                state.height == next,
                                "/val_state/{next} holds another height"
                            );
                            served.insert(next, state);
                            next += GRID_INTERVAL;
                            refused_since = None;
                            continue;
                        }
                        // One refusal can mean the floor just passed `next`, which the next
                        // status read reports; a lasting one is the app's failure.
                        Ok(Err(log)) => {
                            let since = *refused_since.get_or_insert_with(Instant::now);
                            anyhow::ensure!(
                                since.elapsed() < REFUSAL_DEADLINE,
                                "/val_state/{next} refused for {REFUSAL_DEADLINE:?} while \
                                 retained ({floor}..={}): {log}",
                                status.head
                            );
                        }
                        Err(error) => eprintln!("reading /val_state/{next}: {error:#}"),
                    }
                }
                Err(error) => eprintln!("reading /val_state/{next}: {error:#}"),
            }
            tokio::time::sleep(Duration::from_millis(250)).await;
        }
        Ok(served)
    })
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
    // Literal canonical L=20 boundaries of target epoch 1; never derive expected activation
    // from the code under test. The scan covers the heights below `last`.
    let (derivation, switch, h_first) = (18, 19, 21);
    let last = h_first + 10;
    // The grid validator states of the scanned heights, read before pruning.
    let served = read_grid_val_states(devnet.cmt(0).clone(), last - 1);
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

    // The app's validator state against stock CometBFT. Replay CometBFT's arithmetic from the
    // genesis state with the updates CometBFT recorded; every grid state the app served must
    // equal it, and CometBFT must agree where it is exact.
    let served = served.await??;
    let grids: Vec<u64> = (GRID_INTERVAL..last).step_by(GRID_INTERVAL as usize).collect();
    assert_eq!(served.keys().copied().collect::<Vec<_>>(), grids, "grid states read");
    let genesis: Vec<(ConsensusKey, u64)> =
        initial.members.iter().map(|m| (m.pubkey, m.power)).collect();
    // `states[h]` is the state after height h: its `current` signs h + 1.
    let mut states = vec![ValState::genesis(0, &genesis)?];
    for h in 1..last {
        let updates = devnet.cmt(0).validator_updates(h).await?;
        assert_eq!(!updates.is_empty(), h == switch, "height {h}: validator updates {updates:?}");
        let state = states[usize::try_from(h - 1)?].advance(&updates)?;
        if let Some(app) = served.get(&h) {
            assert_eq!(app, &state, "height {h}: /val_state against the replay");
        }
        states.push(state);
    }
    // Only a block decided in round 0 is known to come from the set's stored proposer.
    let mut round_zero = Vec::new();
    for b in 1..last {
        if devnet.cmt(0).commit_round(b).await? != 0 {
            continue;
        }
        let set = &states[usize::try_from(b - 1)?].current;
        assert_eq!(
            devnet.cmt(0).proposer_address(b).await?,
            abci::genesis::validator_address(set.entries[set.proposer].key),
            "height {b}: header proposer against the stored proposer"
        );
        round_zero.push(b);
    }
    eprintln!("round-0 proposers checked at heights {round_zero:?}");
    assert!(round_zero.iter().any(|&b| b >= h_first), "no round-0 height from h_first {h_first}");
    // `/validators` is exact only where CometBFT stores the set in full: genesis height 1 and
    // h_first, where the switched set first signs.
    for h in [1, h_first] {
        assert_eq!(
            devnet.cmt(0).validator_entries(Some(h)).await?,
            states[usize::try_from(h - 1)?].current.entries,
            "/validators priorities at height {h}"
        );
    }

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
