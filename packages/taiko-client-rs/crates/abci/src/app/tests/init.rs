//! `InitChain`: the happy path and every rejection.

use std::time::Duration;

use alloy_primitives::{Address, B256};
use tendermint::{Time, block::Height, vote};

use super::*;
use crate::{
    committee::{self, CommitteeError, verify_committee_witness_at_cutoff},
    elsync::ElSyncError,
    engine::PayloadVerdict,
    genesis::GenesisError,
    l1::{RawL1Header, witness::WitnessError},
    rules::{RuleViolation, chain_id_for},
    schedule::Schedule,
    test_utils::{
        EngineCall, GenesisSpec, L1Call, MockEngine, TestState, committee_witness, edit_l1_header,
        filler_accounts, inbox_account, l1_header, registry_account, sample_entries,
    },
    types::RegistryEntry,
};

#[tokio::test]
async fn init_chain_persists_the_verified_genesis_state() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());

    let resp = init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");
    assert!(resp.validators.is_empty());
    assert_eq!(resp.app_hash.as_bytes(), fx.genesis_hash().as_slice());
    assert_eq!(resp.consensus_params, None);

    let expected = fx.expected_state();
    assert_eq!(app.state(), Some(&expected));
    assert_eq!(Store::volatile(dir.path().to_path_buf()).load().unwrap(), Some(expected));

    // L1: only the finality check (finalized number and the canonical header at L1_0).
    assert_eq!(app.l1().calls(), [L1Call::Finalized, L1Call::CanonicalHash(fx.genesis.l1_0)]);
    // EL: already holds B*, so no forkchoice update.
    assert!(
        !app.engine().calls().iter().any(|c| matches!(c, EngineCall::Forkchoice { .. })),
        "{:?}",
        app.engine().calls()
    );
}

