//! Proposals from a proof-authenticated recovery boundary: R's committee signs every height
//! after c, the first block needs an anchor at or after R, and the stored state keeps one schema
//! and a consistent recovery origin.

use super::*;
use crate::{
    app::validate::{self, Rejection, WitnessKind},
    l1::verify_anchor_witness,
    recovery::verify_recovery_witness,
    rules::chain_id_for,
    store::AppState,
    test_utils::{GenesisSpec, RegistryStorage, recovery_fixture_with_spec, sample_entries},
};

/// Real MPT recovery evidence, the authenticated old anchor, and no imported pending sets.
fn recovered(epoch_len: u64) -> (Fixture, MockL1, AppState) {
    let mut spec = GenesisSpec::new(2);
    spec.epoch_len = epoch_len;
    let (fx, l1, _, witness) = recovery_fixture_with_spec(spec, 1, 6, 1);
    let origin = verify_recovery_witness(&witness, &fx.params).unwrap();
    let mut state = fx.expected_state();
    state.anchor = verify_anchor_witness(&fx.anchor_witness(&l1, 64), fx.params.inbox).unwrap();
    state.generation = 1;
    state.chain_id = chain_id_for(&fx.params, 1).unwrap();
    state.last_height = 6;
    state.parent.number = 6;
    state.parent.hash = origin.el_hash;
    state.forced_cursor = origin.forced_cursor;
    state.val_state = crate::valstate::ValState::genesis(
        origin.height,
        &crate::test_utils::powers(&origin.committee.members),
    )
    .unwrap();
    state.recovery = Some(origin);
    (fx, l1, state)
}

/// Plants the finalized L1 block 101 above R, whose Inbox holds c (generation 1) as its
/// checkpoint, for the first recovered block to anchor at.
fn plant_r_anchor(fx: &Fixture, l1: &MockL1, origin_hash: alloy_primitives::B256) {
    let storage =
        RegistryStorage { checkpoints: vec![(63, sample_entries(2)), (101, sample_entries(3))] };
    let mut inbox = fx.inbox_at_checkpoint(6, origin_hash);
    inbox.recovery_generation = 1;
    inbox.forced_inclusion_head = 3;
    inbox.forced_inclusion_tail = 3;
    fx.plant_l1_block(l1, 101, &inbox, &storage);
}

#[test]
fn stored_state_has_one_schema_and_a_consistent_recovery_origin() {
    use crate::store::{STATE_FILE, STATE_SCHEMA_VERSION};
    let (fx, _, recovered) = recovered(7);
    let check = |state: &AppState| super::super::check_stored_state(state, &fx.params);
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
    // The recovery origin alone distinguishes generation zero from a recovery generation.
    let mut wrong = recovered.clone();
    wrong.recovery = None;
    assert!(check(&wrong).is_err());
    let mut wrong = genesis.clone();
    wrong.recovery = recovered.recovery.clone();
    assert!(check(&wrong).is_err());
    let mut mismatched = recovered.clone();
    mismatched.recovery.as_mut().unwrap().generation = 2;
    assert!(check(&mismatched).is_err());
}

/// R's committee signs every height after c, through what the global schedule called switch
/// heights: every FinalizeBlock returns no validator updates and the replica's signing set
/// stays R's.
#[tokio::test]
async fn recovery_committee_signs_every_height_after_c() {
    use super::proposal::{decide, judge, propose};
    let (fx, l1, state) = recovered(7);
    let r_set = state.val_state.current.members();
    let mut spec = GenesisSpec::new(2);
    spec.epoch_len = 7;
    let (_, _, engine, _) = recovery_fixture_with_spec(spec, 1, 6, 1);
    plant_r_anchor(&fx, &l1, state.parent.hash);
    l1.set_finalized(101);
    let dir = tempfile::tempdir().unwrap();
    let mut app =
        app_with(l1, engine, fx.params.clone(), dir.path(), crate::test_utils::test_options());
    app.state = Some(state);
    for height in 7..=23 {
        let env = propose(&mut app).await;
        if height == 7 {
            assert!(env.anchor.is_some(), "the first block carries its anchor witness");
        }
        let (accepted, request) = judge(&mut app, &env).await;
        assert_eq!(accepted, response::ProcessProposal::Accept, "height {height}");
        let finalized = decide(&mut app, &request).await;
        assert!(finalized.validator_updates.is_empty(), "height {height}");
        let state = app.state().unwrap();
        assert_eq!(state.last_height, height);
        assert_eq!(state.val_state.current.members(), r_set, "height {height}");
        if height == 18 {
            let mut inbox = fx.inbox_at_checkpoint(18, state.parent.hash);
            inbox.recovery_generation = 1;
            inbox.forced_inclusion_head = 3;
            inbox.forced_inclusion_tail = 3;
            let storage = RegistryStorage {
                checkpoints: vec![(63, sample_entries(2)), (101, sample_entries(3))],
            };
            fx.advance_l1(app.l1(), 102, &inbox, &storage);
        }
    }
}

#[test]
fn recovery_schedule_first_block_requires_a_witness_at_or_after_r() {
    let (fx, _, state) = recovered(8);
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
