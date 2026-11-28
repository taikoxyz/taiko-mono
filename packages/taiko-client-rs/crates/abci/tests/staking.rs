//! Docker scenarios of the per-block signing sets on a six-validator devnet, one validator
//! instance per key. Keys 0 to 3 form the Inbox's fallback key list; keys 2 to 5 register bonds
//! of two minStakes each on the L2 `EtnaStaking` predeploy, owned by the four harness stakers, and
//! the DAO's `minTotalStake` is planted at seven minStakes, which the four bonds reach and any
//! three do not:
//!
//! - the fallback keys sign from the first block, each at power 1, until the snapshot of X + 1
//!   holds the four bonds, X being the block of the last registration; the candidate, each member
//!   at its stake's power, signs X + 3;
//! - a candidate member offline for a multiple of `missLimit` consecutive blocks loses
//!   `missSlashBps` of its stake in the block-start call that counts its last miss, keeps its seat
//!   and its count and is in the set of two blocks later at its lower power; at `missReleaseLimit`
//!   consecutive misses that call also releases its seat, with no exit set, so the snapshot of that
//!   block R falls below the minimum and the fallback keys sign R + 2, until the owner's top-up of
//!   one base unit in block T takes the seat again and the candidate signs T + 3;
//! - an exit in block E drops the snapshot of E + 1 below the minimum, so the fallback keys sign E
//!   + 3, and every fallback key's instance precommits again;
//! - a `minTotalStake` of 2^256 − 1 hands H + 2 to the fallback keys, H being the first block whose
//!   anchor proves it.
//!
//! Keys 2 and 3 are both fallback keys and candidate members: every switch re-weights them in the
//! one update list that removes the other source's other keys and adds its own. The expected
//! update lists are written out, not computed by the client's own rule.

use std::{
    collections::BTreeSet,
    ops::Range,
    time::{Duration, Instant},
};

use abci::{FallbackReason, key::ConsensusKey, rules::ExtraData};
use alloy_eips::BlockId;
use alloy_primitives::U256;
use anyhow::{Context, Result, ensure};
use test_harness::{
    Bond, Devnet, DevnetSpec, InboxValues, Registration, Staking, StakingParams, extra_data_of,
    first_anchored_at, staker, wait_until,
};

/// Validators started, each with its own instance.
const VALIDATORS: usize = 6;
/// The keys of the Inbox's fallback key list.
const FALLBACK_KEYS: Range<usize> = 0..4;
/// The keys that register bonds; key `CANDIDATE_KEYS.start + i` is owned by staker `i`.
const CANDIDATE_KEYS: Range<usize> = 2..6;
/// The planted `minTotalStake`, in minStakes: the four bonds of two minStakes reach it, three do
/// not, and the three missed-signature penalties of 10 % that one bond takes before its release
/// leave the four above it.
const MIN_TOTAL_STAKE_IN_MIN_STAKES: u64 = 7;
/// Bound on any one wait for heights, receipts or anchors.
const WAIT: Duration = Duration::from_secs(120);
/// Poll interval of the waits.
const POLL: Duration = Duration::from_millis(250);
/// Bound on an offline member's run of `missReleaseLimit` misses, from its stop to its release.
const RUN_WAIT: Duration = Duration::from_secs(240);

/// A devnet on which the candidate took over from the fallback keys.
struct Takeover {
    devnet: Devnet,
    staking: Staking,
    params: StakingParams,
    /// Each candidate key's bond, in [`CANDIDATE_KEYS`] order.
    bonds: Vec<Bond>,
    /// Each bond's stake: two minStakes.
    stake: U256,
    /// The planted `minTotalStake`.
    minimum: U256,
    /// The fallback key set, each key at power 1, sorted.
    fallback: Vec<(ConsensusKey, u64)>,
    /// The candidate, each member at its stake's power, sorted.
    candidate: Vec<(ConsensusKey, u64)>,
    /// X: the block of the registration that brought the bonds' total stake to the minimum.
    x: u64,
}

