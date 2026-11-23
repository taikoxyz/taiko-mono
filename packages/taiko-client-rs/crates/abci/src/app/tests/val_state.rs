//! The CometBFT validator-state replica: the genesis state `InitChain` builds, its advance by
//! exactly the updates `FinalizeBlock` returns, its persistence across restarts, the records
//! `InitChain` and `Commit` write (the origin's and every snapshot height's full state, every
//! committed height's update record), retention from the newest snapshot below the checkpoint,
//! the recompute between snapshots, and the `/val_state/<height>` query.

use std::collections::BTreeMap;

use tendermint::abci::Code;

use super::{
    finalize::{
        RUN_HEIGHTS, multi_height_run, share_l1_chain, short_limit, short_limit_at, started_at,
        updates_of,
    },
    proposal::{
        bft_time, commit, finalize, finalize_req, judge, next_height, process_req, propose, step,
    },
    *,
};
use crate::{
    app::CODE_REJECTED,
    key::ConsensusKey,
    store::{Record, SEGMENT_HEIGHTS, StoreError},
    test_utils::{GenesisSpec, test_key},
    valstate::ValState,
};

/// A fresh app in `dir`, initialized like `source`, whose own L1 holds `source`'s chain, so it
/// finalizes `source`'s decided blocks cold, as a restarted or block-syncing node does.
async fn replica(
    fx: &Fixture,
    source: &App<MockL1, MockEngine>,
    dir: &Path,
) -> App<MockL1, MockEngine> {
    let app = initialized(fx, dir).await;
    share_l1_chain(source.l1(), app.l1());
    app
}

/// InitChain starts the replica from CometBFT's genesis state of the validators it matched, the
/// origin fallback keys, at the origin (the Etna start S), and persists it with the state.
#[tokio::test]
async fn init_chain_sets_the_genesis_validator_state() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    let expected = ValState::genesis(0, &fx.fallback_keys.validator_set()).unwrap();
    let state = app.state().unwrap();
    assert_eq!(state.val_state, expected);
    assert_eq!(state.val_state.height, state.last_height);
    let saved = Store::volatile(dir.path().into()).load().unwrap().unwrap();
    assert_eq!(saved.val_state, expected);
}

/// A decided header must commit the replica's next signing set even when its execution verdict
/// is cached. Missing or contradictory native hashes halt before any further EL work.
#[tokio::test]
async fn finalize_block_checks_the_decided_next_validator_hash_before_execution() {
    for cached in [false, true] {
        for hash in [tendermint::Hash::None, tendermint::Hash::Sha256([0x55; 32])] {
            let fx = Fixture::genesis(2);
            let dir = tempfile::tempdir().unwrap();
            let mut app = initialized(&fx, dir.path()).await;
            let env = propose(&mut app).await;
            let req = if cached {
                judge(&mut app, &env).await.1
            } else {
                process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()])
            };
            let mut decided = finalize_req(&req);
            decided.next_validators_hash = hash;
            let committed = app.state().unwrap().clone();
            let calls = app.engine().calls();
            let l1_calls = app.l1().calls();

            let error = finalize(&mut app, decided).await.expect_err("the hash contradicts Comet");
            assert!(
                matches!(&error, AbciError::SafetyHalt(reason) if reason.contains("next_validators_hash")),
                "cached={cached}, hash={hash}: {error}"
            );
            assert_eq!(app.engine().calls(), calls, "no EL call after the contradiction");
            assert_eq!(app.l1().calls(), l1_calls, "no L1 call after the contradiction");
            assert_eq!(app.state(), Some(&committed));
            assert!(app.pending.is_none());
            assert_eq!(app.store.load().unwrap(), Some(committed));
            assert!(app.store.fatal_evidence().unwrap().unwrap().contains("next_validators_hash"));
        }
    }
}

