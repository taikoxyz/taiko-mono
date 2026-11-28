//! Consecutive, authenticated batch assembly and immutable proof-job construction.

use abci::engine::{
    Engine,
    forced::{ForcedBuildContext, ForcedBuildError, verify_forced},
};
use std::{collections::BTreeMap, sync::Arc, time::Duration};

use abci::{
    AccountWitness, AnchorState, ChainParams, ParentInfo, committee::SignerSource,
    fallback::FallbackKeys, rules, staking::StakingWords,
};
use alloy_primitives::{Address, B256, Bytes, U256, aliases::U48};
use async_trait::async_trait;
use prost::Message;
use tendermint_proto::v0_38::types::Commit as RawCommit;
use tokio::sync::Mutex;

use crate::{
    blob,
    codec::{self, PayloadList},
    comet::{CometSource, CometStatus},
    committee::Validators,
    config::COMET_BLOCK_MAX_BYTES,
    contracts::IEtnaInbox::LandInput,
    error::{LanderError, Result, engine_diagnostic},
    history,
    l1::{LandingSource, ParentContext},
    proof::ProofRequest,
    statement,
    store::MAX_JOURNAL_BYTES,
    types::{CertifiedBlock, HeightReads, LandingSnapshot, Limits, PreparedBatch, SidecarMode},
    validate::{EnvelopeContext, verify_commit, verify_envelope},
};

/// Uncompressed published execution DA bytes prefix selection admits into one batch.
///
/// Bounds public DA independently from retained private protobuf witnesses. PayloadList also
/// reserves at most one quarter of the journal limit for complete block/commit protobufs;
/// base64 expansion and additional proving contexts remain subject to the final journal bound.
pub const MAX_BATCH_LIST_BYTES: usize = codec::MAX_DECOMPRESSED_BYTES;

/// Uncompressed bytes prefix selection may deflate while sizing longer prefixes in one call.
///
/// Sizing the first block is never refused. A longer prefix whose sizing would pass this budget is
/// left for a later batch, so the work of one poll stays bounded.
pub const MAX_SELECTION_DEFLATE_BYTES: usize = 32 * 1024 * 1024;

const _: () = assert!(MAX_BATCH_LIST_BYTES / 3 * 4 <= MAX_JOURNAL_BYTES as usize / 2);
const _: () = assert!(COMET_BLOCK_MAX_BYTES <= MAX_BATCH_LIST_BYTES / 2);

/// Journal bytes left for what a job journals besides its proof request: the signed
/// transaction, whose sidecar repeats the request's blobs and whose calldata carries the proof and
/// the cut leaves, the proof itself, and the journal's envelope.
const JOURNAL_RESERVE_BYTES: u64 = 16 * 1024 * 1024;

/// The most bytes a proof request may journal as. Preparation refuses, before any proof, a
/// request that would journal more, so a prepared job always journals.
pub(crate) const MAX_REQUEST_BYTES: u64 = MAX_JOURNAL_BYTES - JOURNAL_RESERVE_BYTES;

/// The bytes prefix selection leaves for the parts of a proof request that do not grow with its
/// heights: the snapshot, the starting and anchor witnesses, header(p), the sets and staking proof
/// of p, the origin list, the reference chain and the blobs.
const REQUEST_FIXED_BYTES: u64 = 48 * 1024 * 1024;

/// The most bytes one height adds to a journaled proof request besides its block and commit
/// protobufs: its staking reads (258 snapshot words and up to 128 seat words), a 128-key fallback
/// key list, its anchor, cut leaf and commit height, and its block's JSON framing.
pub(crate) const MAX_HEIGHT_REQUEST_BYTES: u64 = 48 * 1024;

/// The bytes prefix selection lets a batch's heights journal as in its proof request: each
/// height's base64 block and commit protobufs and [`MAX_HEIGHT_REQUEST_BYTES`].
const HEIGHTS_REQUEST_BYTES: u64 = MAX_REQUEST_BYTES - REQUEST_FIXED_BYTES;

/// The most heights a batch may hold so that its heights journal within
/// [`HEIGHTS_REQUEST_BYTES`] whatever they hold, with their block and commit protobufs at the
/// whole private budget selection admits ([`codec::MAX_PRIVATE_BYTES`]). [`batch_cap`] refuses a
/// larger cap.
pub const MAX_REQUEST_HEIGHTS: u64 = (HEIGHTS_REQUEST_BYTES -
    journaled_bytes(codec::MAX_PRIVATE_BYTES as u64)) /
    MAX_HEIGHT_REQUEST_BYTES;

const _: () = assert!(MAX_REQUEST_HEIGHTS >= 1_000);

/// The length of the padded base64 of `bytes` bytes, the journal encoding of a protobuf.
const fn journaled_bytes(bytes: u64) -> u64 {
    bytes.div_ceil(3) * 4
}

/// The most bytes the height of `pair` adds to a journaled proof request: its base64 block and
/// commit protobufs and [`MAX_HEIGHT_REQUEST_BYTES`].
fn height_request_bytes(pair: &CertifiedBlock) -> u64 {
    let commit = RawCommit::from(pair.commit.clone()).encoded_len() as u64;
    journaled_bytes(pair.raw_block.len() as u64) +
        journaled_bytes(commit) +
        MAX_HEIGHT_REQUEST_BYTES
}

/// Decided backlog and complete-prefix facts used by the runner's publication policy.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BatchObservation {
    /// Highest certified CometBFT height reported by the configured chain.
    pub decided_height: u64,
    /// Complete blocks fitting the configured block, codec, payload and blob bounds and the
    /// selection budgets.
    pub publishable_blocks: usize,
    /// The decided tip's authenticated anchor puts its unsettled depth at `U - 1` or more.
    pub force_back_pressure: bool,
}

/// One observation and its optional, owned selection work, consumed by preparation.
/// A preview never authenticates its blocks and is not retained between runner steps.
#[derive(Debug)]
pub struct BatchPreview {
    /// Copyable publication-policy facts, independent of the retained selection.
    pub observation: BatchObservation,
    /// Private selection bound to the snapshot, tip and producing capacity budgets.
    selected: Option<ObservedPrefix>,
}

impl BatchPreview {
    /// Wrap facts from a source that prepares independently, without retained selection work.
    pub fn from_observation(observation: BatchObservation) -> Self {
        Self { observation, selected: None }
    }
}

/// Selection work that is reusable only under its original snapshot, tip and capacity limits.
#[derive(Debug)]
struct ObservedPrefix {
    /// Complete coherent inputs used to select the prefix.
    snapshot: LandingSnapshot,
    /// Fresh decided height required before consuming this selection.
    decided_height: u64,
    /// Producing public/private codec bounds, including the list budget.
    limits: Limits,
    /// Producing deployment block cap.
    max_batch_blocks: u64,
    /// Producing per-selection deflate work budget.
    deflate_budget: usize,
    /// Already checked and encoded complete prefix, still awaiting full authentication.
    prefix: PublishablePrefix,
}

/// Canonical complete-block prefix shared by readiness preview and authenticated preparation.
#[derive(Debug)]
struct PublishablePrefix {
    /// Exact complete pairs selected without computing signatures, witnesses or KZG proofs.
    blocks: Vec<CertifiedBlock>,
    /// The selected blocks' RLP list.
    list: PayloadList,
    /// The selected blocks' V6 payload, when sizing already compressed it; otherwise its
    /// worst-case size fits and [`BatchBuilder::payload`] compresses it once.
    payload: Option<Vec<u8>>,
}

/// Fully authenticated starting checkpoint p and the sets that sign p and p + 1.
struct BatchStart {
    /// Parent header and ancestry-derived base-fee timestamp.
    parent: ParentContext,
    /// The checkpoint's anchor: above the generation's start, the one `anchor_witness` proves
    /// under the root the checkpoint's EL header names; at the start, the origin anchor.
    anchor: AnchorState,
    /// The checkpoint's anchor witness, from the block that carried it, above the generation's
    /// start; absent at the start, whose anchor words no rule reads.
    anchor_witness: Option<abci::AnchorWitness>,
    /// Certified checkpoint block, absent at the fixed generation origin.
    previous: Option<CertifiedBlock>,
    /// The set that signs p, which p + 1's LastCommit lists: above the generation's start o, the
    /// set header(p)'s `validators_hash` commits; absent at o, whose successor has no LastCommit.
    parent_signers: Option<Validators>,
    /// The set that signs p + 1: the origin list while p + 1 is at most o + 2, otherwise the set
    /// header(p)'s `next_validators_hash` commits.
    signers: Validators,
    /// The fallback key list whose hash the generation's origin record holds.
    origin_keys: FallbackKeys,
    /// Its keys, each at power 1: the set that signs o + 1 and o + 2.
    origin: Validators,
}

/// Immutable checkpoint identity; advancing the operational L1 head does not change it.
#[derive(Clone, PartialEq, Eq)]
struct CheckpointIdentity {
    /// L1 chain whose canonical roots authenticate the stored proofs.
    l1_chain_id: U256,
    /// L2 chain whose execution history and certificates are authenticated.
    l2_chain_id: u64,
    /// Inbox proxy authenticating the checkpoint and deployment commitments.
    inbox: Address,
    /// Recovery generation carried by the execution history and BFT chain id.
    generation: u64,
    /// Fixed origin facts verified independently of current checkpoint progress.
    recovery: Option<abci::recovery::RecoveryOrigin>,
    /// Exact settled execution height.
    height: u64,
    /// Exact settled execution hash binding every ancestry header.
    hash: B256,
    /// Certified BFT checkpoint hash binding the private parent certificate.
    comet_hash: B256,
    /// Complete genesis configuration, including forced inclusion and anchor age rules.
    genesis: abci::GenesisRecord,
    /// The deployment's authenticated configuration hash.
    config_hash: B256,
}

impl CheckpointIdentity {
    /// Bind every snapshot input used to authenticate an immutable starting context.
    fn from_snapshot(snapshot: &LandingSnapshot) -> Self {
        Self {
            l1_chain_id: snapshot.l1_chain_id,
            l2_chain_id: snapshot.l2_chain_id,
            inbox: snapshot.inbox,
            generation: snapshot.generation,
            recovery: snapshot.recovery.clone(),
            height: snapshot.checkpoint_height,
            hash: snapshot.checkpoint_hash,
            comet_hash: snapshot.checkpoint_comet_hash,
            genesis: snapshot.genesis.clone(),
            config_hash: snapshot.config_hash,
        }
    }
}

/// One fully verified starting context; forward descendants are never retained.
struct CachedCheckpoint {
    /// Checkpoint and complete configuration for which the proofs were verified.
    identity: CheckpointIdentity,
    /// Shared ancestry, proofs and signing set, copied only when retained in a new immutable
    /// proof job.
    start: Arc<BatchStart>,
}

/// A decided tip an observation resolved, and the authenticated anchor it consumes.
#[derive(Clone)]
struct TipAnchor {
    /// The tip's height.
    height: u64,
    /// The tip's CometBFT block hash, pinning the chain the anchor was found on.
    comet_hash: B256,
    /// The anchor the tip consumes.
    anchor: AnchorState,
}

/// Constant-space forward authentication state of proof preparation, after the parent x.
///
/// The set that signs x + 2 is not held here: it is decided at x while x + 1 is authenticated
/// ([`BatchBuilder::decide_at_parent`]), because the one staking read of x's post-state also
/// proves the seats of the validators x + 1's LastCommit misses.
struct ForwardState {
    /// Exact authenticated committed parent inputs.
    parent: ParentInfo,
    /// The parent's EL state root, under which its staking words are proven.
    parent_state_root: B256,
    /// The set that signs the parent x, which x + 1's LastCommit lists; absent at the
    /// generation's start o.
    parent_signers: Option<Validators>,
    /// The set that signs x + 1.
    signers: Validators,
    /// The origin list's set, which signs o + 2 whatever o's state holds.
    origin: Validators,
    /// Current authenticated L1 anchor: the parent's.
    anchor: AnchorState,
    /// Previous certified block used to check last_commit and BFT parent links.
    previous: Option<CertifiedBlock>,
    /// Forced inclusion cursor after `parent`: the queue entries the chain has consumed.
    forced_cursor: u64,
}

impl ForwardState {
    /// Initialize from a contract-bound checkpoint after its history and certificate verify.
    ///
    /// The cursor starts at the snapshot's Inbox head: every landing leaves the head at the
    /// cursor of the checkpoint it lands.
    fn new(start: &BatchStart, snapshot: &LandingSnapshot) -> Result<Self> {
        Ok(Self {
            parent: parent_info(&start.parent)?,
            parent_state_root: start.parent.header.state_root,
            parent_signers: start.parent_signers.clone(),
            signers: start.signers.clone(),
            origin: start.origin.clone(),
            anchor: start.anchor.clone(),
            previous: start.previous.clone(),
            forced_cursor: snapshot.forced_inclusion_head,
        })
    }
}

/// What authenticating a batch's blocks establishes for its proof request.
struct AuthenticatedBlocks {
    /// Each block's own anchor, in block order.
    anchors: Vec<AnchorState>,
    /// One cut leaf for every height strictly inside (p, h).
    leaves: Vec<B256>,
    /// The heights whose commits a proof verifies, ascending: every x in (p, h) whose successor
    /// is signed by another set, as (key, power) multisets, and h.
    commit_heights: Vec<u64>,
    /// p's staking proof, verified under p's EL state root; absent at the generation's start.
    staking_at_p: Option<AccountWitness>,
    /// The verified staking words of every height in (p, h − 1].
    staking_reads: Vec<HeightReads>,
    /// The fallback key lists the decisions fell back to, by hash.
    fallback_key_lists: BTreeMap<B256, FallbackKeys>,
    /// The forward state after the terminal block h.
    end: ForwardState,
}

/// What the decision at a parent x above the generation's start read, retained for the proof
/// request.
#[derive(Debug)]
struct ParentReads {
    /// x's staking proof, verified under x's EL state root.
    witness: AccountWitness,
    /// The candidate snapshot it proves.
    words: StakingWords,
    /// The key-to-seat word of each validator x + 1's LastCommit lacks, in CometBFT order.
    seat_words: Vec<(Address, U256)>,
    /// The fallback key list the decision fell back to; `None` when the candidate signs.
    fallback: Option<FallbackKeys>,
}

/// Boundary used by the runner to prepare jobs and authenticate competing checkpoint progress.
#[async_trait]
pub trait BatchSource: Send + Sync {
    /// Preview complete-prefix capacity and authenticated urgency without building a proof job.
    async fn observe(&self, snapshot: &LandingSnapshot) -> Result<BatchPreview>;
    /// Build the largest complete publishable prefix above this coherent checkpoint, or the
    /// batch ending exactly at [`BatchSource::land_to`].
    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>>;
    /// Consume same-iteration observation work when supported; other sources prepare afresh.
    async fn prepare_observed(
        &self,
        snapshot: LandingSnapshot,
        preview: BatchPreview,
    ) -> Result<Option<ProofRequest>> {
        drop(preview);
        self.prepare(snapshot).await
    }
    /// Ensure the current L1 checkpoint identifies this node's certified execution chain.
    async fn validate_checkpoint(&self, snapshot: &LandingSnapshot) -> Result<()>;
    /// The height every batch ends at exactly (`lander --land-to`), if this source selects one;
    /// otherwise batches end at the decided tip within the batch cap.
    fn land_to(&self) -> Option<u64> {
        None
    }
}

/// Validated runtime dependencies and limits for authenticated batch construction.
pub struct BatchBuilderConfig {
    /// Shared consensus parameters.
    pub params: ChainParams,
    /// Complete-block and codec capacity limits.
    pub limits: Limits,
    /// L1 sidecar representation.
    pub mode: SidecarMode,
    /// Operator-controlled EL used to establish canonical forced-transaction skips.
    /// Leave allow-unwind-canonical-header disabled for historical canonical probes.
    pub engine: Arc<dyn Engine>,
    /// Positive, bounded deadline for a singleton check.
    pub engine_timeout: Duration,
    /// The executing Inbox's `maxBatchBlocks` ([`crate::l1::Deployment::max_batch_blocks`]), read
    /// at startup; batch selection never exceeds it nor `limits.max_blocks` ([`batch_cap`]).
    pub max_batch_blocks: u64,
}

/// The most blocks one batch selects: the configured `max_blocks` or the Inbox's
/// `max_batch_blocks`, whichever is lower. A landing may end at any height (LAND-6.1-5), so any
/// cap of at least one block can land; a zero cap is a configuration error, which the lander
/// checks before it starts. So is a cap above [`MAX_REQUEST_HEIGHTS`], whose batches could need
/// a proof request larger than the journal holds.
pub fn batch_cap(max_blocks: usize, max_batch_blocks: u64) -> Result<usize> {
    let deployed = usize::try_from(max_batch_blocks).unwrap_or(usize::MAX);
    let cap = max_blocks.min(deployed);
    if cap == 0 {
        return Err(LanderError::Configuration(format!(
            "batches of at most {max_blocks} configured and {max_batch_blocks} deployed \
             (maxBatchBlocks) blocks cannot hold one block"
        )));
    }
    if cap as u64 > MAX_REQUEST_HEIGHTS {
        return Err(LanderError::Configuration(format!(
            "batches of up to {cap} blocks, the lower of --max-blocks {max_blocks} and the Inbox \
             maxBatchBlocks {max_batch_blocks}, can need a proof request beyond the journal \
             bound; set --max-blocks to at most {MAX_REQUEST_HEIGHTS}"
        )));
    }
    Ok(cap)
}

/// Refuses a `min_blocks` collection threshold ([`crate::config::BatchPolicy::min_blocks`])
/// above `cap` ([`batch_cap`]). No batch selects more than `cap` blocks, so such a threshold is
/// never met and every landing would wait the full collection wait instead. The lander checks
/// this at startup, once the Inbox's `maxBatchBlocks` is known; the configuration alone only
/// bounds the threshold by `max_blocks`.
pub fn check_min_blocks(min_blocks: usize, cap: usize) -> Result<()> {
    if min_blocks > cap {
        return Err(LanderError::Configuration(format!(
            "minimum batch blocks {min_blocks} exceed the {cap}-block batch cap, the lower of \
             the configured maximum and the Inbox maxBatchBlocks: no batch reaches it, so every \
             landing would wait the full batch wait"
        )));
    }
    Ok(())
}

/// Collector-backed builder; no proof computation or transaction mutation occurs here.
pub struct BatchBuilder<C: ?Sized, L: ?Sized> {
    /// Read-only CometBFT block/certificate source.
    comet: Arc<C>,
    /// Coherent L1 reads and public L2 checkpoint headers.
    l1: Arc<L>,
    /// EL dependency for completed forced decisions.
    engine: Arc<dyn Engine>,
    /// Deadline bounding the entire forced check.
    engine_timeout: Duration,
    /// Shared Etna constants; the existing ABCI helpers enforce them.
    params: ChainParams,
    /// Explicit codec, complete-block and transaction blob bounds.
    limits: Limits,
    /// The Inbox's `maxBatchBlocks`, read at startup: no batch selects more blocks.
    max_batch_blocks: u64,
    /// Operator-selected target L1 sidecar representation.
    mode: SidecarMode,
    /// Uncompressed list bytes one batch may select ([`MAX_BATCH_LIST_BYTES`]).
    list_budget: usize,
    /// Bytes one prefix selection may deflate ([`MAX_SELECTION_DEFLATE_BYTES`]).
    deflate_budget: usize,
    /// Bytes the selected heights may journal as in the proof request
    /// ([`HEIGHTS_REQUEST_BYTES`], counted by [`height_request_bytes`]).
    heights_budget: u64,
    /// Bytes the whole proof request may journal as ([`MAX_REQUEST_BYTES`]).
    request_budget: u64,
    /// Retain at most one authenticated starting context and serialize concurrent misses.
    checkpoint_cache: Mutex<Option<CachedCheckpoint>>,
    /// The last tip whose anchor [`BatchBuilder::tip_anchor`] authenticated, so a later
    /// observation reads only the blocks decided since.
    tip_anchor: Mutex<Option<TipAnchor>>,
    /// The fallback key lists obtained from the L1, by their hash, so each is read once.
    fallback_lists: Mutex<BTreeMap<B256, FallbackKeys>>,
    /// The exact end of every batch ([`BatchBuilder::with_land_to`]).
    land_to: Option<u64>,
}

impl<C: CometSource + ?Sized, L: LandingSource + ?Sized> BatchBuilder<C, L> {
    /// Create a builder after validating operator and consensus limits. Execution beneficiaries
    /// remain authenticated header fields; the V1 landing input contains no payout recipient.
    pub fn new(comet: Arc<C>, l1: Arc<L>, config: BatchBuilderConfig) -> Result<Self> {
        let BatchBuilderConfig { params, limits, mode, engine, engine_timeout, max_batch_blocks } =
            config;
        if engine_timeout.is_zero() ||
            engine_timeout > Duration::from_secs(crate::config::MAX_TIMEOUT_SECS)
        {
            return Err(LanderError::Configuration(
                "engine timeout must be positive and at most one hour".into(),
            ));
        }
        params.validate().map_err(|e| LanderError::Configuration(e.to_string()))?;
        limits.validate()?;
        Ok(Self {
            comet,
            l1,
            engine,
            engine_timeout,
            params,
            limits,
            max_batch_blocks,
            mode,
            list_budget: MAX_BATCH_LIST_BYTES,
            deflate_budget: MAX_SELECTION_DEFLATE_BYTES,
            heights_budget: HEIGHTS_REQUEST_BYTES,
            request_budget: MAX_REQUEST_BYTES,
            checkpoint_cache: Mutex::new(None),
            tip_anchor: Mutex::new(None),
            fallback_lists: Mutex::new(BTreeMap::new()),
            land_to: None,
        })
    }

    /// Ends every batch exactly at `height` (`lander --land-to`), through the same selection,
    /// authentication and leaves as any other batch. Selection then waits while the decided tip
    /// is below `height` and refuses, as a configuration error, a `height` at or below the latest
    /// checkpoint p or more than the batch cap ([`batch_cap`]) above it, because one batch carries
    /// all of (p, `height`]. `None` keeps the normal selection.
    pub fn with_land_to(mut self, height: Option<u64>) -> Self {
        self.land_to = height;
        self
    }

    /// Replaces the selection budgets, so tests reach them with small blocks.
    #[cfg(test)]
    pub(crate) fn with_selection_budgets(
        mut self,
        list_bytes: usize,
        deflate_bytes: usize,
    ) -> Self {
        self.list_budget = list_bytes;
        self.deflate_budget = deflate_bytes;
        self
    }

    /// Replaces the journal budgets of the selected heights and of the whole proof request, so
    /// tests reach them with small batches.
    #[cfg(test)]
    pub(crate) fn with_request_budgets(mut self, heights_bytes: u64, request_bytes: u64) -> Self {
        self.heights_budget = heights_bytes;
        self.request_budget = request_bytes;
        self
    }

    /// Ensure one coherent Inbox context matches the configured chain and genesis record.
    fn check_snapshot(&self, snapshot: &LandingSnapshot) -> Result<()> {
        crate::l1::authenticate_snapshot(snapshot, &self.params)?;
        if snapshot.l2_chain_id != self.params.l2_chain_id ||
            snapshot.inbox != self.params.inbox ||
            snapshot.genesis.genesis_hash.is_zero() ||
            snapshot.genesis.genesis_state_root.is_zero() ||
            snapshot.config_hash != self.params.config_hash() ||
            snapshot.checkpoint_hash.is_zero()
        {
            return Err(LanderError::Configuration(
                "landing snapshot identity/genesis contradicts chain parameters".into(),
            ));
        }
        Ok(())
    }

    /// The exact end ([`BatchBuilder::with_land_to`]) of a batch above the latest checkpoint
    /// `checkpoint`, refused when it is not above it or lies beyond the batch cap.
    fn exact_end(&self, checkpoint: u64) -> Result<Option<u64>> {
        let Some(end) = self.land_to else {
            return Ok(None);
        };
        if checkpoint >= end {
            return Err(LanderError::Configuration(format!(
                "the latest checkpoint {checkpoint} is already at or above --land-to {end}, so \
                 no landing can end there"
            )));
        }
        let cap = batch_cap(self.limits.max_blocks, self.max_batch_blocks)?;
        if end - checkpoint > cap as u64 {
            return Err(LanderError::Configuration(format!(
                "--land-to {end} is {} blocks above the latest checkpoint {checkpoint}, beyond \
                 the {cap}-block batch cap, the lower of --max-blocks and the Inbox \
                 maxBatchBlocks",
                end - checkpoint
            )));
        }
        Ok(Some(end))
    }

    /// Read a decided tip from the configured generation and reject a lagging endpoint.
    async fn status(&self, snapshot: &LandingSnapshot) -> Result<CometStatus> {
        let status = self.comet.status().await?;
        crate::metrics::LanderMetrics::progress(snapshot.checkpoint_height, status.height);
        if status.chain_id !=
            rules::chain_id_for(&self.params, snapshot.generation)
                .map_err(|e| LanderError::Configuration(e.to_string()))?
        {
            return Err(LanderError::Safety("Comet endpoint chain/generation mismatch".into()));
        }
        if status.height < snapshot.checkpoint_height {
            return Err(LanderError::Unavailable(format!(
                "Comet decided tip {} is below checkpoint {}",
                status.height, snapshot.checkpoint_height
            )));
        }
        if status.height - snapshot.checkpoint_height > self.params.unsettled_limit {
            return Err(LanderError::Temporary(
                "Comet tip exceeds this operational checkpoint's unsettled-block limit; refresh coherent Inbox snapshot".into(),
            ));
        }
        Ok(status)
    }