/// The fallback keys sign the first blocks at power 1; once all four bonds are in the snapshot
/// of X + 1, the candidate signs X + 3, through one update list returned at X + 1.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn fallback_keys_sign_from_genesis_then_candidate_takes_over_at_h_plus_2() -> Result<()> {
    let started = Instant::now();
    let t = take_over().await?;
    // The candidate keeps signing: X + 2 decided it again from the same four bonds.
    t.devnet.wait_for_height(0, t.x + 5, WAIT).await?;
    assert_eq!(
        t.devnet.cmt(0).signing_set(t.x + 4).await?,
        t.candidate,
        "the set that signs X + 4"
    );
    let signers = t.devnet.cmt(0).abci_signers().await?;
    assert_eq!(signers.after.source, abci::committee::SignerSource::Candidate, "{signers:?}");
    assert_eq!(signers.after.total_stake, Some(t.stake * U256::from(4)), "{signers:?}");
    assert_eq!(signers.after.min_total_stake, Some(t.minimum), "{signers:?}");
    t.devnet.stop().await?;
    eprintln!("candidate takeover scenario done after {:?}", started.elapsed());
    Ok(())
}

/// A candidate member that stops signing is missing from every LastCommit. Each block-start call
/// that raises its seat's count to a multiple of `missLimit` deducts `missSlashBps` of its stake,
/// rounded up, and keeps the count; with two minStakes the bond keeps its seat, and the set that
/// block decides holds it at its lower power, although it signs nothing. The call that raises the
/// count to `missReleaseLimit`, R, releases the seat after its own penalty, with no exit set and
/// nothing more deducted: R's post-state maps the key to no seat and discards the count, and R's
/// snapshot holds the three other bonds, below the minimum, so the fallback keys sign R + 2. A
/// top-up of one base unit by the owner in block T takes the released seat again with count 0;
/// the snapshot of T + 1 holds the four bonds, and the candidate signs T + 3 with the member at its
/// lower power.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn misses_penalize_at_every_miss_limit_then_release_the_seat_until_a_top_up() -> Result<()> {
    let started = Instant::now();
    let mut t = take_over().await?;
    let offline = CANDIDATE_KEYS.end - 1;
    let owner = staker(offline - CANDIDATE_KEYS.start);
    let bond = t.bonds[offline - CANDIDATE_KEYS.start];
    let key = t.devnet.keys()[offline].pubkey();
    let release = t.params.miss_release_limit;
    let before = t.staking.bond(bond.id, BlockId::latest()).await?.effStake;
    assert_eq!(before, t.stake, "the offline member's stake before it stops");

    t.devnet.node_stop(offline).await?;
    let stopped = t.devnet.cmt(0).latest_height().await?;
    eprintln!("validator {offline} (seat {}) stopped at height {stopped}", bond.seat);
    let staking = &t.staking;
    wait_until(
        &format!("the release of the seat of validator {offline}"),
        RUN_WAIT,
        POLL,
        || async move {
            let seat = staking.seat_of_bond(bond.id, BlockId::latest()).await?;
            Ok(seat.is_none().then_some(()))
        },
    )
    .await?;

    // R: the first block whose post-state holds the release. Its call carries the run's
    // `missReleaseLimit`-th miss: the seat's bit is set in the `missBitmap` of the
    // `missReleaseLimit` blocks ending at R and clear in the one before them.
    let mut r = stopped;
    while t.staking.seat_of_bond(bond.id, BlockId::number(r)).await?.is_some() {
        r += 1;
    }
    ensure!(r > release, "the release at {r} came before {release} blocks were possible");
    let first = r - release;
    for h in first + 1..=r {
        assert!(
            seat_missed(&t.devnet, h, bond.seat).await?,
            "seat {} not missed at {h}",
            bond.seat
        );
    }
    assert!(
        !seat_missed(&t.devnet, first, bond.seat).await?,
        "seat {} missed at {first}",
        bond.seat
    );

    // Each call of the run raises the count by one and never resets it: every multiple of
    // `missLimit` deducts a penalty from the stake the previous one left, and the bond keeps its
    // seat, above minStake, until R.
    let mut stake = before;
    let mut penalties = Vec::new();
    for h in first + 1..=r {
        let count = h - first;
        let now = t.staking.bond(bond.id, BlockId::number(h)).await?.effStake;
        if t.params.penalizes(count) {
            assert_eq!(
                now,
                stake - t.params.miss_penalty(stake),
                "the penalty at {h}, miss {count}"
            );
            penalties.push((h, stake, now));
        } else {
            assert_eq!(now, stake, "no penalty at {h}, miss {count}");
        }
        stake = now;
        if h < r {
            assert!(!t.params.releases(count), "a release due at {h}, miss {count}");
            let at = BlockId::number(h);
            assert_eq!(t.staking.seat_of_bond(bond.id, at).await?, Some(bond.seat), "seat at {h}");
            let kept = u64::from(t.staking.miss_count(bond.seat, at).await?);
            assert_eq!(kept, count, "the count at {h}, a penalty's included");
        }
    }
    assert!(penalties.len() >= 2, "the run is penalized more than once: {penalties:?}");
    assert!(stake >= t.params.min_stake, "the release at {r} is the count's, not the stake's");
    eprintln!("penalties {penalties:?}; seat released in block {r} at stake {stake}");

    // A penalty before R re-weights the member in the set that its block decides.
    for &(p, prior, lowered) in penalties.iter().filter(|&&(p, ..)| p < r) {
        t.devnet.wait_for_height(0, p + 3, WAIT).await?;
        let (prior, lower) = (t.params.power(prior)?, t.params.power(lowered)?);
        let set = |power| reweighted(&t.candidate, key, power);
        assert_eq!(
            t.devnet.cmt(0).signing_set(p + 1).await?,
            set(prior),
            "the set that signs {p} + 1"
        );
        assert_eq!(
            t.devnet.cmt(0).signing_set(p + 2).await?,
            set(lower),
            "the set that signs {p} + 2"
        );
        assert_eq!(updates_at(&t.devnet, p).await?, vec![(key, lower)], "the updates of {p}");
    }

    // At R the bond holds no seat and no exit, its stake is what the last penalty left, its key's
    // key-to-seat word is zero and the seat's count is discarded.
    let at_r = BlockId::number(r);
    let released = t.staking.bond(bond.id, at_r).await?;
    assert!(!released.holdsSeat, "the bond holds a seat at {r}");
    assert!(!released.withdrawn, "the bond is withdrawn at {r}");
    assert_eq!(released.exitHeight.to::<u64>(), abci::UINT48_MAX, "an exit set at {r}");
    assert_eq!(released.effStake, stake, "the stake at {r}");
    let seat_word = |at| staking.key_seat_word(key.address(), at);
    assert_eq!(
        abci::staking::decode_seat(seat_word(BlockId::number(r - 1)).await?),
        Some(bond.seat)
    );
    assert_eq!(seat_word(at_r).await?, U256::ZERO, "the key's key-to-seat word at {r}");
    assert_eq!(t.staking.miss_count(bond.seat, at_r).await?, 0, "the released seat's count");

    // R's snapshot holds the three other bonds, below the minimum: R decides the fallback keys for
    // R + 2, while R + 1, decided at R − 1, is still the candidate's.
    let (height, total, members) = t.staking.snapshot(at_r).await?;
    assert_eq!(height, U256::from(r), "the snapshot of R");
    assert_eq!((total, members.len()), (t.stake * U256::from(3), 3), "the snapshot of R");
    assert!(members.iter().all(|m| member_key(m).is_ok_and(|member| member != key)));
    assert!(total < t.minimum);
    t.devnet.wait_for_height(0, r + 3, WAIT).await?;
    let prior = t.params.power(t.staking.bond(bond.id, BlockId::number(r - 1)).await?.effStake)?;
    let at_prior = reweighted(&t.candidate, key, prior);
    assert_eq!(t.devnet.cmt(0).signing_set(r + 1).await?, at_prior, "the set that signs R + 1");
    assert_eq!(t.devnet.cmt(0).signing_set(r + 2).await?, t.fallback, "the set that signs R + 2");
    assert_eq!(
        updates_at(&t.devnet, r).await?,
        switch_updates(&t.devnet, None),
        "the mode switch's one update list at R"
    );
    // R's post-state maps the key to no seat, so the next block counts nothing for the seat,
    // although the member is still missing from its LastCommit.
    assert!(!seat_missed(&t.devnet, r + 1, bond.seat).await?, "seat {} missed at R + 1", bond.seat);
    let signers = t.devnet.cmt(0).abci_signers().await?;
    assert_eq!(signers.after.fallback_reason, Some(FallbackReason::BelowMinTotalStake));
    every_fallback_key_precommits(&t, r + 2).await?;

    // The owner's top-up of one base unit in block T takes the lowest empty seat, the released
    // one, with count 0. T's snapshot was stored before it; the snapshot of T + 1 holds the four
    // bonds again.
    let top_up = t.staking.top_up(&owner, bond.id, U256::from(1)).await?;
    let at_t = BlockId::number(top_up);
    let topped = stake + U256::from(1);
    eprintln!("bond {} topped up by one base unit in block {top_up}", bond.id);
    assert_eq!(t.staking.bond(bond.id, at_t).await?.effStake, topped, "the stake at T");
    assert_eq!(t.staking.seat_of_bond(bond.id, at_t).await?, Some(bond.seat), "the seat at T");
    assert_eq!(abci::staking::decode_seat(seat_word(at_t).await?), Some(bond.seat));
    assert_eq!(t.staking.miss_count(bond.seat, at_t).await?, 0, "the count at T");
    let (_, total, members) = t.staking.snapshot(at_t).await?;
    assert_eq!((total, members.len()), (t.stake * U256::from(3), 3), "the snapshot of T");
    t.devnet.wait_for_height(0, top_up + 5, WAIT).await?;
    let (height, total, members) = t.staking.snapshot(BlockId::number(top_up + 1)).await?;
    assert_eq!(height, U256::from(top_up + 1), "the snapshot of T + 1");
    assert_eq!(
        (total, members.len()),
        (t.stake * U256::from(3) + topped, 4),
        "the snapshot of T + 1"
    );
    assert!(total >= t.minimum);

    // T + 1 decides the candidate for T + 3, the member at the topped-up stake's power. The
    // fallback keys' commits give it no miss; the candidate's first commit without it does.
    let lower = t.params.power(topped)?;
    assert_eq!(
        t.devnet.cmt(0).signing_set(top_up + 2).await?,
        t.fallback,
        "the set that signs T + 2"
    );
    let back = reweighted(&t.candidate, key, lower);
    assert_eq!(t.devnet.cmt(0).signing_set(top_up + 3).await?, back, "the set that signs T + 3");
    let switch_back =
        reweighted(&switch_updates(&t.devnet, Some(t.params.power(t.stake)?)), key, lower);
    assert_eq!(updates_at(&t.devnet, top_up + 1).await?, switch_back, "the update list at T + 1");
    let addresses = addresses(&t.devnet, CANDIDATE_KEYS.start..offline);
    let signed = t.devnet.cmt(0).commit_signers(top_up + 3).await?;
    ensure!(
        !signed.is_empty() && signed.iter().all(|a| addresses.contains(a)),
        "T + 3 committed by {signed:?}, not the online candidate members {addresses:?}"
    );
    for (h, count) in [(top_up + 3, 0), (top_up + 4, 1)] {
        let counted = t.staking.miss_count(bond.seat, BlockId::number(h)).await?;
        assert_eq!(counted, count, "the count at {h}");
    }

    t.devnet.stop().await?;
    eprintln!("miss penalty and release scenario done after {:?}", started.elapsed());
    Ok(())
}

