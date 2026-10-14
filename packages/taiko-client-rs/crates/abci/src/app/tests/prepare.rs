//! `PrepareProposal`: anchor choice, and every reason it proposes nothing.

use std::{path::Path, time::Duration};

use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{B256, Bytes};

use super::{
    proposal::{
        bft_time, decide, hand_forced_envelope, incompressible, judge, jump, mid_epoch,
        next_height, plant_due_entry, plant_entries, prepare, prepare_req, propose, sample_tx_list,
        set_anchor_age, step,
    },
    *,
};
use crate::{
    engine::{EngineError, PayloadVerdict},
    envelope::EtnaEnvelope,
    forced::{EMPTY_TX_LIST, FORCED_INCLUSION_EXPIRY_SECS},
    l1::{L1Error, layout::inbox},
    rules::decode_extra_data,
    test_utils::{
        BlobCall, GenesisSpec, L1Call, blob_versioned_hash, forced_blob, manifest_payload,
        sample_transactions, simple_block,
    },
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

/// The proof read of forced inclusion entry `index` in the Inbox at L1 block `block`.
fn entry_read(fx: &Fixture, index: u64, block: u64) -> L1Call {
    L1Call::AccountWitness {
        address: fx.params.inbox,
        slots: inbox::forced_inclusion_entry_slots(index).to_vec(),
        block,
    }
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

    // Epoch 1 opens on L1 only at L1_first(1) = L1_0 + EPOCH_LEN_L1.
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h_first = app.state().unwrap().schedule().h_first(1);
    let anchor = fx.anchor_state(app.l1(), fx.genesis.l1_0);
    jump(&mut app, h_first - 1, anchor, &[(1, fx.committee(1))]);
    assert_eq!(refused(&mut app).await, "epoch_not_open_on_l1");
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
    let witness = crate::l1::build_committee_witness(
        app.l1(),
        &app.params,
        &app.state().unwrap().schedule(),
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
    let App { l1, engine, blobs, params, store, opts, .. } = app;
    let mut restarted =
        App::new(Arc::try_unwrap(l1).expect("sole L1 owner"), engine, blobs, params, store, opts)
            .unwrap();
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
    let App { l1, engine, blobs, params, store, opts, .. } = node;
    let mut restarted =
        App::new(Arc::try_unwrap(l1).expect("sole L1 owner"), engine, blobs, params, store, opts)
            .unwrap();
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
    let App { l1, engine, blobs, params, store, opts, .. } = app;
    let mut restarted =
        App::new(Arc::try_unwrap(l1).expect("sole L1 owner"), engine, blobs, params, store, opts)
            .unwrap();
    step(&mut restarted).await;
    step(&mut restarted).await;
    restarted.l1().state().calls.clear();
    assert_eq!(propose(&mut restarted).await.committee, witness);
    assert_eq!(registry_reads(&restarted), 0, "{:?}", restarted.l1().calls());
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
    let witness = crate::l1::build_committee_witness(
        app.l1(),
        &app.params,
        &app.state().unwrap().schedule(),
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
/// cannot be proposed anyway (back-pressure, anchor progress, a superseded generation, a stale
/// anchor) costs no registry read.
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

    // Anchor progress: epoch 1 is not open on L1 at the genesis anchor.
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let anchor = fx.anchor_state(app.l1(), fx.genesis.l1_0);
    jump(&mut app, h_e - 1, anchor, &[(1, fx.committee(1))]);
    app.l1().state().calls.clear();
    assert_eq!(refused(&mut app).await, "epoch_not_open_on_l1");
    assert_eq!(registry_reads(&app), 0, "anchor progress: {:?}", app.l1().calls());

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

/// A due entry at the cursor: the proposer proves it at the anchor, fetches its blob by the
/// entry's timestamp and versioned hash, and builds the forced inclusion block from its
/// transaction list, exactly the block an honest proposer builds. A validator rebuilds and
/// accepts it, and the cursor advances.
#[tokio::test]
async fn prepare_builds_a_forced_block_when_due() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let blob = plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());

    let env = propose(&mut app).await;
    assert_eq!(built_tx_list(&app), Some(sample_tx_list()), "the build carries the list");
    assert_eq!(env.block.transactions.len(), sample_transactions().len());
    let forced = fx.forced_witness(app.l1(), 66, 0, blob.clone());
    assert_eq!(env.forced.as_ref(), Some(&forced), "the envelope carries the blob");
    let anchor = Some(fx.anchor_witness(app.l1(), 66));
    assert_eq!(env, hand_forced_envelope(&app, anchor, None, forced, sample_tx_list()));
    assert!(app.l1().calls().contains(&entry_read(&fx, 0, 66)), "{:?}", app.l1().calls());
    let timestamp = Fixture::l1_timestamp(66) - fx.genesis.forced_inclusion_delay;
    let versioned_hash = blob_versioned_hash(&blob);
    assert_eq!(fx.blobs.calls(), [BlobCall { timestamp, versioned_hash }]);

    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 1);
}

/// An entry below the anchor's tail that is not yet due is peeked: the block carries the
/// entry's proof with an empty blob and stays ordinary (the EL selects its transactions), and
/// no blob is fetched. Once L1 finalizes a block at which the entry is due, the next proposal
/// consumes it.
#[tokio::test]
async fn prepare_peeks_while_pending() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    // Due from an anchor at L1 block 67 on, so still pending at 66.
    let entries = || {
        vec![(Fixture::l1_timestamp(67) - fx.genesis.forced_inclusion_delay, sample_transactions())]
    };
    plant_entries(&fx, app.l1(), 66, fx.inbox.clone(), entries());

    let env = propose(&mut app).await;
    assert_eq!(env.forced, Some(fx.forced_witness(app.l1(), 66, 0, Bytes::new())), "a peek");
    assert_eq!(built_tx_list(&app), None, "an ordinary block");
    assert!(app.l1().calls().contains(&entry_read(&fx, 0, 66)), "{:?}", app.l1().calls());
    assert_eq!(fx.blobs.calls(), [], "a pending entry needs no blob");
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 0, "a peek consumes nothing");

    let blob = plant_entries(&fx, app.l1(), 67, fx.inbox.clone(), entries()).remove(0);
    let env = propose(&mut app).await;
    assert_eq!(env.forced, Some(fx.forced_witness(app.l1(), 67, 0, blob)));
    assert_eq!(built_tx_list(&app), Some(sample_tx_list()));
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 1);
}

