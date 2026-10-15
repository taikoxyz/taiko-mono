//! `ProcessProposal`: every rejection, and its effect on `/status`.

use std::time::Duration;

use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes, U256};

use super::{
    proposal::{
        MAX_TX_BYTES, bft_time, decide, hand_envelope, hand_forced_envelope, incompressible, judge,
        jump, mid_epoch, next_height, plant_due_entry, prepare, prepare_req, process, process_req,
        propose, rejected, sample_tx_list, set_anchor_age, validate, with_extra_transaction,
    },
    *,
};
use crate::{
    app::validate::{Rejection, WitnessKind, check_landing_capacity},
    compression::{HEADER_ALLOWANCE, MAX_BLOCK_LANDING_BYTES, zlib_compress},
    engine::{EngineError, PayloadVerdict},
    envelope::{EnvelopeError, EtnaEnvelope},
    forced::ForcedError,
    l1::L1Error,
    rules::{RuleViolation, encode_extra_data},
    test_utils::{edit_l1_header, sample_transactions},
};

/// One in-place header mutation.
type Mutation = dyn Fn(&mut Header);

/// A mid-epoch app (next height plain) and the valid envelope it proposes for that height.
async fn plain(fx: &Fixture, dir: &Path) -> (App<MockL1, MockEngine>, EtnaEnvelope) {
    let mut app = mid_epoch(fx, dir, 5).await;
    let env = propose(&mut app).await;
    assert!(env.anchor.is_none() && env.committee.is_none());
    (app, env)
}

/// Expects `env` to fail validation on `field` and to be rejected as `header_field`.
async fn assert_header_field(app: &mut App<MockL1, MockEngine>, env: &EtnaEnvelope, field: &str) {
    match validate(app, env) {
        Err(Rejection::Rule(RuleViolation::HeaderField { field: got, .. })) => {
            assert_eq!(got, field)
        }
        other => panic!("{field}: {other:?}"),
    }
    assert_eq!(rejected(app, env).await, "header_field", "{field}");
}

#[tokio::test]
async fn transaction_count_and_garbage_are_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = plain(&fx, dir.path()).await;
    let (h, t) = (next_height(&app), bft_time(&app));

    let cases: [(Vec<Bytes>, &str, &str); 4] = [
        (vec![], "zero txs", "empty_proposal"),
        (vec![env.encode(), env.encode()], "two txs", "envelope"),
        (vec![Bytes::from_static(&[0x01, 0xff, 0x00])], "garbage", "envelope"),
        (vec![Bytes::from_static(&[0x02, 0xc0])], "wrong version", "envelope"),
    ];
    for (txs, case, label) in cases {
        let resp = process(&mut app, process_req(h, t, txs)).await;
        assert_eq!(resp, response::ProcessProposal::Reject, "{case}");
        assert_eq!(app.halt.as_deref(), Some(label), "{case}");
    }
    let txs = vec![env.encode()];
    let resp = process(&mut app, process_req(h, t, txs.clone())).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "the untouched envelope passes");
    assert_eq!(app.halt, None, "an accepted proposal clears the halt reason");
    assert_eq!(
        crate::envelope::single_envelope(&[]),
        Err(EnvelopeError::TxCount(0)),
        "zero txs is the envelope's tx-count error"
    );
}

/// A halted proposer proposes no block; rejecting that empty proposal must not mask
/// the reason this node recorded at the height, which `/status` reports.
#[tokio::test]
async fn empty_proposal_keeps_the_recorded_halt_reason() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let (h, t) = (next_height(&app), bft_time(&app));
    let reject = response::ProcessProposal::Reject;

    // Nothing recorded yet: the empty proposal itself is the reason.
    assert_eq!(process(&mut app, process_req(h, t, vec![])).await, reject);
    assert_eq!(app.status().unwrap().halt_reason.as_deref(), Some("empty_proposal"));

    // The node's own build fails, so it proposes nothing; judging that empty proposal keeps the
    // build's reason.
    app.l1().state().fail = Some(L1Error::Rpc("down".into()));
    assert!(prepare(&mut app, prepare_req(h, t)).await.is_empty());
    assert_eq!(app.halt.as_deref(), Some("l1_error"));
    assert_eq!(process(&mut app, process_req(h, t, vec![])).await, reject);
    assert_eq!(app.status().unwrap().halt_reason.as_deref(), Some("l1_error"));

    // A malformed, non-empty proposal is news and replaces it.
    let garbage = vec![Bytes::from_static(&[0x01, 0xff, 0x00])];
    assert_eq!(process(&mut app, process_req(h, t, garbage)).await, reject);
    assert_eq!(app.halt.as_deref(), Some("envelope"));
}