    /// Select exact complete-block boundaries using canonical codec, blob and journal capacity
    /// checks: the selected heights may journal as at most the heights budget in the proof
    /// request, each counted at the most it can add ([`height_request_bytes`]).
    ///
    /// An oversized first block is a capacity error; a later oversized block ends the prefix.
    /// With an exact end, which the caller has checked and seen decided, the prefix runs to it,
    /// and a prefix that ends earlier is a capacity error instead.
    /// This shared preview performs no signature/MPT validation, reference reads or KZG work.
    /// Each block is validated and encoded once. A prefix whose worst-case compressed size fits
    /// is accepted without deflating it; otherwise it is deflated off the async workers, within
    /// the deflate budget. DA and private block/commit budgets are independent.
    async fn publishable_prefix(
        &self,
        snapshot: &LandingSnapshot,
        decided_height: u64,
    ) -> Result<PublishablePrefix> {
        let limits = self.selection_limits();
        let capacity = limits
            .max_payload_bytes
            .min(limits.max_blobs.saturating_mul(blob::PAYLOAD_BYTES_PER_BLOB));
        let mut list = PayloadList::new(&limits)?;
        let mut blocks = Vec::new();
        let mut payload = None;
        let mut deflated = 0usize;
        let mut journaled = 0u64;
        let most = self.max_batch_blocks.min(self.limits.max_blocks as u64);
        let mut stop = decided_height.min(snapshot.checkpoint_height.saturating_add(most));
        if let Some(end) = self.land_to {
            stop = stop.min(end);
        }
        for height in snapshot.checkpoint_height + 1..=stop {
            let pair = self.comet.block(height).await?;
            if pair.block.header.height.value() != height {
                return Err(LanderError::Safety(format!(
                    "Comet response at requested height {height} identifies {}",
                    pair.block.header.height
                )));
            }
            let height_bytes = height_request_bytes(&pair);
            if journaled + height_bytes > self.heights_budget {
                if blocks.is_empty() {
                    return Err(LanderError::Capacity(format!(
                        "block {height} can add {height_bytes} bytes to the proof request, beyond \
                         the {} journal bytes a batch's heights may take",
                        self.heights_budget
                    )));
                }
                break;
            }
            journaled += height_bytes;
            match list.push(&pair) {
                Ok(()) => {}
                Err(LanderError::Capacity(_)) if !blocks.is_empty() => break,
                Err(LanderError::Capacity(reason)) => {
                    return Err(LanderError::Capacity(format!("block {height}: {reason}")))
                }
                Err(error) => return Err(error),
            }
            let list_len = list.list_len();
            if codec::payload_bound(list_len) <= capacity {
                blocks.push(pair);
                payload = None;
                continue;
            }
            if !blocks.is_empty() && deflated.saturating_add(list_len) > self.deflate_budget {
                list.pop();
                break;
            }
            deflated = deflated.saturating_add(list_len);
            match compress(list.to_list(), limits).await {
                Ok(encoded) if blob::required_blobs(encoded.len()) <= limits.max_blobs => {
                    blocks.push(pair);
                    payload = Some(encoded);
                }
                Ok(_) | Err(LanderError::Capacity(_)) if !blocks.is_empty() => {
                    list.pop();
                    break;
                }
                Ok(encoded) => {
                    return Err(LanderError::Capacity(format!(
                        "block {height} needs {} blobs, configured {}",
                        blob::required_blobs(encoded.len()),
                        limits.max_blobs
                    )));
                }
                Err(LanderError::Capacity(reason)) => {
                    return Err(LanderError::Capacity(format!("block {height}: {reason}")))
                }
                Err(error) => return Err(error),
            }
        }
        let last = snapshot.checkpoint_height + blocks.len() as u64;
        if let Some(end) = self.land_to &&
            last != end
        {
            return Err(LanderError::Capacity(format!(
                "blocks {}..={end} do not fit one batch, whose payload, blob, journal and \
                 selection limits end it at {last}, so --land-to {end} cannot land",
                snapshot.checkpoint_height + 1
            )));
        }
        Ok(PublishablePrefix { blocks, list, payload })
    }

    /// The configured limits with the list budget applied to the decompressed bound.
    fn selection_limits(&self) -> Limits {
        Limits {
            max_decompressed_bytes: self.limits.max_decompressed_bytes.min(self.list_budget),
            ..self.limits
        }
    }

    /// The selected prefix's V6 payload, compressing its list unless sizing already did.
    async fn payload(&self, prefix: PublishablePrefix) -> Result<(Vec<CertifiedBlock>, Vec<u8>)> {
        let payload = match prefix.payload {
            Some(payload) => payload,
            None => compress(prefix.list.to_list(), self.selection_limits()).await?,
        };
        Ok((prefix.blocks, payload))
    }

    /// The fallback key list whose hash the generation's origin record holds, and the set that
    /// signs the generation's first two blocks o + 1 and o + 2 whatever o's state holds: its keys,
    /// each at power 1. The record is the one the snapshot authenticates
    /// ([`crate::l1::snapshot_origin`]). The batch's starting proof proves the same record under
    /// its reference header ([`BatchBuilder::starting_inbox`]). The list is obtained by its hash
    /// ([`BatchBuilder::fallback_list`]) at R for a recovery generation, and at the checkpoint's
    /// anchor `anchor`, a block at or after `L1_0`, at generation zero.
    async fn origin_set(
        &self,
        snapshot: &LandingSnapshot,
        anchor: &AnchorState,
    ) -> Result<(FallbackKeys, Validators)> {
        let origin_hash = crate::l1::snapshot_origin(snapshot)?.fallback_keys_hash;
        let (at, at_number) = match &snapshot.recovery {
            Some(_) => {
                let r = recovery_anchor(snapshot)?;
                (r.hash, r.number)
            }
            None => (anchor.hash, anchor.number),
        };
        let keys = self.fallback_list(origin_hash, at, at_number).await?;
        let set = Validators::from_powers(&keys.validator_set())
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        Ok((keys, set))
    }

    /// The fallback key list whose hash is `hash`, from the cache of lists already obtained or
    /// from the L1 at the block with hash `at` and number `at_number`
    /// ([`crate::l1::obtain_fallback_list`]).
    async fn fallback_list(&self, hash: B256, at: B256, at_number: u64) -> Result<FallbackKeys> {
        if let Some(keys) = self.fallback_lists.lock().await.get(&hash) {
            return Ok(keys.clone());
        }
        let keys = crate::l1::obtain_fallback_list(self.l1.as_ref(), hash, at, at_number).await?;
        self.fallback_lists.lock().await.insert(hash, keys.clone());
        Ok(keys)
    }

    /// The batch's starting Inbox proof under its reference header `reference`
    /// ([`crate::l1::verify_starting_inbox`]): the genesis record and the generation's origin
    /// record it proves must be the ones the snapshot authenticates, or the batch stops as
    /// `Safety`.
    async fn starting_inbox(
        &self,
        snapshot: &LandingSnapshot,
        reference: &abci::RawL1Header,
    ) -> Result<abci::AnchorWitness> {
        let witness = self.l1.starting_inbox_witness(reference, snapshot.generation).await?;
        let (genesis, origin) = crate::l1::verify_starting_inbox(
            &witness,
            reference,
            snapshot.generation,
            self.params.inbox,
        )?;
        if genesis != snapshot.genesis ||
            genesis.config_hash != snapshot.config_hash ||
            origin != crate::l1::snapshot_origin(snapshot)?
        {
            return Err(LanderError::Safety(
                "starting Inbox proof under the reference header contradicts the snapshot".into(),
            ));
        }
        Ok(witness)
    }

    /// Reuse only a fully authenticated checkpoint whose source parent and proving root remain
    /// current. A failed refresh removes the entry.
    async fn checkpoint(&self, snapshot: &LandingSnapshot) -> Result<Arc<BatchStart>> {
        if snapshot.checkpoint_height < snapshot.origin_height() {
            return Err(LanderError::Safety("checkpoint predates generation origin".into()));
        }
        let identity = CheckpointIdentity::from_snapshot(snapshot);
        if snapshot.recovery.is_some() {
            self.check_proving_anchor_canonicality(&recovery_anchor(snapshot)?).await?;
        }
        let mut retained = self.checkpoint_cache.lock().await;
        let cached = retained.take();
        let parent = self.l1.parent_header(snapshot).await?;
        history::check_header_capacity(&parent.header)?;
        if parent.header.number != snapshot.checkpoint_height ||
            parent.header.hash_slow() != snapshot.checkpoint_hash
        {
            return Err(LanderError::Safety(format!(
                "EL parent disagrees with checkpoint {}",
                snapshot.checkpoint_height
            )));
        }
        if let Some(cached) = cached.filter(|cached| cached.identity == identity) {
            if cached.start.parent != parent {
                return Err(LanderError::Safety("cached checkpoint parent changed".into()));
            }
            if self.l1.canonical_hash(snapshot.l1_block_number).await? != snapshot.l1_block_hash {
                return Err(LanderError::Stale(
                    "coherent Inbox snapshot is no longer canonical".into(),
                ));
            }
            self.check_proving_anchor_canonicality(&cached.start.anchor).await?;
            let start = cached.start.clone();
            *retained = Some(cached);
            return Ok(start);
        }
        let start = Arc::new(self.reconstruct_checkpoint(snapshot, parent).await?);
        *retained = Some(CachedCheckpoint { identity, start: start.clone() });
        Ok(start)
    }

    /// Reject a moved historical proving root after either acquiring or reusing its proofs.
    async fn check_proving_anchor_canonicality(&self, anchor: &AnchorState) -> Result<()> {
        if self.l1.canonical_hash(anchor.number).await? != anchor.hash {
            return Err(LanderError::Safety(
                "checkpoint proving anchor is no longer canonical".into(),
            ));
        }
        Ok(())
    }

