//! A block's `missBitmap` against its LastCommit, through `PrepareProposal` (the bitmap the
//! proposer builds), `ProcessProposal` (accept or reject) and the `FinalizeBlock` of a node that
//! never judged the block (accept or halt).
//!
//! Unless a test says otherwise, the next height is S + 6, its parent is signed by the
//! fixture's four origin fallback keys at power 1, and each test sets the key-to-seat words of
//! the staking contract in the parent's post-state, one per parent signer in CometBFT order.

use std::time::Duration;

use alloy_primitives::{Address, U256};
use etna_core::staking::{key_to_seat_slot, snapshot_slots};
use proptest::prelude::*;
use tendermint::{abci::types::CommitInfo, block::BlockIdFlag, vote::Power};

use super::{
    proposal::{
        bft_time, commit, finalize, finalize_req, hand_envelope, hand_envelope_with_bitmap, judge,
        mid_epoch, next_height, prepare, prepare_req, process, process_req, propose, step,
    },
    recovery_init::document,
    *,
};
use crate::{
    app::{LastCommitError, validate::Rejection},
    engine::EngineError,
    envelope::EtnaEnvelope,
    rules::{self, RuleViolation},
    test_utils::{
        commit_info, committed_block, extended_commit_info, init_chain_request,
        recovery_fallback_keys, recovery_fixture, test_key, test_options,
    },
    valstate::{ValEntry, comet_order},
};

/// A committed vote for the parent.
const C: BlockIdFlag = BlockIdFlag::Commit;
/// An absent vote.
const A: BlockIdFlag = BlockIdFlag::Absent;
/// A nil vote.
const N: BlockIdFlag = BlockIdFlag::Nil;

/// The four-key fixture every test but the recovery one runs on.
fn fixture() -> Fixture {
    Fixture::genesis(4)
}

/// The set that signs the parent of `app`'s next height, in CometBFT order.
fn parent_signers(app: &App<MockL1, MockEngine>) -> Vec<ValEntry> {
    app.state().expect("initialized").parent_signers.clone()
}

/// The keys and powers of the set that signs the parent of `app`'s next height.
fn parent_members(app: &App<MockL1, MockEngine>) -> Vec<(crate::key::ConsensusKey, i64)> {
    parent_signers(app).iter().map(|entry| (entry.key, entry.power)).collect()
}

/// The keys and powers of `set`.
fn members(set: &[ValEntry]) -> Vec<(crate::key::ConsensusKey, i64)> {
    set.iter().map(|entry| (entry.key, entry.power)).collect()
}

/// The address of the `i`-th validator that signs the parent of `app`'s next height.
fn signer(app: &App<MockL1, MockEngine>, i: usize) -> Address {
    parent_signers(app)[i].key.address()
}

/// Sets `address`'s key-to-seat word in the post-state of block `hash` of `app`'s EL.
fn set_seat_word_at(
    app: &App<MockL1, MockEngine>,
    hash: alloy_primitives::B256,
    address: Address,
    word: U256,
) {
    app.engine().set_storage(hash, app.params.staking, key_to_seat_slot(address), word);
}

/// Sets `address`'s key-to-seat word in the post-state of `app`'s committed parent.
fn set_seat_word(app: &App<MockL1, MockEngine>, address: Address, word: U256) {
    set_seat_word_at(app, app.state().expect("initialized").parent.hash, address, word);
}

/// A node at S + 5 whose parent's post-state holds `words[i]` as the key-to-seat word of the
/// i-th parent signer.
async fn node(fx: &Fixture, dir: &std::path::Path, words: &[U256]) -> App<MockL1, MockEngine> {
    let app = mid_epoch(fx, dir, 5).await;
    for (i, word) in words.iter().enumerate() {
        set_seat_word(&app, signer(&app, i), *word);
    }
    app
}

/// `words` as whole words.
fn words(words: &[u64]) -> Vec<U256> {
    words.iter().copied().map(U256::from).collect()
}

/// The LastCommit of `app`'s next height in which the i-th parent signer has `flags[i]`.
fn last_commit(app: &App<MockL1, MockEngine>, flags: &[BlockIdFlag]) -> CommitInfo {
    commit_info(&parent_signers(app), flags)
}

/// Prepares the next height of `app` with the LastCommit `commit`; returns the envelope.
async fn propose_with(app: &mut App<MockL1, MockEngine>, commit: &CommitInfo) -> EtnaEnvelope {
    let mut req = prepare_req(app, next_height(app), bft_time(app));
    req.local_last_commit = Some(extended_commit_info(commit));
    let txs = prepare(app, req).await;
    assert_eq!(txs.len(), 1, "one envelope; halt = {:?}", app.halt);
    EtnaEnvelope::decode(&txs[0]).expect("the envelope decodes")
}

