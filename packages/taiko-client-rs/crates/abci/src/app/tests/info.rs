//! `Info`, `Query` and `CheckTx`, and `App::new` reloading the store.

use std::time::Duration;

use alloy_consensus::Header;
use alloy_primitives::B256;
use tendermint::abci::{Code, request::CheckTxKind};

use super::*;
use crate::{
    app::{APP_NAME, APP_VERSION, Status},
    config::ConfigError,
    elsync::ElSyncError,
    engine::PayloadVerdict,
    rules::RuleViolation,
    schedule::ScheduleError,
    store::CommitteeState,
    test_utils::{EngineCall, MockEngine},
    types::ParentInfo,
};

#[tokio::test]
async fn info_before_init_chain_reports_height_zero() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let resp = info(&mut app).await.expect("Info succeeds");
    assert_eq!(resp.data, APP_NAME);
    assert_eq!(resp.data, "taiko-abci");
    assert_eq!(resp.version, env!("CARGO_PKG_VERSION"));
    assert_eq!(resp.app_version, APP_VERSION);
    assert_eq!(resp.last_block_height.value(), 0);
    assert!(resp.last_block_app_hash.as_bytes().is_empty());
    assert!(app.engine().calls().is_empty(), "nothing to reconcile before InitChain");
}

/// Before the first PoS block CometBFT's store is empty: it accepts only an app at height 0
/// (and then re-sends InitChain). `InitChain` already made sure the EL holds `B*`, so a later
/// `Info` of the same process does not ask the EL again.
#[tokio::test]
async fn info_at_genesis_reports_height_zero() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    assert!(
        app.engine().calls().contains(&EngineCall::HeaderByNumber(fx.activation.genesis_height)),
        "InitChain checks B* on the EL"
    );
    app.engine().state().calls.clear();
    let resp = info(&mut app).await.expect("Info succeeds");
    assert_eq!(resp.last_block_height.value(), 0);
    assert!(resp.last_block_app_hash.as_bytes().is_empty());
    assert_eq!(app.engine().calls(), [], "InitChain reconciled the EL already");
}

/// CometBFT also sends `Info` for every RPC `/abci_info` call, on the same sequential worker as
/// consensus: only the first `Info` after a start (the handshake) reconciles the EL, later ones
/// answer from the committed state without EL I/O.
#[tokio::test(start_paused = true)]
async fn only_the_first_info_after_a_start_reconciles_the_el() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let b_star = fx.el_chain.last().unwrap().clone();
    let first = Header {
        number: b_star.number + 1,
        parent_hash: b_star.hash_slow(),
        timestamp: b_star.timestamp + 2,
        ..b_star.clone()
    };
    let mut state = fx.expected_state();
    state.last_height = first.number;
    state.parent = ParentInfo {
        number: first.number,
        hash: first.hash_slow(),
        grandparent_timestamp: b_star.timestamp,
        timestamp: first.timestamp,
        ..state.parent
    };
    Store::new(dir.path().to_path_buf()).save(&state).unwrap();
    let mut chain = fx.el_chain.clone();
    chain.push(first.clone());
    let engine = MockEngine::with_chain(chain);
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());

    let handshake = info(&mut app).await.expect("the handshake Info reconciles");
    assert_eq!(app.engine().calls(), [EngineCall::HeaderByNumber(first.number)]);

    // Even an EL that went away is not asked again.
    app.engine().state().calls.clear();
    app.engine().state().delay = Some(Duration::from_secs(3_600));
    for _ in 0..3 {
        let later = info(&mut app).await.expect("a later Info answers from the state");
        assert_eq!(later, handshake);
        assert_eq!(later.last_block_height.value(), first.number);
        assert_eq!(later.last_block_app_hash.as_bytes(), first.hash_slow().as_slice());
    }
    assert_eq!(app.engine().calls(), [], "later Info calls make no engine call");
}

/// A failed reconcile is not remembered: the next `Info` tries again.
#[tokio::test(start_paused = true)]
async fn info_retries_a_failed_reconcile() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let opts = AppOptions { elsync_timeout: Duration::from_secs(30), ..AppOptions::default() };
    let mut app = app_with(fx.l1(), MockEngine::new(), fx.params.clone(), dir.path(), opts);
    info(&mut app).await.expect_err("the EL never syncs");

    // The EL catches up (e.g. after its own restart); the next Info reconciles and succeeds.
    {
        let mut engine = app.engine().state();
        for header in &fx.el_chain {
            engine.known.insert(header.hash_slow(), header.clone());
            engine.chain.insert(header.number, header.clone());
        }
        engine.calls.clear();
    }
    let resp = info(&mut app).await.expect("the retried reconcile succeeds");
    assert_eq!(resp.last_block_height.value(), 0, "still at genesis");
    assert_eq!(app.engine().calls(), [EngineCall::HeaderByNumber(fx.activation.genesis_height)]);

    app.engine().state().calls.clear();
    info(&mut app).await.expect("Info succeeds");
    assert_eq!(app.engine().calls(), [], "the successful reconcile is remembered");
}

