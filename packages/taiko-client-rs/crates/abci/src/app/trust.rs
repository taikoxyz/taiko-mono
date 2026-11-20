//! Node-local checkpoint trust: the one value the signing gate (SYNC-9-10) and the public trust
//! status (SYNC-9-15) read, so no signature needs an L1 read of its own.
//!
//! Readiness metadata never enters the app hash. Comet block IDs persist with committed state.
//!
//! # State machine
//!
//! The shared [`TrustSnapshot`] holds one signer session's [`TrustPhase`] and the latest
//! checkpoint target that session knows. The sequential app worker moves it:
//!
//! - **acquiring**: every app start and every `begin_session` (one per signer-to-Comet connection)
//!   starts here, untrusted (SYNC-9-4). The worker reads the Inbox's latest checkpoint (slots
//!   270/271) and `recoveryGeneration` (slot 268) at the own finalized L1 block. Missing data stays
//!   here and retries; an authenticated contradiction is a safety halt (SYNC-9-7), a different
//!   generation included (RECOV-8-16).
//! - **catching_up**: a target is pending. The committed chain is below it, so signing stays closed
//!   until it gets there, or the comparison has not finished: the local EL hash at the target
//!   height first, then the slot 285 record read at the same finalized L1 block, retried there
//!   while unavailable (SYNC-9-6a). A newer authenticated checkpoint replaces the target; a failed
//!   read never clears it.
//! - **ready**: the local EL and CometBFT hashes equal the latest known target's exactly (SYNC-9-5;
//!   the EL hash alone while it is the generation's origin, S or c), the switch checks pass
//!   (SYNC-9-5a) and the generation is current. The worker keeps following the own finalized L1
//!   view: a checkpoint above the matched one, read there or proven by a proposal's anchor
//!   (CONS-3.4-16), makes the session pending again; one at or below it needs no comparison; an
//!   unavailable read keeps the result (RECOV-8-5). Only a ready snapshot names an
//!   `eligible_height`.
//! - **halted**: terminal for the process. A contradiction found before the session first matched
//!   is a safety halt and the process exits (SYNC-9-7). Once a session has matched, a hash that
//!   conflicts with a newer checkpoint (SYNC-9-6a, CONS-3.4-16) or a larger `recoveryGeneration`
//!   (RECOV-8-14, RECOV-8-15) revokes trust instead: the node reports halted and signs nothing
//!   further while the process keeps running, and the generic fatal record makes the next start
//!   refuse. A signer reconnect cannot reopen it.
use std::{
    io::Read,
    sync::{Arc, Mutex, PoisonError},
    time::Duration,
};

use alloy_primitives::{Address, B256};
use serde::{Deserialize, Serialize};
use tokio::sync::Notify;

use super::{AbciError, App, ErrorClass, classify, contradiction_halt, within};
use crate::{
    engine::Engine,
    envelope::AnchorWitness,
    l1::{
        L1Source, OwnFinality, RawL1Header,
        layout::{inbox, word_u48},
        own_finality, verify_account_witness, verify_anchor_witness,
    },
    store::AppState,
    types::AnchorState,
};

/// First pause of the latest-checkpoint reads of a ready session after one failed; it doubles
/// per further failure up to [`FOLLOW_RETRY_MAX`]. Pausing keeps an unreachable own L1 from
/// taking the sequential worker's time on every tick while the matched result stands
/// (RECOV-8-5).
pub const FOLLOW_RETRY_INITIAL: Duration = Duration::from_secs(1);

/// Cap of the pause between the latest-checkpoint reads of a ready session.
pub const FOLLOW_RETRY_MAX: Duration = Duration::from_secs(30);

/// One authenticated checkpoint at an immutable own-finalized L1 block.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CheckpointTarget {
    /// Own finalized L1 block number whose Inbox proof authenticated this checkpoint.
    pub l1_number: u64,
    /// Hash of that L1 block's raw header.
    pub l1_hash: B256,
    /// Checkpoint L2 height (slot 270).
    pub height: u64,
    /// Checkpoint L2 block hash (slot 271).
    pub hash: B256,
    /// Comet block ID of the slot 285 record read at the same L1 block (zero at the Etna start
    /// S); `None` until that record is read.
    pub comet_hash: Option<B256>,
    /// Authenticated recovery generation (slot 268).
    pub generation: u64,
    /// Forced inclusion queue head proven with the checkpoint, which its record repeats.
    pub forced_head: u64,
    /// Account whose storage proof authenticated this target.
    pub inbox: Address,
}

impl CheckpointTarget {
    /// The checkpoint `anchor` proves at its own L1 block, before its slot 285 record is read.
    pub(super) fn of_anchor(anchor: &AnchorState, inbox: Address) -> Self {
        Self {
            l1_number: anchor.number,
            l1_hash: anchor.hash,
            height: anchor.inbox.last_checkpoint_height,
            hash: anchor.inbox.last_checkpoint_hash,
            comet_hash: None,
            generation: anchor.inbox.recovery_generation,
            forced_head: anchor.inbox.forced_inclusion_head,
            inbox,
        }
    }
}

/// A committed L2 block reference, never an uncommitted execution result.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BlockRef {
    /// L2 block number.
    pub height: u64,
    /// L2 block hash.
    pub hash: B256,
}

/// Local trust phase, separate from consensus validity and liveness pause labels; the module
/// docs give the transitions.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrustPhase {
    /// No checkpoint authenticated in this session yet, or waiting for initialization.
    Acquiring,
    /// A checkpoint target is pending: the committed chain is below it or the comparison with
    /// it has not finished.
    CatchingUp,
    /// The latest known checkpoint matched and the generation is current.
    Ready,
    /// An authenticated contradiction halted, or a later checkpoint or generation revoked,
    /// trust for the rest of the process.
    Halted,
}

/// Immutable recovery identity authenticated by the app's retained bootstrap evidence.
/// Private control caches this summary; signature requests never load the witness sidecar.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryTrustOrigin {
    /// Authenticated nonzero generation.
    pub generation: u64,
    /// Fixed retained L2 checkpoint c.
    pub height: u64,
    /// Canonical recovery execution block R.
    pub l1_number: u64,
    /// Hash of the proof-verified R header.
    pub l1_hash: B256,
    /// Timestamp of R in Unix seconds.
    pub l1_timestamp: u64,
    /// Retained execution hash at c.
    pub el_hash: B256,
    /// Retained old-generation Comet boundary hash at c.
    pub comet_hash: B256,
    /// Authenticated forced-inclusion cursor at c.
    pub forced_cursor: u64,
    /// Initial independently derived committee set hash (ENC-A-39a).
    pub committee_hash: B256,
}

