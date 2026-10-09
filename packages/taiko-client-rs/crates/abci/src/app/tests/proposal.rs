//! `PrepareProposal` → `ProcessProposal` round trips (spec §5.3, §5.4), and the helpers the
//! proposal tests share: requests, crafted committed states and hand-built envelopes.

use alloy_primitives::{B256, Bytes, keccak256};
use tendermint::{
    Hash, Time,
    abci::types::CommitInfo,
    account,
    block::{Height, Round},
};

use super::*;
use crate::{
    app::validate::{self, Rejection, Validated},
    committee::record_hash,
    envelope::{AnchorWitness, CommitteeWitness, EtnaEnvelope},
    l1::{layout::registry, verify_anchor_witness},
    rules,
    store::CommitteeState,
    test_utils::{GenesisSpec, L1Call, RegistryStorage, sample_entries, simple_block},
    types::{AnchorState, ParentInfo},
};

/// CometBFT's default `max_tx_bytes` for the fixture's `block.max_bytes`.
pub(super) const MAX_TX_BYTES: i64 = 22_020_096;

/// A `PrepareProposal` request for `height` at BFT time `time` (Unix seconds).
pub(super) fn prepare_req(height: u64, time: u64) -> request::PrepareProposal {
    request::PrepareProposal {
        max_tx_bytes: MAX_TX_BYTES,
        txs: vec![],
        local_last_commit: None,
        misbehavior: vec![],
        height: Height::try_from(height).unwrap(),
        time: Time::from_unix_timestamp(i64::try_from(time).unwrap(), 0).unwrap(),
        next_validators_hash: Hash::None,
        proposer_address: account::Id::new([1; 20]),
    }
}

/// A `ProcessProposal` request for `txs` at `height` and BFT time `time`; its block hash is
/// derived from the height and the transactions.
pub(super) fn process_req(height: u64, time: u64, txs: Vec<Bytes>) -> request::ProcessProposal {
    let mut preimage = height.to_be_bytes().to_vec();
    for tx in &txs {
        preimage.extend_from_slice(tx);
    }
    request::ProcessProposal {
        txs: txs.into_iter().map(|tx| tx.0).collect(),
        proposed_last_commit: None,
        misbehavior: vec![],
        hash: Hash::Sha256(keccak256(preimage).0),
        height: Height::try_from(height).unwrap(),
        time: Time::from_unix_timestamp(i64::try_from(time).unwrap(), 0).unwrap(),
        next_validators_hash: Hash::None,
        proposer_address: account::Id::new([2; 20]),
    }
}

/// Sends `PrepareProposal` through [`App::handle`] and returns its transactions.
pub(super) async fn prepare(
    app: &mut App<MockL1, MockEngine>,
    req: request::PrepareProposal,
) -> Vec<Bytes> {
    match app.handle(Request::PrepareProposal(req)).await.expect("PrepareProposal never fails") {
        Response::PrepareProposal(r) => r.txs.into_iter().map(Bytes::from).collect(),
        other => panic!("PrepareProposal answered {other:?}"),
    }
}

/// Sends `ProcessProposal` through [`App::handle`].
pub(super) async fn process(
    app: &mut App<MockL1, MockEngine>,
    req: request::ProcessProposal,
) -> response::ProcessProposal {
    match app.handle(Request::ProcessProposal(req)).await.expect("ProcessProposal never fails") {
        Response::ProcessProposal(r) => r,
        other => panic!("ProcessProposal answered {other:?}"),
    }
}

/// The BFT time the tests propose with: two seconds after the committed parent.
pub(super) fn bft_time(app: &App<MockL1, MockEngine>) -> u64 {
    app.state().expect("initialized").parent.timestamp + 2
}

/// The next height of `app`.
pub(super) fn next_height(app: &App<MockL1, MockEngine>) -> u64 {
    app.state().expect("initialized").last_height + 1
}

/// Prepares the next height and returns its envelope (exactly one transaction).
pub(super) async fn propose(app: &mut App<MockL1, MockEngine>) -> EtnaEnvelope {
    let txs = prepare(app, prepare_req(next_height(app), bft_time(app))).await;
    assert_eq!(txs.len(), 1, "one envelope; halt = {:?}", app.halt);
    EtnaEnvelope::decode(&txs[0]).expect("the envelope decodes")
}

