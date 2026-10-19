//! Startup checkpoint trust is distinct from consensus progress.
use std::time::Duration;

use super::{
    proposal::{bft_time, commit, finalize, finalize_req, hand_envelope, next_height, process_req},
    *,
};
use crate::{
    app::trust::TrustPhase,
    l1::L1Error,
    test_utils::{InboxStorage, L1Call},
};
use alloy_primitives::B256;

/// Provides real proofs at the exact finalized snapshot, without subtracting extra depth.
fn target(app: &App<MockL1, MockEngine>, fx: &Fixture, height: u64, hash: B256) {
    let inbox = InboxStorage {
        last_checkpoint_height: height,
        last_checkpoint_hash: hash,
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 100, &inbox, &fx.registry);
    app.l1().set_finalized(100);
}

#[tokio::test]
async fn trust_query_is_closed_and_available_before_init() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let response = query(&mut app, "/trust").await;
    assert!(response.code.is_ok(), "trust status must be available before init");
    let value: serde_json::Value = serde_json::from_slice(&response.value).unwrap();
    assert_eq!(value["schema_version"], 1);
    assert_eq!(value["trust_ready"], false);
    assert_eq!(value["syncing"], true);
    assert!(value["chain_id"].is_null());
    assert!(value["trusted_consensus_head"].is_null());
}

#[tokio::test]
async fn ready_requires_authenticated_checkpoint_and_durable_genesis() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    assert_eq!(app.trust.snapshot().target.unwrap().l1_number, 100);
    init_chain(&mut app, fx.request.clone()).await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().trust_ready);
    assert_eq!(app.trust.snapshot().trusted_consensus_head.unwrap().hash, fx.genesis_hash());
    assert!(Store::volatile(dir.path().into()).load().unwrap().is_some());
    assert!(
        app.l1()
            .calls()
            .iter()
            .any(|call| matches!(call, L1Call::AccountWitness { block: 100, .. }))
    );
    assert!(
        !app.l1()
            .calls()
            .iter()
            .any(|call| matches!(call, L1Call::AccountWitness { block: 98, .. }))
    );
}

#[tokio::test]
async fn future_target_allows_info_and_replay_but_finalize_does_not_unlock() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, 1, hash);
    app.refresh_trust().await.unwrap();
    assert_eq!(app.trust.snapshot().phase, TrustPhase::CatchingUp);
    assert_eq!(
        tokio::time::timeout(Duration::from_secs(1), info(&mut app))
            .await
            .unwrap()
            .unwrap()
            .last_block_height
            .value(),
        0
    );
    let req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    assert!(app.engine().calls().iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, safe, finalized } if *head == hash && safe.is_zero() && *finalized == fx.genesis_hash())));
    commit(&mut app).await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().trust_ready);
    assert_eq!(Store::volatile(dir.path().into()).load().unwrap().unwrap().parent.hash, hash);
}

#[tokio::test]
async fn conflicting_decided_checkpoint_halts_before_settle_or_pending() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 1, B256::repeat_byte(7));
    app.refresh_trust().await.unwrap();
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
    let before = app.engine().calls().len();
    let error = finalize(&mut app, finalize_req(&req)).await.unwrap_err();
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
    assert!(error.to_string().contains("checkpoint hash mismatch"), "{error}");
    assert!(app.pending.is_none());
    assert_eq!(app.engine().calls().len(), before);
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    assert!(!app.trust.begin_session().trust_ready);
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
}

#[tokio::test]
async fn proof_errors_and_timeout_stay_closed_and_retry_recovers_without_blocks() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    app.l1().state().proof_fail = Some(L1Error::Rpc("unavailable".into()));
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    app.l1().state().proof_fail = None;
    app.opts.l1_timeout = Duration::from_millis(1);
    app.l1().state().proof_delay = Some(Duration::from_millis(20));
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    app.l1().state().proof_delay = None;
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().trust_ready);
}

