//! The committee witness at `H(t)-2`: it is proven against the PARENT's anchor even when the
//! block moves its own anchor, and every forgery of its record, entries or registry proofs is
//! refused. Also the committees a switch height needs.

use alloy_primitives::{B256, U256};

use super::{
    proposal::{
        bft_time, hand_envelope, judge, jump, next_height, prepare, prepare_req, propose, rejected,
        validate,
    },
    *,
};
use crate::{
    app::validate::Rejection,
    committee::{CommitteeError, entries_root, snapshot_slots, verify_committee_witness},
    engine::EngineError,
    envelope::CommitteeWitness,
    l1::{
        MptError, build_committee_witness_at_cutoff, build_committee_witness_within,
        layout::registry,
    },
    test_utils::{L1Call, RegistryStorage, sample_entries},
    types::AnchorState,
};

/// The L1 block the parent of `switch 2` is anchored at in [`before_switch`].
const PARENT_ANCHOR: u64 = 1010;
/// The L1 block the block at `switch 2` moves its anchor to in [`before_switch`].
const NEW_ANCHOR: u64 = 1030;
/// The L1 block of the registry checkpoint written between the two anchors.
const JOIN_BLOCK: u64 = 1020;
/// A later finalized L1 block a second round at `switch 2` moves its anchor to.
const LATER_ANCHOR: u64 = 1040;

/// The registry after [`JOIN_BLOCK`]: the genesis checkpoint (three entries) and a second one
/// (four entries).
fn joined_registry(fx: &Fixture) -> RegistryStorage {
    RegistryStorage {
        checkpoints: vec![
            (fx.genesis.genesis_cutoff, sample_entries(3)),
            (JOIN_BLOCK, sample_entries(4)),
        ],
    }
}

/// The staking-registry reads `app` made so far, in order.
fn registry_calls(app: &App<MockL1, MockEngine>) -> Vec<L1Call> {
    let registry = app.params.registry;
    app.l1()
        .calls()
        .into_iter()
        .filter(|c| {
            matches!(c, L1Call::StorageAt { address, .. } | L1Call::AccountWitness { address, .. }
                if *address == registry)
        })
        .collect()
}

/// The two reads that re-prove the committed snapshot (checkpoint 0) under the root of `block`,
/// where checkpoint 1 also exists: the checkpoint count, then one registry proof.
fn reproof_calls(app: &App<MockL1, MockEngine>, block: u64) -> Vec<L1Call> {
    let address = app.params.registry;
    vec![
        L1Call::StorageAt { address, slot: registry::length_slot(), block },
        L1Call::AccountWitness { address, slots: snapshot_slots(0, true), block },
    ]
}

/// An app whose next height is `switch 2` and whose block there moves the anchor.
///
/// The parent is anchored at L1 block [`PARENT_ANCHOR`], where the registry holds only the
/// genesis checkpoint (three entries). The own L1 has finalized [`NEW_ANCHOR`], where the last
/// checkpoint has advanced and a second registry checkpoint (block [`JOIN_BLOCK`], four entries)
/// exists. Committee 2 uses committed parent 1010, before the join at 1020.
/// Returns the app and new candidate anchor 1030.
async fn before_switch(fx: &Fixture, dir: &Path) -> (App<MockL1, MockEngine>, AnchorState) {
    let mut app = initialized(fx, dir).await;
    let h_e = app.state().unwrap().schedule().h_first(2) - 2;
    fx.plant_l1_block(app.l1(), PARENT_ANCHOR, &fx.inbox_with(h_e - 6), &fx.registry);
    let parent = fx.anchor_state(app.l1(), PARENT_ANCHOR);
    jump(&mut app, h_e - 1, parent, &[(1, fx.committee(1))]);

    fx.plant_l1_block(app.l1(), JOIN_BLOCK - 1, &fx.inbox_with(h_e - 3), &fx.registry);
    fx.advance_l1(app.l1(), NEW_ANCHOR, &fx.inbox_with(h_e - 3), &joined_registry(fx));
    let moved = fx.anchor_state(app.l1(), NEW_ANCHOR);
    assert_ne!(moved.state_root, app.state().unwrap().anchor.state_root);
    (app, moved)
}

