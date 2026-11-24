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
    engine::EngineError,
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
    fx.advance_l1(app.l1(), 66, &inbox);
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
async fn proposal_fallback_survives_optional_candidate_above_comet_limit() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let minimum = propose(&mut app).await;
    let mut optional = minimum.block.clone();
    optional.transactions = vec![sample_transactions()[0].encoded_2718().into()];
    optional.header.transactions_root =
        alloy_consensus::proofs::ordered_trie_root_encoded(&optional.transactions);
    app.engine().state().build_script.extend([Ok(minimum.block.clone()), Ok(optional)]);

    let bytes = minimum.encode();
    let mut req = prepare_req(next_height(&app), bft_time(&app));
    req.max_tx_bytes = i64::try_from(bytes.len()).unwrap();
    assert_eq!(prepare(&mut app, req).await, [bytes]);
    accept_and_commit(&mut app, &minimum).await;
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
    assert_eq!(refused(&mut app).await, "block_size_bound");

    let mut zeros = built;
    zeros.transactions.push(vec![0u8; 5_000_000].into());
    app.engine().state().build_script.push_back(Ok(zeros.clone()));
    assert_eq!(refused(&mut app).await, "block_size_bound");
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
async fn proposer_anchors_at_the_own_finalized_block() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let header = fx.advance_l1(app.l1(), 70, &fx.inbox);
    assert_eq!(app.l1().state().finalized, 70);

    let env = propose(&mut app).await;
    assert_eq!(env.anchor.as_ref().map(|w| &w.l1_header), Some(&header));
    let (resp, _) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
}

/// CONS-3.4-16: a finalized anchor whose proven `lastCheckpoint` does not name a block of the
/// local chain is never proposed, and the proposer does not keep producing on its parent's
/// anchor instead (16.d/16.g): it proposes nothing and raises an alert. A height above the
/// parent is one its chain has not reached, so its trust waits for it (catching up, 16.b); a
/// hash that differs at a height it holds contradicts finalized L1 and revokes its trust (16.c).
#[tokio::test]
async fn proposer_proposes_nothing_on_a_finalized_checkpoint_off_the_local_chain() {
    use crate::app::trust::TrustPhase;
    let fx = Fixture::genesis(1);
    for (inbox, phase, label) in [
        (fx.inbox_with(6), TrustPhase::CatchingUp, "checkpoint_above_parent"),
        (
            fx.inbox_at_checkpoint(3, B256::repeat_byte(0xc4)),
            TrustPhase::Halted,
            "checkpoint_conflict",
        ),
    ] {
        let dir = tempfile::tempdir().unwrap();
        let mut app = mid_epoch(&fx, dir.path(), 5).await;
        assert_eq!(app.state().unwrap().last_height, 5);
        fx.advance_l1(app.l1(), 66, &inbox);
        let logs = crate::test_utils::LogCapture::start();
        let req = prepare_req(next_height(&app), bft_time(&app));
        let txs = prepare(&mut app, req).await;
        assert!(txs.is_empty(), "{label}: a placeholder proposal");
        assert_eq!(app.halt.as_deref(), Some(label));
        assert!(
            logs.at("ERROR").iter().any(|line| line.contains(label)),
            "{label}: the refusal is an alert: {}",
            logs.text()
        );
        let snapshot = app.trust.snapshot();
        assert_eq!(snapshot.phase, phase, "{label}");
        assert_eq!(snapshot.eligible_height, None);
        assert_eq!(app.store.fatal_evidence().unwrap().is_some(), phase == TrustPhase::Halted);
    }
}

