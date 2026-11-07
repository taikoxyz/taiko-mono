//! Startup checkpoint trust is distinct from consensus progress.
use std::time::Duration;

use super::{
    proposal::{bft_time, commit, finalize, finalize_req, hand_envelope, next_height, process_req},
    *,
};
use crate::{
    GRID_INTERVAL,
    app::trust::TrustPhase,
    envelope::EtnaEnvelope,
    l1::L1Error,
    store::Record,
    test_utils::{InboxStorage, L1Call},
    valstate::{ValState, spec_41a_state, stock_lookup},
};
use alloy_primitives::{B256, keccak256};

/// Provides real proofs at the exact finalized snapshot. A committed `height` lands with the
/// app's own Comet and validator-state hashes, the next height with those [`next_envelope`]
/// decides, and any other height with placeholders.
fn target(app: &App<MockL1, MockEngine>, fx: &Fixture, height: u64, hash: B256) {
    let next = || height == next_height(app);
    let inbox = InboxStorage {
        last_checkpoint_height: height,
        last_checkpoint_hash: hash,
        last_checkpoint_comet_hash: if height == 0 {
            B256::ZERO
        } else {
            app.store.load_comet_hash(height).unwrap().unwrap_or_else(|| {
                if next() {
                    let env = next_envelope(app, fx);
                    B256::from_slice(
                        process_req(app, height, bft_time(app), vec![env.encode()]).hash.as_bytes(),
                    )
                } else {
                    B256::repeat_byte(8)
                }
            })
        },
        last_checkpoint_val_state_hash: if height == 0 {
            B256::ZERO
        } else if next() {
            next_val_state_hash(app)
        } else {
            app.val_state_preimage(height).map_or(B256::repeat_byte(8), keccak256)
        },
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 100, &inbox, &fx.registry);
    app.l1().set_finalized(100);
}

/// The envelope the tests decide at the next height: the first block after genesis carries the
/// genesis anchor's witness, later ones inherit the committed anchor.
fn next_envelope(app: &App<MockL1, MockEngine>, fx: &Fixture) -> EtnaEnvelope {
    let first = app.state().expect("initialized").last_height == 0;
    hand_envelope(app, first.then(|| fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None)
}

/// The validator-state hash the app holds after the committed grid `height`.
fn val_state_hash(app: &App<MockL1, MockEngine>, height: u64) -> B256 {
    keccak256(app.val_state_preimage(height).expect("a retained grid height"))
}

/// The validator-state hash after the next height, which changes no validator in these tests.
fn next_val_state_hash(app: &App<MockL1, MockEngine>) -> B256 {
    app.state().expect("initialized").val_state.advance(&[]).expect("advances").hash()
}

/// Commits blocks up to `height`, the first one anchored at the genesis L1 block.
async fn commit_to(app: &mut App<MockL1, MockEngine>, fx: &Fixture, height: u64) {
    while app.state().expect("initialized").last_height < height {
        let first = app.state().expect("initialized").last_height == 0;
        commit_next(app, fx, first.then_some(fx.genesis.l1_0)).await;
    }
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
    commit_to(&mut app, &fx, GRID_INTERVAL - 1).await;
    let env = next_envelope(&app, &fx);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, GRID_INTERVAL, hash);
    app.refresh_trust().await.unwrap();
    assert_eq!(app.trust.snapshot().phase, TrustPhase::CatchingUp);
    assert_eq!(
        tokio::time::timeout(Duration::from_secs(1), info(&mut app))
            .await
            .unwrap()
            .unwrap()
            .last_block_height
            .value(),
        GRID_INTERVAL - 1
    );
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
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
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
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
            inbox.last_checkpoint_hash = B256::repeat_byte(0xde);
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
    commit_to(&mut app, &fx, GRID_INTERVAL - 1).await;
    let env = next_envelope(&app, &fx);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, GRID_INTERVAL, hash);
    app.refresh_trust().await.unwrap();
    let inbox = InboxStorage {
        last_checkpoint_height: 2 * GRID_INTERVAL,
        last_checkpoint_hash: B256::repeat_byte(8),
        last_checkpoint_comet_hash: B256::repeat_byte(8),
        last_checkpoint_val_state_hash: B256::repeat_byte(8),
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 101, &inbox, &fx.registry);
    app.l1().set_finalized(101);
    app.refresh_trust().await.unwrap();
    assert_eq!(app.trust.snapshot().target.unwrap().height, GRID_INTERVAL);
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(!snapshot.trust_ready);
    assert_eq!(snapshot.target.unwrap().height, 2 * GRID_INTERVAL);
}

