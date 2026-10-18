//! `FinalizeBlock` and `Commit`: verdict cache, cold-start re-validation,
//! state transitions, validator-set switches, EL forkchoice and retries, safety halts,
//! persistence, crash replay, determinism and a multi-epoch run.

use std::{collections::BTreeMap, time::Duration};

use alloy_primitives::{B256, U256};
use tendermint::{AppHash, Hash, abci::Code};

use super::{
    proposal::{
        bft_time, commit, decide, finalize, finalize_req, hand_envelope, hand_forced_envelope,
        judge, jump, mid_epoch, next_height, plant_due_entry, process, process_req, propose,
        sample_tx_list, set_anchor_age, step, validate, with_extra_transaction,
    },
    *,
};
use crate::{
    app::{
        FINALIZE_RETRY_ESCALATE, MAX_VERDICTS,
        validate::{Rejection, Validated},
    },
    committee::{self, Snapshot},
    engine::{EngineError, PayloadVerdict},
    envelope::EtnaEnvelope,
    forced::ForcedError,
    l1::{L1Error, RawL1Header},
    store::{AppState, CommitteeState},
    test_utils::{GenesisSpec, L1Call, LogCapture, RegistryStorage, l1_header, sample_entries},
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
    let inbox = fx.inbox_with(fx.genesis.genesis_height + 3);
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
    let checkpoint = fx.inbox_with(fx.genesis.genesis_height + 3).last_checkpoint_hash;
    assert_eq!(
        engine_calls_since(&app, before),
        [EngineCall::Forkchoice { head: hash, safe: hash, finalized: checkpoint }],
        "the cached verdict was executed already: no second newPayload"
    );
    assert!(app.l1().calls().is_empty(), "a cached verdict needs no L1 call");

    assert_eq!(out.tx_results.len(), 1, "one result for the one envelope transaction");
    assert_eq!(out.tx_results[0].code, Code::Ok);
    assert!(out.events.is_empty() && out.validator_updates.is_empty());
    assert_eq!(out.consensus_param_updates, None);
    assert_eq!(out.app_hash, AppHash::try_from(hash.to_vec()).unwrap());
    assert_eq!(app.state().unwrap().last_height, next_height(&app) - 1, "not committed yet");
    assert_eq!(app.pending.as_ref().map(|s| s.parent.hash), Some(hash));
}

/// A height that takes many rounds keeps only the latest [`MAX_VERDICTS`] accepted proposals,
/// and a decided block whose verdict was evicted is re-validated and executed like one
/// `ProcessProposal` never saw.
#[tokio::test]
async fn the_verdict_cache_is_bounded_and_an_evicted_block_still_finalizes() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = anchor_moving(&fx, dir.path()).await;
    let env = propose(&mut app).await;
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    for round in 1..=MAX_VERDICTS {
        let mut later = req.clone();
        later.hash = Hash::Sha256([u8::try_from(round).unwrap(); 32]);
        assert_eq!(process(&mut app, later).await, response::ProcessProposal::Accept);
    }
    assert_eq!(app.verdicts.len(), MAX_VERDICTS);
    assert!(app.verdicts.get(&req.hash).is_none(), "the oldest verdict is evicted");

    // Processing a kept block again refreshes it instead of adding a second verdict.
    let mut kept = req.clone();
    kept.hash = Hash::Sha256([1; 32]);
    assert_eq!(process(&mut app, kept.clone()).await, response::ProcessProposal::Accept);
    assert_eq!(app.verdicts.len(), MAX_VERDICTS);

    let before = app.engine().calls().len();
    finalize(&mut app, finalize_req(&req)).await.expect("the evicted block finalizes");
    let hash = env.block.header.hash_slow();
    let checkpoint = fx.inbox_with(fx.genesis.genesis_height + 3).last_checkpoint_hash;
    assert_eq!(
        engine_calls_since(&app, before),
        [
            EngineCall::NewPayload(hash),
            EngineCall::Forkchoice { head: hash, safe: hash, finalized: checkpoint },
        ],
        "re-validated and executed, as on a cold start"
    );
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

    // A node that never saw the proposal (crash replay, block sync), whose own L1 finalized the
    // same block 66.
    let mut validator = anchor_moving(&fx, validator_dir.path()).await;
    validator.l1().state().calls.clear();
    let before = validator.engine().calls().len();
    let out = finalize(&mut validator, req.clone()).await.expect("finalizes");
    let hash = env.block.header.hash_slow();
    let checkpoint = fx.inbox_with(fx.genesis.genesis_height + 3).last_checkpoint_hash;
    assert_eq!(
        engine_calls_since(&validator, before),
        [
            EngineCall::NewPayload(hash),
            EngineCall::Forkchoice { head: hash, safe: hash, finalized: checkpoint },
        ]
    );
    assert_eq!(
        validator.l1().calls(),
        [L1Call::Finalized, L1Call::CanonicalHash(66)],
        "the moved anchor is confirmed in the own L1 view"
    );
    let pending = validator.pending.as_ref().expect("pending state");
    assert_eq!(pending.anchor, fx.anchor_state(proposer.l1(), 66));

    assert_eq!(finalize(&mut proposer, req).await.expect("finalizes"), out, "same response");
    assert_eq!(proposer.pending, validator.pending, "same next state");
}

