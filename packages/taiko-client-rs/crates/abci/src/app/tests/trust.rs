//! Startup checkpoint trust is distinct from consensus progress.
use std::time::Duration;

use super::{
    proposal::{bft_time, commit, finalize, finalize_req, hand_envelope, next_height, process_req},
    *,
};
use crate::{
    app::trust::TrustPhase,
    config::SwitchConfig,
    envelope::EtnaEnvelope,
    l1::{L1Error, layout::inbox},
    test_utils::{InboxStorage, L1Call, TestState, filler_accounts, inbox_account, l1_header},
};
use alloy_primitives::{Address, B256, U256};

/// A landed checkpoint height the scenarios commit up to. Any height can be landed; 6 only
/// keeps a few blocks between the origin and the first checkpoint.
const LANDED: u64 = 6;

/// Provides real proofs at the exact finalized snapshot. A committed `height` lands with the
/// app's own Comet hash, the next height with the one [`next_envelope`] decides, and any other
/// height with a placeholder.
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
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 100, &inbox);
    app.l1().set_finalized(100);
}

/// The envelope the tests decide at the next height: the first block after genesis carries the
/// genesis anchor's witness, later ones inherit the committed anchor.
fn next_envelope(app: &App<MockL1, MockEngine>, fx: &Fixture) -> EtnaEnvelope {
    let first = app.state().expect("initialized").last_height == 0;
    hand_envelope(app, first.then(|| fx.anchor_witness(app.l1(), fx.genesis.l1_0)))
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
    assert_eq!(value["schema_version"], 2);
    assert_eq!(value["phase"], "acquiring");
    // The phase is the only readiness field: no second flag can disagree with it.
    let keys = value.as_object().unwrap().keys().map(String::as_str).collect();
    assert_eq!(
        std::collections::BTreeSet::from([
            "schema_version",
            "session_id",
            "chain_id",
            "generation",
            "recovery_origin",
            "phase",
            "target",
            "committed_head",
            "trusted_consensus_head",
            "eligible_height",
            "reason",
        ]),
        keys
    );
    assert!(value["chain_id"].is_null());
    assert!(value["trusted_consensus_head"].is_null());
    assert!(value["eligible_height"].is_null());
}

#[tokio::test]
async fn ready_requires_authenticated_checkpoint_and_durable_genesis() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    assert_eq!(app.trust.snapshot().target.unwrap().l1_number, 100);
    init_chain(&mut app, fx.request.clone()).await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
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
    commit_to(&mut app, &fx, LANDED - 1).await;
    let env = next_envelope(&app, &fx);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, LANDED, hash);
    app.refresh_trust().await.unwrap();
    assert_eq!(app.trust.snapshot().phase, TrustPhase::CatchingUp);
    assert_eq!(
        tokio::time::timeout(Duration::from_secs(1), info(&mut app))
            .await
            .unwrap()
            .unwrap()
            .last_block_height
            .value(),
        LANDED - 1
    );
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    assert!(app.engine().calls().iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, safe, finalized } if *head == hash && safe.is_zero() && *finalized == fx.genesis_hash())));
    commit(&mut app).await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    assert_eq!(Store::volatile(dir.path().into()).load().unwrap().unwrap().parent.hash, hash);
}

#[tokio::test]
async fn conflicting_decided_checkpoint_halts_before_settle_or_pending() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 1, B256::repeat_byte(7));
    app.refresh_trust().await.unwrap();
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)));
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    let before = app.engine().calls().len();
    let error = finalize(&mut app, finalize_req(&req)).await.unwrap_err();
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
    assert!(error.to_string().contains("checkpoint hash mismatch"), "{error}");
    assert!(app.pending.is_none());
    assert_eq!(app.engine().calls().len(), before);
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    assert!(!app.trust.begin_session().is_ready());
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
    assert!(!app.trust.snapshot().is_ready());
    app.l1().state().proof_fail = None;
    app.opts.l1_timeout = Duration::from_millis(1);
    app.l1().state().proof_delay = Some(Duration::from_millis(20));
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    app.l1().state().proof_delay = None;
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
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
        fx.plant_l1_block(app.l1(), 100, &inbox);
        app.l1().set_finalized(100);
        if case == 3 {
            app.l1().state().canonical_script.push_back(Ok(B256::repeat_byte(9)));
        }
        if case == 4 {
            let header = crate::test_utils::l1_header(100, Fixture::l1_timestamp(100));
            app.l1().insert_header(crate::l1::RawL1Header::from(&header));
        }
        assert!(matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(_))), "case {case}");
        assert!(!app.trust.snapshot().is_ready());
    }
}

#[tokio::test]
async fn a_newer_checkpoint_replaces_the_pending_target_until_matched() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, LANDED - 1).await;
    let env = next_envelope(&app, &fx);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, LANDED, hash);
    app.refresh_trust().await.unwrap();
    let inbox = InboxStorage {
        last_checkpoint_height: 2 * LANDED,
        last_checkpoint_hash: B256::repeat_byte(8),
        last_checkpoint_comet_hash: B256::repeat_byte(8),
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 101, &inbox);
    app.l1().set_finalized(101);
    app.refresh_trust().await.unwrap();
    // The latest known target is the one a complete match must reach (SYNC-9-6a).
    assert_eq!(app.trust.snapshot().target.unwrap().height, 2 * LANDED);
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(!snapshot.is_ready());
    assert_eq!(snapshot.target.unwrap().height, 2 * LANDED);
}

