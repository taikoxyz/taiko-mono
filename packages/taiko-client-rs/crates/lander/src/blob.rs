//! Canonical V6 blob construction and decoding using the shared Kona-v0 field coder.
//!
//! Ordered batches contain one to six blobs. Each chunk has 1..=130044 bytes; every nonfinal
//! chunk is full, and all unused bytes/bits are zero. Every field element has its top two bits
//! clear, including the first. Version/24-bit length, decoded-tail padding and untouched blob
//! padding are checked before concatenation. Compression validity is checked by codec::decode;
//! authenticated checkpoint coverage is checked by codec::decode_landed.
use alloy_eips::eip7594::BlobTransactionSidecarVariant;
use alloy_primitives::B256;
use serde::{Deserialize, Serialize};
/// Sidecar and immutable ordered commitments generated for one complete V6 payload.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreparedBlobs {
    /// Number of V6 payload bytes (version byte and compressed list) before field-element
    /// encoding.
    pub payload_bytes: usize,
    /// Explicit target-fork sidecar representation.
    pub sidecar: BlobTransactionSidecarVariant,
    /// Transaction-order KZG versioned hashes.
    pub versioned_hashes: Vec<B256>,
}

use crate::{
    error::{LanderError, Result},
    types::{Limits, SidecarMode},
};
use alloy_eips::eip4844::{BYTES_PER_BLOB, Blob};

/// Kona-compatible capacity: 127 usable bytes per four field elements, minus four header bytes.
pub const PAYLOAD_BYTES_PER_BLOB: usize = BYTES_PER_BLOB * 127 / 128 - 4;

/// The blobs one landing carries: the six Fusaka permits per transaction, which the configured
/// `max_blobs` must equal.
pub const MAX_LANDING_BLOBS: usize = 6;

/// Number of blobs needed for a payload; does not allocate or compute KZG proofs.
pub const fn required_blobs(payload_bytes: usize) -> usize {
    if payload_bytes == 0 { 0 } else { (payload_bytes - 1) / PAYLOAD_BYTES_PER_BLOB + 1 }
}

/// Build exactly one sidecar for an already selected complete V6 payload.
pub fn build(payload: &[u8], limits: &Limits, mode: SidecarMode) -> Result<PreparedBlobs> {
    use alloy_eips::eip4844::builder::SidecarBuilder;
    use protocol::shasta::BlobCoder;
    let limits = crate::codec::bounded_limits(limits)?;
    let count = required_blobs(payload.len());
    if count == 0 || count > limits.max_blobs || payload.len() > limits.max_payload_bytes {
        return Err(LanderError::Capacity(format!(
            "payload {} bytes needs {count} blobs; configured maximum {}",
            payload.len(),
            limits.max_blobs
        )));
    }
    let builder = SidecarBuilder::<BlobCoder>::from_slice(payload);
    let sidecar = match mode {
        SidecarMode::Eip4844 => BlobTransactionSidecarVariant::Eip4844(
            builder.build_4844().map_err(|e| LanderError::Encoding(format!("KZG sidecar: {e}")))?,
        ),
        SidecarMode::Eip7594 => BlobTransactionSidecarVariant::Eip7594(
            builder
                .build_7594()
                .map_err(|e| LanderError::Encoding(format!("KZG cell sidecar: {e}")))?,
        ),
    };
    if sidecar.blobs().len() != count {
        return Err(LanderError::Safety(
            "blob coder capacity disagrees with counted payload".into(),
        ));
    }
    let versioned_hashes = sidecar.versioned_hashes().collect();
    Ok(PreparedBlobs { payload_bytes: payload.len(), sidecar, versioned_hashes })
}

