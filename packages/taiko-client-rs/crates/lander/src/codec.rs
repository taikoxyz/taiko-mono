//! V5 published block payload codec, bounded before parsing or allocating messages.
//!
//! A batch publishes each block's canonical CometBFT header and its single Etna envelope. The
//! header hashes to the block id the committee signed, its `data_hash` commits to the envelope and
//! its `last_block_id` to the preceding header. Commits and signatures are not published: proofs
//! take them as witnesses from the prepared batch. The pinned Tendermint domain adapter maps
//! CometBFT's empty height-1 last block id to `None`; V5 publishes that canonical domain form.
//!
//! V5 carries the RLP list compressed as one zlib stream with the codec the ABCI landing capacity
//! guard uses. A single block that does not fit otherwise is compressed with a full flush before
//! its envelope ([`zlib_compress_split`]), so the envelope deflates exactly as the guard measured
//! it and every block the guard admits lands on its own; decoders read any flush transparently.

use crate::{
    error::{LanderError, Result},
    types::{CertifiedBlock, Limits},
    validate::data_hash,
};

/// Version prefix of `0x05 || zlib(rlp([[header_proto, envelope], ...]))`.
pub const VERSION: u8 = 5;

use abci::compression::{
    InflateError, zlib_compress, zlib_compress_best, zlib_compress_split, zlib_inflate_exact,
};
use alloy_rlp::{Encodable, Header};
use prost::Message;
use tendermint_proto::v0_38::types::{Commit as RawCommit, Header as RawHeader};

/// One published block: its CometBFT header and the Etna envelope its single transaction holds.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PublishedBlock {
    /// Canonical CometBFT header whose hash is the signed block id hash.
    pub header: tendermint::block::Header,
    /// Exact envelope bytes, `0x06 || rlp([block, anchor, committee, forced])`.
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
///
/// The RLP list is bounded by `max_decompressed_bytes` before it is allocated; the compressed
/// payload, version byte included, by `max_payload_bytes`.
pub fn encode(blocks: &[CertifiedBlock], limits: &Limits) -> Result<Vec<u8>> {
    limits.validate()?;
    if blocks.is_empty() || blocks.len() > limits.max_blocks {
        return Err(LanderError::Capacity("batch is empty or exceeds block limit".into()));
    }
    let mut list = PayloadList::new(limits)?;
    for pair in blocks {
        list.push(pair)?;
    }
    if blocks.len() == 1 {
        compress_single(&list.to_list(), limits)
    } else {
        compress(&list.to_list(), limits)
    }
}

/// Compress one published block: at the default level, then at the best level, and when neither
/// fits, with a full flush before the envelope ([`zlib_compress_split`]). That last stream is at
/// most the envelope's own `zlib_compress` size plus the published prefix and
/// `SPLIT_OVERHEAD`, which the ABCI landing capacity guard reserves in `HEADER_ALLOWANCE`, so a
/// block the guard admitted always fits. Joint compression has no such bound: the header prefix
/// shifts the envelope's deflate block boundaries, which crafted calldata turns into kilobytes.
/// Larger prefixes keep the default codec and its deflate-work budget.
pub(crate) fn compress_single(list: &[u8], limits: &Limits) -> Result<Vec<u8>> {
    match compress(list, limits) {
        Err(LanderError::Capacity(_)) => {}
        result => return result,
    }
    match compressed_payload(zlib_compress_best(list), limits) {
        Err(LanderError::Capacity(_)) => {}
        result => return result,
    }
    let offset = single_envelope_offset(list)
        .ok_or_else(|| LanderError::Encoding("single-block list without one envelope".into()))?;
    let (prefix, envelope) = list.split_at(offset);
    compressed_payload(zlib_compress_split(prefix, envelope), limits)
}

/// The offset of the envelope bytes in a single block's list `rlp([[header_proto, envelope]])`:
/// everything before it is the published prefix (list headers, header, envelope string header).
fn single_envelope_offset(list: &[u8]) -> Option<usize> {
    let mut rest = list;
    let mut items = Header::decode_bytes(&mut rest, true).ok()?;
    if !rest.is_empty() {
        return None;
    }
    let mut fields = Header::decode_bytes(&mut items, true).ok()?;
    if !items.is_empty() {
        return None;
    }
    Header::decode_bytes(&mut fields, false).ok()?;
    let envelope = Header::decode_bytes(&mut fields, false).ok()?;
    fields.is_empty().then(|| list.len() - envelope.len())
}

