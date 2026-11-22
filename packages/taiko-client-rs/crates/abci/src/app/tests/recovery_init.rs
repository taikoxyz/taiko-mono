//! Recovery bootstrap through the real ABCI handlers.
use super::*;
use crate::{
    AppStateJson, GenesisDoc,
    engine::EngineError,
    genesis::{GenesisConsensusParams, GenesisValidator},
    recovery::{RecoveryWitness, verify_recovery_witness},
    rules::chain_id_for,
    test_utils::{fallback_list, recovery_fallback_keys, recovery_fixture, test_key},
};
use alloy_primitives::B256;

/// The recovery genesis document of `w` over `fx`'s deployment: its validators are the keys of
/// the fixture's origin fallback key list, each at power 1.
pub(super) fn document(fx: &Fixture, w: &RecoveryWitness) -> GenesisDoc {
    let origin = verify_recovery_witness(w, &fx.params).unwrap();
    let keys = recovery_fallback_keys();
    assert_eq!(keys.hash(), origin.fallback_keys_hash);
    let mut canonical = w.clone();
    canonical.finalized_header = w.recovery_header.clone();
    canonical.finalized_inbox = w.recovery_inbox.clone();
    let mut bytes = vec![1];
    bytes.extend(alloy_rlp::encode(&canonical));
    GenesisDoc {
        genesis_time: crate::genesis::genesis_time(origin.l1_timestamp).unwrap().to_rfc3339(),
        chain_id: chain_id_for(&fx.params, origin.generation).unwrap(),
        initial_height: (origin.height + 1).to_string(),
        consensus_params: GenesisConsensusParams::etna(),
        validators: keys.keys().iter().map(|key| GenesisValidator::new(*key, 1)).collect(),
        app_hash: crate::genesis::genesis_app_hash(
            origin.height,
            origin.el_hash,
            &keys.validator_set(),
        )
        .unwrap(),
        app_state: AppStateJson { witness: bytes.into() },
    }
}

/// The `InitChain` request CometBFT sends for a genesis document.
pub(super) use crate::test_utils::init_chain_request as request;

#[tokio::test]
async fn recovery_init_preserves_guarded_signer_session_on_first_and_replayed_handshake() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let doc = document(&fx, &w);
    let first = app.trust.begin_session();
    assert!(!first.is_ready());
    init_chain(&mut app, request(&doc)).await.unwrap();
    assert_eq!(app.trust.snapshot().session_id, first.session_id);
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    // SYNC-9-5 5.e/5.i: while the latest checkpoint is the origin c, its EL hash alone is
    // compared; this node joined through the genesis path and holds no Comet block at c.
    assert_eq!(app.store.load_comet_hash(6).unwrap(), None);
    // SYNC-9-10 10.g: before the generation's first commit only initial_height c + 1 is eligible.
    assert_eq!(app.trust.snapshot().eligible_height, Some(7));
    // Stock Comet replays InitChain while app Info still reports zero at the origin.
    let rearmed = app.trust.begin_session();
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    init_chain(&mut app, request(&doc)).await.unwrap();
    assert_eq!(app.trust.snapshot().session_id, rearmed.session_id);
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
}

#[tokio::test]
async fn recovery_init_replay_closes_unavailable_history_without_replacing_signer_session() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let req = request(&document(&fx, &w));
    init_chain(&mut app, req.clone()).await.unwrap();
    app.trust.begin_session();
    app.refresh_trust().await.unwrap();
    let trust = app.trust_handle();
    let session = trust.snapshot().session_id;
    assert!(trust.snapshot().is_ready());
    let l1 = app.l1.clone();
    let finalized = l1.state().finalized;
    l1.set_finalized(w.recovery_header.number() - 1);
    {
        let pending = init_chain(&mut app, req);
        tokio::pin!(pending);
        tokio::select! {
            result = &mut pending => panic!("unavailable history must wait: {result:?}"),
            _ = tokio::time::sleep(std::time::Duration::from_millis(30)) => {}
        }
        assert!(!trust.snapshot().is_ready());
        assert_eq!(trust.snapshot().session_id, session);
        l1.set_finalized(finalized);
        tokio::time::timeout(std::time::Duration::from_secs(3), pending).await.unwrap().unwrap();
    }
    assert_eq!(trust.snapshot().session_id, session);
    assert!(!trust.snapshot().is_ready());
    app.refresh_trust().await.unwrap();
    assert!(trust.snapshot().is_ready());
}