/// An exit in block E releases the bond's seat in that call, so the snapshot of E + 1 holds three
/// bonds, below the minimum: the fallback keys sign E + 3, and every fallback key's instance, the
/// two whose keys signed nothing while the candidate did included, precommits again.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn exit_below_min_total_stake_returns_to_fallback() -> Result<()> {
    let started = Instant::now();
    let t = take_over().await?;
    let leaving = 2;
    let bond = t.bonds[leaving];
    let e = t.staking.request_exit(&staker(leaving), bond.id).await?;
    eprintln!("bond {} exited in block {e}", bond.id);
    t.devnet.wait_for_height(0, e + 4, WAIT).await?;

    assert_eq!(t.staking.seat_of_bond(bond.id, BlockId::number(e)).await?, None, "seat at E");
    let (height, total, members) = t.staking.snapshot(BlockId::number(e + 1)).await?;
    assert_eq!(height, U256::from(e + 1), "the snapshot of E + 1");
    assert_eq!(total, t.stake * U256::from(3), "the total stake in the snapshot of E + 1");
    assert_eq!(members.len(), 3, "the members in the snapshot of E + 1");
    assert!(total < t.minimum);

    assert_eq!(t.devnet.cmt(0).signing_set(e + 2).await?, t.candidate, "the set that signs E + 2");
    assert_eq!(t.devnet.cmt(0).signing_set(e + 3).await?, t.fallback, "the set that signs E + 3");
    assert_eq!(
        updates_at(&t.devnet, e + 1).await?,
        switch_updates(&t.devnet, None),
        "the mode switch's one update list at E + 1"
    );
    let signers = t.devnet.cmt(0).abci_signers().await?;
    assert_eq!(signers.after.fallback_reason, Some(FallbackReason::BelowMinTotalStake));

    every_fallback_key_precommits(&t, e + 3).await?;
    t.devnet.stop().await?;
    eprintln!("exit scenario done after {:?}", started.elapsed());
    Ok(())
}

