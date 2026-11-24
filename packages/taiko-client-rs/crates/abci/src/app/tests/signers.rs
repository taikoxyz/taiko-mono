//! The set that signs H + 2, decided by `FinalizeBlock(H)` once H has executed: the candidate
//! snapshot H's block-start call stored, read from H's post-state, when it is usable under the
//! minimum total stake H's anchor proves, otherwise the fallback key list whose hash that anchor
//! proves, each key at power 1. The response lists the difference to the set that signs H + 1,
//! which stock CometBFT applies at H + 2.
//!
//! Unless a test says otherwise, the generation starts at S = 0 on the fixture's origin fallback
//! keys, and its first block anchors at L1 block 65, where the Inbox proves the origin list's
//! hash and a minimum total stake of [`MIN_STAKE`]. A block's candidate snapshot is planted in
//! its post-state once the block is built; a block without one reads all zero words, a snapshot
//! no block-start call wrote.

use std::time::Duration;

use alloy_primitives::{B256, U256};
use etna_core::staking::{StakingWords, snapshot_height_slot, snapshot_total_stake_slot};
use tendermint::account;

use super::{
    finalize::updates_of,
    proposal::{
        bft_time, commit, finalize, finalize_req, next_height, prepare, prepare_req, process,
        process_req,
    },
    recovery_init::document,
    *,
};
use crate::{
    app::trust::TrustPhase,
    committee::SignerSource,
    envelope::EtnaEnvelope,
    fallback::FallbackKeys,
    key::ConsensusKey,
    store::{AppState, SignerStatus},
    test_utils::{
        GenesisSpec, InboxStorage, L1Call, LogCapture, fallback_list, init_chain_request,
        recovery_fixture, serve_fallback_keys, test_key, test_options,
    },
    valstate::{ValEntry, ValSet, ValState, comet_order},
};

/// The minimum total stake the tests' anchors prove.
pub(super) const MIN_STAKE: u64 = 1_000;

/// A node of `fx` after `InitChain` whose own L1 has finalized block 65, where the Inbox proves
/// the origin list's hash and `min_total_stake`: the generation's first block anchors there.
pub(super) async fn node(
    fx: &Fixture,
    dir: &std::path::Path,
    min_total_stake: U256,
) -> App<MockL1, MockEngine> {
    let app = initialized(fx, dir).await;
    let inbox = InboxStorage { min_total_stake, ..fx.inbox_with(fx.genesis.genesis_height) };
    fx.advance_l1(app.l1(), 65, &inbox);
    app
}

/// The candidate snapshot `height`'s block-start call stores for `members`, seated from seat 0
/// on in the given order, with the total stake `total`.
pub(super) fn snapshot(height: u64, total: u64, members: &[(ConsensusKey, u64)]) -> StakingWords {
    let mut words = StakingWords::header_only(U256::from(height), U256::from(total));
    for (seat, &(key, power)) in members.iter().enumerate() {
        words.records[seat] = record(key, U256::from(power));
    }
    words
}

/// The seat record holding `key` at `power`: `ckX`, then `ckPrefix | power << 8`.
fn record(key: ConsensusKey, power: U256) -> [U256; 2] {
    [U256::from_be_bytes(key.x().0), U256::from(key.prefix()) | (power << 8usize)]
}

/// The keys of seeds `seeds`, each at `power`, in ascending key order.
fn at_power(seeds: &[u64], power: u64) -> Vec<(ConsensusKey, u64)> {
    let mut members: Vec<_> = seeds.iter().map(|&seed| (test_key(seed), power)).collect();
    members.sort();
    members
}

/// The keys and powers of `set` in ascending key order.
fn sorted(set: &ValSet) -> Vec<(ConsensusKey, u64)> {
    let mut members = set.members();
    members.sort();
    members
}

/// Where the sets that sign `state`'s next two heights come from, in height order.
fn sources(state: &AppState) -> [SignerSource; 2] {
    [state.signers.next.source, state.signers.after.source]
}

/// `updates` in ascending key order, the order a response lists them in.
fn by_key(mut updates: Vec<(ConsensusKey, u64)>) -> Vec<(ConsensusKey, u64)> {
    updates.sort();
    updates
}

/// The CometBFT address of `key`, as a certified proposer.
fn address(key: ConsensusKey) -> account::Id {
    account::Id::new(key.address().into_array())
}

/// A member of the set that signs `app`'s next height, as that height's certified proposer:
/// the app checks that the proposer is in that set, not CometBFT's proposer rotation.
fn proposer_of(app: &App<MockL1, MockEngine>) -> account::Id {
    address(app.state().expect("initialized").val_state.current.entries[0].key)
}

/// Prepares `app`'s next height with a proposer of its signing set; returns the envelope.
async fn propose(app: &mut App<MockL1, MockEngine>) -> EtnaEnvelope {
    let mut req = prepare_req(app, next_height(app), bft_time(app));
    req.proposer_address = proposer_of(app);
    let txs = prepare(app, req).await;
    assert_eq!(txs.len(), 1, "one envelope; halt = {:?}", app.halt);
    EtnaEnvelope::decode(&txs[0]).expect("the envelope decodes")
}

/// The `ProcessProposal` request of `env` as `app`'s next height, proposed by a member of the
/// set that signs it.
fn process_request(app: &App<MockL1, MockEngine>, env: &EtnaEnvelope) -> request::ProcessProposal {
    let mut req = process_req(app, next_height(app), bft_time(app), vec![env.encode()]);
    req.proposer_address = proposer_of(app);
    req
}

