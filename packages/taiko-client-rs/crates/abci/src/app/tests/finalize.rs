//! `FinalizeBlock` and `Commit`: verdict cache, cold-start re-validation,
//! state transitions, validator-set switches, EL forkchoice and retries, safety halts,
//! persistence, crash replay, determinism and a multi-epoch run.

use std::{collections::BTreeMap, time::Duration};

use alloy_primitives::{B256, U256};
use tendermint::{AppHash, Hash, abci::Code};

use super::{
    proposal::{
        bft_time, commit, decide, finalize, finalize_req, judge, jump, mid_epoch, next_height,
        process, process_req, propose, step,
    },
    *,
};
use crate::{
    app::FINALIZE_RETRY_ESCALATE,
    committee::{self, Snapshot, record_hash},
    engine::{EngineError, PayloadVerdict},
    store::{AppState, CommitteeState},
    test_utils::{GenesisSpec, LogCapture, RegistryStorage, sample_entries},
    types::{ParentInfo, RegistryEntry},
};

/// `(pubkey, power)` pairs of CometBFT validator updates, in response order.
fn updates_of(resp: &response::FinalizeBlock) -> Vec<(B256, u64)> {
    resp.validator_updates
        .iter()
        .map(|u| (B256::from_slice(&u.pub_key.to_bytes()), u.power.value()))
        .collect()
}

/// The engine calls `app` made after the first `from` ones.
fn engine_calls_since(app: &App<MockL1, MockEngine>, from: usize) -> Vec<EngineCall> {
    app.engine().calls()[from..].to_vec()
}

/// Expects a safety halt; returns its message.
fn safety_halt(result: Result<response::FinalizeBlock, AbciError>) -> String {
    match result {
        Err(AbciError::SafetyHalt(msg)) => msg,
        other => panic!("expected a safety halt, got {other:?}"),
    }
}

/// A mid-epoch app (next height `B* + 6`) whose own L1 finalized block 66 with the last
/// checkpoint at `B* + 3`, so its next proposal moves the anchor and carries a witness.
async fn anchor_moving(fx: &Fixture, dir: &Path) -> App<MockL1, MockEngine> {
    let app = mid_epoch(fx, dir, 5).await;
    let inbox = fx.inbox_with(fx.activation.genesis_height + 3, &[]);
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    app
}

#[tokio::test]
async fn finalize_after_process_uses_the_cached_verdict() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = anchor_moving(&fx, dir.path()).await;
    let env = propose(&mut app).await;
    assert!(env.anchor.is_some());
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);

    app.l1().state().calls.clear();
    let before = app.engine().calls().len();
    let out = finalize(&mut app, finalize_req(&req)).await.expect("finalizes");
    let hash = env.block.header.hash_slow();
    let checkpoint = fx.inbox_with(fx.activation.genesis_height + 3, &[]).last_checkpoint_hash;
    assert_eq!(
        engine_calls_since(&app, before),
        [EngineCall::Forkchoice { head: hash, safe: hash, finalized: checkpoint }],
        "the cached verdict was executed already: no second newPayload"
    );
    assert!(app.l1().calls().is_empty(), "FinalizeBlock never calls L1");

    assert_eq!(out.tx_results.len(), 1, "one result for the one envelope transaction");
    assert_eq!(out.tx_results[0].code, Code::Ok);
    assert!(out.events.is_empty() && out.validator_updates.is_empty());
    assert_eq!(out.consensus_param_updates, None);
    assert_eq!(out.app_hash, AppHash::try_from(hash.to_vec()).unwrap());
    assert_eq!(app.state().unwrap().last_height, next_height(&app) - 1, "not committed yet");
    assert_eq!(app.pending.as_ref().map(|s| s.parent.hash), Some(hash));
}