#[tokio::test]
async fn app_new_reloads_the_persisted_state() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let mut app = fx.app(dir.path());
    assert_eq!(app.state(), Some(&fx.expected_state()));
    let resp = info(&mut app).await.expect("Info succeeds");
    assert_eq!(resp.last_block_height.value(), 0, "still at genesis");
    assert!(resp.last_block_app_hash.as_bytes().is_empty());
}

#[tokio::test]
async fn info_after_the_first_block_reports_the_committed_head() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let b_star = fx.el_chain.last().unwrap().clone();
    let first = Header {
        number: b_star.number + 1,
        parent_hash: b_star.hash_slow(),
        timestamp: b_star.timestamp + 2,
        ..b_star.clone()
    };
    let mut state = fx.expected_state();
    state.last_height = first.number;
    state.parent = ParentInfo {
        number: first.number,
        hash: first.hash_slow(),
        grandparent_timestamp: b_star.timestamp,
        timestamp: first.timestamp,
        ..state.parent
    };
    Store::new(dir.path().to_path_buf()).save(&state).unwrap();

    let mut chain = fx.el_chain.clone();
    chain.push(first.clone());
    let engine = MockEngine::with_chain(chain);
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());
    let resp = info(&mut app).await.expect("Info succeeds");
    assert_eq!(resp.last_block_height.value(), first.number);
    assert_eq!(resp.last_block_app_hash.as_bytes(), first.hash_slow().as_slice());
}

#[tokio::test]
async fn info_syncs_an_el_missing_the_committed_block() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    // Restart against an EL that knows the committed block but has not made it canonical.
    let engine = MockEngine::new();
    for header in &fx.el_chain {
        engine.insert_known(header.clone());
    }
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());
    let resp = info(&mut app).await.expect("Info succeeds after the EL sync");
    assert_eq!(resp.last_block_height.value(), 0, "still at genesis");
    let h = fx.genesis_hash();
    assert!(
        app.engine().calls().contains(&EngineCall::Forkchoice {
            head: h,
            safe: B256::ZERO,
            finalized: B256::ZERO
        }),
        "{:?}",
        app.engine().calls()
    );
}

#[tokio::test(start_paused = true)]
async fn info_fails_when_the_el_never_reaches_the_committed_block() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let opts = AppOptions { elsync_timeout: Duration::from_secs(30), ..AppOptions::default() };
    let mut app = app_with(fx.l1(), MockEngine::new(), fx.params.clone(), dir.path(), opts);
    let err = info(&mut app).await.expect_err("EL never syncs");
    assert!(matches!(err, AbciError::ElSync(ElSyncError::Timeout { .. })), "{err:?}");
}

#[tokio::test]
async fn info_halts_when_the_el_holds_another_committed_block() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let mut other = fx.el_chain.clone();
    other[1].gas_used += 1;
    let engine = MockEngine::with_chain(other);
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());
    let err = info(&mut app).await.expect_err("EL disagrees with the app state");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert!(
        !app.engine().calls().iter().any(|c| matches!(c, EngineCall::Forkchoice { .. })),
        "a conflicting EL is not re-pointed"
    );
}

#[tokio::test]
async fn info_halts_when_the_el_rejects_the_committed_block() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let engine = MockEngine::new();
    engine.state().forkchoice_script.push_back(Ok(PayloadVerdict::Invalid("bad".into())));
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), AppOptions::default());
    let err = info(&mut app).await.expect_err("EL rejects the committed block");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
}

#[test]
fn app_new_rejects_invalid_parameters() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let params = ChainParams { n_max: 0, ..fx.params.clone() };
    let err = App::new(
        fx.l1(),
        fx.engine(),
        params,
        Store::new(dir.path().into()),
        AppOptions::default(),
    )
    .expect_err("invalid parameters");
    assert!(matches!(err, AbciError::Config(ConfigError::ZeroNMax)), "{err:?}");
}