#[tokio::test]
async fn wrong_height_number_and_parent_are_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = plain(&fx, dir.path()).await;

    // The request names another height than the committed head's successor.
    let req = process_req(next_height(&app) + 1, bft_time(&app), vec![env.encode()]);
    assert_eq!(process(&mut app, req).await, response::ProcessProposal::Reject);
    assert_eq!(app.halt.as_deref(), Some("height_mismatch"));

    let mut bad = env.clone();
    bad.block.header.number += 1;
    assert_header_field(&mut app, &bad, "number").await;

    let mut bad = env.clone();
    bad.block.header.parent_hash = B256::repeat_byte(0x13);
    assert_header_field(&mut app, &bad, "parent_hash").await;
}

#[tokio::test]
async fn every_derived_header_field_is_checked() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = plain(&fx, dir.path()).await;
    let pctg = |h: &mut Header| {
        let mut extra = h.extra_data.to_vec();
        extra[0] = 99; // basefeeSharingPctg
        h.extra_data = extra.into();
    };
    let mutations: [(&str, &Mutation); 7] = [
        ("timestamp", &|h| h.timestamp += 1),
        ("extra_data", &pctg),
        ("beneficiary", &|h| h.beneficiary = Address::repeat_byte(0x42)),
        ("gas_limit", &|h| h.gas_limit += 1),
        ("base_fee_per_gas", &|h| h.base_fee_per_gas = h.base_fee_per_gas.map(|f| f + 1)),
        ("mix_hash", &|h| h.mix_hash = B256::repeat_byte(0x43)),
        ("parent_beacon_block_root", &|h| h.parent_beacon_block_root = Some(B256::ZERO)),
    ];
    for (field, mutate) in mutations {
        let mut bad = env.clone();
        mutate(&mut bad.block.header);
        assert_header_field(&mut app, &bad, field).await;
    }
}

#[tokio::test]
async fn generation_mismatch_is_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = plain(&fx, dir.path()).await;
    let mut bad = env.clone();
    bad.block.header.extra_data = encode_extra_data(1, fx.genesis.l1_0).unwrap();
    assert_eq!(
        validate(&app, &bad),
        Err(Rejection::Rule(RuleViolation::GenerationMismatch { chain: 0, extra: 1 }))
    );
    assert_eq!(rejected(&mut app, &bad).await, "generation_mismatch");
    assert!(!app.superseded);
}

#[tokio::test]
async fn anchor_regression_is_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    fx.advance_l1(app.l1(), 66, &fx.inbox, &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 66);
    jump(&mut app, fx.genesis.genesis_height + 5, anchor, &[]);

    let witness = fx.anchor_witness(app.l1(), fx.genesis.l1_0);
    let env = hand_envelope(&app, Some(witness), None);
    assert_eq!(
        validate(&app, &env).map(|_| ()),
        Err(Rejection::Rule(RuleViolation::AnchorRegressed { parent: 66, anchor: 64 }))
    );
    assert_eq!(rejected(&mut app, &env).await, "anchor_regressed");
}

#[tokio::test]
async fn anchor_not_final_is_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    fx.plant_l1_block(app.l1(), 66, &fx.inbox, &fx.registry); // canonical, not finalized
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66)), None);
    assert!(validate(&app, &env).is_ok(), "deterministically valid");
    assert_eq!(rejected(&mut app, &env).await, "anchor_not_final");

    // Final but not canonical: the own L1 holds another block 66.
    let mut other = fx.anchor_witness(app.l1(), 66);
    app.l1().set_finalized(66);
    other.l1_header = edit_l1_header(&other.l1_header, |h| h.gas_used += 1);
    app.l1().insert_header(other.l1_header.clone());
    assert_eq!(rejected(&mut app, &env).await, "anchor_not_final");
}