#[tokio::test]
async fn finalize_without_process_revalidates_and_executes() {
    let fx = Fixture::genesis(2);
    let (proposer_dir, validator_dir) =
        (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
    let mut proposer = anchor_moving(&fx, proposer_dir.path()).await;
    let env = propose(&mut proposer).await;
    let (_, req) = judge(&mut proposer, &env).await;
    let req = finalize_req(&req);

    // A node that never saw the proposal (crash replay, block sync).
    let mut validator = mid_epoch(&fx, validator_dir.path(), 5).await;
    validator.l1().state().calls.clear();
    let before = validator.engine().calls().len();
    let out = finalize(&mut validator, req.clone()).await.expect("finalizes");
    let hash = env.block.header.hash_slow();
    let checkpoint = fx.inbox_with(fx.activation.genesis_height + 3, &[]).last_checkpoint_hash;
    assert_eq!(
        engine_calls_since(&validator, before),
        [
            EngineCall::NewPayload(hash),
            EngineCall::Forkchoice { head: hash, safe: hash, finalized: checkpoint },
        ]
    );
    assert!(validator.l1().calls().is_empty(), "the anchor witness is checked without L1");
    let pending = validator.pending.as_ref().expect("pending state");
    assert_eq!(pending.anchor, fx.anchor_state(proposer.l1(), 66, None));

    assert_eq!(finalize(&mut proposer, req).await.expect("finalizes"), out, "same response");
    assert_eq!(proposer.pending, validator.pending, "same next state");
}

#[tokio::test]
async fn finalize_updates_parent_anchor_and_committees() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h0 = fx.activation.genesis_height + 1;

    // H_0 = h_first(e_0): the committee of epoch 1 is derived and kept.
    let env = propose(&mut app).await;
    let (_, req) = judge(&mut app, &env).await;
    let before = app.state().unwrap().clone();
    finalize(&mut app, finalize_req(&req)).await.expect("finalizes");
    let h = &env.block.header;
    let mut expected = before.clone();
    expected.last_height = h0;
    expected.parent = ParentInfo {
        number: h0,
        hash: h.hash_slow(),
        timestamp: h.timestamp,
        gas_limit: h.gas_limit,
        gas_used: h.gas_used,
        base_fee: h.base_fee_per_gas.unwrap(),
        difficulty: h.difficulty,
        grandparent_timestamp: before.parent.timestamp,
    };
    expected.anchor = fx.anchor_state(app.l1(), fx.activation.l1_0, None);
    expected.committees.insert(1, fx.committee(1));
    assert_eq!(app.pending.as_ref(), Some(&expected));
    assert_eq!(app.state(), Some(&before), "the committed state waits for Commit");
    commit(&mut app).await.expect("commits");
    assert_eq!(app.state(), Some(&expected));

    // A plain height inherits the anchor; the grandparent timestamp is H_0's.
    let env = step(&mut app).await;
    let state = app.state().unwrap();
    assert_eq!(state.last_height, h0 + 1);
    assert_eq!(state.parent.hash, env.block.header.hash_slow());
    assert_eq!(state.parent.grandparent_timestamp, expected.parent.timestamp);
    assert_eq!(state.anchor, expected.anchor);
    assert_eq!(state.committees, expected.committees);

    // A moved anchor replaces the anchor facts.
    let inbox = fx.inbox_with(h0, &[]);
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    step(&mut app).await;
    assert_eq!(app.state().unwrap().anchor, fx.anchor_state(app.l1(), 66, None));
}

/// The switch height to epoch 2 (`h_first(2) − 2`, as CometBFT applies updates two heights
/// later) emits the exact updates (a removal, a power change, an unchanged member restated, an
/// addition), sorted by key, and committees below 1 pruned.
#[tokio::test]
async fn switch_height_emits_the_exact_updates_and_prunes() {
    let fx = Fixture::genesis(3);
    let params = &fx.params;
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let switch = app.state().unwrap().schedule.h_first(2) - 2;

    let derive = |entries: Vec<RegistryEntry>, target| {
        let l1_0 = fx.activation.l1_0;
        let cutoff = committee::cutoff(l1_0, params.cutoff_grid, params.cutoff_lag).unwrap();
        let snapshot = Snapshot { checkpoint_index: 0, l1_block: l1_0, entries };
        let (record, members) = committee::derive(&snapshot, cutoff, target, params).unwrap();
        CommitteeState { record, members }
    };
    let all = sample_entries(4);
    let c1 = derive(all[..3].to_vec(), 1);
    let mut next = all.clone();
    next.remove(0); // validator 0 leaves
    next[0].eff_stake *= U256::from(5); // validator 1 changes power; 2 stays; 3 joins
    let c2 = derive(next, 2);

    let landed = fx.inbox_with(switch - 5, &[(2, record_hash(params.l2_chain_id, &c2.record))]);
    fx.advance_l1(app.l1(), 70, &landed, &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 70, None);
    jump(&mut app, switch - 1, anchor, &[(1, c1.clone()), (2, c2.clone())]);
    assert_eq!(app.state().unwrap().committees.keys().copied().collect::<Vec<_>>(), [0, 1, 2]);

    let env = propose(&mut app).await;
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    let out = finalize(&mut app, finalize_req(&req)).await.expect("finalizes");

    let unit = 1_000_000_000u64; // 1 TAIKO / VP_UNIT
    let expected: BTreeMap<B256, u64> = BTreeMap::from([
        (all[0].pubkey, 0),
        (all[1].pubkey, 10 * unit),
        (all[2].pubkey, 3 * unit),
        (all[3].pubkey, 4 * unit),
    ]);
    assert_eq!(updates_of(&out), expected.into_iter().collect::<Vec<_>>());
    assert_eq!(updates_of(&out), committee::validator_updates(&c1.members, &c2.members));
    let pending = app.pending.as_ref().expect("pending state");
    assert_eq!(pending.committees.keys().copied().collect::<Vec<_>>(), [1, 2], "0 is pruned");

    // The heights around it emit nothing.
    commit(&mut app).await.unwrap();
    let env = propose(&mut app).await;
    let (_, req) = judge(&mut app, &env).await;
    assert!(decide(&mut app, &req).await.validator_updates.is_empty());
}