#[tokio::test]
async fn finalize_updates_parent_anchor_and_committees() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h0 = fx.genesis.genesis_height + 1;

    // H_0 = h_first(e_0): re-prove the launch anchor; committee 1 waits until H(1)-2.
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
    expected.anchor = fx.anchor_state(app.l1(), fx.genesis.l1_0);
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
    let inbox = fx.inbox_with(h0);
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    step(&mut app).await;
    assert_eq!(app.state().unwrap().anchor, fx.anchor_state(app.l1(), 66));
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
    let switch = app.state().unwrap().schedule().h_first(4) - 2;

    let derive = |entries: Vec<RegistryEntry>, target| {
        let cutoff = if target == 4 { 76 } else { 64 };
        let snapshot = Snapshot {
            checkpoint_index: u64::from(target == 4),
            l1_block: if target == 4 { 71 } else { 63 },
            entries,
        };
        let (record, members) =
            committee::derive(&snapshot, cutoff, target, &fx.schedule(), params).unwrap();
        CommitteeState { record, members }
    };
    let all = sample_entries(4);
    let c1 = derive(all[..3].to_vec(), 3);
    let mut next = all.clone();
    next.remove(0); // validator 0 leaves
    next[0].eff_stake *= U256::from(5); // validator 1 changes power; 2 stays; 3 joins
    let c2 = derive(next.clone(), 4);

    let landed = fx.inbox_with(switch - 5);
    let changed = RegistryStorage { checkpoints: vec![(63, all[..3].to_vec()), (71, next)] };
    fx.advance_l1(app.l1(), 76, &landed, &changed);
    let anchor = fx.anchor_state(app.l1(), 76);
    jump(&mut app, switch - 1, anchor, &[(3, c1.clone())]);
    assert_eq!(app.state().unwrap().committees.keys().copied().collect::<Vec<_>>(), [0, 3]);

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
    assert_eq!(pending.committees.keys().copied().collect::<Vec<_>>(), [3, 4], "0 is pruned");

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
    let mut inbox = fx.inbox_with(fx.genesis.genesis_height + 1);
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
    Store::volatile(dir.path().to_path_buf()).save(app.state().unwrap()).unwrap();
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
        Store::volatile(dir.path().to_path_buf()),
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
    assert!(app.verdicts.get(&req.hash).expect("the verdict is cached").executed);
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

/// A decided block whose anchor is more than `maxAnchorAge` older than it, finalized by a node
/// that never judged it (crash replay, block sync): a safety halt before the EL moves.
#[tokio::test]
async fn cold_finalize_of_stale_anchor_block_halts() {
    let fx = Fixture::genesis(1);
    let max = fx.genesis.max_anchor_age;
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    set_anchor_age(&mut app, max + 1);
    let env = hand_envelope(&app, None, None);
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    let before = app.engine().calls().len();
    let msg = safety_halt(finalize(&mut app, req).await);
    let violation = crate::rules::RuleViolation::AnchorTooOld { age: max + 1, max };
    assert!(msg.contains(&violation.to_string()), "{msg}");
    assert_eq!(engine_calls_since(&app, before), [], "the EL is not touched");
    assert_eq!(app.pending, None);
}