#[tokio::test]
async fn restart_checks_contiguous_ancestry_not_presence_of_genuine_checkpoint() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)));
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    let mut broken = env.block.header.clone();
    broken.parent_hash = B256::repeat_byte(3);
    let mut state = app.state().unwrap().clone();
    state.parent.hash = broken.hash_slow();
    Store::volatile(dir.path().into()).save(&state).unwrap();
    let engine = app.engine().reopen();
    engine.state().chain.insert(1, broken);
    let mut restarted =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    target(&restarted, &fx, 0, fx.genesis_hash());
    assert!(!restarted.trust.snapshot().is_ready());
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
    assert!(!app.trust.snapshot().is_ready());
    app.engine().state().chain.insert(0, header);
    app.refresh_trust().await.unwrap();
    let old = app.trust.snapshot();
    assert!(old.is_ready());
    let new = app.trust.begin_session();
    assert!(!new.is_ready());
    assert_ne!(new.session_id, old.session_id);
    assert!(!app.trust.check_session(&old.session_id).is_ready());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.check_session(&new.session_id).is_ready());
    // A stale answer reports acquiring in its own copy and never closes the current session.
    let stale = app.trust.check_session(&old.session_id);
    assert_eq!(stale.phase, TrustPhase::Acquiring);
    assert!(stale.trusted_consensus_head.is_none());
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Ready);
    assert!(app.trust.check_session(&new.session_id).trusted_consensus_head.is_some());
    let handle = app.trust_handle();
    drop(app);
    assert!(!handle.snapshot().is_ready());
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
    assert!(!handle.check_session(&session.session_id).is_ready());
    app.l1().state().proof_delay = None;
    app.refresh_trust().await.unwrap();
    assert!(handle.check_session(&session.session_id).is_ready());
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
    assert!(!trust.snapshot().is_ready());
    l1.state().proof_fail = None;
    tokio::time::timeout(Duration::from_secs(3), async {
        while !trust.snapshot().is_ready() {
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    assert_eq!(trust.snapshot().committed_head.unwrap().height, 0);
    worker.abort();
    let _ = worker.await;
    assert!(!trust.snapshot().is_ready());
}

#[tokio::test]
async fn failed_commit_never_authorizes_and_keeps_original_durable_head() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)));
    let hash = env.block.header.hash_slow();
    target(&app, &fx, 1, hash);
    app.refresh_trust().await.unwrap();
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    // An occupied temp path causes the actual atomic store write to fail.
    std::fs::create_dir(dir.path().join(crate::store::TMP_FILE)).unwrap();
    assert!(matches!(commit(&mut app).await, Err(AbciError::Store(_))));
    assert!(!app.trust.snapshot().is_ready());
    assert_eq!(app.trust.snapshot().committed_head.unwrap().height, 0);
    assert_eq!(app.state().unwrap().last_height, 0);
    let saved: crate::store::AppState =
        serde_json::from_slice(&std::fs::read(dir.path().join(crate::store::STATE_FILE)).unwrap())
            .unwrap();
    assert_eq!(saved.last_height, 0);
}

/// The names in the app store `dir`.
fn store_files(dir: &std::path::Path) -> std::collections::BTreeSet<String> {
    std::fs::read_dir(dir).unwrap().map(|e| e.unwrap().file_name().into_string().unwrap()).collect()
}

/// A superseded generation adds only the generic fatal record to its store, and that record
/// makes the next start refuse (RECOV-8-16).
fn assert_superseded_store(
    fx: &Fixture,
    dir: &std::path::Path,
    before: &std::collections::BTreeSet<String>,
) {
    let added: Vec<_> = store_files(dir).difference(before).cloned().collect();
    assert_eq!(added, ["fatal-evidence.txt"], "supersession must use only the generic fatal latch");
    let restart = App::new(
        fx.l1(),
        fx.engine(),
        fx.params.clone(),
        Store::volatile(dir.into()),
        crate::test_utils::test_options(),
    );
    assert!(matches!(restart, Err(AbciError::SafetyHalt(_))));
}

/// RECOV-8-15: a proposal whose final anchor shows a later generation is rejected and trust is
/// revoked while the process keeps running. The generic fatal record only makes a restart
/// refuse (RECOV-8-16), and the halted session cannot be reopened by a signer reconnect.
#[tokio::test]
async fn higher_generation_proposal_revokes_even_without_finalize_error() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    let mut inbox = fx.inbox.clone();
    inbox.recovery_generation = 1;
    fx.plant_l1_block(app.l1(), 101, &inbox);
    app.l1().set_finalized(101);
    let before = store_files(dir.path());
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 101)));
    let (response, _) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(response, response::ProcessProposal::Reject);
    assert!(app.superseded);
    assert!(!app.trust.snapshot().is_ready());
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    assert!(app.store.fatal_evidence().unwrap().is_some());
    assert_superseded_store(&fx, dir.path(), &before);
    assert_eq!(app.trust.begin_session().phase, TrustPhase::Halted);
}

/// RECOV-8-16: a startup trust check that finds a later Inbox generation is a safety halt. It
/// keeps the AppState bytes, records the generic fatal evidence and makes the restart refuse.
#[tokio::test]
async fn generation_zero_startup_supersession_records_generic_fatal() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);
    let original = std::fs::read(dir.path().join(crate::store::STATE_FILE)).unwrap();
    let before = store_files(dir.path());
    let mut app = fx.app(dir.path());
    let inbox = InboxStorage { recovery_generation: 1, ..fx.inbox.clone() };
    fx.plant_l1_block(app.l1(), 101, &inbox);
    app.l1().set_finalized(101);
    assert!(matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    assert!(app.store.fatal_evidence().unwrap().is_some());
    assert_superseded_store(&fx, dir.path(), &before);
    assert_eq!(std::fs::read(dir.path().join(crate::store::STATE_FILE)).unwrap(), original);
    assert_eq!(app.trust.begin_session().phase, TrustPhase::Halted);
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
            assert!(!app.trust.snapshot().is_ready());
            assert!(!dir.path().join("fatal-evidence.txt").exists());
            for _ in 0..2 {
                app.refresh_trust().await.unwrap();
            }
            assert!(app.trust.snapshot().is_ready(), "code {code}");
        }
    }
}