/// Across a multi-height run every FinalizeBlock advances the replica by exactly the validator
/// updates it returns, the empty list: at every height it equals a reference replay of the
/// responses, and the set it holds as signing the next height is still the genesis set.
#[tokio::test]
async fn finalize_block_advances_with_the_returned_updates() {
    let fx = short_limit();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_height_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;

    let mut reference = ValState::genesis(0, &fx.fallback_keys.validator_set()).unwrap();
    for (req, expected) in &decided {
        let height = req.height.value();
        let response = finalize(&mut app, req.clone()).await.unwrap();
        assert_eq!(&response, expected, "height {height}");
        let updates = updates_of(&response);
        assert!(updates.is_empty(), "height {height}");
        reference = reference.advance(&updates).unwrap();
        assert_eq!(app.pending.as_ref().unwrap().val_state, reference, "height {height}");
        commit(&mut app).await.unwrap();

        let state = app.state().unwrap();
        assert_eq!(state.val_state, reference, "height {height}");
        assert_eq!(state.val_state.height, height);
        let signing: BTreeMap<ConsensusKey, u64> = reference
            .current
            .entries
            .iter()
            .map(|e| (e.key, u64::try_from(e.power).unwrap()))
            .collect();
        let genesis: BTreeMap<ConsensusKey, u64> =
            fx.fallback_keys.validator_set().into_iter().collect();
        assert_eq!(signing, genesis, "the set signing {}", height + 1);
    }
    assert_eq!(reference.current.entries.len(), 3, "the genesis set signs");
    assert_eq!(source.state().unwrap().val_state, reference, "the proposer agrees");
}

/// The replica is part of the persisted state: a restarted app resumes from the committed one
/// and keeps advancing it. Every committed height's state is recomputed from the origin's
/// snapshot, and a snapshot is immutable: saving the same state again (a replay
/// after a crash before the state was saved) succeeds and another state conflicts. Commit
/// writes a snapshot only at a height divisible by [`SEGMENT_HEIGHTS`]: one that meets a corrupt
/// snapshot there supersedes it (a corrupt record is missing data), while one that
/// meets a well-formed snapshot of another state fails before it persists its state.
#[tokio::test]
async fn val_state_survives_restart_and_snapshots_are_immutable() {
    const HEAD: u64 = 5;
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let mut states = vec![app.state().unwrap().val_state.clone()];
    for _ in 0..HEAD {
        step(&mut app).await;
        states.push(app.state().unwrap().val_state.clone());
    }
    let committed = app.state().unwrap().clone();
    assert_eq!(committed.last_height, HEAD);
    for (height, state) in (0..).zip(&states) {
        assert_eq!(app.store.load_val_state(height).unwrap(), Record::Valid(state.clone()));
    }
    assert_eq!(app.store.val_states().heights().unwrap(), [0], "only the origin's snapshot");
    let recorded = Record::Valid(committed.val_state.clone());

    let engine = app.engine().reopen();
    drop(app);
    let mut app =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    assert_eq!(app.state(), Some(&committed));
    info(&mut app).await.unwrap();
    step(&mut app).await;
    assert_eq!(app.state().unwrap().val_state, committed.val_state.advance(&[]).unwrap());

    app.store.save_val_state(&committed.val_state).unwrap();
    app.store.save_val_state(&committed.val_state).unwrap();
    let mut other = committed.val_state.clone();
    other.next.entries[0].priority += 1;
    assert!(matches!(app.store.save_val_state(&other), Err(StoreError::ValStateConflict(HEAD))));
    assert_eq!(app.store.load_val_state(HEAD).unwrap(), recorded);

    // At the first snapshot height of a run, three heights after its start: a corrupt snapshot
    // is superseded; a well-formed one of another state stops the Commit before the state is
    // saved.
    const PLANTED: u64 = SEGMENT_HEIGHTS;
    let fx = started_at(PLANTED - 3, GenesisSpec::new(2));
    for corrupt in [true, false] {
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        for _ in 1..3 {
            step(&mut app).await;
        }
        let before = app.state().unwrap().clone();
        assert_eq!(app.store.val_states().heights().unwrap(), [PLANTED - 3]);
        let mut other = before.val_state.advance(&[]).unwrap();
        other.next.entries[0].priority += 1;
        app.store.save_val_state(&other).unwrap();
        if corrupt {
            app.store.val_states().corrupt(PLANTED);
        }
        let segment = dir.path().join(format!("val-state-{PLANTED:020}.log"));
        let planted = std::fs::read(&segment).unwrap();
        let env = propose(&mut app).await;
        let (_, req) = judge(&mut app, &env).await;
        finalize(&mut app, finalize_req(&req)).await.unwrap();
        let result = commit(&mut app).await;
        if corrupt {
            result.expect("a corrupt snapshot is superseded");
            let state = app.state().unwrap();
            assert_eq!(state.last_height, PLANTED);
            assert_eq!(
                app.store.load_val_state(PLANTED).unwrap(),
                Record::Valid(state.val_state.clone())
            );
            assert_eq!(app.store.val_states().heights().unwrap(), [PLANTED - 3, PLANTED]);
        } else {
            let err = result.expect_err("the snapshot conflicts");
            assert!(
                matches!(err, AbciError::Store(StoreError::ValStateConflict(PLANTED))),
                "{err:?}"
            );
            assert_eq!(app.state(), Some(&before));
            assert_eq!(Store::volatile(dir.path().into()).load().unwrap(), Some(before));
            assert_eq!(std::fs::read(&segment).unwrap(), planted);
        }
    }
}

