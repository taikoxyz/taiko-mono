//! `PrepareProposal` → `ProcessProposal` round trips, and the helpers the
//! proposal tests share: requests, crafted committed states and hand-built envelopes.

use alloy_consensus::{
    SignableTransaction, TxEnvelope, TxLegacy, proofs::ordered_trie_root_encoded,
};
use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{Address, B256, Bytes, Signature, TxKind, U256, keccak256};
use tendermint::{
    Hash, Time,
    abci::types::CommitInfo,
    account,
    block::{Height, Round},
};

use super::*;
use crate::{
    app::validate::{self, Rejection, Validated},
    envelope::{AnchorWitness, CommitteeWitness, EtnaEnvelope, ForcedWitness},
    forced::{ForcedEntry, ForcedError},
    l1::{layout::registry, verify_anchor_witness},
    rules,
    store::CommitteeState,
    test_utils::{
        GenesisSpec, InboxStorage, L1Call, RegistryStorage, sample_entries, sample_transactions,
        simple_block,
    },
    types::{AnchorState, ParentInfo},
};

/// CometBFT's default `max_tx_bytes` for the fixture's `block.max_bytes`.
pub(super) const MAX_TX_BYTES: i64 = 22_020_096;

/// The authenticated first fixture registry key's CometBFT address.
pub(super) fn proposer() -> account::Id {
    account::Id::new(sample_entries(1)[0].consensus_key().unwrap().address().into_array())
}

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
        proposer_address: proposer(),
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
        proposer_address: proposer(),
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
    validate::validate_block(state, &app.params, env, next_height(app), bft_time(app), proposer())
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

/// Moves the committed parent's timestamp so that the next height's derived timestamp, at
/// [`bft_time`] (two seconds after the parent), is `age` seconds after the committed anchor's.
pub(super) fn set_anchor_age(app: &mut App<MockL1, MockEngine>, age: u64) {
    let state = app.state.as_mut().expect("initialized");
    state.parent.timestamp = state.anchor.timestamp + age - 2;
}

/// `len` deterministic bytes zlib cannot compress: a keccak256 chain.
pub(super) fn incompressible(len: usize) -> Bytes {
    let mut out = Vec::with_capacity(len + 32);
    let mut word = B256::ZERO;
    while out.len() < len {
        word = keccak256(word);
        out.extend_from_slice(word.as_slice());
    }
    out.truncate(len);
    out.into()
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
    hand_built(app, anchor, committee, None)
}

/// The forced inclusion block an honest proposer would build for the next height: as
/// [`hand_envelope`], carrying `forced`, with the EL building from `tx_list` (the consumed
/// entry's transaction list).
pub(super) fn hand_forced_envelope(
    app: &App<MockL1, MockEngine>,
    anchor: Option<AnchorWitness>,
    committee: Option<CommitteeWitness>,
    forced: ForcedWitness,
    tx_list: Bytes,
) -> EtnaEnvelope {
    EtnaEnvelope { forced: Some(forced), ..hand_built(app, anchor, committee, Some(tx_list)) }
}

/// The envelope of [`hand_envelope`] without a forced witness, its block built by
/// [`simple_block`] from `tx_list` when given.
fn hand_built(
    app: &App<MockL1, MockEngine>,
    anchor: Option<AnchorWitness>,
    committee: Option<CommitteeWitness>,
    tx_list: Option<Bytes>,
) -> EtnaEnvelope {
    let state = app.state().expect("initialized");
    let height = next_height(app);
    let anchor_state = match &anchor {
        Some(w) => verify_anchor_witness(w, app.params.inbox)
            .expect("the hand-built anchor witness verifies"),
        None => state.anchor.clone(),
    };
    let expected = validate::expected_header(
        state,
        &app.params,
        height,
        &anchor_state,
        bft_time(app),
        proposer(),
    )
    .expect("derivable header");
    let attrs = rules::payload_attributes(&expected, anchor_state.hash, tx_list);
    EtnaEnvelope { block: simple_block(state.parent.hash, &attrs), anchor, committee, forced: None }
}

/// The EL transaction list of the entry [`plant_due_entry`] plants: [`sample_transactions`].
pub(super) fn sample_tx_list() -> Bytes {
    protocol::shasta::encode_transactions(&sample_transactions())
}