/// Processes `env` as the next height; returns the response and the request (for its hash).
pub(super) async fn judge(
    app: &mut App<MockL1, MockEngine>,
    env: &EtnaEnvelope,
) -> (response::ProcessProposal, request::ProcessProposal) {
    let req = process_req(next_height(app), bft_time(app), vec![env.encode()]);
    (process(app, req.clone()).await, req)
}

/// Processes `env` as the next height, expects `REJECT` and returns the recorded halt label.
pub(super) async fn rejected(app: &mut App<MockL1, MockEngine>, env: &EtnaEnvelope) -> String {
    let (resp, _) = judge(app, env).await;
    assert_eq!(resp, response::ProcessProposal::Reject);
    app.halt.clone().expect("a rejection records its label")
}

/// Runs the deterministic validation of `env` as the next height.
pub(super) fn validate(
    app: &App<MockL1, MockEngine>,
    env: &EtnaEnvelope,
) -> Result<Validated, Rejection> {
    let state = app.state().expect("initialized");
    validate::validate_block(state, &app.params, env, next_height(app), bft_time(app))
}

/// The `FinalizeBlock` request CometBFT sends once the block `p` proposed is decided.
pub(super) fn finalize_req(p: &request::ProcessProposal) -> request::FinalizeBlock {
    request::FinalizeBlock {
        txs: p.txs.clone(),
        decided_last_commit: CommitInfo { round: Round::default(), votes: vec![] },
        misbehavior: vec![],
        hash: p.hash,
        height: p.height,
        time: p.time,
        next_validators_hash: p.next_validators_hash,
        proposer_address: p.proposer_address,
    }
}

/// Sends `FinalizeBlock` through [`App::handle`].
pub(super) async fn finalize(
    app: &mut App<MockL1, MockEngine>,
    req: request::FinalizeBlock,
) -> Result<response::FinalizeBlock, AbciError> {
    match app.handle(Request::FinalizeBlock(req)).await? {
        Response::FinalizeBlock(r) => Ok(r),
        other => panic!("FinalizeBlock answered {other:?}"),
    }
}

/// Sends `Commit` through [`App::handle`].
pub(super) async fn commit(
    app: &mut App<MockL1, MockEngine>,
) -> Result<response::Commit, AbciError> {
    match app.handle(Request::Commit).await? {
        Response::Commit(r) => Ok(r),
        other => panic!("Commit answered {other:?}"),
    }
}

/// Finalizes and commits the block `p` proposed; returns the `FinalizeBlock` response.
pub(super) async fn decide(
    app: &mut App<MockL1, MockEngine>,
    p: &request::ProcessProposal,
) -> response::FinalizeBlock {
    let resp = finalize(app, finalize_req(p)).await.expect("FinalizeBlock succeeds");
    commit(app).await.expect("Commit succeeds");
    resp
}