/// Builds `app`'s next height H, plants `words` as the candidate snapshot in H's post-state
/// (none: all zero), then processes, finalizes and commits H; returns the `FinalizeBlock`
/// response.
pub(super) async fn step(
    app: &mut App<MockL1, MockEngine>,
    words: Option<StakingWords>,
) -> response::FinalizeBlock {
    let env = propose(app).await;
    if let Some(words) = &words {
        app.engine().set_staking_words(env.block.header.hash_slow(), app.params.staking, words);
    }
    let req = process_request(app, &env);
    assert_eq!(
        process(app, req.clone()).await,
        response::ProcessProposal::Accept,
        "{:?}",
        app.halt
    );
    let resp = finalize(app, finalize_req(&req)).await.expect("FinalizeBlock succeeds");
    commit(app).await.expect("Commit succeeds");
    resp
}

/// The storage reads `app`'s EL answered: the block hash and the slots of each.
fn storage_reads(app: &App<MockL1, MockEngine>) -> Vec<(B256, Vec<B256>)> {
    app.engine()
        .calls()
        .into_iter()
        .filter_map(|call| match call {
            EngineCall::StorageAt { hash, slots, .. } => Some((hash, slots)),
            _ => None,
        })
        .collect()
}

/// The two header words of a candidate snapshot, the only words read when they rule it out.
fn header_slots() -> Vec<B256> {
    vec![snapshot_height_slot(), snapshot_total_stake_slot()]
}

/// A usable candidate at H = o + 1 signs H + 2: `FinalizeBlock(H)` removes every origin key at
/// power 0 and adds the members at their stored powers. The updates take effect at H + 2 and not
/// before: the origin keys still sign H + 1, whose proposer must be one of them, a proposal at
/// H + 2 by an origin key is refused, and from H + 3 on the LastCommit lists the members.
#[tokio::test]
async fn usable_candidate_signs_h_plus_2() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(&fx, dir.path(), U256::from(MIN_STAKE)).await;
    let origin = fx.fallback_keys.validator_set();
    let members = vec![(test_key(13), 1), (test_key(11), 5), (test_key(12), 7)];
    let h = next_height(&app);

    let resp = step(&mut app, Some(snapshot(h, MIN_STAKE, &members))).await;
    let mut expected: Vec<_> = origin.iter().map(|&(key, _)| (key, 0)).collect();
    expected.extend(members.iter().copied());
    assert_eq!(updates_of(&resp), by_key(expected));
    let state = app.state().unwrap();
    assert_eq!(sorted(&state.val_state.current), origin, "the origin keys sign H + 1");
    assert_eq!(sorted(&state.val_state.next), by_key(members.clone()), "the members sign H + 2");
    assert_eq!(sources(state), [SignerSource::Fallback, SignerSource::Candidate]);

    // H + 1: an origin key proposes, and its LastCommit lists the origin keys.
    let env = propose(&mut app).await;
    let words = snapshot(h + 1, MIN_STAKE, &members);
    app.engine().set_staking_words(env.block.header.hash_slow(), app.params.staking, &words);
    let req = process_request(&app, &env);
    assert!(origin.iter().any(|&(key, _)| address(key) == req.proposer_address));
    let listed: Vec<_> = req
        .proposed_last_commit
        .as_ref()
        .unwrap()
        .votes
        .iter()
        .map(|v| v.validator.address)
        .collect();
    let origin_order = comet_order(&origin).unwrap();
    assert_eq!(
        listed,
        origin_order.iter().map(|e| e.key.address().into_array()).collect::<Vec<_>>()
    );
    assert_eq!(process(&mut app, req.clone()).await, response::ProcessProposal::Accept);
    let resp = finalize(&mut app, finalize_req(&req)).await.unwrap();
    assert!(resp.validator_updates.is_empty(), "the same candidate signs H + 3");
    commit(&mut app).await.unwrap();

    // H + 2: the members sign; an origin key is no longer a proposer.
    let env = propose(&mut app).await;
    let mut refused = process_request(&app, &env);
    refused.proposer_address = address(test_key(1));
    refused.hash = tendermint::Hash::Sha256([0x77; 32]);
    assert_eq!(process(&mut app, refused).await, response::ProcessProposal::Reject);
    assert_eq!(app.halt.as_deref(), Some("proposer_unknown"));
    let words = snapshot(h + 2, MIN_STAKE, &members);
    app.engine().set_staking_words(env.block.header.hash_slow(), app.params.staking, &words);
    let req = process_request(&app, &env);
    assert!(members.iter().any(|&(key, _)| address(key) == req.proposer_address));
    assert_eq!(process(&mut app, req.clone()).await, response::ProcessProposal::Accept);
    finalize(&mut app, finalize_req(&req)).await.unwrap();
    commit(&mut app).await.unwrap();
    let state = app.state().unwrap();
    let listed: Vec<_> = state.parent_signers.iter().map(|e| (e.key, e.power)).collect();
    let order: Vec<_> = comet_order(&members).unwrap().iter().map(|e| (e.key, e.power)).collect();
    assert_eq!(listed, order, "H + 3's LastCommit lists the members");
    assert_eq!(sources(state), [SignerSource::Candidate; 2]);
}