#[tokio::test]
async fn restart_checks_contiguous_ancestry_not_presence_of_genuine_checkpoint() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
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
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
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
    app.l1().set_finalized(101);
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 101)), None);
    let (response, _) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(response, response::ProcessProposal::Reject);
    assert!(app.superseded);
    assert!(!app.trust.snapshot().trust_ready);
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    assert!(
        dir.path().join("generation-superseded.json").is_file(),
        "expected supersession must retain typed evidence"
    );
    assert!(app.store.fatal_evidence().unwrap().is_some());
}

#[tokio::test]
async fn generation_zero_startup_supersession_retains_typed_recovery_evidence() {
    use crate::recovery::supersession::{SUPERSESSION_FILE, SupersessionEvidence};
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);
    let original = std::fs::read(dir.path().join(crate::store::STATE_FILE)).unwrap();
    let mut app = fx.app(dir.path());
    let inbox = InboxStorage { recovery_generation: 1, ..fx.inbox.clone() };
    fx.plant_l1_block(app.l1(), 101, &inbox, &fx.registry);
    app.l1().set_finalized(101);
    assert!(matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    let evidence: SupersessionEvidence = serde_json::from_slice(
        &std::fs::read(dir.path().join(SUPERSESSION_FILE))
            .expect("startup supersession must be acknowledgeable by authenticated recovery"),
    )
    .unwrap();
    assert_eq!((evidence.previous_generation, evidence.current_generation), (0, 1));
    assert!(
        evidence
            .validates(&original, &std::fs::read(dir.path().join("fatal-evidence.txt")).unwrap(),)
    );
    assert_eq!(std::fs::read(dir.path().join(crate::store::STATE_FILE)).unwrap(), original);
}

#[tokio::test]
async fn trust_forkchoice_invalid_state_halts_but_transient_replies_retry() {
    for code in [-38002, -32603, -32000] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        target(&app, &fx, 0, fx.genesis_hash());
        app.engine().state().chain.clear();
        app.engine().state().forkchoice_script.push_back(Err(crate::EngineError::ErrorReply {
            call: "engine_forkchoiceUpdatedV3".into(),
            code,
            message: "fixture refusal".into(),
        }));
        let result = app.refresh_trust().await;
        if code == -38002 {
            assert!(matches!(result, Err(AbciError::SafetyHalt(_))), "{result:?}");
            assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
            assert!(dir.path().join("fatal-evidence.txt").is_file());
        } else {
            result.unwrap();
            assert!(!app.trust.snapshot().trust_ready);
            assert!(!dir.path().join("fatal-evidence.txt").exists());
            for _ in 0..2 {
                app.refresh_trust().await.unwrap();
            }
            assert!(app.trust.snapshot().trust_ready, "code {code}");
        }
    }
}

#[tokio::test]
async fn refreshed_lower_checkpoint_never_downgrades_pinned_target() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, GRID_INTERVAL - 1).await;
    let env = next_envelope(&app, &fx);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, GRID_INTERVAL, hash);
    app.refresh_trust().await.unwrap();
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    fx.plant_l1_block(app.l1(), 101, &fx.inbox, &fx.registry);
    app.l1().set_finalized(101);
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);
    assert_eq!(app.trust.snapshot().target.unwrap().height, GRID_INTERVAL);
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

