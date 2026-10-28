//! Consecutive, authenticated batch assembly and immutable proof-job construction.

use abci::engine::{
    Engine,
    forced::{ForcedBuildContext, ForcedBuildError, verify_forced},
};
use std::{collections::BTreeMap, sync::Arc, time::Duration};

use abci::{
    AnchorState, ChainParams, GRID_INTERVAL, ParentInfo, Schedule,
    committee::{record_hash, verify_committee_witness_at_cutoff},
    rules,
};
use alloy_primitives::{Address, B256, U256, aliases::U48};
use async_trait::async_trait;
use tokio::sync::Mutex;

use crate::{
    blob,
    codec::{self, PayloadList},
    comet::{CometSource, CometStatus},
    committee::AuthenticatedCommittee,
    config::COMET_BLOCK_MAX_BYTES,
    contracts::IEtnaInbox::LandInput,
    error::{LanderError, Result, engine_diagnostic},
    history,
    l1::{LandingSource, ParentContext},
    proof::ProofRequest,
    statement,
    store::MAX_JOURNAL_BYTES,
    types::{
        CertifiedBlock, CommitteeContext, LandingSnapshot, Limits, PreparedBatch, SidecarMode,
    },
    validate::{EnvelopeContext, verify_body, verify_commit, verify_envelope, verify_structure},
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
    /// The certified tip's anchored unsettled depth has reached `U - 1`.
    pub force_backpressure: bool,
    /// An unlanded switch witness exists anywhere in the decided backlog.
    pub force_epoch: bool,
}

/// Canonical complete-block prefix shared by readiness preview and authenticated preparation.
struct PublishablePrefix {
    /// Exact complete pairs selected without computing signatures, witnesses or KZG proofs.
    blocks: Vec<CertifiedBlock>,
    /// The selected blocks' RLP list.
    list: PayloadList,
    /// The selected blocks' V6 payload, when sizing already compressed it; otherwise its
    /// worst-case size fits and [`BatchBuilder::payload`] compresses it once.
    payload: Option<Vec<u8>>,
}

/// Fully authenticated starting checkpoint and immutable derivation history.
struct BatchStart {
    /// Parent header and ancestry-derived base-fee timestamp.
    parent: ParentContext,
    /// Historical L1 proving anchor authenticated by the checkpoint execution header.
    anchor: AnchorState,
    /// Full schedule/bootstrap/anchor-facts proof retained for the guest.
    inbox_witness: abci::AnchorWitness,
    /// Certified checkpoint block, absent at genesis.
    previous: Option<CertifiedBlock>,
    /// Exact minimal descending checkpoint-bound execution headers.
    history: Vec<alloy_consensus::Header>,
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
    /// Registry whose historical proofs derive the starting committees.
    registry: Address,
    /// Recovery generation carried by the execution history and BFT chain id.
    generation: u64,
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
            height: snapshot.checkpoint_height,
            hash: snapshot.checkpoint_hash,
            comet_hash: snapshot.checkpoint_comet_hash,
            genesis: snapshot.genesis.clone(),
            committee_config_hash: snapshot.committee_config_hash,
            bootstrap_hash: snapshot.genesis_committee_record_hash,
        }
    }
}

/// One fully verified, epoch-bounded starting context; forward descendants are never retained.
struct CachedCheckpoint {
    /// Checkpoint and complete configuration for which the proofs were verified.
    identity: CheckpointIdentity,
    /// Shared ancestry and proofs, copied only when retained in a new immutable proof job.
    start: Arc<BatchStart>,
    /// Only committees derived from committed checkpoint ancestry, cloned before traversal.
    committees: BTreeMap<u64, AuthenticatedCommittee>,
}