/// A candidate that signs while its total stake reaches the minimum hands H + 3 back to the
/// fallback keys once the total of H + 1's snapshot drops below it, by one update list; the
/// candidate's records are then not read.
#[tokio::test]
async fn fallback_returns_when_total_drops_below_m() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(&fx, dir.path(), U256::from(MIN_STAKE)).await;
    let origin = fx.fallback_keys.validator_set();
    let members = at_power(&[11, 12], 9);
    let h = next_height(&app);
    let resp = step(&mut app, Some(snapshot(h, MIN_STAKE, &members))).await;
    assert_eq!(updates_of(&resp).len(), 4, "the candidate signs H + 2");

    let reads = storage_reads(&app).len();
    let resp = step(&mut app, Some(snapshot(h + 1, MIN_STAKE - 1, &members))).await;
    let mut expected: Vec<_> = members.iter().map(|&(key, _)| (key, 0)).collect();
    expected.extend(origin.iter().copied());
    assert_eq!(updates_of(&resp), by_key(expected));
    let state = app.state().unwrap();
    assert_eq!(sorted(&state.val_state.next), origin);
    assert_eq!(sources(state), [SignerSource::Candidate, SignerSource::Fallback]);
    let hash = state.parent.hash;
    assert_eq!(storage_reads(&app)[reads..], [(hash, header_slots())], "the header alone");
}

/// When H's block-start call fails, H's post-state still holds the snapshot of H − 1, usable in
/// every other way: the fallback keys sign H + 2 and H is committed, no halt.
#[tokio::test]
async fn failed_block_start_call_falls_back_without_a_halt() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(&fx, dir.path(), U256::from(MIN_STAKE)).await;
    let origin = fx.fallback_keys.validator_set();
    let members = at_power(&[11, 12, 13], 4);
    let h = next_height(&app);
    step(&mut app, Some(snapshot(h, MIN_STAKE, &members))).await;

    let stale = snapshot(h, MIN_STAKE, &members);
    let resp = step(&mut app, Some(stale)).await;
    let mut expected: Vec<_> = members.iter().map(|&(key, _)| (key, 0)).collect();
    expected.extend(origin.iter().copied());
    assert_eq!(updates_of(&resp), by_key(expected));
    let state = app.state().unwrap();
    assert_eq!(state.last_height, h + 1, "the block is committed");
    assert_eq!(sources(state), [SignerSource::Candidate, SignerSource::Fallback]);
    assert_eq!(app.halt, None);
}

/// With a minimum total stake of 2^256 − 1 no candidate signs, even one written by H's own call
/// whose total stake is 2^256 − 1 and whose records are valid: the fallback keys sign H + 2, and
/// the records are not read.
#[tokio::test]
async fn m_max_with_a_usable_looking_candidate_falls_back() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(&fx, dir.path(), U256::MAX).await;
    let h = next_height(&app);
    let mut words = snapshot(h, 0, &at_power(&[11, 12], 3));
    words.total_stake = U256::MAX;
    let resp = step(&mut app, Some(words)).await;
    assert!(resp.validator_updates.is_empty(), "the origin keys sign H + 2 again");
    let state = app.state().unwrap();
    assert_eq!(sources(state), [SignerSource::Fallback; 2]);
    assert_eq!(storage_reads(&app), [(state.parent.hash, header_slots())]);
}

/// A candidate whose records are no valid set (a member at power 0, or a stray bit in a second
/// word) is not usable: the fallback keys sign H + 2 and H is committed, no halt. The same
/// snapshot with that record well formed signs H + 2.
#[tokio::test]
async fn invalid_candidate_falls_back_without_a_halt() {
    let fx = Fixture::genesis(2);
    let members = at_power(&[11, 12], 6);
    let well_formed = record(test_key(13), U256::from(6));
    let zero_power = record(test_key(13), U256::ZERO);
    let mut stray_bit = well_formed;
    stray_bit[1] |= U256::from(1) << 72usize;
    for (third, usable) in [(well_formed, true), (zero_power, false), (stray_bit, false)] {
        let dir = tempfile::tempdir().unwrap();
        let mut app = node(&fx, dir.path(), U256::from(MIN_STAKE)).await;
        let h = next_height(&app);
        let mut words = snapshot(h, MIN_STAKE, &members);
        words.records[members.len()] = third;
        let resp = step(&mut app, Some(words)).await;
        assert_eq!(resp.validator_updates.is_empty(), !usable, "{third:?}");
        let state = app.state().unwrap();
        assert_eq!(state.last_height, h, "{third:?}: the block is committed");
        let source = if usable { SignerSource::Candidate } else { SignerSource::Fallback };
        assert_eq!(sources(state), [SignerSource::Fallback, source], "{third:?}");
        assert_eq!(app.halt, None);
    }
}

/// One case of the stock CometBFT v0.40.0 validator-state vectors etna-core replays: the keys
/// its steps index and, per height from the generation's origin on, the updates and the state
/// stock CometBFT holds after them.
struct StockCase {
    /// The vector keys, of seeds 1 to 256.
    keys: Vec<ConsensusKey>,
    /// The case's steps, the first the genesis.
    steps: Vec<serde_json::Value>,
}

impl StockCase {
    /// The case called `name`.
    fn load(name: &str) -> Self {
        let vectors: serde_json::Value = serde_json::from_str(include_str!(
            "../../../../etna-core/testdata/cometbft-v0.40-valstate/vectors.json"
        ))
        .unwrap();
        let keys = serde_json::from_value(vectors["keys"].clone()).unwrap();
        let case = vectors["cases"].as_array().unwrap().iter().find(|case| case["name"] == name);
        let steps = case.unwrap()["steps"].as_array().unwrap().clone();
        Self { keys, steps }
    }

    /// The comma-separated `key:…` items of `field` at `step`, each integer parsed.
    fn items(&self, step: usize, field: &str) -> Vec<Vec<i64>> {
        let list = self.steps[step][field].as_str().unwrap();
        list.split(',')
            .filter(|item| !item.is_empty())
            .map(|item| item.split(':').map(|n| n.parse().unwrap()).collect())
            .collect()
    }

