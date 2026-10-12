//! The committee witness at `H(t)-2`: it is proven against the PARENT's anchor even when the
//! block moves its own anchor, and every forgery of its record, entries or registry proofs is
//! refused. Also the committees a switch height needs.

use alloy_primitives::{B256, U256};

use super::{
    proposal::{
        bft_time, hand_envelope, judge, jump, prepare, prepare_req, propose, rejected, validate,
    },
    *,
};
use crate::{
    app::validate::Rejection,
    committee::{CommitteeError, entries_root, verify_committee_witness},
    envelope::CommitteeWitness,
    l1::{DiscoveryProgress, MptError, build_committee_witness_within},
    test_utils::{RegistryStorage, sample_entries},
    types::AnchorState,
};

/// The L1 block the parent of `switch 2` is anchored at in [`before_switch`].
const PARENT_ANCHOR: u64 = 1010;
/// The L1 block the block at `switch 2` moves its anchor to in [`before_switch`].
const NEW_ANCHOR: u64 = 1030;
/// The L1 block of the registry checkpoint written between the two anchors.
const JOIN_BLOCK: u64 = 1020;

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

    let joined = RegistryStorage {
        checkpoints: vec![
            (fx.genesis.genesis_cutoff, sample_entries(3)),
            (JOIN_BLOCK, sample_entries(4)),
        ],
    };
    fx.plant_l1_block(app.l1(), JOIN_BLOCK - 1, &fx.inbox_with(h_e - 3), &fx.registry);
    fx.advance_l1(app.l1(), NEW_ANCHOR, &fx.inbox_with(h_e - 3), &joined);
    let moved = fx.anchor_state(app.l1(), NEW_ANCHOR);
    assert_ne!(moved.state_root, app.state().unwrap().anchor.state_root);
    (app, moved)
}

/// The committee-2 witness an honest proposer builds at `switch 2` against the anchor
/// `n_p`, using that parent number and its authenticated registry state.
async fn witness_at(app: &App<MockL1, MockEngine>, n_p: u64) -> CommitteeWitness {
    let progress = DiscoveryProgress::default();
    let schedule = app.state().expect("initialized").schedule();
    build_committee_witness_within(
        app.l1(),
        &app.params,
        &schedule,
        n_p,
        2,
        app.opts.l1_timeout,
        &progress,
    )
    .await
    .expect("the committee witness builds")
}

/// (a) The honest proposer moves the anchor to [`NEW_ANCHOR`] and proves committee 2 at the
/// parent's anchor [`PARENT_ANCHOR`]: snapshot 1010 selects the genesis checkpoint. Accepted.
#[tokio::test]
async fn committee_witness_proven_at_the_parent_anchor_is_accepted() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, moved) = before_switch(&fx, dir.path()).await;

    let env = propose(&mut app).await;
    assert_eq!(env.anchor.as_ref().map(|w| w.l1_header.number()), Some(NEW_ANCHOR));
    let w = env.committee.clone().expect("switch 2 carries a committee witness");
    assert_eq!(w, witness_at(&app, PARENT_ANCHOR).await);
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

/// (b) The candidate anchor 1030 selects the joined checkpoint and is valid there, but its
/// registry proof does not authenticate under the committed parent 1010, so it is refused.
#[tokio::test]
async fn committee_witness_proven_at_the_new_anchor_is_rejected() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, moved) = before_switch(&fx, dir.path()).await;

    let w = witness_at(&app, NEW_ANCHOR).await;
    assert_eq!(w.record.cutoff_l1_block, NEW_ANCHOR);
    assert_eq!(w.record.checkpoint_index, 1);
    assert_eq!(w.entries, sample_entries(4));
    assert_eq!(
        verify_committee_witness(&moved, &app.state().unwrap().schedule(), &app.params, &w, 2)
            .map(|_| ()),
        Ok(()),
        "valid against the new anchor"
    );

    let anchor = fx.anchor_witness(app.l1(), NEW_ANCHOR);
    let env = hand_envelope(&app, Some(anchor), Some(w));
    match validate(&app, &env) {
        Err(Rejection::Committee(CommitteeError::Mpt(MptError::Account(_)))) => {}
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
    let valid = witness_at(&app, PARENT_ANCHOR).await;
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
                w.registry.storage[1].value = U256::from(l1_0) | (U256::from(2) << 64);
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
