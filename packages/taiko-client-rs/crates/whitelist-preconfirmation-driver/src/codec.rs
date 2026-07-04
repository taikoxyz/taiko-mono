//! Codec helpers for Taiko whitelist preconfirmation P2P payloads.

use std::io::Read;

use alloy_primitives::{Address, B256, Signature, U256, keccak256};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use flate2::read::ZlibDecoder;
use ssz::{Decode, Encode};

use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Size, in bytes, of secp256k1 signatures carried on the wire.
const SIGNATURE_LEN: usize = 65;
/// Envelope header length (`2 flag bytes + 32-byte parent beacon root`).
const ENVELOPE_HEADER_LEN: usize = 34;
/// Maximum allowed size after snappy decompression, bounded by gossip limits.
const MAX_DECOMPRESSED_GOSSIP_BYTES: usize = kona_gossip::MAX_GOSSIP_SIZE;
/// Maximum compressed tx-list size accepted from a preconfirmation payload.
pub(crate) const MAX_COMPRESSED_TX_LIST_BYTES: usize = 131_072 * 6;
/// Maximum decompressed tx-list size accepted from a preconfirmation payload.
///
/// Aligned with the preconfirmation tx-list cap to prevent zlib bomb expansion
/// on untrusted payloads.
pub(crate) const MAX_DECOMPRESSED_TX_LIST_BYTES: usize = 8 * 1024 * 1024;

/// Decoded whitelist preconfirmation envelope.
#[derive(Clone, Debug)]
pub(crate) struct WhitelistExecutionPayloadEnvelope {
    /// End-of-sequencing marker (present only when true).
    pub end_of_sequencing: Option<bool>,
    /// Forced-inclusion marker (present only when true).
    pub is_forced_inclusion: Option<bool>,
    /// Optional parent beacon block root.
    pub parent_beacon_block_root: Option<B256>,
    /// Optional hash-relevant header difficulty for post-Unzen blocks.
    /// When `Some`, the encoder emits a 32-byte big-endian slot after
    /// `parent_beacon_block_root` and sets `flags0 & 0x02`.
    pub header_difficulty: Option<U256>,
    /// Execution payload.
    pub execution_payload: ExecutionPayloadV1,
    /// Optional embedded signature.
    pub signature: Option<[u8; SIGNATURE_LEN]>,
}

/// Decoded message for `/preconfBlocks` topic.
#[derive(Clone, Debug)]
pub(crate) struct DecodedUnsafePayload {
    /// Wire signature prefix.
    pub wire_signature: [u8; SIGNATURE_LEN],
    /// SSZ envelope bytes used for signature verification.
    pub payload_bytes: Vec<u8>,
    /// Decoded envelope.
    pub envelope: WhitelistExecutionPayloadEnvelope,
}

/// Compute the block signing hash used by the whitelist preconfirmation protocol.
///
/// Formula: `keccak256(domain || chain_id || keccak256(signing_payload))`, where `domain` is
/// 32 zero bytes.
pub(crate) fn block_signing_hash(chain_id: u64, signing_payload: &[u8]) -> B256 {
    let payload_hash = keccak256(signing_payload);

    let mut message = [0u8; 96];
    message[32..64].copy_from_slice(U256::from(chain_id).to_be_bytes::<32>().as_slice());
    message[64..96].copy_from_slice(payload_hash.as_slice());

    keccak256(message)
}

/// Recover signer address from a signature and prehash.
pub(crate) fn recover_signer(prehash: B256, signature: &[u8; SIGNATURE_LEN]) -> Result<Address> {
    let signature = Signature::from_raw_array(signature).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidSignature(format!(
            "invalid signature bytes: {err}"
        ))
    })?;

    signature.recover_address_from_prehash(&prehash).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidSignature(format!(
            "failed to recover signer: {err}"
        ))
    })
}

/// Decode a preconfirmation payload into its wire signature and envelope bytes.
pub(crate) fn decode_unsafe_payload_signature(
    data: &[u8],
) -> Result<([u8; SIGNATURE_LEN], Vec<u8>)> {
    let decoded = decompress_snappy_with_limit(data, "payload")?;

    if decoded.len() < SIGNATURE_LEN {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "unsafe payload too short: {}",
            decoded.len()
        )));
    }

    let mut wire_signature = [0u8; SIGNATURE_LEN];
    wire_signature.copy_from_slice(&decoded[..SIGNATURE_LEN]);

    Ok((wire_signature, decoded[SIGNATURE_LEN..].to_vec()))
}

