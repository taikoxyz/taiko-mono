//! `ProcessProposal` (spec §5.4): every rejection, and its effect on `/status`.

use std::time::Duration;

use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes, U256};

use super::{
    proposal::{
        bft_time, hand_envelope, jump, mid_epoch, next_height, prepare, prepare_req, process,
        process_req, propose, rejected, validate,
    },
    *,
};
use crate::{
    app::validate::{Rejection, WitnessKind},
    engine::{EngineError, PayloadVerdict},
    envelope::{EnvelopeError, EtnaEnvelope},
    l1::L1Error,
    rules::{RuleViolation, encode_extra_data},
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

/// A halted proposer proposes no block (spec §5.3); rejecting that empty proposal must not mask
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
    bad.block.header.extra_data = encode_extra_data(1, fx.activation.l1_0).unwrap();
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
    let anchor = fx.anchor_state(app.l1(), 66, None);
    jump(&mut app, fx.activation.genesis_height + 5, anchor, &[]);

    let witness = fx.anchor_witness(app.l1(), fx.activation.l1_0, None);
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
    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66, None)), None);
    assert!(validate(&app, &env).is_ok(), "deterministically valid");
    assert_eq!(rejected(&mut app, &env).await, "anchor_not_final");

    // Final but not canonical: the own L1 holds another block 66.
    let mut other = fx.anchor_witness(app.l1(), 66, None);
    app.l1().set_finalized(66);
    other.l1_header.gas_used += 1;
    app.l1().insert_header(other.l1_header.clone());
    assert_eq!(rejected(&mut app, &env).await, "anchor_not_final");
}

#[tokio::test]
async fn wrong_inbox_proof_is_rejected() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(1_002, &[]), &fx.registry);
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
    let mut bad = env.clone();
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
    bad.anchor = Some(fx.anchor_witness(app.l1(), fx.activation.l1_0, None));
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
    assert_eq!(next_height(&app) - fx.activation.genesis_height, cap);
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

#[tokio::test]
async fn superseded_generation_rejects_every_proposal() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let valid = propose(&mut app).await;
    let mut inbox = fx.inbox.clone();
    inbox.recovery_generation = 1;
    fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);

    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66, None)), None);
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

    let env = hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66, None)), None);
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