#[tokio::test]
async fn recovery_init_preserves_stock_zero_height_handshake() {
    use super::proposal::{decide, judge, propose};
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let doc = document(&fx, &w);
    assert_eq!(doc.initial_height, "7");
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let response = init_chain(&mut app, request(&doc)).await.unwrap();
    let info_before = info(&mut app).await.unwrap();
    assert_eq!(info_before.last_block_height.value(), 0);
    assert!(info_before.last_block_app_hash.as_bytes().is_empty());
    assert_eq!(app.state().unwrap().anchor.number, 64);
    assert_eq!(app.state().unwrap().last_comet_hash, B256::ZERO);
    assert_eq!(app.state().unwrap().genesis, fx.genesis);
    // CometBFT starts the generation from the origin fallback keys at the origin height.
    let origin = verify_recovery_witness(&w, &fx.params).unwrap();
    let genesis_vals = crate::valstate::ValState::genesis(
        origin.height,
        &recovery_fallback_keys().validator_set(),
    )
    .unwrap();
    assert_eq!(app.state().unwrap().val_state, genesis_vals);
    // appHash(c): ELHash(c) with the origin keys' genesis validator state.
    let expected = crate::valstate::app_hash(w.el_header.hash_slow(), genesis_vals.hash());
    assert_eq!(response.app_hash.as_bytes(), expected.as_slice());
    drop(app);
    let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    assert_eq!(info(&mut app).await.unwrap().last_block_height.value(), 0);
    assert_eq!(init_chain(&mut app, request(&doc)).await.unwrap(), response);
    let mut inbox = fx.inbox_at_checkpoint(6, w.el_header.hash_slow());
    inbox.recovery_generation = 1;
    inbox.forced_inclusion_head = 3;
    inbox.forced_inclusion_tail = 3;
    fx.advance_l1(app.l1(), 111, &inbox);
    let env = propose(&mut app).await;
    assert!(env.anchor.as_ref().unwrap().l1_header.number() >= 100);
    assert_eq!(env.block.header.base_fee_per_gas, Some(5_000_000));
    assert_ne!(env.block.header.base_fee_per_gas, Some(25_000_000), "block-1 rule is global");
    let (accepted, req) = judge(&mut app, &env).await;
    assert_eq!(accepted, response::ProcessProposal::Accept);
    decide(&mut app, &req).await;
    assert_eq!(app.state().unwrap().val_state, genesis_vals.advance(&[]).unwrap());
    let info_after = info(&mut app).await.unwrap();
    assert_eq!(info_after.last_block_height.value(), 7);
    let after = genesis_vals.advance(&[]).unwrap();
    let expected = crate::valstate::app_hash(env.block.header.hash_slow(), after.hash());
    assert_eq!(info_after.last_block_app_hash.as_bytes(), expected.as_slice());
    assert!(app.state().unwrap().has_generation_commit());
    let chain = app.engine.state().chain.values().cloned().collect::<Vec<_>>();
    drop(app);
    let (_, l1, _, _) = recovery_fixture(1, 6, 1);
    let mut app = app_with(
        l1,
        MockEngine::with_chain(chain),
        fx.params.clone(),
        dir.path(),
        crate::test_utils::test_options(),
    );
    assert_eq!(info(&mut app).await.unwrap(), info_after);
    assert!(matches!(
        init_chain(&mut app, request(&doc)).await,
        Err(AbciError::AlreadyInitialized)
    ));
}

#[tokio::test]
async fn recovery_init_accepts_zero_origin_without_changing_deployment_genesis() {
    let (fx, l1, engine, w) = recovery_fixture(1, 0, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    assert_eq!(app.state().unwrap().genesis, fx.genesis);
    assert_eq!(app.state().unwrap().anchor.number, 64);
    assert_eq!(info(&mut app).await.unwrap().last_block_height.value(), 0);
    checkpoint(&fx, app.l1(), &w, 0, [w.el_header.hash_slow(), B256::ZERO], 1);
    let env = super::proposal::propose(&mut app).await;
    assert_eq!(env.block.header.number, 1);
    assert_eq!(env.block.header.base_fee_per_gas, Some(25_000_000));
    let (accepted, req) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(accepted, response::ProcessProposal::Accept);
    super::proposal::decide(&mut app, &req).await;
    assert_eq!(info(&mut app).await.unwrap().last_block_height.value(), 1);
}

/// The EL and Comet hashes of the retained landing at c > 0 in [`recovery_fixture`].
pub(super) fn retained(w: &RecoveryWitness) -> [B256; 2] {
    [w.el_header.hash_slow(), B256::repeat_byte(0xcc)]
}

/// [`checkpoint_at`] the finalized L1 block 120.
pub(super) fn checkpoint(
    fx: &Fixture,
    l1: &MockL1,
    w: &RecoveryWitness,
    height: u64,
    hashes: [B256; 2],
    generation: u64,
) {
    checkpoint_at(fx, l1, w, 120, height, hashes, generation);
}

/// Changes only the current observation, at the L1 block `number` it makes final; immutable R
/// evidence stays intact. The checkpoint `height` gets the EL hash `hash`, and a `height` above
/// the origin a three-word landing record with the EL and Comet hashes `[hash, comet]`; at the
/// origin the retained record stays.
pub(super) fn checkpoint_at(
    fx: &Fixture,
    l1: &MockL1,
    w: &RecoveryWitness,
    number: u64,
    height: u64,
    [hash, comet]: [B256; 2],
    generation: u64,
) {
    use crate::{
        l1::layout::inbox,
        test_utils::{TestState, filler_accounts, l1_header},
    };
    use alloy_primitives::U256;
    let mut words: Vec<_> = w.recovery_inbox.storage.iter().map(|p| (p.slot, p.value)).collect();
    words.extend([
        (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HASH), hash.into()),
        (inbox::slot(inbox::RECOVERY_GENERATION), U256::from(generation)),
        (
            inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL),
            U256::from(if w.el_header.number == 0 { 0 } else { 3 }) *
                ((U256::from(1) << 48) + U256::from(1)),
        ),
    ]);
    if height > w.el_header.number {
        words.extend(inbox::landing_record_slots(height).into_iter().zip([
            U256::from(w.el_header.number) | (U256::from(generation) << 48) | (U256::from(3) << 96),
            hash.into(),
            comet.into(),
        ]));
    }
    let mut accounts = filler_accounts();
    accounts.push((fx.params.inbox, 1, U256::ZERO, B256::repeat_byte(1), words));
    l1.insert_block(l1_header(number, Fixture::l1_timestamp(number)), TestState::new(accounts));
    l1.set_finalized(number);
}

