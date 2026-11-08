//! Global committee timing from a proof-authenticated recovery boundary.

use super::*;
use crate::{
    app::validate::{self, Rejection, WitnessKind},
    committee::{Snapshot, VerifiedWitness, derive},
    l1::verify_anchor_witness,
    recovery::verify_recovery_witness,
    rules::chain_id_for,
    store::AppState,
    test_utils::{
        GenesisSpec, RegistryStorage, committee_witness, recovery_fixture_with_spec, sample_entries,
    },
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
    state.committees = [(origin.committee.record.target_epoch, origin.committee.clone())].into();
    state.val_state = crate::valstate::ValState::genesis(
        origin.height,
        &crate::test_utils::powers(&origin.committee.members),
    )
    .unwrap();
    state.recovery = Some(origin);
    (fx, l1, state)
}

fn committee_at_r(
    fx: &Fixture,
    l1: &MockL1,
    target: u64,
    origin_hash: alloy_primitives::B256,
) -> crate::CommitteeWitness {
    let storage =
        RegistryStorage { checkpoints: vec![(63, sample_entries(2)), (101, sample_entries(3))] };
    let mut inbox = fx.inbox_at_checkpoint(6, origin_hash);
    inbox.recovery_generation = 1;
    inbox.forced_inclusion_head = 3;
    inbox.forced_inclusion_tail = 3;
    fx.plant_l1_block(l1, 101, &inbox, &storage);
    let (record, _) = derive(
        &Snapshot { checkpoint_index: 0, l1_block: 63, entries: sample_entries(2) },
        100,
        target,
        &fx.params,
    )
    .unwrap();
    committee_witness(&l1.state().states[&101], fx.params.registry, &storage, 0, record)
}

#[test]
fn recovery_schedule_keeps_initial_set_when_old_switch_was_discarded() {
    let (fx, l1, mut state) = recovered(7);
    let r_committee = state.recovery.as_ref().unwrap().committee.clone();
    assert_eq!(state.origin_height(), 6);
    assert_eq!(state.anchor_floor(), 100);
    assert_eq!(state.initial_committee_epoch(), 0);
    assert_eq!(state.schedule().h0(), 1);
    assert_eq!(state.committee_at(6), None);
    assert_eq!(state.committee_at(7), Some(&r_committee));
    state.committees.insert(1, fx.committee(1)); // Old pending set from the discarded switch.
    assert_eq!(state.committee_at(8), Some(&r_committee));
    assert_eq!(state.committee_at(14), Some(&r_committee));
    assert_eq!(state.committee_at(15), None, "a switch within this generation cannot be skipped");
    let witness = committee_at_r(&fx, &l1, 2, state.parent.hash);
    let anchor = verify_anchor_witness(&fx.anchor_witness(&l1, 101), fx.params.inbox).unwrap();
    // The snapshot is R (block 100), which floors the retained anchor 64.
    let witness = VerifiedWitness::verify(anchor.state_root, 100, &fx.params, witness, 2).unwrap();
    let facts =
        validate::finish_candidate(&state.chain_context(), 13, Some(&witness), anchor).unwrap();
    let (epoch, epoch_two_committee) = facts.derived.unwrap();
    assert_eq!(epoch, 2);
    state.committees.insert(epoch, epoch_two_committee.clone());
    state.prune_committees(1);
    assert_eq!(state.committee_at(8), Some(&r_committee));
    assert_eq!(state.committee_at(14), Some(&r_committee));
    assert_eq!(state.committee_at(15), Some(&epoch_two_committee));
}

#[test]
fn recovery_schedule_first_block_switch_uses_r_floor_and_activates_at_nine() {
    let (fx, l1, mut state) = recovered(8);
    let initial = state.committees[&0].clone();
    assert_eq!(state.schedule().derivation_parent_height(1), Some(6));
    assert_eq!(state.schedule().switch_target(7), Some(1));
    let witness = committee_at_r(&fx, &l1, 1, state.parent.hash);
    let anchor = verify_anchor_witness(&fx.anchor_witness(&l1, 101), fx.params.inbox).unwrap();
    let witness = VerifiedWitness::verify(anchor.state_root, 100, &fx.params, witness, 1).unwrap();
    let facts =
        validate::finish_candidate(&state.chain_context(), 7, Some(&witness), anchor.clone())
            .unwrap();
    let (_, incoming) = facts.derived.unwrap();
    assert_eq!(incoming.record.cutoff_l1_block, 100, "old D(1) anchor 64 is floored by R");
    state.committees.insert(1, incoming.clone());
    assert_eq!(state.committee_at(7), Some(&initial));
    assert_eq!(state.committee_at(8), Some(&initial));
    assert_eq!(state.committee_at(9), Some(&incoming));
    let wrong_root = fx.expected_state().anchor;
    assert!(
        validate::finish_candidate(&state.chain_context(), 7, Some(&witness), wrong_root).is_err()
    );
    assert_eq!(
        validate::finish_candidate(&state.chain_context(), 7, None, anchor).unwrap_err(),
        Rejection::MissingWitness(WitnessKind::Committee)
    );
}