/// A decided block whose anchor witness proves an L1 block the finalizing node's own L1 does not
/// have at that number (block sync of a forged history, its proofs consistent with the forged
/// header alone): a safety halt before the EL moves.
#[tokio::test(start_paused = true)]
async fn cold_finalize_halts_on_an_anchor_off_its_own_l1_chain() {
    let fx = Fixture::genesis(1);
    let (proposer_dir, node_dir) = (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
    let mut proposer = anchor_moving(&fx, proposer_dir.path()).await;
    let env = propose(&mut proposer).await;
    let (_, req) = judge(&mut proposer, &env).await;

    // The node's own L1 finalized a different block 66.
    let mut node = mid_epoch(&fx, node_dir.path(), 5).await;
    let other = fx.inbox_with(fx.genesis.genesis_height + 4);
    let canonical = fx.advance_l1(node.l1(), 66, &other, &fx.registry);
    assert_ne!(canonical.hash(), env.anchor.as_ref().unwrap().l1_header.hash());

    let before = node.engine().calls().len();
    let msg = safety_halt(finalize(&mut node, finalize_req(&req)).await);
    assert!(msg.contains("anchor L1 block 66"), "{msg}");
    assert!(msg.contains("not on the own L1 chain"), "{msg}");
    assert_eq!(engine_calls_since(&node, before), [], "the EL is not touched");
    assert_eq!(node.pending, None);
}

/// A node finalizing a decided block it never judged waits, with the FinalizeBlock backoff, while
/// its own L1 is down or has not finalized the block's anchor yet: it neither halts nor
/// finalizes before its L1 confirms the anchor.
#[tokio::test(start_paused = true)]
async fn cold_finalize_waits_until_its_own_l1_confirms_the_anchor() {
    let fx = Fixture::genesis(1);
    let (proposer_dir, node_dir) = (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
    let mut proposer = anchor_moving(&fx, proposer_dir.path()).await;
    let env = propose(&mut proposer).await;
    let (_, req) = judge(&mut proposer, &env).await;

    let mut node = anchor_moving(&fx, node_dir.path()).await;
    {
        let mut l1 = node.l1().state();
        l1.finalized_script.push_back(Err(L1Error::Rpc("down".into())));
        l1.finalized_script.push_back(Ok(65));
        l1.calls.clear();
    }
    let start = tokio::time::Instant::now();
    finalize(&mut node, finalize_req(&req)).await.expect("finalizes once its L1 confirms");
    assert_eq!(start.elapsed(), Duration::from_millis(100 + 200), "two backoff pauses");
    assert_eq!(
        node.l1().calls(),
        [
            L1Call::Finalized,
            L1Call::Finalized,
            // Behind the anchor, the own finalized header bounds how early block 66 can be.
            L1Call::Header(65),
            L1Call::Finalized,
            L1Call::CanonicalHash(66)
        ]
    );
    assert_eq!(node.pending.as_ref().unwrap().parent.hash, env.block.header.hash_slow());
}

/// One own-L1 answer naming a different block at the anchor's number (e.g. a lagging backend of a
/// load-balanced endpoint) is re-read after a backoff pause before it halts anything: the second
/// read confirms the anchor and the block finalizes.
#[tokio::test(start_paused = true)]
async fn a_single_off_chain_answer_is_re_read_before_a_halt() {
    let fx = Fixture::genesis(1);
    let (proposer_dir, node_dir) = (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
    let mut proposer = anchor_moving(&fx, proposer_dir.path()).await;
    let env = propose(&mut proposer).await;
    let (_, req) = judge(&mut proposer, &env).await;

    let mut node = anchor_moving(&fx, node_dir.path()).await;
    {
        let mut l1 = node.l1().state();
        l1.canonical_script.push_back(Ok(B256::repeat_byte(0xee)));
        l1.calls.clear();
    }
    let start = tokio::time::Instant::now();
    finalize(&mut node, finalize_req(&req)).await.expect("the re-read confirms the anchor");
    assert_eq!(start.elapsed(), Duration::from_millis(100), "one backoff pause");
    assert_eq!(
        node.l1().calls(),
        [
            L1Call::Finalized,
            L1Call::CanonicalHash(66),
            L1Call::Finalized,
            L1Call::CanonicalHash(66)
        ]
    );
}

/// Sticky routing can return the same stale backend more than once within 100 ms. Recovery
/// inside the suspicion window must still finalize, without treating those reads as a fork.
#[tokio::test(start_paused = true)]
async fn repeated_off_chain_answers_can_recover_within_the_suspicion_window() {
    let fx = Fixture::genesis(1);
    let (proposer_dir, node_dir) = (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
    let mut proposer = anchor_moving(&fx, proposer_dir.path()).await;
    let env = propose(&mut proposer).await;
    let (_, req) = judge(&mut proposer, &env).await;
    let mut node = anchor_moving(&fx, node_dir.path()).await;
    node.l1().state().canonical_script.extend(std::iter::repeat_n(Ok(B256::repeat_byte(0xee)), 4));
    let started = tokio::time::Instant::now();
    finalize(&mut node, finalize_req(&req)).await.expect("a briefly stale backend can recover");
    assert_eq!(started.elapsed(), Duration::from_millis(1500));
}

/// Persistent disagreement must span a time window before a safety halt, rather than two
/// immediate observations of one backend.
#[tokio::test(start_paused = true)]
async fn persistent_off_chain_answers_halt_after_the_suspicion_window() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let node = anchor_moving(&fx, dir.path()).await;
    let forged = RawL1Header::from(&l1_header(66, Fixture::l1_timestamp(66) + 1));
    let started = tokio::time::Instant::now();
    let result = node.confirm_anchor(7, &forged).await;
    assert!(matches!(result, Err(AbciError::SafetyHalt(_))));
    assert!(started.elapsed() >= Duration::from_secs(5));
}

/// A payload id can disappear after an EL restart between FCU and getPayload. Cold replay
/// retries the whole build to acquire a fresh id.
#[tokio::test(start_paused = true)]
async fn cold_forced_skip_retries_an_unknown_payload_id() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = skipped_block(&fx, dir.path()).await;
    app.engine().state().build_script.push_back(Err(EngineError::ErrorReply {
        call: "engine_getPayloadV5".into(),
        code: -38001,
        message: "Unknown payload".into(),
    }));
    app.engine().state().build_script.push_back(Ok(env.block.clone()));
    let req = cold_req(&app, &env);
    finalize(&mut app, req).await.expect("rebuilds with a fresh payload id");
    assert_eq!(app.pending.as_ref().map(|s| s.parent.hash), Some(env.block.header.hash_slow()));
}

/// With an extra finality depth, the own L1 must have finalized the anchor's number plus that
/// depth: a node whose L1 finalized only one block past the anchor waits for the second.
#[tokio::test(start_paused = true)]
async fn cold_finalize_waits_for_the_extra_finality_depth() {
    let mut fx = Fixture::genesis(1);
    fx.params.l1_finality_extra_depth = 2;
    let (proposer_dir, node_dir) = (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
    let mut proposer = anchor_moving(&fx, proposer_dir.path()).await;
    let env = propose(&mut proposer).await;
    let (_, req) = judge(&mut proposer, &env).await;

    let mut node = anchor_moving(&fx, node_dir.path()).await;
    {
        let mut l1 = node.l1().state();
        l1.finalized_script.push_back(Ok(67));
        l1.calls.clear();
    }
    let start = tokio::time::Instant::now();
    finalize(&mut node, finalize_req(&req)).await.expect("finalizes at depth 2");
    assert_eq!(start.elapsed(), Duration::from_millis(100), "one backoff pause");
    assert_eq!(
        node.l1().calls(),
        [L1Call::Finalized, L1Call::Finalized, L1Call::CanonicalHash(66)]
    );
}

/// An anchor numbered beyond the own L1's finalized block whose timestamp no real block there can
/// have (L1 timestamps rise by at least a second per block): a safety halt instead of an endless
/// wait for a block that cannot exist.
#[tokio::test(start_paused = true)]
async fn an_anchor_beyond_the_own_l1_head_with_an_impossible_timestamp_halts() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let node = anchor_moving(&fx, dir.path()).await;
    // The own L1 finalized block 66; a real block 1066 is at least 1000 s younger.
    let forged = RawL1Header::from(&l1_header(1066, Fixture::l1_timestamp(66) + 999));
    let halted = tokio::time::timeout(Duration::from_secs(600), node.confirm_anchor(7, &forged));
    match halted.await.expect("halts instead of waiting") {
        Err(AbciError::SafetyHalt(msg)) => {
            assert!(msg.contains("anchor L1 block 1066"), "{msg}");
            assert!(msg.contains("timestamp"), "{msg}");
        }
        other => panic!("expected a safety halt, got {other:?}"),
    }
    // A plausible future block is waited for, not halted on.
    let plausible = RawL1Header::from(&l1_header(1066, Fixture::l1_timestamp(66) + 1000));
    let wait = node.confirm_anchor(7, &plausible);
    assert!(
        tokio::time::timeout(Duration::from_secs(600), wait).await.is_err(),
        "still waiting for the own L1 to reach block 1066"
    );
}

/// An anchor number so large that no finality bound exists for it: a safety halt without any L1
/// read.
#[tokio::test]
async fn an_anchor_number_beyond_any_finality_bound_halts() {
    let mut fx = Fixture::genesis(1);
    fx.params.l1_finality_extra_depth = 2;
    let dir = tempfile::tempdir().unwrap();
    let node = mid_epoch(&fx, dir.path(), 5).await;
    node.l1().state().calls.clear();
    let forged = RawL1Header::from(&l1_header(u64::MAX, 0));
    match tokio::time::timeout(Duration::from_secs(60), node.confirm_anchor(7, &forged))
        .await
        .expect("halts at once")
    {
        Err(AbciError::SafetyHalt(msg)) => assert!(msg.contains("finality bound"), "{msg}"),
        other => panic!("expected a safety halt, got {other:?}"),
    }
    assert!(node.l1().calls().is_empty());
}

/// A decided block carrying no anchor witness introduces no L1 fact: a node that never judged it
/// finalizes it without any L1 call, even with its own L1 down.
#[tokio::test]
async fn a_cold_block_without_an_anchor_witness_needs_no_l1() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = hand_envelope(&app, None, None);
    let req = finalize_req(&process_req(next_height(&app), bft_time(&app), vec![env.encode()]));
    {
        let mut l1 = app.l1().state();
        l1.fail = Some(L1Error::Rpc("down".into()));
        l1.calls.clear();
    }
    finalize(&mut app, req).await.expect("finalizes without L1");
    assert!(app.l1().calls().is_empty());
}

/// Two different records for one epoch: a safety halt.
#[tokio::test]
async fn a_conflicting_committee_record_is_a_safety_halt() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let switch = fx.schedule().h_first(1) - 2;
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(switch - 7), &fx.registry);
    let parent = fx.anchor_state(app.l1(), 66);
    jump(&mut app, switch - 1, parent, &[]);
    let env = propose(&mut app).await; // switch derives committee 1
    let (_, req) = judge(&mut app, &env).await;
    let derived = app.verdicts.get(&req.hash).unwrap().derived.as_ref().unwrap().1.clone();
    app.state.as_mut().unwrap().committees.insert(1, fx.committee(2));
    let before = app.engine().calls().len();
    let msg = safety_halt(finalize(&mut app, finalize_req(&req)).await);
    assert!(msg.contains("epoch 1"), "{msg}");
    assert_eq!(engine_calls_since(&app, before), [], "the EL is not touched");

    // The same record again is no conflict.
    app.state.as_mut().unwrap().committees.insert(1, derived);
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
    let store = Store::volatile(dir.path().to_path_buf());
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