#[tokio::test]
async fn app_new_rejects_a_stored_state_of_another_chain() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let params = ChainParams { l2_chain_id: fx.params.l2_chain_id + 1, ..fx.params.clone() };
    let err = App::new(
        fx.l1(),
        fx.engine(),
        params,
        Store::new(dir.path().into()),
        AppOptions::default(),
    )
    .expect_err("stored chain id is for another chain");
    assert!(matches!(err, AbciError::ChainId(RuleViolation::InvalidChainId { .. })), "{err:?}");
}

#[tokio::test]
async fn app_new_rejects_a_stored_schedule_violating_the_cap() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    // L = 20 is too short once the cap grows to 18.
    let params = ChainParams { d_max: 20, ..fx.params.clone() };
    let err = App::new(
        fx.l1(),
        fx.engine(),
        params,
        Store::new(dir.path().into()),
        AppOptions::default(),
    )
    .expect_err("stored schedule violates the cap");
    assert!(
        matches!(err, AbciError::Schedule(ScheduleError::EpochShorterThanCap { .. })),
        "{err:?}"
    );
}

#[tokio::test]
async fn app_new_rejects_an_inconsistent_stored_state() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let store = Store::new(dir.path().into());
    let good = fx.expected_state();

    let mut bad_generation = good.clone();
    bad_generation.generation = 1;
    let mut bad_schedule = good.clone();
    bad_schedule.schedule.l1_0 += 1;
    let mut bad_parent = good.clone();
    bad_parent.parent.number += 1;
    let mut bad_height = good.clone();
    bad_height.last_height = u64::MAX;
    bad_height.parent.number = u64::MAX;

    for state in [bad_generation, bad_schedule, bad_parent, bad_height] {
        store.save(&state).unwrap();
        let err =
            App::new(fx.l1(), fx.engine(), fx.params.clone(), store.clone(), AppOptions::default())
                .expect_err("inconsistent stored state");
        assert!(matches!(err, AbciError::StoredState(_)), "{err:?}");
    }
}

#[tokio::test]
async fn status_query_reports_the_committed_head() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let resp = query(&mut app, "/status").await;
    assert_eq!(resp.code, Code::Ok, "{}", resp.log);
    assert_eq!(resp.height.value(), fx.activation.genesis_height);
    let status: Status = serde_json::from_slice(&resp.value).expect("status JSON");
    assert_eq!(
        status,
        Status {
            head: fx.activation.genesis_height,
            epoch: 0,
            generation: 0,
            last_checkpoint_height: fx.activation.genesis_height,
            anchor: fx.activation.l1_0,
            halt_reason: None,
            superseded: false,
        }
    );
    assert_eq!(app.status(), Some(status));
}

#[tokio::test]
async fn status_query_before_init_chain_is_an_error() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let resp = query(&mut app, "/status").await;
    assert_eq!(resp.code, Code::from(1));
    assert!(resp.value.is_empty());
    assert_eq!(resp.height.value(), 0);
    assert_eq!(app.status(), None);
}

#[tokio::test]
async fn committee_query_returns_a_known_committee() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let resp = query(&mut app, "/committee/0").await;
    assert_eq!(resp.code, Code::Ok, "{}", resp.log);
    let committee: CommitteeState = serde_json::from_slice(&resp.value).expect("committee JSON");
    assert_eq!(
        committee,
        CommitteeState { record: fx.record.clone(), members: fx.members.clone() }
    );
}

#[tokio::test]
async fn bad_queries_answer_code_one() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for path in ["/committee/1", "/committee/x", "/committee/", "/committee", "/nope", ""] {
        let resp = query(&mut app, path).await;
        assert_eq!(resp.code, Code::from(1), "{path:?}");
        assert!(!resp.log.is_empty(), "{path:?}");
        assert!(resp.value.is_empty(), "{path:?}");
    }
    let resp = query(&mut app, "/nope").await;
    assert!(resp.log.contains("/nope"), "{}", resp.log);
}

#[tokio::test]
async fn check_tx_rejects_every_transaction() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    for kind in [CheckTxKind::New, CheckTxKind::Recheck] {
        let req = request::CheckTx { tx: vec![0x02, 0xf8].into(), kind };
        let Response::CheckTx(resp) = app.handle(Request::CheckTx(req)).await.unwrap() else {
            panic!("CheckTx answered another response");
        };
        assert_eq!(resp.code, Code::from(1));
        assert_eq!(resp.log, "transactions go to the execution layer");
    }
}
