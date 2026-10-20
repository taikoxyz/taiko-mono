//! The landing capacity guard's promise to the lander: every block it admits lands on its own.
//!
//! The guard sizes a block by its envelope alone, so the published header must fit the room it
//! reserves, and the single-block payload must deflate the envelope as the guard measured it,
//! whatever the header's length shifts. The properties below are scale-free: a block lands alone
//! within the guard's measure whatever its size, and the guard's own bound,
//! `MAX_BLOCK_LANDING_BYTES`, is the case that fits `MAX_LANDING_BLOBS` blobs.

use abci::compression::{
    HEADER_ALLOWANCE, MAX_BLOCK_LANDING_BYTES, MAX_LANDING_BLOBS, zlib_compress,
};
use proptest::{collection::vec, prelude::*};
use tendermint::block::{self, Commit};

use super::strategies::{
    HeaderFields, Payload, bytes, envelope_with, header_fields, noise, payload,
};
use crate::{
    blob,
    codec::{self, PublishedBlock},
    config::COMET_BLOCK_MAX_BYTES,
    test_utils::consensus,
    types::{CertifiedBlock, Limits, SidecarMode},
    validate::block_parts,
};

/// The landing capacity guard's measure of a block: its envelope (the CometBFT transaction) as
/// zlib compresses it, plus `HEADER_ALLOWANCE` for the published header. The guard admits the
/// block iff the measure is at most `MAX_BLOCK_LANDING_BYTES`.
///
/// A replica of `check_landing_capacity` in `abci/src/app/validate.rs`, which is `pub(crate)`
/// there; `process_rejects_a_block_that_cannot_fit_one_landing` in `abci/src/app/tests/process.rs`
/// pins the guard to exactly this formula.
pub(crate) fn guard_measure(envelope: &[u8]) -> usize {
    zlib_compress(&alloy_rlp::encode(&abci::EtnaEnvelope::decode(envelope).unwrap().block)).len() +
        HEADER_ALLOWANCE
}

/// A certified block whose header has `fields` and whose one transaction is `envelope`, with no
/// last commit and an unsigned commit naming it: the codec checks that a commit names its block,
/// not its signatures.
fn certified(fields: &HeaderFields, envelope: Vec<u8>) -> CertifiedBlock {
    let header = fields.header(&envelope);
    let mut decoded = abci::EtnaEnvelope::decode(&envelope).unwrap();
    decoded.block.header.number = header.height.value();
    let envelope = decoded.encode().to_vec();
    let header = fields.header(&envelope);
    let block = tendermint::Block::new(header, vec![envelope], Default::default(), None);
    let raw = consensus::raw_block(&block);
    let commit = Commit {
        height: block.header.height,
        round: 0u16.into(),
        block_id: block::Id { hash: block.header.hash(), part_set_header: block_parts(&raw) },
        signatures: vec![],
    };
    CertifiedBlock::from_raw(raw, commit).expect("a valid CometBFT block")
}

/// Limits under which a block whose guard measure is `measure` must land alone: a payload of at
/// most `measure` bytes in the blobs that takes, CometBFT-sized messages, and `max_blocks`.
fn landing_limits(measure: usize, max_blocks: usize) -> Limits {
    Limits {
        max_blocks,
        max_blobs: blob::required_blobs(measure),
        max_payload_bytes: measure,
        max_message_bytes: COMET_BLOCK_MAX_BYTES,
        max_decompressed_bytes: COMET_BLOCK_MAX_BYTES,
    }
}

/// An encoded envelope whose first transaction is `payload`, sometimes followed by a short second
/// one, with random witnesses.
fn landing_envelope(payload: impl Strategy<Value = Payload>) -> impl Strategy<Value = Vec<u8>> {
    (envelope_with(vec(bytes(200), 1..=2)), payload).prop_map(|(mut envelope, payload)| {
        payload.fill(&mut envelope);
        envelope.encode().to_vec()
    })
}