/// Constant-space forward authentication state shared by observation and proof preparation.
struct ForwardState {
    /// Exact authenticated committed parent inputs.
    parent: ParentInfo,
    /// Exact execution header whose anchor selects an embedded incoming set.
    header: alloy_consensus::Header,
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
            header: start.parent.header.clone(),
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
    async fn observe(&self, snapshot: &LandingSnapshot) -> Result<BatchObservation>;
    /// Build the largest complete publishable prefix above this coherent checkpoint.
    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>>;
    /// Ensure the current L1 checkpoint identifies this node's certified execution chain.
    async fn validate_checkpoint(&self, snapshot: &LandingSnapshot) -> Result<()>;
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
/// `max_batch_blocks`, whichever is lower, rounded down to whole grid segments
/// ([`GRID_INTERVAL`]). A cap below one segment can never land: a configuration error, which
/// the lander checks before it starts.
pub fn batch_cap(max_blocks: usize, max_batch_blocks: u64) -> Result<usize> {
    let grid = GRID_INTERVAL as usize;
    let deployed = usize::try_from(max_batch_blocks).unwrap_or(usize::MAX);
    let cap = max_blocks.min(deployed) / grid * grid;
    if cap < grid {
        return Err(LanderError::Configuration(format!(
            "batches of at most {max_blocks} configured and {max_batch_blocks} deployed \
             (maxBatchBlocks) blocks cannot hold one {GRID_INTERVAL}-block grid segment"
        )));
    }
    Ok(cap)
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
    /// Retain at most one authenticated epoch-sized context and serialize concurrent misses.
    checkpoint_cache: Mutex<Option<CachedCheckpoint>>,
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
        })
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

    /// Ensure one coherent Inbox context matches the configured chain and genesis schedule.
    fn schedule(&self, snapshot: &LandingSnapshot) -> Result<Schedule> {
        crate::l1::authenticate_snapshot(snapshot, &self.params)?;
        if snapshot.l2_chain_id != self.params.l2_chain_id ||
            snapshot.inbox != self.params.inbox ||
            snapshot.registry != self.params.registry ||
            snapshot.genesis.genesis_height != 0 ||
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
        let schedule = Schedule::from_genesis(&snapshot.genesis);
        schedule
            .validate(self.params.unsettled_cap())
            .map_err(|e| LanderError::Configuration(e.to_string()))?;
        Ok(schedule)
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
        if status.height - snapshot.checkpoint_height > self.params.unsettled_cap() {
            return Err(LanderError::Temporary(
                "Comet tip exceeds this operational checkpoint's unsettled cap; refresh coherent Inbox snapshot".into(),
            ));
        }
        Ok(status)
    }

    /// Select exact complete-block boundaries using canonical codec and blob capacity checks.
    ///
    /// An oversized first block is a capacity error; a later oversized block ends the prefix.
    /// This shared preview performs no signature/MPT validation, reference reads or KZG work.
    /// Each block is validated and encoded once. A prefix whose worst-case compressed size fits
    /// is accepted without deflating it; otherwise it is deflated off the async workers, within
    /// the deflate budget. DA and private block/commit budgets are independent.
    async fn publishable_prefix(
        &self,
        snapshot: &LandingSnapshot,
        _schedule: &Schedule,
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
        let stop = decided_height.min(snapshot.checkpoint_height.saturating_add(most));
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
        // A capacity boundary may split a segment. Retain only complete grid segments.
        while !blocks.len().is_multiple_of(GRID_INTERVAL as usize) {
            blocks.pop();
            list.pop();
            payload = None;
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

    /// Derive an epoch from its authenticated parent snapshot registry proof under an authenticated
    /// anchor.
    async fn committee(
        &self,
        snapshot: &LandingSnapshot,
        anchor: &AnchorState,
        epoch: u64,
        derivation_parent: Option<alloy_consensus::Header>,
        committees: &mut BTreeMap<u64, AuthenticatedCommittee>,
    ) -> Result<()> {
        if committees.contains_key(&epoch) {
            return Ok(());
        }
        let schedule = Schedule::from_genesis(&snapshot.genesis);
        let snapshot_number = history::snapshot_number(derivation_parent.as_ref(), &schedule)?;
        if anchor.number < snapshot_number {
            return Err(LanderError::Safety(
                "committee proving root predates authenticated derivation snapshot".into(),
            ));
        }
        let witness = self.l1.committee_witness(anchor, snapshot_number, epoch).await?;
        let (record, members) = verify_committee_witness_at_cutoff(
            anchor.state_root,
            snapshot_number,
            &self.params,
            &witness,
            epoch,
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
        let hash = record_hash(self.params.l2_chain_id, &record);
        if epoch == 0 && hash != snapshot.genesis_committee_record_hash {
            return Err(LanderError::Safety(
                "derived genesis committee differs from bootstrap".into(),
            ));
        }
        let mut authenticated =
            AuthenticatedCommittee::new(abci::CommitteeState { record, members })
                .map_err(|e| LanderError::Safety(e.to_string()))?;
        authenticated.provenance =
            Some(CommitteeContext { anchor: anchor.clone(), derivation_parent, witness });
        committees.insert(epoch, authenticated);
        Ok(())
    }

    /// Reuse only a fully authenticated checkpoint whose source parent and proving root remain
    /// current. A failed refresh removes the entry; each caller gets separate starting committees.
    async fn checkpoint(
        &self,
        snapshot: &LandingSnapshot,
        schedule: &Schedule,
        committees: &mut BTreeMap<u64, AuthenticatedCommittee>,
    ) -> Result<Arc<BatchStart>> {
        let required = history::requirements(snapshot.checkpoint_height, schedule)?;
        let identity = CheckpointIdentity::from_snapshot(snapshot);
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
            *committees = cached.committees.clone();
            let start = cached.start.clone();
            *retained = Some(cached);
            return Ok(start);
        }
        let mut starting_committees = BTreeMap::new();
        let start = Arc::new(
            self.reconstruct_checkpoint(
                snapshot,
                schedule,
                parent,
                &required,
                &mut starting_committees,
            )
            .await?,
        );
        self.check_proving_anchor_canonicality(&start.anchor).await?;
        *committees = starting_committees.clone();
        *retained = Some(CachedCheckpoint {
            identity,
            start: start.clone(),
            committees: starting_committees,
        });
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

    /// Hash-check all required EL ancestors, historical proofs and the checkpoint BFT certificate.
    async fn reconstruct_checkpoint(
        &self,
        snapshot: &LandingSnapshot,
        schedule: &Schedule,
        mut parent: ParentContext,
        required: &history::HistoryRequirements,
        committees: &mut BTreeMap<u64, AuthenticatedCommittee>,
    ) -> Result<BatchStart> {
        let mut headers = vec![parent.header.clone()];
        for height in (required.oldest..snapshot.checkpoint_height).rev() {
            let header = self.l1.execution_header(height).await?;
            history::check_header_capacity(&header)?;
            headers.push(header);
        }
        let derivations = history::verify(
            history::HistoryInput {
                height: snapshot.checkpoint_height,
                hash: snapshot.checkpoint_hash,
                generation: snapshot.generation,
                schedule,
            },
            &headers,
        )?;
        parent.grandparent_timestamp = headers.get(1).map_or(0, |h| h.timestamp);
        if parent.header.number != snapshot.checkpoint_height ||
            parent.header.hash_slow() != snapshot.checkpoint_hash
        {
            return Err(LanderError::Safety(format!(
                "EL parent disagrees with checkpoint {}",
                snapshot.checkpoint_height
            )));
        }
        let anchor = self.l1.parent_anchor(snapshot, &parent).await?;
        let embedded_number = if parent.header.number == 0 {
            snapshot.genesis.l1_0
        } else {
            rules::decode_extra_data(&parent.header.extra_data)
                .map_err(|e| LanderError::Safety(e.to_string()))?
                .2
        };
        if anchor.number != embedded_number ||
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
        for (epoch, derivation) in derivations {
            self.committee(snapshot, &anchor, epoch, derivation, committees).await?;
        }
        if snapshot.checkpoint_height == 0 {
            if snapshot.checkpoint_hash != snapshot.genesis.genesis_hash ||
                parent.header.state_root != snapshot.genesis.genesis_state_root
            {
                return Err(LanderError::Safety(
                    "genesis checkpoint hash/state root mismatch".into(),
                ));
            }
            return Ok(BatchStart {
                parent,
                anchor,
                inbox_witness: starting_inbox_witness,
                previous: None,
                history: headers,
            });
        }
        let pair = self.comet.block(snapshot.checkpoint_height).await?;
        let epoch = schedule.epoch_of(snapshot.checkpoint_height);
        let envelope = verify_body(&pair, snapshot.checkpoint_height, parent.header.parent_hash)
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
            &committees[&epoch],
            &rules::chain_id_for(&self.params, snapshot.generation)
                .map_err(|e| LanderError::Configuration(e.to_string()))?,
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
        let next_epoch = schedule.epoch_of(
            snapshot
                .checkpoint_height
                .checked_add(1)
                .ok_or_else(|| LanderError::Safety("checkpoint height overflow".into()))?,
        );
        if pair.block.header.next_validators_hash != committees[&next_epoch].validators.hash() {
            return Err(LanderError::Safety("checkpoint next validator hash disagrees".into()));
        }
        Ok(BatchStart {
            parent,
            anchor,
            inbox_witness: starting_inbox_witness,
            previous: Some(pair),
            history: headers,
        })
    }
    /// Verify one successor using a known outgoing certificate before accepting new authorities.
    ///
    /// Both the carried parent certificate and the current certificate must verify before
    /// authenticated committees or execution facts can advance.
    async fn authenticate_block(
        &self,
        snapshot: &LandingSnapshot,
        schedule: &Schedule,
        state: &mut ForwardState,
        committees: &mut BTreeMap<u64, AuthenticatedCommittee>,
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
        let epoch = schedule.epoch_of(height);
        if !committees.contains_key(&epoch) {
            return Err(LanderError::Safety(format!(
                "missing authenticated signing committee {epoch}"
            )));
        }
        let envelope = verify_structure(pair, state.previous.as_ref(), height, state.parent.hash)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        if let (Some(last), Some(previous)) = (&pair.block.last_commit, state.previous.as_ref()) {
            let prev_epoch = schedule.epoch_of(height - 1);
            verify_commit(last, &previous.block.header, &committees[&prev_epoch], &chain_id)
                .map_err(|e| LanderError::Safety(e.to_string()))?;
        }
        verify_commit(&pair.commit, &pair.block.header, &committees[&epoch], &chain_id)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        let bft_secs = u64::try_from(pair.block.header.time.unix_timestamp())
            .map_err(|_| LanderError::Safety("negative BFT block timestamp".into()))?;
        let facts = verify_envelope(
            envelope,
            EnvelopeContext {
                bft_time_secs: bft_secs,
                proposer: pair.block.header.proposer_address,
                committees,
                parent: &state.parent,
                parent_anchor: &state.anchor,
                generation: snapshot.generation,
                genesis: &snapshot.genesis,
                params: &self.params,
                forced_cursor: state.forced_cursor,
            },
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
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
                LanderError::Temporary(format!(
                    "forced parent lookup at {}: {}",
                    probe_context(),
                    engine_diagnostic(&error),
                ))
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
            ForcedBuildError::Engine(error) => LanderError::Temporary(format!(
                "forced singleton build at {}: {}",
                probe_context(),
                engine_diagnostic(&error),
            )),
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
        if let Some(derived) = facts.derived {
            let epoch = derived.record.target_epoch;
            if let Some(existing) = committees.get(&epoch) &&
                existing.state != derived
            {
                return Err(LanderError::Safety(format!(
                    "derived committee {epoch} conflicts with authenticated context"
                )));
            }
            let mut committee = AuthenticatedCommittee::new(derived)
                .map_err(|e| LanderError::Safety(e.to_string()))?;
            committee.provenance = Some(CommitteeContext {
                anchor: facts.anchor.clone(),
                derivation_parent: Some(state.header.clone()),
                witness: facts.envelope.committee.clone().expect("verified switch witness"),
            });
            committees.entry(epoch).or_insert(committee);
        }
        let next_epoch = schedule.epoch_of(
            height.checked_add(1).ok_or_else(|| LanderError::Safety("height overflow".into()))?,
        );
        if !committees.contains_key(&next_epoch) {
            return Err(LanderError::Safety(format!(
                "missing authenticated next committee {next_epoch}"
            )));
        }
        if pair.block.header.next_validators_hash != committees[&next_epoch].validators.hash() {
            return Err(LanderError::Safety(format!(
                "next validator hash disagrees at height {height}"
            )));
        }
        state.header = facts.envelope.block.header.clone();
        state.parent = facts.parent;
        state.anchor = facts.anchor;
        state.previous = Some(pair.clone());
        state.forced_cursor = forced_cursor;
        Ok(())
    }

    /// Retain only the selected proof prefix's per-block anchors after shared verification, the
    /// forced inclusion cursor after its last block.
    async fn authenticate_blocks(
        &self,
        snapshot: &LandingSnapshot,
        schedule: &Schedule,
        start: &BatchStart,
        committees: &mut BTreeMap<u64, AuthenticatedCommittee>,
        blocks: &[CertifiedBlock],
    ) -> Result<(Vec<AnchorState>, u64, Vec<B256>)> {
        let mut state = ForwardState::new(start, snapshot)?;
        let mut anchors = Vec::new();
        let mut leaves = Vec::new();
        for pair in blocks {
            self.authenticate_block(snapshot, schedule, &mut state, committees, pair).await?;
            anchors.push(state.anchor.clone());
            if state.parent.number.is_multiple_of(GRID_INTERVAL) &&
                blocks
                    .last()
                    .is_some_and(|last| last.block.header.height.value() != state.parent.number)
            {
                leaves.push(statement::cut_leaf(
                    state.parent.number,
                    state.parent.hash,
                    B256::from_slice(pair.block.header.hash().as_bytes()),
                    state.forced_cursor,
                ));
            }
        }
        Ok((anchors, state.forced_cursor, leaves))
    }
}

#[async_trait]
impl<C: CometSource + ?Sized, L: LandingSource + ?Sized> BatchSource for BatchBuilder<C, L> {
    /// Authenticate the coherent checkpoint against this source's certified chain.
    async fn validate_checkpoint(&self, snapshot: &LandingSnapshot) -> Result<()> {
        let schedule = self.schedule(snapshot)?;
        self.status(snapshot).await?;
        self.checkpoint(snapshot, &schedule, &mut BTreeMap::new()).await?;
        Ok(())
    }

    /// Preview capacity and authenticate the tip's historical anchor for urgency decisions.
    async fn observe(&self, snapshot: &LandingSnapshot) -> Result<BatchObservation> {
        let schedule = self.schedule(snapshot)?;
        let status = self.status(snapshot).await?;
        if status.height == snapshot.checkpoint_height {
            return Ok(BatchObservation {
                decided_height: status.height,
                publishable_blocks: 0,
                force_backpressure: false,
                force_epoch: false,
            });
        }
        let prefix = self.publishable_prefix(snapshot, &schedule, status.height).await?;
        let mut committees = BTreeMap::new();
        let start = self.checkpoint(snapshot, &schedule, &mut committees).await?;
        let mut state = ForwardState::new(&start, snapshot)?;
        for pair in &prefix.blocks {
            self.authenticate_block(snapshot, &schedule, &mut state, &mut committees, pair).await?;
        }
        let fetched = state.parent.number;
        for height in fetched + 1..=status.height {
            let pair = self.comet.block(height).await?;
            self.authenticate_block(snapshot, &schedule, &mut state, &mut committees, &pair)
                .await?;
        }
        let anchor = &state.anchor;
        Ok(BatchObservation {
            decided_height: status.height,
            publishable_blocks: prefix.blocks.len(),
            force_backpressure: status.height.saturating_sub(anchor.inbox.last_checkpoint_height) >=
                self.params.unsettled_cap().saturating_sub(1),
            // A decided switch witness justifies publication even outside this prefix.
            force_epoch: force_epoch(&schedule, status.height, snapshot.checkpoint_height),
        })
    }

    /// Authenticate the selected prefix and construct its immutable statement and sidecar.
    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>> {
        let schedule = self.schedule(&snapshot)?;
        let status = self.status(&snapshot).await?;
        if status.height == snapshot.checkpoint_height {
            return Ok(None);
        }
        let mut committees = BTreeMap::new();
        let start = self.checkpoint(&snapshot, &schedule, &mut committees).await?;
        let prefix = self.publishable_prefix(&snapshot, &schedule, status.height).await?;
        let (anchors, forced_cursor, leaves) = self
            .authenticate_blocks(&snapshot, &schedule, &start, &mut committees, &prefix.blocks)
            .await?;
        if prefix.blocks.is_empty() {
            return Ok(None);
        }
        let (blocks, payload) = self.payload(prefix).await?;
        let Some(terminal) = blocks.last() else {
            return Ok(None);
        };
        let last = abci::EtnaEnvelope::decode(&terminal.block.data[0])
            .map_err(|e| LanderError::Safety(e.to_string()))?
            .block
            .header;
        let parent_anchor = start.anchor.clone();
        let consumed = std::iter::once(parent_anchor.clone())
            .chain(anchors.iter().cloned())
            .collect::<Vec<_>>();
        let headers = self.l1.reference(&snapshot, &consumed).await?;
        verify_reference_chain(&headers, &consumed)?;
        let reference = &headers[0];
        self.l1.validate_reference(&snapshot, reference.number(), reference.hash()).await?;
        let active_epoch = schedule.epoch_of(last.number);
        let active_committee = committees.get(&active_epoch).ok_or_else(|| {
            LanderError::Safety(format!("missing active committee {active_epoch}"))
        })?;
        let provenance = active_committee.provenance.as_ref().ok_or_else(|| {
            LanderError::Safety(format!("missing active committee {active_epoch} provenance"))
        })?;
        let active_snapshot =
            history::snapshot_number(provenance.derivation_parent.as_ref(), &schedule)?;
        if active_snapshot != active_committee.state.record.cutoff_l1_block ||
            active_snapshot > reference.number()
        {
            return Err(LanderError::Safety(
                "active committee snapshot contradicts authenticated provenance".into(),
            ));
        }
        let input = LandInput {
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
                execution_history: start.history.clone(),
                grandparent_timestamp: start.parent.grandparent_timestamp,
                parent_anchor,
                starting_inbox_witness: start.inbox_witness.clone(),
                blocks,
                anchors,
                reference_headers: headers.iter().map(|header| header.raw().clone()).collect(),
                committee_witnesses: committees
                    .values()
                    .filter_map(|c| c.provenance.clone())
                    .collect(),
                committees: committees.into_values().map(|committee| committee.state).collect(),
                input,
                leaves,
                deployment_identity: deployment.identity,
                blobs,
                statement_hash: hash,
            },
        }))
    }
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

/// Whether a decided switch is still unlanded: the decided `tip` is a switch height, the next
/// switch height lies in `(checkpoint, tip]`, or the switch into `tip`'s epoch lies above
/// `checkpoint`. Switch heights are computed with checked arithmetic; one beyond `u64` does not
/// exist.
fn force_epoch(schedule: &Schedule, tip: u64, checkpoint: u64) -> bool {
    let switch_height = |epoch: u64| schedule.checked_h_first(epoch).map(|h| h.saturating_sub(2));
    let epoch = schedule.epoch_of(tip);
    schedule.switch_target(tip).is_some() ||
        epoch
            .checked_add(1)
            .and_then(switch_height)
            .is_some_and(|next| next <= tip && next > checkpoint) ||
        epoch > 0 && switch_height(epoch).is_some_and(|current| current > checkpoint)
}

/// Independently checks the exact descending header chain and every consumed anchor.
///
/// The source authenticates finality/canonicality; this pure check prevents an adapter from
/// silently changing a per-block anchor while selecting a newer L1 reference.
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
        anchor_reorg: AtomicBool,
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
                anchor_reorg: AtomicBool::new(false),
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
            self.fixture().block(height).await
        }

        async fn committee(&self, epoch: u64) -> Result<abci::CommitteeState> {
            self.fixture().committee(epoch).await
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

        async fn reference(
            &self,
            snapshot: &LandingSnapshot,
            anchors: &[AnchorState],
        ) -> Result<Vec<abci::RawL1Header>> {
            self.fixture().reference(snapshot, anchors).await
        }

        async fn deployment(&self, snapshot: &LandingSnapshot) -> Result<crate::l1::Deployment> {
            let deployment = self.fixture().deployment(snapshot).await?;
            let max_batch_blocks = self.max_batch_blocks.load(Ordering::Relaxed);
            Ok(crate::l1::Deployment { max_batch_blocks, ..deployment })
        }
        async fn canonical_hash(&self, number: u64) -> Result<alloy_primitives::B256> {
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

    #[tokio::test]
    async fn v1_grid_prefix_stops_at_last_complete_six_block_segment() {
        let fixture = Arc::new(Fixture::new(0, 8));
        let batch = builder(fixture.clone(), limits(8))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap()
            .batch;
        assert_eq!(batch.input.parentHeight, U256::ZERO);
        assert_eq!(batch.input.lastHeight, U256::from(6));
        assert_eq!(batch.blocks.len(), 6);
        assert!(batch.leaves.is_empty());
    }

    #[tokio::test]
    async fn unchanged_checkpoint_reuses_history_across_validation_observation_and_preparation() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        let snapshot = source.fixture().snapshot.clone();
        b.validate_checkpoint(&snapshot).await.unwrap();
        b.observe(&snapshot).await.unwrap();
        let request = b.prepare(snapshot.clone()).await.unwrap().unwrap();
        assert_eq!(request.batch.execution_history.len(), 3);
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 2);
        assert_eq!(source.inbox_reads.load(Ordering::Relaxed), 1);
        // Checkpoint 24 is H(1)-1, so both outgoing and pending committees are required.
        assert_eq!(source.committee_reads.load(Ordering::Relaxed), 2);
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
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 2);
        assert_eq!(source.inbox_reads.load(Ordering::Relaxed), 1);
        // Checkpoint 24 is H(1)-1, so both outgoing and pending committees are required.
        assert_eq!(source.committee_reads.load(Ordering::Relaxed), 2);
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
        assert_eq!(source.history_reads.load(Ordering::Relaxed), reads + 2);
    }

    #[tokio::test]
    async fn checkpoint_progress_replaces_the_retained_context() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        b.validate_checkpoint(&source.fixture().snapshot).await.unwrap();
        *source.fixture.write().unwrap() = Arc::new(Fixture::new(30, 30));
        b.validate_checkpoint(&source.fixture().snapshot).await.unwrap();
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 10);
        assert_eq!(source.inbox_reads.load(Ordering::Relaxed), 2);
        // The old checkpoint needs two committees; checkpoint 30 needs only epoch 1.
        assert_eq!(source.committee_reads.load(Ordering::Relaxed), 3);
        b.validate_checkpoint(&source.fixture().snapshot).await.unwrap();
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 10);
    }

    #[tokio::test]
    async fn cached_checkpoint_rejects_a_reorganized_operational_snapshot_and_rebuilds() {
        let source = TrackingSource::new(Fixture::new(24, 30));
        let b = source.builder(6);
        let snapshot = source.fixture().snapshot.clone();
        b.validate_checkpoint(&snapshot).await.unwrap();
        source.snapshot_reorg.store(true, Ordering::Relaxed);
        assert!(matches!(b.validate_checkpoint(&snapshot).await, Err(LanderError::Stale(_))));
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 2);
        source.snapshot_reorg.store(false, Ordering::Relaxed);
        b.validate_checkpoint(&snapshot).await.unwrap();
        assert_eq!(source.history_reads.load(Ordering::Relaxed), 4);
    }

    #[tokio::test]
    async fn observation_does_not_cache_a_descendants_committee_as_a_starting_authority() {
        let source = TrackingSource::new(Fixture::new(18, 30));
        let b = source.builder(1);
        let snapshot = source.fixture().snapshot.clone();
        b.validate_checkpoint(&snapshot).await.unwrap();
        b.observe(&snapshot).await.unwrap();
        let mut starting = BTreeMap::new();
        b.checkpoint(&snapshot, &Schedule::from_genesis(&snapshot.genesis), &mut starting)
            .await
            .unwrap();
        assert_eq!(starting.keys().copied().collect::<Vec<_>>(), vec![0]);
        assert_eq!(source.committee_reads.load(Ordering::Relaxed), 1);
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
            assert!(matches!(
                b.checkpoint(
                    &changed,
                    &Schedule::from_genesis(&changed.genesis),
                    &mut BTreeMap::new(),
                )
                .await,
                Err(LanderError::Safety(_))
            ));
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

    #[test]
    fn batch_cap_is_the_lower_limit_in_whole_grid_segments() {
        assert_eq!(batch_cap(16, u64::MAX).unwrap(), 12);
        assert_eq!(batch_cap(100, 120).unwrap(), 96);
        assert_eq!(batch_cap(100, 13).unwrap(), 12);
        assert_eq!(batch_cap(6, 6).unwrap(), 6);
        for (max_blocks, max_batch_blocks) in [(5, 120), (100, 5), (0, 0)] {
            assert!(
                matches!(
                    batch_cap(max_blocks, max_batch_blocks),
                    Err(LanderError::Configuration(_))
                ),
                "{max_blocks} configured, {max_batch_blocks} deployed"
            );
        }
    }

    /// However many blocks `--max-blocks` allows, observation and selection never exceed the
    /// deployed Inbox's `maxBatchBlocks`, rounded down to whole grid segments, so a landing never
    /// reverts `BatchTooLarge`.
    #[tokio::test]
    async fn selection_never_exceeds_the_deployed_max_batch_blocks() {
        let fixture = Arc::new(Fixture::new(0, 18));
        for (max_batch_blocks, expected) in [(120, 18), (17, 12), (12, 12), (7, 6)] {
            let builder = builder_with(fixture.clone(), limits(18), max_batch_blocks);
            let observed = builder.observe(&fixture.snapshot).await.unwrap();
            assert_eq!(observed.publishable_blocks, expected, "maxBatchBlocks {max_batch_blocks}");
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

    #[tokio::test]
    async fn terminal_active_committee_snapshot_tracks_activation_and_mid_epoch_cuts() {
        use alloy::sol_types::SolValue;
        for (checkpoint, tip, expected) in [(0, 6, 1), (6, 12, 1), (12, 18, 11)] {
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
            request.batch.validate_statement().unwrap();
        }
    }

    #[tokio::test]
    async fn later_epochs_and_partial_batches_restore_the_terminal_active_cutoff() {
        for (checkpoint, tip, expected) in
            [(6, 12, 1), (12, 18, 11), (18, 24, 11), (24, 30, 13), (30, 36, 13)]
        {
            let fixture = Arc::new(Fixture::with_progressing_epochs(checkpoint, tip));
            let batch = builder(fixture.clone(), limits((tip - checkpoint) as usize))
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .unwrap()
                .batch;
            assert_eq!(batch.input.activeCommitteeSnapshot, expected, "{checkpoint}..{tip}");
            assert_eq!(batch.input.lastHeight, tip);
            batch.validate_statement().unwrap();
            let restored: PreparedBatch =
                serde_json::from_slice(&serde_json::to_vec(&batch).unwrap()).unwrap();
            restored.validate_statement().unwrap();
        }
    }

    #[tokio::test]
    async fn durable_cutoff_rejects_rebound_digest_and_forged_committee_provenance() {
        for checkpoint in [6, 12, 24] {
            let fixture = Arc::new(if checkpoint == 24 {
                Fixture::new(24, 30)
            } else {
                Fixture::with_epoch(checkpoint, checkpoint + 6, 0, 12)
            });
            let batch = builder(fixture.clone(), limits(6))
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .unwrap()
                .batch;
            batch.validate_statement().unwrap();
            let reference =
                abci::RawL1Header::from_raw(batch.reference_headers[0].clone()).unwrap();
            for bit in 0..64 {
                let mut changed = batch.clone();
                changed.input.activeCommitteeSnapshot ^= U256::from(1) << bit;
                changed.statement_hash = statement::hash(
                    &changed.snapshot,
                    &changed.input,
                    reference.hash(),
                    &changed.blobs.versioned_hashes,
                    &changed.leaves,
                );
                assert!(
                    changed.validate_statement().is_err(),
                    "checkpoint {checkpoint}, cutoff bit {bit}"
                );
            }
            if checkpoint != 6 {
                let epoch = Schedule::from_genesis(&batch.snapshot.genesis)
                    .epoch_of(crate::types::protocol_u48(batch.input.lastHeight).unwrap());
                for mutation in 0..5 {
                    let mut changed = batch.clone();
                    let provenance = changed
                        .committee_witnesses
                        .iter_mut()
                        .find(|context| context.witness.record.target_epoch == epoch)
                        .unwrap();
                    match mutation {
                        0 => provenance.derivation_parent = None,
                        1 => provenance.derivation_parent.as_mut().unwrap().number += 1,
                        2 => provenance.witness.record.cutoff_l1_block += 1,
                        3 => {
                            provenance.derivation_parent.as_mut().unwrap().extra_data =
                                rules::encode_extra_data(0, 12).unwrap()
                        }
                        4 => provenance.anchor.hash = B256::ZERO,
                        _ => unreachable!(),
                    }
                    assert!(
                        changed.validate_statement().is_err(),
                        "checkpoint {checkpoint}, provenance mutation {mutation}"
                    );
                }
            }
        }
    }

    #[tokio::test]
    async fn mid_epoch_uses_derivation_parent_snapshot_after_anchor_moves() {
        let fixture = Arc::new(Fixture::new(24, 30));
        let request = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        let incoming =
            request.batch.committees.iter().find(|c| c.record.target_epoch == 1).unwrap();
        assert_eq!(incoming.record.cutoff_l1_block, 11);
        assert_eq!(request.batch.parent_anchor.number, 12);
    }

    #[tokio::test]
    async fn pending_incoming_committee_survives_switch_checkpoint_and_one_block_cut() {
        for (checkpoint, tip) in [(6, 12), (12, 18)] {
            let fixture = Arc::new(Fixture::with_epoch(checkpoint, tip, 0, 12));
            let request = builder(fixture.clone(), limits(6))
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .unwrap();
            let next =
                request.batch.committees.iter().find(|c| c.record.target_epoch == 1).unwrap();
            assert_eq!(next.record.cutoff_l1_block, 11);
            let context = request
                .batch
                .committee_witnesses
                .iter()
                .find(|c| c.witness.record.target_epoch == 1)
                .unwrap();
            assert_eq!(context.derivation_parent.as_ref().unwrap().number, 10);
            assert_eq!(
                request.batch.grandparent_timestamp,
                fixture.headers[&(checkpoint - 1)].timestamp
            );
            let restored: PreparedBatch =
                serde_json::from_slice(&serde_json::to_vec(&request.batch).unwrap()).unwrap();
            assert_eq!(restored, request.batch);
        }
    }

    #[tokio::test]
    async fn builder_and_observe_reject_missing_and_forged_required_history() {
        for mutation in 0..5 {
            let mut fixture = Fixture::new(24, 30);
            match mutation {
                0 => {
                    fixture.headers.remove(&22);
                }
                1 => fixture.headers.get_mut(&22).unwrap().number = 23,
                2 => {
                    fixture.headers.get_mut(&23).unwrap().parent_hash = alloy_primitives::B256::ZERO
                }
                3 => {
                    fixture.headers.get_mut(&22).unwrap().extra_data =
                        abci::rules::encode_extra_data(1, 11).unwrap()
                }
                4 => {
                    fixture.headers.get_mut(&22).unwrap().parent_beacon_block_root =
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
                    assert!(error.to_string().contains("height 22"));
                } else {
                    assert!(matches!(error, LanderError::Safety(_)), "{error}");
                }
            }
        }
    }

    #[test]
    fn force_epoch_flags_unlanded_switches_without_overflowing() {
        // L = 10: the switch heights are 9 (to epoch 1) and 19 (to epoch 2).
        let base = Schedule { l1_0: 10, epoch_len: 10, genesis_cutoff: 1 };
        for (tip, checkpoint, expected) in [
            (5, 0, false),
            (9, 0, true),
            (10, 0, true),
            (10, 9, false),
            (12, 7, true),
            (12, 9, false),
            (19, 12, true),
        ] {
            assert_eq!(force_epoch(&base, tip, checkpoint), expected, "tip {tip} cp {checkpoint}");
        }
        // The same answer as the former unchecked expression wherever that one did not overflow.
        for epoch_len in [3, 10, 20] {
            let s = Schedule { epoch_len, ..base };
            for tip in 1..100 {
                let epoch = s.epoch_of(tip);
                for checkpoint in 0..=tip {
                    let former = s.switch_target(tip).is_some() ||
                        s.h_first(epoch + 1) - 2 <= tip && s.h_first(epoch + 1) - 2 > checkpoint ||
                        epoch > 0 && s.h_first(epoch) - 2 > checkpoint;
                    assert_eq!(
                        force_epoch(&s, tip, checkpoint),
                        former,
                        "L={epoch_len} {tip}/{checkpoint}"
                    );
                }
            }
        }
        // Unvalidated L = u64::MAX: h_first(1) overflows, so epoch 1 has no switch height.
        let unbounded = Schedule { epoch_len: u64::MAX, ..base };
        for tip in [1, 2, i64::MAX as u64] {
            assert!(!force_epoch(&unbounded, tip, 0), "tip {tip}");
        }
    }

    /// A complete prefix that crosses epoch boundaries is published whole.
    #[tokio::test]
    async fn no_freeze_cutoff_in_complete_prefix() {
        for checkpoint in [18, 24, 30] {
            let fixture = Arc::new(Fixture::new(checkpoint, 36));
            let builder = builder(fixture.clone(), limits(20));
            let schedule = builder.schedule(&fixture.snapshot).unwrap();
            let prefix =
                builder.publishable_prefix(&fixture.snapshot, &schedule, 36).await.unwrap();
            assert_eq!(prefix.blocks.len(), (36 - checkpoint) as usize, "{checkpoint}");
        }
    }

    #[tokio::test]
    async fn no_freeze_only_publication_urgency() {
        for checkpoint in [24] {
            let fixture = Arc::new(Fixture::new(checkpoint, 30));
            let observed =
                builder(fixture.clone(), limits(20)).observe(&fixture.snapshot).await.unwrap();
            assert!(!observed.force_epoch, "{checkpoint}");
            assert!(!observed.force_backpressure, "{checkpoint}");
        }
    }

    #[tokio::test]
    async fn observe_authenticates_switch_beyond_capacity_limited_prefix() {
        let fixture = Arc::new(Fixture::new(18, 30));
        let observed =
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.publishable_blocks, 0);
        assert_eq!(observed.decided_height, 30);
        assert!(observed.force_epoch);
        let mut fixture = Fixture::new(18, 30);
        alter_envelope(&mut fixture, 23, |e| e.committee = None);
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
        let mut fixture = Fixture::new(18, 30);
        fixture.blocks.get_mut(&21).unwrap().commit.signatures.clear();
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
    }

    #[tokio::test]
    async fn oversized_history_rejects_before_reading_any_source_header() {
        let fixture = Arc::new(Fixture::new(24, 30));
        let b = builder(fixture.clone(), limits(1));
        let mut snapshot = fixture.snapshot.clone();
        snapshot.checkpoint_height = 199_999;
        let mut schedule = Schedule::from_genesis(&snapshot.genesis);
        schedule.epoch_len = 100_000;
        // The fixture source has no header at this height and panics if called: capacity must
        // reject before either parent_header or execution_header is invoked.
        let error = b
            .checkpoint(&snapshot, &schedule, &mut BTreeMap::new())
            .await
            .err()
            .expect("operational history cap");
        assert!(matches!(error, LanderError::Capacity(_)));
    }

    /// The builder holds every block to the snapshot genesis's `maxAnchorAge`: block 1 of the
    /// fixture (101 s) uses anchor 10 (10 s), an anchor age of 91 s.
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
        for observation in [false, true] {
            let b = builder(fixture.clone(), limits(6));
            let error = if observation {
                b.observe(&fixture.snapshot).await.unwrap_err()
            } else {
                b.prepare(fixture.snapshot.clone()).await.unwrap_err()
            };
            assert!(matches!(error, LanderError::Safety(_)), "{error}");
            assert!(error.to_string().contains(&violation.to_string()), "{error}");
        }
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
        assert_eq!(request.batch.committee_witnesses.len(), 1);
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

    /// Epoch changes retain every authenticated block and bind their exact base fees.
    #[tokio::test]
    async fn prepared_batch_binds_execution_across_epoch_boundary() {
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
            batch.validate_statement().unwrap();
        }
    }

    /// CometBFT's `/commit` for a height can carry precommits that block `h + 1`'s canonical
    /// `last_commit` lacks; both certificates must independently satisfy quorum.
    #[tokio::test]
    async fn canonical_last_commit_is_verified_independently_of_the_seen_commit() {
        let mut fixture = Fixture::new(24, 30);
        let key = crate::test_utils::consensus::SigningKey::from_slice(&[2; 32]).unwrap();
        let pubkey = crate::test_utils::consensus::public_key(&key);
        let slot = fixture.committees[&1]
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
        let fixture = Arc::new(Fixture::new(0, 6));
        let snapshot = fixture.snapshot_with_forced_queue(fixture.snapshot.genesis.clone(), 3, 9);
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
    async fn middle_epoch_batch_authenticates_h_plus_two_switch_and_derives_exact_next_record() {
        let fixture = Arc::new(Fixture::new(18, 30));
        let snapshot = fixture.snapshot.clone();
        let request =
            builder(fixture.clone(), limits(12)).prepare(snapshot).await.unwrap().unwrap();
        let batch = &request.batch;
        assert_eq!(batch.input.lastHeight, 30);
        assert_eq!(batch.committee_witnesses.len(), 2);
        assert_eq!(
            batch
                .committees
                .iter()
                .map(|committee| committee.record.target_epoch)
                .collect::<Vec<_>>(),
            vec![0, 1]
        );
        // Canonical L=24: D=22, S=23, H=25. S and S+1 retain the outgoing set.
        for (index, height) in [(4, 23), (5, 24)] {
            assert_eq!(batch.blocks[index].block.header.height.value(), height);
            assert_eq!(
                batch.blocks[index].block.header.validators_hash,
                fixture.committees[&0].validators.hash()
            );
        }
        assert_eq!(
            batch.blocks[5].block.header.next_validators_hash,
            fixture.committees[&1].validators.hash()
        );
        assert_eq!(batch.blocks[6].block.header.height.value(), 25);
        assert_eq!(
            batch.blocks[6].block.header.validators_hash,
            fixture.committees[&1].validators.hash()
        );
        assert_ne!(
            fixture.committees[&0].validators.hash(),
            fixture.committees[&1].validators.hash()
        );
        let incoming = batch
            .committee_witnesses
            .iter()
            .find(|context| context.witness.record.target_epoch == 1)
            .unwrap();
        assert_eq!(incoming.derivation_parent.as_ref().unwrap().number, 22);
        assert_eq!(incoming.witness.record.cutoff_l1_block, 11);
        assert_eq!(incoming.anchor.number, 12);
        assert_eq!(batch.parent_anchor.number, 11);
        assert_eq!(batch.anchors[3].number, 11);
        assert_eq!(batch.anchors[4].number, 12);
        assert_eq!(batch.input.l1ReferenceBlockNumber, 14);
        let restored: PreparedBatch =
            serde_json::from_slice(&serde_json::to_vec(batch).unwrap()).unwrap();
        assert_eq!(&restored, batch);
        restored.validate_statement().unwrap();
        let mut wrong = restored;
        wrong
            .committee_witnesses
            .iter_mut()
            .find(|context| context.witness.record.target_epoch == 1)
            .unwrap()
            .derivation_parent
            .as_mut()
            .unwrap()
            .number = 21;
        assert!(
            wrong.validate_statement().is_err(),
            "old D=21 cannot authorize the restored batch"
        );
    }

    #[tokio::test]
    async fn chooses_whole_block_prefix_and_reports_oversized_first_height() {
        let fixture = Arc::new(Fixture::new(0, 6));
        let first = codec::encode(&[fixture.blocks[&1].clone()], &limits(6)).unwrap();
        let mut bound = limits(6);
        bound.max_payload_bytes = first.len();
        assert!(
            builder(fixture.clone(), bound)
                .prepare(fixture.snapshot.clone())
                .await
                .unwrap()
                .is_none()
        );
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
        assert!(error.to_string().contains("deployment identity"), "{error}");
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
        let schedule = abci::Schedule::from_genesis(&fixture.snapshot.genesis);
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
            let committee = &fixture.committees[&schedule.epoch_of(h)];
            crate::test_utils::consensus::resign(pair, committee, &keys);
        }
    }

    #[tokio::test]
    async fn missing_extra_and_wrong_epoch_committee_witnesses_are_rejected() {
        let mut fixture = Fixture::new(18, 30);
        alter_envelope(&mut fixture, 23, |envelope| envelope.committee = None);
        let fixture = Arc::new(fixture);
        let error = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)));
        assert!(error.to_string().contains("required committee witness"));
        let mut fixture = Fixture::new(18, 30);
        let extra =
            abci::EtnaEnvelope::decode(&fixture.blocks[&23].block.data[0]).unwrap().committee;
        alter_envelope(&mut fixture, 22, |envelope| envelope.committee = extra);
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(6)).prepare(fixture.snapshot.clone()).await,
            Err(LanderError::Safety(_))
        ));
        let mut fixture = Fixture::new(18, 30);
        alter_envelope(&mut fixture, 23, |envelope| {
            envelope.committee.as_mut().unwrap().record.target_epoch = 2
        });
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(6)).prepare(fixture.snapshot.clone()).await,
            Err(LanderError::Safety(_))
        ));
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

    #[tokio::test]
    async fn checkpoint_pending_next_validator_hash_is_independently_authenticated() {
        let mut fixture = Fixture::with_epoch(24, 30, 0, 24);
        let pair = fixture.blocks.get_mut(&24).unwrap();
        pair.block.header.next_validators_hash = fixture.committees[&0].validators.hash();
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
            .expect_err("checkpoint next hash must derive pending epoch 1 from L1");
        assert!(error.to_string().contains("next validator hash"), "{error}");
    }

    #[tokio::test]
    async fn arbitrary_batch_cuts_rederive_starting_and_pending_committees_without_hints() {
        // Every complete prefix crosses the epoch boundary when capacity permits.
        for (checkpoint, tip, last) in
            [(18, 30, 30), (24, 30, 30), (30, 39, 36), (18, 36, 36), (24, 36, 36)]
        {
            let mut fixture = Fixture::new(checkpoint, tip);
            fixture.reject_committee_hints = true;
            let fixture = Arc::new(fixture);
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
                crate::l1::snapshot_slots()
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
            for context in &request.batch.committee_witnesses {
                assert!(headers.iter().any(|h| h.hash() == context.anchor.hash &&
                    h.state_root() == context.anchor.state_root));
            }

            assert_eq!(request.batch.committees.len(), request.batch.committee_witnesses.len());
            for (committee, context) in
                request.batch.committees.iter().zip(&request.batch.committee_witnesses)
            {
                assert_eq!(committee.record, context.witness.record);
                assert!(context.anchor.number >= committee.record.cutoff_l1_block);
            }
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
        /// preimage (words 16 and 17, before the L1 and L2 recipients), which
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

        /// The batch errors with a safety error naming `violation`, in preparation and observation.
        async fn assert_safety(fixture: Fixture, violation: &str) {
            let fixture = Arc::new(fixture);
            for observation in [false, true] {
                let b = builder(fixture.clone(), limits(6));
                let error = if observation {
                    b.observe(&fixture.snapshot).await.unwrap_err()
                } else {
                    b.prepare(fixture.snapshot.clone()).await.unwrap_err()
                };
                assert!(matches!(error, LanderError::Safety(_)), "{error}");
                assert!(error.to_string().contains(violation), "{error}");
            }
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

            // A stored head past the entry block 2 consumes contradicts the decided chain.
            let snapshot = fixture.snapshot_with_forced_queue(snapshot.genesis.clone(), 1, 1);
            let error = builder(fixture.clone(), limits(6)).prepare(snapshot).await.unwrap_err();
            assert!(matches!(error, LanderError::Safety(_)), "{error}");
            assert!(error.to_string().contains(&ForcedError::UnexpectedWitness.to_string()));
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
            // A capacity below K cannot publish a partial interval.
            assert!(
                builder(fixture.clone(), limits(3))
                    .prepare(snapshot.clone())
                    .await
                    .unwrap()
                    .is_none()
            );
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

        /// Review Focus 1: a forced inclusion block at the switch height `H(1) - 2` carries the
        /// committee and the forced witness, and both must verify.
        #[tokio::test]
        async fn switch_height_forced_block_lands() {
            // Entry 0 first appears in L1 12, the anchor the switch-height block 23 moves to.
            let plan =
                ForcedPlan { entries: vec![(12, 3)], consume_at: vec![23], ..Default::default() };
            let forced = || Fixture::with_forced(18, 30, plan.clone());
            let fixture = Arc::new(forced());
            let request = prepare(&fixture, 6).await;
            let switch = envelope(&request, 4);
            assert_eq!(switch.block.header.number, 23);
            assert!(switch.anchor.is_some() && switch.committee.is_some());
            let witness = switch.forced.unwrap();
            assert_eq!((witness.index, witness.tx.is_empty()), (0, false));
            assert_eq!(envelope(&request, 0).forced, None);
            assert_eq!(heads(&request), (0, 1));
            assert_eq!(
                request.batch.committees.iter().map(|c| c.record.target_epoch).collect::<Vec<_>>(),
                vec![0, 1]
            );

            let mut fixture = forced();
            alter_envelope(&mut fixture, 23, |envelope| envelope.committee = None);
            assert_safety(fixture, "required committee witness").await;
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
            for mode in 0..7 {
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
                    result: if mode == 3 {
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
            let error = builder(absent.clone(), limits(6))
                .prepare(absent.snapshot.clone())
                .await
                .unwrap_err();
            assert!(
                matches!(error, LanderError::Temporary(_)),
                "missing execution state must fail closed: {error}"
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
            &fixture.committees[&0],
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
