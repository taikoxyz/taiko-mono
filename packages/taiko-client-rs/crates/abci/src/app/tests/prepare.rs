//! `PrepareProposal`: anchor choice, and every reason it proposes nothing.

use std::{path::Path, time::Duration};

use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{B256, Bytes};

use super::{
    proposal::{
        bft_time, decide, incompressible, judge, jump, mid_epoch, next_height, prepare,
        prepare_req, propose, set_anchor_age, step,
    },
    *,
};
use crate::{
    engine::{EngineError, PayloadVerdict},
    envelope::EtnaEnvelope,
    l1::L1Error,
    rules::decode_extra_data,
    test_utils::{GenesisSpec, L1Call, sample_transactions, simple_block},
};

/// Prepares the next height of `app`, expects no transactions and returns the halt label.
async fn refused(app: &mut App<MockL1, MockEngine>) -> String {
    let txs = prepare(app, prepare_req(next_height(app), bft_time(app))).await;
    assert!(txs.is_empty(), "no proposal expected");
    app.halt.clone().expect("a refused proposal records its label")
}

/// Whether `app` ever asked its EL to build a block.
fn built_any(app: &App<MockL1, MockEngine>) -> bool {
    app.engine().calls().iter().any(|c| matches!(c, EngineCall::BuildBlock { .. }))
}

/// The transaction list of the last block `app` asked its EL to build.
fn built_tx_list(app: &App<MockL1, MockEngine>) -> Option<Bytes> {
    let calls = app.engine().calls();
    let Some(EngineCall::BuildBlock { attrs, .. }) =
        calls.iter().rfind(|c| matches!(c, EngineCall::BuildBlock { .. }))
    else {
        panic!("no build: {calls:?}");
    };
    attrs.block_metadata.tx_list.clone()
}

/// Accepts `env` as the next height of `app`, then finalizes and commits it.
async fn accept_and_commit(app: &mut App<MockL1, MockEngine>, env: &EtnaEnvelope) {
    let (resp, req) = judge(app, env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    decide(app, &req).await;
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
    let inbox = fx.inbox_with(fx.genesis.genesis_height + 3);
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

/// An EL that builds a block whose compressed envelope cannot fit one landing gets nothing
/// proposed, though the envelope fits `max_tx_bytes`; a zero-heavy block several times larger
/// is proposed.
#[tokio::test]
async fn prepare_does_not_propose_an_oversized_block() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let built = propose(&mut app).await.block;

    let mut random = built.clone();
    random.transactions.push(incompressible(800_000));
    app.engine().state().build_script.push_back(Ok(random));
    assert_eq!(refused(&mut app).await, "landing_capacity");

    let mut zeros = built;
    zeros.transactions.push(vec![0u8; 5_000_000].into());
    app.engine().state().build_script.push_back(Ok(zeros.clone()));
    assert_eq!(propose(&mut app).await.block, zeros);
    assert_eq!(app.halt, None);
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
    assert_eq!(app.l1().state().finalized, fx.genesis.l1_0 + 2);
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
    let anchor = fx.anchor_state(app.l1(), 66);
    jump(&mut app, fx.genesis.genesis_height + 5, anchor, &[]);
    assert_eq!(app.l1().state().finalized, fx.genesis.l1_0, "own L1 lags behind");

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
    inbox.status = 2;
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    assert_eq!(refused(&mut app).await, "inbox_not_active");
}

/// An epoch boundary places no floor on the anchor: when the own L1 has finalized nothing newer,
/// the first block of epoch 1 keeps its parent's anchor and is accepted.
#[tokio::test]
async fn the_first_block_of_an_epoch_keeps_the_parent_anchor() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h_first = app.state().unwrap().schedule().h_first(1);
    fx.plant_l1_block(app.l1(), 66, &fx.inbox_with(h_first - 6), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 66);
    jump(&mut app, h_first - 1, anchor, &[(1, fx.committee(1))]);
    assert_eq!(app.l1().state().finalized, fx.genesis.l1_0, "own L1 lags behind");

    let env = propose(&mut app).await;
    assert_eq!(env.block.header.number, h_first);
    assert!(env.anchor.is_none());
    assert_eq!(decode_extra_data(&env.block.header.extra_data).unwrap().2, 66);
    let (resp, _) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
}

/// A proposer whose newest finalized anchor is more than `maxAnchorAge` older than the block
/// proposes nothing; once L1 finalizes a fresh enough block, it anchors there and proposes.
#[tokio::test]
async fn prepare_halts_when_finalized_anchor_is_too_old() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    set_anchor_age(&mut app, fx.genesis.max_anchor_age + 1);
    assert_eq!(refused(&mut app).await, "anchor_too_old");
    assert!(app.engine().calls().iter().all(|c| !matches!(c, EngineCall::BuildBlock { .. })));

    // L1 finality resumes: block 66 is 24 s newer than the stale anchor 64.
    let header = fx.advance_l1(app.l1(), 66, &fx.inbox, &fx.registry);
    let env = propose(&mut app).await;
    assert_eq!(env.anchor.as_ref().map(|w| &w.l1_header), Some(&header));
    assert_eq!(app.halt, None);
}

/// An own L1 node answering the header request for the anchor block with another block's header
/// gets nothing proposed on it.
#[tokio::test]
async fn a_header_of_another_l1_block_is_not_proposed_on() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let header = fx.advance_l1(app.l1(), 66, &fx.inbox_with(1_003), &fx.registry);
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