/// The committee-2 witness an honest proposer builds at `switch 2` against the anchor
/// `n_p`, using that parent number and its authenticated registry state.
async fn witness_at(app: &App<MockL1, MockEngine>, n_p: u64) -> CommitteeWitness {
    build_committee_witness_within(app.l1(), &app.params, n_p, 2, app.opts.l1_timeout)
        .await
        .expect("the committee witness builds")
}

/// (a) The honest proposer moves the anchor to [`NEW_ANCHOR`] and proves committee 2 at the
/// parent's anchor [`PARENT_ANCHOR`]: snapshot 1010 selects the genesis checkpoint. Accepted.
#[tokio::test]
async fn committee_witness_uses_own_anchor_root_and_parent_cutoff() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, moved) = before_switch(&fx, dir.path()).await;

    let env = propose(&mut app).await;
    assert_eq!(env.anchor.as_ref().map(|w| w.l1_header.number()), Some(NEW_ANCHOR));
    let w = env.committee.clone().expect("switch 2 carries a committee witness");
    assert_eq!(
        w,
        crate::l1::build_committee_witness_at_cutoff(
            app.l1(),
            &app.params,
            NEW_ANCHOR,
            PARENT_ANCHOR,
            2
        )
        .await
        .unwrap()
    );
    assert_eq!(w.record.target_epoch, 2);
    assert_eq!(w.record.cutoff_l1_block, PARENT_ANCHOR, "committed parent snapshot");
    assert_eq!(w.record.checkpoint_index, 0, "checkpoint 1 (block 1020) is after the parent");
    assert_eq!(w.entries, sample_entries(3));

    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    let v = app.verdicts.get(&req.hash).expect("the verdict is cached");
    assert_eq!(v.anchor, moved, "the block itself is anchored at the new L1 block");
    let (target, derived) = v.derived.clone().expect("committee 2 is derived");
    assert_eq!(target, 2);
    assert_eq!(derived.record, w.record);
    assert_eq!(derived.members.len(), 3);
}

/// Another node accepts the honest moved-anchor `switch 2` proposal and retains its witness, in
/// memory only, under the candidate anchor it was verified at.
#[tokio::test]
async fn a_valid_peer_switch_witness_is_accepted_and_retained_in_memory() {
    let fx = Fixture::genesis(3);
    let proposer_dir = tempfile::tempdir().unwrap();
    let (mut proposer, _) = before_switch(&fx, proposer_dir.path()).await;
    let env = propose(&mut proposer).await;
    let dir = tempfile::tempdir().unwrap();
    let (mut app, moved) = before_switch(&fx, dir.path()).await;
    let (response, _) = judge(&mut app, &env).await;
    assert_eq!(response, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    assert!(!dir.path().join("fatal-evidence.txt").exists());
    let state = app.state().unwrap().clone();
    assert_eq!(app.cached_candidate_committee_witness(&state, &moved, 2), env.committee);
    assert!(!dir.path().join("abci-committee-witness.json").exists());
}

/// The in-memory cache takes a witness only once it verifies, and serves it only for its full
/// committed context: chain, genesis, parent anchor (number, hash, root) and target epoch.
#[tokio::test]
async fn the_witness_cache_holds_only_verified_witnesses_for_their_full_context() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (app, _) = before_switch(&fx, dir.path()).await;
    let state = app.state().unwrap().clone();
    let valid = witness_at(&app, PARENT_ANCHOR).await;
    let mut forged = valid.clone();
    forged.entries[1].eff_stake += U256::from(1);
    match app.cache_committee_witness(&state, 2, &forged) {
        Err(Rejection::Committee(CommitteeError::EntriesRootMismatch { .. })) => {}
        other => panic!("a forged witness must not verify: {other:?}"),
    }
    assert_eq!(app.context_committee_witness(&state, 2), None, "nothing forged is retained");

    app.cache_committee_witness(&state, 2, &valid).unwrap();
    assert_eq!(app.cached_committee_witness(&state, 2), Some(valid));
    assert_eq!(app.cached_committee_witness(&state, 3), None, "target epoch");
    type Change = Box<dyn Fn(&mut crate::store::AppState)>;
    let changes: Vec<(&str, Change)> = vec![
        ("chain_id", Box::new(|s| s.chain_id.push_str("-other"))),
        ("genesis", Box::new(|s| s.genesis.epoch_len += 1)),
        ("parent anchor number", Box::new(|s| s.anchor.number += 1)),
        ("parent anchor hash", Box::new(|s| s.anchor.hash = B256::repeat_byte(0xe1))),
        ("parent state root", Box::new(|s| s.anchor.state_root = B256::repeat_byte(0xe1))),
    ];
    for (case, change) in changes {
        let mut other = state.clone();
        change(&mut other);
        assert_eq!(app.cached_committee_witness(&other, 2), None, "{case}");
        assert_eq!(app.context_committee_witness(&other, 2), None, "{case}");
    }
}