/// Prepares, accepts, finalizes and commits the next height; returns its envelope.
pub(super) async fn step(app: &mut App<MockL1, MockEngine>) -> EtnaEnvelope {
    let env = propose(app).await;
    let (resp, req) = judge(app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    decide(app, &req).await;
    env
}

/// Moves the committed state to height `last` with a synthetic parent block, `anchor` as the
/// committed anchor, and `committees` added to the known ones.
pub(super) fn jump(
    app: &mut App<MockL1, MockEngine>,
    last: u64,
    anchor: AnchorState,
    committees: &[(u64, CommitteeState)],
) {
    let state = app.state.as_mut().expect("initialized");
    let offset = last - state.activation.genesis_height;
    let timestamp = state.parent.timestamp + 2 * offset;
    state.parent = ParentInfo {
        number: last,
        hash: keccak256(last.to_be_bytes()),
        timestamp,
        grandparent_timestamp: timestamp - 2,
        ..state.parent.clone()
    };
    state.last_height = last;
    state.anchor = anchor;
    state.committees.extend(committees.iter().cloned());
}

/// An initialized app whose committed head sits `offset` heights after `B*`, anchored at the
/// genesis L1 block (last checkpoint `B*`). With `offset` in 1..=9 the next height is a plain
/// height: no witness required, back-pressure satisfied.
pub(super) async fn mid_epoch(fx: &Fixture, dir: &Path, offset: u64) -> App<MockL1, MockEngine> {
    let mut app = initialized(fx, dir).await;
    let anchor = fx.anchor_state(app.l1(), fx.activation.l1_0, None);
    jump(&mut app, fx.activation.genesis_height + offset, anchor, &[]);
    app
}

/// The envelope an honest proposer would build for the next height with these witnesses: the
/// header derived for the witnessed (or inherited) anchor, built by [`simple_block`].
pub(super) fn hand_envelope(
    app: &App<MockL1, MockEngine>,
    anchor: Option<AnchorWitness>,
    committee: Option<CommitteeWitness>,
) -> EtnaEnvelope {
    let state = app.state().expect("initialized");
    let height = next_height(app);
    let anchor_state = match &anchor {
        Some(w) => verify_anchor_witness(w, app.params.inbox, state.schedule.switch_target(height))
            .expect("the hand-built anchor witness verifies"),
        None => state.anchor.clone(),
    };
    let expected =
        validate::expected_header(state, &app.params, height, &anchor_state, bft_time(app))
            .expect("derivable header");
    let attrs = rules::payload_attributes(&expected, anchor_state.hash);
    EtnaEnvelope { block: simple_block(state.parent.hash, &attrs), anchor, committee }
}

#[tokio::test]
async fn round_trip_at_h0_carries_the_anchor_and_committee_witnesses() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h0 = fx.activation.genesis_height + 1;
    assert_eq!(next_height(&app), h0);

    let env = propose(&mut app).await;
    let anchor = env.anchor.as_ref().expect("H_0 carries an anchor witness");
    assert_eq!(anchor.l1_header, fx.witness.l1_header, "anchored at the finalized L1_0");
    let committee = env.committee.as_ref().expect("H_0 = h_first(e_0) carries a committee");
    assert_eq!(committee.record.target_epoch, 1);
    assert_eq!(committee.entries, sample_entries(3));
    assert_eq!(env.block.header.number, h0);
    assert_eq!(env.block.header.parent_hash, fx.genesis_hash());

    // An independent validator accepts it too.
    let other_dir = tempfile::tempdir().unwrap();
    let mut validator = initialized(&fx, other_dir.path()).await;
    let (resp, req) = judge(&mut validator, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", validator.halt);
    let v = validator.verdicts.get(&req.hash).expect("the verdict is cached");
    assert!(v.executed);
    assert_eq!(v.block, env.block);
    assert_eq!(v.anchor.number, fx.activation.l1_0, "H_0 re-proves the genesis anchor L1_0");
    let (target, derived) = v.derived.as_ref().expect("committee 1 is derived");
    assert_eq!(*target, 1);
    assert_eq!(derived.record, committee.record);
    assert_eq!(derived.members, fx.members, "same snapshot, same members");
    assert_eq!(derived, &fx.committee(1));
    assert!(
        validator.engine().calls().contains(&EngineCall::NewPayload(env.block.header.hash_slow()))
    );

    let (resp, _) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept);
    assert_eq!(app.halt, None);
}