/// Review Focus 2: two entries due at once fill consecutive blocks. The second keeps the anchor
/// and carries a fresh proof of the next entry (index `c + 1`) with that entry's own blob and
/// list; the block after them is ordinary and carries no forced witness.
#[tokio::test]
async fn prepare_builds_consecutive_forced_blocks() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let due = Fixture::l1_timestamp(66) - fx.genesis.forced_inclusion_delay;
    let second = sample_transactions()[..1].to_vec();
    let blobs = plant_entries(
        &fx,
        app.l1(),
        66,
        fx.inbox.clone(),
        vec![(due, sample_transactions()), (due, second.clone())],
    );

    let first = step(&mut app).await;
    assert_eq!(first.forced, Some(fx.forced_witness(app.l1(), 66, 0, blobs[0].clone())));
    assert_eq!(app.state().unwrap().forced_cursor, 1);

    app.l1().state().calls.clear();
    let env = propose(&mut app).await;
    assert!(env.anchor.is_none(), "the anchor stays at 66");
    assert_eq!(env.forced, Some(fx.forced_witness(app.l1(), 66, 1, blobs[1].clone())));
    assert!(app.l1().calls().contains(&entry_read(&fx, 1, 66)), "{:?}", app.l1().calls());
    assert_eq!(built_tx_list(&app), Some(protocol::shasta::encode_transactions(&second)));
    let expected: Vec<Bytes> = second.iter().map(|tx| tx.encoded_2718().into()).collect();
    assert_eq!(env.block.transactions, expected);
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 2);

    let env = step(&mut app).await;
    assert_eq!(env.forced, None, "the cursor reached the tail");
    assert_eq!(app.state().unwrap().forced_cursor, 2);
    let hashes: Vec<B256> = fx.blobs.calls().iter().map(|c| c.versioned_hash).collect();
    assert_eq!(hashes, [blob_versioned_hash(&blobs[0]), blob_versioned_hash(&blobs[1])]);
}

