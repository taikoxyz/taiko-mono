//! `InitChain`: the happy path and every rejection.

use std::time::Duration;

use alloy_primitives::{Address, B256};
use tendermint::{Time, block::Height, vote};

use super::{
    proposal::{bft_time, finalize, finalize_req, hand_envelope, next_height, process_req},
    *,
};
use crate::{
    engine::PayloadVerdict,
    genesis::GenesisError,
    l1::{RawL1Header, witness::WitnessError},
    rules::{RuleViolation, chain_id_for},
    test_utils::{
        EngineCall, GenesisSpec, L1Call, MockEngine, TestState, edit_l1_header, fallback_list,
        filler_accounts, inbox_account, l1_header, test_key, validator_updates,
    },
    valstate::{ValState, app_hash},
};

#[tokio::test]
async fn init_chain_persists_the_verified_genesis_state() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());

    let resp = init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");
    assert!(resp.validators.is_empty());
    assert_eq!(resp.app_hash, crate::app::app_hash(&fx.expected_state()));
    assert_eq!(resp.consensus_params, None);

    let expected = fx.expected_state();
    assert_eq!(app.state(), Some(&expected));
    assert_eq!(Store::volatile(dir.path().to_path_buf()).load().unwrap(), Some(expected));

    // L1: only the finality check (finalized number and the canonical header at L1_0).
    assert_eq!(app.l1().calls(), [L1Call::Finalized, L1Call::CanonicalHash(fx.genesis.l1_0)]);
    // EL: already holds the Etna start block, so no forkchoice update.
    assert!(
        !app.engine().calls().iter().any(|c| matches!(c, EngineCall::Forkchoice { .. })),
        "{:?}",
        app.engine().calls()
    );
}

/// InitChain answers appHash(o), the origin's EL hash with CometBFT's genesis validator state of
/// the origin keys at o, not the EL hash alone.
#[tokio::test]
async fn init_chain_returns_the_app_hash_of_the_origin_and_its_genesis_validator_state() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());

    let resp = init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");

    let origin = fx.genesis.genesis_height;
    let genesis = ValState::genesis(origin, &fx.fallback_keys.validator_set()).unwrap();
    let expected = app_hash(fx.genesis_hash(), genesis.hash());
    assert_eq!(resp.app_hash.as_bytes(), expected.as_slice());
    assert_ne!(resp.app_hash.as_bytes(), fx.genesis_hash().as_slice());
}

#[tokio::test(start_paused = true)]
async fn init_chain_retries_transient_l1_failure_on_the_same_abci_request() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    app.l1().state().finalized_script.push_back(Err(crate::L1Error::Rpc("offline".into())));
    let response = init_chain(&mut app, fx.request.clone())
        .await
        .expect("temporary L1 failure must not fail ABCI");
    assert_eq!(response.app_hash, crate::app::app_hash(&fx.expected_state()));
    assert_eq!(app.state(), Some(&fx.expected_state()));
    assert!(!dir.path().join("fatal-evidence.txt").exists());
}

#[tokio::test]
async fn init_chain_latches_malformed_own_engine_reply_during_genesis_sync() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    app.engine().state().header_script.push_back(Err(crate::EngineError::BadReply("null".into())));
    let result = init_chain(&mut app, fx.request.clone()).await;
    assert!(matches!(result, Err(AbciError::SafetyHalt(_))), "{result:?}");
    assert_not_initialized(&app, dir.path());
    assert!(dir.path().join("fatal-evidence.txt").is_file());
}

/// The genesis validators, and so the set that signs S + 1 and S + 2, are the keys of the list
/// whose hash generation 0's origin record holds, each at power 1; the state keeps the list.
/// InitChain reads no list from L1: the request's validators name it, and the origin record
/// accepts it only under its hash.
#[tokio::test]
async fn init_chain_validators_are_the_origin_keys_at_power_one() {
    let fx = Fixture::genesis(4);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");
    let state = app.state().expect("initialized");
    assert_eq!(state, &fx.expected_state());
    let mut signing: Vec<_> = state
        .val_state
        .current
        .entries
        .iter()
        .map(|e| (e.key, u64::try_from(e.power).unwrap()))
        .collect();
    signing.sort();
    assert_eq!(signing, fx.fallback_keys.validator_set());
    assert!(fx.fallback_keys.validator_set().iter().all(|(_, power)| *power == 1));
    let mut next: Vec<_> = state
        .val_state
        .next
        .entries
        .iter()
        .map(|e| (e.key, u64::try_from(e.power).unwrap()))
        .collect();
    next.sort();
    assert_eq!(next, signing, "the origin keys sign the second block too");
    assert_eq!(state.fallback_keys.get(&fx.fallback_keys.hash()), Some(&fx.fallback_keys));
    assert!(
        !app.l1()
            .calls()
            .iter()
            .any(|c| matches!(c, L1Call::CallAt { .. } | L1Call::InboxLogs { .. })),
        "{:?}",
        app.l1().calls()
    );
}