#[tokio::test]
async fn round_trips_through_a_plain_height_and_an_anchor_change() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    step(&mut app).await; // H_0

    // A plain height: the finalized L1 block has not moved, so no witness at all.
    let env = propose(&mut app).await;
    assert_eq!((env.anchor.is_none(), env.committee.is_none()), (true, true));
    app.l1().state().calls.clear();
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    assert!(app.l1().calls().is_empty(), "no witness, no L1 call");
    let anchor_before = app.state().unwrap().anchor.clone();
    assert_eq!(app.verdicts[&req.hash].anchor, anchor_before);
    decide(&mut app, &req).await;

    // L1 finalizes block 66, where the checkpoint has advanced: the anchor moves.
    let inbox = fx.inbox_with(fx.activation.genesis_height + 1, &[]);
    let header = fx.advance_l1(app.l1(), 66, &inbox, &fx.registry);
    let env = propose(&mut app).await;
    let anchor = env.anchor.as_ref().expect("a moved anchor carries its witness");
    assert_eq!(anchor.l1_header, header);
    assert!(env.committee.is_none());
    let (_, _, extra_anchor) = rules::decode_extra_data(&env.block.header.extra_data).unwrap();
    assert_eq!(extra_anchor, 66);
    assert_eq!(env.block.header.parent_beacon_block_root, Some(header.state_root()));

    app.l1().state().calls.clear();
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    assert_eq!(app.l1().calls(), [L1Call::Finalized, L1Call::CanonicalHash(66)], "finality check");
    let v = &app.verdicts[&req.hash];
    assert_eq!(v.anchor.number, 66);
    assert_eq!(v.anchor.inbox.last_checkpoint_height, fx.activation.genesis_height + 1);
    decide(&mut app, &req).await;
    assert_eq!(app.state().unwrap().anchor.number, 66);
}

/// At `h_first(1)` the committee of epoch 2 is derived from the registry snapshot at the
/// parent's anchor: the last checkpoint at or before the cutoff, with its own entries.
#[tokio::test]
async fn round_trip_at_an_epoch_start_derives_the_next_committee() {
    let mut spec = GenesisSpec::new(3);
    spec.params.cutoff_grid = 4;
    let fx = Fixture::build(spec);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let schedule = app.state().unwrap().schedule;
    let h_e = schedule.h_first(1);

    // Checkpoints at L1 blocks 64 (genesis), 66 (a fourth validator joins) and 69 (a fifth).
    // Only blocks 68 (the newest block still holding checkpoint 1's entries) and 70 (the
    // anchor) are served: discovery needs no older state.
    let l1_0 = fx.activation.l1_0;
    let at_66 =
        RegistryStorage { checkpoints: vec![(l1_0, sample_entries(3)), (66, sample_entries(4))] };
    let mut at_70 = at_66.clone();
    at_70.checkpoints.push((69, sample_entries(5)));
    let c1 = fx.committee(1);
    let inbox = fx.inbox_with(h_e - 6, &[(1, record_hash(fx.params.l2_chain_id, &c1.record))]);
    fx.plant_l1_block(app.l1(), 68, &inbox, &at_66);
    fx.advance_l1(app.l1(), 70, &inbox, &at_70);
    let anchor = fx.anchor_state(app.l1(), 70, None);
    jump(&mut app, h_e - 1, anchor, &[(1, c1)]);

    let env = propose(&mut app).await;
    assert!(env.anchor.is_none(), "the anchor stays at 70");
    let committee = env.committee.as_ref().expect("h_first(1) carries a committee");
    // Cutoff 4·floor(70 / 4) = 68: checkpoint 1 (block 66) is the last one at or before it.
    assert_eq!(committee.record.target_epoch, 2);
    assert_eq!(committee.record.cutoff_l1_block, 68);
    assert_eq!(committee.record.checkpoint_index, 1);
    assert_eq!(committee.entries, sample_entries(4));
    assert_eq!(committee.registry.storage.len(), 4, "checkpoint 2 (block 69) is proven too");
    let entry_slots: Vec<B256> = (0..4).flat_map(registry::entry_slots).collect();
    let entry_reads: Vec<L1Call> = app
        .l1()
        .calls()
        .into_iter()
        .filter(|c| matches!(c, L1Call::AccountWitness { block: 68, .. }))
        .collect();
    assert_eq!(
        entry_reads,
        [L1Call::AccountWitness { address: fx.params.registry, slots: entry_slots, block: 68 }],
        "all entries in one read, at min(n_p, checkpoints[2].l1Block - 1) = 68"
    );
    assert!(app.l1().calls().contains(&L1Call::StorageAt {
        address: fx.params.registry,
        slot: registry::length_slot(),
        block: 70,
    }));

    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    let (target, derived) = app.verdicts[&req.hash].derived.clone().expect("derived");
    assert_eq!(target, 2);
    assert_eq!(derived.record, committee.record);
    assert_eq!(derived.members.len(), 4);
}