/// An entry queued behind another, already due when its predecessor's block commits, is never
/// peeked; `Commit` still reads it under the committed anchor and prefetches its blob, so the
/// next proposal holds it although the beacon answers slower than a proposal may wait.
#[tokio::test(start_paused = true)]
async fn a_queued_entry_blob_is_prefetched_when_its_predecessor_commits() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let due = Fixture::l1_timestamp(66) - fx.genesis.forced_inclusion_delay;
    let blobs = plant_entries(
        &fx,
        app.l1(),
        66,
        fx.inbox.clone(),
        vec![(due, sample_transactions()), (due, sample_transactions()[..1].to_vec())],
    );
    let first = propose(&mut app).await;
    assert_eq!(first.forced.as_ref().map(|w| w.index), Some(0));
    let slow = app.opts.prepare_timeout + Duration::from_millis(500);
    fx.blobs.state().delay = Some(slow);
    accept_and_commit(&mut app, &first).await;
    tokio::time::sleep(slow + Duration::from_millis(100)).await;
    assert!(app.l1().calls().contains(&entry_read(&fx, 1, 66)), "{:?}", app.l1().calls());

    let env = propose(&mut app).await;
    assert_eq!(env.forced, Some(fx.forced_witness(app.l1(), 66, 1, blobs[1].clone())));
    let hashes: Vec<B256> = fx.blobs.calls().iter().map(|c| c.versioned_hash).collect();
    assert_eq!(hashes, [blob_versioned_hash(&blobs[0]), blob_versioned_hash(&blobs[1])]);
}

/// A read lost to a transient L1 failure right after `Commit` is restarted by the next round's
/// `ProcessProposal`, an empty proposal included, so a stalled height still prefetches the
/// queued entry's blob.
#[tokio::test(start_paused = true)]
async fn a_failed_entry_prefetch_is_restarted_by_the_next_round() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let due = Fixture::l1_timestamp(66) - fx.genesis.forced_inclusion_delay;
    let blobs = plant_entries(
        &fx,
        app.l1(),
        66,
        fx.inbox.clone(),
        vec![(due, sample_transactions()), (due, sample_transactions()[..1].to_vec())],
    );
    let first = propose(&mut app).await;
    let slow = app.opts.prepare_timeout + Duration::from_millis(500);
    fx.blobs.state().delay = Some(slow);
    let (resp, req) = judge(&mut app, &first).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    app.l1().state().fail = Some(L1Error::Rpc("flaky".into()));
    decide(&mut app, &req).await;
    tokio::task::yield_now().await;
    app.l1().state().fail = None;
    tokio::time::sleep(slow + Duration::from_millis(100)).await;
    assert_eq!(fx.blobs.calls().len(), 1, "the failed read started no blob fetch");

    let req = super::proposal::process_req(next_height(&app), bft_time(&app), vec![]);
    assert_eq!(super::proposal::process(&mut app, req).await, response::ProcessProposal::Reject);
    tokio::time::sleep(slow + Duration::from_millis(100)).await;
    let env = propose(&mut app).await;
    assert_eq!(env.forced, Some(fx.forced_witness(app.l1(), 66, 1, blobs[1].clone())));
    let hashes: Vec<B256> = fx.blobs.calls().iter().map(|c| c.versioned_hash).collect();
    assert_eq!(hashes, [blob_versioned_hash(&blobs[0]), blob_versioned_hash(&blobs[1])]);
}

/// An entry expired at the anchor (exactly at the expiry) is consumed as an empty block: the
/// witness carries no blob, the EL builds from the empty list, and the blob source is never
/// asked, even while it is down.
#[tokio::test]
async fn prepare_builds_an_empty_forced_block_for_an_expired_entry_without_fetching() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let expired = Fixture::l1_timestamp(66) - FORCED_INCLUSION_EXPIRY_SECS;
    plant_entries(&fx, app.l1(), 66, fx.inbox.clone(), vec![(expired, sample_transactions())]);
    fx.blobs.state().fail = Some("beacon down".into());

    let env = propose(&mut app).await;
    assert_eq!(env.forced, Some(fx.forced_witness(app.l1(), 66, 0, Bytes::new())));
    assert_eq!(built_tx_list(&app), Some(EMPTY_TX_LIST));
    assert!(env.block.transactions.is_empty());
    assert_eq!(fx.blobs.calls(), []);
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 1);
}