/// An app whose next height is switch 2, anchored at the finalized L1 block 70 where the
/// checkpoint is within the cap: the proposer there discovers the committee of epoch 2.
async fn before_switch(fx: &Fixture, dir: &Path) -> App<MockL1, MockEngine> {
    let mut app = initialized(fx, dir).await;
    let h_e = app.state().unwrap().schedule().h_first(2) - 2;
    fx.advance_l1(app.l1(), 70, &fx.inbox_with(h_e - 6), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 70);
    jump(&mut app, h_e - 1, anchor, &[(1, fx.committee(1))]);
    app
}

/// Repeated rounds at `H(t)-2` reuse the committee witness the first round discovered: the
/// parent's anchor and the target epoch are the same, so is the witness. `Commit` drops it.
#[tokio::test]
async fn a_second_round_at_a_switch_reuses_the_committee_witness() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_switch(&fx, dir.path()).await;

    // Round 0: the committee is discovered, then the EL fails to build.
    app.engine().state().build_script.push_back(Err(EngineError::Transport("down".into())));
    assert_eq!(refused(&mut app).await, "engine_error");
    assert!(registry_reads(&app) > 0, "round 0 discovers the committee");

    // Round 1 at the same height: no registry read at all, and the same witness.
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert_eq!(registry_reads(&app), 0, "{:?}", app.l1().calls());
    let witness = crate::l1::build_committee_witness(app.l1(), &app.params, 70, 2)
        .await
        .expect("the witness builds");
    assert_eq!(env.committee, Some(witness));

    let (resp, req) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    super::proposal::decide(&mut app, &req).await;
    assert!(app.committee_cache.lock().unwrap().is_none(), "Commit drops the cached witness");
}

/// The fixed switch snapshot remains available after restart even when the primary L1 has
/// pruned every historical state: the proposal still carries the independently verified witness.
#[tokio::test]
async fn verified_switch_witness_survives_restart_without_historical_l1_state() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_switch(&fx, dir.path()).await;
    app.store.save(app.state().unwrap()).expect("persists the switch parent");
    let before = propose(&mut app).await;
    app.l1().state().states.clear();
    app.l1().state().calls.clear();
    let App { l1, engine, params, store, opts, .. } = app;
    let mut restarted =
        App::new(Arc::try_unwrap(l1).expect("sole L1 owner"), engine, params, store, opts).unwrap();
    let height = next_height(&restarted);
    let time = bft_time(&restarted);
    let txs = prepare(&mut restarted, prepare_req(height, time)).await;
    assert_eq!(txs.len(), 1, "restart must propose; halt = {:?}", restarted.halt);
    let after = EtnaEnvelope::decode(&txs[0]).unwrap();
    assert_eq!(after.committee, before.committee);
    assert_eq!(registry_reads(&restarted), 0, "durable verified witness needs no state RPC");
}

/// A peer's independently valid switch witness is persisted even when local execution refuses
/// its block, so restart can still propose without the fixed anchor's pruned state.
#[tokio::test]
async fn peer_switch_witness_survives_restart_after_local_execution_refusal() {
    let fx = Fixture::genesis(3);
    let a_dir = tempfile::tempdir().unwrap();
    let mut proposer = before_switch(&fx, a_dir.path()).await;
    let env = propose(&mut proposer).await;
    let b_dir = tempfile::tempdir().unwrap();
    let mut node = before_switch(&fx, b_dir.path()).await;
    node.store.save(node.state().unwrap()).unwrap();
    node.engine().state().new_payload_script.push_back(Ok(PayloadVerdict::Syncing));
    assert_eq!(judge(&mut node, &env).await.0, response::ProcessProposal::Reject);
    node.l1().state().states.clear();
    // The judge started a background switch-witness discovery; stop it to take the sole L1.
    *node.committee_prefetch() = None;
    tokio::task::yield_now().await;
    let App { l1, engine, params, store, opts, .. } = node;
    let mut restarted =
        App::new(Arc::try_unwrap(l1).expect("sole L1 owner"), engine, params, store, opts).unwrap();
    assert_eq!(propose(&mut restarted).await.committee, env.committee);
}

/// A validator at `D(t)` discovers, verifies and persists the switch witness in the background
/// as soon as it handles any round, an empty proposal included, before a proposal needs it.
/// Once its L1 has pruned the parent anchor's state (after a stall longer than its proof
/// window), it still proposes `S(t)` from that witness, without an archive.
#[tokio::test]
async fn the_switch_witness_is_prefetched_before_the_parent_anchor_state_is_pruned() {
    use crate::store::COMMITTEE_WITNESS_FILE;
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_switch(&fx, dir.path()).await;
    let req = super::proposal::process_req(next_height(&app), bft_time(&app), vec![]);
    assert_eq!(super::proposal::process(&mut app, req).await, response::ProcessProposal::Reject);
    let state = app.state().unwrap().clone();
    let target = state.schedule().switch_target(state.last_height + 1).unwrap();
    let witness = app.prefetched_committee_witness(&state, target).await;
    assert!(witness.is_some(), "the background discovery verified the witness");
    app.adopt_committee_prefetch(&state);
    assert!(dir.path().join(COMMITTEE_WITNESS_FILE).exists(), "and persisted it");

    app.l1().state().states.clear();
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert_eq!(env.committee, witness);
    assert_eq!(registry_reads(&app), 0, "{:?}", app.l1().calls());
}

