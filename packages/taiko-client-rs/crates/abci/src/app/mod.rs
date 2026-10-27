//! The ABCI++ application.
//!
//! [`App`] owns the node's own L1 view and execution engine,
//! the chain parameters and the persisted [`AppState`], and answers CometBFT's requests through
//! [`App::handle`]. `InitChain` lives in [`init`]; `Info`, `Query` and `CheckTx` in [`info`];
//! `PrepareProposal` in [`prepare`] and `ProcessProposal` in [`process`], both on top of the
//! deterministic checks of [`validate`]; `FinalizeBlock` and `Commit` in [`finalize`].
//!
//! Errors returned by [`App::handle`] are fatal to the connection; [`AbciError::SafetyHalt`]
//! marks the ones where the node must stop signing and an operator must investigate.
//! Invalid proposals are rejected; own-node integrity failures require explicit repair.

use crate::wire::{Request, Response, response};
use std::{
    collections::VecDeque,
    future::Future,
    sync::{Arc, Mutex, MutexGuard, PoisonError},
    time::Duration,
};

use alloy_primitives::B256;
use rpc::client::http_timeout_for;
use serde::{Deserialize, Serialize};
use tendermint::{AppHash, Hash, Time, block::Height};

use crate::{
    config::{ChainParams, ConfigError},
    elsync::{ElSyncError, ensure_block},
    engine::{Engine, EngineError},
    genesis::GenesisError,
    l1::{DiscoveryProgress, L1Error, L1Source},
    metrics::{AbciMetrics, set_u64},
    rules::{RuleViolation, check_chain_id},
    schedule::ScheduleError,
    store::{AppState, Store, StoreError},
};

/// Durable independently verified switch witness retention.
mod committee_cache;
/// The `FinalizeBlock` and `Commit` handlers.
mod finalize;
/// `Info`, `Query` and `CheckTx` handlers.
mod info;
/// The `InitChain` handler.
mod init;
/// Completed proposal reads retained across timed-out rounds at the same height.
mod preparation_cache;
/// The `PrepareProposal` handler.
mod prepare;
/// The `ProcessProposal` handler.
mod process;
/// Node-local startup checkpoint authentication and signing readiness.
pub mod trust;
/// Deterministic block validation shared by `ProcessProposal` and `FinalizeBlock`.
mod validate;

#[cfg(test)]
mod tests;

use committee_cache::{CachedCommittee, CommitteePrefetch, load_cached_committee};

pub use info::{CHECK_TX_LOG, CODE_REJECTED};
pub use validate::{Rejection, Validated, WitnessKind};

/// The application name reported in `Info.data`.
pub const APP_NAME: &str = "taiko-abci";

/// The ABCI application version reported in `Info.app_version`; the genesis
/// `consensus_params.version.app` carries the same value.
pub const APP_VERSION: u64 = 1;

/// Interval between EL polls while waiting for an EL sync to a trusted head.
pub const ELSYNC_POLL: Duration = Duration::from_secs(1);

/// First pause before `FinalizeBlock` retries an EL call for a decided block that answered
/// `SYNCING`/`ACCEPTED`, exceeded the engine deadline or failed with a retryable error
/// ([`EngineError::is_retryable`]: a transport failure, or a JSON-RPC error code a retry may
/// cure); the pause doubles per retry of the block up to [`FINALIZE_RETRY_MAX`]. Every other
/// engine error (an Engine API or malformed-call error code, a reply of the wrong shape) is the
/// EL's deterministic answer and never retried: a safety halt.
pub const FINALIZE_RETRY_INITIAL: Duration = Duration::from_millis(100);

/// Cap of the doubling pause between `FinalizeBlock`'s EL retries.
pub const FINALIZE_RETRY_MAX: Duration = Duration::from_secs(5);

/// How long `FinalizeBlock` retries the EL for one decided block before it logs every further
/// retry at ERROR instead of WARN (it keeps retrying), so operators notice a stuck EL.
pub const FINALIZE_RETRY_ESCALATE: Duration = Duration::from_secs(60);