/// The forced block an honest proposer builds for the next height of `app` consuming entry 0,
/// which [`plant_due_entry`] plants as due in its own L1's finalized block 66; anchored at 66.
fn forced_block_on(fx: &Fixture, app: &App<MockL1, MockEngine>) -> EtnaEnvelope {
    let blob = plant_due_entry(fx, app.l1(), 66, fx.inbox.clone());
    let anchor = Some(fx.anchor_witness(app.l1(), 66));
    let witness = fx.forced_witness(app.l1(), 66, 0, blob);
    hand_forced_envelope(app, anchor, None, witness, sample_tx_list())
}

/// A mid-epoch app whose own L1 finalized block 66 holding one due entry, and the forced block
/// consuming it, anchored at 66.
async fn forced_block(fx: &Fixture, dir: &Path) -> (App<MockL1, MockEngine>, EtnaEnvelope) {
    let app = mid_epoch(fx, dir, 5).await;
    let env = forced_block_on(fx, &app);
    (app, env)
}

/// The `FinalizeBlock` request of `env` decided as the next height of `app`, which never judged
/// it.
fn cold_req(app: &App<MockL1, MockEngine>, env: &EtnaEnvelope) -> request::FinalizeBlock {
    finalize_req(&process_req(next_height(app), bft_time(app), vec![env.encode()]))
}

/// Cold included replay executes the ordinary mixed payload without probing forced input.
#[tokio::test]
async fn cold_inclusion_needs_no_skip_probe() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, mut honest) = forced_block(&fx, dir.path()).await;
    honest.forced.as_mut().unwrap().tx = alloy_primitives::Bytes::new();
    let env = with_extra_transaction(honest);
    let req = cold_req(&app, &env);
    let before = app.engine().calls().len();
    finalize(&mut app, req).await.unwrap();
    assert!(matches!(
        &app.engine().calls()[before..],
        [EngineCall::NewPayload(_), EngineCall::Forkchoice { .. }]
    ));
    assert_eq!(app.pending.as_ref().unwrap().forced_cursor, 1);
}

/// Canonical skip fixture whose ordinary block omits the forced transaction.
async fn skipped_block(fx: &Fixture, dir: &Path) -> (App<MockL1, MockEngine>, EtnaEnvelope) {
    let (app, mut env) = forced_block(fx, dir).await;
    env.block.transactions.clear();
    env.block.header.transactions_root = alloy_consensus::EMPTY_ROOT_HASH;
    (app, env)
}

/// The EL failing to rebuild a decided forced inclusion block for a node-local reason (a
/// transport failure, a deadline, a build it did not start, e.g. while it lacks the parent) is
/// retried with backoff until the block finalizes; an EL refusing the build call itself is a
/// safety halt. Retries and the halt are logged under the forced rebuild's own label, and a build
/// the EL did not start, like the halt, names the parent and the likely missing state.
#[tokio::test(start_paused = true)]
async fn cold_forced_skip_failures_retry_or_halt() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = skipped_block(&fx, dir.path()).await;
    let req = cold_req(&app, &env);
    let slow = app.opts.engine_timeout + Duration::from_secs(1);
    {
        let mut engine = app.engine().state();
        engine.build_script.extend([
            Err(EngineError::Transport("connection refused".into())),
            Err(EngineError::BuildNotStarted("SYNCING".into())),
        ]);
        engine.build_script.push_back(Ok(env.block.clone()));
        engine.delay_script.extend([Duration::ZERO, Duration::ZERO, slow]);
    }
    let parent = app.state().unwrap().parent.clone();
    let on_parent = format!("parent {} ({})", parent.number, parent.hash);
    let before = app.engine().calls().len();
    let start = tokio::time::Instant::now();
    let logs = LogCapture::start();
    finalize(&mut app, req.clone()).await.expect("finalizes once the EL rebuilds the block");
    let retries = logs.at("WARN");
    assert_eq!(retries.len(), 3, "{}", logs.text());
    for line in &retries {
        assert!(line.contains("method=\"forced_rebuild_unavailable\""), "{line}");
        assert!(line.contains(&on_parent), "{line}");
        assert!(line.contains("may lack"), "{line}");
    }
    assert!(retries[0].contains("connection refused"), "{}", retries[0]);
    assert!(retries[1].contains("SYNCING"), "{}", retries[1]);
    // Pauses of 100, 200 and 400 ms after the two failures and the timed-out third build.
    assert_eq!(start.elapsed(), app.opts.engine_timeout + Duration::from_millis(700));
    let builds = engine_calls_since(&app, before)
        .iter()
        .filter(|c| matches!(c, EngineCall::BuildBlock { .. }))
        .count();
    assert_eq!(builds, 3, "the timed-out build is never recorded");
    assert_eq!(app.pending.as_ref().map(|s| s.parent.hash), Some(env.block.header.hash_slow()));

    let refusal = EngineError::ErrorReply {
        call: "engine_forkchoiceUpdatedV3 at http://el.test/".into(),
        code: -38003,
        message: "Invalid payload attributes".into(),
    };
    app.engine().state().build_script.push_back(Err(refusal));
    let msg = safety_halt(finalize(&mut app, req).await);
    assert!(msg.contains("-38003"), "{msg}");
    // The halt names the parent the EL could not build on and what to do about it.
    assert!(msg.contains(&on_parent), "{msg}");
    assert!(msg.contains("historical state"), "{msg}");
    let halts = logs.at("ERROR");
    assert!(
        halts.iter().any(|line| line.contains("reason=\"forced_rebuild_unavailable\"")),
        "{}",
        logs.text()
    );
}