#[tokio::test]
async fn recovery_init_origin_trust_uses_retained_boundary_without_fabricating_comet_commit() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    // Before InitChain there is no authenticated reason to accept an older landing generation.
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    assert_eq!(app.store.load_comet_hash(6).unwrap(), None);
    assert_eq!(app.state().unwrap().last_comet_hash, B256::ZERO);
    // A later generation in the own finalized view revokes the running node's trust and the
    // process keeps running (RECOV-8-15).
    checkpoint_at(&fx, app.l1(), &w, 121, 6, retained(&w), 2);
    app.refresh_trust().await.expect("a revocation keeps the process running");
    assert!(!app.trust.snapshot().is_ready());
    assert!(app.status().unwrap().superseded);
}

#[tokio::test]
async fn recovery_init_future_target_requires_replay_and_both_committed_hashes() {
    use super::proposal::{decide, judge, propose};
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    checkpoint(&fx, app.l1(), &w, 6, retained(&w), 1);
    let mut requests = Vec::new();
    for _ in 7..=12 {
        let env = propose(&mut app).await;
        let (accepted, req) = judge(&mut app, &env).await;
        assert_eq!(accepted, response::ProcessProposal::Accept);
        decide(&mut app, &req).await;
        requests.push(req);
    }
    let target_hash = app.state().unwrap().parent.hash;
    let target_comet = app.state().unwrap().last_comet_hash;
    let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
    // Replay the exact anchor history while own finality reports the later landing.
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let anchor_state = l1.state().states[&120].clone();
    let anchor_header = l1.state().headers[&120].clone();
    let replay_dir = tempfile::tempdir().unwrap();
    let mut replay = app_with(
        l1,
        engine,
        fx.params.clone(),
        replay_dir.path(),
        crate::test_utils::test_options(),
    );
    init_chain(&mut replay, request(&document(&fx, &w))).await.unwrap();
    checkpoint(&fx, replay.l1(), &w, 12, [target_hash, target_comet], 1);
    // Move changed target to 121 and restore the immutable block-120 anchor.
    let current_state = replay.l1().state().states[&120].clone();
    replay
        .l1()
        .insert_block(crate::test_utils::l1_header(121, Fixture::l1_timestamp(121)), current_state);
    replay.l1().state().states.insert(120, anchor_state);
    replay.l1().insert_header(anchor_header);
    replay.l1().set_finalized(121);
    replay.refresh_trust().await.unwrap();
    assert!(!replay.trust.snapshot().is_ready());
    for req in requests {
        decide(&mut replay, &req).await;
    }
    assert!(!replay.trust.snapshot().is_ready());
    replay.refresh_trust().await.unwrap();
    assert!(replay.trust.snapshot().is_ready());
    replay.trust.begin_session();
    replay.store.comet_hashes().remove(12).expect("12 is committed");
    replay.state.as_mut().unwrap().last_comet_hash = B256::repeat_byte(0xff);
    assert!(matches!(replay.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
    assert!(!replay.trust.snapshot().is_ready());
}

#[test]
fn recovery_bootstrap_codec_is_disjoint_and_strict_without_changing_genesis_bytes() {
    use crate::{BootstrapWitness, decode_bootstrap_state};
    let (fx, _, _, mut w) = recovery_fixture(1, 6, 1);
    let initial = serde_json::to_vec(&AppStateJson::from(&fx.witness)).unwrap();
    assert_eq!(
        decode_bootstrap_state(&initial).unwrap(),
        BootstrapWitness::Initial(fx.witness.clone())
    );
    assert_eq!(AppStateJson::from(&fx.witness).witness.as_ref(), alloy_rlp::encode(&fx.witness));
    let bytes = serde_json::to_vec(&AppStateJson::from(&w)).unwrap();
    assert_eq!(decode_bootstrap_state(&bytes).unwrap(), BootstrapWitness::Recovery(w.clone()));
    let mut malformed = AppStateJson::from(&w);
    malformed.witness = [malformed.witness.as_ref(), &[0]].concat().into();
    assert!(decode_bootstrap_state(&serde_json::to_vec(&malformed).unwrap()).is_err());
    malformed = AppStateJson::from(&w);
    let mut raw = malformed.witness.to_vec();
    raw[0] = 2;
    malformed.witness = raw.into();
    assert!(decode_bootstrap_state(&serde_json::to_vec(&malformed).unwrap()).is_err());
    w.version = 1;
    assert!(decode_bootstrap_state(&serde_json::to_vec(&AppStateJson::from(&w)).unwrap()).is_err());
}

#[tokio::test]
async fn recovery_genesis_is_identical_when_latest_admission_target_advances() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let first = crate::build_recovery_genesis(&l1, &engine, &fx.params, 1).await.unwrap();
    assert_eq!(first, document(&fx, &w));
    checkpoint(&fx, &l1, &w, 18, [B256::repeat_byte(0x18), B256::repeat_byte(0x19)], 1);
    let next = crate::build_recovery_genesis(&l1, &engine, &fx.params, 1).await.unwrap();
    assert_eq!(first.to_json_pretty(), next.to_json_pretty());
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&next)).await.unwrap();
    app.refresh_trust().await.unwrap();
    assert_eq!(app.trust.snapshot().target.unwrap().height, 18);
    assert!(!app.trust.snapshot().is_ready());
}

