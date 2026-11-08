//! Recovery bootstrap through the real ABCI handlers.
use super::*;
use crate::{
    AppStateJson, GenesisDoc,
    genesis::{GenesisConsensusParams, GenesisValidator},
    recovery::{RecoveryWitness, verify_recovery_witness},
    rules::chain_id_for,
    test_utils::recovery_fixture,
};
use alloy_primitives::B256;

/// The recovery genesis document of `w` over `fx`'s deployment.
pub(super) fn document(fx: &Fixture, w: &RecoveryWitness) -> GenesisDoc {
    let origin = verify_recovery_witness(w, &fx.params).unwrap();
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
        validators: origin.committee.members.iter().map(GenesisValidator::from_member).collect(),
        app_hash: alloy_primitives::hex::encode_upper(origin.el_hash),
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
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    let doc = document(&fx, &w);
    let first = app.trust.begin_session();
    assert!(!first.is_ready());
    init_chain(&mut app, request(&doc)).await.unwrap();
    assert_eq!(app.trust.snapshot().session_id, first.session_id);
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
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
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
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
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    let response = init_chain(&mut app, request(&doc)).await.unwrap();
    assert_eq!(response.app_hash.as_bytes(), w.el_header.hash_slow().as_slice());
    let info_before = info(&mut app).await.unwrap();
    assert_eq!(info_before.last_block_height.value(), 0);
    assert!(info_before.last_block_app_hash.as_bytes().is_empty());
    assert_eq!(app.state().unwrap().anchor.number, 64);
    assert_eq!(app.state().unwrap().last_comet_hash, B256::ZERO);
    assert_eq!(app.state().unwrap().genesis, fx.genesis);
    // CometBFT starts the generation from the origin committee at the origin height.
    let origin = verify_recovery_witness(&w, &fx.params).unwrap();
    let genesis_vals = crate::valstate::ValState::genesis(
        origin.height,
        &crate::test_utils::powers(&origin.committee.members),
    )
    .unwrap();
    assert_eq!(app.state().unwrap().val_state, genesis_vals);
    drop(app);
    let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    assert_eq!(info(&mut app).await.unwrap().last_block_height.value(), 0);
    assert_eq!(init_chain(&mut app, request(&doc)).await.unwrap(), response);
    let mut inbox = fx.inbox_at_checkpoint(6, w.el_header.hash_slow());
    inbox.recovery_generation = 1;
    inbox.forced_inclusion_head = 3;
    inbox.forced_inclusion_tail = 3;
    fx.advance_l1(app.l1(), 111, &inbox, &fx.registry);
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
    assert_eq!(info_after.last_block_app_hash.as_bytes(), env.block.header.hash_slow().as_slice());
    assert!(app.state().unwrap().has_generation_commit());
    let chain = app.engine.state().chain.values().cloned().collect::<Vec<_>>();
    drop(app);
    let (_, l1, _, _) = recovery_fixture(1, 6, 1);
    let mut app = app_with(
        l1,
        MockEngine::with_chain(chain),
        fx.params.clone(),
        dir.path(),
        AppOptions::default(),
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
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    assert_eq!(app.state().unwrap().genesis, fx.genesis);
    assert_eq!(app.state().unwrap().anchor.number, 64);
    assert_eq!(info(&mut app).await.unwrap().last_block_height.value(), 0);
    checkpoint(&fx, app.l1(), &w, 0, [w.el_header.hash_slow(), B256::ZERO, B256::ZERO], 1);
    let env = super::proposal::propose(&mut app).await;
    assert_eq!(env.block.header.number, 1);
    assert_eq!(env.block.header.base_fee_per_gas, Some(25_000_000));
    let (accepted, req) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(accepted, response::ProcessProposal::Accept);
    super::proposal::decide(&mut app, &req).await;
    assert_eq!(info(&mut app).await.unwrap().last_block_height.value(), 1);
}

/// The EL, Comet and validator-state hashes of the retained landing at c > 0 in
/// [`recovery_fixture`].
fn retained(w: &RecoveryWitness) -> [B256; 3] {
    [w.el_header.hash_slow(), B256::repeat_byte(0xcc), B256::repeat_byte(0xdd)]
}

/// Changes only the current observation; immutable R evidence stays intact. The checkpoint
/// `height` gets the EL hash `hash`, and a `height` above the origin a landing record with the
/// EL, Comet and validator-state hashes `[hash, comet, val_state]`; at the origin the retained
/// record stays.
fn checkpoint(
    fx: &Fixture,
    l1: &MockL1,
    w: &RecoveryWitness,
    height: u64,
    [hash, comet, val_state]: [B256; 3],
    generation: u64,
) {
    use crate::{
        l1::layout::inbox,
        test_utils::{TestState, filler_accounts, l1_header, registry_account},
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
        words.extend(inbox::landing_slots(height).into_iter().zip([
            U256::from(w.el_header.number) | (U256::from(generation) << 48) | (U256::from(3) << 96),
            hash.into(),
            comet.into(),
            val_state.into(),
        ]));
    }
    let mut accounts = filler_accounts();
    accounts.push((fx.params.inbox, 1, U256::ZERO, B256::repeat_byte(1), words));
    accounts.push(registry_account(fx.params.registry, &fx.registry));
    l1.insert_block(l1_header(120, Fixture::l1_timestamp(120)), TestState::new(accounts));
    l1.set_finalized(120);
}

#[tokio::test]
async fn recovery_init_origin_trust_uses_retained_boundary_without_fabricating_comet_commit() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    // Before InitChain there is no authenticated reason to accept an older landing generation.
    app.refresh_trust().await.unwrap();
    assert!(!app.trust.snapshot().is_ready());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    assert_eq!(app.store.load_comet_hash(6).unwrap(), None);
    assert_eq!(app.state().unwrap().last_comet_hash, B256::ZERO);
    checkpoint(&fx, app.l1(), &w, 6, retained(&w), 2);
    assert!(matches!(app.refresh_trust().await, Err(AbciError::SafetyHalt(_))));
    assert!(!app.trust.snapshot().is_ready());
}