#[tokio::test]
async fn forkchoice_finalizes_the_anchored_checkpoint() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();

    // At H_0 the anchored checkpoint is the genesis anchor (B*, H*).
    let mut app = initialized(&fx, dir.path()).await;
    let before = app.engine().calls().len();
    let env = step(&mut app).await;
    let hash = env.block.header.hash_slow();
    let fcu = EngineCall::Forkchoice { head: hash, safe: hash, finalized: fx.genesis_hash() };
    assert_eq!(engine_calls_since(&app, before).last(), Some(&fcu));

    // An Inbox with no checkpoint hash keeps `finalized` at zero.
    let mut inbox = fx.inbox_with(fx.activation.genesis_height + 1, &[]);
    inbox.last_checkpoint_hash = B256::ZERO;
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    let before = app.engine().calls().len();
    let env = step(&mut app).await;
    let hash = env.block.header.hash_slow();
    let fcu = EngineCall::Forkchoice { head: hash, safe: hash, finalized: B256::ZERO };
    assert_eq!(engine_calls_since(&app, before).last(), Some(&fcu));
}

#[tokio::test]
async fn execution_failures_of_a_decided_block_are_safety_halts() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    let committed = app.state().cloned();

    let new_payload = [
        Ok(PayloadVerdict::Invalid("bad state root".into())),
        Err(EngineError::NotEtnaShaped("withdrawals_root")),
    ];
    for script in new_payload {
        app.engine().state().new_payload_script.push_back(script);
        let msg = safety_halt(finalize(&mut app, req.clone()).await);
        assert!(msg.contains("engine_newPayload"), "{msg}");
    }
    app.engine().state().forkchoice_script.push_back(Ok(PayloadVerdict::Invalid("no".into())));
    let msg = safety_halt(finalize(&mut app, req.clone()).await);
    assert!(msg.contains("engine_forkchoiceUpdated"), "{msg}");

    assert_eq!(app.pending, None, "nothing becomes pending");
    assert_eq!(app.state().cloned(), committed);
}

/// An Engine API error code, a JSON-RPC code for a malformed call, or a reply of the wrong shape
/// is the EL's deterministic answer to the call: retrying cannot change it, so the decided block
/// halts at once.
#[tokio::test]
async fn el_error_replies_on_a_decided_block_are_safety_halts() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    let reply = |code: i64, message: &str| EngineError::ErrorReply {
        call: "engine_x at http://el.test/".into(),
        code,
        message: message.into(),
    };

    let before = app.engine().calls().len();
    app.engine()
        .state()
        .forkchoice_script
        .push_back(Err(reply(-38002, "Invalid forkchoice state")));
    let msg = safety_halt(finalize(&mut app, req.clone()).await);
    assert!(msg.contains("engine_forkchoiceUpdated") && msg.contains("-38002"), "{msg}");
    let fcus = engine_calls_since(&app, before)
        .iter()
        .filter(|c| matches!(c, EngineCall::Forkchoice { .. }))
        .count();
    assert_eq!(fcus, 1, "an error reply is not retried");

    for error in [
        reply(-32602, "Invalid params"),
        reply(-38005, "Unsupported fork"),
        EngineError::BadReply("null".into()),
    ] {
        let before = app.engine().calls().len();
        app.engine().state().new_payload_script.push_back(Err(error.clone()));
        let msg = safety_halt(finalize(&mut app, req.clone()).await);
        assert!(msg.contains("engine_newPayload"), "{error:?}: {msg}");
        assert_eq!(
            engine_calls_since(&app, before),
            [EngineCall::NewPayload(env.block.header.hash_slow())],
            "{error:?} is not retried and the forkchoice never moves"
        );
    }
    assert_eq!(app.pending, None, "nothing becomes pending");
}