    /// Hash-check the checkpoint's EL parent link, its anchor, the sets that sign p and p + 1 and
    /// the checkpoint BFT certificate.
    ///
    /// Above the generation's start, the checkpoint p's anchor comes from the anchor witness of
    /// the block that carried it ([`BatchBuilder::checkpoint_anchor_witness`]), checked against
    /// p's EL header ([`crate::l1::verify_checkpoint_anchor`]). That header, not L1 ancestry,
    /// authenticates it: p's anchor joins the reference chain only when p + 1 inherits it, as
    /// p + 1's own anchor, whose block rules check p + 1's `extraData` and
    /// `parentBeaconBlockRoot` against it. At the start the origin anchor only precedes the
    /// generation's first block, which carries its own.
    ///
    /// At the start o the origin list signs o + 1 and no set signs o, as o + 1 has no LastCommit.
    /// Above it, the set that signs p is the Comet node's `/validators` answer at p, accepted
    /// only when it hashes to header(p)'s `validators_hash`, and p's commit must verify against
    /// it; the set that signs p + 1 is the origin list while p + 1 is at most o + 2, otherwise
    /// the answer at p + 1, accepted only when it hashes to header(p)'s `next_validators_hash`
    /// ([`BatchBuilder::archived_set`]). header(p) is the checkpoint's own Comet header, whose
    /// hash the snapshot's landing record holds.
    async fn reconstruct_checkpoint(
        &self,
        snapshot: &LandingSnapshot,
        mut parent: ParentContext,
    ) -> Result<BatchStart> {
        // The parent's own parent supplies the base-fee grandparent timestamp.
        parent.grandparent_timestamp = match snapshot.checkpoint_height.checked_sub(1) {
            Some(below) => {
                let header = self.l1.execution_header(below).await?;
                history::check_header_capacity(&header)?;
                if header.number != below || parent.header.parent_hash != header.hash_slow() {
                    return Err(LanderError::Safety(
                        "execution history hash/height links are discontinuous".into(),
                    ));
                }
                header.timestamp
            }
            None => 0,
        };
        if snapshot.recovery.as_ref().is_some_and(|origin| {
            parent.header.number == origin.height && parent.header.hash_slow() != origin.el_hash
        }) {
            return Err(LanderError::Safety("execution history contradicts recovery origin".into()));
        }
        if parent.header.number == snapshot.origin_height() {
            let (hash, root) = snapshot.recovery.as_ref().map_or(
                (snapshot.genesis.genesis_hash, snapshot.genesis.genesis_state_root),
                |r| (r.el_hash, r.state_root),
            );
            if snapshot.checkpoint_hash != hash || parent.header.state_root != root {
                return Err(LanderError::Safety(
                    "genesis checkpoint hash/state root mismatch".into(),
                ));
            }
            let anchor = self.l1.origin_anchor(snapshot).await?;
            let origin_number =
                snapshot.recovery.as_ref().map_or(snapshot.genesis.l1_0, |r| r.l1_number);
            if anchor.number != origin_number ||
                anchor.inbox.recovery_generation != snapshot.generation
            {
                return Err(LanderError::Safety(
                    "origin anchor differs from the generation's origin".into(),
                ));
            }
            self.check_proving_anchor_canonicality(&anchor).await?;
            let (origin_keys, origin) = self.origin_set(snapshot, &anchor).await?;
            return Ok(BatchStart {
                parent,
                anchor,
                anchor_witness: None,
                previous: None,
                parent_signers: None,
                signers: origin.clone(),
                origin_keys,
                origin,
            });
        }
        let pair = self.comet.block(snapshot.checkpoint_height).await?;
        let envelope = crate::validate::verify_body_at_origin(
            &pair,
            snapshot.checkpoint_height,
            parent.header.parent_hash,
            snapshot.origin_height(),
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
        if B256::from_slice(pair.block.header.hash().as_bytes()) != snapshot.checkpoint_comet_hash {
            return Err(LanderError::Safety(
                "checkpoint Comet hash contradicts retained landing".into(),
            ));
        }
        if envelope.block.header != parent.header {
            return Err(LanderError::Safety(format!(
                "decided EL block contradicts checkpoint {}",
                snapshot.checkpoint_height
            )));
        }
        let witness = self.checkpoint_anchor_witness(snapshot, &envelope).await?;
        let anchor = crate::l1::verify_checkpoint_anchor(
            &witness,
            &parent.header,
            snapshot.generation,
            self.params.inbox,
        )?;
        self.check_proving_anchor_canonicality(&anchor).await?;
        let (origin_keys, origin) = self.origin_set(snapshot, &anchor).await?;
        let p = snapshot.checkpoint_height;
        let header = &pair.block.header;
        let parent_signers = self.archived_set(p, header.validators_hash, "validator", p).await?;
        verify_commit(
            &pair.commit,
            header,
            &parent_signers,
            &rules::chain_id_for(&self.params, snapshot.generation)
                .map_err(|e| LanderError::Configuration(e.to_string()))?,
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
        let signers = if p < snapshot.origin_height() + 2 {
            origin.clone()
        } else {
            self.archived_set(p + 1, header.next_validators_hash, "next validator", p).await?
        };
        if header.next_validators_hash != signers.hash() {
            return Err(LanderError::Safety("checkpoint next validator hash disagrees".into()));
        }
        Ok(BatchStart {
            parent,
            anchor,
            anchor_witness: Some(witness),
            previous: Some(pair),
            parent_signers: Some(parent_signers),
            signers,
            origin_keys,
            origin,
        })
    }

    /// The set that signs `height`, from the Comet node's `/validators` answer at `height`
    /// ([`CometSource::archive_validators`]), accepted only when it hashes to `expected`, the
    /// `what` hash of the checkpoint `checkpoint`'s authenticated Comet header. An answer that
    /// hashes elsewhere, or holds no valid set, is `Safety`; a failed read keeps the source's
    /// class.
    async fn archived_set(
        &self,
        height: u64,
        expected: tendermint::Hash,
        what: &str,
        checkpoint: u64,
    ) -> Result<Validators> {
        let members = self.comet.archive_validators(height).await?;
        let contradicts = |found: String| {
            LanderError::Safety(format!(
                "the Comet node's validators of height {height} ({found}) disagree with the {what} \
                 hash {expected} of checkpoint {checkpoint}"
            ))
        };
        let set =
            Validators::from_powers(&members).map_err(|error| contradicts(error.to_string()))?;
        if set.hash() != expected {
            return Err(contradicts(format!("hash {}", set.hash())));
        }
        Ok(set)
    }

    /// The anchor witness the checkpoint p uses, p being above its generation's start: the one
    /// p's own envelope `envelope` carries or, when p inherits its anchor, the one the newest
    /// block below p carries, read down from p − 1 towards the generation's first block, which
    /// always carries one. The blocks below p are read but not authenticated: the caller checks
    /// the witness against p's EL header. A block there that is not one envelope, or no witness
    /// down to the generation's first block, is `Safety`.
    async fn checkpoint_anchor_witness(
        &self,
        snapshot: &LandingSnapshot,
        envelope: &abci::EtnaEnvelope,
    ) -> Result<abci::AnchorWitness> {
        if let Some(witness) = &envelope.anchor {
            return Ok(witness.clone());
        }
        for height in (snapshot.origin_height() + 1..snapshot.checkpoint_height).rev() {
            let pair = self.comet.block(height).await?;
            let envelope = match pair.block.data.as_slice() {
                [tx] => abci::EtnaEnvelope::decode(tx).map_err(|e| {
                    LanderError::Safety(format!("block {height} below the checkpoint: {e}"))
                })?,
                _ => {
                    return Err(LanderError::Safety(format!(
                        "block {height} below the checkpoint holds no single envelope"
                    )));
                }
            };
            if let Some(witness) = envelope.anchor {
                return Ok(witness);
            }
        }
        Err(LanderError::Safety(format!(
            "no block of generation {} up to the checkpoint carries an anchor witness",
            snapshot.generation
        )))
    }

    /// Verify the successor x + 1 of the parent x in `state` against the sets 4.3 gives, then
    /// advance `state` past it.
    ///
    /// x + 1's LastCommit must verify against the set that signs x and its commit against the
    /// set that signs x + 1, before any read its contents select. The set that signs x + 2 and
    /// x + 1's `missBitmap` are then decided at x ([`BatchBuilder::decide_at_parent`]); the block
    /// rules check that `missBitmap`, and header(x + 1)'s `next_validators_hash` must commit the
    /// set that signs x + 2 (its `validators_hash` the commit check covers). Returns what the
    /// decision at x read, absent at the generation's start.
    async fn authenticate_block(
        &self,
        snapshot: &LandingSnapshot,
        state: &mut ForwardState,
        pair: &CertifiedBlock,
    ) -> Result<Option<ParentReads>> {
        let chain_id = rules::chain_id_for(&self.params, snapshot.generation)
            .map_err(|e| LanderError::Configuration(e.to_string()))?;
        let expected = state
            .parent
            .number
            .checked_add(1)
            .ok_or_else(|| LanderError::Safety("forward height overflow".into()))?;
        if pair.block.header.height.value() != expected {
            return Err(LanderError::Safety(format!(
                "Comet successor requires height {expected}, got {}",
                pair.block.header.height
            )));
        }
        codec::check_message_limits(pair, &self.limits)?;
        let height = pair.block.header.height.value();
        let envelope = crate::validate::verify_structure_at_origin(
            pair,
            state.previous.as_ref(),
            height,
            state.parent.hash,
            snapshot.origin_height(),
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
        // The structure check admits no LastCommit only at the generation's first block, and
        // every later parent has its signing set.
        let missing = match (&pair.block.last_commit, &state.previous, &state.parent_signers) {
            (None, None, _) => Vec::new(),
            (Some(last), Some(previous), Some(parent_signers)) => {
                verify_commit(last, &previous.block.header, parent_signers, &chain_id)
                    .and_then(|()| crate::validate::missing_validators(last, parent_signers))
                    .map_err(|e| LanderError::Safety(e.to_string()))?
            }
            _ => {
                return Err(LanderError::Safety(format!(
                    "block {height}'s LastCommit has no set that signs its parent"
                )));
            }
        };
        verify_commit(&pair.commit, &pair.block.header, &state.signers, &chain_id)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        let (miss_bitmap, next_signers, reads) =
            self.decide_at_parent(snapshot, state, &missing).await?;
        let bft_secs = u64::try_from(pair.block.header.time.unix_timestamp())
            .map_err(|_| LanderError::Safety("negative BFT block timestamp".into()))?;
        let signers = state.signers.entries();
        let parent_signers = state.parent_signers.as_ref().map(Validators::entries);
        let facts = verify_envelope(
            envelope,
            EnvelopeContext {
                bft_time_secs: bft_secs,
                proposer: pair.block.header.proposer_address,
                signers: &signers,
                parent_signers: parent_signers.as_deref().unwrap_or_default(),
                miss_bitmap,
                parent: &state.parent,
                parent_anchor: &state.anchor,
                generation: snapshot.generation,
                recovery: snapshot.recovery.as_ref(),
                genesis: &snapshot.genesis,
                params: &self.params,
                forced_cursor: state.forced_cursor,
            },
        )
        .map_err(|e| match e {
            crate::validate::ValidationError::UnsupportedRuleset { rules } => {
                LanderError::UnsupportedRuleset { rules }
            }
            other => LanderError::Safety(other.to_string()),
        })?;
        let probe_context = || {
            format!(
                "L2 {}, entry {}, parent {} ({}), anchor {} ({})",
                facts.expected.number,
                state.forced_cursor,
                state.parent.number,
                state.parent.hash,
                facts.anchor.number,
                facts.anchor.hash,
            )
        };
        if matches!(facts.forced, abci::forced::ForcedDecision::NeedsSkip { .. }) {
            let header = tokio::time::timeout(
                self.engine_timeout,
                self.engine.header_by_number(state.parent.number),
            )
            .await
            .map_err(|_| {
                LanderError::Temporary(format!(
                    "forced parent lookup at {} timed out after {:?}",
                    probe_context(),
                    self.engine_timeout,
                ))
            })?
            .map_err(|error| {
                let reason = format!(
                    "forced parent lookup at {}: {}",
                    probe_context(),
                    engine_diagnostic(&error),
                );
                if error.is_retryable() {
                    LanderError::Temporary(reason)
                } else {
                    LanderError::Safety(format!("{reason}; repair the EL before retrying"))
                }
            })?;
            let observed = header.map(|header| header.hash_slow());
            if observed != Some(state.parent.hash) {
                return Err(LanderError::Temporary(format!(
                    "forced parent lookup at {}: canonical header hash {observed:?} does not match the authenticated parent",
                    probe_context(),
                )));
            }
        }
        let consumed = tokio::time::timeout(
            self.engine_timeout,
            verify_forced(
                self.engine.as_ref(),
                ForcedBuildContext { expected: &facts.expected, anchor_hash: facts.anchor.hash },
                &facts.forced,
            ),
        )
        .await
        .map_err(|_| {
            LanderError::Temporary(format!(
                "forced singleton check at {} timed out after {:?}",
                probe_context(),
                self.engine_timeout,
            ))
        })?
        .map_err(|e| match e {
            ForcedBuildError::Engine(error) => {
                let reason = format!(
                    "forced singleton build at {}: {}",
                    probe_context(),
                    engine_diagnostic(&error),
                );
                if error.is_retryable_build() {
                    LanderError::Temporary(reason)
                } else {
                    LanderError::Safety(format!(
                        "{reason}; repair the EL and restore historical parent state if pruned"
                    ))
                }
            }
            other => LanderError::Safety(format!(
                "forced singleton check at {}: {other}",
                probe_context()
            )),
        })?;
        let forced_cursor = if consumed.is_some() {
            state
                .forced_cursor
                .checked_add(1)
                .ok_or_else(|| LanderError::Safety("forced inclusion cursor overflow".into()))?
        } else {
            state.forced_cursor
        };
        if pair.block.header.next_validators_hash != next_signers.hash() {
            return Err(LanderError::Safety(format!(
                "next validator hash disagrees at height {height}"
            )));
        }
        state.parent = facts.parent;
        state.parent_state_root = facts.envelope.block.header.state_root;
        state.anchor = facts.anchor;
        state.previous = Some(pair.clone());
        state.forced_cursor = forced_cursor;
        state.parent_signers = Some(std::mem::replace(&mut state.signers, next_signers));
        Ok(reads)
    }

    /// The `missBitmap` of x + 1, whose LastCommit misses the validators `missing`, and the set
    /// that signs x + 2, both decided at the parent x in `state`, with what the decision read.
    ///
    /// At the generation's start o, x + 1 has no LastCommit, so its `missBitmap` is 0, and the
    /// origin list signs o + 2: nothing of o's state or anchor is read. Above o, one staking read
    /// of x's post-state, pinned to x's hash ([`LandingSource::staking_witness`]), proves under
    /// x's state root the candidate snapshot and each missing validator's key-to-seat word
    /// ([`crate::l1::verify_staking_witness`]). Those words give the `missBitmap`
    /// ([`abci::miss::miss_bitmap`]); the snapshot, the minimum total stake x's anchor proves and
    /// the fallback key list whose hash that anchor proves ([`BatchBuilder::fallback_list`]) give
    /// the set ([`abci::committee::decide`]). At x = p, x's EL header is p's, and its anchor the
    /// one p's anchor witness proves. A failed read waits as `Temporary`; a proof that does not
    /// verify is `Safety`.
    async fn decide_at_parent(
        &self,
        snapshot: &LandingSnapshot,
        state: &ForwardState,
        missing: &[Address],
    ) -> Result<(u128, Validators, Option<ParentReads>)> {
        let x = state.parent.number;
        if x == snapshot.origin_height() {
            return Ok((0, state.origin.clone(), None));
        }
        let slots = crate::l1::staking_slots(missing);
        let witness = self.l1.staking_witness(state.parent.hash, &slots).await?;
        let (words, seats) = crate::l1::verify_staking_witness(
            state.parent_state_root,
            self.params.staking,
            &witness,
            x,
            missing,
        )?;
        // The verified witness holds the key-to-seat word of every missing validator.
        let miss_bitmap = abci::miss::miss_bitmap(missing, |address| seats[&address]);
        let anchor = &state.anchor;
        let fallback =
            self.fallback_list(anchor.inbox.fallback_keys_hash, anchor.hash, anchor.number).await?;
        let decided = abci::committee::decide(x, &words, anchor.inbox.min_total_stake, &fallback);
        let next = Validators::from_powers(&decided.members).map_err(|error| {
            LanderError::Safety(format!("the set decided at {x} has no validator set: {error}"))
        })?;
        let reads = ParentReads {
            witness,
            words,
            seat_words: missing.iter().map(|address| (*address, seats[address])).collect(),
            fallback: (decided.source == SignerSource::Fallback).then_some(fallback),
        };
        Ok((miss_bitmap, next, Some(reads)))
    }

    /// Retain only the selected proof prefix's per-block anchors, cut leaves, commit heights and
    /// the staking reads and fallback key lists of its decisions after shared verification: one
    /// leaf for every height strictly inside (p, h), none for the terminal block, and the forward
    /// state after its last block (its forced inclusion cursor). A height x of the prefix is a
    /// commit height when it is the terminal block or the set that signs x + 1 differs from the
    /// one that signs x. The decisions at [p, h − 1] read p's staking proof, kept whole, and the
    /// words of every later height, kept as the verified values.
    async fn authenticate_blocks(
        &self,
        snapshot: &LandingSnapshot,
        start: &BatchStart,
        blocks: &[CertifiedBlock],
    ) -> Result<AuthenticatedBlocks> {
        let mut state = ForwardState::new(start, snapshot)?;
        let mut anchors = Vec::new();
        let mut leaves = Vec::new();
        let mut commit_heights = Vec::new();
        let mut staking_at_p = None;
        let mut staking_reads = Vec::new();
        let mut fallback_key_lists = BTreeMap::new();
        for (index, pair) in blocks.iter().enumerate() {
            let signers = state.signers.clone();
            let height = state.parent.number;
            if let Some(reads) = self.authenticate_block(snapshot, &mut state, pair).await? {
                let ParentReads { witness, words, seat_words, fallback } = reads;
                if let Some(keys) = fallback {
                    fallback_key_lists.entry(keys.hash()).or_insert(keys);
                }
                if height == snapshot.checkpoint_height {
                    staking_at_p = Some(witness);
                } else {
                    let values = snapshot_values(&words);
                    staking_reads.push(HeightReads { height, values, seat_words });
                }
            }
            anchors.push(state.anchor.clone());
            if index + 1 == blocks.len() || state.signers != signers {
                commit_heights.push(state.parent.number);
            }
            if index + 1 < blocks.len() {
                leaves.push(statement::cut_leaf(
                    state.parent.number,
                    state.parent.hash,
                    B256::from_slice(pair.block.header.hash().as_bytes()),
                    state.forced_cursor,
                ));
            }
        }
        Ok(AuthenticatedBlocks {
            anchors,
            leaves,
            commit_heights,
            staking_at_p,
            staking_reads,
            fallback_key_lists,
            end: state,
        })
    }

    /// The authenticated anchor the decided `tip` consumes, used only for back-pressure urgency.
    ///
    /// Walks back from `tip` to the newest block above `checkpoint` that carries an anchor
    /// witness, or to the tip an earlier observation resolved. Blocks are read and decoded
    /// without verifying their certificates: `prepare` authenticates a batch's blocks, and a
    /// block past the batch never stops a landing (BATCH-6.3-12a). With no later witness the
    /// tip consumes the checkpoint's anchor `start`. A newest witness that does not decode or
    /// authenticate against the own L1, or whose own-L1 lookup is unavailable, also yields
    /// `start`, whose unsettled depth never undercounts the tip's (BACKP-6.4-10); such a result
    /// is not remembered, and the tip an earlier observation resolved stays remembered. An
    /// own-L1 answer that is malformed or inconsistent is returned as its error.
    async fn tip_anchor(
        &self,
        start: &AnchorState,
        checkpoint: u64,
        tip: u64,
    ) -> Result<AnchorState> {
        let mut retained = self.tip_anchor.lock().await;
        let known = retained.clone().filter(|known| {
            known.height > checkpoint && known.height <= tip && known.anchor.number >= start.number
        });
        let mut tip_hash = None;
        for height in (checkpoint + 1..=tip).rev() {
            let pair = self.comet.block(height).await?;
            let hash = B256::from_slice(pair.block.header.hash().as_bytes());
            let comet_hash = *tip_hash.get_or_insert(hash);
            let resolved = match &known {
                Some(known) if (known.height, known.comet_hash) == (height, hash) => {
                    Ok(Some(known.anchor.clone()))
                }
                _ => match pair.block.data.as_slice() {
                    [tx] => match abci::EtnaEnvelope::decode(tx) {
                        // The block inherits its parent's anchor.
                        Ok(envelope) if envelope.anchor.is_none() => continue,
                        Ok(envelope) => {
                            let witness = envelope.anchor.expect("checked above");
                            self.authenticated_anchor(&witness, start).await
                        }
                        Err(_) => Ok(None),
                    },
                    _ => Ok(None),
                },
            };
            let anchor = match resolved {
                Ok(Some(anchor)) => anchor,
                Ok(None) => {
                    tracing::warn!(
                        height,
                        "decided block's anchor does not authenticate; counting back-pressure from the checkpoint's anchor"
                    );
                    return Ok(start.clone());
                }
                Err(error) if error.is_retryable() => {
                    tracing::debug!(
                        height, %error,
                        "own L1 anchor lookup is unavailable; counting back-pressure from the checkpoint's anchor"
                    );
                    return Ok(start.clone());
                }
                Err(error) => return Err(error),
            };
            *retained = Some(TipAnchor { height: tip, comet_hash, anchor: anchor.clone() });
            return Ok(anchor);
        }
        if let Some(comet_hash) = tip_hash {
            *retained = Some(TipAnchor { height: tip, comet_hash, anchor: start.clone() });
        }
        Ok(start.clone())
    }

    /// The anchor `witness` proves, when it authenticates against the own L1 and does not precede
    /// the checkpoint's anchor `start`; `None` for an invalid witness or hash mismatch.
    /// Own-L1 lookup failures retain their retry-versus-stop classification.
    async fn authenticated_anchor(
        &self,
        witness: &abci::AnchorWitness,
        start: &AnchorState,
    ) -> Result<Option<AnchorState>> {
        let Ok(anchor) = abci::l1::verify_anchor_witness(witness, self.params.inbox) else {
            return Ok(None);
        };
        if anchor.number < start.number {
            return Ok(None);
        }
        let canonical = self.l1.canonical_hash(anchor.number).await?;
        Ok((canonical == anchor.hash).then_some(anchor))
    }
    /// Prepare with fresh chain context, consuming selection only when all inputs still match.
    async fn prepare_inner(
        &self,
        snapshot: LandingSnapshot,
        selected: Option<ObservedPrefix>,
    ) -> Result<Option<ProofRequest>> {
        self.check_snapshot(&snapshot)?;
        let end = self.exact_end(snapshot.checkpoint_height)?;
        let status = self.status(&snapshot).await?;
        if status.height == snapshot.checkpoint_height || end.is_some_and(|end| status.height < end)
        {
            return Ok(None);
        }
        let start = self.checkpoint(&snapshot).await?;
        // The first proof from S on a switching network carries both proxies' implementation
        // proofs at S: the L2 SignalService's and the staking proxy's that the configuration
        // hash commits.
        let from_switch_start = self.params.switch.is_some() &&
            snapshot.checkpoint_height == snapshot.genesis.genesis_height;
        let (start_signal_service_witness, start_staking_witness) = if from_switch_start {
            let signal_service = abci::l2_signal_service_address(self.params.l2_chain_id);
            (
                self.l1.start_proxy_witness(&snapshot, signal_service).await?,
                self.l1.start_proxy_witness(&snapshot, self.params.staking).await?,
            )
        } else {
            (None, None)
        };
        crate::types::verify_start_witness(
            &snapshot,
            &start.parent.header,
            &self.params,
            start_signal_service_witness.as_ref(),
            start_staking_witness.as_ref(),
        )?;
        let selected = selected.filter(|selected| {
            selected.snapshot == snapshot &&
                selected.decided_height == status.height &&
                selected.limits == self.selection_limits() &&
                selected.max_batch_blocks == self.max_batch_blocks &&
                selected.deflate_budget == self.deflate_budget
        });
        let prefix = match selected {
            Some(selected) => selected.prefix,
            None => self.publishable_prefix(&snapshot, status.height).await?,
        };
        let AuthenticatedBlocks {
            anchors,
            leaves,
            commit_heights,
            staking_at_p,
            staking_reads,
            fallback_key_lists,
            end,
        } = self.authenticate_blocks(&snapshot, &start, &prefix.blocks).await?;
        if prefix.blocks.is_empty() {
            return Ok(None);
        }
        let forced_cursor = end.forced_cursor;
        let (blocks, payload) = self.payload(prefix).await?;
        let Some(terminal) = blocks.last() else {
            return Ok(None);
        };
        let last = abci::EtnaEnvelope::decode(&terminal.block.data[0])
            .map_err(|e| LanderError::Safety(e.to_string()))?
            .block
            .header;
        // The reference chain reaches the anchors the batch's blocks use, and no other: p's
        // anchor only as the one p + 1 inherits, R only as a block's anchor.
        let headers = self.l1.reference(&snapshot, &anchors).await?;
        verify_reference_chain(&headers, &anchors)?;
        let reference = &headers[0];
        self.l1.validate_reference(&snapshot, reference.number(), reference.hash()).await?;
        let starting_inbox_witness = self.starting_inbox(&snapshot, reference).await?;
        let input = LandInput {
            // Proof origin p: the latest checkpoint c of the snapshot this batch is built on.
            parentHeight: U256::from(snapshot.checkpoint_height),
            lastHeight: U256::from(last.number),
            lastBlockHash: last.hash_slow(),
            lastCometHash: B256::from_slice(terminal.block.header.hash().as_bytes()),
            lastStateRoot: last.state_root,
            l1ReferenceBlockNumber: U256::from(reference.number()),
            forcedInclusionHead: U256::from(
                U48::try_from(forced_cursor)
                    .map_err(|_| {
                        LanderError::Safety(format!(
                            "forced inclusion cursor {forced_cursor} exceeds uint48"
                        ))
                    })?
                    .to::<u64>(),
            ),
        };
        let blobs = blob::build(&payload, &self.limits, self.mode)?;
        let hash =
            statement::hash(&snapshot, &input, reference.hash(), &blobs.versioned_hashes, &leaves);
        let deployment = self.l1.deployment(&snapshot).await?;
        if blocks.len() as u64 > deployment.max_batch_blocks {
            // The Inbox changed since startup; the next start selects under the new value.
            return Err(LanderError::Configuration(format!(
                "the Inbox maxBatchBlocks is now {}, below this {}-block batch; restart to apply it",
                deployment.max_batch_blocks,
                blocks.len()
            )));
        }
        // The origin list signs p + 1 up to o + 2, so the proof takes the set of p + 1 as input
        // only above.
        let validators_p1 = (snapshot.checkpoint_height >= snapshot.origin_height() + 2)
            .then(|| start.signers.members());
        // header(p), from the original block protobuf of the checkpoint above the start.
        let header_p = match &start.previous {
            Some(pair) => {
                let header = pair.block_proto()?.header.ok_or_else(|| {
                    LanderError::Safety("checkpoint block protobuf holds no header".into())
                })?;
                Some(Bytes::from(header.encode_to_vec()))
            }
            None => None,
        };
        let request = ProofRequest {
            batch: PreparedBatch {
                snapshot,
                parent_header: start.parent.header.clone(),
                start_signal_service_witness,
                start_staking_witness,
                grandparent_timestamp: start.parent.grandparent_timestamp,
                parent_anchor: start.anchor.clone(),
                starting_inbox_witness,
                p_anchor_witness: start.anchor_witness.clone(),
                origin_fallback_keys: start.origin_keys.clone(),
                header_p,
                validators_p: start.parent_signers.as_ref().map(Validators::members),
                validators_p1,
                staking_at_p,
                blocks,
                anchors,
                staking_reads,
                fallback_key_lists: fallback_key_lists.into_values().collect(),
                reference_headers: headers.iter().map(|header| header.raw().clone()).collect(),
                input,
                leaves,
                commit_heights,
                blobs,
                statement_hash: hash,
            },
        };
        request.batch.check_origin_sets().map_err(LanderError::Safety)?;
        let journaled = request_bytes(&request)?;
        if journaled > self.request_budget {
            // A restart selects this prefix or a longer one again; only a lower cap selects a
            // shorter one.
            let (first, last, budget) =
                (request.batch.snapshot.checkpoint_height + 1, last.number, self.request_budget);
            let blocks = last + 1 - first;
            let remedy = if blocks > 1 {
                format!("; lower --max-blocks below {blocks} so a batch selects fewer blocks")
            } else {
                String::new()
            };
            return Err(LanderError::Capacity(format!(
                "the proof request of blocks {first}..={last} would journal {journaled} bytes, \
                 beyond the {budget} a request may take{remedy}"
            )));
        }
        Ok(Some(request))
    }
}

#[async_trait]
impl<C: CometSource + ?Sized, L: LandingSource + ?Sized> BatchSource for BatchBuilder<C, L> {
    /// Authenticate the coherent checkpoint against this source's certified chain. Reads only
    /// CometBFT, L1 and the EL, never the app, so the runner's reconciliation of a sent landing,
    /// which this gates, never waits on the app.
    async fn validate_checkpoint(&self, snapshot: &LandingSnapshot) -> Result<()> {
        self.check_snapshot(snapshot)?;
        self.status(snapshot).await?;
        self.checkpoint(snapshot).await?;
        Ok(())
    }

    /// Preview capacity and the tip's authenticated anchor for urgency decisions, without
    /// verifying the decided blocks: `prepare` authenticates the ones a batch selects.
    async fn observe(&self, snapshot: &LandingSnapshot) -> Result<BatchPreview> {
        self.check_snapshot(snapshot)?;
        let end = self.exact_end(snapshot.checkpoint_height)?;
        let status = self.status(snapshot).await?;
        if status.height == snapshot.checkpoint_height || end.is_some_and(|end| status.height < end)
        {
            return Ok(BatchPreview::from_observation(BatchObservation {
                decided_height: status.height,
                publishable_blocks: 0,
                force_back_pressure: false,
            }));
        }
        let prefix = self.publishable_prefix(snapshot, status.height).await?;
        let start = self.checkpoint(snapshot).await?;
        let anchor =
            self.tip_anchor(&start.anchor, snapshot.checkpoint_height, status.height).await?;
        let observation = BatchObservation {
            decided_height: status.height,
            publishable_blocks: prefix.blocks.len(),
            force_back_pressure: status.height.saturating_sub(anchor.inbox.last_checkpoint_height) >=
                self.params.unsettled_limit.saturating_sub(1),
        };
        Ok(BatchPreview {
            observation,
            selected: Some(ObservedPrefix {
                snapshot: snapshot.clone(),
                decided_height: status.height,
                limits: self.selection_limits(),
                max_batch_blocks: self.max_batch_blocks,
                deflate_budget: self.deflate_budget,
                prefix,
            }),
        })
    }

    /// Authenticate the selected prefix and construct its immutable statement and sidecar.
    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>> {
        self.prepare_inner(snapshot, None).await
    }

    /// Authenticate a preview with fresh context, discarding changed selection inputs.
    async fn prepare_observed(
        &self,
        snapshot: LandingSnapshot,
        preview: BatchPreview,
    ) -> Result<Option<ProofRequest>> {
        self.prepare_inner(snapshot, preview.selected).await
    }

    /// The exact end set by [`BatchBuilder::with_land_to`].
    fn land_to(&self) -> Option<u64> {
        self.land_to
    }
}

/// Reconstructs R's proof-bound anchor, whose canonicality a recovery generation's checkpoint
/// rechecks and at which its origin key list is obtained.
pub(crate) fn recovery_anchor(snapshot: &LandingSnapshot) -> Result<AnchorState> {
    use alloy_rlp::Decodable;
    let bytes = snapshot
        .recovery_witness
        .as_ref()
        .ok_or_else(|| LanderError::Safety("missing recovery evidence".into()))?;
    let witness = abci::recovery::RecoveryWitness::decode(&mut bytes.as_ref())
        .map_err(|e| LanderError::Safety(format!("recovery evidence: {e}")))?;
    let mut inbox = witness.recovery_inbox;
    let slots = abci::l1::layout::inbox::anchor_slots();
    inbox.storage = slots
        .iter()
        .map(|slot| {
            inbox
                .storage
                .iter()
                .find(|p| p.slot == *slot)
                .cloned()
                .ok_or_else(|| LanderError::Safety("recovery anchor slot missing".into()))
        })
        .collect::<Result<Vec<_>>>()?;
    abci::l1::verify_anchor_witness(
        &abci::AnchorWitness { l1_header: witness.recovery_header, inbox },
        snapshot.inbox,
    )
    .map_err(|e| LanderError::Safety(format!("recovery anchor: {e}")))
}

/// Compresses `list` into a V6 payload on the blocking pool, keeping deflate off the async
/// workers.
async fn compress(list: Vec<u8>, limits: Limits) -> Result<Vec<u8>> {
    match tokio::task::spawn_blocking(move || codec::compress(&list, &limits)).await {
        Ok(payload) => payload,
        Err(error) if error.is_panic() => std::panic::resume_unwind(error.into_panic()),
        Err(error) => {
            Err(LanderError::Temporary(format!("payload compression did not finish: {error}")))
        }
    }
}

/// Converts an authenticated public EL parent into existing ABCI derivation inputs.
fn parent_info(context: &ParentContext) -> Result<ParentInfo> {
    let header = &context.header;
    Ok(ParentInfo {
        number: header.number,
        hash: header.hash_slow(),
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        difficulty: header.difficulty,
        base_fee: header
            .base_fee_per_gas
            .ok_or_else(|| LanderError::Safety("EL parent has no base fee".into()))?,
        grandparent_timestamp: context.grandparent_timestamp,
    })
}

/// The bytes `request` journals as: the length of its JSON, counted without retaining it.
fn request_bytes(request: &ProofRequest) -> Result<u64> {
    /// Counts the bytes written to it.
    struct Count(u64);
    impl std::io::Write for Count {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            self.0 += bytes.len() as u64;
            Ok(bytes.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    let mut count = Count(0);
    serde_json::to_writer(&mut count, request)
        .map_err(|error| LanderError::Encoding(format!("proof request: {error}")))?;
    Ok(count.0)
}

/// The values of the candidate snapshot `words` at [`abci::staking::snapshot_slots`], in that
/// order.
fn snapshot_values(words: &StakingWords) -> Vec<U256> {
    [words.snapshot_height, words.total_stake]
        .into_iter()
        .chain(words.records.iter().flatten().copied())
        .collect()
}

/// Checks the exact descending header chain and every consumed anchor (PROOF-6.2-33/34).
///
/// The source only fetches the chain from a finalized tip; this pure check is the one
/// fetch-time check of its links and anchors, and `validate_reference` then authenticates the
/// tip's canonicality.
pub fn verify_reference_chain(
    headers: &[abci::RawL1Header],
    anchors: &[AnchorState],
) -> Result<()> {
    if headers.is_empty() || anchors.is_empty() {
        return Err(LanderError::Safety("empty reference header/anchor context".into()));
    }
    let oldest = anchors.iter().map(|anchor| anchor.number).min().expect("nonempty anchors");
    if headers.last().expect("nonempty headers").number() != oldest {
        return Err(LanderError::Safety(
            "reference chain does not terminate at oldest consumed anchor".into(),
        ));
    }
    for pair in headers.windows(2) {
        if pair[0].number().checked_sub(1) != Some(pair[1].number()) ||
            pair[0].parent_hash() != pair[1].hash()
        {
            return Err(LanderError::Safety("reference header ancestry is discontinuous".into()));
        }
    }
    let by_number =
        headers.iter().map(|header| (header.number(), header)).collect::<BTreeMap<_, _>>();
    for anchor in anchors {
        let header = by_number.get(&anchor.number).ok_or_else(|| {
            LanderError::Safety(format!("reference chain omits anchor {}", anchor.number))
        })?;
        if header.hash() != anchor.hash ||
            header.state_root() != anchor.state_root ||
            header.timestamp() != anchor.timestamp
        {
            return Err(LanderError::Safety(format!(
                "reference chain contradicts anchor {}",
                anchor.number
            )));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::consensus_mpt::{Fixture, MAX_BATCH_BLOCKS};
    use std::sync::{
        RwLock,
        atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering},
    };

    struct TrackingSource {
        fixture: RwLock<Arc<Fixture>>,
        /// The `maxBatchBlocks` the Inbox reports now, which a builder read at startup.
        max_batch_blocks: AtomicU64,
        history_reads: AtomicUsize,
        inbox_reads: AtomicUsize,
        list_reads: AtomicUsize,
        parent_reads: AtomicUsize,
        status_reads: AtomicUsize,
        block_reads: AtomicUsize,
        val_state_reads: AtomicUsize,
        anchor_reorg: AtomicBool,
        canonical_unavailable: AtomicBool,
        canonical_failure: AtomicBool,
        snapshot_reorg: AtomicBool,
        parent_changed: AtomicBool,
        /// The L2 block hashes of the staking reads, in order.
        staking_reads: std::sync::Mutex<Vec<alloy_primitives::B256>>,
    }

    impl TrackingSource {
        fn new(fixture: Fixture) -> Arc<Self> {
            Arc::new(Self {
                fixture: RwLock::new(Arc::new(fixture)),
                max_batch_blocks: AtomicU64::new(MAX_BATCH_BLOCKS),
                history_reads: AtomicUsize::new(0),
                inbox_reads: AtomicUsize::new(0),
                list_reads: AtomicUsize::new(0),
                parent_reads: AtomicUsize::new(0),
                status_reads: AtomicUsize::new(0),
                block_reads: AtomicUsize::new(0),
                val_state_reads: AtomicUsize::new(0),
                anchor_reorg: AtomicBool::new(false),
                canonical_unavailable: AtomicBool::new(false),
                canonical_failure: AtomicBool::new(false),
                snapshot_reorg: AtomicBool::new(false),
                parent_changed: AtomicBool::new(false),
                staking_reads: std::sync::Mutex::new(Vec::new()),
            })
        }

        fn fixture(&self) -> Arc<Fixture> {
            self.fixture.read().unwrap().clone()
        }

        fn builder(self: &Arc<Self>, max_blocks: usize) -> BatchBuilder<Self, Self> {
            BatchBuilder::new(
                self.clone(),
                self.clone(),
                crate::batch::BatchBuilderConfig {
                    params: self.fixture().params.clone(),
                    limits: limits(max_blocks),
                    mode: SidecarMode::Eip4844,
                    engine: std::sync::Arc::new(
                        test_harness::unavailable_engine::UnavailableEngine,
                    ),
                    engine_timeout: std::time::Duration::from_secs(1),
                    max_batch_blocks: MAX_BATCH_BLOCKS,
                },
            )
            .unwrap()
        }
    }

    #[async_trait]
    impl CometSource for TrackingSource {
        async fn status(&self) -> Result<CometStatus> {
            self.status_reads.fetch_add(1, Ordering::Relaxed);
            self.fixture().status().await
        }

        async fn block(&self, height: u64) -> Result<CertifiedBlock> {
            self.block_reads.fetch_add(1, Ordering::Relaxed);
            self.fixture().block(height).await
        }

        async fn val_state(&self, height: u64) -> Result<Vec<u8>> {
            self.val_state_reads.fetch_add(1, Ordering::Relaxed);
            self.fixture().val_state(height).await
        }

        async fn archive_validators(
            &self,
            height: u64,
        ) -> Result<Vec<(abci::key::ConsensusKey, u64)>> {
            self.fixture().archive_validators(height).await
        }
    }

    #[async_trait]
    impl LandingSource for TrackingSource {
        async fn snapshot(&self) -> Result<LandingSnapshot> {
            self.fixture().snapshot().await
        }

        async fn parent_header(&self, snapshot: &LandingSnapshot) -> Result<ParentContext> {
            self.parent_reads.fetch_add(1, Ordering::Relaxed);
            let mut parent = self.fixture().parent_header(snapshot).await?;
            if self.parent_changed.load(Ordering::Relaxed) {
                parent.header.timestamp += 1;
            }
            Ok(parent)
        }

        async fn execution_header(&self, number: u64) -> Result<alloy_consensus::Header> {
            self.history_reads.fetch_add(1, Ordering::Relaxed);
            self.fixture().execution_header(number).await
        }

        async fn origin_anchor(&self, snapshot: &LandingSnapshot) -> Result<AnchorState> {
            self.fixture().origin_anchor(snapshot).await
        }

        async fn starting_inbox_witness(
            &self,
            reference: &abci::RawL1Header,
            generation: u64,
        ) -> Result<abci::AnchorWitness> {
            self.inbox_reads.fetch_add(1, Ordering::Relaxed);
            self.fixture().starting_inbox_witness(reference, generation).await
        }

        async fn fallback_keys(
            &self,
            hash: B256,
            at: B256,
            at_number: u64,
            from_block: u64,
        ) -> Result<abci::fallback::FallbackKeys> {
            self.list_reads.fetch_add(1, Ordering::Relaxed);
            self.fixture().fallback_keys(hash, at, at_number, from_block).await
        }

        async fn staking_witness(
            &self,
            block_hash: B256,
            slots: &[B256],
        ) -> Result<abci::AccountWitness> {
            self.staking_reads.lock().unwrap().push(block_hash);
            self.fixture().staking_witness(block_hash, slots).await
        }

        async fn reference(
            &self,
            snapshot: &LandingSnapshot,
            anchors: &[AnchorState],
        ) -> Result<Vec<abci::RawL1Header>> {
            self.fixture().reference(snapshot, anchors).await
        }

        async fn deployment(&self, snapshot: &LandingSnapshot) -> Result<crate::l1::Deployment> {
            self.fixture().deployment(snapshot).await?;
            let max_batch_blocks = self.max_batch_blocks.load(Ordering::Relaxed);
            Ok(crate::l1::Deployment { max_batch_blocks })
        }
        async fn canonical_hash(&self, number: u64) -> Result<alloy_primitives::B256> {
            if self.canonical_unavailable.load(Ordering::Relaxed) {
                return Err(LanderError::Temporary("L1 unavailable".into()));
            }
            if self.canonical_failure.load(Ordering::Relaxed) {
                return Err(LanderError::Safety("malformed own-L1 reply".into()));
            }
            let fixture = self.fixture();
            if self.snapshot_reorg.load(Ordering::Relaxed) &&
                number == fixture.snapshot.l1_block_number
            {
                return Ok(alloy_primitives::B256::repeat_byte(0xff));
            }
            if self.anchor_reorg.load(Ordering::Relaxed) &&
                number < fixture.snapshot.l1_block_number
            {
                return Ok(alloy_primitives::B256::repeat_byte(0xff));
            }
            fixture.canonical_hash(number).await
        }

        async fn validate_reference(
            &self,
            snapshot: &LandingSnapshot,
            number: u64,
            hash: alloy_primitives::B256,
        ) -> Result<()> {
            self.fixture().validate_reference(snapshot, number, hash).await
        }
    }

    /// The prefix ends at the last decided block, at any height (LAND-6.1-5), and carries one
    /// leaf per height strictly inside (p, h) (ENC-A-31).
    #[tokio::test]
    async fn prefix_ends_at_any_height_with_one_leaf_per_interior_height() {
        let fixture = Arc::new(Fixture::new(0, 8));
        let batch = builder(fixture.clone(), limits(8))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap()
            .batch;
        assert_eq!(batch.input.parentHeight, U256::ZERO);
        assert_eq!(batch.input.lastHeight, U256::from(8));
        assert_eq!(batch.blocks.len(), 8);
        assert_eq!(batch.leaves.len(), 7);
    }

    #[tokio::test]
    async fn observed_prefix_is_consumed_without_repeating_block_reads() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        let snapshot = source.fixture().snapshot.clone();
        let preview = b.observe(&snapshot).await.unwrap();
        source.block_reads.store(0, Ordering::Relaxed);
        let parent_reads = source.parent_reads.load(Ordering::Relaxed);
        let status_reads = source.status_reads.load(Ordering::Relaxed);
        let request = b.prepare_observed(snapshot.clone(), preview).await.unwrap().unwrap();
        assert_eq!(request.batch.blocks.len(), 6);
        assert_eq!(source.block_reads.load(Ordering::Relaxed), 0);
        assert_eq!(source.parent_reads.load(Ordering::Relaxed), parent_reads + 1);
        assert_eq!(source.status_reads.load(Ordering::Relaxed), status_reads + 1);
    }

    #[tokio::test]
    async fn observed_prefix_reselects_when_the_fresh_tip_changes() {
        for fresh_tip in [0, 6, 18] {
            let mut fixture = Fixture::new(0, 18);
            fixture.headers.retain(|height, _| *height <= 12);
            let source = TrackingSource::new(fixture);
            let b = source.builder(18);
            let snapshot = source.fixture().snapshot.clone();
            let preview = b.observe(&snapshot).await.unwrap();
            assert_eq!(preview.observation.publishable_blocks, 12);
            let mut fresh = Fixture::new(0, 18);
            fresh.headers.retain(|height, _| *height <= fresh_tip);
            *source.fixture.write().unwrap() = Arc::new(fresh);
            source.block_reads.store(0, Ordering::Relaxed);
            let result = b.prepare_observed(snapshot, preview).await.unwrap();
            assert_eq!(
                result.as_ref().map(|r| r.batch.blocks.len()),
                (fresh_tip != 0).then_some(fresh_tip as usize)
            );
            assert_eq!(source.block_reads.load(Ordering::Relaxed), fresh_tip as usize);
        }
    }

    #[tokio::test]
    async fn observed_prefix_from_different_selection_inputs_is_reselected() {
        for changed in 0..5 {
            let source = TrackingSource::new(Fixture::new(0, 12));
            let snapshot = source.fixture().snapshot.clone();
            let mut preview = source.builder(12).observe(&snapshot).await.unwrap();
            let mut other = source.builder(12);
            match changed {
                0 => other.limits.max_blocks = 6,
                1 => other.max_batch_blocks = 6,
                2 => other.list_budget = 1,
                3 => other.deflate_budget = 0,
                4 => preview.selected.as_mut().unwrap().snapshot.forced_inclusion_head += 1,
                _ => unreachable!(),
            }
            source.block_reads.store(0, Ordering::Relaxed);
            let result = other.prepare_observed(snapshot, preview).await;
            if changed == 2 {
                assert!(matches!(result, Err(LanderError::Capacity(_))));
            } else {
                let expected = if changed < 2 { 6 } else { 12 };
                assert_eq!(result.unwrap().unwrap().batch.blocks.len(), expected);
            }
            assert!(source.block_reads.load(Ordering::Relaxed) > 0, "input {changed}");
        }
    }

    #[tokio::test]
    async fn observed_prefix_keeps_fresh_checkpoint_checks() {
        for changed in 0..4 {
            let source = TrackingSource::new(Fixture::new(24, 30));
            let b = source.builder(6);
            let snapshot = source.fixture().snapshot.clone();
            let preview = b.observe(&snapshot).await.unwrap();
            match changed {
                0 => source.parent_changed.store(true, Ordering::Relaxed),
                1 => source.anchor_reorg.store(true, Ordering::Relaxed),
                2 => source.snapshot_reorg.store(true, Ordering::Relaxed),
                3 => source.canonical_unavailable.store(true, Ordering::Relaxed),
                _ => unreachable!(),
            }
            let error = b.prepare_observed(snapshot, preview).await.unwrap_err();
            match changed {
                0 | 1 => assert!(matches!(error, LanderError::Safety(_)), "{error}"),
                2 => assert!(matches!(error, LanderError::Stale(_)), "{error}"),
                3 => assert!(matches!(error, LanderError::Temporary(_)), "{error}"),
                _ => unreachable!(),
            }
        }
    }

    #[tokio::test]
    async fn observed_prefix_still_authenticates_private_blocks_and_certificates() {
        for corrupt_certificate in [false, true] {
            let source = TrackingSource::new(Fixture::new(24, 30));
            let b = source.builder(6);
            let snapshot = source.fixture().snapshot.clone();
            let mut preview = b.observe(&snapshot).await.unwrap();
            let pair = &mut preview.selected.as_mut().unwrap().prefix.blocks[0];
            if corrupt_certificate {
                pair.commit.signatures.clear();
            } else {
                pair.block.data[0].push(0);
            }
            source.block_reads.store(0, Ordering::Relaxed);
            assert!(matches!(
                b.prepare_observed(snapshot, preview).await,
                Err(LanderError::Safety(_))
            ));
            assert_eq!(source.block_reads.load(Ordering::Relaxed), 0);
        }
    }

    /// Validation and observation run no KZG; preparation verifies the sidecar it built once
    /// (PROOF-6.2-35/38).
    #[tokio::test]
    async fn prepare_verifies_its_built_sidecar_exactly_once() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        let snapshot = source.fixture().snapshot.clone();
        let before = crate::blob::kzg_verifications();
        b.validate_checkpoint(&snapshot).await.unwrap();
        let preview = b.observe(&snapshot).await.unwrap();
        assert_eq!(crate::blob::kzg_verifications(), before);
        b.prepare_observed(snapshot, preview).await.unwrap().unwrap();
        assert_eq!(crate::blob::kzg_verifications(), before + 1);
    }

    #[tokio::test]
    async fn unchanged_checkpoint_reuses_history_across_validation_observation_and_preparation() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        let snapshot = source.fixture().snapshot.clone();
        b.validate_checkpoint(&snapshot).await.unwrap();
        b.observe(&snapshot).await.unwrap();
        b.prepare(snapshot.clone()).await.unwrap().unwrap();
        // One start: the grandparent header and the origin key list, read once; the starting
        // Inbox proof is read once, under the one prepared batch's reference header.
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 1);
        assert_eq!(source.inbox_reads.load(Ordering::Relaxed), 1);
        assert_eq!(source.list_reads.load(Ordering::Relaxed), 1);
        assert_eq!(source.parent_reads.load(Ordering::Relaxed), 3);
        assert_eq!(source.status_reads.load(Ordering::Relaxed), 3);

        // A new operational L1 head cannot make immutable checkpoint ancestry expensive again.
        let mut advanced = Fixture::new(24, 30);
        let mut header: alloy_consensus::Header =
            alloy_rlp::decode_exact(advanced.snapshot.l1_header.raw()).unwrap();
        header.parent_hash = advanced.snapshot.l1_block_hash;
        header.number += 1;
        header.timestamp += 1;
        advanced.snapshot.l1_header = abci::RawL1Header::from(&header);
        advanced.snapshot.l1_block_number = header.number;
        advanced.snapshot.l1_block_hash = header.hash_slow();
        advanced.l1_headers.insert(header.number, advanced.snapshot.l1_header.clone());
        *source.fixture.write().unwrap() = Arc::new(advanced);
        b.validate_checkpoint(&source.fixture().snapshot).await.unwrap();
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 1);
        assert_eq!(source.inbox_reads.load(Ordering::Relaxed), 1);
        assert_eq!(source.list_reads.load(Ordering::Relaxed), 1);
    }

    #[tokio::test]
    async fn cached_checkpoint_rechecks_parent_and_l1_anchor_canonicality() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        let snapshot = source.fixture().snapshot.clone();
        b.validate_checkpoint(&snapshot).await.unwrap();
        source.parent_changed.store(true, Ordering::Relaxed);
        assert!(matches!(b.observe(&snapshot).await, Err(LanderError::Safety(_))));
        source.parent_changed.store(false, Ordering::Relaxed);
        b.validate_checkpoint(&snapshot).await.unwrap();
        source.anchor_reorg.store(true, Ordering::Relaxed);
        assert!(b.observe(&snapshot).await.is_err(), "a reorged proving anchor cannot be reused");
        source.anchor_reorg.store(false, Ordering::Relaxed);
        let reads = source.history_reads.load(Ordering::Relaxed);
        b.validate_checkpoint(&snapshot).await.unwrap();
        assert_eq!(source.history_reads.load(Ordering::Relaxed), reads + 1);
    }