#[tokio::test]
async fn recovery_init_rejects_changed_domain_time_validators_and_config() {
    let (fx, _, _, w) = recovery_fixture(1, 6, 1);
    let doc = document(&fx, &w);
    for case in 0..5 {
        let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
        let mut params = fx.params.clone();
        let mut req = request(&doc);
        match case {
            0 => req.chain_id = chain_id_for(&params, 2).unwrap(),
            1 => req.time = crate::genesis::genesis_time(1).unwrap(),
            2 => req.validators.pop().map(|_| ()).unwrap(),
            3 => req.initial_height = 1u32.into(),
            4 => params.l2_chain_id += 1,
            _ => unreachable!(),
        }
        let dir = tempfile::tempdir().unwrap();
        let mut app = app_with(l1, engine, params, dir.path(), crate::test_utils::test_options());
        assert!(init_chain(&mut app, req).await.is_err(), "case {case}");
        assert_not_initialized(&app, dir.path());
        assert!(!app.trust.snapshot().is_ready());
        assert!(app.store.load_recovery_bootstrap().unwrap().is_none());
    }
}

/// Runs a recovery InitChain whose request's validators `edit` changed and asserts that it is
/// refused as a validator mismatch with trust closed, before the bootstrap sidecar or any state
/// is stored.
async fn assert_validators_refused(edit: impl FnOnce(&mut Vec<crate::wire::ValidatorUpdate>)) {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let mut req = request(&document(&fx, &w));
    edit(&mut req.validators);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let result = init_chain(&mut app, req).await;
    assert!(matches!(result, Err(AbciError::GenesisValidatorsMismatch(_))), "{result:?}");
    assert_not_initialized(&app, dir.path());
    assert!(app.store.load_recovery_bootstrap().unwrap().is_none());
    assert!(!app.trust.snapshot().is_ready());
}

/// A key of the origin list at power 2.
#[tokio::test]
async fn recovery_init_chain_refuses_power_two() {
    assert_validators_refused(|validators| {
        validators[0].power = tendermint::vote::Power::from(2u32);
    })
    .await;
}

/// The origin list without one of its keys.
#[tokio::test]
async fn recovery_init_chain_refuses_a_missing_key() {
    assert_validators_refused(|validators| {
        validators.pop();
    })
    .await;
}

/// The origin list with a key it does not hold.
#[tokio::test]
async fn recovery_init_chain_refuses_an_extra_key() {
    assert_validators_refused(|validators| {
        validators.push(crate::wire::ValidatorUpdate {
            pub_key: test_key(9),
            power: tendermint::vote::Power::from(1u32),
        });
    })
    .await;
}

/// Another valid list, at power 1, whose hash the origin record does not hold.
#[tokio::test]
async fn recovery_init_chain_refuses_a_list_with_another_hash() {
    let other = fallback_list(&[3, 4]);
    assert_ne!(other.hash(), recovery_fallback_keys().hash());
    assert_validators_refused(|validators| {
        *validators = other
            .keys()
            .iter()
            .map(|key| crate::wire::ValidatorUpdate {
                pub_key: *key,
                power: tendermint::vote::Power::from(1u32),
            })
            .collect();
    })
    .await;
}

/// A node without archive state at R cannot answer `getFallbackKeys()` there, so a list stored
/// long before R comes only from its logs, found many bounded log queries below R. Each L1 read
/// has its own deadline and the acquisition none: InitChain completes on the origin keys,
/// although the scan takes far longer than one read's deadline.
#[tokio::test(start_paused = true)]
async fn recovery_init_obtains_an_old_origin_list_from_logs_far_below_r() {
    use crate::{
        fallback::FALLBACK_KEYS_UPDATED, l1::L1Error, test_utils::recovery_fixture_at,
        valstate::ValState,
    };
    use std::time::Duration;
    let (fx, l1, engine, w) = recovery_fixture_at(1, 6, 1, 200_000);
    let keys = recovery_fallback_keys();
    l1.state().call_fail = Some(L1Error::Rpc("missing trie node".into()));
    l1.insert_log(
        70,
        fx.params.inbox,
        [FALLBACK_KEYS_UPDATED, keys.hash()],
        keys.abi_encode().into(),
    );
    // Each log query takes one second, within a read's deadline; the scan needs twenty.
    l1.state().log_delay = Some(Duration::from_secs(1));
    let opts = crate::test_utils::test_options();
    assert!(opts.l1_timeout > Duration::from_secs(1));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), opts);
    let started = tokio::time::Instant::now();
    tokio::time::timeout(
        Duration::from_secs(600),
        init_chain(&mut app, request(&document(&fx, &w))),
    )
    .await
    .expect("InitChain completes on a deep log scan")
    .unwrap();
    assert!(started.elapsed() >= Duration::from_secs(20));
    assert_eq!(app.l1().log_ranges().len(), 20);
    assert_eq!(app.l1().log_ranges().last(), Some(&(1, 10_000)));
    let state = app.state().unwrap();
    assert_eq!(state.val_state, ValState::genesis(6, &keys.validator_set()).unwrap());
    assert_eq!(state.fallback_keys.get(&keys.hash()), Some(&keys));
    assert_eq!(app.store.load_recovery_bootstrap().unwrap().unwrap().fallback_keys, keys);
}