/// A live `Commit` of `D(t)` starts the switch-witness discovery on its own, before any round at
/// `S(t)` (which an anchor freshness stall could keep from ever reaching it).
#[tokio::test]
async fn committing_the_derivation_parent_prefetches_the_switch_witness() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h_e = app.state().unwrap().schedule().h_first(2) - 2;
    fx.advance_l1(app.l1(), 70, &fx.inbox_with(h_e - 6), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 70);
    jump(&mut app, h_e - 2, anchor, &[(1, fx.committee(1))]);
    step(&mut app).await;
    let state = app.state().unwrap().clone();
    assert_eq!(state.last_height, h_e - 1, "D(t) is committed");
    let target = state.schedule().switch_target(state.last_height + 1).unwrap();
    let witness = app.prefetched_committee_witness(&state, target).await;
    assert!(witness.is_some(), "Commit started the discovery");

    app.l1().state().states.clear();
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert_eq!(env.committee, witness);
    assert_eq!(registry_reads(&app), 0, "{:?}", app.l1().calls());
}

/// A committed state at `D(t)-3` (`t = 2`) anchored at L1 block 68 while L1 has finalized 70,
/// both with their last checkpoint at `last_checkpoint`: the next block adopts anchor 70.
async fn before_anchor_adoption(
    fx: &Fixture,
    dir: &Path,
    last_checkpoint: u64,
) -> App<MockL1, MockEngine> {
    let mut app = initialized(fx, dir).await;
    let d_t = fx.schedule().derivation_parent_height(2).unwrap();
    fx.advance_l1(app.l1(), 68, &fx.inbox_with(last_checkpoint), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 68);
    jump(&mut app, d_t - 3, anchor, &[(1, fx.committee(1))]);
    fx.advance_l1(app.l1(), 70, &fx.inbox_with(last_checkpoint), &fx.registry);
    app
}

/// `D(t)` of the fixtures' switch `t = 2`.
fn d_2(fx: &Fixture) -> u64 {
    fx.schedule().derivation_parent_height(2).unwrap()
}

/// The live `Commit` of the block adopting an anchor discovers the switch witness under it right
/// away, while its L1 state is recent: when L1 finality then stalls, that anchor stays until
/// `D(t)` and the L1 node prunes its state, yet `S(t)` is still proposed without an archive.
#[tokio::test]
async fn committing_a_new_anchor_prefetches_the_switch_witness_it_may_have_to_prove() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_anchor_adoption(&fx, dir.path(), d_2(&fx) - 5).await;
    step(&mut app).await;
    let state = app.state().unwrap().clone();
    assert_eq!((state.last_height, state.anchor.number), (d_2(&fx) - 2, 70));
    let witness = app.prefetched_committee_witness(&state, 2).await;
    assert!(witness.is_some(), "Commit started the discovery two heights before D(t)");

    // L1 finality stalls at 70 and the L1 node prunes block 70's state.
    app.l1().state().states.clear();
    step(&mut app).await;
    step(&mut app).await;
    let state = app.state().unwrap();
    assert_eq!(
        (state.schedule().switch_target(state.last_height + 1), state.anchor.number),
        (Some(2), 70)
    );
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert_eq!(env.committee, witness);
    assert_eq!(registry_reads(&app), 0, "{:?}", app.l1().calls());
}

/// The witness discovered under a newly adopted anchor is saved, and a restart before `D(t)`
/// loads it: the restarted node proposes `S(t)` once its L1 has pruned that anchor's state.
#[tokio::test]
async fn a_switch_witness_prefetched_before_the_derivation_parent_survives_restart() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_anchor_adoption(&fx, dir.path(), d_2(&fx) - 5).await;
    step(&mut app).await;
    let state = app.state().unwrap().clone();
    let witness = app.prefetched_committee_witness(&state, 2).await;
    assert!(witness.is_some());
    app.adopt_committee_prefetch(&state);

    app.l1().state().states.clear();
    let App { l1, engine, params, store, opts, .. } = app;
    let mut restarted =
        App::new(Arc::try_unwrap(l1).expect("sole L1 owner"), engine, params, store, opts).unwrap();
    step(&mut restarted).await;
    step(&mut restarted).await;
    restarted.l1().state().calls.clear();
    assert_eq!(propose(&mut restarted).await.committee, witness);
    assert_eq!(registry_reads(&restarted), 0, "{:?}", restarted.l1().calls());
}

/// The registry storage-word and proof reads at L1 block `block` that `app` made so far.
fn registry_reads_at(app: &App<MockL1, MockEngine>, block: u64) -> (usize, usize) {
    let registry = app.params.registry;
    let calls = app.l1().calls();
    let count = |proof: bool| {
        calls
            .iter()
            .filter(|c| match c {
                L1Call::StorageAt { address, block: at, .. } => {
                    !proof && (*address, *at) == (registry, block)
                }
                L1Call::AccountWitness { address, block: at, .. } => {
                    proof && (*address, *at) == (registry, block)
                }
                _ => false,
            })
            .count()
    };
    (count(false), count(true))
}