/// The one private trust-control wire version, for generation zero and recovery alike.
/// Requests carrying any other version are refused; every snapshot carries this version.
pub const CONTROL_SCHEMA_VERSION: u32 = 1;

/// Versioned read-only signing/readiness snapshot. Null identity is always closed.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TrustSnapshot {
    /// Private control protocol version; always [`CONTROL_SCHEMA_VERSION`].
    pub schema_version: u32,
    /// Opaque process nonce and session counter; never reused across process restarts.
    pub session_id: String,
    /// Verified AppState identity; absent before InitChain.
    pub chain_id: Option<String>,
    /// Verified AppState generation; absent before InitChain.
    pub generation: Option<u64>,
    /// Recovery evidence summary, always on the wire: null for generation zero and before
    /// authentication.
    pub recovery_origin: Option<RecoveryTrustOrigin>,
    /// Current local phase; [`TrustPhase::Ready`] is the only phase that authorizes signing
    /// and serving (SYNC-9-10/9-15).
    pub phase: TrustPhase,
    /// Latest authenticated checkpoint this session knows: the matched one while ready, the
    /// pending one otherwise.
    pub target: Option<CheckpointTarget>,
    /// Raw durable local progress, whether or not trusted.
    pub committed_head: Option<BlockRef>,
    /// Available only when the current session is ready.
    pub trusted_consensus_head: Option<BlockRef>,
    /// The only height the app admits for signing (SYNC-9-10), present exactly while ready:
    /// the durable committed boundary plus one, which is the generation's `initial_height`
    /// before its first commit and s + 1 right after a 5.4 import at s. At most `i64::MAX`.
    pub eligible_height: Option<u64>,
    /// Reason for remaining closed, if available.
    pub reason: Option<String>,
    /// The session's progress, private to the app worker.
    #[serde(skip)]
    progress: SessionProgress,
}

/// What one signer session has done so far; reset by every `begin_session`.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct SessionProgress {
    /// Height of the checkpoint this session last matched; set once the session follows L1
    /// (SYNC-9-6a), so a later conflict revokes trust instead of halting the process.
    matched: Option<u64>,
    /// Own finalized L1 number whose Inbox slots this session read last.
    observed_l1: Option<u64>,
}

impl TrustSnapshot {
    /// Whether this snapshot authorizes signing and serving: only after durable committed-chain
    /// verification against the latest known checkpoint, which is exactly
    /// [`TrustPhase::Ready`].
    pub fn is_ready(&self) -> bool {
        self.phase == TrustPhase::Ready
    }

    /// Whether this session has matched a checkpoint, and so follows the own finalized L1 view.
    fn following(&self) -> bool {
        self.progress.matched.is_some()
    }

    /// Whether the known target is the one this session matched last: nothing is pending.
    fn target_matched(&self) -> bool {
        self.target.as_ref().is_some_and(|target| Some(target.height) == self.progress.matched)
    }

    /// Derives the fields that follow the phase: the trusted head and the eligible height exist
    /// only while ready. Then publishes the gauges.
    fn settle(&mut self) {
        if self.is_ready() {
            self.trusted_consensus_head = self.committed_head.clone();
            self.eligible_height = self
                .committed_head
                .as_ref()
                .and_then(|head| head.height.checked_add(1))
                .filter(|height| i64::try_from(*height).is_ok());
        } else {
            self.trusted_consensus_head = None;
            self.eligible_height = None;
        }
        self.publish_metrics();
    }

    /// Latches the first fatal reason and revokes this snapshot. Callers hold the state mutex.
    /// Returns false when an earlier fatal failure already revoked authorization.
    fn halt(&mut self, reason: String) -> bool {
        if self.phase == TrustPhase::Halted {
            return false;
        }
        self.phase = TrustPhase::Halted;
        self.reason = Some(bounded_reason(reason));
        self.settle();
        true
    }

    /// Reports only bounded numeric readiness metadata; detailed failure reasons stay in status.
    fn publish_metrics(&self) {
        use crate::metrics::{AbciMetrics, set_u64};
        AbciMetrics::checkpoint_trust_ready().set(i64::from(self.is_ready()));
        AbciMetrics::checkpoint_trust_phase().set(match self.phase {
            TrustPhase::Acquiring => 0,
            TrustPhase::CatchingUp => 1,
            TrustPhase::Ready => 2,
            TrustPhase::Halted => 3,
        });
        set_u64(
            AbciMetrics::checkpoint_target_l1(),
            self.target.as_ref().map_or(0, |t| t.l1_number),
        );
        let height = self.target.as_ref().map_or(0, |t| t.height);
        set_u64(AbciMetrics::checkpoint_target_l2(), height);
        set_u64(
            AbciMetrics::checkpoint_distance(),
            height.saturating_sub(self.committed_head.as_ref().map_or(0, |h| h.height)),
        );
    }
}

/// Shared snapshot and session counter. The app alone may publish verified readiness.
#[derive(Debug)]
struct TrustState {
    /// Random process incarnation identifier.
    nonce: String,
    /// Monotonic count of signer connections within this process.
    counter: u64,
    /// Current authorization snapshot.
    snapshot: TrustSnapshot,
    /// Strongest already authenticated checkpoint in this process (or committed anchor).
    /// Retained across signer reconnects, never persisted as a readiness marker.
    floor: Option<CheckpointTarget>,
}

impl TrustState {
    /// Checks `target` against the retained floor and raises the floor to it. Lagging own-L1
    /// answers are [`AbciError::TrustControl`]; an authenticated identity or hash conflict is a
    /// safety halt.
    fn raise_floor(&mut self, target: &CheckpointTarget) -> Result<(), AbciError> {
        if let Some(floor) = &self.floor {
            if target.generation != floor.generation || target.inbox != floor.inbox {
                return Err(AbciError::SafetyHalt(
                    "authenticated checkpoint identity changed".into(),
                ));
            }
            if target.l1_number < floor.l1_number || target.height < floor.height {
                return Err(AbciError::TrustControl(
                    "own finalized checkpoint is below authenticated floor".into(),
                ));
            }
            if (target.l1_number == floor.l1_number && target.l1_hash != floor.l1_hash) ||
                (target.height == floor.height &&
                    (target.hash != floor.hash ||
                        floor
                            .comet_hash
                            .zip(target.comet_hash)
                            .is_some_and(|(a, b)| a != b)))
            {
                return Err(AbciError::SafetyHalt(
                    "authenticated checkpoint conflicts with retained floor".into(),
                ));
            }
        }
        let comet_hash = target.comet_hash.or_else(|| {
            self.floor.as_ref().filter(|floor| floor.height == target.height)?.comet_hash
        });
        self.floor = Some(CheckpointTarget { comet_hash, ..target.clone() });
        Ok(())
    }
}

