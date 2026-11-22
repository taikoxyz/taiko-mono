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
    envelope::{AnchorWitness, EtnaEnvelope, ForcedWitness},
    forced::ForcedEntry,
    l1::verify_anchor_witness,
    rules,
    test_utils::{
        InboxStorage, L1Call, committed_block, sample_transactions, simple_block, test_key,
    },
    types::{AnchorState, ParentInfo},
};

/// CometBFT's default `max_tx_bytes` for the fixture's `block.max_bytes`.
pub(super) const MAX_TX_BYTES: i64 = 22_020_096;

/// The CometBFT address of the fixture's first origin fallback key.
pub(super) fn proposer() -> account::Id {
    account::Id::new(test_key(1).address().into_array())
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
/// derived from the height and the transactions. The next-set hash is explicit native Comet
/// header metadata from the fixture state, never repaired by the execution helper.
pub(super) fn process_req(
    app: &App<MockL1, MockEngine>,
    height: u64,
    time: u64,
    txs: Vec<Bytes>,
) -> request::ProcessProposal {
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
        next_validators_hash: app.state().map_or(Hash::None, |state| {
            Hash::Sha256(state.val_state.next.validators_hash().unwrap().0)
        }),
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
    let req = process_req(app, next_height(app), bft_time(app), vec![env.encode()]);
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
    validate::validate_block(
        &state.chain_context(),
        &app.params,
        env,
        next_height(app),
        bft_time(app),
        proposer(),
    )
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

/// Moves the committed state to height `last` with a synthetic parent block and `anchor` as the
/// committed anchor. The parent is the
/// [`committed_block`] at `last`, and the EL's canonical chain gains one below it at every height
/// above genesis it does not hold yet, so anchored checkpoints of `Fixture::inbox_with` name the
/// local chain. The validator state advances to `last` without updates.
pub(super) fn jump(app: &mut App<MockL1, MockEngine>, last: u64, anchor: AnchorState) {
    let genesis_height = app.state().expect("initialized").genesis.genesis_height;
    {
        let mut engine = app.engine().state();
        for number in genesis_height + 1..=last {
            let header =
                engine.chain.entry(number).or_insert_with(|| committed_block(number)).clone();
            engine.known.insert(header.hash_slow(), header);
        }
    }
    let state = app.state.as_mut().expect("initialized");
    let offset = last - state.genesis.genesis_height;
    let timestamp = state.parent.timestamp + 2 * offset;
    state.parent = ParentInfo {
        number: last,
        hash: committed_block(last).hash_slow(),
        timestamp,
        grandparent_timestamp: timestamp - 2,
        ..state.parent.clone()
    };
    state.last_height = last;
    state.anchor = anchor;
    while state.val_state.height < last {
        state.val_state = state.val_state.advance(&[]).expect("a nonempty set advances");
    }
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

/// An initialized app whose committed head sits `offset` heights after the Etna start S, anchored
/// at the genesis L1 block (last checkpoint S). With `offset` in 1..=9 the next height is a plain
/// height: no witness required, back-pressure satisfied.
pub(super) async fn mid_epoch(fx: &Fixture, dir: &Path, offset: u64) -> App<MockL1, MockEngine> {
    let mut app = initialized(fx, dir).await;
    let anchor = fx.anchor_state(app.l1(), fx.genesis.l1_0);
    jump(&mut app, fx.genesis.genesis_height + offset, anchor);
    app
}

/// The envelope an honest proposer would build for the next height with this anchor witness:
/// the header derived for the witnessed (or inherited) anchor, built by [`simple_block`].
pub(super) fn hand_envelope(
    app: &App<MockL1, MockEngine>,
    anchor: Option<AnchorWitness>,
) -> EtnaEnvelope {
    hand_built(app, anchor, None)
}

/// The forced inclusion block an honest proposer would build for the next height: as
/// [`hand_envelope`], carrying `forced`, with the EL building from `tx_list` (the consumed
/// entry's transaction list).
pub(super) fn hand_forced_envelope(
    app: &App<MockL1, MockEngine>,
    anchor: Option<AnchorWitness>,
    forced: ForcedWitness,
    tx_list: Bytes,
) -> EtnaEnvelope {
    EtnaEnvelope { forced: Some(forced), ..hand_built(app, anchor, Some(tx_list)) }
}

/// The envelope of [`hand_envelope`] without a forced witness, its block built by
/// [`simple_block`] from `tx_list` when given.
fn hand_built(
    app: &App<MockL1, MockEngine>,
    anchor: Option<AnchorWitness>,
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
        &state.chain_context(),
        &app.params,
        height,
        &anchor_state,
        bft_time(app),
        proposer(),
    )
    .expect("derivable header");
    let attrs = rules::payload_attributes(&expected, anchor_state.hash, tx_list);
    EtnaEnvelope { block: simple_block(state.parent.hash, &attrs), anchor, forced: None }
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
    fx.advance_l1(l1, number, &inbox);
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
    let h0 = step(&mut app).await.block.header;

    // A plain height: the finalized L1 block has not moved, so no witness at all.
    let env = propose(&mut app).await;
    assert!(env.anchor.is_none());
    app.l1().state().calls.clear();
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    assert!(app.l1().calls().is_empty(), "no witness, no L1 call");
    let anchor_before = app.state().unwrap().anchor.clone();
    assert_eq!(app.verdicts.get(&req.hash).expect("the verdict is cached").anchor, anchor_before);
    decide(&mut app, &req).await;

    // L1 finalizes block 66, where the checkpoint has advanced to H_0: the anchor moves.
    let inbox = fx.inbox_at_checkpoint(h0.number, h0.hash_slow());
    let header = fx.advance_l1(app.l1(), 66, &inbox);
    let env = propose(&mut app).await;
    let anchor = env.anchor.as_ref().expect("a moved anchor carries its witness");
    assert_eq!(anchor.l1_header, header);
    assert_eq!(rules::decode_extra_data(&env.block.header.extra_data).unwrap().anchor, 66);
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

/// The DAO's emergency setting, `minTotalStake` = 2^256 − 1, reaches the facts of the anchor
/// that proves it in all 256 bits, as does an all-ones fallback keys hash; a block that keeps
/// that anchor inherits both, and so does the committed state a restart reads back.
#[tokio::test]
async fn min_total_stake_max_is_decoded_unmasked_and_inherited() {
    use crate::{
        l1::layout::inbox,
        test_utils::{TestState, anchor_witness_in, filler_accounts, inbox_account, l1_header},
    };
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 6).await;
    let mut account = inbox_account(fx.params.inbox, &fx.inbox);
    account.4.extend([
        (inbox::slot(inbox::FALLBACK_KEYS_HASH), U256::MAX),
        (inbox::slot(inbox::MIN_TOTAL_STAKE), U256::MAX),
    ]);
    let mut accounts = filler_accounts();
    accounts.push(account);
    let state = TestState::new(accounts);
    let header = l1_header(66, Fixture::l1_timestamp(66));
    app.l1().insert_block(header.clone(), state.clone());
    app.l1().set_finalized(66);
    let witness = anchor_witness_in(&state, fx.params.inbox, header);
    let anchor = verify_anchor_witness(&witness, fx.params.inbox).unwrap();
    assert_eq!(anchor.inbox.min_total_stake, U256::MAX);
    assert_eq!(anchor.inbox.fallback_keys_hash, B256::repeat_byte(0xff));

    let env = hand_envelope(&app, Some(witness));
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    decide(&mut app, &req).await;
    assert_eq!(app.state().unwrap().anchor, anchor);

    let env = hand_envelope(&app, None);
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", app.halt);
    assert_eq!(app.verdicts.get(&req.hash).expect("the verdict is cached").anchor, anchor);
    decide(&mut app, &req).await;
    assert_eq!(app.state().unwrap().anchor, anchor);
    let stored = Store::volatile(dir.path().to_path_buf()).load().unwrap().expect("committed");
    assert_eq!(stored.anchor, anchor);
}

/// A stored state whose genesis configuration hash is not the one of the node's built-in L2
/// chain id, staking proxy and U is refused at startup and left as it is, without migration:
/// a state written under another staking address, and a state carrying the hash of the removed
/// registry-era configuration.
#[test]
fn stored_state_with_another_config_hash_is_refused() {
    let fx = Fixture::genesis(2);
    let other_staking =
        ChainParams { staking: alloy_primitives::Address::repeat_byte(0x22), ..fx.params.clone() };
    let registry_era =
        alloy_primitives::b256!("af72a8cac328b7a82ec9c449fb39aecc89a196de580f512cc40f0e1d8a6ad2fa");
    for config_hash in [other_staking.config_hash(), registry_era] {
        let mut state = fx.expected_state();
        state.genesis.config_hash = config_hash;
        let dir = tempfile::tempdir().unwrap();
        let store = Store::volatile(dir.path().to_path_buf());
        store.save(&state).unwrap();
        let file = dir.path().join(crate::store::STATE_FILE);
        let before = std::fs::read(&file).unwrap();
        let result = App::new(
            fx.l1(),
            fx.engine(),
            fx.params.clone(),
            store,
            crate::test_utils::test_options(),
        );
        assert!(
            matches!(&result, Err(AbciError::StoredState(message))
                if message.contains("configuration hash")),
            "{config_hash}"
        );
        assert_eq!(std::fs::read(file).unwrap(), before);
    }
}

/// No handler may accept a proposer outside the set that signs the block.
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
    let mut expected = engine_before;
    expected.push(EngineCall::HeaderByNumber(app.state().unwrap().last_height));
    assert_eq!(
        app.engine().calls(),
        expected,
        "unknown proposer performs only the committed-parent presence check"
    );
    assert_eq!(app.halt.as_deref(), Some("proposer_unknown"));
    let mut req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    req.proposer_address = account::Id::new([0xff; 20]);
    assert_eq!(process(&mut app, req.clone()).await, response::ProcessProposal::Reject);
    assert_eq!(app.halt.as_deref(), Some("proposer_unknown"));
    assert!(finalize(&mut app, finalize_req(&req)).await.is_err());
}