/// A switch-witness discovery its L1 keeps failing (a rate limit, a proof window too short) is
/// restarted only once its backoff has passed since it failed: 2 s, doubling per failure up to
/// 60 s, however many rounds and commits come in between. Each restart resumes from the reads
/// already finished, and once the L1 serves proofs again the next attempt succeeds.
#[tokio::test(start_paused = true)]
async fn a_failing_switch_witness_prefetch_is_restarted_after_a_growing_backoff() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_anchor_adoption(&fx, dir.path(), d_2(&fx) - 5).await;
    let env = propose(&mut app).await;
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    // The L1 node refuses proofs from the commit of the block adopting anchor 70 on.
    app.l1().state().proof_fail = Some(L1Error::Rpc("429 Too Many Requests".into()));
    decide(&mut app, &req).await;
    let state = app.state().unwrap().clone();

    // `checkpoints.length` and the checkpoint head are read once; every attempt then fails on
    // the entries read.
    for (attempt, pause) in [2, 4, 8, 16, 32, 60, 60].into_iter().enumerate() {
        assert!(app.prefetched_committee_witness(&state, 2).await.is_none());
        assert_eq!(registry_reads_at(&app, 70), (2, attempt + 1));
        tokio::time::advance(Duration::from_secs(pause) - Duration::from_millis(1)).await;
        app.prefetch_committee_witness(&state);
        tokio::task::yield_now().await;
        assert_eq!(registry_reads_at(&app, 70), (2, attempt + 1), "within the {pause} s pause");
        tokio::time::advance(Duration::from_millis(1)).await;
        app.adopt_committee_prefetch(&state);
        tokio::task::yield_now().await;
        assert_eq!(
            registry_reads_at(&app, 70),
            (2, attempt + 1),
            "only a round or commit restarts"
        );
        app.prefetch_committee_witness(&state);
    }
    assert!(app.prefetched_committee_witness(&state, 2).await.is_none());
    app.l1().state().proof_fail = None;
    tokio::time::advance(Duration::from_secs(60)).await;
    app.prefetch_committee_witness(&state);
    assert!(app.prefetched_committee_witness(&state, 2).await.is_some());
    assert_eq!(registry_reads_at(&app, 70), (2, 10), "the entries and the snapshot proof");
}

/// Commits the block adopting anchor 70 at `D(t)-2` (see [`before_anchor_adoption`]), that block
/// `age` seconds after anchor 70 when given, and answers whether its `Commit` started the
/// switch-witness discovery.
async fn adopting_anchor_70_prefetches(last_checkpoint: u64, age: Option<u64>) -> bool {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_anchor_adoption(&fx, dir.path(), last_checkpoint).await;
    if let Some(age) = age {
        // The block is proposed at `bft_time`, two seconds after its parent.
        app.state.as_mut().unwrap().parent.timestamp = Fixture::l1_timestamp(70) + age - 2;
    }
    step(&mut app).await;
    assert_eq!(app.state().unwrap().anchor.number, 70);
    app.committee_prefetch().is_some()
}

/// Adopting an anchor discovers the switch witness exactly while `D(t)` can still carry that
/// anchor: within back-pressure of its last checkpoint and within its freshness, every height
/// adding at least a second. Otherwise a newer anchor comes first, and nothing is read.
#[tokio::test]
async fn adopting_an_anchor_prefetches_only_while_the_derivation_parent_can_carry_it() {
    let fx = Fixture::genesis(3);
    let (d_t, cap, max_age) = (d_2(&fx), fx.params.unsettled_cap(), fx.genesis.max_anchor_age);
    assert!(adopting_anchor_70_prefetches(d_t - cap, None).await, "D(t) at the cap");
    assert!(!adopting_anchor_70_prefetches(d_t - cap - 1, None).await, "D(t) past the cap");
    // `D(t)` is two heights, so at least two seconds, after the adopting block.
    assert!(adopting_anchor_70_prefetches(d_t - 5, Some(max_age - 2)).await, "D(t) at maxAge");
    assert!(!adopting_anchor_70_prefetches(d_t - 5, Some(max_age - 1)).await, "D(t) past maxAge");
}

/// A saved identity cannot grant trust to a forged witness or an RLP value with trailing bytes.
#[tokio::test]
async fn corrupt_switch_sidecar_is_reverified_and_reacquired() {
    use crate::store::COMMITTEE_WITNESS_FILE;
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_switch(&fx, dir.path()).await;
    app.store.save(app.state().unwrap()).unwrap();
    let original = propose(&mut app).await.committee.unwrap();
    let path = dir.path().join(COMMITTEE_WITNESS_FILE);
    let saved: serde_json::Value = serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
    for trailing in [false, true] {
        let mut forged = original.clone();
        if !trailing {
            forged.entries[0].eff_stake += alloy_primitives::U256::from(1);
        }
        let mut raw = alloy_rlp::encode(&forged);
        if trailing {
            raw.push(0);
        }
        let mut corrupt = saved.clone();
        corrupt["witness"] = serde_json::json!(Bytes::from(raw));
        std::fs::write(&path, serde_json::to_vec(&corrupt).unwrap()).unwrap();
        let mut restarted = fx.app(dir.path());
        let parent = restarted.state().unwrap().clone();
        fx.plant_l1_block(restarted.l1(), 70, &fx.inbox_with(parent.last_height - 5), &fx.registry);
        assert_eq!(propose(&mut restarted).await.committee, Some(original.clone()));
        assert!(registry_reads(&restarted) > 0, "invalid cache must reacquire the witness");
    }
}

