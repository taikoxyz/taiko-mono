//! Consecutive, authenticated batch assembly and immutable proof-job construction.

use abci::engine::{
    Engine,
    forced::{ForcedBuildContext, ForcedBuildError, verify_forced},
};
use std::{collections::BTreeMap, sync::Arc, time::Duration};

use abci::{
    AnchorState, ChainParams, ParentInfo, Schedule,
    committee::{record_hash, verify_committee_witness_at_cutoff},
    fallback::FallbackKeys,
    rules,
};
use alloy_primitives::{Address, B256, U256, aliases::U48};
use async_trait::async_trait;
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
    types::{CertifiedBlock, LandingSnapshot, Limits, PreparedBatch, SidecarMode},
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

/// Fully authenticated starting checkpoint and the set that signs the batch.
struct BatchStart {
    /// Parent header and ancestry-derived base-fee timestamp.
    parent: ParentContext,
    /// Historical L1 proving anchor authenticated by the checkpoint execution header.
    anchor: AnchorState,
    /// Full schedule/bootstrap/anchor-facts proof retained for the guest.
    inbox_witness: abci::AnchorWitness,
    /// Certified checkpoint block, absent at the fixed generation origin.
    previous: Option<CertifiedBlock>,
    /// The generation's initial set, which signs every height until per-height set decisions
    /// land.
    validators: Validators,
    /// The L1 cutoff of the initial set's snapshot, the active committee snapshot of the batch.
    initial_cutoff: u64,
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
    /// Registry whose historical proofs derive generation zero's initial committee.
    registry: Address,
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
    /// Deployment's authenticated committee derivation configuration.
    committee_config_hash: B256,
    /// Bootstrap commitment independently checked by the starting Inbox proof.
    bootstrap_hash: B256,
}

