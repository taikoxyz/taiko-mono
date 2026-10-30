//! Property test of complete-prefix selection ([`BatchBuilder::publishable_prefix`]) over decided
//! chains of blocks of random sizes and contents, under payload capacities around the first
//! block's own payload size and random deflate budgets.

use std::sync::Arc;

use abci::{AnchorState, AnchorWitness, ChainParams, CommitteeWitness, RawL1Header};
use alloy_primitives::B256;
use async_trait::async_trait;
use proptest::{collection::vec, prelude::*};

use super::{BatchBuilder, BatchBuilderConfig, MAX_BATCH_LIST_BYTES};
use crate::{
    blob::{self, PAYLOAD_BYTES_PER_BLOB},
    codec::{self, PublishedBlock},
    comet::{CometSource, CometStatus},
    config::COMET_BLOCK_MAX_BYTES,
    error::{LanderError, Result},
    l1::{LandingSource, ParentContext},
    proptests::strategies::{bytes, envelope_with, payload},
    test_utils::{consensus, protocol},
    types::{CertifiedBlock, LandingSnapshot, Limits, SidecarMode},
};

/// A decided chain served from memory. Prefix selection reads its blocks only; every other read
/// fails.
struct Decided(Vec<CertifiedBlock>);

/// The error of a read prefix selection never makes.
fn unread(what: &str) -> LanderError {
    LanderError::Unavailable(format!("prefix selection does not read {what}"))
}

#[async_trait]
impl CometSource for Decided {
    async fn status(&self) -> Result<CometStatus> {
        Err(unread("the CometBFT status"))
    }

    async fn block(&self, height: u64) -> Result<CertifiedBlock> {
        let index = usize::try_from(height).ok().and_then(|height| height.checked_sub(1));
        index
            .and_then(|index| self.0.get(index))
            .cloned()
            .ok_or_else(|| LanderError::Unavailable(format!("no decided block at height {height}")))
    }
}

#[async_trait]
impl LandingSource for Decided {
    async fn snapshot(&self) -> Result<LandingSnapshot> {
        Err(unread("L1"))
    }

    async fn parent_header(&self, _: &LandingSnapshot) -> Result<ParentContext> {
        Err(unread("L1"))
    }

    async fn execution_header(&self, _: u64) -> Result<alloy_consensus::Header> {
        Err(unread("L2"))
    }

    async fn parent_anchor(&self, _: &LandingSnapshot, _: &ParentContext) -> Result<AnchorState> {
        Err(unread("L1"))
    }

    async fn starting_inbox_witness(&self, _: &AnchorState) -> Result<AnchorWitness> {
        Err(unread("L1"))
    }

    async fn committee_witness(&self, _: &AnchorState, _: u64, _: u64) -> Result<CommitteeWitness> {
        Err(unread("L1"))
    }

    async fn reference(&self, _: &LandingSnapshot, _: &[AnchorState]) -> Result<Vec<RawL1Header>> {
        Err(unread("L1"))
    }

    async fn deployment(&self, _: &LandingSnapshot) -> Result<crate::l1::Deployment> {
        Err(unread("L1"))
    }
    async fn canonical_hash(&self, _: u64) -> Result<B256> {
        Err(unread("L1"))
    }

    async fn validate_reference(&self, _: &LandingSnapshot, _: u64, _: B256) -> Result<()> {
        Err(unread("L1"))
    }
}

/// The payload bytes `limits` admit: `max_payload_bytes`, or fewer if `max_blobs` blobs carry
/// less.
fn capacity(limits: &Limits) -> usize {
    limits.max_payload_bytes.min(limits.max_blobs * PAYLOAD_BYTES_PER_BLOB)
}

/// Limits under which any one decided block encodes alone: a landing's blobs and CometBFT-sized
/// messages.
fn unbounded() -> Limits {
    Limits {
        max_blocks: 1,
        max_blobs: blob::MAX_LANDING_BLOBS,
        max_payload_bytes: blob::MAX_LANDING_BLOBS * PAYLOAD_BYTES_PER_BLOB,
        max_message_bytes: COMET_BLOCK_MAX_BYTES,
        max_decompressed_bytes: COMET_BLOCK_MAX_BYTES,
    }
}

/// One to four decided blocks from height 1, each carrying as its first transaction a payload of
/// up to 150 kB, 75 kB or 37.5 kB.
fn decided_chain() -> impl Strategy<Value = Vec<CertifiedBlock>> {
    let sized = prop_oneof![payload(150_000), payload(75_000), payload(37_500)];
    vec((envelope_with(vec(bytes(100), 1..=2)), sized), 6..=12).prop_map(|blocks| {
        let (_, committee, keys) = consensus::committee(&[1], 0);
        let mut chain: Vec<CertifiedBlock> = Vec::new();
        for (height, (mut envelope, payload)) in (1..).zip(blocks) {
            envelope.block.header.number = height;
            if let Some(previous) = chain.last() {
                envelope.block.header.parent_hash =
                    abci::EtnaEnvelope::decode(&previous.block.data[0])
                        .unwrap()
                        .block
                        .header
                        .hash_slow();
            }
            payload.fill(&mut envelope);
            chain.push(consensus::pair_with_envelope(envelope, &committee, &keys, chain.last()));
        }
        chain
    })
}