/// A stale sidecar never reuses a witness across another chain, schedule, config, anchor or epoch.
#[tokio::test]
async fn switch_sidecar_requires_its_full_authenticated_identity() {
    use crate::store::COMMITTEE_WITNESS_FILE;
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_switch(&fx, dir.path()).await;
    app.store.save(app.state().unwrap()).unwrap();
    let original = propose(&mut app).await.committee.unwrap();
    let path = dir.path().join(COMMITTEE_WITNESS_FILE);
    let saved: serde_json::Value = serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
    let word = serde_json::json!(B256::repeat_byte(0xe1));
    for (pointer, value) in [
        ("/key/chain_id", serde_json::json!("taiko-etna-167001-g1")),
        ("/key/genesis/epoch_len", serde_json::json!(99)),
        ("/key/inbox", serde_json::json!(alloy_primitives::Address::repeat_byte(0xe1))),
        ("/key/committee_config_hash", word.clone()),
        ("/key/parent_anchor", serde_json::json!(71)),
        ("/key/parent_anchor_hash", word.clone()),
        ("/key/parent_state_root", word),
        ("/key/target_epoch", serde_json::json!(3)),
    ] {
        let mut stale = saved.clone();
        *stale.pointer_mut(pointer).unwrap() = value;
        std::fs::write(&path, serde_json::to_vec(&stale).unwrap()).unwrap();
        let mut restarted = fx.app(dir.path());
        let parent = restarted.state().unwrap().clone();
        fx.plant_l1_block(restarted.l1(), 70, &fx.inbox_with(parent.last_height - 5), &fx.registry);
        assert_eq!(propose(&mut restarted).await.committee, Some(original.clone()), "{pointer}");
        assert!(registry_reads(&restarted) > 0, "{pointer}: another context must reacquire");
    }
}

/// A node must surface failed durable retention rather than publish a witness it would lose on
/// restart; the sidecar is kept separate from the committed state file.
#[tokio::test]
async fn switch_sidecar_write_failure_refuses_the_proposal() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_switch(&fx, dir.path()).await;
    std::fs::create_dir(dir.path().join(crate::store::COMMITTEE_WITNESS_FILE)).unwrap();
    assert_eq!(refused(&mut app).await, "committee_cache_error");
    assert!(app.committee_cache.lock().unwrap().is_none());
}

/// CometBFT rotates proposers round by round: a node that judged another proposer's block at
/// `H(t)-2` keeps its verified committee witness, so its own proposal at that height (a later
/// round) needs no discovery. The witness is proven against the committed parent's anchor alone,
/// so it is kept even when a node-local check (here the EL) refuses that block.
#[tokio::test]
async fn a_committee_witness_judged_at_a_switch_is_reused_by_the_next_proposer() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut a = before_switch(&fx, dir.path()).await;
    let env = propose(&mut a).await;
    let witness = env.committee.clone().expect("switch 2 carries a committee witness");

    // B accepts A's round-0 block, the round fails anyway, and B proposes in round 1.
    let dir = tempfile::tempdir().unwrap();
    let mut b = before_switch(&fx, dir.path()).await;
    let (resp, _) = super::proposal::judge(&mut b, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", b.halt);
    b.l1().state().calls.clear();
    let own = propose(&mut b).await;
    assert_eq!(registry_reads(&b), 0, "{:?}", b.l1().calls());
    assert_eq!(own.committee.as_ref(), Some(&witness));

    // C's EL refuses A's block (syncing); C still proposes without discovery.
    let dir = tempfile::tempdir().unwrap();
    let mut c = before_switch(&fx, dir.path()).await;
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
    let mut app = before_switch(&fx, dir.path()).await;
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
    let witness = crate::l1::build_committee_witness(app.l1(), &app.params, 70, 2)
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
    let mut app = before_switch(&fx, dir.path()).await;
    app.engine().state().build_script.push_back(Err(EngineError::Transport("down".into())));
    assert_eq!(refused(&mut app).await, "engine_error");

    // The committed parent moves to anchor 72 (e.g. after a state rewrite): rediscovered there.
    let h_e = app.state().unwrap().schedule().h_first(2) - 2;
    fx.advance_l1(app.l1(), 72, &fx.inbox_with(h_e - 6), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 72);
    jump(&mut app, h_e - 1, anchor, &[]);
    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert!(registry_reads(&app) > 0, "rediscovered at the new parent anchor");
    assert_eq!(env.committee.expect("switch 2 carries a committee").record.cutoff_l1_block, 72);
}

/// At `H(t)-2` the cheap candidate checks run before the committee discovery: a block that
/// cannot be proposed anyway (back-pressure, a superseded generation, a stale anchor) costs no
/// registry read.
#[tokio::test]
async fn failing_pre_checks_skip_the_committee_discovery() {
    let fx = Fixture::genesis(3);

    // Back-pressure: the checkpoint is still at B*, more than the cap below h_first(1).
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h_e = app.state().unwrap().schedule().h_first(2) - 2;
    fx.advance_l1(app.l1(), 70, &fx.inbox, &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 70);
    jump(&mut app, h_e - 1, anchor, &[(1, fx.committee(1))]);
    app.l1().state().calls.clear();
    assert_eq!(refused(&mut app).await, "back_pressure");
    assert_eq!(registry_reads(&app), 0, "back-pressure: {:?}", app.l1().calls());

    // Generation: the new anchor proves a later recovery generation.
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let mut inbox = fx.inbox_with(h_e - 6);
    inbox.recovery_generation = 1;
    fx.advance_l1(app.l1(), 70, &inbox, &fx.registry);
    let anchor = fx.anchor_state(app.l1(), fx.genesis.l1_0);
    jump(&mut app, h_e - 1, anchor, &[(1, fx.committee(1))]);
    app.l1().state().calls.clear();
    assert_eq!(refused(&mut app).await, "superseded");
    assert_eq!(registry_reads(&app), 0, "generation: {:?}", app.l1().calls());

    // Freshness: the finalized anchor 70 is more than maxAnchorAge older than the block.
    let dir = tempfile::tempdir().unwrap();
    let mut app = before_switch(&fx, dir.path()).await;
    set_anchor_age(&mut app, fx.genesis.max_anchor_age + 1);
    app.l1().state().calls.clear();
    assert_eq!(refused(&mut app).await, "anchor_too_old");
    assert_eq!(registry_reads(&app), 0, "freshness: {:?}", app.l1().calls());
}

