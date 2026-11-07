//! The CometBFT validator-state replica: the genesis state `InitChain` builds, its advance by
//! exactly the updates `FinalizeBlock` returns, its persistence across restarts, the grid
//! sidecars `Commit` writes and prunes with the Comet history floor, and the
//! `/val_state/<height>` query.

use std::collections::BTreeMap;

use tendermint::abci::Code;

use super::{
    finalize::{multi_epoch_run, share_l1_chain, short_epochs, updates_of},
    proposal::{
        bft_time, commit, finalize, finalize_req, judge, next_height, process_req, propose, step,
    },
    *,
};
use crate::{
    GRID_INTERVAL,
    app::CODE_REJECTED,
    key::ConsensusKey,
    store::{Record, StoreError},
    test_utils::powers,
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
/// `e_0` committee, at the origin `B*`, and persists it with the state.
#[tokio::test]
async fn init_chain_sets_the_genesis_validator_state() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    let expected = ValState::genesis(0, &powers(&fx.members)).unwrap();
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

/// A response's updates affect h+2; the decided h header still names the old h+1 set.
#[tokio::test]
async fn finalize_block_next_validator_hash_does_not_apply_its_own_updates_early() {
    let fx = short_epochs();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_epoch_run(&fx, source_dir.path()).await;
    let switch = decided.iter().position(|(_, response)| !updates_of(response).is_empty()).unwrap();

    for use_future_hash in [false, true] {
        let dir = tempfile::tempdir().unwrap();
        let mut app = replica(&fx, &source, dir.path()).await;
        for (req, _) in &decided[..switch] {
            finalize(&mut app, req.clone()).await.unwrap();
            commit(&mut app).await.unwrap();
        }
        let (req, response) = &decided[switch];
        let future = app.state().unwrap().val_state.advance(&updates_of(response)).unwrap();
        let future_hash = tendermint::Hash::Sha256(future.next.validators_hash().unwrap().0);
        assert_ne!(req.next_validators_hash, future_hash, "the switch changes keys/powers");
        if use_future_hash {
            let mut req = req.clone();
            req.next_validators_hash = future_hash;
            assert!(matches!(finalize(&mut app, req).await, Err(AbciError::SafetyHalt(_))));
            assert!(app.pending.is_none());
        } else {
            finalize(&mut app, req.clone()).await.unwrap();
            commit(&mut app).await.unwrap();
            let (following, _) = &decided[switch + 1];
            assert_eq!(following.next_validators_hash, future_hash);
            finalize(&mut app, following.clone()).await.unwrap();
        }
    }
}

/// Across the switches of a multi-epoch run (one of which adds a validator), every
/// FinalizeBlock advances the replica by exactly the validator updates it returns: at every
/// height it equals a reference replay of the responses, and the set it holds as signing the
/// next height is the committee active there.
#[tokio::test]
async fn finalize_block_advances_with_the_returned_updates() {
    let fx = short_epochs();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_epoch_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;

    let mut reference = ValState::genesis(0, &powers(&fx.members)).unwrap();
    let mut changes = vec![];
    for (req, expected) in &decided {
        let height = req.height.value();
        let response = finalize(&mut app, req.clone()).await.unwrap();
        assert_eq!(&response, expected, "height {height}");
        let updates = updates_of(&response);
        if !updates.is_empty() {
            changes.push(height);
        }
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
        let active = state.committee_at(height + 1).expect("the next height's committee");
        let active: BTreeMap<ConsensusKey, u64> = powers(&active.members).into_iter().collect();
        assert_eq!(signing, active, "the set signing {}", height + 1);
    }
    let schedule = fx.schedule();
    assert_eq!(changes, [schedule.h_first(2) - 2], "only the switch to 2 changes the set");
    assert_eq!(reference.current.entries.len(), 4, "the fourth validator signs");
    assert_eq!(source.state().unwrap().val_state, reference, "the proposer agrees");
}

/// The replica is part of the persisted state: a restarted app resumes from the committed one
/// and keeps advancing it. A grid sidecar is immutable: saving the same state again (a replay
/// after a crash before the state was saved) succeeds and another state conflicts. A Commit
/// that meets a corrupt sidecar sets it aside and writes its own (a corrupt record is missing
/// data, SYNC-9-7), while one that meets a well-formed sidecar of another state fails before
/// it persists its state.
#[tokio::test]
async fn val_state_survives_restart_and_sidecar_is_immutable() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..GRID_INTERVAL {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    assert_eq!(committed.last_height, GRID_INTERVAL);
    let recorded = Record::Valid(committed.val_state.clone());
    assert_eq!(app.store.load_val_state(GRID_INTERVAL).unwrap(), recorded);

    let engine = app.engine().reopen();
    drop(app);
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());
    assert_eq!(app.state(), Some(&committed));
    info(&mut app).await.unwrap();
    step(&mut app).await;
    assert_eq!(app.state().unwrap().val_state, committed.val_state.advance(&[]).unwrap());

    app.store.save_val_state(&committed.val_state).unwrap();
    let mut other = committed.val_state.clone();
    other.next.entries[0].priority += 1;
    assert!(matches!(
        app.store.save_val_state(&other),
        Err(StoreError::ValStateConflict(GRID_INTERVAL))
    ));
    assert_eq!(app.store.load_val_state(GRID_INTERVAL).unwrap(), recorded);

    // At the first grid height of a fresh run: a corrupt sidecar is set aside and replaced; a
    // well-formed one of another state stops the Commit before the state is saved.
    for corrupt in [true, false] {
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        for _ in 1..GRID_INTERVAL {
            step(&mut app).await;
        }
        let before = app.state().unwrap().clone();
        let sidecar = dir.path().join(format!("val-state-{GRID_INTERVAL}.bin"));
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
            assert_eq!(state.last_height, GRID_INTERVAL);
            let set_aside = dir.path().join(format!("val-state-{GRID_INTERVAL}.bin.corrupt"));
            assert_eq!(std::fs::read(set_aside).unwrap(), planted);
            assert_eq!(
                app.store.load_val_state(GRID_INTERVAL).unwrap(),
                Record::Valid(state.val_state.clone())
            );
        } else {
            let err = result.expect_err("the sidecar conflicts");
            assert!(
                matches!(err, AbciError::Store(StoreError::ValStateConflict(GRID_INTERVAL))),
                "{err:?}"
            );
            assert_eq!(app.state(), Some(&before));
            assert_eq!(Store::volatile(dir.path().into()).load().unwrap(), Some(before));
            assert_eq!(std::fs::read(&sidecar).unwrap(), planted);
        }
    }
}