    /// The updates of `step`, the genesis members at step 0.
    fn updates(&self, step: usize) -> Vec<(ConsensusKey, u64)> {
        self.items(step, "updates")
            .iter()
            .map(|i| (self.keys[i[0] as usize], i[1] as u64))
            .collect()
    }

    /// The validator state stock CometBFT holds after `step`, at the app's `height`.
    fn state(&self, step: usize, height: u64) -> ValState {
        let set = |field: &str| ValSet {
            entries: self
                .items(step, field)
                .iter()
                .map(|i| ValEntry { key: self.keys[i[0] as usize], power: i[1], priority: i[2] })
                .collect(),
            proposer: self.steps[step][format!("{field}_proposer")].as_u64().unwrap() as usize,
        };
        ValState { height, current: set("current"), next: set("next") }
    }

    /// A fixture whose origin fallback keys are the genesis members of the case, at power 1.
    fn fixture(&self) -> Fixture {
        let mut keys: Vec<_> = self.updates(0).into_iter().map(|(key, _)| key).collect();
        keys.sort();
        let origin_keys = FallbackKeys::new(keys).unwrap();
        Fixture::build(GenesisSpec { origin_keys: Some(origin_keys), ..GenesisSpec::new(1) })
    }
}

/// Runs the stock `case` on an app in `dir`: the genesis is its first step, and at every later
/// height the candidate `candidate(step)` (none: the fallback keys) decides. Each response holds
/// exactly the step's updates and the app's validator state equals stock CometBFT's.
async fn replay_stock(
    case: &StockCase,
    dir: &std::path::Path,
    candidate: impl Fn(usize) -> Option<Vec<(ConsensusKey, u64)>>,
) -> App<MockL1, MockEngine> {
    let fx = case.fixture();
    let mut app = node(&fx, dir, U256::from(1)).await;
    let o = fx.genesis.genesis_height;
    assert_eq!(app.state().unwrap().val_state, case.state(0, o));
    for step_index in 1..case.steps.len() {
        let h = next_height(&app);
        let words = candidate(step_index).map(|members| snapshot(h, 1, &members));
        let resp = step(&mut app, words).await;
        assert_eq!(updates_of(&resp), case.updates(step_index), "height {h}");
        assert_eq!(app.state().unwrap().val_state, case.state(step_index, h), "height {h}");
    }
    app
}

/// A fallback key that is also the key of a seated bond, at another power, is re-weighted by one
/// entry, never removed, both when the candidate takes over and when the fallback keys return,
/// and the app's validator state stays the one stock CometBFT holds.
#[tokio::test]
async fn mode_switch_reweights_a_key_in_both_sets() {
    let case = StockCase::load("fallback_key_reweighted_as_seat_key");
    let shared = case.keys[0];
    let switched = case.updates(2);
    assert_eq!(switched.len(), 4);
    assert!(switched.contains(&(shared, 250_000)));
    let candidate = |step: usize| (step >= 2).then(|| vec![(shared, 250_000)]);
    let dir = tempfile::tempdir().unwrap();
    let mut app = replay_stock(&case, dir.path(), candidate).await;
    assert_eq!(sources(app.state().unwrap()), [SignerSource::Candidate; 2]);

    let resp = step(&mut app, None).await;
    let origin = case.fixture().fallback_keys.validator_set();
    assert_eq!(updates_of(&resp), origin, "the shared key goes back to power 1, the others return");
    let state = app.state().unwrap();
    assert_eq!(sorted(&state.val_state.next), origin);
    assert_eq!(sources(state), [SignerSource::Candidate, SignerSource::Fallback]);
}

/// 128 origin keys replaced by 128 other keys at H + 2: one list of 256 updates, which stock
/// CometBFT accepts, and a validator state equal to stock CometBFT's at every height.
#[tokio::test]
async fn replace_128_with_128() {
    let case = StockCase::load("replace_128_with_128_other_keys");
    let replaced = case.updates(3);
    assert_eq!(replaced.len(), 256);
    let members: Vec<_> = replaced.iter().copied().filter(|&(_, power)| power > 0).collect();
    assert_eq!(members.len(), 128);
    let dir = tempfile::tempdir().unwrap();
    let app = replay_stock(&case, dir.path(), |step| (step >= 3).then(|| members.clone())).await;
    let state = app.state().unwrap();
    assert_eq!(sources(state), [SignerSource::Candidate; 2]);
    assert_eq!(state.parent_signers.len(), 128);
}

/// 128 origin keys and a 128-member candidate at a total of the maximum power replace each
/// other as a whole, so that each switch's total before its removals exceeds the maximum, then
/// the same with a candidate that shares one origin key: every response holds stock CometBFT's
/// updates, and the app's validator state is stock CometBFT's at every height.
#[tokio::test]
async fn whole_set_switches_at_the_maximum_total_follow_stock() {
    let case = StockCase::load("max_total_switches_with_128_fallback_keys");
    let origin = case.fixture().fallback_keys.validator_set();
    let candidate = |step: usize| {
        let next = sorted(&case.state(step, 0).next);
        (next != origin).then_some(next)
    };
    assert_eq!((1..case.steps.len()).filter(|&step| candidate(step).is_some()).count(), 4);
    let dir = tempfile::tempdir().unwrap();
    let app = replay_stock(&case, dir.path(), candidate).await;
    let state = app.state().unwrap();
    assert_eq!(sources(state), [SignerSource::Fallback; 2]);
    assert_eq!(sorted(&state.val_state.current), origin);
}