/// (b) The candidate anchor 1030 selects the joined checkpoint and is valid there, but its
/// registry proof does not authenticate under the committed parent 1010, so it is refused.
#[tokio::test]
async fn committee_witness_cannot_select_a_newer_cutoff() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, moved) = before_switch(&fx, dir.path()).await;

    let w = witness_at(&app, NEW_ANCHOR).await;
    assert_eq!(w.record.cutoff_l1_block, NEW_ANCHOR);
    assert_eq!(w.record.checkpoint_index, 1);
    assert_eq!(w.entries, sample_entries(4));
    assert_eq!(
        verify_committee_witness(&moved, &app.params, &w, 2).map(|_| ()),
        Ok(()),
        "valid against the new anchor"
    );

    let anchor = fx.anchor_witness(app.l1(), NEW_ANCHOR);
    let env = hand_envelope(&app, Some(anchor), Some(w));
    match validate(&app, &env) {
        Err(Rejection::Committee(CommitteeError::CheckpointAfterCutoff { .. })) => {}
        other => panic!("expected the registry account proof to fail at the parent: {other:?}"),
    }
    assert_eq!(rejected(&mut app, &env).await, "committee_witness");
}

/// A forgery applied in place to a valid committee witness.
type Forge = Box<dyn Fn(&mut CommitteeWitness)>;
/// Whether a committee error is the one a forgery must be rejected with.
type Expect = fn(&CommitteeError) -> bool;