#[tokio::test]
async fn refreshed_lower_checkpoint_never_downgrades_pinned_target() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, LANDED - 1).await;
    let env = next_envelope(&app, &fx);
    let hash = env.block.header.hash_slow();
    target(&app, &fx, LANDED, hash);
    app.refresh_trust().await.unwrap();
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    fx.plant_l1_block(app.l1(), 101, &fx.inbox);
    app.l1().set_finalized(101);
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    assert_eq!(app.trust.snapshot().target.unwrap().height, LANDED);
}

#[tokio::test]
async fn reconnect_never_forgets_an_authenticated_unreached_checkpoint() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 2, B256::repeat_byte(8));
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    fx.plant_l1_block(app.l1(), 101, &fx.inbox);
    app.l1().set_finalized(101);
    app.trust.begin_session();
    app.refresh_trust().await.unwrap();
    assert!(
        !app.trust.snapshot().is_ready(),
        "reconnect must not lower an unreached authenticated checkpoint"
    );
}

/// An own L1 whose finalized block precedes L1_0, as when it lags or after a failover to a node
/// that is behind, reads an Inbox that holds no checkpoint yet: every word is zero. That is
/// missing data, not a contradiction (SYNC-9-7): trust stays closed with the reason, before
/// InitChain and after it, and no fatal evidence is written. Once the own L1 finalizes past L1_0,
/// trust becomes ready.
#[tokio::test]
async fn own_finality_before_the_inbox_genesis_waits_instead_of_halting() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let early = fx.genesis.l1_0 - 1;
    let empty = InboxStorage {
        status: 0,
        recovery_generation: 0,
        last_checkpoint_height: 0,
        last_checkpoint_hash: B256::ZERO,
        last_checkpoint_comet_hash: B256::ZERO,
        forced_inclusion_head: 0,
        forced_inclusion_tail: 0,
        forced_inclusion_queue: vec![],
        genesis: None,
        origin_fallback_keys_hash: B256::ZERO,
        fallback_keys_hash: B256::ZERO,
        min_total_stake: U256::ZERO,
    };
    let behind = |app: &App<MockL1, MockEngine>| {
        fx.plant_l1_block(app.l1(), early, &empty);
        app.l1().set_finalized(early);
    };
    let waits = |app: &App<MockL1, MockEngine>, when: &str| {
        let snapshot = app.trust.snapshot();
        assert!(!snapshot.is_ready(), "{when}");
        assert!(
            snapshot.reason.as_deref().is_some_and(|reason| reason.contains("precedes the Inbox")),
            "{when}: {snapshot:?}"
        );
        assert!(app.store.fatal_evidence().unwrap().is_none(), "{when}");
    };
    behind(&app);
    app.refresh_trust().await.unwrap();
    waits(&app, "before InitChain");

    target(&app, &fx, 0, fx.genesis_hash());
    init_chain(&mut app, fx.request.clone()).await.unwrap();
    behind(&app);
    app.refresh_trust().await.unwrap();
    waits(&app, "after InitChain");

    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready(), "{:?}", app.trust.snapshot());

    // An empty Inbox at or past L1_0, where it already held the genesis checkpoint, is a
    // contradiction: it halts with fatal evidence.
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    target(&app, &fx, 0, fx.genesis_hash());
    init_chain(&mut app, fx.request.clone()).await.unwrap();
    fx.plant_l1_block(app.l1(), 100, &empty);
    app.l1().set_finalized(100);
    let result = app.refresh_trust().await;
    assert!(matches!(&result, Err(AbciError::SafetyHalt(_))), "{result:?}");
    assert!(app.store.fatal_evidence().unwrap().is_some());
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
    assert!(!app.trust.snapshot().is_ready());
    assert!(!dir.path().join("fatal-evidence.txt").exists());
    app.l1().state().fail = None;
    target(&app, &fx, 0, fx.genesis_hash());
    init_chain(&mut app, fx.request.clone()).await.unwrap();
    app.refresh_trust().await.unwrap();
    assert!(
        app.trust.snapshot().is_ready(),
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
    assert!(!app.trust.snapshot().is_ready());
    assert!(app.engine().calls()[before..].iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, safe, finalized } if *head == fx.genesis_hash() && safe.is_zero() && finalized.is_zero())));
    assert!(!app.engine().calls()[before..].iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, .. } if *head == B256::repeat_byte(8))));
}

/// SYNC-9-6a 6a.a/6a.h: a ready node follows the Inbox's latest checkpoint in its own finalized
/// L1 view although no proposal adopted it: a newer checkpoint it holds is compared (EL hash,
/// then the slot 285 record read once at that L1 block) and trust stays ready. A finalized
/// block it read already costs one finalized-number read. Ready sessions label valid
/// candidates safe and name the durable boundary plus one as the eligible height (SYNC-9-10).
#[tokio::test]
async fn ready_session_follows_newer_finalized_checkpoints_and_labels_candidates_safe() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, 2 * LANDED - 1).await;
    finalize_landing(&app, &fx, 65, LANDED);
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, LANDED);
    assert_eq!(app.trust.snapshot().eligible_height, Some(2 * LANDED));

    finalize_landing(&app, &fx, 66, 2 * LANDED - 1);
    for _ in 0..3 {
        app.refresh_trust().await.unwrap();
    }
    assert_ready_at(&app, 2 * LANDED - 1);
    let record = inbox::landing_record_slots(2 * LANDED - 1)[0];
    let reads = app.l1().calls().into_iter().filter(|call| {
        matches!(call, L1Call::AccountWitness { slots, block: 66, .. } if slots.contains(&record))
    });
    assert_eq!(reads.count(), 1, "one slot 285 read for that checkpoint");
    let before = app.l1().calls().len();
    app.refresh_trust().await.unwrap();
    assert_eq!(app.l1().calls()[before..], [L1Call::Finalized]);

    let env = next_envelope(&app, &fx);
    let hash = env.block.header.hash_slow();
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    assert!(app.engine().calls().iter().any(|call| matches!(call,
        EngineCall::Forkchoice { head, safe, finalized } if *head == hash && *safe == hash && *finalized == fx.genesis_hash())));
    commit(&mut app).await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(snapshot.is_ready());
    assert_eq!(snapshot.target.unwrap().height, 2 * LANDED - 1);
    assert_eq!(snapshot.trusted_consensus_head.unwrap().hash, hash);
    assert_eq!(snapshot.eligible_height, Some(2 * LANDED + 1));
}