#[tokio::test(start_paused = true)]
async fn initial_l1_outage_does_not_permanently_poison_genesis_trust() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    app.l1().state().fail = Some(L1Error::Rpc("startup outage".into()));
    assert!(
        tokio::time::timeout(Duration::from_secs(20), init_chain(&mut app, fx.request.clone()),)
            .await
            .is_err()
    );
    assert!(!app.trust.snapshot().trust_ready);
    assert!(!dir.path().join("fatal-evidence.txt").exists());
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
        last_checkpoint_comet_hash: B256::repeat_byte(8),
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 101, &inbox, &fx.registry);
    app.l1().set_finalized(101);
    let reads = app.l1().calls().len();
    app.refresh_trust().await.unwrap();
    assert_eq!(app.l1().calls().len(), reads, "ready sessions do not chase moving finality");
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let hash = env.block.header.hash_slow();
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
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
    commit_to(&mut app, &fx, 2 * GRID_INTERVAL).await;
    for checkpoint in [GRID_INTERVAL, 2 * GRID_INTERVAL] {
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
        assert_eq!(restarted.trust.snapshot().committed_head.unwrap().height, 2 * GRID_INTERVAL);
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

#[tokio::test]
async fn typed_l1_adapter_integrity_errors_latch_halt_across_recovery_and_reconnect() {
    use crate::l1::header::L1HeaderError;
    let hash = B256::repeat_byte(9);
    let cases = [
        L1Error::ProofAddressMismatch {
            requested: alloy_primitives::Address::ZERO,
            got: alloy_primitives::Address::repeat_byte(1),
        },
        L1Error::ProofSlotMismatch { requested: vec![B256::ZERO], got: vec![hash] },
        L1Error::HeaderHashMismatch { number: 100, reported: hash, computed: B256::ZERO },
        L1Error::HeaderNumberMismatch { requested: 100, got: 99 },
        L1Error::MalformedHeader { number: 100, error: L1HeaderError::TooFewFields { got: 0 } },
        L1Error::MalformedResponse("header lacks number".into()),
    ];
    for error in cases {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        target(&app, &fx, 0, fx.genesis_hash());
        if matches!(error, L1Error::ProofAddressMismatch { .. } | L1Error::ProofSlotMismatch { .. })
        {
            app.l1().state().proof_fail = Some(error.clone());
        } else {
            app.l1().state().header_fail = Some(error.clone());
        }
        let result = app.refresh_trust().await;
        assert!(
            matches!(result, Err(AbciError::SafetyHalt(_))),
            "typed integrity failure must halt: {error}; got {result:?}"
        );
        assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
        let reason = app.trust.snapshot().reason;
        app.l1().state().proof_fail = None;
        app.l1().state().header_fail = None;
        app.trust.begin_session();
        app.refresh_trust().await.unwrap();
        assert!(!app.trust.snapshot().trust_ready);
        assert_eq!(app.trust.snapshot().reason, reason, "first integrity failure remains sticky");
    }
}

#[tokio::test]
async fn typed_engine_header_integrity_errors_latch_halt() {
    use crate::engine::EngineError;
    for error in [
        EngineError::HeaderHashMismatch {
            number: 0,
            reported: B256::ZERO,
            computed: B256::repeat_byte(1),
        },
        EngineError::HeaderNumberMismatch { requested: 0, got: 1 },
        EngineError::BadReply("header is the wrong shape".into()),
    ] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        target(&app, &fx, 0, fx.genesis_hash());
        app.engine().state().header_script.push_back(Err(error));
        assert!(matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
        app.trust.begin_session();
        app.refresh_trust().await.unwrap();
        assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    }
}

#[tokio::test]
async fn typed_source_unavailability_and_capability_errors_remain_retryable() {
    for error in [
        L1Error::Rpc("getProof unavailable".into()),
        L1Error::BlockNotFound(alloy_eips::BlockNumberOrTag::Number(100)),
        L1Error::UnknownHeaderFields { number: 100, fields: vec!["futureHeaderField".into()] },
    ] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        target(&app, &fx, 0, fx.genesis_hash());
        app.l1().state().header_fail = Some(error);
        app.refresh_trust().await.unwrap();
        assert!(!app.trust.snapshot().trust_ready);
        assert_ne!(app.trust.snapshot().phase, TrustPhase::Halted);
        app.l1().state().header_fail = None;
        app.refresh_trust().await.unwrap();
        assert!(app.trust.snapshot().trust_ready);
    }
}

#[tokio::test]
async fn stale_adapter_integrity_failure_does_not_stop_new_session_recovery() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    app.l1().state().header_fail = Some(L1Error::HeaderNumberMismatch { requested: 100, got: 99 });
    app.l1().state().delay = Some(Duration::from_millis(20));
    let l1 = app.l1.clone();
    let handle = app.trust_handle();
    let (result, current) = tokio::join!(app.refresh_trust(), async {
        // Wait until the old verification has definitely started, then allocate the new session
        // while that acquisition is suspended in its own-L1 call.
        while l1.state().in_flight == 0 {
            tokio::task::yield_now().await;
        }
        handle.begin_session()
    });
    result.expect("a stale fatal result must not terminate the app worker");
    assert_eq!(handle.snapshot().session_id, current.session_id);
    assert_eq!(handle.snapshot().phase, TrustPhase::Acquiring);
    app.l1().state().header_fail = None;
    app.l1().state().delay = None;
    app.refresh_trust().await.unwrap();
    assert!(handle.check_session(&current.session_id).trust_ready);
}

