//! `Info`, `Query` and `CheckTx`, and `App::new` reloading the store.

use std::time::Duration;

use alloy_consensus::Header;
use alloy_primitives::{B256, U256};
use tendermint::abci::{Code, request::CheckTxKind};

use etna_core::staking::StakingWords;

use super::{
    proposal::next_height,
    signers::{MIN_STAKE, node, snapshot, step},
    *,
};
use crate::{
    app::{APP_NAME, APP_VERSION, Status},
    committee::{SignerSource, Unusable},
    config::{ConfigError, ParamsError},
    engine::PayloadVerdict,
    fallback::FallbackKeys,
    rules::RuleViolation,
    store::{ExecutionFloor, FallbackReason, SignerStatus, Signers, StoreError},
    test_utils::{
        EngineCall, InboxStorage, MockEngine, fallback_list, serve_fallback_keys, test_key,
    },
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
/// (and then re-sends InitChain). `InitChain` already made sure the EL holds the Etna start
/// block, so a later `Info` on the same ABCI connections does not ask the EL again.
#[tokio::test]
async fn info_at_genesis_reports_height_zero() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    assert!(
        app.engine().calls().contains(&EngineCall::HeaderByNumber(fx.genesis.genesis_height)),
        "InitChain checks the Etna start block on the EL"
    );
    app.engine().state().calls.clear();
    let resp = info(&mut app).await.expect("Info succeeds");
    assert_eq!(resp.last_block_height.value(), 0);
    assert!(resp.last_block_app_hash.as_bytes().is_empty());
    assert_eq!(app.engine().calls(), [], "InitChain reconciled the EL already");
}

#[tokio::test(start_paused = true)]
async fn info_retries_transient_engine_failure_on_the_same_abci_request() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);
    let mut app = fx.app(dir.path());
    app.engine().state().delay_script.push_back(Duration::from_secs(60));
    let response = info(&mut app).await.expect("temporary EL timeout must not fail ABCI");
    assert_eq!(response.last_block_height.value(), 0);
    assert!(!dir.path().join("fatal-evidence.txt").exists());
}

/// CometBFT also sends `Info` for every RPC `/abci_info` call, on the same sequential worker as
/// consensus: within one set of ABCI connections only the first `Info` (the handshake)
/// reconciles the EL, later ones answer from the committed state without EL I/O. A CometBFT
/// restart under the running app opens new connections and handshakes again: its `Info`
/// reconciles the EL again and answers only once the EL holds the committed head
/// (CONS-3.1-9, vector 9.o).
#[tokio::test(start_paused = true)]
async fn info_reconciles_the_el_again_after_comet_reconnects() {
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
    state.val_state = state.val_state.advance(&[]).unwrap();
    state.parent = ParentInfo {
        number: first.number,
        hash: first.hash_slow(),
        grandparent_timestamp: b_star.timestamp,
        timestamp: first.timestamp,
        ..state.parent
    };
    Store::volatile(dir.path().to_path_buf()).save(&state).unwrap();
    let mut chain = fx.el_chain.clone();
    chain.push(first.clone());
    let engine = MockEngine::with_chain(chain);
    let mut app =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());

    app.connections().bump();
    let handshake = info(&mut app).await.expect("the handshake Info reconciles");
    assert_eq!(app.engine().calls(), [EngineCall::HeaderByNumber(first.number)]);

    // Even an EL that went away is not asked again on the same connections.
    app.engine().state().calls.clear();
    app.engine().state().delay = Some(Duration::from_secs(3_600));
    for _ in 0..3 {
        let later = info(&mut app).await.expect("a later Info answers from the state");
        assert_eq!(later, handshake);
        assert_eq!(later.last_block_height.value(), first.number);
        assert_eq!(later.last_block_app_hash, crate::app::app_hash(&state));
    }
    assert_eq!(app.engine().calls(), [], "later Info calls make no engine call");

    // CometBFT restarts and connects again: its handshake Info asks the EL again.
    app.engine().state().delay = None;
    app.connections().bump();
    let again = info(&mut app).await.expect("the new handshake Info reconciles");
    assert_eq!(again, handshake);
    assert_eq!(app.engine().calls(), [EngineCall::HeaderByNumber(first.number)]);
    app.engine().state().calls.clear();
    assert_eq!(info(&mut app).await.expect("a later Info"), handshake);
    assert_eq!(app.engine().calls(), [], "the new connections reconciled already");

    // The EL lost the committed head before the next reconnect: that handshake Info does not
    // answer before the EL holds `first` again.
    {
        let mut engine = app.engine().state();
        engine.chain.remove(&first.number);
        engine.known.remove(&first.hash_slow());
    }
    app.connections().bump();
    assert!(
        tokio::time::timeout(Duration::from_secs(60), info(&mut app)).await.is_err(),
        "Info reported {} while the EL lacks it",
        first.number
    );
    assert!(
        app.engine().calls().contains(&EngineCall::Forkchoice {
            head: first.hash_slow(),
            safe: B256::ZERO,
            finalized: B256::ZERO
        }),
        "the EL is pointed at the committed head: {:?}",
        app.engine().calls()
    );
    app.engine().state().backfill.insert(first.number, first.clone());
    let synced = info(&mut app).await.expect("Info answers once the EL synced the head");
    assert_eq!(synced, handshake);
}