/// A list read that outlasts its deadline is missing data, never an acceptance: InitChain stays
/// pending with trust closed and nothing stored, and completes on the origin keys once the own
/// L1 answers in time.
#[tokio::test(start_paused = true)]
async fn recovery_init_waits_while_a_list_read_times_out() {
    use crate::{fallback::FALLBACK_KEYS_UPDATED, l1::L1Error, test_utils::recovery_fixture_at};
    use std::time::Duration;
    let (fx, l1, engine, w) = recovery_fixture_at(1, 6, 1, 30_000);
    let keys = recovery_fallback_keys();
    l1.state().call_fail = Some(L1Error::Rpc("missing trie node".into()));
    l1.insert_log(
        70,
        fx.params.inbox,
        [FALLBACK_KEYS_UPDATED, keys.hash()],
        keys.abi_encode().into(),
    );
    let opts = crate::test_utils::test_options();
    l1.state().log_delay = Some(opts.list_read_timeout() + Duration::from_secs(1));
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), opts);
    let trust = app.trust_handle();
    let req = request(&document(&fx, &w));
    let waiting =
        tokio::time::timeout(Duration::from_secs(120), init_chain(&mut app, req.clone())).await;
    assert!(waiting.is_err(), "a timed-out list read must keep InitChain pending: {waiting:?}");
    assert!(app.store.load().unwrap().is_none());
    assert!(app.store.load_recovery_bootstrap().unwrap().is_none());
    assert!(app.store.fatal_evidence().unwrap().is_none(), "a slow L1 is not a halt");
    assert!(!trust.snapshot().is_ready());
    app.l1().state().log_delay = None;
    tokio::time::timeout(Duration::from_secs(120), init_chain(&mut app, req))
        .await
        .expect("InitChain completes once the reads answer in time")
        .unwrap();
    assert_eq!(app.state().unwrap().fallback_keys.get(&keys.hash()), Some(&keys));
}

/// A recovery discards every validator update the old generation returned that had not taken
/// effect: whatever the old generation's last heights returned, c + 1 and c + 2
/// are signed by the origin record's fallback keys, each at power 1, and the generation's own
/// records recompute that set.
#[tokio::test]
async fn old_generation_updates_are_discarded() {
    use super::proposal::{decide, judge, propose};
    use crate::valstate::ValState;
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    // The old generation left its own state below c, and its FinalizeBlock of c - 1 and c
    // returned updates for c + 1 and c + 2.
    let store = Store::new(dir.path().into());
    store.save_val_state(&ValState::genesis(5, &[(test_key(9), 4)]).unwrap()).unwrap();
    store.save_val_updates(5, &[(test_key(9), 4), (test_key(1), 0)]).unwrap();
    store.save_val_updates(6, &[(test_key(8), 2), (test_key(2), 0)]).unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let origin = ValState::genesis(6, &recovery_fallback_keys().validator_set()).unwrap();
    let state = app.state().unwrap();
    // After c, `current` signs c + 1 and `next` signs c + 2.
    assert_eq!(state.val_state, origin);
    assert_eq!(state.val_state.next.members(), origin.current.members());
    for height in [7, 8] {
        let env = propose(&mut app).await;
        let (accepted, req) = judge(&mut app, &env).await;
        assert_eq!(accepted, response::ProcessProposal::Accept, "height {height}");
        assert!(decide(&mut app, &req).await.validator_updates.is_empty(), "height {height}");
        let state = app.state().unwrap();
        assert_eq!(state.last_height, height);
        assert_eq!(state.val_state.current.members(), origin.current.members(), "{height}");
        assert_eq!(
            app.store.load_val_state(height).unwrap(),
            crate::store::Record::Valid(state.val_state.clone()),
            "height {height}"
        );
    }
}

#[tokio::test]
async fn recovery_init_restart_rejects_missing_mixed_or_tampered_bootstrap_sidecar() {
    for case in 0..6 {
        let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
        let dir = tempfile::tempdir().unwrap();
        let mut app =
            app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
        init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
        drop(app);
        let path = dir.path().join("recovery-bootstrap.json");
        match case {
            0 => std::fs::remove_file(path).unwrap(),
            1 => std::fs::write(path, b"{}").unwrap(),
            2 => {
                let store = Store::new(dir.path().into());
                let mut sidecar = store.load_recovery_bootstrap().unwrap().unwrap();
                sidecar.anchor = None;
                std::fs::write(path, serde_json::to_vec(&sidecar).unwrap()).unwrap();
            }
            3 => {
                let store = Store::new(dir.path().into());
                let mut state = store.load().unwrap().unwrap();
                state.recovery.as_mut().unwrap().comet_hash = B256::repeat_byte(0xff);
                store.save(&state).unwrap();
            }
            4 | 5 => {
                let store = Store::new(dir.path().into());
                let mut state = store.load().unwrap().unwrap();
                if case == 4 {
                    state.parent.base_fee += 1;
                } else {
                    state.forced_cursor += 1;
                }
                store.save(&state).unwrap();
            }
            _ => unreachable!(),
        }
        let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
        assert!(
            App::new(
                l1,
                engine,
                fx.params,
                Store::new(dir.path().into()),
                crate::test_utils::test_options()
            )
            .is_err(),
            "case {case}"
        );
    }
}

#[tokio::test]
async fn recovery_init_durable_sidecar_precedes_state_and_is_immutable_on_retry() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let path = dir.path().join("recovery-bootstrap.json");
    let original = std::fs::read(&path).unwrap();
    let mut conflict = app.store.load_recovery_bootstrap().unwrap().unwrap();
    conflict.fallback_keys = fallback_list(&[1]);
    assert!(matches!(
        app.store.save_recovery_bootstrap(&conflict),
        Err(crate::store::StoreError::BootstrapConflict)
    ));
    assert_eq!(std::fs::read(&path).unwrap(), original);
    drop(app);
    // Model a crash between the sidecar publication and AppState publication.
    std::fs::remove_file(dir.path().join(crate::store::STATE_FILE)).unwrap();
    let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    assert_eq!(std::fs::read(&path).unwrap(), original);
}