/// The validators must be exactly the origin keys, each once at power 1: a key at power 2, a
/// missing key, an extra key and another valid list at power 1, whose hash the origin record
/// does not hold, are all refused, without any state.
#[tokio::test]
async fn init_chain_refuses_power_two_missing_extra_and_another_hash() {
    let fx = Fixture::genesis(3);
    let mut power_two = fx.request.clone();
    power_two.validators[1].power = vote::Power::from(2u32);
    let mut missing = fx.request.clone();
    missing.validators.pop();
    let mut extra = fx.request.clone();
    extra.validators.extend(validator_updates(&[(test_key(9), 1)]));
    let mut another = fx.request.clone();
    let other = fallback_list(&[4, 5, 6]);
    assert_ne!(other.hash(), fx.fallback_keys.hash());
    another.validators = validator_updates(&other.validator_set());
    for (case, req) in
        [("power two", power_two), ("missing", missing), ("extra", extra), ("another", another)]
    {
        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        let err = init_chain(&mut app, req).await.expect_err(case);
        assert!(matches!(err, AbciError::GenesisValidatorsMismatch(_)), "{case}: {err:?}");
        assert_not_initialized(&app, dir.path());
    }
}

/// An origin list of 128 keys, the most a list holds, starts the chain on all of them.
#[tokio::test]
async fn init_chain_accepts_128_keys() {
    let fx = Fixture::genesis(128);
    assert_eq!(fx.fallback_keys.keys().len(), 128);
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    let state = app.state().expect("initialized");
    assert_eq!(state.val_state.current.entries.len(), 128);
    assert_eq!(state, &fx.expected_state());
}

#[tokio::test]
async fn genesis_validators_are_compared_as_a_set() {
    let mut fx = Fixture::genesis(4);
    fx.request.validators.reverse();
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let resp = init_chain(&mut app, fx.request.clone()).await.expect("order is irrelevant");
    assert!(resp.validators.is_empty());
}

#[tokio::test]
async fn genesis_at_block_zero_has_a_zero_grandparent_timestamp() {
    let fx = Fixture::build(GenesisSpec { genesis_height: 0, ..GenesisSpec::new(1) });
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    let state = app.state().expect("initialized");
    assert_eq!(state.last_height, 0);
    assert_eq!(state.parent.grandparent_timestamp, 0);
    assert_eq!(state, &fx.expected_state());
}

#[tokio::test]
async fn a_later_generation_is_explicitly_unsupported() {
    let fx = Fixture::build(GenesisSpec { recovery_generation: 2, ..GenesisSpec::new(2) });
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    assert!(matches!(
        init_chain(&mut app, fx.request.clone()).await,
        Err(AbciError::Genesis(GenesisError::UnsupportedRecovery(_)))
    ));
    assert_not_initialized(&app, dir.path());
    assert!(app.engine().calls().is_empty());
}

/// CometBFT re-sends InitChain while the app reports height 0 (no PoS block yet): the same
/// genesis is re-verified and answered again, in the same process and after a restart.
#[tokio::test]
async fn init_chain_is_idempotent_at_genesis() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let first = init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");

    let again = init_chain(&mut app, fx.request.clone()).await.expect("re-sent InitChain");
    assert_eq!(again, first);
    assert_eq!(app.state(), Some(&fx.expected_state()));

    let mut app = fx.app(dir.path());
    let restarted = init_chain(&mut app, fx.request.clone()).await.expect("after a restart");
    assert_eq!(restarted, first);
    assert_eq!(app.state(), Some(&fx.expected_state()));
    assert_eq!(
        Store::volatile(dir.path().to_path_buf()).load().unwrap(),
        Some(fx.expected_state())
    );
    assert!(app.l1().calls().contains(&L1Call::CanonicalHash(fx.genesis.l1_0)), "re-verified");

    // The validators are echoed in the request's order, as on the first InitChain.
    let mut reordered = fx.request.clone();
    reordered.validators.reverse();
    let resp = init_chain(&mut app, reordered.clone()).await.expect("same genesis");
    assert!(resp.validators.is_empty());
}

