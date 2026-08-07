use std::{
    io::Write,
    time::{Duration, Instant},
};

use flate2::{Compression, write::ZlibEncoder};

use crate::{
    api::service::{
        HAND_OVER_WINDOW_SLOTS, SHUTDOWN_BLOCK_WINDOW, SHUTDOWN_IMMINENCE_MARGIN_SLOTS,
        can_shutdown_for,
    },
    cache::SharedPreconfState,
    codec::{MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES, decompress_tx_list},
    error::WhitelistPreconfirmationDriverError,
};

/// Mainnet slots-per-epoch used by the shutdown tests.
const SLOTS_PER_EPOCH: u64 = 32;

/// First slot of the epoch at which the imminence guard starts refusing
/// shutdown: the hand-over boundary minus the imminence margin.
const IMMINENCE_BAND_START: u64 =
    SLOTS_PER_EPOCH - HAND_OVER_WINDOW_SLOTS - SHUTDOWN_IMMINENCE_MARGIN_SLOTS;

/// A slot comfortably outside the imminence band, so activity-focused tests
/// exercise only the request-recency rule.
const MID_EPOCH_SLOT: u64 = 2;

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
    assert!(can_shutdown_for(None, MID_EPOCH_SLOT, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_returns_false_for_request_just_now() {
    assert!(!can_shutdown_for(Some(Instant::now()), MID_EPOCH_SLOT, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_returns_true_after_full_window_has_elapsed() {
    let well_past = Instant::now()
        .checked_sub(SHUTDOWN_BLOCK_WINDOW + Duration::from_secs(1))
        .expect("test platform must support subtracting from Instant::now");
    assert!(can_shutdown_for(Some(well_past), MID_EPOCH_SLOT, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_returns_false_just_before_window_boundary() {
    let almost = Instant::now()
        .checked_sub(SHUTDOWN_BLOCK_WINDOW - Duration::from_secs(1))
        .expect("test platform must support subtracting from Instant::now");
    assert!(!can_shutdown_for(Some(almost), MID_EPOCH_SLOT, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_allows_just_before_imminence_band() {
    assert!(can_shutdown_for(None, IMMINENCE_BAND_START - 1, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_blocks_at_imminence_band_start() {
    assert!(!can_shutdown_for(None, IMMINENCE_BAND_START, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_blocks_through_epoch_tail() {
    assert!(!can_shutdown_for(None, SLOTS_PER_EPOCH - 1, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_allows_at_epoch_start() {
    assert!(can_shutdown_for(None, 0, SLOTS_PER_EPOCH));
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
