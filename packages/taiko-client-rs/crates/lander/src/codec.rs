//! V1 complete block/commit payload codec, bounded before parsing or allocating messages.
//!
//! The pinned Tendermint domain adapter normalizes CometBFT's default height-1 last commit to
//! `None`; V1 uses that adapter's canonical protobuf form. Certificate part-set validation restores
//! the empty Go commit when reconstructing CometBFT's signed network-block serialization.

use crate::{
    error::{LanderError, Result},
    types::{CertifiedBlock, Limits},
};

/// Version prefix of `0x01 || rlp([[block_proto, commit_proto], ...])`.
pub const VERSION: u8 = 1;

use alloy_rlp::{Encodable, Header};
use prost::Message;
use tendermint_proto::v0_38::types::{Block as RawBlock, Commit as RawCommit};

/// Encode complete, consecutive pairs without altering their envelope or signatures.
pub fn encode(blocks: &[CertifiedBlock], limits: &Limits) -> Result<Vec<u8>> {
    limits.validate()?;
    if blocks.is_empty() || blocks.len() > limits.max_blocks {
        return Err(LanderError::Capacity("batch is empty or exceeds block limit".into()));
    }
    let mut messages = Vec::with_capacity(blocks.len());
    let mut payload_length = 0usize;
    let mut previous = None;
    for pair in blocks {
        validate_pair(pair, previous)?;
        previous = Some(pair.block.header.height.value());
        let block = RawBlock::from(pair.block.clone());
        let commit = RawCommit::from(pair.commit.clone());
        if block.encoded_len() > limits.max_message_bytes ||
            commit.encoded_len() > limits.max_message_bytes
        {
            return Err(LanderError::Capacity(format!(
                "protobuf at height {} exceeds message limit",
                pair.block.header.height
            )));
        }
        let block = block.encode_to_vec();
        let commit = commit.encode_to_vec();
        let length = block
            .as_slice()
            .length()
            .checked_add(commit.as_slice().length())
            .ok_or_else(|| LanderError::Capacity("RLP pair length overflow".into()))?;
        payload_length = payload_length
            .checked_add(Header { list: true, payload_length: length }.length())
            .and_then(|n| n.checked_add(length))
            .ok_or_else(|| LanderError::Capacity("RLP payload length overflow".into()))?;
        // Bound retained message bytes incrementally; no whole-batch allocation precedes this.
        if payload_length > limits.max_payload_bytes {
            return Err(LanderError::Capacity("batch exceeds payload limit".into()));
        }
        messages.push((block, commit, length));
    }
    let outer = Header { list: true, payload_length };
    let total = 1usize
        .checked_add(outer.length())
        .and_then(|n| n.checked_add(payload_length))
        .ok_or_else(|| LanderError::Capacity("payload length overflow".into()))?;
    if total > limits.max_payload_bytes {
        return Err(LanderError::Capacity("batch exceeds payload limit".into()));
    }
    let mut out = Vec::with_capacity(total);
    out.push(VERSION);
    outer.encode(&mut out);
    for (block, commit, length) in messages {
        Header { list: true, payload_length: length }.encode(&mut out);
        block.as_slice().encode(&mut out);
        commit.as_slice().encode(&mut out);
    }
    Ok(out)
}

/// Decode bounded, canonical RLP and canonical v0_38 protobuf block/commit messages.
pub fn decode(payload: &[u8], limits: &Limits) -> Result<Vec<CertifiedBlock>> {
    limits.validate()?;
    if payload.len() > limits.max_payload_bytes {
        return Err(LanderError::Capacity("batch exceeds payload limit".into()));
    }
    let (&version, mut outer) =
        payload.split_first().ok_or_else(|| LanderError::Encoding("empty batch payload".into()))?;
    if version != VERSION {
        return Err(LanderError::Encoding(format!("unsupported batch version {version}")));
    }
    let mut list = Header::decode_bytes(&mut outer, true).map_err(rlp_error)?;
    if !outer.is_empty() {
        return Err(LanderError::Encoding("trailing bytes after batch list".into()));
    }
    let mut blocks = Vec::new();
    let mut previous = None;
    while !list.is_empty() {
        if blocks.len() == limits.max_blocks {
            return Err(LanderError::Capacity("batch exceeds block limit".into()));
        }
        let mut fields = Header::decode_bytes(&mut list, true).map_err(rlp_error)?;
        let block_bytes = Header::decode_bytes(&mut fields, false).map_err(rlp_error)?;
        let commit_bytes = Header::decode_bytes(&mut fields, false).map_err(rlp_error)?;
        if !fields.is_empty() {
            return Err(LanderError::Encoding("block/commit pair has extra fields".into()));
        }
        if block_bytes.len() > limits.max_message_bytes ||
            commit_bytes.len() > limits.max_message_bytes
        {
            return Err(LanderError::Capacity("protobuf exceeds message limit".into()));
        }
        let raw_block = RawBlock::decode(block_bytes)
            .map_err(|e| LanderError::Encoding(format!("invalid block protobuf: {e}")))?;
        let raw_commit = RawCommit::decode(commit_bytes)
            .map_err(|e| LanderError::Encoding(format!("invalid commit protobuf: {e}")))?;
        if raw_block.encode_to_vec() != block_bytes || raw_commit.encode_to_vec() != commit_bytes {
            return Err(LanderError::Encoding("noncanonical protobuf encoding".into()));
        }
        let pair = CertifiedBlock {
            block: raw_block
                .try_into()
                .map_err(|e| LanderError::Encoding(format!("invalid CometBFT block: {e}")))?,
            commit: raw_commit
                .try_into()
                .map_err(|e| LanderError::Encoding(format!("invalid CometBFT commit: {e}")))?,
        };
        // Domain adapters normalize empty evidence and nil commits: require their canonical form
        // too.
        if RawBlock::from(pair.block.clone()).encode_to_vec() != block_bytes ||
            RawCommit::from(pair.commit.clone()).encode_to_vec() != commit_bytes
        {
            return Err(LanderError::Encoding("noncanonical CometBFT protobuf form".into()));
        }
        validate_pair(&pair, previous)?;
        previous = Some(pair.block.header.height.value());
        blocks.push(pair);
    }
    if blocks.is_empty() {
        return Err(LanderError::Encoding("empty batch list".into()));
    }
    Ok(blocks)
}

