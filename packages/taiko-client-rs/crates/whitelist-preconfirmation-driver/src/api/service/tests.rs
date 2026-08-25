use std::{
    io::Write,
    time::{Duration, Instant},
};

use alloy_signer_local::PrivateKeySigner;
use flate2::{Compression, write::ZlibEncoder};

use crate::{
    api::service::{
        HAND_OVER_WINDOW_SLOTS, SHUTDOWN_BLOCK_WINDOW, SHUTDOWN_IMMINENCE_MARGIN_SLOTS,
        WhitelistApiService, can_shutdown_for,
    },
    cache::{
        BACKFILL_RETRY_INTERVAL_SECS, L1_EPOCH_DURATION_SECS, PENDING_ENVELOPE_CAPACITY,
        SharedPreconfState,
    },
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

#[test]
fn whitelist_service_uses_standard_signer() {
    fn assert_standard_signer(_: &PrivateKeySigner) {}

    fn check_service_signer(service: &WhitelistApiService) {
        assert_standard_signer(&service.signer);
    }

    let _ = check_service_signer as fn(&WhitelistApiService);
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
fn backfill_retry_interval_stays_inside_the_preconfer_client_tolerance() {
    // The preconfer client cancels and exits after a continuous `/status` mismatch lasting half an
    // L2 epoch. An autonomous retry slower than that arrives after the process is already gone, so
    // a dropped final response with no further gossip would never get a second attempt. This was
    // an L1-epoch poll before; keep it an order of magnitude inside the budget.
    let client_tolerance_secs = L1_EPOCH_DURATION_SECS / 2;
    assert!(
        BACKFILL_RETRY_INTERVAL_SECS * 10 < client_tolerance_secs,
        "retry interval {BACKFILL_RETRY_INTERVAL_SECS}s is not comfortably inside {client_tolerance_secs}s"
    );
}

#[test]
fn shutdown_block_window_is_one_hundred_forty_four_seconds() {
    assert_eq!(SHUTDOWN_BLOCK_WINDOW, Duration::from_secs(144));
}

#[test]
fn observed_head_prefers_live_head_and_records_it_as_fallback() {
    let state = SharedPreconfState::new(5_811_208);
    // This is the node's own execution head, which `/status` floors its report at rather than
    // reporting directly. The live head always wins here, covering both the L1-reorg (head
    // rewound) and the catch-up (head advanced via canonical derivation with no gossip)
    // directions.
    assert_eq!(state.reconcile_observed_head(Some(5_811_227)), 5_811_227);
    assert_eq!(state.reconcile_observed_head(Some(5_811_190)), 5_811_190);
    // A later failed read reports the most recently observed head, not the startup seed.
    assert_eq!(state.reconcile_observed_head(None), 5_811_190);
}

#[test]
fn observed_head_falls_back_to_seed_before_first_observation() {
    // Best-effort: a failed head read before any successful observation reports the
    // startup seed.
    let state = SharedPreconfState::new(5_811_208);
    assert_eq!(state.reconcile_observed_head(None), 5_811_208);
}

#[test]
fn observed_head_covers_locally_inserted_blocks_when_head_unreadable() {
    // Blocks inserted by this process (cached import or local build) must survive a failed
    // head read even before any successful status poll observed them.
    let state = SharedPreconfState::new(5_811_208);
    state.record_inserted_block(5_811_209);
    assert_eq!(state.reconcile_observed_head(None), 5_811_209);
    // A successful poll still overwrites the fallback with the live head.
    assert_eq!(state.reconcile_observed_head(Some(5_811_210)), 5_811_210);
    assert_eq!(state.reconcile_observed_head(None), 5_811_210);
}

#[test]
fn reported_value_exceeds_head_while_a_backlog_is_pending() {
    // The incident: a restarted follower held 156 blocks of valid, signature-checked envelopes it
    // could not apply. Reporting its own stale execution head made the preconfer client's parity
    // check compare stale against stale, match, and sequence from the stale head.
    let state = SharedPreconfState::new(10_522_943);
    state.set_pending_high_water(Some(10_523_099));

    let head = state.reconcile_observed_head(Some(10_522_943));
    assert_eq!(state.highest_unsafe_for_head(head), 10_523_099);
    assert_ne!(state.highest_unsafe_for_head(head), head, "a lagging node must not read as synced");
}

#[test]
fn reported_value_matches_head_when_ahead_of_gossip() {
    // Right after a beacon sync the execution head runs ahead of anything seen over gossip. That
    // is not a backlog, and reporting it as one would exit the preconfer client.
    let state = SharedPreconfState::new(10_522_943);

    let head = state.reconcile_observed_head(Some(10_523_500));
    assert_eq!(state.highest_unsafe_for_head(head), head);
}

#[test]
fn a_deep_backlog_survives_the_head_advancing() {
    // Regression for bounding the report with a stored watermark. A cap written back at
    // `head + span` reads correctly once, then reports parity as soon as the head reaches that
    // artificial height -- while the original payload is still cached and unapplied. Reading the
    // backlog from the cache leaves no artificial height for the head to overtake.
    let state = SharedPreconfState::new(1_000);
    state.set_pending_high_water(Some(4_000));

    for head in [1_000, 1_000 + PENDING_ENVELOPE_CAPACITY as u64, 3_999] {
        assert_eq!(
            state.highest_unsafe_for_head(head),
            4_000,
            "an unapplied payload stays visible at head {head}"
        );
    }

    // Only the chain actually reaching it, or the cache dropping it, clears the backlog.
    assert_eq!(state.highest_unsafe_for_head(4_000), 4_000);
    state.set_pending_high_water(None);
    assert_eq!(state.highest_unsafe_for_head(1_000), 1_000, "an emptied cache reports the head");
}

#[test]
fn a_cached_envelope_survives_a_confirmed_tip_rewind() {
    // Regression for resetting a watermark on a rewind. The tip is observed asynchronously, so a
    // rewind can be seen *after* the first envelope of the new branch was already recorded; a
    // reset that overwrites by height then erases it, and `/status` falls back to the rewound head
    // while that envelope sits unapplied in the cache.
    //
    // Nothing overwrites by height any more: the report is recomputed from the cache, so an
    // envelope that is still cached is still counted no matter when the rewind is noticed.
    let state = SharedPreconfState::new(90);
    state.set_pending_high_water(Some(120));

    assert_eq!(state.highest_unsafe_for_head(90), 120);
    assert_ne!(
        state.highest_unsafe_for_head(90),
        90,
        "must not read as synced at the rewound head"
    );
}