/// Two consecutive candidates with the same members and powers, seated otherwise and with
/// another total stake, decide the same set: an empty update list.
#[tokio::test]
async fn same_set_returns_an_empty_list() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(&fx, dir.path(), U256::from(MIN_STAKE)).await;
    let mut members = vec![(test_key(11), 2), (test_key(12), 3), (test_key(13), 4)];
    let h = next_height(&app);
    step(&mut app, Some(snapshot(h, MIN_STAKE, &members))).await;
    let next = app.state().unwrap().val_state.next.clone();

    members.reverse();
    let resp = step(&mut app, Some(snapshot(h + 1, MIN_STAKE * 5, &members))).await;
    assert!(resp.validator_updates.is_empty());
    let state = app.state().unwrap();
    assert_eq!(sorted(&state.val_state.next), sorted(&next));
    assert_eq!(sources(state), [SignerSource::Candidate; 2]);
}

/// `FinalizeBlock(o + 1)` diffs the set it decides against the origin keys, which sign o + 2:
/// in generation 0 against the fallback list another anchor than the origin's proves, so a key in
/// both lists is not returned, and after a recovery against its origin keys, replaced by a
/// usable candidate.
#[tokio::test]
async fn h_equal_o_plus_1_diffs_against_the_origin_keys() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let other = fallback_list(&[2, 3]);
    serve_fallback_keys(app.l1(), fx.params.inbox, &other);
    let inbox = InboxStorage {
        fallback_keys_hash: other.hash(),
        ..fx.inbox_with(fx.genesis.genesis_height)
    };
    fx.advance_l1(app.l1(), 65, &inbox);
    assert_eq!(next_height(&app), fx.genesis.genesis_height + 1);
    let resp = step(&mut app, None).await;
    assert_eq!(updates_of(&resp), by_key(vec![(test_key(1), 0), (test_key(3), 1)]));
    let state = app.state().unwrap();
    assert_eq!(state.fallback_keys.get(&other.hash()), Some(&other), "the list is kept");

    let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), test_options());
    init_chain(&mut app, init_chain_request(&document(&fx, &w))).await.unwrap();
    let mut inbox = fx.inbox_at_checkpoint(6, w.el_header.hash_slow());
    inbox.recovery_generation = 1;
    inbox.forced_inclusion_head = 3;
    inbox.forced_inclusion_tail = 3;
    inbox.min_total_stake = U256::from(MIN_STAKE);
    fx.advance_l1(app.l1(), 111, &inbox);
    let origin = app.state().unwrap().val_state.next.members();
    let members = at_power(&[1, 21], 8);
    assert_eq!(next_height(&app), 7, "c + 1");
    let resp = step(&mut app, Some(snapshot(7, MIN_STAKE, &members))).await;
    let mut expected: Vec<_> = origin.iter().map(|&(key, _)| (key, 0)).collect();
    expected.retain(|&(key, _)| key != test_key(1));
    expected.extend(members.iter().copied());
    assert_eq!(updates_of(&resp), by_key(expected), "the shared origin key is re-weighted");
    assert_eq!(sources(app.state().unwrap()), [SignerSource::Fallback, SignerSource::Candidate]);
}

/// A `FinalizeBlock(H)` replayed after a crash before `Commit`, with the EL already at H,
/// reads the staking words at H's hash again and answers byte for byte the same updates and
/// app hash, deriving the same pending state.
#[tokio::test]
async fn finalize_replay_with_the_el_already_at_h_returns_identical_updates_and_app_hash() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(&fx, dir.path(), U256::from(MIN_STAKE)).await;
    step(&mut app, None).await;
    let committed = app.state().unwrap().clone();
    let env = propose(&mut app).await;
    let hash = env.block.header.hash_slow();
    let members = at_power(&[11, 12], 7);
    let words = snapshot(committed.last_height + 1, MIN_STAKE, &members);
    app.engine().set_staking_words(hash, app.params.staking, &words);
    let req = finalize_req(&process_request(&app, &env));
    let first = finalize(&mut app, req.clone()).await.expect("finalizes");
    assert_eq!(updates_of(&first).len(), 4, "the candidate signs H + 2");
    let pending = app.pending.clone().expect("pending");
    assert_eq!(
        app.engine().state().chain.get(&(committed.last_height + 1)).map(|h| h.hash_slow()),
        Some(hash),
        "the EL is at H"
    );

    // Crash before Commit: the EL keeps H and its post-state, the store the previous height.
    let engine = app.engine().reopen();
    drop(app);
    let l1 = fx.l1();
    let inbox = InboxStorage {
        min_total_stake: U256::from(MIN_STAKE),
        ..fx.inbox_with(fx.genesis.genesis_height)
    };
    fx.advance_l1(&l1, 65, &inbox);
    let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), test_options());
    assert_eq!(app.state(), Some(&committed));
    info(&mut app).await.expect("Info reconciles with an EL ahead");
    let replayed = finalize(&mut app, req).await.expect("the replay finalizes");
    assert_eq!(replayed, first);
    assert_eq!(app.pending.as_ref(), Some(&pending));
    let decided = SignerStatus::candidate(
        committed.last_height + 1,
        U256::from(MIN_STAKE),
        U256::from(MIN_STAKE),
        2,
    );
    assert_eq!(pending.signers.after, decided, "the replay records the same decision");
    let reads = storage_reads(&app);
    assert!(!reads.is_empty() && reads.iter().all(|(at, _)| *at == hash), "{reads:?}");
}