/// Cancelling a pending reconcile cannot mark it successful; the next `Info` retries it.
#[tokio::test(start_paused = true)]
async fn info_retries_a_failed_reconcile() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let opts =
        AppOptions { elsync_timeout: Duration::from_secs(30), ..crate::test_utils::test_options() };
    let mut app = app_with(fx.l1(), MockEngine::new(), fx.params.clone(), dir.path(), opts);
    assert!(tokio::time::timeout(Duration::from_secs(40), info(&mut app)).await.is_err());
    {
        let mut state = app.engine().state();
        for header in &fx.el_chain {
            state.known.insert(header.hash_slow(), header.clone());
            state.chain.insert(header.number, header.clone());
        }
    }
    let resp = info(&mut app).await.expect("the pending reconcile succeeds");
    assert_eq!(resp.last_block_height.value(), 0, "still at genesis");
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
    state.val_state = state.val_state.advance(&[]).unwrap();
    state.parent = ParentInfo {
        number: first.number,
        hash: first.hash_slow(),
        grandparent_timestamp: b_star.timestamp,
        timestamp: first.timestamp,
        ..state.parent
    };
    Store::volatile(dir.path().to_path_buf()).save(&state).unwrap();

    let mut chain = fx.el_chain.clone();
    chain.push(first.clone());
    let engine = MockEngine::with_chain(chain);
    let mut app =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let resp = info(&mut app).await.expect("Info succeeds");
    assert_eq!(resp.last_block_height.value(), first.number);
    assert_eq!(resp.last_block_app_hash, crate::app::app_hash(&state));
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
    let mut app =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
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
async fn info_stays_pending_when_the_el_has_not_reached_the_committed_block() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let opts =
        AppOptions { elsync_timeout: Duration::from_secs(30), ..crate::test_utils::test_options() };
    let mut app = app_with(fx.l1(), MockEngine::new(), fx.params.clone(), dir.path(), opts);
    assert!(tokio::time::timeout(Duration::from_secs(90), info(&mut app)).await.is_err());
    assert!(!dir.path().join("fatal-evidence.txt").exists());
}

#[tokio::test]
async fn info_halts_when_the_el_holds_another_committed_block() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    let mut other = fx.el_chain.clone();
    other[0].gas_used += 1;
    let engine = MockEngine::with_chain(other);
    let mut app =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
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
    let mut app =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let err = info(&mut app).await.expect_err("EL rejects the committed block");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
}

#[tokio::test(start_paused = true)]
async fn info_forkchoice_invalid_state_halts_but_transient_replies_recover() {
    for code in [-38002, -32603, -32000] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        drop(initialized(&fx, dir.path()).await);
        let engine = MockEngine::with_chain(fx.el_chain.clone());
        engine.state().chain.clear();
        engine.state().forkchoice_script.push_back(Err(crate::EngineError::ErrorReply {
            call: "engine_forkchoiceUpdatedV3".into(),
            code,
            message: "fixture refusal".into(),
        }));
        let mut app = app_with(
            fx.l1(),
            engine,
            fx.params.clone(),
            dir.path(),
            crate::test_utils::test_options(),
        );
        let result = info(&mut app).await;
        if code == -38002 {
            assert!(matches!(result, Err(AbciError::SafetyHalt(_))), "{result:?}");
            assert!(dir.path().join("fatal-evidence.txt").is_file());
            assert!(!app.trust.snapshot().is_ready());
        } else {
            assert_eq!(result.unwrap().last_block_height.value(), 0, "code {code}");
            assert!(!dir.path().join("fatal-evidence.txt").exists());
        }
    }
}