#[tokio::test]
async fn checkpoint_proof_root_canonical_status_and_generation_are_authenticated() {
    for case in 0..5 {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        let mut inbox = fx.inbox.clone();
        if case == 0 {
            inbox.status = 0;
        }
        if case == 1 {
            inbox.last_checkpoint_hash = B256::ZERO;
        }
        if case == 2 {
            inbox.recovery_generation += 1;
        }
        fx.plant_l1_block(app.l1(), 100, &inbox, &fx.registry);
        app.l1().set_finalized(100);
        if case == 3 {
            app.l1().state().canonical_script.push_back(Ok(B256::repeat_byte(9)));
        }
        if case == 4 {
            let header = crate::test_utils::l1_header(100, Fixture::l1_timestamp(100));
            app.l1().insert_header(crate::l1::RawL1Header::from(&header));
        }
        assert!(matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(_))), "case {case}");
        assert!(!app.trust.snapshot().trust_ready);
    }
}

#[tokio::test]
async fn target_is_pinned_until_match_then_refresh_can_extend_catchup() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, 1, hash);
    app.refresh_trust().await.unwrap();
    let inbox = InboxStorage {
        last_checkpoint_height: 2,
        last_checkpoint_hash: B256::repeat_byte(8),
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 101, &inbox, &fx.registry);
    app.l1().set_finalized(101);
    app.refresh_trust().await.unwrap();
    assert_eq!(app.trust.snapshot().target.unwrap().height, 1);
    let req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(!snapshot.trust_ready);
    assert_eq!(snapshot.target.unwrap().height, 2);
}

#[tokio::test]
async fn restart_checks_contiguous_ancestry_not_presence_of_genuine_checkpoint() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().trust_ready);
    let mut broken = env.block.header.clone();
    broken.parent_hash = B256::repeat_byte(3);
    let mut state = app.state().unwrap().clone();
    state.parent.hash = broken.hash_slow();
    Store::volatile(dir.path().into()).save(&state).unwrap();
    let engine = app.engine().reopen();
    engine.state().chain.insert(1, broken);
    let mut restarted =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());
    target(&restarted, &fx, 0, fx.genesis_hash());
    assert!(!restarted.trust.snapshot().trust_ready);
    assert_ne!(restarted.trust.snapshot().session_id, app.trust.snapshot().session_id);
    assert!(matches!(restarted.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
}

#[tokio::test]
async fn missing_ancestry_retries_and_sessions_revoke_ready_without_stale_reuse() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    let header = app.engine().state().chain.remove(&0).unwrap();
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    app.engine().state().chain.insert(0, header);
    app.refresh_trust().await.unwrap();
    let old = app.trust.snapshot();
    assert!(old.trust_ready);
    let new = app.trust.begin_session();
    assert!(!new.trust_ready);
    assert_ne!(new.session_id, old.session_id);
    assert!(!app.trust.check_session(&old.session_id).trust_ready);
    app.refresh_trust().await.unwrap();
    assert!(app.trust.check_session(&new.session_id).trust_ready);
    assert!(!app.trust.check_session(&old.session_id).trust_ready);
    let handle = app.trust_handle();
    drop(app);
    assert!(!handle.snapshot().trust_ready);
}

#[tokio::test]
async fn begin_session_during_io_cannot_receive_stale_ready_result() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    app.l1().state().proof_delay = Some(Duration::from_millis(20));
    let handle = app.trust_handle();
    let (result, session) = tokio::join!(app.refresh_trust(), async {
        tokio::time::sleep(Duration::from_millis(5)).await;
        handle.begin_session()
    });
    result.unwrap();
    assert!(!handle.check_session(&session.session_id).trust_ready);
    app.l1().state().proof_delay = None;
    app.refresh_trust().await.unwrap();
    assert!(handle.check_session(&session.session_id).trust_ready);
}