/// (c) At the same moving-anchor `switch 2`: a forged record, a forged entry list and a
/// tampered registry proof are each refused, with the expected committee error and the
/// `committee_witness` label.
#[tokio::test]
async fn forged_committee_witnesses_are_rejected() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, _) = before_switch(&fx, dir.path()).await;
    let anchor = fx.anchor_witness(app.l1(), NEW_ANCHOR);
    let valid = crate::l1::build_committee_witness_at_cutoff(
        app.l1(),
        &app.params,
        NEW_ANCHOR,
        PARENT_ANCHOR,
        2,
    )
    .await
    .unwrap();
    let env = hand_envelope(&app, Some(anchor.clone()), Some(valid.clone()));
    assert!(validate(&app, &env).is_ok(), "the unforged witness passes");

    let record: Expect = |e| matches!(e, CommitteeError::RecordMismatch { .. });
    let count: Expect = |e| matches!(e, CommitteeError::EntryCountMismatch { .. });
    let root: Expect = |e| matches!(e, CommitteeError::EntriesRootMismatch { .. });
    let storage: Expect = |e| matches!(e, CommitteeError::Mpt(MptError::Storage { .. }));
    let account: Expect = |e| matches!(e, CommitteeError::Mpt(MptError::Account(_)));
    let slots: Expect = |e| matches!(e, CommitteeError::Mpt(MptError::SlotSet { .. }));
    let contract: Expect = |e| matches!(e, CommitteeError::WrongContract { .. });
    let (l1_0, inbox) = (fx.genesis.l1_0, fx.params.inbox);
    let cases: Vec<(&str, Forge, Expect)> = vec![
        // The record.
        ("set_root", Box::new(|w| w.record.set_root = B256::repeat_byte(0x5e)), record),
        ("total_power", Box::new(|w| w.record.total_power += 1), record),
        ("new anchor's cutoff", Box::new(|w| w.record.cutoff_l1_block = NEW_ANCHOR), record),
        ("target_epoch", Box::new(|w| w.record.target_epoch = 3), record),
        // The entry list.
        ("entry dropped", Box::new(|w| w.entries.truncate(2)), count),
        ("entry added", Box::new(|w| w.entries.push(sample_entries(4)[3].clone())), count),
        ("entry changed", Box::new(|w| w.entries[1].eff_stake += U256::from(1)), root),
        ("entries reordered", Box::new(|w| w.entries.swap(0, 2)), root),
        // The registry proof.
        (
            "count and entriesRoot words forged to match a dropped entry",
            Box::new(move |w| {
                w.entries.truncate(2);
                w.registry.storage[1].value = U256::from(l1_0) | (U256::from(2) << 48);
                w.registry.storage[2].value = entries_root(&w.entries).into();
            }),
            storage,
        ),
        ("truncated storage proof", Box::new(|w| w.registry.storage[0].proof.truncate(1)), storage),
        ("account storage root", Box::new(|w| w.registry.storage_root = B256::ZERO), account),
        ("another checkpoint's slots", Box::new(|w| w.record.checkpoint_index = 1), slots),
        ("another contract", Box::new(move |w| w.registry.address = inbox), contract),
    ];
    for (case, forge, expected) in cases {
        let mut w = valid.clone();
        forge(&mut w);
        let env = hand_envelope(&app, Some(anchor.clone()), Some(w));
        match validate(&app, &env) {
            Err(Rejection::Committee(e)) if expected(&e) => {}
            other => panic!("{case}: {other:?}"),
        }
        assert_eq!(rejected(&mut app, &env).await, "committee_witness", "{case}");
    }
}

/// (d) The snapshot of a moved-anchor `switch 2` is fixed by the committed parent anchor
/// (COMM-4.3-11), and only its registry proof depends on the candidate's root (COMM-4.3-12): a
/// proposer holding the parent anchor's verified witness re-proves it with two reads at
/// [`NEW_ANCHOR`] instead of discovering the registry again.
#[tokio::test]
async fn a_moved_anchor_reproves_the_parent_anchor_witness() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, _) = before_switch(&fx, dir.path()).await;
    let state = app.state().unwrap().clone();
    app.cache_committee_witness(&state, 2, &witness_at(&app, PARENT_ANCHOR).await).unwrap();
    app.l1().state().calls.clear();

    let env = propose(&mut app).await;
    assert_eq!(registry_calls(&app), reproof_calls(&app, NEW_ANCHOR));
    let expected =
        build_committee_witness_at_cutoff(app.l1(), &app.params, NEW_ANCHOR, PARENT_ANCHOR, 2)
            .await
            .unwrap();
    assert_eq!(env.committee, Some(expected));
}

/// (e) A later round at `switch 2`, after the own L1 finalized past the anchor an earlier
/// round proved under, re-proves the witness that round retained: finality moving between
/// rounds never restarts the registry discovery.
#[tokio::test]
async fn a_round_after_finality_moves_again_reproves_the_retained_witness() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, _) = before_switch(&fx, dir.path()).await;
    // Round 0 at NEW_ANCHOR: the committee witness is built, then the EL fails to build.
    app.engine().state().build_script.push_back(Err(EngineError::Transport("down".into())));
    let req = prepare_req(next_height(&app), bft_time(&app));
    assert!(prepare(&mut app, req).await.is_empty());

    // Round 1: the own L1 has finalized LATER_ANCHOR in between.
    let h_e = app.state().unwrap().schedule().h_first(2) - 2;
    fx.advance_l1(app.l1(), LATER_ANCHOR, &fx.inbox_with(h_e - 3), &joined_registry(&fx));
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert_eq!(env.anchor.as_ref().map(|w| w.l1_header.number()), Some(LATER_ANCHOR));
    assert_eq!(registry_calls(&app), reproof_calls(&app, LATER_ANCHOR));
    let expected =
        build_committee_witness_at_cutoff(app.l1(), &app.params, LATER_ANCHOR, PARENT_ANCHOR, 2)
            .await
            .unwrap();
    assert_eq!(env.committee, Some(expected));
}

