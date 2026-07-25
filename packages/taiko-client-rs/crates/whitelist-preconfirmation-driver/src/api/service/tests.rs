use std::{
    io::Write,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicUsize, Ordering},
    },
    time::{Duration, Instant},
};

use flate2::{Compression, write::ZlibEncoder};

use crate::{
    api::service::{
        SHUTDOWN_BLOCK_WINDOW, can_shutdown_for, retry_post_insert_step,
        run_serialized_drop_resistant_build,
    },
    cache::SharedPreconfState,
    codec::{MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES, decompress_tx_list},
    error::WhitelistPreconfirmationDriverError,
};

#[tokio::test]
async fn drop_resistant_build_continues_after_requester_is_aborted() {
    let build_lock = Arc::new(tokio::sync::Mutex::new(()));
    let entered = Arc::new(tokio::sync::Semaphore::new(0));
    let release = Arc::new(tokio::sync::Semaphore::new(0));
    let completed = Arc::new(tokio::sync::Semaphore::new(0));

    let build_entered = Arc::clone(&entered);
    let build_release = Arc::clone(&release);
    let build_completed = Arc::clone(&completed);
    let requester = tokio::spawn(run_serialized_drop_resistant_build(
        build_lock,
        move |_build_guard| async move {
            build_entered.add_permits(1);
            build_release.acquire().await.expect("release semaphore should remain open").forget();
            build_completed.add_permits(1);
            Ok::<_, WhitelistPreconfirmationDriverError>(())
        },
    ));

    entered.acquire().await.expect("entry semaphore should remain open").forget();
    requester.abort();
    assert!(requester.await.expect_err("requester task should be cancelled").is_cancelled());

    release.add_permits(1);
    tokio::time::timeout(Duration::from_secs(1), completed.acquire())
        .await
        .expect("detached build should finish after requester cancellation")
        .expect("completion semaphore should remain open")
        .forget();
}

#[tokio::test]
async fn build_waiting_for_serialization_lock_is_cancelled_with_requester() {
    let build_lock = Arc::new(tokio::sync::Mutex::new(()));
    let held_guard = Arc::clone(&build_lock).lock_owned().await;
    let started = Arc::new(AtomicBool::new(false));
    let build_started = Arc::clone(&started);

    let requester = tokio::spawn(run_serialized_drop_resistant_build(
        build_lock,
        move |_build_guard| async move {
            build_started.store(true, Ordering::Release);
            Ok::<_, WhitelistPreconfirmationDriverError>(())
        },
    ));
    tokio::task::yield_now().await;
    requester.abort();
    assert!(requester.await.expect_err("requester task should be cancelled").is_cancelled());

    drop(held_guard);
    tokio::task::yield_now().await;
    assert!(!started.load(Ordering::Acquire), "cancelled lock waiter must not detach a build");
}

#[tokio::test]
async fn post_insert_finalization_retries_transient_failures() {
    let attempts = Arc::new(AtomicUsize::new(0));
    let operation_attempts = Arc::clone(&attempts);
    let finalization = tokio::spawn(retry_post_insert_step(42, "test_step", move || {
        let operation_attempts = Arc::clone(&operation_attempts);
        async move {
            let attempt = operation_attempts.fetch_add(1, Ordering::AcqRel);
            if attempt < 2 { Err("transient failure") } else { Ok(0x2au64) }
        }
    }));

    tokio::task::yield_now().await;
    assert_eq!(attempts.load(Ordering::Acquire), 1);

    assert_eq!(
        tokio::time::timeout(Duration::from_secs(4), finalization)
            .await
            .expect("retry task should finish after two transient failures")
            .expect("retry task should not panic"),
        0x2a
    );
    assert_eq!(attempts.load(Ordering::Acquire), 3);
}

fn compress(payload: &[u8]) -> Vec<u8> {
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(payload).expect("write zlib payload");
    encoder.finish().expect("finish zlib encoding")
}

