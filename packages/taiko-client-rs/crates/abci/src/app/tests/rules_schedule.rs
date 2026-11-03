//! Schedule enforcement in all ABCI paths, including inherited anchors and cold replay.

use alloy_primitives::U256;

use super::{
    proposal::{
        bft_time, finalize, finalize_req, hand_envelope, judge, jump, mid_epoch, next_height,
        prepare, prepare_req,
    },
    *,
};
use crate::test_utils::{TestState, anchor_witness_in, filler_accounts, inbox_account, l1_header};

/// Installs real proofs of slot 293 at the next finalized anchor.
fn install_schedule(
    fx: &Fixture,
    app: &App<MockL1, MockEngine>,
    word: U256,
) -> crate::AnchorWitness {
    let mut accounts = filler_accounts();
    let mut account = inbox_account(fx.params.inbox, &fx.inbox);
    account.4.push((crate::l1::layout::inbox::slot(293), word));
    accounts.push(account);
    let state = TestState::new(accounts);
    let header = l1_header(66, Fixture::l1_timestamp(66));
    app.l1().insert_block(header.clone(), state.clone());
    app.l1().set_finalized(66);
    anchor_witness_in(&state, fx.params.inbox, header)
}

#[tokio::test]
async fn prepare_returns_placeholder_for_unknown_rules_and_planned_stop() {
    for (word, label) in [
        (U256::from(1) << 48, "unsupported_ruleset"),
        ((U256::from(1) << 144) | (U256::from(6) << 192), "planned_stop"),
    ] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = mid_epoch(&fx, dir.path(), 6).await;
        install_schedule(&fx, &app, word);
        let req = prepare_req(next_height(&app), bft_time(&app));
        assert!(prepare(&mut app, req).await.is_empty());
        assert_eq!(app.halt.as_deref(), Some(label));
    }
}

#[tokio::test]
async fn inherited_schedule_is_enforced_and_unknown_rules_pause_cold_finalize() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 6).await;
    let witness = install_schedule(&fx, &app, U256::from(1) << 48);
    let anchor = crate::l1::verify_anchor_witness(&witness, fx.params.inbox).unwrap();
    jump(&mut app, 6, anchor, &[]);
    let env = hand_envelope(&app, None, None);
    let (verdict, req) = judge(&mut app, &env).await;
    assert_eq!(verdict, response::ProcessProposal::Reject);
    assert_eq!(app.halt.as_deref(), Some("unsupported_ruleset"));
    assert!(
        tokio::time::timeout(
            std::time::Duration::from_millis(20),
            finalize(&mut app, finalize_req(&req))
        )
        .await
        .is_err()
    );
    assert!(app.pending.is_none());
    assert!(!dir.path().join("fatal-evidence.txt").exists());
}

#[tokio::test]
async fn decided_planned_stop_violation_is_a_safety_halt() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 6).await;
    let witness = install_schedule(&fx, &app, (U256::from(1) << 144) | (U256::from(6) << 192));
    let env = hand_envelope(&app, Some(witness), None);
    let (_, req) = judge(&mut app, &env).await;
    assert!(
        matches!(finalize(&mut app, finalize_req(&req)).await, Err(AbciError::SafetyHalt(message)) if message.contains("planned stop"))
    );
    assert!(app.pending.is_none());
}
