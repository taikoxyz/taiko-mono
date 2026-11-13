//! The V6 payload codec, `0x06 || zlib(rlp([ExecutionBlock, ...]))`, whose decoder reads
//! blob data anyone can post.

use std::sync::LazyLock;

use abci::EtnaEnvelope;
use alloy_primitives::B256;
use proptest::{collection::vec, prelude::*, sample::Index};

use super::strategies::{bytes, envelope_with};
use crate::{
    blob::{MAX_LANDING_BLOBS, PAYLOAD_BYTES_PER_BLOB},
    codec::{self, PublishedBlock, VERSION},
    compression::{zlib_compress, zlib_inflate_exact},
    config::COMET_BLOCK_MAX_BYTES,
    test_utils::consensus,
    types::{CertifiedBlock, Limits},
};

/// Limits every generated payload fits: up to eight blocks of CometBFT-sized messages in a
/// landing's six blobs.
fn limits() -> Limits {
    Limits {
        max_blocks: 8,
        max_blobs: MAX_LANDING_BLOBS,
        max_payload_bytes: MAX_LANDING_BLOBS * PAYLOAD_BYTES_PER_BLOB,
        max_message_bytes: COMET_BLOCK_MAX_BYTES,
        max_decompressed_bytes: 1 << 24,
    }
}

/// A genuinely signed chain of consecutive blocks from height 1, one per envelope, each
/// envelope's execution header numbered with its block's height.
fn chain(envelopes: Vec<EtnaEnvelope>) -> Vec<CertifiedBlock> {
    let (_, committee, keys) = consensus::committee(&[1], 0);
    let mut blocks: Vec<CertifiedBlock> = Vec::new();
    for (height, mut envelope) in (1..).zip(envelopes) {
        envelope.block.header.number = height;
        if let Some(previous) = blocks.last() {
            envelope.block.header.parent_hash =
                EtnaEnvelope::decode(&previous.block.data[0]).unwrap().block.header.hash_slow();
        }
        blocks.push(consensus::pair_with_envelope(envelope, &committee, &keys, blocks.last()));
    }
    blocks
}

/// What a payload of `blocks` publishes.
fn published(blocks: &[CertifiedBlock]) -> Vec<PublishedBlock> {
    blocks.iter().map(|pair| PublishedBlock::try_from(pair).unwrap()).collect()
}

/// The published items of `blocks`: each header's canonical protobuf and its execution block.
fn items(blocks: &[PublishedBlock]) -> Vec<Vec<u8>> {
    blocks.iter().map(|block| alloy_rlp::encode(&block.block)).collect()
}

/// Outer RLP list over already encoded execution block lists.
fn list(items: &[Vec<u8>]) -> Vec<u8> {
    let body = items.concat();
    let mut out = Vec::new();
    alloy_rlp::Header { list: true, payload_length: body.len() }.encode(&mut out);
    out.extend(body);
    out
}

/// `0x06 || zlib(list)`.
fn frame(list: &[u8]) -> Vec<u8> {
    [vec![VERSION], zlib_compress(list)].concat()
}

/// The published items of a real three-block chain, to edit.
static REAL_ITEMS: LazyLock<Vec<Vec<u8>>> = LazyLock::new(|| {
    let (_, committee, keys) = consensus::committee(&[1], 0);
    let mut blocks: Vec<CertifiedBlock> = Vec::new();
    for height in 1..=3u8 {
        let parent = blocks
            .last()
            .map(|p: &CertifiedBlock| {
                EtnaEnvelope::decode(&p.block.data[0]).unwrap().block.header.hash_slow()
            })
            .unwrap_or(B256::repeat_byte(height));
        let previous = blocks.last();
        blocks.push(consensus::pair(height.into(), parent, &committee, &keys, previous));
    }
    items(&published(&blocks))
});

/// One edit of a published item's bytes.
#[derive(Clone, Debug)]
enum Edit {
    /// Flips one bit (`0..8`) of the byte at a position.
    FlipBit(Index, u8),
    /// Inserts a byte before a position (or at the end).
    Insert(Index, u8),
    /// Removes the byte at a position.
    Remove(Index),
    /// Appends a varint field numbered 15, which the CometBFT header message does not define:
    /// protobuf decoders skip it, so only the codec's canonical-encoding check refuses it.
    UnknownField(u8),
}