/// reth answers `-32603` (internal error) while its engine task stops during a shutdown
/// ("beacon consensus engine task stopped") and on provider or database faults, and
/// implementation-defined `-32000`-range errors: none is a verdict on the block, so
/// `FinalizeBlock` retries them with backoff, on newPayload and on the forkchoice update alike,
/// and the block then finalizes.
#[tokio::test(start_paused = true)]
async fn transient_el_error_replies_are_retried_until_the_block_finalizes() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    let reply = |code: i64, message: &str| EngineError::ErrorReply {
        call: "engine_x at http://el.test/".into(),
        code,
        message: message.into(),
    };
    {
        let mut engine = app.engine().state();
        engine.new_payload_script.extend([
            Err(reply(-32603, "beacon consensus engine task stopped")),
            Err(reply(-32603, "database error")),
        ]);
        engine.forkchoice_script.extend([
            Err(reply(-32603, "beacon consensus engine task stopped")),
            Err(reply(-32001, "busy")),
        ]);
    }
    let before = app.engine().calls().len();
    let start = tokio::time::Instant::now();
    tokio::time::timeout(Duration::from_secs(600), finalize(&mut app, req))
        .await
        .expect("the retried calls succeed")
        .expect("finalizes once the EL answers");

    // One backoff for the block: 100 and 200 ms after the failed newPayloads, 400 and 800 ms
    // after the failed forkchoice updates.
    assert_eq!(start.elapsed(), Duration::from_millis(100 + 200 + 400 + 800));
    let hash = env.block.header.hash_slow();
    let fcu = EngineCall::Forkchoice { head: hash, safe: hash, finalized: fx.genesis_hash() };
    assert_eq!(
        engine_calls_since(&app, before),
        [
            EngineCall::NewPayload(hash),
            EngineCall::NewPayload(hash),
            EngineCall::NewPayload(hash),
            fcu.clone(),
            fcu.clone(),
            fcu,
        ]
    );
    assert_eq!(app.pending.as_ref().map(|s| s.parent.hash), Some(hash));
}

/// alethia-reth's `INVALID` with a `null` `validationError` (which alloy's strict decoding
/// refuses) reaches `FinalizeBlock` through the RPC engine as `INVALID`: a safety halt, not an
/// endless retry.
#[tokio::test(start_paused = true)]
async fn rpc_engine_invalid_without_a_validation_error_is_a_safety_halt() {
    use alloy_provider::ProviderBuilder;
    use alloy_transport::mock::Asserter;

    use crate::engine::RpcEngine;

    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    Store::new(dir.path().to_path_buf()).save(app.state().unwrap()).unwrap();
    drop(app);

    let (l2, auth) = (Asserter::new(), Asserter::new());
    let engine = RpcEngine::from_parts(
        ProviderBuilder::default().connect_mocked_client(l2),
        "http://l2-http.test/".into(),
        ProviderBuilder::default().connect_mocked_client(auth.clone()),
        "http://l2-auth.test/".into(),
    );
    auth.push_success(
        &serde_json::json!({ "status": "INVALID", "latestValidHash": null, "validationError": null }),
    );
    let mut app = App::new(
        fx.l1(),
        engine,
        fx.params.clone(),
        Store::new(dir.path().to_path_buf()),
        AppOptions::default(),
    )
    .expect("the app restarts on the RPC engine");
    let result =
        tokio::time::timeout(Duration::from_secs(600), app.handle(Request::FinalizeBlock(req)))
            .await
            .expect("FinalizeBlock halts instead of retrying");
    match result {
        Err(AbciError::SafetyHalt(msg)) => {
            assert!(msg.contains("engine_newPayload answered INVALID: INVALID"), "{msg}")
        }
        other => panic!("expected a safety halt, got {other:?}"),
    }
}

/// The block was executed in `ProcessProposal`, but the EL lost it (e.g. it restarted): its
/// forkchoice update answers `SYNCING`, so `FinalizeBlock` re-sends the payload before
/// retrying the forkchoice.
#[tokio::test(start_paused = true)]
async fn forkchoice_syncing_after_a_cached_verdict_resends_the_payload() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    let hash = env.block.header.hash_slow();
    assert!(app.verdicts[&req.hash].executed);
    app.engine().state().known.remove(&hash);

    let before = app.engine().calls().len();
    tokio::time::timeout(Duration::from_secs(600), finalize(&mut app, finalize_req(&req)))
        .await
        .expect("the re-sent payload lets the forkchoice through")
        .expect("finalizes once the EL has the block");
    let fcu = EngineCall::Forkchoice { head: hash, safe: hash, finalized: fx.genesis_hash() };
    assert_eq!(
        engine_calls_since(&app, before),
        [fcu.clone(), EngineCall::NewPayload(hash), fcu],
        "SYNCING on the forkchoice re-sends the payload first"
    );
    assert_eq!(
        app.engine().state().chain.get(&env.block.header.number).map(|h| h.hash_slow()),
        Some(hash)
    );
}

