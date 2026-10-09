//! `PrepareProposal` (spec §5.3): anchor choice, and every reason it proposes nothing.

use std::time::Duration;

use super::{
    proposal::{bft_time, jump, mid_epoch, next_height, prepare, prepare_req, propose},
    *,
};
use crate::{
    engine::EngineError,
    l1::L1Error,
    rules::decode_extra_data,
    test_utils::{GenesisSpec, L1Call, simple_block},
};

/// Prepares the next height of `app`, expects no transactions and returns the halt label.
async fn refused(app: &mut App<MockL1, MockEngine>) -> String {
    let txs = prepare(app, prepare_req(next_height(app), bft_time(app))).await;
    assert!(txs.is_empty(), "no proposal expected");
    app.halt.clone().expect("a refused proposal records its label")
}

#[tokio::test]
async fn l1_failure_proposes_nothing() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    app.l1().state().fail = Some(L1Error::Rpc("down".into()));
    assert_eq!(refused(&mut app).await, "l1_error");
    assert!(app.engine().calls().iter().all(|c| !matches!(c, EngineCall::BuildBlock { .. })));

    // Recovery: the next successful build clears the halt reason.
    app.l1().state().fail = None;
    propose(&mut app).await;
    assert_eq!(app.halt, None);
}

#[tokio::test(start_paused = true)]
async fn slow_l1_proposes_nothing() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    app.l1().state().delay = Some(app.opts.l1_timeout + Duration::from_secs(1));
    assert_eq!(refused(&mut app).await, "timeout");
}

/// One overall deadline bounds `PrepareProposal` (below CometBFT's `timeout_propose`): reads
/// that each stay within their own deadline still propose nothing once they add up past it.
#[tokio::test(start_paused = true)]
async fn prepare_proposes_nothing_past_its_overall_deadline() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    // The anchor moves, so the proposer reads the finalized number, a header and a proof.
    let inbox = fx.inbox_with(fx.activation.genesis_height + 3, &[]);
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    let overall = app.opts.prepare_timeout;
    assert_eq!(overall, Duration::from_secs(2), "the default overall deadline");
    let per_read = overall / 2 + Duration::from_millis(1);
    assert!(per_read < app.opts.l1_timeout, "each read alone is in time");
    app.l1().state().delay = Some(per_read);

    let start = tokio::time::Instant::now();
    assert_eq!(refused(&mut app).await, "timeout");
    assert_eq!(start.elapsed(), overall, "answered at the overall deadline");
    assert!(app.engine().calls().iter().all(|c| !matches!(c, EngineCall::BuildBlock { .. })));

    // In time, the same height builds.
    app.l1().state().delay = None;
    assert!(propose(&mut app).await.anchor.is_some());
    assert_eq!(app.halt, None);
}

#[tokio::test]
async fn envelope_above_max_tx_bytes_is_not_proposed() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let mut req = prepare_req(next_height(&app), bft_time(&app));
    req.max_tx_bytes = 100;
    assert!(prepare(&mut app, req).await.is_empty());
    assert_eq!(app.halt.as_deref(), Some("envelope_too_large"));

    // Exactly the envelope's size fits.
    let len = propose(&mut app).await.encode().len();
    let mut req = prepare_req(next_height(&app), bft_time(&app));
    req.max_tx_bytes = i64::try_from(len).unwrap();
    assert_eq!(prepare(&mut app, req).await.len(), 1);
}

#[tokio::test]
async fn engine_failures_propose_nothing() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    app.engine().state().build_script.push_back(Err(EngineError::Rpc("no payload".into())));
    assert_eq!(refused(&mut app).await, "engine_error");

    // An EL that builds another timestamp than derived fails the self-check.
    let built = propose(&mut app).await.block;
    let mut wrong = built.clone();
    wrong.header.timestamp += 1;
    app.engine().state().build_script.push_back(Ok(wrong));
    assert_eq!(refused(&mut app).await, "built_header_mismatch");
}