#[test]
fn decompress_tx_list_rejects_oversized_compressed_payload() {
    let oversized = vec![0u8; MAX_COMPRESSED_TX_LIST_BYTES + 1];
    let err = decompress_tx_list(&oversized).expect_err("oversized compressed payload must fail");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("compressed tx list exceeds maximum size")
    ));
}

#[test]
fn decompress_tx_list_rejects_oversized_decompressed_payload() {
    let oversized = vec![0x11u8; MAX_DECOMPRESSED_TX_LIST_BYTES + 1];
    let compressed = compress(&oversized);
    let err = decompress_tx_list(&compressed)
        .expect_err("oversized decompressed payload must fail before use");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("decompressed tx list exceeds maximum size")
    ));
}

#[test]
fn decompress_tx_list_accepts_non_empty_payload_within_limits() {
    let expected = vec![0xAA, 0xBB, 0xCC];
    let compressed = compress(&expected);
    let decoded = decompress_tx_list(&compressed).expect("valid payload should decode");
    assert_eq!(decoded, expected);
}

#[test]
fn can_shutdown_returns_true_when_no_request_received() {
    assert!(can_shutdown_for(None));
}

#[test]
fn can_shutdown_returns_false_for_request_just_now() {
    assert!(!can_shutdown_for(Some(Instant::now())));
}

#[test]
fn can_shutdown_returns_true_after_full_window_has_elapsed() {
    let well_past = Instant::now()
        .checked_sub(SHUTDOWN_BLOCK_WINDOW + Duration::from_secs(1))
        .expect("test platform must support subtracting from Instant::now");
    assert!(can_shutdown_for(Some(well_past)));
}

#[test]
fn can_shutdown_returns_false_just_before_window_boundary() {
    let almost = Instant::now()
        .checked_sub(SHUTDOWN_BLOCK_WINDOW - Duration::from_secs(1))
        .expect("test platform must support subtracting from Instant::now");
    assert!(!can_shutdown_for(Some(almost)));
}

#[test]
fn shutdown_block_window_is_one_hundred_forty_four_seconds() {
    assert_eq!(SHUTDOWN_BLOCK_WINDOW, Duration::from_secs(144));
}

#[test]
fn reported_head_prefers_live_head_and_records_it_as_fallback() {
    let state = SharedPreconfState::new(5_811_208);
    // The live head always wins — the Catalyst sync gate compares the reported value
    // against the execution head exactly, and reporting anything else wedges it in a
    // restart loop. This covers both the L1-reorg (head rewound) and the catch-up
    // (head advanced via canonical derivation with no gossip) directions.
    assert_eq!(state.reconcile_reported_head(Some(5_811_227)), 5_811_227);
    assert_eq!(state.reconcile_reported_head(Some(5_811_190)), 5_811_190);
    // A later failed read reports the most recently observed head, not the startup seed.
    assert_eq!(state.reconcile_reported_head(None), 5_811_190);
}

#[test]
fn reported_head_falls_back_to_seed_before_first_observation() {
    // Best-effort: a failed head read before any successful observation reports the
    // startup seed.
    let state = SharedPreconfState::new(5_811_208);
    assert_eq!(state.reconcile_reported_head(None), 5_811_208);
}

#[test]
fn reported_head_covers_locally_inserted_blocks_when_head_unreadable() {
    // Blocks inserted by this process (cached import or local build) must survive a failed
    // head read even before any successful status poll observed them.
    let state = SharedPreconfState::new(5_811_208);
    state.record_inserted_block(5_811_209);
    assert_eq!(state.reconcile_reported_head(None), 5_811_209);
    // A successful poll still overwrites the fallback with the live head.
    assert_eq!(state.reconcile_reported_head(Some(5_811_210)), 5_811_210);
    assert_eq!(state.reconcile_reported_head(None), 5_811_210);
}