/// SYNC-9-5: the record at the generation's start height does not hold this generation's
/// validator state, so its word 4 is never compared with the node's: generation 0's start
/// record holds 0, and recovery origin c's keeps the original generation's value.
#[tokio::test]
async fn trust_skips_the_validator_state_at_the_generation_origin() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    fx.advance_l1(app.l1(), 100, &fx.inbox, &fx.registry);
    assert_eq!(fx.inbox.last_checkpoint_val_state_hash, B256::ZERO);
    assert_ne!(app.state().unwrap().val_state.hash(), B256::ZERO);
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready(), "{:?}", app.trust.snapshot().reason);
    assert_eq!(app.trust.snapshot().target.unwrap().val_state_hash, B256::ZERO);

    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let origin = app.state().unwrap().recovery.clone().unwrap();
    assert_eq!(origin.val_state_hash, retained(&w)[2]);
    assert_ne!(app.state().unwrap().val_state.hash(), origin.val_state_hash);
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready(), "{:?}", app.trust.snapshot().reason);
    assert_eq!(app.trust.snapshot().target.unwrap().val_state_hash, origin.val_state_hash);
}

#[tokio::test]
async fn recovery_init_future_target_requires_replay_and_both_committed_hashes() {
    use super::proposal::{decide, judge, propose};
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
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
    let target_val_state = app.state().unwrap().val_state.hash();
    let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
    // Replay the exact anchor history while own finality reports the later landing.
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let anchor_state = l1.state().states[&120].clone();
    let anchor_header = l1.state().headers[&120].clone();
    let replay_dir = tempfile::tempdir().unwrap();
    let mut replay =
        app_with(l1, engine, fx.params.clone(), replay_dir.path(), AppOptions::default());
    init_chain(&mut replay, request(&document(&fx, &w))).await.unwrap();
    checkpoint(&fx, replay.l1(), &w, 12, [target_hash, target_comet, target_val_state], 1);
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
    std::fs::remove_file(replay_dir.path().join("comet-hash-12.json")).unwrap();
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
    w.version = 2;
    assert!(decode_bootstrap_state(&serde_json::to_vec(&AppStateJson::from(&w)).unwrap()).is_err());
}