/// Independent read handle and private session rearm capability.
#[derive(Clone, Debug)]
pub struct TrustHandle {
    /// Mutex holds only short synchronous snapshot updates, never network I/O.
    inner: Arc<Mutex<TrustState>>,
    /// Wakes the sequential worker to authenticate a new session or a pending target.
    wake: Arc<Notify>,
}

impl TrustHandle {
    /// Starts closed with a fresh OS-random process nonce; entropy failure refuses startup.
    pub(super) fn new(state: Option<&AppState>) -> Result<Self, AbciError> {
        let mut nonce = [0u8; 16];
        std::fs::File::open("/dev/urandom")
            .and_then(|mut f| f.read_exact(&mut nonce))
            .map_err(|e| AbciError::TrustControl(format!("session entropy: {e}")))?;
        let nonce = nonce.iter().map(|b| format!("{b:02x}")).collect::<String>();
        let head = state.map(|s| BlockRef { height: s.last_height, hash: s.parent.hash });
        let mut snapshot = TrustSnapshot {
            schema_version: CONTROL_SCHEMA_VERSION,
            session_id: format!("{nonce}:0"),
            chain_id: state.map(|s| s.chain_id.clone()),
            generation: state.map(|s| s.generation),
            recovery_origin: None,
            phase: TrustPhase::Acquiring,
            target: None,
            committed_head: head,
            trusted_consensus_head: None,
            eligible_height: None,
            reason: None,
            progress: SessionProgress::default(),
        };
        snapshot.settle();
        Ok(Self {
            inner: Arc::new(Mutex::new(TrustState {
                nonce,
                counter: 0,
                snapshot,
                // Committed anchors authenticate the EL hash; this floor's Comet hash is
                // unknown until a slot 285 record is read.
                floor: state.map(|state| CheckpointTarget {
                    generation: state.generation,
                    ..CheckpointTarget::of_anchor(&state.anchor, state.inbox)
                }),
            })),
            wake: Arc::new(Notify::new()),
        })
    }

    /// Reads current authorization without waiting for the app worker or any network call.
    pub fn snapshot(&self) -> TrustSnapshot {
        self.inner.lock().unwrap_or_else(PoisonError::into_inner).snapshot.clone()
    }

    /// Immediately closes the old session and allocates a new one, then schedules verification.
    /// A fatal halt is sticky; reconnects cannot reset it.
    pub(crate) fn begin_session(&self) -> TrustSnapshot {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        match state.counter.checked_add(1) {
            Some(counter) => {
                state.counter = counter;
                state.snapshot.session_id = format!("{}:{counter}", state.nonce);
                state.snapshot.progress = SessionProgress::default();
                if state.snapshot.phase != TrustPhase::Halted {
                    state.snapshot.phase = TrustPhase::Acquiring;
                    state.snapshot.target = None;
                    state.snapshot.reason = None;
                }
            }
            None => {
                state.snapshot.phase = TrustPhase::Halted;
                state.snapshot.reason = Some("session counter exhausted".into());
            }
        }
        state.snapshot.settle();
        let snapshot = state.snapshot.clone();
        drop(state);
        self.wake.notify_one();
        snapshot
    }

    /// Closes authorization while retrying recovery inputs, preserving the signer's session
    /// and authenticated checkpoint floor. Only a later verification may publish readiness.
    pub(super) fn await_authentication(&self, reason: String) {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        let snapshot = &mut state.snapshot;
        if snapshot.phase != TrustPhase::Halted {
            snapshot.phase = TrustPhase::Acquiring;
            snapshot.progress.matched = None;
            snapshot.reason = Some(bounded_reason(reason));
        }
        snapshot.settle();
    }

    /// Returns closed for a stale session without altering the current session: only the
    /// returned copy reports [`TrustPhase::Acquiring`], with the current session's id; a fatal
    /// halt stays visible.
    pub(crate) fn check_session(&self, session: &str) -> TrustSnapshot {
        let mut snapshot = self.snapshot();
        if snapshot.session_id != session {
            if snapshot.phase != TrustPhase::Halted {
                snapshot.phase = TrustPhase::Acquiring;
            }
            snapshot.trusted_consensus_head = None;
            snapshot.eligible_height = None;
            snapshot.reason = Some("stale trust session".into());
        }
        snapshot
    }

    /// Waits for a rearm request. Periodic retries are driven independently by the worker.
    pub(crate) async fn notified(&self) {
        self.wake.notified().await;
    }

    /// Permanently revokes authorization before a fatal error, shutdown or worker drop.
    pub(crate) fn revoke(&self, reason: impl Into<String>) -> bool {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        state.snapshot.halt(reason.into())
    }

    /// Atomically checks the verification session and latches its fatal failure under the same
    /// mutex. A reconnect cannot interleave between authorization to revoke and the revocation.
    /// Returns true only when this error actually halted the current session.
    fn revoke_if_session(&self, session: &str, reason: String) -> bool {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        state.snapshot.session_id == session && state.snapshot.halt(reason)
    }

    /// Remembers authenticated evidence without allowing reconnects to lower an unreached
    /// checkpoint. Lagging own-L1 answers retry; authenticated identity/hash conflicts halt.
    fn pin(&self, session: &str, target: &CheckpointTarget) -> Result<(), AbciError> {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        if state.snapshot.session_id != session || state.snapshot.phase == TrustPhase::Halted {
            return Err(AbciError::TrustControl("trust session changed during acquisition".into()));
        }
        state.raise_floor(target)
    }

    /// Makes `target`, a checkpoint an own-finalized anchor proves, the session's pending target
    /// when it is above both the known target and the last matched checkpoint (SYNC-9-6a,
    /// CONS-3.4-16): a ready session reports catching up and signs nothing until the worker has
    /// compared it. One at or below them needs no comparison. Returns the reason to revoke trust
    /// when it conflicts with an authenticated checkpoint at its height.
    pub(super) fn raise(&self, target: CheckpointTarget) -> Result<(), String> {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        let snapshot = &state.snapshot;
        let known = snapshot.target.as_ref().map(|t| t.height).max(snapshot.progress.matched);
        if snapshot.phase == TrustPhase::Halted || known.is_some_and(|known| target.height <= known)
        {
            return Ok(());
        }
        match state.raise_floor(&target) {
            Ok(()) => {}
            Err(AbciError::SafetyHalt(reason)) => return Err(reason),
            Err(_) => return Ok(()),
        }
        let snapshot = &mut state.snapshot;
        snapshot.phase = TrustPhase::CatchingUp;
        snapshot.target = Some(target);
        snapshot.reason = Some("a newer authenticated checkpoint is pending".into());
        snapshot.settle();
        drop(state);
        self.wake.notify_one();
        Ok(())
    }

