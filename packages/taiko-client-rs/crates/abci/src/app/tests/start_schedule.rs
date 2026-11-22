//! A nonzero Etna start S: the genesis set signs from S + 1 on, whatever global epoch S lies in,
//! and keeps signing through the heights the global schedule called switches. Every height runs
//! the real `PrepareProposal`, `ProcessProposal`, `FinalizeBlock` and `Commit`; [`jump`] only
//! skips plain heights.

use super::{
    proposal::{decide, judge, jump, propose},
    *,
};
use crate::test_utils::GenesisSpec;

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

/// S = 1000, L = 900: the genesis set signs 1001 and every height around what the global
/// schedule names S(2) = 1799 and H(2) = 1801, with no validator update anywhere.
#[tokio::test]
async fn a_nonzero_start_keeps_the_genesis_set_signing() {
    let dir = tempfile::tempdir().unwrap();
    let (fx, mut app) = started(1000, 900, dir.path());
    let genesis = app.state().unwrap().val_state.current.members();

    let (env, updates) = run(&mut app).await;
    assert_eq!(app.state().unwrap().last_height, 1001);
    assert!(env.anchor.is_some() && updates.is_empty());

    fx.advance_l1(app.l1(), 100, &fx.inbox_with(1790), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 100);
    jump(&mut app, 1798, anchor);
    for height in 1799..=1802 {
        let (_, updates) = run(&mut app).await;
        let state = app.state().unwrap();
        assert_eq!(state.last_height, height);
        assert!(updates.is_empty(), "height {height}");
        assert_eq!(state.val_state.current.members(), genesis, "height {height}");
    }
}