/// Commit writes a sidecar holding the full preimage at grid heights only and deletes those
/// below the Comet history floor once the floor passes them, so the sidecars on disk are
/// exactly the committed grid heights in `[floor, last_height]`, on the proposer and on a
/// replaying node alike.
#[tokio::test]
async fn grid_sidecars_are_written_and_pruned_with_the_comet_floor() {
    let fx = short_epochs();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_epoch_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;

    let mut written = BTreeMap::new();
    let mut pruned = vec![];
    let retained = |app: &App<MockL1, MockEngine>, written: &BTreeMap<u64, ValState>| {
        let state = app.state().unwrap();
        let (last, floor) = (state.last_height, state.comet_history_floor());
        for height in 0..=last + GRID_INTERVAL {
            let expected = written
                .get(&height)
                .filter(|_| (floor..=last).contains(&height))
                .map_or(Record::Missing, |recorded| Record::Valid(recorded.clone()));
            assert_eq!(
                app.store.load_val_state(height).unwrap(),
                expected,
                "sidecar {height} at head {last} (floor {floor})"
            );
        }
    };
    for (req, _) in &decided {
        finalize(&mut app, req.clone()).await.unwrap();
        commit(&mut app).await.unwrap();
        let state = app.state().unwrap();
        if state.last_height.is_multiple_of(GRID_INTERVAL) {
            written.insert(state.last_height, state.val_state.clone());
        }
        pruned.extend(written.keys().filter(|&&h| h < state.comet_history_floor()));
        retained(&app, &written);
    }
    assert_eq!(written.keys().copied().collect::<Vec<_>>(), [GRID_INTERVAL, 2 * GRID_INTERVAL]);
    assert!(pruned.contains(&GRID_INTERVAL) && pruned.contains(&(2 * GRID_INTERVAL)));
    retained(&source, &written);
}

