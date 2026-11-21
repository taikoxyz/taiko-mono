//! Restoring a committed execution suffix when the EL lost it and has no peers.

use std::time::Duration;

use alloy_primitives::B256;

use super::{
    proposal::{bft_time, next_height, process, process_req, propose, step},
    *,
};
use crate::app::execution_recovery::SuffixRestore;

/// Lose all execution blocks above the generation origin, retaining only that ancestor's state.
fn lose_suffix(app: &App<MockL1, MockEngine>) {
    let state = app.state().unwrap();
    let boundary = state.origin_height();
    let ancestor = app.engine().state().chain[&boundary].hash_slow();
    let mut engine = app.engine().state();
    engine.chain.retain(|number, _| *number <= boundary);
    engine.known.retain(|_, header| header.number <= boundary);
    engine.historical_state.insert(ancestor);
    engine.require_payload_parent = true;
    engine.calls.clear();
    assert!(engine.backfill.is_empty(), "no peer-provided blocks");
}

#[tokio::test(start_paused = true)]
async fn startup_restores_committed_execution_suffix_without_peers() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    lose_suffix(&app);
    let engine = app.engine().reopen();
    engine.state().historical_state.insert(committed.genesis.genesis_hash);
    engine.state().require_payload_parent = true;
    drop(app);
    let mut reopened =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let response = tokio::time::timeout(Duration::from_secs(2), info(&mut reopened))
        .await
        .expect("local committed payloads restore the EL without peer sync")
        .unwrap();
    assert_eq!(response.last_block_height.value(), committed.last_height);
    assert_eq!(response.last_block_app_hash, crate::app::app_hash(&committed));
    assert_eq!(
        reopened.engine().state().chain[&committed.last_height].hash_slow(),
        committed.parent.hash
    );
    assert_eq!(reopened.state(), Some(&committed), "recovery never rewrites app state");
}

#[tokio::test(start_paused = true)]
async fn process_restores_committed_execution_suffix_without_canonicalizing_the_proposal() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let envelope = propose(&mut app).await;
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![envelope.encode()]);
    let committed = app.state().unwrap().clone();
    lose_suffix(&app);
    let response = tokio::time::timeout(Duration::from_secs(2), process(&mut app, req))
        .await
        .expect("ProcessProposal re-feeds the committed ancestors");
    assert_eq!(response, response::ProcessProposal::Accept);
    assert_eq!(app.state(), Some(&committed));
    assert_eq!(
        app.engine().state().chain[&committed.last_height].hash_slow(),
        committed.parent.hash
    );
    assert!(!app.engine().calls().iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, .. } if *head == envelope.block.header.hash_slow())));
    assert!(app.engine().calls().iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, safe, finalized }
            if *head == committed.parent.hash && *safe == B256::ZERO && *finalized == B256::ZERO)));
}

/// Replace auxiliary bytes with a checksum-valid RLP block, simulating coherent local damage.
fn replace_body(directory: &Path, block: &crate::ExecutionBlock) {
    let body = alloy_rlp::encode(block);
    let framed = [alloy_primitives::keccak256(&body).as_slice(), body.as_slice()].concat();
    std::fs::write(directory.join(format!("execution-block-{}.bin", block.header.number)), framed)
        .unwrap();
}

#[tokio::test(start_paused = true)]
async fn unavailable_execution_sidecars_keep_process_pending_without_false_rejection() {
    for corrupt in [false, true] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        for _ in 0..3 {
            step(&mut app).await;
        }
        let envelope = propose(&mut app).await;
        let req = process_req(&app, next_height(&app), bft_time(&app), vec![envelope.encode()]);
        let committed = app.state().unwrap().clone();
        let path = dir.path().join("execution-block-2.bin");
        if corrupt {
            std::fs::write(path, b"damaged payload").unwrap();
        } else {
            std::fs::remove_file(path).unwrap();
        }
        lose_suffix(&app);
        assert!(
            tokio::time::timeout(Duration::from_secs(1), process(&mut app, req)).await.is_err()
        );
        assert_eq!(app.state(), Some(&committed));
        assert!(app.halt.is_none(), "missing auxiliary bodies are not invalid proposals");
        assert!(!dir.path().join("fatal-evidence.txt").exists());
        assert!(!app.engine().calls().iter().any(|call| matches!(call,
            EngineCall::Forkchoice { head, .. } if *head == envelope.block.header.hash_slow())));
        assert!(
            !app.engine().state().known.contains_key(&committed.parent.hash),
            "authenticate the complete available suffix before re-feeding it"
        );
    }
}