/// Retries are logged at WARN for the first minute, then at ERROR (still retrying), so an EL
/// that never settles a decided block reaches the operators.
#[tokio::test(start_paused = true)]
async fn el_retries_escalate_after_a_minute() {
    let start = tokio::time::Instant::now();
    let mut backoff = super::super::finalize::Backoff::new(7);
    let mut log = vec![];
    while start.elapsed() < Duration::from_secs(70) {
        log.push((start.elapsed(), backoff.escalated()));
        backoff.wait("engine_newPayload", "the execution engine is syncing").await;
    }
    assert!(log.iter().all(|(at, escalated)| *escalated == (*at >= FINALIZE_RETRY_ESCALATE)));
    assert!(log.iter().any(|(_, escalated)| !escalated));
    assert!(log.iter().any(|(_, escalated)| *escalated));
    assert_eq!(FINALIZE_RETRY_ESCALATE, Duration::from_secs(60));
}

#[tokio::test]
async fn a_decided_block_failing_validation_is_a_safety_halt() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let mut env = propose(&mut app).await;
    env.block.header.timestamp += 1;
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    let before = app.engine().calls().len();
    let msg = safety_halt(finalize(&mut app, req).await);
    assert!(msg.contains("timestamp"), "{msg}");
    assert_eq!(engine_calls_since(&app, before), [], "the EL is not touched");

    let garbage = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![]));
    safety_halt(finalize(&mut app, garbage).await);
    assert_eq!(app.pending, None);
}

/// Two different records for one epoch: a safety halt.
#[tokio::test]
async fn a_conflicting_committee_record_is_a_safety_halt() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = propose(&mut app).await; // H_0 derives committee 1
    let (_, req) = judge(&mut app, &env).await;
    app.state.as_mut().unwrap().committees.insert(1, fx.committee(2));
    let before = app.engine().calls().len();
    let msg = safety_halt(finalize(&mut app, finalize_req(&req)).await);
    assert!(msg.contains("epoch 1"), "{msg}");
    assert_eq!(engine_calls_since(&app, before), [], "the EL is not touched");

    // The same record again is no conflict.
    app.state.as_mut().unwrap().committees.insert(1, fx.committee(1));
    finalize(&mut app, finalize_req(&req)).await.expect("an identical record is fine");
}

#[tokio::test(start_paused = true)]
async fn syncing_and_transport_errors_are_retried_with_backoff() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    {
        let mut engine = app.engine().state();
        engine.new_payload_script.push_back(Ok(PayloadVerdict::Syncing));
        engine.new_payload_script.push_back(Err(EngineError::Transport("refused".into())));
        for _ in 0..7 {
            engine.forkchoice_script.push_back(Ok(PayloadVerdict::Syncing));
        }
    }
    let before = app.engine().calls().len();
    let start = tokio::time::Instant::now();
    finalize(&mut app, req).await.expect("finalizes once the EL is ready");

    // One backoff for the block: 100 ms after newPayload's SYNCING (whose forkchoice nudge takes
    // one scripted SYNCING), 200 ms after the transport error, then 400, 800, 1600, 3200 ms and
    // twice the 5 s cap for the forkchoice (each SYNCING re-sends the payload first).
    assert_eq!(start.elapsed(), Duration::from_millis(300 + 6_000 + 10_000));
    let calls = engine_calls_since(&app, before);
    let count = |pred: fn(&EngineCall) -> bool| calls.iter().filter(|c| pred(c)).count();
    assert_eq!(count(|c| matches!(c, EngineCall::NewPayload(_))), 3 + 6);
    assert_eq!(count(|c| matches!(c, EngineCall::Forkchoice { .. })), 1 + 7);
}