/// `env` with one more signed transaction appended to its block and the header's transactions
/// root recomputed, so the block stays well-formed: a proposer slipping its own transaction into
/// a forced inclusion block.
pub(super) fn with_extra_transaction(mut env: EtnaEnvelope) -> EtnaEnvelope {
    let extra = TxLegacy {
        chain_id: Some(167_001),
        nonce: 9,
        gas_price: 1_000_000_000,
        gas_limit: 21_000,
        to: TxKind::Call(Address::repeat_byte(0x33)),
        value: U256::from(1),
        input: Bytes::new(),
    }
    .into_signed(Signature::new(U256::from(1), U256::from(1), false));
    let block = &mut env.block;
    block.transactions.push(TxEnvelope::Legacy(extra).encoded_2718().into());
    block.header.transactions_root = ordered_trie_root_encoded(&block.transactions);
    env
}

/// Plants `inbox` as the finalized L1 block `number` of `l1`, its forced inclusion queue holding
/// one entry (index 0, tail 1) submitted `forcedInclusionDelay` before that block, so the entry
/// is due at an anchor there. The entry's blob codes a one-block manifest of
/// [`sample_transactions`] and the fixture's blob source serves it; returns the blob.
pub(super) fn plant_due_entry(
    fx: &Fixture,
    l1: &MockL1,
    number: u64,
    inbox: InboxStorage,
) -> Bytes {
    let due = Fixture::l1_timestamp(number) - fx.genesis.forced_inclusion_delay;
    plant_entries(fx, l1, number, inbox, vec![(due, sample_transactions())]).remove(0)
}