#[tokio::test(start_paused = true)]
async fn coherent_execution_sidecar_hash_or_transaction_root_damage_halts_before_replay() {
    for damage_transactions in [false, true] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        let mut block = step(&mut app).await.block;
        step(&mut app).await;
        if damage_transactions {
            block.transactions.push(alloy_primitives::Bytes::from_static(&[0xff]));
        } else {
            block.header.timestamp += 1;
        }
        replace_body(dir.path(), &block);
        let committed = app.state().unwrap().clone();
        lose_suffix(&app);
        let error = app.restore_committed_execution(&committed).await.unwrap_err();
        assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
        assert!(
            !app.engine().calls().iter().any(|call| matches!(call, EngineCall::NewPayload(_))),
            "no unauthenticated suffix is executed"
        );
        assert_eq!(app.state(), Some(&committed));
    }
}

#[tokio::test(start_paused = true)]
async fn execution_recovery_stops_at_the_import_floor_and_requires_its_existing_state() {
    for keep_floor in [false, true] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        step(&mut app).await;
        let floor = step(&mut app).await.block.header;
        step(&mut app).await;
        let mut committed = app.state().unwrap().clone();
        committed.execution_floor =
            Some(crate::store::ExecutionFloor { number: floor.number, hash: floor.hash_slow() });
        app.store.save(&committed).unwrap();
        lose_suffix(&app);
        if keep_floor {
            let mut engine = app.engine().state();
            engine.chain.insert(floor.number, floor.clone());
            engine.known.insert(floor.hash_slow(), floor.clone());
            engine.historical_state.insert(floor.hash_slow());
        }
        let engine = Arc::clone(&app.engine);
        drop(app);
        let engine = Arc::try_unwrap(engine).expect("app released the execution engine");
        let mut reopened = app_with(
            fx.l1(),
            engine,
            fx.params.clone(),
            dir.path(),
            crate::test_utils::test_options(),
        );
        let result = tokio::time::timeout(Duration::from_secs(1), info(&mut reopened)).await;
        if keep_floor {
            assert_eq!(result.unwrap().unwrap().last_block_height.value(), committed.last_height);
        } else {
            assert!(result.is_err(), "sidecars never recreate an absent imported state floor");
        }
        assert!(
            !reopened.engine().calls().iter().any(|call| matches!(call,
            EngineCall::NewPayload(hash) if *hash == floor.hash_slow())),
            "never replay the import boundary"
        );
        assert_eq!(reopened.state(), Some(&committed));
    }
}

#[tokio::test]
async fn execution_sidecar_write_failure_prevents_a_finalized_state_from_becoming_committable() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let original = app.state().unwrap().clone();
    let envelope = propose(&mut app).await;
    let (accepted, req) = super::proposal::judge(&mut app, &envelope).await;
    assert_eq!(accepted, response::ProcessProposal::Accept);
    std::fs::create_dir(dir.path().join("execution-block-1.bin")).unwrap();
    let result = super::proposal::finalize(&mut app, super::proposal::finalize_req(&req)).await;
    assert!(matches!(result, Err(AbciError::Store(_))), "{result:?}");
    assert!(app.pending.is_none(), "failed payload durability prevents Commit acknowledgement");
    assert_eq!(app.state(), Some(&original));
    assert_eq!(app.store.load().unwrap(), Some(original));
}

#[tokio::test(start_paused = true)]
async fn syncing_payload_nudges_the_committed_head_even_when_its_state_is_present() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    step(&mut app).await;
    let envelope = propose(&mut app).await;
    let committed = app.state().unwrap().clone();
    {
        let mut engine = app.engine().state();
        engine.historical_state.insert(committed.parent.hash);
        engine.new_payload_script.extend([
            Ok(crate::engine::PayloadVerdict::Syncing),
            Ok(crate::engine::PayloadVerdict::Valid),
        ]);
        engine.calls.clear();
    }
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![envelope.encode()]);
    assert_eq!(process(&mut app, req).await, response::ProcessProposal::Accept);
    let choices: Vec<_> = app
        .engine()
        .calls()
        .into_iter()
        .filter(|call| matches!(call, EngineCall::Forkchoice { .. }))
        .collect();
    assert_eq!(
        choices,
        [EngineCall::Forkchoice {
            head: committed.parent.hash,
            safe: B256::ZERO,
            finalized: B256::ZERO
        }]
    );
    assert_eq!(
        app.engine().state().chain[&committed.last_height].hash_slow(),
        committed.parent.hash
    );
    assert!(!app.engine().state().chain.contains_key(&envelope.block.header.number));
}