#[tokio::test]
async fn authenticated_genesis_landing_requires_zero_comet_hash() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let inbox =
        InboxStorage { last_checkpoint_comet_hash: B256::repeat_byte(0x77), ..fx.inbox.clone() };
    fx.plant_l1_block(app.l1(), 100, &inbox, &fx.registry);
    app.l1().set_finalized(100);
    assert!(matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
    assert!(!app.trust.snapshot().trust_ready);
}

#[tokio::test]
async fn committed_comet_history_is_required_and_survives_restart() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for i in 0..=GRID_INTERVAL {
        let anchor = (i == 0).then(|| fx.anchor_witness(app.l1(), fx.genesis.l1_0));
        let env = hand_envelope(&app, anchor, None);
        let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
        finalize(&mut app, finalize_req(&req)).await.unwrap();
        assert!(app.store.load_comet_hash(req.height.value()).unwrap().is_none());
        commit(&mut app).await.unwrap();
        assert_eq!(
            app.store.load_comet_hash(req.height.value()).unwrap(),
            Some(B256::from_slice(req.hash.as_bytes()))
        );
    }
    let comet = app.store.load_comet_hash(GRID_INTERVAL).unwrap().unwrap();
    let el = app.engine().state().chain[&GRID_INTERVAL].hash_slow();
    let mut restarted = app_with(
        fx.l1(),
        app.engine().reopen(),
        fx.params.clone(),
        dir.path(),
        AppOptions::default(),
    );
    target(&restarted, &fx, GRID_INTERVAL, el);
    let path = dir.path().join(format!("comet-hash-{GRID_INTERVAL}.json"));
    std::fs::remove_file(&path).unwrap();
    restarted.refresh_trust().await.unwrap();
    assert!(!restarted.trust.snapshot().trust_ready);
    assert!(restarted.trust.snapshot().reason.unwrap().contains("missing committed Comet"));
    restarted.store.save_comet_hash(GRID_INTERVAL, comet).unwrap();
    restarted.refresh_trust().await.unwrap();
    assert!(restarted.trust.snapshot().trust_ready);
    restarted.trust.begin_session();
    let inbox = InboxStorage {
        last_checkpoint_comet_hash: B256::repeat_byte(0xaa),
        ..landed(&restarted, &fx, GRID_INTERVAL)
    };
    fx.plant_l1_block(restarted.l1(), 101, &inbox, &fx.registry);
    restarted.l1().set_finalized(101);
    assert!(matches!(restarted.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
    assert!(restarted.store.fatal_evidence().unwrap().is_some());
    assert!(matches!(
        App::new(
            fx.l1(),
            app.engine().reopen(),
            fx.params.clone(),
            Store::volatile(dir.path().into()),
            AppOptions::default()
        ),
        Err(AbciError::SafetyHalt(_))
    ));
}

#[tokio::test]
async fn decided_comet_hash_mismatch_halts_before_settle_even_when_el_matches() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)), None);
    let inbox = InboxStorage {
        last_checkpoint_height: 1,
        last_checkpoint_hash: env.block.header.hash_slow(),
        last_checkpoint_comet_hash: B256::repeat_byte(0xaa),
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 100, &inbox, &fx.registry);
    app.l1().set_finalized(100);
    app.refresh_trust().await.unwrap();
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    let calls = app.engine().calls().len();
    assert!(matches!(finalize(&mut app, finalize_req(&req)).await, Err(AbciError::SafetyHalt(_))));
    assert!(app.pending.is_none());
    assert_eq!(app.engine().calls().len(), calls);
}

/// Commits the next block, anchored at L1 block `anchor` when given (else inheriting the
/// committed anchor); returns its Comet block ID.
async fn commit_next(app: &mut App<MockL1, MockEngine>, fx: &Fixture, anchor: Option<u64>) -> B256 {
    let witness = anchor.map(|number| fx.anchor_witness(app.l1(), number));
    let env = hand_envelope(app, witness, None);
    let req = process_req(app, next_height(app), bft_time(app), vec![env.encode()]);
    finalize(app, finalize_req(&req)).await.unwrap();
    commit(app).await.unwrap();
    B256::from_slice(req.hash.as_bytes())
}