/// A `minTotalStake` of 2^256 − 1 makes no candidate usable: H, the first block whose anchor
/// proves it, decides the fallback keys for H + 2, while H + 1, decided under the older anchor,
/// is still the candidate's.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn max_min_total_stake_forces_fallback() -> Result<()> {
    let started = Instant::now();
    let t = take_over().await?;
    let from = t.devnet.cmt(0).latest_height().await?;
    let l1 = plant_min_total_stake(&t.devnet, U256::MAX).await?;
    let h = first_anchored_at(t.devnet.cmt(0), &t.devnet.l2_provider(0), from, l1, WAIT, || {
        t.devnet.check_apps()
    })
    .await?;
    eprintln!("minTotalStake 2^256 - 1 in L1 block {l1}, first anchored at L2 {h}");
    t.devnet.wait_for_height(0, h + 3, WAIT).await?;

    assert_eq!(t.devnet.cmt(0).signing_set(h + 1).await?, t.candidate, "the set that signs H + 1");
    assert_eq!(t.devnet.cmt(0).signing_set(h + 2).await?, t.fallback, "the set that signs H + 2");
    assert_eq!(
        updates_at(&t.devnet, h).await?,
        switch_updates(&t.devnet, None),
        "the mode switch's one update list at H"
    );
    // The bonds are untouched: only the DAO's threshold moved.
    let (_, total, members) = t.staking.snapshot(BlockId::number(h)).await?;
    assert_eq!((total, members.len()), (t.stake * U256::from(4), 4), "the snapshot of H");
    let signers = t.devnet.cmt(0).abci_signers().await?;
    assert_eq!(signers.after.fallback_reason, Some(FallbackReason::MinTotalStakeMax));
    assert_eq!(signers.after.min_total_stake, Some(U256::MAX));

    every_fallback_key_precommits(&t, h + 2).await?;
    t.devnet.stop().await?;
    eprintln!("maximum minTotalStake scenario done after {:?}", started.elapsed());
    Ok(())
}