/// A due entry whose blob the blob source cannot serve gets nothing proposed, never an ordinary
/// block in its place: the source failing or serving another blob records `blob_unavailable`
/// and the EL is never asked to build. Once the blob is served, the forced block is proposed.
#[tokio::test]
async fn prepare_records_blob_unavailable_and_proposes_nothing() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let blob = plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    let versioned_hash = blob_versioned_hash(&blob);

    fx.blobs.state().fail = Some("beacon down".into());
    assert_eq!(refused(&mut app).await, "blob_unavailable");
    assert!(!built_any(&app));

    fx.blobs.state().fail = None;
    let (other, _) = forced_blob(&manifest_payload(vec![]));
    fx.blobs.insert(versioned_hash, other);
    assert_eq!(refused(&mut app).await, "blob_unavailable", "another blob");
    assert!(!built_any(&app));
    assert_eq!(fx.blobs.calls().len(), 2);

    fx.blobs.insert(versioned_hash, blob.clone());
    let env = propose(&mut app).await;
    assert_eq!(env.forced.map(|f| f.blob), Some(blob));
    assert_eq!(app.halt, None);
}

/// A blob source slower than the proposal's deadline gets nothing proposed.
#[tokio::test(start_paused = true)]
async fn slow_blob_source_proposes_nothing() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    fx.blobs.state().delay = Some(app.opts.prepare_timeout + Duration::from_secs(1));
    assert_eq!(refused(&mut app).await, "timeout");
    assert!(!built_any(&app));
}

/// A round cancelled during the EL build retains the already verified forced proof and blob.
/// The next round can build even if the beacon has since become unavailable.
#[tokio::test(start_paused = true)]
async fn cancelled_prepare_reuses_completed_forced_reads() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    app.engine().state().delay_script.push_back(app.opts.prepare_timeout + Duration::from_secs(1));
    assert_eq!(refused(&mut app).await, "timeout");
    assert_eq!(fx.blobs.calls().len(), 1);

    fx.blobs.state().fail = Some("beacon down after the first read".into());
    let env = propose(&mut app).await;
    assert!(env.forced.as_ref().is_some_and(|w| !w.blob.is_empty()));
    assert_eq!(fx.blobs.calls().len(), 1, "the verified blob survives round cancellation");
    assert_eq!(
        app.l1().calls().iter().filter(|c| **c == entry_read(&fx, 0, 66)).count(),
        1,
        "the entry proof is reused only under the same anchor root"
    );
}

/// Header and Inbox proof acquisition share a latency wave instead of serially consuming the
/// whole proposal budget.
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

/// A blob fetch inside its own deadline can outlive a cancelled two-second proposal and complete
/// for the next round without starting another fetch.
#[tokio::test(start_paused = true)]
async fn forced_blob_fetch_outlives_a_cancelled_round() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let blob = plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    fx.blobs.state().delay = Some(Duration::from_millis(2500));
    assert_eq!(refused(&mut app).await, "timeout");
    tokio::time::sleep(Duration::from_millis(501)).await;
    let env = propose(&mut app).await;
    assert_eq!(env.forced.map(|w| w.blob), Some(blob));
    assert_eq!(fx.blobs.calls().len(), 1, "one bounded fetch spans rounds");
}

/// A blob read slower than the L1 deadline is bounded by the blob deadline instead: the round
/// cannot wait for it, but the read completes in the background and the next round consumes the
/// entry. Under the L1 deadline every round would restart the read and the entry never land.
#[tokio::test(start_paused = true)]
async fn a_blob_slower_than_the_l1_timeout_lands_in_a_later_round() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let blob = plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    let slow = app.opts.l1_timeout + Duration::from_millis(500);
    assert!(slow < app.opts.blob_timeout);
    fx.blobs.state().delay = Some(slow);
    assert_eq!(refused(&mut app).await, "timeout");
    tokio::time::sleep(slow).await;
    let env = propose(&mut app).await;
    assert_eq!(env.forced.map(|w| w.blob), Some(blob));
    assert_eq!(fx.blobs.calls().len(), 1, "one background read spans the rounds");
}