    /// Publishes only into the session that performed the verification. Old asynchronous work
    /// cannot reopen a newly allocated session or a fatal halt.
    fn publish(&self, mut snapshot: TrustSnapshot) {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        if state.snapshot.session_id == snapshot.session_id &&
            state.snapshot.phase != TrustPhase::Halted
        {
            snapshot.settle();
            state.snapshot = snapshot;
        }
    }

    /// Updates raw durable progress; ready sessions extend through sequential valid commits, and
    /// their eligible height follows the durable boundary. A session that is not ready is woken
    /// to compare as soon as the head reaches its target; a ready one keeps following on the
    /// worker's periodic retry, which keeps L1 reads off the path between blocks.
    pub(super) fn committed(&self, state: &AppState) {
        let mut inner = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        let snapshot = &mut inner.snapshot;
        snapshot.chain_id = Some(state.chain_id.clone());
        snapshot.generation = Some(state.generation);
        snapshot.committed_head =
            Some(BlockRef { height: state.last_height, hash: state.parent.hash });
        snapshot.settle();
        let ready = snapshot.is_ready();
        drop(inner);
        if !ready {
            self.wake.notify_one();
        }
    }
}

/// What one trust attempt leaves for [`App::refresh_trust`] to do.
#[derive(Debug)]
enum Outcome {
    /// Publish the attempt's snapshot.
    Publish,
    /// The latest-checkpoint read failed while the session's matched result stands: keep it
    /// (RECOV-8-5) and pause further reads.
    Unavailable(AbciError),
    /// Revoke trust while the process keeps running (SYNC-9-6a, RECOV-8-15).
    Revoke(Revocation),
}

/// Why a following session's trust is revoked.
#[derive(Debug)]
enum Revocation {
    /// A newer checkpoint's EL or Comet hash conflicts with local history.
    Conflict(String),
    /// The own finalized L1 view shows this larger `recoveryGeneration`.
    Superseded(u64),
}

/// The latest checkpoint in the own finalized L1 view.
#[derive(Debug)]
enum Observation {
    /// The own finalized block is the one the session read last.
    Unchanged,
    /// The checkpoint the own finalized block's Inbox proves.
    Checkpoint(CheckpointTarget),
    /// The Inbox's `recoveryGeneration` is this larger one.
    Superseded(u64),
}

/// The pause bookkeeping of a ready session's latest-checkpoint reads ([`FOLLOW_RETRY_INITIAL`]).
#[derive(Debug, Default)]
pub(super) struct FollowBackoff {
    /// Consecutive failed reads.
    failures: u32,
    /// No read before this instant.
    until: Option<tokio::time::Instant>,
}

impl FollowBackoff {
    /// Whether reads are paused.
    fn paused(&self) -> bool {
        self.until.is_some_and(|until| tokio::time::Instant::now() < until)
    }

    /// Records one failed read and returns the pause before the next.
    fn failed(&mut self) -> Duration {
        self.failures = self.failures.saturating_add(1);
        let doublings = self.failures.saturating_sub(1).min(5);
        let pause = FOLLOW_RETRY_INITIAL.saturating_mul(1 << doublings).min(FOLLOW_RETRY_MAX);
        self.until = Some(tokio::time::Instant::now() + pause);
        pause
    }
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// Cloneable local readiness handle. It never grants access to persisted consensus data.
    pub fn trust_handle(&self) -> TrustHandle {
        self.trust.clone()
    }

    /// Private control path beside the durable app store.
    pub fn trust_control_path(&self) -> std::path::PathBuf {
        self.store.directory().join("checkpoint-trust.sock")
    }

    /// Performs one bounded trust attempt: authentication of a closed session, or one step of
    /// following the own finalized L1 view for a ready one (see the module docs). Network or
    /// history unavailability stays closed, or keeps a ready result. An error [`classify`]
    /// calls [`ErrorClass::Contradiction`] halts (SYNC-9-7); any other is published as the
    /// retry reason. A conflict found while following revokes trust and the process keeps
    /// running.
    pub(crate) async fn refresh_trust(&mut self) -> Result<(), AbciError> {
        let mut snapshot = self.trust.snapshot();
        if snapshot.phase == TrustPhase::Halted ||
            (snapshot.is_ready() && snapshot.target_matched() && self.follow_backoff.paused())
        {
            return Ok(());
        }
        match self.try_trust(&mut snapshot).await {
            Ok(Outcome::Publish) => {
                self.follow_backoff = FollowBackoff::default();
                self.trust.publish(snapshot);
            }
            Ok(Outcome::Unavailable(error)) => {
                let pause = self.follow_backoff.failed();
                tracing::warn!(
                    %error,
                    ?pause,
                    "latest checkpoint unavailable in the own finalized L1 view; keeping the \
                     matched result"
                );
            }
            Ok(Outcome::Revoke(revocation)) => {
                let reason = match revocation {
                    Revocation::Conflict(reason) => reason,
                    Revocation::Superseded(current) => {
                        self.superseded = true;
                        format!("authenticated higher recovery generation {current}")
                    }
                };
                if self.trust.revoke_if_session(&snapshot.session_id, reason.clone()) {
                    self.record_revocation(&reason);
                }
            }
            Err(error) if classify(&error) == ErrorClass::Contradiction => {
                let error = contradiction_halt(error);
                // A stale result cannot halt or authorize a newer session. A later Inbox
                // generation is one such halt (RECOV-8-16): it keeps only the generic fatal
                // record, which makes the next start refuse.
                if self.trust.revoke_if_session(&snapshot.session_id, error.to_string()) {
                    self.store.record_fatal(&error.to_string())?;
                    return Err(error);
                }
            }
            Err(error) => {
                if self.state.as_ref().is_some_and(|s| s.recovery.is_some()) {
                    snapshot.phase = TrustPhase::Acquiring;
                    snapshot.progress.matched = None;
                }
                snapshot.reason = Some(bounded_reason(error.to_string()));
                self.trust.publish(snapshot);
            }
        }
        Ok(())
    }

    /// Revokes trust for the rest of the process while it keeps running (SYNC-9-6a,
    /// CONS-3.4-16, RECOV-8-15): the node reports halted and signs nothing further. The generic
    /// fatal record makes the next start refuse.
    pub(super) fn revoke_checkpoint_trust(&self, reason: &str) {
        if self.trust.revoke(reason) {
            self.record_revocation(reason);
        }
    }

    /// Alerts on a revocation and records the generic fatal evidence; a record that cannot be
    /// persisted is logged, and the revocation stands.
    fn record_revocation(&self, reason: &str) {
        tracing::error!(
            reason,
            "checkpoint trust revoked; signing stops, the process keeps running"
        );
        if let Err(error) = self.store.record_fatal(reason) {
            tracing::error!(%error, "could not persist the revocation's fatal evidence; it stands");
        }
    }