/// A store a checkpoint import installed at `floor` with blocks up to `head` committed since
/// ([`Fixture::imported_state`]), saved in `dir`, and an app started over it whose EL serves
/// `chain` and holds the state of the blocks named in `states`.
fn imported_app(
    fx: &Fixture,
    dir: &std::path::Path,
    state: &crate::store::AppState,
    chain: Vec<Header>,
    states: &[B256],
) -> App<MockL1, MockEngine> {
    Store::volatile(dir.into()).save(state).unwrap();
    let engine = MockEngine::with_chain(chain);
    engine.state().historical_state.extend(states.iter().copied());
    app_with(fx.l1(), engine, fx.params.clone(), dir, crate::test_utils::test_options())
}

/// DATA-5.4-4: the first `Info` over an imported store answers the landed head and its app hash
/// (its EL hash with the imported validator state) as `LastBlockAppHash`, after checking once that
/// the own EL serves the execution floor's block and holds its state; a later `Info` asks the EL
/// nothing.
#[tokio::test]
async fn info_checks_the_execution_floor_header_and_state_once() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let (state, chain) = fx.imported_state(12, 12);
    let h12 = state.execution_floor.unwrap().hash;
    let mut app = imported_app(&fx, dir.path(), &state, chain, &[h12]);

    let resp = info(&mut app).await.expect("the EL serves the floor and the head");
    assert_eq!(resp.last_block_height.value(), 12);
    assert_eq!(resp.last_block_app_hash, crate::app::app_hash(&state));
    assert_eq!(
        app.engine().calls(),
        [
            EngineCall::HeaderByNumber(12),
            EngineCall::HistoricalState(h12),
            EngineCall::HeaderByNumber(12)
        ],
        "the floor check, then the head check"
    );
    app.engine().state().calls.clear();
    assert_eq!(info(&mut app).await.unwrap(), resp);
    assert_eq!(app.engine().calls(), [], "the floor is checked once per connection set");
}

/// SYNC-9-7: an own EL serving another block at the execution floor contradicts the landed
/// import, even when it serves the committed head: a safety halt, recorded as fatal evidence.
#[tokio::test]
async fn info_halts_when_the_el_serves_another_block_at_the_execution_floor() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let (state, mut chain) = fx.imported_state(12, 13);
    let h12 = state.execution_floor.unwrap().hash;
    let other = chain.iter_mut().find(|header| header.number == 12).unwrap();
    other.gas_used += 1;
    let other = other.hash_slow();
    let mut app = imported_app(&fx, dir.path(), &state, chain, &[h12, other]);

    let error = info(&mut app).await.expect_err("the EL contradicts the import");
    let AbciError::SafetyHalt(message) = &error else { panic!("{error:?}") };
    assert!(message.contains("execution floor"), "{message}");
    assert!(message.contains(&other.to_string()) && message.contains(&h12.to_string()));
    assert!(dir.path().join("fatal-evidence.txt").is_file());
    assert!(!app.trust.snapshot().is_ready());
    assert_eq!(app.engine().calls(), [EngineCall::HeaderByNumber(12)], "the floor comes first");
}

/// SYNC-9-7: an own EL lacking the execution floor's block, or its state, is missing data: the
/// same `Info` stays pending and the node untrusted until the EL holds both.
#[tokio::test(start_paused = true)]
async fn info_waits_while_the_el_lacks_the_execution_floor_or_its_state() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let (state, mut chain) = fx.imported_state(12, 12);
    let h12 = state.execution_floor.unwrap().hash;
    let floor = chain.pop().unwrap();
    let mut app = imported_app(&fx, dir.path(), &state, chain, &[]);

    assert!(tokio::time::timeout(Duration::from_secs(60), info(&mut app)).await.is_err());
    assert!(!app.trust.snapshot().is_ready());
    assert!(app.trust.snapshot().reason.unwrap().contains("height 12"));
    assert!(!app.engine().calls().contains(&EngineCall::HistoricalState(h12)));
    {
        let mut engine = app.engine().state();
        engine.known.insert(h12, floor.clone());
        engine.chain.insert(12, floor);
    }
    assert!(tokio::time::timeout(Duration::from_secs(60), info(&mut app)).await.is_err());
    assert!(!app.trust.snapshot().is_ready());
    assert!(app.engine().calls().contains(&EngineCall::HistoricalState(h12)));

    app.engine().state().historical_state.insert(h12);
    let resp = info(&mut app).await.expect("the EL now holds the floor and its state");
    assert_eq!(resp.last_block_height.value(), 12);
    assert!(!dir.path().join("fatal-evidence.txt").exists());
}

