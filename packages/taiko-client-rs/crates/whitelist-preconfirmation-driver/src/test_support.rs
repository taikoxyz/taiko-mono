//! Shared test fixtures for `whitelist-preconfirmation-driver` unit tests.
//!
//! This is the crate's single test-support hub. It absorbs the fixtures that
//! were previously duplicated across `codec.rs`, `cache.rs`, `importer/tests.rs`
//! and `api/service/tests.rs`: the envelope builders, the zlib `compress`
//! helper, the golden-touch `fixed_k_sign` signer, and the Go-fixture loaders.
//! Modules that need a variant with different defaults keep a thin (≤5 line)
//! local wrapper that calls into these builders and overrides the fields.
#![cfg(test)]

use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
use alloy_rpc_types_engine::ExecutionPayloadV1;

use crate::codec::WhitelistExecutionPayloadEnvelope;

/// Length, in bytes, of the secp256k1 wire signatures fixtures carry.
const SIGNATURE_LEN: usize = 65;

/// Canonical envelope fixture, parameterized on the (already zlib-compressed)
/// transaction lists it should carry.
///
/// This is the most general of the crate's former envelope builders — every
/// other builder is expressible as this one with a couple of fields overridden.
pub(crate) fn sample_envelope_with_transactions(
    transactions: Vec<Bytes>,
) -> WhitelistExecutionPayloadEnvelope {
    WhitelistExecutionPayloadEnvelope {
        end_of_sequencing: None,
        is_forced_inclusion: None,
        parent_beacon_block_root: None,
        header_difficulty: Some(U256::from(1_000_000u64)),
        execution_payload: ExecutionPayloadV1 {
            parent_hash: B256::from([0x10u8; 32]),
            fee_recipient: Address::from([0x11u8; 20]),
            state_root: B256::from([0x12u8; 32]),
            receipts_root: B256::from([0x13u8; 32]),
            logs_bloom: Bloom::default(),
            prev_randao: B256::from([0x14u8; 32]),
            block_number: 42,
            gas_limit: 30_000_000,
            gas_used: 21_000,
            timestamp: 1_735_000_000,
            extra_data: Bytes::from(vec![0x55u8; 8]),
            base_fee_per_gas: U256::from(1_000_000_000u64),
            block_hash: B256::from([0x15u8; 32]),
            transactions,
        },
        signature: Some([0x22u8; SIGNATURE_LEN]),
    }
}

/// Fully populated envelope fixture with every flag set, used by the codec
/// round-trip and gossip tests.
///
/// Differs from [`sample_envelope_with_transactions`] in that it exercises the
/// full header (EOS + forced-inclusion + beacon root + header difficulty) and
/// carries a single placeholder transaction.
pub(crate) fn sample_envelope() -> WhitelistExecutionPayloadEnvelope {
    WhitelistExecutionPayloadEnvelope {
        end_of_sequencing: Some(true),
        is_forced_inclusion: Some(true),
        parent_beacon_block_root: Some(B256::from([0xabu8; 32])),
        header_difficulty: Some(U256::from(0x12345678u64)),
        execution_payload: ExecutionPayloadV1 {
            parent_hash: B256::from([0x01u8; 32]),
            fee_recipient: Address::from([0x11u8; 20]),
            state_root: B256::from([0x02u8; 32]),
            receipts_root: B256::from([0x03u8; 32]),
            logs_bloom: Bloom::default(),
            prev_randao: B256::from([0x04u8; 32]),
            block_number: 42,
            gas_limit: 30_000_000,
            gas_used: 21000,
            timestamp: 1_735_000_000,
            extra_data: Bytes::from(vec![0x55u8; 8]),
            base_fee_per_gas: U256::from(1_000_000_000u64),
            block_hash: B256::from([0x05u8; 32]),
            transactions: vec![Bytes::from(vec![0x99u8; 4])],
        },
        signature: Some([0x22u8; SIGNATURE_LEN]),
    }
}

/// Zlib-compresses test payloads at the default level (matching Go's encoder),
/// returning the compressed bytes ready to drop into an envelope's tx list.
pub(crate) fn compress(data: &[u8]) -> Bytes {
    let mut encoder = flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
    std::io::Write::write_all(&mut encoder, data).expect("zlib write");
    Bytes::from(encoder.finish().expect("zlib finish"))
}

/// Signs a 32-byte prehash with the golden-touch [`protocol::FixedKSigner`] and
/// returns the 65-byte wire signature (`r || s || recovery_id`).
///
/// Mirrors the production `payload_build::sign_digest` assembly so callers get a
/// signature that `codec::recover_signer` accepts without assuming any v-byte
/// convention.
pub(crate) fn fixed_k_sign(prehash: B256) -> [u8; SIGNATURE_LEN] {
    let signer = protocol::FixedKSigner::golden_touch().expect("golden touch signer");
    let sig = signer.sign_with_predefined_k(prehash.as_ref()).expect("fixed-k signature");

    let mut sig_bytes = [0u8; SIGNATURE_LEN];
    sig_bytes[..32].copy_from_slice(&sig.signature.r().to_be_bytes::<32>());
    sig_bytes[32..64].copy_from_slice(&sig.signature.s().to_be_bytes::<32>());
    sig_bytes[64] = sig.recovery_id;
    sig_bytes
}

/// Reads a Go-generated fixture, failing with a regeneration hint.
pub(crate) fn go_fixture(rel: &str) -> Vec<u8> {
    let path = format!("{}/fixtures/go/{rel}", env!("CARGO_MANIFEST_DIR"));
    std::fs::read(&path)
        .unwrap_or_else(|e| panic!("missing fixture {path} ({e}) — run `just gen-fixtures`"))
}

/// Parses a fixture JSON sidecar.
pub(crate) fn go_fixture_json(rel: &str) -> serde_json::Value {
    serde_json::from_slice(&go_fixture(rel)).expect("fixture json")
}
