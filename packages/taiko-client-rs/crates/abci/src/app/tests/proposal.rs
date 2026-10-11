//! `PrepareProposal` → `ProcessProposal` round trips, and the helpers the
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
    let offset = last - state.genesis.genesis_height;
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
    let anchor = fx.anchor_state(app.l1(), fx.genesis.l1_0);
    jump(&mut app, fx.genesis.genesis_height + offset, anchor, &[]);
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
        Some(w) => verify_anchor_witness(w, app.params.inbox)
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
async fn round_trip_at_h0_carries_only_the_anchor_witness() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h0 = fx.genesis.genesis_height + 1;
    assert_eq!(next_height(&app), h0);

    let env = propose(&mut app).await;
    let anchor = env.anchor.as_ref().expect("H_0 carries an anchor witness");
    assert_eq!(anchor.l1_header, fx.witness.l1_header, "anchored at the finalized L1_0");
    assert!(env.committee.is_none());
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
    assert_eq!(v.anchor.number, fx.genesis.l1_0, "H_0 re-proves the genesis anchor L1_0");
    assert!(v.derived.is_none());
    assert!(
        validator.engine().calls().contains(&EngineCall::NewPayload(env.block.header.hash_slow()))
    );

    let (resp, _) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept);
    assert_eq!(app.halt, None);
}

/// A `genesisCutoff` above the genesis anchor's lagged cutoff does not halt the chain at `H_0`:
/// under `L1_0 = 64`, lag 5, grid 1, genesis cutoff 63 and entries active from L1 block 62,
/// `InitChain` derives `e_0` at 63, and `H_0` derives `e_0 + 1` at the floored cutoff
/// `max(cutoff(64) = 59, 63) = 63` (at 59 no entry would be active). Proposer and validator
/// agree on it.
#[tokio::test]
async fn switch_derives_the_next_committee_at_the_floored_genesis_cutoff() {
    let fx = Fixture::build(GenesisSpec::active_after_lagged_l1_0_cutoff(2));
    let genesis_cutoff = fx.genesis.genesis_cutoff;
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let e0 = app.state().expect("initialized").committees[&0].clone();
    assert_eq!(e0.record.cutoff_l1_block, genesis_cutoff);
    assert_eq!(e0.members.len(), 2);

    let switch = fx.schedule().h_first(1) - 2;
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(switch - 7), &fx.registry);
    let parent = fx.anchor_state(app.l1(), 66);
    jump(&mut app, switch - 1, parent.clone(), &[]);
    let env = propose(&mut app).await;
    let committee = env.committee.as_ref().expect("H(1)-2 carries the incoming committee");
    assert_eq!(committee.record.target_epoch, 1);
    assert_eq!(committee.record.cutoff_l1_block, genesis_cutoff);
    assert_eq!(committee.record.checkpoint_index, 0);

    let other_dir = tempfile::tempdir().unwrap();
    let mut validator = initialized(&fx, other_dir.path()).await;
    fx.advance_l1(validator.l1(), 66, &fx.inbox_with(switch - 7), &fx.registry);
    jump(&mut validator, switch - 1, parent, &[]);
    let (resp, req) = judge(&mut validator, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", validator.halt);
    let (target, derived) = validator
        .verdicts
        .get(&req.hash)
        .expect("the verdict is cached")
        .derived
        .clone()
        .expect("committee 1 is derived");
    assert_eq!(target, 1);
    assert_eq!(derived.record, committee.record);
    assert_eq!(derived, fx.committee(1));
    assert_eq!(derived.members, e0.members, "same snapshot, same members");

    decide(&mut validator, &req).await;
    let state = validator.state().expect("committed");
    assert_eq!(state.last_height, switch);
    assert_eq!(state.committees[&1], derived);
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
    assert_eq!(app.verdicts.get(&req.hash).expect("the verdict is cached").anchor, anchor_before);
    decide(&mut app, &req).await;

    // L1 finalizes block 66, where the checkpoint has advanced: the anchor moves.
    let inbox = fx.inbox_with(fx.genesis.genesis_height + 1);
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
    let v = app.verdicts.get(&req.hash).expect("the verdict is cached");
    assert_eq!(v.anchor.number, 66);
    assert_eq!(v.anchor.inbox.last_checkpoint_height, fx.genesis.genesis_height + 1);
    decide(&mut app, &req).await;
    assert_eq!(app.state().unwrap().anchor.number, 66);
}