/// Plants `inbox` as the finalized L1 block `number` of `l1`, with one queue entry per
/// `(timestamp, transactions)` (indices from 0, tail = their count). Each entry commits the first
/// transaction's exact canonical bytes, or empty bytes for an empty list. The mock L1 serves those
/// admission bytes; returns them in entry order.
pub(super) fn plant_entries(
    fx: &Fixture,
    l1: &MockL1,
    number: u64,
    mut inbox: InboxStorage,
    entries: Vec<(u64, Vec<TxEnvelope>)>,
) -> Vec<Bytes> {
    let mut blobs = Vec::with_capacity(entries.len());
    for (index, (timestamp, transactions)) in (0..).zip(entries) {
        let blob: Bytes =
            transactions.first().map(|tx| tx.encoded_2718().into()).unwrap_or_default();
        let tx_hash = keccak256(&blob);
        l1.state().forced_transactions.insert((fx.params.inbox, index, number), blob.clone());
        inbox.forced_inclusion_queue.push(ForcedEntry {
            index,
            tx_hash,
            l1_block: number,
            timestamp,
        });
        blobs.push(blob);
    }
    inbox.forced_inclusion_tail = inbox.forced_inclusion_queue.len() as u64;
    fx.advance_l1(l1, number, &inbox, &fx.registry);
    blobs
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

/// Genesis remains at explicit snapshot 63 while the runtime switch derives at parent 66.
/// Both select the same entries, and proposer and validator agree on the runtime record.
#[tokio::test]
async fn switch_derives_the_next_committee_at_the_committed_parent() {
    let fx = Fixture::build(GenesisSpec::eligible_at_explicit_genesis_snapshot(2));
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
    assert_eq!(committee.record.cutoff_l1_block, 66);
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
    assert_eq!(derived.record.cutoff_l1_block, 66);
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

/// Switch 4 derives at parent 70 and authenticates the latest checkpoint (69) and all entries.
#[tokio::test]
async fn round_trip_at_a_switch_derives_the_parent_snapshot_committee() {
    let fx = Fixture::genesis(3);
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
    // The parent snapshot 70 selects the latest registry checkpoint at 69.
    assert_eq!(committee.record.target_epoch, 4);
    assert_eq!(committee.record.cutoff_l1_block, 70);
    assert_eq!(committee.record.checkpoint_index, 2);
    assert_eq!(committee.entries, sample_entries(5));
    assert_eq!(committee.registry.storage.len(), 3, "latest checkpoint needs no successor");
    let entry_slots: Vec<B256> = (0..5).flat_map(registry::entry_slots).collect();
    let entry_reads: Vec<L1Call> = app
        .l1()
        .calls()
        .into_iter()
        .filter(|c| matches!(c, L1Call::AccountWitness { slots, block: 70, .. } if slots == &entry_slots))
        .collect();
    assert_eq!(
        entry_reads,
        [L1Call::AccountWitness { address: fx.params.registry, slots: entry_slots, block: 70 }],
        "all latest entries in one read at parent 70"
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
    assert_eq!(derived.members.len(), 5);
}

/// Review Focus 1: a forced inclusion block at the switch height `H(t)-2` carries both the
/// committee and the forced witness; both are required and both must verify.
#[tokio::test]
async fn switch_height_forced_block_carries_both_witnesses() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let switch = fx.schedule().h_first(1) - 2;
    let blob = plant_due_entry(&fx, app.l1(), 66, fx.inbox_with(switch - 7));
    let parent = fx.anchor_state(app.l1(), 66);
    jump(&mut app, switch - 1, parent, &[]);

    // The proposer builds the honest forced block with both witnesses.
    let proposed = propose(&mut app).await;
    assert!(proposed.anchor.is_none(), "the anchor stays at 66");
    assert_eq!(proposed.committee.as_ref().unwrap().record.target_epoch, 1);
    let forced = fx.forced_witness(app.l1(), 66, 0, blob);
    let env =
        hand_forced_envelope(&app, None, proposed.committee.clone(), forced, sample_tx_list());
    let mut expected = env.forced.clone();
    expected.as_mut().unwrap().tx = Bytes::new();
    assert_eq!(proposed.forced, expected);

    let v = validate(&app, &env).expect("both witnesses verify");
    assert_eq!(v.decision, crate::forced::ForcedDecision::Included(0));
    assert_eq!(v.derived.as_ref().map(|(target, _)| *target), Some(1));

    let mut missing = env.clone();
    missing.committee = None;
    assert_eq!(
        validate(&app, &missing).map(|_| ()),
        Err(Rejection::MissingWitness(validate::WitnessKind::Committee))
    );
    let mut bad_committee = env.clone();
    bad_committee.committee.as_mut().unwrap().record.total_power += 1;
    assert!(matches!(validate(&app, &bad_committee), Err(Rejection::Committee(_))));
    let mut bad_forced = env.clone();
    bad_forced.forced.as_mut().unwrap().entry.storage[0].value += U256::from(1);
    assert!(matches!(validate(&app, &bad_forced), Err(Rejection::Forced(ForcedError::Entry(_)))));

    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    decide(&mut app, &req).await;
    let state = app.state().expect("committed");
    assert_eq!(state.last_height, switch);
    assert_eq!(state.forced_cursor, 1);
    assert_eq!(state.committees[&1], v.derived.unwrap().1);
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
            Store::volatile(dir.path().to_path_buf()),
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

#[test]
fn persisted_fixed_cutoff_config_is_rejected_without_migration() {
    let mut spec = GenesisSpec::new(2);
    spec.params.registry = alloy_primitives::Address::repeat_byte(0x22);
    spec.params.unsettled_limit = 36;
    let fx = Fixture::build(spec);
    let mut state = fx.expected_state();
    // Independent ethers eleven-word vector: same remaining fields, old grid10/lag20.
    state.genesis.committee_config_hash =
        alloy_primitives::b256!("af72a8cac328b7a82ec9c449fb39aecc89a196de580f512cc40f0e1d8a6ad2fa");
    let dir = tempfile::tempdir().unwrap();
    let store = Store::volatile(dir.path().to_path_buf());
    store.save(&state).unwrap();
    let file = dir.path().join(crate::store::STATE_FILE);
    let before = std::fs::read(&file).unwrap();
    let result = App::new(fx.l1(), fx.engine(), fx.params.clone(), store, AppOptions::default());
    assert!(matches!(result, Err(AbciError::StoredState(_))));
    assert_eq!(std::fs::read(file).unwrap(), before);
}

/// No handler may accept a proposer outside the authenticated committee.
#[tokio::test]
async fn proposal_unknown_certified_proposer_fails_closed() {
    let fx = Fixture::genesis(3);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let env = propose(&mut app).await;
    let mut prepare_request = prepare_req(next_height(&app), bft_time(&app));
    prepare_request.proposer_address = account::Id::new([0xff; 20]);
    let engine_before = app.engine().calls();
    assert!(prepare(&mut app, prepare_request).await.is_empty());
    assert_eq!(
        app.engine().calls(),
        engine_before,
        "unknown proposer cannot build or reuse an EL result"
    );
    assert_eq!(app.halt.as_deref(), Some("proposer_unknown"));
    let mut req = process_req(next_height(&app), bft_time(&app), vec![env.encode()]);
    req.proposer_address = account::Id::new([0xff; 20]);
    assert_eq!(process(&mut app, req.clone()).await, response::ProcessProposal::Reject);
    assert_eq!(app.halt.as_deref(), Some("proposer_unknown"));
    assert!(finalize(&mut app, finalize_req(&req)).await.is_err());
}
