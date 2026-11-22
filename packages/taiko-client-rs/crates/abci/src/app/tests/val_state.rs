//! The CometBFT validator-state replica: the genesis state `InitChain` builds, its advance by
//! exactly the updates `FinalizeBlock` returns, its persistence across restarts, the records
//! `InitChain` and `Commit` write (the origin's and every committed height's sidecar and update
//! record), retention from the checkpoint's s − 1 on, the recompute of a lost record from them,
//! and the `/val_state/<height>` query.

use std::collections::BTreeMap;

use tendermint::abci::Code;

use super::{
    finalize::{RUN_HEIGHTS, multi_height_run, share_l1_chain, short_limit, updates_of},
    proposal::{
        bft_time, commit, finalize, finalize_req, judge, next_height, process_req, propose, step,
    },
    *,
};
use crate::{
    app::{CODE_REJECTED, info::recompute_val_state},
    key::ConsensusKey,
    store::{Record, StoreError},
    test_utils::test_key,
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
/// `e_0` committee, at the origin (the Etna start S), and persists it with the state.
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
/// and keeps advancing it. Every committed height has a sidecar (SYNC-9-5c), and it is
/// immutable: saving the same state again (a replay after a crash before the state was saved)
/// succeeds and another state conflicts. A Commit that meets a corrupt sidecar sets it aside
/// and writes its own (a corrupt record is missing data, SYNC-9-7), while one that meets a
/// well-formed sidecar of another state fails before it persists its state.
#[tokio::test]
async fn val_state_survives_restart_and_sidecar_is_immutable() {
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
    let mut other = committed.val_state.clone();
    other.next.entries[0].priority += 1;
    assert!(matches!(app.store.save_val_state(&other), Err(StoreError::ValStateConflict(HEAD))));
    assert_eq!(app.store.load_val_state(HEAD).unwrap(), recorded);

    // At any height of a fresh run, here the third: a corrupt sidecar is set aside and
    // replaced; a well-formed one of another state stops the Commit before the state is saved.
    const PLANTED: u64 = 3;
    for corrupt in [true, false] {
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        for _ in 1..PLANTED {
            step(&mut app).await;
        }
        let before = app.state().unwrap().clone();
        let sidecar = dir.path().join(format!("val-state-{PLANTED}.bin"));
        if corrupt {
            std::fs::write(&sidecar, b"conflicting").unwrap();
        } else {
            let mut other = before.val_state.advance(&[]).unwrap();
            other.next.entries[0].priority += 1;
            app.store.save_val_state(&other).unwrap();
        }
        let planted = std::fs::read(&sidecar).unwrap();
        let env = propose(&mut app).await;
        let (_, req) = judge(&mut app, &env).await;
        finalize(&mut app, finalize_req(&req)).await.unwrap();
        let result = commit(&mut app).await;
        if corrupt {
            result.expect("a corrupt sidecar is replaced");
            let state = app.state().unwrap();
            assert_eq!(state.last_height, PLANTED);
            let set_aside = dir.path().join(format!("val-state-{PLANTED}.bin.corrupt"));
            assert_eq!(std::fs::read(set_aside).unwrap(), planted);
            assert_eq!(
                app.store.load_val_state(PLANTED).unwrap(),
                Record::Valid(state.val_state.clone())
            );
        } else {
            let err = result.expect_err("the sidecar conflicts");
            assert!(
                matches!(err, AbciError::Store(StoreError::ValStateConflict(PLANTED))),
                "{err:?}"
            );
            assert_eq!(app.state(), Some(&before));
            assert_eq!(Store::volatile(dir.path().into()).load().unwrap(), Some(before));
            assert_eq!(std::fs::read(&sidecar).unwrap(), planted);
        }
    }
}

/// The records a node keeps, as [`val_records_are_kept_from_the_checkpoint_minus_one`] tracks
/// them: the validator states recorded so far (InitChain's origin state, then every committed
/// height's) and the updates every committed height returned.
#[derive(Default)]
struct Written {
    /// The recorded validator states by height.
    states: BTreeMap<u64, ValState>,
    /// The returned validator updates by height.
    updates: BTreeMap<u64, Vec<(ConsensusKey, u64)>>,
}

impl Written {
    /// Asserts that `app` keeps exactly the records retention leaves (SYNC-9-5c, DATA-5.4-8):
    /// the recorded states from the checkpoint's s − 1 (the height an import package at s needs)
    /// through `last_height`, from the origin while the checkpoint is the origin, and the updates
    /// of the heights above s − 1.
    fn assert_retained(&self, app: &App<MockL1, MockEngine>) {
        let state = app.state().unwrap();
        let (last, checkpoint) = (state.last_height, state.comet_history_floor());
        let base = checkpoint.checked_sub(1);
        for height in 0..=last + 4 {
            let kept = (base.unwrap_or(checkpoint)..=last).contains(&height);
            let expected = self
                .states
                .get(&height)
                .filter(|_| kept)
                .map_or(Record::Missing, |recorded| Record::Valid(recorded.clone()));
            assert_eq!(
                app.store.load_val_state(height).unwrap(),
                expected,
                "sidecar {height} at head {last} (checkpoint {checkpoint})"
            );
            let expected = self
                .updates
                .get(&height)
                .filter(|_| base.is_none_or(|base| height > base))
                .map_or(Record::Missing, |updates| Record::Valid(updates.clone()));
            assert_eq!(
                app.store.load_val_updates(height).unwrap(),
                expected,
                "update record {height} at head {last} (checkpoint {checkpoint})"
            );
        }
    }
}

/// InitChain records the origin state and Commit the state and the updates at every committed
/// height, an empty list included. Retention keeps the records from the
/// checkpoint's s − 1 on, the preimage an import package at s carries (DATA-5.4-3, DATA-5.4-8),
/// which is also the base the states above it are recomputed from: after every commit, on a
/// replaying node and on the proposer alike, the sidecars on disk are exactly those of
/// `[checkpoint − 1, last_height]` and the update records those of the heights above
/// checkpoint − 1.
#[tokio::test]
async fn val_records_are_kept_from_the_checkpoint_minus_one() {
    let fx = short_limit();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_height_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;

    let mut written = Written::default();
    let origin = app.state().unwrap();
    written.states.insert(origin.last_height, origin.val_state.clone());
    written.assert_retained(&app);
    let mut checkpoints = vec![];
    for (req, response) in &decided {
        finalize(&mut app, req.clone()).await.unwrap();
        commit(&mut app).await.unwrap();
        let state = app.state().unwrap();
        let height = state.last_height;
        written.states.insert(height, state.val_state.clone());
        written.updates.insert(height, updates_of(response));
        written.assert_retained(&app);
        checkpoints.push(state.comet_history_floor());
    }
    let heights = (0..=RUN_HEIGHTS).collect::<Vec<_>>();
    assert_eq!(written.states.keys().copied().collect::<Vec<_>>(), heights);
    assert_eq!(written.updates.keys().copied().collect::<Vec<_>>(), heights[1..]);
    for (height, updates) in &written.updates {
        assert!(updates.is_empty(), "height {height}");
    }
    checkpoints.dedup();
    assert!(
        checkpoints.len() > 2 && checkpoints.iter().any(|c| c % 6 != 0 && *c > 1),
        "the checkpoint rises through heights off the old grid: {checkpoints:?}"
    );
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
        let record = dir.path().join(format!("val-updates-{height}.bin"));
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
/// state or from its sidecar: every height from the checkpoint's s − 1 (the preimage an import
/// package at s carries, DATA-5.4-3, DATA-5.4-8) through the head, whether or not it is a
/// multiple of 6, and the origin while the checkpoint is the origin. It rejects a height below
/// s − 1 or above the head, though a valid sidecar is planted there, and a malformed number.
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
    assert!(retained.clone().any(|h| h % 6 != 0), "{retained:?} holds non-grid heights");
    for height in retained.clone() {
        let answer = query(&mut app, &format!("/val_state/{height}")).await;
        assert_eq!(answer.code, Code::Ok, "height {height}: {}", answer.log);
        let decoded = ValState::decode(&answer.value).unwrap();
        assert_eq!(decoded, states[&height], "height {height}");
        assert_eq!(app.val_state_preimage(height), Ok(answer.value.to_vec()));
    }

    // Valid preimages outside the retained range are still refused: one planted below s − 1,
    // where retention deleted the record, and one of a future height.
    let below = checkpoint - 2;
    assert_eq!(app.store.load_val_state(below).unwrap(), Record::Missing);
    app.store.save_val_state(&states[&below]).unwrap();
    let future = states[&HEAD].advance(&[]).unwrap();
    app.store.save_val_state(&future).unwrap();
    for height in [below, 0, HEAD + 1] {
        assert!(app.val_state_preimage(height).is_err(), "height {height}");
    }
    let rejected = [
        format!("/val_state/{below}"), // below s − 1, a valid sidecar planted
        "/val_state/0".to_string(),    // the origin, below s − 1
        format!("/val_state/{}", HEAD + 1), // above the head, a valid sidecar planted
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

/// SYNC-9-5c: after a checkpoint import the record at s is the installed preimage, the base a
/// later lost record is recomputed from with the update records Commit writes above it.
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
    assert_eq!(recompute_val_state(&store, 0, 18), Ok(expected));
}

/// A store holding `ValState::genesis` of three keys at `base`, and empty update records for
/// every height in `updates`.
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

/// Without a valid record below the height, from the generation's origin on, there
/// is nothing to recompute from: missing data, an error naming the range.
#[test]
fn recompute_without_a_valid_starting_record_is_an_error() {
    let dir = tempfile::tempdir().unwrap();
    let store = Store::volatile(dir.path().into());
    let error = recompute_val_state(&store, 0, 5).unwrap_err();
    assert!(error.contains("no valid validator-state record below height 5"), "{error}");

    // A record at the height itself is not below it.
    let (_dir, store, _) = recompute_store(5, 6..=6);
    let error = recompute_val_state(&store, 0, 5).unwrap_err();
    assert!(error.contains("below height 5"), "{error}");
}

/// A valid record below the generation's origin belongs to an earlier generation and
/// is no base: with the only valid record at 10 and the origin at 11 there is none, while the
/// same store recomputes from it with the origin at 10.
#[test]
fn recompute_excludes_a_record_below_the_generation_origin() {
    let (_dir, store, start) = recompute_store(10, 11..=13);
    let error = recompute_val_state(&store, 11, 13).unwrap_err();
    assert!(error.contains("below height 13 from the generation's origin 11"), "{error}");
    let expected = (11..=13).try_fold(start, |state, _| state.advance(&[])).unwrap();
    assert_eq!(recompute_val_state(&store, 10, 13), Ok(expected));
}

/// A corrupt record is no base; the newest valid record below it is, and the
/// recompute advances from there through the corrupt height.
#[test]
fn recompute_skips_a_corrupt_newer_record_for_an_older_valid_one() {
    let (dir, store, start) = recompute_store(10, 11..=14);
    let newer = start.advance(&[]).unwrap().advance(&[]).unwrap();
    assert_eq!(newer.height, 12);
    store.save_val_state(&newer).unwrap();
    std::fs::write(dir.path().join("val-state-12.bin"), b"corrupt").unwrap();
    assert!(matches!(store.load_val_state(12).unwrap(), Record::Corrupt(_)));
    let expected = (11..=14).try_fold(start, |state, _| state.advance(&[])).unwrap();
    assert_eq!(recompute_val_state(&store, 0, 14), Ok(expected));
}

/// The update record of each height is applied at that height, a non-empty one
/// changing the set: here one key leaves and another joins at 12.
#[test]
fn recompute_applies_a_non_empty_update_list_at_its_height() {
    let (_dir, store, start) = recompute_store(10, 11..=13);
    let updates = vec![(test_key(1), 0), (test_key(4), 40)];
    std::fs::remove_file(store.directory().join("val-updates-12.bin")).unwrap();
    store.save_val_updates(12, &updates).unwrap();
    let expected = start.advance(&[]).unwrap().advance(&updates).unwrap().advance(&[]).unwrap();
    let recomputed = recompute_val_state(&store, 0, 13).unwrap();
    assert_eq!(recomputed, expected);
    let next: Vec<ConsensusKey> = recomputed.next.entries.iter().map(|e| e.key).collect();
    assert!(next.contains(&test_key(4)) && !next.contains(&test_key(1)), "{next:?}");
}

/// Every height records its validator updates, so a missing record at any height
/// between the base and the target is missing data, not "no change", until it is back.
#[test]
fn recompute_needs_a_record_at_every_height() {
    let (_dir, store, start) = recompute_store(10, 11..=14);
    std::fs::remove_file(store.directory().join("val-updates-12.bin")).unwrap();
    let error = recompute_val_state(&store, 0, 14).unwrap_err();
    assert!(error.contains("the validator-update record of height 12 is missing"), "{error}");
    // The heights below the gap still recompute.
    assert_eq!(recompute_val_state(&store, 0, 11), Ok(start.advance(&[]).unwrap()));
    store.save_val_updates(12, &[]).unwrap();
    let expected = (11..=14).try_fold(start, |state, _| state.advance(&[])).unwrap();
    assert_eq!(recompute_val_state(&store, 0, 14), Ok(expected));
}

/// SYNC-9-5c: a retained height whose record is missing or corrupt (junk, the bare preimage
/// without its checksum, or the well-formed record of another height) answers the state
/// recomputed from the base at the checkpoint's s − 1 and the update records since, and
/// records it again byte for byte, a corrupt file set aside first (5c.i). Without an update
/// record it needs, here the empty one at the lost height itself, the state is missing data:
/// refused and not recorded, until the update record is back.
#[tokio::test]
async fn val_state_query_recomputes_lost_records_and_waits_without_their_inputs() {
    let fx = short_limit();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_height_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;
    // The lost record is height 11, between the base and the head.
    let (lost, head) = (11, 12);
    for (req, _) in decided.iter().take_while(|(req, _)| req.height.value() <= head) {
        finalize(&mut app, req.clone()).await.unwrap();
        commit(&mut app).await.unwrap();
    }
    let state = app.state().unwrap();
    assert_eq!(state.last_height, head);
    let base = state.comet_history_floor() - 1;
    assert!(base < lost, "base {base}");
    assert!(matches!(app.store.load_val_state(base).unwrap(), Record::Valid(_)));
    assert_eq!(app.store.load_val_state(base - 1).unwrap(), Record::Missing, "pruned below");
    assert_eq!(app.store.load_val_updates(lost).unwrap(), Record::Valid(vec![]));

    let path = format!("/val_state/{lost}");
    let sidecar = dir.path().join(format!("val-state-{lost}.bin"));
    let recorded = std::fs::read(&sidecar).unwrap();
    let Record::Valid(at_lost) = app.store.load_val_state(lost).unwrap() else {
        panic!("the height is recorded")
    };
    let answers = async |app: &mut App<MockL1, MockEngine>| {
        let answer = query(app, &path).await;
        assert_eq!(answer.code, Code::Ok, "{}", answer.log);
        assert_eq!(answer.value.as_ref(), at_lost.encode());
        assert_eq!(std::fs::read(&sidecar).unwrap(), recorded, "recorded again");
    };

    std::fs::remove_file(&sidecar).unwrap();
    answers(&mut app).await;

    let set_aside = dir.path().join(format!("val-state-{lost}.bin.corrupt"));
    let other_height = std::fs::read(dir.path().join(format!("val-state-{base}.bin")));
    for bytes in [b"junk".to_vec(), at_lost.encode(), other_height.unwrap()] {
        std::fs::write(&sidecar, &bytes).unwrap();
        answers(&mut app).await;
        assert_eq!(std::fs::read(&set_aside).unwrap(), bytes);
    }

    std::fs::remove_file(&sidecar).unwrap();
    std::fs::remove_file(dir.path().join(format!("val-updates-{lost}.bin"))).unwrap();
    let error = app.val_state_preimage(lost).expect_err("an update record is missing");
    assert!(error.contains(&format!("record of height {lost} is missing")), "{error}");
    let answer = query(&mut app, &path).await;
    assert_eq!(answer.code, Code::from(CODE_REJECTED));
    assert!(answer.value.is_empty() && !answer.log.is_empty());
    assert!(!sidecar.exists(), "nothing is recorded without the inputs");

    app.store.save_val_updates(lost, &[]).unwrap();
    answers(&mut app).await;
}