/// Boots the devnet and lets the candidate take over, checking each step: the fallback keys
/// sign 1 and 2 and every block up to X + 2 with no update returned; the DAO's minimum is planted
/// and proved by an anchor before the registrations, so the snapshot of X + 1 is the first to
/// reach it; the update list of X + 1 switches the set; the candidate signs X + 3.
async fn take_over() -> Result<Takeover> {
    let devnet = Devnet::start(DevnetSpec {
        validators: VALIDATORS,
        fallback_keys: FALLBACK_KEYS.len(),
        ..Default::default()
    })
    .await?;
    let mut fallback: Vec<_> =
        devnet.keys()[FALLBACK_KEYS].iter().map(|key| (key.pubkey(), 1)).collect();
    fallback.sort();
    devnet.wait_for_height(0, 3, WAIT).await?;
    for h in [1, 2] {
        assert_eq!(
            devnet.cmt(0).signing_set(h).await?,
            fallback,
            "the origin fallback keys sign {h}"
        );
        let addresses = addresses(&devnet, FALLBACK_KEYS);
        let signed = devnet.cmt(0).commit_signers(h).await?;
        ensure!(
            !signed.is_empty() && signed.iter().all(|a| addresses.contains(a)),
            "height {h} committed by {signed:?}, not the fallback keys {addresses:?}"
        );
    }

    let staking = devnet.staking().await?;
    let params = staking.params().await?;
    let stake = params.min_stake * U256::from(2);
    let minimum = params.min_stake * U256::from(MIN_TOTAL_STAKE_IN_MIN_STAKES);
    for i in 0..CANDIDATE_KEYS.len() {
        let balance = staking.balance(staker(i).address()).await?;
        ensure!(balance >= stake, "staker {i} holds {balance} bridged TAIKO, below {stake}");
    }
    let from = devnet.cmt(0).latest_height().await?;
    let l1 = plant_min_total_stake(&devnet, minimum).await?;
    let proved = first_anchored_at(devnet.cmt(0), &devnet.l2_provider(0), from, l1, WAIT, || {
        devnet.check_apps()
    })
    .await?;
    eprintln!("minTotalStake {minimum} in L1 block {l1}, first anchored at L2 {proved}");

    let registrations: Vec<_> = CANDIDATE_KEYS
        .enumerate()
        .map(|(i, k)| Registration { owner: staker(i), key: &devnet.keys()[k], amount: stake })
        .collect();
    let bonds = staking.register_all(&registrations).await?;
    let x = bonds.iter().map(|bond| bond.block).max().context("no bond")?;
    ensure!(x > proved, "registered at {x}, not after the minimum's anchor at {proved}");
    eprintln!("bonds {bonds:?} registered; X = {x}");
    let power = params.power(stake)?;
    let mut candidate: Vec<_> =
        devnet.keys()[CANDIDATE_KEYS].iter().map(|key| (key.pubkey(), power)).collect();
    candidate.sort();

    devnet.wait_for_height(0, x + 4, WAIT).await?;
    let (_, total, _) = staking.snapshot(BlockId::number(x)).await?;
    assert!(total < minimum, "the snapshot of X already reaches the minimum: {total}");
    let (height, total, members) = staking.snapshot(BlockId::number(x + 1)).await?;
    assert_eq!(height, U256::from(x + 1), "the snapshot of X + 1 is its own");
    assert_eq!(total, stake * U256::from(4), "the total stake in the snapshot of X + 1");
    let mut snapshot: Vec<_> =
        members.iter().map(|m| Ok((member_key(m)?, m.power))).collect::<Result<_>>()?;
    snapshot.sort();
    assert_eq!(snapshot, candidate, "the members of the snapshot of X + 1");

    for h in 1..=x + 2 {
        assert_eq!(devnet.cmt(0).signing_set(h).await?, fallback, "the fallback keys sign {h}");
    }
    for h in 1..=x {
        assert_eq!(updates_at(&devnet, h).await?, vec![], "no update at {h}");
    }
    assert_eq!(
        updates_at(&devnet, x + 1).await?,
        switch_updates(&devnet, Some(power)),
        "the mode switch's one update list at X + 1"
    );
    assert_eq!(devnet.cmt(0).signing_set(x + 3).await?, candidate, "the candidate signs X + 3");
    let addresses = addresses(&devnet, CANDIDATE_KEYS);
    let signed = devnet.cmt(0).commit_signers(x + 3).await?;
    ensure!(
        !signed.is_empty() && signed.iter().all(|a| addresses.contains(a)),
        "X + 3 committed by {signed:?}, not the candidate {addresses:?}"
    );
    Ok(Takeover { devnet, staking, params, bonds, stake, minimum, fallback, candidate, x })
}