#[tokio::test]
async fn wrong_inbox_proof_is_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(1_002), &fx.registry);
    let env = propose(&mut app).await;

    let mut bad = env.clone();
    let w = bad.anchor.as_mut().expect("the anchor moved");
    w.inbox.storage[2].value += U256::from(1); // lastCheckpoint.height
    assert!(matches!(validate(&app, &bad), Err(Rejection::Witness(_))));
    assert_eq!(rejected(&mut app, &bad).await, "anchor_witness");

    // A witness of another account.
    let mut bad = env.clone();
    bad.anchor.as_mut().unwrap().inbox.address = fx.params.registry;
    assert_eq!(rejected(&mut app, &bad).await, "anchor_witness");
}

#[tokio::test]
async fn missing_required_witnesses_are_rejected() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();

    // H_0 requires both witnesses.
    let mut app = initialized(&fx, dir.path()).await;
    let env = propose(&mut app).await;
    let mut bad = env.clone();
    bad.anchor = None;
    assert_eq!(
        validate(&app, &bad).map(|_| ()),
        Err(Rejection::MissingWitness(WitnessKind::Anchor))
    );
    assert_eq!(rejected(&mut app, &bad).await, "missing_anchor_witness");
    let switch = fx.schedule().h_first(1) - 2;
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(switch - 7), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 66);
    super::proposal::jump(&mut app, switch - 1, anchor, &[]);
    let mut bad = propose(&mut app).await;
    bad.committee = None;
    assert_eq!(rejected(&mut app, &bad).await, "missing_committee_witness");

    // A moved anchor (per extraData) requires its witness.
    let other_dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, other_dir.path(), 5).await;
    fx.advance_l1(app.l1(), 66, &fx.inbox, &fx.registry);
    let mut bad = propose(&mut app).await;
    bad.anchor = None;
    assert_eq!(rejected(&mut app, &bad).await, "missing_anchor_witness");
}

#[tokio::test]
async fn unexpected_witnesses_are_rejected() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = plain(&fx, dir.path()).await;

    // An anchor witness that does not move the anchor, at a height that does not force one.
    let mut bad = env.clone();
    bad.anchor = Some(fx.anchor_witness(app.l1(), fx.genesis.l1_0));
    assert_eq!(rejected(&mut app, &bad).await, "unexpected_anchor_witness");

    let mut bad = env.clone();
    bad.committee = Some(fx.witness.committee.clone());
    assert_eq!(
        validate(&app, &bad).map(|_| ()),
        Err(Rejection::UnexpectedWitness(WitnessKind::Committee))
    );
    assert_eq!(rejected(&mut app, &bad).await, "unexpected_committee_witness");
}

/// HALT-03: `H − lastCheckpoint.height ≤ D_MAX − MARGIN_V`, inclusive.
#[tokio::test]
async fn back_pressure_boundary() {
    let fx = Fixture::genesis(1);
    let cap = fx.params.unsettled_cap();
    let dir = tempfile::tempdir().unwrap();

    // Depth exactly the cap (the anchored last checkpoint is B*).
    let mut app = mid_epoch(&fx, dir.path(), cap - 1).await;
    assert_eq!(next_height(&app) - fx.genesis.genesis_height, cap);
    let env = propose(&mut app).await;
    let (resp, _) = super::proposal::judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);

    // One more is over the cap.
    let other_dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, other_dir.path(), cap).await;
    let env = hand_envelope(&app, None, None);
    assert_eq!(
        validate(&app, &env).map(|_| ()),
        Err(Rejection::Rule(RuleViolation::BackPressure { depth: cap + 1, cap }))
    );
    assert_eq!(rejected(&mut app, &env).await, "back_pressure");
}