/// Switch 4 derives at fixed cutoff 68 and authenticates checkpoint 1 plus its successor under
/// the unchanged parent anchor 70. Discovery reads the complete historical entries at 68.
#[tokio::test]
async fn round_trip_at_a_switch_derives_the_fixed_cutoff_committee() {
    let mut spec = GenesisSpec::new(3);
    spec.params.cutoff_grid = 4;
    spec.epoch_len_l1 = 2;
    let fx = Fixture::build(spec);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let schedule = app.state().unwrap().schedule();
    let h_e = schedule.h_first(4) - 2;

    // Checkpoints at L1 blocks 64 (genesis), 66 (a fourth validator joins) and 69 (a fifth).
    // Only blocks 68 (the newest block still holding checkpoint 1's entries) and 70 (the
    // anchor) are served: discovery needs no older state.
    let l1_0 = fx.genesis.l1_0;
    let at_66 =
        RegistryStorage { checkpoints: vec![(l1_0, sample_entries(3)), (66, sample_entries(4))] };
    let mut at_70 = at_66.clone();
    at_70.checkpoints.push((69, sample_entries(5)));
    let c3 = fx.committee(3);
    let inbox = fx.inbox_with(h_e - 6);
    fx.plant_l1_block(app.l1(), 68, &inbox, &at_66);
    fx.advance_l1(app.l1(), 70, &inbox, &at_70);
    let anchor = fx.anchor_state(app.l1(), 70);
    jump(&mut app, h_e - 1, anchor, &[(3, c3)]);

    let env = propose(&mut app).await;
    assert!(env.anchor.is_none(), "the anchor stays at 70");
    let committee = env.committee.as_ref().expect("switch 4 carries a committee");
    // Fixed cutoff 4·floor((64 + (4-2)*2) / 4) = 68: checkpoint 1 (block 66) is the last one at or
    // before it.
    assert_eq!(committee.record.target_epoch, 4);
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
    let (target, derived) = app
        .verdicts
        .get(&req.hash)
        .expect("the verdict is cached")
        .derived
        .clone()
        .expect("derived");
    assert_eq!(target, 4);
    assert_eq!(derived.record, committee.record);
    assert_eq!(derived.members.len(), 4);
}

#[tokio::test]
async fn committee_is_required_only_at_switch_without_l1_publication() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h0 = propose(&mut app).await;
    assert!(h0.committee.is_none(), "H0 needs no runtime committee witness");
    let switch = fx.schedule().h_first(1) - 2;
    fx.advance_l1(app.l1(), 66, &fx.inbox_with(switch - 7), &fx.registry);
    let anchor = fx.anchor_state(app.l1(), 66);
    jump(&mut app, switch - 1, anchor, &[]);
    let env = propose(&mut app).await;
    assert!(env.anchor.is_none(), "switch does not force a stationary anchor proof");
    assert_eq!(env.committee.as_ref().unwrap().record.target_epoch, 1);
    assert!(validate(&app, &env).is_ok());
    let mut missing = env.clone();
    missing.committee = None;
    assert_eq!(
        validate(&app, &missing).map(|_| ()),
        Err(Rejection::MissingWitness(validate::WitnessKind::Committee))
    );
}

#[tokio::test]
async fn restart_rejects_a_changed_committee_config_opening() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let _app = initialized(&fx, dir.path()).await;
    let mut params = fx.params.clone();
    params.n_max += 1;
    assert!(matches!(
        App::new(
            fx.l1(),
            fx.engine(),
            params,
            Store::new(dir.path().to_path_buf()),
            AppOptions::default()
        ),
        Err(AbciError::StoredState(_))
    ));
}

#[tokio::test]
async fn epoch_first_height_forbids_a_runtime_committee_witness() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let h = fx.schedule().h_first(1);
    fx.advance_l1(app.l1(), 68, &fx.inbox_with(h - 7), &fx.registry);
    let parent = fx.anchor_state(app.l1(), 68);
    jump(&mut app, h - 1, parent, &[(1, fx.committee(1))]);
    let mut env = propose(&mut app).await;
    assert!(env.committee.is_none());
    env.committee = Some(fx.witness.committee.clone());
    assert_eq!(
        validate(&app, &env).map(|_| ()),
        Err(Rejection::UnexpectedWitness(validate::WitnessKind::Committee))
    );
}