/// The Inbox storage landing the committed `height` with the app's own EL, Comet and
/// validator-state hashes there.
fn landed(app: &App<MockL1, MockEngine>, fx: &Fixture, height: u64) -> InboxStorage {
    InboxStorage {
        last_checkpoint_comet_hash: app.store.load_comet_hash(height).unwrap().expect("committed"),
        last_checkpoint_val_state_hash: val_state_hash(app, height),
        ..fx.inbox_at_checkpoint(height, app.engine().state().chain[&height].hash_slow())
    }
}

/// Plants L1 block `number` landing the committed `height` (see [`landed`]), and makes it
/// final.
fn finalize_landing(app: &App<MockL1, MockEngine>, fx: &Fixture, number: u64, height: u64) {
    fx.advance_l1(app.l1(), number, &landed(app, fx, height), &fx.registry);
}

/// A checkpoint below the committed anchor's names pruned Comet history: while own finality
/// lags there, trust stays closed, and it opens once finality reaches the committed anchor.
#[tokio::test]
async fn lagging_own_finality_waits_for_a_checkpoint_with_retained_comet_history() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, 2 * GRID_INTERVAL).await;
    finalize_landing(&app, &fx, 65, GRID_INTERVAL);
    finalize_landing(&app, &fx, 66, 2 * GRID_INTERVAL);
    commit_next(&mut app, &fx, Some(66)).await;
    assert_eq!(
        app.store.load_comet_hash(GRID_INTERVAL).unwrap(),
        None,
        "below the anchored checkpoint"
    );

    app.l1().set_finalized(65);
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().trust_ready);

    app.l1().set_finalized(66);
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(snapshot.trust_ready, "{:?}", snapshot.reason);
    assert_eq!(snapshot.target.unwrap().height, 2 * GRID_INTERVAL);
}

/// A session target pinned before the committed anchor moved past it names pruned Comet
/// history: the next attempt acquires a current checkpoint instead of stalling on it.
#[tokio::test]
async fn pinned_target_below_the_comet_history_floor_is_reacquired() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, GRID_INTERVAL - 1).await;
    let env = next_envelope(&app, &fx);
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    let inbox = InboxStorage {
        last_checkpoint_comet_hash: B256::from_slice(req.hash.as_bytes()),
        last_checkpoint_val_state_hash: next_val_state_hash(&app),
        ..fx.inbox_at_checkpoint(GRID_INTERVAL, env.block.header.hash_slow())
    };
    fx.advance_l1(app.l1(), 65, &inbox, &fx.registry);
    app.refresh_trust().await.unwrap();
    let pinned = app.trust.snapshot().target.unwrap().height;
    assert_eq!(pinned, GRID_INTERVAL, "pinned above the head");
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    commit_to(&mut app, &fx, 2 * GRID_INTERVAL).await;
    finalize_landing(&app, &fx, 66, 2 * GRID_INTERVAL);
    commit_next(&mut app, &fx, Some(66)).await;
    assert_eq!(
        app.store.load_comet_hash(GRID_INTERVAL).unwrap(),
        None,
        "below the anchored checkpoint"
    );

    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(snapshot.trust_ready, "{:?}", snapshot.reason);
    assert_eq!(snapshot.target.unwrap().height, 2 * GRID_INTERVAL);
}

/// SYNC-9-5b: a landed validator-state hash that differs from the state the node's own
/// replica holds after that height, from the head state or from the grid sidecar, is an
/// authenticated contradiction: trust halts for safety and records the fatal evidence.
#[tokio::test]
async fn trust_halts_on_a_landed_validator_state_mismatch() {
    for head in [GRID_INTERVAL, GRID_INTERVAL + 1] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        commit_to(&mut app, &fx, head).await;
        let inbox = InboxStorage {
            last_checkpoint_val_state_hash: B256::repeat_byte(0x5a),
            ..landed(&app, &fx, GRID_INTERVAL)
        };
        fx.advance_l1(app.l1(), 100, &inbox, &fx.registry);
        let error = app.refresh_trust().await.unwrap_err();
        assert!(matches!(error, AbciError::SafetyHalt(_)), "head {head}: {error}");
        assert!(error.to_string().contains("validator_state_mismatch"), "head {head}: {error}");
        assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
        let evidence = std::fs::read_to_string(dir.path().join("fatal-evidence.txt")).unwrap();
        assert!(evidence.contains("validator_state_mismatch"), "head {head}: {evidence}");
    }
}