/// CONS-3.3-4 4.a/4.g, RECOV-8-5: once its own L1 node first shows a newer block as finalized,
/// the proposer may keep its parent's anchor for `anchor_hold`, so validators whose view is
/// slightly behind do not reject the proposal; validators accept that block. Then it moves to
/// the finalized block. It never holds an anchor that would leave the block stale (CONS-3.4-8).
#[tokio::test(start_paused = true)]
async fn proposer_holds_the_parent_anchor_briefly_after_finality_advances() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    app.opts.anchor_hold = Duration::from_secs(12);
    let parent_anchor = app.state().unwrap().anchor.number;
    let header = fx.advance_l1(app.l1(), 70, &fx.inbox);
    for wait in [0, 6, 5] {
        tokio::time::advance(Duration::from_secs(wait)).await;
        let env = propose(&mut app).await;
        assert!(env.anchor.is_none(), "{wait}: the parent's anchor is kept");
        assert_eq!(decode_extra_data(&env.block.header.extra_data).unwrap().anchor, parent_anchor);
        let other = tempfile::tempdir().unwrap();
        let mut validator = mid_epoch(&fx, other.path(), 5).await;
        validator.l1().set_finalized(parent_anchor);
        assert_eq!(judge(&mut validator, &env).await.0, response::ProcessProposal::Accept);
    }
    tokio::time::advance(Duration::from_secs(1)).await;
    let env = propose(&mut app).await;
    assert_eq!(env.anchor.map(|w| w.l1_header), Some(header));

    // A parent anchor too old for the next block is never held.
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    app.opts.anchor_hold = Duration::from_secs(12);
    set_anchor_age(&mut app, fx.genesis.max_anchor_age + 1);
    let header = fx.advance_l1(app.l1(), 66, &fx.inbox);
    let env = propose(&mut app).await;
    assert_eq!(env.anchor.map(|w| w.l1_header), Some(header));
}

/// CONS-3.3-4: the hold counts from the first time this node's own L1 showed a block above the
/// committed anchor as finalized, read by the trust worker on every node whether or not it
/// proposes, not from the node's first proposal on that anchor. A validator whose turn comes
/// more than `anchor_hold` after its own L1 showed the block moves the anchor at its first
/// proposal; one that saw it less than `anchor_hold` ago keeps the parent's anchor until
/// `anchor_hold` after that first sighting, which a later, higher finalized block does not
/// restart. (`proposer_holds_the_parent_anchor_briefly_after_finality_advances` covers a first
/// sighting inside `PrepareProposal`.)
#[tokio::test(start_paused = true)]
async fn the_anchor_hold_counts_from_the_own_l1_sighting_not_the_proposers_turn() {
    let fx = Fixture::genesis(1);
    let hold = Duration::from_secs(12);
    // A node past its generation's first block, whose committed anchor is L1_0.
    async fn after_first_block(
        fx: &Fixture,
        dir: &Path,
        hold: Duration,
    ) -> App<MockL1, MockEngine> {
        let mut app = initialized(fx, dir).await;
        step(&mut app).await;
        app.opts.anchor_hold = hold;
        app
    }
    let dir = tempfile::tempdir().unwrap();
    let mut app = after_first_block(&fx, dir.path(), hold).await;
    let header = fx.advance_l1(app.l1(), 70, &fx.inbox);
    app.l1().state().calls.clear();
    app.refresh_trust().await.unwrap();
    assert_eq!(app.l1().calls().first(), Some(&L1Call::Finalized), "the trust worker's read");
    tokio::time::advance(hold + Duration::from_secs(1)).await;
    let env = propose(&mut app).await;
    assert_eq!(env.anchor.map(|w| w.l1_header), Some(header), "the first proposal moves");

    let dir = tempfile::tempdir().unwrap();
    let mut app = after_first_block(&fx, dir.path(), hold).await;
    let parent_anchor = app.state().unwrap().anchor.number;
    fx.advance_l1(app.l1(), 70, &fx.inbox);
    app.refresh_trust().await.unwrap();
    tokio::time::advance(Duration::from_secs(5)).await;
    let later = fx.advance_l1(app.l1(), 80, &fx.inbox);
    for wait in [0, 6] {
        tokio::time::advance(Duration::from_secs(wait)).await;
        let env = propose(&mut app).await;
        assert!(env.anchor.is_none(), "{wait}: within the hold of the first sighting");
        assert_eq!(decode_extra_data(&env.block.header.extra_data).unwrap().anchor, parent_anchor);
    }
    tokio::time::advance(Duration::from_secs(1)).await;
    let env = propose(&mut app).await;
    assert_eq!(env.anchor.map(|w| w.l1_header), Some(later), "12 s after it, to the newest");
}

#[tokio::test]
async fn proposer_never_anchors_below_the_parent() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    fx.plant_l1_block(app.l1(), 66, &fx.inbox);
    let anchor = fx.anchor_state(app.l1(), 66);
    jump(&mut app, fx.genesis.genesis_height + 5, anchor);
    assert_eq!(app.l1().state().finalized, fx.genesis.l1_0, "own L1 lags behind");

    let env = propose(&mut app).await;
    assert!(env.anchor.is_none());
    assert_eq!(decode_extra_data(&env.block.header.extra_data).unwrap().anchor, 66);
    assert_eq!(
        app.l1().calls().last(),
        Some(&L1Call::Finalized),
        "only the finalized number is read"
    );
}