    /// Feeds the checkpoint an own-finalized `anchor` proves to the trust state
    /// ([`TrustHandle::raise`]): above the last matched one it is pending until the worker
    /// compared it; a conflict with an authenticated checkpoint at its height revokes trust.
    pub(super) fn observe_anchor_checkpoint(&self, anchor: &AnchorState) {
        if let Err(reason) =
            self.trust.raise(CheckpointTarget::of_anchor(anchor, self.params.inbox))
        {
            self.revoke_checkpoint_trust(&reason);
        }
    }

    /// One attempt: re-check recovery evidence, read the latest checkpoint at the own finalized
    /// L1 block, then compare the session's target with the committed chain.
    async fn try_trust(&self, snapshot: &mut TrustSnapshot) -> Result<Outcome, AbciError> {
        if self.state.as_ref().is_some_and(|s| s.recovery.is_some()) {
            self.recheck_recovery(snapshot).await?;
        }
        let following = snapshot.following();
        match self.observe_latest(snapshot).await {
            Ok(Observation::Unchanged) => {}
            Ok(Observation::Checkpoint(latest)) => {
                if !self.adopt(snapshot, latest)? {
                    return Ok(Outcome::Publish);
                }
            }
            Ok(Observation::Superseded(current)) if following => {
                return Ok(Outcome::Revoke(Revocation::Superseded(current)));
            }
            Ok(Observation::Superseded(current)) => {
                return Err(AbciError::Recovery(crate::RecoveryError::Superseded {
                    requested: self.state.as_ref().map_or(0, |state| state.generation),
                    current,
                }));
            }
            Err(error) if classify(&error) == ErrorClass::Contradiction => return Err(error),
            // A failed read never clears a known target (SYNC-9-6a); a matched one stands.
            Err(error) if snapshot.is_ready() && snapshot.target_matched() => {
                return Ok(Outcome::Unavailable(error));
            }
            Err(error) if snapshot.target.is_none() => return Err(error),
            Err(error) => snapshot.reason = Some(bounded_reason(error.to_string())),
        }
        let (Some(state), Some(mut target)) = (&self.state, snapshot.target.clone()) else {
            return Ok(Outcome::Publish);
        };
        check_identity(state, &target)?;
        if snapshot.is_ready() && snapshot.target_matched() {
            return Ok(Outcome::Publish);
        }
        snapshot.phase = TrustPhase::CatchingUp;
        // The slot 285 record at the same finalized L1 block, read as soon as the target is
        // known and retried there while unavailable; the EL comparison below never waits for it.
        let mut record_wait = None;
        if target.comet_hash.is_none() {
            match self.read_landing(state, &target).await {
                Ok(comet_hash) => {
                    target.comet_hash = Some(comet_hash);
                    self.trust.pin(&snapshot.session_id, &target)?;
                    snapshot.target = Some(target.clone());
                }
                Err(error) if classify(&error) == ErrorClass::Contradiction => return Err(error),
                Err(error) => {
                    record_wait = Some(bounded_reason(format!(
                        "waiting for the checkpoint's slot 285 record at L1 block {}: {error}",
                        target.l1_number
                    )));
                }
            }
        }
        // An imported node is trusted only once the app checked its execution floor on the
        // current ABCI connections (SYNC-9-7); the handshake reconciliation does that, never
        // this worker.
        if state.execution_floor.is_some() && !self.el_reconciled() {
            snapshot.reason = Some("waiting for the startup execution floor check".into());
            return Ok(Outcome::Publish);
        }
        if !self.reconcile_trust_head(state).await? {
            snapshot.reason = Some("execution engine is recovering the committed head".into());
            return Ok(Outcome::Publish);
        }
        if state.last_height < target.height {
            snapshot.reason = Some("committed head is below the checkpoint".into());
            return Ok(Outcome::Publish);
        }
        if names_pruned_history(Some(state), target.height) {
            return Err(AbciError::TrustControl(
                "own finalized checkpoint precedes the retained Comet history".into(),
            ));
        }
        // The EL hash at once, even while the slot 285 record is unavailable.
        if let Some(conflict) = self.verify_link(state, &target).await? {
            return mismatch(following, conflict);
        }
        let Some(comet_hash) = target.comet_hash else {
            snapshot.reason = record_wait;
            return Ok(Outcome::Publish);
        };
        // No Comet block of this generation exists at its origin, S or c: the EL hash alone.
        if target.height != state.origin_height() &&
            self.committed_comet_hash(state, target.height)? != comet_hash
        {
            return mismatch(
                following,
                format!("committed checkpoint Comet hash mismatch at {}", target.height),
            );
        }
        self.verify_fork_time(&state.genesis, target.l1_hash).await?;
        if target.height == state.genesis.genesis_height {
            let header = self.pinned_header(&target).await?;
            self.verify_switch_origin(&state.genesis, &header).await?;
        }
        // Every session reads the latest checkpoint itself before it trusts (SYNC-9-4).
        if snapshot.progress.observed_l1.is_none() {
            snapshot.reason = Some("waiting for the own finalized L1 view".into());
            return Ok(Outcome::Publish);
        }
        snapshot.progress.matched = Some(target.height);
        snapshot.phase = TrustPhase::Ready;
        snapshot.reason = None;
        Ok(Outcome::Publish)
    }

    /// Re-authenticates a recovery generation's evidence: the bootstrap, R's canonicality and
    /// the historical anchor's finality, in the own finalized L1 view.
    async fn recheck_recovery(&self, snapshot: &mut TrustSnapshot) -> Result<(), AbciError> {
        let bootstrap = self
            .store
            .load_recovery_bootstrap()?
            .ok_or_else(|| AbciError::SafetyHalt("missing recovery bootstrap evidence".into()))?;
        let crate::recovery::VerifiedBootstrap { witness, anchor, origin, .. } =
            bootstrap.verify(&self.params)?;
        if self.state.as_ref().and_then(|state| state.recovery.as_ref()) != Some(&origin) {
            return Err(AbciError::SafetyHalt("recovery trust evidence changed".into()));
        }
        snapshot.recovery_origin = Some(RecoveryTrustOrigin {
            generation: origin.generation,
            height: origin.height,
            l1_number: origin.l1_number,
            l1_hash: witness.recovery_header.hash(),
            l1_timestamp: origin.l1_timestamp,
            el_hash: origin.el_hash,
            comet_hash: origin.comet_hash,
            forced_cursor: origin.forced_cursor,
            committee_hash: origin.committee.record.set_hash,
        });
        within("trust recovery origin", self.opts.l1_timeout, async {
            crate::recovery::check_recovery_canonicality(self.l1(), &self.params, &witness)
                .await
                .map_err(AbciError::Recovery)
        })
        .await?;
        match within(
            "trust historical anchor finality",
            self.opts.l1_timeout,
            own_finality(self.l1(), anchor.number, anchor.hash),
        )
        .await?
        {
            OwnFinality::Canonical => Ok(()),
            OwnFinality::NotFinal { .. } => {
                Err(AbciError::TrustControl("historical anchor is not final in own L1".into()))
            }
            OwnFinality::OffChain { .. } => {
                Err(AbciError::SafetyHalt("historical recovery anchor changed".into()))
            }
        }
    }