/// A landed record whose EL hash and validator-state hash both differ from the node's own
/// halts naming the EL divergence: the ancestry walk precedes the validator-state comparison.
#[tokio::test]
async fn trust_names_an_el_divergence_before_a_validator_state_mismatch() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, GRID_INTERVAL + 1).await;
    let inbox = InboxStorage {
        last_checkpoint_hash: B256::repeat_byte(0x33),
        last_checkpoint_val_state_hash: B256::repeat_byte(0x5a),
        ..landed(&app, &fx, GRID_INTERVAL)
    };
    fx.advance_l1(app.l1(), 100, &inbox, &fx.registry);
    let error = app.refresh_trust().await.unwrap_err();
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
    let reason = error.to_string();
    assert!(
        reason.contains(&format!("committed checkpoint hash mismatch at {GRID_INTERVAL}")),
        "{reason}"
    );
    assert!(!reason.contains("validator_state_mismatch"), "{reason}");
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
}

/// Commits through `2K + 1`, the last block anchored at L1 block 66, which lands `2K` with the
/// node's own EL and Comet hashes and `val_state_hash` (by default the node's own); block 65
/// lands `K`. The trust target `2K` is then the Comet history floor, and retention keeps the
/// record of `K` below it as the recompute base (the origin's is pruned).
async fn commit_past_the_floor(
    app: &mut App<MockL1, MockEngine>,
    fx: &Fixture,
    val_state_hash: Option<B256>,
) {
    let grid = 2 * GRID_INTERVAL;
    commit_to(app, fx, grid).await;
    finalize_landing(app, fx, 65, GRID_INTERVAL);
    let landing = landed(app, fx, grid);
    let inbox = InboxStorage {
        last_checkpoint_val_state_hash: val_state_hash
            .unwrap_or(landing.last_checkpoint_val_state_hash),
        ..landing
    };
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    commit_next(app, fx, Some(66)).await;
    let state = app.state().unwrap();
    assert_eq!((state.last_height, state.comet_history_floor()), (grid + 1, grid));
    assert_eq!(app.store.val_state_heights().unwrap(), [GRID_INTERVAL, grid]);
}

/// A node committed past the floor (see [`commit_past_the_floor`]) and restarted.
async fn restarted_at_the_floor(fx: &Fixture, dir: &Path) -> App<MockL1, MockEngine> {
    let mut app = initialized(fx, dir).await;
    commit_past_the_floor(&mut app, fx, None).await;
    restart(app, fx, dir)
}

/// `app` restarted over its store in `dir`, its EL and its own L1 node, which keep their
/// blocks.
fn restart(app: App<MockL1, MockEngine>, fx: &Fixture, dir: &Path) -> App<MockL1, MockEngine> {
    let (engine, l1) = (app.engine().reopen(), MockL1::default());
    {
        let (old, mut new) = (app.l1().state(), l1.state());
        new.headers = old.headers.clone();
        new.states = old.states.clone();
        new.finalized = old.finalized;
    }
    drop(app);
    app_with(l1, engine, fx.params.clone(), dir, AppOptions::default())
}

/// The validator-state record of `height` in `dir`.
fn val_state_record(dir: &Path, height: u64) -> std::path::PathBuf {
    dir.join(format!("val-state-{height}.bin"))
}

/// Asserts that `app`'s trust is ready at the target `height`.
fn assert_ready_at(app: &App<MockL1, MockEngine>, height: u64) {
    let snapshot = app.trust.snapshot();
    assert!(snapshot.trust_ready, "{:?}", snapshot.reason);
    assert_eq!(snapshot.target.unwrap().height, height);
}

/// Asserts that `error` and `app`'s trust and fatal evidence are a validator-state halt.
fn assert_val_state_halt(app: &App<MockL1, MockEngine>, error: &AbciError) {
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
    assert!(error.to_string().contains("validator_state_mismatch"), "{error}");
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    let evidence = app.store.fatal_evidence().unwrap().expect("fatal evidence");
    assert!(evidence.contains("validator_state_mismatch"), "{evidence}");
}

/// SYNC-9-5c 5c.d, at the history floor: a node that lost the record of its trust target
/// recomputes it from the base `K` below the floor and the updates since, compares that, and
/// records it again.
#[tokio::test]
async fn trust_recomputes_a_lost_record_from_an_earlier_one() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let grid = 2 * GRID_INTERVAL;
    let mut app = restarted_at_the_floor(&fx, dir.path()).await;
    let record = val_state_record(dir.path(), grid);
    let recorded = std::fs::read(&record).unwrap();
    std::fs::remove_file(&record).unwrap();
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, grid);
    assert_eq!(std::fs::read(&record).unwrap(), recorded);
}