#[tokio::test]
async fn recovery_init_waits_on_the_same_request_for_historical_evidence() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let historical = l1.state().states.remove(&64).unwrap();
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let shared_l1 = app.l1.clone();
    let trust = app.trust_handle();
    let store = app.store.clone();
    let req = request(&document(&fx, &w));
    let pending = init_chain(&mut app, req);
    tokio::pin!(pending);
    tokio::select! {
        result = &mut pending => panic!("unavailable history must keep InitChain pending: {result:?}"),
        _ = tokio::time::sleep(std::time::Duration::from_millis(30)) => {}
    }
    assert!(store.load().unwrap().is_none());
    assert!(store.load_recovery_bootstrap().unwrap().is_none());
    assert!(!trust.snapshot().is_ready());
    shared_l1.state().states.insert(64, historical);
    let result =
        tokio::time::timeout(std::time::Duration::from_secs(3), pending).await.unwrap().unwrap();
    assert_eq!(result.app_hash, crate::app::app_hash(&store.load().unwrap().unwrap()));
    assert_eq!(store.load().unwrap().unwrap().last_height, 6);
    assert!(!trust.snapshot().is_ready());
}

/// An own EL that answers the origin-state probe with a block that does not hash to c's hash
/// contradicts itself: recovery InitChain halts with durable fatal evidence (SYNC-9-7), instead
/// of failing the request as an ordinary error.
#[tokio::test]
async fn recovery_init_halts_when_the_el_serves_another_block_for_the_origin() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let origin = w.el_header.hash_slow();
    engine.state().historical_state_fail =
        Some(EngineError::BlockHashMismatch { expected: origin, computed: B256::repeat_byte(9) });
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let result = tokio::time::timeout(
        std::time::Duration::from_secs(3),
        init_chain(&mut app, request(&document(&fx, &w))),
    )
    .await
    .expect("a contradiction must not wait");
    assert!(matches!(&result, Err(AbciError::SafetyHalt(_))), "{result:?}");
    assert!(app.store.fatal_evidence().unwrap().is_some());
    assert!(app.store.load().unwrap().is_none());
}

/// An EL that lost c's state after `prepare` (pruned, or replaced by another EL serving the same
/// headers) is missing data (SYNC-9-7): InitChain stays pending with trust closed and stores
/// nothing, instead of reporting Ready and halting on the first execution, and completes once
/// the EL serves that state again.
#[tokio::test]
async fn recovery_init_waits_with_trust_closed_until_the_el_serves_origin_state() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let origin = w.el_header.hash_slow();
    assert!(engine.state().historical_state.remove(&origin));
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let trust = app.trust_handle();
    let req = request(&document(&fx, &w));
    let waiting = tokio::time::timeout(
        std::time::Duration::from_millis(30),
        init_chain(&mut app, req.clone()),
    )
    .await;
    assert!(waiting.is_err(), "missing origin state must keep InitChain pending: {waiting:?}");
    assert!(app.store.load().unwrap().is_none());
    assert!(app.store.fatal_evidence().unwrap().is_none(), "missing state is not a halt");
    let closed = trust.snapshot();
    assert!(!closed.is_ready());
    assert!(
        closed.reason.as_deref().is_some_and(|reason| reason.contains("lacks the state")),
        "{closed:?}"
    );
    app.engine.state().historical_state.insert(origin);
    let result = tokio::time::timeout(std::time::Duration::from_secs(3), init_chain(&mut app, req))
        .await
        .unwrap()
        .unwrap();
    assert_eq!(result.app_hash, crate::app::app_hash(&app.store.load().unwrap().unwrap()));
    assert_eq!(app.store.load().unwrap().unwrap().last_height, 6);
}

/// A node whose EL holds its own blocks from c - 1 on, where L1 settled other ones (vector 7.l
/// of RECOV-8.1-7), takes the settled block at c in place of its own. InitChain points the EL
/// at c's authenticated hash and, while the EL lacks that block, waits with trust closed and
/// stores nothing (SYNC-9-7) instead of halting. Once the EL has synced the settled blocks
/// from a peer, InitChain completes on them and the origin's checkpoint trust opens.
#[tokio::test]
async fn recovery_init_takes_the_settled_block_at_c_in_place_of_its_own() {
    use alloy_consensus::Header;
    use std::time::Duration;
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let settled = [w.parent_headers[0].clone(), w.el_header.clone()];
    let hash = w.el_header.hash_slow();
    let own_parent = Header { timestamp: settled[0].timestamp + 1, ..settled[0].clone() };
    let own = Header { parent_hash: own_parent.hash_slow(), ..settled[1].clone() };
    {
        let mut state = engine.state();
        for header in &settled {
            state.known.remove(&header.hash_slow());
        }
        for header in [own_parent, own] {
            state.known.insert(header.hash_slow(), header.clone());
            state.chain.insert(header.number, header);
        }
    }
    let opts = AppOptions {
        elsync_timeout: Duration::from_millis(20),
        ..crate::test_utils::test_options()
    };
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), opts);
    let trust = app.trust_handle();
    let req = request(&document(&fx, &w));
    let waiting =
        tokio::time::timeout(Duration::from_millis(300), init_chain(&mut app, req.clone())).await;
    assert!(waiting.is_err(), "another block at c must keep InitChain pending: {waiting:?}");
    assert!(app.store.load().unwrap().is_none());
    assert!(app.store.fatal_evidence().unwrap().is_none(), "another block at c is not a halt");
    let closed = trust.snapshot();
    assert!(!closed.is_ready());
    assert!(
        closed.reason.as_deref().is_some_and(|reason| reason.contains("did not reach block 6")),
        "{closed:?}"
    );
    let pointed = EngineCall::Forkchoice { head: hash, safe: B256::ZERO, finalized: B256::ZERO };
    assert!(app.engine.calls().contains(&pointed), "{:?}", app.engine.calls());
    // The EL syncs the settled blocks from a peer that holds them.
    app.engine.state().backfill.extend(settled.iter().map(|h| (h.number, h.clone())));
    let result = tokio::time::timeout(Duration::from_secs(3), init_chain(&mut app, req))
        .await
        .expect("InitChain completes once the EL serves the settled block")
        .unwrap();
    let state = app.store.load().unwrap().unwrap();
    assert_eq!(result.app_hash, crate::app::app_hash(&state));
    assert_eq!((state.last_height, state.parent.hash), (6, hash));
    assert_eq!(app.engine.state().chain.get(&5), Some(&settled[0]));
    assert_eq!(app.engine.state().chain.get(&6), Some(&settled[1]));
    app.refresh_trust().await.unwrap();
    assert!(trust.snapshot().is_ready());
}