/// Waits until every fallback key's address precommitted a block from `from` on: the union of
/// the commits of `from`, `from + 1`, … covers them all, and no other key signs any of them.
async fn every_fallback_key_precommits(t: &Takeover, from: u64) -> Result<()> {
    let expected = addresses(&t.devnet, FALLBACK_KEYS);
    let deadline = Instant::now() + WAIT;
    let mut seen = BTreeSet::new();
    let mut h = from;
    while seen != expected {
        ensure!(
            Instant::now() < deadline,
            "fallback keys {:?} did not precommit from {from} to {h}",
            expected.difference(&seen).collect::<Vec<_>>()
        );
        // The commit of h is canonical once h + 1 is committed.
        t.devnet
            .wait_for_height(0, h + 1, deadline.saturating_duration_since(Instant::now()))
            .await?;
        let signed = t.devnet.cmt(0).commit_signers(h).await?;
        ensure!(
            signed.iter().all(|a| expected.contains(a)),
            "{h} committed by {signed:?}, not only the fallback keys"
        );
        seen.extend(signed);
        h += 1;
    }
    eprintln!("every fallback key precommitted between {from} and {}", h - 1);
    Ok(())
}

/// Plants `minTotalStake` (slot 279) into the Inbox; returns its L1 block.
async fn plant_min_total_stake(devnet: &Devnet, value: U256) -> Result<u64> {
    devnet
        .planter()
        .plant_inbox(&InboxValues { min_total_stake: Some(value), ..Default::default() })
        .await?
        .context("the minTotalStake write was a no-op")
}