/// A decided block proving a pending entry starts this validator's blob read, whether or not it
/// proposes (proposing a peek fetches nothing). The read outlives `Commit` and the following
/// heights, so once the entry falls due the proposal holds the blob without asking again.
#[tokio::test(start_paused = true)]
async fn a_decided_peek_prefetches_the_entry_blob_across_heights() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    // Due from an anchor at L1 block 67 on, so still pending at 66.
    let entries = || {
        vec![(Fixture::l1_timestamp(67) - fx.genesis.forced_inclusion_delay, sample_transactions())]
    };
    let blob = plant_entries(&fx, app.l1(), 66, fx.inbox.clone(), entries()).remove(0);
    fx.blobs.state().delay = Some(Duration::from_millis(2500));
    for _ in 0..2 {
        let env = propose(&mut app).await;
        assert_eq!(env.forced, Some(fx.forced_witness(app.l1(), 66, 0, Bytes::new())), "a peek");
        accept_and_commit(&mut app, &env).await;
    }
    tokio::time::sleep(Duration::from_secs(3)).await;
    assert_eq!(fx.blobs.calls().len(), 1, "one read started at the first decision spans both");

    fx.blobs.state().fail = Some("beacon down once the entry is due".into());
    plant_entries(&fx, app.l1(), 67, fx.inbox.clone(), entries());
    let env = propose(&mut app).await;
    assert_eq!(env.forced.map(|w| w.blob), Some(blob));
    assert_eq!(fx.blobs.calls().len(), 1, "the due proposal reuses the prefetched blob");
}

/// The same cancellation rule applies to a forced-entry proof, keyed to the anchor's state
/// root and queue index. Finality and header reads remain below the preparation budget.
#[tokio::test(start_paused = true)]
async fn forced_entry_fetch_outlives_a_cancelled_round() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    let anchor = fx.anchor_state(app.l1(), 66);
    app.state.as_mut().unwrap().anchor = anchor;
    app.l1().state().proof_delay = Some(Duration::from_millis(2500));
    assert_eq!(refused(&mut app).await, "timeout");
    tokio::time::sleep(Duration::from_millis(501)).await;
    let env = propose(&mut app).await;
    assert!(env.forced.is_some());
    assert_eq!(
        app.l1().calls().iter().filter(|c| **c == entry_read(&fx, 0, 66)).count(),
        1,
        "one bounded proof read spans rounds"
    );
}

/// Replacing the chosen entry's hash aborts its unfinished fetch instead of accumulating
/// background requests or allowing the old blob to satisfy the new entry.
#[tokio::test(start_paused = true)]
async fn a_new_blob_hash_aborts_the_previous_inflight_fetch() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let previous = plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    fx.blobs.state().delay = Some(Duration::from_millis(2500));
    assert_eq!(refused(&mut app).await, "timeout");

    fx.blobs.state().delay = None;
    let timestamp = Fixture::l1_timestamp(67) - fx.genesis.forced_inclusion_delay;
    let replacement =
        plant_entries(&fx, app.l1(), 67, fx.inbox.clone(), vec![(timestamp, vec![])]).remove(0);
    assert_ne!(blob_versioned_hash(&previous), blob_versioned_hash(&replacement));
    let env = propose(&mut app).await;
    assert_eq!(env.forced.map(|w| w.blob), Some(replacement));
    tokio::time::sleep(Duration::from_secs(1)).await;
    assert!(
        fx.blobs.calls().iter().all(|call| call.versioned_hash != blob_versioned_hash(&previous))
    );
}

/// Another proposer can commit while this node's blob request is in flight. Commit aborts it;
/// voting and finalizing the carried blob never require that request to finish.
#[tokio::test(start_paused = true)]
async fn commit_aborts_an_unfinished_blob_fetch() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let blob = plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    fx.blobs.state().delay = Some(Duration::from_millis(2500));
    assert_eq!(refused(&mut app).await, "timeout");
    let env = hand_forced_envelope(
        &app,
        Some(fx.anchor_witness(app.l1(), 66)),
        None,
        fx.forced_witness(app.l1(), 66, 0, blob),
        sample_tx_list(),
    );
    accept_and_commit(&mut app, &env).await;
    tokio::time::sleep(Duration::from_secs(1)).await;
    assert_eq!(fx.blobs.calls(), [], "the obsolete request was aborted before answering");
    assert_eq!(app.state().unwrap().forced_cursor, 1);
}