/// CONS-3.1-9, vectors 9.r and 9.s: with S = 0 the node crashed between `FinalizeBlock` and
/// `Commit` of block 1. The restarted app still reports height 0 although the EL holds block 1,
/// CometBFT re-sends `InitChain`, and it answers the same `app_hash` as the first time; CometBFT
/// then finalizes block 1 again, with the same result.
#[tokio::test]
async fn re_sent_init_chain_after_a_crash_in_block_one_returns_the_same_app_hash() {
    let fx = Fixture::genesis(2);
    assert_eq!(fx.genesis.genesis_height, 0, "S = 0");
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let first = init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");

    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0)));
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    let decided = finalize(&mut app, finalize_req(&req)).await.expect("FinalizeBlock of block 1");
    let block_one = (fx.genesis.genesis_height + 1, env.block.header.clone());
    assert_eq!(app.engine().state().chain.get(&block_one.0), Some(&block_one.1), "EL holds it");
    let engine = app.engine().reopen();
    drop(app); // Crash before Commit: the store still holds the origin state.

    let mut app =
        app_with(fx.l1(), engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    assert_eq!(app.state(), Some(&fx.expected_state()));
    let resp = info(&mut app).await.expect("Info succeeds");
    assert_eq!(resp.last_block_height.value(), 0, "block 1 was never committed");
    assert!(resp.last_block_app_hash.as_bytes().is_empty());
    let again = init_chain(&mut app, fx.request.clone()).await.expect("re-sent InitChain");
    assert_eq!(again.app_hash, first.app_hash);
    assert_eq!(again, first);
    assert_eq!(app.engine().state().chain.get(&block_one.0), Some(&block_one.1), "still held");
    let replayed = finalize(&mut app, finalize_req(&req)).await.expect("FinalizeBlock again");
    assert_eq!(replayed, decided);
}

/// InitChain records the generation's genesis validator state at its origin as an immutable
/// sidecar, the base later states are recomputed from (SYNC-9-5c). A re-sent InitChain at the
/// origin saves it again, unchanged, and writes it when it is missing, as over a store
/// imported at the origin. A recovery InitChain records it at the recovery origin.
#[tokio::test]
async fn init_chain_records_the_genesis_validator_state() {
    use crate::{
        recovery::verify_recovery_witness, store::Record, test_utils::recovery_fixture,
        valstate::ValState,
    };
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let origin = fx.genesis.genesis_height;
    let genesis =
        Record::Valid(ValState::genesis(origin, &fx.fallback_keys.validator_set()).unwrap());
    assert_eq!(app.store.load_val_state(origin).unwrap(), genesis);
    let path = dir.path().join(format!("val-state-{origin}.bin"));
    let recorded = std::fs::read(&path).unwrap();

    init_chain(&mut app, fx.request.clone()).await.expect("re-sent InitChain");
    let mut app = fx.app(dir.path());
    init_chain(&mut app, fx.request.clone()).await.expect("re-sent after a restart");
    assert_eq!(std::fs::read(&path).unwrap(), recorded);
    std::fs::remove_file(&path).unwrap();
    init_chain(&mut app, fx.request.clone()).await.expect("re-sent without the record");
    assert_eq!(std::fs::read(&path).unwrap(), recorded);

    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let req = super::recovery_init::request(&super::recovery_init::document(&fx, &w));
    init_chain(&mut app, req.clone()).await.expect("recovery InitChain");
    let origin = verify_recovery_witness(&w, &fx.params).unwrap();
    assert_eq!(app.state().unwrap().origin_height(), origin.height);
    let genesis = ValState::genesis(
        origin.height,
        &crate::test_utils::recovery_fallback_keys().validator_set(),
    )
    .unwrap();
    assert_eq!(app.store.load_val_state(origin.height).unwrap(), Record::Valid(genesis.clone()));
    init_chain(&mut app, req).await.expect("re-sent at the recovery origin");
    assert_eq!(app.store.load_val_state(origin.height).unwrap(), Record::Valid(genesis));
}