/// The `extraData` of L2 block `h` on EL 0, once it serves the block.
async fn extra_at(devnet: &Devnet, h: u64) -> Result<ExtraData> {
    let l2 = devnet.l2_provider(0);
    let l2 = &l2;
    wait_until(&format!("L2 block {h} on EL 0"), WAIT, POLL, || async move {
        Ok(Some(extra_data_of(l2, h).await?))
    })
    .await
}

/// Whether block `h`'s `missBitmap` has the bit of seat `seat`.
async fn seat_missed(devnet: &Devnet, h: u64, seat: u8) -> Result<bool> {
    Ok((extra_at(devnet, h).await?.miss_bitmap >> seat) & 1 == 1)
}

/// The one update list of a mode switch, written out: to the candidate at `power`, the fallback
/// keys outside it leave at power 0 and every candidate key comes in at `power`, the two shared
/// keys re-weighted; back to the fallback keys (`None`), the candidate keys outside the list leave
/// and every fallback key comes in at power 1, the shared ones re-weighted. Sorted by key.
fn switch_updates(devnet: &Devnet, to_candidate: Option<u64>) -> Vec<(ConsensusKey, u64)> {
    let mut updates: Vec<_> = devnet
        .keys()
        .iter()
        .enumerate()
        .map(|(k, key)| {
            let power = match to_candidate {
                Some(power) if CANDIDATE_KEYS.contains(&k) => power,
                None if FALLBACK_KEYS.contains(&k) => 1,
                _ => 0,
            };
            (key.pubkey(), power)
        })
        .collect();
    updates.sort();
    updates
}

/// `set` with `key` at `power`.
fn reweighted(
    set: &[(ConsensusKey, u64)],
    key: ConsensusKey,
    power: u64,
) -> Vec<(ConsensusKey, u64)> {
    set.iter().map(|&(member, p)| (member, if member == key { power } else { p })).collect()
}

/// The validator updates `FinalizeBlock(h)` returned, sorted.
async fn updates_at(devnet: &Devnet, h: u64) -> Result<Vec<(ConsensusKey, u64)>> {
    let mut updates = devnet.cmt(0).validator_updates(h).await?;
    updates.sort();
    Ok(updates)
}

/// The CometBFT validator addresses of `keys`.
fn addresses(devnet: &Devnet, keys: Range<usize>) -> BTreeSet<String> {
    devnet.keys()[keys].iter().map(|key| key.address()).collect()
}

/// The consensus key of a snapshot seat record.
fn member_key(member: &test_harness::IEtnaStaking::SeatMember) -> Result<ConsensusKey> {
    let bytes = [&[member.ckPrefix][..], member.ckX.as_slice()].concat();
    Ok(ConsensusKey::from_slice(&bytes)?)
}