/// An EL that answers a request for c's authenticated hash or height with another block still
/// contradicts itself (SYNC-9-7): one that accepts c's hash and keeps serving its own block at
/// c, or answers the read of c with a header of another height or one that does not hash to the
/// hash it reports. Recovery InitChain halts with fatal evidence and stores nothing.
#[tokio::test]
async fn recovery_init_halts_when_the_el_answers_c_with_another_block() {
    use alloy_consensus::Header;
    for answer in ["accepts c and serves its own", "another height", "another hash"] {
        let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
        let hash = w.el_header.hash_slow();
        let own = Header { timestamp: w.el_header.timestamp + 1, ..w.el_header.clone() };
        {
            let mut state = engine.state();
            match answer {
                "accepts c and serves its own" => {
                    state.known.remove(&hash);
                    state.chain.insert(6, own);
                    state.forkchoice_script.push_back(Ok(crate::engine::PayloadVerdict::Valid));
                }
                "another height" => state
                    .header_script
                    .push_back(Err(EngineError::HeaderNumberMismatch { requested: 6, got: 5 })),
                _ => state.header_script.push_back(Err(EngineError::HeaderHashMismatch {
                    number: 6,
                    reported: hash,
                    computed: own.hash_slow(),
                })),
            }
        }
        let dir = tempfile::tempdir().unwrap();
        let mut app =
            app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
        let result = tokio::time::timeout(
            std::time::Duration::from_secs(3),
            init_chain(&mut app, request(&document(&fx, &w))),
        )
        .await
        .expect("a contradiction must not wait");
        assert!(matches!(&result, Err(AbciError::SafetyHalt(_))), "{answer}: {result:?}");
        assert!(app.store.fatal_evidence().unwrap().is_some(), "{answer}");
        assert!(app.store.load().unwrap().is_none(), "{answer}");
    }
}

#[tokio::test]
async fn recovery_init_restart_reuses_authenticated_historical_sidecar_when_state_is_pruned() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    let req = request(&document(&fx, &w));
    let first = init_chain(&mut app, req.clone()).await.unwrap();
    drop(app);
    let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 18, [B256::repeat_byte(0x18), B256::repeat_byte(0x19)], 1);
    l1.state().states.remove(&64);
    let mut app = app_with(l1, engine, fx.params, dir.path(), crate::test_utils::test_options());
    let repeated =
        tokio::time::timeout(std::time::Duration::from_millis(100), init_chain(&mut app, req))
            .await
            .expect("verified sidecar replaces unavailable historical state proof")
            .unwrap();
    assert_eq!(repeated, first);
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().is_ready(), "the later target still needs replay");
}

#[tokio::test]
async fn recovery_init_never_trusts_an_old_generation_header_above_the_origin() {
    use super::proposal::{decide, judge, propose};
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let env = propose(&mut app).await;
    let (_, req) = judge(&mut app, &env).await;
    decide(&mut app, &req).await;
    // A coherent old suffix must not pass merely because it descends from the genuine origin.
    let mut old = env.block.header;
    old.extra_data = crate::test_utils::extra_data(0, 120);
    app.state.as_mut().unwrap().parent.hash = old.hash_slow();
    app.engine.state().chain.insert(7, old);
    app.store.save(app.state().unwrap()).unwrap();
    assert!(
        matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(reason)) if reason.contains("old-generation"))
    );
    assert!(!app.trust.snapshot().is_ready());
}

#[tokio::test]
async fn recovery_init_historical_sidecar_cannot_substitute_r_for_the_committed_c_anchor() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let mut sidecar = app.store.load_recovery_bootstrap().unwrap().unwrap();
    sidecar.anchor = Some(alloy_rlp::encode(fx.anchor_witness(app.l1(), 100)).into());
    assert!(matches!(sidecar.verify(&fx.params), Err(crate::RecoveryError::Invalid(_))));
}