/// Decode a message from the `responsePreconfBlocks` topic.
pub(crate) fn decode_unsafe_response_message(
    data: &[u8],
) -> Result<WhitelistExecutionPayloadEnvelope> {
    let decoded = decompress_snappy_with_limit(data, "response")?;

    decode_envelope_ssz(&decoded)
}

/// Failure mode of [`bounded_decompress_snappy`], distinguishing the stage that failed.
pub(crate) enum SnappyDecompressError {
    /// `decompress_len` could not inspect the snappy frame.
    Inspect(snap::Error),
    /// Decompressed length would exceed [`MAX_DECOMPRESSED_GOSSIP_BYTES`].
    TooLarge(usize),
    /// `decompress_vec` failed to produce the decompressed bytes.
    Decompress(snap::Error),
}

/// Decompress snappy bytes, bounding the decompressed length against gossip limits.
///
/// On success returns the decompressed bytes; on failure returns a
/// [`SnappyDecompressError`] identifying the stage so callers can choose their own
/// error-reporting or fallback behavior.
pub(crate) fn bounded_decompress_snappy(
    data: &[u8],
) -> core::result::Result<Vec<u8>, SnappyDecompressError> {
    let decoded_len = match snap::raw::decompress_len(data) {
        Ok(len) => len,
        Err(err) => return Err(SnappyDecompressError::Inspect(err)),
    };

    if decoded_len > MAX_DECOMPRESSED_GOSSIP_BYTES {
        return Err(SnappyDecompressError::TooLarge(decoded_len));
    }

    snap::raw::Decoder::new().decompress_vec(data).map_err(SnappyDecompressError::Decompress)
}

/// Decode snappy bytes after validating decompressed length against gossip limits.
fn decompress_snappy_with_limit(data: &[u8], kind: &str) -> Result<Vec<u8>> {
    bounded_decompress_snappy(data).map_err(|err| match err {
        SnappyDecompressError::Inspect(err) => WhitelistPreconfirmationDriverError::InvalidPayload(
            format!("failed to inspect snappy {kind} size: {err}"),
        ),
        SnappyDecompressError::TooLarge(decoded_len) => {
            WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "snappy {kind} too large after decompression: {decoded_len} > {MAX_DECOMPRESSED_GOSSIP_BYTES}"
            ))
        }
        SnappyDecompressError::Decompress(err) => {
            WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "failed to decompress snappy {kind}: {err}"
            ))
        }
    })
}

/// Encode a message for the `preconfBlocks` topic (signature || SSZ envelope, snappy compressed).
pub(crate) fn encode_unsafe_payload_message(
    signature: &[u8; 65],
    envelope: &WhitelistExecutionPayloadEnvelope,
) -> Result<Vec<u8>> {
    let ssz_bytes = encode_envelope_ssz(envelope);
    let mut raw = Vec::with_capacity(SIGNATURE_LEN + ssz_bytes.len());
    raw.extend_from_slice(signature);
    raw.extend_from_slice(&ssz_bytes);
    snap::raw::Encoder::new().compress_vec(&raw).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "failed to compress snappy payload: {err}"
        ))
    })
}

/// Encode a message for the `requestEndOfSequencingPreconfBlocks` topic.
pub(crate) fn encode_eos_request_message(epoch: u64) -> Vec<u8> {
    epoch.to_be_bytes().to_vec()
}

/// Encode a message for the `requestPreconfBlocks` topic.
pub(crate) fn encode_unsafe_request_message(hash: B256) -> Vec<u8> {
    hash.to_vec()
}