/// SYNC-9-5c 5c.d/5c.f: a record whose bytes changed fails its checksum. It is missing data,
/// not a mismatch: the node sets it aside, recomputes the state and trusts, with no fatal
/// evidence.
#[tokio::test]
async fn trust_treats_a_corrupt_record_as_missing_not_as_a_mismatch() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let grid = 2 * GRID_INTERVAL;
    let mut app = restarted_at_the_floor(&fx, dir.path()).await;
    let record = val_state_record(dir.path(), grid);
    let recorded = std::fs::read(&record).unwrap();
    // The low byte of the first entry's proposer priority: after the 32-byte checksum, the six
    // head words, the first set's length word and the entry's first three words.
    let mut flipped = recorded.clone();
    flipped[32 + 32 * (6 + 1 + 3) + 31] ^= 1;
    std::fs::write(&record, &flipped).unwrap();
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, grid);
    assert!(!dir.path().join("fatal-evidence.txt").exists());
    assert_eq!(std::fs::read(&record).unwrap(), recorded);
    let set_aside = dir.path().join(format!("val-state-{grid}.bin.corrupt"));
    assert_eq!(std::fs::read(set_aside).unwrap(), flipped);
}

/// SYNC-9-5c 5c.e/5c.f: without the target's record and the base below the floor to recompute
/// it from (retention already pruned the origin's), the target's validator state is missing
/// data: trust stays closed and retrying, never halted and without fatal evidence, and opens
/// once the record is back.
#[tokio::test]
async fn trust_waits_while_the_record_cannot_be_recomputed() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let grid = 2 * GRID_INTERVAL;
    let mut app = restarted_at_the_floor(&fx, dir.path()).await;
    let Record::Valid(original) = app.store.load_val_state(grid).unwrap() else {
        panic!("the target is recorded")
    };
    for height in [GRID_INTERVAL, grid] {
        std::fs::remove_file(val_state_record(dir.path(), height)).unwrap();
    }
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(!snapshot.trust_ready);
    assert_ne!(snapshot.phase, TrustPhase::Halted);
    let reason = snapshot.reason.unwrap();
    assert!(reason.contains(&format!("validator state unavailable at {grid}")), "{reason}");
    assert!(app.store.fatal_evidence().unwrap().is_none());
    assert!(!dir.path().join("fatal-evidence.txt").exists());
    app.store.save_val_state(&original).unwrap();
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, grid);
}

/// SYNC-9-5b 5b.a: a well-formed record whose state differs from the landed one is an
/// authenticated contradiction, not missing data: trust halts for safety with fatal evidence.
#[tokio::test]
async fn trust_halts_on_a_well_formed_record_that_differs() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let grid = 2 * GRID_INTERVAL;
    let mut app = restarted_at_the_floor(&fx, dir.path()).await;
    let Record::Valid(mut other) = app.store.load_val_state(grid).unwrap() else {
        panic!("the target is recorded")
    };
    other.next.entries[0].priority += 1;
    std::fs::remove_file(val_state_record(dir.path(), grid)).unwrap();
    app.store.save_val_state(&other).unwrap();
    let error = app.refresh_trust().await.unwrap_err();
    assert_val_state_halt(&app, &error);
}

/// ACCEPTANCE §7.7, SYNC-9-5c 5c.a/5c.b: after a restart above its target, the node compares
/// the record it made there, never what stock CometBFT's stored-set lookup rebuilds. Here the
/// record holds `x + 2` of PROOF-6.2-41a's state `x`, two per-height increments, and the
/// lookup's one two-step increment from the full set stored at `x` differs from it: a landing
/// of the record's hash is trusted after a restart, and one of the lookup's hash halts.
#[tokio::test]
async fn restart_above_target_compares_the_record_not_a_stock_rebuild() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let grid = 2 * GRID_INTERVAL;
    let x = spec_41a_state(grid - 2);
    let record = x.advance(&[]).unwrap().advance(&[]).unwrap();
    let stock = ValState { next: stock_lookup(&x.next, 2), ..record.clone() };
    assert_ne!(stock.hash(), record.hash());

    let mut app = initialized(&fx, dir.path()).await;
    commit_past_the_floor(&mut app, &fx, Some(record.hash())).await;
    std::fs::remove_file(val_state_record(dir.path(), grid)).unwrap();
    app.store.save_val_state(&record).unwrap();
    let mut app = restart(app, &fx, dir.path());
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, grid);

    let mut app = restart(app, &fx, dir.path());
    let inbox =
        InboxStorage { last_checkpoint_val_state_hash: stock.hash(), ..landed(&app, &fx, grid) };
    fx.advance_l1(app.l1(), 100, &inbox, &fx.registry);
    let error = app.refresh_trust().await.unwrap_err();
    assert_val_state_halt(&app, &error);
}