/// The records a node keeps, as [`records_are_kept_from_the_newest_snapshot_below_the_checkpoint`]
/// tracks them: every committed height's validator state, InitChain's origin state included,
/// and the updates every committed height returned.
#[derive(Default)]
struct Written {
    /// The validator states by height.
    states: BTreeMap<u64, ValState>,
    /// The returned validator updates by height.
    updates: BTreeMap<u64, Vec<(ConsensusKey, u64)>>,
}

/// Whether pruning below `floor` keeps the segment holding `height`.
fn kept(height: u64, floor: u64) -> bool {
    floor.saturating_sub(height - height % SEGMENT_HEIGHTS) < SEGMENT_HEIGHTS
}

impl Written {
    /// Asserts that `app` keeps exactly the records retention leaves,
    /// a segment at a time: the snapshots (the origin's and those of the heights divisible by
    /// [`SEGMENT_HEIGHTS`]) from the newest one below the checkpoint s, the base, on, the update
    /// records above the base, and the Comet block IDs and execution blocks from s on. Every
    /// height from s − 1 (from the origin while s is the origin) through `last_height`
    /// recomputes to the state committed there.
    fn assert_retained(&self, app: &App<MockL1, MockEngine>) {
        let state = app.state().unwrap();
        let (last, checkpoint, origin) =
            (state.last_height, state.comet_history_floor(), state.origin_height());
        let snapshots = self
            .states
            .keys()
            .copied()
            .filter(|&height| height == origin || height % SEGMENT_HEIGHTS == 0)
            .collect::<Vec<_>>();
        let base = snapshots.iter().copied().filter(|&height| height < checkpoint).max();
        let at = format!("head {last}, checkpoint {checkpoint}, base {base:?}");
        let expected = snapshots.iter().copied().filter(|&h| base.is_none_or(|b| kept(h, b)));
        assert_eq!(app.store.val_states().heights().unwrap(), expected.collect::<Vec<_>>(), "{at}");
        let expected =
            self.updates.keys().copied().filter(|&h| base.is_none_or(|b| kept(h, b + 1)));
        assert_eq!(
            app.store.val_updates().heights().unwrap(),
            expected.collect::<Vec<_>>(),
            "{at}"
        );
        for height in origin + 1..=last {
            let comet = app.store.load_comet_hash(height).unwrap();
            assert_eq!(comet.is_some(), kept(height, checkpoint), "Comet ID {height} at {at}");
            let block = app.store.load_execution_block(height).unwrap();
            let held = matches!(block, Record::Valid(_));
            assert_eq!(held, kept(height, checkpoint), "execution block {height} at {at}");
        }
        for height in checkpoint.saturating_sub(1).max(origin)..=last {
            let expected = Record::Valid(self.states[&height].clone());
            assert_eq!(app.store.load_val_state(height).unwrap(), expected, "{height} at {at}");
        }
        let above = app.store.load_val_state(last + 1).unwrap();
        assert!(matches!(above, Record::Corrupt(_)), "{above:?} above {at}");
    }
}

