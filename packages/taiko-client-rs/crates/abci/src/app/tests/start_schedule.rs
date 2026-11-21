//! Committee timing from a nonzero Etna start S (COMM-4.3-9..13): committee 0 governs from
//! S + 1 whatever global epoch S lies in, and the first rotation above S keeps it signing through
//! S(t) + 1. Every height runs the real `PrepareProposal`, `ProcessProposal`, `FinalizeBlock` and
//! `Commit`; [`jump`] only skips plain heights between switches.

use super::{
    proposal::{decide, judge, jump, propose},
    *,
};
use crate::{
    store::AppState,
    test_utils::{GenesisSpec, RegistryStorage, sample_entries},
};

/// A generation-zero app committed at its Etna start `s` (the state `InitChain` persists there),
/// with epoch length `epoch_len` and two genesis validators.
fn started(s: u64, epoch_len: u64, dir: &Path) -> (Fixture, App<MockL1, MockEngine>) {
    let fx = Fixture::build(GenesisSpec { genesis_height: s, epoch_len, ..GenesisSpec::new(2) });
    let mut app = fx.app(dir);
    app.state = Some(fx.expected_state());
    (fx, app)
}

/// Runs the next height through every handler; returns its envelope and validator updates.
async fn run(
    app: &mut App<MockL1, MockEngine>,
) -> (crate::EtnaEnvelope, Vec<crate::wire::ValidatorUpdate>) {
    let env = propose(app).await;
    let (accepted, request) = judge(app, &env).await;
    assert_eq!(accepted, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    let finalized = decide(app, &request).await;
    (env, finalized.validator_updates)
}

/// The target epoch of the committee `state` requires at `height`.
fn active(state: &AppState, height: u64) -> u64 {
    state
        .committee_at(height)
        .unwrap_or_else(|| panic!("no committee known for height {height}"))
        .record
        .target_epoch
}

/// The registry with the genesis checkpoint (two entries) and one more checkpoint per entry in
/// `later`: `(L1 block, number of entries)`.
fn registry(fx: &Fixture, later: &[(u64, usize)]) -> RegistryStorage {
    let mut checkpoints = vec![(fx.genesis.genesis_cutoff, sample_entries(2))];
    checkpoints.extend(later.iter().map(|&(block, n)| (block, sample_entries(n))));
    RegistryStorage { checkpoints }
}

/// Vector 9.d (COMM-4.3-9, COMM-4.3-13): S = 1000, L = 900. Committee 0 governs from 1001
/// without a witness (9.f); the next switch above S is S(2) = 1799, an ordinary rotation whose
/// outgoing set is committee 0, not the never-derived committee 1. 1800 = S(2) + 1 is still
/// accepted under committee 0, 1801 = H(2) under committee 2, and only the next real switch,
/// S(3) = 2699, makes committee 0 obsolete.
#[tokio::test]
async fn vector_9d_first_rotation_above_s_keeps_committee_zero_through_s_t_plus_one() {
    let dir = tempfile::tempdir().unwrap();
    let (fx, mut app) = started(1000, 900, dir.path());
    let schedule = fx.schedule();
    assert_eq!(schedule.switch_target(899), Some(1), "S(1) = 899 is an Unzen height");
    assert_eq!(schedule.switch_target(1799), Some(2));

    let (env, updates) = run(&mut app).await;
    assert_eq!(app.state().unwrap().last_height, 1001);
    assert!(env.anchor.is_some() && env.committee.is_none() && updates.is_empty());
    assert_eq!(active(app.state().unwrap(), 1001), 0);

    // D(2) = 1798 commits anchor 100, which sees a registry checkpoint at 99 with a third entry.
    fx.advance_l1(app.l1(), 100, &fx.inbox_with(1790), &registry(&fx, &[(99, 3)]));
    let anchor = fx.anchor_state(app.l1(), 100);
    jump(&mut app, 1798, anchor, &[]);
    let (env, updates) = run(&mut app).await;
    let witness = env.committee.expect("S(2) carries committee 2's witness");
    assert_eq!((witness.record.target_epoch, witness.record.cutoff_l1_block), (2, 100));
    assert_eq!(updates.len(), 1, "the third entry joins at H(2)");
    let state = app.state().unwrap();
    assert_eq!(state.committees.keys().copied().collect::<Vec<_>>(), [0, 2]);
    assert_eq!((active(state, 1800), active(state, 1801)), (0, 2));

    let (_, updates) = run(&mut app).await;
    assert!(updates.is_empty());
    assert_eq!(app.state().unwrap().last_height, 1800, "S(2) + 1 is signed by committee 0");
    let (_, updates) = run(&mut app).await;
    assert!(updates.is_empty());
    assert_eq!(active(app.state().unwrap(), 1801), 2);
    assert_eq!(app.state().unwrap().committee_at(1801).unwrap().members.len(), 3);

    // S(3) = 2699 rotates to committee 3 (four entries); committee 0 is now obsolete.
    fx.advance_l1(app.l1(), 200, &fx.inbox_with(2690), &registry(&fx, &[(99, 3), (199, 4)]));
    let anchor = fx.anchor_state(app.l1(), 200);
    jump(&mut app, 2698, anchor, &[]);
    let (env, updates) = run(&mut app).await;
    assert_eq!(env.committee.expect("S(3) carries a witness").record.target_epoch, 3);
    assert_eq!(updates.len(), 1);
    let state = app.state().unwrap();
    assert_eq!(state.committees.keys().copied().collect::<Vec<_>>(), [2, 3]);
    assert_eq!((active(state, 2700), active(state, 2701)), (2, 3));
    run(&mut app).await;
    run(&mut app).await;
    assert_eq!(app.state().unwrap().last_height, 2701);
}

/// Vector 9.g (COMM-4.3-9, COMM-4.3-11, CONS-3.4-7): S = 898, L = 900, so S + 1 = 899 = S(1).
/// The generation's first block carries the committee witness for epoch 1, and as D(1) = 898 = S
/// its snapshot is the origin record's `l1BlockNumber` L1_0, not the block's own later anchor,
/// under whose root it is proven. Committee 0 signs 900 = S(1) + 1 and committee 1 signs from
/// H(1) = 901.
#[tokio::test]
async fn vector_9g_first_block_at_s_1_derives_committee_one_at_l1_0() {
    let dir = tempfile::tempdir().unwrap();
    let (fx, mut app) = started(898, 900, dir.path());
    assert_eq!(fx.schedule().switch_target(899), Some(1));
    // The own L1 finalized 100, where a later checkpoint (block 99) holds three entries.
    fx.advance_l1(app.l1(), 100, &fx.inbox_with(898), &registry(&fx, &[(99, 3)]));

    let (env, updates) = run(&mut app).await;
    assert_eq!(env.anchor.as_ref().map(|w| w.l1_header.number()), Some(100));
    let witness = env.committee.expect("S + 1 = S(1) carries committee 1's witness");
    assert_eq!(witness.record.target_epoch, 1);
    assert_eq!(witness.record.cutoff_l1_block, fx.genesis.l1_0, "D(1) = S: the origin's L1_0");
    assert_eq!(witness.entries, sample_entries(2), "the genesis checkpoint, not block 99's");
    assert!(updates.is_empty(), "committee 1 keeps committee 0's keys and powers");
    let state = app.state().unwrap();
    assert_eq!(state.committees.keys().copied().collect::<Vec<_>>(), [0, 1]);
    assert_eq!((active(state, 900), active(state, 901)), (0, 1));

    run(&mut app).await;
    run(&mut app).await;
    let state = app.state().unwrap();
    assert_eq!(state.last_height, 901);
    assert_eq!(state.committee_at(901).unwrap().record.cutoff_l1_block, fx.genesis.l1_0);
}