/// A cold `FinalizeBlock` whose anchor proves the hash of a fallback key list the node does not
/// hold and its own L1 cannot serve yet waits, while checkpoint trust is still pending, with H
/// already the EL's head and logging why; it neither halts nor decides another set, and answers
/// once the list is served, keeping the list.
#[tokio::test(start_paused = true)]
async fn missing_list_waits_on_the_cold_path_with_trust_pending() {
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    let other = fallback_list(&[5, 6, 7]);
    let anchored = InboxStorage {
        fallback_keys_hash: other.hash(),
        ..fx.inbox_with(fx.genesis.genesis_height)
    };
    fx.plant_l1_block(app.l1(), 66, &anchored);
    let target = InboxStorage {
        last_checkpoint_height: 6,
        last_checkpoint_hash: B256::repeat_byte(8),
        last_checkpoint_comet_hash: B256::repeat_byte(8),
        ..fx.inbox.clone()
    };
    fx.plant_l1_block(app.l1(), 100, &target);
    app.l1().set_finalized(100);
    app.refresh_trust().await.unwrap();
    assert_eq!(app.trust.snapshot().phase, TrustPhase::CatchingUp);

    let env = super::proposal::hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66)));
    let hash = env.block.header.hash_slow();
    let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
    let (l1, engine, trust) = (app.l1.clone(), app.engine.clone(), app.trust.clone());
    let logs = LogCapture::start();
    let resp = {
        let fut = finalize(&mut app, finalize_req(&req));
        tokio::pin!(fut);
        assert!(
            tokio::time::timeout(Duration::from_secs(120), &mut fut).await.is_err(),
            "it waits"
        );

        let calls = engine.calls();
        let fcu = calls.iter().position(|call| {
            matches!(call, EngineCall::Forkchoice { head, safe, .. } if *head == hash && safe.is_zero())
        });
        let read = calls
            .iter()
            .position(|call| matches!(call, EngineCall::StorageAt { hash: at, .. } if *at == hash));
        assert!(fcu.is_some() && fcu < read, "read after H is the head: {calls:?}");
        let anchor_hash = env.anchor.as_ref().unwrap().l1_header.hash();
        let l1_calls = l1.calls();
        assert!(
            l1_calls
                .iter()
                .any(|call| matches!(call, L1Call::CallAt { hash, .. } if *hash == anchor_hash))
        );
        assert!(l1_calls.iter().any(
            |call| matches!(call, L1Call::InboxLogs { topic1, .. } if *topic1 == other.hash())
        ));
        let warned = logs.at("WARN");
        assert!(warned.iter().any(|line| line.contains(&other.hash().to_string())), "{warned:?}");
        assert_eq!(trust.snapshot().phase, TrustPhase::CatchingUp);

        serve_fallback_keys(&l1, fx.params.inbox, &other);
        fut.await.expect("finalizes once the list is served")
    };
    let mut expected: Vec<_> = fx.fallback_keys.keys().iter().map(|&key| (key, 0)).collect();
    expected.extend(other.validator_set());
    assert_eq!(updates_of(&resp), by_key(expected));
    let pending = app.pending.as_ref().unwrap();
    assert_eq!(pending.fallback_keys.get(&other.hash()), Some(&other));
    assert_eq!(sources(pending), [SignerSource::Fallback; 2]);
    assert_eq!(app.trust.snapshot().phase, TrustPhase::CatchingUp);
}

/// The fallback key list an anchor proves is obtained before the block is decided: a proposal
/// whose anchor proves a list this node does not hold makes `ProcessProposal` (and the proposer's
/// `PrepareProposal`) fetch it from the own L1, so `FinalizeBlock` finds it. While it cannot be
/// obtained the node waits, never rejecting; the committed state keeps only the lists the next
/// decisions can need.
mod fallback_prefetch {
    use alloy_primitives::{Address, Bytes};
    use alloy_sol_types::SolCall;

    use super::*;
    use crate::{
        app::Rejection,
        fallback::{FALLBACK_KEYS_UPDATED, getFallbackKeysCall},
        l1::L1Error,
    };

    /// The fallback key list reads `app`'s own L1 answered: `getFallbackKeys()` calls and
    /// `FallbackKeysUpdated` log queries.
    fn list_reads(app: &App<MockL1, MockEngine>) -> Vec<L1Call> {
        app.l1()
            .calls()
            .into_iter()
            .filter(|call| matches!(call, L1Call::CallAt { .. } | L1Call::InboxLogs { .. }))
            .collect()
    }

    /// The hashes of the fallback key lists `app`'s committed state holds, ascending.
    fn held(app: &App<MockL1, MockEngine>) -> Vec<B256> {
        app.state().expect("initialized").fallback_keys.keys().copied().collect()
    }

    /// `hashes` in ascending order, as [`held`] lists them.
    fn ascending<const N: usize>(mut hashes: [B256; N]) -> Vec<B256> {
        hashes.sort();
        hashes.to_vec()
    }

    /// Serves the Inbox `inbox`'s `FallbackKeysUpdated` log of `keys` in L1 block `block`.
    fn emit(l1: &MockL1, inbox: Address, block: u64, keys: &FallbackKeys) {
        l1.insert_log(block, inbox, [FALLBACK_KEYS_UPDATED, keys.hash()], keys.abi_encode().into());
    }

    /// Plants L1 block `number` as `fx`'s finalized block, its Inbox proving `keys`' hash; the
    /// list itself is not served.
    fn anchor_proving(
        fx: &Fixture,
        app: &App<MockL1, MockEngine>,
        number: u64,
        keys: &FallbackKeys,
    ) {
        let inbox = InboxStorage {
            fallback_keys_hash: keys.hash(),
            ..fx.inbox_with(fx.genesis.genesis_height)
        };
        fx.advance_l1(app.l1(), number, &inbox);
    }