#[tokio::test]
async fn recovery_init_engine_integrity_errors_halt_without_publishing_state() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    engine
        .state()
        .header_script
        .push_back(Err(crate::EngineError::BadReply("malformed origin header".into())));
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    assert!(matches!(
        init_chain(&mut app, request(&document(&fx, &w))).await,
        Err(AbciError::SafetyHalt(_))
    ));
    assert_not_initialized(&app, dir.path());
    assert!(app.store.fatal_evidence().unwrap().is_some());
}

#[tokio::test]
async fn recovered_trust_summary_uses_verified_recovery_header() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let doc = document(&fx, &w);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    init_chain(&mut app, request(&doc)).await.unwrap();
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust_handle().snapshot();
    assert!(snapshot.is_ready());
    let wire = serde_json::to_value(&snapshot).unwrap();
    assert_eq!(wire["recovery_origin"]["generation"], 1);
    assert_eq!(wire["recovery_origin"]["height"], 6);
    assert_eq!(
        wire["recovery_origin"]["l1_hash"],
        serde_json::to_value(w.recovery_header.hash()).unwrap()
    );
}

/// The state InitChain persists for [`recovery_fixture`]'s generation 1 at its origin c = 6,
/// with the authenticated old anchor that c inherited.
fn recovered_state() -> (Fixture, crate::store::AppState) {
    use crate::{l1::verify_anchor_witness, valstate::ValState};
    let (fx, l1, _, witness) = recovery_fixture(1, 6, 1);
    let origin = verify_recovery_witness(&witness, &fx.params).unwrap();
    let keys = recovery_fallback_keys();
    let mut state = fx.expected_state();
    state.anchor = verify_anchor_witness(&fx.anchor_witness(&l1, 64), fx.params.inbox).unwrap();
    state.generation = 1;
    state.chain_id = chain_id_for(&fx.params, 1).unwrap();
    state.last_height = 6;
    state.parent.number = 6;
    state.parent.hash = origin.el_hash;
    state.forced_cursor = origin.forced_cursor;
    state.val_state = ValState::genesis(origin.height, &keys.validator_set()).unwrap();
    state.fallback_keys = [(keys.hash(), keys)].into();
    state.recovery = Some(origin);
    (fx, state)
}

/// The stored state has one schema, the recovery origin alone distinguishes generation zero
/// from a recovery generation, and a recovery generation holds its origin fallback key list
/// under the hash the origin record holds.
#[test]
fn stored_state_has_one_schema_and_a_consistent_recovery_origin() {
    use crate::store::{STATE_FILE, STATE_SCHEMA_VERSION};
    let (fx, recovered) = recovered_state();
    let check =
        |state: &crate::store::AppState| super::super::check_stored_state(state, &fx.params);
    let genesis = fx.expected_state();
    for state in [&recovered, &genesis] {
        assert_eq!(state.schema_version, STATE_SCHEMA_VERSION);
        assert!(check(state).is_ok());
        for schema in [STATE_SCHEMA_VERSION - 1, STATE_SCHEMA_VERSION + 1] {
            let mut wrong = state.clone();
            wrong.schema_version = schema;
            assert!(check(&wrong).is_err(), "{schema}");
        }
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        store.save(state).unwrap();
        let on_disk = std::fs::read(dir.path().join(STATE_FILE)).unwrap();
        // The key is always written: `null` at generation zero, the origin after recovery.
        let json: serde_json::Value = serde_json::from_slice(&on_disk).unwrap();
        assert!(json.as_object().unwrap().contains_key("recovery"));
        assert_eq!(json["recovery"].is_null(), state.recovery.is_none());
        let loaded = store.load().unwrap().unwrap();
        assert_eq!(&loaded, state);
        store.save(&loaded).unwrap();
        assert_eq!(std::fs::read(dir.path().join(STATE_FILE)).unwrap(), on_disk);
    }
    let mut wrong = recovered.clone();
    wrong.recovery = None;
    assert!(check(&wrong).is_err());
    let mut wrong = genesis.clone();
    wrong.recovery = recovered.recovery.clone();
    assert!(check(&wrong).is_err());
    let mut mismatched = recovered.clone();
    mismatched.recovery.as_mut().unwrap().generation = 2;
    assert!(check(&mismatched).is_err());
    // Without its origin list, or with a list under another hash than its own.
    let mut without = recovered.clone();
    without.fallback_keys.clear();
    assert!(check(&without).is_err());
    let mut misfiled = recovered.clone();
    misfiled.fallback_keys.insert(B256::repeat_byte(0x99), fallback_list(&[3]));
    assert!(check(&misfiled).is_err());
}

/// The recovered generation's first block carries an anchor witness, at or after R.
#[test]
fn recovery_first_block_requires_a_witness_at_or_after_r() {
    use crate::app::validate::{self, Rejection, WitnessKind};
    let (fx, state) = recovered_state();
    let no_witness = validate::Candidate {
        anchor: None,
        extra_generation: 1,
        extra_anchor: state.anchor.number,
    };
    assert_eq!(
        validate::check_candidate_anchor(&state.chain_context(), &fx.params, 7, &no_witness)
            .unwrap_err(),
        Rejection::MissingWitness(WitnessKind::Anchor)
    );
    let old_witness = fx.anchor_witness(&fx.l1(), 64);
    let old_anchor = validate::Candidate { anchor: Some(&old_witness), ..no_witness };
    assert_eq!(
        validate::check_candidate_anchor(&state.chain_context(), &fx.params, 7, &old_anchor)
            .unwrap_err(),
        Rejection::Rule(crate::rules::RuleViolation::AnchorBeforeActivation {
            anchor: 64,
            origin: 100
        })
    );
}
