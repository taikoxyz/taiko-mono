//! Cancellation and identity boundaries of authenticated admission-byte reads.
use std::time::Duration;

use super::*;
use crate::{forced::ForcedEntry, test_utils::L1Call};
use alloy_primitives::{Bytes, keccak256};

fn entry(tx: &Bytes, block: u64) -> ForcedEntry {
    ForcedEntry { index: 0, tx_hash: keccak256(tx), timestamp: 1, l1_block: block, fee_in_gwei: 7 }
}
fn install(app: &App<MockL1, MockEngine>, e: ForcedEntry, tx: Bytes) {
    app.l1().state().forced_transactions.insert((app.params.inbox, e.index, e.l1_block), tx);
}
fn reads(app: &App<MockL1, MockEngine>) -> usize {
    app.l1().calls().iter().filter(|c| matches!(c, L1Call::ForcedTransaction { .. })).count()
}
async fn cancel_waiter(app: &App<MockL1, MockEngine>, e: ForcedEntry) {
    assert!(
        tokio::time::timeout(Duration::from_millis(1), app.forced_transaction(e)).await.is_err()
    );
    assert_eq!(app.l1().state().in_flight, 1, "the owned read survives its round");
}

#[tokio::test(start_paused = true)]
async fn admission_cache_cancelled_round_reuses_completed_read() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let app = fx.app(dir.path());
    let tx = Bytes::from_static(b"authenticated bytes");
    let e = entry(&tx, 66);
    install(&app, e, tx.clone());
    app.l1().state().delay = Some(Duration::from_secs(1));
    cancel_waiter(&app, e).await;
    tokio::time::advance(Duration::from_secs(1)).await;
    tokio::task::yield_now().await;
    assert_eq!(app.forced_transaction(e).await.unwrap(), tx);
    assert_eq!(app.forced_transaction(e).await.unwrap(), tx);
    assert_eq!(reads(&app), 1, "one read across cancellation and reuse");
}

#[tokio::test(start_paused = true)]
async fn admission_cache_replaces_in_flight_identity_at_same_cursor() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let app = fx.app(dir.path());
    let old = Bytes::from_static(b"old bytes");
    let new = Bytes::from_static(b"new bytes");
    let a = entry(&old, 66);
    let b = entry(&new, 67);
    install(&app, a, old);
    install(&app, b, new.clone());
    app.l1().state().delay = Some(Duration::from_secs(1));
    cancel_waiter(&app, a).await;
    assert_eq!(app.forced_transaction(b).await.unwrap(), new);
    assert_eq!(app.l1().state().in_flight, 0);
    assert_eq!(reads(&app), 1, "obsolete fetch cancelled before returning");
    assert_eq!(app.forced_transaction(b).await.unwrap(), new);
    assert_eq!(reads(&app), 1);
}

#[tokio::test(start_paused = true)]
async fn admission_cache_failed_cancelled_read_retries_after_recovery() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let app = fx.app(dir.path());
    let tx = Bytes::from_static(b"recovered bytes");
    let e = entry(&tx, 66);
    app.l1().state().delay = Some(Duration::from_secs(1));
    cancel_waiter(&app, e).await;
    tokio::time::advance(Duration::from_secs(1)).await;
    tokio::task::yield_now().await;
    assert_eq!(reads(&app), 1);
    install(&app, e, tx.clone());
    assert_eq!(app.forced_transaction(e).await.unwrap(), tx);
    assert_eq!(reads(&app), 2, "failed reads do not poison later rounds");
}

#[tokio::test(start_paused = true)]
async fn admission_cache_app_drop_cancels_owned_read() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let app = fx.app(dir.path());
    let e = entry(&Bytes::from_static(b"pending"), 66);
    let l1 = Arc::clone(&app.l1);
    app.l1().state().delay = Some(Duration::from_secs(1));
    cancel_waiter(&app, e).await;
    drop(app);
    tokio::task::yield_now().await;
    assert_eq!(l1.state().in_flight, 0, "dropping app cancels event I/O");
    tokio::time::advance(Duration::from_secs(2)).await;
    assert!(l1.calls().is_empty(), "the abandoned read never returns");
}
