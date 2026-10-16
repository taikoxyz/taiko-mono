//! Bounded blob construction sharing the existing protocol coder.
use alloy_eips::eip7594::BlobTransactionSidecarVariant;
use alloy_primitives::B256;
use serde::{Deserialize, Serialize};
/// Sidecar and immutable ordered commitments generated for one complete V5 payload.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreparedBlobs {
    /// Number of V5 payload bytes (version byte and compressed list) before field-element
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

// The ABCI landing capacity guard sizes blocks by this same per-blob capacity.
const _: () = assert!(abci::compression::LANDING_PAYLOAD_BYTES_PER_BLOB == PAYLOAD_BYTES_PER_BLOB);

/// Number of blobs needed for a payload; does not allocate or compute KZG proofs.
pub const fn required_blobs(payload_bytes: usize) -> usize {
    if payload_bytes == 0 { 0 } else { (payload_bytes - 1) / PAYLOAD_BYTES_PER_BLOB + 1 }
}

/// Build exactly one sidecar for an already selected complete V5 payload.
pub fn build(payload: &[u8], limits: &Limits, mode: SidecarMode) -> Result<PreparedBlobs> {
    use alloy_eips::eip4844::builder::SidecarBuilder;
    use protocol::shasta::BlobCoder;
    limits.validate()?;
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
    limits.validate()?;
    if blobs.is_empty() || blobs.len() > limits.max_blobs {
        return Err(LanderError::Capacity(
            "blob collection is empty or exceeds configured limit".into(),
        ));
    }
    let mut payload = Vec::new();
    for (index, blob) in blobs.iter().enumerate() {
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
        // exactly one blob's payload. Rejecting such a prefix is left to the V5 payload's zlib
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
        use abci::compression::MAX_LANDING_BLOBS;
        Limits {
            max_blocks: 1,
            max_blobs: MAX_LANDING_BLOBS,
            max_payload_bytes: MAX_LANDING_BLOBS * PAYLOAD_BYTES_PER_BLOB,
            max_message_bytes: 2 << 20,
            max_decompressed_bytes: 2 << 20,
        }
    }

    /// The ABCI landing capacity guard admits a block whose zlib-compressed envelope plus
    /// `HEADER_ALLOWANCE` is at most `MAX_BLOCK_LANDING_BYTES`. A block at that bound, with an
    /// incompressible transaction, still encodes (`codec::encode`) and builds into at most
    /// `MAX_LANDING_BLOBS` blobs, so every block the guard admits can land on its own.
    #[test]
    fn a_block_at_the_landing_guard_bound_fits_max_landing_blobs() {
        use abci::compression::{
            HEADER_ALLOWANCE, MAX_BLOCK_LANDING_BYTES, MAX_LANDING_BLOBS, zlib_compress,
        };
        let guarded =
            |len: usize| zlib_compress(&noisy_envelope(len).encode()).len() + HEADER_ALLOWANCE;
        // The longest transaction the guard admits.
        let (mut low, mut high) = (0, MAX_BLOCK_LANDING_BYTES);
        while low < high {
            let mid = (low + high).div_ceil(2);
            if guarded(mid) <= MAX_BLOCK_LANDING_BYTES { low = mid } else { high = mid - 1 }
        }
        let at_bound = guarded(low);
        assert!(at_bound <= MAX_BLOCK_LANDING_BYTES, "{at_bound}");
        assert!(MAX_BLOCK_LANDING_BYTES - at_bound < 8, "{at_bound} is at the bound");

        let limits = landing_limits();
        let payload = crate::codec::encode(&[noisy_block(low)], &limits).unwrap();
        let blobs = build(&payload, &limits, SidecarMode::Eip4844).unwrap();
        assert_eq!(blobs.versioned_hashes.len(), MAX_LANDING_BLOBS, "{} bytes", payload.len());
    }

    /// Bytes alternating, every 16,383 bytes (one deflate symbol buffer), between two 128-value
    /// alphabets with no 3-byte string repeated within deflate's window, so deflate emits only
    /// literals: a block costs about 7 bits a byte when it covers one run and 8 when it straddles
    /// two. Shifting the run boundaries against deflate's block boundaries, as a published
    /// header prefix does, therefore changes the output by kilobytes.
    fn deflate_boundary_noise(first: usize, runs: usize) -> Vec<u8> {
        let mut state = 0x9e37_79b9_7f4a_7c15u64;
        let mut next = || {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            state
        };
        let mut out = Vec::new();
        let mut seen = std::collections::HashMap::<[u8; 3], usize>::new();
        for run in 0..runs {
            for _ in 0..if run == 0 { first } else { 16_383 } {
                loop {
                    let byte = ((next() % 128) as u8) * 2 + (run % 2) as u8;
                    if let [.., a, b] = out[..] {
                        let at = out.len();
                        if seen.get(&[a, b, byte]).is_some_and(|p| at - p < 40_000) {
                            continue;
                        }
                        seen.insert([a, b, byte], at);
                    }
                    out.push(byte);
                    break;
                }
            }
        }
        out
    }

    /// A crafted block the ABCI guard admits, whose header prefix makes joint compression exceed
    /// six blobs at every level, still lands on its own: the single-block fallback deflates its
    /// envelope after a full flush, exactly as the guard measured it.
    #[test]
    fn a_crafted_block_the_guard_admits_still_fits_max_landing_blobs() {
        use abci::compression::{
            HEADER_ALLOWANCE, MAX_BLOCK_LANDING_BYTES, MAX_LANDING_BLOBS, zlib_compress,
            zlib_compress_best,
        };
        const RUN: usize = 16_383;
        let base = deflate_boundary_noise(RUN, 57);
        let envelope = |start: usize, end: usize| {
            let mut envelope = noisy_envelope(0);
            envelope.block.transactions = vec![base[start..end].to_vec().into()];
            envelope.encode()
        };
        let guarded = |start: usize, end: usize| {
            zlib_compress(&envelope(start, end)).len() + HEADER_ALLOWANCE
        };
        // Align the runs with deflate's blocks for the bare envelope, then take the longest
        // transaction the guard still admits.
        let start = (0..128).min_by_key(|start| guarded(*start, 53 * RUN)).unwrap();
        let (mut low, mut high) = (53 * RUN, 57 * RUN);
        while low < high {
            let mid = (low + high).div_ceil(2);
            if guarded(start, mid) <= MAX_BLOCK_LANDING_BYTES { low = mid } else { high = mid - 1 }
        }
        assert!(guarded(start, low) <= MAX_BLOCK_LANDING_BYTES);

        let limits = landing_limits();
        let (_, committee, keys) = crate::test_utils::consensus::committee(&[1, 1, 1, 1], 0);
        let mut crafted = noisy_envelope(0);
        crafted.block.transactions = vec![base[start..low].to_vec().into()];
        let block =
            crate::test_utils::consensus::pair_with_envelope(crafted, &committee, &keys, None);
        let mut list = crate::codec::PayloadList::new(&limits).unwrap();
        list.push(&block).unwrap();
        let list = list.to_list();
        for joint in [zlib_compress(&list), zlib_compress_best(&list)] {
            assert!(joint.len() + 1 > limits.max_payload_bytes, "joint compression must not fit");
        }

        let payload = crate::codec::encode(&[block], &limits).unwrap();
        assert!(payload.len() <= limits.max_payload_bytes);
        assert_eq!(crate::codec::decode(&payload, &limits).unwrap().len(), 1);
        let blobs = build(&payload, &limits, SidecarMode::Eip4844).unwrap();
        assert_eq!(blobs.versioned_hashes.len(), MAX_LANDING_BLOBS);
    }

    /// The published prefix of a header whose every variable field is maximal (a 50-byte chain
    /// id, the largest height and versions, a negative time, a last block id) stays within the
    /// bound `HEADER_ALLOWANCE` reserves for it.
    #[test]
    fn the_published_prefix_of_a_maximal_header_fits_its_allowance() {
        use abci::compression::MAX_PUBLISHED_PREFIX_BYTES;
        use tendermint::{Hash, block};
        let mut header = noisy_block(0).block.header;
        let hash = Hash::Sha256([0xff; 32]);
        header.version = block::header::Version { block: u64::MAX, app: u64::MAX };
        header.chain_id = "c".repeat(50).as_str().try_into().unwrap();
        header.height = block::Height::try_from(i64::MAX).unwrap();
        // A negative timestamp's seconds take a ten-byte varint.
        header.time = tendermint::Time::from_unix_timestamp(-62_135_596_800, 999_999_999).unwrap();
        header.last_block_id = Some(block::Id {
            hash,
            part_set_header: block::parts::Header::new(u32::MAX, hash).unwrap(),
        });
        header.app_hash = vec![0xff; 32].try_into().unwrap();
        let proto = <tendermint_proto::v0_38::types::Header as prost::Message>::encode_to_vec(
            &header.into(),
        );
        // The outer list, item list, header string and envelope string headers: each at most
        // 5 bytes for lists and strings below 4 GiB (CometBFT blocks stay below 22 MiB).
        let prefix = 5 + 5 + 5 + proto.len() + 5;
        assert!(prefix <= MAX_PUBLISHED_PREFIX_BYTES, "{prefix}");
    }

    /// A real V5 payload spanning two blobs, cut to its first blob: the blob codec serves the
    /// prefix, and the V4 codec rejects it at the zlib stream's end and checksum.
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