    #[tokio::test]
    async fn checkpoint_progress_replaces_the_retained_context() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        b.validate_checkpoint(&source.fixture().snapshot).await.unwrap();
        *source.fixture.write().unwrap() = Arc::new(Fixture::new(30, 30));
        b.validate_checkpoint(&source.fixture().snapshot).await.unwrap();
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 2);
        // A start reads no starting Inbox proof: each batch reads it under its reference.
        assert_eq!(source.inbox_reads.load(Ordering::Relaxed), 0);
        // The origin key list is read once by its hash, whatever start needs it.
        assert_eq!(source.list_reads.load(Ordering::Relaxed), 1);
        b.validate_checkpoint(&source.fixture().snapshot).await.unwrap();
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 2);
    }

    #[tokio::test]
    async fn cached_checkpoint_rejects_a_reorganized_operational_snapshot_and_rebuilds() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        let snapshot = source.fixture().snapshot.clone();
        b.validate_checkpoint(&snapshot).await.unwrap();
        source.snapshot_reorg.store(true, Ordering::Relaxed);
        assert!(matches!(b.validate_checkpoint(&snapshot).await, Err(LanderError::Stale(_))));
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 1);
        source.snapshot_reorg.store(false, Ordering::Relaxed);
        b.validate_checkpoint(&snapshot).await.unwrap();
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 2);
    }

    /// The start a checkpoint retains holds the origin list's set and the sets that sign p and
    /// p + 1, whatever descendants an observation read: here generation zero's origin keys, each
    /// at power 1, which sign every height of the default fixture.
    #[tokio::test]
    async fn the_retained_start_holds_the_initial_set() {
        let source = TrackingSource::new(Fixture::new(18, 30));
        let b = source.builder(1);
        let snapshot = source.fixture().snapshot.clone();
        b.validate_checkpoint(&snapshot).await.unwrap();
        b.observe(&snapshot).await.unwrap();
        let start = b.checkpoint(&snapshot).await.unwrap();
        let origin = &source.fixture().committees[&0].validators;
        assert_eq!(&start.origin, origin);
        assert_eq!(start.parent_signers.as_ref(), Some(origin));
        assert_eq!(&start.signers, origin);
        assert_eq!(source.list_reads.load(Ordering::Relaxed), 1);
    }

    /// Generation zero's initial set is the list whose hash its origin record holds, each key at
    /// power 1, not the one slot 278 names after a later `setFallbackKeys`: the list comes by
    /// the hash the origin record holds.
    #[tokio::test]
    async fn initial_set_is_the_origin_list_at_power_one() {
        let fixture = Fixture::new(18, 30);
        let expected = Validators::from_powers(&fixture.origin_keys.validator_set()).unwrap();
        assert!(fixture.origin_keys.validator_set().iter().all(|(_, power)| *power == 1));
        let source = TrackingSource::new(fixture);
        let snapshot = source.fixture().snapshot.clone();
        let start = source.builder(1).checkpoint(&snapshot).await.unwrap();
        assert_eq!(start.origin.hash(), expected.hash());
        assert_eq!(start.origin.total_voting_power(), 2);
    }

    /// The batch takes generation zero's origin hash from origin word 4, never from slot 278:
    /// after a later `setFallbackKeys` moved slot 278 to another list, the starting proof under a
    /// later header and the snapshot still name the origin list, whose keys form the initial set.
    #[tokio::test]
    async fn snapshot_takes_the_origin_hash_from_origin_word_4() {
        use abci::l1::layout::inbox;
        let other = crate::test_utils::consensus::fallback_keys(&[
            crate::test_utils::consensus::SigningKey::from_slice(&[7; 32]).unwrap(),
        ]);
        let mut fixture = Fixture::new(18, 30);
        fixture.fallback_lists.insert(other.hash(), other.clone());
        let origin = fixture.origin_keys.clone();
        let moved = [(inbox::slot(278), other.hash().into())];
        let number = fixture.anchors[&18].number;
        let witness = fixture.starting_witness_with_inbox_words(number, moved);
        let (_, record) =
            crate::l1::verify_starting_inbox(&witness, &witness.l1_header, 0, fixture.params.inbox)
                .unwrap();
        assert_eq!(record.fallback_keys_hash, origin.hash());

        let snapshot = fixture.snapshot_with_inbox_words(moved);
        crate::l1::authenticate_snapshot(&snapshot, &fixture.params).unwrap();
        assert_eq!(
            crate::l1::snapshot_origin(&snapshot).unwrap().fallback_keys_hash,
            origin.hash()
        );
        let anchor = fixture.anchors[&18].clone();
        let source = TrackingSource::new(fixture);
        let (keys, validators) = source.builder(1).origin_set(&snapshot, &anchor).await.unwrap();
        let expected = Validators::from_powers(&origin.validator_set()).unwrap();
        assert_eq!(keys, origin);
        assert_eq!(validators.hash(), expected.hash());
    }

    /// A recovery generation's initial set is the origin record's fallback keys, each at power
    /// 1, obtained once by the origin's hash: building the start again reads no list.
    #[tokio::test]
    async fn origin_list_is_read_once_by_its_hash() {
        let recovered = crate::test_utils::consensus_mpt::recovery::fixture(8, 12, 18).await;
        let source = TrackingSource::new(recovered);
        let b = source.builder(18);
        let snapshot = source.fixture().snapshot.clone();
        let keys = crate::test_utils::consensus_mpt::recovery::origin_keys();
        let expected = Validators::from_powers(&keys.validator_set()).unwrap();
        let start = b.checkpoint(&snapshot).await.unwrap();
        assert_eq!(start.origin.hash(), expected.hash());
        *b.checkpoint_cache.lock().await = None;
        let rebuilt = b.checkpoint(&snapshot).await.unwrap();
        assert_eq!(rebuilt.origin.hash(), expected.hash());
        assert_eq!(source.fixture().fallback_reads.load(Ordering::SeqCst), 1);
    }

    /// The origin hash comes from the origin record the snapshot authenticates: a snapshot
    /// naming another hash is refused before any list is read.
    #[tokio::test]
    async fn the_snapshot_binds_the_origin_list_hash() {
        let recovered = crate::test_utils::consensus_mpt::recovery::fixture(8, 12, 18).await;
        let source = TrackingSource::new(recovered);
        let mut snapshot = source.fixture().snapshot.clone();
        snapshot.recovery.as_mut().unwrap().fallback_keys_hash = B256::repeat_byte(0x99);
        let result = source.builder(18).validate_checkpoint(&snapshot).await;
        assert!(
            matches!(&result, Err(LanderError::Safety(message)) if message.contains("recovery origin")),
            "{:?}",
            result.err()
        );
        assert_eq!(source.fixture().fallback_reads.load(Ordering::SeqCst), 0);
    }

    /// An origin list the L1 cannot give leaves the batch temporarily unbuildable, never a
    /// safety fault.
    #[tokio::test]
    async fn an_unavailable_origin_list_leaves_the_start_temporary() {
        let mut recovered = crate::test_utils::consensus_mpt::recovery::fixture(8, 12, 18).await;
        recovered.fallback_lists.clear();
        let source = TrackingSource::new(recovered);
        let snapshot = source.fixture().snapshot.clone();
        let result = source.builder(18).checkpoint(&snapshot).await;
        assert!(matches!(result, Err(LanderError::Temporary(_))), "{:?}", result.err());
    }

    /// A later observation resolves the tip's anchor from the tip an earlier one resolved, so
    /// each poll reads the blocks decided since rather than walking back to the anchor's move
    /// (block 23 here).
    #[tokio::test]
    async fn a_repeated_observation_reuses_the_resolved_tip_anchor() {
        let source = TrackingSource::new(Fixture::new(18, 30));
        let b = source.builder(1);
        let snapshot = source.fixture().snapshot.clone();
        let first = b.observe(&snapshot).await.unwrap();
        // At least the one-block prefix and the walk back from block 30 to block 23.
        assert!(source.block_reads.swap(0, Ordering::Relaxed) > 8);
        assert_eq!(b.observe(&snapshot).await.unwrap().observation, first.observation);
        // The one-block prefix and the remembered tip.
        assert_eq!(source.block_reads.load(Ordering::Relaxed), 2);
    }

    /// A snapshot whose generation, genesis or configuration differs never reuses the start
    /// retained for the original, which stays retained.
    #[tokio::test]
    async fn cached_context_cannot_outlive_generation_genesis_or_bootstrap_identity() {
        for mutation in 0..3 {
            let source = TrackingSource::new(Fixture::new(24, 30));
            let b = source.builder(6);
            let snapshot = source.fixture().snapshot.clone();
            b.validate_checkpoint(&snapshot).await.unwrap();
            let mut changed = snapshot.clone();
            match mutation {
                0 => changed.generation += 1,
                1 => changed.genesis.max_anchor_age += 1,
                2 => changed.config_hash = alloy_primitives::B256::ZERO,
                _ => unreachable!(),
            }
            assert!(matches!(b.validate_checkpoint(&changed).await, Err(LanderError::Safety(_))));
            let reads = source.history_reads.load(Ordering::Relaxed);
            b.validate_checkpoint(&snapshot).await.unwrap();
            assert_eq!(source.history_reads.load(Ordering::Relaxed), reads, "mutation {mutation}");
            // The checkpoint's own extraData names generation zero, so no start is built for
            // another generation either.
            if mutation == 0 {
                assert!(matches!(b.checkpoint(&changed).await, Err(LanderError::Safety(_))));
            }
        }
    }

    fn limits(blocks: usize) -> Limits {
        Limits {
            max_blocks: blocks,
            max_blobs: 2,
            max_payload_bytes: 240_000,
            max_message_bytes: 200_000,
            max_decompressed_bytes: 2_000_000,
        }
    }
    fn builder(fixture: Arc<Fixture>, limits: Limits) -> BatchBuilder<Fixture, Fixture> {
        builder_with(fixture, limits, MAX_BATCH_BLOCKS)
    }

    /// A builder over `fixture` that read `max_batch_blocks` from the Inbox at startup.
    fn builder_with(
        fixture: Arc<Fixture>,
        limits: Limits,
        max_batch_blocks: u64,
    ) -> BatchBuilder<Fixture, Fixture> {
        BatchBuilder::new(
            fixture.clone(),
            fixture.clone(),
            crate::batch::BatchBuilderConfig {
                params: fixture.params.clone(),
                limits,
                mode: SidecarMode::Eip4844,
                engine: std::sync::Arc::new(test_harness::unavailable_engine::UnavailableEngine),
                engine_timeout: std::time::Duration::from_secs(1),
                max_batch_blocks,
            },
        )
        .unwrap()
    }

    /// A landing may end at any height (LAND-6.1-5): the cap is the lower limit, down to one
    /// block, with no rounding.
    #[test]
    fn batch_cap_is_the_lower_limit() {
        assert_eq!(batch_cap(16, u64::MAX).unwrap(), 16);
        assert_eq!(batch_cap(100, 120).unwrap(), 100);
        assert_eq!(batch_cap(100, 13).unwrap(), 13);
        assert_eq!(batch_cap(7, 120).unwrap(), 7);
        assert_eq!(batch_cap(1, 1).unwrap(), 1);
        for (max_blocks, max_batch_blocks) in [(0, 120), (100, 0), (0, 0)] {
            assert!(
                matches!(
                    batch_cap(max_blocks, max_batch_blocks),
                    Err(LanderError::Configuration(_))
                ),
                "{max_blocks} configured, {max_batch_blocks} deployed"
            );
        }
    }

    /// A minimum the batch cap can reach starts; one above it, which the configuration's own
    /// `min_blocks <= max_blocks` check lets through when the Inbox's `maxBatchBlocks` is lower,
    /// is refused.
    #[test]
    fn a_min_blocks_above_the_batch_cap_is_refused() {
        for (min_blocks, max_blocks, max_batch_blocks) in
            [(12, 12, u64::MAX), (1, 1, 1), (13, 100, 13), (100, 100, 120)]
        {
            let cap = batch_cap(max_blocks, max_batch_blocks).unwrap();
            assert!(check_min_blocks(min_blocks, cap).is_ok(), "{min_blocks} below cap {cap}");
        }
        for (min_blocks, max_blocks, max_batch_blocks) in
            [(2, 2, 1), (14, 100, 13), (24, 24, 18), (101, 120, 100)]
        {
            assert!(min_blocks <= max_blocks, "the configuration check alone allows it");
            let cap = batch_cap(max_blocks, max_batch_blocks).unwrap();
            assert!(
                matches!(
                    check_min_blocks(min_blocks, cap),
                    Err(LanderError::Configuration(reason))
                        if reason.contains(&format!("{min_blocks} exceed the {cap}-block batch cap"))
                ),
                "{min_blocks} above cap {cap}"
            );
        }
    }

    /// A cap whose batches always journal starts; a larger one is refused at startup, whatever
    /// the reason the cap is that large, unless the Inbox's `maxBatchBlocks` lowers it.
    #[test]
    fn a_batch_cap_beyond_the_journal_is_refused() {
        let most = MAX_REQUEST_HEIGHTS as usize;
        assert!(most >= 300, "{most}");
        assert_eq!(batch_cap(most, u64::MAX).unwrap(), most);
        assert_eq!(batch_cap(usize::MAX, 1_000).unwrap(), 1_000);
        for (max_blocks, max_batch_blocks) in [(most + 1, u64::MAX), (usize::MAX, u64::MAX)] {
            let error = batch_cap(max_blocks, max_batch_blocks).unwrap_err();
            assert!(
                matches!(&error, LanderError::Configuration(reason)
                    if reason.contains(&format!("set --max-blocks to at most {most}"))),
                "{error}"
            );
        }
    }

    /// Selection stops adding heights before they would journal beyond the heights budget,
    /// each counted at the most it can add, and a first height that cannot fit is a capacity
    /// error naming it. A request that would journal beyond the request budget is refused before
    /// any proof.
    #[tokio::test]
    async fn selection_stops_before_the_request_would_outgrow_the_journal() {
        let fixture = Arc::new(Fixture::new(0, 6));
        let cost = |height: u64| height_request_bytes(&fixture.blocks[&height]);
        let three = cost(1) + cost(2) + cost(3);
        for (budget, expected) in [(three, 3), (three + cost(4) - 1, 3), (three + cost(4), 4)] {
            let b = builder(fixture.clone(), limits(6)).with_request_budgets(budget, u64::MAX);
            let preview = b.observe(&fixture.snapshot).await.unwrap();
            assert_eq!(preview.observation.publishable_blocks, expected, "budget {budget}");
            let request = b.prepare_observed(fixture.snapshot.clone(), preview).await.unwrap();
            let last = request.unwrap().batch.input.lastHeight;
            assert_eq!(last, U256::from(expected), "budget {budget}");
        }
        let b = builder(fixture.clone(), limits(6)).with_request_budgets(cost(1) - 1, u64::MAX);
        let error = b.prepare(fixture.snapshot.clone()).await.unwrap_err();
        assert!(
            matches!(&error, LanderError::Capacity(reason) if reason.contains("block 1 can add")),
            "{error}"
        );

        let request = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        let journaled = request_bytes(&request).unwrap();
        assert_eq!(journaled, serde_json::to_vec(&request).unwrap().len() as u64);
        for (budget, fits) in [(journaled, true), (journaled - 1, false)] {
            let b = builder(fixture.clone(), limits(6)).with_request_budgets(u64::MAX, budget);
            let prepared = b.prepare(fixture.snapshot.clone()).await;
            match prepared {
                Ok(Some(prepared)) if fits => assert_eq!(prepared, request),
                Err(LanderError::Capacity(reason)) if !fits => assert!(
                    reason
                        .contains(&format!("would journal {journaled} bytes, beyond the {budget}")) &&
                        reason.contains("lower --max-blocks below 6"),
                    "{reason}"
                ),
                other => panic!("budget {budget}: {other:?}"),
            }
        }
    }

    /// A request of 300 blocks, the average batch of the 4 s block and 20 min landing operating
    /// targets, journals within the bound with every witness at its largest: 128 seat words at
    /// each height of (p, h), a 128-key fallback key list for each of the 300 decisions,
    /// 128-member sets of p and p + 1, header(p), and p's staking proof of the 258 snapshot and
    /// 128 seat slots, each proof a path of 65 full branch nodes. Each height adds at most
    /// [`MAX_HEIGHT_REQUEST_BYTES`] besides its block and commit protobufs, the parts that do not
    /// grow with the heights stay within [`REQUEST_FIXED_BYTES`], and the whole request fits
    /// [`MAX_REQUEST_BYTES`] with the private block and commit witnesses at their whole budget.
    #[test]
    fn request_of_300_blocks_stays_under_the_journal_bound() {
        use crate::test_utils::{
            consensus::{committee, fallback_keys, pair},
            consensus_mpt::seed_key,
            protocol,
            runtime::leaves,
        };
        /// A request of `count` blocks with every witness at its largest.
        fn worst(count: u64) -> ProofRequest {
            let mut request = protocol::request();
            let batch = &mut request.batch;
            let (_, signers, keys) = committee(&[3, 3, 3]);
            let mut parent = batch.snapshot.checkpoint_hash;
            for height in 1..=count {
                let block = pair(height, parent, &signers, &keys, batch.blocks.last());
                let envelope = abci::EtnaEnvelope::decode(&block.block.data[0]).unwrap();
                parent = envelope.block.header.hash_slow();
                batch.blocks.push(block);
            }
            let header = batch.blocks[0].block_proto().unwrap().header.unwrap();
            batch.header_p = Some(Bytes::from(header.encode_to_vec()));
            batch.leaves = leaves(&batch.blocks);
            batch.anchors = vec![batch.parent_anchor.clone(); count as usize];
            batch.commit_heights = (1..=count).collect();
            batch.input.lastHeight = U256::from(count);

            let list = fallback_keys(&(1..=128).map(seed_key).collect::<Vec<_>>());
            let power = abci::committee::MAX_TOTAL_POWER / 128;
            let set = list.keys().iter().map(|key| (*key, power)).collect::<Vec<_>>();
            // A full branch node: 16 child hashes and an empty value under a three-byte header.
            let path = vec![Bytes::from(vec![0xff; 532]); 65];
            let seats = [Address::repeat_byte(0xff); 128];
            batch.staking_at_p = Some(AccountWitness {
                address: Address::repeat_byte(0xff),
                nonce: u64::MAX,
                balance: U256::MAX,
                storage_root: B256::repeat_byte(0xff),
                code_hash: B256::repeat_byte(0xff),
                account_proof: path.clone(),
                storage: crate::l1::staking_slots(&seats)
                    .into_iter()
                    .map(|slot| abci::StorageProof { slot, value: U256::MAX, proof: path.clone() })
                    .collect(),
            });
            batch.staking_reads = (1..count)
                .map(|height| HeightReads {
                    height,
                    values: vec![U256::MAX; abci::staking::SNAPSHOT_SLOT_COUNT],
                    seat_words: seats.iter().map(|address| (*address, U256::MAX)).collect(),
                })
                .collect();
            batch.fallback_key_lists = vec![list.clone(); count as usize];
            batch.origin_fallback_keys = list;
            batch.validators_p = Some(set.clone());
            batch.validators_p1 = Some(set);
            request
        }
        // The bytes of `request` besides its block and commit protobufs.
        let witness_bytes = |request: &ProofRequest| {
            let protobufs = request
                .batch
                .blocks
                .iter()
                .map(|pair| height_request_bytes(pair) - MAX_HEIGHT_REQUEST_BYTES);
            request_bytes(request).unwrap() - protobufs.sum::<u64>()
        };
        let (one, many) = (worst(1), worst(300));
        let per_height = (witness_bytes(&many) - witness_bytes(&one)).div_ceil(299);
        assert!(per_height <= MAX_HEIGHT_REQUEST_BYTES, "a height adds {per_height} bytes");
        let fixed = witness_bytes(&one) - per_height;
        assert!(fixed <= REQUEST_FIXED_BYTES, "the fixed parts take {fixed} bytes");
        let whole =
            request_bytes(&many).unwrap() + journaled_bytes(codec::MAX_PRIVATE_BYTES as u64);
        assert!(whole <= MAX_REQUEST_BYTES, "a 300-block request journals {whole} bytes");
    }

    /// However many blocks `--max-blocks` allows, observation and selection never exceed the
    /// deployed Inbox's `maxBatchBlocks`, so a landing never reverts `BatchTooLarge`.
    #[tokio::test]
    async fn selection_never_exceeds_the_deployed_max_batch_blocks() {
        let fixture = Arc::new(Fixture::new(0, 18));
        for (max_batch_blocks, expected) in [(120, 18), (17, 17), (12, 12), (7, 7), (1, 1)] {
            let builder = builder_with(fixture.clone(), limits(18), max_batch_blocks);
            let observed = builder.observe(&fixture.snapshot).await.unwrap();
            assert_eq!(
                observed.observation.publishable_blocks, expected,
                "maxBatchBlocks {max_batch_blocks}"
            );
            let batch = builder.prepare(fixture.snapshot.clone()).await.unwrap().unwrap().batch;
            assert_eq!(batch.blocks.len(), expected, "maxBatchBlocks {max_batch_blocks}");
            assert_eq!(batch.input.lastHeight, U256::from(expected));
        }
    }

    /// An Inbox whose `maxBatchBlocks` dropped below the selection since startup refuses the
    /// batch before it is proved, so a restart can select under the new value.
    #[tokio::test]
    async fn a_lowered_max_batch_blocks_refuses_the_batch_before_proving() {
        let source = TrackingSource::new(Fixture::new(0, 18));
        let builder = source.builder(18);
        let snapshot = source.fixture().snapshot.clone();
        source.max_batch_blocks.store(12, Ordering::Relaxed);
        assert!(matches!(
            builder.prepare(snapshot).await,
            Err(LanderError::Configuration(reason)) if reason.contains("maxBatchBlocks")
        ));
    }

    /// `--land-to h` ends the batch exactly at h, also below the decided tip and at the full cap,
    /// with the leaves of (p, h) (LAND-6.1-7). Below a decided h it waits; an h at or below the
    /// checkpoint p, or more than the batch cap above it, is refused.
    #[tokio::test]
    async fn land_to_ends_the_batch_exactly_at_its_height_or_refuses() {
        let fixture = Arc::new(Fixture::new(18, 30));
        let snapshot = &fixture.snapshot;
        for end in [19, 23, 30] {
            let exact = builder(fixture.clone(), limits(12)).with_land_to(Some(end));
            assert_eq!(exact.land_to(), Some(end));
            let preview = exact.observe(snapshot).await.unwrap();
            assert_eq!(preview.observation.publishable_blocks as u64, end - 18, "end {end}");
            let batch =
                exact.prepare_observed(snapshot.clone(), preview).await.unwrap().unwrap().batch;
            assert_eq!(batch.input.parentHeight, U256::from(18));
            assert_eq!(batch.input.lastHeight, U256::from(end));
            assert_eq!(batch.blocks.len() as u64, end - 18);
            assert_eq!(batch.leaves.len() as u64, end - 19);
            // The terminal block is h, not the decided tip.
            let last = batch.blocks.last().unwrap();
            assert_eq!(last.block.header.height.value(), end);
        }
        // The decided tip 30 is below h = 31: nothing to land yet.
        let waiting = builder(fixture.clone(), limits(13)).with_land_to(Some(31));
        let preview = waiting.observe(snapshot).await.unwrap();
        assert_eq!(preview.observation.publishable_blocks, 0);
        assert!(waiting.prepare(snapshot.clone()).await.unwrap().is_none());
        for (end, max_blocks, max_batch_blocks, reason) in [
            (18, 12, MAX_BATCH_BLOCKS, "already at or above --land-to 18"),
            (17, 12, MAX_BATCH_BLOCKS, "already at or above --land-to 17"),
            (31, 12, MAX_BATCH_BLOCKS, "13 blocks above the latest checkpoint 18, beyond the 12"),
            (26, 18, 7, "8 blocks above the latest checkpoint 18, beyond the 7"),
        ] {
            let refused = builder_with(fixture.clone(), limits(max_blocks), max_batch_blocks)
                .with_land_to(Some(end));
            for error in [
                refused.observe(snapshot).await.unwrap_err(),
                refused.prepare(snapshot.clone()).await.unwrap_err(),
            ] {
                assert!(
                    matches!(&error, LanderError::Configuration(r) if r.contains(reason)),
                    "--land-to {end}: {error}"
                );
            }
        }
    }

    /// An exact end whose blocks do not all fit one batch is a capacity error, not a shorter
    /// batch.
    #[tokio::test]
    async fn land_to_beyond_the_payload_capacity_is_refused() {
        let fixture = Arc::new(Fixture::new(0, 6));
        let first = codec::encode(&[fixture.blocks[&1].clone()], &limits(6)).unwrap();
        let mut bound = limits(6);
        bound.max_payload_bytes = first.len();
        let one = builder(fixture.clone(), bound).with_land_to(Some(1));
        let batch = one.prepare(fixture.snapshot.clone()).await.unwrap().unwrap().batch;
        assert_eq!(batch.input.lastHeight, U256::from(1));
        let three = builder(fixture.clone(), bound).with_land_to(Some(3));
        let error = three.observe(&fixture.snapshot).await.unwrap_err();
        assert!(
            matches!(&error, LanderError::Capacity(r) if r.contains("blocks 1..=3 do not fit")),
            "{error}"
        );
        assert!(matches!(
            three.prepare(fixture.snapshot.clone()).await,
            Err(LanderError::Capacity(_))
        ));
    }

    /// A batch start takes its base-fee grandparent timestamp from the header below the
    /// checkpoint, and the prepared batch round-trips through its journal form.
    #[tokio::test]
    async fn a_batch_start_keeps_the_grandparent_timestamp_and_round_trips() {
        for (checkpoint, tip) in [(6, 12), (12, 18)] {
            let fixture = Arc::new(Fixture::with_epoch(checkpoint, tip, 0, 12));
            let request = builder(fixture.clone(), limits(6))
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .unwrap();
            assert_eq!(
                request.batch.grandparent_timestamp,
                fixture.headers[&(checkpoint - 1)].timestamp
            );
            let restored: PreparedBatch =
                serde_json::from_slice(&serde_json::to_vec(&request.batch).unwrap()).unwrap();
            assert_eq!(restored, request.batch);
        }
    }

    /// The start reads the one header below the checkpoint, for the base-fee grandparent: a
    /// missing one is unavailable, and one that is not the checkpoint's parent is refused.
    #[tokio::test]
    async fn builder_and_observe_reject_missing_and_forged_required_history() {
        for mutation in 0..5 {
            let mut fixture = Fixture::new(24, 30);
            match mutation {
                0 => {
                    fixture.headers.remove(&23);
                }
                1 => fixture.headers.get_mut(&23).unwrap().number = 22,
                2 => {
                    fixture.headers.get_mut(&23).unwrap().parent_hash = alloy_primitives::B256::ZERO
                }
                3 => {
                    fixture.headers.get_mut(&23).unwrap().extra_data =
                        abci::rules::encode_extra_data(&abci::rules::ExtraData {
                            basefee_sharing_pctg: abci::rules::BASEFEE_SHARING_PCTG,
                            generation: 1,
                            anchor: 11,
                            miss_bitmap: 0,
                        })
                        .unwrap()
                }
                4 => {
                    fixture.headers.get_mut(&23).unwrap().parent_beacon_block_root =
                        Some(alloy_primitives::B256::ZERO)
                }
                _ => unreachable!(),
            }
            let fixture = Arc::new(fixture);
            for observation in [false, true] {
                let b = builder(fixture.clone(), limits(1));
                let error = if observation {
                    b.observe(&fixture.snapshot).await.unwrap_err()
                } else {
                    b.prepare(fixture.snapshot.clone()).await.unwrap_err()
                };
                if mutation == 0 {
                    assert!(matches!(error, LanderError::Unavailable(_)));
                    assert!(error.to_string().contains("height 23"));
                } else {
                    assert!(matches!(error, LanderError::Safety(_)), "{error}");
                }
            }
        }
    }

    /// A complete prefix is published whole, whatever checkpoint it starts at.
    #[tokio::test]
    async fn a_complete_prefix_is_published_whole() {
        for checkpoint in [18, 24, 30] {
            let fixture = Arc::new(Fixture::new(checkpoint, 36));
            let builder = builder(fixture.clone(), limits(20));
            let prefix = builder.publishable_prefix(&fixture.snapshot, 36).await.unwrap();
            assert_eq!(prefix.blocks.len(), (36 - checkpoint) as usize, "{checkpoint}");
        }
    }

    #[tokio::test]
    async fn no_freeze_only_publication_urgency() {
        for checkpoint in [24] {
            let fixture = Arc::new(Fixture::new(checkpoint, 30));
            let observed =
                builder(fixture.clone(), limits(20)).observe(&fixture.snapshot).await.unwrap();
            assert!(!observed.observation.force_back_pressure, "{checkpoint}");
        }
    }

    /// Observation verifies no certificate or envelope of a decided block past its publishable
    /// prefix, so such a block never stops the prefix from landing; `prepare` still refuses it
    /// once a batch includes it.
    #[tokio::test]
    async fn observe_does_not_verify_blocks_beyond_its_prefix() {
        let fixture = Arc::new(Fixture::new(18, 30));
        let observed =
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.observation.publishable_blocks, 1);
        assert_eq!(observed.observation.decided_height, 30);
        // Block 21 carries block 23's anchor witness, which its header does not name.
        let mut forged = Fixture::new(18, 30);
        let moved = abci::EtnaEnvelope::decode(&forged.blocks[&23].block.data[0]).unwrap().anchor;
        assert!(moved.is_some());
        alter_envelope(&mut forged, 21, |e| e.anchor = moved);
        let mut unsigned = Fixture::new(18, 30);
        unsigned.blocks.get_mut(&21).unwrap().commit.signatures.clear();
        for fixture in [forged, unsigned] {
            let fixture = Arc::new(fixture);
            assert_eq!(
                builder(fixture.clone(), limits(1))
                    .observe(&fixture.snapshot)
                    .await
                    .unwrap()
                    .observation,
                observed.observation
            );
            let prepared =
                builder(fixture.clone(), limits(12)).prepare(fixture.snapshot.clone()).await;
            assert!(matches!(prepared, Err(LanderError::Safety(_))), "{:?}", prepared.map(|_| ()));
        }
    }

    /// When the newest anchor witness past the prefix does not authenticate, the tip's unsettled
    /// depth is counted from the checkpoint's own anchor, which never undercounts it
    /// (BACKP-6.4-10): block 23 moves the anchor to an L1 state whose last checkpoint is 18, but
    /// its proof is forged, so the depth is 30 − 6 = 24 ≥ U − 1 instead of 30 − 18 = 12.
    #[tokio::test]
    async fn an_unauthenticated_tip_anchor_counts_pressure_from_the_checkpoint_anchor() {
        let mut fixture = Fixture::new(18, 30);
        alter_envelope(&mut fixture, 23, |e| {
            let witness = e.anchor.as_mut().expect("block 23 moves its anchor");
            witness.inbox.storage[0].value += U256::from(1);
        });
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.observation.publishable_blocks, 1);
        assert!(observed.observation.force_back_pressure);
    }

    /// An unavailable lookup above a remembered tip yields the checkpoint's anchor without
    /// forgetting that tip, so later polls still stop their walk there.
    #[tokio::test]
    async fn an_unavailable_lookup_keeps_the_remembered_tip() {
        let source = TrackingSource::new(Fixture::new(18, 30));
        let start = source.fixture().anchors[&18].clone();
        let b = source.builder(1);
        b.tip_anchor(&start, 18, 22).await.unwrap();
        assert_eq!(b.tip_anchor.lock().await.as_ref().map(|memo| memo.height), Some(22));
        source.canonical_unavailable.store(true, Ordering::Relaxed);
        assert_eq!(b.tip_anchor(&start, 18, 30).await.unwrap(), start);
        assert_eq!(b.tip_anchor.lock().await.as_ref().map(|memo| memo.height), Some(22));
        source.canonical_unavailable.store(false, Ordering::Relaxed);
        let moved = b.tip_anchor(&start, 18, 30).await.unwrap();
        assert!(moved.inbox.last_checkpoint_height > start.inbox.last_checkpoint_height);
        assert_eq!(b.tip_anchor.lock().await.as_ref().map(|memo| memo.height), Some(30));
    }

    #[tokio::test]
    async fn advisory_anchor_keeps_l1_errors_distinct_from_invalid_witnesses() {
        let source = TrackingSource::new(Fixture::new(18, 30));
        let fixture = source.fixture();
        let start = fixture.anchors[&18].clone();
        let envelope = abci::EtnaEnvelope::decode(&fixture.blocks[&23].block.data[0]).unwrap();
        let witness = envelope.anchor.unwrap();
        let b = source.builder(1);
        source.canonical_unavailable.store(true, Ordering::Relaxed);
        assert!(matches!(
            b.authenticated_anchor(&witness, &start).await,
            Err(LanderError::Temporary(_))
        ));
        assert_eq!(b.tip_anchor(&start, 18, 30).await.unwrap(), start);
        assert!(b.tip_anchor.lock().await.is_none(), "unavailable observations are not cached");
        source.canonical_unavailable.store(false, Ordering::Relaxed);
        source.canonical_failure.store(true, Ordering::Relaxed);
        assert!(matches!(b.tip_anchor(&start, 18, 30).await, Err(LanderError::Safety(_))));
        source.canonical_failure.store(false, Ordering::Relaxed);
        let recovered = b.tip_anchor(&start, 18, 30).await.unwrap();
        assert!(recovered.inbox.last_checkpoint_height > start.inbox.last_checkpoint_height);
    }

    /// The builder holds every block to the snapshot genesis's `maxAnchorAge`: block 1 of the
    /// fixture (101 s) uses anchor 10 (10 s), an anchor age of 91 s. Observation verifies no
    /// block, so preparation reports it.
    #[tokio::test]
    async fn a_block_with_an_anchor_older_than_the_genesis_maximum_age_is_rejected() {
        let fixture = Arc::new(Fixture::with_max_anchor_age(0, 6, 2000));
        builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();

        let fixture = Arc::new(Fixture::with_max_anchor_age(0, 6, 1251));
        let violation = abci::rules::RuleViolation::AnchorTooOld { age: 1252, max: 1251 };
        let b = builder(fixture.clone(), limits(6));
        assert_eq!(b.observe(&fixture.snapshot).await.unwrap().observation.publishable_blocks, 6);
        let error = b.prepare(fixture.snapshot.clone()).await.unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "{error}");
        assert!(error.to_string().contains(&violation.to_string()), "{error}");
    }

    /// The anchor witness the fixture's block `height` carries.
    fn carried_witness(fixture: &Fixture, height: u64) -> abci::AnchorWitness {
        abci::EtnaEnvelope::decode(&fixture.blocks[&height].block.data[0])
            .unwrap()
            .anchor
            .expect("the block carries its anchor witness")
    }

    /// The fixture's reference chain as the headers' L1 numbers, newest first.
    fn reference_numbers(request: &ProofRequest) -> Vec<u64> {
        request
            .batch
            .reference_headers
            .iter()
            .map(|raw| abci::RawL1Header::from_raw(raw.clone()).unwrap().number())
            .collect()
    }

    /// p = 22 uses anchor 11, which block 7 carried, and p + 1 moves to anchor 12. With a bound
    /// one header short of reaching 11 from the reference tip 14, the batch still lands: p's
    /// anchor comes from block 7's witness, checked against p's EL header, and stays off the
    /// reference chain, which reaches 12 only.
    #[tokio::test]
    async fn p_anchor_beyond_the_reference_bound_succeeds_when_p_plus_1_moves_the_anchor() {
        let mut fixture = Fixture::new(22, 30);
        assert_eq!((fixture.anchors[&22].number, fixture.anchors[&23].number), (11, 12));
        let tip = fixture.snapshot.l1_block_number - 1;
        fixture.reference_bound = tip - 11;
        let p_anchor = fixture.anchors[&22].clone();
        assert!(matches!(
            crate::l1::reference_floor(
                std::slice::from_ref(&p_anchor),
                tip,
                fixture.reference_bound
            ),
            Err(LanderError::Capacity(_))
        ));
        let fixture = Arc::new(fixture);
        let request = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(request.batch.parent_anchor, p_anchor);
        assert_eq!(request.batch.p_anchor_witness, Some(carried_witness(&fixture, 7)));
        assert!(request.batch.anchors.iter().all(|anchor| anchor.number == 12));
        assert_eq!(reference_numbers(&request), (12..=tip).rev().collect::<Vec<_>>());
        request.batch.verify_restored().unwrap();
        // The journal keeps p's anchor witness as its exact RLP.
        let journaled: crate::types::PreparedBatch =
            serde_json::from_slice(&serde_json::to_vec(&request.batch).unwrap()).unwrap();
        assert_eq!(journaled, request.batch);
    }

    /// p = 21 uses anchor 11 and p + 1 inherits it, so p's anchor is p + 1's and must reach the
    /// reference chain like every anchor of (p, h]: under the same bound the batch is refused for
    /// capacity, and one header more lets the chain reach 11.
    #[tokio::test]
    async fn inherited_p_anchor_beyond_the_bound_is_capacity() {
        let mut fixture = Fixture::new(21, 30);
        assert_eq!((fixture.anchors[&21].number, fixture.anchors[&22].number), (11, 11));
        let tip = fixture.snapshot.l1_block_number - 1;
        fixture.reference_bound = tip - 11;
        let capped = Arc::new(fixture);
        let error = builder(capped.clone(), limits(6))
            .prepare(capped.snapshot.clone())
            .await
            .expect_err("the inherited anchor lies beyond the bound");
        assert!(matches!(error, LanderError::Capacity(_)), "{error}");

        let mut fixture = Fixture::new(21, 30);
        fixture.reference_bound = tip - 11 + 1;
        let fixture = Arc::new(fixture);
        let request = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(request.batch.anchors[0], request.batch.parent_anchor);
        assert_eq!(reference_numbers(&request).last(), Some(&11));
    }

    /// p's anchor witness must prove the anchor p's `extraData` names, under the root p's
    /// `parentBeaconBlockRoot` names, in p's generation. p = 24 inherits anchor 12 from block
    /// 23; an own Comet node that serves block 23 with block 7's witness of anchor 11 stops the
    /// lander.
    #[tokio::test]
    async fn p_anchor_number_must_match_p_extra_data() {
        let fixture = Fixture::new(24, 30);
        let header = &fixture.headers[&24];
        let witness = carried_witness(&fixture, 23);
        let inbox = fixture.params.inbox;
        assert_eq!(
            crate::l1::verify_checkpoint_anchor(&witness, header, 0, inbox).unwrap(),
            fixture.anchors[&24]
        );
        let other = carried_witness(&fixture, 7);
        let mut moved = header.clone();
        let mut extra = rules::decode_extra_data(&header.extra_data).unwrap();
        extra.anchor = 11;
        moved.extra_data = rules::encode_extra_data(&extra).unwrap();
        let mut rooted = header.clone();
        rooted.parent_beacon_block_root = Some(fixture.anchors[&7].state_root);
        let mut regenerated = header.clone();
        let mut extra = rules::decode_extra_data(&header.extra_data).unwrap();
        extra.generation = 1;
        regenerated.extra_data = rules::encode_extra_data(&extra).unwrap();
        for (witness, header, why) in [
            (&other, header, "extraData names L1 12"),
            (&witness, &moved, "extraData names L1 11"),
            (&witness, &rooted, "parentBeaconBlockRoot"),
            (&witness, &regenerated, "another generation"),
        ] {
            let error = crate::l1::verify_checkpoint_anchor(witness, header, 0, inbox).unwrap_err();
            assert!(
                matches!(&error, LanderError::Safety(message) if message.contains(why)),
                "{why}: {error}"
            );
        }

        let mut served = fixture;
        let pair = served.blocks.get_mut(&23).unwrap();
        let mut envelope = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
        envelope.anchor = Some(other);
        pair.block.data[0] = envelope.encode().to_vec();
        let served = Arc::new(served);
        let error = builder(served.clone(), limits(6))
            .validate_checkpoint(&served.snapshot)
            .await
            .expect_err("block 23 serves another anchor's witness");
        assert!(
            matches!(&error, LanderError::Safety(message) if message.contains("extraData names L1 12")),
            "{error}"
        );
    }

    /// p = 24 uses anchor 12 and p + 1 inherits it, carrying no witness: p's witness is then
    /// checked against p + 1's EL header too, through p + 1's block rules, so a p + 1 whose
    /// `parentBeaconBlockRoot` or `extraData` anchor differs from it is refused.
    #[tokio::test]
    async fn inherited_witness_is_checked_against_p_plus_1() {
        let fixture = Arc::new(Fixture::new(24, 30));
        assert!(
            abci::EtnaEnvelope::decode(&fixture.blocks[&25].block.data[0])
                .unwrap()
                .anchor
                .is_none()
        );
        let request = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        let witness = request.batch.p_anchor_witness.clone().unwrap();
        assert_eq!(witness, carried_witness(&fixture, 23));
        assert_eq!(request.batch.anchors[0], request.batch.parent_anchor);
        assert_eq!(
            crate::l1::verify_checkpoint_anchor(
                &witness,
                &fixture.headers[&25],
                0,
                fixture.params.inbox
            )
            .unwrap(),
            request.batch.parent_anchor
        );

        let other_root = fixture.anchors[&7].state_root;
        for (change, why) in [(0, "parent_beacon_block_root"), (1, "anchor witness")] {
            let mut fixture = Fixture::new(24, 30);
            alter_envelope(&mut fixture, 25, |envelope| {
                let header = &mut envelope.block.header;
                if change == 0 {
                    header.parent_beacon_block_root = Some(other_root);
                } else {
                    let mut extra = rules::decode_extra_data(&header.extra_data).unwrap();
                    extra.anchor = 11;
                    header.extra_data = rules::encode_extra_data(&extra).unwrap();
                }
            });
            // A one-block batch: block 26 no longer links to the altered block 25.
            let fixture = Arc::new(fixture);
            let error = builder(fixture.clone(), limits(1))
                .prepare(fixture.snapshot.clone())
                .await
                .expect_err("p + 1 contradicts the anchor it inherits");
            assert!(
                matches!(&error, LanderError::Safety(message) if message.contains(why)),
                "{why}: {error}"
            );
        }
    }

    /// The configuration hash, the start record, slot 282 and the origin record are proven under
    /// the reference header, not under p's anchor: the proof carries the reference header and the
    /// starting slots, which hold no anchor slot, and a reference whose Inbox holds another value
    /// of any of them stops the batch.
    #[tokio::test]
    async fn origin_and_config_are_read_under_the_reference_root() {
        use abci::l1::layout::inbox;
        let fixture = Arc::new(Fixture::new(22, 30));
        let request = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        let reference =
            abci::RawL1Header::from_raw(request.batch.reference_headers[0].clone()).unwrap();
        let witness = &request.batch.starting_inbox_witness;
        assert_eq!(witness.l1_header, reference);
        let slots = witness.inbox.storage.iter().map(|proof| proof.slot).collect::<Vec<_>>();
        assert_eq!(slots, crate::l1::starting_slots(0));
        for slot in [
            inbox::LAST_CHECKPOINT_HEIGHT,
            inbox::LAST_CHECKPOINT_HASH,
            inbox::FALLBACK_KEYS_HASH,
            inbox::MIN_TOTAL_STAKE,
            inbox::FORCED_INCLUSION_HEAD_TAIL,
            inbox::RULES_SCHEDULE,
        ] {
            assert!(!slots.contains(&inbox::slot(slot)), "anchor slot {slot}");
        }
        let (genesis, origin) =
            crate::l1::verify_starting_inbox(witness, &reference, 0, fixture.params.inbox).unwrap();
        assert_eq!(genesis, fixture.snapshot.genesis);
        assert_eq!(origin, crate::l1::snapshot_origin(&fixture.snapshot).unwrap());
        // The same slots proven under p's anchor root do not stand in for the reference's.
        let p_anchor = fixture.l1_headers[&11].clone();
        let under_p = abci::AnchorWitness {
            inbox: fixture.import_witness(fixture.params.inbox, &slots, 11),
            l1_header: p_anchor.clone(),
        };
        crate::l1::verify_starting_inbox(&under_p, &p_anchor, 0, fixture.params.inbox).unwrap();
        assert!(
            crate::l1::verify_starting_inbox(&under_p, &reference, 0, fixture.params.inbox)
                .is_err()
        );

        let origin_hash = inbox::origin_slots(0)[3];
        let contradicts = "contradicts the snapshot";
        for (slot, value, why) in [
            (inbox::slot(inbox::CONFIG_HASH), U256::from(7), contradicts),
            (inbox::slot(inbox::START_BLOCK_HASH), U256::from(7), contradicts),
            (
                inbox::slot(inbox::FORCED_INCLUSION_CONFIG),
                U256::from(3_601) | U256::from(7_200) << 48,
                contradicts,
            ),
            (origin_hash, U256::from(7), contradicts),
            (inbox::slot(inbox::RECOVERY_GENERATION), U256::from(1), "in generation 1, not 0"),
        ] {
            let mut fixture = Fixture::new(22, 30);
            fixture.rewrite_inbox_at(reference.number(), [(slot, value)]);
            let fixture = Arc::new(fixture);
            let error = builder(fixture.clone(), limits(6))
                .prepare(fixture.snapshot.clone())
                .await
                .expect_err("the reference's Inbox contradicts the snapshot");
            assert!(
                matches!(&error, LanderError::Safety(message) if message.contains(why)),
                "slot {slot}: {error}"
            );
        }
    }

    #[tokio::test]
    async fn stale_operational_checkpoint_retries_before_any_decided_block_reads() {
        let mut fixture = Fixture::new(18, 41);
        fixture.blocks.clear();
        let fixture = Arc::new(fixture);
        for observe in [true, false] {
            let b = builder(fixture.clone(), limits(1));
            let error = if observe {
                b.observe(&fixture.snapshot).await.unwrap_err()
            } else {
                b.prepare(fixture.snapshot.clone()).await.unwrap_err()
            };
            assert!(
                matches!(error, LanderError::Temporary(_)),
                "stale coherent snapshot must retry: {error}"
            );
        }
    }

    #[tokio::test]
    async fn genesis_batch_binds_actual_proofs_committee_outputs_and_later_reference() {
        let fixture = Arc::new(Fixture::new(0, 6));
        let snapshot = fixture.snapshot.clone();
        let request = builder(fixture, limits(6)).prepare(snapshot).await.unwrap().unwrap();
        assert_eq!(request.batch.blocks.len(), 6);
        assert_eq!(request.batch.input.lastHeight, 6);
        assert_eq!(request.batch.input.l1ReferenceBlockNumber, 14);
        assert_eq!(request.batch.parent_anchor.number, 10);
        assert!(request.batch.anchors.iter().all(|anchor| anchor.number == 10));
        assert_eq!(
            codec::decode(
                &blob::decode(request.batch.blobs.sidecar.blobs(), &limits(6)).unwrap(),
                &limits(6)
            )
            .unwrap(),
            request
                .batch
                .blocks
                .iter()
                .map(|pair| codec::PublishedBlock::try_from(pair).unwrap())
                .collect::<Vec<_>>()
        );
    }

    /// A landing carries no validator state (PROOF-6.2-42), so validation, observation and
    /// preparation never query the app's `/val_state`, even while it refuses every height.
    #[tokio::test]
    async fn landing_never_queries_the_app_validator_state() {
        for (checkpoint, tip) in [(0, 12), (7, 13)] {
            let mut refusing = Fixture::new(checkpoint, tip);
            for height in 0..=tip {
                refusing.val_state_answers.insert(height, None);
            }
            let source = TrackingSource::new(refusing);
            let b = source.builder(12);
            let snapshot = source.fixture().snapshot.clone();
            b.validate_checkpoint(&snapshot).await.unwrap();
            b.observe(&snapshot).await.unwrap();
            let batch = b.prepare(snapshot).await.unwrap().unwrap().batch;
            assert_eq!(batch.input.lastHeight, U256::from(tip));
            batch.verify_restored().unwrap();
            assert_eq!(source.val_state_reads.load(Ordering::Relaxed), 0);
        }
    }

    /// Software lacking a selected ruleset pauses without treating certified history as invalid.
    #[tokio::test]
    async fn unsupported_inherited_ruleset_pauses_batch_authentication() {
        let fixture = Arc::new(Fixture::new(0, 6));
        let b = builder(fixture.clone(), limits(6));
        let snapshot = &fixture.snapshot;
        b.check_snapshot(snapshot).unwrap();
        let start = b.checkpoint(snapshot).await.unwrap();
        let mut state = ForwardState::new(&start, snapshot).unwrap();
        b.authenticate_block(snapshot, &mut state, &fixture.blocks[&1]).await.unwrap();
        // This method receives an already-authenticated inherited anchor. A future ruleset
        // changes no framing, and software support is checked before ruleset-zero predicates.
        state.anchor.inbox.rules_schedule = U256::from(1) << 48;
        let error =
            b.authenticate_block(snapshot, &mut state, &fixture.blocks[&2]).await.unwrap_err();
        assert!(matches!(error, LanderError::UnsupportedRuleset { rules: 1 }), "{error}");
        assert!(
            error.to_string().contains("ruleset 1") && error.to_string().contains("upgrade"),
            "{error}"
        );
        assert_eq!(state.parent.number, 1, "refusal never advances the authenticated state");
        let upgrade_retries = || {
            prometheus::gather()
                .into_iter()
                .find(|family| family.get_name() == "lander_retries_total")
                .and_then(|family| {
                    family
                        .get_metric()
                        .iter()
                        .find(|metric| {
                            metric.get_label().iter().any(|label| {
                                label.get_name() == "reason" &&
                                    label.get_value() == "unsupported_ruleset"
                            })
                        })
                        .map(|metric| metric.get_counter().get_value())
                })
                .unwrap_or(0.0)
        };
        let before = upgrade_retries();
        crate::metrics::LanderMetrics::retry(&error);
        assert!(
            upgrade_retries() >= before + 1.0,
            "upgrade waits have a distinct operational signal"
        );
    }

    /// Prepares the one batch `fixture` offers in batches of `blocks` blocks.
    async fn prepared(fixture: Fixture, blocks: usize) -> Result<Option<ProofRequest>> {
        let fixture = Arc::new(fixture);
        builder(fixture.clone(), limits(blocks)).prepare(fixture.snapshot.clone()).await
    }

    /// The batch carries one four-word leaf for every height strictly inside (18, 30), each from
    /// that block's EL hash, Comet hash and forced inclusion cursor.
    #[tokio::test]
    async fn leaves_cover_every_interior_height() {
        let fixture = Fixture::new(18, 30);
        let leaves: Vec<_> = (19..30)
            .map(|height| {
                statement::cut_leaf(
                    height,
                    fixture.headers[&height].hash_slow(),
                    B256::from_slice(fixture.blocks[&height].block.header.hash().as_bytes()),
                    0,
                )
            })
            .collect();
        let batch = prepared(fixture, 12).await.unwrap().unwrap().batch;
        assert_eq!(batch.input.lastHeight, U256::from(30));
        assert_eq!(batch.leaves, leaves);
        batch.verify_restored().unwrap();
    }

    /// A batch retains every authenticated block and binds its exact base fees, at any
    /// checkpoint.
    #[tokio::test]
    async fn prepared_batch_binds_execution_at_any_checkpoint() {
        for (checkpoint, tip) in [(0, 6), (18, 24), (24, 30)] {
            let fixture = Arc::new(Fixture::new(checkpoint, tip));
            let batch = builder(fixture.clone(), limits(6))
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .unwrap()
                .batch;
            assert_eq!(batch.input.lastHeight, tip);
            assert_eq!(batch.blocks.len(), (tip - checkpoint) as usize);
            assert!(
                batch.blocks.iter().all(|pair| abci::EtnaEnvelope::decode(&pair.block.data[0])
                    .unwrap()
                    .block
                    .header
                    .extra_data[0] ==
                    100)
            );
            batch.verify_restored().unwrap();
        }
    }

    /// CometBFT's `/commit` for a height can carry precommits that block `h + 1`'s canonical
    /// `last_commit` lacks; both certificates must independently satisfy quorum. With the two
    /// origin keys at power 1 each, a canonical `last_commit` without one of them is no quorum,
    /// and the batch is refused although height 25's `/commit` holds both precommits.
    #[tokio::test]
    async fn canonical_last_commit_is_verified_independently_of_the_seen_commit() {
        let mut fixture = Fixture::new(24, 30);
        let key = crate::test_utils::consensus::SigningKey::from_slice(&[2; 32]).unwrap();
        let pubkey = crate::test_utils::consensus::public_key(&key);
        let slot = fixture.committees[&0]
            .validators
            .validators()
            .iter()
            .position(|validator| validator.pub_key == pubkey)
            .unwrap();
        let seen = &fixture.blocks[&25].commit;
        assert!(matches!(
            seen.signatures[slot],
            crate::native::CommitSig::BlockIdFlagCommit { .. }
        ));
        let pair = fixture.blocks.get_mut(&26).unwrap();
        let last_commit = pair.block.last_commit.as_mut().unwrap();
        last_commit.signatures[slot] = crate::native::CommitSig::BlockIdFlagAbsent;
        pair.block.header.last_commit_hash = Some(crate::validate::commit_hash(last_commit));
        reseal_from(&mut fixture, 26);
        assert!(matches!(
            fixture.blocks[&25].commit.signatures[slot],
            crate::native::CommitSig::BlockIdFlagCommit { .. }
        ));

        let fixture = Arc::new(fixture);
        let error = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .expect_err("a canonical last_commit without quorum");
        assert!(
            matches!(&error, LanderError::Safety(message) if message.contains("insufficient commit power 1/2")),
            "{error}"
        );
    }

    #[tokio::test]
    async fn batch_input_and_statement_carry_the_stored_forced_head() {
        let fixture = Arc::new(Fixture::with_forced(
            6,
            12,
            crate::test_utils::consensus_mpt::ForcedPlan {
                entries: vec![(10, 5); 9],
                consume_at: vec![2, 3, 4],
                ..Default::default()
            },
        ));
        let snapshot = fixture.snapshot.clone();
        assert_eq!((snapshot.forced_inclusion_head, snapshot.forced_inclusion_tail), (3, 9));
        let request = builder(fixture, limits(6)).prepare(snapshot.clone()).await.unwrap().unwrap();
        let batch = &request.batch;
        assert_eq!(batch.input.forcedInclusionHead, U256::from(3));
        let reference = alloy_primitives::keccak256(&batch.reference_headers[0]);
        let preimage = statement::preimage(
            &snapshot,
            &batch.input,
            reference,
            &batch.blobs.versioned_hashes,
            &batch.leaves,
        );
        let three = U256::from(3).to_be_bytes::<32>();
        assert_eq!(&preimage[16 * 32..17 * 32], &three);
        assert_eq!(&preimage[17 * 32..18 * 32], &three);
        assert_eq!(batch.statement_hash, alloy_primitives::keccak256(preimage));
    }

    #[tokio::test]
    async fn chooses_whole_block_prefix_and_reports_oversized_first_height() {
        let fixture = Arc::new(Fixture::new(0, 6));
        let first = codec::encode(&[fixture.blocks[&1].clone()], &limits(6)).unwrap();
        let mut bound = limits(6);
        bound.max_payload_bytes = first.len();
        let request = builder(fixture.clone(), bound)
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .expect("block 1 alone fits");
        assert_eq!(request.batch.blocks.len(), 1);
        bound.max_payload_bytes = first.len() - 1;
        let error =
            builder(fixture.clone(), bound).prepare(fixture.snapshot.clone()).await.unwrap_err();
        assert!(matches!(error, LanderError::Capacity(_)));
        assert!(error.to_string().contains("block 1"));
    }

    #[tokio::test]
    async fn pruned_history_and_contract_statement_disagreement_never_yield_jobs() {
        let mut fixture = Fixture::new(18, 30);
        fixture.blocks.remove(&22);
        let fixture = Arc::new(fixture);
        let error = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Unavailable(_)));
        assert!(error.to_string().contains("height 22"));
        let fixture = Arc::new(Fixture::new(0, 6));
        fixture.mismatch_statement.store(true, Ordering::Relaxed);
        let error = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Configuration(_)), "{error}");
        assert!(error.to_string().contains("deployment configuration mismatch"), "{error}");
    }

    #[test]
    fn reference_chain_preserves_per_block_anchor_roots_and_requires_complete_ancestry() {
        let fixture = Fixture::new(18, 30);
        let anchors = vec![fixture.anchors[&20].clone(), fixture.anchors[&22].clone()];
        let headers =
            (11..=14).rev().map(|number| fixture.l1_headers[&number].clone()).collect::<Vec<_>>();
        verify_reference_chain(&headers, &anchors).unwrap();
        assert!(verify_reference_chain(&headers[..3], &anchors).is_err());
        let mut wrong = anchors.clone();
        wrong[1].state_root = alloy_primitives::B256::ZERO;
        assert!(verify_reference_chain(&headers, &wrong).is_err());
        let mut wrong = headers.clone();
        wrong.swap(0, 1);
        assert!(verify_reference_chain(&wrong, &anchors).is_err());
    }

    #[tokio::test]
    async fn prepare_refuses_a_fetched_reference_chain_that_breaks_ancestry() {
        // `reference` only fetches, so `prepare` is the single place the fetched links are
        // checked (PROOF-6.2-34). The reference tip is not an anchor, so the earlier
        // canonical-anchor checks still pass.
        let mut fixture = Fixture::new(24, 30);
        let tip = fixture.snapshot.l1_block_number - 1;
        assert!(fixture.anchors.values().all(|anchor| anchor.number != tip));
        let mut header: alloy_consensus::Header =
            alloy_rlp::decode_exact(fixture.l1_headers[&tip].raw()).unwrap();
        header.parent_hash = alloy_primitives::B256::ZERO;
        fixture.l1_headers.insert(tip, abci::RawL1Header::from(&header));
        let fixture = Arc::new(fixture);
        let error = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "{error}");
        assert!(
            error.to_string().contains("reference header ancestry is discontinuous"),
            "{error}"
        );
    }
    /// Rewrites one block's envelope, then reseals it and relinks every later block so the
    /// tampered history stays a consistently linked, genuinely signed chain. The fixture's EL
    /// keeps the rewritten header, at the same state root.
    fn alter_envelope(
        fixture: &mut Fixture,
        height: u64,
        change: impl FnOnce(&mut abci::EtnaEnvelope),
    ) {
        let pair = fixture.blocks.get_mut(&height).unwrap();
        let mut envelope = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
        change(&mut envelope);
        pair.block.header.app_hash = envelope.block.header.parent_hash.to_vec().try_into().unwrap();
        pair.block.data[0] = envelope.encode().to_vec();
        pair.block.header.data_hash = Some(crate::validate::data_hash(&pair.block.data));
        fixture.headers.insert(height, envelope.block.header);
        reseal_from(fixture, height);
    }

    /// Re-signs block `height` after a change to it, then relinks and re-signs every later block,
    /// each carrying its predecessor's new `/commit` as its `last_commit` and signed by the set
    /// that signs its height.
    fn reseal_from(fixture: &mut Fixture, height: u64) {
        let last = *fixture.blocks.keys().next_back().unwrap();
        for h in height..=last {
            if h > height {
                let previous = fixture.blocks[&(h - 1)].commit.clone();
                let pair = fixture.blocks.get_mut(&h).unwrap();
                pair.block.header.last_block_id = Some(previous.block_id);
                pair.block.header.last_commit_hash = Some(crate::validate::commit_hash(&previous));
                pair.block.last_commit = Some(previous);
            }
            let pair = fixture.blocks.get_mut(&h).unwrap();
            crate::test_utils::consensus::resign(
                pair,
                &fixture.signing_sets[&h],
                &fixture.signing_keys,
            );
        }
    }

    /// The starting Inbox proof under the reference header must prove every starting slot
    /// as stored: one without the configuration hash, or with another origin `fallbackKeysHash`,
    /// stops the batch.
    #[tokio::test]
    async fn starting_inbox_proofs_are_required_and_cannot_be_mutated() {
        for mutation in [0, 1] {
            let mut fixture = Fixture::new(24, 30);
            fixture.starting_proof_mutation = Some(mutation);
            let fixture = Arc::new(fixture);
            assert!(
                matches!(
                    builder(fixture.clone(), limits(6)).prepare(fixture.snapshot.clone()).await,
                    Err(LanderError::Safety(_))
                ),
                "starting checkpoint proof mutation {mutation} was accepted"
            );
        }
    }

    /// The checkpoint's next-set hash must name the set that signs p + 1, here the origin keys
    /// the Comet node archived for it; a header naming another set is refused.
    #[tokio::test]
    async fn checkpoint_next_validator_hash_must_name_the_initial_set() {
        let mut fixture = Fixture::with_epoch(24, 30, 0, 24);
        let (_, other, _) = crate::test_utils::consensus::committee(&[1]);
        assert_ne!(fixture.committees[&0].validators.hash(), other.validators.hash());
        let pair = fixture.blocks.get_mut(&24).unwrap();
        pair.block.header.next_validators_hash = other.validators.hash();
        let keys = vec![
            crate::test_utils::consensus::SigningKey::from_slice(&[1; 32]).unwrap(),
            crate::test_utils::consensus::SigningKey::from_slice(&[2; 32]).unwrap(),
        ];
        crate::test_utils::consensus::resign(pair, &fixture.committees[&0], &keys);
        fixture.snapshot.checkpoint_comet_hash =
            B256::from_slice(pair.block.header.hash().as_bytes());
        fixture.snapshot =
            fixture.snapshot_with_forced_queue(fixture.snapshot.genesis.clone(), 0, 0);
        fixture
            .l1_headers
            .insert(fixture.snapshot.l1_block_number, fixture.snapshot.l1_header.clone());
        let fixture = Arc::new(fixture);
        let error = builder(fixture.clone(), limits(6))
            .validate_checkpoint(&fixture.snapshot)
            .await
            .expect_err("the checkpoint's next hash names another set");
        assert!(error.to_string().contains("next validator hash"), "{error}");
    }

    #[tokio::test]
    async fn arbitrary_batch_cuts_reauthenticate_the_start_without_hints() {
        // Every prefix may end at any height.
        for (checkpoint, tip, last) in
            [(18, 30, 30), (24, 30, 30), (30, 35, 35), (18, 36, 36), (24, 36, 36)]
        {
            let fixture = Arc::new(Fixture::new(checkpoint, tip));
            let request = builder(fixture.clone(), limits(20))
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .unwrap();
            assert_eq!(request.batch.input.lastHeight, last);
            let headers = request
                .batch
                .reference_headers
                .iter()
                .map(|raw| abci::RawL1Header::from_raw(raw.clone()).unwrap())
                .collect::<Vec<_>>();
            assert!(headers.iter().all(|h| h.number() < request.batch.snapshot.l1_block_number));
            let witness = &request.batch.starting_inbox_witness;
            let (genesis, origin) =
                crate::l1::verify_starting_inbox(witness, &headers[0], 0, fixture.params.inbox)
                    .unwrap();
            assert_eq!(genesis, request.batch.snapshot.genesis);
            assert_eq!(origin.fallback_keys_hash, fixture.origin_keys.hash());
            assert_eq!(
                witness.inbox.storage.iter().map(|p| p.slot).collect::<Vec<_>>(),
                crate::l1::starting_slots(request.batch.snapshot.generation)
            );
            // The proof holds under the reference header only, not under an older L1 header with
            // another root.
            let older = &fixture.l1_headers[&10];
            assert_ne!(older.state_root(), headers[0].state_root());
            let mut moved = witness.clone();
            moved.l1_header = older.clone();
            assert!(
                crate::l1::verify_starting_inbox(&moved, older, 0, fixture.params.inbox).is_err()
            );
            assert!(
                crate::l1::verify_starting_inbox(witness, older, 0, fixture.params.inbox).is_err()
            );
        }
    }

    #[tokio::test]
    async fn snapshot_config_mutations_are_rejected() {
        for mutation in 0..4 {
            let fixture = Arc::new(Fixture::new(24, 30));
            let mut snapshot = fixture.snapshot.clone();
            match mutation {
                0 => snapshot.config_hash = alloy_primitives::B256::ZERO,
                1 => snapshot.genesis.config_hash = alloy_primitives::B256::ZERO,
                2 => snapshot.genesis.l1_0 += 1,
                3 => snapshot.inbox_witness.address = alloy_primitives::Address::ZERO,
                _ => unreachable!(),
            }
            assert!(
                builder(fixture.clone(), limits(6)).prepare(snapshot).await.is_err(),
                "Inbox binding mutation {mutation}"
            );
        }
    }

    /// Forced inclusion: the batch's blocks consume queue entries from the snapshot's Inbox head
    /// on, and the landing moves the head past the last one.
    mod forced {
        use super::*;
        use crate::test_utils::consensus_mpt::ForcedPlan;
        use abci::forced::ForcedError;

        /// The envelope of the batch's block at `position`.
        fn envelope(request: &ProofRequest, position: usize) -> abci::EtnaEnvelope {
            abci::EtnaEnvelope::decode(&request.batch.blocks[position].block.data[0]).unwrap()
        }

        /// The batch prepared over `fixture`'s snapshot with at most `blocks` blocks.
        async fn prepare(fixture: &Arc<Fixture>, blocks: usize) -> ProofRequest {
            builder(fixture.clone(), limits(blocks))
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .unwrap()
        }

        /// The forced inclusion heads before and after `request`'s batch, read from its statement
        /// preimage (0-based words 16 and 17 of the nineteen), which must hash to the statement
        /// and carry the input's.
        fn heads(request: &ProofRequest) -> (u64, u64) {
            let batch = &request.batch;
            let reference = alloy_primitives::keccak256(&batch.reference_headers[0]);
            let preimage = statement::preimage(
                &batch.snapshot,
                &batch.input,
                reference,
                &batch.blobs.versioned_hashes,
                &batch.leaves,
            );
            assert_eq!(batch.statement_hash, alloy_primitives::keccak256(preimage));
            let word = |index: usize| {
                alloy_primitives::U256::from_be_slice(&preimage[index * 32..(index + 1) * 32])
                    .to::<u64>()
            };
            assert_eq!(U256::from(word(17)), batch.input.forcedInclusionHead);
            (word(16), word(17))
        }

        /// Preparing the batch errors with a safety error naming `violation`; observation verifies
        /// no block and succeeds.
        async fn assert_safety(fixture: Fixture, violation: &str) {
            let fixture = Arc::new(fixture);
            let b = builder(fixture.clone(), limits(6));
            b.observe(&fixture.snapshot).await.unwrap();
            let error = b.prepare(fixture.snapshot.clone()).await.unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{error}");
            assert!(error.to_string().contains(violation), "{error}");
        }

        #[tokio::test]
        async fn batch_with_a_forced_block_sets_the_head_after_it() {
            // Entry 0 sits in the genesis anchor's queue: block 1 peeks at it, block 2 consumes it.
            let plan =
                ForcedPlan { entries: vec![(10, 5)], consume_at: vec![2], ..Default::default() };
            let fixture = Arc::new(Fixture::with_forced(0, 6, plan));
            let snapshot = &fixture.snapshot;
            assert_eq!((snapshot.forced_inclusion_head, snapshot.forced_inclusion_tail), (0, 1));
            for (blocks, head) in [(6, 1)] {
                let request = prepare(&fixture, blocks).await;
                assert_eq!(request.batch.blocks.len(), blocks);
                assert_eq!(heads(&request), (0, head), "{blocks} blocks");
            }
            let request = prepare(&fixture, 6).await;
            let peek = envelope(&request, 0).forced.unwrap();
            let consumed = envelope(&request, 1).forced.unwrap();
            assert_eq!((peek.index, peek.tx.is_empty()), (0, false));
            assert_eq!((consumed.index, consumed.tx.is_empty()), (0, false));
            assert_eq!(envelope(&request, 2).forced, None);

            // The start record must retain head zero even after an entry is admitted.
            let snapshot = fixture.snapshot_with_forced_queue(snapshot.genesis.clone(), 1, 1);
            let error = builder(fixture.clone(), limits(6)).prepare(snapshot).await.unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{error}");
            assert!(error.to_string().contains("invalid checkpoint landing record"), "{error}");

            // A later checkpoint may carry a nonzero head, but it cannot skip the entry that
            // the decided successor still witnesses and block 8 consumes.
            let fixture = Arc::new(Fixture::with_forced(
                6,
                12,
                ForcedPlan { entries: vec![(10, 5)], consume_at: vec![8], ..Default::default() },
            ));
            let snapshot =
                fixture.snapshot_with_forced_queue(fixture.snapshot.genesis.clone(), 1, 1);
            crate::l1::authenticate_snapshot(&snapshot, &fixture.params).unwrap();
            let error = builder(fixture, limits(6)).prepare(snapshot).await.unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{error}");
            assert!(
                error.to_string().contains(&ForcedError::UnexpectedWitness.to_string()),
                "{error}"
            );
        }

        /// The leaf of every interior height x carries the cursor after x (ENC-A-29): the leaf
        /// at `x - p - 1` of a block that consumes an entry mid-batch already counts it, so an
        /// overlapping landing whose checkpoint is x finds its record's head there.
        #[tokio::test]
        async fn interior_leaves_carry_the_cursor_after_a_consumed_entry() {
            let cases = [
                // From the origin: block 2 consumes entry 0.
                (0, 6, vec![(10, 5)], vec![2], 6, 2),
                // From checkpoint 18 at head 1: block 24 consumes entry 1.
                (18, 30, vec![(10, 1), (11, 2)], vec![5, 24], 12, 24),
            ];
            for (p, tip, entries, consume_at, blocks, consumed) in cases {
                let plan = ForcedPlan { entries, consume_at, ..Default::default() };
                let fixture = Arc::new(Fixture::with_forced(p, tip, plan));
                let head = fixture.snapshot.forced_inclusion_head;
                let request = prepare(&fixture, blocks).await;
                let leaves = &request.batch.leaves;
                assert_eq!(leaves.len(), blocks - 1);
                for (index, leaf) in leaves.iter().enumerate() {
                    let x = p + 1 + index as u64;
                    let cursor = head + u64::from(x >= consumed);
                    let expected = statement::cut_leaf(
                        x,
                        envelope(&request, index).block.header.hash_slow(),
                        B256::from_slice(
                            request.batch.blocks[index].block.header.hash().as_bytes(),
                        ),
                        cursor,
                    );
                    assert_eq!(*leaf, expected, "leaf of height {x} with cursor {cursor}");
                }
                assert_eq!(heads(&request), (head, head + 1));
            }
        }

        /// Review Focus 4: the cut starts while an entry is pending, so its first block peeks.
        #[tokio::test]
        async fn batch_starting_mid_pending_queue() {
            // Entry 0 (L1 10) is consumed at height 5, below the checkpoint 20; entry 1 (L1 11) is
            // still pending there, so blocks 21 to 23 peek at it and block 24 consumes it.
            let plan = ForcedPlan {
                entries: vec![(10, 1), (11, 2)],
                consume_at: vec![5, 24],
                ..Default::default()
            };
            let fixture = Arc::new(Fixture::with_forced(18, 30, plan));
            let snapshot = &fixture.snapshot;
            assert_eq!((snapshot.forced_inclusion_head, snapshot.forced_inclusion_tail), (1, 2));
            let request = prepare(&fixture, 6).await;
            // Continue through block 26 after consuming the forced entry.
            assert_eq!(request.batch.input.lastHeight, 24);
            let first = envelope(&request, 0).forced.unwrap();
            assert_eq!((first.index, first.tx.is_empty()), (1, false));
            let consumed = envelope(&request, 5).forced.unwrap();
            assert_eq!((consumed.index, consumed.tx.is_empty()), (1, false));
            assert_eq!(heads(&request), (1, 2));
            // Any capacity publishes its prefix: three blocks that only peek keep the head.
            let partial = prepare(&fixture, 3).await;
            assert_eq!(partial.batch.input.lastHeight, 21);
            assert_eq!(heads(&partial), (1, 1));
        }

        /// Review Focus 4: the cut's first block consumes the entry at the stored head.
        #[tokio::test]
        async fn batch_starting_with_forced_block() {
            // Entries 0 and 1 (L1 11) are pending at the checkpoint 20: block 21, the cut's first,
            // consumes entry 0, block 22 peeks at entry 1 and block 23 consumes it.
            let plan = ForcedPlan {
                entries: vec![(11, 1), (11, 2)],
                consume_at: vec![19, 21],
                ..Default::default()
            };
            let fixture = Arc::new(Fixture::with_forced(18, 30, plan));
            let snapshot = &fixture.snapshot;
            assert_eq!((snapshot.forced_inclusion_head, snapshot.forced_inclusion_tail), (0, 2));
            for (blocks, head) in [(6, 2), (12, 2)] {
                let request = prepare(&fixture, blocks).await;
                assert_eq!(heads(&request), (0, head), "{blocks} blocks");
            }
            let request = prepare(&fixture, 6).await;
            let first = envelope(&request, 0).forced.unwrap();
            assert_eq!((first.index, first.tx.is_empty()), (0, false));
            let peek = envelope(&request, 1).forced.unwrap();
            assert_eq!((peek.index, peek.tx.is_empty()), (1, false));

            // A stored head of 1 says entry 0 is settled, so block 21 consuming it is out of order.
            let snapshot = fixture.snapshot_with_forced_queue(snapshot.genesis.clone(), 1, 2);
            let error = builder(fixture.clone(), limits(6)).prepare(snapshot).await.unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{error}");
            let violation = ForcedError::WrongIndex { expected: 1, got: 0 };
            assert!(error.to_string().contains(&violation.to_string()), "{error}");
        }

        #[tokio::test]
        async fn omitted_preimages_preserve_pending_and_included_batch_cursors() {
            let plan = ForcedPlan {
                entries: vec![(11, 1), (11, 2)],
                consume_at: vec![19, 21],
                ..Default::default()
            };
            let mut fixture = Fixture::with_forced(18, 30, plan);
            for height in 19..=30 {
                alter_envelope(&mut fixture, height, |env| {
                    if let Some(witness) = &mut env.forced {
                        witness.tx = alloy_primitives::Bytes::new();
                    }
                });
            }
            let fixture = Arc::new(fixture);
            for (blocks, head) in [(6, 2), (12, 2)] {
                let request = prepare(&fixture, blocks).await;
                assert_eq!(heads(&request), (0, head));
                for pair in &request.batch.blocks {
                    let env = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
                    assert!(env.forced.is_none_or(|witness| witness.tx.is_empty()));
                }
            }
        }

        /// A forced inclusion block that also moves the anchor carries both witnesses, and both
        /// must verify.
        #[tokio::test]
        async fn anchor_moving_forced_block_lands() {
            // Entry 0 first appears in L1 12, the anchor block 23 moves to.
            let plan =
                ForcedPlan { entries: vec![(12, 3)], consume_at: vec![23], ..Default::default() };
            let forced = || Fixture::with_forced(18, 30, plan.clone());
            let fixture = Arc::new(forced());
            let request = prepare(&fixture, 6).await;
            let moving = envelope(&request, 4);
            assert_eq!(moving.block.header.number, 23);
            assert!(moving.anchor.is_some());
            let witness = moving.forced.unwrap();
            assert_eq!((witness.index, witness.tx.is_empty()), (0, false));
            assert_eq!(envelope(&request, 0).forced, None);
            assert_eq!(heads(&request), (0, 1));

            let mut fixture = forced();
            alter_envelope(&mut fixture, 23, |envelope| envelope.anchor = None);
            assert_safety(fixture, "anchor witness").await;
            let mut fixture = forced();
            alter_envelope(&mut fixture, 23, |envelope| {
                let witness = envelope.forced.as_mut().unwrap();
                let mut blob = witness.tx.to_vec();
                blob[0] ^= 1;
                witness.tx = blob.into();
            });
            assert_safety(fixture, "transaction hash").await;
        }

        #[tokio::test(start_paused = true)]
        async fn canonical_skip_requires_completed_empty_matching_singleton() {
            use test_harness::unavailable_engine::ProbeEngine;
            for mode in 0..18 {
                let plan = ForcedPlan { delay: 5, entries: vec![(10, 5)], consume_at: vec![1] };
                let mut fixture = Fixture::with_forced(0, 6, plan);
                alter_envelope(&mut fixture, 1, |env| {
                    env.block.transactions.clear();
                    env.block.header.transactions_root = alloy_consensus::EMPTY_ROOT_HASH;
                    if mode == 5 {
                        env.forced.as_mut().unwrap().tx = alloy_primitives::Bytes::new();
                    }
                });
                for height in 2..=6 {
                    let parent =
                        abci::EtnaEnvelope::decode(&fixture.blocks[&(height - 1)].block.data[0])
                            .unwrap()
                            .block
                            .header
                            .hash_slow();
                    alter_envelope(&mut fixture, height, |env| {
                        env.block.header.parent_hash = parent
                    });
                }
                let env = abci::EtnaEnvelope::decode(&fixture.blocks[&1].block.data[0]).unwrap();
                let mut result = env.block.clone();
                if mode == 1 {
                    result.transactions.push(env.forced.as_ref().unwrap().tx.clone());
                }
                if mode == 2 {
                    result.header.timestamp += 1;
                }
                let parent = fixture.headers[&0].clone();
                let fixture = Arc::new(fixture);
                let mut b = builder(fixture.clone(), limits(6));
                b.engine_timeout = Duration::from_millis(10);
                b.engine = Arc::new(ProbeEngine {
                    parent,
                    parent_reply: match mode {
                        14 => Some(Err(abci::EngineError::BadReply("bad header secret".into()))),
                        15 => Some(Err(abci::EngineError::ErrorReply {
                            call: "eth_getBlockByNumber secret".into(),
                            code: -32602,
                            message: "secret".into(),
                        })),
                        16 => Some(Err(abci::EngineError::ErrorReply {
                            call: "eth_getBlockByNumber secret".into(),
                            code: -32603,
                            message: "secret".into(),
                        })),
                        17 => Some(Err(abci::EngineError::ErrorReply {
                            call: "eth_getBlockByNumber secret".into(),
                            code: -38001,
                            message: "secret".into(),
                        })),
                        _ => None,
                    },
                    result: if mode == 7 {
                        Err(abci::EngineError::ErrorReply {
                            call: "engine_forkchoiceUpdatedV3 secret".into(),
                            code: -38100,
                            message: "secret".into(),
                        })
                    } else if mode == 8 {
                        Err(abci::EngineError::BuildNotStarted(abci::PayloadVerdict::Invalid(
                            "secret".into(),
                        )))
                    } else if mode == 9 {
                        Err(abci::EngineError::Setup("secret".into()))
                    } else if mode == 10 {
                        Err(abci::EngineError::BadReply("secret".into()))
                    } else if mode == 11 {
                        Err(abci::EngineError::ErrorReply {
                            call: "engine_getPayloadV5 secret".into(),
                            code: -38001,
                            message: "secret".into(),
                        })
                    } else if mode == 12 {
                        Err(abci::EngineError::BuildNotStarted(abci::PayloadVerdict::Syncing))
                    } else if mode == 13 {
                        Err(abci::EngineError::BuildNotStarted(abci::PayloadVerdict::Valid))
                    } else if mode == 3 {
                        Err(abci::EngineError::Transport("unavailable".into()))
                    } else if mode == 6 {
                        Err(abci::EngineError::ErrorReply {
                            call: "engine_getPayloadV5 at http://user-secret:pass-secret@el.test/path-secret?key=query-secret".into(),
                            code: -32603,
                            message: "upstream body-secret echoed path-secret".into(),
                        })
                    } else {
                        Ok(result)
                    },
                    delay: if mode == 4 { Duration::from_secs(1) } else { Duration::ZERO },
                });
                let prepared = b.prepare(fixture.snapshot.clone()).await;
                match mode {
                    0 => assert_eq!(heads(&prepared.unwrap().unwrap()), (0, 1)),
                    1 | 2 | 5 => assert!(matches!(prepared, Err(LanderError::Safety(_)))),
                    7..=10 | 14 | 15 | 17 => {
                        let error = prepared.unwrap_err();
                        assert!(matches!(error, LanderError::Safety(_)), "mode {mode}: {error}");
                        let text = error.to_string();
                        assert!(
                            text.contains("L2 1") &&
                                text.contains("entry 0") &&
                                text.contains("parent 0"),
                            "{text}"
                        );
                        assert!(!text.contains("secret"), "{text}");
                    }
                    _ => {
                        let error = prepared.unwrap_err();
                        assert!(matches!(error, LanderError::Temporary(_)));
                        let text = error.to_string();
                        assert!(
                            text.contains("L2 1") &&
                                text.contains("entry 0") &&
                                text.contains("parent 0"),
                            "{text}"
                        );
                        assert!(
                            text.contains(&fixture.headers[&0].hash_slow().to_string()),
                            "{text}"
                        );
                        if mode == 6 {
                            assert!(
                                text.contains("engine_getPayloadV5") && text.contains("-32603"),
                                "{text}"
                            );
                            for secret in [
                                "user-secret",
                                "pass-secret",
                                "path-secret",
                                "query-secret",
                                "body-secret",
                            ] {
                                assert!(!text.contains(secret), "{text}");
                            }
                        }
                    }
                }
            }
        }

        #[tokio::test]
        async fn batch_skipping_a_due_entry_is_a_safety_error() {
            // Delay 5 s: entry 0, submitted at 5 s, is due at the genesis anchor (L1 10, at 10 s).
            let due =
                |consume_at: Vec<u64>| ForcedPlan { delay: 5, entries: vec![(10, 5)], consume_at };
            let fixture = Arc::new(Fixture::with_forced(0, 6, due(vec![1])));
            assert_eq!(heads(&prepare(&fixture, 6).await), (0, 1));

            // Block 1 peeks at the due entry; block 2 consumes it too late.
            let absent = Arc::new(Fixture::with_forced(0, 6, due(vec![2])));
            let env = abci::EtnaEnvelope::decode(&absent.blocks[&1].block.data[0]).unwrap();
            let mut singleton = env.block.clone();
            singleton.transactions = vec![env.forced.unwrap().tx];
            singleton.header.transactions_root =
                alloy_trie::root::ordered_trie_root_encoded(&singleton.transactions);
            let mut b = builder(absent.clone(), limits(6));
            b.engine = Arc::new(test_harness::unavailable_engine::ProbeEngine {
                parent: absent.headers[&0].clone(),
                parent_reply: None,
                result: Ok(singleton),
                delay: Duration::ZERO,
            });
            let error = b.prepare(absent.snapshot.clone()).await.unwrap_err();
            assert!(
                matches!(&error, LanderError::Safety(reason) if reason.contains("singleton build retained a transaction")),
                "the due transaction could have been included in block 1: {error}"
            );
            // Block 1 carries no forced witness at all.
            let mut fixture = Fixture::with_forced(0, 6, due(vec![1]));
            alter_envelope(&mut fixture, 1, |envelope| envelope.forced = None);
            let violation = ForcedError::MissingWitness { index: 0 }.to_string();
            assert_safety(fixture, &violation).await;
        }
    }

    #[tokio::test]
    async fn checkpoint_certificate_authenticates_its_complete_envelope_body() {
        let mut fixture = Fixture::new(18, 30);
        let pair = fixture.blocks.get_mut(&18).unwrap();
        let mut envelope = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
        envelope
            .block
            .transactions
            .push(alloy_primitives::Bytes::from_static(b"forged checkpoint body"));
        pair.block.data[0] = envelope.encode().to_vec();
        // Its original header/certificate remain genuine; only the purported payload was replaced.
        crate::validate::verify_commit(
            &pair.commit,
            &pair.block.header,
            &fixture.committees[&0].validators,
            "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
        )
        .unwrap();
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(6)).validate_checkpoint(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
    }
    /// Per-height signing sets under 4.3: each block is signed by the set the chain decided two
    /// blocks earlier, the proof origin p's sets come from p's own header and post-state, and
    /// each block's `missBitmap` is the one its LastCommit and its parent's seats give.
    mod signing_sets {
        use super::*;
        use crate::{
            test_utils::{
                consensus::{fallback_keys, public_key},
                consensus_mpt::{
                    Missing, PlannedAnchorWords, SigningPlan, candidate_words, recovery, seed_key,
                    staking_words,
                },
            },
            types::HeightReads,
        };
        use abci::{fallback::FallbackKeys, key::ConsensusKey, staking};

        /// The key of seed `seed`.
        fn key(seed: u8) -> ConsensusKey {
            public_key(&seed_key(seed))
        }

        /// Slots 278 and 279 of every L1 state: the origin list's hash, and the minimum total
        /// stake `minimum` gives the state's block number.
        fn anchor_minimum(minimum: impl Fn(u64) -> U256 + 'static) -> PlannedAnchorWords {
            Box::new(move |number, origin| (origin.hash(), minimum(number)))
        }

        /// A minimum total stake of 1000 at L1 11, which anchors heights 7 to 22, and 2^256 − 1
        /// at every other L1 block.
        fn usable_at_11(number: u64) -> U256 {
            if number == 11 { U256::from(1000) } else { U256::MAX }
        }

        /// The validator set of `members`.
        fn set(members: &[(ConsensusKey, u64)]) -> Validators {
            Validators::from_powers(members).unwrap()
        }

        /// The default fixture candidate over the origin list `origin`: its key `i` at power
        /// `i + 1`.
        fn default_candidate(origin: &FallbackKeys) -> Vec<(ConsensusKey, u64)> {
            (1..).zip(origin.keys()).map(|(power, key)| (*key, power)).collect()
        }

        /// The candidate after `height` whose seat `i` holds origin key `i` at power
        /// `i + 1 + height`.
        fn growing_members(height: u64, origin: &FallbackKeys) -> Vec<(ConsensusKey, u64)> {
            (1..).zip(origin.keys()).map(|(power, key)| (*key, power + height)).collect()
        }

        /// The staking words of [`growing_members`], taken at `height`.
        fn growing_candidate(height: u64, origin: &FallbackKeys) -> Vec<(B256, U256)> {
            let members = growing_members(height, origin);
            candidate_words(U256::from(height), U256::from(1000 + height), &members)
        }

        /// The candidate snapshot `words` hold.
        fn snapshot_of(words: &[(B256, U256)]) -> staking::StakingWords {
            let words = words.iter().copied().collect::<BTreeMap<_, _>>();
            let values =
                staking::snapshot_slots().map(|slot| words.get(&slot).copied().unwrap_or_default());
            staking::StakingWords::from_snapshot_values(&values).unwrap()
        }

        /// The batch above `fixture`'s checkpoint, of at most `blocks` blocks.
        async fn batch(fixture: &Arc<Fixture>, blocks: usize) -> Result<PreparedBatch> {
            let request =
                builder(fixture.clone(), limits(blocks)).prepare(fixture.snapshot.clone()).await?;
            Ok(request.expect("blocks above the checkpoint").batch)
        }

        /// The forward state after the blocks above `fixture`'s checkpoint up to `to`.
        async fn forward_to(fixture: &Arc<Fixture>, to: u64) -> Result<ForwardState> {
            let b = builder(fixture.clone(), limits(20));
            let snapshot = &fixture.snapshot;
            let start = b.checkpoint(snapshot).await?;
            let mut state = ForwardState::new(&start, snapshot)?;
            for height in snapshot.checkpoint_height + 1..=to {
                b.authenticate_block(snapshot, &mut state, &fixture.blocks[&height]).await?;
            }
            Ok(state)
        }

        /// The `missBitmap` in block `height`'s `extraData`.
        fn header_bitmap(fixture: &Fixture, height: u64) -> u128 {
            rules::decode_extra_data(&fixture.headers[&height].extra_data).unwrap().miss_bitmap
        }

        /// The candidate signs 9 to 24, decided at 7 to 22 under L1 11's minimum total stake of
        /// 1000; the origin keys sign before and after, decided under the 2^256 − 1 of L1 10 and
        /// L1 12. Both switches are commit heights of the batch (6, 24]: 8 inside it, and its end
        /// 24, whose header names the origin keys as the next set. The batch (6, 8] ends on the
        /// first switch. A header naming the set the chain did not switch to is refused.
        #[tokio::test]
        async fn mode_switch_inside_a_batch_and_at_its_end() {
            let plan = || SigningPlan {
                anchor_words: anchor_minimum(usable_at_11),
                ..SigningPlan::default()
            };
            let fixture = Fixture::with_plan(6, 24, plan());
            let origin = fixture.committees[&0].validators.clone();
            let candidate = set(&default_candidate(&fixture.origin_keys));
            assert_ne!(origin, candidate);
            for (height, expected) in
                [(8, &origin), (9, &candidate), (24, &candidate), (25, &origin)]
            {
                assert_eq!(&fixture.signing_sets[&height].validators, expected, "height {height}");
            }
            let fixture = Arc::new(fixture);
            let whole = batch(&fixture, 18).await.unwrap();
            assert_eq!(whole.input.lastHeight, U256::from(24));
            assert_eq!(whole.commit_heights, [8, 24]);
            let first = batch(&fixture, 2).await.unwrap();
            assert_eq!(first.input.lastHeight, U256::from(8));
            assert_eq!(first.commit_heights, [8]);

            for height in [8, 24] {
                let mut forged = Fixture::with_plan(6, 24, plan());
                let unswitched = forged.signing_sets[&height].validators.hash();
                forged.blocks.get_mut(&height).unwrap().block.header.next_validators_hash =
                    unswitched;
                reseal_from(&mut forged, height);
                let error = batch(&Arc::new(forged), 18).await.unwrap_err();
                let reason = format!("next validator hash disagrees at height {height}");
                assert!(
                    matches!(&error, LanderError::Safety(message) if message.contains(&reason)),
                    "{error}"
                );
            }
        }

        /// Under a minimum total stake of 0 at every anchor, a candidate whose powers grow with
        /// the height signs every height from 3 on, each with a set of its own, so every height
        /// of a batch is a commit height; only the origin keys sign both 1 and 2.
        #[tokio::test]
        async fn power_change_at_every_height() {
            let plan = || SigningPlan {
                anchor_words: anchor_minimum(|_| U256::ZERO),
                staking: Box::new(growing_candidate),
                ..SigningPlan::default()
            };
            let fixture = Fixture::with_plan(18, 24, plan());
            for height in 3..=26 {
                let expected = growing_members(height - 2, &fixture.origin_keys);
                assert_eq!(fixture.signing_sets[&height].members, expected, "height {height}");
            }
            let deep = batch(&Arc::new(fixture), 6).await.unwrap();
            assert_eq!(deep.commit_heights, (19..=24).collect::<Vec<_>>());
            let first = batch(&Arc::new(Fixture::with_plan(0, 6, plan())), 6).await.unwrap();
            assert_eq!(first.commit_heights, [2, 3, 4, 5, 6]);
        }

        /// The decider's candidate cases driven through the lander: the snapshot of height 19
        /// decides, under L1 11's minimum total stake M, the set that signs 21, and the lander
        /// derives it from the staking proof of 19's post-state as the fixture's chain did. Every
        /// other height L1 11 anchors falls back, its total stake below M.
        #[tokio::test]
        async fn candidate_cases_table() {
            /// One candidate at height 19 under the minimum total stake `minimum`, and the
            /// members it signs 21 with, if it is usable.
            struct Case {
                name: &'static str,
                minimum: U256,
                snapshot_height: U256,
                total: U256,
                records: Vec<(u8, [U256; 2])>,
                signs: Option<Vec<(ConsensusKey, u64)>>,
            }
            let m = U256::from(1_000_000);
            let max = abci::committee::MAX_TOTAL_POWER;
            let (k1, k2) = (key(1), key(2));
            let record = |key: ConsensusKey, power: u64| {
                [U256::from_be_bytes(key.x().0), U256::from(key.prefix()) | U256::from(power) << 8]
            };
            // A snapshot of 19 with a total stake of M, under M.
            let case = |name, records, signs| Case {
                name,
                minimum: m,
                snapshot_height: U256::from(19),
                total: m,
                records,
                signs,
            };
            let k1_at_5 = || vec![(0, record(k1, 5))];
            let cases = [
                case("usable at the minimum", k1_at_5(), Some(vec![(k1, 5)])),
                Case {
                    total: m - U256::from(1),
                    ..case("total below the minimum", k1_at_5(), None)
                },
                Case {
                    snapshot_height: U256::from(18),
                    ..case("snapshot of the height below", k1_at_5(), None)
                },
                Case {
                    snapshot_height: U256::from((1u64 << 48) | 19),
                    ..case("snapshot height with bit 48 set", k1_at_5(), None)
                },
                Case {
                    minimum: U256::MAX,
                    total: U256::MAX,
                    ..case("maximal minimum, maximal total", k1_at_5(), None)
                },
                Case {
                    minimum: U256::MAX - U256::from(1),
                    total: U256::MAX,
                    ..case(
                        "minimum below the maximum, maximal total",
                        k1_at_5(),
                        Some(vec![(k1, 5)]),
                    )
                },
                case("record in seat 70", vec![(70, record(k1, 5))], Some(vec![(k1, 5)])),
                case("power 250,000", vec![(0, record(k1, 250_000))], Some(vec![(k1, 250_000)])),
                case(
                    "unused bit 72 in the second word",
                    vec![(0, {
                        let [x, packed] = record(k1, 250_000);
                        [x, packed | U256::from(1) << 72]
                    })],
                    None,
                ),
                case(
                    "key word without prefix or power",
                    vec![(0, [record(k1, 5)[0], U256::ZERO])],
                    None,
                ),
                case("zero power", vec![(0, record(k1, 0))], None),
                case("repeated key", vec![(0, record(k1, 5)), (1, record(k1, 6))], None),
                case(
                    "prefix 4",
                    vec![(0, [record(k1, 5)[0], U256::from(4) | U256::from(5) << 8])],
                    None,
                ),
                case("no member", vec![], None),
                case(
                    "powers summing to the maximum",
                    vec![(0, record(k1, max - 1)), (1, record(k2, 1))],
                    Some(vec![(k1, max - 1), (k2, 1)]),
                ),
                case(
                    "powers summing above the maximum",
                    vec![(0, record(k1, max)), (1, record(k2, 1))],
                    None,
                ),
            ];
            for Case { name, minimum, snapshot_height, total, records, signs } in cases {
                let mut words = vec![
                    (staking::snapshot_height_slot(), snapshot_height),
                    (staking::snapshot_total_stake_slot(), total),
                ];
                for (seat, pair) in records {
                    words.extend(staking::record_slots(seat).into_iter().zip(pair));
                }
                let plan =
                    SigningPlan {
                        anchor_words: anchor_minimum(move |number| {
                            if number == 11 { minimum } else { U256::MAX }
                        }),
                        staking: Box::new(move |height, origin| {
                            if height == 19 { words.clone() } else { staking_words(height, origin) }
                        }),
                        ..SigningPlan::default()
                    };
                let fixture = Fixture::with_plan(18, 24, plan);
                let origin = fixture.committees[&0].validators.clone();
                let decided = signs.as_deref().map_or(origin, set);
                assert_eq!(fixture.signing_sets[&21].validators, decided, "{name}");
                let fixture = Arc::new(fixture);
                let state = forward_to(&fixture, 20).await.unwrap();
                assert_eq!(state.signers, decided, "{name}");
                let heights = batch(&fixture, 6).await.unwrap().commit_heights;
                let changes = if signs.is_some() { vec![20, 21, 24] } else { vec![24] };
                assert_eq!(heights, changes, "{name}");
            }
        }

        /// At p = o the origin list signs o + 1 and o + 2, whatever o's state and anchor hold:
        /// generation 0's anchors here prove a minimum total stake of 0, under which o's own
        /// snapshot is usable, yet the candidate signs only from 3 on. No staking read is made
        /// at o, and a recovery generation's start c reads nothing at c either.
        #[tokio::test]
        async fn p_equal_o_uses_the_origin_list() {
            let plan = SigningPlan {
                anchor_words: anchor_minimum(|_| U256::ZERO),
                ..SigningPlan::default()
            };
            let fixture = Fixture::with_plan(0, 6, plan);
            let origin = fixture.committees[&0].validators.clone();
            let at_o = snapshot_of(&staking_words(0, &fixture.origin_keys));
            assert!(abci::committee::usable_candidate(0, &at_o, U256::ZERO).is_some());
            assert_eq!(fixture.signing_sets[&2].validators, origin);
            let candidate = set(&default_candidate(&fixture.origin_keys));
            assert_eq!(fixture.signing_sets[&3].validators, candidate);
            let source = TrackingSource::new(fixture);
            let b = source.builder(6);
            let snapshot = source.fixture().snapshot.clone();
            let start = b.checkpoint(&snapshot).await.unwrap();
            assert!(start.parent_signers.is_none());
            assert_eq!(start.signers, origin);
            let request = b.prepare(snapshot).await.unwrap().unwrap();
            assert_eq!(request.batch.commit_heights, [2, 6]);
            let fixture = source.fixture();
            let reads =
                (1..=5).map(|height| fixture.headers[&height].hash_slow()).collect::<Vec<_>>();
            assert_eq!(*source.staking_reads.lock().unwrap(), reads);

            let source = TrackingSource::new(recovery::fixture(8, 6, 12).await);
            let b = source.builder(12);
            let snapshot = source.fixture().snapshot.clone();
            let start = b.checkpoint(&snapshot).await.unwrap();
            assert!(start.parent_signers.is_none());
            assert_eq!(start.signers, set(&recovery::origin_keys().validator_set()));
            let request = b.prepare(snapshot).await.unwrap().unwrap();
            assert_eq!(request.batch.input.lastHeight, U256::from(12));
            assert_eq!(request.batch.commit_heights, [12]);
            let fixture = source.fixture();
            let reads =
                (7..=11).map(|height| fixture.headers[&height].hash_slow()).collect::<Vec<_>>();
            assert_eq!(*source.staking_reads.lock().unwrap(), reads);
        }

        /// At p = o + 1 the set that signs p is the Comet node's answer at p, checked against
        /// header(p), but the set that signs p + 1 = o + 2 is the origin list: the node's answer
        /// at p + 1, another set here, is never read.
        #[tokio::test]
        async fn p_equal_o_plus_1_takes_p_plus_1_from_the_origin() {
            let origin = set(&recovery::origin_keys().validator_set());
            let other = vec![(key(9), 1)];
            let mut recovered = recovery::fixture(8, 7, 12).await;
            recovered.validator_answers.insert(8, other.clone());
            let recovered = Arc::new(recovered);
            let b = builder(recovered.clone(), limits(12));
            let start = b.checkpoint(&recovered.snapshot).await.unwrap();
            assert_eq!(start.parent_signers.as_ref(), Some(&origin));
            assert_eq!(start.signers, origin);
            assert!(b.prepare(recovered.snapshot.clone()).await.unwrap().is_some());

            let mut recovered = recovery::fixture(8, 7, 12).await;
            recovered.validator_answers.insert(7, other);
            let recovered = Arc::new(recovered);
            let error = builder(recovered.clone(), limits(12))
                .validate_checkpoint(&recovered.snapshot)
                .await
                .unwrap_err();
            assert!(
                matches!(&error, LanderError::Safety(message) if message.contains("validators of height 7")),
                "{error}"
            );
        }

        /// Deep in a generation the sets that sign p and p + 1 are the Comet node's answers at p
        /// and p + 1, checked against header(p): with powers growing every height they are the
        /// candidates decided at p − 2 and p − 1, neither of them the origin list. p + 1's
        /// LastCommit verifies against the first and its commit against the second.
        #[tokio::test]
        async fn p_deep_in_a_generation_uses_validators_of_p_and_p_plus_1() {
            let plan = SigningPlan {
                anchor_words: anchor_minimum(|_| U256::ZERO),
                staking: Box::new(growing_candidate),
                ..SigningPlan::default()
            };
            let fixture = Fixture::with_plan(18, 24, plan);
            let at_p = set(&growing_members(16, &fixture.origin_keys));
            let at_p1 = set(&growing_members(17, &fixture.origin_keys));
            let at_p2 = set(&growing_members(18, &fixture.origin_keys));
            let origin = fixture.committees[&0].validators.clone();
            assert!(at_p != origin && at_p1 != origin && at_p != at_p1);
            let fixture = Arc::new(fixture);
            let start =
                builder(fixture.clone(), limits(6)).checkpoint(&fixture.snapshot).await.unwrap();
            assert_eq!(start.parent_signers.as_ref(), Some(&at_p));
            assert_eq!(start.signers, at_p1);
            assert_eq!(start.origin, origin);
            let state = forward_to(&fixture, 19).await.unwrap();
            assert_eq!(state.parent_signers, Some(at_p1));
            assert_eq!(state.signers, at_p2);
        }

        /// A Comet node's `/validators` answer at p or p + 1 that does not hash to header(p)'s
        /// `validators_hash` or `next_validators_hash` is refused as `Safety`: another key, the
        /// right keys with one power changed, no member at all, or powers that each fit
        /// CometBFT's int64 but together overflow a u64.
        #[tokio::test]
        async fn validators_answer_with_another_hash_is_safety() {
            let mut repowered = Fixture::new(18, 24).signing_sets[&18].members.clone();
            repowered[0].1 += 1;
            let overflowing = [9, 10, 11].map(|seed| (key(seed), i64::MAX as u64)).to_vec();
            for (height, what) in
                [(18, "with the validator hash"), (19, "with the next validator hash")]
            {
                for answer in [vec![(key(9), 1)], repowered.clone(), vec![], overflowing.clone()] {
                    let mut fixture = Fixture::new(18, 24);
                    fixture.validator_answers.insert(height, answer);
                    let fixture = Arc::new(fixture);
                    let error = builder(fixture.clone(), limits(6))
                        .validate_checkpoint(&fixture.snapshot)
                        .await
                        .unwrap_err();
                    let named = format!("validators of height {height}");
                    assert!(
                        matches!(&error, LanderError::Safety(message) if message.contains(&named) && message.contains(what)),
                        "{error}"
                    );
                }
            }
        }

        /// The set that signs p + 2 is decided at p from the staking proof of p's post-state,
        /// read at p's hash and verified under p's EL state root, and from the minimum total
        /// stake and fallback key list p's anchor (L1 11 for p = 18) proves: its usable candidate,
        /// otherwise that list's keys at power 1, the origin list's or a later one, as for a total
        /// stake below the minimum or a snapshot of p − 1. A proof of another state is refused.
        #[tokio::test]
        async fn p_staking_usable_candidate_fallback_and_stale_snapshot() {
            #[derive(Clone, Copy, Debug)]
            enum Signs {
                Candidate,
                Origin,
                Later,
            }
            let later = fallback_keys(&[0x41, 0x42, 0x43].map(seed_key));
            let plan = |minimum: u64, list: Option<B256>, stale: bool| SigningPlan {
                extra_keys: vec![0x41, 0x42, 0x43],
                lists: vec![later.clone()],
                anchor_words: Box::new(move |number, origin| {
                    if number == 11 {
                        (list.unwrap_or_else(|| origin.hash()), U256::from(minimum))
                    } else {
                        (origin.hash(), U256::MAX)
                    }
                }),
                staking: Box::new(move |height, origin| {
                    let taken = if stale && height == 18 { 17 } else { height };
                    let members = default_candidate(origin);
                    candidate_words(U256::from(taken), U256::from(1000 + height), &members)
                }),
                ..SigningPlan::default()
            };
            for (minimum, list, stale, signs) in [
                (1000, None, false, Signs::Candidate),
                (1_000_000, None, false, Signs::Origin),
                (1000, None, true, Signs::Origin),
                (1_000_000, Some(later.hash()), false, Signs::Later),
            ] {
                let source =
                    TrackingSource::new(Fixture::with_plan(18, 24, plan(minimum, list, stale)));
                let fixture = source.fixture();
                let expected = match signs {
                    Signs::Candidate => set(&default_candidate(&fixture.origin_keys)),
                    Signs::Origin => fixture.committees[&0].validators.clone(),
                    Signs::Later => set(&later.validator_set()),
                };
                assert_eq!(fixture.signing_sets[&20].validators, expected, "{signs:?}");
                let b = source.builder(6);
                let snapshot = fixture.snapshot.clone();
                let start = b.checkpoint(&snapshot).await.unwrap();
                let mut state = ForwardState::new(&start, &snapshot).unwrap();
                b.authenticate_block(&snapshot, &mut state, &fixture.blocks[&19]).await.unwrap();
                assert_eq!(state.signers, expected, "{signs:?}");
                assert_eq!(
                    *source.staking_reads.lock().unwrap(),
                    [fixture.headers[&18].hash_slow()],
                    "{signs:?}"
                );
                assert!(b.prepare(snapshot).await.unwrap().is_some(), "{signs:?}");
            }

            let mut fixture = Fixture::with_plan(18, 24, plan(1000, None, false));
            let below = fixture.l2_states[&17].clone();
            fixture.l2_states.insert(18, below);
            let fixture = Arc::new(fixture);
            let error = batch(&fixture, 6).await.unwrap_err();
            assert!(
                matches!(&error, LanderError::Safety(message) if message.contains("staking proof at L2 18")),
                "{error}"
            );
        }

        /// Each block's `missBitmap` must be the one its LastCommit gives: an absent precommit
        /// in 21's LastCommit and a nil one in 22's, each by an origin key the parent's
        /// post-state seats, set that seat's bit, and a header carrying another bitmap is refused
        /// as `Safety`, inside the batch and at its end.
        #[tokio::test]
        async fn wrong_miss_bitmap_is_a_safety_error() {
            let plan = || SigningPlan {
                origin_keys: 4,
                missing: Box::new(|height| match height {
                    21 => vec![Missing::Absent(1)],
                    22 => vec![Missing::Nil(2)],
                    _ => vec![],
                }),
                ..SigningPlan::default()
            };
            let fixture = Fixture::with_plan(18, 22, plan());
            // The default script seats origin key i in seat i at every height.
            let seat = |height: u64, index: usize| {
                let validator = &fixture.signing_sets[&(height - 1)].validators.validators()[index];
                fixture.origin_keys.keys().iter().position(|key| *key == validator.pub_key).unwrap()
            };
            let (at_21, at_22) = (1u128 << seat(21, 1), 1u128 << seat(22, 2));
            assert_eq!(header_bitmap(&fixture, 21), at_21);
            assert_eq!(header_bitmap(&fixture, 22), at_22);
            let last = fixture.blocks[&22].block.last_commit.as_ref().unwrap();
            assert!(matches!(last.signatures[2], crate::native::CommitSig::BlockIdFlagNil { .. }));
            assert!(batch(&Arc::new(fixture), 4).await.is_ok());

            for (height, expected, wrong) in
                [(21, at_21, 0), (22, at_22, 0), (22, at_22, at_22 | 1 << 127)]
            {
                let mut forged = Fixture::with_plan(18, 22, plan());
                alter_envelope(&mut forged, height, |envelope| {
                    let header = &mut envelope.block.header;
                    let mut extra = rules::decode_extra_data(&header.extra_data).unwrap();
                    extra.miss_bitmap = wrong;
                    header.extra_data = rules::encode_extra_data(&extra).unwrap();
                });
                // Block 22 no longer links to an altered 21, so that batch ends at 21.
                let error = batch(&Arc::new(forged), (height - 18) as usize).await.unwrap_err();
                let violation =
                    rules::RuleViolation::MissBitmap { expected, got: wrong }.to_string();
                assert!(
                    matches!(&error, LanderError::Safety(message) if message.contains(&violation)),
                    "{error}"
                );
            }
        }

        /// p + 1's `missBitmap` is taken over the set that signs p, the Comet node's answer at
        /// p, in its CometBFT order, with the seats of p's post-state: the candidate signs 18 and
        /// the origin keys 19 (17's total stake is below the minimum), the seats rotate every
        /// height, and the second validator of 18's set, of power 3, is absent from 19's
        /// LastCommit.
        #[tokio::test]
        async fn miss_bitmap_of_p_plus_1_uses_the_set_of_p() {
            /// The default candidate, with a total stake of 0 at 17 and origin key `i` seated in
            /// seat `(i + height) mod 4`.
            fn rotating(height: u64, origin: &FallbackKeys) -> Vec<(B256, U256)> {
                let total = if height == 17 { 0 } else { 1000 + height };
                let members = default_candidate(origin);
                let mut words = candidate_words(U256::from(height), U256::from(total), &members);
                for (i, key) in (0u64..).zip(origin.keys()) {
                    let seat = U256::from((i + height) % 4);
                    words.push((
                        staking::key_to_seat_slot(key.address()),
                        U256::from(1) | seat << 8,
                    ));
                }
                words
            }
            let plan_fixture = || {
                Fixture::with_plan(
                    18,
                    24,
                    SigningPlan {
                        origin_keys: 4,
                        anchor_words: anchor_minimum(usable_at_11),
                        staking: Box::new(rotating),
                        missing: Box::new(|height| {
                            if height == 19 { vec![Missing::Absent(1)] } else { vec![] }
                        }),
                        ..SigningPlan::default()
                    },
                )
            };
            let fixture = plan_fixture();
            let candidate = set(&default_candidate(&fixture.origin_keys));
            assert_eq!(fixture.signing_sets[&18].validators, candidate);
            assert_eq!(fixture.signing_sets[&19].validators, fixture.committees[&0].validators);
            let absent = &candidate.validators()[1];
            assert_eq!(absent.power(), 3);
            let index = (0u64..)
                .zip(fixture.origin_keys.keys())
                .find_map(|(i, key)| (*key == absent.pub_key).then_some(i))
                .unwrap();
            let at_p = 1u128 << ((index + 18) % 4);
            assert_eq!(header_bitmap(&fixture, 19), at_p);
            // The second validator of 19's own set, the origin keys in address order.
            let second = &fixture.committees[&0].validators.validators()[1];
            let second = (0u64..)
                .zip(fixture.origin_keys.keys())
                .find_map(|(i, key)| (*key == second.pub_key).then_some(i))
                .unwrap();
            let whole = batch(&Arc::new(fixture), 6).await.unwrap();
            assert_eq!(whole.input.lastHeight, U256::from(24));

            // The bitmap the seats of 19's post-state give, and the one the second validator of
            // 19's own set gives, are refused.
            for wrong in [1u128 << ((index + 19) % 4), 1u128 << ((second + 18) % 4)] {
                assert_ne!(wrong, at_p);
                let mut forged = plan_fixture();
                alter_envelope(&mut forged, 19, |envelope| {
                    let header = &mut envelope.block.header;
                    let mut extra = rules::decode_extra_data(&header.extra_data).unwrap();
                    extra.miss_bitmap = wrong;
                    header.extra_data = rules::encode_extra_data(&extra).unwrap();
                });
                // Block 20 no longer links to the altered 19: a one-block batch.
                let error = batch(&Arc::new(forged), 1).await.unwrap_err();
                let violation =
                    rules::RuleViolation::MissBitmap { expected: at_p, got: wrong }.to_string();
                assert!(
                    matches!(&error, LanderError::Safety(message) if message.contains(&violation)),
                    "{error}"
                );
            }
        }

        /// The precommits the LastCommit of each height of
        /// [`staking_reads_cover_p_plus_1_through_h_minus_1`] lacks, among seven origin
        /// keys.
        fn missing_precommits(height: u64) -> Vec<Missing> {
            match height {
                2 | 21 => vec![Missing::Absent(1)],
                19 => vec![Missing::Nil(0)],
                22 => vec![Missing::Nil(2), Missing::Absent(5)],
                _ => vec![],
            }
        }

        /// The addresses of the validators `height`'s LastCommit lacks in `fixture`, in the
        /// CometBFT order of the set that signs `height − 1`.
        fn missing_addresses(fixture: &Fixture, height: u64) -> Vec<Address> {
            let parent = fixture.signing_sets[&(height - 1)].validators.validators();
            missing_precommits(height)
                .into_iter()
                .map(|missing| {
                    let (Missing::Absent(index) | Missing::Nil(index)) = missing;
                    Address::from_slice(parent[index].address.as_bytes())
                })
                .collect()
        }

        /// The request carries the staking words the proof reads. Above the generation's start
        /// o, p's staking proof: the snapshot slots and the key-to-seat slot of each validator
        /// p + 1's LastCommit lacks, under p's EL state root. For every height H in (p, h − 1],
        /// H's 258 snapshot words in snapshot slot order and the key-to-seat word of each
        /// validator H + 1's LastCommit lacks, in CometBFT order. At p = o nothing is read at p,
        /// and a one-block batch reads only at p.
        #[tokio::test]
        async fn staking_reads_cover_p_plus_1_through_h_minus_1() {
            let plan = || SigningPlan {
                origin_keys: 7,
                missing: Box::new(missing_precommits),
                ..SigningPlan::default()
            };
            let reads = |fixture: &Fixture, height: u64| {
                let words = staking_words(height, &fixture.origin_keys)
                    .into_iter()
                    .collect::<BTreeMap<_, _>>();
                let word = |slot| words.get(&slot).copied().unwrap_or_default();
                HeightReads {
                    height,
                    values: staking::snapshot_slots().map(word).to_vec(),
                    seat_words: missing_addresses(fixture, height + 1)
                        .into_iter()
                        .map(|address| (address, word(staking::key_to_seat_slot(address))))
                        .collect(),
                }
            };

            let at_o = Fixture::with_plan(0, 6, plan());
            let expected = (1..=5).map(|height| reads(&at_o, height)).collect::<Vec<_>>();
            assert_eq!(expected[0].seat_words.len(), 1);
            let request = batch(&Arc::new(at_o), 6).await.unwrap();
            assert_eq!(request.staking_at_p, None);
            assert_eq!(request.staking_reads, expected);

            let deep = Fixture::with_plan(18, 22, plan());
            let slots = crate::l1::staking_slots(&missing_addresses(&deep, 19));
            assert_eq!(slots.len(), staking::SNAPSHOT_SLOT_COUNT + 1);
            let at_p = deep.l2_states[&18].witness(deep.params.staking, &slots);
            let expected = (19..=21).map(|height| reads(&deep, height)).collect::<Vec<_>>();
            assert_eq!(expected[2].seat_words.len(), 2);
            let deep = Arc::new(deep);
            let whole = batch(&deep, 4).await.unwrap();
            assert_eq!(whole.input.lastHeight, U256::from(22));
            assert_eq!(whole.staking_at_p.as_ref(), Some(&at_p));
            assert_eq!(whole.staking_reads, expected);
            let single = batch(&deep, 1).await.unwrap();
            assert_eq!(single.input.lastHeight, U256::from(19));
            assert_eq!(single.staking_at_p, Some(at_p));
            assert!(single.staking_reads.is_empty());
        }

        /// The request carries the origin list, and the sets that sign p and p + 1 where the
        /// proof takes them as input, keys and powers in CometBFT order: the set of p above the
        /// generation's start o, and the set of p + 1 above o + 2, the origin list signing o + 1
        /// and o + 2. At p = o neither is carried; deep in generation zero both are candidates,
        /// decided at p − 2 and p − 1. A recovery generation starting at o = 6 carries the origin
        /// keys as the set of p = o + 1, and as both sets at p = o + 2.
        #[tokio::test]
        async fn request_carries_the_sets_of_p_and_p_plus_1_above_the_origin() {
            let plan = || SigningPlan {
                anchor_words: anchor_minimum(|_| U256::ZERO),
                staking: Box::new(growing_candidate),
                ..SigningPlan::default()
            };
            let ordered = |set: &Validators| {
                set.validators().iter().map(|v| (v.pub_key, v.power())).collect::<Vec<_>>()
            };
            let at_o = Fixture::with_plan(0, 4, plan());
            let origin = at_o.origin_keys.clone();
            let request = batch(&Arc::new(at_o), 4).await.unwrap();
            assert_eq!(request.origin_fallback_keys, origin);
            assert_eq!((request.validators_p, request.validators_p1), (None, None));

            let deep = Fixture::with_plan(18, 22, plan());
            let origin = deep.origin_keys.clone();
            let (at_p, at_p1) =
                (set(&growing_members(16, &origin)), set(&growing_members(17, &origin)));
            assert_eq!(
                (&deep.signing_sets[&18].validators, &deep.signing_sets[&19].validators),
                (&at_p, &at_p1)
            );
            let request = batch(&Arc::new(deep), 4).await.unwrap();
            assert_eq!(request.origin_fallback_keys, origin);
            assert_eq!(request.validators_p, Some(ordered(&at_p)));
            assert_eq!(request.validators_p1, Some(ordered(&at_p1)));

            let origin = set(&recovery::origin_keys().validator_set());
            for (p, carries_p1) in [(7, false), (8, true)] {
                let source = TrackingSource::new(recovery::fixture(8, p, 12).await);
                let snapshot = source.fixture().snapshot.clone();
                let request = source.builder(4).prepare(snapshot).await.unwrap().unwrap().batch;
                assert_eq!(request.origin_fallback_keys, recovery::origin_keys(), "p = {p}");
                assert_eq!(request.validators_p, Some(ordered(&origin)), "p = {p}");
                let at_p1 = carries_p1.then(|| ordered(&origin));
                assert_eq!(request.validators_p1, at_p1, "p = {p}");
            }
        }

        /// Above the generation's start the request carries header(p), the original protobuf of
        /// the CometBFT header p's landing record names, and header(p), the sets that sign p and
        /// p + 1 and the origin list commit each other, on build and on restore. A request whose
        /// header(p) or sets are missing or carried where the proof does not take them, whose
        /// header(p) is another block's, noncanonical or no header, or whose sets are reordered
        /// or re-powered is refused, as is one at p = o + 1 whose origin list header(p) does not
        /// commit as the set that signs p + 1.
        #[tokio::test]
        async fn request_carries_header_p_committing_the_sets_of_p_and_p_plus_1() {
            use prost::Message;
            let refused = |batch: &PreparedBatch, expected: &str| {
                let reason = batch.check_origin_sets().unwrap_err();
                assert!(reason.contains(expected), "{expected}: {reason}");
                let error = batch.verify_restored().unwrap_err();
                assert!(
                    matches!(&error, LanderError::Journal(message) if message.contains(expected)),
                    "{expected}: {error}"
                );
            };
            let header = |fixture: &Fixture, height: u64| {
                let raw = fixture.blocks[&height].block_proto().unwrap().header.unwrap();
                Bytes::from(raw.encode_to_vec())
            };
            let misplaced = "carried where the proof does not take it";

            let at_o = Arc::new(Fixture::new(0, 6));
            let request = batch(&at_o, 4).await.unwrap();
            assert_eq!(request.header_p, None);
            request.verify_restored().unwrap();
            let mut changed = request.clone();
            changed.header_p = Some(header(&at_o, 1));
            refused(&changed, misplaced);

            let deep = Arc::new(Fixture::new(18, 22));
            let request = batch(&deep, 4).await.unwrap();
            assert_eq!(request.header_p, Some(header(&deep, 18)));
            request.verify_restored().unwrap();
            let at_p = request.validators_p.clone().unwrap();
            let at_p1 = request.validators_p1.clone().unwrap();
            assert!(at_p.len() > 1 && at_p1.len() > 1);
            let mut cases = Vec::new();
            let mut changed = request.clone();
            changed.header_p = None;
            cases.push((changed, misplaced));
            let mut changed = request.clone();
            changed.validators_p = None;
            cases.push((changed, misplaced));
            let mut changed = request.clone();
            changed.validators_p1 = None;
            cases.push((changed, misplaced));
            let mut changed = request.clone();
            changed.header_p = Some(header(&deep, 19));
            cases.push((changed, "does not hash to p's Comet hash"));
            // A repeated height field decodes to the same header but re-encodes without it.
            let mut changed = request.clone();
            changed.header_p = Some([header(&deep, 18).as_ref(), &[0x18, 18]].concat().into());
            cases.push((changed, "noncanonical"));
            let mut changed = request.clone();
            changed.header_p = Some(Bytes::from_static(&[0xff]));
            cases.push((changed, "no CometBFT header protobuf"));
            let mut changed = request.clone();
            changed.validators_p.as_mut().unwrap().reverse();
            cases.push((changed, "signs p is not in CometBFT order"));
            let mut changed = request.clone();
            changed.validators_p1.as_mut().unwrap().reverse();
            cases.push((changed, "signs p + 1 is not in CometBFT order"));
            let mut changed = request.clone();
            changed.validators_p.as_mut().unwrap()[0].1 += 1;
            cases.push((changed, "signs p differs from header(p)'s"));
            let mut changed = request.clone();
            changed.validators_p1.as_mut().unwrap()[0].1 += 1;
            cases.push((changed, "signs p + 1 differs from header(p)'s"));
            for (changed, expected) in &cases {
                refused(changed, expected);
            }

            // At p = o + 1 the origin list signs p + 1, and header(p) commits it.
            let source = TrackingSource::new(recovery::fixture(8, 7, 12).await);
            let snapshot = source.fixture().snapshot.clone();
            let request = source.builder(4).prepare(snapshot).await.unwrap().unwrap().batch;
            assert_eq!(request.header_p, Some(header(&source.fixture(), 7)));
            assert_eq!(request.validators_p1, None);
            request.verify_restored().unwrap();
            let mut changed = request.clone();
            changed.origin_fallback_keys = fallback_keys(&[seed_key(0x51)]);
            refused(&changed, "signs p + 1 differs from header(p)'s");
            let mut changed = request;
            changed.validators_p1 = changed.validators_p.clone();
            refused(&changed, misplaced);
        }

        /// The request carries each fallback key list a decision at a height of [p, h − 1] fell
        /// back to, once, in ascending order of hash: none while the candidate signs, the origin
        /// list while the minimum total stake is out of reach, and a later list the anchors of 18
        /// to 22 name besides the origin list 23's anchor names.
        #[tokio::test]
        async fn request_carries_each_fallback_list_a_decision_used() {
            let later = fallback_keys(&[0x41, 0x42, 0x43].map(seed_key));
            let candidate = SigningPlan {
                anchor_words: anchor_minimum(|_| U256::ZERO),
                staking: Box::new(growing_candidate),
                ..SigningPlan::default()
            };
            let request = batch(&Arc::new(Fixture::with_plan(18, 24, candidate)), 6).await;
            assert!(request.unwrap().fallback_key_lists.is_empty());

            let fixture = Fixture::with_plan(18, 24, SigningPlan::default());
            let origin = fixture.origin_keys.clone();
            let request = batch(&Arc::new(fixture), 6).await.unwrap();
            assert_eq!(request.fallback_key_lists, [origin]);

            let replaced = {
                let later = later.clone();
                SigningPlan {
                    extra_keys: vec![0x41, 0x42, 0x43],
                    lists: vec![later.clone()],
                    anchor_words: Box::new(move |number, origin| {
                        let list = if number == 11 { later.hash() } else { origin.hash() };
                        (list, U256::MAX)
                    }),
                    ..SigningPlan::default()
                }
            };
            let fixture = Fixture::with_plan(18, 24, replaced);
            assert_eq!(fixture.signing_sets[&24].validators, set(&later.validator_set()));
            assert_eq!(fixture.signing_sets[&25].validators, fixture.committees[&0].validators);
            let mut expected = vec![fixture.origin_keys.clone(), later];
            expected.sort_by_key(FallbackKeys::hash);
            let request = batch(&Arc::new(fixture), 6).await.unwrap();
            assert_eq!(request.fallback_key_lists, expected);
        }

        /// Only a change of keys or powers is a commit height: the candidate holds the origin
        /// keys at power 1, as the fallback key set does, but for the first key at power 2 in
        /// 20's snapshot, and 19's total stake is below the minimum. The switch to the fallback
        /// keys at 21 and back at 22 changes no key or power and adds no commit height; the power
        /// change at 22 and back at 23 adds 21 and 22.
        #[tokio::test]
        async fn commit_heights_include_only_set_changes() {
            /// Origin keys at power 1, the first at 2 at height 20, with a total stake of 0 at 19.
            fn flat(height: u64, origin: &FallbackKeys) -> Vec<(B256, U256)> {
                let total = if height == 19 { 0 } else { 1000 + height };
                let members = (0..)
                    .zip(origin.keys())
                    .map(|(i, key)| (*key, if i == 0 && height == 20 { 2 } else { 1 }))
                    .collect::<Vec<_>>();
                candidate_words(U256::from(height), U256::from(total), &members)
            }
            let plan = SigningPlan {
                anchor_words: anchor_minimum(usable_at_11),
                staking: Box::new(flat),
                ..SigningPlan::default()
            };
            let fixture = Fixture::with_plan(18, 24, plan);
            let origin = fixture.committees[&0].validators.clone();
            for height in [19, 20, 21, 23, 24, 25] {
                assert_eq!(fixture.signing_sets[&height].validators, origin, "height {height}");
            }
            assert_ne!(fixture.signing_sets[&22].validators, origin);
            let at_19 = snapshot_of(&flat(19, &fixture.origin_keys));
            assert!(abci::committee::usable_candidate(19, &at_19, U256::from(1000)).is_none());
            let at_20 = snapshot_of(&flat(20, &fixture.origin_keys));
            assert!(abci::committee::usable_candidate(20, &at_20, U256::from(1000)).is_some());
            let heights = batch(&Arc::new(fixture), 6).await.unwrap().commit_heights;
            assert_eq!(heights, [21, 22, 24]);
        }
    }
}

#[cfg(test)]
mod prefix_proptests;
