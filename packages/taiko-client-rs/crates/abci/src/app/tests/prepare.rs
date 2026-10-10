//! `PrepareProposal`: anchor choice, and every reason it proposes nothing.

use std::{path::Path, time::Duration};

use super::{
    proposal::{bft_time, jump, mid_epoch, next_height, prepare, prepare_req, propose},
    *,
};
use crate::{
    engine::{EngineError, PayloadVerdict},
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
    app.engine().state().build_script.push_back(Err(EngineError::Transport("no payload".into())));
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

/// An own L1 node answering the header request for the anchor block with another block's header
/// gets nothing proposed on it.
#[tokio::test]
async fn a_header_of_another_l1_block_is_not_proposed_on() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let header = fx.advance_l1(app.l1(), 66, &fx.inbox_with(1_003, &[]), &fx.registry);
    let other = crate::test_utils::edit_l1_header(&header, |h| h.number = 67);
    app.l1().state().headers.insert(66, other);

    assert_eq!(refused(&mut app).await, "l1_error");
    assert!(app.engine().calls().iter().all(|c| !matches!(c, EngineCall::BuildBlock { .. })));
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

/// The L1 reads of the staking registry `app` made so far.
fn registry_reads(app: &App<MockL1, MockEngine>) -> usize {
    let registry = app.params.registry;
    app.l1()
        .calls()
        .iter()
        .filter(|c| {
            matches!(c, L1Call::StorageAt { address, .. } | L1Call::AccountWitness { address, .. }
                if *address == registry)
        })
        .count()
}

/// An app whose next height is `h_first(1)`, anchored at the finalized L1 block 70 where the
/// checkpoint is within the cap: the proposer there discovers the committee of epoch 2.
async fn before_epoch_start(fx: &Fixture, dir: &Path) -> App<MockL1, MockEngine> {
    let mut app = initialized(fx, dir).await;
    let h_e = app.state().unwrap().schedule.h_first(1);
    fx.advance_l1(app.l1(), 70, &fx.inbox_with(h_e - 6, &[]), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 70, None);
    jump(&mut app, h_e - 1, anchor, &[(1, fx.committee(1))]);
    app
}

/// Repeated rounds at `h_first(e)` reuse the committee witness the first round discovered: the
/// parent's anchor and the target epoch are the same, so is the witness. `Commit` drops it.
#[tokio::test]
async fn a_second_round_at_an_epoch_start_reuses_the_committee_witness() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_epoch_start(&fx, dir.path()).await;

    // Round 0: the committee is discovered, then the EL fails to build.
    app.engine().state().build_script.push_back(Err(EngineError::Transport("down".into())));
    assert_eq!(refused(&mut app).await, "engine_error");
    assert!(registry_reads(&app) > 0, "round 0 discovers the committee");

    // Round 1 at the same height: no registry read at all, and the same witness.
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert_eq!(registry_reads(&app), 0, "{:?}", app.l1().calls());
    let witness = crate::l1::build_committee_witness(
        app.l1(),
        &app.params,
        &app.state().unwrap().schedule,
        70,
        2,
    )
    .await
    .expect("the witness builds");
    assert_eq!(env.committee, Some(witness));

    let (resp, req) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    super::proposal::decide(&mut app, &req).await;
    assert!(app.committee_cache.lock().unwrap().is_none(), "Commit drops the cached witness");
}

/// CometBFT rotates proposers round by round: a node that judged another proposer's block at
/// `h_first(e)` keeps its verified committee witness, so its own proposal at that height (a later
/// round) needs no discovery. The witness is proven against the committed parent's anchor alone,
/// so it is kept even when a node-local check (here the EL) refuses that block.
#[tokio::test]
async fn a_committee_witness_judged_at_an_epoch_start_is_reused_by_the_next_proposer() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut a = before_epoch_start(&fx, dir.path()).await;
    let env = propose(&mut a).await;
    let witness = env.committee.clone().expect("h_first(1) carries a committee witness");

    // B accepts A's round-0 block, the round fails anyway, and B proposes in round 1.
    let dir = tempfile::tempdir().unwrap();
    let mut b = before_epoch_start(&fx, dir.path()).await;
    let (resp, _) = super::proposal::judge(&mut b, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", b.halt);
    b.l1().state().calls.clear();
    let own = propose(&mut b).await;
    assert_eq!(registry_reads(&b), 0, "{:?}", b.l1().calls());
    assert_eq!(own.committee.as_ref(), Some(&witness));

    // C's EL refuses A's block (syncing); C still proposes without discovery.
    let dir = tempfile::tempdir().unwrap();
    let mut c = before_epoch_start(&fx, dir.path()).await;
    c.engine().state().new_payload_script.push_back(Ok(PayloadVerdict::Syncing));
    let (resp, _) = super::proposal::judge(&mut c, &env).await;
    assert_eq!(resp, response::ProcessProposal::Reject);
    assert_eq!(c.halt.as_deref(), Some("payload_syncing"));
    c.l1().state().calls.clear();
    let own = propose(&mut c).await;
    assert_eq!(registry_reads(&c), 0, "{:?}", c.l1().calls());
    assert_eq!(own.committee, Some(witness));
}