#[tokio::test]
async fn init_chain_with_another_genesis_is_rejected() {
    let fx = Fixture::genesis(2);
    let other = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);

    // `other` verifies against its own L1 and EL, but starts another state.
    let mut app = app_with(
        other.l1(),
        other.engine(),
        other.params.clone(),
        dir.path(),
        crate::test_utils::test_options(),
    );
    let err = init_chain(&mut app, other.request.clone()).await.expect_err("another genesis");
    assert!(matches!(err, AbciError::AlreadyInitialized), "{err:?}");
    assert_eq!(app.state(), Some(&fx.expected_state()));
    assert_eq!(
        Store::volatile(dir.path().to_path_buf()).load().unwrap(),
        Some(fx.expected_state())
    );
}

#[tokio::test]
async fn init_chain_after_the_first_block_is_rejected() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut state = fx.expected_state();
    state.last_height += 1;
    state.parent.number += 1;
    state.val_state = state.val_state.advance(&[]).unwrap();
    Store::volatile(dir.path().to_path_buf()).save(&state).unwrap();

    let mut app = fx.app(dir.path());
    let err = init_chain(&mut app, fx.request.clone()).await.expect_err("past genesis");
    assert!(matches!(err, AbciError::AlreadyInitialized), "{err:?}");
    assert!(app.l1().calls().is_empty(), "nothing is re-verified past genesis");
    assert_eq!(app.state(), Some(&state));
}

/// A re-sent InitChain that no longer verifies reports why.
#[tokio::test]
async fn re_sent_init_chain_reports_a_verification_failure() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let mut req = fx.request.clone();
    req.chain_id = chain_id_for(&fx.params, 1).unwrap();
    let err = init_chain(&mut app, req).await.expect_err("generation 1 is not on L1");
    assert!(matches!(err, AbciError::ChainId(RuleViolation::InvalidChainId { .. })), "{err:?}");
    assert_eq!(app.state(), Some(&fx.expected_state()));
}

