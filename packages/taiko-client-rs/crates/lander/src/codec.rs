//! V2 published block payload codec, bounded before parsing or allocating messages.
//!
//! A batch publishes each block's canonical CometBFT header and its single Etna envelope. The
//! header hashes to the block id the committee signed, its `data_hash` commits to the envelope and
//! its `last_block_id` to the preceding header. Commits and signatures are not published: proofs
//! take them as witnesses from the prepared batch. The pinned Tendermint domain adapter maps
//! CometBFT's empty height-1 last block id to `None`; V2 publishes that canonical domain form.

use crate::{
    error::{LanderError, Result},
    types::{CertifiedBlock, Limits},
    validate::data_hash,
};

/// Version prefix of `0x02 || rlp([[header_proto, envelope], ...])`.
pub const VERSION: u8 = 2;

use alloy_rlp::{Encodable, Header};
use prost::Message;
use tendermint_proto::v0_38::types::{Block as RawBlock, Commit as RawCommit, Header as RawHeader};

/// One published block: its CometBFT header and the Etna envelope its single transaction holds.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PublishedBlock {
    /// Canonical CometBFT header whose hash is the signed block id hash.
    pub header: tendermint::block::Header,
    /// Exact envelope bytes, `0x03 || rlp([block, anchor, committee])`.
    pub envelope: Vec<u8>,
}

impl From<&CertifiedBlock> for PublishedBlock {
    /// Drops the commit, last commit and evidence; a block without a transaction maps to an
    /// empty envelope, which [`decode`] rejects.
    fn from(pair: &CertifiedBlock) -> Self {
        Self {
            header: pair.block.header.clone(),
            envelope: pair.block.data.first().cloned().unwrap_or_default(),
        }
    }
}