/// Independent header and proof reads share one bounded preparation window.
#[tokio::test(start_paused = true)]
async fn prepare_fetches_anchor_header_and_proof_concurrently() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    fx.advance_l1(app.l1(), 66, &fx.inbox, &fx.registry);
    app.l1().state().delay = Some(Duration::from_millis(750));
    let started = tokio::time::Instant::now();
    let env = propose(&mut app).await;
    assert!(env.anchor.is_some());
    assert_eq!(started.elapsed(), Duration::from_millis(1500));
    assert_eq!(app.l1().state().max_in_flight, 2);
}

/// Plants exact input bytes and genuine two-slot proofs under the next chosen anchor.
fn plant_input(fx: &Fixture, app: &App<MockL1, MockEngine>, tx: Bytes, due: bool) {
    let timestamp =
        Fixture::l1_timestamp(66) - if due { fx.genesis.forced_inclusion_delay } else { 0 };
    let mut inbox = fx.inbox.clone();
    inbox.forced_inclusion_tail = 1;
    inbox.forced_inclusion_queue = vec![crate::forced::ForcedEntry {
        index: 0,
        tx_hash: alloy_primitives::keccak256(&tx),
        timestamp,
        l1_block: 66,
    }];
    app.l1().state().forced_transactions.insert((fx.params.inbox, 0, 66), tx);
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
}

#[tokio::test]
async fn mixed_forced_inclusion_works_before_and_after_due() {
    for due in [false, true] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = mid_epoch(&fx, dir.path(), 5).await;
        let txs = sample_transactions();
        let tx: Bytes = txs[0].encoded_2718().into();
        plant_input(&fx, &app, tx.clone(), due);
        app.engine().state().pool = vec![txs[1].clone()];
        let env = propose(&mut app).await;
        assert!(env.forced.as_ref().unwrap().tx.is_empty());
        assert_eq!(
            env.block.transactions,
            txs.iter().map(|tx| Bytes::from(tx.encoded_2718())).collect::<Vec<_>>()
        );
        let selections = app
            .engine()
            .calls()
            .into_iter()
            .filter_map(|call| match call {
                EngineCall::PoolTransactions(s) => Some(s),
                _ => None,
            })
            .collect::<Vec<_>>();
        assert_eq!(selections.len(), 1);
        use alloy_consensus::Transaction;
        assert_eq!(selections[0].gas_limit, fx.params.block_gas_limit - txs[0].gas_limit());
        assert_eq!(selections[0].max_bytes, 131_072 - tx.len() as u64);
        accept_and_commit(&mut app, &env).await;
        assert_eq!(app.state().unwrap().forced_cursor, 1);
    }
}

#[tokio::test]
async fn invalid_input_is_retained_early_and_consumed_when_due() {
    for due in [false, true] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = mid_epoch(&fx, dir.path(), 5).await;
        plant_input(&fx, &app, Bytes::from_static(&[0xff]), due);
        let env = propose(&mut app).await;
        assert!(built_tx_list(&app).is_none());
        accept_and_commit(&mut app, &env).await;
        assert_eq!(app.state().unwrap().forced_cursor, u64::from(due));
    }
}

#[tokio::test]
async fn unavailable_admission_bytes_block_only_due_proposals() {
    for due in [false, true] {
        for failure in 0..3 {
            let fx = Fixture::genesis(1);
            let dir = tempfile::tempdir().unwrap();
            let mut app = mid_epoch(&fx, dir.path(), 5).await;
            plant_input(&fx, &app, sample_transactions()[0].encoded_2718().into(), due);
            let key = (fx.params.inbox, 0, 66);
            match failure {
                0 => {
                    app.l1().state().forced_transactions.remove(&key);
                }
                1 => {
                    app.l1().state().forced_transactions.insert(key, Bytes::from_static(&[0xff]));
                }
                _ => {
                    app.l1().state().forced_transaction_fail =
                        Some(L1Error::Rpc("logs unavailable".into()));
                }
            }
            if due {
                let time = bft_time(&app);
                assert!(prepare(&mut app, prepare_req(6, time)).await.is_empty());
                assert!(!built_any(&app));
            } else {
                let env = propose(&mut app).await;
                assert!(env.forced.as_ref().unwrap().tx.is_empty());
                assert!(env.block.transactions.is_empty());
                accept_and_commit(&mut app, &env).await;
                assert_eq!(app.state().unwrap().forced_cursor, 0);
            }
        }
    }
}

