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
    cache::{PENDING_ENVELOPE_CAPACITY, SharedPreconfState},
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
    // The incident: a restarted follower held 156 blocks of valid, signature-checked envelopes
    // it could not apply. Reporting its own stale execution head made the preconfer client's
    // parity check compare stale against stale, match, and sequence from the stale head.
    let state = SharedPreconfState::new(10_522_943);
    state.record_seen_block(10_523_099);

    let head = state.reconcile_observed_head(Some(10_522_943));
    assert_eq!(state.highest_unsafe_floored_at(head), 10_523_099);
    assert_ne!(
        state.highest_unsafe_floored_at(head),
        head,
        "a lagging node must not read as synced"
    );
}

#[test]
fn reported_value_matches_head_when_ahead_of_gossip() {
    // Right after a beacon sync the execution head runs ahead of anything seen over gossip.
    // That is not a backlog, and reporting it as one would exit the preconfer client.
    let state = SharedPreconfState::new(10_522_943);

    let head = state.reconcile_observed_head(Some(10_523_500));
    assert_eq!(state.highest_unsafe_floored_at(head), head);
}

#[test]
fn seen_block_advances_monotonically() {
    let state = SharedPreconfState::new(1_000);

    state.record_seen_block(1_050);
    assert_eq!(state.highest_seen_block(), 1_050);

    // Never moves backwards on a late or out-of-order envelope.
    state.record_seen_block(1_010);
    assert_eq!(state.highest_seen_block(), 1_050);
}

#[test]
fn absurd_block_number_is_anchored_and_eventually_releases() {
    // A signature-valid payload with a wrong or hostile block number must not keep the node out
    // of sync forever, or it keeps the preconfer client from ever starting.
    let state = SharedPreconfState::new(1_000);
    state.record_seen_block(u64::MAX);

    let anchored = 1_000 + PENDING_ENVELOPE_CAPACITY as u64;
    assert_eq!(state.highest_seen_block(), anchored, "anchored at record time, not at report time");
    assert_ne!(state.highest_unsafe_floored_at(1_000), 1_000, "still reads as behind for now");

    // The anchor is a fixed height rather than one that tracks the head, so the chain catching up
    // to it restores equality. Clamping the reported value instead would return `head + capacity`
    // forever, and the node could never read as synced again.
    assert_eq!(state.highest_unsafe_floored_at(anchored - 1), anchored);
    assert_eq!(state.highest_unsafe_floored_at(anchored), anchored, "synced again");
    assert_eq!(state.highest_unsafe_floored_at(anchored + 10), anchored + 10);
}

#[test]
fn a_rewind_does_not_erase_the_envelope_that_arrived_with_it() {
    // Ordering guard for the ingress path: the tip rewind lowers the counter unconditionally, so
    // it has to run before the envelope in hand is counted. Recording first would forget the
    // first block of the new branch, and `/status` would fall back to the rewound head — which
    // equals the execution head, so the preconfer client would read a node holding an unimported
    // block as synced.
    let state = SharedPreconfState::new(90);
    state.observe_envelope(150, Some(100));

    // An L1 reorg rewinds the confirmed tip, and the first new-branch payload arrives with it.
    // `observe_envelope` is the single call the ingress path makes, so this is the real ordering.
    state.observe_envelope(120, Some(90));

    assert_eq!(state.highest_seen_block(), 120);
    assert_ne!(
        state.highest_unsafe_floored_at(90),
        90,
        "must not read as synced at the rewound head"
    );
}

#[test]
fn a_backlog_deeper_than_one_cache_span_still_reads_as_behind() {
    // The anchor must not silently turn a real backlog into a synced report: a node returning
    // from long downtime is behind by more than the cache can bridge, and still has to say so.
    let state = SharedPreconfState::new(1_000);
    state.record_seen_block(1_000 + PENDING_ENVELOPE_CAPACITY as u64 * 4);

    assert_ne!(state.highest_unsafe_floored_at(1_000), 1_000);
}

#[test]
fn confirmed_tip_resets_seen_only_when_it_moves_backwards() {
    let state = SharedPreconfState::new(1_000);
    state.record_seen_block(1_100);

    // Steady state: preconfirmations outpace L1 confirmation by design, so an advancing tip
    // below the highest seen block must leave the counter alone.
    state.note_confirmed_tip(1_000);
    state.note_confirmed_tip(1_040);
    assert_eq!(state.highest_seen_block(), 1_100, "an advancing tip must not reset the counter");

    // An L1 reorg rewinds the chain past envelopes already counted: without the reset the node
    // reports a height the chain no longer reaches and never reads as synced again.
    state.note_confirmed_tip(1_020);
    assert_eq!(state.highest_seen_block(), 1_020);
    assert_eq!(state.highest_unsafe_floored_at(1_020), 1_020, "node reads as synced again");
}