/// Encodes `block` alone under the limits its guard measure `measure` sets, checks that the
/// payload is at most `measure` bytes and decodes back to the block, and returns it.
fn land_alone(
    block: &CertifiedBlock,
    measure: usize,
    max_blocks: usize,
) -> Result<Vec<u8>, TestCaseError> {
    let limits = landing_limits(measure, max_blocks);
    let payload = codec::encode(std::slice::from_ref(block), &limits)
        .map_err(|error| TestCaseError::fail(format!("measure {measure}: {error}")))?;
    prop_assert!(payload.len() <= measure, "{} > {measure}", payload.len());
    prop_assert_eq!(
        codec::decode(&payload, &limits)?,
        vec![PublishedBlock::try_from(block).unwrap()]
    );
    Ok(payload)
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 48, ..ProptestConfig::default() })]

    /// Whatever its envelope holds (noise, repeated-byte runs, deflate-boundary runs, mostly
    /// aligned so that the published header shifts them across deflate's block boundaries, and
    /// random witnesses) and whatever its published header's variable fields (a chain id of up
    /// to 50 bytes, any height, time, last block id, app hash and other hashes), a block lands
    /// alone within its guard measure `g`: encoding it with `max_payload_bytes = g` succeeds, the
    /// payload is at most `g` bytes and decodes back to it, and it needs at most
    /// `MAX_LANDING_BLOBS` blobs whenever the guard admits the block.
    #[test]
    fn a_block_lands_alone_within_its_landing_guard_measure(
        envelope in landing_envelope(payload(120_000)),
        fields in header_fields(),
        max_blocks in 1usize..=16,
    ) {
        let measure = guard_measure(&envelope);
        let payload = land_alone(&certified(&fields, envelope), measure, max_blocks)?;
        if measure <= MAX_BLOCK_LANDING_BYTES {
            prop_assert!(blob::required_blobs(payload.len()) <= MAX_LANDING_BLOBS);
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 3, ..ProptestConfig::default() })]

    /// A block whose noise transaction brings its guard measure to just within
    /// `MAX_BLOCK_LANDING_BYTES` lands alone in at most `MAX_LANDING_BLOBS` blobs, whatever its
    /// header's variable fields and its witnesses.
    #[test]
    fn a_block_at_the_landing_guard_bound_lands_in_at_most_max_landing_blobs(
        envelope in landing_envelope(Just(Payload::Noise { len: 0, seed: 0 })),
        seed in any::<u64>(),
        fields in header_fields(),
    ) {
        // Grow the transaction until the measure reaches the bound (noise deflates to about its
        // own length), and land the largest block the guard still admits.
        let envelope_with_noise = |len: usize| {
            let mut envelope = abci::EtnaEnvelope::decode(&envelope).expect("an envelope");
            envelope.block.transactions[0] = noise(len, seed).into();
            envelope.encode().to_vec()
        };
        let mut len = MAX_BLOCK_LANDING_BYTES - guard_measure(&envelope);
        let mut bounded = envelope_with_noise(len);
        while guard_measure(&bounded) > MAX_BLOCK_LANDING_BYTES {
            len -= guard_measure(&bounded) - MAX_BLOCK_LANDING_BYTES;
            bounded = envelope_with_noise(len);
        }
        let measure = guard_measure(&bounded);
        prop_assert!(MAX_BLOCK_LANDING_BYTES - measure < 64, "{measure} is far below the bound");
        let payload = land_alone(&certified(&fields, bounded), measure, 1)?;
        prop_assert!(blob::required_blobs(payload.len()) <= MAX_LANDING_BLOBS);
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 3, ..ProptestConfig::default() })]

    /// The payload of a block landing alone builds into a sidecar of exactly the blobs counted
    /// for it, within its limits, which serves the payload back (few cases: KZG commitments and
    /// proofs are slow in a debug build).
    #[test]
    fn a_landing_payload_builds_into_the_blobs_counted_for_it(
        envelope in landing_envelope(payload(200_000)),
        fields in header_fields(),
    ) {
        let measure = guard_measure(&envelope);
        let payload = land_alone(&certified(&fields, envelope), measure, 1)?;
        let limits = landing_limits(measure, 1);
        let blobs = blob::build(&payload, &limits, SidecarMode::Eip4844)?;
        prop_assert_eq!(blobs.versioned_hashes.len(), blob::required_blobs(payload.len()));
        prop_assert!(blobs.versioned_hashes.len() <= limits.max_blobs);
        prop_assert_eq!(blob::decode(blobs.sidecar.blobs(), &limits)?, payload);
    }
}
