//! Checkpoint trust in a recovery generation (g ≥ 1): a session authenticates the recovery
//! evidence once, when it is established (RECOV-8.4-2, SYNC-9-4), and then follows the own
//! finalized L1 view exactly as generation zero does (SYNC-9-6a). A larger generation revokes a
//! following session while the process keeps running (RECOV-8-15) and halts a startup or
//! signer-session check (RECOV-8-16).
use std::{
    path::Path,
    sync::{Arc, Mutex},
    time::Duration,
};

use alloy_primitives::B256;

use super::{
    recovery_init::{checkpoint, checkpoint_at, document, request, retained},
    *,
};
use crate::{
    app::trust::{FOLLOW_RETRY_MAX, TrustPhase},
    l1::{L1Error, layout::inbox},
    recovery::RecoveryWitness,
    test_utils::{L1Call, l1_header, recovery_fixture, test_options},
};

/// The recovery origin c of [`recovered`].
const C: u64 = 6;

/// A checkpoint above c that a recovered node has not reached, with its EL and Comet hashes.
const AHEAD: (u64, [B256; 2]) = (12, [B256::repeat_byte(0x12), B256::repeat_byte(0x13)]);

/// Generation 1 recovered at c ([`recovery_fixture`]) after `InitChain`, with the latest
/// checkpoint c at the finalized L1 block 120. Its trust session is still acquiring.
async fn recovered(dir: &Path) -> (Fixture, RecoveryWitness, App<MockL1, MockEngine>) {
    let (fx, l1, engine, w) = recovery_fixture(1, C, 1);
    checkpoint(&fx, &l1, &w, C, retained(&w), 1);
    let mut app = app_with(l1, engine, fx.params.clone(), dir, test_options());
    init_chain(&mut app, request(&document(&fx, &w))).await.unwrap();
    (fx, w, app)
}

/// [`recovered`], with its session trusted at c.
async fn trusted(dir: &Path) -> (Fixture, RecoveryWitness, App<MockL1, MockEngine>) {
    let (fx, w, mut app) = recovered(dir).await;
    app.refresh_trust().await.unwrap();
    assert_trusted_at_origin(&app, "after InitChain");
    (fx, w, app)
}

/// Asserts that `app` is ready at c with c + 1 as its eligible height: signing is open.
fn assert_trusted_at_origin(app: &App<MockL1, MockEngine>, when: &str) {
    let snapshot = app.trust.snapshot();
    assert!(snapshot.is_ready(), "{when}: {:?}", snapshot.reason);
    assert_eq!(snapshot.target.unwrap().height, C, "{when}");
    assert_eq!(snapshot.eligible_height, Some(C + 1), "{when}");
}

/// Makes the L1 block `number` final with block 120's state: the same latest checkpoint and
/// generation at a newer finalized block, so the follow path reads it in full.
fn advance(app: &App<MockL1, MockEngine>, number: u64) {
    let state = app.l1().state().states[&120].clone();
    app.l1().insert_block(l1_header(number, Fixture::l1_timestamp(number)), state);
    app.l1().set_finalized(number);
}