impl CheckpointIdentity {
    /// Bind every snapshot input used to authenticate an immutable starting context.
    fn from_snapshot(snapshot: &LandingSnapshot) -> Self {
        Self {
            l1_chain_id: snapshot.l1_chain_id,
            l2_chain_id: snapshot.l2_chain_id,
            inbox: snapshot.inbox,
            registry: snapshot.registry,
            generation: snapshot.generation,
            recovery: snapshot.recovery.clone(),
            height: snapshot.checkpoint_height,
            hash: snapshot.checkpoint_hash,
            comet_hash: snapshot.checkpoint_comet_hash,
            genesis: snapshot.genesis.clone(),
            committee_config_hash: snapshot.committee_config_hash,
            bootstrap_hash: snapshot.genesis_committee_record_hash,
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

/// Constant-space forward authentication state of proof preparation.
struct ForwardState {
    /// Exact authenticated committed parent inputs.
    parent: ParentInfo,
    /// The set that signs every block of the batch, and its parent certificate.
    validators: Validators,
    /// Current authenticated L1 anchor.
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
            validators: start.validators.clone(),
            anchor: start.anchor.clone(),
            previous: start.previous.clone(),
            forced_cursor: snapshot.forced_inclusion_head,
        })
    }
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
/// checks before it starts.
pub fn batch_cap(max_blocks: usize, max_batch_blocks: u64) -> Result<usize> {
    let deployed = usize::try_from(max_batch_blocks).unwrap_or(usize::MAX);
    let cap = max_blocks.min(deployed);
    if cap == 0 {
        return Err(LanderError::Configuration(format!(
            "batches of at most {max_blocks} configured and {max_batch_blocks} deployed \
             (maxBatchBlocks) blocks cannot hold one block"
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

    /// Ensure one coherent Inbox context matches the configured chain and genesis record.
    fn check_snapshot(&self, snapshot: &LandingSnapshot) -> Result<()> {
        crate::l1::authenticate_snapshot(snapshot, &self.params)?;
        if snapshot.l2_chain_id != self.params.l2_chain_id ||
            snapshot.inbox != self.params.inbox ||
            snapshot.registry != self.params.registry ||
            snapshot.genesis.genesis_cutoff >= snapshot.genesis.l1_0 ||
            snapshot.genesis.genesis_hash.is_zero() ||
            snapshot.genesis.genesis_state_root.is_zero() ||
            snapshot.committee_config_hash.is_zero() ||
            snapshot.checkpoint_hash.is_zero()
        {
            return Err(LanderError::Configuration(
                "landing snapshot identity/genesis contradicts chain parameters".into(),
            ));
        }
        Schedule::from_genesis(&snapshot.genesis)
            .validate()
            .map_err(|e| LanderError::Configuration(e.to_string()))?;
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
        if status.height - snapshot.checkpoint_height > self.params.unsettled_limit() {
            return Err(LanderError::Temporary(
                "Comet tip exceeds this operational checkpoint's unsettled-block limit; refresh coherent Inbox snapshot".into(),
            ));
        }
        Ok(status)
    }

    /// Select exact complete-block boundaries using canonical codec and blob capacity checks.
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
                "blocks {}..={end} do not fit one batch, whose payload, blob and selection limits \
                 end it at {last}, so --land-to {end} cannot land",
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

    /// The generation's initial set, which signs every height until per-height set decisions
    /// land, and the L1 block it is fixed at. A recovery generation's set is the keys of the
    /// fallback key list whose hash its origin record holds, each at power 1, fixed at R: the
    /// batch's starting proof `starting`, under `anchor`, proves that hash, which must be the
    /// snapshot's authenticated origin's, and the list is obtained by it at R
    /// ([`BatchBuilder::fallback_list`]). So no root but the batch's own anchors authenticates
    /// the set. Generation zero's is the bootstrap committee, derived from its registry witness
    /// at the genesis cutoff under `anchor`'s root and checked against the bootstrap record hash.
    async fn initial_set(
        &self,
        snapshot: &LandingSnapshot,
        anchor: &AnchorState,
        starting: &abci::AnchorWitness,
    ) -> Result<(Validators, u64)> {
        if let Some(origin) = &snapshot.recovery {
            let slot = abci::l1::layout::inbox::origin_slots(origin.generation)[3];
            let proven = starting
                .inbox
                .storage
                .iter()
                .find(|proof| proof.slot == slot)
                .map(|proof| B256::from(proof.value));
            if proven != Some(origin.fallback_keys_hash) {
                return Err(LanderError::Safety(
                    "starting proof's origin fallbackKeysHash contradicts the recovery origin"
                        .into(),
                ));
            }
            let r = recovery_anchor(snapshot)?;
            let keys = self.fallback_list(origin.fallback_keys_hash, r.hash, r.number).await?;
            let validators = Validators::from_powers(&keys.validator_set())
                .map_err(|e| LanderError::Safety(e.to_string()))?;
            return Ok((validators, origin.l1_number));
        }
        let cutoff = snapshot.genesis.genesis_cutoff;
        if anchor.number < cutoff {
            return Err(LanderError::Safety(
                "committee proving root predates authenticated derivation snapshot".into(),
            ));
        }
        let witness = self.l1.committee_witness(anchor, cutoff, Schedule::E0).await?;
        let (record, members) = verify_committee_witness_at_cutoff(
            anchor.state_root,
            cutoff,
            &self.params,
            &witness,
            Schedule::E0,
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
        if record_hash(self.params.l2_chain_id, &record) != snapshot.genesis_committee_record_hash {
            return Err(LanderError::Safety(
                "derived genesis committee differs from bootstrap".into(),
            ));
        }
        let validators =
            Validators::from_members(&members).map_err(|e| LanderError::Safety(e.to_string()))?;
        Ok((validators, record.cutoff_l1_block))
    }

    /// The fallback key list whose hash is `hash`, from the cache of lists already obtained or
    /// from the L1 at the block with hash `at` and number `at_number`, the block that stored it
    /// or a later one ([`LandingSource::fallback_keys`], whose log scan reaches block 0). A list
    /// the L1 cannot give is [`LanderError::Temporary`]; one that hashes elsewhere is refused.
    async fn fallback_list(&self, hash: B256, at: B256, at_number: u64) -> Result<FallbackKeys> {
        if let Some(keys) = self.fallback_lists.lock().await.get(&hash) {
            return Ok(keys.clone());
        }
        let keys = self.l1.fallback_keys(hash, at, at_number, 0).await?;
        if keys.hash() != hash {
            return Err(LanderError::Safety(format!(
                "L1 source answered the fallback key list {hash} with {}",
                keys.hash()
            )));
        }
        self.fallback_lists.lock().await.insert(hash, keys.clone());
        Ok(keys)
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
        self.check_proving_anchor_canonicality(&start.anchor).await?;
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

    /// Hash-check the checkpoint's EL parent link, its historical proofs, the initial signing set
    /// and the checkpoint BFT certificate.
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
        let anchor = self.l1.parent_anchor(snapshot, &parent).await?;
        let at_origin = parent.header.number == snapshot.origin_height();
        let embedded_number = if let Some(origin) = snapshot.recovery.as_ref().filter(|_| at_origin)
        {
            origin.l1_number
        } else if parent.header.number == snapshot.genesis.genesis_height {
            snapshot.genesis.l1_0
        } else {
            let extra = rules::decode_extra_data(&parent.header.extra_data)
                .map_err(|e| LanderError::Safety(e.to_string()))?;
            if extra.generation != snapshot.generation {
                return Err(LanderError::Safety(
                    "checkpoint execution header belongs to another generation".into(),
                ));
            }
            extra.anchor
        };
        if anchor.number != embedded_number ||
            !at_origin &&
                parent.header.number > 0 &&
                parent.header.parent_beacon_block_root != Some(anchor.state_root)
        {
            return Err(LanderError::Safety(
                "checkpoint proving anchor differs from embedded EL number/root".into(),
            ));
        }

        let starting_inbox_witness = self.l1.starting_inbox_witness(&anchor).await?;
        let (genesis, bootstrap) =
            crate::l1::verify_starting_inbox(&starting_inbox_witness, &anchor, self.params.inbox)?;
        if genesis != snapshot.genesis ||
            bootstrap != snapshot.genesis_committee_record_hash ||
            anchor.inbox.recovery_generation != snapshot.generation ||
            anchor.number < genesis.l1_0
        {
            return Err(LanderError::Safety(
                "starting genesis/config proof contradicts snapshot".into(),
            ));
        }
        let (validators, initial_cutoff) =
            self.initial_set(snapshot, &anchor, &starting_inbox_witness).await?;
        if at_origin {
            let (hash, root) = snapshot.recovery.as_ref().map_or(
                (snapshot.genesis.genesis_hash, snapshot.genesis.genesis_state_root),
                |r| (r.el_hash, r.state_root),
            );
            if snapshot.checkpoint_hash != hash || parent.header.state_root != root {
                return Err(LanderError::Safety(
                    "genesis checkpoint hash/state root mismatch".into(),
                ));
            }
            return Ok(BatchStart {
                parent,
                anchor,
                inbox_witness: starting_inbox_witness,
                previous: None,
                validators,
                initial_cutoff,
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
        verify_commit(
            &pair.commit,
            &pair.block.header,
            &validators,
            &rules::chain_id_for(&self.params, snapshot.generation)
                .map_err(|e| LanderError::Configuration(e.to_string()))?,
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
        if pair.block.header.next_validators_hash != validators.hash() {
            return Err(LanderError::Safety("checkpoint next validator hash disagrees".into()));
        }
        Ok(BatchStart {
            parent,
            anchor,
            inbox_witness: starting_inbox_witness,
            previous: Some(pair),
            validators,
            initial_cutoff,
        })
    }

    /// Verify one successor against the set that signs the batch.
    ///
    /// Both the carried parent certificate and the current certificate must verify before
    /// execution facts can advance.
    async fn authenticate_block(
        &self,
        snapshot: &LandingSnapshot,
        state: &mut ForwardState,
        pair: &CertifiedBlock,
    ) -> Result<()> {
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
        if let (Some(last), Some(previous)) = (&pair.block.last_commit, state.previous.as_ref()) {
            verify_commit(last, &previous.block.header, &state.validators, &chain_id)
                .map_err(|e| LanderError::Safety(e.to_string()))?;
        }
        verify_commit(&pair.commit, &pair.block.header, &state.validators, &chain_id)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        let bft_secs = u64::try_from(pair.block.header.time.unix_timestamp())
            .map_err(|_| LanderError::Safety("negative BFT block timestamp".into()))?;
        let signers = state.validators.entries();
        let facts = verify_envelope(
            envelope,
            EnvelopeContext {
                bft_time_secs: bft_secs,
                proposer: pair.block.header.proposer_address,
                signers: &signers,
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
        if pair.block.header.next_validators_hash != state.validators.hash() {
            return Err(LanderError::Safety(format!(
                "next validator hash disagrees at height {height}"
            )));
        }
        state.parent = facts.parent;
        state.anchor = facts.anchor;
        state.previous = Some(pair.clone());
        state.forced_cursor = forced_cursor;
        Ok(())
    }

    /// Retain only the selected proof prefix's per-block anchors and cut leaves after shared
    /// verification: one leaf for every height strictly inside (p, h), none for the terminal
    /// block (ENC-A-31), with the forward state after its last block (its forced inclusion
    /// cursor).
    async fn authenticate_blocks(
        &self,
        snapshot: &LandingSnapshot,
        start: &BatchStart,
        blocks: &[CertifiedBlock],
    ) -> Result<(Vec<AnchorState>, Vec<B256>, ForwardState)> {
        let mut state = ForwardState::new(start, snapshot)?;
        let mut anchors = Vec::new();
        let mut leaves = Vec::new();
        for (index, pair) in blocks.iter().enumerate() {
            self.authenticate_block(snapshot, &mut state, pair).await?;
            anchors.push(state.anchor.clone());
            if index + 1 < blocks.len() {
                leaves.push(statement::cut_leaf(
                    state.parent.number,
                    state.parent.hash,
                    B256::from_slice(pair.block.header.hash().as_bytes()),
                    state.forced_cursor,
                ));
            }
        }
        Ok((anchors, leaves, state))
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
        let start_signal_service_witness = if self.params.switch.is_some() &&
            snapshot.checkpoint_height == snapshot.genesis.genesis_height
        {
            self.l1.start_signal_service_witness(&snapshot).await?
        } else {
            None
        };
        crate::types::verify_start_signal_service_witness(
            &snapshot,
            &start.parent.header,
            &self.params,
            start_signal_service_witness.as_ref(),
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
        let (anchors, leaves, end) =
            self.authenticate_blocks(&snapshot, &start, &prefix.blocks).await?;
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
        let parent_anchor = start.anchor.clone();
        let consumed = consumed_anchors(&snapshot, &parent_anchor, &anchors)?;
        let headers = self.l1.reference(&snapshot, &consumed).await?;
        verify_reference_chain(&headers, &consumed)?;
        let reference = &headers[0];
        self.l1.validate_reference(&snapshot, reference.number(), reference.hash()).await?;
        // The initial set signs every height of the batch, so its snapshot is the active one.
        let active_snapshot = start.initial_cutoff;
        if active_snapshot > reference.number() {
            return Err(LanderError::Safety(
                "active committee snapshot lies above the reference block".into(),
            ));
        }
        let input = LandInput {
            // Proof origin p: the latest checkpoint c of the snapshot this batch is built on.
            parentHeight: U256::from(snapshot.checkpoint_height),
            activeCommitteeSnapshot: U256::from(active_snapshot),
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
        Ok(Some(ProofRequest {
            batch: PreparedBatch {
                snapshot,
                parent_header: start.parent.header.clone(),
                start_signal_service_witness,
                grandparent_timestamp: start.parent.grandparent_timestamp,
                parent_anchor,
                starting_inbox_witness: start.inbox_witness.clone(),
                blocks,
                anchors,
                reference_headers: headers.iter().map(|header| header.raw().clone()).collect(),
                input,
                leaves,
                blobs,
                statement_hash: hash,
            },
        }))
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
                self.params.unsettled_limit().saturating_sub(1),
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

/// The anchors a batch's reference chain must reach: p's anchor, every block's anchor and, for a
/// batch from the recovery origin c itself, R. Later batches authenticate the fixed origin
/// record under their starting anchor, so R never ages a generation out of the reference bound.
pub(crate) fn consumed_anchors(
    snapshot: &LandingSnapshot,
    parent_anchor: &AnchorState,
    anchors: &[AnchorState],
) -> Result<Vec<AnchorState>> {
    let mut consumed =
        std::iter::once(parent_anchor.clone()).chain(anchors.iter().cloned()).collect::<Vec<_>>();
    if let Some(origin) = &snapshot.recovery &&
        snapshot.checkpoint_height == origin.height
    {
        consumed.push(recovery_anchor(snapshot)?);
    }
    Ok(consumed)
}

/// Reconstructs R's proof-bound anchor, whose canonicality a recovery generation's checkpoint
/// rechecks and which a batch from c adds to its reference ancestry ([`consumed_anchors`]).
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
        committee_reads: AtomicUsize,
        parent_reads: AtomicUsize,
        status_reads: AtomicUsize,
        block_reads: AtomicUsize,
        val_state_reads: AtomicUsize,
        anchor_reorg: AtomicBool,
        canonical_unavailable: AtomicBool,
        canonical_failure: AtomicBool,
        snapshot_reorg: AtomicBool,
        parent_changed: AtomicBool,
    }

    impl TrackingSource {
        fn new(fixture: Fixture) -> Arc<Self> {
            Arc::new(Self {
                fixture: RwLock::new(Arc::new(fixture)),
                max_batch_blocks: AtomicU64::new(MAX_BATCH_BLOCKS),
                history_reads: AtomicUsize::new(0),
                inbox_reads: AtomicUsize::new(0),
                committee_reads: AtomicUsize::new(0),
                parent_reads: AtomicUsize::new(0),
                status_reads: AtomicUsize::new(0),
                block_reads: AtomicUsize::new(0),
                val_state_reads: AtomicUsize::new(0),
                anchor_reorg: AtomicBool::new(false),
                canonical_unavailable: AtomicBool::new(false),
                canonical_failure: AtomicBool::new(false),
                snapshot_reorg: AtomicBool::new(false),
                parent_changed: AtomicBool::new(false),
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

        async fn parent_anchor(
            &self,
            snapshot: &LandingSnapshot,
            parent: &ParentContext,
        ) -> Result<AnchorState> {
            self.fixture().parent_anchor(snapshot, parent).await
        }

        async fn starting_inbox_witness(
            &self,
            anchor: &AnchorState,
        ) -> Result<abci::AnchorWitness> {
            self.inbox_reads.fetch_add(1, Ordering::Relaxed);
            self.fixture().starting_inbox_witness(anchor).await
        }

        async fn committee_witness(
            &self,
            anchor: &AnchorState,
            snapshot_number: u64,
            epoch: u64,
        ) -> Result<abci::CommitteeWitness> {
            self.committee_reads.fetch_add(1, Ordering::Relaxed);
            self.fixture().committee_witness(anchor, snapshot_number, epoch).await
        }

        async fn fallback_keys(
            &self,
            hash: B256,
            at: B256,
            at_number: u64,
            from_block: u64,
        ) -> Result<abci::fallback::FallbackKeys> {
            self.fixture().fallback_keys(hash, at, at_number, from_block).await
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
        // One start: the grandparent header and the initial committee, read once.
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 1);
        assert_eq!(source.inbox_reads.load(Ordering::Relaxed), 1);
        assert_eq!(source.committee_reads.load(Ordering::Relaxed), 1);
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
        assert_eq!(source.committee_reads.load(Ordering::Relaxed), 1);
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
        assert_eq!(source.inbox_reads.load(Ordering::Relaxed), 2);
        // Each start reads the initial committee once.
        assert_eq!(source.committee_reads.load(Ordering::Relaxed), 2);
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

    /// The start a checkpoint retains holds the generation's initial set, whatever descendants
    /// an observation read, and its snapshot is the genesis cutoff.
    #[tokio::test]
    async fn the_retained_start_holds_the_initial_set() {
        let source = TrackingSource::new(Fixture::new(18, 30));
        let b = source.builder(1);
        let snapshot = source.fixture().snapshot.clone();
        b.validate_checkpoint(&snapshot).await.unwrap();
        b.observe(&snapshot).await.unwrap();
        let start = b.checkpoint(&snapshot).await.unwrap();
        assert_eq!(start.validators.hash(), source.fixture().committees[&0].validators.hash());
        assert_eq!(start.initial_cutoff, snapshot.genesis.genesis_cutoff);
        assert_eq!(source.committee_reads.load(Ordering::Relaxed), 1);
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
        assert_eq!(start.validators.hash(), expected.hash());
        assert_eq!(start.initial_cutoff, snapshot.recovery.as_ref().unwrap().l1_number);
        *b.checkpoint_cache.lock().await = None;
        let rebuilt = b.checkpoint(&snapshot).await.unwrap();
        assert_eq!(rebuilt.validators.hash(), expected.hash());
        assert_eq!(source.fixture().fallback_reads.load(Ordering::SeqCst), 1);
    }

    /// The origin hash comes from the origin record the batch's own starting proof carries, so
    /// no root but the batch's anchors authenticates the set: a snapshot naming another hash is
    /// refused before any list is read.
    #[tokio::test]
    async fn the_starting_proof_binds_the_origin_list_hash() {
        let recovered = crate::test_utils::consensus_mpt::recovery::fixture(8, 12, 18).await;
        let source = TrackingSource::new(recovered);
        let mut snapshot = source.fixture().snapshot.clone();
        snapshot.recovery.as_mut().unwrap().fallback_keys_hash = B256::repeat_byte(0x99);
        let result = source.builder(18).checkpoint(&snapshot).await;
        assert!(
            matches!(&result, Err(LanderError::Safety(message)) if message.contains("fallbackKeysHash")),
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
                2 => changed.genesis_committee_record_hash = alloy_primitives::B256::ZERO,
                _ => unreachable!(),
            }
            assert!(matches!(b.checkpoint(&changed).await, Err(LanderError::Safety(_))));
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

    /// The initial set signs every height, so the active committee snapshot is its genesis
    /// cutoff (1) at any cut, across what the global schedule called switches.
    #[tokio::test]
    async fn terminal_active_committee_snapshot_is_the_initial_sets() {
        use alloy::sol_types::SolValue;
        for (checkpoint, tip, expected) in [(0, 6, 1), (6, 12, 1), (12, 18, 1), (18, 24, 1)] {
            let fixture = Arc::new(Fixture::with_epoch(checkpoint, tip, 0, 12));
            let request = builder(fixture.clone(), limits((tip - checkpoint) as usize))
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .unwrap();
            let encoded = request.batch.input.abi_encode();
            assert_eq!(
                encoded.get(7 * 32..),
                Some(U256::from(expected).to_be_bytes::<32>().as_slice()),
                "checkpoint {checkpoint}, terminal {tip}: eighth ABI word must name the active committee snapshot"
            );
            request.batch.verify_restored().unwrap();
        }
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
        let fixture = source.fixture();
        let parent = fixture.parent_header(&fixture.snapshot).await.unwrap();
        let start = fixture.parent_anchor(&fixture.snapshot, &parent).await.unwrap();
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
        let parent = fixture.parent_header(&fixture.snapshot).await.unwrap();
        let start = fixture.parent_anchor(&fixture.snapshot, &parent).await.unwrap();
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

    #[tokio::test]
    async fn checkpoint_rejects_proving_anchor_not_embedded_in_its_el_header() {
        let mut fixture = Fixture::new(24, 30);
        fixture.parent_anchor_override = Some(fixture.anchors[&20].clone());
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).validate_checkpoint(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
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
        assert_eq!(request.batch.input.activeCommitteeSnapshot, 1);
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
    /// `last_commit` lacks; both certificates must independently satisfy quorum.
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
        // Height 25's `/commit` has the power-1 member's precommit; block 26's `last_commit`
        // omits it, which leaves 3 of 4 power, still a quorum.
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
        let batch = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap()
            .batch;
        assert_eq!(batch.input.lastHeight, 30);
        let reference = alloy_primitives::keccak256(&batch.reference_headers[0]);
        assert_eq!(
            batch.statement_hash,
            statement::hash(
                &batch.snapshot,
                &batch.input,
                reference,
                &batch.blobs.versioned_hashes,
                &batch.leaves
            )
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
        assert_eq!(&preimage[17 * 32..18 * 32], &three);
        assert_eq!(&preimage[18 * 32..19 * 32], &three);
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
    /// tampered history stays a consistently linked, genuinely signed chain.
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
        reseal_from(fixture, height);
    }

    /// Re-signs block `height` after a change to it, then relinks and re-signs every later block,
    /// each carrying its predecessor's new `/commit` as its `last_commit`.
    fn reseal_from(fixture: &mut Fixture, height: u64) {
        let keys = vec![
            crate::test_utils::consensus::SigningKey::from_slice(&[1; 32]).unwrap(),
            crate::test_utils::consensus::SigningKey::from_slice(&[2; 32]).unwrap(),
        ];
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
            crate::test_utils::consensus::resign(pair, &fixture.committees[&0], &keys);
        }
    }

    #[tokio::test]
    async fn starting_inbox_checkpoint_proofs_are_required_and_cannot_be_mutated() {
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

    /// The checkpoint's next-set hash must name the initial set, which also signs the next
    /// height; another set there is refused.
    #[tokio::test]
    async fn checkpoint_next_validator_hash_must_name_the_initial_set() {
        let mut fixture = Fixture::with_epoch(24, 30, 0, 24);
        let (_, other, _) = crate::test_utils::consensus::committee(&[1], 0);
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
            let (genesis, bootstrap) = crate::l1::verify_starting_inbox(
                &request.batch.starting_inbox_witness,
                &request.batch.parent_anchor,
                fixture.params.inbox,
            )
            .unwrap();
            assert_eq!(genesis, request.batch.snapshot.genesis);
            assert_eq!(bootstrap, request.batch.snapshot.genesis_committee_record_hash);
            let headers = request
                .batch
                .reference_headers
                .iter()
                .map(|raw| abci::RawL1Header::from_raw(raw.clone()).unwrap())
                .collect::<Vec<_>>();
            assert!(headers.iter().all(|h| h.number() < request.batch.snapshot.l1_block_number));
            assert_eq!(
                request
                    .batch
                    .starting_inbox_witness
                    .inbox
                    .storage
                    .iter()
                    .map(|p| p.slot)
                    .collect::<Vec<_>>(),
                crate::l1::starting_slots(request.batch.snapshot.generation)
            );
            assert!(
                headers
                    .iter()
                    .any(|h| h.hash() == request.batch.starting_inbox_witness.l1_header.hash())
            );
            let mut changed_parent = request.batch.parent_anchor.clone();
            changed_parent.inbox.last_checkpoint_height += 1;
            assert!(
                crate::l1::verify_starting_inbox(
                    &request.batch.starting_inbox_witness,
                    &changed_parent,
                    fixture.params.inbox
                )
                .is_err()
            );
            assert_eq!(request.batch.input.activeCommitteeSnapshot, 1);
        }
    }

    #[tokio::test]
    async fn registry_address_root_entries_and_snapshot_config_mutations_are_rejected() {
        for mutation in 0..4 {
            let mut fixture = Fixture::new(24, 30);
            fixture.witness_mutation = Some(mutation);
            let fixture = Arc::new(fixture);
            assert!(
                matches!(
                    builder(fixture.clone(), limits(6)).prepare(fixture.snapshot.clone()).await,
                    Err(LanderError::Safety(_))
                ),
                "registry mutation {mutation}"
            );
        }
        for mutation in 0..5 {
            let fixture = Arc::new(Fixture::new(24, 30));
            let mut snapshot = fixture.snapshot.clone();
            match mutation {
                0 => snapshot.committee_config_hash = alloy_primitives::B256::ZERO,
                1 => snapshot.genesis.epoch_len += 1,
                2 => snapshot.genesis.genesis_cutoff += 1,
                3 => snapshot.inbox_witness.address = alloy_primitives::Address::ZERO,
                4 => snapshot.genesis_committee_record_hash = alloy_primitives::B256::ZERO,
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
        /// preimage (0-based words 17 and 18, ENC-A-35), which
        /// must hash to the statement and carry the input's.
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
            assert_eq!(U256::from(word(18)), batch.input.forcedInclusionHead);
            (word(17), word(18))
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
}

#[cfg(test)]
mod prefix_proptests;