/// An EL answering `newPayload` with SYNCING (e.g. one that lost its tail and so the block's
/// ancestry) is pointed at the block by a forkchoice update before the payload is retried, so it
/// starts backfilling from it; a nudge answered VALID settles the block at once.
#[tokio::test(start_paused = true)]
async fn a_syncing_payload_is_followed_by_a_forkchoice_nudge() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let hash = env.block.header.hash_slow();
    let finalized = app.state().unwrap().anchor.inbox.last_checkpoint_hash;
    let fcu = EngineCall::Forkchoice { head: hash, safe: hash, finalized };
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));

    // An EL without the block (this node built it, so drop it from the mock EL's blocks):
    // SYNCING twice, each nudge answered SYNCING too, then the payload executes and the
    // forkchoice settles it.
    {
        let mut engine = app.engine().state();
        engine.known.remove(&hash);
        engine
            .new_payload_script
            .extend([Ok(PayloadVerdict::Syncing), Ok(PayloadVerdict::Syncing)]);
    }
    let before = app.engine().calls().len();
    finalize(&mut app, req.clone()).await.expect("finalizes once the EL is ready");
    let payload = EngineCall::NewPayload(hash);
    assert_eq!(
        engine_calls_since(&app, before),
        [payload.clone(), fcu.clone(), payload.clone(), fcu.clone(), payload.clone(), fcu.clone()]
    );

    // A nudge the EL answers VALID (it caught up meanwhile) settles the block.
    {
        let mut engine = app.engine().state();
        engine.new_payload_script.push_back(Ok(PayloadVerdict::Syncing));
        engine.forkchoice_script.push_back(Ok(PayloadVerdict::Valid));
    }
    let before = app.engine().calls().len();
    finalize(&mut app, req).await.expect("finalizes on the nudge");
    assert_eq!(engine_calls_since(&app, before), [payload, fcu]);
}

/// A forkchoice nudge that itself fails (a transport error, its deadline) is not reported as
/// having pointed the EL at the block: the payload retry is logged with the nudge's own error.
#[tokio::test(start_paused = true)]
async fn a_failed_forkchoice_nudge_logs_its_own_error() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let hash = env.block.header.hash_slow();
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    let slow = app.opts.engine_timeout + Duration::from_secs(1);
    {
        // newPayload answers SYNCING three times; the nudges after it fail on the transport,
        // time out, then answer SYNCING (the EL lacks the block).
        let mut engine = app.engine().state();
        engine.known.remove(&hash);
        engine.new_payload_script.extend((0..3).map(|_| Ok(PayloadVerdict::Syncing)));
        engine.forkchoice_script.push_back(Err(EngineError::Transport("connection reset".into())));
        engine.delay_script.extend([Duration::ZERO, Duration::ZERO, Duration::ZERO, slow]);
    }
    let logs = LogCapture::start();
    finalize(&mut app, req).await.expect("finalizes once the EL executes the block");

    let retries = logs.at("WARN");
    assert_eq!(retries.len(), 3, "{}", logs.text());
    for (line, error) in retries[..2].iter().zip(["connection reset", "timed out"]) {
        assert!(line.contains("pointing it at the block failed") && line.contains(error), "{line}");
        assert!(!line.contains("pointed it at the block"), "{line}");
    }
    assert!(retries[2].contains("pointed it at the block"), "{}", retries[2]);
}

#[tokio::test(start_paused = true)]
async fn a_slow_engine_is_retried() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    let timeout = app.opts.engine_timeout;
    let slow = timeout + Duration::from_secs(1);
    app.engine().state().delay_script.extend([slow, slow]);

    let start = tokio::time::Instant::now();
    finalize(&mut app, req).await.expect("finalizes once the EL answers in time");
    // Two attempts time out (each after the deadline), with 100 and 200 ms pauses after them.
    assert_eq!(start.elapsed(), timeout * 2 + Duration::from_millis(300));
}

#[tokio::test]
async fn commit_persists_the_pending_state_and_clears_the_cache() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    assert!(matches!(commit(&mut app).await, Err(AbciError::NothingToCommit)));

    let env = propose(&mut app).await;
    let (_, req) = judge(&mut app, &env).await;
    let mut other = req.clone();
    other.hash = Hash::Sha256([7; 32]); // a competing proposal of the same height
    assert_eq!(process(&mut app, other).await, response::ProcessProposal::Accept);
    assert_eq!(app.verdicts.len(), 2);

    finalize(&mut app, finalize_req(&req)).await.expect("finalizes");
    let pending = app.pending.clone().expect("pending state");
    let store = Store::new(dir.path().to_path_buf());
    assert_eq!(store.load().unwrap(), Some(fx.expected_state()), "nothing persisted yet");

    app.halt = Some("stale".into());
    let resp = commit(&mut app).await.expect("commits");
    assert_eq!(resp.retain_height.value(), 0, "retain_height = 0 (no pruning)");
    assert!(resp.data.is_empty());
    assert_eq!(app.state(), Some(&pending));
    assert_eq!(app.pending, None);
    assert!(app.verdicts.is_empty(), "the cache is cleared");
    assert_eq!(app.halt, None);
    assert_eq!(store.load().unwrap(), Some(pending.clone()));
    assert_eq!(fx.app(dir.path()).state(), Some(&pending), "a restarted app loads it");

    assert!(matches!(commit(&mut app).await, Err(AbciError::NothingToCommit)));
}