/// One way the own L1 fails, by name, and how to make the mock L1 fail that way.
type Flap = (&'static str, fn(&MockL1));

/// The ways the own L1 fails or lags on the reads the trust worker makes, each the kind of read
/// a recovery evidence check makes (the finalized number, the canonical hashes of L1_0, R and
/// the historical anchor, a header, the Inbox proof of the origin record) or one that times
/// out, and an own L1 whose finalized view is behind R.
fn flaps() -> [Flap; 8] {
    fn down(what: &str) -> L1Error {
        L1Error::Rpc(format!("{what} unavailable"))
    }
    [
        ("unreachable", |l1| l1.state().fail = Some(L1Error::Rpc("connection refused".into()))),
        ("finalized number", |l1| l1.state().finalized_script.push_back(Err(down("finalized")))),
        ("canonical hash", |l1| l1.state().canonical_script.push_back(Err(down("canonical hash")))),
        ("header", |l1| l1.state().header_fail = Some(down("header"))),
        ("Inbox proof", |l1| l1.state().proof_fail = Some(down("eth_getProof"))),
        ("origin record proof", |l1| {
            l1.state().proof_fail_slot = Some((inbox::origin_slots(1)[0], down("origin record")));
        }),
        ("timeout", |l1| l1.state().delay = Some(Duration::from_secs(60))),
        ("behind R", |l1| l1.state().finalized = 99),
    ]
}

/// Ends every failure [`flaps`] sets, except the finalized number, which the caller restores.
fn heal(l1: &MockL1) {
    let mut l1 = l1.state();
    l1.fail = None;
    l1.finalized_script.clear();
    l1.canonical_script.clear();
    l1.header_fail = None;
    l1.proof_fail = None;
    l1.proof_fail_slot = None;
    l1.delay = None;
}

/// A trusted recovery generation's snapshot names, in its recovery origin, the
/// `fallbackKeysHash` its origin record holds, whose keys sign c + 1 and c + 2; the wire has no
/// committee hash.
#[tokio::test]
async fn recovery_origin_reports_the_origin_hash() {
    let dir = tempfile::tempdir().unwrap();
    let (fx, w, app) = trusted(dir.path()).await;
    let origin = crate::recovery::verify_recovery_witness(&w, &fx.params).unwrap();
    let snapshot = app.trust.snapshot();
    let reported = snapshot.recovery_origin.as_ref().expect("a recovery origin");
    assert_eq!(reported.fallback_keys_hash, origin.fallback_keys_hash);
    assert_eq!(reported.fallback_keys_hash, crate::test_utils::recovery_fallback_keys().hash());
    let wire = serde_json::to_value(&snapshot).unwrap();
    assert_eq!(
        wire["recovery_origin"]["fallback_keys_hash"],
        serde_json::to_value(origin.fallback_keys_hash).unwrap()
    );
    assert!(wire["recovery_origin"].get("committee_hash").is_none());
}

/// SYNC-9-6a 6a.g, RECOV-8-5: a ready recovery generation whose own L1 fails, times out or lags
/// on any read keeps its matched result: signing stays open in the same session and nothing
/// halts. Each read fails while a newer finalized block is to be followed.
#[tokio::test(start_paused = true)]
async fn a_ready_recovery_generation_keeps_its_matched_result_while_l1_flaps() {
    let dir = tempfile::tempdir().unwrap();
    let (_, _, mut app) = trusted(dir.path()).await;
    let session = app.trust.snapshot().session_id;
    let mut number = 120;
    for (name, flap) in flaps() {
        number += 1;
        advance(&app, number);
        flap(app.l1());
        app.refresh_trust().await.unwrap_or_else(|e| panic!("{name}: {e}"));
        assert_trusted_at_origin(&app, name);
        assert!(app.store.fatal_evidence().unwrap().is_none(), "{name}");
        heal(app.l1());
        app.l1().set_finalized(number);
        tokio::time::advance(FOLLOW_RETRY_MAX).await;
        app.refresh_trust().await.unwrap();
        assert_trusted_at_origin(&app, name);
    }
    assert_eq!(app.trust.snapshot().session_id, session);
}

/// SYNC-9-7 7.a/7.e: an acquiring recovery session whose own L1 fails, times out or lags
/// on its evidence check stays acquiring with the reason, halts nothing and becomes ready once
/// the own L1 answers. An own L1 that falls behind R after the check waits as well: below R its
/// Inbox still shows the older generation, which is missing data, not a contradiction.
#[tokio::test(start_paused = true)]
async fn an_acquiring_recovery_session_waits_through_l1_flaps() {
    let dir = tempfile::tempdir().unwrap();
    let (fx, w, mut app) = recovered(dir.path()).await;
    let waits = |app: &App<MockL1, MockEngine>, name: &str| {
        let snapshot = app.trust.snapshot();
        assert_eq!(snapshot.phase, TrustPhase::Acquiring, "{name}: {:?}", snapshot.reason);
        assert!(snapshot.reason.is_some(), "{name}");
        assert!(app.store.fatal_evidence().unwrap().is_none(), "{name}");
    };
    for (name, flap) in flaps() {
        flap(app.l1());
        app.refresh_trust().await.unwrap_or_else(|e| panic!("{name}: missing data halted: {e}"));
        waits(&app, name);
        heal(app.l1());
        app.l1().set_finalized(120);
        app.refresh_trust().await.unwrap();
        assert_trusted_at_origin(&app, name);
        // The next flap meets a new signer session's check.
        app.trust.begin_session();
    }

    // The evidence check reads the finalized number twice (its own view and the historical
    // anchor's); the latest-checkpoint read then fails, so the session checked its evidence but
    // observed nothing yet. Then the own L1 fails over to a node behind R.
    app.l1().state().finalized_script.extend([Ok(120), Ok(120), Err(L1Error::Rpc("lost".into()))]);
    app.refresh_trust().await.unwrap();
    waits(&app, "latest checkpoint unavailable");
    let r = w.recovery_header.number();
    checkpoint_at(&fx, app.l1(), &w, r - 1, C, retained(&w), 0);
    app.refresh_trust().await.unwrap_or_else(|e| panic!("an own L1 behind R halted: {e}"));
    waits(&app, "behind R");
    assert!(app.trust.snapshot().reason.unwrap().contains("recovery block"));
    app.l1().set_finalized(120);
    app.refresh_trust().await.unwrap();
    assert_trusted_at_origin(&app, "back at 120");
}

/// A session authenticates the recovery evidence once: a closed session catching up reads
/// nothing of it again, and a ready one reads only what generation zero's follow path does:
/// the finalized number while it is unchanged, the latest checkpoint at a newer one. A new
/// signer session checks the evidence again.
#[tokio::test]
async fn a_recovery_session_authenticates_its_evidence_once() {
    let dir = tempfile::tempdir().unwrap();
    let (fx, w, mut app) = recovered(dir.path()).await;
    let (height, hashes) = AHEAD;
    checkpoint_at(&fx, app.l1(), &w, 121, height, hashes, 1);
    app.refresh_trust().await.unwrap();
    let snapshot = app.trust.snapshot();
    assert_eq!(snapshot.phase, TrustPhase::CatchingUp, "{:?}", snapshot.reason);
    assert!(snapshot.recovery_origin.is_some());
    let before = app.l1().calls().len();
    app.refresh_trust().await.unwrap();
    assert_eq!(app.l1().calls()[before..], [L1Call::Finalized], "catching up");

    let dir = tempfile::tempdir().unwrap();
    let (fx, w, mut app) = trusted(dir.path()).await;
    let before = app.l1().calls().len();
    app.refresh_trust().await.unwrap();
    assert_eq!(app.l1().calls()[before..], [L1Call::Finalized], "ready, unchanged");
    advance(&app, 121);
    let before = app.l1().calls().len();
    app.refresh_trust().await.unwrap();
    assert_eq!(
        app.l1().calls()[before..],
        [
            L1Call::Finalized,
            L1Call::Header(121),
            L1Call::AccountWitness {
                address: fx.params.inbox,
                slots: inbox::anchor_slots(),
                block: 121
            },
            L1Call::Finalized,
            L1Call::CanonicalHash(121),
        ],
        "ready, newer finalized block"
    );
    assert_trusted_at_origin(&app, "after following");
    app.trust.begin_session();
    let before = app.l1().calls().len();
    app.refresh_trust().await.unwrap();
    assert_trusted_at_origin(&app, "new session");
    let r = w.recovery_header.number();
    assert!(app.l1().calls()[before..].contains(&L1Call::CanonicalHash(r)), "R checked again");
}

/// SYNC-9-7 7.b, RECOV-8.4-2: recovery evidence the own finalized L1 view contradicts, R no
/// longer canonical at startup or the historical anchor off-chain at a new signer session, is a
/// safety halt with the fatal record.
#[tokio::test]
async fn a_recovery_evidence_contradiction_halts_at_a_session_check() {
    for reconnect in [false, true] {
        let dir = tempfile::tempdir().unwrap();
        let (fx, _, mut app) =
            if reconnect { trusted(dir.path()).await } else { recovered(dir.path()).await };
        if reconnect {
            app.trust.begin_session();
        }
        let retained = app.store.load_recovery_bootstrap().unwrap().unwrap();
        let w = retained.verify(&fx.params).unwrap().witness;
        // The check reads the canonical hashes of the retained witness's L1_0, R and finalized
        // headers and of the current finalized block, then the historical anchor's.
        let mut answers = vec![w.genesis.l1_header.hash()];
        let expected = if reconnect {
            let current = app.l1().state().headers[&120].hash();
            answers.extend([w.recovery_header.hash(), w.finalized_header.hash(), current]);
            "historical recovery anchor changed"
        } else {
            "retained L1 header is not canonical"
        };
        answers.push(B256::repeat_byte(0xbd));
        app.l1().state().canonical_script.extend(answers.into_iter().map(Ok));
        let result = app.refresh_trust().await;
        assert!(
            matches!(&result, Err(AbciError::SafetyHalt(reason)) if reason.contains(expected)),
            "reconnect {reconnect}: {result:?}"
        );
        assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
        assert!(app.store.fatal_evidence().unwrap().is_some());
    }
}

/// SYNC-9-7 7.b: from R on the Inbox generation never decreases, so a following recovery
/// session whose own finalized view at or after R shows a smaller one halts for safety. (Below
/// R it is a lagging view: see [`an_acquiring_recovery_session_waits_through_l1_flaps`].)
#[tokio::test]
async fn a_smaller_generation_at_or_after_r_halts_a_following_recovery_session() {
    let dir = tempfile::tempdir().unwrap();
    let (fx, w, mut app) = trusted(dir.path()).await;
    checkpoint_at(&fx, app.l1(), &w, 121, C, retained(&w), 0);
    let result = app.refresh_trust().await;
    assert!(
        matches!(&result, Err(AbciError::SafetyHalt(reason)) if reason.contains("below this chain's")),
        "{result:?}"
    );
    assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
    assert!(app.store.fatal_evidence().unwrap().is_some());
}

/// Asserts that the store in `dir` holds the generic fatal record and that a restart over it
/// refuses (RECOV-8-16).
fn assert_restart_refused(fx: &Fixture, dir: &Path) {
    assert!(Store::volatile(dir.into()).fatal_evidence().unwrap().is_some());
    let restart = App::new(
        fx.l1(),
        fx.engine(),
        fx.params.clone(),
        Store::volatile(dir.into()),
        test_options(),
    );
    assert!(matches!(restart, Err(AbciError::SafetyHalt(_))));
}

/// SYNC-9-6a 6a.l/6a.m, RECOV-8-14/8-15 15.d, RECOV-8.2-5: a recovery generation that follows
/// the own finalized L1 view, ready or catching up to a newer checkpoint, revokes its trust
/// when that view shows a larger `recoveryGeneration`, also after a failed read: `/trust`
/// reports halted, the chain is superseded, a reconnect cannot reopen it, the process keeps
/// running and the next start refuses.
#[tokio::test(start_paused = true)]
async fn a_larger_generation_revokes_a_following_recovery_session() {
    for pending in [false, true] {
        let dir = tempfile::tempdir().unwrap();
        let (fx, w, mut app) = trusted(dir.path()).await;
        app.l1().state().fail = Some(L1Error::Rpc("connection refused".into()));
        app.refresh_trust().await.unwrap();
        app.l1().state().fail = None;
        tokio::time::advance(FOLLOW_RETRY_MAX).await;
        let (height, hashes) = if pending { AHEAD } else { (C, retained(&w)) };
        if pending {
            checkpoint_at(&fx, app.l1(), &w, 121, height, hashes, 1);
            app.refresh_trust().await.unwrap();
            assert_eq!(app.trust.snapshot().phase, TrustPhase::CatchingUp);
        }
        checkpoint_at(&fx, app.l1(), &w, 122, height, hashes, 2);
        app.refresh_trust().await.expect("a revocation keeps the process running");
        let snapshot = app.trust.snapshot();
        assert_eq!(snapshot.phase, TrustPhase::Halted, "pending {pending}");
        assert_eq!(snapshot.eligible_height, None);
        assert!(snapshot.reason.unwrap().contains("recovery generation 2"));
        assert!(app.status().unwrap().superseded);
        assert_eq!(app.trust.begin_session().phase, TrustPhase::Halted);
        assert_restart_refused(&fx, dir.path());
    }
}

/// RECOV-8-16 16.b: a startup or signer-session trust check of a recovery generation that finds
/// a larger Inbox generation is a safety halt with the fatal record.
#[tokio::test]
async fn a_larger_generation_at_a_recovery_session_check_halts() {
    for reconnect in [false, true] {
        let dir = tempfile::tempdir().unwrap();
        let (fx, w, mut app) =
            if reconnect { trusted(dir.path()).await } else { recovered(dir.path()).await };
        if reconnect {
            app.trust.begin_session();
        }
        checkpoint_at(&fx, app.l1(), &w, 121, C, retained(&w), 2);
        let result = app.refresh_trust().await;
        assert!(
            matches!(&result, Err(AbciError::SafetyHalt(reason)) if reason.contains("superseded")),
            "reconnect {reconnect}: {result:?}"
        );
        assert_eq!(app.trust.snapshot().phase, TrustPhase::Halted);
        assert_restart_refused(&fx, dir.path());
    }
}

/// The process behaviour of the two outcomes, through the app worker: a following recovery
/// session that sees a larger generation is revoked and the worker keeps running without the
/// halt hook (RECOV-8-15); a startup check that sees it halts, and the worker stops through the
/// hook, which exits the process in production (RECOV-8-16).
#[tokio::test(start_paused = true)]
async fn the_worker_keeps_running_after_a_revocation_and_stops_on_a_session_check_halt() {
    for following in [true, false] {
        let dir = tempfile::tempdir().unwrap();
        let (fx, w, app) =
            if following { trusted(dir.path()).await } else { recovered(dir.path()).await };
        checkpoint_at(&fx, app.l1(), &w, 121, C, retained(&w), 2);
        let trust = app.trust_handle();
        let halts = Arc::new(Mutex::new(Vec::<String>::new()));
        let hook = {
            let halts = halts.clone();
            move |reason: &str| halts.lock().unwrap().push(reason.to_owned())
        };
        let (_service, worker) = crate::server::AppService::spawn(app, hook);
        tokio::time::timeout(Duration::from_secs(10), async {
            while trust.snapshot().phase != TrustPhase::Halted {
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
        })
        .await
        .unwrap();
        tokio::time::sleep(Duration::from_secs(5)).await;
        if following {
            assert!(!worker.is_finished(), "a revocation keeps the worker running");
            assert!(halts.lock().unwrap().is_empty());
            worker.abort();
            let _ = worker.await;
        } else {
            let stopped = worker.await.unwrap();
            assert!(stopped.starts_with("checkpoint trust failed"), "{stopped}");
            assert_eq!(halts.lock().unwrap().len(), 1);
        }
        assert_restart_refused(&fx, dir.path());
    }
}