    /// The `ProcessProposal` request of a hand-built envelope for `app`'s next height carrying
    /// the anchor witness of L1 block `number`.
    fn anchored_request(
        fx: &Fixture,
        app: &App<MockL1, MockEngine>,
        number: u64,
    ) -> request::ProcessProposal {
        let env =
            super::super::proposal::hand_envelope(app, Some(fx.anchor_witness(app.l1(), number)));
        process_req(app, next_height(app), bft_time(app), vec![env.encode()])
    }

    /// `ProcessProposal` of a block whose anchor proves a list this node does not hold fetches
    /// that list from the own L1, pinned to the anchor's hash; `FinalizeBlock` then decides with
    /// it without reading the L1 again, and the committed state keeps it.
    #[tokio::test]
    async fn new_anchor_hash_is_prefetched_in_process() {
        let fx = Fixture::genesis(2);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        let other = fallback_list(&[5, 6, 7]);
        serve_fallback_keys(app.l1(), fx.params.inbox, &other);
        anchor_proving(&fx, &app, 66, &other);
        let anchor_hash = fx.anchor_witness(app.l1(), 66).l1_header.hash();
        let req = anchored_request(&fx, &app, 66);

        assert_eq!(process(&mut app, req.clone()).await, response::ProcessProposal::Accept);
        assert_eq!(
            list_reads(&app),
            [L1Call::CallAt {
                address: fx.params.inbox,
                input: Bytes::copy_from_slice(&getFallbackKeysCall::SELECTOR),
                hash: anchor_hash,
            }],
            "one getFallbackKeys() call pinned to the anchor hash"
        );

        let resp = finalize(&mut app, finalize_req(&req)).await.expect("finalizes");
        assert_eq!(list_reads(&app).len(), 1, "FinalizeBlock reads no list");
        let mut expected: Vec<_> = fx.fallback_keys.keys().iter().map(|&key| (key, 0)).collect();
        expected.extend(other.validator_set());
        assert_eq!(updates_of(&resp), by_key(expected), "the prefetched list signs H + 2");
        commit(&mut app).await.expect("commits");
        assert_eq!(app.state().unwrap().fallback_keys.get(&other.hash()), Some(&other));
    }

    /// While the own L1 cannot give the list a proposal's anchor proves, whether a log query
    /// fails or no log holds it, `ProcessProposal` waits, logging why, and never rejects;
    /// `PrepareProposal` proposes nothing. Once the list is served the waiting proposal is
    /// accepted, and the proposer builds on the list it now holds.
    #[tokio::test(start_paused = true)]
    async fn unobtainable_list_waits_in_process_and_placeholders_prepare() {
        let fx = Fixture::genesis(2);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        let other = fallback_list(&[5, 6, 7]);
        anchor_proving(&fx, &app, 66, &other);
        app.l1().state().log_fail = Some(L1Error::Rpc("eth_getLogs rate limited".into()));
        let logs = LogCapture::start();

        let req = prepare_req(&app, next_height(&app), bft_time(&app));
        assert!(prepare(&mut app, req).await.is_empty(), "a placeholder proposal");
        assert_eq!(app.halt.as_deref(), Some("fallback_keys_unavailable"));

        let req = anchored_request(&fx, &app, 66);
        let l1 = app.l1.clone();
        let resp = {
            let fut = process(&mut app, req);
            tokio::pin!(fut);
            assert!(
                tokio::time::timeout(Duration::from_secs(120), &mut fut).await.is_err(),
                "it waits while the log query fails"
            );
            let warned = logs.at("WARN");
            let named = |text: &str| {
                warned
                    .iter()
                    .any(|line| line.contains(&other.hash().to_string()) && line.contains(text))
            };
            assert!(named("rate limited"), "the L1 failure is logged: {warned:?}");

            l1.state().log_fail = None;
            assert!(
                tokio::time::timeout(Duration::from_secs(120), &mut fut).await.is_err(),
                "it waits while no log holds the list"
            );
            serve_fallback_keys(&l1, fx.params.inbox, &other);
            fut.await
        };
        assert_eq!(resp, response::ProcessProposal::Accept);

        let calls = list_reads(&app).len();
        let req = prepare_req(&app, next_height(&app), bft_time(&app));
        assert_eq!(prepare(&mut app, req).await.len(), 1, "one envelope; halt = {:?}", app.halt);
        assert_eq!(list_reads(&app).len(), calls, "the held list needs no read");
    }

    /// A list this node holds needs no L1 read: a later proposal of the same height whose anchor
    /// proves a list an earlier proposal fetched, `FinalizeBlock` of it, and once committed a
    /// block inheriting that anchor.
    #[tokio::test]
    async fn cached_list_needs_no_l1() {
        let fx = Fixture::genesis(2);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        let other = fallback_list(&[5, 6, 7]);
        serve_fallback_keys(app.l1(), fx.params.inbox, &other);
        anchor_proving(&fx, &app, 66, &other);
        let first = anchored_request(&fx, &app, 66);
        assert_eq!(process(&mut app, first.clone()).await, response::ProcessProposal::Accept);
        assert_eq!(list_reads(&app).len(), 1, "the first proposal fetches the list");

        let mut later = first;
        later.hash = tendermint::Hash::Sha256([0x77; 32]);
        assert_eq!(process(&mut app, later.clone()).await, response::ProcessProposal::Accept);
        finalize(&mut app, finalize_req(&later)).await.expect("finalizes");
        commit(&mut app).await.expect("commits");
        assert_eq!(list_reads(&app).len(), 1, "neither the later proposal nor its decision");

        let env = super::super::proposal::hand_envelope(&app, None);
        let req = process_req(&app, next_height(&app), bft_time(&app), vec![env.encode()]);
        assert_eq!(process(&mut app, req.clone()).await, response::ProcessProposal::Accept);
        finalize(&mut app, finalize_req(&req)).await.expect("finalizes");
        commit(&mut app).await.expect("commits");
        assert_eq!(list_reads(&app).len(), 1, "nor a block inheriting the anchor");
    }