/// How many `ProcessProposal` ACCEPT verdicts the app keeps for `FinalizeBlock` at one height.
///
/// A height that takes many rounds (e.g. while more than a third of the voting power cannot see
/// the proposals' anchors as final) yields a new accepted proposal per round, each up to the
/// block size limit, so the cache is bounded. The decided block is a recent round's proposal, or
/// a locked block that its re-proposal processes again, and `FinalizeBlock` re-validates and
/// executes a block whose verdict was evicted.
pub const MAX_VERDICTS: usize = 4;

/// Deadlines of the app's external calls.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AppOptions {
    /// Deadline of one L1 operation (a finality check, a header or proof read).
    pub l1_timeout: Duration,
    /// Deadline of one Engine API or EL RPC call.
    pub engine_timeout: Duration,
    /// Deadline of an EL sync to a trusted head (devp2p download included).
    pub elsync_timeout: Duration,
    /// Overall deadline of one `PrepareProposal` (every L1 read and the EL build together, on
    /// top of their own deadlines); past it the node proposes nothing. Must stay below
    /// CometBFT's `timeout_propose`, or the round times out before the proposal is ready.
    pub prepare_timeout: Duration,
}

impl Default for AppOptions {
    /// `l1_timeout` 3 s, `engine_timeout` 5 s, `elsync_timeout` 600 s,
    /// `prepare_timeout` 2 s (below CometBFT's default `timeout_propose` of 3 s).
    fn default() -> Self {
        Self {
            l1_timeout: Duration::from_secs(3),
            engine_timeout: Duration::from_secs(5),
            elsync_timeout: Duration::from_secs(600),
            prepare_timeout: Duration::from_secs(2),
        }
    }
}

/// The app's status as served by the `/status` query.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Status {
    /// Last committed height (== L2 block number); `B*` right after `InitChain`.
    pub head: u64,
    /// Epoch of the head (`e_0` while the head is still the genesis anchor `B*`).
    pub epoch: u64,
    /// Recovery generation of the running chain.
    pub generation: u64,
    /// `lastCheckpoint.height` proven by the head's anchor.
    pub last_checkpoint_height: u64,
    /// L1 block number of the head's anchor.
    pub anchor: u64,
    /// Why the app currently refuses to make progress (liveness halt), if it does.
    pub halt_reason: Option<String>,
    /// Whether L1 records a larger recovery generation than the running chain's.
    pub superseded: bool,
    /// True only after checkpoint trust has been established for this session.
    pub trust_ready: bool,
    /// Whether the node is withholding signing pending checkpoint authentication.
    pub syncing: bool,
    /// Node-local checkpoint phase, separate from the proposal liveness halt.
    pub trust_phase: trust::TrustPhase,
    /// Own-finalized checkpoint pinned for this startup attempt.
    pub trust_target: Option<trust::CheckpointTarget>,
    /// Durable trusted head; absent while closed.
    pub trusted_consensus_head: Option<trust::BlockRef>,
    /// Local checkpoint acquisition or ancestry retry reason.
    pub trust_reason: Option<String>,
}