#[tokio::test(start_paused = true)]
async fn missing_origin_state_never_replays_the_available_generation_archive() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..6 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    {
        let mut engine = app.engine().state();
        engine.chain.clear();
        engine.known.clear();
        engine.historical_state.clear();
        engine.calls.clear();
    }
    // The EL lacks the origin's block and state, which no retained body recreates.
    assert_eq!(
        app.restore_committed_execution(&committed).await.unwrap(),
        SuffixRestore::Missing(committed.origin_height())
    );
    assert!(
        !app.engine()
            .calls()
            .iter()
            .any(|call| matches!(call, EngineCall::NewPayload(_) | EngineCall::Forkchoice { .. })),
        "the complete backward traversal must reach an existing stateful ancestor first"
    );
    assert_eq!(app.state(), Some(&committed));
}

#[tokio::test(start_paused = true)]
async fn restart_ignores_execution_sidecars_above_the_committed_app_state() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    let envelope = propose(&mut app).await;
    let (_, req) = super::proposal::judge(&mut app, &envelope).await;
    super::proposal::finalize(&mut app, super::proposal::finalize_req(&req)).await.unwrap();
    assert!(dir.path().join("execution-block-4.bin").exists());
    lose_suffix(&app);
    let engine = Arc::clone(&app.engine);
    drop(app);
    let engine = Arc::try_unwrap(engine).expect("app released the execution engine");
    let mut reopened =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let response =
        tokio::time::timeout(Duration::from_secs(2), info(&mut reopened)).await.unwrap().unwrap();
    assert_eq!(response.last_block_height.value(), committed.last_height);
    assert!(
        !reopened.engine().calls().iter().any(|call| matches!(call,
        EngineCall::NewPayload(hash) if *hash == envelope.block.header.hash_slow())),
        "an orphan sidecar is never evidence of an app commit"
    );
    assert_eq!(reopened.state(), Some(&committed));
}

#[tokio::test(start_paused = true)]
async fn cached_finalize_restores_a_suffix_lost_after_process_accepted_without_peers() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    let envelope = propose(&mut app).await;
    let (accepted, req) = super::proposal::judge(&mut app, &envelope).await;
    assert_eq!(accepted, response::ProcessProposal::Accept);
    lose_suffix(&app);
    let result = tokio::time::timeout(
        Duration::from_secs(2),
        super::proposal::finalize(&mut app, super::proposal::finalize_req(&req)),
    )
    .await
    .expect("cached Finalize re-feeds committed ancestors without peer sync")
    .unwrap();
    assert_eq!(result.app_hash, crate::app::app_hash(app.pending.as_ref().unwrap()));
    assert_eq!(app.pending.as_ref().unwrap().parent.hash, envelope.block.header.hash_slow());
    assert_eq!(app.state(), Some(&committed), "Finalize leaves the new app state pending");
    assert_eq!(
        app.engine().state().chain[&envelope.block.header.number].hash_slow(),
        envelope.block.header.hash_slow()
    );
}

#[tokio::test(start_paused = true)]
async fn prepare_first_restores_a_lost_committed_suffix_before_building_without_peers() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    lose_suffix(&app);
    let envelope = propose(&mut app).await;
    assert_eq!(envelope.block.header.parent_hash, committed.parent.hash);
    assert_eq!(app.state(), Some(&committed));
    assert!(!dir.path().join("fatal-evidence.txt").exists());
    let calls = app.engine().calls();
    let restore = calls
        .iter()
        .position(|call| {
            matches!(call,
        EngineCall::Forkchoice { head, .. } if *head == committed.parent.hash)
        })
        .unwrap();
    let build =
        calls.iter().position(|call| matches!(call, EngineCall::BuildBlock { .. })).unwrap();
    assert!(restore < build, "restore the committed parent before asking the EL to build");
    assert!(!calls.iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, .. } if *head == envelope.block.header.hash_slow())));
}