/// A landed validator-state hash equal to the replica's after that height, from the head
/// state or from the grid sidecar, lets trust open.
#[tokio::test]
async fn trust_accepts_a_matching_validator_state() {
    for head in [GRID_INTERVAL, GRID_INTERVAL + 1] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        commit_to(&mut app, &fx, head).await;
        finalize_landing(&app, &fx, 100, GRID_INTERVAL);
        app.refresh_trust().await.unwrap();
        let snapshot = app.trust.snapshot();
        assert!(snapshot.trust_ready, "head {head}: {:?}", snapshot.reason);
        let target = snapshot.target.unwrap();
        assert_eq!(target.height, GRID_INTERVAL);
        assert_eq!(target.val_state_hash, val_state_hash(&app, GRID_INTERVAL));
    }
}

/// STOR-B-9: the start write records validator-state hash 0, so a start record with any other
/// word 4 is malformed L1 data and halts, as a nonzero Comet hash there does.
#[tokio::test]
async fn start_record_with_nonzero_val_state_is_invalid() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let inbox = InboxStorage {
        last_checkpoint_val_state_hash: B256::repeat_byte(0x77),
        ..fx.inbox.clone()
    };
    fx.advance_l1(app.l1(), 100, &inbox, &fx.registry);
    let error = app.refresh_trust().await.unwrap_err();
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
    assert!(error.to_string().contains("invalid checkpoint landing record"), "{error}");
    assert!(!app.trust.snapshot().trust_ready);
}

/// A pinned target's landing record cannot change: a later proof of the same height whose
/// only difference is the validator-state hash halts, both on the refresh after the link
/// check and against the floor a reconnect keeps.
#[tokio::test]
async fn pinned_target_changing_only_val_state_is_rejected() {
    for (reconnect, reason) in [
        (false, "authenticated checkpoint changed at the same height"),
        (true, "authenticated checkpoint conflicts with retained floor"),
    ] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        commit_to(&mut app, &fx, GRID_INTERVAL - 1).await;
        let env = next_envelope(&app, &fx);
        target(&app, &fx, GRID_INTERVAL, env.block.header.hash_slow());
        app.refresh_trust().await.unwrap();
        assert_eq!(app.trust.snapshot().target.unwrap().height, GRID_INTERVAL);
        let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
        finalize(&mut app, finalize_req(&req)).await.unwrap();
        commit(&mut app).await.unwrap();
        let changed = InboxStorage {
            last_checkpoint_val_state_hash: B256::repeat_byte(0x5a),
            ..landed(&app, &fx, GRID_INTERVAL)
        };
        fx.advance_l1(app.l1(), 101, &changed, &fx.registry);
        if reconnect {
            app.trust.begin_session();
        }
        let error = app.refresh_trust().await.unwrap_err();
        assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
        assert!(error.to_string().contains(reason), "{error}");
        assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    }
}

/// A decided block at the pinned target height whose validator state differs from the landed
/// one halts before it settles, even though its EL and Comet hashes match.
#[tokio::test]
async fn check_trust_candidate_compares_val_state() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, GRID_INTERVAL - 1).await;
    let env = next_envelope(&app, &fx);
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    let inbox = InboxStorage {
        last_checkpoint_comet_hash: B256::from_slice(req.hash.as_bytes()),
        last_checkpoint_val_state_hash: B256::repeat_byte(0x5a),
        ..fx.inbox_at_checkpoint(GRID_INTERVAL, env.block.header.hash_slow())
    };
    fx.advance_l1(app.l1(), 100, &inbox, &fx.registry);
    app.refresh_trust().await.unwrap();
    assert_eq!(app.trust.snapshot().target.unwrap().height, GRID_INTERVAL);
    let calls = app.engine().calls().len();
    let error = finalize(&mut app, finalize_req(&req)).await.unwrap_err();
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
    assert!(error.to_string().contains("validator_state_mismatch"), "{error}");
    assert!(app.pending.is_none());
    assert_eq!(app.engine().calls().len(), calls);
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    let evidence = app.store.fatal_evidence().unwrap().expect("fatal evidence");
    assert!(evidence.contains("validator_state_mismatch"), "{evidence}");
}
