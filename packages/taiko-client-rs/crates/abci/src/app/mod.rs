//! The ABCI++ application.
//!
//! [`App`] owns the node's own L1 view, the execution engine, the chain parameters and the
//! persisted [`AppState`], and answers CometBFT's requests through [`App::handle`]. `InitChain`
//! lives in [`init`]; `Info`, `Query` and `CheckTx` in [`info`]; `PrepareProposal` in
//! [`prepare`] and `ProcessProposal` in [`process`], both on top of the deterministic checks of
//! [`validate`]; `FinalizeBlock` and `Commit` in [`finalize`].
//!
//! Errors returned by [`App::handle`] are fatal to the connection; [`AbciError::SafetyHalt`]
//! marks the ones where the node must stop signing and an operator must investigate.
//! A bad or unbuildable proposal is never an error: it is a [`Rejection`] (liveness only).

use std::{
    collections::HashMap,
    future::Future,
    sync::{Mutex, MutexGuard, PoisonError},
    time::Duration,
};

use alloy_primitives::B256;
use serde::{Deserialize, Serialize};
use tendermint::{
    AppHash, Hash, Time,
    block::Height,
    v0_38::abci::{Request, Response, response},
};

use crate::{
    committee::CommitteeError,
    config::{ChainParams, ConfigError},
    elsync::ElSyncError,
    engine::{Engine, EngineError},
    envelope::CommitteeWitness,
    genesis::GenesisError,
    l1::{DiscoveryProgress, L1Error, L1Source, WitnessError},
    metrics::{AbciMetrics, set_u64},
    rules::{RuleViolation, generation_from_chain_id},
    schedule::{Schedule, ScheduleError},
    store::{AppState, Store, StoreError},
};

/// The `FinalizeBlock` and `Commit` handlers.
mod finalize;
/// `Info`, `Query` and `CheckTx` handlers.
mod info;
/// The `InitChain` handler.
mod init;
/// The `PrepareProposal` handler.
mod prepare;
/// The `ProcessProposal` handler.
mod process;
/// Deterministic block validation shared by `ProcessProposal` and `FinalizeBlock`.
mod validate;

#[cfg(test)]
mod tests;

pub use info::{CHECK_TX_LOG, CODE_REJECTED};
pub use validate::{Rejection, Validated, WitnessKind};

/// The application name reported in `Info.data`.
pub const APP_NAME: &str = "taiko-abci";

/// The ABCI application version reported in `Info.app_version`; the genesis
/// `consensus_params.version.app` carries the same value.
pub const APP_VERSION: u64 = 0;

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
    /// `l1_timeout` 3 s, `engine_timeout` 5 s, `elsync_timeout` 600 s, `prepare_timeout` 2 s
    /// (below CometBFT's default `timeout_propose` of 3 s).
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
}