/// SYNC-9-10 10.g: at a generation's start, before its first commit, the only eligible height
/// is its `initial_height`, the origin plus one, while `Info` reports height 0.
#[tokio::test]
async fn the_first_eligible_height_is_the_generation_initial_height() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, fx.genesis.genesis_height, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, fx.genesis.genesis_height);
    assert_eq!(info(&mut app).await.unwrap().last_block_height.value(), 0);
    assert_eq!(app.trust.snapshot().eligible_height, Some(fx.genesis.genesis_height + 1));
}

/// SYNC-9-6a 6a.f/6a.k, CONS-3.4-16 16.h: a newer checkpoint above the committed head makes a
/// ready node untrusted, with no eligible height, whether or not its slot 285 record is
/// available. A failed read never clears it. Once the chain reaches it and both hashes match,
/// trust returns without an operator.
#[tokio::test]
async fn a_newer_checkpoint_above_the_head_closes_signing_until_reached_and_matched() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, LANDED - 1).await;
    finalize_landing(&app, &fx, 65, LANDED - 1);
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, LANDED - 1);
    let env = next_envelope(&app, &fx);
    target(&app, &fx, LANDED, env.block.header.hash_slow());
    let record = inbox::landing_record_slots(LANDED)[0];
    app.l1().state().proof_fail_slot = Some((record, L1Error::Rpc("record unavailable".into())));
    app.refresh_trust().await.unwrap();
    let pending = |app: &App<MockL1, MockEngine>| {
        let snapshot = app.trust.snapshot();
        assert_eq!(snapshot.phase, TrustPhase::CatchingUp, "{:?}", snapshot.reason);
        assert_eq!(snapshot.target.unwrap().height, LANDED);
        assert_eq!(snapshot.eligible_height, None);
        assert!(snapshot.trusted_consensus_head.is_none());
    };
    pending(&app);
    app.l1().state().fail = Some(L1Error::Rpc("down".into()));
    app.refresh_trust().await.unwrap();
    pending(&app);
    app.l1().state().fail = None;
    app.l1().state().proof_fail_slot = None;
    app.refresh_trust().await.unwrap();
    pending(&app);

    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    pending(&app);
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, LANDED);
    assert_eq!(app.trust.snapshot().eligible_height, Some(LANDED + 1));
    assert!(app.store.fatal_evidence().unwrap().is_none());
}

/// SYNC-9-6a 6a.r: with the EL hash matching, a temporarily unavailable slot 285 record keeps
/// the target pending and is read again at the same pinned L1 block, not at a newer one.
#[tokio::test]
async fn an_unavailable_record_is_retried_at_the_pinned_l1_block() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, 2 * LANDED).await;
    finalize_landing(&app, &fx, 65, LANDED);
    app.refresh_trust().await.unwrap();
    finalize_landing(&app, &fx, 66, 2 * LANDED);
    let record = inbox::landing_record_slots(2 * LANDED)[0];
    app.l1().state().proof_fail_slot = Some((record, L1Error::Rpc("record unavailable".into())));
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert_eq!(snapshot.phase, TrustPhase::CatchingUp);
    assert!(snapshot.reason.unwrap().contains("slot 285 record at L1 block 66"));
    // A newer finalized block with the same checkpoint does not move the pinned read.
    fx.plant_l1_block(app.l1(), 67, &landed(&app, &fx, 2 * LANDED));
    app.l1().state().proof_fail_slot = None;
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, 2 * LANDED);
    assert!(app.l1().calls().iter().any(|call| {
        matches!(call, L1Call::AccountWitness { slots, block: 66, .. } if slots.contains(&record))
    }));
}

/// SYNC-9-6a 6a.b/6a.c/6a.d/6a.q, RECOV-8-15: once trusted, a newer checkpoint in the own
/// finalized L1 view whose EL hash conflicts with the node's block at that height (even while
/// its slot 285 record is unavailable), or whose Comet hash does, revokes trust although no
/// proposal adopted it. The node reports halted with no eligible height, a reconnect cannot
/// reopen it and the process keeps running; the fatal record makes a restart refuse (6a.e).
#[tokio::test]
async fn a_conflicting_newer_checkpoint_revokes_trust_while_the_process_keeps_running() {
    for el_conflict in [true, false] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        commit_to(&mut app, &fx, 2 * LANDED).await;
        finalize_landing(&app, &fx, 65, LANDED);
        app.refresh_trust().await.unwrap();
        assert_ready_at(&app, LANDED);
        let mut inbox = landed(&app, &fx, 2 * LANDED);
        if el_conflict {
            inbox.last_checkpoint_hash = B256::repeat_byte(0xc4);
            let record = inbox::landing_record_slots(2 * LANDED)[0];
            app.l1().state().proof_fail_slot =
                Some((record, L1Error::Rpc("record unavailable".into())));
        } else {
            inbox.last_checkpoint_comet_hash = B256::repeat_byte(0xc5);
        }
        fx.advance_l1(app.l1(), 66, &inbox);
        app.refresh_trust().await.expect("a revocation keeps the process running");
        let snapshot = app.trust.snapshot();
        assert_eq!(snapshot.phase, TrustPhase::Halted, "EL conflict {el_conflict}");
        assert_eq!(snapshot.eligible_height, None);
        let kind = if el_conflict { "checkpoint hash mismatch" } else { "Comet hash mismatch" };
        assert!(snapshot.reason.unwrap().contains(kind));
        assert!(app.store.fatal_evidence().unwrap().is_some());
        assert_eq!(app.trust.begin_session().phase, TrustPhase::Halted);
        let restarted = App::new(
            fx.l1(),
            app.engine().reopen(),
            fx.params.clone(),
            Store::volatile(dir.path().into()),
            crate::test_utils::test_options(),
        );
        assert!(matches!(restarted, Err(AbciError::SafetyHalt(_))));
    }
}