#[tokio::test]
async fn background_retry_recovers_genesis_without_signed_blocks() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    let l1 = app.l1.clone();
    l1.state().proof_fail = Some(L1Error::Rpc("temporary outage".into()));
    let trust = app.trust_handle();
    let (_service, worker) = crate::server::AppService::spawn(app, |_: &str| {});
    tokio::time::sleep(Duration::from_millis(30)).await;
    assert!(!trust.snapshot().trust_ready);
    l1.state().proof_fail = None;
    tokio::time::timeout(Duration::from_secs(3), async {
        while !trust.snapshot().trust_ready {
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    assert_eq!(trust.snapshot().committed_head.unwrap().height, 0);
    worker.abort();
    let _ = worker.await;
    assert!(!trust.snapshot().trust_ready);
}

#[tokio::test]
async fn failed_commit_never_authorizes_and_keeps_original_durable_head() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, 1, hash);
    app.refresh_trust().await.unwrap();
    let req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    // An occupied temp path causes the actual atomic store write to fail.
    std::fs::create_dir(dir.path().join(crate::store::TMP_FILE)).unwrap();
    assert!(matches!(commit(&mut app).await, Err(AbciError::Store(_))));
    assert!(!app.trust.snapshot().trust_ready);
    assert_eq!(app.trust.snapshot().committed_head.unwrap().height, 0);
    assert_eq!(app.state().unwrap().last_height, 0);
    let saved: crate::store::AppState =
        serde_json::from_slice(&std::fs::read(dir.path().join(crate::store::STATE_FILE)).unwrap())
            .unwrap();
    assert_eq!(saved.last_height, 0);
}

#[tokio::test]
async fn higher_generation_proposal_revokes_even_without_finalize_error() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().trust_ready);
    let mut inbox = fx.inbox.clone();
    inbox.recovery_generation = 1;
    fx.plant_l1_block(app.l1(), 101, &inbox, &fx.registry);
    app.l1().set_finalized(101 + fx.params.l1_finality_extra_depth);
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 101)), None);
    let (response, _) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(response, response::ProcessProposal::Reject);
    assert!(app.superseded);
    assert!(!app.trust.snapshot().trust_ready);
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
}

#[tokio::test]
async fn refreshed_lower_checkpoint_never_downgrades_pinned_target() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, 1, hash);
    app.refresh_trust().await.unwrap();
    let req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    fx.plant_l1_block(app.l1(), 101, &fx.inbox, &fx.registry);
    app.l1().set_finalized(101);
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    assert_eq!(app.trust.snapshot().target.unwrap().height, 1);
}

#[tokio::test]
async fn reconnect_never_forgets_an_authenticated_unreached_checkpoint() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 2, B256::repeat_byte(8));
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    fx.plant_l1_block(app.l1(), 101, &fx.inbox, &fx.registry);
    app.l1().set_finalized(101);
    app.trust.begin_session();
    app.refresh_trust().await.unwrap();
    assert!(
        !app.trust.snapshot().trust_ready,
        "reconnect must not lower an unreached authenticated checkpoint"
    );
}

#[tokio::test]
async fn initial_l1_outage_does_not_permanently_poison_genesis_trust() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    app.l1().state().fail = Some(L1Error::Rpc("startup outage".into()));
    assert!(init_chain(&mut app, fx.request.clone()).await.is_err());
    assert!(!app.trust.snapshot().trust_ready);
    app.l1().state().fail = None;
    target(&app, &fx, 0, fx.genesis_hash());
    init_chain(&mut app, fx.request.clone()).await.unwrap();
    app.refresh_trust().await.unwrap();
    assert!(
        app.trust.snapshot().trust_ready,
        "successful startup retry must recover without a signed block"
    );
}

#[tokio::test]
async fn closed_reconnect_recovers_only_committed_head_without_jumping_to_future_target() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 2, B256::repeat_byte(8));
    app.engine().state().chain.remove(&0);
    let before = app.engine().calls().len();
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    assert!(app.engine().calls()[before..].iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, safe, finalized } if *head == fx.genesis_hash() && safe.is_zero() && finalized.is_zero())));
    assert!(!app.engine().calls()[before..].iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, .. } if *head == B256::repeat_byte(8))));
}