/// CometBFT replays a decided forced inclusion block after a crash before `Commit`, with no
/// admission-log access: the cold node confirms the moved anchor in its own L1 and executes
/// the included transaction using the entry proof and the first execution-block transaction,
/// without a second copy in the witness.
#[tokio::test]
async fn replay_validates_inclusion_without_admission_log_reads() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    step(&mut app).await; // H_0
    let committed = app.state().unwrap().clone();
    let mut env = forced_block_on(&fx, &app);
    env.forced.as_mut().unwrap().tx = alloy_primitives::Bytes::new();
    let hash = env.block.header.hash_slow();
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    let req = finalize_req(&req);
    let before = app.engine().calls().len();
    let first = finalize(&mut app, req.clone()).await.expect("finalizes");
    let calls = engine_calls_since(&app, before);
    assert!(
        matches!(calls.as_slice(), [EngineCall::Forkchoice { head, .. }] if *head == hash),
        "the cached verdict was rebuilt and executed already: {calls:?}"
    );

    // Crash before Commit: the EL keeps the block, the store the previous height;
    // the own L1 still has block 66.
    let engine = app.engine().reopen();
    drop(app);
    let l1 = fx.l1();
    plant_due_entry(&fx, &l1, 66, fx.inbox.clone());
    l1.state().calls.clear();
    let store = Store::volatile(dir.path().to_path_buf());
    let mut app = App::new(l1, engine, fx.params.clone(), store, AppOptions::default())
        .expect("the app restarts");
    assert_eq!(app.state(), Some(&committed));
    info(&mut app).await.expect("Info reconciles with an EL ahead");

    let before = app.engine().calls().len();
    let replayed = finalize(&mut app, req).await.expect("the replay finalizes");
    assert_eq!(replayed, first);
    assert_eq!(
        app.l1().calls(),
        [L1Call::Finalized, L1Call::CanonicalHash(66)],
        "only the moved anchor is confirmed in the own L1"
    );
    let calls = engine_calls_since(&app, before);
    let [EngineCall::NewPayload(executed), EngineCall::Forkchoice { head, .. }] = calls.as_slice()
    else {
        panic!("ordinary execution only: {calls:?}");
    };
    assert_eq!((*executed, *head), (hash, hash));
    commit(&mut app).await.expect("commits");
    let state = app.state().unwrap();
    assert_eq!((state.parent.hash, state.forced_cursor), (hash, 1));
}

#[tokio::test]
async fn forced_cursor_advances_after_a_forced_block_commits() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = forced_block(&fx, dir.path()).await;
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    assert_eq!(app.state().unwrap().forced_cursor, 0, "judging commits nothing");

    // A node that never judged the block derives the same cursor from the envelope alone.
    let cold_dir = tempfile::tempdir().unwrap();
    let mut cold = mid_epoch(&fx, cold_dir.path(), 5).await;
    share_l1_chain(app.l1(), cold.l1());
    finalize(&mut cold, finalize_req(&req)).await.expect("the cold node finalizes");
    assert_eq!(cold.pending.as_ref().map(|s| s.forced_cursor), Some(1));

    decide(&mut app, &req).await;
    assert_eq!(app.state().unwrap().forced_cursor, 1);
    let stored = Store::volatile(dir.path().to_path_buf()).load().unwrap().expect("persisted");
    assert_eq!(stored.forced_cursor, 1);

    // The next block (cursor 1 == tail 1) is ordinary, carries no witness and keeps the cursor.
    let next = hand_envelope(&app, None, None);
    let (resp, req) = judge(&mut app, &next).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    decide(&mut app, &req).await;
    assert_eq!(app.state().unwrap().forced_cursor, 1);
}

/// The cursor is persisted state: a restarted node (no `InitChain`) judges the next height from
/// it, so the consumed entry cannot be consumed again.
#[tokio::test]
async fn forced_cursor_survives_restart() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = forced_block(&fx, dir.path()).await;
    let (_, req) = judge(&mut app, &env).await;
    decide(&mut app, &req).await;
    let committed = app.state().unwrap().clone();
    assert_eq!(committed.forced_cursor, 1);
    let again = env.forced.clone().expect("the consumed entry's witness");

    let engine = app.engine().reopen();
    drop(app);
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());
    assert_eq!(app.state(), Some(&committed), "loaded from the store");
    info(&mut app).await.expect("Info answers from the stored state");
    assert_eq!(app.state().unwrap().forced_cursor, 1);

    let ordinary = hand_envelope(&app, None, None);
    assert!(matches!(validate(&app, &ordinary), Ok(Validated { forced: None, .. })));
    let mut replayed = ordinary;
    replayed.forced = Some(again);
    assert_eq!(
        validate(&app, &replayed).map(|_| ()),
        Err(Rejection::Forced(ForcedError::UnexpectedWitness))
    );
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

/// Drives `PrepareProposal → ProcessProposal → FinalizeBlock → Commit` for `3 L + 2` heights
/// from `H_0` on a [`short_epochs`] fixture; returns the app and every decided height's
/// `FinalizeBlock` request and response.
///
/// With a cap of 1 every height needs a new checkpoint, so before each height after `H_0` the
/// own L1 finalizes one more block (`L1_0 + k`) whose Inbox records the last committed block as
/// checkpoint; settlement advances only checkpoint facts. A fourth validator registers at
/// L1 block `L1_0 + 2`. Committee 1 selects its earlier committed parent; committees 2 and 3
/// include the fourth validator once their committed parent anchors cover the join.
async fn multi_epoch_run(
    fx: &Fixture,
    dir: &Path,
) -> (App<MockL1, MockEngine>, Vec<(request::FinalizeBlock, response::FinalizeBlock)>) {
    multi_epoch_run_for(fx, dir, 3).await
}