/// The `ProcessProposal` request of `env` as `app`'s next height with the LastCommit `commit`.
fn process_with(
    app: &App<MockL1, MockEngine>,
    env: &EtnaEnvelope,
    commit: &CommitInfo,
) -> request::ProcessProposal {
    let mut req = process_req(app, next_height(app), bft_time(app), vec![env.encode()]);
    req.proposed_last_commit = Some(commit.clone());
    req
}

/// The `missBitmap` in `env`'s `extraData`.
fn bitmap_of(env: &EtnaEnvelope) -> u128 {
    rules::decode_extra_data(&env.block.header.extra_data).expect("Etna extraData").miss_bitmap
}

/// The storage reads `app`'s EL answered but those of candidate snapshot words, which
/// `FinalizeBlock` makes at the decided block's own hash once it has executed: the block hash and
/// the slots of each.
fn storage_reads(
    app: &App<MockL1, MockEngine>,
) -> Vec<(alloy_primitives::B256, Vec<alloy_primitives::B256>)> {
    let snapshot = snapshot_slots();
    app.engine()
        .calls()
        .into_iter()
        .filter_map(|call| match call {
            EngineCall::StorageAt { hash, slots, .. }
                if !slots.iter().all(|slot| snapshot.contains(slot)) =>
            {
                Some((hash, slots))
            }
            _ => None,
        })
        .collect()
}

/// The `missBitmap` the proposer builds with the parent's words `words` and the LastCommit
/// `flags`, after checking that a validator accepts that block with the same LastCommit and that
/// a node which never judged it finalizes it.
async fn built(fx: &Fixture, words: &[U256], flags: &[BlockIdFlag]) -> u128 {
    let dirs = [(); 3].map(|()| tempfile::tempdir().unwrap());
    let mut proposer = node(fx, dirs[0].path(), words).await;
    let commit = last_commit(&proposer, flags);
    let env = propose_with(&mut proposer, &commit).await;

    let mut validator = node(fx, dirs[1].path(), words).await;
    let req = process_with(&validator, &env, &commit);
    assert_eq!(
        process(&mut validator, req.clone()).await,
        response::ProcessProposal::Accept,
        "halt = {:?}",
        validator.halt
    );

    let mut cold = node(fx, dirs[2].path(), words).await;
    finalize(&mut cold, finalize_req(&req)).await.expect("the cold node finalizes the block");
    bitmap_of(&env)
}

/// A block carrying `bitmap` where the parent's words `words` and the LastCommit `flags` give
/// `expected`: the deterministic check names both, `ProcessProposal` rejects it and a node that
/// never judged it halts.
async fn refused(
    fx: &Fixture,
    words: &[U256],
    flags: &[BlockIdFlag],
    bitmap: u128,
    expected: u128,
) {
    let violation = RuleViolation::MissBitmap { expected, got: bitmap };
    let dirs = [(); 2].map(|()| tempfile::tempdir().unwrap());
    let mut validator = node(fx, dirs[0].path(), words).await;
    let env = hand_envelope_with_bitmap(&validator, bitmap);
    let state = validator.state().unwrap();
    assert_eq!(
        crate::app::validate_block(
            &state.chain_context(),
            &validator.params,
            &env,
            next_height(&validator),
            bft_time(&validator),
            super::proposal::proposer(),
            expected,
        )
        .unwrap_err(),
        Rejection::Rule(violation.clone())
    );
    let commit = last_commit(&validator, flags);
    let req = process_with(&validator, &env, &commit);
    assert_eq!(process(&mut validator, req.clone()).await, response::ProcessProposal::Reject);
    assert_eq!(validator.halt.as_deref(), Some("miss_bitmap"));

    let mut cold = node(fx, dirs[1].path(), words).await;
    let err = finalize(&mut cold, finalize_req(&req)).await.expect_err("a safety halt");
    assert!(
        matches!(&err, AbciError::SafetyHalt(m) if m.contains(&violation.to_string())),
        "{err:?}"
    );
}