/// Where a payload bound sits against the first block's own payload size `g`.
#[derive(Clone, Copy, Debug)]
enum Room {
    /// `g - n` bytes: too few for the first block.
    Below(usize),
    /// `g + n` bytes, `n` at most 64: just room for the first block.
    At(usize),
    /// `g` times the factor: room for further blocks.
    Above(f64),
}

impl Room {
    /// The payload bound for a first block whose own payload is `measure` bytes.
    fn bound(self, measure: usize) -> usize {
        match self {
            Self::Below(n) => measure.saturating_sub(n).max(1),
            Self::At(n) => measure + n,
            Self::Above(factor) => (measure as f64 * factor) as usize,
        }
    }
}

/// A [`Room`]: below, at or (most often) above the first block's own payload size.
fn room() -> impl Strategy<Value = Room> {
    prop_oneof![
        1 => (1usize..=2_048).prop_map(Room::Below),
        1 => (0usize..=64).prop_map(Room::At),
        2 => (1.01..=3.0f64).prop_map(Room::Above),
    ]
}

/// A builder selecting from `chain` under `limits`, the deployed `max_batch_blocks` and the
/// deflate budget `deflate_bytes`.
fn builder(
    chain: Vec<CertifiedBlock>,
    limits: Limits,
    max_batch_blocks: u64,
    deflate_bytes: usize,
) -> BatchBuilder<Decided, Decided> {
    let decided = Arc::new(Decided(chain));
    let config = BatchBuilderConfig {
        params: ChainParams::builtin(167_001).expect("a built-in chain"),
        limits,
        mode: SidecarMode::Eip4844,
        engine: Arc::new(test_harness::unavailable_engine::UnavailableEngine),
        engine_timeout: std::time::Duration::from_secs(1),
        max_batch_blocks,
    };
    BatchBuilder::new(decided.clone(), decided, config)
        .expect("valid limits")
        .with_selection_budgets(MAX_BATCH_LIST_BYTES, deflate_bytes)
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 32, ..ProptestConfig::default() })]

    /// Selection returns an exact consecutive prefix ending on a grid point within every capacity
    /// bound, never above the configured or the deployed batch limit.
    /// Admitting the first block prevents a first-block capacity error; admitting all six candidate
    /// prefixes with enough deflate work guarantees a nonempty grid segment. Random capacities
    /// and work budgets also exercise the legitimate empty result below the next grid endpoint.
    #[test]
    fn selected_prefix_is_a_bounded_grid_prefix_and_publishes_an_admitted_segment(
        chain in decided_chain(),
        room in room(),
        blob_bound in any::<bool>(),
        spare_blob in any::<bool>(),
        max_blocks in 1usize..=12,
        max_batch_blocks in prop_oneof![Just(u64::MAX), 1u64..=18],
        deflate_bytes in 0usize..=2 << 20,
    ) {
        let measure = codec::encode(&chain[..1], &unbounded()).expect("one block encodes").len();
        let bound = room.bound(measure);
        let limits = Limits {
            max_blocks,
            max_blobs: blob::required_blobs(bound) + usize::from(spare_blob),
            max_payload_bytes: if blob_bound { 2 * bound } else { bound },
            max_message_bytes: COMET_BLOCK_MAX_BYTES,
            max_decompressed_bytes: COMET_BLOCK_MAX_BYTES * max_blocks,
        };
        let admitted = measure <= capacity(&limits);
        // Independent sufficient condition: every candidate encoding up to one grid segment fits,
        // and even charging
        // every candidate's entire inflated list stays inside the deflate-work budget.
        let grid = abci::GRID_INTERVAL as usize;
        let cap = max_blocks.min(usize::try_from(max_batch_blocks).unwrap_or(usize::MAX));
        let mut segment_admitted = cap >= grid;
        let mut work = 0;
        for count in 1..=grid {
            match codec::encode(&chain[..count], &limits) {
                Ok(payload) if blob::required_blobs(payload.len()) <= limits.max_blobs => {
                    work += crate::compression::zlib_inflate_exact(&payload[1..], usize::MAX)?.len();
                }
                _ => segment_admitted = false,
            }
        }
        segment_admitted &= work <= deflate_bytes;
        let decided = chain.len();
        let builder = builder(chain.clone(), limits, max_batch_blocks, deflate_bytes);
        let runtime = tokio::runtime::Builder::new_current_thread().build()?;
        let snapshot = protocol::request().batch.snapshot;
        match runtime.block_on(builder.publishable_prefix(&snapshot, decided as u64)) {
            Ok(prefix) => {
                let selected = prefix.blocks.len();
                prop_assert!(selected <= cap.min(decided));
                prop_assert_eq!(selected % grid, 0);
                prop_assert!(!segment_admitted || selected >= grid);
                if selected == 0 { return Ok(()); }
                prop_assert_eq!(&prefix.blocks[..], &chain[..selected]);
                let (blocks, payload) = runtime.block_on(builder.payload(prefix))?;
                prop_assert!(payload.len() <= limits.max_payload_bytes);
                prop_assert!(blob::required_blobs(payload.len()) <= limits.max_blobs);
                let published: Vec<PublishedBlock> =
                    blocks.iter().map(|pair| PublishedBlock::try_from(pair).unwrap()).collect();
                prop_assert_eq!(codec::decode(&payload, &limits)?, published);
            }
            Err(LanderError::Capacity(reason)) => {
                prop_assert!(!admitted, "measure {} admitted, yet: {}", measure, reason);
            }
            Err(error) => return Err(TestCaseError::fail(format!("unexpected error: {error}"))),
        }
    }
}
