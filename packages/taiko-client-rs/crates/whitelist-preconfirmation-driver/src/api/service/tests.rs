use protocol::{
    codec::{TxListCodecError, ZlibTxListCodec},
    shasta::encode_tx_list,
};

use crate::{
    error::WhitelistPreconfirmationDriverError,
    tx_list_codec::{
        MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES,
        decode_preconfirmation_tx_list,
    },
};

fn compress(transactions: &[Vec<u8>]) -> Vec<u8> {
    ZlibTxListCodec::new_with_limits(MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES)
        .encode(transactions)
        .expect("compress tx list")
}

#[test]
fn decode_preconfirmation_tx_list_rejects_oversized_compressed_payload() {
    let oversized = vec![0u8; MAX_COMPRESSED_TX_LIST_BYTES + 1];
    let err = decode_preconfirmation_tx_list(&oversized)
        .expect_err("oversized compressed payload must fail");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("compressed tx list exceeds maximum size")
    ));
}

#[test]
fn decode_preconfirmation_tx_list_rejects_oversized_decompressed_payload() {
    let oversized = vec![0x11u8; MAX_DECOMPRESSED_TX_LIST_BYTES + 1];
    let compressed = compress(&[oversized]);
    let err = decode_preconfirmation_tx_list(&compressed)
        .expect_err("oversized decompressed payload must fail before use");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("decompressed tx list exceeds maximum size")
    ));
}

#[test]
fn decode_preconfirmation_tx_list_accepts_payload_within_limits() {
    let transaction = vec![0xAA, 0xBB, 0xCC];
    let transactions = vec![transaction.clone()];
    let compressed = compress(&transactions);
    let decoded = decode_preconfirmation_tx_list(&compressed).expect("valid payload should decode");
    let expected = encode_tx_list(&[alloy_primitives::Bytes::from(transaction)]);
    assert_eq!(decoded, expected);
}

#[test]
fn protocol_codec_rejects_oversized_preconf_tx_list() {
    let codec = ZlibTxListCodec::new_with_limits(
        MAX_COMPRESSED_TX_LIST_BYTES,
        MAX_DECOMPRESSED_TX_LIST_BYTES,
    );
    let oversized = vec![0u8; MAX_COMPRESSED_TX_LIST_BYTES + 1];
    let err = codec.decode(&oversized).expect_err("oversized compressed payload must fail");
    assert!(matches!(err, TxListCodecError::CompressedTooLarge { .. }));
}