/// Translate canonical RLP errors into the shared codec error category.
fn rlp_error(error: alloy_rlp::Error) -> LanderError {
    LanderError::Encoding(format!("malformed batch RLP: {error}"))
}

/// Require one envelope and a commit naming the same consecutive block; signatures are verified by
/// consensus.
fn validate_pair(pair: &CertifiedBlock, previous: Option<u64>) -> Result<()> {
    let height = pair.block.header.height.value();
    if height == 0 ||
        pair.commit.height != pair.block.header.height ||
        pair.commit.block_id.hash != pair.block.header.hash()
    {
        return Err(LanderError::Encoding(format!("block/commit disagreement at height {height}")));
    }
    if let Some(previous) = previous &&
        previous.checked_add(1) != Some(height)
    {
        return Err(LanderError::Encoding(format!(
            "nonconsecutive block height {height} after {previous}"
        )));
    }
    if pair.block.data.len() != 1 {
        return Err(LanderError::Encoding(format!(
            "height {height} must contain one Etna envelope"
        )));
    }
    abci::EtnaEnvelope::decode(&pair.block.data[0])
        .map_err(|e| LanderError::Encoding(format!("invalid envelope at height {height}: {e}")))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::protocol_blocks::block;
    use alloy_rlp::{Encodable, Header};
    use prost::Message;
    use tendermint_proto::v0_38::types::{Block as RawBlock, Commit as RawCommit};

    fn limits() -> Limits {
        Limits {
            max_blocks: 4,
            max_blobs: 2,
            max_payload_bytes: 250_000,
            max_message_bytes: 200_000,
        }
    }

    fn wire(block_bytes: &[u8], commit_bytes: &[u8]) -> Vec<u8> {
        let pair_size = block_bytes.length() + commit_bytes.length();
        let outer_size = Header { list: true, payload_length: pair_size }.length() + pair_size;
        let mut bytes = vec![VERSION];
        Header { list: true, payload_length: outer_size }.encode(&mut bytes);
        Header { list: true, payload_length: pair_size }.encode(&mut bytes);
        block_bytes.encode(&mut bytes);
        commit_bytes.encode(&mut bytes);
        bytes
    }

    #[test]
    fn canonical_wire_is_ordinary_v038_protobuf_in_two_rlp_strings() {
        let pair = block(1);
        let block_bytes = RawBlock::from(pair.block.clone()).encode_to_vec();
        let commit_bytes = RawCommit::from(pair.commit.clone()).encode_to_vec();
        let expected = wire(&block_bytes, &commit_bytes);
        assert_eq!(encode(std::slice::from_ref(&pair), &limits()).unwrap(), expected);
        assert_eq!(decode(&expected, &limits()).unwrap(), vec![pair]);
    }

    #[test]
    fn height_one_empty_go_commit_normalizes_to_the_canonical_v1_domain_form() {
        let pair = block(1);
        let mut go_raw = RawBlock::from(pair.block.clone());
        // Go's nullable=false BlockID/PartSetHeader fields are present even when their
        // scalar values are empty. Construct these messages independently of block_parts.
        let empty_id = tendermint_proto::v0_38::types::BlockId {
            hash: Vec::new(),
            part_set_header: Some(tendermint_proto::v0_38::types::PartSetHeader {
                total: 0,
                hash: Vec::new(),
            }),
        };
        go_raw.header.as_mut().unwrap().last_block_id = Some(empty_id.clone());
        go_raw.last_commit = Some(RawCommit {
            height: 0,
            round: 0,
            block_id: Some(empty_id),
            signatures: Vec::new(),
        });
        let normalized: tendermint::Block = go_raw.clone().try_into().unwrap();
        assert!(normalized.last_commit.is_none());
        assert_eq!(normalized, pair.block);
        let go_bytes = go_raw.encode_to_vec();
        let go_parts = go_bytes.chunks(65_536).map(<[u8]>::to_vec).collect::<Vec<_>>();
        let signed_parts = crate::validate::block_parts(&normalized);
        assert_eq!(signed_parts.total, go_parts.len() as u32);
        assert_eq!(
            signed_parts.hash,
            tendermint::Hash::Sha256(tendermint::merkle::simple_hash_from_byte_vectors::<
                tendermint::crypto::default::Sha256,
            >(&go_parts))
        );
        let canonical_raw = RawBlock::from(normalized.clone()).encode_to_vec();
        assert_ne!(canonical_raw, go_bytes);
        let commit_bytes = RawCommit::from(pair.commit.clone()).encode_to_vec();
        assert!(decode(&wire(&go_raw.encode_to_vec(), &commit_bytes), &limits()).is_err());
        let canonical =
            encode(&[CertifiedBlock { block: normalized, commit: pair.commit.clone() }], &limits())
                .unwrap();
        assert_eq!(decode(&canonical, &limits()).unwrap(), vec![pair]);
    }

    #[test]
    fn multiple_blocks_preserve_complete_envelope_bytes() {
        let blocks = vec![block(1), block(2), block(3)];
        let bytes = encode(&blocks, &limits()).unwrap();
        assert_eq!(decode(&bytes, &limits()).unwrap(), blocks);
    }

    #[test]
    fn rejects_empty_version_trailing_truncated_and_noncanonical_messages() {
        let pair = block(1);
        let valid = encode(std::slice::from_ref(&pair), &limits()).unwrap();
        assert!(decode(&[], &limits()).is_err());
        assert!(encode(&[], &limits()).is_err());
        assert!(decode(&[1, 0xc0], &limits()).is_err());
        let mut changed = valid.clone();
        changed[0] = 2;
        assert!(decode(&changed, &limits()).is_err());
        let mut changed = valid.clone();
        changed.push(0);
        assert!(decode(&changed, &limits()).is_err());
        for end in [1, 2, valid.len() - 1] {
            assert!(decode(&valid[..end], &limits()).is_err());
        }
        let block_bytes = RawBlock::from(pair.block).encode_to_vec();
        let mut commit_bytes = RawCommit::from(pair.commit).encode_to_vec();
        commit_bytes.extend_from_slice(&[0x08, 0x01]); // repeated singular height: protobuf accepts, canonical codec rejects.
        assert!(decode(&wire(&block_bytes, &commit_bytes), &limits()).is_err());
        let mut block_bytes = block_bytes;
        block_bytes.extend_from_slice(&[0xf8, 0x07, 0x01]); // unknown field.
        assert!(decode(&wire(&block_bytes, &commit_bytes), &limits()).is_err());
        assert!(decode(&[1, 0xf8, 0x00], &limits()).is_err()); // noncanonical empty RLP list.
    }

    #[test]
    fn rejects_pair_height_hash_and_order_disagreement() {
        let mut pair = block(1);
        pair.commit.height = 2u32.into();
        assert!(encode(&[pair], &limits()).is_err());
        let mut pair = block(1);
        pair.commit.block_id.hash = tendermint::Hash::Sha256([0; 32]);
        assert!(encode(&[pair], &limits()).is_err());
        assert!(encode(&[block(1), block(3)], &limits()).is_err());
        assert!(encode(&[block(2), block(1)], &limits()).is_err());
    }

    #[test]
    fn bounds_count_message_and_payload_at_exact_capacity() {
        let pair = block(1);
        let encoded = encode(std::slice::from_ref(&pair), &limits()).unwrap();
        let mut cap = limits();
        cap.max_payload_bytes = encoded.len();
        assert!(encode(std::slice::from_ref(&pair), &cap).is_ok());
        assert!(decode(&encoded, &cap).is_ok());
        cap.max_payload_bytes -= 1;
        assert!(encode(std::slice::from_ref(&pair), &cap).is_err());
        assert!(decode(&encoded, &cap).is_err());
        cap = limits();
        cap.max_blocks = 1;
        assert!(encode(&[pair.clone(), block(2)], &cap).is_err());
        let bytes = encode(&[pair.clone(), block(2)], &limits()).unwrap();
        assert!(decode(&bytes, &cap).is_err());
        cap = limits();
        cap.max_message_bytes = 1;
        assert!(encode(&[pair], &cap).is_err());
        assert!(decode(&encoded, &cap).is_err());
        cap = limits();
        cap.max_blocks = 0;
        assert!(decode(&encoded, &cap).is_err());
    }
}