/// `/val_state/<height>` answers the raw preimage at a retained grid height, from the head
/// state or from its sidecar, and rejects a non-grid height, one below the floor or above the
/// head, a malformed number, and a retained height whose sidecar is missing or corrupt.
#[tokio::test]
async fn val_state_query_rejects_unretained_heights() {
    let fx = short_epochs();
    let source_dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_epoch_run(&fx, source_dir.path()).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = replica(&fx, &source, dir.path()).await;

    let grid = 2 * GRID_INTERVAL;
    let (mut at_grid, mut pruned) = (None, None);
    for (req, _) in decided.iter().take_while(|(req, _)| req.height.value() <= grid + 1) {
        finalize(&mut app, req.clone()).await.unwrap();
        commit(&mut app).await.unwrap();
        if req.height.value() == GRID_INTERVAL {
            pruned = Some(app.state().unwrap().val_state.clone());
        }
        if req.height.value() == grid {
            let head = app.state().unwrap().val_state.clone();
            let answer = query(&mut app, &format!("/val_state/{grid}")).await;
            assert_eq!(answer.code, Code::Ok, "{}", answer.log);
            assert_eq!(answer.value.as_ref(), head.encode(), "the head answers itself");
            at_grid = Some(head);
        }
    }
    let at_grid = at_grid.expect("the replay passes the grid height");
    let state = app.state().unwrap().clone();
    assert_eq!(state.last_height, grid + 1);
    let floor = state.comet_history_floor();
    assert!(GRID_INTERVAL < floor && floor <= grid, "floor {floor}");

    let answer = query(&mut app, &format!("/val_state/{grid}")).await;
    assert_eq!(answer.code, Code::Ok, "{}", answer.log);
    let decoded = ValState::decode(&answer.value).unwrap();
    assert_eq!(decoded, at_grid);
    assert_eq!(decoded.hash(), at_grid.hash());
    assert_eq!(app.val_state_preimage(grid), Ok(answer.value.to_vec()));

    // Valid preimages outside the retained range are still refused: the one pruned below the
    // floor, restored, and one of a future grid height.
    app.store.save_val_state(&pruned.unwrap()).unwrap();
    let mut future = at_grid.clone();
    while future.height < 3 * GRID_INTERVAL {
        future = future.advance(&[]).unwrap();
    }
    app.store.save_val_state(&future).unwrap();
    for height in [grid + 1, GRID_INTERVAL, 0, 3 * GRID_INTERVAL] {
        assert!(app.val_state_preimage(height).is_err(), "height {height}");
    }
    let rejected = [
        format!("/val_state/{}", grid + 1),          // not a grid height
        format!("/val_state/{GRID_INTERVAL}"),       // below the floor, sidecar restored
        "/val_state/0".to_string(),                  // the origin, below the floor
        format!("/val_state/{}", 3 * GRID_INTERVAL), // above the head, sidecar planted
        "/val_state/".to_string(),
        "/val_state/x".to_string(),
        format!("/val_state/+{grid}"),
        format!("/val_state/0{grid}"),
        format!("/val_state/-{grid}"),
        format!("/val_state/{grid}/"),
        "/val_state/18446744073709551616".to_string(),
    ];
    for path in &rejected {
        let answer = query(&mut app, path).await;
        assert_eq!(answer.code, Code::from(CODE_REJECTED), "{path}");
        assert!(answer.value.is_empty(), "{path}");
        assert!(!answer.log.is_empty(), "{path}");
    }

    // A retained grid height never answers from a missing or corrupt sidecar: junk, the bare
    // preimage without its checksum, or the well-formed record of another height.
    let sidecar = dir.path().join(format!("val-state-{grid}.bin"));
    let other_height = std::fs::read(dir.path().join(format!("val-state-{GRID_INTERVAL}.bin")));
    for bytes in [b"junk".to_vec(), at_grid.encode(), other_height.unwrap()] {
        std::fs::write(&sidecar, bytes).unwrap();
        let error = app.val_state_preimage(grid).expect_err("corrupt sidecar");
        assert!(error.contains(&grid.to_string()), "{error}");
        let answer = query(&mut app, &format!("/val_state/{grid}")).await;
        assert_eq!(answer.code, Code::from(CODE_REJECTED));
    }
    std::fs::remove_file(&sidecar).unwrap();
    let error = app.val_state_preimage(grid).expect_err("missing sidecar");
    assert!(error.contains("missing"), "{error}");
}