/// InitChain records the origin's snapshot and Commit the updates of every committed height,
/// an empty list included, and the snapshot of every height divisible by [`SEGMENT_HEIGHTS`].
/// Over a run that crosses a segment boundary, on a replaying node and on the proposer alike,
/// retention keeps after every commit exactly the records [`Written::assert_retained`] names:
/// from the newest snapshot below the checkpoint s on, the base the state at s − 1 (the preimage
/// an import package at s carries, 5.4) and later ones are recomputed from,
/// and the Comet block IDs and execution blocks from s's segment on.
#[tokio::test]
async fn records_are_kept_from_the_newest_snapshot_below_the_checkpoint() {
    let origin = SEGMENT_HEIGHTS - 8;
    let fx = short_limit_at(origin);
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_height_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;

    let mut written = Written::default();
    written.states.insert(origin, app.state().unwrap().val_state.clone());
    written.assert_retained(&app);
    for (req, response) in &decided {
        finalize(&mut app, req.clone()).await.unwrap();
        commit(&mut app).await.unwrap();
        let state = app.state().unwrap();
        let height = state.last_height;
        written.states.insert(height, state.val_state.clone());
        written.updates.insert(height, updates_of(response));
        written.assert_retained(&app);
    }
    let heights = (origin..=origin + RUN_HEIGHTS).collect::<Vec<_>>();
    assert_eq!(written.states.keys().copied().collect::<Vec<_>>(), heights);
    assert_eq!(written.updates.keys().copied().collect::<Vec<_>>(), heights[1..]);
    for (height, updates) in &written.updates {
        assert!(updates.is_empty(), "height {height}");
    }
    let state = app.state().unwrap();
    assert!(state.comet_history_floor() > SEGMENT_HEIGHTS, "the checkpoint passes a snapshot");
    assert_eq!(app.store.val_states().heights().unwrap(), [SEGMENT_HEIGHTS], "the origin's goes");
    written.assert_retained(&source);
}

/// A crash after Commit wrote a height's records but before it saved the state makes CometBFT
/// replay that height: FinalizeBlock and Commit over the reopened store derive the same
/// records, whose re-save succeeds and leaves their bytes unchanged.
#[tokio::test]
async fn replayed_commit_rewrites_identical_update_records() {
    let fx = short_limit();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_height_run(&fx, source_dir.path()).await;

    for switch in [2, 6] {
        let dir = tempfile::tempdir().unwrap();
        let mut app = replica(&fx, &source, dir.path()).await;
        for (req, _) in &decided[..switch] {
            finalize(&mut app, req.clone()).await.unwrap();
            commit(&mut app).await.unwrap();
        }
        let committed = app.state().unwrap().clone();
        let state_file = dir.path().join(crate::store::STATE_FILE);
        let saved = std::fs::read(&state_file).unwrap();
        let (req, response) = &decided[switch];
        let height = req.height.value();
        finalize(&mut app, req.clone()).await.unwrap();
        commit(&mut app).await.unwrap();
        let record = dir.path().join("val-updates-00000000000000000000.log");
        let bytes = std::fs::read(&record).unwrap();
        let expected = Record::Valid(updates_of(response));
        assert_eq!(app.store.load_val_updates(height).unwrap(), expected, "height {height}");

        // The crash: the records stay, the state file holds the previous height.
        std::fs::write(&state_file, saved).unwrap();
        let engine = app.engine().reopen();
        drop(app);
        let mut app = app_with(
            fx.l1(),
            engine,
            fx.params.clone(),
            dir.path(),
            crate::test_utils::test_options(),
        );
        share_l1_chain(source.l1(), app.l1());
        assert_eq!(app.state(), Some(&committed));
        info(&mut app).await.unwrap();
        assert_eq!(&finalize(&mut app, req.clone()).await.unwrap(), response, "height {height}");
        commit(&mut app).await.expect("the identical records are saved again");
        assert_eq!(app.state().unwrap().last_height, height);
        assert_eq!(std::fs::read(&record).unwrap(), bytes, "height {height}");
        assert_eq!(app.store.load_val_updates(height).unwrap(), expected, "height {height}");
    }
}