#[tokio::test]
async fn malformed_app_state_is_rejected() {
    let mut fx = Fixture::genesis(2);
    fx.request.app_state_bytes = b"{\"witness\": \"0x00\"}".to_vec().into();
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let err = init_chain(&mut app, fx.request.clone()).await.expect_err("bad app_state");
    assert!(matches!(err, AbciError::Genesis(GenesisError::Rlp(_))), "{err:?}");

    fx.request.app_state_bytes = b"null".to_vec().into();
    let err = init_chain(&mut app, fx.request.clone()).await.expect_err("bad app_state");
    assert!(matches!(err, AbciError::Genesis(GenesisError::Json(_))), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test(start_paused = true)]
async fn genesis_l1_block_above_finalized_waits_for_finality() {
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    l1.set_finalized(fx.genesis.l1_0 - 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    let l1 = app.l1.clone();
    let finalize = async {
        tokio::time::sleep(Duration::from_secs(10)).await;
        l1.set_finalized(fx.genesis.l1_0);
    };
    let (response, ()) = tokio::join!(init_chain(&mut app, req), finalize);
    assert!(response.is_ok(), "{response:?}");
    assert_eq!(app.state(), Some(&fx.expected_state()));
}

/// Waiting for genesis finality is a normal startup wait (about 13 minutes on Ethereum), not a
/// stuck request: InitChain keeps logging its retries at WARN past `FINALIZE_RETRY_ESCALATE`,
/// which only escalates `FinalizeBlock`'s retries to ERROR.
#[tokio::test(start_paused = true)]
async fn init_chain_waits_for_genesis_finality_at_warn() {
    use crate::{app::FINALIZE_RETRY_ESCALATE, test_utils::LogCapture};
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    l1.set_finalized(fx.genesis.l1_0 - 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    let l1 = app.l1.clone();
    let finalize = async {
        tokio::time::sleep(FINALIZE_RETRY_ESCALATE * 2).await;
        l1.set_finalized(fx.genesis.l1_0);
    };
    let logs = LogCapture::start();
    let (response, ()) = tokio::join!(init_chain(&mut app, req), finalize);
    assert!(response.is_ok(), "{response:?}");
    assert!(logs.at("WARN").len() > 20, "{}", logs.text());
    assert_eq!(logs.at("ERROR"), Vec::<String>::new());
}

#[tokio::test]
async fn non_canonical_genesis_l1_header_is_rejected() {
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    // The own L1 node holds a different block at L1_0.
    l1.insert_header(RawL1Header::from(&l1_header(fx.genesis.l1_0, 1)));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    let err = init_chain(&mut app, req).await.expect_err("not canonical");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test(start_paused = true)]
async fn slow_l1_keeps_init_chain_pending() {
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    l1.state().delay = Some(Duration::from_secs(60));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    assert!(
        tokio::time::timeout(Duration::from_secs(90), init_chain(&mut app, req)).await.is_err()
    );
    assert_not_initialized(&app, dir.path());
    assert!(!dir.path().join("fatal-evidence.txt").exists());
}

#[tokio::test]
async fn witness_of_another_inbox_is_rejected() {
    let fx = Fixture::genesis(2);
    let (l1, engine, mut params, req) = fx.parts();
    params.inbox = Address::repeat_byte(0x11);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    let err = init_chain(&mut app, req).await.expect_err("wrong inbox");
    assert!(
        matches!(&err, AbciError::Genesis(GenesisError::Witness(e)) if matches!(e.as_ref(), WitnessError::WrongContract { .. })),
        "{err:?}"
    );
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn genesis_header_must_be_the_initialization_block() {
    let mut fx = Fixture::genesis(2);
    let l1_0 = fx.genesis.l1_0;
    // Same L1 state, but the witness header is block L1_0 + 1 (canonical and final there).
    let mut witness = fx.witness.clone();
    witness.l1_header = edit_l1_header(&witness.l1_header, |h| h.number = l1_0 + 1);
    fx.set_witness(witness.clone());
    let (l1, engine, params, req) = fx.parts();
    l1.insert_header(witness.l1_header);
    l1.set_finalized(l1_0 + 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    let err = init_chain(&mut app, req).await.expect_err("header is not L1_0");
    assert!(
        matches!(err, AbciError::Genesis(GenesisError::InitializationMismatch { l1_0: header, proven: a }) if header == l1_0 + 1 && a == l1_0),
        "{err:?}"
    );
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn chain_id_generation_must_match_the_inbox() {
    let mut fx = Fixture::genesis(2);
    fx.request.chain_id = chain_id_for(&fx.params, 1).unwrap();
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let err = init_chain(&mut app, fx.request.clone()).await.expect_err("generation mismatch");
    assert!(matches!(err, AbciError::ChainId(RuleViolation::InvalidChainId { .. })), "{err:?}");

    for bad in ["taiko-etna-1-g0".to_string(), format!("taiko-etna-{}-g", fx.params.l2_chain_id)] {
        fx.request.chain_id = bad;
        let err = init_chain(&mut app, fx.request.clone()).await.expect_err("bad chain id");
        assert!(matches!(err, AbciError::ChainId(RuleViolation::InvalidChainId { .. })), "{err:?}");
    }
    assert_not_initialized(&app, dir.path());
}

/// Unsupported bootstrap records are refused before any Engine call or state write.
#[tokio::test]
async fn nonzero_genesis_height_is_rejected_before_el_work() {
    let fx = Fixture::build(GenesisSpec { genesis_height: 1, ..GenesisSpec::new(2) });
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    init_chain(&mut app, fx.request.clone()).await.expect_err("nonzero genesis");
    assert!(app.engine().calls().is_empty(), "no EL initialization for an invalid record");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn initial_height_must_be_one() {
    let mut fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    for wrong in [0, 2, 7] {
        fx.request.initial_height = Height::try_from(wrong).unwrap();
        let err = init_chain(&mut app, fx.request.clone()).await.expect_err("wrong height");
        assert!(
            matches!(err, AbciError::InitialHeight { got, expected } if got == wrong && expected == 1),
            "{err:?}"
        );
    }
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn genesis_time_must_equal_the_authenticated_initialization_time() {
    let fx = Fixture::genesis(2);
    let seconds = i64::try_from(fx.witness.l1_header.timestamp()).unwrap();
    for time in [
        Time::from_unix_timestamp(seconds - 1, 0).unwrap(),
        Time::from_unix_timestamp(seconds + 1, 0).unwrap(),
        Time::from_unix_timestamp(seconds, 1).unwrap(),
    ] {
        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        let mut req = fx.request.clone();
        req.time = time;
        let err = init_chain(&mut app, req).await.expect_err("altered genesis time");
        assert!(
            matches!(err, AbciError::GenesisTimeMismatch { got, .. } if got == time),
            "{err:?}"
        );
        assert_not_initialized(&app, dir.path());
    }
}

#[tokio::test]
async fn genesis_rejects_noncanonical_consensus_parameters() {
    let canonical = Fixture::genesis(2).request.consensus_params;
    let mut changes = Vec::new();
    let mut changed = canonical.clone();
    changed.block.as_mut().unwrap().max_bytes -= 1;
    changes.push(("block byte limit", changed));
    let mut changed = canonical.clone();
    changed.block.as_mut().unwrap().max_gas = 45_000_000;
    changes.push(("block gas limit", changed));
    let mut changed = canonical.clone();
    changed.evidence.as_mut().unwrap().max_age_num_blocks -= 1;
    changes.push(("evidence block age", changed));
    let mut changed = canonical.clone();
    changed.evidence.as_mut().unwrap().max_age_duration.as_mut().unwrap().seconds -= 1;
    changes.push(("evidence duration", changed));
    let mut changed = canonical.clone();
    changed.evidence.as_mut().unwrap().max_bytes = 1;
    changes.push(("evidence byte limit", changed));
    let mut changed = canonical.clone();
    changed.validator.as_mut().unwrap().pub_key_types.push("secp256k1".into());
    changes.push(("validator key types", changed));
    let mut changed = canonical.clone();
    changed.version.as_mut().unwrap().app = crate::app::APP_VERSION + 1;
    changes.push(("app version", changed));
    let mut changed = canonical.clone();
    changed.version = None;
    changes.push(("missing app version", changed));
    let mut changed = canonical;
    changed.abci.as_mut().unwrap().vote_extensions_enable_height = 1;
    changes.push(("vote extensions", changed));

    let fx = Fixture::genesis(2);
    for (field, params) in changes {
        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        let mut req = fx.request.clone();
        req.consensus_params = params;
        let err = init_chain(&mut app, req).await.expect_err("altered consensus parameters");
        assert!(matches!(err, AbciError::GenesisConsensusParamsMismatch), "{field}: {err:?}");
        assert_not_initialized(&app, dir.path());
    }
}

/// CometBFT's default evidence limits (100,000 blocks, 48 h), the earlier Etna parameters
/// (22,020,096 block bytes, 900 blocks, 1 h, 1 MiB of evidence) and another committee cap's
/// `block.max_bytes` are not START-10-21's for this deployment: old geneses are refused.
#[tokio::test]
async fn genesis_rejects_stock_default_and_earlier_consensus_limits() {
    use tendermint_proto::google::protobuf::Duration;
    let fx = Fixture::genesis(2);
    let edit = |f: &dyn Fn(&mut tendermint_proto::v0_38::types::ConsensusParams)| {
        let mut params = fx.request.consensus_params.clone();
        f(&mut params);
        params
    };
    let cases = [
        ("100,000 blocks", edit(&|p| p.evidence.as_mut().unwrap().max_age_num_blocks = 100_000)),
        (
            "48 h",
            edit(&|p| {
                p.evidence.as_mut().unwrap().max_age_duration =
                    Some(Duration { seconds: 172_800, nanos: 0 })
            }),
        ),
        (
            "earlier Etna limits",
            edit(&|p| {
                p.block.as_mut().unwrap().max_bytes = 22_020_096;
                let evidence = p.evidence.as_mut().unwrap();
                evidence.max_age_num_blocks = 900;
                evidence.max_age_duration = Some(Duration { seconds: 3_600, nanos: 0 });
                evidence.max_bytes = 1_048_576;
            }),
        ),
        (
            "another n_max",
            edit(&|p| {
                p.block.as_mut().unwrap().max_bytes =
                    crate::genesis::block_max_bytes(fx.params.n_max + 1)
            }),
        ),
    ];
    for (limit, params) in cases {
        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        let mut req = fx.request.clone();
        req.consensus_params = params;
        let err = init_chain(&mut app, req).await.expect_err("stock default evidence limit");
        assert!(matches!(err, AbciError::GenesisConsensusParamsMismatch), "{limit}: {err:?}");
        assert_not_initialized(&app, dir.path());
    }
}

#[tokio::test]
async fn genesis_state_root_must_match_the_authenticated_el_genesis() {
    let mut fx = Fixture::genesis(2);
    fx.genesis.genesis_state_root = B256::repeat_byte(0x88);
    fx.inbox.genesis.as_mut().unwrap().genesis_state_root = fx.genesis.genesis_state_root;
    let mut accounts = filler_accounts();
    accounts.push(inbox_account(fx.params.inbox, &fx.inbox));
    let state = TestState::new(accounts);
    let mut header = l1_header(fx.genesis.l1_0, Fixture::l1_timestamp(fx.genesis.l1_0));
    header.state_root = state.state_root();
    let mut witness = fx.witness.clone();
    witness.l1_header = RawL1Header::from(&header);
    witness.inbox = state.witness(fx.params.inbox, &crate::l1::layout::inbox::genesis_slots());
    fx.l1_state = state;
    fx.set_witness(witness);

    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let err =
        init_chain(&mut app, fx.request.clone()).await.expect_err("inconsistent start state root");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

/// An origin record naming a list the request's validators do not hash to is refused; the
/// genesis witness, not the request, fixes the list.
#[tokio::test]
async fn origin_record_naming_another_list_is_refused() {
    let fx = Fixture::build(GenesisSpec {
        origin_hash: Some(B256::repeat_byte(0xc0)),
        ..GenesisSpec::new(3)
    });
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let err = init_chain(&mut app, fx.request.clone()).await.expect_err("another origin hash");
    assert!(matches!(err, AbciError::GenesisValidatorsMismatch(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn genesis_validators_must_equal_the_origin_keys() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());

    let mut duplicate = fx.request.clone();
    duplicate.validators[2] = duplicate.validators[0];
    let mut empty = fx.request.clone();
    empty.validators.clear();
    let mut too_many = fx.request.clone();
    too_many.validators =
        validator_updates(&(1..=129).map(|seed| (test_key(seed), 1)).collect::<Vec<_>>());

    for req in [duplicate, empty, too_many] {
        let err = init_chain(&mut app, req).await.expect_err("validators mismatch");
        assert!(matches!(err, AbciError::GenesisValidatorsMismatch(_)), "{err:?}");
    }
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn el_missing_the_etna_start_is_synced_first() {
    let fx = Fixture::genesis(2);
    let (l1, _, params, req) = fx.parts();
    // The EL knows the Etna start block (and its parent) but has not made them canonical yet.
    let engine = MockEngine::new();
    for header in &fx.el_chain {
        engine.insert_known(header.clone());
    }
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, req).await.expect("InitChain succeeds after the EL sync");
    assert_eq!(app.state(), Some(&fx.expected_state()));
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
async fn el_that_has_not_reached_the_etna_start_keeps_init_chain_pending() {
    let fx = Fixture::genesis(2);
    let (l1, _, params, req) = fx.parts();
    let opts =
        AppOptions { elsync_timeout: Duration::from_secs(30), ..crate::test_utils::test_options() };
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, MockEngine::new(), params, dir.path(), opts);
    assert!(
        tokio::time::timeout(Duration::from_secs(90), init_chain(&mut app, req)).await.is_err()
    );
    assert_not_initialized(&app, dir.path());
    assert!(!dir.path().join("fatal-evidence.txt").exists());
}

#[tokio::test]
async fn el_holding_another_etna_start_is_a_safety_halt() {
    let fx = Fixture::genesis(2);
    let (l1, _, params, req) = fx.parts();
    let mut other = fx.el_chain.clone();
    other[0].timestamp += 1;
    let engine = MockEngine::with_chain(other);
    // The EL accepts the start hash as VALID but keeps serving its own block at the start height.
    engine.state().forkchoice_script.push_back(Ok(PayloadVerdict::Valid));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    let err = init_chain(&mut app, req).await.expect_err("EL disagrees");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn el_rejecting_the_etna_start_is_a_safety_halt() {
    let fx = Fixture::genesis(2);
    let (l1, _, params, req) = fx.parts();
    let engine = MockEngine::new();
    engine.state().forkchoice_script.push_back(Ok(PayloadVerdict::Invalid("bad block".into())));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    let err = init_chain(&mut app, req).await.expect_err("EL rejects the start hash");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn el_serving_another_block_after_sync_is_a_safety_halt() {
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    let mut other = fx.el_chain[0].clone();
    other.timestamp += 1;
    // ensure_block sees the Etna start block; the follow-up read of it returns another block.
    engine.state().header_script.extend([Ok(Some(fx.el_chain[0].clone())), Ok(Some(other))]);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
    let err = init_chain(&mut app, req).await.expect_err("EL changed its mind");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

/// The Inbox's configuration hash in slot 269 must be the one of the built-in L2 chain id,
/// staking proxy and U: a node whose built-in staking address is another refuses to start, at
/// InitChain and on a stored state.
#[tokio::test]
async fn startup_refuses_a_builtin_staking_address_that_misses_slot_269() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    drop(initialized(&fx, dir.path()).await);
    let mut wrong = fx.clone();
    wrong.params.staking = Address::repeat_byte(0x5a);
    let (proven, local) = (fx.genesis.config_hash, wrong.params.config_hash());
    assert_ne!(proven, local);
    let empty = tempfile::tempdir().unwrap();
    let mut app = wrong.app(empty.path());
    let err = init_chain(&mut app, fx.request.clone()).await.unwrap_err();
    assert!(
        matches!(err, AbciError::Genesis(GenesisError::ConfigMismatch { local: l, proven: p })
            if l == local && p == proven),
        "{err:?}"
    );
    assert_not_initialized(&app, empty.path());
    let error = App::new(
        wrong.l1(),
        wrong.engine(),
        wrong.params.clone(),
        Store::volatile(dir.path().into()),
        crate::test_utils::test_options(),
    )
    .expect_err("another staking address opened the stored state");
    assert!(
        matches!(&error, AbciError::StoredState(message) if message.contains("configuration hash")),
        "{error:?}"
    );
}

#[tokio::test]
async fn genesis_rejects_a_different_unsettled_limit() {
    let mut fx = Fixture::genesis(2);
    let proven = fx.genesis.config_hash;
    fx.params.unsettled_limit -= 6;
    let local = fx.params.config_hash();
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let err = init_chain(&mut app, fx.request.clone()).await.unwrap_err();
    assert!(
        matches!(err, AbciError::Genesis(GenesisError::ConfigMismatch {local:l,proven:p}) if l==local && p==proven)
    );
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn lost_state_rejects_old_app_zero_genesis_before_replay() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let mut request = fx.request.clone();
    request.consensus_params.version.as_mut().unwrap().app = 0;
    assert!(matches!(
        init_chain(&mut app, request).await,
        Err(AbciError::GenesisConsensusParamsMismatch)
    ));
    assert_not_initialized(&app, dir.path());
}

/// Back-pressure values are per-chain configuration authenticated at genesis and restart.
#[tokio::test]
async fn genesis_and_restart_authenticate_chain_specific_back_pressure_parameters() {
    let params =
        ChainParams::builtin(167001).unwrap().with_overrides("unsettled_limit = 24").unwrap();
    let fx = Fixture::build(GenesisSpec { params, ..GenesisSpec::new(2) });
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    let expected = app.state().unwrap().clone();
    drop(app);
    let mut reopened = fx.app(dir.path());
    info(&mut reopened).await.unwrap();
    assert_eq!(reopened.state(), Some(&expected));
    drop(reopened);
    let limit = fx.params.unsettled_limit;
    for (case, unsettled_limit) in [("smaller", limit - 6), ("larger", limit + 6)] {
        let mut wrong = fx.clone();
        wrong.params.unsettled_limit = unsettled_limit;
        let empty_dir = tempfile::tempdir().unwrap();
        let mut app = wrong.app(empty_dir.path());
        assert!(
            matches!(
                init_chain(&mut app, fx.request.clone()).await,
                Err(AbciError::Genesis(GenesisError::ConfigMismatch { .. }))
            ),
            "a {case} unsettled limit opened genesis"
        );
        assert_not_initialized(&app, empty_dir.path());
        let error = App::new(
            wrong.l1(),
            wrong.engine(),
            wrong.params,
            Store::volatile(dir.path().into()),
            crate::test_utils::test_options(),
        )
        .expect_err("wrong back-pressure configuration opened stored state");
        assert!(
            matches!(error, AbciError::StoredState(message)
            if message.contains("configuration hash")),
            "a {case} unsettled limit opened persisted state"
        );
    }
}