#[tokio::test(start_paused = true)]
async fn prepare_parent_recovery_uses_the_same_total_proposal_timeout() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    lose_suffix(&app);
    std::fs::remove_file(dir.path().join("execution-block-3.bin")).unwrap();
    app.engine().state().delay = Some(app.opts.prepare_timeout / 2);
    let request = super::proposal::prepare_req(next_height(&app), bft_time(&app));
    let start = tokio::time::Instant::now();
    let output = super::proposal::prepare(&mut app, request).await;
    assert!(output.is_empty(), "unavailable parent produces a nonconsuming placeholder");
    assert!(start.elapsed() <= app.opts.prepare_timeout);
    assert_eq!(app.state(), Some(&committed));
    assert!(!dir.path().join("fatal-evidence.txt").exists());
    assert!(!app.engine().calls().iter().any(|call| matches!(call, EngineCall::BuildBlock { .. })));
}

/// A due canonical forced skip whose singleton can complete only after its parent is restored.
fn forced_skip_after_loss(fx: &Fixture, app: &App<MockL1, MockEngine>) -> crate::EtnaEnvelope {
    let tx = super::proposal::plant_due_entry(fx, app.l1(), 66, fx.inbox.clone());
    let envelope = super::proposal::hand_forced_envelope(
        app,
        Some(fx.anchor_witness(app.l1(), 66)),
        None,
        fx.forced_witness(app.l1(), 66, 0, tx),
        protocol::shasta::encode_transactions(&[]),
    );
    lose_suffix(app);
    let mut engine = app.engine().state();
    engine.missing_parent_build_error =
        Some(crate::engine::EngineError::BuildNotStarted(crate::engine::PayloadVerdict::Syncing));
    engine.build_script.push_back(Ok(envelope.block.clone()));
    envelope
}

#[tokio::test(start_paused = true)]
async fn process_forced_skip_repairs_the_missing_committed_parent_before_retrying_singleton() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    let envelope = forced_skip_after_loss(&fx, &app);
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![envelope.encode()]);
    let output = tokio::time::timeout(Duration::from_secs(2), process(&mut app, req))
        .await
        .expect("retrying a singleton must restore its committed parent");
    assert_eq!(output, response::ProcessProposal::Accept);
    assert_eq!(app.state(), Some(&committed), "Process never consumes the forced queue cursor");
    assert!(app.pending.is_none());
    assert!(!app.engine().calls().iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, .. } if *head == envelope.block.header.hash_slow())));
}

#[tokio::test(start_paused = true)]
async fn cold_finalize_forced_skip_repairs_the_missing_parent_before_retrying_singleton() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    let envelope = forced_skip_after_loss(&fx, &app);
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![envelope.encode()]);
    let output = tokio::time::timeout(
        Duration::from_secs(2),
        super::proposal::finalize(&mut app, super::proposal::finalize_req(&req)),
    )
    .await
    .expect("cold Finalize restores the singleton's parent")
    .unwrap();
    assert_eq!(output.app_hash, crate::app::app_hash(app.pending.as_ref().unwrap()));
    assert_eq!(app.pending.as_ref().unwrap().parent.hash, envelope.block.header.hash_slow());
    assert_eq!(app.state(), Some(&committed));
    assert_eq!(app.pending.as_ref().unwrap().forced_cursor, 1);
}

#[tokio::test(start_paused = true)]
async fn prepare_parent_preflight_and_optional_build_share_one_absolute_deadline() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    {
        let mut engine = app.engine().state();
        engine.delay_script.push_back(Duration::from_millis(250));
        engine.ordinary_build_delay = Some(Duration::from_secs(60));
    }
    let start = tokio::time::Instant::now();
    let envelope = propose(&mut app).await;
    assert!(envelope.block.transactions.is_empty());
    assert!(
        start.elapsed() < app.opts.prepare_timeout,
        "the completed minimum must survive a slow preflight and optional build"
    );
}

#[tokio::test(start_paused = true)]
async fn repeated_prepare_deadlines_do_not_cancel_a_long_execution_repair() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    lose_suffix(&app);
    app.opts.prepare_timeout = Duration::from_secs(1);
    app.engine().state().delay = Some(Duration::from_millis(200));
    let mut envelope = None;
    for _ in 0..12 {
        let request = super::proposal::prepare_req(next_height(&app), bft_time(&app));
        let started = tokio::time::Instant::now();
        let output = super::proposal::prepare(&mut app, request).await;
        assert!(
            started.elapsed() <= app.opts.prepare_timeout,
            "each Prepare request retains its original total deadline"
        );
        if let Some(bytes) = output.first() {
            envelope = Some(crate::EtnaEnvelope::decode(bytes).unwrap());
            break;
        }
    }
    let envelope = envelope.expect("long parent repair must survive cancelled preparation waiters");
    assert_eq!(envelope.block.header.parent_hash, committed.parent.hash);
    assert_eq!(app.state(), Some(&committed));
    assert!(!dir.path().join("fatal-evidence.txt").exists());
    assert!(!app.engine().calls().iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, .. } if *head == envelope.block.header.hash_slow())));
}