    /// Makes `latest` the session's pending target when it is above the known one, and
    /// publishes that at once so signing closes before the comparison runs (SYNC-9-6a). One at
    /// or below a matched target needs no comparison. While a target is pending, the same
    /// checkpoint at a newer L1 block replaces it, so its record is read there again and any
    /// change halts against the retained floor; a lower one is an inconsistent own L1 view,
    /// which leaves the session closed (`false`) and reads again next time. The same height
    /// with another hash is a contradiction.
    fn adopt(
        &self,
        snapshot: &mut TrustSnapshot,
        latest: CheckpointTarget,
    ) -> Result<bool, AbciError> {
        if let Some(known) = &snapshot.target {
            if latest.height == known.height && latest.hash != known.hash {
                return Err(AbciError::SafetyHalt(
                    "authenticated checkpoint changed at the same height".into(),
                ));
            }
            if snapshot.target_matched() && latest.height <= known.height {
                return Ok(true);
            }
            if latest.height < known.height {
                snapshot.progress.observed_l1 = None;
                snapshot.reason = Some(
                    "own finalized checkpoint regressed below the pending target; waiting for \
                     consistent L1"
                        .into(),
                );
                return Ok(false);
            }
            if latest.height == known.height && latest.l1_number <= known.l1_number {
                return Ok(true);
            }
        }
        self.trust.pin(&snapshot.session_id, &latest)?;
        snapshot.target = Some(latest);
        if self.state.is_some() {
            snapshot.phase = TrustPhase::CatchingUp;
            snapshot.reason = Some("a newer authenticated checkpoint is pending".into());
        }
        self.trust.publish(snapshot.clone());
        Ok(true)
    }

    /// Authenticates the Inbox's latest checkpoint and generation (slots 268, 270, 271 among the
    /// anchor slots) at the own finalized L1 block, unless the session read that block already.
    async fn observe_latest(&self, snapshot: &mut TrustSnapshot) -> Result<Observation, AbciError> {
        let timeout = self.opts.l1_timeout;
        let number = within("trust finalized L1", timeout, self.l1.finalized_number()).await?;
        match snapshot.progress.observed_l1 {
            Some(seen) if seen == number => return Ok(Observation::Unchanged),
            Some(seen) if number < seen => {
                return Err(AbciError::TrustControl(format!(
                    "own finalized L1 {number} is below the observed {seen}; waiting"
                )));
            }
            _ => {}
        }
        let header = within("trust L1 header", timeout, self.l1.header(number)).await?;
        if header.number() != number {
            return Err(AbciError::SafetyHalt("trust L1 header has wrong number".into()));
        }
        let proof = within(
            "trust Inbox proof",
            timeout,
            self.l1.account_witness(self.params.inbox, &inbox::anchor_slots(), number),
        )
        .await?;
        let facts = verify_anchor_witness(
            &AnchorWitness { l1_header: header.clone(), inbox: proof },
            self.params.inbox,
        )
        .map_err(|e| AbciError::SafetyHalt(format!("invalid checkpoint proof: {e}")))?
        .inbox;
        // The Inbox holds the genesis checkpoint from L1_0 on, so an empty one means the own L1
        // has not finalized L1_0 yet: it is behind, as when it lags or after a failover to a
        // node that is. That is missing data (SYNC-9-7). Before InitChain the app does not know
        // L1_0 and waits on any empty Inbox; after it, an empty Inbox at or past L1_0 is a
        // contradiction, below.
        if facts.last_checkpoint_hash.is_zero() &&
            self.state.as_ref().is_none_or(|state| number < state.genesis.l1_0)
        {
            return Err(AbciError::TrustControl(format!(
                "own finalized L1 {number} precedes the Inbox's genesis checkpoint; waiting"
            )));
        }
        // A recovery keeps its origin's older landing record. Authenticate supersession from
        // the own-finalized Inbox before interpreting that record in the old generation.
        if let Some(state) = &self.state &&
            facts.recovery_generation > state.generation
        {
            self.confirm_target_header(&header).await?;
            return Ok(Observation::Superseded(facts.recovery_generation));
        }
        if facts.last_checkpoint_hash.is_zero() ||
            i64::try_from(facts.last_checkpoint_height).is_err()
        {
            return Err(AbciError::SafetyHalt("invalid finalized Inbox checkpoint/status".into()));
        }
        self.confirm_target_header(&header).await?;
        snapshot.progress.observed_l1 = Some(number);
        Ok(Observation::Checkpoint(CheckpointTarget {
            l1_number: number,
            l1_hash: header.hash(),
            height: facts.last_checkpoint_height,
            hash: facts.last_checkpoint_hash,
            comet_hash: None,
            generation: facts.recovery_generation,
            forced_head: facts.forced_inclusion_head,
            inbox: self.params.inbox,
        }))
    }