#[tokio::test]
async fn recovery_genesis_is_identical_when_latest_admission_target_advances() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let first = crate::build_recovery_genesis(&l1, &engine, &fx.params, 1).await.unwrap();
    assert_eq!(first, document(&fx, &w));
    checkpoint(
        &fx,
        &l1,
        &w,
        18,
        [B256::repeat_byte(0x18), B256::repeat_byte(0x19), B256::repeat_byte(0x1a)],
        1,
    );
    let next = crate::build_recovery_genesis(&l1, &engine, &fx.params, 1).await.unwrap();
    assert_eq!(first.to_json_pretty(), next.to_json_pretty());
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
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
        let mut app = app_with(l1, engine, params, dir.path(), AppOptions::default());
        assert!(init_chain(&mut app, req).await.is_err(), "case {case}");
        assert_not_initialized(&app, dir.path());
        assert!(!app.trust.snapshot().is_ready());
        assert!(app.store.load_recovery_bootstrap().unwrap().is_none());
    }
}

#[tokio::test]
async fn recovery_init_restart_rejects_missing_mixed_or_tampered_bootstrap_sidecar() {
    for case in 0..6 {
        let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
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
            App::new(l1, engine, fx.params, Store::new(dir.path().into()), AppOptions::default())
                .is_err(),
            "case {case}"
        );
    }
}

#[tokio::test]
async fn recovery_init_durable_sidecar_precedes_state_and_is_immutable_on_retry() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let path = dir.path().join("recovery-bootstrap.json");
    let original = std::fs::read(&path).unwrap();
    let mut conflict = app.store.load_recovery_bootstrap().unwrap().unwrap();
    conflict.version = 2;
    assert!(matches!(
        app.store.save_recovery_bootstrap(&conflict),
        Err(crate::store::StoreError::BootstrapConflict)
    ));
    assert_eq!(std::fs::read(&path).unwrap(), original);
    drop(app);
    // Model a crash between the sidecar publication and AppState publication.
    std::fs::remove_file(dir.path().join(crate::store::STATE_FILE)).unwrap();
    let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    assert_eq!(std::fs::read(&path).unwrap(), original);
}

#[tokio::test]
async fn recovery_init_waits_on_the_same_request_for_historical_evidence() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let historical = l1.state().states.remove(&64).unwrap();
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
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
    assert_eq!(result.app_hash.as_bytes(), w.el_header.hash_slow().as_slice());
    assert_eq!(store.load().unwrap().unwrap().last_height, 6);
    assert!(!trust.snapshot().is_ready());
}