/// `/val_state/<height>` answers the raw preimage at every retained height, from the head
/// state or recomputed from a snapshot: every height from the checkpoint's s − 1 (the preimage
/// an import package at s carries, 5.4) through the head, and the origin
/// while the checkpoint is the origin. It rejects a height below s − 1, though the store can
/// still recompute it, one above the head, though a valid snapshot is planted there, and a
/// malformed number.
#[tokio::test]
async fn val_state_query_serves_any_retained_height() {
    let fx = short_limit();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_height_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;

    const HEAD: u64 = 9;
    let mut states = BTreeMap::from([(0, app.state().unwrap().val_state.clone())]);
    for (req, _) in decided.iter().take_while(|(req, _)| req.height.value() <= HEAD) {
        finalize(&mut app, req.clone()).await.unwrap();
        commit(&mut app).await.unwrap();
        let state = app.state().unwrap().clone();
        states.insert(state.last_height, state.val_state.clone());
        if state.last_height == 1 {
            // The checkpoint is still the origin, whose state InitChain recorded: it is served.
            assert_eq!(state.comet_history_floor(), 0);
            let answer = query(&mut app, "/val_state/0").await;
            assert_eq!(answer.code, Code::Ok, "{}", answer.log);
            assert_eq!(answer.value.as_ref(), states[&0].encode());
        }
        let answer = query(&mut app, &format!("/val_state/{}", state.last_height)).await;
        assert_eq!(answer.code, Code::Ok, "{}", answer.log);
        assert_eq!(answer.value.as_ref(), state.val_state.encode(), "the head answers itself");
    }
    let state = app.state().unwrap().clone();
    assert_eq!(state.last_height, HEAD);
    let checkpoint = state.comet_history_floor();
    assert!((2..HEAD).contains(&checkpoint), "checkpoint {checkpoint}");
    let retained = checkpoint - 1..=HEAD;
    for height in retained.clone() {
        let answer = query(&mut app, &format!("/val_state/{height}")).await;
        assert_eq!(answer.code, Code::Ok, "height {height}: {}", answer.log);
        let decoded = ValState::decode(&answer.value).unwrap();
        assert_eq!(decoded, states[&height], "height {height}");
        assert_eq!(app.val_state_preimage(height), Ok(answer.value.to_vec()));
    }

    // Valid states outside the retained range are still refused: one below s − 1, which the
    // store still recomputes, and a planted snapshot of a future height.
    let below = checkpoint - 2;
    assert_eq!(app.store.load_val_state(below).unwrap(), Record::Valid(states[&below].clone()));
    let future = states[&HEAD].advance(&[]).unwrap();
    app.store.save_val_state(&future).unwrap();
    for height in [below, 0, HEAD + 1] {
        assert!(app.val_state_preimage(height).is_err(), "height {height}");
    }
    let rejected = [
        format!("/val_state/{below}"),      // below s − 1, still recomputable
        "/val_state/0".to_string(),         // the origin, below s − 1
        format!("/val_state/{}", HEAD + 1), // above the head, a valid snapshot planted
        "/val_state/".to_string(),
        "/val_state/x".to_string(),
        format!("/val_state/+{HEAD}"),
        format!("/val_state/0{HEAD}"),
        format!("/val_state/-{HEAD}"),
        format!("/val_state/{HEAD}/"),
        "/val_state/18446744073709551616".to_string(),
    ];
    for path in &rejected {
        let answer = query(&mut app, path).await;
        assert_eq!(answer.code, Code::from(CODE_REJECTED), "{path}");
        assert!(answer.value.is_empty(), "{path}");
        assert!(!answer.log.is_empty(), "{path}");
    }
}