#[tokio::test]
async fn failing_pre_checks_propose_nothing() {
    let fx = Fixture::genesis(1);

    // Back-pressure: the checkpoint is a full unsettled limit behind the next height.
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), fx.params.unsettled_limit).await;
    assert_eq!(refused(&mut app).await, "back_pressure");
    assert!(app.engine().calls().iter().all(|c| !matches!(c, EngineCall::BuildBlock { .. })));

    // The finalized Inbox is not (or no longer) active.
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let mut inbox = fx.inbox.clone();
    inbox.status = 2;
    fx.advance_l1(app.l1(), 66, &inbox);
    assert!(propose(&mut app).await.anchor.is_some());
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
    let header = fx.advance_l1(app.l1(), 66, &fx.inbox);
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
    let header = fx.advance_l1(app.l1(), 66, &fx.inbox_with(1_003));
    let other = crate::test_utils::edit_l1_header(&header, |h| h.number = 67);
    app.l1().state().headers.insert(66, other);

    let req = prepare_req(next_height(&app), bft_time(&app));
    assert!(matches!(
        app.handle(Request::PrepareProposal(req)).await,
        Err(AbciError::SafetyHalt(_))
    ));
    assert!(app.store.fatal_evidence().unwrap().is_some());
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
    fx.advance_l1(app.l1(), 66, &inbox);

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

/// Independent header and proof reads share one bounded preparation window.
#[tokio::test(start_paused = true)]
async fn prepare_fetches_anchor_header_and_proof_concurrently() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    fx.advance_l1(app.l1(), 66, &fx.inbox);
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
    fx.advance_l1(app.l1(), 66, &inbox);
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

/// A failed or malformed pool selection, such as a reply the EL client cannot decode, costs the
/// mixed block its tail and nothing else: the forced transaction is proposed alone at position 0,
/// the node keeps running and validators accept the block.
#[tokio::test]
async fn failed_pool_selection_proposes_the_forced_transaction_alone() {
    let failures = [
        EngineError::BadReply("taikoAuth_txPoolContentWithMinTip: invalid reply".into()),
        EngineError::Transport("connection refused".into()),
        EngineError::ErrorReply { call: "pool".into(), code: -32601, message: "no".into() },
    ];
    for failure in failures {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = mid_epoch(&fx, dir.path(), 5).await;
        let txs = sample_transactions();
        let tx: Bytes = txs[0].encoded_2718().into();
        plant_input(&fx, &app, tx.clone(), true);
        app.engine().state().pool = vec![txs[1].clone()];
        app.engine().state().pool_script.push_back(Err(failure.clone()));
        let env = propose(&mut app).await;
        assert_eq!(env.block.transactions, [tx], "{failure}: the forced transaction alone");
        assert_eq!(app.halt, None, "{failure}");
        accept_and_commit(&mut app, &env).await;
        assert_eq!(app.state().unwrap().forced_cursor, 1, "{failure}: the entry is consumed");
    }
}

/// A due entry that governance recovery blanked (its txHash is `keccak256("")`) has empty raw
/// bytes: the proposer reads no admission log for it and skips it as ineligible, which
/// validators accept.
#[tokio::test]
async fn blanked_due_entry_is_skipped_without_reading_its_admission_log() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    plant_input(&fx, &app, Bytes::new(), true);
    {
        let mut l1 = app.l1().state();
        l1.forced_transactions.clear();
        l1.forced_transaction_fail = Some(L1Error::Rpc("no admission log".into()));
    }
    let env = propose(&mut app).await;
    assert!(
        !app.l1().calls().iter().any(|call| matches!(call, L1Call::ForcedTransaction { .. })),
        "no admission log is read"
    );
    assert_eq!(env.forced.as_ref().map(|w| (w.index, w.tx.is_empty())), Some((0, true)));
    assert!(built_tx_list(&app).is_none(), "an ordinary build");
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 1, "skipped as ineligible");
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
                let req = prepare_req(6, time);
                assert!(prepare(&mut app, req).await.is_empty());
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
async fn proposal_fallback_is_ready_before_optional_pre_due_admission() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let raw: Bytes = sample_transactions()[0].encoded_2718().into();
    plant_input(&fx, &app, raw, false);
    app.l1().state().forced_transaction_delay = Some(Duration::from_millis(2500));
    app.engine().state().delay_script.extend([Duration::ZERO, Duration::from_millis(1700)]);
    app.engine().state().ordinary_build_delay = Some(Duration::from_secs(3));

    let env = propose(&mut app).await;
    assert!(env.block.transactions.is_empty());
    assert!(env.forced.as_ref().unwrap().tx.is_empty());
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 0);
}

