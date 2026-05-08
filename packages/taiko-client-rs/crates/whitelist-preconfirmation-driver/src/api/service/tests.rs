use std::io::Write;

use flate2::{Compression, write::ZlibEncoder};

use crate::{
    codec::{MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES, decompress_tx_list},
    error::WhitelistPreconfirmationDriverError,
};

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

use std::time::{Duration, Instant};

use crate::api::service::{SHUTDOWN_BLOCK_WINDOW, can_shutdown_for};

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