/// The execution floor lies above the generation's origin and at or below the committed head:
/// a stored state with a floor outside that range is inconsistent.
#[test]
fn app_new_rejects_an_execution_floor_outside_the_committed_range() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let store = Store::volatile(dir.path().into());
    let (state, _) = fx.imported_state(12, 12);
    for number in [13, state.origin_height()] {
        let mut bad = state.clone();
        bad.execution_floor = Some(ExecutionFloor { number, ..state.execution_floor.unwrap() });
        store.save(&bad).unwrap();
        let err = App::new(
            fx.l1(),
            fx.engine(),
            fx.params.clone(),
            store.clone(),
            crate::test_utils::test_options(),
        )
        .expect_err("a floor outside the committed range");
        let floor_refused =
            matches!(err, AbciError::StoredState(ref m) if m.contains("execution floor"));
        assert!(floor_refused, "{err:?}");
    }
    store.save(&state).unwrap();
    App::new(fx.l1(), fx.engine(), fx.params.clone(), store, crate::test_utils::test_options())
        .expect("a floor at the head is in range");
}

#[test]
fn app_new_rejects_invalid_parameters() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let params = ChainParams { unsettled_limit: 0, ..fx.params.clone() };
    let err = App::new(
        fx.l1(),
        fx.engine(),
        params,
        Store::volatile(dir.path().into()),
        crate::test_utils::test_options(),
    )
    .expect_err("invalid parameters");
    assert!(
        matches!(err, AbciError::Config(ConfigError::Params(ParamsError::InvalidUnsettledLimit))),
        "{err:?}"
    );
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
        Store::volatile(dir.path().into()),
        crate::test_utils::test_options(),
    )
    .expect_err("stored chain id is for another chain");
    assert!(matches!(err, AbciError::ChainId(RuleViolation::InvalidChainId { .. })), "{err:?}");
}

#[tokio::test]
async fn app_new_rejects_a_changed_inbox_after_initialization() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);
    let mut params = fx.params.clone();
    params.inbox = alloy_primitives::Address::repeat_byte(0x11);
    let err = App::new(
        fx.l1(),
        fx.engine(),
        params,
        Store::volatile(dir.path().into()),
        crate::test_utils::test_options(),
    )
    .expect_err("Inbox differs from authenticated bootstrap");
    assert!(matches!(err, AbciError::StoredState(_)), "{err:?}");
}

#[tokio::test]
async fn app_new_rejects_a_changed_authenticated_unsettled_limit() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    // L = 20 is too short once the unsettled limit grows to 18.
    let params = ChainParams { unsettled_limit: 18, ..fx.params.clone() };
    let err = App::new(
        fx.l1(),
        fx.engine(),
        params,
        Store::volatile(dir.path().into()),
        crate::test_utils::test_options(),
    )
    .expect_err("stored schedule violates the unsettled limit");
    assert!(
        matches!(err, AbciError::StoredState(ref msg) if msg.contains("configuration")),
        "{err:?}"
    );
}

/// A state file of the previous schema is refused, never migrated: one in the previous shape (a
/// `parent_signers` list beside the validator state) does not even decode, and one in the current
/// shape claiming schema 22 fails the schema check.
#[test]
fn schema_22_state_is_refused() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let store = Store::volatile(dir.path().into());
    let open = |store: &Store| {
        App::new(
            fx.l1(),
            fx.engine(),
            fx.params.clone(),
            store.clone(),
            crate::test_utils::test_options(),
        )
    };
    assert_eq!(crate::store::STATE_SCHEMA_VERSION, 23);

    let mut old = fx.expected_state();
    old.schema_version = 22;
    store.save(&old).unwrap();
    let err = open(&store).expect_err("schema 22 is refused");
    assert!(
        matches!(&err, AbciError::StoredState(msg)
            if msg == "unsupported app state schema 22 (expected 23)"),
        "{err:?}"
    );

    let mut json = serde_json::to_value(&old).unwrap();
    json.as_object_mut().unwrap().insert("parent_signers".into(), serde_json::json!([]));
    std::fs::write(dir.path().join(crate::store::STATE_FILE), serde_json::to_vec(&json).unwrap())
        .unwrap();
    let err = open(&store).expect_err("the schema-22 shape does not decode");
    assert!(matches!(err, AbciError::Store(StoreError::Corrupt { .. })), "{err:?}");
}