/// `0x05 || zlib(list)`, bounded by `max_payload_bytes`.
pub(crate) fn compress(list: &[u8], limits: &Limits) -> Result<Vec<u8>> {
    compressed_payload(zlib_compress(list), limits)
}

/// Prefix a complete zlib stream after verifying its byte capacity.
fn compressed_payload(compressed: Vec<u8>, limits: &Limits) -> Result<Vec<u8>> {
    // The version byte precedes the compressed list.
    if compressed.len() + 1 > limits.max_payload_bytes {
        return Err(LanderError::Capacity("batch exceeds payload limit".into()));
    }
    let mut out = Vec::with_capacity(compressed.len() + 1);
    out.push(VERSION);
    out.extend_from_slice(&compressed);
    Ok(out)
}

/// An upper bound on [`compress`]'s output for a `list_len`-byte list: the version byte plus
/// deflate's worst case, which stores incompressible input with a few bytes of overhead per block
/// (zlib bounds it by `n + n/4096 + n/16384 + n/2^25 + 13`). Prefix selection accepts a list whose
/// bound already fits without compressing it.
pub(crate) const fn payload_bound(list_len: usize) -> usize {
    list_len.saturating_add(list_len / 256).saturating_add(64)
}

/// A V5 payload's RLP list, built one validated block at a time so prefix selection checks and
/// encodes each block once rather than once per candidate prefix.
pub(crate) struct PayloadList {
    /// Bounds applied to every appended block and to the whole list.
    limits: Limits,
    /// Encoded `[header_proto, envelope]` items, without the outer list header.
    items: Vec<u8>,
    /// End offset in `items` of each block's item.
    ends: Vec<usize>,
    /// Each block's header, linking its successor.
    headers: Vec<tendermint::block::Header>,
}

impl PayloadList {
    /// An empty list under `limits`.
    pub(crate) fn new(limits: &Limits) -> Result<Self> {
        limits.validate()?;
        Ok(Self { limits: *limits, items: Vec::new(), ends: Vec::new(), headers: Vec::new() })
    }

    /// Validates `pair` as the next block and appends its item; on error the list is unchanged.
    pub(crate) fn push(&mut self, pair: &CertifiedBlock) -> Result<()> {
        if self.ends.len() >= self.limits.max_blocks {
            return Err(LanderError::Capacity("batch is empty or exceeds block limit".into()));
        }
        validate_pair(pair)?;
        check_message_limits(pair, &self.limits)?;
        let published = PublishedBlock::from(pair);
        validate_published(&published, self.headers.last())?;
        let header = RawHeader::from(published.header.clone()).encode_to_vec();
        let length = header
            .as_slice()
            .length()
            .checked_add(published.envelope.as_slice().length())
            .ok_or_else(|| LanderError::Capacity("RLP item length overflow".into()))?;
        let items = self
            .items
            .len()
            .checked_add(Header { list: true, payload_length: length }.length())
            .and_then(|n| n.checked_add(length))
            .ok_or_else(|| LanderError::Capacity("RLP payload length overflow".into()))?;
        let total = Header { list: true, payload_length: items }
            .length()
            .checked_add(items)
            .ok_or_else(|| LanderError::Capacity("payload length overflow".into()))?;
        // Bound retained message bytes before appending; no whole-batch allocation precedes this.
        if total > self.limits.max_decompressed_bytes {
            return Err(LanderError::Capacity("batch exceeds decompressed limit".into()));
        }
        Header { list: true, payload_length: length }.encode(&mut self.items);
        header.as_slice().encode(&mut self.items);
        published.envelope.as_slice().encode(&mut self.items);
        self.ends.push(self.items.len());
        self.headers.push(published.header);
        Ok(())
    }

    /// Removes the last block, if any.
    pub(crate) fn pop(&mut self) {
        self.ends.pop();
        self.headers.pop();
        self.items.truncate(self.ends.last().copied().unwrap_or(0));
    }