/// `PrepareProposal`'s deadline does not grow with the round, so a discovery cut short by it
/// keeps the registry reads it finished: the next attempt at the height resumes from them.
#[tokio::test(start_paused = true)]
async fn a_discovery_cut_short_by_the_deadline_resumes_where_it_stopped() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_epoch_start(&fx, dir.path()).await;
    let registry = fx.params.registry;
    let storage_reads = |app: &App<MockL1, MockEngine>| -> Vec<L1Call> {
        let calls = app.l1().calls();
        calls.into_iter().filter(|c| matches!(c, L1Call::StorageAt { .. })).collect()
    };

    // 600 ms per read: the finalized number, `checkpoints.length` and the one checkpoint head
    // answer by 1.8 s; the entries read is still pending at the 2 s deadline.
    app.l1().state().delay = Some(Duration::from_millis(600));
    assert_eq!(refused(&mut app).await, "timeout");
    let finished = storage_reads(&app);
    assert_eq!(finished.len(), 2, "{:?}", app.l1().calls());

    // The next round reads only what is still missing: the entries and the snapshot proof.
    app.l1().state().delay = None;
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert_eq!(storage_reads(&app), [], "the finished reads are not repeated");
    assert_eq!(registry_reads(&app), 2, "{:?}", app.l1().calls());
    let witness = crate::l1::build_committee_witness(
        app.l1(),
        &app.params,
        &app.state().unwrap().schedule,
        70,
        2,
    )
    .await
    .expect("the witness builds");
    assert_eq!(env.committee, Some(witness));
    assert!(
        finished
            .iter()
            .all(|c| matches!(c, L1Call::StorageAt { address, .. } if *address == registry))
    );
}

/// A cached witness is only reused for the same parent anchor and target epoch.
#[tokio::test]
async fn a_cached_committee_witness_of_another_parent_anchor_is_not_reused() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_epoch_start(&fx, dir.path()).await;
    app.engine().state().build_script.push_back(Err(EngineError::Transport("down".into())));
    assert_eq!(refused(&mut app).await, "engine_error");

    // The committed parent moves to anchor 72 (e.g. after a state rewrite): rediscovered there.
    let h_e = app.state().unwrap().schedule.h_first(1);
    fx.advance_l1(app.l1(), 72, &fx.inbox_with(h_e - 6, &[]), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 72, None);
    jump(&mut app, h_e - 1, anchor, &[]);
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert!(registry_reads(&app) > 0, "rediscovered at the new parent anchor");
    assert_eq!(env.committee.expect("h_first(1) carries a committee").record.cutoff_l1_block, 72);
}

/// At `h_first(e)` the cheap candidate checks run before the committee discovery: a block that
/// cannot be proposed anyway (back-pressure, anchor progress, a superseded generation) costs no
/// registry read.
#[tokio::test]
async fn failing_pre_checks_skip_the_committee_discovery() {
    let fx = Fixture::genesis(3);

    // Back-pressure: the checkpoint is still at B*, more than the cap below h_first(1).
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h_e = app.state().unwrap().schedule.h_first(1);
    fx.advance_l1(app.l1(), 70, &fx.inbox, &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 70, None);
    jump(&mut app, h_e - 1, anchor, &[(1, fx.committee(1))]);
    app.l1().state().calls.clear();
    assert_eq!(refused(&mut app).await, "back_pressure");
    assert_eq!(registry_reads(&app), 0, "back-pressure: {:?}", app.l1().calls());

    // Anchor progress: epoch 1 is not open on L1 at the genesis anchor.
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let anchor = fx.anchor_state(app.l1(), fx.activation.l1_0, None);
    jump(&mut app, h_e - 1, anchor, &[(1, fx.committee(1))]);
    app.l1().state().calls.clear();
    assert_eq!(refused(&mut app).await, "epoch_not_open_on_l1");
    assert_eq!(registry_reads(&app), 0, "anchor progress: {:?}", app.l1().calls());

    // Generation: the new anchor proves a later recovery generation.
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let mut inbox = fx.inbox_with(h_e - 6, &[]);
    inbox.recovery_generation = 1;
    fx.advance_l1(app.l1(), 70, &inbox, &fx.registry);
    let anchor = fx.anchor_state(app.l1(), fx.activation.l1_0, None);
    jump(&mut app, h_e - 1, anchor, &[(1, fx.committee(1))]);
    app.l1().state().calls.clear();
    assert_eq!(refused(&mut app).await, "superseded");
    assert_eq!(registry_reads(&app), 0, "generation: {:?}", app.l1().calls());
}