/// Anchor freshness, inclusive: the derived timestamp is at most `maxAnchorAge` after the
/// anchor's.
#[tokio::test]
async fn stale_anchor_proposal_is_rejected() {
    let fx = Fixture::genesis(1);
    let max = fx.genesis.max_anchor_age;
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;

    // Exactly the maximum age.
    set_anchor_age(&mut app, max);
    let env = hand_envelope(&app, None, None);
    let (resp, _) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);

    // One second older: every header field is derived, but the anchor is stale.
    set_anchor_age(&mut app, max + 1);
    let env = hand_envelope(&app, None, None);
    assert_eq!(
        validate(&app, &env).map(|_| ()),
        Err(Rejection::Rule(RuleViolation::AnchorTooOld { age: max + 1, max }))
    );
    assert_eq!(rejected(&mut app, &env).await, "anchor_too_old");
}

/// An entry due at the block's anchor must be consumed: an ordinary block, with no forced
/// witness or with a peek, is rejected as `forced_inclusion`; the block consuming it is accepted.
#[tokio::test]
async fn ordinary_block_skipping_a_due_entry_is_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let blob = plant_due_entry(&fx, app.l1(), 66, fx.inbox.clone());
    let ordinary = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66)), None);

    assert_eq!(
        validate(&app, &ordinary).map(|_| ()),
        Err(Rejection::Forced(ForcedError::MissingWitness { index: 0 }))
    );
    assert_eq!(rejected(&mut app, &ordinary).await, "forced_inclusion");

    let mut peek = ordinary.clone();
    peek.forced = Some(fx.forced_witness(app.l1(), 66, 0, blob.clone()));
    assert!(matches!(
        validate(&app, &peek).unwrap().decision,
        crate::forced::ForcedDecision::NeedsSkip { .. }
    ));
    assert_eq!(rejected(&mut app, &peek).await, "forced_skip_invalid");

    let witness = fx.forced_witness(app.l1(), 66, 0, blob);
    let forced = hand_forced_envelope(&app, ordinary.anchor, None, witness, sample_tx_list());
    assert_eq!(
        validate(&app, &forced).unwrap().decision,
        crate::forced::ForcedDecision::Included(0)
    );
    let (resp, _) = judge(&mut app, &forced).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
}

/// A mid-epoch app whose own L1 finalized block 66 holding one due entry, and the forced block
/// an honest proposer builds consuming it, anchored at 66.
async fn forced_block(fx: &Fixture, dir: &Path) -> (App<MockL1, MockEngine>, EtnaEnvelope) {
    let app = mid_epoch(fx, dir, 5).await;
    let blob = plant_due_entry(fx, app.l1(), 66, fx.inbox.clone());
    let anchor = Some(fx.anchor_witness(app.l1(), 66));
    let witness = fx.forced_witness(app.l1(), 66, 0, blob);
    let env = hand_forced_envelope(&app, anchor, None, witness, sample_tx_list());
    (app, env)
}

/// The EL rebuilds a forced inclusion block on the committed parent from the consumed entry's
/// transaction list, with the derived header's attributes; a proposed block equal to the rebuild
/// is then executed and accepted.
#[tokio::test]
async fn process_accepts_a_forced_block_equal_to_the_rebuild() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = forced_block(&fx, dir.path()).await;
    assert_eq!(env.block.transactions.len(), sample_transactions().len());

    let before = app.engine().calls().len();
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);

    let calls = app.engine().calls()[before..].to_vec();
    assert!(
        matches!(calls.as_slice(), [EngineCall::NewPayload(_)]),
        "included transaction requires no singleton build: {calls:?}"
    );
    let v = app.verdicts.get(&req.hash).expect("the verdict is cached");
    assert_eq!(v.forced, Some(0));
    assert!(v.executed);
}

/// Mixed inclusion permits an ordinary tail and requires no singleton probe.
#[tokio::test]
async fn process_accepts_a_forced_block_with_an_extra_transaction() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, honest) = forced_block(&fx, dir.path()).await;
    let env = with_extra_transaction(honest);
    let before = app.engine().calls().len();
    let (resp, _) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept);
    assert!(matches!(&app.engine().calls()[before..], [EngineCall::NewPayload(_)]));
}