#[tokio::test]
async fn app_new_rejects_an_inconsistent_stored_state() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let store = Store::volatile(dir.path().into());
    let good = fx.expected_state();

    let mut bad_generation = good.clone();
    bad_generation.generation = 1;
    let mut bad_genesis = good.clone();
    bad_genesis.genesis.genesis_height = 1;
    let mut bad_parent = good.clone();
    bad_parent.parent.number += 1;
    let mut bad_height = good.clone();
    bad_height.last_height = u64::MAX;
    bad_height.parent.number = u64::MAX;
    let mut bad_schema = good.clone();
    bad_schema.schema_version = crate::store::STATE_SCHEMA_VERSION + 1;
    let mut bad_val_state = good.clone();
    bad_val_state.val_state = good.val_state.advance(&[]).unwrap();

    for state in [bad_generation, bad_genesis, bad_parent, bad_height, bad_schema, bad_val_state] {
        store.save(&state).unwrap();
        let err = App::new(
            fx.l1(),
            fx.engine(),
            fx.params.clone(),
            store.clone(),
            crate::test_utils::test_options(),
        )
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
    assert_eq!(resp.height.value(), fx.genesis.genesis_height);
    let status: Status = serde_json::from_slice(&resp.value).expect("status JSON");
    assert_eq!(
        status,
        Status {
            execution_floor: None,
            head: fx.genesis.genesis_height,
            generation: 0,
            last_checkpoint_height: fx.genesis.genesis_height,
            anchor: fx.genesis.l1_0,
            signers: Signers::origin(&fx.fallback_keys),
            halt_reason: None,
            superseded: false,
            trust_phase: crate::app::trust::TrustPhase::Acquiring,
            trust_target: None,
            trusted_consensus_head: None,
            trust_reason: None,
        }
    );
    assert_eq!(app.status(), Some(status));
}

/// A node of `fx` after `InitChain` whose own L1 has finalized block 65, where the Inbox proves
/// the fallback list `keys` (served by `getFallbackKeys()`) and a minimum total stake of
/// [`MIN_STAKE`]: the generation's first block anchors there.
async fn anchored_on(
    fx: &Fixture,
    dir: &std::path::Path,
    keys: &FallbackKeys,
) -> App<MockL1, MockEngine> {
    let app = initialized(fx, dir).await;
    serve_fallback_keys(app.l1(), fx.params.inbox, keys);
    let inbox = InboxStorage {
        fallback_keys_hash: keys.hash(),
        min_total_stake: U256::from(MIN_STAKE),
        ..fx.inbox_with(fx.genesis.genesis_height)
    };
    fx.advance_l1(app.l1(), 65, &inbox);
    app
}

/// `/status` reports the set that signs the next height and the one after it, each with where
/// it comes from: the origin keys sign both after `InitChain`, for that reason alone; a decided
/// set carries the candidate's total stake and the minimum its anchor proves, the fallback list
/// that anchor proves is named by its hash and the reason it signs, a usable candidate by its
/// snapshot height. Each block shifts the pair by one, and a restarted app reports the same sets
/// from its store.
#[tokio::test]
async fn status_reports_both_sets() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let other = fallback_list(&[2, 3, 4]);
    let mut app = anchored_on(&fx, dir.path(), &other).await;
    let min = U256::from(MIN_STAKE);
    let origin = SignerStatus::origin(&fx.fallback_keys);
    let fallback = SignerStatus::fallback(&other, Unusable::StaleSnapshot, U256::ZERO, min);
    let candidate =
        |height, total: u64, size| SignerStatus::candidate(height, U256::from(total), min, size);
    let signers = |app: &App<MockL1, MockEngine>| app.status().expect("initialized").signers;
    assert_eq!(signers(&app), Signers { next: origin, after: origin });

    // No block-start call wrote this block's snapshot: all its words are zero.
    let h = next_height(&app);
    step(&mut app, None).await;
    assert_eq!(signers(&app), Signers { next: origin, after: fallback });

    let members = [(test_key(11), 5), (test_key(12), 7), (test_key(13), 1), (test_key(14), 2)];
    step(&mut app, Some(snapshot(h + 1, 4_000, &members))).await;
    assert_eq!(signers(&app), Signers { next: fallback, after: candidate(h + 1, 4_000, 4) });

    step(&mut app, Some(snapshot(h + 2, 5_000, &members[..3]))).await;
    let expected = Signers { next: candidate(h + 1, 4_000, 4), after: candidate(h + 2, 5_000, 3) };
    assert_eq!(signers(&app), expected);

    drop(app);
    assert_eq!(signers(&fx.app(dir.path())), expected, "the restarted app reads its store");
}