#[tokio::test(start_paused = true)]
async fn slow_pre_due_admission_read_leaves_time_for_ordinary_build_and_is_reused() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let raw: Bytes = sample_transactions()[0].encoded_2718().into();
    plant_input(&fx, &app, raw.clone(), false);
    app.l1().state().forced_transaction_delay = Some(Duration::from_millis(2500));
    app.engine().state().delay = Some(Duration::from_millis(500));
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
    let mut ordinary = super::proposal::hand_envelope(&app, anchor).block;
    let empty = ordinary.clone();
    ordinary.transactions = vec![sample_transactions()[1].encoded_2718().into()];
    ordinary.header.transactions_root =
        alloy_consensus::proofs::ordered_trie_root_encoded(&ordinary.transactions);
    app.engine().state().build_script.extend([
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
    assert_eq!(lists.len(), 2, "one singleton probe and one ordinary build");
    assert!(lists[0].is_some() && lists[1].is_none());
    assert!(
        calls.iter().all(|call| !matches!(call, EngineCall::PoolTransactions(_))),
        "a proven skip does not spend a mixed-selection budget"
    );
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
    // history. Use the landing payload's default zlib level and the genuine entry proof above.
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
        use std::io::Write;
        let mut encoder =
            flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
        encoder.write_all(&alloy_rlp::encode(vec![envelope.encode(); 4])).unwrap();
        encoder.finish().unwrap().len()
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
    use crate::test_utils::test_key;
    use alloy_primitives::Address;
    for recipient in [Address::ZERO, Address::repeat_byte(0x88)] {
        let mut spec = GenesisSpec::new(3);
        spec.params.fee_recipient = recipient;
        let fx = Fixture::build(spec);
        let dir = tempfile::tempdir().unwrap();
        let mut app = mid_epoch(&fx, dir.path(), 3).await;
        plant_due_entry(&fx, app.l1(), 70, fx.inbox_with(1));
        let env = propose(&mut app).await;
        assert_eq!(env.block.header.beneficiary, fx.params.fee_recipient);
        app.l1().state().calls.clear();
        let before = app.engine().calls().len();
        let mut req = prepare_req(next_height(&app), bft_time(&app));
        req.proposer_address = tendermint::account::Id::new(test_key(2).address().into_array());
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
        assert!(!builds.is_empty(), "even equal payout addresses require fresh builds");
        for build in builds {
            assert_eq!(build.payload_attributes.suggested_fee_recipient, recipient);
            assert_eq!(build.block_metadata.beneficiary, recipient);
        }
        assert!(
            app.l1().calls().iter().all(|call| match call {
                L1Call::ForcedTransaction { .. } => false,
                L1Call::AccountWitness { address, slots, .. } =>
                    *address != fx.params.inbox ||
                        *slots != crate::l1::layout::inbox::forced_inclusion_entry_slots(0),
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
    use crate::test_utils::test_key;
    use alloy_primitives::Address;
    let mut spec = GenesisSpec::new(3);
    spec.params.fee_recipient = Address::repeat_byte(0x88);
    let fx = Fixture::build(spec);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 3).await;
    let old = propose(&mut app).await;
    assert_eq!(old.block.header.beneficiary, fx.params.fee_recipient);
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
    req.proposer_address = tendermint::account::Id::new(test_key(2).address().into_array());
    let txs = prepare(&mut app, req).await;
    assert_eq!(txs.len(), 1);
    let env = EtnaEnvelope::decode(&txs[0]).unwrap();
    assert_eq!(env.block.header.beneficiary, Address::repeat_byte(0x88));
    assert_eq!(env.block.transactions[0], sample_transactions()[0].encoded_2718());
    assert!(
        app.l1().calls().iter().all(|call| match call {
            L1Call::ForcedTransaction { .. } => false,
            L1Call::AccountWitness { address, slots, .. } =>
                *address != fx.params.inbox ||
                    *slots != crate::l1::layout::inbox::forced_inclusion_entry_slots(0),
            _ => true,
        }),
        "the new proposer reuses only authenticated raw reads: {:?}",
        app.l1().calls()
    );
}

#[tokio::test]
async fn review_own_l1_invalid_mpt_proof_halts_durably() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    app.refresh_trust().await.unwrap();
    assert!(app.trust.snapshot().is_ready());
    fx.advance_l1(app.l1(), 66, &fx.inbox);
    let mut proof = fx.anchor_witness(app.l1(), 66).inbox;
    proof.storage[0].value += alloy_primitives::U256::from(1);
    app.l1().state().proof_override = Some(proof);
    let request = prepare_req(next_height(&app), bft_time(&app));
    let result = app.handle(Request::PrepareProposal(request)).await;
    assert!(matches!(result, Err(AbciError::SafetyHalt(_))), "{result:?}");
    assert!(!app.trust.snapshot().is_ready());
    assert!(app.store.fatal_evidence().unwrap().is_some());
    assert!(matches!(
        App::new(
            fx.l1(),
            fx.engine(),
            fx.params.clone(),
            app.store.clone(),
            crate::test_utils::test_options()
        ),
        Err(AbciError::SafetyHalt(_))
    ));
}

/// Slow optional pool execution must not turn every consensus round into a placeholder.
#[tokio::test(start_paused = true)]
async fn slow_pool_build_falls_back_to_a_valid_empty_execution_envelope() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    app.engine().state().ordinary_build_delay = Some(Duration::from_millis(2500));
    let started = tokio::time::Instant::now();
    let req = prepare_req(6, bft_time(&app));
    let txs = prepare(&mut app, req).await;
    assert_eq!(txs.len(), 1, "resource pressure must still yield an execution envelope");
    assert!(started.elapsed() <= app.opts.prepare_timeout);
    let env = EtnaEnvelope::decode(&txs[0]).unwrap();
    assert!(env.block.transactions.is_empty());
    app.engine().state().ordinary_build_delay = None;
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().last_height, 6);
}

/// The optional forced-first pool tail cannot consume the budget for mandatory inclusion.
#[tokio::test(start_paused = true)]
async fn slow_forced_pool_selection_falls_back_to_a_valid_singleton() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let tx = Bytes::from(sample_transactions()[0].encoded_2718());
    plant_input(&fx, &app, tx.clone(), true);
    app.engine().state().pool_selection_delay = Some(Duration::from_millis(2500));
    let started = tokio::time::Instant::now();
    let req = prepare_req(6, bft_time(&app));
    let txs = prepare(&mut app, req).await;
    assert_eq!(txs.len(), 1, "optional work must not starve due forced inclusion");
    assert!(started.elapsed() <= app.opts.prepare_timeout);
    let env = EtnaEnvelope::decode(&txs[0]).unwrap();
    assert_eq!(env.block.transactions, [tx]);
    app.engine().state().pool_selection_delay = None;
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 1);
}