/// After a checkpoint import the snapshot at s is the installed preimage, the base
/// the later states are recomputed from with the update records Commit writes above it.
#[test]
fn an_installed_import_record_is_the_recompute_base() {
    let fx = Fixture::genesis(1);
    let (state, _) = fx.imported_state(12, 12);
    let dir = tempfile::tempdir().unwrap();
    let store = Store::volatile(dir.path().into());
    store.install_import(&state, None).unwrap();
    for height in 13..=18 {
        store.save_val_updates(height, &[]).unwrap();
    }
    let expected = (13..=18).try_fold(state.val_state.clone(), |s, _| s.advance(&[])).unwrap();
    assert_eq!(store.load_val_state(18).unwrap(), Record::Valid(expected));
}

/// A store holding `ValState::genesis` of three keys at `base` as its snapshot, and empty update
/// records for every height in `updates`.
fn recompute_store(
    base: u64,
    updates: std::ops::RangeInclusive<u64>,
) -> (tempfile::TempDir, Store, ValState) {
    let dir = tempfile::tempdir().unwrap();
    let store = Store::volatile(dir.path().into());
    let members = [(test_key(1), 10), (test_key(2), 20), (test_key(3), 30)];
    let start = ValState::genesis(base, &members).unwrap();
    store.save_val_state(&start).unwrap();
    for height in updates {
        store.save_val_updates(height, &[]).unwrap();
    }
    (dir, store, start)
}

/// Without a snapshot at or below the height there is nothing to recompute from: missing data.
/// A snapshot at the height itself is its state.
#[test]
fn recompute_without_a_snapshot_at_or_below_is_missing() {
    let dir = tempfile::tempdir().unwrap();
    let store = Store::volatile(dir.path().into());
    assert_eq!(store.load_val_state(5).unwrap(), Record::Missing);

    let (_dir, store, start) = recompute_store(5, 6..=6);
    assert_eq!(store.load_val_state(4).unwrap(), Record::Missing);
    assert_eq!(store.load_val_state(5).unwrap(), Record::Valid(start.clone()));
    assert_eq!(store.load_val_state(6).unwrap(), Record::Valid(start.advance(&[]).unwrap()));
}

/// A corrupt snapshot is no base; the newest valid one below it is, and the recompute advances
/// from there through the corrupt height.
#[test]
fn recompute_skips_a_corrupt_newer_snapshot_for_an_older_valid_one() {
    let (_dir, store, start) = recompute_store(10, 11..=14);
    let newer = start.advance(&[]).unwrap().advance(&[]).unwrap();
    assert_eq!(newer.height, 12);
    store.save_val_state(&newer).unwrap();
    store.val_states().corrupt(12);
    let expected = (11..=14).try_fold(start, |state, _| state.advance(&[])).unwrap();
    assert_eq!(store.load_val_state(14).unwrap(), Record::Valid(expected));
}