/// `/signers` answers the JSON of the two sets `/status` reports, at the committed height: each
/// names its source and fallback reason in lower case and writes the facts a set lacks as
/// `null`, and it decodes to the same value. Before `InitChain` it is refused.
#[tokio::test]
async fn signers_query_round_trips() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let resp = query(&mut fx.app(dir.path()), "/signers").await;
    assert_eq!(resp.code, Code::from(1));
    assert!(resp.value.is_empty() && !resp.log.is_empty(), "{resp:?}");

    let mut app = anchored_on(&fx, dir.path(), &fx.fallback_keys).await;
    let h = next_height(&app);
    let members = [(test_key(11), 5), (test_key(12), 7), (test_key(13), 1)];
    step(&mut app, Some(snapshot(h, 4_000, &members))).await;
    let resp = query(&mut app, "/signers").await;
    assert_eq!(resp.code, Code::Ok, "{}", resp.log);
    assert_eq!(resp.height.value(), h);
    let json: serde_json::Value = serde_json::from_slice(&resp.value).expect("signers JSON");
    assert_eq!(
        json,
        serde_json::json!({
            "next": {
                "source": "fallback",
                "fallback_reason": "generation_origin",
                "snapshot_height": null,
                "total_stake": null,
                "min_total_stake": null,
                "fallback_keys_hash": fx.fallback_keys.hash(),
                "size": 2,
            },
            "after": {
                "source": "candidate",
                "fallback_reason": null,
                "snapshot_height": h,
                "total_stake": "0xfa0",
                "min_total_stake": "0x3e8",
                "fallback_keys_hash": null,
                "size": 3,
            },
        })
    );
    let signers: Signers = serde_json::from_slice(&resp.value).expect("signers decode");
    assert_eq!(signers, app.status().unwrap().signers);
    assert_eq!(serde_json::to_vec(&signers).unwrap(), resp.value);
}

/// The status of the origin fallback keys of `fx` signing because the candidate, of stored total
/// stake `total`, fails the minimum `min` for `reason`.
fn falls_back(fx: &Fixture, reason: FallbackReason, total: U256, min: U256) -> SignerStatus {
    SignerStatus {
        source: SignerSource::Fallback,
        fallback_reason: Some(reason),
        snapshot_height: None,
        total_stake: Some(total),
        min_total_stake: Some(min),
        fallback_keys_hash: Some(fx.fallback_keys.hash()),
        size: 2,
    }
}

/// The status `/status` reports, after a node of `fx` whose anchor proves the minimum `min` has
/// committed its first block H with the candidate snapshot `words(H)`, of the set H decided.
async fn decided_at_first_block(
    fx: &Fixture,
    min: U256,
    words: impl FnOnce(u64) -> StakingWords,
) -> SignerStatus {
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(fx, dir.path(), min).await;
    let h = next_height(&app);
    step(&mut app, Some(words(h))).await;
    app.status().expect("initialized").signers.after
}

/// Two members at powers 5 and 7: a valid set.
fn members() -> [(crate::key::ConsensusKey, u64); 2] {
    [(test_key(11), 5), (test_key(12), 7)]
}

/// A minimum total stake of 2^256 − 1 hands H + 2 to the fallback keys even when H's own call
/// wrote a valid snapshot whose total stake is 2^256 − 1: the status names that reason beside
/// the total and the minimum.
#[tokio::test]
async fn status_reports_a_maximal_minimum_as_the_fallback_reason() {
    let fx = Fixture::genesis(2);
    let after = decided_at_first_block(&fx, U256::MAX, |h| StakingWords {
        total_stake: U256::MAX,
        ..snapshot(h, 0, &members())
    })
    .await;
    assert_eq!(after, falls_back(&fx, FallbackReason::MinTotalStakeMax, U256::MAX, U256::MAX));
}