/// Encode complete, consecutive certified blocks as their published headers and envelopes.
pub fn encode(blocks: &[CertifiedBlock], limits: &Limits) -> Result<Vec<u8>> {
    limits.validate()?;
    if blocks.is_empty() || blocks.len() > limits.max_blocks {
        return Err(LanderError::Capacity("batch is empty or exceeds block limit".into()));
    }
    let mut messages = Vec::with_capacity(blocks.len());
    let mut payload_length = 0usize;
    let mut previous: Option<PublishedBlock> = None;
    for pair in blocks {
        validate_pair(pair)?;
        check_message_limits(pair, limits)?;
        let published = PublishedBlock::from(pair);
        validate_published(&published, previous.as_ref())?;
        let header = RawHeader::from(published.header.clone()).encode_to_vec();
        let length = header
            .as_slice()
            .length()
            .checked_add(published.envelope.as_slice().length())
            .ok_or_else(|| LanderError::Capacity("RLP item length overflow".into()))?;
        payload_length = payload_length
            .checked_add(Header { list: true, payload_length: length }.length())
            .and_then(|n| n.checked_add(length))
            .ok_or_else(|| LanderError::Capacity("RLP payload length overflow".into()))?;
        // Bound retained message bytes incrementally; no whole-batch allocation precedes this.
        if payload_length > limits.max_payload_bytes {
            return Err(LanderError::Capacity("batch exceeds payload limit".into()));
        }
        messages.push((header, length));
        previous = Some(published);
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
    for (pair, (header, length)) in blocks.iter().zip(messages) {
        Header { list: true, payload_length: length }.encode(&mut out);
        header.as_slice().encode(&mut out);
        pair.block.data[0].as_slice().encode(&mut out);
    }
    Ok(out)
}

/// Bound one block and certificate without retaining a complete backlog or encoding its payload.
///
/// The prepared batch keeps both protobufs as proof witnesses, so they stay bounded even though
/// only the header and envelope are published.
pub(crate) fn check_message_limits(pair: &CertifiedBlock, limits: &Limits) -> Result<()> {
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
    Ok(())
}

/// Decode bounded, canonical RLP and canonical v0_38 protobuf headers with their envelopes.
pub fn decode(payload: &[u8], limits: &Limits) -> Result<Vec<PublishedBlock>> {
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
    let mut blocks: Vec<PublishedBlock> = Vec::new();
    while !list.is_empty() {
        if blocks.len() == limits.max_blocks {
            return Err(LanderError::Capacity("batch exceeds block limit".into()));
        }
        let mut fields = Header::decode_bytes(&mut list, true).map_err(rlp_error)?;
        let header_bytes = Header::decode_bytes(&mut fields, false).map_err(rlp_error)?;
        let envelope = Header::decode_bytes(&mut fields, false).map_err(rlp_error)?;
        if !fields.is_empty() {
            return Err(LanderError::Encoding("header/envelope item has extra fields".into()));
        }
        if header_bytes.len() > limits.max_message_bytes ||
            envelope.len() > limits.max_message_bytes
        {
            return Err(LanderError::Capacity("header or envelope exceeds message limit".into()));
        }
        let raw = RawHeader::decode(header_bytes)
            .map_err(|e| LanderError::Encoding(format!("invalid header protobuf: {e}")))?;
        if raw.encode_to_vec() != header_bytes {
            return Err(LanderError::Encoding("noncanonical header protobuf encoding".into()));
        }
        let header: tendermint::block::Header = raw
            .try_into()
            .map_err(|e| LanderError::Encoding(format!("invalid CometBFT header: {e}")))?;
        // The domain adapter normalizes empty block ids: require their canonical form too.
        if RawHeader::from(header.clone()).encode_to_vec() != header_bytes {
            return Err(LanderError::Encoding("noncanonical CometBFT header form".into()));
        }
        let block = PublishedBlock { header, envelope: envelope.to_vec() };
        validate_published(&block, blocks.last())?;
        blocks.push(block);
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

/// Require one envelope and a commit naming the same block; signatures are verified by consensus.
fn validate_pair(pair: &CertifiedBlock) -> Result<()> {
    let height = pair.block.header.height.value();
    if pair.commit.height != pair.block.header.height ||
        pair.commit.block_id.hash != pair.block.header.hash()
    {
        return Err(LanderError::Encoding(format!("block/commit disagreement at height {height}")));
    }
    if pair.block.data.len() != 1 {
        return Err(LanderError::Encoding(format!(
            "height {height} must contain one Etna envelope"
        )));
    }
    Ok(())
}

/// Require consecutive heights linked by `last_block_id`, a `data_hash` committing to exactly
/// the envelope, and a decodable envelope.
fn validate_published(block: &PublishedBlock, previous: Option<&PublishedBlock>) -> Result<()> {
    let height = block.header.height.value();
    if height == 0 {
        return Err(LanderError::Encoding("published block at height 0".into()));
    }
    let linked = match previous {
        Some(previous) => {
            if previous.header.height.value().checked_add(1) != Some(height) {
                return Err(LanderError::Encoding(format!(
                    "nonconsecutive block height {height} after {}",
                    previous.header.height
                )));
            }
            block.header.last_block_id.map(|id| id.hash) == Some(previous.header.hash())
        }
        None => block.header.last_block_id.is_none() == (height == 1),
    };
    if !linked {
        return Err(LanderError::Encoding(format!(
            "last block id does not link height {height} to its predecessor"
        )));
    }
    if block.header.data_hash != Some(data_hash(std::slice::from_ref(&block.envelope))) {
        return Err(LanderError::Encoding(format!(
            "header data hash does not commit to the envelope at height {height}"
        )));
    }
    abci::EtnaEnvelope::decode(&block.envelope)
        .map_err(|e| LanderError::Encoding(format!("invalid envelope at height {height}: {e}")))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::consensus;
    use alloy_primitives::B256;
    use alloy_rlp::{Encodable, Header};
    use prost::Message;
    use tendermint::block::CommitSig;
    use tendermint_proto::v0_38::types::{
        BlockId as RawBlockId, Header as RawHeader, PartSetHeader as RawPartSetHeader,
    };

    fn limits() -> Limits {
        Limits {
            max_blocks: 4,
            max_blobs: 2,
            max_payload_bytes: 250_000,
            max_message_bytes: 200_000,
        }
    }

    /// Genuinely signed consecutive blocks from height 1.
    fn chain(len: u64) -> Vec<CertifiedBlock> {
        let (_, committee, keys) = consensus::committee(&[1, 1, 1, 1], 0);
        let mut blocks: Vec<CertifiedBlock> = Vec::new();
        for height in 1..=len {
            let parent = B256::repeat_byte(u8::try_from(height).unwrap());
            let pair = consensus::pair(height, parent, &committee, &keys, blocks.last());
            blocks.push(pair);
        }
        blocks
    }

    fn header_bytes(header: &tendermint::block::Header) -> Vec<u8> {
        RawHeader::from(header.clone()).encode_to_vec()
    }

    fn items(blocks: &[CertifiedBlock]) -> Vec<(Vec<u8>, Vec<u8>)> {
        blocks
            .iter()
            .map(|pair| (header_bytes(&pair.block.header), pair.block.data[0].clone()))
            .collect()
    }

    fn published(blocks: &[CertifiedBlock]) -> Vec<PublishedBlock> {
        blocks.iter().map(PublishedBlock::from).collect()
    }

    /// `0x02 || rlp([[header, envelope], ...])`, assembled independently of `encode`.
    fn wire(items: &[(Vec<u8>, Vec<u8>)]) -> Vec<u8> {
        let mut list = Vec::new();
        for (header, envelope) in items {
            let length = header.as_slice().length() + envelope.as_slice().length();
            Header { list: true, payload_length: length }.encode(&mut list);
            header.as_slice().encode(&mut list);
            envelope.as_slice().encode(&mut list);
        }
        let mut bytes = vec![VERSION];
        Header { list: true, payload_length: list.len() }.encode(&mut bytes);
        bytes.extend_from_slice(&list);
        bytes
    }

    fn encoding_error(result: Result<Vec<PublishedBlock>>) -> String {
        match result {
            Err(LanderError::Encoding(reason)) => reason,
            other => panic!("expected an encoding error, got {other:?}"),
        }
    }

    #[test]
    fn canonical_wire_is_v038_header_protobuf_and_envelope_in_two_rlp_strings() {
        let blocks = chain(1);
        let expected = wire(&items(&blocks));
        assert_eq!(expected[0], 2);
        assert_eq!(encode(&blocks, &limits()).unwrap(), expected);
        assert_eq!(decode(&expected, &limits()).unwrap(), published(&blocks));
    }

    #[test]
    fn payload_omits_every_commit_signature() {
        let blocks = chain(3);
        let payload = encode(&blocks, &limits()).unwrap();
        let signatures = blocks
            .iter()
            .flat_map(|pair| {
                pair.commit
                    .signatures
                    .iter()
                    .chain(pair.block.last_commit.iter().flat_map(|c| c.signatures.iter()))
            })
            .filter_map(|sig| match sig {
                CommitSig::BlockIdFlagCommit { signature, .. } |
                CommitSig::BlockIdFlagNil { signature, .. } => signature.clone(),
                CommitSig::BlockIdFlagAbsent => None,
            })
            .collect::<Vec<_>>();
        assert_eq!(signatures.len(), 4 * 3 + 4 * 2);
        for signature in signatures {
            assert!(!payload.windows(64).any(|window| window == signature.as_bytes()));
        }
    }

    #[test]
    fn decoded_headers_hash_to_the_signed_block_ids_with_exact_envelopes() {
        let blocks = chain(3);
        let decoded = decode(&encode(&blocks, &limits()).unwrap(), &limits()).unwrap();
        assert_eq!(decoded, published(&blocks));
        for (block, pair) in decoded.iter().zip(&blocks) {
            assert_eq!(block.header.hash(), pair.commit.block_id.hash);
            assert_eq!(block.envelope, pair.block.data[0]);
        }
    }

    #[test]
    fn height_one_go_empty_last_block_id_is_noncanonical() {
        let blocks = chain(1);
        let mut go = RawHeader::from(blocks[0].block.header.clone());
        // Go's nullable=false BlockID/PartSetHeader are present even when empty; the domain
        // adapter maps them to `None`, which is the only published form.
        go.last_block_id = Some(RawBlockId {
            hash: Vec::new(),
            part_set_header: Some(RawPartSetHeader { total: 0, hash: Vec::new() }),
        });
        let normalized: tendermint::block::Header = go.clone().try_into().unwrap();
        assert_eq!(normalized, blocks[0].block.header);
        let envelope = blocks[0].block.data[0].clone();
        assert!(decode(&wire(&[(go.encode_to_vec(), envelope.clone())]), &limits()).is_err());
        assert!(decode(&wire(&[(header_bytes(&normalized), envelope)]), &limits()).is_ok());
    }

    #[test]
    fn rejects_empty_version_trailing_truncated_and_noncanonical_items() {
        let blocks = chain(1);
        let valid = encode(&blocks, &limits()).unwrap();
        assert!(decode(&[], &limits()).is_err());
        assert!(encode(&[], &limits()).is_err());
        assert!(decode(&[VERSION, 0xc0], &limits()).is_err());
        let mut changed = valid.clone();
        changed[0] = 1; // the former complete-block payload version
        assert!(decode(&changed, &limits()).is_err());
        let mut changed = valid.clone();
        changed.push(0);
        assert!(decode(&changed, &limits()).is_err());
        for end in [1, 2, valid.len() - 1] {
            assert!(decode(&valid[..end], &limits()).is_err());
        }
        let envelope = blocks[0].block.data[0].clone();
        let mut header = header_bytes(&blocks[0].block.header);
        header.extend_from_slice(&[0x18, 0x01]); // repeated singular height: protobuf accepts, canonical codec rejects.
        assert!(decode(&wire(&[(header, envelope.clone())]), &limits()).is_err());
        let mut header = header_bytes(&blocks[0].block.header);
        header.extend_from_slice(&[0xf8, 0x07, 0x01]); // unknown field.
        assert!(decode(&wire(&[(header, envelope.clone())]), &limits()).is_err());
        let mut padded = envelope;
        padded.push(0);
        assert!(
            decode(&wire(&[(header_bytes(&blocks[0].block.header), padded)]), &limits()).is_err()
        );
        assert!(decode(&[VERSION, 0xf8, 0x00], &limits()).is_err()); // noncanonical empty RLP list.
    }

    #[test]
    fn rejects_an_envelope_the_header_data_hash_does_not_commit_to() {
        let blocks = chain(2);
        let swapped =
            wire(&[(header_bytes(&blocks[0].block.header), blocks[1].block.data[0].clone())]);
        assert!(encoding_error(decode(&swapped, &limits())).contains("data hash"));
    }

    #[test]
    fn rejects_headers_that_do_not_link_by_last_block_id() {
        let blocks = chain(3);
        let all = items(&blocks);
        assert!(decode(&wire(&[all[0].clone(), all[2].clone()]), &limits()).is_err());
        let mut relinked = blocks[1].block.header.clone();
        let mut id = relinked.last_block_id.unwrap();
        id.hash = tendermint::Hash::Sha256([7; 32]);
        relinked.last_block_id = Some(id);
        let chained = [all[0].clone(), (header_bytes(&relinked), all[1].1.clone())];
        assert!(encoding_error(decode(&wire(&chained), &limits())).contains("last block id"));
        let mut first = blocks[0].block.header.clone();
        first.last_block_id = blocks[1].block.header.last_block_id;
        let first = [(header_bytes(&first), all[0].1.clone())];
        // The domain adapter itself refuses a previous block id at the first height.
        assert!(decode(&wire(&first), &limits()).is_err());
        let mut second = blocks[1].block.header.clone();
        second.last_block_id = None;
        let second = [(header_bytes(&second), all[1].1.clone())];
        assert!(encoding_error(decode(&wire(&second), &limits())).contains("last block id"));
    }

    #[test]
    fn encode_rejects_pair_height_hash_and_order_disagreement() {
        let blocks = chain(3);
        let mut pair = blocks[0].clone();
        pair.commit.height = 2u32.into();
        assert!(encode(&[pair], &limits()).is_err());
        let mut pair = blocks[0].clone();
        pair.commit.block_id.hash = tendermint::Hash::Sha256([0; 32]);
        assert!(encode(&[pair], &limits()).is_err());
        assert!(encode(&[blocks[0].clone(), blocks[2].clone()], &limits()).is_err());
        assert!(encode(&[blocks[1].clone(), blocks[0].clone()], &limits()).is_err());
    }

    #[test]
    fn bounds_count_message_and_payload_at_exact_capacity() {
        let blocks = chain(2);
        let one = &blocks[..1];
        let encoded = encode(one, &limits()).unwrap();
        let mut cap = limits();
        cap.max_payload_bytes = encoded.len();
        assert!(encode(one, &cap).is_ok());
        assert!(decode(&encoded, &cap).is_ok());
        cap.max_payload_bytes -= 1;
        assert!(encode(one, &cap).is_err());
        assert!(decode(&encoded, &cap).is_err());
        cap = limits();
        cap.max_blocks = 1;
        assert!(encode(&blocks, &cap).is_err());
        assert!(decode(&encode(&blocks, &limits()).unwrap(), &cap).is_err());
        let largest =
            header_bytes(&blocks[0].block.header).len().max(blocks[0].block.data[0].len());
        cap = limits();
        cap.max_message_bytes = largest;
        assert!(decode(&encoded, &cap).is_ok());
        cap.max_message_bytes = largest - 1;
        assert!(decode(&encoded, &cap).is_err());
        cap.max_message_bytes = 1;
        assert!(encode(one, &cap).is_err());
        cap = limits();
        cap.max_blocks = 0;
        assert!(decode(&encoded, &cap).is_err());
    }
}
