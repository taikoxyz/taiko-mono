//! Property test of complete-prefix selection ([`BatchBuilder::publishable_prefix`]) over decided
//! chains of blocks of random sizes and contents, under payload capacities around the first
//! block's landing guard measure and random deflate budgets.

use std::sync::Arc;

use abci::{
    AnchorState, AnchorWitness, ChainParams, CommitteeState, CommitteeWitness, RawL1Header,
};
use alloy_primitives::{Address, B256};
use async_trait::async_trait;
use proptest::{collection::vec, prelude::*};

use super::{BatchBuilder, BatchBuilderConfig, MAX_BATCH_LIST_BYTES};
use crate::{
    blob::{self, PAYLOAD_BYTES_PER_BLOB},
    codec::{self, PublishedBlock},
    comet::{CometSource, CometStatus},
    config::COMET_BLOCK_MAX_BYTES,
    contracts::IEtnaInbox::LandInput,
    error::{LanderError, Result},
    l1::{LandingSource, ParentContext},
    proptests::{
        guard_measure,
        strategies::{bytes, envelope_with, payload},
    },
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

    async fn committee(&self, _: u64) -> Result<CommitteeState> {
        Err(unread("committee hints"))
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

    async fn committee_witness(
        &self,
        _: &LandingSnapshot,
        _: &AnchorState,
        _: u64,
        _: u64,
    ) -> Result<CommitteeWitness> {
        Err(unread("L1"))
    }

    async fn reference(&self, _: &LandingSnapshot, _: &[AnchorState]) -> Result<Vec<RawL1Header>> {
        Err(unread("L1"))
    }

    async fn statement_hash(
        &self,
        _: &LandingSnapshot,
        _: &LandInput,
        _: B256,
        _: &[B256],
    ) -> Result<B256> {
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

/// One to four decided blocks from height 1, each carrying as its first transaction a payload of
/// up to 150 kB, 75 kB or 37.5 kB.
fn decided_chain() -> impl Strategy<Value = Vec<CertifiedBlock>> {
    let sized = prop_oneof![payload(150_000), payload(75_000), payload(37_500)];
    vec((envelope_with(vec(bytes(100), 1..=2)), sized), 1..=4).prop_map(|blocks| {
        let (_, committee, keys) = consensus::committee(&[1], 0);
        let mut chain: Vec<CertifiedBlock> = Vec::new();
        for (height, (mut envelope, payload)) in (1..).zip(blocks) {
            envelope.block.header.number = height;
            payload.fill(&mut envelope);
            chain.push(consensus::pair_with_envelope(envelope, &committee, &keys, chain.last()));
        }
        chain
    })
}

/// Where a payload bound sits against the first block's landing guard measure `g`.
#[derive(Clone, Copy, Debug)]
enum Room {
    /// `g - n` bytes: the guard would not admit the first block against it.
    Below(usize),
    /// `g + n` bytes, `n` at most 64: just room for the first block.
    At(usize),
    /// `g` times the factor: room for further blocks.
    Above(f64),
}

impl Room {
    /// The payload bound for a first block of guard measure `measure`.
    fn bound(self, measure: usize) -> usize {
        match self {
            Self::Below(n) => measure.saturating_sub(n).max(1),
            Self::At(n) => measure + n,
            Self::Above(factor) => (measure as f64 * factor) as usize,
        }
    }
}

/// A [`Room`]: below, at or (most often) above the first block's guard measure.
fn room() -> impl Strategy<Value = Room> {
    prop_oneof![
        1 => (1usize..=2_048).prop_map(Room::Below),
        1 => (0usize..=64).prop_map(Room::At),
        2 => (1.01..=3.0f64).prop_map(Room::Above),
    ]
}

/// A builder selecting from `chain` under `limits` and the deflate budget `deflate_bytes`.
fn builder(
    chain: Vec<CertifiedBlock>,
    limits: Limits,
    deflate_bytes: usize,
) -> BatchBuilder<Decided, Decided> {
    let decided = Arc::new(Decided(chain));
    let config = BatchBuilderConfig {
        params: ChainParams::builtin(167_001).expect("a built-in chain"),
        limits,
        mode: SidecarMode::Eip4844,
        fee_recipient: Address::repeat_byte(0xfe),
        engine: Arc::new(test_harness::unavailable_engine::UnavailableEngine),
        engine_timeout: std::time::Duration::from_secs(1),
    };
    BatchBuilder::new(decided.clone(), decided, config)
        .expect("valid limits")
        .with_selection_budgets(MAX_BATCH_LIST_BYTES, deflate_bytes)
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 32, ..ProptestConfig::default() })]

    /// Over a decided chain above the checkpoint, prefix selection returns a complete prefix of
    /// at most `max_blocks` blocks whose payload fits `max_payload_bytes` and `max_blobs` and
    /// decodes to exactly those blocks, and fails only on a first block the landing capacity
    /// guard would not admit against the limits' payload capacity: whenever the guard's measure
    /// of the first block is within it (as `MAX_BLOCK_LANDING_BYTES` is within the lander's six
    /// blobs), the selected prefix is not empty. Payload bounds sit below, at and above the first
    /// block's measure, with the blobs as many as they need or (at blob granularity) binding,
    /// under random deflate budgets.
    #[test]
    fn selected_prefix_fits_its_limits_and_is_never_empty_when_the_guard_admits_the_first_block(
        chain in decided_chain(),
        room in room(),
        blob_bound in any::<bool>(),
        spare_blob in any::<bool>(),
        max_blocks in 1usize..=6,
        deflate_bytes in 0usize..=2 << 20,
    ) {
        let measure = guard_measure(&chain[0].block.data[0]);
        let bound = room.bound(measure);
        let limits = Limits {
            max_blocks,
            max_blobs: blob::required_blobs(bound) + usize::from(spare_blob),
            max_payload_bytes: if blob_bound { 2 * bound } else { bound },
            max_message_bytes: COMET_BLOCK_MAX_BYTES,
            max_decompressed_bytes: COMET_BLOCK_MAX_BYTES * max_blocks,
        };
        let admitted = measure <= capacity(&limits);
        let decided = chain.len();
        let builder = builder(chain.clone(), limits, deflate_bytes);
        let runtime = tokio::runtime::Builder::new_current_thread().build()?;
        let snapshot = protocol::request().batch.snapshot;
        match runtime.block_on(builder.publishable_prefix(&snapshot, decided as u64)) {
            Ok(prefix) => {
                let selected = prefix.blocks.len();
                prop_assert!((1..=max_blocks.min(decided)).contains(&selected));
                prop_assert_eq!(&prefix.blocks[..], &chain[..selected]);
                let (blocks, payload) = runtime.block_on(builder.payload(prefix))?;
                prop_assert!(payload.len() <= limits.max_payload_bytes);
                prop_assert!(blob::required_blobs(payload.len()) <= limits.max_blobs);
                let published: Vec<PublishedBlock> =
                    blocks.iter().map(PublishedBlock::from).collect();
                prop_assert_eq!(codec::decode(&payload, &limits)?, published);
            }
            Err(LanderError::Capacity(reason)) => {
                prop_assert!(!admitted, "measure {} admitted, yet: {}", measure, reason);
            }
            Err(error) => return Err(TestCaseError::fail(format!("unexpected error: {error}"))),
        }
    }
}