/// A legal singleton skip remains available even when the ordinary pool build never finishes.
#[tokio::test(start_paused = true)]
async fn slow_pool_after_a_legal_skip_returns_the_completed_singleton() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let tx = Bytes::from(sample_transactions()[0].encoded_2718());
    plant_input(&fx, &app, tx.clone(), true);
    let anchor = Some(fx.anchor_witness(app.l1(), 66));
    let empty = super::proposal::hand_envelope(&app, anchor).block;
    app.engine().state().build_script.extend([Ok(empty.clone()), Ok(empty)]);
    app.engine().state().ordinary_build_delay = Some(Duration::from_millis(2500));
    let started = tokio::time::Instant::now();
    let req = prepare_req(6, bft_time(&app));
    let txs = prepare(&mut app, req).await;
    assert_eq!(txs.len(), 1, "a completed legal skip must survive optional build timeout");
    assert!(started.elapsed() <= app.opts.prepare_timeout);
    let env = EtnaEnvelope::decode(&txs[0]).unwrap();
    assert!(env.block.transactions.is_empty());
    assert_eq!(env.forced.as_ref().unwrap().tx, tx);
    app.engine().state().ordinary_build_delay = None;
    accept_and_commit(&mut app, &env).await;
    assert_eq!(app.state().unwrap().forced_cursor, 1);
}