/// A same-number replacement header changes the authentication root. Neither cached anchor
/// nor entry proofs can be reused, while the identical commitment-verified blob remains valid.
#[tokio::test]
async fn preparation_proofs_are_refetched_when_the_anchor_root_changes() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    let first = propose(&mut app).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox_with(fx.genesis.genesis_height + 4));
    let second = propose(&mut app).await;
    assert_ne!(first.anchor.unwrap().l1_header.hash(), second.anchor.unwrap().l1_header.hash());
    assert_eq!(
        app.l1().calls().iter().filter(|c| **c == entry_read(&fx, 0, 66)).count(),
        2,
        "a different root needs a different entry proof"
    );
    assert_eq!(fx.blobs.calls().len(), 1, "the same immutable blob is safe across roots");
}

/// A task that fails after its waiting round was cancelled must not consume another healthy
/// round merely to report its obsolete error.
#[tokio::test(start_paused = true)]
async fn a_failed_blob_task_is_retried_by_the_next_healthy_round() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    {
        let mut blobs = fx.blobs.state();
        blobs.delay = Some(Duration::from_millis(2500));
        blobs.fail = Some("temporarily unavailable".into());
    }
    assert_eq!(refused(&mut app).await, "timeout");
    tokio::time::sleep(Duration::from_millis(501)).await;
    {
        let mut blobs = fx.blobs.state();
        blobs.delay = None;
        blobs.fail = None;
    }
    assert!(propose(&mut app).await.forced.is_some());
    assert_eq!(fx.blobs.calls().len(), 2, "one failed read and a fresh successful retry");
}

/// The underlying read's own timeout also discards its completed failure before retrying a
/// now-healthy beacon, independently of the shorter PrepareProposal timeout.
#[tokio::test(start_paused = true)]
async fn a_timed_out_blob_task_is_retried_by_the_next_healthy_round() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    fx.blobs.state().delay = Some(app.opts.l1_timeout + Duration::from_secs(1));
    assert_eq!(refused(&mut app).await, "timeout");
    tokio::time::sleep(Duration::from_millis(1001)).await;
    fx.blobs.state().delay = None;
    assert!(propose(&mut app).await.forced.is_some());
    assert_eq!(fx.blobs.calls().len(), 1, "the timed-out source never completed");
}

/// A late proof error is likewise evicted before the next healthy proposal retries under the
/// same root and queue index.
#[tokio::test(start_paused = true)]
async fn a_failed_entry_task_is_retried_by_the_next_healthy_round() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    app.state.as_mut().unwrap().anchor = fx.anchor_state(app.l1(), 66);
    app.l1().state().proof_delay = Some(Duration::from_millis(2500));
    assert_eq!(refused(&mut app).await, "timeout");
    app.l1().state().fail = Some(L1Error::Rpc("temporarily unavailable".into()));
    tokio::time::sleep(Duration::from_millis(501)).await;
    {
        let mut l1 = app.l1().state();
        l1.fail = None;
        l1.proof_delay = None;
    }
    assert!(propose(&mut app).await.forced.is_some());
    assert_eq!(
        app.l1().calls().iter().filter(|c| **c == entry_read(&fx, 0, 66)).count(),
        2,
        "one failed proof and a fresh successful retry"
    );
}

/// A new authentication root aborts an unfinished proof instead of allowing it to accumulate
/// in the background or satisfy the replacement root.
#[tokio::test(start_paused = true)]
async fn a_new_anchor_root_aborts_the_previous_inflight_entry_read() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    app.state.as_mut().unwrap().anchor = fx.anchor_state(app.l1(), 66);
    app.l1().state().proof_delay = Some(Duration::from_millis(2500));
    assert_eq!(refused(&mut app).await, "timeout");
    app.l1().state().proof_delay = None;
    plant_due_entry(&fx, app.l1(), 67, fx.inbox.clone());
    assert!(propose(&mut app).await.forced.is_some());
    tokio::time::sleep(Duration::from_secs(1)).await;
    assert!(app.l1().calls().iter().all(|call| *call != entry_read(&fx, 0, 66)));
    assert!(app.l1().calls().contains(&entry_read(&fx, 0, 67)));
}

/// Dropping the app cancels its owned task even when an external blob-source owner remains.
#[tokio::test(start_paused = true)]
async fn app_drop_aborts_an_unfinished_blob_fetch() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    fx.blobs.state().delay = Some(Duration::from_millis(2500));
    assert_eq!(refused(&mut app).await, "timeout");
    drop(app);
    tokio::time::sleep(Duration::from_secs(1)).await;
    assert_eq!(fx.blobs.calls(), [], "the detached source cannot finish the dropped app's task");
}