#[tokio::test(start_paused = true)]
async fn app_drop_aborts_owned_parent_repair_without_a_later_forkchoice() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    lose_suffix(&app);
    app.opts.prepare_timeout = Duration::from_secs(1);
    app.engine().state().delay = Some(Duration::from_millis(200));
    let request = super::proposal::prepare_req(next_height(&app), bft_time(&app));
    assert!(super::proposal::prepare(&mut app, request).await.is_empty());
    let engine = Arc::clone(&app.engine);
    let calls = engine.calls();
    drop(app);
    tokio::time::advance(Duration::from_secs(30)).await;
    for _ in 0..4 {
        tokio::task::yield_now().await;
    }
    assert_eq!(engine.calls(), calls, "dropping the app aborts its unfinished repair I/O");
    assert!(
        !engine.calls().iter().any(|call| matches!(call, EngineCall::Forkchoice { .. })),
        "background repair never canonicalizes any head"
    );
}

#[tokio::test(start_paused = true)]
async fn committing_a_new_parent_aborts_the_obsolete_owned_repair() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let envelope = propose(&mut app).await;
    let (accepted, decided) = super::proposal::judge(&mut app, &envelope).await;
    assert_eq!(accepted, response::ProcessProposal::Accept);
    let (chain, known) = {
        let engine = app.engine().state();
        (engine.chain.clone(), engine.known.clone())
    };
    lose_suffix(&app);
    app.opts.prepare_timeout = Duration::from_secs(1);
    app.engine().state().delay = Some(Duration::from_millis(200));
    let request = super::proposal::prepare_req(next_height(&app), bft_time(&app));
    assert!(super::proposal::prepare(&mut app, request).await.is_empty());
    {
        let mut engine = app.engine().state();
        engine.chain = chain;
        engine.known = known;
        engine.delay = None;
    }
    super::proposal::decide(&mut app, &decided).await;
    let calls = app.engine().calls();
    tokio::time::advance(Duration::from_secs(30)).await;
    for _ in 0..4 {
        tokio::task::yield_now().await;
    }
    assert_eq!(app.engine().calls(), calls, "Commit retires I/O owned by the old parent context");
    assert_eq!(app.state().unwrap().parent.hash, envelope.block.header.hash_slow());
    assert_eq!(
        app.engine().state().chain[&envelope.block.header.number].hash_slow(),
        envelope.block.header.hash_slow()
    );
}

#[tokio::test(start_paused = true)]
async fn prepare_repairs_a_second_execution_crash_at_the_same_committed_parent() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    for _ in 0..2 {
        lose_suffix(&app);
        let envelope = propose(&mut app).await;
        assert_eq!(envelope.block.header.parent_hash, committed.parent.hash);
        assert_eq!(app.state(), Some(&committed), "no Commit separates the crashes");
        assert_eq!(
            app.engine().state().chain[&committed.last_height].hash_slow(),
            committed.parent.hash
        );
        assert!(
            app.engine().calls().iter().any(|call| matches!(call,
            EngineCall::NewPayload(hash) if *hash == committed.parent.hash)),
            "every new crash re-feeds the lost committed payload"
        );
    }
}

/// Finishes a failed owned repair after its Prepare waiter times out, then restores the EL
/// independently so subsequent handlers could otherwise discard the original delivered error.
async fn delivered_execution_repair_failure(
    directory: &Path,
    io_failure: bool,
) -> (App<MockL1, MockEngine>, request::ProcessProposal, crate::store::AppState) {
    let fx = Fixture::genesis(1);
    let mut app = initialized(&fx, directory).await;
    let mut first = step(&mut app).await.block;
    for _ in 0..2 {
        step(&mut app).await;
    }
    let envelope = propose(&mut app).await;
    let (_, decided) = super::proposal::judge(&mut app, &envelope).await;
    let committed = app.state().unwrap().clone();
    let (chain, known) = {
        let engine = app.engine().state();
        (engine.chain.clone(), engine.known.clone())
    };
    if io_failure {
        let path = directory.join("execution-block-1.bin");
        std::fs::remove_file(&path).unwrap();
        std::fs::create_dir(path).unwrap();
    } else {
        first.header.timestamp += 1;
        replace_body(directory, &first);
    }
    lose_suffix(&app);
    app.opts.prepare_timeout = Duration::from_secs(1);
    app.engine().state().delay = Some(Duration::from_millis(400));
    let request = super::proposal::prepare_req(next_height(&app), bft_time(&app));
    assert!(super::proposal::prepare(&mut app, request).await.is_empty());
    for _ in 0..8 {
        tokio::time::advance(Duration::from_secs(1)).await;
        tokio::task::yield_now().await;
    }
    {
        let mut engine = app.engine().state();
        engine.chain = chain;
        engine.known = known;
        engine.delay = None;
    }
    (app, decided, committed)
}