/// CometBFT re-sends `FinalizeBlock` for a height whose block the EL executed before a crash
/// (`Info` reports the previous height): the replay answers the same.
#[tokio::test]
async fn finalize_replays_after_a_crash_before_commit() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    step(&mut app).await; // H_0
    let committed = app.state().unwrap().clone();
    let env = propose(&mut app).await;
    let (_, req) = judge(&mut app, &env).await;
    let req = finalize_req(&req);
    let first = finalize(&mut app, req.clone()).await.expect("finalizes");
    let hash = env.block.header.hash_slow();
    let canonical = |app: &App<MockL1, MockEngine>, n| {
        app.engine().state().chain.get(&n).map(|h: &alloy_consensus::Header| h.hash_slow())
    };
    assert_eq!(canonical(&app, committed.last_height + 1), Some(hash), "the EL moved on");

    // Crash before Commit: the EL keeps the block, the store the previous height.
    let engine = app.engine().reopen();
    drop(app);
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());
    assert_eq!(app.state(), Some(&committed));
    let resp = info(&mut app).await.expect("Info reconciles with an EL ahead");
    assert_eq!(resp.last_block_height.value(), committed.last_height);

    let replayed = finalize(&mut app, req).await.expect("the replay finalizes");
    assert_eq!(replayed, first);
    assert!(
        app.engine().calls().contains(&EngineCall::NewPayload(hash)),
        "the cache is gone, so the known block is executed again"
    );
    commit(&mut app).await.expect("commits");
    assert_eq!(app.state().unwrap().parent.hash, hash);
}

#[tokio::test]
async fn finalize_before_init_chain_is_an_error() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let req = finalize_req(&process_req(1_001, 0, vec![]));
    let err = finalize(&mut app, req).await.expect_err("not initialized");
    assert!(matches!(err, AbciError::Uninitialized("FinalizeBlock")), "{err:?}");
}

/// A genesis with `L = 4` and an unsettled cap of 1 (`D_MAX = 3`, `MARGIN_V = 2`).
fn short_epochs() -> Fixture {
    let mut spec = GenesisSpec::new(3);
    spec.epoch_len = 4;
    spec.params.d_max = 3;
    spec.params.margin_v = 2;
    Fixture::build(spec)
}

/// Drives `PrepareProposal → ProcessProposal → FinalizeBlock → Commit` for `2 L + 2` heights
/// from `H_0` on a [`short_epochs`] fixture; returns the app and every decided height's
/// `FinalizeBlock` request and response.
///
/// With a cap of 1 every height needs a new checkpoint, so before each height after `H_0` the
/// own L1 finalizes one more block (`L1_0 + k`) whose Inbox records the last committed block as
/// the checkpoint and every committee the app knows as landed. A fourth validator registers
/// at L1 block `L1_0 + 2`, so committees 2 and 3 have four members and 0 and 1 three.
async fn multi_epoch_run(
    fx: &Fixture,
    dir: &Path,
) -> (App<MockL1, MockEngine>, Vec<(request::FinalizeBlock, response::FinalizeBlock)>) {
    let mut app = initialized(fx, dir).await;
    let (h0, l1_0) = (app.state().unwrap().schedule.h0(), fx.activation.l1_0);
    let joined = RegistryStorage {
        checkpoints: vec![(l1_0, sample_entries(3)), (l1_0 + 2, sample_entries(4))],
    };
    let mut decided = vec![];
    for k in 0..2 * fx.activation.epoch_len + 2 {
        if k > 0 {
            let state = app.state().unwrap();
            let landed: Vec<(u64, B256)> = state
                .committees
                .iter()
                .map(|(e, c)| (*e, record_hash(fx.params.l2_chain_id, &c.record)))
                .collect();
            let mut inbox = fx.inbox_with(state.last_height, &landed);
            inbox.last_checkpoint_hash = state.parent.hash;
            let registry = if k >= 2 { &joined } else { &fx.registry };
            fx.advance_l1(app.l1(), l1_0 + k, &inbox, registry);
        }
        let env = propose(&mut app).await;
        assert_eq!(env.block.header.number, h0 + k);
        let (resp, req) = judge(&mut app, &env).await;
        assert_eq!(resp, response::ProcessProposal::Accept, "height {}: {:?}", h0 + k, app.halt);
        let req = finalize_req(&req);
        app.l1().state().calls.clear();
        let out = finalize(&mut app, req.clone()).await.expect("finalizes");
        assert!(app.l1().calls().is_empty(), "height {}: FinalizeBlock called L1", h0 + k);
        commit(&mut app).await.expect("commits");
        decided.push((req, out));
    }
    (app, decided)
}