    /// The committed state keeps the list its anchor proves and, after a recovery, the origin
    /// record's list, which a restart checks; the list of an anchor no longer in play is
    /// dropped. Generation 0's state records no origin hash, so its origin list stays only while
    /// an anchor proves it.
    #[tokio::test]
    async fn cache_keeps_only_origin_and_anchor_hashes() {
        let (a, b) = (fallback_list(&[5, 6]), fallback_list(&[7, 8, 9]));

        let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
        let dir = tempfile::tempdir().unwrap();
        let mut app = app_with(l1, engine, fx.params.clone(), dir.path(), test_options());
        init_chain(&mut app, init_chain_request(&document(&fx, &w))).await.unwrap();
        let origin = crate::test_utils::recovery_fallback_keys();
        assert_eq!(held(&app), [origin.hash()]);
        let mut inbox = fx.inbox_at_checkpoint(6, w.el_header.hash_slow());
        inbox.recovery_generation = 1;
        inbox.forced_inclusion_head = 3;
        inbox.forced_inclusion_tail = 3;
        for (number, keys, kept) in [
            (111, &a, ascending([origin.hash(), a.hash()])),
            (112, &b, ascending([origin.hash(), b.hash()])),
            (113, &origin, vec![origin.hash()]),
        ] {
            serve_fallback_keys(app.l1(), fx.params.inbox, keys);
            let inbox = InboxStorage { fallback_keys_hash: keys.hash(), ..inbox.clone() };
            fx.advance_l1(app.l1(), number, &inbox);
            step(&mut app, None).await;
            assert_eq!(app.state().unwrap().anchor.number, number);
            assert_eq!(held(&app), kept, "after the block anchored at L1 block {number}");
        }

        let fx = Fixture::genesis(2);
        let dir = tempfile::tempdir().unwrap();
        let mut app = initialized(&fx, dir.path()).await;
        let origin = fx.fallback_keys.clone();
        assert_eq!(held(&app), [origin.hash()]);
        for (number, keys) in [(66, &a), (67, &b), (68, &origin)] {
            serve_fallback_keys(app.l1(), fx.params.inbox, keys);
            anchor_proving(&fx, &app, number, keys);
            step(&mut app, None).await;
            assert_eq!(held(&app), [keys.hash()], "after the block anchored at L1 block {number}");
        }
    }

    /// A fallback key list the node cannot obtain, and EL state it cannot read, are node-local
    /// faults: a liveness pause, never a safety halt and never a rejection.
    #[test]
    fn unavailable_list_is_never_a_halt_or_a_reject() {
        let list = Rejection::FallbackKeysUnavailable(B256::repeat_byte(7));
        let state = Rejection::ElState("eth_getStorageAt answered JSON-RPC error -32000".into());
        for (rejection, label) in
            [(list, "fallback_keys_unavailable"), (state, "el_state_unavailable")]
        {
            assert!(!rejection.requires_dependency_repair(), "{rejection}");
            assert!(rejection.retryable_dependency(), "{rejection}");
            assert!(!rejection.logs_at_error(), "{rejection}");
            assert_eq!(rejection.label(), label);
        }
    }

    /// A list read gets a deadline long enough for one log query of the most blocks a scan asks
    /// for, beyond the deadline of an ordinary L1 read: a log query answered after three times
    /// that deadline completes, in `ProcessProposal` and in a cold `FinalizeBlock`.
    #[tokio::test(start_paused = true)]
    async fn a_slow_log_query_is_not_cut_at_the_l1_deadline() {
        let fx = Fixture::genesis(2);
        let other = fallback_list(&[5, 6, 7]);
        let limit = Duration::from_secs(600);
        let (dirs, mut req) = ([(); 2].map(|()| tempfile::tempdir().unwrap()), None);
        for (dir, cold) in dirs.iter().zip([false, true]) {
            let mut app = initialized(&fx, dir.path()).await;
            anchor_proving(&fx, &app, 66, &other);
            emit(app.l1(), fx.params.inbox, 66, &other);
            let slow = app.opts.l1_timeout * 3;
            app.l1().state().log_delay = Some(slow);
            let logs = LogCapture::start();
            let req = req.get_or_insert_with(|| anchored_request(&fx, &app, 66)).clone();
            if cold {
                tokio::time::timeout(limit, finalize(&mut app, finalize_req(&req)))
                    .await
                    .expect("the cold FinalizeBlock gets the list")
                    .expect("finalizes");
            } else {
                let resp = tokio::time::timeout(limit, process(&mut app, req))
                    .await
                    .expect("ProcessProposal gets the list");
                assert_eq!(resp, response::ProcessProposal::Accept);
            }
            assert_eq!(app.l1().log_ranges(), [(0, 66)], "one log query, answered after {slow:?}");
            assert!(!logs.text().contains("timed out"), "{}", logs.text());
        }
    }
}