/// At the switch height `h_first(1) − 2` the anchor witness proves `committee[1]`; the landed
/// record lets the block through.
#[tokio::test]
async fn round_trip_at_a_switch_height_with_the_landed_record() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let switch = app.state().unwrap().schedule.h_first(1) - 2;
    let c1 = fx.committee(1);
    let landed = fx.inbox_with(switch - 7, &[(1, record_hash(fx.params.l2_chain_id, &c1.record))]);

    // The anchor moves to the landing block.
    let genesis_anchor = fx.anchor_state(app.l1(), fx.activation.l1_0, None);
    jump(&mut app, switch - 1, genesis_anchor, &[(1, c1.clone())]);
    fx.advance_l1(app.l1(), 66, &landed, &fx.registry);
    let env = propose(&mut app).await;
    let anchor = env.anchor.as_ref().expect("a switch height carries an anchor witness");
    assert_eq!(anchor.inbox.storage.len(), 5, "committee[1] is proven");
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    assert_eq!(
        app.verdicts[&req.hash].anchor.inbox.committee,
        Some((1, record_hash(fx.params.l2_chain_id, &c1.record)))
    );

    // The witness is forced even when the anchor does not move.
    let landed_anchor = fx.anchor_state(app.l1(), 66, None);
    jump(&mut app, switch - 1, landed_anchor, &[]);
    let env = propose(&mut app).await;
    assert_eq!(env.anchor.as_ref().map(|w| w.l1_header.number()), Some(66));
    let (resp, _) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
}

/// D19: without `committee[1]` on L1 the switch height cannot be built nor accepted. The record
/// has not landed yet: a wait, not a conflict.
#[tokio::test]
async fn switch_height_without_the_landed_record_halts() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let switch = app.state().unwrap().schedule.h_first(1) - 2;
    let genesis_anchor = fx.anchor_state(app.l1(), fx.activation.l1_0, None);
    jump(&mut app, switch - 1, genesis_anchor, &[(1, fx.committee(1))]);
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(switch - 7, &[]), &fx.registry);

    let time = bft_time(&app);
    let txs = prepare(&mut app, prepare_req(switch, time)).await;
    assert!(txs.is_empty());
    assert_eq!(app.halt.as_deref(), Some("record_not_landed"));

    let witness = fx.anchor_witness(app.l1(), 66, Some(1));
    let env = hand_envelope(&app, Some(witness), None);
    assert_eq!(rejected(&mut app, &env).await, "record_not_landed");
    assert_eq!(validate(&app, &env).map(|_| ()), Err(Rejection::RecordNotLanded { epoch: 1 }));
}

/// Spec §8.2: a different non-zero `committee[1]` on L1 means L1 and the chain hold two records
/// for epoch 1. The switch height is refused as `record_conflict` (logged at ERROR, as an
/// operator must investigate), never accepted; refusing stays a liveness matter.
#[tokio::test]
async fn switch_height_with_a_conflicting_record_is_rejected() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let switch = app.state().unwrap().schedule.h_first(1) - 2;
    let c1 = fx.committee(1);
    let genesis_anchor = fx.anchor_state(app.l1(), fx.activation.l1_0, None);
    jump(&mut app, switch - 1, genesis_anchor, &[(1, c1.clone())]);
    let other = B256::repeat_byte(0xc1);
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(switch - 7, &[(1, other)]), &fx.registry);

    let time = bft_time(&app);
    assert!(prepare(&mut app, prepare_req(switch, time)).await.is_empty());
    assert_eq!(app.halt.as_deref(), Some("record_conflict"));

    let witness = fx.anchor_witness(app.l1(), 66, Some(1));
    let env = hand_envelope(&app, Some(witness), None);
    assert_eq!(rejected(&mut app, &env).await, "record_conflict");
    let expected = record_hash(fx.params.l2_chain_id, &c1.record);
    let conflict = || Rejection::RecordConflict { epoch: 1, expected, proven: other };
    assert_eq!(validate(&app, &env).map(|_| ()), Err(conflict()));
    assert!(conflict().logs_at_error(), "a conflict is logged at ERROR");
    assert!(!Rejection::RecordNotLanded { epoch: 1 }.logs_at_error(), "a wait is a WARN");
}
