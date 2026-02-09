//! Codec helpers for Taiko whitelist preconfirmation P2P payloads.

use alloy_primitives::{Address, B256, Signature, U256, keccak256};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use ssz::{Decode, Encode};

use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Minimum bytes for a decoded unsafe payload (`signature + at least one payload byte`).
const MIN_UNSAFE_PAYLOAD_BYTES: usize = 66;
/// Size, in bytes, of secp256k1 signatures carried on the wire.
const SIGNATURE_LEN: usize = 65;
/// Envelope header length (`2 flag bytes + 32-byte parent beacon root`).
const ENVELOPE_HEADER_LEN: usize = 34;
/// Maximum allowed size after snappy decompression, bounded by gossip limits.
const MAX_DECOMPRESSED_GOSSIP_BYTES: usize = kona_gossip::MAX_GOSSIP_SIZE;

/// Decoded whitelist preconfirmation envelope.
#[derive(Clone, Debug)]
pub(crate) struct WhitelistExecutionPayloadEnvelope {
    /// End-of-sequencing marker (present only when true).
    pub end_of_sequencing: Option<bool>,
    /// Forced-inclusion marker (present only when true).
    pub is_forced_inclusion: Option<bool>,
    /// Optional parent beacon block root.
    pub parent_beacon_block_root: Option<B256>,
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

/// Decode a message from the `preconfBlocks` topic.
pub(crate) fn decode_unsafe_payload_message(data: &[u8]) -> Result<DecodedUnsafePayload> {
    let decoded = decompress_snappy_with_limit(data, "payload")?;

    if decoded.len() < MIN_UNSAFE_PAYLOAD_BYTES {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "unsafe payload too short: {}",
            decoded.len()
        )));
    }

    let mut wire_signature = [0u8; SIGNATURE_LEN];
    wire_signature.copy_from_slice(&decoded[..SIGNATURE_LEN]);

    let payload_bytes = decoded[SIGNATURE_LEN..].to_vec();
    let envelope = decode_envelope_ssz(&payload_bytes)?;

    Ok(DecodedUnsafePayload { wire_signature, payload_bytes, envelope })
}

/// Decode a message from the `responsePreconfBlocks` topic.
pub(crate) fn decode_unsafe_response_message(
    data: &[u8],
) -> Result<WhitelistExecutionPayloadEnvelope> {
    let decoded = decompress_snappy_with_limit(data, "response")?;

    decode_envelope_ssz(&decoded)
}

/// Decode snappy bytes after validating decompressed length against gossip limits.
fn decompress_snappy_with_limit(data: &[u8], kind: &str) -> Result<Vec<u8>> {
    let decoded_len = snap::raw::decompress_len(data).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "failed to inspect snappy {kind} size: {err}"
        ))
    })?;

    if decoded_len > MAX_DECOMPRESSED_GOSSIP_BYTES {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "snappy {kind} too large after decompression: {decoded_len} > {MAX_DECOMPRESSED_GOSSIP_BYTES}"
        )));
    }

    let mut decoder = snap::raw::Decoder::new();
    decoder.decompress_vec(data).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "failed to decompress snappy {kind}: {err}"
        ))
    })
}

/// Encode a message for the `requestPreconfBlocks` topic.
pub(crate) fn encode_unsafe_request_message(hash: B256) -> Vec<u8> {
    hash.to_vec()
}

/// Encode Taiko whitelist preconfirmation SSZ envelope bytes.
pub(crate) fn encode_envelope_ssz(envelope: &WhitelistExecutionPayloadEnvelope) -> Vec<u8> {
    let mut out = Vec::with_capacity(
        ENVELOPE_HEADER_LEN +
            envelope.execution_payload.as_ssz_bytes().len() +
            envelope.signature.map(|_| SIGNATURE_LEN).unwrap_or_default(),
    );

    let mut flags0 = 0u8;
    let mut flags1 = 0u8;
    if envelope.end_of_sequencing.unwrap_or(false) {
        flags0 |= 0x01;
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
    let is_forced_inclusion = (flags1 & 0x01 != 0).then_some(true);
    let has_signature = flags1 & 0x02 != 0;

    let root = &bytes[2..ENVELOPE_HEADER_LEN];
    let parent_beacon_block_root = root.iter().any(|b| *b != 0).then(|| B256::from_slice(root));

    let signature_len = if has_signature { SIGNATURE_LEN } else { 0 };
    if bytes.len() < ENVELOPE_HEADER_LEN + signature_len {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "envelope missing payload data: {}",
            bytes.len()
        )));
    }

    let payload_end = bytes.len() - signature_len;
    let payload_bytes = &bytes[ENVELOPE_HEADER_LEN..payload_end];
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
        execution_payload,
        signature,
    })
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Bloom, Bytes};

    use super::*;

    fn sample_envelope() -> WhitelistExecutionPayloadEnvelope {
        WhitelistExecutionPayloadEnvelope {
            end_of_sequencing: Some(true),
            is_forced_inclusion: Some(true),
            parent_beacon_block_root: Some(B256::from([0xabu8; 32])),
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

        let err = decode_unsafe_payload_message(&encoded).expect_err("oversized payload must fail");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("too large after decompression")
        ));
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
}