    /// Bytes of the RLP list: the outer header and every item; at most `max_decompressed_bytes`.
    pub(crate) fn list_len(&self) -> usize {
        Header { list: true, payload_length: self.items.len() }.length() + self.items.len()
    }

    /// The RLP list `rlp([[header_proto, envelope], ...])`.
    pub(crate) fn to_list(&self) -> Vec<u8> {
        let mut list = Vec::with_capacity(self.list_len());
        Header { list: true, payload_length: self.items.len() }.encode(&mut list);
        list.extend_from_slice(&self.items);
        list
    }
}

/// Bound one block and certificate without retaining a complete backlog or encoding its payload.
///
/// The prepared batch keeps both protobufs as proof witnesses, so they stay bounded even though
/// only the header and envelope are published.
pub(crate) fn check_message_limits(pair: &CertifiedBlock, limits: &Limits) -> Result<()> {
    let commit = RawCommit::from(pair.commit.clone());
    if pair.raw_block.len() > limits.max_message_bytes ||
        commit.encoded_len() > limits.max_message_bytes
    {
        return Err(LanderError::Capacity(format!(
            "protobuf at height {} exceeds message limit",
            pair.block.header.height
        )));
    }
    Ok(())
}

/// Decode one complete zlib stream of at most `max_decompressed_bytes`, then bounded, canonical RLP
/// and canonical v0_38 protobuf headers with their envelopes.
pub fn decode(payload: &[u8], limits: &Limits) -> Result<Vec<PublishedBlock>> {
    limits.validate()?;
    if payload.len() > limits.max_payload_bytes {
        return Err(LanderError::Capacity("batch exceeds payload limit".into()));
    }
    let (&version, compressed) =
        payload.split_first().ok_or_else(|| LanderError::Encoding("empty batch payload".into()))?;
    if version != VERSION {
        return Err(LanderError::Encoding(format!("unsupported batch version {version}")));
    }
    let inflated =
        zlib_inflate_exact(compressed, limits.max_decompressed_bytes).map_err(|e| match e {
            InflateError::TooLarge { .. } => {
                LanderError::Capacity("batch exceeds decompressed limit".into())
            }
            InflateError::Malformed | InflateError::TrailingBytes => {
                LanderError::Encoding(format!("invalid batch compression: {e}"))
            }
        })?;
    let mut outer = inflated.as_slice();
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
        validate_published(&block, blocks.last().map(|previous| &previous.header))?;
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
pub(crate) fn validate_pair(pair: &CertifiedBlock) -> Result<()> {
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
fn validate_published(
    block: &PublishedBlock,
    previous: Option<&tendermint::block::Header>,
) -> Result<()> {
    let height = block.header.height.value();
    if height == 0 {
        return Err(LanderError::Encoding("published block at height 0".into()));
    }
    let linked = match previous {
        Some(previous) => {
            if previous.height.value().checked_add(1) != Some(height) {
                return Err(LanderError::Encoding(format!(
                    "nonconsecutive block height {height} after {}",
                    previous.height
                )));
            }
            block.header.last_block_id.map(|id| id.hash) == Some(previous.hash())
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
    use abci::compression::zlib_compress;
    use alloy_primitives::B256;
    use alloy_rlp::{Encodable, Header};
    use prost::Message;
    use tendermint::block::CommitSig;
    use tendermint_proto::v0_38::types::{
        BlockId as RawBlockId, Header as RawHeader, PartSetHeader as RawPartSetHeader,
    };

    #[test]
    fn retries_best_compression_for_a_single_block_that_exceeds_default_output() {
        use flate2::{Compression, write::ZlibEncoder};
        use std::io::Write;

        let list: Vec<u8> =
            (0..100_000u32).flat_map(|i| (i % 1021).to_le_bytes().repeat(4)).collect();
        let default = zlib_compress(&list);
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::best());
        encoder.write_all(&list).unwrap();
        let best = encoder.finish().unwrap();
        assert!(best.len() < default.len());
        let limits = Limits { max_payload_bytes: best.len() + 1, ..limits() };
        assert!(matches!(compress(&list, &limits), Err(LanderError::Capacity(_))));
        let payload = compress_single(&list, &limits).expect("best level fits the payload cap");
        assert_eq!(payload[0], VERSION);
        assert_eq!(zlib_inflate_exact(&payload[1..], list.len()).unwrap(), list);
    }

    fn limits() -> Limits {
        Limits {
            max_blocks: 4,
            max_blobs: 2,
            max_payload_bytes: 250_000,
            max_message_bytes: 200_000,
            max_decompressed_bytes: 1_000_000,
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

    /// Consecutive blocks whose envelopes each carry one all-zero `size`-byte transaction.
    fn zero_heavy_chain(len: u64, size: usize) -> Vec<CertifiedBlock> {
        let (_, committee, keys) = consensus::committee(&[1, 1, 1, 1], 0);
        let mut blocks: Vec<CertifiedBlock> = Vec::new();
        for height in 1..=len {
            let envelope = abci::EtnaEnvelope {
                block: abci::ExecutionBlock {
                    header: alloy_consensus::Header {
                        number: height,
                        parent_hash: B256::repeat_byte(u8::try_from(height).unwrap()),
                        ..Default::default()
                    },
                    transactions: vec![vec![0; size].into()],
                },
                anchor: None,
                committee: None,
                forced: None,
            };
            let pair = consensus::pair_with_envelope(envelope, &committee, &keys, blocks.last());
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

    /// `rlp([[header, envelope], ...])`, assembled independently of `encode`.
    fn list(items: &[(Vec<u8>, Vec<u8>)]) -> Vec<u8> {
        let mut body = Vec::new();
        for (header, envelope) in items {
            let length = header.as_slice().length() + envelope.as_slice().length();
            Header { list: true, payload_length: length }.encode(&mut body);
            header.as_slice().encode(&mut body);
            envelope.as_slice().encode(&mut body);
        }
        let mut bytes = Vec::new();
        Header { list: true, payload_length: body.len() }.encode(&mut bytes);
        bytes.extend_from_slice(&body);
        bytes
    }

    /// `version || zlib(list)`.
    fn frame(version: u8, list: &[u8]) -> Vec<u8> {
        let mut bytes = vec![version];
        bytes.extend_from_slice(&zlib_compress(list));
        bytes
    }

    /// `0x05 || zlib(rlp([[header, envelope], ...]))`, assembled independently of `encode`.
    fn wire(items: &[(Vec<u8>, Vec<u8>)]) -> Vec<u8> {
        frame(VERSION, &list(items))
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
        assert_eq!(expected[0], 5);
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
        assert!(encoding_error(decode(&wire(&[]), &limits())).contains("empty batch list"));
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
        assert!(decode(&frame(VERSION, &[0xf8, 0x00]), &limits()).is_err()); // noncanonical empty RLP list.
    }

    #[test]
    fn payload_list_appends_and_removes_whole_blocks() {
        let blocks = chain(3);
        let mut payload_list = PayloadList::new(&limits()).unwrap();
        for pair in &blocks {
            payload_list.push(pair).unwrap();
        }
        assert_eq!(payload_list.to_list(), list(&items(&blocks)));
        payload_list.pop();
        let two = list(&items(&blocks[..2]));
        assert_eq!((payload_list.to_list(), payload_list.list_len()), (two.clone(), two.len()));
        // A block that does not link is refused without changing the list.
        assert!(payload_list.push(&blocks[0]).is_err());
        assert_eq!(payload_list.to_list(), two);
        payload_list.push(&blocks[2]).unwrap();
        assert_eq!(
            compress(&payload_list.to_list(), &limits()).unwrap(),
            encode(&blocks, &limits()).unwrap()
        );

        let cap = Limits { max_decompressed_bytes: two.len(), ..limits() };
        let mut bounded = PayloadList::new(&cap).unwrap();
        bounded.push(&blocks[0]).unwrap();
        bounded.push(&blocks[1]).unwrap();
        assert!(matches!(bounded.push(&blocks[2]), Err(LanderError::Capacity(_))));
        assert_eq!(bounded.to_list(), two);
    }

    #[test]
    fn payload_bound_covers_incompressible_lists() {
        let mut state = 0x2545_f491_4f6c_dd1d_u64;
        let unbounded = Limits { max_payload_bytes: usize::MAX, ..limits() };
        for len in [0, 1, 100, 65_535, 65_536, 300_000, 1 << 20] {
            let data = (0..len)
                .map(|_| {
                    state ^= state << 13;
                    state ^= state >> 7;
                    state ^= state << 17;
                    (state >> 56) as u8
                })
                .collect::<Vec<_>>();
            let payload = compress(&data, &unbounded).unwrap();
            assert!(payload.len() > len, "random bytes do not compress");
            assert!(payload.len() <= payload_bound(len), "{len}: {}", payload.len());
        }
    }

    #[test]
    fn v2_payload_is_rejected() {
        let blocks = chain(2);
        let list = list(&items(&blocks));
        assert!(
            encoding_error(decode(&frame(3, &list), &limits()))
                .contains("unsupported batch version 3")
        );
        assert!(
            encoding_error(decode(&frame(4, &list), &limits()))
                .contains("unsupported batch version 4")
        );
        let mut v2 = vec![2];
        v2.extend_from_slice(&list);
        assert!(encoding_error(decode(&v2, &limits())).contains("unsupported batch version 2"));
        // Neither the V2 version byte over a compressed list nor V3's over an uncompressed one.
        assert!(
            encoding_error(decode(&frame(2, &list), &limits()))
                .contains("unsupported batch version 2")
        );
        let mut uncompressed = vec![VERSION];
        uncompressed.extend_from_slice(&list);
        assert!(encoding_error(decode(&uncompressed, &limits())).contains("zlib"));
    }

    #[test]
    fn trailing_bytes_after_the_zlib_stream_are_rejected() {
        let blocks = chain(2);
        let valid = encode(&blocks, &limits()).unwrap();
        assert_eq!(decode(&valid, &limits()).unwrap(), published(&blocks));
        let mut padded = valid.clone();
        padded.push(0);
        assert!(
            encoding_error(decode(&padded, &limits()))
                .contains("trailing bytes after the zlib stream")
        );
        let mut doubled = valid.clone();
        doubled.extend_from_slice(&valid[1..]);
        assert!(
            encoding_error(decode(&doubled, &limits()))
                .contains("trailing bytes after the zlib stream")
        );
    }

    #[test]
    fn decompressed_size_above_cap_is_rejected() {
        let blocks = chain(3);
        let list = list(&items(&blocks));
        let payload = encode(&blocks, &limits()).unwrap();
        assert_eq!(payload, frame(VERSION, &list));
        let mut cap = limits();
        cap.max_decompressed_bytes = list.len();
        assert_eq!(decode(&payload, &cap).unwrap(), published(&blocks));
        assert_eq!(encode(&blocks, &cap).unwrap(), payload);
        cap.max_decompressed_bytes -= 1;
        assert!(matches!(decode(&payload, &cap), Err(LanderError::Capacity(_))));
        assert!(matches!(encode(&blocks, &cap), Err(LanderError::Capacity(_))));
        cap.max_decompressed_bytes = 0;
        assert!(matches!(decode(&payload, &cap), Err(LanderError::Configuration(_))));
    }

    #[test]
    fn compressed_limit_counts_compressed_bytes() {
        let blocks = zero_heavy_chain(3, 100_000);
        assert!(list(&items(&blocks)).len() > 300_000);
        let cap = Limits { max_payload_bytes: 4_096, ..limits() };
        let payload = encode(&blocks, &cap).unwrap();
        assert!(payload.len() <= cap.max_payload_bytes);
        assert_eq!(decode(&payload, &cap).unwrap(), published(&blocks));
        let tight = Limits { max_payload_bytes: payload.len() - 1, ..cap };
        assert!(matches!(encode(&blocks, &tight), Err(LanderError::Capacity(_))));
        assert!(matches!(decode(&payload, &tight), Err(LanderError::Capacity(_))));
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
        assert!(decode(&encoded, &cap).is_err());
        let list = zlib_inflate_exact(&encoded[1..], usize::MAX).unwrap();
        cap.max_payload_bytes = encoded.len().min(zlib_compress_best(&list).len() + 1) - 1;
        assert!(encode(one, &cap).is_err());
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