#[tokio::test(start_paused = true)]
async fn slow_pre_due_admission_read_leaves_time_for_ordinary_build_and_is_reused() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let raw: Bytes = sample_transactions()[0].encoded_2718().into();
    plant_input(&fx, &app, raw.clone(), false);
    app.l1().state().forced_transaction_delay = Some(Duration::from_millis(2500));
    app.engine().state().delay = Some(Duration::from_secs(1));
    let start = tokio::time::Instant::now();
    let env = propose(&mut app).await;
    assert!(start.elapsed() < app.opts.prepare_timeout);
    assert!(env.forced.as_ref().unwrap().tx.is_empty());
    assert!(env.block.transactions.is_empty());
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 0);
    tokio::time::advance(Duration::from_secs(3)).await;
    tokio::task::yield_now().await;
    app.engine().state().delay = None;
    let next = propose(&mut app).await;
    assert_eq!(next.block.transactions.first(), Some(&raw));
    assert_eq!(
        app.l1().calls().iter().filter(|c| matches!(c, L1Call::ForcedTransaction { .. })).count(),
        1
    );
}

#[tokio::test]
async fn canonical_skip_reuses_confirmation_after_restoring_the_ordinary_budget() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_input(&fx, &app, sample_transactions()[0].encoded_2718().into(), true);
    let anchor = Some(fx.anchor_witness(app.l1(), 66));
    let mut ordinary = super::proposal::hand_envelope(&app, anchor, None).block;
    let empty = ordinary.clone();
    ordinary.transactions = vec![sample_transactions()[1].encoded_2718().into()];
    ordinary.header.transactions_root =
        alloy_consensus::proofs::ordered_trie_root_encoded(&ordinary.transactions);
    app.engine().state().build_script.extend([
        Ok(empty.clone()),
        Ok(empty.clone()),
        Ok(ordinary.clone()),
        Err(EngineError::Transport("a repeated singleton check is unavailable".into())),
    ]);
    let env = propose(&mut app).await;
    assert_eq!(env.block, ordinary);
    let calls = app.engine().calls();
    let lists = calls
        .iter()
        .filter_map(|call| match call {
            EngineCall::BuildBlock { attrs, .. } => Some(attrs.block_metadata.tx_list.clone()),
            _ => None,
        })
        .collect::<Vec<_>>();
    assert_eq!(lists.len(), 3);
    assert!(lists[0].is_some() && lists[1].is_some() && lists[2].is_none());
    assert_eq!(app.state().unwrap().forced_cursor, 0);
}

#[tokio::test]
async fn zero_remaining_gas_does_not_call_pool_api() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    use alloy_consensus::{SignableTransaction, TxLegacy};
    let tx = alloy_consensus::TxEnvelope::Legacy(
        TxLegacy { gas_limit: fx.params.block_gas_limit, ..Default::default() }.into_signed(
            alloy_primitives::Signature::new(
                alloy_primitives::U256::from(1),
                alloy_primitives::U256::from(1),
                false,
            ),
        ),
    );
    plant_input(&fx, &app, tx.encoded_2718().into(), true);
    let env = propose(&mut app).await;
    assert_eq!(env.block.transactions.len(), 1);
    assert!(
        !app.engine().calls().iter().any(|call| matches!(call, EngineCall::PoolTransactions(_)))
    );
}

#[tokio::test]
async fn completed_entry_and_transaction_reads_are_reused_only_for_matching_root() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_input(&fx, &app, sample_transactions()[0].encoded_2718().into(), false);
    propose(&mut app).await;
    let first =
        app.l1().calls().iter().filter(|c| matches!(c, L1Call::ForcedTransaction { .. })).count();
    propose(&mut app).await;
    assert_eq!(
        app.l1().calls().iter().filter(|c| matches!(c, L1Call::ForcedTransaction { .. })).count(),
        first
    );
    plant_input(&fx, &app, sample_transactions()[1].encoded_2718().into(), false);
    let env = propose(&mut app).await;
    assert!(env.forced.unwrap().tx.is_empty());
    assert_eq!(env.block.transactions.first().unwrap(), &sample_transactions()[1].encoded_2718());
    assert_eq!(
        app.l1().calls().iter().filter(|c| matches!(c, L1Call::ForcedTransaction { .. })).count(),
        first + 1
    );
}

/// An L1 admission cannot force its 8 KiB preimage into every ordinary proposal before due.
#[tokio::test]
async fn pending_junk_preimage_is_omitted_from_proposal_data() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let noise = incompressible(8191 + 65_536);
    let raw = Bytes::from([vec![0xff], noise[..8191].to_vec()].concat());
    plant_input(&fx, &app, raw.clone(), false);
    let env = propose(&mut app).await;
    assert!(env.forced.as_ref().unwrap().tx.is_empty());
    let mut redundant = env.clone();
    redundant.forced.as_mut().unwrap().tx = raw;
    assert!(redundant.encode().len() - env.encode().len() >= 8192);

    // Repeat full envelopes separated by a busy execution block, outside deflate's 32 KiB
    // history. Use the landing guard's pinned compressor and the genuine entry proof above.
    use alloy_consensus::{SignableTransaction, TxEnvelope, TxLegacy};
    let transaction = TxEnvelope::Legacy(
        TxLegacy { gas_limit: 2_000_000, input: noise.slice(8191..), ..Default::default() }
            .into_signed(alloy_primitives::Signature::new(
                alloy_primitives::U256::from(1),
                alloy_primitives::U256::from(1),
                false,
            )),
    );
    let mut compact = env.clone();
    compact.block.transactions = vec![transaction.encoded_2718().into()];
    compact.block.header.transactions_root =
        alloy_consensus::proofs::ordered_trie_root_encoded(&compact.block.transactions);
    redundant.block = compact.block.clone();
    let compressed = |envelope: &EtnaEnvelope| {
        crate::compression::zlib_compress(&alloy_rlp::encode(vec![envelope.encode(); 4])).len()
    };
    let saved = compressed(&redundant) - compressed(&compact);
    eprintln!("four busy envelopes omit {saved} compressed FI-preimage bytes");
    assert!(saved > 28_000, "the repeated preimage must not rely on zlib deduplication");
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 0);
}