/// SYNC-9-6a, SYNC-9-7: at startup the node compares the authenticated lastCheckpoint EL hash as
/// soon as it holds the target height, and a mismatch halts for safety even while the slot 285
/// read is pending.
#[tokio::test]
async fn a_startup_el_mismatch_halts_while_the_record_is_unavailable() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, LANDED).await;
    fx.advance_l1(app.l1(), 66, &fx.inbox_at_checkpoint(LANDED, B256::repeat_byte(0xc4)));
    let record = inbox::landing_record_slots(LANDED)[0];
    app.l1().state().proof_fail_slot = Some((record, L1Error::Rpc("record unavailable".into())));
    let result = app.refresh_trust().await;
    assert!(
        matches!(result, Err(AbciError::SafetyHalt(ref reason)) if reason.contains("checkpoint hash mismatch")),
        "{result:?}"
    );
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    assert!(app.store.fatal_evidence().unwrap().is_some());
}

/// SYNC-9-6a 6a.l/6a.m, RECOV-8-14/8-15 15.d, RECOV-8.2-5: a running ready node revokes its
/// checkpoint trust as soon as its own finalized L1 view shows a larger `recoveryGeneration`,
/// with no proposal or signer reconnect, refuses old-generation signing from then on and keeps
/// running.
#[tokio::test]
async fn a_larger_generation_in_the_finalized_view_revokes_a_ready_node() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    let mut inbox = fx.inbox.clone();
    inbox.recovery_generation += 1;
    fx.advance_l1(app.l1(), 101, &inbox);
    app.refresh_trust().await.expect("a revocation keeps the process running");
    let snapshot = app.trust.snapshot();
    assert_eq!(snapshot.phase, TrustPhase::Halted);
    assert_eq!(snapshot.eligible_height, None);
    assert!(snapshot.reason.unwrap().contains("recovery generation"));
    assert!(app.status().unwrap().superseded);
    assert!(app.store.fatal_evidence().unwrap().is_some());
    assert_eq!(app.trust.begin_session().phase, TrustPhase::Halted);
}

/// SYNC-9-6a 6a.g, RECOV-8-5: a ready node whose own L1 cannot answer the latest-checkpoint read
/// keeps its matched result, and pauses those reads instead of spending the worker's time on
/// them every tick.
#[tokio::test(start_paused = true)]
async fn an_unavailable_latest_checkpoint_keeps_the_matched_result() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    target(&app, &fx, 0, fx.genesis_hash());
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    app.l1().state().fail = Some(L1Error::Rpc("down".into()));
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(snapshot.is_ready());
    assert_eq!(snapshot.eligible_height, Some(fx.genesis.genesis_height + 1));
    let before = app.l1().calls().len();
    app.refresh_trust().await.unwrap();
    assert_eq!(app.l1().calls().len(), before, "paused");
    app.l1().state().fail = None;
    tokio::time::advance(crate::app::trust::FOLLOW_RETRY_INITIAL).await;
    app.refresh_trust().await.unwrap();
    assert_eq!(app.l1().calls()[before..], [L1Call::Finalized]);
    assert!(app.trust.snapshot().is_ready());
}

/// CONS-3.4-16 16.b/16.h/16.i: a ready node rejects a proposal whose own-finalized anchor proves
/// a checkpoint above the parent, alerts, and signs nothing until its chain has reached that
/// height and compared; the match then restores signing without an operator. 16.c/16.d/16.g:
/// a proposal whose anchor proves another hash at a height the node holds is rejected and
/// revokes its trust while the process keeps running.
#[tokio::test]
async fn proposal_checkpoints_above_the_parent_pend_and_conflicting_ones_revoke() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, LANDED - 1).await;
    finalize_landing(&app, &fx, 65, LANDED - 1);
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, LANDED - 1);
    let env = next_envelope(&app, &fx);
    target(&app, &fx, LANDED, env.block.header.hash_slow());
    let ahead = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 100)));
    let logs = crate::test_utils::LogCapture::start();
    assert_eq!(super::proposal::rejected(&mut app, &ahead).await, "checkpoint_above_parent");
    assert!(logs.at("ERROR").iter().any(|line| line.contains("checkpoint_above_parent")));
    let snapshot = app.trust.snapshot();
    assert_eq!(snapshot.phase, TrustPhase::CatchingUp);
    assert_eq!(snapshot.target.unwrap().height, LANDED);
    assert_eq!(snapshot.eligible_height, None);

    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, LANDED);
    assert!(app.store.fatal_evidence().unwrap().is_none());

    fx.advance_l1(app.l1(), 101, &fx.inbox_at_checkpoint(LANDED - 2, B256::repeat_byte(0xc4)));
    let conflicting = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 101)));
    assert_eq!(super::proposal::rejected(&mut app, &conflicting).await, "checkpoint_conflict");
    let snapshot = app.trust.snapshot();
    assert_eq!(snapshot.phase, TrustPhase::Halted);
    assert!(snapshot.reason.unwrap().contains("differs from the local block"));
    assert!(app.store.fatal_evidence().unwrap().is_some());
    assert_eq!(app.trust.begin_session().phase, TrustPhase::Halted);
}