/// Why an ABCI request failed. Every variant is fatal to the request; see the module docs.
#[derive(Debug, thiserror::Error)]
pub enum AbciError {
    /// A committed block or the EL contradicts the app's verified state: the
    /// process must exit and an operator must investigate.
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
    /// The genesis `app_state` does not decode.
    #[error(transparent)]
    AppState(#[from] GenesisError),
    /// The genesis L1 header is not final and canonical in the node's own L1 view.
    #[error("genesis L1 block {number} ({hash}) is not final and canonical in the own L1 view")]
    GenesisNotFinal {
        /// The genesis header's L1 block number.
        number: u64,
        /// The genesis header's hash.
        hash: B256,
    },
    /// The genesis Inbox witness does not verify or is not an activated Inbox.
    #[error("genesis inbox witness rejected: {0}")]
    Witness(#[from] WitnessError),
    /// The genesis L1 header is not the activation record's `L1_0` block.
    #[error("genesis L1 header is block {header}, but the activation record's L1_0 is {l1_0}")]
    GenesisL1Mismatch {
        /// The genesis header's L1 block number.
        header: u64,
        /// `L1_0` from the activation record.
        l1_0: u64,
    },
    /// The activation record's schedule violates the epoch-length bounds
    /// ([`Schedule::validate`]).
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
    /// The genesis `initial_height` is not `B* + 1` (so that every CometBFT height equals its
    /// EL block number).
    #[error("initial_height {got} must be B* + 1 = {expected}")]
    InitialHeight {
        /// The requested initial height.
        got: u64,
        /// `B* + 1`.
        expected: u64,
    },
    /// The genesis committee witness does not verify.
    #[error("genesis committee witness rejected: {0}")]
    Committee(#[from] CommitteeError),
    /// The committee derived from the genesis witness is not the one recorded at
    /// `committee[e_0]`.
    #[error("derived committee record hash {derived} differs from committee[e0] = {recorded}")]
    CommitteeRecordMismatch {
        /// `record_hash` of the derived committee record.
        derived: B256,
        /// The record hash proven at `committee[e_0]`.
        recorded: B256,
    },
    /// The genesis validators are not exactly the derived `e_0` committee; the value says how.
    #[error("genesis validators differ from the derived committee: {0}")]
    GenesisValidatorsMismatch(String),
    /// An EL block the app needs carries no base fee.
    #[error("execution block {0} has no base fee")]
    MissingBaseFee(u64),
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
    /// The node's own L1 view (never used by `FinalizeBlock` or replay: blocks carry their L1
    /// facts).
    l1: L,
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
    /// `ProcessProposal` ACCEPT verdicts by CometBFT block hash, for `FinalizeBlock`; cleared
    /// at `Commit`.
    verdicts: HashMap<Hash, Validated>,
    /// The last committee witness verified at `h_first(e)`, by `PrepareProposal` (discovered) or
    /// `ProcessProposal` (another proposer's), kept so that this node's proposals in later rounds
    /// at the same height reuse it instead of reading the registry again. Replaced when the key
    /// differs; cleared at `Commit`. Behind a mutex as the handlers run on `&self`.
    committee_cache: Mutex<Option<CachedCommittee>>,
    /// The registry reads of a committee discovery `PrepareProposal`'s deadline cut short, from
    /// which the next attempt resumes; cleared at `Commit`.
    discovery: DiscoveryProgress,
    /// The label of the last proposal rejection or failed build (a liveness halt), reported by
    /// `/status`; an empty proposal does not replace a recorded label. Cleared by the next
    /// accepted or built proposal and by `Commit`.
    halt: Option<String>,
    /// Whether L1 records a larger recovery generation than the running chain's.
    superseded: bool,
    /// Whether this process already made sure the EL serves the committed head: set by the
    /// first successful `Info` reconcile (CometBFT's handshake) or a successful `InitChain`,
    /// never cleared, so a CometBFT restart under a running app is not re-checked (see
    /// [`App::info`]). Later `Info` calls (CometBFT also sends one per RPC `/abci_info`) then
    /// answer from the committed state without EL I/O.
    el_reconciled: bool,
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// Creates the app, validating `params` and loading the persisted state from `store` (if
    /// any).
    ///
    /// A loaded state must be consistent with `params` and with itself: its schedule must pass
    /// [`Schedule::validate`] for `params`' unsettled cap and equal the one derived
    /// from its activation record, its `chain_id` must name `params.l2_chain_id` and its
    /// generation, and its last height must equal its parent's number and fit a CometBFT
    /// height.
    pub fn new(
        l1: L,
        engine: E,
        params: ChainParams,
        store: Store,
        opts: AppOptions,
    ) -> Result<Self, AbciError> {
        params.validate()?;
        let state = store.load()?;
        if let Some(state) = &state {
            check_stored_state(state, &params)?;
        }
        let app = Self {
            l1,
            engine,
            params,
            store,
            opts,
            state,
            pending: None,
            verdicts: HashMap::new(),
            committee_cache: Mutex::new(None),
            discovery: DiscoveryProgress::default(),
            halt: None,
            superseded: false,
            el_reconciled: false,
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
        let schedule = &state.schedule;
        Some(Status {
            head: state.last_height,
            epoch: schedule.epoch_of(state.last_height.max(schedule.h0())),
            generation: state.generation,
            last_checkpoint_height: state.anchor.inbox.last_checkpoint_height,
            anchor: state.anchor.number,
            halt_reason: self.halt.clone(),
            superseded: self.superseded,
        })
    }

    /// Answers one ABCI request.
    ///
    /// Methods without app logic answer at once: `Echo` echoes, `Flush` flushes, vote
    /// extensions are empty and accepted (disabled), and the snapshot methods answer empty
    /// defaults (state sync is disabled).
    pub async fn handle(&mut self, req: Request) -> Result<Response, AbciError> {
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

    /// Caches `witness`, verified as the committee witness of `target_epoch` against the
    /// committed parent's anchor `parent_anchor`, for this node's proposals at the height.
    fn cache_committee_witness(
        &self,
        parent_anchor: u64,
        target_epoch: u64,
        witness: &CommitteeWitness,
    ) {
        *self.committee_cache() =
            Some(CachedCommittee { parent_anchor, target_epoch, witness: witness.clone() });
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

/// A verified committee witness, with the key it was verified for.
#[derive(Clone, Debug)]
struct CachedCommittee {
    /// The parent's anchor L1 block number `n_p` the witness is proven against.
    parent_anchor: u64,
    /// The epoch whose committee the witness proves.
    target_epoch: u64,
    /// The witness.
    witness: CommitteeWitness,
}

/// Whether `state` is still at the genesis anchor `B*`: no PoS block has been committed yet.
///
/// CometBFT re-sends `InitChain` whenever the app reports height 0, so `Info` reports 0 and
/// `InitChain` is idempotent in this state.
fn at_genesis(state: &AppState) -> bool {
    state.last_height == state.activation.genesis_height
}

/// Rejects a persisted state that `params` or the state itself contradicts (see [`App::new`]).
fn check_stored_state(state: &AppState, params: &ChainParams) -> Result<(), AbciError> {
    state.schedule.validate(params.unsettled_cap())?;
    if state.schedule != Schedule::from_activation(&state.activation) {
        return Err(AbciError::StoredState(format!(
            "schedule {:?} differs from the activation record's",
            state.schedule
        )));
    }
    let generation = generation_from_chain_id(&state.chain_id, params.l2_chain_id)?;
    if generation != state.generation {
        return Err(AbciError::StoredState(format!(
            "chain_id {} names generation {generation}, state has {}",
            state.chain_id, state.generation
        )));
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

/// `time` in whole seconds since the Unix epoch (`floor(time_H)`); times before the epoch map to
/// 0.
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