/// (f) A retained witness whose snapshot does not hold under the candidate's root is not
/// proposed. Here it was verified under another L1 state whose genesis checkpoint holds two
/// entries, as a forged peer proposal can leave one. The proposer falls back to the parent
/// anchor's own snapshot and re-proves that.
#[tokio::test]
async fn a_retained_witness_that_fails_under_the_new_root_gives_way_to_the_parent_anchor() {
    const FORGED_ANCHOR: u64 = 1025;
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, _) = before_switch(&fx, dir.path()).await;
    let h_e = app.state().unwrap().schedule().h_first(2) - 2;
    let other =
        RegistryStorage { checkpoints: vec![(fx.genesis.genesis_cutoff, sample_entries(2))] };
    fx.plant_l1_block(app.l1(), FORGED_ANCHOR, &fx.inbox_with(h_e - 3), &other);
    let forged_anchor = fx.anchor_state(app.l1(), FORGED_ANCHOR);
    let forged =
        build_committee_witness_at_cutoff(app.l1(), &app.params, FORGED_ANCHOR, PARENT_ANCHOR, 2)
            .await
            .unwrap();
    let state = app.state().unwrap().clone();
    app.cache_candidate_committee_witness(&state, &forged_anchor, 2, &forged).unwrap();

    let env = propose(&mut app).await;
    let expected =
        build_committee_witness_at_cutoff(app.l1(), &app.params, NEW_ANCHOR, PARENT_ANCHOR, 2)
            .await
            .unwrap();
    assert_eq!(env.committee, Some(expected));
}

#[tokio::test]
async fn a_rejected_switch_proposal_cannot_replace_the_authenticated_cache() {
    for checkpoint_conflict in [false, true] {
        let fx = Fixture::genesis(3);
        let dir = tempfile::tempdir().unwrap();
        let (mut app, _) = before_switch(&fx, dir.path()).await;
        let state = app.state().unwrap().clone();
        let retained = witness_at(&app, PARENT_ANCHOR).await;
        app.cache_committee_witness(&state, 2, &retained).unwrap();
        if checkpoint_conflict {
            let mut inbox = fx.inbox_with(state.last_height);
            inbox.last_checkpoint_hash = B256::repeat_byte(0xde);
            fx.plant_l1_block(app.l1(), NEW_ANCHOR, &inbox, &joined_registry(&fx));
        }
        let moved =
            build_committee_witness_at_cutoff(app.l1(), &app.params, NEW_ANCHOR, PARENT_ANCHOR, 2)
                .await
                .unwrap();
        let anchor = fx.anchor_witness(app.l1(), NEW_ANCHOR);
        let env = hand_envelope(&app, Some(anchor), Some(moved));
        let reason = if checkpoint_conflict {
            "checkpoint_conflict"
        } else {
            app.l1().set_finalized(PARENT_ANCHOR);
            "anchor_not_final"
        };
        assert_eq!(rejected(&mut app, &env).await, reason);
        assert_eq!(app.context_committee_witness(&state, 2), Some(retained));
    }
}

/// An unknown outgoing committee cannot be replaced, even with a valid incoming witness.
#[tokio::test]
async fn switch_height_with_an_unknown_outgoing_committee_is_rejected() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let switch = fx.schedule().h_first(1) - 2;
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(switch - 7), &fx.registry);
    let parent = fx.anchor_state(app.l1(), 66);
    jump(&mut app, switch - 1, parent, &[]);
    let env = propose(&mut app).await;
    app.state.as_mut().unwrap().committees.remove(&0);
    assert_eq!(validate(&app, &env).map(|_| ()), Err(Rejection::CommitteeUnknown(0)));
    assert_eq!(rejected(&mut app, &env).await, "committee_unknown");
    let time = bft_time(&app);
    assert!(prepare(&mut app, prepare_req(switch, time)).await.is_empty());
}