#[tokio::test]
async fn recovery_init_restart_reuses_authenticated_historical_sidecar_when_state_is_pruned() {
    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    let req = request(&document(&fx, &w));
    let first = init_chain(&mut app, req.clone()).await.unwrap();
    drop(app);
    let (_, l1, engine, _) = recovery_fixture(1, 6, 1);
    checkpoint(
        &fx,
        &l1,
        &w,
        18,
        [B256::repeat_byte(0x18), B256::repeat_byte(0x19), B256::repeat_byte(0x1a)],
        1,
    );
    l1.state().states.remove(&64);
    let mut app = app_with(l1, engine, fx.params, dir.path(), AppOptions::default());
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
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let env = propose(&mut app).await;
    let (_, req) = judge(&mut app, &env).await;
    decide(&mut app, &req).await;
    // A coherent old suffix must not pass merely because it descends from the genuine origin.
    let mut old = env.block.header;
    old.extra_data = crate::rules::encode_extra_data(0, 120).unwrap();
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
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
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
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
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
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
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

/// The first new-generation block can itself derive an incoming committee, from R's snapshot
/// (COMM-4.3-11). Every state read at R here outlasts a whole PrepareProposal budget: the first
/// round starts the background discovery at R and proposes nothing (RECOV-8-4, RECOV-8-10), the
/// discovery keeps reading past that deadline, and the next round proposes from it. No registry
/// read is repeated across rounds, and the snapshot is read at R alone.
#[tokio::test(start_paused = true)]
async fn recovery_first_switch_waits_for_the_background_discovery_at_r() {
    use super::proposal::{bft_time, next_height, prepare, prepare_req};
    use crate::test_utils::{GenesisSpec, L1Call, recovery_fixture_with_spec};
    use std::time::Duration;

    let mut spec = GenesisSpec::new(2);
    spec.epoch_len = 8;
    spec.entries = Some(crate::test_utils::sample_entries(301));
    let (fx, l1, engine, w) = recovery_fixture_with_spec(spec, 1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let floor = app.state().unwrap().anchor_floor();
    assert_eq!(app.state().unwrap().schedule().switch_target(7), Some(1));
    assert!(app.state().unwrap().anchor.number < floor, "c's retained anchor precedes R");
    let slow = Duration::from_millis(2_500);
    assert!(
        slow > AppOptions::default().prepare_timeout && slow < AppOptions::default().l1_timeout
    );
    app.l1().state().block_delay = Some((floor, slow));
    app.l1().state().calls.clear();
    let mut inbox = fx.inbox_at_checkpoint(6, w.el_header.hash_slow());
    inbox.recovery_generation = 1;
    inbox.forced_inclusion_head = 3;
    inbox.forced_inclusion_tail = 3;
    let proposer = tendermint::account::Id::new(
        app.state().unwrap().committee_at(7).unwrap().members[0].pubkey.address().into_array(),
    );
    let round = |app: &App<MockL1, MockEngine>| {
        let mut req = prepare_req(next_height(app), bft_time(app));
        req.proposer_address = proposer;
        req
    };

    fx.advance_l1(app.l1(), 121, &inbox, &fx.registry);
    let req = round(&app);
    assert!(prepare(&mut app, req).await.is_empty(), "R's reads outlast the round");
    assert_eq!(app.halt.as_deref(), Some("timeout"));
    // No request comes in meanwhile: the discovery the round started goes on at R.
    tokio::time::sleep(Duration::from_secs(30)).await;

    fx.advance_l1(app.l1(), 122, &inbox, &fx.registry);
    let req = round(&app);
    let txs = prepare(&mut app, req).await;
    let env = crate::EtnaEnvelope::decode(txs.first().expect("the next round proposes")).unwrap();
    assert_eq!(env.committee.unwrap().record.cutoff_l1_block, floor);
    let registry = fx.params.registry;
    let reads: Vec<(u64, L1Call)> = app
        .l1()
        .calls()
        .into_iter()
        .filter_map(|call| match &call {
            L1Call::StorageAt { address, block, .. } |
            L1Call::AccountWitness { address, block, .. }
                if *address == registry =>
            {
                Some((*block, call.clone()))
            }
            _ => None,
        })
        .collect();
    for (i, (_, call)) in reads.iter().enumerate() {
        assert!(reads[..i].iter().all(|(_, read)| read != call), "{call:?} again: {reads:?}");
    }
    let at_r = reads.iter().filter(|(block, _)| *block == floor).count();
    assert!(at_r >= 4, "the snapshot is discovered at R: {reads:?}");
    assert_eq!(
        reads.iter().filter(|(block, _)| *block != floor).collect::<Vec<_>>().len(),
        2,
        "beside R only round 2's anchor re-proves it (count and proof): {reads:?}"
    );
    assert!(reads.iter().all(|(block, _)| [floor, 122].contains(block)), "{reads:?}");
}

/// A read of R's state can take longer than a whole PrepareProposal budget, so no proposal can
/// finish the R snapshot on its own. The background discovery at R, which every
/// ProcessProposal starts, still completes the first recovered switch.
#[tokio::test(start_paused = true)]
async fn recovery_first_switch_completes_when_each_r_read_outlasts_the_proposal_budget() {
    use super::proposal::{bft_time, next_height, prepare, prepare_req};
    use crate::test_utils::{GenesisSpec, recovery_fixture_with_spec};
    use std::time::Duration;

    let mut spec = GenesisSpec::new(2);
    spec.epoch_len = 8;
    let (fx, l1, engine, w) = recovery_fixture_with_spec(spec, 1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let floor = app.state().unwrap().anchor_floor();
    assert_eq!(app.state().unwrap().schedule().switch_target(7), Some(1));
    assert!(app.state().unwrap().anchor.number < floor);
    let slow = Duration::from_millis(2_500);
    assert!(
        slow > AppOptions::default().prepare_timeout && slow < AppOptions::default().l1_timeout
    );
    app.l1().state().block_delay = Some((floor, slow));
    let mut inbox = fx.inbox_at_checkpoint(6, w.el_header.hash_slow());
    inbox.recovery_generation = 1;
    inbox.forced_inclusion_head = 3;
    inbox.forced_inclusion_tail = 3;
    for round in 0..40 {
        fx.advance_l1(app.l1(), 121 + round, &inbox, &fx.registry);
        let state = app.state().unwrap().clone();
        // As every ProcessProposal of the round does, empty proposals included.
        app.prefetch_committee_witness(&state);
        let mut req = prepare_req(next_height(&app), bft_time(&app));
        req.proposer_address = tendermint::account::Id::new(
            state.committee_at(7).unwrap().members[0].pubkey.address().into_array(),
        );
        if let Some(tx) = prepare(&mut app, req).await.first() {
            let env = crate::EtnaEnvelope::decode(tx).unwrap();
            assert_eq!(env.committee.unwrap().record.cutoff_l1_block, floor);
            return;
        }
        assert_eq!(app.halt.as_deref(), Some("timeout"));
    }
    panic!("the recovered switch never completed although every L1 read is within its deadline");
}

/// The first recovered switch's snapshot is fixed at R (COMM-4.3-11) and kept in memory: a later
/// round whose anchor advanced re-proves it with that anchor's registry proof alone. Nothing
/// survives a restart, so the restarted node discovers the same R snapshot again from its own L1
/// (SYNC-9-16) and proves it under the advanced anchor.
#[tokio::test]
async fn recovery_first_switch_reuses_snapshot_on_anchor_advance_and_rediscovers_after_restart() {
    use super::proposal::propose;
    use crate::test_utils::{GenesisSpec, L1Call, recovery_fixture_with_spec};
    let mut spec = GenesisSpec::new(2);
    spec.epoch_len = 8;
    let (fx, l1, engine, w) = recovery_fixture_with_spec(spec.clone(), 1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    let first = propose(&mut app).await.committee.unwrap();
    let floor = app.state().unwrap().anchor_floor();
    let mut inbox = fx.inbox_at_checkpoint(6, w.el_header.hash_slow());
    inbox.recovery_generation = 1;
    inbox.forced_inclusion_head = 3;
    inbox.forced_inclusion_tail = 3;
    let registry = fx.params.registry;
    let registry_reads = |app: &App<MockL1, MockEngine>| -> Vec<L1Call> {
        app.l1().calls().into_iter().filter(|call| {
            matches!(call, L1Call::StorageAt { address, .. } | L1Call::AccountWitness { address, .. }
                if *address == registry)
        }).collect()
    };

    fx.advance_l1(app.l1(), 121, &inbox, &fx.registry);
    app.l1().state().calls.clear();
    let next = propose(&mut app).await.committee.unwrap();
    assert_eq!((&next.record, &next.entries), (&first.record, &first.entries));
    let reads = registry_reads(&app);
    assert_eq!(reads.len(), 2, "only the new anchor's registry proof is fetched: {reads:?}");
    drop(app);

    let (_, l1, engine, _) = recovery_fixture_with_spec(spec, 1, 6, 1);
    checkpoint(&fx, &l1, &w, 6, retained(&w), 1);
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    fx.advance_l1(app.l1(), 121, &inbox, &fx.registry);
    app.l1().state().calls.clear();
    let restarted = propose(&mut app).await.committee.unwrap();
    assert_eq!((&restarted.record, &restarted.entries), (&first.record, &first.entries));
    let reads = registry_reads(&app);
    for block in [floor, 121] {
        assert!(
            reads
                .iter()
                .any(|c| matches!(c, L1Call::AccountWitness { block: at, .. } if *at == block)),
            "the restart proves the R snapshot at {block}: {reads:?}"
        );
    }
}