/// Why an ABCI request failed. Every variant is fatal to the request; see the module docs.
#[derive(Debug, thiserror::Error)]
pub enum AbciError {
    /// Local checkpoint control or acquisition failed without authenticating a contradiction.
    #[error("checkpoint trust: {0}")]
    TrustControl(String),
    /// A committed block or the EL contradicts the app's verified state: the process must exit
    /// and an operator must investigate.
    #[error("safety halt: {0}")]
    SafetyHalt(String),
    /// `Commit` arrived without a `FinalizeBlock` result to persist; CometBFT never sends one,
    /// so the connection is broken.
    #[error("Commit without a finalized block")]
    NothingToCommit,
    /// A block-level method (named by the value) arrived before `InitChain`; CometBFT never
    /// sends one, so the connection is broken.
    #[error("{0} before InitChain")]
    Uninitialized(&'static str),
    /// `InitChain` arrived although the app already holds (or persisted) a state.
    #[error("InitChain on an already initialized app")]
    AlreadyInitialized,
    /// The genesis `app_state` does not decode or its authenticated facts do not verify.
    #[error(transparent)]
    Genesis(#[from] GenesisError),
    /// The genesis L1 header is not final and canonical in the node's own L1 view.
    #[error("genesis L1 block {number} ({hash}) is not final and canonical in the own L1 view")]
    GenesisNotFinal {
        /// The genesis header's L1 block number.
        number: u64,
        /// The genesis header's hash.
        hash: B256,
    },
    /// The genesis record's schedule violates the epoch-length bounds
    /// ([`Schedule::validate`](crate::schedule::Schedule::validate)).
    #[error(transparent)]
    Schedule(#[from] ScheduleError),
    /// A CometBFT `chain_id` is not `taiko-etna-<l2ChainId>-g<generation>` for this chain.
    #[error(transparent)]
    ChainId(#[from] RuleViolation),
    /// The `chain_id` generation differs from the Inbox's `recoveryGeneration`.
    #[error("chain_id generation {chain_id} differs from the inbox recoveryGeneration {inbox}")]
    GenerationMismatch {
        /// The generation in the `chain_id` suffix.
        chain_id: u64,
        /// The Inbox's `recoveryGeneration` at `L1_0`.
        inbox: u64,
    },
    /// The requested first consensus height is not 1 for this genesis-only chain.
    #[error("initial_height {got} must be {expected} for a genesis-only chain")]
    InitialHeight {
        /// The requested initial height.
        got: u64,
        /// The first consensus height, always 1.
        expected: u64,
    },
    /// The request time differs from the authenticated L1 initialization timestamp.
    #[error("genesis time {got} differs from the authenticated initialization time {expected}")]
    GenesisTimeMismatch {
        /// Genesis time supplied by CometBFT.
        got: Time,
        /// Whole-second timestamp of the authenticated initialization header.
        expected: Time,
    },
    /// The request's representable consensus parameters differ from the canonical Etna values.
    #[error("genesis consensus parameters differ from the canonical Etna parameters")]
    GenesisConsensusParamsMismatch,
    /// The genesis validators are not exactly the derived `e_0` committee; the value says how.
    #[error("genesis validators differ from the derived committee: {0}")]
    GenesisValidatorsMismatch(String),
    /// The EL has no canonical block at a height it must serve.
    #[error("execution engine has no canonical block at height {0}")]
    ElBlockMissing(u64),
    /// An external call exceeded its deadline.
    #[error("{what} timed out after {after:?}")]
    Timeout {
        /// The operation that timed out.
        what: &'static str,
        /// The deadline that elapsed.
        after: Duration,
    },
    /// An L1 read failed.
    #[error(transparent)]
    L1(#[from] L1Error),
    /// An Engine API or EL RPC call failed.
    #[error(transparent)]
    Engine(#[from] EngineError),
    /// An EL sync to a trusted head failed without contradicting it (call error or timeout);
    /// contradictions convert to [`AbciError::SafetyHalt`].
    #[error(transparent)]
    ElSync(ElSyncError),
    /// The state could not be loaded or persisted.
    #[error(transparent)]
    Store(#[from] StoreError),
    /// The chain parameters are invalid.
    #[error(transparent)]
    Config(#[from] ConfigError),
    /// The persisted state is internally inconsistent; the value says how.
    #[error("persisted app state is inconsistent: {0}")]
    StoredState(String),
}

impl From<ElSyncError> for AbciError {
    /// An EL that rejects a trusted head or serves another block after accepting it contradicts
    /// the app's verified chain: a safety halt. Call errors and timeouts stay
    /// [`AbciError::ElSync`].
    fn from(e: ElSyncError) -> Self {
        match e {
            ElSyncError::Rejected { .. } | ElSyncError::Conflict { .. } => {
                Self::SafetyHalt(e.to_string())
            }
            other => Self::ElSync(other),
        }
    }
}

/// The ABCI++ application over an L1 source `L` and an execution engine `E`.
#[derive(Debug)]
pub struct App<L: L1Source, E: Engine> {
    /// The node's own L1 view. `FinalizeBlock` and replay read no L1 state through it (blocks
    /// carry their L1 facts); they only confirm a block's anchor header when the block was never
    /// judged here ([`App::confirm_anchor`]).
    l1: Arc<L>,
    /// The execution engine.
    engine: E,
    /// The chain parameters (validated).
    params: ChainParams,
    /// Where [`App::state`] is persisted.
    store: Store,
    /// Deadlines of external calls.
    opts: AppOptions,
    /// The committed state; `None` before `InitChain`.
    state: Option<AppState>,
    /// The state `FinalizeBlock` derived for the decided block; persisted and made the
    /// committed state by `Commit`.
    pending: Option<AppState>,
    /// The latest `ProcessProposal` ACCEPT verdicts (at most [`MAX_VERDICTS`]), for
    /// `FinalizeBlock`; cleared at `Commit`.
    verdicts: Verdicts,
    /// The last committee witness verified for switch height `H(t)-2`, by `PrepareProposal` (its
    /// own), `ProcessProposal` (another proposer's) or the background discovery under the
    /// committed anchor ([`App::prefetch_committee_witness`]), kept so that this node's proposals
    /// at that height reuse it instead of reading the registry again. Its durable sidecar is
    /// reverified after restart against the full committed context. It is dropped once the
    /// committed state leaves that context (another anchor or switch); the one bounded sidecar
    /// then becomes stale and is ignored. Behind a mutex as the handlers run on `&self`.
    committee_cache: Mutex<Option<CachedCommittee>>,
    /// The registry reads of a committee discovery `PrepareProposal`'s deadline or a failed L1
    /// read cut short, from which the next attempt resumes; cleared at `Commit`.
    discovery: DiscoveryProgress,
    /// The background discovery of the upcoming switch height's committee witness under the
    /// committed anchor ([`App::prefetch_committee_witness`]).
    committee_prefetch: Mutex<Option<CommitteePrefetch>>,
    /// Bounded completed anchor, forced proof and authenticated transaction reads. Each successful
    /// stage survives an overall proposal timeout; root/hash keys prevent reuse for different
    /// facts. These reads are proposer-independent; expected headers, builds and singleton
    /// verdicts are derived anew for every request's certified proposer.
    preparation_cache: Arc<Mutex<preparation_cache::PreparationCache>>,
    /// Whether the block `FinalizeBlock` last decided was judged here (its `ProcessProposal`
    /// verdict was cached), rather than replayed or block-synced; gates `Commit`'s prefetches.
    decided_live: bool,
    /// The label of the last proposal rejection or failed build (a liveness halt), reported by
    /// `/status`; an empty proposal does not replace a recorded label. Cleared by the next
    /// accepted or built proposal and by `Commit`.
    halt: Option<String>,
    /// Whether L1 records a larger recovery generation than the running chain's.
    superseded: bool,
    /// Whether this process already made sure the EL serves the committed head: set by the
    /// first successful `Info` reconcile or successful `InitChain`. Later ordinary Info calls
    /// answer without EL I/O. Independent signer sessions separately recheck the durable head
    /// and ancestry through the checkpoint trust worker.
    el_reconciled: bool,
    /// Process-local trust and session state, never serialized into AppState.
    trust: trust::TrustHandle,
    /// Revokes shared authorization on worker destruction, including panic/cancellation.
    _trust_lifetime: trust::TrustLifetime,
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// Creates the app, validating `params` and loading any persisted state from `store`.
    ///
    /// A loaded state must be consistent with `params` and with itself: its schedule must pass
    /// [`Schedule::validate`](crate::schedule::Schedule::validate) independently of the unsettled
    /// cap and equal the one derived from its genesis record, its Inbox must match the account
    /// authenticated at genesis, its `chain_id` must name `params.l2_chain_id` and its
    /// generation, and its last height must equal its parent's number and fit a CometBFT
    /// height. Every saved committee must retain canonical stake-derived powers, checked totals
    /// and its set root. These local consistency checks do not authenticate a coherently
    /// rewritten state file.
    ///
    /// Forced inclusion uses authenticated calldata and requires no KZG initialization.
    pub fn new(
        l1: L,
        engine: E,
        params: ChainParams,
        store: Store,
        opts: AppOptions,
    ) -> Result<Self, AbciError> {
        params.validate()?;
        if let Some(reason) = store.fatal_evidence()? {
            return Err(AbciError::SafetyHalt(format!(
                "persisted fatal evidence requires operator repair: {reason}"
            )));
        }
        let state = store.load()?;
        if let Some(state) = &state {
            check_stored_state(state, &params)?;
        }
        let committee_cache = load_cached_committee(&store, state.as_ref(), &params);
        let trust = trust::TrustHandle::new(state.as_ref())?;
        let app = Self {
            l1: Arc::new(l1),
            engine,
            params,
            store,
            opts,
            state,
            pending: None,
            verdicts: Verdicts::default(),
            committee_cache: Mutex::new(committee_cache),
            discovery: DiscoveryProgress::default(),
            committee_prefetch: Mutex::default(),
            preparation_cache: Arc::default(),
            decided_live: false,
            halt: None,
            superseded: false,
            el_reconciled: false,
            _trust_lifetime: trust::TrustLifetime(trust.clone()),
            trust,
        };
        app.publish_state_metrics();
        Ok(app)
    }

    /// The committed state; `None` before `InitChain`.
    pub fn state(&self) -> Option<&AppState> {
        self.state.as_ref()
    }

    /// The node's own L1 source.
    pub fn l1(&self) -> &L {
        &self.l1
    }

    /// The execution engine.
    pub fn engine(&self) -> &E {
        &self.engine
    }

    /// The chain parameters.
    pub fn params(&self) -> &ChainParams {
        &self.params
    }

    /// The `/status` view of the app; `None` before `InitChain`.
    pub fn status(&self) -> Option<Status> {
        let state = self.state.as_ref()?;
        let schedule = &state.schedule();
        let trust = self.trust.snapshot();
        Some(Status {
            head: state.last_height,
            epoch: schedule.epoch_of(state.last_height.max(schedule.h0())),
            generation: state.generation,
            last_checkpoint_height: state.anchor.inbox.last_checkpoint_height,
            anchor: state.anchor.number,
            halt_reason: self.halt.clone(),
            superseded: self.superseded,
            trust_ready: trust.trust_ready,
            syncing: trust.syncing,
            trust_phase: trust.phase,
            trust_target: trust.target,
            trusted_consensus_head: trust.trusted_consensus_head,
            trust_reason: trust.reason,
        })
    }

    /// Answers one ABCI request.
    ///
    /// Methods without app logic answer at once: `Echo` echoes, `Flush` flushes, vote
    /// extensions are empty and accepted (disabled), and the snapshot methods answer empty
    /// defaults (state sync is disabled).
    pub async fn handle(&mut self, req: Request) -> Result<Response, AbciError> {
        let result = self.dispatch(req).await;
        if let Err(error) = &result {
            if matches!(error, AbciError::SafetyHalt(_) | AbciError::Store(_)) {
                self.trust.revoke(error.to_string());
                self.store.record_fatal(&error.to_string())?;
            } else {
                // Network/initialization failures close authorization but must allow a later
                // successful handshake to recover without requiring a signed block.
                self.trust.begin_session();
            }
        }
        result
    }

    /// Dispatches sequential consensus requests; the outer handler revokes trust on failure.
    async fn dispatch(&mut self, req: Request) -> Result<Response, AbciError> {
        Ok(match req {
            Request::Echo(r) => Response::Echo(response::Echo { message: r.message }),
            Request::Flush => Response::Flush,
            Request::Info(r) => Response::Info(self.info(r).await?),
            Request::Query(r) => Response::Query(self.query(r)),
            Request::CheckTx(r) => Response::CheckTx(self.check_tx(r)),
            Request::InitChain(r) => Response::InitChain(self.init_chain(r).await?),
            Request::Commit => Response::Commit(self.commit()?),
            Request::ListSnapshots => Response::ListSnapshots(Default::default()),
            Request::OfferSnapshot(_) => Response::OfferSnapshot(Default::default()),
            Request::LoadSnapshotChunk(_) => Response::LoadSnapshotChunk(Default::default()),
            Request::ApplySnapshotChunk(_) => Response::ApplySnapshotChunk(Default::default()),
            Request::ExtendVote(_) => {
                Response::ExtendVote(response::ExtendVote { vote_extension: Default::default() })
            }
            Request::VerifyVoteExtension(_) => {
                Response::VerifyVoteExtension(response::VerifyVoteExtension::Accept)
            }
            Request::PrepareProposal(r) => {
                Response::PrepareProposal(self.prepare_proposal(r).await?)
            }
            Request::ProcessProposal(r) => {
                Response::ProcessProposal(self.process_proposal(r).await?)
            }
            Request::FinalizeBlock(r) => Response::FinalizeBlock(self.finalize_block(r).await?),
        })
    }

    /// Records a refused proposal: logs it (ERROR for a local build fault or a record conflict,
    /// see [`Rejection::logs_at_error`], WARN otherwise), keeps its label as the halt reason for
    /// `/status`, and sets the `superseded` status when the Inbox proved a later generation.
    ///
    /// An [`Rejection::EmptyProposal`] never replaces a reason already recorded: it is how a
    /// halted proposer (this node included) proposes nothing, so the reason recorded earlier at
    /// the height (e.g. this node's own failed build) is the one that explains the halt.
    fn note_rejection(&mut self, method: &'static str, height: u64, rejection: &Rejection) {
        let reason = rejection.label();
        if rejection.logs_at_error() {
            tracing::error!(method, height, reason, error = %rejection, "proposal refused");
        } else {
            tracing::warn!(method, height, reason, error = %rejection, "proposal refused");
        }
        if matches!(rejection, Rejection::Superseded { .. }) {
            self.superseded = true;
            self.trust.revoke("authenticated higher recovery generation");
        }
        if matches!(rejection, Rejection::EmptyProposal) && self.halt.is_some() {
            return;
        }
        self.halt = Some(reason.to_string());
        AbciMetrics::halted().set(1);
    }

    /// The committee-witness cache, which holds no invariant a panicking holder could break.
    fn committee_cache(&self) -> MutexGuard<'_, Option<CachedCommittee>> {
        self.committee_cache.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// The switch-witness prefetch slot, which holds no invariant a panicking holder could break.
    fn committee_prefetch(&self) -> MutexGuard<'_, Option<CommitteePrefetch>> {
        self.committee_prefetch.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Makes the EL serve block `hash` at `number` ([`ensure_block`] within
    /// [`AppOptions::elsync_timeout`]).
    ///
    /// The outer deadline (an [`AbciError::Timeout`] naming `what`) adds one EL request's HTTP
    /// timeout to the sync's own, so a poll in flight at the sync deadline ends with the sync's
    /// own timeout error rather than being cut short by the outer one.
    async fn sync_el_to(
        &self,
        what: &'static str,
        number: u64,
        hash: B256,
    ) -> Result<(), AbciError> {
        let opts = self.opts;
        within(
            what,
            opts.elsync_timeout.saturating_add(http_timeout_for(opts.engine_timeout)),
            ensure_block(&self.engine, number, hash, opts.elsync_timeout, ELSYNC_POLL),
        )
        .await
    }

    /// Clears the liveness-halt reason after an accepted or built proposal or a commit.
    fn clear_halt(&mut self) {
        self.halt = None;
        AbciMetrics::halted().set(0);
    }

    /// Publishes the committed state's head, epoch, generation and unsettled depth gauges
    /// (no-op before `InitChain`).
    fn publish_state_metrics(&self) {
        let Some(status) = self.status() else { return };
        set_u64(AbciMetrics::head(), status.head);
        set_u64(AbciMetrics::epoch(), status.epoch);
        set_u64(AbciMetrics::generation(), status.generation);
        set_u64(
            AbciMetrics::unsettled_depth(),
            status.head.saturating_sub(status.last_checkpoint_height),
        );
    }
}

/// The latest `ProcessProposal` ACCEPT verdicts by CometBFT block hash, oldest first, at most
/// [`MAX_VERDICTS`].
#[derive(Debug, Default)]
struct Verdicts(VecDeque<(Hash, Validated)>);

impl Verdicts {
    /// Records `validated` as the newest verdict for `hash`, replacing an older one for the same
    /// hash and evicting the oldest beyond [`MAX_VERDICTS`].
    fn insert(&mut self, hash: Hash, validated: Validated) {
        self.0.retain(|(kept, _)| *kept != hash);
        if self.0.len() >= MAX_VERDICTS {
            self.0.pop_front();
        }
        self.0.push_back((hash, validated));
    }

    /// Takes the verdict for `hash`, if kept.
    fn remove(&mut self, hash: &Hash) -> Option<Validated> {
        let index = self.0.iter().position(|(kept, _)| kept == hash)?;
        self.0.remove(index).map(|(_, validated)| validated)
    }

    /// The verdict for `hash`, if kept.
    #[cfg(test)]
    fn get(&self, hash: &Hash) -> Option<&Validated> {
        self.0.iter().find(|(kept, _)| kept == hash).map(|(_, validated)| validated)
    }

    /// How many verdicts are kept.
    #[cfg(test)]
    fn len(&self) -> usize {
        self.0.len()
    }

    /// Whether no verdict is kept.
    #[cfg(test)]
    fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    /// Forgets every verdict.
    fn clear(&mut self) {
        self.0.clear();
    }
}

/// Whether `state` is still at genesis block 0: no PoS block has been committed yet.
///
/// CometBFT re-sends `InitChain` whenever the app reports height 0, so `Info` reports 0 and
/// `InitChain` is idempotent in this state.
fn at_genesis(state: &AppState) -> bool {
    state.last_height == 0
}

/// Rejects a persisted state that `params` or the state itself contradicts (see [`App::new`]).
fn check_stored_state(state: &AppState, params: &ChainParams) -> Result<(), AbciError> {
    if state.schema_version != 13 {
        return Err(AbciError::StoredState(format!(
            "unsupported journal schema {} (expected 13)",
            state.schema_version
        )));
    }
    if state.app_version != APP_VERSION {
        return Err(AbciError::StoredState(format!(
            "unsupported app version {} (expected {APP_VERSION})",
            state.app_version
        )));
    }
    if state.inbox != params.inbox {
        return Err(AbciError::StoredState(format!(
            "Inbox {} differs from the authenticated genesis account {}",
            params.inbox, state.inbox
        )));
    }
    state.schedule().validate(params.unsettled_cap())?;
    if state.genesis.genesis_height != 0 {
        return Err(AbciError::StoredState("genesis height must be zero".into()));
    }
    if state.generation != 0 {
        return Err(AbciError::StoredState(
            "unsupported recovery generation: fresh generation 0 only".into(),
        ));
    }
    check_chain_id(&state.chain_id, params, state.generation)?;
    if state.genesis.committee_config_hash != crate::committee::committee_config_hash(params) {
        return Err(AbciError::StoredState(
            "committee configuration opening differs from genesis".into(),
        ));
    }
    for (epoch, committee) in &state.committees {
        let members = &committee.members;
        if committee.record.target_epoch != *epoch ||
            members.is_empty() ||
            members.len() > params.n_max ||
            members.windows(2).any(|pair| {
                crate::committee::set_key(params.l2_chain_id, pair[0].pubkey) >=
                    crate::committee::set_key(params.l2_chain_id, pair[1].pubkey)
            })
        {
            return Err(AbciError::StoredState(format!(
                "invalid committee metadata for epoch {epoch}"
            )));
        }
        // These are local consistency checks, not authentication of a coherently rewritten
        // state file. Every retained/current/scheduled committee must obey the same math.
        let invalid = |reason: String| {
            AbciError::StoredState(format!("invalid committee for epoch {epoch}: {reason}"))
        };
        for member in members {
            let power = crate::committee::member_power(member.pubkey, member.eff_stake, params)
                .map_err(|err| invalid(err.to_string()))?;
            if member.power != power {
                return Err(invalid(format!("noncanonical power for {}", member.pubkey)));
            }
        }
        let (total_power, _) =
            crate::committee::member_totals(members).map_err(|err| invalid(err.to_string()))?;
        if total_power != committee.record.total_power {
            return Err(invalid("record totals differ from members".into()));
        }
        let k = epoch
            .checked_add(1)
            .ok_or_else(|| AbciError::StoredState("committee epoch overflows".into()))?;
        if crate::committee::set_root(params.l2_chain_id, k, members) != committee.record.set_root {
            return Err(AbciError::StoredState(format!(
                "committee members differ from the set commitment for epoch {epoch}"
            )));
        }
    }
    if state.parent.number != state.last_height {
        return Err(AbciError::StoredState(format!(
            "last height {} differs from the parent block number {}",
            state.last_height, state.parent.number
        )));
    }
    if Height::try_from(state.last_height).is_err() {
        return Err(AbciError::StoredState(format!(
            "last height {} exceeds the CometBFT height range",
            state.last_height
        )));
    }
    Ok(())
}

/// Runs `fut` with a deadline of `limit`; an elapsed deadline is [`AbciError::Timeout`] naming
/// `what`, and `fut`'s own error converts into [`AbciError`].
async fn within<T, Err>(
    what: &'static str,
    limit: Duration,
    fut: impl Future<Output = Result<T, Err>>,
) -> Result<T, AbciError>
where
    AbciError: From<Err>,
{
    match tokio::time::timeout(limit, fut).await {
        Ok(result) => result.map_err(AbciError::from),
        Err(_) => Err(AbciError::Timeout { what, after: limit }),
    }
}

/// Runs `fut` with a deadline of `limit` for a proposal handler: an elapsed deadline is
/// [`Rejection::Timeout`] naming `what`, and `fut`'s own error converts into [`Rejection`].
async fn deadline<T, Err>(
    what: &'static str,
    limit: Duration,
    fut: impl Future<Output = Result<T, Err>>,
) -> Result<T, Rejection>
where
    Rejection: From<Err>,
{
    match tokio::time::timeout(limit, fut).await {
        Ok(result) => result.map_err(Rejection::from),
        Err(_) => Err(Rejection::Timeout(what)),
    }
}

/// `time` in whole seconds since the Unix epoch (`floor(time_H)`); earlier times map to 0.
fn unix_secs(time: Time) -> u64 {
    u64::try_from(time.unix_timestamp()).unwrap_or(0)
}

/// `h` as a CometBFT height.
///
/// Every height the app stores fits: `InitChain` takes `B*` from CometBFT's `initial_height - 1`,
/// later heights are CometBFT heights, and [`App::new`] rejects a loaded state that does not fit.
fn cometbft_height(h: u64) -> Height {
    Height::try_from(h).expect("stored heights fit a CometBFT height (checked at InitChain/load)")
}

/// The 32 bytes of `hash` as a CometBFT app hash.
fn app_hash(hash: B256) -> AppHash {
    AppHash::try_from(hash.to_vec()).expect("any byte string is a valid AppHash")
}