/// An absent vote and a nil vote both leave the validator missing: its seat 3 sets bit 3. Two
/// missing validators set both their bits, and a LastCommit that misses nobody sets none.
#[tokio::test]
async fn absent_and_nil_both_set_the_seat_bit() {
    let fx = fixture();
    for flag in [A, N] {
        assert_eq!(built(&fx, &words(&[0, 0x0301, 0, 0]), &[C, flag, C, C]).await, 8, "{flag:?}");
    }
    assert_eq!(built(&fx, &words(&[0x0001, 0, 0x0301, 0]), &[A, C, N, C]).await, 9);
    assert_eq!(built(&fx, &words(&[0x0001, 0x0101, 0x0201, 0x0301]), &[C; 4]).await, 0);
}

/// A missing fallback key that holds no bond has the zero word: no seat, no bit.
#[tokio::test]
async fn missing_fallback_key_without_a_bond_sets_nothing() {
    let fx = fixture();
    assert_eq!(built(&fx, &words(&[0, 0, 0, 0]), &[A, C, C, C]).await, 0);
}

/// A missing fallback key that is also the key of a bond holding seat 7 sets bit 7.
#[tokio::test]
async fn missing_fallback_key_with_a_seated_bond_sets_its_bit() {
    let fx = fixture();
    assert_eq!(built(&fx, &words(&[0x0701, 0, 0, 0]), &[A, C, C, C]).await, 1 << 7);
}

/// A missing validator whose bond vacated seat 4 in the parent's transactions has the zero word
/// in the parent's post-state, even though the grandparent's post-state still gave it seat 4 and
/// the parent's snapshot records are not empty; a key outside the parent's signing set that took
/// seat 4 there is not considered. Only the missing validator's key-to-seat word is read, at the
/// parent's hash.
#[tokio::test]
async fn seat_vacated_in_the_parent_sets_nothing() {
    let fx = fixture();
    let newcomer = test_key(9).address();
    let dirs = [(); 3].map(|()| tempfile::tempdir().unwrap());
    let setup = |app: &App<MockL1, MockEngine>| {
        let state = app.state().unwrap();
        let grandparent = committed_block(state.last_height - 1).hash_slow();
        set_seat_word_at(app, grandparent, signer(app, 0), U256::from(0x0401));
        set_seat_word(app, newcomer, U256::from(0x0401));
        for slot in snapshot_slots() {
            app.engine().set_storage(state.parent.hash, app.params.staking, slot, U256::MAX);
        }
    };
    let mut proposer = node(&fx, dirs[0].path(), &[]).await;
    setup(&proposer);
    let commit = last_commit(&proposer, &[A, C, C, C]);
    let env = propose_with(&mut proposer, &commit).await;
    assert_eq!(bitmap_of(&env), 0);
    let parent = proposer.state().unwrap().parent.hash;
    assert_eq!(storage_reads(&proposer), [(parent, vec![key_to_seat_slot(signer(&proposer, 0))])]);

    let mut validator = node(&fx, dirs[1].path(), &[]).await;
    setup(&validator);
    let req = process_with(&validator, &env, &commit);
    assert_eq!(process(&mut validator, req.clone()).await, response::ProcessProposal::Accept);
    let mut cold = node(&fx, dirs[2].path(), &[]).await;
    setup(&cold);
    finalize(&mut cold, finalize_req(&req)).await.expect("the cold node finalizes the block");

    // A block that sets bit 4 for the vacated seat is refused.
    refused(&fx, &[], &[A, C, C, C], 1 << 4, 0).await;
}

/// Words that are not well formed give no seat: a holdsSeat flag of 2, a seat of 128, a nonzero
/// bit from bit 16 up, and a seat number without the holdsSeat flag. A block that reads the
/// third masked to its low 16 bits, setting bit 3, is refused.
#[tokio::test]
async fn malformed_seat_words_set_nothing() {
    let fx = fixture();
    let malformed = words(&[0x0302, 0x8001, 0x10301, 0x0500]);
    assert_eq!(built(&fx, &malformed, &[A, A, A, A]).await, 0);
    let full_width = [U256::MAX, U256::MAX - U256::from(0xfeff), U256::ZERO, U256::ZERO];
    assert_eq!(built(&fx, &full_width, &[A, N, C, C]).await, 0);
    refused(&fx, &malformed, &[C, C, A, C], 1 << 3, 0).await;
}

/// A bit set for a seat no missing validator holds is refused.
#[tokio::test]
async fn bit_for_an_empty_seat_is_rejected() {
    let fx = fixture();
    let none = words(&[0, 0, 0, 0]);
    assert_eq!(built(&fx, &none, &[C; 4]).await, 0);
    refused(&fx, &none, &[C; 4], 4, 0).await;
}

