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
    l1::{L1Error, L1Source},
    metrics::{AbciMetrics, set_u64},
    rules::{RuleViolation, check_chain_id},
    schedule::ScheduleError,
    server::ConnectionEpoch,
    store::{AppState, STATE_SCHEMA_VERSION, Store, StoreError},
};

/// Checkpoint ancestry of anchor witnesses against the local chain.
mod checkpoint;
/// In-memory retention of independently verified switch witnesses.
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
/// Deterministic block validation shared by `ProcessProposal`, `FinalizeBlock` and the lander.
mod validate;

#[cfg(test)]
mod tests;

use committee_cache::{CachedCommittee, CommitteePrefetch};

pub use info::{CHECK_TX_LOG, CODE_REJECTED};
pub use validate::{
    ChainContext, CommitteeLookup, Rejection, Validated, WitnessKind, check_execution_size,
    validate_block,
};

/// The application name reported in `Info.data`.
pub const APP_NAME: &str = "taiko-abci";

/// The ABCI application version reported in `Info.app_version`; the genesis
/// `consensus_params.version.app` carries the same value.
pub const APP_VERSION: u64 = 1;

/// Interval between EL polls while waiting for an EL sync to a trusted head.
pub const ELSYNC_POLL: Duration = Duration::from_secs(1);

/// First pause of every retry schedule on missing data (SYNC-9-7); the pause doubles per retry
/// up to [`FINALIZE_RETRY_MAX`]. It applies to `FinalizeBlock`'s EL calls for a decided block
/// that answered `SYNCING`/`ACCEPTED`, exceeded the engine deadline or failed with a retryable
/// error ([`EngineError::is_retryable`]: a transport failure, or a JSON-RPC error code a retry
/// may cure), and to the authenticated inputs `InitChain` and the startup `Info` wait for. Every
/// other engine error (an Engine API or malformed-call error code, a reply of the wrong shape)
/// is the EL's deterministic answer and never retried: a safety halt. `ProcessProposal` also
/// waits this long before re-judging a proposal whose dependency was unavailable.
pub const FINALIZE_RETRY_INITIAL: Duration = Duration::from_millis(100);

/// Cap of the doubling pause between retries: `FinalizeBlock`'s, `InitChain`'s and the startup
/// `Info`'s. `FinalizeBlock` also waits this long between checks of a decided block whose L1
/// header is not yet final or supported, or whose ruleset this node lacks.
pub const FINALIZE_RETRY_MAX: Duration = Duration::from_secs(5);