/// SYNC-9-5a 5a.d/5a.k: on a switching network every trust grant checks the node's own fork
/// time against the switching EtnaInbox's immutable `etnaForkTime()`, read at the target's own
/// finalized L1 block, not only while the checkpoint is S: an unavailable read keeps trust
/// closed, another value halts.
#[tokio::test]
async fn switching_trust_checks_the_fork_time_at_a_later_checkpoint() {
    let mut fx = Fixture::genesis(1);
    let implementation = Address::with_last_byte(0x55);
    let fork_timestamp = fx.el_chain[0].timestamp + 1;
    fx.params.switch = Some(SwitchConfig {
        unzen_inbox: Address::with_last_byte(1),
        fork_timestamp,
        signal_service_implementation: implementation,
        staking_implementation: Address::with_last_byte(0x56),
    });
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, LANDED).await;
    let hash = app.engine().state().chain[&LANDED].hash_slow();
    target(&app, &fx, LANDED, hash);
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(!snapshot.is_ready());
    assert!(snapshot.reason.unwrap().contains("EtnaInbox fork time"));
    app.l1().state().etna_fork_time = Some((fx.params.inbox, fork_timestamp));
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready(), "{:?}", app.trust.snapshot().reason);
    let l1_hash = app.trust.snapshot().target.unwrap().l1_hash;
    assert!(app.l1().calls().iter().any(|call| matches!(call,
        L1Call::CallAt { address, hash, .. } if *address == fx.params.inbox && *hash == l1_hash)));

    let mut restarted =
        app_with(fx.l1(), app.engine().reopen(), fx.params.clone(), dir.path(), Default::default());
    restarted.l1().state().etna_fork_time = Some((fx.params.inbox, fork_timestamp + 1));
    target(&restarted, &fx, LANDED, hash);
    let result = restarted.refresh_trust().await;
    assert!(
        matches!(result, Err(AbciError::SafetyHalt(ref reason)) if reason.contains("etnaForkTime")),
        "{result:?}"
    );
    assert!(!restarted.trust.snapshot().is_ready());
}

#[tokio::test]
async fn restart_equal_and_above_checkpoint_require_fresh_proof_and_linked_history() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, 2 * LANDED).await;
    for checkpoint in [LANDED, 2 * LANDED] {
        let hash = app.engine().state().chain[&checkpoint].hash_slow();
        let mut restarted = app_with(
            fx.l1(),
            app.engine().reopen(),
            fx.params.clone(),
            dir.path(),
            crate::test_utils::test_options(),
        );
        target(&restarted, &fx, checkpoint, hash);
        assert!(!restarted.trust.snapshot().is_ready());
        restarted.refresh_trust().await.unwrap();
        assert!(restarted.trust.snapshot().is_ready());
        assert_eq!(restarted.trust.snapshot().committed_head.unwrap().height, 2 * LANDED);
    }
    let mut restarted = app_with(
        fx.l1(),
        app.engine().reopen(),
        fx.params.clone(),
        dir.path(),
        crate::test_utils::test_options(),
    );
    target(&restarted, &fx, 0, fx.genesis_hash());
    let missing = restarted.engine().state().chain.remove(&1).unwrap();
    restarted.refresh_trust().await.unwrap();
    assert!(
        !restarted.trust.snapshot().is_ready(),
        "missing intermediate history does not establish ancestry"
    );
    restarted.engine().state().chain.insert(1, missing);
    restarted.refresh_trust().await.unwrap();
    assert!(restarted.trust.snapshot().is_ready());
    let json: serde_json::Value =
        serde_json::from_slice(&std::fs::read(dir.path().join(crate::store::STATE_FILE)).unwrap())
            .unwrap();
    assert!(
        json.get("phase").is_none() &&
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
        assert!(!app.trust.snapshot().is_ready());
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
        assert!(!app.trust.snapshot().is_ready());
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
        assert!(!app.trust.snapshot().is_ready());
        assert_ne!(app.trust.snapshot().phase, TrustPhase::Halted);
        app.l1().state().header_fail = None;
        app.refresh_trust().await.unwrap();
        assert!(app.trust.snapshot().is_ready());
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
    assert!(handle.check_session(&current.session_id).is_ready());
}

#[tokio::test]
async fn authenticated_genesis_landing_requires_zero_comet_hash() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let inbox =
        InboxStorage { last_checkpoint_comet_hash: B256::repeat_byte(0x77), ..fx.inbox.clone() };
    fx.plant_l1_block(app.l1(), 100, &inbox);
    app.l1().set_finalized(100);
    assert!(matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
    assert!(!app.trust.snapshot().is_ready());
}