/// Decode canonical Kona chunks in transaction order, bounded before allocating payload bytes.
pub fn decode(blobs: &[Blob], limits: &Limits) -> Result<Vec<u8>> {
    use protocol::shasta::BlobCoder;
    let limits = crate::codec::bounded_limits(limits)?;
    if blobs.is_empty() || blobs.len() > limits.max_blobs {
        return Err(LanderError::Capacity(
            "blob collection is empty or exceeds configured limit".into(),
        ));
    }
    let mut payload = Vec::new();
    for (index, blob) in blobs.iter().enumerate() {
        // The shared Shasta decoder checks later field elements; V6 also forbids the first
        // field element's reserved top bits rather than silently masking them.
        if blob[0] & 0xc0 != 0 {
            return Err(LanderError::Encoding(format!(
                "invalid first field element at index {index}"
            )));
        }
        let chunk = BlobCoder::decode_blob(blob)
            .ok_or_else(|| LanderError::Encoding(format!("invalid Kona blob at index {index}")))?;
        if chunk.is_empty() || (index + 1 < blobs.len() && chunk.len() != PAYLOAD_BYTES_PER_BLOB) {
            return Err(LanderError::Encoding(format!(
                "noncanonical blob chunk length {} at index {index}",
                chunk.len()
            )));
        }
        let total = payload
            .len()
            .checked_add(chunk.len())
            .ok_or_else(|| LanderError::Capacity("decoded payload length overflow".into()))?;
        if total > limits.max_payload_bytes {
            return Err(LanderError::Capacity("decoded payload exceeds configured limit".into()));
        }
        payload.extend_from_slice(&chunk);
    }
    Ok(payload)
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_eips::eip4844::env_settings::EnvKzgSettings;

    fn limits(blobs: usize) -> Limits {
        Limits {
            max_blocks: 20,
            max_blobs: blobs,
            max_payload_bytes: PAYLOAD_BYTES_PER_BLOB * blobs,
            max_message_bytes: PAYLOAD_BYTES_PER_BLOB * blobs,
            max_decompressed_bytes: PAYLOAD_BYTES_PER_BLOB * blobs,
        }
    }

    #[test]
    fn v6_rejects_reserved_bits_in_the_first_field_element() {
        let prepared = build(&[6, 1, 2, 3], &limits(1), SidecarMode::Eip4844).unwrap();
        let mut blob = prepared.sidecar.blobs()[0];
        blob[0] |= 0x40;
        assert!(decode(&[blob], &limits(1)).is_err());
    }

    #[test]
    fn protocol_blob_limit_cannot_be_raised_by_operator_configuration() {
        let prepared =
            build(&vec![0; PAYLOAD_BYTES_PER_BLOB], &limits(1), SidecarMode::Eip4844).unwrap();
        let blobs = vec![prepared.sidecar.blobs()[0]; 7];
        assert!(decode(&blobs, &limits(7)).is_err());
    }

    #[test]
    fn exact_blob_capacity_and_crossing_round_trip_without_truncation() {
        assert_eq!(PAYLOAD_BYTES_PER_BLOB, 130_044);
        for bytes in
            [1, PAYLOAD_BYTES_PER_BLOB, PAYLOAD_BYTES_PER_BLOB + 1, 2 * PAYLOAD_BYTES_PER_BLOB]
        {
            let payload = (0..bytes).map(|i| (i % 251) as u8).collect::<Vec<_>>();
            let prepared = build(&payload, &limits(2), SidecarMode::Eip4844).unwrap();
            assert_eq!(prepared.payload_bytes, bytes);
            assert_eq!(prepared.sidecar.blobs().len(), required_blobs(bytes));
            assert_eq!(decode(prepared.sidecar.blobs(), &limits(2)).unwrap(), payload);
            prepared
                .sidecar
                .validate(&prepared.versioned_hashes, EnvKzgSettings::Default.get())
                .unwrap();
        }
    }

    #[test]
    fn sidecar_modes_bind_identical_blobs_and_ordered_hashes() {
        let payload = vec![0x5a; PAYLOAD_BYTES_PER_BLOB + 1];
        let old = build(&payload, &limits(2), SidecarMode::Eip4844).unwrap();
        let new = build(&payload, &limits(2), SidecarMode::Eip7594).unwrap();
        assert!(old.sidecar.is_eip4844());
        assert!(new.sidecar.is_eip7594());
        assert_eq!(old.sidecar.blobs(), new.sidecar.blobs());
        assert_eq!(old.versioned_hashes, new.versioned_hashes);
        new.sidecar.validate(&new.versioned_hashes, EnvKzgSettings::Default.get()).unwrap();
        let mut reversed = old.versioned_hashes.clone();
        reversed.reverse();
        assert_ne!(
            crate::statement::blob_hashes_hash(&reversed),
            crate::statement::blob_hashes_hash(&old.versioned_hashes)
        );
        let mut corrupted = old.sidecar.clone();
        if let BlobTransactionSidecarVariant::Eip4844(sidecar) = &mut corrupted {
            sidecar.blobs[0][100] ^= 1;
        }
        assert!(corrupted.validate(&old.versioned_hashes, EnvKzgSettings::Default.get()).is_err());
    }

    #[test]
    fn rejects_empty_overlimit_noncanonical_and_truncated_collections() {
        assert!(build(&[], &limits(2), SidecarMode::Eip4844).is_err());
        assert!(decode(&[], &limits(2)).is_err());
        assert!(
            build(&vec![0; PAYLOAD_BYTES_PER_BLOB + 1], &limits(1), SidecarMode::Eip4844).is_err()
        );
        let sidecar =
            build(&vec![0x2a; PAYLOAD_BYTES_PER_BLOB + 1], &limits(2), SidecarMode::Eip4844)
                .unwrap();
        assert!(decode(sidecar.sidecar.blobs(), &limits(1)).is_err());
        let mut cap = limits(2);
        cap.max_payload_bytes = PAYLOAD_BYTES_PER_BLOB;
        assert!(decode(sidecar.sidecar.blobs(), &cap).is_err());
        let mut blobs = sidecar.sidecar.blobs().to_vec();
        blobs[0][1] = 1;
        assert!(decode(&blobs, &limits(2)).is_err());
        let short = build(&[1], &limits(2), SidecarMode::Eip4844).unwrap();
        let mut wrong = short.sidecar.blobs().to_vec();
        wrong.push(wrong[0]);
        assert!(decode(&wrong, &limits(2)).is_err());
        // The blob codec returns a truncated collection's full first blob as is: its length is
        // exactly one blob's payload. Rejecting such a prefix is left to the V6 payload's zlib
        // stream end and checksum (`a_truncated_v3_payload_fails_its_zlib_stream`).
        let prefix = decode(&sidecar.sidecar.blobs()[..1], &limits(2)).unwrap();
        assert_eq!(prefix.len(), PAYLOAD_BYTES_PER_BLOB);
    }

    /// A height-1 certified block whose envelope carries one pseudo-random `len`-byte
    /// transaction, which deflate cannot shrink.
    fn noisy_block(len: usize) -> crate::types::CertifiedBlock {
        let (_, committee, keys) = crate::test_utils::consensus::committee(&[1, 1, 1, 1], 0);
        crate::test_utils::consensus::pair_with_envelope(
            noisy_envelope(len),
            &committee,
            &keys,
            None,
        )
    }

    /// The envelope of [`noisy_block`].
    fn noisy_envelope(len: usize) -> abci::EtnaEnvelope {
        let noise = (0u64..)
            .flat_map(|i| alloy_primitives::keccak256(i.to_be_bytes()).0)
            .take(len)
            .collect::<Vec<_>>();
        abci::EtnaEnvelope {
            block: abci::ExecutionBlock {
                header: alloy_consensus::Header {
                    number: 1,
                    parent_hash: B256::repeat_byte(1),
                    ..Default::default()
                },
                transactions: vec![noise.into()],
            },
            anchor: None,
            committee: None,
            forced: None,
        }
    }

    /// Limits admitting one block as large as a landing allows.
    fn landing_limits() -> Limits {
        Limits {
            max_blocks: 1,
            max_blobs: MAX_LANDING_BLOBS,
            max_payload_bytes: MAX_LANDING_BLOBS * PAYLOAD_BYTES_PER_BLOB,
            max_message_bytes: 2 << 20,
            max_decompressed_bytes: 2 << 20,
        }
    }

    /// A real V6 payload spanning two blobs, cut to its first blob: the blob codec serves the
    /// prefix, and the V5 codec rejects it at the zlib stream's end and checksum.
    #[test]
    fn a_truncated_v3_payload_fails_its_zlib_stream() {
        let limits = landing_limits();
        let payload = crate::codec::encode(&[noisy_block(200_000)], &limits).unwrap();
        let sidecar = build(&payload, &limits, SidecarMode::Eip4844).unwrap();
        assert_eq!(sidecar.versioned_hashes.len(), 2);
        assert_eq!(crate::codec::decode(&payload, &limits).unwrap().len(), 1);
        let prefix = decode(&sidecar.sidecar.blobs()[..1], &limits).unwrap();
        assert_eq!(prefix.len(), PAYLOAD_BYTES_PER_BLOB);
        assert!(matches!(crate::codec::decode(&prefix, &limits), Err(LanderError::Encoding(_))));
    }
}