    /// Authenticates `target`'s three-word slot 285 record (STOR-B-9; the start record holds
    /// Comet hash 0) with the Etna start words, at the very L1 block that proved the target, and
    /// returns its Comet block ID. A record that contradicts the target or the authenticated
    /// start is malformed own-L1 data (SYNC-9-7).
    async fn read_landing(
        &self,
        state: &AppState,
        target: &CheckpointTarget,
    ) -> Result<B256, AbciError> {
        let header = self.pinned_header(target).await?;
        let record_slots = inbox::landing_record_slots(target.height);
        let mut slots = record_slots.to_vec();
        slots.extend([
            inbox::slot(inbox::GENESIS_PACKED),
            inbox::slot(inbox::START_BLOCK_HASH),
            inbox::slot(inbox::START_STATE_ROOT),
        ]);
        let landing = within(
            "trust landing proof",
            self.opts.l1_timeout,
            self.l1.account_witness(self.params.inbox, &slots, target.l1_number),
        )
        .await?;
        if landing.address != self.params.inbox {
            return Err(AbciError::SafetyHalt("checkpoint landing account mismatch".into()));
        }
        let storage = verify_account_witness(header.state_root(), &landing, &slots)
            .map_err(|error| AbciError::SafetyHalt(format!("invalid landing proof: {error}")))?;
        let inbox::LandingRecord {
            parent_height: parent,
            generation: landing_generation,
            forced_head,
            el_hash,
            comet_hash,
        } = inbox::LandingRecord::decode(
            record_slots.map(|slot| storage.get(slot).expect("verified exact slots")),
        )
        .ok_or_else(|| AbciError::SafetyHalt("invalid checkpoint landing record".into()))?;
        let genesis_word =
            storage.get(inbox::slot(inbox::GENESIS_PACKED)).expect("verified genesis slot");
        let start_height = word_u48(genesis_word, 0);
        let start_hash = B256::from(
            storage.get(inbox::slot(inbox::START_BLOCK_HASH)).expect("verified genesis slot"),
        );
        let start_root = B256::from(
            storage.get(inbox::slot(inbox::START_STATE_ROOT)).expect("verified genesis slot"),
        );
        let is_start = target.height == start_height;
        let retained_origin = state.recovery.as_ref().is_some_and(|origin| {
            target.generation == origin.generation &&
                target.height == origin.height &&
                el_hash == origin.el_hash &&
                comet_hash == origin.comet_hash &&
                forced_head == origin.forced_cursor &&
                landing_generation < origin.generation
        });
        if el_hash != target.hash ||
            (landing_generation != target.generation && !retained_origin) ||
            forced_head != target.forced_head ||
            genesis_word >> 144 != alloy_primitives::U256::ZERO ||
            target.height < start_height ||
            (is_start &&
                (el_hash != start_hash ||
                    parent != start_height ||
                    !comet_hash.is_zero() ||
                    forced_head != 0)) ||
            (!is_start &&
                (parent < start_height || parent >= target.height || comet_hash.is_zero()))
        {
            return Err(AbciError::SafetyHalt("invalid checkpoint landing record".into()));
        }
        self.confirm_target_header(&header).await?;
        if is_start &&
            (state.genesis.genesis_height != start_height ||
                state.genesis.genesis_hash != start_hash ||
                state.genesis.genesis_state_root != start_root)
        {
            return Err(AbciError::SafetyHalt("authenticated Etna start changed".into()));
        }
        Ok(comet_hash)
    }

    /// The own L1 header at `target`'s block, which must still be the one that proved it.
    async fn pinned_header(&self, target: &CheckpointTarget) -> Result<RawL1Header, AbciError> {
        let header = within(
            "trust pinned L1 header",
            self.opts.l1_timeout,
            self.l1.header(target.l1_number),
        )
        .await?;
        if header.number() != target.l1_number {
            return Err(AbciError::SafetyHalt("trust L1 header has wrong number".into()));
        }
        if header.hash() != target.l1_hash {
            return Err(AbciError::SafetyHalt("checkpoint finalized L1 hash changed".into()));
        }
        Ok(header)
    }

    /// Reconfirms own-finalized canonicality after the proofs used for this target or typed
    /// supersession have been read. A receding observation leaves the session closed; a
    /// different hash at a number still final is a contradiction (SYNC-9-7).
    async fn confirm_target_header(&self, header: &RawL1Header) -> Result<(), AbciError> {
        match within(
            "trust reconfirm finalized L1",
            self.opts.l1_timeout,
            own_finality(self.l1(), header.number(), header.hash()),
        )
        .await?
        {
            OwnFinality::Canonical => Ok(()),
            OwnFinality::NotFinal { .. } => Err(AbciError::TrustControl(
                "own finalized L1 regressed during checkpoint acquisition".into(),
            )),
            OwnFinality::OffChain { .. } => {
                Err(AbciError::SafetyHalt("checkpoint finalized L1 hash changed".into()))
            }
        }
    }

    /// Rechecks the actual committed head on every closed-session attempt, including Comet-only
    /// reconnects. A missing head receives a bounded sync nudge with unknown safe/finalized;
    /// future checkpoints are never used to skip committed history.
    async fn reconcile_trust_head(&self, state: &AppState) -> Result<bool, AbciError> {
        let header = within(
            "trust committed head",
            self.opts.engine_timeout,
            self.engine.header_by_number(state.last_height),
        )
        .await?;
        match header {
            Some(header)
                if header.number == state.last_height &&
                    header.hash_slow() == state.parent.hash =>
            {
                Ok(true)
            }
            Some(_) => Err(AbciError::SafetyHalt(
                "execution engine contradicts durable committed head".into(),
            )),
            None => {
                let verdict = within(
                    "trust committed head sync",
                    self.opts.engine_timeout,
                    self.engine.forkchoice(state.parent.hash, B256::ZERO, B256::ZERO),
                )
                .await?;
                if let crate::engine::PayloadVerdict::Invalid(reason) = verdict {
                    return Err(AbciError::SafetyHalt(format!(
                        "execution engine rejected committed head: {reason}"
                    )));
                }
                // Even VALID is checked through the canonical header on the next bounded pass.
                Ok(false)
            }
        }
    }

    /// Starts at the durable app hash and follows every parentHash down to the target. A
    /// genuine target somewhere else in the EL cannot satisfy this chain. Missing history is
    /// retryable; an EL whose ancestry breaks contradicts the committed chain and halts.
    ///
    /// Returns the conflict when the local EL hash at the target height differs from the
    /// target's (SYNC-9-5, SYNC-9-6a). The Comet hash is compared once the slot 285 record is
    /// read; L1 holds no validator state, so none is compared (SYNC-9-5c).
    async fn verify_link(
        &self,
        state: &AppState,
        target: &CheckpointTarget,
    ) -> Result<Option<String>, AbciError> {
        if state.last_height == target.height && state.parent.hash != target.hash {
            return Ok(Some(format!("durable checkpoint hash mismatch at {}", target.height)));
        }
        if target.height < state.origin_height() {
            return Err(AbciError::SafetyHalt("checkpoint precedes fixed generation origin".into()));
        }
        if let Some(origin) = &state.recovery &&
            target.height == origin.height &&
            target.hash != origin.el_hash
        {
            return Ok(Some("checkpoint contradicts retained origin".into()));
        }
        let mut expected = state.parent.hash;
        for number in (target.height..=state.last_height).rev() {
            let header = within(
                "trust committed ancestry",
                self.opts.engine_timeout,
                self.engine.header_by_number(number),
            )
            .await?
            .ok_or(AbciError::ElBlockMissing(number))?;
            if header.number != number || header.hash_slow() != expected {
                return Err(AbciError::SafetyHalt(format!(
                    "committed checkpoint ancestry conflicts at {number}"
                )));
            }
            if number == target.height && expected != target.hash {
                return Ok(Some(format!("committed checkpoint hash mismatch at {number}")));
            }
            if state.recovery.is_some() &&
                number > state.origin_height() &&
                crate::rules::decode_extra_data(&header.extra_data)
                    .map_or(true, |(_, generation, _)| generation != state.generation)
            {
                return Err(AbciError::SafetyHalt(
                    "old-generation header beyond recovery origin".into(),
                ));
            }
            expected = header.parent_hash;
        }
        Ok(None)
    }