/// A snapshot H's own call did not write, the one H − 1 stored, hands H + 2 to the fallback keys:
/// the status names a stale snapshot, with the total stake that snapshot stores.
#[tokio::test]
async fn status_reports_a_stale_snapshot_as_the_fallback_reason() {
    let fx = Fixture::genesis(2);
    let min = U256::from(MIN_STAKE);
    let after = decided_at_first_block(&fx, min, |h| snapshot(h - 1, 4_000, &members())).await;
    assert_eq!(after, falls_back(&fx, FallbackReason::StaleSnapshot, U256::from(4_000), min));
}

/// A total stake one below the minimum hands H + 2 to the fallback keys: the status shows both,
/// so the gap is visible while the fallback keys sign.
#[tokio::test]
async fn status_reports_a_total_below_the_minimum_as_the_fallback_reason() {
    let fx = Fixture::genesis(2);
    let min = U256::from(MIN_STAKE);
    let after = decided_at_first_block(&fx, min, |h| snapshot(h, MIN_STAKE - 1, &members())).await;
    let total = U256::from(MIN_STAKE - 1);
    assert_eq!(after, falls_back(&fx, FallbackReason::BelowMinTotalStake, total, min));
}

/// A snapshot whose records form no valid set, here a member at power 0, hands H + 2 to the
/// fallback keys although its total stake reaches the minimum: the status names an invalid set.
#[tokio::test]
async fn status_reports_an_invalid_set_as_the_fallback_reason() {
    let fx = Fixture::genesis(2);
    let min = U256::from(MIN_STAKE);
    let zero_power = [(test_key(11), 5), (test_key(12), 0)];
    let after = decided_at_first_block(&fx, min, |h| snapshot(h, 4_000, &zero_power)).await;
    assert_eq!(after, falls_back(&fx, FallbackReason::InvalidSet, U256::from(4_000), min));
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
async fn bad_queries_answer_code_one() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    // No committee is kept by epoch any more, so `/committee/<epoch>` is an unknown path.
    for path in
        ["/committee/0", "/committee/1", "/committee/x", "/committee", "/signers/0", "/nope", ""]
    {
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

#[test]
fn saved_state_rejects_old_and_unknown_protocol_versions() {
    let fx = Fixture::genesis(1);
    for version in [0, 4, 2, crate::app::APP_VERSION + 1] {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::volatile(dir.path().into());
        let mut state = fx.expected_state();
        state.app_version = version;
        store.save(&state).unwrap();
        let result = App::new(
            fx.l1(),
            fx.engine(),
            fx.params.clone(),
            store,
            crate::test_utils::test_options(),
        );
        assert!(
            matches!(result,Err(AbciError::StoredState(ref msg)) if msg.contains("app version"))
        );
    }
}

/// SYNC-9-5c: the handshake `Info` reports the committed head's height, app hash, local EL hash
/// and validator-state hash, whose app hash is the one it answers, and `Commit` the same values
/// for every committed height, so an operator facing a header AppHash mismatch in CometBFT,
/// whose refusal names the header's AppHash beside the app's, can compare them.
#[tokio::test]
async fn handshake_info_reports_the_app_hash_and_its_preimages() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let state = app.state().unwrap().clone();
    let report = crate::app::AppHashReport::of(&state);
    assert_eq!(report.height, state.last_height);
    assert_eq!(report.el_hash, state.parent.hash);
    assert_eq!(report.val_state_hash, state.val_state.hash());
    assert_eq!(report.app_hash.as_slice(), crate::app::app_hash(&state).as_bytes());

    app.connections().bump();
    let logs = crate::test_utils::LogCapture::start();
    info(&mut app).await.unwrap();
    let line = logs.at("INFO").into_iter().find(|line| line.contains("handshake Info"));
    let line = line.unwrap_or_else(|| panic!("no report: {}", logs.text()));
    assert!(line.contains(&report.to_string()), "{line}");

    let logs = crate::test_utils::LogCapture::start();
    super::proposal::step(&mut app).await;
    let committed = crate::app::AppHashReport::of(app.state().unwrap());
    assert_eq!(committed.height, report.height + 1);
    let line = logs.at("INFO").into_iter().find(|line| line.contains("block committed"));
    let line = line.unwrap_or_else(|| panic!("no commit report: {}", logs.text()));
    for value in [committed.app_hash, committed.el_hash, committed.val_state_hash] {
        assert!(line.contains(&value.to_string()), "{line}");
    }
    assert!(line.contains(&format!("height={}", committed.height)), "{line}");
}