#[tokio::test(start_paused = true)]
async fn synchronous_retirement_returns_the_original_delivered_repair_error() {
    for io_failure in [false, true] {
        let dir = tempfile::tempdir().unwrap();
        let (app, _, committed) = delivered_execution_repair_failure(dir.path(), io_failure).await;
        let error = app
            .execution_parent_ready(&committed)
            .await
            .expect_err("retirement must harvest delivered errors");
        if io_failure {
            assert!(
                matches!(error, AbciError::Store(crate::store::StoreError::Io { .. })),
                "{error}"
            );
        } else {
            assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
        }
    }
}

#[tokio::test(start_paused = true)]
async fn commit_harvests_delivered_repair_failure_before_publishing_any_new_state() {
    let dir = tempfile::tempdir().unwrap();
    let (mut app, decided, committed) = delivered_execution_repair_failure(dir.path(), false).await;
    super::proposal::finalize(&mut app, super::proposal::finalize_req(&decided)).await.unwrap();
    let error = super::proposal::commit(&mut app)
        .await
        .expect_err("Commit must return the delivered contradiction");
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
    assert_eq!(app.state(), Some(&committed));
    assert_eq!(app.store.load().unwrap(), Some(committed));
    assert!(
        !dir.path().join("comet-hash-4.json").exists(),
        "no new commit record precedes retirement"
    );
    assert!(
        std::fs::read_to_string(dir.path().join("fatal-evidence.txt"))
            .unwrap()
            .contains("durable execution block at 1")
    );
}

#[tokio::test(start_paused = true)]
async fn context_replacement_cannot_discard_a_delivered_repair_failure() {
    let dir = tempfile::tempdir().unwrap();
    let (app, _, mut context) = delivered_execution_repair_failure(dir.path(), false).await;
    context.parent.timestamp += 1;
    let error = app
        .preparation_execution_parent_ready(&context)
        .await
        .expect_err("replacing a flight must harvest its error");
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
}

#[tokio::test(start_paused = true)]
async fn app_drop_preserves_fatal_evidence_from_a_delivered_repair_failure() {
    let dir = tempfile::tempdir().unwrap();
    let (app, _, _) = delivered_execution_repair_failure(dir.path(), false).await;
    drop(app);
    assert!(
        std::fs::read_to_string(dir.path().join("fatal-evidence.txt"))
            .unwrap()
            .contains("durable execution block at 1")
    );
}

#[tokio::test(start_paused = true)]
async fn completed_prepare_forkchoice_is_not_repeated_when_its_parent_read_timed_out() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    lose_suffix(&app);
    app.opts.prepare_timeout = Duration::from_secs(1);
    {
        let mut engine = app.engine().state();
        engine.header_read_delay = Some(Duration::from_millis(400));
        engine.forkchoice_delay = Some(Duration::from_millis(700));
    }
    let mut envelope = None;
    for _ in 0..12 {
        let started = tokio::time::Instant::now();
        let request = super::proposal::prepare_req(next_height(&app), bft_time(&app));
        let output = super::proposal::prepare(&mut app, request).await;
        assert!(started.elapsed() <= app.opts.prepare_timeout);
        if let Some(bytes) = output.first() {
            envelope = Some(crate::EtnaEnvelope::decode(bytes).unwrap());
            break;
        }
    }
    let envelope =
        envelope.expect("a completed FCU must survive cancellation of the confirming header read");
    assert_eq!(envelope.block.header.parent_hash, committed.parent.hash);
    assert_eq!(app.state(), Some(&committed));
    assert_eq!(
        app.engine()
            .calls()
            .iter()
            .filter(|call| matches!(call, EngineCall::Forkchoice { .. }))
            .count(),
        1,
        "the next waiter checks a served parent before repeating the completed FCU"
    );
}