#[tokio::test]
async fn ready_session_keeps_fixed_target_and_labels_valid_candidates_safe() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().trust_ready);
    let inbox = InboxStorage {
        last_checkpoint_height: 2,
        last_checkpoint_hash: B256::repeat_byte(8),
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 101, &inbox, &fx.registry);
    app.l1().set_finalized(101);
    let reads = app.l1().calls().len();
    app.refresh_trust().await.unwrap();
    assert_eq!(app.l1().calls().len(), reads, "ready sessions do not chase moving finality");
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let hash = env.block.header.hash_slow();
    let req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    assert!(app.engine().calls().iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, safe, finalized } if *head == hash && *safe == hash && *finalized == fx.genesis_hash())));
    commit(&mut app).await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(snapshot.trust_ready);
    assert_eq!(snapshot.target.unwrap().height, 0);
    assert_eq!(snapshot.trusted_consensus_head.unwrap().hash, hash);
}

#[tokio::test]
async fn restart_equal_and_above_checkpoint_require_fresh_proof_and_linked_history() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for i in 0..2 {
        let anchor = (i == 0).then(|| fx.anchor_witness(app.l1(), fx.genesis.l1_0));
        let env = hand_envelope(&app, anchor, None);
        let req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
        finalize(&mut app, finalize_req(&req)).await.unwrap();
        commit(&mut app).await.unwrap();
    }
    for checkpoint in [1, 2] {
        let hash = app.engine().state().chain[&checkpoint].hash_slow();
        let mut restarted = app_with(
            fx.l1(),
            app.engine().reopen(),
            fx.params.clone(),
            dir.path(),
            AppOptions::default(),
        );
        target(&restarted, &fx, checkpoint, hash);
        assert!(!restarted.trust.snapshot().trust_ready);
        restarted.refresh_trust().await.unwrap();
        assert!(restarted.trust.snapshot().trust_ready);
        assert_eq!(restarted.trust.snapshot().committed_head.unwrap().height, 2);
    }
    let mut restarted = app_with(
        fx.l1(),
        app.engine().reopen(),
        fx.params.clone(),
        dir.path(),
        AppOptions::default(),
    );
    target(&restarted, &fx, 0, fx.genesis_hash());
    let missing = restarted.engine().state().chain.remove(&1).unwrap();
    restarted.refresh_trust().await.unwrap();
    assert!(
        !restarted.trust.snapshot().trust_ready,
        "missing intermediate history does not establish ancestry"
    );
    restarted.engine().state().chain.insert(1, missing);
    restarted.refresh_trust().await.unwrap();
    assert!(restarted.trust.snapshot().trust_ready);
    let json: serde_json::Value =
        serde_json::from_slice(&std::fs::read(dir.path().join(crate::store::STATE_FILE)).unwrap())
            .unwrap();
    assert!(
        json.get("trust_ready").is_none() &&
            json.get("target").is_none() &&
            json.get("session_id").is_none()
    );
}

#[tokio::test]
async fn wrong_account_and_slot_set_in_latest_checkpoint_proofs_halt() {
    for wrong_account in [true, false] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        target(&app, &fx, 0, fx.genesis_hash());
        let mut proof = fx.anchor_witness(app.l1(), 100).inbox;
        if wrong_account {
            proof.address = alloy_primitives::Address::repeat_byte(0x99);
        } else {
            proof.storage.pop();
        }
        app.l1().state().proof_override = Some(proof);
        let error = app.refresh_trust().await.unwrap_err();
        assert!(matches!(error, AbciError::SafetyHalt(_)));
        assert!(error.to_string().contains("invalid checkpoint proof"));
        assert!(!app.trust.snapshot().trust_ready);
    }
}