#[tokio::test(start_paused = true)]
async fn slow_engine_proposes_nothing() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    app.engine().state().delay = Some(app.opts.engine_timeout + Duration::from_secs(1));
    assert_eq!(refused(&mut app).await, "timeout");
}

#[tokio::test]
async fn proposer_anchors_at_finalized_minus_the_extra_depth() {
    let mut spec = GenesisSpec::new(1);
    spec.params.l1_finality_extra_depth = 2;
    let fx = Fixture::build(spec);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    assert_eq!(app.l1().state().finalized, fx.activation.l1_0 + 2);
    let header = fx.advance_l1(app.l1(), 70, &fx.inbox, &fx.registry);
    assert_eq!(app.l1().state().finalized, 72);

    let env = propose(&mut app).await;
    assert_eq!(env.anchor.as_ref().map(|w| &w.l1_header), Some(&header));
    let (resp, _) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
}

#[tokio::test]
async fn proposer_never_anchors_below_the_parent() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    fx.plant_l1_block(app.l1(), 66, &fx.inbox, &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 66, None);
    jump(&mut app, fx.activation.genesis_height + 5, anchor, &[]);
    assert_eq!(app.l1().state().finalized, fx.activation.l1_0, "own L1 lags behind");

    let env = propose(&mut app).await;
    assert!(env.anchor.is_none());
    assert_eq!(decode_extra_data(&env.block.header.extra_data).unwrap().2, 66);
    assert_eq!(
        app.l1().calls().last(),
        Some(&L1Call::Finalized),
        "only the finalized number is read"
    );
}

#[tokio::test]
async fn failing_pre_checks_propose_nothing() {
    let fx = Fixture::genesis(1);

    // Back-pressure: the checkpoint is a full cap behind the next height.
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), fx.params.unsettled_cap()).await;
    assert_eq!(refused(&mut app).await, "back_pressure");
    assert!(app.engine().calls().iter().all(|c| !matches!(c, EngineCall::BuildBlock { .. })));

    // The finalized Inbox is not (or no longer) active.
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let mut inbox = fx.inbox.clone();
    inbox.migration_state = 2;
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    assert_eq!(refused(&mut app).await, "inbox_not_active");

    // Epoch 1 opens on L1 only at L1_first(1) = L1_0 + EPOCH_LEN_L1.
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h_first = app.state().unwrap().schedule.h_first(1);
    let anchor = fx.anchor_state(app.l1(), fx.activation.l1_0, None);
    jump(&mut app, h_first - 1, anchor, &[(1, fx.committee(1))]);
    assert_eq!(refused(&mut app).await, "epoch_not_open_on_l1");
}

/// Generation superseded on L1: the proposer stops proposing (and reports it), for good.
#[tokio::test]
async fn superseded_generation_stops_proposing() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let mut inbox = fx.inbox.clone();
    inbox.recovery_generation = 1;
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);

    assert_eq!(refused(&mut app).await, "superseded");
    assert!(app.superseded);
    assert!(app.status().unwrap().superseded);

    app.l1().state().calls.clear();
    assert_eq!(refused(&mut app).await, "superseded");
    assert!(app.l1().calls().is_empty(), "a superseded chain does not even read L1");
}

/// The default mock build is what an honest EL returns for the derived attributes.
#[tokio::test]
async fn the_built_block_is_the_envelope_block() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let env = propose(&mut app).await;
    let calls = app.engine().calls();
    let Some(EngineCall::BuildBlock { parent, attrs }) = calls.last() else {
        panic!("the last engine call is the build: {calls:?}");
    };
    assert_eq!(*parent, app.state().unwrap().parent.hash);
    assert_eq!(attrs.block_metadata.tx_list, None, "the EL selects from its own txpool");
    assert_eq!(simple_block(*parent, attrs), env.block);
}