/// Cached raw proofs survive proposer changes, while each proposer gets a fresh EL build.
#[tokio::test]
async fn preparation_proposer_change_rebuilds_for_payout_and_reuses_raw_proofs() {
    use super::proposal::plant_due_entry;
    use crate::test_utils::sample_entries;
    use alloy_primitives::Address;
    for recipient in [sample_entries(3)[0].reward_recipient, Address::repeat_byte(0x88)] {
        let mut spec = GenesisSpec::new(3);
        let mut entries = sample_entries(3);
        entries[1].reward_recipient = recipient;
        spec.entries = Some(entries.clone());
        let fx = Fixture::build(spec);
        let dir = tempfile::tempdir().unwrap();
        let mut app = mid_epoch(&fx, dir.path(), 3).await;
        plant_due_entry(&fx, app.l1(), 70, fx.inbox_with(1));
        let env = propose(&mut app).await;
        assert_eq!(env.block.header.beneficiary, entries[0].reward_recipient);
        app.l1().state().calls.clear();
        let before = app.engine().calls().len();
        let mut req = prepare_req(next_height(&app), bft_time(&app));
        req.proposer_address = tendermint::account::Id::from(
            tendermint::PublicKey::from_raw_ed25519(entries[1].pubkey.as_slice()).unwrap(),
        );
        let txs = prepare(&mut app, req).await;
        assert_eq!(txs.len(), 1);
        let again = EtnaEnvelope::decode(&txs[0]).unwrap();
        assert_eq!(again.forced, env.forced);
        assert_eq!(again.block.header.beneficiary, recipient);
        let calls = app.engine().calls();
        let builds: Vec<_> = calls[before..]
            .iter()
            .filter_map(|call| match call {
                EngineCall::BuildBlock { attrs, .. } => Some(attrs),
                _ => None,
            })
            .collect();
        assert_eq!(builds.len(), 1, "even equal payout addresses require a fresh build");
        assert_eq!(builds[0].payload_attributes.suggested_fee_recipient, recipient);
        assert_eq!(builds[0].block_metadata.beneficiary, recipient);
        assert!(
            app.l1().calls().iter().all(|call| match call {
                L1Call::ForcedTransaction { .. } => false,
                L1Call::AccountWitness { address, slots, .. } =>
                    *address != fx.params.inbox || *slots != crate::forced::entry_slots(0),
                _ => true,
            }),
            "{:?}",
            app.l1().calls()
        );
    }
}

/// A cancelled raw event read survives a new certified proposer, authenticated by its own entry.
#[tokio::test(start_paused = true)]
async fn preparation_proposer_change_reuses_cancelled_authenticated_io() {
    use super::proposal::plant_due_entry;
    use crate::test_utils::sample_entries;
    use alloy_primitives::Address;
    let mut spec = GenesisSpec::new(3);
    let mut entries = sample_entries(3);
    entries[1].reward_recipient = Address::repeat_byte(0x88);
    spec.entries = Some(entries.clone());
    let fx = Fixture::build(spec);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 3).await;
    let old = propose(&mut app).await;
    assert_eq!(old.block.header.beneficiary, entries[0].reward_recipient);
    plant_due_entry(&fx, app.l1(), 70, fx.inbox_with(1));
    let anchor = fx.anchor_state(app.l1(), 70);
    let entry = app.forced_entry(&anchor, 0).await.unwrap().proven;
    app.l1().state().delay = Some(Duration::from_secs(1));
    assert!(
        tokio::time::timeout(Duration::from_millis(1), app.forced_transaction(entry))
            .await
            .is_err()
    );
    assert_eq!(app.l1().state().in_flight, 1);
    tokio::time::advance(Duration::from_secs(1)).await;
    tokio::task::yield_now().await;
    app.l1().state().delay = None;
    app.l1().state().calls.clear();
    let mut req = prepare_req(next_height(&app), bft_time(&app));
    req.proposer_address = tendermint::account::Id::from(
        tendermint::PublicKey::from_raw_ed25519(entries[1].pubkey.as_slice()).unwrap(),
    );
    let txs = prepare(&mut app, req).await;
    assert_eq!(txs.len(), 1);
    let env = EtnaEnvelope::decode(&txs[0]).unwrap();
    assert_eq!(env.block.header.beneficiary, Address::repeat_byte(0x88));
    assert_eq!(env.block.transactions[0], sample_transactions()[0].encoded_2718());
    assert!(
        app.l1().calls().iter().all(|call| match call {
            L1Call::ForcedTransaction { .. } => false,
            L1Call::AccountWitness { address, slots, .. } =>
                *address != fx.params.inbox || *slots != crate::forced::entry_slots(0),
            _ => true,
        }),
        "the new proposer reuses only authenticated raw reads: {:?}",
        app.l1().calls()
    );
}