/// While the queue's next entry is pending but not due, ordinary blocks peek it (its proof with an
/// empty blob) and are accepted; one without the peek is rejected.
#[tokio::test]
async fn pending_entry_is_peeked_by_ordinary_blocks() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let mut inbox = fx.inbox.clone();
    inbox.forced_inclusion_tail = 1;
    inbox.forced_inclusion_queue = vec![crate::forced::ForcedEntry {
        index: 0,
        fee_in_gwei: 7,
        tx_hash: alloy_primitives::keccak256([]),
        l1_block: 66,
        // One second short of due at block 66.
        timestamp: Fixture::l1_timestamp(66) - fx.genesis.forced_inclusion_delay + 1,
    }];
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    let mut env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66)), None);
    assert_eq!(rejected(&mut app, &env).await, "forced_inclusion");

    env.forced = Some(fx.forced_witness(app.l1(), 66, 0, Bytes::new()));
    assert_eq!(validate(&app, &env).map(|v| v.forced), Ok(None), "a peek consumes nothing");
    let (resp, _) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
}

/// A block whose compressed envelope cannot fit one landing is refused before L1 and the EL are
/// asked; it is a liveness guard only, so the same block, once decided, still commits.
#[tokio::test]
async fn process_rejects_a_block_that_cannot_fit_one_landing() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, mut env) = plain(&fx, dir.path()).await;
    env.block.transactions.push(incompressible(800_000));
    assert!(validate(&app, &env).is_ok(), "deterministically valid");
    let encoded = env.encode();
    assert!(i64::try_from(encoded.len()).unwrap() < MAX_TX_BYTES, "fits CometBFT's tx limit");
    assert_eq!(
        check_landing_capacity(&encoded),
        Err(Rejection::LandingCapacity {
            bytes: zlib_compress(&encoded).len() + HEADER_ALLOWANCE,
            max: MAX_BLOCK_LANDING_BYTES,
        })
    );

    let engine_calls = app.engine().calls().len();
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Reject);
    assert_eq!(app.halt.as_deref(), Some("landing_capacity"));
    assert_eq!(app.engine().calls().len(), engine_calls, "the EL is not asked");
    assert!(app.verdicts.is_empty());

    // FinalizeBlock does not re-check it.
    decide(&mut app, &req).await;
    assert_eq!(app.state().unwrap().parent.hash, env.block.header.hash_slow());
}

/// 5 MB of zero calldata is far beyond one landing uncompressed, but compresses under the bound.
#[tokio::test]
async fn process_accepts_a_zero_heavy_block() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, mut env) = plain(&fx, dir.path()).await;
    env.block.transactions.push(Bytes::from(vec![0u8; 5_000_000]));
    assert!(env.encode().len() > MAX_BLOCK_LANDING_BYTES);
    let (resp, _) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
}

#[tokio::test]
async fn superseded_generation_rejects_every_proposal() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let valid = propose(&mut app).await;
    let mut inbox = fx.inbox.clone();
    inbox.recovery_generation = 1;
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);

    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66)), None);
    assert_eq!(validate(&app, &env).map(|_| ()), Err(Rejection::Superseded { chain: 0, inbox: 1 }));
    assert_eq!(rejected(&mut app, &env).await, "superseded");
    assert!(app.superseded);
    let status = app.status().unwrap();
    assert!(status.superseded);
    assert_eq!(status.halt_reason.as_deref(), Some("superseded"));

    // From now on even a valid block is refused, without any I/O.
    app.l1().state().calls.clear();
    let engine_calls = app.engine().calls().len();
    assert_eq!(rejected(&mut app, &valid).await, "superseded");
    assert!(app.l1().calls().is_empty());
    assert_eq!(app.engine().calls().len(), engine_calls);
}

/// A forged (non-final) L1 header claiming a later generation must not supersede the chain.
#[tokio::test]
async fn superseding_anchor_must_be_final() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let mut inbox = fx.inbox.clone();
    inbox.recovery_generation = 1;
    fx.plant_l1_block(app.l1(), 66, &inbox, &fx.registry);

    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66)), None);
    assert_eq!(rejected(&mut app, &env).await, "anchor_not_final");
    assert!(!app.superseded);
}