#[test]
fn recovery_schedule_initial_epoch_at_h_minus_one_discards_pending_old_set() {
    let (fx, _, mut state) = recovered(6);
    let initial = state.recovery.as_ref().unwrap().committee.clone();
    assert_eq!(state.initial_committee_epoch(), 1);
    assert_eq!(state.schedule().h_first(1), 7);
    assert_eq!(state.committee_at(7), Some(&initial));
    state.committees.insert(0, fx.committee(0));
    assert_eq!(state.committee_at(7), Some(&initial));
    assert_eq!(state.committee_at(12), Some(&initial));
    assert_eq!(state.committee_at(13), None);
}

#[test]
fn recovery_schedule_rejects_missing_switch_after_recovery() {
    let (fx, _, state) = recovered(7);
    assert!(matches!(
        validate::expected_header(
            &state.chain_context(),
            &fx.params,
            15,
            &state.anchor,
            state.parent.timestamp + 2,
            super::proposal::proposer()
        ),
        Err(Rejection::CommitteeUnknown(2))
    ));
    let mut genesis = fx.expected_state();
    genesis.committees.clear();
    assert_eq!(genesis.committee_at(1), None);
    genesis.committees.insert(0, fx.committee(0));
    assert_eq!(genesis.committee_at(8), None, "generation zero still requires every rotation");
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

/// Runs the actual proposal validation, validator updates and pruning over a skipped epoch.
#[tokio::test]
async fn recovery_schedule_proposals_finalize_and_prune_only_after_real_switches() {
    use super::proposal::{decide, judge, propose};
    let (fx, l1, state) = recovered(7);
    let r_committee = state.committees[&0].clone();
    let mut spec = GenesisSpec::new(2);
    spec.epoch_len = 7;
    let (_, _, engine, _) = recovery_fixture_with_spec(spec, 1, 6, 1);
    let _witness = committee_at_r(&fx, &l1, 2, state.parent.hash);
    l1.set_finalized(101);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
    app.state = Some(state);
    for height in 7..=23 {
        let env = propose(&mut app).await;
        assert_eq!(env.committee.is_some(), height == 13 || height == 20);
        let (accepted, request) = judge(&mut app, &env).await;
        assert_eq!(accepted, response::ProcessProposal::Accept);
        let finalized = decide(&mut app, &request).await;
        // Epoch 3 derives a new record with the same native set, so it emits no changes.
        assert_eq!(!finalized.validator_updates.is_empty(), height == 13);
        let state = app.state().unwrap();
        if height <= 14 {
            assert_eq!(state.committee_at(height), Some(&r_committee));
            assert!(state.committees.contains_key(&0), "R set remains active through 14");
        } else {
            assert_eq!(
                state.committee_at(height).unwrap().record.target_epoch,
                if height < 22 { 2 } else { 3 }
            );
            assert_eq!(state.committee_at(height).unwrap().members.len(), 3);
        }
        if height >= 20 {
            assert!(
                !state.committees.contains_key(&0),
                "R set is obsolete after the next real switch"
            );
        }
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
        committee: None,
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

#[tokio::test]
async fn recovery_schedule_boundary_switches_keep_global_h_plus_two() {
    use super::proposal::{decide, judge, propose};
    for (length, switch, activation, target) in [(8, 7, 9, 1), (6, 11, 13, 2)] {
        let (fx, l1, state) = recovered(length);
        let initial = state.committees[&state.initial_committee_epoch()].clone();
        let mut spec = GenesisSpec::new(2);
        spec.epoch_len = length;
        let (_, _, engine, _) = recovery_fixture_with_spec(spec, 1, 6, 1);
        let _witness = committee_at_r(&fx, &l1, target, state.parent.hash);
        l1.set_finalized(101);
        let dir = tempfile::tempdir().unwrap();
        let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), AppOptions::default());
        app.state = Some(state);
        for height in 7..=activation {
            let env = propose(&mut app).await;
            assert_eq!(env.anchor.is_some(), height == 7);
            assert_eq!(env.committee.is_some(), height == switch);
            if let Some(witness) = &env.committee {
                assert_eq!(witness.record.cutoff_l1_block, if length == 8 { 100 } else { 101 });
            }
            let (accepted, request) = judge(&mut app, &env).await;
            assert_eq!(accepted, response::ProcessProposal::Accept);
            let response = decide(&mut app, &request).await;
            assert_eq!(!response.validator_updates.is_empty(), length == 6 && height == switch);
            let active = app.state().unwrap().committee_at(height).unwrap();
            if height < activation {
                assert_eq!(active, &initial);
            } else {
                assert_eq!(active.record.target_epoch, target);
                assert_eq!(active.members.len(), if length == 8 { 2 } else { 3 });
            }
        }
    }
}