/// Encode Taiko whitelist preconfirmation SSZ envelope bytes.
pub(crate) fn encode_envelope_ssz(envelope: &WhitelistExecutionPayloadEnvelope) -> Vec<u8> {
    let has_header_difficulty = envelope.header_difficulty.map(|v| !v.is_zero()).unwrap_or(false);
    let header_difficulty_len = if has_header_difficulty { 32 } else { 0 };
    let sig_len = if envelope.signature.is_some() { SIGNATURE_LEN } else { 0 };
    let mut out = Vec::with_capacity(
        ENVELOPE_HEADER_LEN +
            header_difficulty_len +
            envelope.execution_payload.as_ssz_bytes().len() +
            sig_len,
    );

    let mut flags0 = 0u8;
    let mut flags1 = 0u8;
    if envelope.end_of_sequencing.unwrap_or(false) {
        flags0 |= 0x01;
    }
    if has_header_difficulty {
        flags0 |= 0x02;
    }
    if envelope.is_forced_inclusion.unwrap_or(false) {
        flags1 |= 0x01;
    }
    if envelope.signature.is_some() {
        flags1 |= 0x02;
    }

    out.push(flags0);
    out.push(flags1);
    if let Some(root) = envelope.parent_beacon_block_root {
        out.extend_from_slice(root.as_slice());
    } else {
        out.extend_from_slice(&[0u8; 32]);
    }

    if has_header_difficulty {
        let v = envelope.header_difficulty.expect("has_header_difficulty implies Some");
        out.extend_from_slice(&v.to_be_bytes::<32>());
    }

    out.extend_from_slice(envelope.execution_payload.as_ssz_bytes().as_slice());

    if let Some(signature) = envelope.signature {
        out.extend_from_slice(&signature);
    }

    out
}

/// Encode a message for the `responsePreconfBlocks` topic.
pub(crate) fn encode_unsafe_response_message(
    envelope: &WhitelistExecutionPayloadEnvelope,
) -> Result<Vec<u8>> {
    let ssz_bytes = encode_envelope_ssz(envelope);
    snap::raw::Encoder::new().compress_vec(&ssz_bytes).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "failed to compress snappy response: {err}"
        ))
    })
}

/// Decode Taiko whitelist preconfirmation SSZ envelope bytes.
pub(crate) fn decode_envelope_ssz(bytes: &[u8]) -> Result<WhitelistExecutionPayloadEnvelope> {
    if bytes.len() < ENVELOPE_HEADER_LEN {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "envelope too short: {}",
            bytes.len()
        )));
    }

    let flags0 = bytes[0];
    let flags1 = bytes[1];

    let end_of_sequencing = (flags0 & 0x01 != 0).then_some(true);
    let has_header_difficulty = flags0 & 0x02 != 0;
    let is_forced_inclusion = (flags1 & 0x01 != 0).then_some(true);
    let has_signature = flags1 & 0x02 != 0;

    let root = &bytes[2..ENVELOPE_HEADER_LEN];
    let parent_beacon_block_root = root.iter().any(|&b| b != 0).then(|| B256::from_slice(root));

    let header_difficulty_len = if has_header_difficulty { 32 } else { 0 };
    let signature_len = if has_signature { SIGNATURE_LEN } else { 0 };
    let min_len = ENVELOPE_HEADER_LEN + header_difficulty_len + signature_len;
    if bytes.len() < min_len {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "envelope missing payload data: {}",
            bytes.len()
        )));
    }

    let mut cursor = ENVELOPE_HEADER_LEN;
    let header_difficulty = if has_header_difficulty {
        let slot = &bytes[cursor..cursor + 32];
        cursor += 32;
        Some(U256::from_be_slice(slot))
    } else {
        None
    };

    let payload_end = bytes.len() - signature_len;
    let payload_bytes = &bytes[cursor..payload_end];
    let execution_payload = ExecutionPayloadV1::from_ssz_bytes(payload_bytes).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "invalid execution payload SSZ: {err:?}"
        ))
    })?;

    let signature = has_signature.then(|| {
        let mut sig = [0u8; SIGNATURE_LEN];
        sig.copy_from_slice(&bytes[payload_end..]);
        sig
    });

    Ok(WhitelistExecutionPayloadEnvelope {
        end_of_sequencing,
        is_forced_inclusion,
        parent_beacon_block_root,
        header_difficulty,
        execution_payload,
        signature,
    })
}