/// How long `FinalizeBlock` retries the EL for one decided block before it logs every further
/// retry at ERROR instead of WARN (it keeps retrying), so operators notice a stuck EL. Startup
/// retries (`InitChain`, the startup `Info`) never escalate: their normal waits, such as genesis
/// finality, last far longer.
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
    /// The checkpoint height a checkpoint import installed this store at
    /// ([`AppState::execution_floor`]); absent for a store `InitChain` started.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub execution_floor: Option<u64>,
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
    /// Node-local checkpoint phase, separate from the proposal liveness halt. Only
    /// [`trust::TrustPhase::Ready`] means trusted (SYNC-9-15).
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
    /// Recovery evidence errors convert as [`AbciError::Recovery`] does instead.
    #[error(transparent)]
    Genesis(GenesisError),
    /// Recovery evidence is unavailable, superseded, or invalid.
    #[error(transparent)]
    Recovery(crate::recovery::RecoveryError),
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
    /// A CometBFT `chain_id` differs from this chain's 48-byte `etna-` deployment-domain digest.
    #[error(transparent)]
    ChainId(#[from] RuleViolation),
    /// The first consensus height differs from the authenticated generation origin plus one.
    #[error("initial_height {got} must be {expected} for this generation")]
    InitialHeight {
        /// The requested initial height.
        got: u64,
        /// The authenticated origin plus one: 1 for genesis, c+1 for recovery.
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
    /// The validator updates `FinalizeBlock` returned for the decided block when it is a switch
    /// height (`None` elsewhere), set together with [`App::pending`]; `Commit` records them
    /// before the state and clears them.
    pending_val_updates: Option<Vec<(crate::key::ConsensusKey, u64)>>,
    /// The latest `ProcessProposal` ACCEPT verdicts (at most [`MAX_VERDICTS`]) by CometBFT block
    /// hash, which `FinalizeBlock` reuses without validating again; cleared at `Commit`.
    verdicts: Verdicts,
    /// The last committee witness verified for switch height `H(t)-2`, by `PrepareProposal` (its
    /// own), `ProcessProposal` (another proposer's) or the background discovery at the snapshot
    /// block ([`App::prefetch_committee_witness`]), kept so that this node's proposals at that
    /// height reuse it instead of reading the registry again. It lives in memory only: a restart
    /// re-discovers it from the own L1 (SYNC-9-16). It is dropped once the committed state leaves
    /// that context (another anchor or switch). Behind a mutex as the handlers run on `&self`.
    committee_cache: Mutex<Option<CachedCommittee>>,
    /// The background discovery of the upcoming switch height's committee witness at the
    /// committed state's snapshot block, the only one this node runs: `Commit`,
    /// `ProcessProposal` and `PrepareProposal` start it ([`App::prefetch_committee_witness`]),
    /// and a proposal needing the witness joins it ([`App::discovered_committee_witness`]). It
    /// runs on past any request's deadline; a committed state of another context drops it.
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
    /// The [`App::connections`] count at which the app last made sure the EL serves the
    /// committed head and any execution floor ([`App::reconcile_el_once`]); `None` before the
    /// first time. Set by a successful reconcile (the handshake `Info`, or for an imported store
    /// whichever of `Info` and `FinalizeBlock` comes first) or a successful `InitChain`, it holds
    /// the count read when that request started. While it equals the current count
    /// ([`App::el_reconciled`]), ordinary Info calls answer without EL I/O; trust of an imported
    /// store waits for it. Independent signer sessions separately recheck the durable head and
    /// ancestry through the checkpoint trust worker.
    el_reconciled_epoch: Option<u64>,
    /// The ABCI connections the server accepted, which it bumps for every new connection
    /// ([`ConnectionEpoch`]).
    connections: ConnectionEpoch,
    /// Process-local trust and session state, never serialized into AppState.
    trust: trust::TrustHandle,
    /// Revokes shared authorization on worker destruction, including panic/cancellation.
    _trust_lifetime: trust::TrustLifetime,
}

impl From<GenesisError> for AbciError {
    /// Recovery evidence converts as a [`RecoveryError`](crate::recovery::RecoveryError) does,
    /// keeping its class; other genesis errors stay [`AbciError::Genesis`].
    fn from(error: GenesisError) -> Self {
        match error {
            GenesisError::Recovery(error) => error.into(),
            error => Self::Genesis(error),
        }
    }
}

impl From<crate::recovery::RecoveryError> for AbciError {
    /// Unavailability stays retryable; authenticated recovery contradictions halt durably.
    fn from(error: crate::recovery::RecoveryError) -> Self {
        match error {
            crate::recovery::RecoveryError::Unavailable(_) => Self::Recovery(error),
            _ => Self::SafetyHalt(error.to_string()),
        }
    }
}

/// What a failed startup acquisition, startup EL reconciliation or trust refresh does next
/// (SYNC-9-7), from [`classify`].
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum ErrorClass {
    /// Unavailable, not yet final, timed out or transient input: the node stays untrusted and
    /// retries. A hash-authenticated L1 header this client cannot parse is here too: it needs an
    /// upgrade, not a halt (SYNC-9-8).
    MissingData,
    /// An authenticated contradiction, or malformed or unverifiable data from the own L1 node,
    /// EL or store, which the node cannot tell apart from forgery: a safety halt
    /// ([`contradiction_halt`]).
    Contradiction,
    /// Neither: startup requests fail with the error itself; the trust worker retries with it
    /// as the reason.
    Other,
}

/// The SYNC-9-7 class of `error`. Only acquisition failures are [`ErrorClass::MissingData`]:
/// a recovery input reported unavailable, an elapsed deadline, a missing EL block, a genesis
/// header not yet final, an EL sync timeout, a retryable engine error
/// ([`EngineError::is_retryable`]) and an L1 error that is no integrity failure
/// ([`L1Error::is_integrity_failure`]). [`ErrorClass::Contradiction`] is a raised safety halt,
/// an L1 integrity failure, a corrupt state file, a durable Comet hash, validator state or
/// validator updates record that disagrees with the recomputed one (SYNC-9-5c), a conflicting
/// recovery bootstrap, recovery evidence that is invalid, superseded or opens another
/// configuration, and an engine reply that is malformed, names another block or is
/// `-38100`/`-38002`. Startup and trust read only the own EL, so a block it serves for a hash
/// that it does not hash to ([`EngineError::BlockHashMismatch`]) is an own-EL contradiction here,
/// not a peer's invalid payload. Everything else is [`ErrorClass::Other`].
pub(super) fn classify(error: &AbciError) -> ErrorClass {
    use crate::recovery::RecoveryError;
    match error {
        AbciError::SafetyHalt(_) => ErrorClass::Contradiction,
        AbciError::Recovery(RecoveryError::Unavailable(_)) |
        AbciError::Timeout { .. } |
        AbciError::ElBlockMissing(_) |
        AbciError::GenesisNotFinal { .. } |
        AbciError::ElSync(ElSyncError::Timeout { .. }) => ErrorClass::MissingData,
        AbciError::Recovery(
            RecoveryError::Invalid(_) |
            RecoveryError::Superseded { .. } |
            RecoveryError::ConfigMismatch { .. },
        ) |
        AbciError::Store(
            StoreError::Corrupt { .. } |
            StoreError::CometConflict(_) |
            StoreError::ValStateConflict(_) |
            StoreError::ValUpdatesConflict(_) |
            StoreError::BootstrapConflict,
        ) => ErrorClass::Contradiction,
        AbciError::L1(error) if error.is_integrity_failure() => ErrorClass::Contradiction,
        AbciError::L1(_) => ErrorClass::MissingData,
        AbciError::Engine(error) | AbciError::ElSync(ElSyncError::Engine(error)) => {
            if error.is_retryable() {
                ErrorClass::MissingData
            } else if matches!(
                error,
                EngineError::ErrorReply { code: -38100 | -38002, .. } |
                    EngineError::BlockHashMismatch { .. } |
                    EngineError::HeaderHashMismatch { .. } |
                    EngineError::HeaderNumberMismatch { .. } |
                    EngineError::BadReply(_)
            ) {
                ErrorClass::Contradiction
            } else {
                ErrorClass::Other
            }
        }
        _ => ErrorClass::Other,
    }
}

/// The safety halt of an [`ErrorClass::Contradiction`]: a raised [`AbciError::SafetyHalt`] as
/// it is, any other error as a checkpoint source integrity failure naming it.
pub(super) fn contradiction_halt(error: AbciError) -> AbciError {
    match error {
        halt @ AbciError::SafetyHalt(_) => halt,
        error => AbciError::SafetyHalt(format!("checkpoint source integrity failure: {error}")),
    }
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// Creates the app, validating `params` and loading any persisted state from `store`.
    ///
    /// A loaded state must be consistent with `params` and with itself: its schedule must pass
    /// [`Schedule::validate`](crate::schedule::Schedule::validate) and equal the one derived from
    /// its genesis record, its Inbox must match the account
    /// authenticated at genesis, its `chain_id` must name `params.l2_chain_id` and its
    /// generation, its last height must equal its parent's number and its validator
    /// state's height and fit a CometBFT height, and an execution floor must lie above the
    /// generation's origin and at or below the last height. These local consistency checks do not
    /// authenticate a coherently rewritten state file. Saved committees are not re-derived: one
    /// that contradicts the decided chain halts `FinalizeBlock` (a different derived record at
    /// its switch, a certified proposer outside it, or validator updates the replica refuses or
    /// whose `next_validators_hash` disagrees). A wrong outgoing set at switch height S(t) whose
    /// updates the replica accepts halts only at S(t)+1, after they were returned and committed:
    /// CometBFT's NextValidators, the app's validator state and the immutable
    /// `val-updates-{S(t)}.bin` record then all hold the wrong set. Repairing the state file alone
    /// is not enough; repair is a fresh import (DATA-5.4-5) or clearing all three stores. A
    /// validator's app store may also hold the supervisor's latch and signer-unsafe record: before
    /// a validator runs on any new app store, the operator checks the old one for them and the
    /// domains log's directory for the `<chain_id>.signer-unsafe` marker. Any of them is uncertain
    /// signing state, resolved through governance, never by a new store (RECOV-8.2-3).
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
            if let Some(origin) = &state.recovery {
                let evidence = store.load_recovery_bootstrap()?.ok_or_else(|| {
                    AbciError::StoredState("missing immutable recovery bootstrap".into())
                })?;
                let history = evidence.verify(&params)?;
                if *origin != history.origin ||
                    state.genesis != history.genesis ||
                    (!state.has_generation_commit() &&
                        (state.anchor != history.anchor ||
                            state.parent !=
                                crate::recovery::recovery_parent(&history.witness) ||
                            state.forced_cursor != origin.forced_cursor ||
                            state.last_comet_hash != alloy_primitives::B256::ZERO))
                {
                    return Err(AbciError::StoredState(
                        "recovery bootstrap contradicts stored state".into(),
                    ));
                }
            } else if store.load_recovery_bootstrap()?.is_some() {
                return Err(AbciError::StoredState(
                    "recovery bootstrap beside generation-zero state".into(),
                ));
            }
        }
        let trust = trust::TrustHandle::new(state.as_ref())?;
        let app = Self {
            l1: Arc::new(l1),
            engine,
            params,
            store,
            opts,
            state,
            pending: None,
            pending_val_updates: None,
            verdicts: Verdicts::default(),
            committee_cache: Mutex::default(),
            committee_prefetch: Mutex::default(),
            preparation_cache: Arc::default(),
            decided_live: false,
            halt: None,
            superseded: false,
            el_reconciled_epoch: None,
            connections: ConnectionEpoch::default(),
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

    /// The count of accepted ABCI connections this app shares with its server
    /// ([`AbciHandler::connection_epoch`](crate::server::AbciHandler::connection_epoch)); it
    /// starts at 0.
    pub(crate) fn connections(&self) -> &ConnectionEpoch {
        &self.connections
    }

    /// Whether the EL was reconciled with the committed state since the server accepted its
    /// latest ABCI connection, i.e. during the current CometBFT handshake's connection set.
    fn el_reconciled(&self) -> bool {
        self.el_reconciled_epoch == Some(self.connections.current())
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
            execution_floor: state.execution_floor.map(|floor| floor.number),
            head: state.last_height,
            epoch: schedule.epoch_of(state.last_height.max(schedule.h0())),
            generation: state.generation,
            last_checkpoint_height: state.anchor.inbox.last_checkpoint_height,
            anchor: state.anchor.number,
            halt_reason: self.halt.clone(),
            superseded: self.superseded,
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
    ///
    /// A safety halt or store failure revokes trust and is recorded as fatal evidence. The
    /// error itself is always returned, so the halt stops the node even when its evidence cannot
    /// be persisted; that failure is logged at ERROR instead.
    pub async fn handle(&mut self, req: Request) -> Result<Response, AbciError> {
        let result = self.dispatch(req).await;
        if let Err(error) = &result {
            if matches!(error, AbciError::SafetyHalt(_) | AbciError::Store(_)) {
                self.trust.revoke(error.to_string());
                if let Err(persist) = self.store.record_fatal(&error.to_string()) {
                    tracing::error!(
                        %error,
                        persist_error = %persist,
                        "could not persist the fatal evidence; the halt stands"
                    );
                }
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
            // RECOV-8-15: reject and revoke while the process keeps running. The generic fatal
            // record only makes the restart refuse (RECOV-8-16).
            self.superseded = true;
            let reason = "authenticated higher recovery generation";
            if self.trust.revoke(reason) &&
                let Err(error) = self.store.record_fatal(reason)
            {
                tracing::error!(%error, "could not persist the supersession fatal evidence; the halt stands");
            }
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
///
/// `FinalizeBlock` takes the verdict under its decided block hash without validating the block
/// again. The hash commits to every request input [`validate_block`] reads: the height, BFT time,
/// proposer and transactions. Its other inputs are the committed state and the chain parameters,
/// and only `Commit` changes a committed state, clearing the cache (`InitChain` sets the first
/// one before any verdict can exist). A hit therefore means the same
/// inputs on the same committed state, so `FinalizeBlock` derives what `ProcessProposal` derived
/// (CONS-3.4-1). The verdict also holds the node-local checks a cold `FinalizeBlock` repeats:
/// own-L1 anchor finality, which a later finalized head cannot undo (CONS-3.3-5, CONS-3.4-12),
/// checkpoint ancestry (CONS-3.4-16), the completed forced decision (FI-7.2-9) and execution
/// (CONS-3.4-10); SYNC-9-1 asks them again only of a block the node did not judge live. A REJECT
/// stores nothing, so a block this node never accepted finalizes through full validation. This
/// trusts the local CometBFT to send the fields its block hash commits to.
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

/// Whether no Comet block has been committed in this generation, including a nonzero origin.
///
/// CometBFT re-sends `InitChain` whenever the app reports height 0, so `Info` reports 0 and
/// `InitChain` is idempotent in this state.
fn at_generation_origin(state: &AppState) -> bool {
    !state.has_generation_commit()
}

/// Rejects a persisted state that `params` or the state itself contradicts (see [`App::new`]).
fn check_stored_state(state: &AppState, params: &ChainParams) -> Result<(), AbciError> {
    if state.schema_version != STATE_SCHEMA_VERSION {
        return Err(AbciError::StoredState(format!(
            "unsupported app state schema {} (expected {STATE_SCHEMA_VERSION})",
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
    state.schedule().validate()?;
    if state.genesis.genesis_height != 0 {
        return Err(AbciError::StoredState("genesis height must be zero".into()));
    }
    match &state.recovery {
        None if state.generation != 0 => {
            return Err(AbciError::StoredState(
                "nonzero generation requires an authenticated recovery origin".into(),
            ))
        }
        Some(origin)
            if origin.generation == 0 ||
                origin.generation != state.generation ||
                origin.height > state.last_height ||
                origin.l1_number < state.genesis.l1_0 ||
                origin.committee.record.target_epoch != state.initial_committee_epoch() ||
                origin.committee.record.cutoff_l1_block != origin.l1_number ||
                state
                    .committees
                    .get(&state.initial_committee_epoch())
                    .is_some_and(|set| *set != origin.committee) =>
        {
            return Err(AbciError::StoredState("inconsistent recovery origin".into()));
        }
        _ => {}
    }
    check_chain_id(&state.chain_id, params, state.generation)?;
    if state.genesis.committee_config_hash != crate::committee::committee_config_hash(params) {
        return Err(AbciError::StoredState(
            "committee configuration opening differs from genesis".into(),
        ));
    }
    if state.parent.number != state.last_height {
        return Err(AbciError::StoredState(format!(
            "last height {} differs from the parent block number {}",
            state.last_height, state.parent.number
        )));
    }
    if state.val_state.height != state.last_height {
        return Err(AbciError::StoredState(format!(
            "last height {} differs from the validator state's height {}",
            state.last_height, state.val_state.height
        )));
    }
    if Height::try_from(state.last_height).is_err() {
        return Err(AbciError::StoredState(format!(
            "last height {} exceeds the CometBFT height range",
            state.last_height
        )));
    }
    if let Some(floor) = &state.execution_floor &&
        !(state.origin_height() < floor.number && floor.number <= state.last_height)
    {
        return Err(AbciError::StoredState(format!(
            "execution floor {} is not above the origin {} and at or below the last height {}",
            floor.number,
            state.origin_height(),
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

#[cfg(test)]
mod classify_tests {
    use std::{io, path::PathBuf};

    use alloy_eips::BlockNumberOrTag;
    use alloy_primitives::Address;

    use super::*;
    use crate::{
        genesis::GenesisError, l1::L1HeaderError, recovery::RecoveryError, schedule::ScheduleError,
    };

    /// Every error the startup tables and the trust table named before they were merged, and
    /// the own-L1 and recovery classes P6 settled (integrity vs transport, `Unavailable` vs
    /// `Invalid`), land in their SYNC-9-7 class: missing data retries, a contradiction or
    /// malformed own-source data halts, anything else is the call site's (SYNC-9-8: a
    /// hash-authenticated header this client cannot parse needs an upgrade, so it retries).
    #[test]
    fn classification_follows_sync_9_7() {
        for (error, expected) in &cases() {
            assert_eq!(classify(error), *expected, "{error:?}");
        }
    }

    /// Each error with its expected class.
    fn cases() -> Vec<(AbciError, ErrorClass)> {
        use ErrorClass::{Contradiction, MissingData, Other};
        let reply = |code| EngineError::ErrorReply {
            call: "engine_x at http://el.test/".into(),
            code,
            message: "m".into(),
        };
        let json = || serde_json::from_str::<u8>("x").unwrap_err();
        let header = || L1HeaderError::TrailingBytes(1);
        let (hash, other) = (B256::ZERO, B256::repeat_byte(1));
        let el_hash_mismatch =
            || EngineError::HeaderHashMismatch { number: 1, reported: hash, computed: other };
        vec![
            // Missing data: unavailable, not yet final, timed out or transient.
            (RecoveryError::Unavailable("history".into()).into(), MissingData),
            // `init.rs` converts bootstrap evidence errors with `?` through this `From`.
            (
                GenesisError::Recovery(RecoveryError::Unavailable("history".into())).into(),
                MissingData,
            ),
            (AbciError::Timeout { what: "w", after: Duration::from_secs(1) }, MissingData),
            (AbciError::ElBlockMissing(7), MissingData),
            (AbciError::GenesisNotFinal { number: 1, hash }, MissingData),
            (
                AbciError::ElSync(ElSyncError::Timeout {
                    number: 1,
                    hash,
                    timeout: Duration::from_secs(1),
                    last_error: None,
                }),
                MissingData,
            ),
            (EngineError::Transport("down".into()).into(), MissingData),
            (reply(-32603).into(), MissingData),
            (reply(-32000).into(), MissingData),
            (reply(1).into(), MissingData),
            (
                AbciError::ElSync(ElSyncError::Engine(EngineError::Transport("t".into()))),
                MissingData,
            ),
            (AbciError::ElSync(ElSyncError::Engine(reply(-32603))), MissingData),
            (L1Error::Rpc("transport".into()).into(), MissingData),
            (L1Error::DataUnavailable("pruned".into()).into(), MissingData),
            (L1Error::BlockNotFound(BlockNumberOrTag::Finalized).into(), MissingData),
            (L1Error::UnsupportedHeaderFormat { number: 1, error: header() }.into(), MissingData),
            (L1Error::UnknownHeaderFields { number: 1, fields: vec![] }.into(), MissingData),
            // Contradictions and malformed or unverifiable own-source data.
            (AbciError::SafetyHalt("halt".into()), Contradiction),
            (L1Error::MalformedResponse("shape".into()).into(), Contradiction),
            (L1Error::MalformedHeader { number: 1, error: header() }.into(), Contradiction),
            (
                L1Error::HeaderHashMismatch { number: 1, reported: hash, computed: other }.into(),
                Contradiction,
            ),
            (L1Error::HeaderNumberMismatch { requested: 1, got: 2 }.into(), Contradiction),
            (
                L1Error::ProofAddressMismatch { requested: Address::ZERO, got: Address::ZERO }
                    .into(),
                Contradiction,
            ),
            (
                L1Error::ProofSlotMismatch { requested: vec![], got: vec![hash] }.into(),
                Contradiction,
            ),
            (
                StoreError::Corrupt { path: PathBuf::from("s"), source: json() }.into(),
                Contradiction,
            ),
            (StoreError::CometConflict(1).into(), Contradiction),
            (StoreError::ValStateConflict(1).into(), Contradiction),
            (StoreError::ValUpdatesConflict(1).into(), Contradiction),
            (StoreError::BootstrapConflict.into(), Contradiction),
            (AbciError::Recovery(RecoveryError::Invalid("forged".into())), Contradiction),
            (GenesisError::Recovery(RecoveryError::Invalid("forged".into())).into(), Contradiction),
            (
                AbciError::Recovery(RecoveryError::Superseded { requested: 1, current: 2 }),
                Contradiction,
            ),
            (
                AbciError::Recovery(RecoveryError::ConfigMismatch { local: hash, proven: other }),
                Contradiction,
            ),
            (reply(-38100).into(), Contradiction),
            (reply(-38002).into(), Contradiction),
            (el_hash_mismatch().into(), Contradiction),
            // The own EL's block for a requested hash, such as the origin-state and import-floor
            // probes' (historical_state_available), hashes to something else.
            (
                EngineError::BlockHashMismatch { expected: hash, computed: other }.into(),
                Contradiction,
            ),
            (EngineError::HeaderNumberMismatch { requested: 1, got: 2 }.into(), Contradiction),
            (EngineError::BadReply("shape".into()).into(), Contradiction),
            (AbciError::ElSync(ElSyncError::Engine(reply(-38100))), Contradiction),
            (AbciError::ElSync(ElSyncError::Engine(reply(-38002))), Contradiction),
            (AbciError::ElSync(ElSyncError::Engine(el_hash_mismatch())), Contradiction),
            (
                AbciError::ElSync(ElSyncError::Engine(EngineError::BadReply("x".into()))),
                Contradiction,
            ),
            // Neither: startup fails the request, the trust worker retries with the reason.
            (AbciError::TrustControl("not final".into()), Other),
            (AbciError::NothingToCommit, Other),
            (AbciError::Uninitialized("FinalizeBlock"), Other),
            (AbciError::AlreadyInitialized, Other),
            (GenesisError::UnsupportedRecovery("x".into()).into(), Other),
            (ScheduleError::EpochTooShort { epoch_len: 1 }.into(), Other),
            (RuleViolation::UnsupportedRuleset { rules: 9 }.into(), Other),
            (AbciError::InitialHeight { got: 2, expected: 1 }, Other),
            (
                AbciError::GenesisTimeMismatch {
                    got: Time::unix_epoch(),
                    expected: Time::unix_epoch(),
                },
                Other,
            ),
            (AbciError::GenesisConsensusParamsMismatch, Other),
            (AbciError::GenesisValidatorsMismatch("x".into()), Other),
            (ConfigError::NotConfigured { chain_id: 1 }.into(), Other),
            (AbciError::StoredState("x".into()), Other),
            (StoreError::Import("x").into(), Other),
            (
                StoreError::Io {
                    op: "read",
                    path: PathBuf::from("s"),
                    source: io::Error::other("x"),
                }
                .into(),
                Other,
            ),
            (StoreError::Encode(json()).into(), Other),
            (reply(-38001).into(), Other),
            (reply(-38003).into(), Other),
            (reply(-38005).into(), Other),
            (reply(-32700).into(), Other),
            (reply(-32602).into(), Other),
            (EngineError::Setup("jwt".into()).into(), Other),
            (EngineError::Withdrawals(1).into(), Other),
            (AbciError::ElSync(ElSyncError::Engine(reply(-38001))), Other),
            (AbciError::ElSync(ElSyncError::Rejected { hash, reason: "bad".into() }), Other),
            (
                AbciError::ElSync(ElSyncError::Conflict {
                    number: 1,
                    expected: hash,
                    found: other,
                }),
                Other,
            ),
        ]
    }

    /// A contradiction halts with its own message; a halt already raised is kept as it is.
    #[test]
    fn contradiction_halt_keeps_a_raised_halt() {
        let halt = contradiction_halt(AbciError::SafetyHalt("EL contradicts".into()));
        assert_eq!(halt.to_string(), "safety halt: EL contradicts");
        let halt = contradiction_halt(StoreError::BootstrapConflict.into());
        assert_eq!(
            halt.to_string(),
            "safety halt: checkpoint source integrity failure: conflicting immutable recovery \
             bootstrap"
        );
    }
}