#[tokio::test]
async fn committed_comet_history_is_required_and_survives_restart() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for i in 0..=LANDED {
        let anchor = (i == 0).then(|| fx.anchor_witness(app.l1(), fx.genesis.l1_0));
        let env = hand_envelope(&app, anchor);
        let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
        finalize(&mut app, finalize_req(&req)).await.unwrap();
        assert!(app.store.load_comet_hash(req.height.value()).unwrap().is_none());
        commit(&mut app).await.unwrap();
        assert_eq!(
            app.store.load_comet_hash(req.height.value()).unwrap(),
            Some(B256::from_slice(req.hash.as_bytes()))
        );
    }
    let comet = app.store.load_comet_hash(LANDED).unwrap().unwrap();
    let el = app.engine().state().chain[&LANDED].hash_slow();
    let mut restarted = app_with(
        fx.l1(),
        app.engine().reopen(),
        fx.params.clone(),
        dir.path(),
        crate::test_utils::test_options(),
    );
    target(&restarted, &fx, LANDED, el);
    let path = dir.path().join(format!("comet-hash-{LANDED}.json"));
    std::fs::remove_file(&path).unwrap();
    restarted.refresh_trust().await.unwrap();
    assert!(!restarted.trust.snapshot().is_ready());
    assert!(restarted.trust.snapshot().reason.unwrap().contains("missing committed Comet"));
    restarted.store.save_comet_hash(LANDED, comet).unwrap();
    restarted.refresh_trust().await.unwrap();
    assert!(restarted.trust.snapshot().is_ready());
    restarted.trust.begin_session();
    let inbox = InboxStorage {
        last_checkpoint_comet_hash: B256::repeat_byte(0xaa),
        ..landed(&restarted, &fx, LANDED)
    };
    fx.plant_l1_block(restarted.l1(), 101, &inbox);
    restarted.l1().set_finalized(101);
    assert!(matches!(restarted.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
    assert!(restarted.store.fatal_evidence().unwrap().is_some());
    assert!(matches!(
        App::new(
            fx.l1(),
            app.engine().reopen(),
            fx.params.clone(),
            Store::volatile(dir.path().into()),
            crate::test_utils::test_options()
        ),
        Err(AbciError::SafetyHalt(_))
    ));
}

#[tokio::test]
async fn decided_comet_hash_mismatch_halts_before_settle_even_when_el_matches() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)));
    let inbox = InboxStorage {
        last_checkpoint_height: 1,
        last_checkpoint_hash: env.block.header.hash_slow(),
        last_checkpoint_comet_hash: B256::repeat_byte(0xaa),
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 100, &inbox);
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
    let env = hand_envelope(app, witness);
    let req = process_req(app, next_height(app), bft_time(app), vec![env.encode()]);
    finalize(app, finalize_req(&req)).await.unwrap();
    commit(app).await.unwrap();
    B256::from_slice(req.hash.as_bytes())
}

/// The Inbox storage landing the committed `height` with the app's own EL and Comet hashes
/// there.
fn landed(app: &App<MockL1, MockEngine>, fx: &Fixture, height: u64) -> InboxStorage {
    InboxStorage {
        last_checkpoint_comet_hash: app.store.load_comet_hash(height).unwrap().expect("committed"),
        ..fx.inbox_at_checkpoint(height, app.engine().state().chain[&height].hash_slow())
    }
}

/// Plants L1 block `number` landing the committed `height` (see [`landed`]), and makes it
/// final.
fn finalize_landing(app: &App<MockL1, MockEngine>, fx: &Fixture, number: u64, height: u64) {
    fx.advance_l1(app.l1(), number, &landed(app, fx, height));
}

/// A checkpoint below the committed anchor's names pruned Comet history: while own finality
/// lags there, trust stays closed, and it opens once finality reaches the committed anchor.
#[tokio::test]
async fn lagging_own_finality_waits_for_a_checkpoint_with_retained_comet_history() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, 2 * LANDED).await;
    finalize_landing(&app, &fx, 65, LANDED);
    finalize_landing(&app, &fx, 66, 2 * LANDED);
    commit_next(&mut app, &fx, Some(66)).await;
    assert_eq!(app.store.load_comet_hash(LANDED).unwrap(), None, "below the anchored checkpoint");

    app.l1().set_finalized(65);
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().is_ready());

    app.l1().set_finalized(66);
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(snapshot.is_ready(), "{:?}", snapshot.reason);
    assert_eq!(snapshot.target.unwrap().height, 2 * LANDED);
}

/// A session target pinned before the committed anchor moved past it names pruned Comet
/// history: the next attempt acquires a current checkpoint instead of stalling on it.
#[tokio::test]
async fn pinned_target_below_the_comet_history_floor_is_reacquired() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, LANDED - 1).await;
    let env = next_envelope(&app, &fx);
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    let inbox = InboxStorage {
        last_checkpoint_comet_hash: B256::from_slice(req.hash.as_bytes()),
        ..fx.inbox_at_checkpoint(LANDED, env.block.header.hash_slow())
    };
    fx.advance_l1(app.l1(), 65, &inbox);
    app.refresh_trust().await.unwrap();
    let pinned = app.trust.snapshot().target.unwrap().height;
    assert_eq!(pinned, LANDED, "pinned above the head");
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    commit_to(&mut app, &fx, 2 * LANDED).await;
    finalize_landing(&app, &fx, 66, 2 * LANDED);
    commit_next(&mut app, &fx, Some(66)).await;
    assert_eq!(app.store.load_comet_hash(LANDED).unwrap(), None, "below the anchored checkpoint");

    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(snapshot.is_ready(), "{:?}", snapshot.reason);
    assert_eq!(snapshot.target.unwrap().height, 2 * LANDED);
}

/// Plants L1 block 100 holding `inbox` with its Inbox storage word at `slot` set to `word`
/// afterwards, and makes it final.
fn finalize_inbox_with_word(
    app: &App<MockL1, MockEngine>,
    fx: &Fixture,
    inbox: &InboxStorage,
    slot: B256,
    word: U256,
) {
    let mut account = inbox_account(fx.params.inbox, inbox);
    account.4.push((slot, word));
    let mut accounts = filler_accounts();
    accounts.push(account);
    app.l1().insert_block(l1_header(100, Fixture::l1_timestamp(100)), TestState::new(accounts));
    app.l1().set_finalized(100);
}

/// SYNC-9-5 5.h: trust needs only the EL and Comet hashes of the three-word slot 285 record
/// (STOR-B-9). It compares no validator state, at a checkpoint below the head that was never a
/// grid point or at the head, and it reads no fourth word, as an older record kept one.
#[tokio::test]
async fn trust_is_ready_on_a_three_word_record_without_a_validator_state_comparison() {
    for (checkpoint, fourth_word) in [(7, U256::ZERO), (8, U256::from_be_bytes([0x5a; 32]))] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        commit_to(&mut app, &fx, 8).await;
        let [.., comet_slot] = inbox::landing_record_slots(checkpoint);
        let after_record = B256::from(U256::from_be_bytes(comet_slot.0) + U256::from(1));
        finalize_inbox_with_word(
            &app,
            &fx,
            &landed(&app, &fx, checkpoint),
            after_record,
            fourth_word,
        );
        app.refresh_trust().await.unwrap();
        let snapshot = app.trust.snapshot();
        assert!(snapshot.is_ready(), "checkpoint {checkpoint}: {:?}", snapshot.reason);
        let target = snapshot.target.unwrap();
        assert_eq!(target.height, checkpoint);
        assert_eq!(target.hash, app.engine().state().chain[&checkpoint].hash_slow());
        assert_eq!(target.comet_hash, app.store.load_comet_hash(checkpoint).unwrap());
        assert!(app.store.fatal_evidence().unwrap().is_none());
    }
}