/// Decompress a zlib-compressed transaction list while enforcing size limits.
pub(crate) fn decompress_tx_list(bytes: &[u8]) -> Result<Vec<u8>> {
    if bytes.len() > MAX_COMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
            "compressed tx list exceeds maximum size: {} > {}",
            bytes.len(),
            MAX_COMPRESSED_TX_LIST_BYTES
        )));
    }

    let decoder = ZlibDecoder::new(bytes);
    let mut out = Vec::new();
    let read_cap = MAX_DECOMPRESSED_TX_LIST_BYTES.saturating_add(1) as u64;
    decoder.take(read_cap).read_to_end(&mut out).map_err(|err| {
        WhitelistPreconfirmationDriverError::invalid_payload_with_context(
            "failed to decompress tx list from payload",
            err,
        )
    })?;

    if out.len() > MAX_DECOMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
            "decompressed tx list exceeds maximum size: {} > {}",
            out.len(),
            MAX_DECOMPRESSED_TX_LIST_BYTES
        )));
    }

    if out.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
            "decompressed tx list is empty",
        ));
    }

    Ok(out)
}

#[cfg(test)]
pub(crate) mod tests {
    use alloy_primitives::{Bloom, Bytes};

    use super::*;

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

    fn sample_envelope() -> WhitelistExecutionPayloadEnvelope {
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

    #[test]
    fn encode_unsafe_request_is_raw_hash_bytes() {
        let hash = B256::from([0x33u8; 32]);
        let encoded = encode_unsafe_request_message(hash);

        assert_eq!(encoded.len(), 32);
        assert_eq!(encoded, hash.as_slice());
    }

    #[test]
    fn encode_response_roundtrips_with_decode() {
        let envelope = sample_envelope();

        let encoded = encode_unsafe_response_message(&envelope).expect("response encoding");
        let decoded = decode_unsafe_response_message(&encoded).expect("response decoding");

        assert_eq!(decoded.end_of_sequencing, envelope.end_of_sequencing);
        assert_eq!(decoded.is_forced_inclusion, envelope.is_forced_inclusion);
        assert_eq!(decoded.parent_beacon_block_root, envelope.parent_beacon_block_root);
        assert_eq!(decoded.header_difficulty, envelope.header_difficulty);
        assert_eq!(decoded.execution_payload.block_hash, envelope.execution_payload.block_hash);
        assert_eq!(decoded.execution_payload.block_number, envelope.execution_payload.block_number);
        assert_eq!(decoded.signature, envelope.signature);
    }

    #[test]
    fn decode_unsafe_payload_rejects_oversized_snappy() {
        let oversized = vec![0u8; MAX_DECOMPRESSED_GOSSIP_BYTES + 1];
        let encoded = snap::raw::Encoder::new()
            .compress_vec(&oversized)
            .expect("snappy compression for oversized payload");

        let err =
            decode_unsafe_payload_signature(&encoded).expect_err("oversized payload must fail");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("too large after decompression")
        ));
    }

    #[test]
    fn encode_unsafe_payload_roundtrips_with_decode() {
        let envelope = sample_envelope();
        let signature = envelope.signature.expect("sample has signature");

        let encoded =
            encode_unsafe_payload_message(&signature, &envelope).expect("payload encoding");
        let (wire_signature, payload_bytes) =
            decode_unsafe_payload_signature(&encoded).expect("payload decoding");
        let decoded_envelope = decode_envelope_ssz(&payload_bytes).expect("envelope decoding");

        assert_eq!(wire_signature, signature);
        assert_eq!(decoded_envelope.end_of_sequencing, envelope.end_of_sequencing);
        assert_eq!(decoded_envelope.is_forced_inclusion, envelope.is_forced_inclusion);
        assert_eq!(decoded_envelope.parent_beacon_block_root, envelope.parent_beacon_block_root);
        assert_eq!(decoded_envelope.header_difficulty, envelope.header_difficulty);
        assert_eq!(
            decoded_envelope.execution_payload.block_hash,
            envelope.execution_payload.block_hash
        );
        assert_eq!(
            decoded_envelope.execution_payload.block_number,
            envelope.execution_payload.block_number
        );
        assert_eq!(decoded_envelope.signature, envelope.signature);
    }

    #[test]
    fn encode_eos_request_message_produces_big_endian_bytes() {
        let epoch = 0x0102030405060708u64;
        let encoded = encode_eos_request_message(epoch);
        assert_eq!(encoded, vec![0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]);

        let zero = encode_eos_request_message(0);
        assert_eq!(zero, vec![0u8; 8]);
    }

    #[test]
    fn decode_unsafe_response_rejects_oversized_snappy() {
        let oversized = vec![0u8; MAX_DECOMPRESSED_GOSSIP_BYTES + 1];
        let encoded = snap::raw::Encoder::new()
            .compress_vec(&oversized)
            .expect("snappy compression for oversized response");

        let err =
            decode_unsafe_response_message(&encoded).expect_err("oversized response must fail");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("too large after decompression")
        ));
    }

    /// Pins `block_signing_hash` byte-for-byte against Go `p2p.BlockSigningHash`.
    #[test]
    fn block_signing_hash_matches_go_golden() {
        let fixture = go_fixture_json("signing_hash.json");
        let chain_id: u64 = fixture["chain_id"].as_str().expect("chain_id").parse().expect("u64");
        let payload = alloy_primitives::hex::decode(fixture["payload"].as_str().expect("payload"))
            .expect("hex");
        let expected: B256 =
            fixture["expected_hash"].as_str().expect("hash").parse().expect("b256");
        assert_eq!(block_signing_hash(chain_id, &payload), expected);
    }

    /// Decodes Go-`MarshalSSZ` envelopes — including the legacy-tx txlist shape
    /// that froze mainnet (PR #21906) and the Uzen HeaderDifficulty flag.
    #[test]
    fn decode_envelope_ssz_accepts_go_encoded_fixtures() {
        for name in ["legacy_tx_signed", "all_flags_difficulty", "unsigned"] {
            let ssz = go_fixture(&format!("envelope/{name}.ssz.bin"));
            let meta = go_fixture_json(&format!("envelope/{name}.json"));
            let envelope = decode_envelope_ssz(&ssz)
                .unwrap_or_else(|e| panic!("fixture {name} must decode: {e:?}"));

            assert_eq!(
                envelope.execution_payload.block_number,
                meta["block_number"].as_u64().expect("block_number"),
                "{name}: block number"
            );
            assert_eq!(envelope.execution_payload.transactions.len(), 1, "{name}: tx_count");
            assert_eq!(
                envelope.end_of_sequencing.unwrap_or(false),
                meta["end_of_sequencing"].as_bool().expect("eos"),
                "{name}: eos flag"
            );
            assert_eq!(
                envelope.is_forced_inclusion.unwrap_or(false),
                meta["is_forced_inclusion"].as_bool().expect("forced"),
                "{name}: forced flag"
            );
            assert_eq!(
                envelope.signature.is_some(),
                meta["has_signature"].as_bool().expect("sig"),
                "{name}: signature presence"
            );
            let expected_difficulty: U256 =
                meta["header_difficulty"].as_str().expect("difficulty").parse().expect("u256");
            assert_eq!(
                envelope.header_difficulty.unwrap_or_default(),
                expected_difficulty,
                "{name}: header difficulty"
            );
        }
    }

    /// Re-encoding a Go-decoded envelope must reproduce Go's exact bytes.
    #[test]
    fn encode_envelope_ssz_matches_go_bytes() {
        for name in ["legacy_tx_signed", "all_flags_difficulty", "unsigned"] {
            let ssz = go_fixture(&format!("envelope/{name}.ssz.bin"));
            let envelope = decode_envelope_ssz(&ssz).expect("decode");
            assert_eq!(encode_envelope_ssz(&envelope), ssz, "{name}: re-encode byte mismatch");
        }
    }

    /// Full gossip-wire path: snappy frame -> SSZ -> envelope, then the txlist
    /// inside decodes through the protocol codec (legacy + typed mix).
    #[test]
    fn decode_go_snappy_response_and_inner_txlist() {
        use protocol::codec::ZlibTxListCodec;

        let snappy = go_fixture("envelope/legacy_tx_signed.snappy.bin");
        let envelope = decode_unsafe_response_message(&snappy).expect("snappy+ssz decode");
        let compressed_txlist = envelope.execution_payload.transactions[0].as_ref();
        let txs = ZlibTxListCodec::new_with_limits(
            MAX_COMPRESSED_TX_LIST_BYTES,
            MAX_DECOMPRESSED_TX_LIST_BYTES,
        )
        .decode(compressed_txlist)
        .expect("Go txlist with a legacy tx must decode — this is the #21906 regression");
        assert_eq!(txs.len(), 2, "legacy + eip1559");
        assert!(txs[0][0] >= 0xc0, "first tx is legacy (bare RLP list)");
        assert_eq!(txs[1][0], 0x02, "second tx is typed eip1559");
    }
}