#[tokio::test]
async fn execution_failures_are_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = plain(&fx, dir.path()).await;
    let scripts = [
        (Ok(PayloadVerdict::Invalid("bad state root".into())), "payload_invalid"),
        (Ok(PayloadVerdict::Syncing), "payload_syncing"),
        (Err(EngineError::Transport("connection refused".into())), "engine_error"),
    ];
    for (script, label) in scripts {
        app.engine().state().new_payload_script.push_back(script);
        assert_eq!(rejected(&mut app, &env).await, label);
    }
    assert!(app.verdicts.is_empty(), "nothing rejected is cached");
}

#[tokio::test(start_paused = true)]
async fn engine_timeout_is_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (mut app, env) = plain(&fx, dir.path()).await;
    app.engine().state().delay = Some(app.opts.engine_timeout + Duration::from_secs(1));
    assert_eq!(rejected(&mut app, &env).await, "timeout");
}

#[tokio::test(start_paused = true)]
async fn l1_timeout_is_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    fx.advance_l1(app.l1(), 66, &fx.inbox, &fx.registry);
    let env = propose(&mut app).await;
    assert!(env.anchor.is_some());
    app.l1().state().delay = Some(app.opts.l1_timeout + Duration::from_secs(1));
    assert_eq!(rejected(&mut app, &env).await, "timeout");

    app.l1().state().delay = None;
    app.l1().state().fail = Some(L1Error::Rpc("down".into()));
    assert_eq!(rejected(&mut app, &env).await, "l1_error");
}

#[tokio::test]
async fn proposals_before_init_chain_are_errors() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    let req = process_req(1_001, 0, vec![]);
    let err = app.handle(Request::ProcessProposal(req)).await.expect_err("not initialized");
    assert!(matches!(err, AbciError::Uninitialized("ProcessProposal")), "{err:?}");
    let req = super::proposal::prepare_req(1_001, 0);
    let err = app.handle(Request::PrepareProposal(req)).await.expect_err("not initialized");
    assert!(matches!(err, AbciError::Uninitialized("PrepareProposal")), "{err:?}");
}

#[tokio::test]
async fn same_sender_nonce_replacement_and_later_position_cannot_skip_retained_forced_tx() {
    use alloy_consensus::{SignableTransaction, TxEnvelope, TxLegacy};
    use alloy_eips::eip2718::Encodable2718;
    let signer = protocol::signer::FixedKSigner::golden_touch().unwrap();
    let signed = |price| {
        let tx = TxLegacy {
            chain_id: Some(167001),
            nonce: 0,
            gas_limit: 21000,
            gas_price: price,
            ..Default::default()
        };
        let signature = signer.sign_with_predefined_k(&tx.signature_hash().0).unwrap().signature;
        TxEnvelope::Legacy(tx.into_signed(signature))
    };
    let forced = signed(100);
    let replacement = signed(200);
    for later in [false, true] {
        let fx = Fixture::genesis(1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = mid_epoch(&fx, dir.path(), 5).await;
        let due = Fixture::l1_timestamp(66) - fx.genesis.forced_inclusion_delay;
        let tx = super::proposal::plant_entries(
            &fx,
            app.l1(),
            66,
            fx.inbox.clone(),
            vec![(due, vec![forced.clone()])],
        )
        .remove(0);
        let witness = fx.forced_witness(app.l1(), 66, 0, tx);
        let mut txs = vec![replacement.clone()];
        if later {
            txs.push(forced.clone());
        }
        let env = hand_forced_envelope(
            &app,
            Some(fx.anchor_witness(app.l1(), 66)),
            None,
            witness,
            protocol::shasta::encode_transactions(&txs),
        );
        let before = app.engine().calls().len();
        assert_eq!(rejected(&mut app, &env).await, "forced_skip_invalid");
        assert!(matches!(&app.engine().calls()[before..], [EngineCall::BuildBlock { .. }]));
        assert_eq!(app.state().unwrap().forced_cursor, 0);
        assert_ne!(env.block.transactions[0], forced.encoded_2718());
    }
}