#[tokio::test]
async fn multi_epoch_run_switches_the_validator_set_once() {
    let fx = short_epochs();
    let dir = tempfile::tempdir().unwrap();
    let (app, decided) = multi_epoch_run(&fx, dir.path()).await;
    let state = app.state().unwrap();
    let schedule = state.schedule;
    let h0 = schedule.h0();
    assert_eq!(decided.len(), 10);
    assert_eq!(state.last_height, h0 + 9);
    assert_eq!(schedule.epoch_of(state.last_height), 2);

    let c1 = fx.committee(1);
    let c2 = state.committees[&2].clone();
    assert_eq!(c1.members, fx.members, "committee 1 comes from the genesis snapshot");
    assert_eq!(c2.members.len(), 4, "the fourth validator is in committee 2");
    assert_eq!(state.committees[&3].members, c2.members);
    assert_eq!(state.committees.keys().copied().collect::<Vec<_>>(), [1, 2, 3], "0 is pruned");

    // CometBFT's view of the validator set, updated by every response.
    let mut set: BTreeMap<B256, u64> = fx.members.iter().map(|m| (m.pubkey, m.power)).collect();
    let mut changes = vec![];
    for (req, resp) in &decided {
        let height = req.height.value();
        let block_hash = B256::from_slice(resp.app_hash.as_bytes());
        assert_eq!(resp.tx_results.len(), 1);
        assert_eq!(resp.tx_results[0].code, Code::Ok);
        let updates = updates_of(resp);
        match schedule.switch_target(height) {
            Some(1) => {
                assert_eq!(updates, committee::validator_updates(&fx.members, &c1.members))
            }
            Some(2) => {
                assert_eq!(updates, committee::validator_updates(&c1.members, &c2.members))
            }
            other => assert!(updates.is_empty(), "height {height} (switch {other:?})"),
        }
        let before = set.clone();
        for (key, power) in updates {
            if power == 0 {
                set.remove(&key);
            } else {
                set.insert(key, power);
            }
        }
        if set != before {
            changes.push(height);
        }
        assert_ne!(block_hash, B256::ZERO);
    }
    assert_eq!(changes, [schedule.h_first(2) - 2], "the set changes once, at the switch to 2");
    let expected: BTreeMap<B256, u64> = c2.members.iter().map(|m| (m.pubkey, m.power)).collect();
    assert_eq!(set, expected);
}

/// The invariant that keeps `CommitteeUnknown` (a switch height lacking a committee) unreachable on
/// a chain the app built: the committee of epoch `t` is derived at `h_first(t − 1)` (its witness is
/// mandatory there), which precedes the switch height `h_first(t) − 2` because the schedule refuses
/// `L < 3`, and the switch to `t − 1` prunes only below `t − 2`. Replaying a run with the shortest
/// epochs the fixture's cap allows (`L = U + 3 = 4`), every switch height finds both committees.
#[tokio::test]
async fn every_switch_height_finds_both_committees() {
    let fx = short_epochs();
    let dir = tempfile::tempdir().unwrap();
    let (_, decided) = multi_epoch_run(&fx, dir.path()).await;

    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let schedule = app.state().unwrap().schedule;
    let mut switches = vec![];
    for (req, _) in &decided {
        let height = req.height.value();
        if let Some(t) = schedule.switch_target(height) {
            let known: Vec<u64> = app.state().unwrap().committees.keys().copied().collect();
            assert!(
                known.contains(&(t - 1)) && known.contains(&t),
                "switch to {t} at {height} knows {known:?}"
            );
            assert!(schedule.h_first(t - 1) < height, "committee {t} is derived before its switch");
            switches.push(t);
        }
        finalize(&mut app, req.clone()).await.expect("finalizes");
        commit(&mut app).await.expect("commits");
    }
    assert_eq!(switches, [1, 2]);
}

/// Two fresh apps finalizing the same decided requests (cold: no `ProcessProposal`) give the
/// same responses and states as the app that proposed and processed them.
#[tokio::test]
async fn finalize_is_deterministic_across_fresh_apps() {
    let fx = short_epochs();
    let dir = tempfile::tempdir().unwrap();
    let (proposer, decided) = multi_epoch_run(&fx, dir.path()).await;

    let mut states: Vec<AppState> = vec![];
    for _ in 0..2 {
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        for (req, resp) in &decided {
            let replayed = finalize(&mut app, req.clone()).await.expect("finalizes");
            assert_eq!(&replayed, resp, "height {}", req.height);
            commit(&mut app).await.expect("commits");
        }
        states.push(app.state().unwrap().clone());
    }
    assert_eq!(states[0], states[1]);
    assert_eq!(Some(&states[0]), proposer.state());
}