/// The `e_0` committee is the active bonded set unfiltered by heartbeats: a genesis
/// whose entries never sent one initializes the chain.
#[tokio::test]
async fn a_genesis_committee_without_heartbeats_initializes() {
    let entries: Vec<RegistryEntry> = sample_entries(2);
    let fx = Fixture::build(GenesisSpec { entries: Some(entries), ..GenesisSpec::new(2) });
    assert_eq!(fx.members.len(), 2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let resp = init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");
    assert!(resp.validators.is_empty());
    assert_eq!(app.state(), Some(&fx.expected_state()));
}

/// Genesis derives at explicit snapshot 63; entries active from 62 remain inactive at 59.
#[tokio::test]
async fn the_genesis_committee_is_derived_at_the_genesis_cutoff() {
    let fx = Fixture::build(GenesisSpec::eligible_at_explicit_genesis_snapshot(2));
    let (l1_0, genesis_cutoff) = (fx.genesis.l1_0, fx.genesis.genesis_cutoff);
    assert_eq!((l1_0, genesis_cutoff), (64, 63));
    assert!(fx.registry.checkpoints[0].1.iter().all(|e| e.active_from_l1 == 62));
    // At explicit snapshot 59 the registry mutation checkpoint is the same, but no
    // entry is active yet.
    let earlier = 59;
    assert_eq!(
        verify_committee_witness_at_cutoff(
            fx.witness.l1_header.state_root(),
            earlier,
            &fx.params,
            &fx.witness.committee,
            Schedule::E0
        ),
        Err(CommitteeError::Empty)
    );

    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let resp = init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");
    assert!(resp.validators.is_empty());
    assert_eq!(app.state().unwrap().committees[&0].members.len(), 2);
    let state = app.state().expect("initialized");
    assert_eq!(state, &fx.expected_state());
    let e0 = &state.committees[&0];
    assert_eq!(e0.record.cutoff_l1_block, genesis_cutoff);
    let pubkeys: Vec<crate::key::ConsensusKey> = e0.members.iter().map(|m| m.pubkey).collect();
    let mut expected: Vec<crate::key::ConsensusKey> =
        fx.registry.checkpoints[0].1.iter().map(|e| e.consensus_key().unwrap()).collect();
    expected.sort_by_key(|pubkey| committee::set_key(fx.params.l2_chain_id, *pubkey));
    assert_eq!(pubkeys, expected);
}

/// The Inbox's `genesisCutoff` must lie before `L1_0`.
#[tokio::test]
async fn a_genesis_cutoff_not_before_l1_0_is_rejected() {
    for genesis_cutoff in [64, 65] {
        let fx = Fixture::build(GenesisSpec { genesis_cutoff, ..GenesisSpec::new(2) });
        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        let err = init_chain(&mut app, fx.request.clone()).await.expect_err("cutoff at L1_0");
        assert!(
            matches!(&err, AbciError::Genesis(GenesisError::Witness(e)) if matches!(e.as_ref(),
                WitnessError::GenesisCutoffNotBeforeInitialization { genesis_cutoff: c, l1_0: 64 }
                if *c == genesis_cutoff)),
            "{err:?}"
        );
        assert_not_initialized(&app, dir.path());
    }
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
    assert_eq!(state.schedule().h0(), 1);
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
        AppOptions::default(),
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

#[tokio::test]
async fn genesis_l1_block_above_finalized_is_rejected() {
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    l1.set_finalized(fx.genesis.l1_0 - 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
    let err = init_chain(&mut app, req).await.expect_err("not final");
    assert!(
        matches!(err, AbciError::GenesisNotFinal { number, .. } if number == fx.genesis.l1_0),
        "{err:?}"
    );
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn genesis_l1_block_within_the_extra_depth_is_rejected() {
    let fx = Fixture::genesis(2);
    let (l1, engine, mut params, req) = fx.parts();
    params.l1_finality_extra_depth = 1;
    l1.set_finalized(fx.genesis.l1_0);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
    let err = init_chain(&mut app, req).await.expect_err("not final");
    assert!(matches!(err, AbciError::GenesisNotFinal { .. }), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn non_canonical_genesis_l1_header_is_rejected() {
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    // The own L1 node holds a different block at L1_0.
    l1.insert_header(RawL1Header::from(&l1_header(fx.genesis.l1_0, 1)));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
    let err = init_chain(&mut app, req).await.expect_err("not canonical");
    assert!(matches!(err, AbciError::GenesisNotFinal { .. }), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test(start_paused = true)]
async fn slow_l1_times_out() {
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    l1.state().delay = Some(Duration::from_secs(60));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
    let err = init_chain(&mut app, req).await.expect_err("L1 too slow");
    assert!(
        matches!(err, AbciError::Timeout { after, .. } if after == AppOptions::default().l1_timeout),
        "{err:?}"
    );
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn witness_of_another_inbox_is_rejected() {
    let fx = Fixture::genesis(2);
    let (l1, engine, mut params, req) = fx.parts();
    params.inbox = Address::repeat_byte(0x11);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
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
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
    let err = init_chain(&mut app, req).await.expect_err("header is not L1_0");
    assert!(
        matches!(err, AbciError::Genesis(GenesisError::InitializationMismatch { l1_0: header, proven: a }) if header == l1_0 + 1 && a == l1_0),
        "{err:?}"
    );
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn epoch_length_is_independent_of_unsettled_cap() {
    let fx = Fixture::build(GenesisSpec { epoch_len: 3, ..GenesisSpec::new(2) });
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    assert_eq!(app.state().unwrap().schedule().h_first(1), 3);
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
    changed.evidence.as_mut().unwrap().max_bytes -= 1;
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

#[tokio::test]
async fn genesis_state_root_must_match_the_authenticated_el_genesis() {
    let mut fx = Fixture::genesis(2);
    fx.genesis.genesis_state_root = B256::repeat_byte(0x88);
    fx.inbox.genesis.as_mut().unwrap().genesis_state_root = fx.genesis.genesis_state_root;
    let mut accounts = filler_accounts();
    accounts.push(inbox_account(fx.params.inbox, &fx.inbox));
    accounts.push(registry_account(fx.params.registry, &fx.registry));
    let state = TestState::new(accounts);
    let mut header = l1_header(fx.genesis.l1_0, Fixture::l1_timestamp(fx.genesis.l1_0));
    header.state_root = state.state_root();
    let mut witness = fx.witness.clone();
    witness.l1_header = RawL1Header::from(&header);
    witness.inbox = state.witness(fx.params.inbox, &crate::l1::layout::inbox::genesis_slots());
    witness.committee =
        committee_witness(&state, fx.params.registry, &fx.registry, 0, fx.record.clone());
    fx.l1_state = state;
    fx.set_witness(witness);

    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let err = init_chain(&mut app, fx.request.clone()).await.expect_err("inconsistent S*");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn committee_record_hash_must_match_committee_e0() {
    let fx = Fixture::build(GenesisSpec {
        committee_e0: Some(B256::repeat_byte(0xc0)),
        ..GenesisSpec::new(3)
    });
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let err = init_chain(&mut app, fx.request.clone()).await.expect_err("record hash mismatch");
    assert!(
        matches!(err, AbciError::Genesis(GenesisError::CommitteeRecordMismatch { recorded, .. }) if recorded == B256::repeat_byte(0xc0)),
        "{err:?}"
    );
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn committee_witness_claiming_another_record_is_rejected() {
    let mut fx = Fixture::genesis(3);
    let mut witness = fx.witness.clone();
    witness.committee.record.total_power += 1;
    fx.set_witness(witness);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let err = init_chain(&mut app, fx.request.clone()).await.expect_err("record mismatch");
    assert!(
        matches!(&err, AbciError::Genesis(GenesisError::Committee(e)) if matches!(e.as_ref(), CommitteeError::RecordMismatch { .. })),
        "{err:?}"
    );
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn genesis_validators_must_equal_the_committee() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());

    let mut wrong_power = fx.request.clone();
    wrong_power.validators[1].power = vote::Power::try_from(fx.members[1].power + 1).unwrap();
    let mut missing = fx.request.clone();
    missing.validators.pop();
    let mut extra = fx.request.clone();
    extra.validators.extend(crate::test_utils::validator_updates(&[crate::types::Member {
        pubkey: crate::test_utils::key_from_seed(B256::repeat_byte(0xab)),
        ..fx.members[0].clone()
    }]));
    let mut duplicate = fx.request.clone();
    duplicate.validators[2] = duplicate.validators[0];
    let mut empty = fx.request.clone();
    empty.validators.clear();

    for req in [wrong_power, missing, extra, duplicate, empty] {
        let err = init_chain(&mut app, req).await.expect_err("validators mismatch");
        assert!(matches!(err, AbciError::GenesisValidatorsMismatch(_)), "{err:?}");
    }
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn el_missing_b_star_is_synced_first() {
    let fx = Fixture::genesis(2);
    let (l1, _, params, req) = fx.parts();
    // The EL knows B* (and its parent) but has not made them canonical yet.
    let engine = MockEngine::new();
    for header in &fx.el_chain {
        engine.insert_known(header.clone());
    }
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
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
async fn el_that_never_reaches_b_star_times_out() {
    let fx = Fixture::genesis(2);
    let (l1, _, params, req) = fx.parts();
    let opts = AppOptions { elsync_timeout: Duration::from_secs(30), ..AppOptions::default() };
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, MockEngine::new(), params, dir.path(), opts);
    let err = init_chain(&mut app, req).await.expect_err("EL never syncs");
    assert!(matches!(err, AbciError::ElSync(ElSyncError::Timeout { .. })), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn el_holding_another_b_star_is_a_safety_halt() {
    let fx = Fixture::genesis(2);
    let (l1, _, params, req) = fx.parts();
    let mut other = fx.el_chain.clone();
    other[0].timestamp += 1;
    let engine = MockEngine::with_chain(other);
    // The EL accepts H* as VALID but keeps serving its own block at B*.
    engine.state().forkchoice_script.push_back(Ok(PayloadVerdict::Valid));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
    let err = init_chain(&mut app, req).await.expect_err("EL disagrees");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn el_rejecting_b_star_is_a_safety_halt() {
    let fx = Fixture::genesis(2);
    let (l1, _, params, req) = fx.parts();
    let engine = MockEngine::new();
    engine.state().forkchoice_script.push_back(Ok(PayloadVerdict::Invalid("bad block".into())));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
    let err = init_chain(&mut app, req).await.expect_err("EL rejects H*");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn el_serving_another_block_after_sync_is_a_safety_halt() {
    let fx = Fixture::genesis(2);
    let (l1, engine, params, req) = fx.parts();
    let mut other = fx.el_chain[0].clone();
    other.timestamp += 1;
    // ensure_block sees B*; the follow-up read of B* returns another block.
    engine.state().header_script.extend([Ok(Some(fx.el_chain[0].clone())), Ok(Some(other))]);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
    let err = init_chain(&mut app, req).await.expect_err("EL changed its mind");
    assert!(matches!(err, AbciError::SafetyHalt(_)), "{err:?}");
    assert_not_initialized(&app, dir.path());
}

#[tokio::test]
async fn genesis_rejects_a_different_committee_config_opening() {
    let mut fx = Fixture::genesis(2);
    let proven = fx.genesis.committee_config_hash;
    fx.params.unsettled_limit -= 6;
    let local = committee::committee_config_hash(&fx.params);
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
async fn genesis_and_restart_authenticate_chain_specific_backpressure_parameters() {
    let params =
        ChainParams::builtin(167001).unwrap().with_overrides("unsettled_limit = 24").unwrap();
    let fx = Fixture::build(GenesisSpec { params, epoch_len: 28, ..GenesisSpec::new(2) });
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    let expected = app.state().unwrap().clone();
    drop(app);
    let mut reopened = fx.app(dir.path());
    info(&mut reopened).await.unwrap();
    assert_eq!(reopened.state(), Some(&expected));
    drop(reopened);
    for field in ["d_max", "margin_v"] {
        let mut wrong = fx.clone();
        match field {
            "d_max" => wrong.params.unsettled_limit -= 6,
            "margin_v" => wrong.params.unsettled_limit += 6,
            _ => unreachable!(),
        }
        let empty_dir = tempfile::tempdir().unwrap();
        let mut app = wrong.app(empty_dir.path());
        assert!(
            matches!(
                init_chain(&mut app, fx.request.clone()).await,
                Err(AbciError::Genesis(GenesisError::ConfigMismatch { .. }))
            ),
            "wrong {field} opened genesis"
        );
        assert_not_initialized(&app, empty_dir.path());
        let error = App::new(
            wrong.l1(),
            wrong.engine(),
            wrong.params,
            Store::volatile(dir.path().into()),
            AppOptions::default(),
        )
        .expect_err("wrong back-pressure configuration opened stored state");
        assert!(
            matches!(error, AbciError::StoredState(message)
            if message.contains("configuration opening")),
            "wrong {field} opened persisted state"
        );
    }
}