/// A bit left clear for a missing validator's seat is refused, as is a bitmap built from
/// precommits that reached the proposer after its LastCommit was built.
#[tokio::test]
async fn cleared_bit_for_a_missing_seat_is_rejected() {
    let fx = fixture();
    let seat_3 = words(&[0, 0x0301, 0, 0]);
    assert_eq!(built(&fx, &seat_3, &[C, A, C, C]).await, 8);
    refused(&fx, &seat_3, &[C, A, C, C], 0, 8).await;
}

/// Seat 100, above a 64-seat cap, and seat 127, the highest, set their bits.
#[tokio::test]
async fn seat_at_or_above_n_max_sets_its_bit() {
    let fx = fixture();
    assert_eq!(built(&fx, &words(&[0x6401, 0, 0, 0]), &[A, C, C, C]).await, 1 << 100);
    assert_eq!(built(&fx, &words(&[0, 0, 0, 0x7f01]), &[C, C, C, N]).await, 1 << 127);
}

/// After `InitChain` the parent signers are empty: the first block has an empty LastCommit, its
/// bitmap is 0, nothing is read, and the set that signs it is the one the next LastCommit
/// lists. A nonempty LastCommit there contradicts the replica.
#[tokio::test]
async fn first_block_after_init_chain_has_an_empty_commit_and_bitmap_zero() {
    let fx = fixture();
    let dirs = [(); 4].map(|()| tempfile::tempdir().unwrap());
    let mut proposer = initialized(&fx, dirs[0].path()).await;
    assert!(parent_signers(&proposer).is_empty());
    let env = propose(&mut proposer).await;
    assert_eq!(bitmap_of(&env), 0);

    let mut validator = initialized(&fx, dirs[1].path()).await;
    let (resp, req) = judge(&mut validator, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", validator.halt);
    assert!(req.proposed_last_commit.as_ref().unwrap().votes.is_empty());

    let mut cold = initialized(&fx, dirs[2].path()).await;
    finalize(&mut cold, finalize_req(&req)).await.expect("the cold node finalizes the block");
    commit(&mut cold).await.expect("commits");
    for app in [&proposer, &validator, &cold] {
        assert!(storage_reads(app).is_empty(), "nobody is missing");
    }
    let origin_set = comet_order(&fx.fallback_keys.validator_set()).unwrap();
    assert_eq!(parent_members(&cold), members(&origin_set));

    let mut other = initialized(&fx, dirs[3].path()).await;
    let mut req = prepare_req(&other, next_height(&other), bft_time(&other));
    req.local_last_commit = Some(extended_commit_info(&commit_info(&origin_set, &[C; 4])));
    let err = other.handle(Request::PrepareProposal(req)).await.expect_err("a safety halt");
    let expected = Rejection::LastCommit(LastCommitError::Length { expected: 0, got: 4 });
    assert!(matches!(&err, AbciError::SafetyHalt(m) if *m == expected.to_string()), "{err:?}");
}

/// A recovery generation starts on its origin fallback keys with no parent signers: c + 1 has
/// an empty LastCommit and bitmap 0, and the origin keys sign the parent of c + 2.
#[tokio::test]
async fn recovery_generation_first_block_has_an_empty_commit_and_bitmap_zero() {
    use super::proposal::decide;
    let recovered = |dir: &std::path::Path| {
        let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
        let app = app_with(l1, engine, fx.params.clone(), dir, test_options());
        (fx, w, app)
    };
    let dirs = [(); 2].map(|()| tempfile::tempdir().unwrap());
    let mut nodes = Vec::new();
    for dir in &dirs {
        let (fx, w, mut app) = recovered(dir.path());
        init_chain(&mut app, init_chain_request(&document(&fx, &w))).await.unwrap();
        assert!(parent_signers(&app).is_empty());
        let mut inbox = fx.inbox_at_checkpoint(6, w.el_header.hash_slow());
        inbox.recovery_generation = 1;
        inbox.forced_inclusion_head = 3;
        inbox.forced_inclusion_tail = 3;
        fx.advance_l1(app.l1(), 111, &inbox);
        nodes.push(app);
    }
    let [mut proposer, mut cold] = <[_; 2]>::try_from(nodes).ok().unwrap();
    let env = propose(&mut proposer).await;
    assert_eq!(env.block.header.number, 7, "c + 1");
    assert_eq!(bitmap_of(&env), 0);
    let (resp, req) = judge(&mut proposer, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept, "halt = {:?}", proposer.halt);
    assert!(req.proposed_last_commit.as_ref().unwrap().votes.is_empty());
    finalize(&mut cold, finalize_req(&req)).await.expect("the cold node finalizes the block");
    decide(&mut proposer, &req).await;
    let origin_set = comet_order(&recovery_fallback_keys().validator_set()).unwrap();
    assert_eq!(parent_members(&proposer), members(&origin_set));
}

/// RECOV-8-20a (8.md 20a.b): the candidate signs B − 1 and the fallback key set signs B and
/// B + 1, its members' bonds staying seated. B's LastCommit lists the candidate, the set that
/// signs B − 1: the member whose precommit for B − 1 it lacks sets its seat's bit, the members
/// that committed set none, and a key outside that set, whose bond took a seat in B − 1, sets
/// none. B + 1's LastCommit lists the fallback key set, which signed B: no bond whose key is not
/// a fallback key can set a bit, and a missing fallback key without a bond sets none, so B + 1's
/// bitmap is 0.
#[tokio::test]
async fn first_fallback_block_counts_its_candidate_signed_parent() {
    use super::signers::{self, MIN_STAKE, snapshot};
    let fx = fixture();
    let dir = tempfile::tempdir().unwrap();
    let mut app = signers::node(&fx, dir.path(), U256::from(MIN_STAKE)).await;
    let bonds = [(test_key(11), 2), (test_key(12), 3), (test_key(13), 4)];
    let seat_word = |seat: u64| U256::from((seat << 8) | 1);
    let sorted = |mut set: Vec<(crate::key::ConsensusKey, i64)>| {
        set.sort();
        set
    };
    let fallback = sorted(fx.fallback_keys.keys().iter().map(|&key| (key, 1)).collect());
    let h = next_height(&app);
    // h decides the candidate for h + 2 = B − 1; h + 1's total below the minimum hands h + 3 = B
    // to the fallback keys.
    signers::step(&mut app, Some(snapshot(h, MIN_STAKE, &bonds))).await;
    signers::step(&mut app, Some(snapshot(h + 1, MIN_STAKE - 1, &bonds))).await;
    signers::step(&mut app, None).await;
    assert_eq!(next_height(&app), h + 3, "B");
    let candidate = sorted(bonds.iter().map(|&(key, power)| (key, power as i64)).collect());
    assert_eq!(sorted(parent_members(&app)), candidate, "the candidate signed B − 1");
    let signing_b = members(&app.state().unwrap().val_state.current.entries);
    assert_eq!(sorted(signing_b), fallback, "the fallback keys sign B");

    for (seat, (key, _)) in (0..).zip(&bonds) {
        set_seat_word(&app, key.address(), seat_word(seat));
    }
    set_seat_word(&app, test_key(9).address(), seat_word(5));
    let flags: Vec<_> =
        parent_signers(&app).iter().map(|e| if e.key == test_key(12) { A } else { C }).collect();
    let lacking = last_commit(&app, &flags);
    let env = propose_with(&mut app, &lacking).await;
    assert_eq!(bitmap_of(&env), 1 << 1, "the bond in seat 1 missed B − 1");
    let req = process_with(&app, &env, &lacking);
    assert_eq!(process(&mut app, req.clone()).await, response::ProcessProposal::Accept);
    finalize(&mut app, finalize_req(&req)).await.expect("finalizes B");
    commit(&mut app).await.expect("commits B");

    // B + 1: the bonds hold their seats in B's post-state, and a fallback key misses B.
    for (seat, (key, _)) in (0..).zip(&bonds) {
        set_seat_word(&app, key.address(), seat_word(seat));
    }
    assert_eq!(sorted(parent_members(&app)), fallback, "the fallback keys signed B");
    let mut flags = vec![C; fallback.len()];
    flags[fallback.len() - 1] = A;
    let lacking = last_commit(&app, &flags);
    let env = propose_with(&mut app, &lacking).await;
    assert_eq!(bitmap_of(&env), 0);
    let req = process_with(&app, &env, &lacking);
    assert_eq!(process(&mut app, req).await, response::ProcessProposal::Accept);
}

/// A LastCommit that names another address, gives another power, orders the set otherwise or
/// lists another number of validators contradicts the replica: a safety halt in every handler,
/// before any entry is paired with a validator.
#[tokio::test]
async fn vote_info_that_disagrees_with_the_replica_halts() {
    let fx = fixture();
    let dir = tempfile::tempdir().unwrap();
    let reference = node(&fx, dir.path(), &[]).await;
    let full = last_commit(&reference, &[C, A, C, C]);
    let edit = |f: fn(&mut CommitInfo)| {
        let mut commit = full.clone();
        f(&mut commit);
        commit
    };
    let cases = [
        (
            edit(|c| c.votes[1].validator.address = test_key(9).address().into_array()),
            LastCommitError::Validator { index: 1 },
        ),
        (
            edit(|c| c.votes[1].validator.power = Power::from(2u32)),
            LastCommitError::Power { index: 1 },
        ),
        (edit(|c| c.votes.swap(0, 1)), LastCommitError::Validator { index: 0 }),
        (edit(|c| c.votes.truncate(3)), LastCommitError::Length { expected: 4, got: 3 }),
        (
            edit(|c| {
                let extra = c.votes[0].clone();
                c.votes.push(extra);
            }),
            LastCommitError::Length { expected: 4, got: 5 },
        ),
    ];
    let env = hand_envelope(&reference, None);
    for (commit, error) in cases {
        let halt = Rejection::LastCommit(error).to_string();
        let is_halt =
            |err: &AbciError| matches!(err, AbciError::SafetyHalt(m) if m.contains(&halt));

        let dir = tempfile::tempdir().unwrap();
        let mut app = node(&fx, dir.path(), &[]).await;
        let mut req = prepare_req(&app, next_height(&app), bft_time(&app));
        req.local_last_commit = Some(extended_commit_info(&commit));
        let err = app.handle(Request::PrepareProposal(req)).await.expect_err("halts");
        assert!(is_halt(&err), "{error:?}: {err:?}");

        let dir = tempfile::tempdir().unwrap();
        let mut app = node(&fx, dir.path(), &[]).await;
        let req = process_with(&app, &env, &commit);
        let err = app.handle(Request::ProcessProposal(req.clone())).await.expect_err("halts");
        assert!(is_halt(&err), "{error:?}: {err:?}");

        let dir = tempfile::tempdir().unwrap();
        let mut app = node(&fx, dir.path(), &[]).await;
        let err = finalize(&mut app, finalize_req(&req)).await.expect_err("halts");
        assert!(is_halt(&err), "{error:?}: {err:?}");
        assert!(storage_reads(&app).is_empty(), "{error:?}: nothing is paired or read");
    }
}

/// The proposer builds from the request's `local_last_commit` alone: the same node builds
/// another bitmap for another LastCommit at the same height, and a word it read once at the
/// parent's hash is reused.
#[tokio::test]
async fn prepare_uses_local_last_commit() {
    let fx = fixture();
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(&fx, dir.path(), &words(&[0, 0x0301, 0x0501, 0])).await;
    let parent = app.state().unwrap().parent.hash;
    let missing_1 = last_commit(&app, &[C, A, C, C]);
    assert_eq!(bitmap_of(&propose_with(&mut app, &missing_1).await), 1 << 3);
    let everyone = last_commit(&app, &[C; 4]);
    assert_eq!(bitmap_of(&propose_with(&mut app, &everyone).await), 0);
    let missing_both = last_commit(&app, &[C, A, N, C]);
    assert_eq!(bitmap_of(&propose_with(&mut app, &missing_both).await), (1 << 3) | (1 << 5));
    assert_eq!(bitmap_of(&propose_with(&mut app, &missing_1).await), 1 << 3);
    assert_eq!(
        storage_reads(&app),
        [
            (parent, vec![key_to_seat_slot(signer(&app, 1))]),
            (parent, vec![key_to_seat_slot(signer(&app, 2))]),
        ],
        "each word is read once"
    );
}

/// A node that judged the block live and one that never judged it answer the same
/// `FinalizeBlock` and derive the same state.
#[tokio::test]
async fn cold_finalize_matches_the_live_verdict() {
    let fx = fixture();
    let seat_3 = words(&[0, 0x0301, 0, 0]);
    let dirs = [(); 3].map(|()| tempfile::tempdir().unwrap());
    let mut proposer = node(&fx, dirs[0].path(), &seat_3).await;
    let commit_flags = last_commit(&proposer, &[C, A, C, C]);
    let env = propose_with(&mut proposer, &commit_flags).await;
    assert_eq!(bitmap_of(&env), 8);

    let mut live = node(&fx, dirs[1].path(), &seat_3).await;
    let req = process_with(&live, &env, &commit_flags);
    assert_eq!(process(&mut live, req.clone()).await, response::ProcessProposal::Accept);
    let mut cold = node(&fx, dirs[2].path(), &seat_3).await;
    let reads_before = storage_reads(&live).len();
    let live_resp = finalize(&mut live, finalize_req(&req)).await.unwrap();
    assert_eq!(storage_reads(&live).len(), reads_before, "the verdict stands");
    let cold_resp = finalize(&mut cold, finalize_req(&req)).await.unwrap();
    assert_eq!(cold_resp, live_resp);
    assert_eq!(cold.pending, live.pending);
    commit(&mut live).await.unwrap();
    commit(&mut cold).await.unwrap();
    assert_eq!(cold.state(), live.state());
}

/// A `FinalizeBlock` replayed after a crash before `Commit`, when the EL already executed the
/// block and its post-state gives the missing validator another seat, reads the words at the
/// parent's hash again and answers the same.
#[tokio::test]
async fn seat_words_are_read_at_the_parent_hash_after_the_el_moved_past_it() {
    let fx = fixture();
    let dir = tempfile::tempdir().unwrap();
    let mut app = initialized(&fx, dir.path()).await;
    step(&mut app).await; // S + 1
    let committed = app.state().unwrap().clone();
    let missing = signer(&app, 2);
    set_seat_word(&app, missing, U256::from(0x0301));
    let flags = last_commit(&app, &[C, C, A, C]);
    let env = propose_with(&mut app, &flags).await;
    assert_eq!(bitmap_of(&env), 8);
    let req = finalize_req(&process_with(&app, &env, &flags));
    let first = finalize(&mut app, req.clone()).await.expect("finalizes");
    let hash = env.block.header.hash_slow();
    assert_eq!(
        app.engine().state().chain.get(&(committed.last_height + 1)).map(|h| h.hash_slow()),
        Some(hash),
        "the EL moved on"
    );
    set_seat_word_at(&app, hash, missing, U256::from(0x0501));

    // Crash before Commit: the EL keeps the block and its words, the store the previous height.
    let engine = app.engine().reopen();
    drop(app);
    let mut app = app_with(fx.l1(), engine, fx.params.clone(), dir.path(), test_options());
    assert_eq!(app.state(), Some(&committed));
    info(&mut app).await.expect("Info reconciles with an EL ahead");
    let replayed = finalize(&mut app, req).await.expect("the replay finalizes");
    assert_eq!(replayed, first);
    assert_eq!(
        storage_reads(&app),
        [(committed.parent.hash, vec![key_to_seat_slot(missing)])],
        "read at the parent's hash, never at the block's"
    );
}

/// An EL that cannot answer the seat read, in transport or within the deadline, keeps
/// `ProcessProposal` and `FinalizeBlock` waiting until it answers, and makes `PrepareProposal`
/// propose nothing, its reason unavailable EL state; the transport error's text, which carries
/// the JSON-RPC code, names the refusal.
#[tokio::test(start_paused = true)]
async fn unavailable_el_waits_in_process_and_placeholders_prepare() {
    let fx = fixture();
    let seat_3 = words(&[0, 0x0301, 0, 0]);
    let down = || EngineError::Transport("eth_getStorageAt answered JSON-RPC error -32000".into());
    let dirs = [(); 3].map(|()| tempfile::tempdir().unwrap());

    let mut proposer = node(&fx, dirs[0].path(), &seat_3).await;
    let flags = last_commit(&proposer, &[C, A, C, C]);
    proposer.engine().state().storage_script.push_back(Err(down()));
    let mut req = prepare_req(&proposer, next_height(&proposer), bft_time(&proposer));
    req.local_last_commit = Some(extended_commit_info(&flags));
    assert!(prepare(&mut proposer, req).await.is_empty(), "a placeholder proposal");
    assert_eq!(proposer.halt.as_deref(), Some("el_state_unavailable"));
    let env = propose_with(&mut proposer, &flags).await;
    assert_eq!(bitmap_of(&env), 8);

    let mut validator = node(&fx, dirs[1].path(), &seat_3).await;
    {
        let mut engine = validator.engine().state();
        engine.delay_script.push_back(validator.opts.engine_timeout + Duration::from_secs(1));
        engine.storage_script.extend([Err(down()), Err(down())]);
    }
    let req = process_with(&validator, &env, &flags);
    let logs = crate::test_utils::LogCapture::start();
    assert_eq!(process(&mut validator, req.clone()).await, response::ProcessProposal::Accept);
    // The mock records a read once its delay ends, so the timed-out one is not listed.
    assert_eq!(storage_reads(&validator).len(), 3, "down twice, then answered");
    let warned = logs.at("WARN");
    assert!(warned.iter().any(|line| line.contains("-32000")), "the cause is logged: {warned:?}");

    let mut cold = node(&fx, dirs[2].path(), &seat_3).await;
    cold.engine().state().storage_script.extend([Err(down()), Err(down())]);
    finalize(&mut cold, finalize_req(&req)).await.expect("the cold node finalizes the block");
    assert_eq!(storage_reads(&cold).len(), 3, "down twice, then answered");
}

/// A seat read the EL answers with another number of words, or with a malformed reply, needs
/// repair: a safety halt in every handler, never a zero word.
#[tokio::test]
async fn malformed_el_reply_halts() {
    let fx = fixture();
    let seat_3 = words(&[0, 0x0301, 0, 0]);
    let dir = tempfile::tempdir().unwrap();
    let reference = node(&fx, dir.path(), &seat_3).await;
    let flags = last_commit(&reference, &[C, A, C, C]);
    let env = hand_envelope_with_bitmap(&reference, 8);
    for reply in [Ok(vec![]), Ok(vec![U256::ZERO; 2]), Err(EngineError::BadReply("null".into()))] {
        let case = format!("{reply:?}");
        let halts = |err: &AbciError| matches!(err, AbciError::SafetyHalt(_));

        let dir = tempfile::tempdir().unwrap();
        let mut app = node(&fx, dir.path(), &seat_3).await;
        app.engine().state().storage_script.push_back(reply.clone());
        let mut req = prepare_req(&app, next_height(&app), bft_time(&app));
        req.local_last_commit = Some(extended_commit_info(&flags));
        let err = app.handle(Request::PrepareProposal(req)).await.expect_err("halts");
        assert!(halts(&err), "{case}: {err:?}");

        let dir = tempfile::tempdir().unwrap();
        let mut app = node(&fx, dir.path(), &seat_3).await;
        app.engine().state().storage_script.push_back(reply.clone());
        let req = process_with(&app, &env, &flags);
        let err = app.handle(Request::ProcessProposal(req.clone())).await.expect_err("halts");
        assert!(halts(&err), "{case}: {err:?}");

        let dir = tempfile::tempdir().unwrap();
        let mut app = node(&fx, dir.path(), &seat_3).await;
        app.engine().state().storage_script.push_back(reply);
        let err = finalize(&mut app, finalize_req(&req)).await.expect_err("halts");
        assert!(halts(&err), "{case}: {err:?}");
    }
}

/// A key-to-seat word: well formed, zero, any low 16 bits, well formed but for one high bit,
/// or any full-width word.
fn seat_word() -> impl Strategy<Value = U256> {
    prop_oneof![
        3 => (0u64..128).prop_map(|seat| U256::from((seat << 8) | 1)),
        1 => Just(U256::ZERO),
        2 => (0u64..=0xffff).prop_map(U256::from),
        1 => ((0u64..128), 16usize..256)
            .prop_map(|(seat, bit)| U256::from((seat << 8) | 1) | (U256::from(1) << bit)),
        1 => any::<[u8; 32]>().prop_map(U256::from_be_bytes),
    ]
}

/// A LastCommit flag.
fn flag() -> impl Strategy<Value = BlockIdFlag> {
    prop_oneof![Just(C), Just(A), Just(N)]
}

/// The bitmap the rule gives, written from its text: bit s is 1 exactly when some validator
/// whose flag is not commit has a word with holdsSeat 1 in bits 0..8, seat s below 128 in bits
/// 8..16 and nothing from bit 16 up.
fn reference_bitmap(flags: &[BlockIdFlag], words: &[U256]) -> u128 {
    let mut bitmap = 0;
    for (flag, &word) in flags.iter().zip(words) {
        let holds_seat = word & U256::from(0xff);
        let seat: U256 = (word >> 8) & U256::from(0xff);
        if *flag != C &&
            holds_seat == U256::from(1) &&
            seat < U256::from(128) &&
            word >> 16 == U256::ZERO
        {
            bitmap |= 1u128 << seat.to::<u32>();
        }
    }
    bitmap
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 32, ..ProptestConfig::default() })]

    /// The proposer's bitmap equals the reference model for generated LastCommits and words, and
    /// a validator with the same words accepts the block.
    #[test]
    fn bitmap_matches_a_reference_model(
        flags in prop::collection::vec(flag(), 4),
        words in prop::collection::vec(seat_word(), 4),
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("a current-thread runtime");
        let (built, accepted) = runtime.block_on(async {
            let fx = fixture();
            let dir = tempfile::tempdir().unwrap();
            let mut app = node(&fx, dir.path(), &words).await;
            let commit = last_commit(&app, &flags);
            let env = propose_with(&mut app, &commit).await;
            let req = process_with(&app, &env, &commit);
            (bitmap_of(&env), process(&mut app, req).await)
        });
        prop_assert_eq!(built, reference_bitmap(&flags, &words));
        prop_assert_eq!(accepted, response::ProcessProposal::Accept);
    }
}