/// The update record of each height is applied at that height, a non-empty one
/// changing the set: here one key leaves and another joins at 12.
#[test]
fn recompute_applies_a_non_empty_update_list_at_its_height() {
    let (_dir, store, start) = recompute_store(10, 11..=13);
    let updates = vec![(test_key(1), 0), (test_key(4), 40)];
    store.val_updates().remove(12);
    store.save_val_updates(12, &updates).unwrap();
    let expected = start.advance(&[]).unwrap().advance(&updates).unwrap().advance(&[]).unwrap();
    let Record::Valid(recomputed) = store.load_val_state(13).unwrap() else { panic!() };
    assert_eq!(recomputed, expected);
    let next: Vec<ConsensusKey> = recomputed.next.entries.iter().map(|e| e.key).collect();
    assert!(next.contains(&test_key(4)) && !next.contains(&test_key(1)), "{next:?}");
}

/// Every height records its validator updates, so a missing record at any height
/// between the snapshot and the target is missing data, not "no change", until it is back.
#[test]
fn recompute_needs_a_record_at_every_height() {
    let (_dir, store, start) = recompute_store(10, 11..=14);
    store.val_updates().remove(12);
    let Record::Corrupt(reason) = store.load_val_state(14).unwrap() else { panic!() };
    assert!(reason.contains("the validator-update record of height 12 is missing"), "{reason}");
    // The heights below the gap still recompute.
    assert_eq!(store.load_val_state(11).unwrap(), Record::Valid(start.advance(&[]).unwrap()));
    store.save_val_updates(12, &[]).unwrap();
    let expected = (11..=14).try_fold(start, |state, _| state.advance(&[])).unwrap();
    assert_eq!(store.load_val_state(14).unwrap(), Record::Valid(expected));
}

/// A retained height between snapshots answers the state recomputed from the base
/// snapshot and the update records since. Without an input it needs, an update record on the
/// way or a valid base, the state is missing data: refused naming the cause, and nothing is
/// recorded, until the input is back.
#[tokio::test]
async fn val_state_query_recomputes_between_snapshots_and_waits_without_their_inputs() {
    let fx = short_limit();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_height_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;
    // The queried height is 11, between the base and the head.
    let (lost, head) = (11, 12);
    for (req, _) in decided.iter().take_while(|(req, _)| req.height.value() <= head) {
        finalize(&mut app, req.clone()).await.unwrap();
        commit(&mut app).await.unwrap();
    }
    let state = app.state().unwrap();
    assert_eq!(state.last_height, head);
    assert!(state.comet_history_floor() - 1 < lost, "the height is retained");
    assert_eq!(app.store.val_states().heights().unwrap(), [0], "the origin is the only snapshot");
    let Record::Valid(at_lost) = app.store.load_val_state(lost).unwrap() else {
        panic!("the height recomputes")
    };

    let path = format!("/val_state/{lost}");
    let answers = async |app: &mut App<MockL1, MockEngine>| {
        let answer = query(app, &path).await;
        assert_eq!(answer.code, Code::Ok, "{}", answer.log);
        assert_eq!(answer.value.as_ref(), at_lost.encode());
    };
    answers(&mut app).await;
    let refused = async |app: &mut App<MockL1, MockEngine>, cause: &str| {
        let error = app.val_state_preimage(lost).expect_err("an input is missing");
        assert!(error.contains(cause), "{error}");
        let answer = query(app, &path).await;
        assert_eq!(answer.code, Code::from(CODE_REJECTED));
        assert!(answer.value.is_empty() && !answer.log.is_empty());
    };

    let updates = app.store.val_updates().remove(lost).expect("recorded");
    refused(&mut app, &format!("record of height {lost} is missing")).await;
    assert_eq!(app.store.load_val_updates(lost).unwrap(), Record::Missing, "nothing is recorded");
    app.store.val_updates().append(lost, &updates).unwrap();
    answers(&mut app).await;

    app.store.val_states().corrupt(0);
    refused(&mut app, "snapshot of height 0 is corrupt").await;
    app.store
        .save_val_state(&ValState::genesis(0, &fx.fallback_keys.validator_set()).unwrap())
        .unwrap();
    answers(&mut app).await;
}
