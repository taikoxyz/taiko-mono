use std::io::Write;

use alloy_primitives::Address;
use flate2::{Compression, write::ZlibEncoder};

use super::lookahead::{is_fee_recipient_allowed_for_slot, slot_matches_range};
use crate::{
    api::types::{LookaheadStatus, SlotRange},
    error::WhitelistPreconfirmationDriverError,
    tx_list::{MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES, decompress_tx_list},
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

#[test]
fn slot_matches_range_checks_slot_bounds() {
    let ranges = vec![SlotRange { start: 10, end: 20 }, SlotRange { start: 30, end: 40 }];

    assert!(slot_matches_range(10, &ranges));
    assert!(slot_matches_range(19, &ranges));
    assert!(!slot_matches_range(20, &ranges));
    assert!(!slot_matches_range(25, &ranges));
    assert!(slot_matches_range(30, &ranges));
    assert!(!slot_matches_range(40, &ranges));
}

#[test]
fn fee_recipient_allowed_for_slot_matches_only_assigned_operator() {
    let lookahead = LookaheadStatus {
        curr_operator: Address::from([0x11u8; 20]),
        next_operator: Address::from([0x22u8; 20]),
        curr_ranges: vec![SlotRange { start: 10, end: 20 }],
        next_ranges: vec![SlotRange { start: 20, end: 30 }],
    };

    assert!(is_fee_recipient_allowed_for_slot(Address::from([0x11u8; 20]), 15, &lookahead));
    assert!(is_fee_recipient_allowed_for_slot(Address::from([0x22u8; 20]), 25, &lookahead));
    assert!(!is_fee_recipient_allowed_for_slot(Address::from([0x33u8; 20]), 15, &lookahead));
    assert!(!is_fee_recipient_allowed_for_slot(Address::from([0x11u8; 20]), 25, &lookahead));
    assert!(!is_fee_recipient_allowed_for_slot(Address::from([0x22u8; 20]), 15, &lookahead));
}