/// Up to three [`Edit`]s.
fn edits() -> impl Strategy<Value = Vec<Edit>> {
    let edit = prop_oneof![
        (any::<Index>(), 0..8u8).prop_map(|(at, bit)| Edit::FlipBit(at, bit)),
        (any::<Index>(), any::<u8>()).prop_map(|(at, byte)| Edit::Insert(at, byte)),
        any::<Index>().prop_map(Edit::Remove),
        (0..0x80u8).prop_map(Edit::UnknownField),
    ];
    vec(edit, 0..=3)
}

/// `bytes` after `edits`.
fn edited(bytes: &[u8], edits: &[Edit]) -> Vec<u8> {
    let mut bytes = bytes.to_vec();
    for edit in edits {
        let len = bytes.len();
        match edit {
            Edit::FlipBit(at, bit) if len > 0 => bytes[at.index(len)] ^= 1 << bit,
            Edit::Insert(at, byte) => bytes.insert(at.index(len + 1), *byte),
            Edit::Remove(at) if len > 0 => {
                bytes.remove(at.index(len));
            }
            Edit::UnknownField(value) => bytes.extend([15 << 3, *value]),
            Edit::FlipBit(..) | Edit::Remove(_) => {}
        }
    }
    bytes
}

/// Lists of header/execution items: arbitrary byte pairs, or a prefix of a real chain's items,
/// each with up to three [`Edit`]s.
fn item_lists() -> impl Strategy<Value = Vec<Vec<u8>>> {
    prop_oneof![
        vec(bytes(600), 0..=4),
        (1..=REAL_ITEMS.len(), vec(edits(), REAL_ITEMS.len())).prop_map(|(len, edits)| {
            REAL_ITEMS[..len]
                .iter()
                .zip(edits)
                .map(|(execution, edits)| edited(execution, &edits))
                .collect()
        }),
    ]
}

/// Decodes `payload` (which must not panic) and, if it is accepted, checks the block count
/// against the limits and that the blocks' published items re-encode to exactly the payload's
/// inflated list: the decoder accepts only the canonical encoding of what it returns.
fn assert_canonical_decode(payload: &[u8]) -> Result<(), TestCaseError> {
    let limits = limits();
    if let Ok(blocks) = codec::decode(payload, &limits) {
        prop_assert!(!blocks.is_empty() && blocks.len() <= limits.max_blocks);
        let inflated = zlib_inflate_exact(&payload[1..], limits.max_decompressed_bytes)?;
        prop_assert_eq!(list(&items(&blocks)), inflated);
    }
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 2048, ..ProptestConfig::default() })]

    /// Arbitrary payloads, with or without the V6 version byte, never panic the decoder.
    #[test]
    fn decode_never_panics_on_arbitrary_payloads(
        payload in prop_oneof![bytes(2_000), bytes(2_000).prop_map(|b| [vec![VERSION], b].concat())],
    ) {
        assert_canonical_decode(&payload)?;
    }

    /// `0x06 || zlib(bytes)` never panics the decoder, whatever the bytes.
    #[test]
    fn decode_never_panics_on_compressed_arbitrary_bytes(bytes in bytes(2_000)) {
        assert_canonical_decode(&frame(&bytes))?;
    }

    /// `0x06 || zlib(rlp([[header, execution], ...]))` never panics the decoder, whether the
    /// items are arbitrary bytes or a real chain's header protobufs and envelopes with a few
    /// bytes edited, and any payload it accepts is canonical.
    #[test]
    fn decode_accepts_only_canonical_header_execution_lists(items in item_lists()) {
        assert_canonical_decode(&frame(&list(&items)))?;
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 128, ..ProptestConfig::default() })]

    /// A genuinely signed, consecutive chain of one to four blocks with arbitrary envelopes
    /// encodes into a payload that decodes to exactly its published blocks.
    #[test]
    fn decode_returns_the_published_blocks_an_encoded_chain_carries(
        envelopes in vec(envelope_with(vec(bytes(300), 0..=3)), 1..=4),
    ) {
        let blocks = chain(envelopes);
        let payload = codec::encode(&blocks, &limits())?;
        prop_assert_eq!(codec::decode(&payload, &limits())?, published(&blocks));
    }
}