    /// The Comet block ID this node committed at `height`, above the generation's origin.
    /// History pruned or never held (below an import) is missing data.
    fn committed_comet_hash(&self, state: &AppState, height: u64) -> Result<B256, AbciError> {
        if height == state.last_height {
            return Ok(state.last_comet_hash);
        }
        self.store.load_comet_hash(height)?.ok_or_else(|| {
            AbciError::TrustControl(format!("missing committed Comet hash at {height}"))
        })
    }

    /// Checks a decided block at the pending target height against the target's EL hash and,
    /// once read, its Comet hash before settling it; Finalize alone never grants readiness.
    pub(super) fn check_trust_candidate(
        &self,
        height: u64,
        hash: B256,
        comet_hash: B256,
    ) -> Result<(), AbciError> {
        let Some(target) = self.trust.snapshot().target.filter(|t| t.height == height) else {
            return Ok(());
        };
        if hash == target.hash && target.comet_hash.is_none_or(|comet| comet == comet_hash) {
            return Ok(());
        }
        let reason = format!("decided checkpoint hash mismatch at {height}");
        self.trust.revoke(reason.clone());
        Err(AbciError::SafetyHalt(reason))
    }
}

/// A conflict between a checkpoint and local history: a revocation for a session that already
/// follows L1 (SYNC-9-6a), a safety halt for a startup or new session check (SYNC-9-7).
fn mismatch(following: bool, conflict: String) -> Result<Outcome, AbciError> {
    if following {
        Ok(Outcome::Revoke(Revocation::Conflict(conflict)))
    } else {
        Err(AbciError::SafetyHalt(conflict))
    }
}

/// Binds a finalized proof to verified initialization identity, never query parameters.
fn check_identity(state: &AppState, target: &CheckpointTarget) -> Result<(), AbciError> {
    if target.inbox == state.inbox && target.generation > state.generation {
        return Err(AbciError::Recovery(crate::RecoveryError::Superseded {
            requested: state.generation,
            current: target.generation,
        }));
    }
    if target.generation != state.generation || target.inbox != state.inbox {
        return Err(AbciError::SafetyHalt(
            "checkpoint generation/Inbox differs from initialized chain".into(),
        ));
    }
    Ok(())
}

/// Whether a checkpoint at `height` names a Comet block ID that commits have pruned: above the
/// generation origin (whose ID the state retains) and below
/// [`AppState::comet_history_floor`]. Such a checkpoint is never verified; a newer one is.
fn names_pruned_history(state: Option<&AppState>, height: u64) -> bool {
    state
        .is_some_and(|state| state.origin_height() < height && height < state.comet_history_floor())
}

/// Revokes the independently cloned handle when its sole app owner is dropped.
#[derive(Debug)]
pub(super) struct TrustLifetime(
    /// Shared authorization owned by the app worker.
    pub(super) TrustHandle,
);

impl Drop for TrustLifetime {
    /// Covers graceful shutdown, task cancellation and stack unwinding.
    fn drop(&mut self) {
        self.0.revoke("app worker stopped");
    }
}

/// Bounds status/control diagnostics so external RPC error text cannot exceed the wire budget.
fn bounded_reason(reason: String) -> String {
    reason.chars().take(512).collect()
}

#[cfg(test)]
mod session_tests {
    use super::*;

    #[test]
    fn delayed_fatal_result_cannot_revoke_rearmed_session() {
        let trust = TrustHandle::new(None).unwrap();
        let old_session = trust.snapshot().session_id;
        let old_worker = trust.clone();
        let (error_ready, error_captured) = std::sync::mpsc::channel();
        let (apply_error, error_allowed) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || {
            // The old worker already owns its failed verification result. Deliberately finish
            // BeginSession before allowing that result to reach conditional revocation.
            error_ready.send(()).unwrap();
            error_allowed.recv().unwrap();
            old_worker.revoke_if_session(&old_session, "old fatal proof result".into())
        });
        error_captured.recv().unwrap();
        let current = trust.begin_session();
        apply_error.send(()).unwrap();
        assert!(!worker.join().unwrap(), "stale failure must not report a current fatal halt");
        assert_eq!(trust.snapshot().session_id, current.session_id);
        assert_eq!(trust.snapshot().phase, TrustPhase::Acquiring);
        assert!(trust.snapshot().reason.is_none());
        assert!(trust.revoke_if_session(&current.session_id, "current fatal proof result".into()));
        assert!(!trust.revoke_if_session(&current.session_id, "later fatal result".into()));
        assert_eq!(trust.snapshot().reason.as_deref(), Some("current fatal proof result"));
        assert_eq!(trust.begin_session().phase, TrustPhase::Halted);
        // A stale answer never hides a fatal halt behind a retryable phase.
        assert_eq!(trust.check_session(&current.session_id).phase, TrustPhase::Halted);
    }

    /// A ready snapshot names the durable boundary plus one as its only eligible height, and no
    /// other phase names one (SYNC-9-10): the stale copy for an old session included.
    #[test]
    fn only_a_ready_session_names_the_eligible_height() {
        let trust = TrustHandle::new(None).unwrap();
        let session = trust.snapshot().session_id;
        let mut snapshot = trust.snapshot();
        snapshot.committed_head = Some(BlockRef { height: 1200, hash: B256::repeat_byte(1) });
        snapshot.phase = TrustPhase::CatchingUp;
        trust.publish(snapshot.clone());
        assert_eq!(trust.snapshot().eligible_height, None);
        snapshot.phase = TrustPhase::Ready;
        trust.publish(snapshot.clone());
        assert_eq!(trust.snapshot().eligible_height, Some(1201));
        assert_eq!(trust.check_session(&session).eligible_height, Some(1201));
        assert_eq!(trust.check_session("other").eligible_height, None);
        // The boundary is a CometBFT height, so the next one must fit one too.
        snapshot.committed_head = Some(BlockRef { height: i64::MAX as u64, hash: B256::ZERO });
        trust.publish(snapshot);
        assert_eq!(trust.snapshot().eligible_height, None);
        let current = trust.begin_session();
        assert_eq!(current.phase, TrustPhase::Acquiring);
        assert_eq!(current.eligible_height, None);
        assert!(trust.revoke("revoked"));
        assert_eq!(trust.snapshot().eligible_height, None);
    }
}