/// Execute a bounded number of full production switch epochs for nightly crash replay.
async fn multi_epoch_run_for(
    fx: &Fixture,
    dir: &Path,
    epochs: u64,
) -> (App<MockL1, MockEngine>, Vec<(request::FinalizeBlock, response::FinalizeBlock)>) {
    assert!((3..=128).contains(&epochs), "trace epochs must be in 3..=128");
    let mut app = initialized(fx, dir).await;
    let (h0, l1_0) = (app.state().unwrap().schedule().h0(), fx.genesis.l1_0);
    let joined = RegistryStorage {
        checkpoints: vec![
            (fx.genesis.genesis_cutoff, sample_entries(3)),
            (l1_0 + 2, sample_entries(4)),
        ],
    };
    let mut decided = vec![];
    for k in 0..epochs * fx.genesis.epoch_len + 2 {
        if k > 0 {
            let state = app.state().unwrap();
            let mut inbox = fx.inbox_with(state.last_height);
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

/// Gives `to` the L1 chain `from` holds (its headers and finalized number), as the own L1 of a
/// node replaying blocks anchored on that chain sees it; `to` keeps its own block states.
fn share_l1_chain(from: &MockL1, to: &MockL1) {
    let (headers, finalized) = {
        let from = from.state();
        (from.headers.clone(), from.finalized)
    };
    let mut to = to.state();
    to.headers.extend(headers);
    to.finalized = finalized;
}

/// Whether `calls` only confirm anchors (finalized number and canonical hashes), never reading
/// L1 state.
fn only_anchor_confirmations(calls: &[L1Call]) -> bool {
    calls.iter().all(|c| matches!(c, L1Call::Finalized | L1Call::CanonicalHash(_)))
}

#[tokio::test]
async fn multi_epoch_run_switches_the_validator_set_once() {
    let fx = short_epochs();
    let dir = tempfile::tempdir().unwrap();
    let (app, decided) = multi_epoch_run(&fx, dir.path()).await;
    let state = app.state().unwrap();
    let schedule = state.schedule();
    let h0 = schedule.h0();
    assert_eq!(decided.len(), 14);
    assert_eq!(state.last_height, h0 + 13);
    assert_eq!(schedule.epoch_of(state.last_height), 3);

    let c1 = fx.committee(1);
    let c2 = state.committees[&3].clone();
    assert_eq!(c1.members, fx.members, "committee 1 comes from the genesis snapshot");
    assert_eq!(c2.members.len(), 4, "the fourth validator is in committee 3");
    assert_eq!(state.committees[&2].members, c2.members);
    assert_eq!(state.committees.keys().copied().collect::<Vec<_>>(), [2, 3], "0 is pruned");

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
                assert_eq!(updates, committee::validator_updates(&c1.members, &c2.members));
            }
            Some(3) => {
                assert_eq!(updates, committee::validator_updates(&c2.members, &c2.members))
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

/// Full-history replay requires only the outgoing set before a switch. The embedded switch
/// witness authenticates the incoming set, which FinalizeBlock inserts before H+2 updates.
/// The minimum allowed epoch length remains unchanged.
#[tokio::test]
async fn every_switch_height_finds_both_committees() {
    let fx = short_epochs();
    let dir = tempfile::tempdir().unwrap();
    let (source, decided) = multi_epoch_run(&fx, dir.path()).await;

    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    share_l1_chain(source.l1(), app.l1());
    let schedule = app.state().unwrap().schedule();
    let mut switches = vec![];
    for (req, _) in &decided {
        let height = req.height.value();
        if let Some(t) = schedule.switch_target(height) {
            let known: Vec<u64> = app.state().unwrap().committees.keys().copied().collect();
            assert!(
                known.contains(&(t - 1)) && !known.contains(&t),
                "switch to {t} at {height} knows {known:?}"
            );
            assert!(schedule.h_first(t - 1) < height, "committee {t} is derived before its switch");
            switches.push(t);
        }
        finalize(&mut app, req.clone()).await.expect("finalizes");
        commit(&mut app).await.expect("commits");
        if let Some(t) = schedule.switch_target(height) {
            assert!(app.state().unwrap().committees.contains_key(&t));
        }
    }
    assert_eq!(switches, [1, 2, 3]);
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
        share_l1_chain(proposer.l1(), app.l1());
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

/// Crash on both sides of Commit at each switch, including the joining-validator switch.
/// Cold replay must preserve complete responses, updates, committees and canonical EL hashes.
#[tokio::test]
async fn switch_replay_survives_crashes_before_and_after_commit() {
    let fx = short_epochs();
    let source_dir = tempfile::tempdir().unwrap();
    let epochs = std::env::var("ETNA_TRACE_EPOCHS")
        .map(|value| value.parse::<u64>().expect("ETNA_TRACE_EPOCHS must be an integer"))
        .unwrap_or(3);
    let (source, decided) = multi_epoch_run_for(&fx, source_dir.path(), epochs).await;
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    share_l1_chain(source.l1(), app.l1());
    // The own L1 of the restarted node: the same chain.
    let restarted_l1 = || {
        let l1 = fx.l1();
        share_l1_chain(source.l1(), &l1);
        l1
    };
    let mut switches = Vec::new();
    for (req, expected) in &decided {
        let target = fx.schedule().switch_target(req.height.value());
        let committed = app.state().unwrap().clone();
        app.l1().state().calls.clear();
        let response = finalize(&mut app, req.clone()).await.unwrap();
        assert_eq!(&response, expected);
        assert!(only_anchor_confirmations(&app.l1().calls()), "{:?}", app.l1().calls());
        let pending = app.pending.as_ref().unwrap().clone();
        let hash = pending.parent.hash;
        assert_eq!(app.engine().state().chain[&pending.last_height].hash_slow(), hash);
        if let Some(target) = target {
            switches.push(target);
            assert!(!committed.committees.contains_key(&target));
            assert!(pending.committees.contains_key(&target));
            assert_eq!(response.validator_updates.is_empty(), target != 2);
            if target == 2 {
                assert_eq!(pending.committees[&target].members.len(), 4);
                assert_eq!(committed.committees[&(target - 1)].members.len(), 3);
            }
            // The EL has executed the switch while the durable store still holds its parent.
            let engine = app.engine().reopen();
            drop(app);
            app = app_with(
                restarted_l1(),
                engine,
                fx.params.clone(),
                dir.path(),
                AppOptions::default(),
            );
            assert_eq!(app.state(), Some(&committed));
            info(&mut app).await.unwrap();
            app.l1().state().calls.clear();
            assert_eq!(finalize(&mut app, req.clone()).await.unwrap(), response);
            assert_eq!(app.pending.as_ref(), Some(&pending));
            let calls = app.l1().calls();
            assert!(
                only_anchor_confirmations(&calls),
                "switch replay reads no L1 state: {calls:?}"
            );
        }
        commit(&mut app).await.unwrap();
        assert_eq!(app.state(), Some(&pending));
        if target.is_some() {
            // A crash after Commit reloads the incoming committee before the following height.
            let engine = app.engine().reopen();
            drop(app);
            app = app_with(
                restarted_l1(),
                engine,
                fx.params.clone(),
                dir.path(),
                AppOptions::default(),
            );
            assert_eq!(app.state(), Some(&pending));
            info(&mut app).await.unwrap();
            assert_eq!(app.engine().state().chain[&pending.last_height].hash_slow(), hash);
        }
    }
    assert_eq!(switches, (1..=epochs).collect::<Vec<_>>());
    println!(
        "ETNA_TRACE epochs={epochs} heights={} switches={} crashes={}",
        decided.len(),
        switches.len(),
        switches.len() * 2
    );
}

#[tokio::test]
async fn cached_verdict_is_bound_to_exact_proposal_bytes() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = forced_block(&fx, dir.path()).await;
    let (_, req) = judge(&mut app, &env).await;
    let replacement = with_extra_transaction(env);
    let mut final_req = finalize_req(&req);
    final_req.txs = vec![replacement.encode().0];
    finalize(&mut app, final_req).await.unwrap();
    assert_eq!(app.pending.as_ref().unwrap().parent.hash, replacement.block.header.hash_slow());
}

/// Cold canonical skips must preserve the consumed cursor through crash replay and Commit.
#[tokio::test]
async fn cold_canonical_skip_advances_cursor_on_replay_and_persists_after_commit() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    step(&mut app).await; // A persisted parent with a real canonical EL header for restart.
    let mut env = forced_block_on(&fx, &app);
    env.block.transactions.clear();
    env.block.header.transactions_root = alloy_consensus::EMPTY_ROOT_HASH;
    let parent = app.state().unwrap().clone();
    let req = cold_req(&app, &env);
    app.engine().state().build_script.push_back(Ok(env.block.clone()));
    let first = finalize(&mut app, req.clone()).await.unwrap();
    assert_eq!(app.state().unwrap().forced_cursor, 0, "Finalize has not committed");
    assert_eq!(app.pending.as_ref().unwrap().forced_cursor, 1, "cold canonical skip consumes once");
    let engine = app.engine().reopen();
    drop(app); // Crash after Finalize, before Commit; the persisted cursor is still zero.
    let l1 = fx.l1();
    plant_due_entry(&fx, &l1, 66, fx.inbox.clone());
    let mut replay = App::new(
        l1,
        engine,
        fx.params.clone(),
        Store::volatile(dir.path().into()),
        AppOptions::default(),
    )
    .unwrap();
    assert_eq!(replay.state(), Some(&parent));
    info(&mut replay).await.unwrap();
    replay.engine().state().build_script.push_back(Ok(env.block.clone()));
    let again = finalize(&mut replay, req).await.unwrap();
    assert_eq!(again, first);
    assert_eq!(replay.pending.as_ref().unwrap().forced_cursor, 1);
    commit(&mut replay).await.unwrap();
    assert_eq!(replay.state().unwrap().forced_cursor, 1);
    let reopened = App::new(
        fx.l1(),
        replay.engine().reopen(),
        fx.params.clone(),
        Store::volatile(dir.path().into()),
        AppOptions::default(),
    )
    .unwrap();
    assert_eq!(reopened.state().unwrap().forced_cursor, 1);
}

/// Hot cached consumption and cold replay must commit the same canonical-skip cursor.
#[tokio::test]
async fn hot_canonical_skip_matches_cold_replay_and_persists_after_commit() {
    let fx = Fixture::genesis(1);
    let hot_dir = tempfile::tempdir().unwrap();
    let cold_dir = tempfile::tempdir().unwrap();
    let mut hot = initialized(&fx, hot_dir.path()).await;
    let mut cold = initialized(&fx, cold_dir.path()).await;
    step(&mut hot).await;
    step(&mut cold).await;
    assert_eq!(hot.state(), cold.state());
    let mut env = forced_block_on(&fx, &hot);
    plant_due_entry(&fx, cold.l1(), 66, fx.inbox.clone());
    env.block.transactions.clear();
    env.block.header.transactions_root = alloy_consensus::EMPTY_ROOT_HASH;
    hot.engine().state().build_script.push_back(Ok(env.block.clone()));
    let (verdict, req) = judge(&mut hot, &env).await;
    assert_eq!(verdict, response::ProcessProposal::Accept, "halt = {:?}", hot.halt);
    assert!(matches!(
        hot.verdicts.get(&req.hash).unwrap().decision,
        crate::forced::ForcedDecision::NeedsSkip { index: 0, .. }
    ));
    let before = hot.engine().calls().len();
    let response = finalize(&mut hot, finalize_req(&req)).await.unwrap();
    assert_eq!(hot.state().unwrap().forced_cursor, 0, "Finalize has not committed");
    assert_eq!(hot.pending.as_ref().unwrap().forced_cursor, 1, "hot canonical skip consumes once");
    let hash = env.block.header.hash_slow();
    assert_eq!(
        engine_calls_since(&hot, before),
        [EngineCall::Forkchoice {
            head: hash,
            safe: hash,
            finalized: fx.inbox.last_checkpoint_hash,
        }],
        "hot Finalize must use ProcessProposal's cached consumption without rebuilding"
    );
    assert!(hot.verdicts.get(&req.hash).is_none());
    cold.engine().state().build_script.push_back(Ok(env.block.clone()));
    assert!(cold.verdicts.is_empty(), "cold replay has no ProcessProposal verdict");
    assert_eq!(finalize(&mut cold, finalize_req(&req)).await.unwrap(), response);
    assert_eq!(hot.pending, cold.pending, "complete hot and cold successor states match");
    commit(&mut hot).await.unwrap();
    commit(&mut cold).await.unwrap();
    assert_eq!(hot.state(), cold.state());
    assert_eq!(hot.state().unwrap().forced_cursor, 1);
    let expected = hot.state().unwrap().clone();
    let mut reopened = App::new(
        fx.l1(),
        hot.engine().reopen(),
        fx.params.clone(),
        Store::volatile(hot_dir.path().into()),
        AppOptions::default(),
    )
    .unwrap();
    assert_eq!(reopened.state(), Some(&expected));
    info(&mut reopened).await.unwrap();
    assert_eq!(reopened.state().unwrap().forced_cursor, 1);
}

/// A cancelled historical singleton probe cannot stage or durably consume a cursor.
#[tokio::test(start_paused = true)]
async fn cancelled_canonical_skip_preserves_pending_and_durable_cursor() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = skipped_block(&fx, dir.path()).await;
    let committed = app.state().unwrap().clone();
    let durable_before = Store::new(dir.path().into()).load().unwrap();
    let req = cold_req(&app, &env);
    app.engine().state().delay_script.push_back(Duration::from_secs(60));
    assert!(
        tokio::time::timeout(Duration::from_millis(1), finalize(&mut app, req.clone()))
            .await
            .is_err()
    );
    assert!(app.pending.is_none());
    assert_eq!(app.state(), Some(&committed));
    assert_eq!(Store::new(dir.path().into()).load().unwrap(), durable_before);
    app.engine().state().delay_script.clear();
    app.engine().state().build_script.push_back(Ok(env.block.clone()));
    finalize(&mut app, req).await.unwrap();
    assert_eq!(app.pending.as_ref().unwrap().forced_cursor, 1);
    assert_eq!(app.state().unwrap().forced_cursor, 0);
    commit(&mut app).await.unwrap();
    assert_eq!(app.state().unwrap().forced_cursor, 1);
}

/// Checked cache fields must match freshly authenticated candidate facts before reuse.
#[tokio::test]
async fn canonical_skip_cache_misses_when_checked_context_fields_change() {
    for changed in ["cursor", "header", "anchor", "decision"] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        step(&mut app).await;
        let mut env = forced_block_on(&fx, &app);
        env.block.transactions.clear();
        env.block.header.transactions_root = alloy_consensus::EMPTY_ROOT_HASH;
        app.engine().state().build_script.push_back(Ok(env.block.clone()));
        let (verdict, req) = judge(&mut app, &env).await;
        assert_eq!(verdict, response::ProcessProposal::Accept);
        let mut stale = app.verdicts.remove(&req.hash).unwrap();
        match changed {
            "cursor" => stale.parent_cursor += 1,
            "header" => stale.expected.timestamp += 1,
            "anchor" => stale.anchor.hash = B256::repeat_byte(0xa5),
            "decision" => stale.decision = crate::forced::ForcedDecision::Ordinary,
            _ => unreachable!(),
        }
        app.verdicts.insert(req.hash, stale);
        app.engine().state().build_script.push_back(Ok(env.block.clone()));
        let before = app.engine().calls().len();
        finalize(&mut app, finalize_req(&req)).await.unwrap();
        assert!(
            engine_calls_since(&app, before)
                .iter()
                .any(|call| matches!(call, EngineCall::BuildBlock { .. })),
            "{changed}"
        );
        assert_eq!(app.pending.as_ref().unwrap().forced_cursor, 1, "{changed}");
        assert_eq!(app.state().unwrap().forced_cursor, 0, "{changed}");
    }
}

/// Payout metadata is installed for its epoch even when the CometBFT set stays identical.
#[tokio::test]
async fn payout_only_switch_installs_and_persists_epoch_metadata_without_native_updates() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let schedule = fx.schedule();
    let switch = schedule.h_first(4) - 2;
    let old = sample_entries(3);
    let mut new = old.clone();
    new[0].reward_recipient = alloy_primitives::Address::repeat_byte(0x88);
    let derive = |entries, epoch, cutoff, checkpoint| {
        let snapshot = Snapshot { checkpoint_index: checkpoint, l1_block: cutoff, entries };
        let (record, members) =
            committee::derive(&snapshot, cutoff, epoch, &schedule, &fx.params).unwrap();
        CommitteeState { record, members }
    };
    let previous = derive(old.clone(), 3, 64, 0);
    let expected = derive(new.clone(), 4, 76, 1);
    let landed = fx.inbox_with(switch - 5);
    let changed = RegistryStorage { checkpoints: vec![(63, old.clone()), (71, new.clone())] };
    fx.advance_l1(app.l1(), 76, &landed, &changed);
    let anchor = fx.anchor_state(app.l1(), 76);
    jump(&mut app, switch - 1, anchor, &[(3, previous.clone())]);
    let env = propose(&mut app).await;
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept);
    let out = finalize(&mut app, finalize_req(&req)).await.unwrap();
    assert!(out.validator_updates.is_empty());
    assert_eq!(app.pending.as_ref().unwrap().committees[&4], expected);
    commit(&mut app).await.unwrap();
    let mut reopened = fx.app(dir.path());
    let state = reopened.state().unwrap();
    let recipient_at = |height| {
        state.committees[&schedule.epoch_of(height)]
            .members
            .iter()
            .find(|m| m.pubkey == old[0].pubkey)
            .unwrap()
            .reward_recipient
    };
    assert_eq!(recipient_at(schedule.h_first(4) - 1), old[0].reward_recipient);
    assert_eq!(recipient_at(schedule.h_first(4)), new[0].reward_recipient);
    assert_eq!(state.committees[&4], expected);
    fx.advance_l1(reopened.l1(), schedule.l1_first(4), &landed, &changed);
    assert_eq!(committee::validator_updates(&previous.members, &expected.members), vec![]);
    // The same key keeps its old payout through the last old-epoch block, then switches
    // after persistence/reopen despite no native validator changes.
    for recipient in [old[0].reward_recipient, new[0].reward_recipient] {
        let env = propose(&mut reopened).await;
        assert_eq!(env.block.header.beneficiary, recipient);
        let mut wrong = env.clone();
        wrong.block.header.beneficiary = if recipient == old[0].reward_recipient {
            new[0].reward_recipient
        } else {
            old[0].reward_recipient
        };
        assert_eq!(judge(&mut reopened, &wrong).await.0, response::ProcessProposal::Reject);
        let (resp, req) = judge(&mut reopened, &env).await;
        assert_eq!(resp, response::ProcessProposal::Accept);
        // Exercise the cold path's epoch lookup independently of its hot verdict.
        reopened.verdicts.clear();
        finalize(&mut reopened, finalize_req(&req)).await.unwrap();
        assert!(!reopened.decided_live);
        commit(&mut reopened).await.unwrap();
    }
}