/// Asserts that `app`'s trust is ready at the target `height`.
fn assert_ready_at(app: &App<MockL1, MockEngine>, height: u64) {
    let snapshot = app.trust.snapshot();
    assert!(snapshot.is_ready(), "{:?}", snapshot.reason);
    assert_eq!(snapshot.target.unwrap().height, height);
}

/// STOR-B-23/24: a slot 285 record whose word 1 sets a reserved bit, from bit 144 up, is
/// malformed L1 data and halts, as a nonzero Comet hash in the start record does.
#[tokio::test]
async fn landing_record_with_a_reserved_bit_is_invalid() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let height = fx.inbox.last_checkpoint_height;
    let packed = U256::from(height) | (U256::from(1) << inbox::LandingRecord::RESERVED_BIT);
    finalize_inbox_with_word(&app, &fx, &fx.inbox, inbox::landing_record_slots(height)[0], packed);
    let error = app.refresh_trust().await.unwrap_err();
    assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
    assert!(error.to_string().contains("invalid checkpoint landing record"), "{error}");
    assert!(!app.trust.snapshot().is_ready());
}

/// A pinned target's landing record cannot change: a later proof of the same height whose
/// only difference is the Comet hash halts against the retained floor, whether the session
/// reads it again at the newer L1 block or a reconnect does.
#[tokio::test]
async fn pinned_target_changing_only_the_comet_hash_is_rejected() {
    for reconnect in [false, true] {
        let reason = "authenticated checkpoint conflicts with retained floor";
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        commit_to(&mut app, &fx, LANDED - 1).await;
        let env = next_envelope(&app, &fx);
        target(&app, &fx, LANDED, env.block.header.hash_slow());
        app.refresh_trust().await.unwrap();
        assert_eq!(app.trust.snapshot().target.unwrap().height, LANDED);
        let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
        finalize(&mut app, finalize_req(&req)).await.unwrap();
        commit(&mut app).await.unwrap();
        let changed = InboxStorage {
            last_checkpoint_comet_hash: B256::repeat_byte(0x5a),
            ..landed(&app, &fx, LANDED)
        };
        fx.advance_l1(app.l1(), 101, &changed);
        if reconnect {
            app.trust.begin_session();
        }
        let error = app.refresh_trust().await.unwrap_err();
        assert!(matches!(error, AbciError::SafetyHalt(_)), "{error}");
        assert!(error.to_string().contains(reason), "{error}");
        assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    }
}

/// Restarts `app` in place as a process over its store that a checkpoint import installed at
/// the committed head: the state gains that execution floor and the EL is not yet reconciled.
fn restart_as_imported(app: &mut App<MockL1, MockEngine>) -> crate::store::ExecutionFloor {
    let state = app.state.as_mut().expect("initialized");
    let floor = crate::store::ExecutionFloor { number: state.last_height, hash: state.parent.hash };
    state.execution_floor = Some(floor);
    app.el_reconciled_epoch = None;
    floor
}

/// SYNC-9-7: an imported node stays untrusted until the app checked its execution floor at the
/// current CometBFT handshake (on the current set of ABCI connections), however well the
/// checkpoint matches; the handshake `Info` check then lets trust proceed.
#[tokio::test]
async fn trust_stays_closed_until_the_execution_floor_is_checked() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    commit_to(&mut app, &fx, LANDED).await;
    let floor = restart_as_imported(&mut app);
    target(&app, &fx, LANDED, floor.hash);
    app.engine().state().historical_state.insert(floor.hash);

    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert!(!snapshot.is_ready());
    assert!(snapshot.reason.unwrap().contains("execution floor"));

    info(&mut app).await.expect("the EL serves the floor and its state");
    app.refresh_trust().await.unwrap();
    assert_ready_at(&app, LANDED);
    // SYNC-9-10 10.h: right after an import at s the only eligible height is s + 1.
    assert_eq!(app.trust.snapshot().eligible_height, Some(LANDED + 1));
}

/// A `FinalizeBlock` reaching an imported store before any `Info` still runs the startup
/// execution floor check first: an EL serving another block there halts before the block is
/// judged or executed (SYNC-9-7), and a matching EL lets it finalize.
#[tokio::test]
async fn finalize_block_first_checks_the_execution_floor() {
    for matching in [false, true] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        commit_to(&mut app, &fx, LANDED).await;
        let env = next_envelope(&app, &fx);
        let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
        let floor = restart_as_imported(&mut app);
        app.engine().state().historical_state.insert(floor.hash);
        if !matching {
            let mut engine = app.engine().state();
            let other = engine.chain.get_mut(&LANDED).unwrap();
            other.gas_used += 1;
        }
        app.engine().state().calls.clear();

        let result = finalize(&mut app, finalize_req(&req)).await;
        assert_eq!(
            app.engine().calls().first(),
            Some(&EngineCall::HeaderByNumber(LANDED)),
            "the floor check comes first"
        );
        if matching {
            result.expect("the EL serves the floor and its state");
            assert!(app.pending.is_some());
            assert!(app.el_reconciled());
        } else {
            let error = result.expect_err("the EL contradicts the import");
            assert!(matches!(error, AbciError::SafetyHalt(ref m) if m.contains("execution floor")));
            assert!(app.pending.is_none());
            assert_eq!(app.engine().calls().len(), 1);
        }
    }
}
