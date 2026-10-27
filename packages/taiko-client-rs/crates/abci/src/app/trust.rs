//! Node-local checkpoint authentication and durable committed-chain trust.
//!
//! Readiness metadata never enters the app hash. Comet block IDs persist with committed state.
//! A session pins an own-finalized L1
//! proof, permits deterministic replay while closed, and refreshes once before becoming ready.
use std::{
    io::Read,
    sync::{Arc, Mutex, PoisonError},
};

use alloy_primitives::{Address, B256};
use serde::{Deserialize, Serialize};
use tokio::sync::Notify;

use super::{AbciError, App, within};
use crate::{
    engine::Engine,
    envelope::AnchorWitness,
    l1::{
        L1Source,
        layout::{inbox, word_u48},
        verify_account_witness, verify_anchor_witness,
    },
    store::AppState,
};

/// One authenticated checkpoint at an immutable finalized L1 snapshot.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CheckpointTarget {
    /// Own finalized L1 block number used for the proof (without extra depth subtraction).
    pub l1_number: u64,
    /// Hash of the raw header authenticating the proof's state root.
    pub l1_hash: B256,
    /// Checkpoint L2 height.
    pub height: u64,
    /// Checkpoint L2 block hash.
    pub hash: B256,
    /// Comet block ID authenticated by the checkpoint landing record (zero at height zero).
    pub comet_hash: B256,
    /// Authenticated recovery generation.
    pub generation: u64,
    /// Account whose storage proof authenticated this target.
    pub inbox: Address,
}

/// A committed L2 block reference, never an uncommitted execution result.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BlockRef {
    /// L2 block number.
    pub height: u64,
    /// L2 block hash.
    pub hash: B256,
}

/// Local trust phase, separate from consensus validity and liveness halt labels.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrustPhase {
    /// Authenticating own finalized L1 or waiting for initialization.
    Acquiring,
    /// Replaying to the pinned checkpoint or obtaining committed ancestry.
    CatchingUp,
    /// Durable committed-chain linkage and the final refresh succeeded.
    Ready,
    /// An authenticated contradiction or fatal app error requires intervention.
    Halted,
}

/// Versioned read-only signing/readiness snapshot. Null identity is always closed.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TrustSnapshot {
    /// Private control protocol version.
    pub schema_version: u32,
    /// Opaque process nonce and session counter; never reused across process restarts.
    pub session_id: String,
    /// Verified AppState identity; absent before InitChain.
    pub chain_id: Option<String>,
    /// Verified AppState generation; absent before InitChain.
    pub generation: Option<u64>,
    /// Only true after durable committed-chain verification and refresh.
    pub trust_ready: bool,
    /// True whenever signing must remain closed.
    pub syncing: bool,
    /// Current local phase.
    pub phase: TrustPhase,
    /// Authenticated checkpoint pinned for this catch-up attempt.
    pub target: Option<CheckpointTarget>,
    /// Raw durable local progress, whether or not trusted.
    pub committed_head: Option<BlockRef>,
    /// Available only when the current session is ready.
    pub trusted_consensus_head: Option<BlockRef>,
    /// Reason for remaining closed, if available.
    pub reason: Option<String>,
}

impl TrustSnapshot {
    /// Latches the first fatal reason and revokes this snapshot. Callers hold the state mutex.
    /// Returns false when an earlier fatal failure already revoked authorization.
    fn halt(&mut self, reason: String) -> bool {
        if self.phase == TrustPhase::Halted {
            return false;
        }
        self.trust_ready = false;
        self.syncing = true;
        self.phase = TrustPhase::Halted;
        self.trusted_consensus_head = None;
        self.reason = Some(bounded_reason(reason));
        self.publish_metrics();
        true
    }

    /// Reports only bounded numeric readiness metadata; detailed failure reasons stay in status.
    fn publish_metrics(&self) {
        use crate::metrics::{AbciMetrics, set_u64};
        AbciMetrics::checkpoint_trust_ready().set(i64::from(self.trust_ready));
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

/// Independent read handle and private session rearm capability.
#[derive(Clone, Debug)]
pub struct TrustHandle {
    /// Mutex holds only short synchronous snapshot updates, never network I/O.
    inner: Arc<Mutex<TrustState>>,
    /// Wakes the sequential worker to authenticate a new session.
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
        let snapshot = TrustSnapshot {
            schema_version: 1,
            session_id: format!("{nonce}:0"),
            chain_id: state.map(|s| s.chain_id.clone()),
            generation: state.map(|s| s.generation),
            trust_ready: false,
            syncing: true,
            phase: TrustPhase::Acquiring,
            target: None,
            committed_head: head,
            trusted_consensus_head: None,
            reason: None,
        };
        snapshot.publish_metrics();
        Ok(Self {
            inner: Arc::new(Mutex::new(TrustState {
                nonce,
                counter: 0,
                snapshot,
                floor: state.map(|state| CheckpointTarget {
                    l1_number: state.anchor.number,
                    l1_hash: state.anchor.hash,
                    height: state.anchor.inbox.last_checkpoint_height,
                    hash: state.anchor.inbox.last_checkpoint_hash,
                    // Committed anchors authenticate the EL hash; this floor's Comet hash is
                    // unknown until the first slot-285 proof is acquired.
                    comet_hash: B256::ZERO,
                    generation: state.generation,
                    inbox: state.inbox,
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
        state.snapshot.trust_ready = false;
        state.snapshot.syncing = true;
        state.snapshot.trusted_consensus_head = None;
        state.snapshot.publish_metrics();
        let snapshot = state.snapshot.clone();
        drop(state);
        self.wake.notify_one();
        snapshot
    }

    /// Returns closed for a stale session without altering the current session.
    pub(crate) fn check_session(&self, session: &str) -> TrustSnapshot {
        let mut snapshot = self.snapshot();
        if snapshot.session_id != session {
            snapshot.trust_ready = false;
            snapshot.syncing = true;
            snapshot.trusted_consensus_head = None;
            snapshot.reason = Some("stale trust session".into());
        }
        snapshot
    }

    /// Waits for a rearm request. Periodic retries are driven independently by the worker.
    pub(crate) async fn notified(&self) {
        self.wake.notified().await;
    }

    /// Permanently revokes authorization before a fatal error, shutdown or worker drop.
    pub(crate) fn revoke(&self, reason: impl Into<String>) {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        state.snapshot.halt(reason.into());
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
        if let Some(floor) = &state.floor {
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
                        (!floor.comet_hash.is_zero() &&
                            target.comet_hash != floor.comet_hash)))
            {
                return Err(AbciError::SafetyHalt(
                    "authenticated checkpoint conflicts with retained floor".into(),
                ));
            }
        }
        state.floor = Some(target.clone());
        Ok(())
    }

    /// Publishes only into the session that performed the verification. Old asynchronous work
    /// cannot reopen a newly allocated session or a fatal halt.
    fn publish(&self, snapshot: TrustSnapshot) {
        let mut state = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        if state.snapshot.session_id == snapshot.session_id &&
            state.snapshot.phase != TrustPhase::Halted
        {
            snapshot.publish_metrics();
            state.snapshot = snapshot;
        }
    }

    /// Updates raw durable progress; ready sessions extend through sequential valid commits.
    pub(super) fn committed(&self, state: &AppState) {
        let mut inner = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        let snapshot = &mut inner.snapshot;
        snapshot.chain_id = Some(state.chain_id.clone());
        snapshot.generation = Some(state.generation);
        snapshot.committed_head =
            Some(BlockRef { height: state.last_height, hash: state.parent.hash });
        if snapshot.trust_ready {
            snapshot.trusted_consensus_head = snapshot.committed_head.clone();
        }
        snapshot.publish_metrics();
        self.wake.notify_one();
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

    /// Performs one bounded retry of local trust acquisition/reconciliation. Network/history
    /// unavailability remains closed. Contradictions are fatal, independently of proposal halt.
    pub(crate) async fn refresh_trust(&mut self) -> Result<(), AbciError> {
        let mut snapshot = self.trust.snapshot();
        if matches!(snapshot.phase, TrustPhase::Ready | TrustPhase::Halted) {
            return Ok(());
        }
        match self.try_trust(&mut snapshot).await.map_err(classify_trust_error) {
            Ok(()) => self.trust.publish(snapshot),
            Err(error @ AbciError::SafetyHalt(_)) => {
                // A stale result cannot halt or authorize a newer session.
                if self.trust.revoke_if_session(&snapshot.session_id, error.to_string()) {
                    self.store.record_fatal(&error.to_string())?;
                    return Err(error);
                }
            }
            Err(error) => {
                snapshot.reason = Some(bounded_reason(error.to_string()));
                self.trust.publish(snapshot);
            }
        }
        Ok(())
    }

    /// Acquires a fixed target, proves durable linkage, refreshes, then publishes Ready.
    async fn try_trust(&self, snapshot: &mut TrustSnapshot) -> Result<(), AbciError> {
        let target = match &snapshot.target {
            Some(target) => target.clone(),
            None => {
                let target = self.acquire_target().await?;
                self.trust.pin(&snapshot.session_id, &target)?;
                snapshot.target = Some(target.clone());
                // Retain acquisition across retries, but only for this session.
                self.trust.publish(snapshot.clone());
                target
            }
        };
        let Some(state) = &self.state else { return Ok(()) };
        check_identity(state, &target)?;
        snapshot.phase = TrustPhase::CatchingUp;
        if !self.reconcile_trust_head(state).await? {
            snapshot.reason = Some("execution engine is recovering the committed head".into());
            return Ok(());
        }
        if state.last_height < target.height {
            snapshot.reason = Some("committed head is below the checkpoint".into());
            return Ok(());
        }
        self.verify_link(state, &target).await?;
        let refreshed = self.acquire_target().await?;
        check_identity(state, &refreshed)?;
        if refreshed.l1_number < target.l1_number || refreshed.height < target.height {
            snapshot.reason =
                Some("own finalized checkpoint regressed; waiting for consistent L1".into());
            return Ok(());
        }
        if (refreshed.l1_number == target.l1_number && refreshed.l1_hash != target.l1_hash) ||
            (refreshed.height == target.height &&
                (refreshed.hash != target.hash || refreshed.comet_hash != target.comet_hash))
        {
            return Err(AbciError::SafetyHalt(
                "authenticated checkpoint changed at the same height".into(),
            ));
        }
        self.trust.pin(&snapshot.session_id, &refreshed)?;
        snapshot.target = Some(refreshed.clone());
        if state.last_height < refreshed.height {
            snapshot.reason = Some("refreshed checkpoint is ahead of the committed head".into());
            return Ok(());
        }
        self.verify_link(state, &refreshed).await?;
        snapshot.phase = TrustPhase::Ready;
        snapshot.trust_ready = true;
        snapshot.syncing = false;
        snapshot.trusted_consensus_head = snapshot.committed_head.clone();
        snapshot.reason = None;
        Ok(())
    }

    /// Authenticates the exact own-finalized header/root and full Inbox anchor slot set.
    async fn acquire_target(&self) -> Result<CheckpointTarget, AbciError> {
        let timeout = self.opts.l1_timeout;
        let number = within("trust finalized L1", timeout, self.l1.finalized_number()).await?;
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
        let slots = inbox::landing_slots(facts.last_checkpoint_height);
        let landing = within(
            "trust landing proof",
            timeout,
            self.l1.account_witness(self.params.inbox, &slots, number),
        )
        .await?;
        if landing.address != self.params.inbox {
            return Err(AbciError::SafetyHalt("checkpoint landing account mismatch".into()));
        }
        let storage = verify_account_witness(header.state_root(), &landing, &slots)
            .map_err(|error| AbciError::SafetyHalt(format!("invalid landing proof: {error}")))?;
        let packed = storage.get(slots[0]).expect("verified exact slots");
        let el_hash = B256::from(storage.get(slots[1]).expect("verified exact slots"));
        let comet_hash = B256::from(storage.get(slots[2]).expect("verified exact slots"));
        let parent = word_u48(packed, 0);
        if el_hash != facts.last_checkpoint_hash ||
            word_u48(packed, 48) != facts.recovery_generation ||
            word_u48(packed, 96) != facts.forced_inclusion_head ||
            (facts.last_checkpoint_height == 0 && (parent != 0 || !comet_hash.is_zero())) ||
            (facts.last_checkpoint_height > 0 &&
                (parent >= facts.last_checkpoint_height || comet_hash.is_zero()))
        {
            return Err(AbciError::SafetyHalt("invalid checkpoint landing record".into()));
        }
        let canonical =
            within("trust canonical L1", timeout, self.l1.canonical_hash(number)).await?;
        if canonical != header.hash() {
            return Err(AbciError::SafetyHalt("checkpoint finalized L1 hash changed".into()));
        }
        if within("trust reconfirm finalized L1", timeout, self.l1.finalized_number()).await? <
            number
        {
            return Err(AbciError::TrustControl(
                "own finalized L1 regressed during checkpoint acquisition".into(),
            ));
        }
        if facts.last_checkpoint_hash.is_zero() || facts.last_checkpoint_height > i64::MAX as u64 {
            return Err(AbciError::SafetyHalt("invalid finalized Inbox checkpoint/status".into()));
        }
        Ok(CheckpointTarget {
            l1_number: number,
            l1_hash: header.hash(),
            height: facts.last_checkpoint_height,
            hash: facts.last_checkpoint_hash,
            comet_hash,
            generation: facts.recovery_generation,
            inbox: self.params.inbox,
        })
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

    /// Starts at the durable app hash and follows every parentHash to the target. A genuine
    /// target somewhere else in the EL cannot satisfy this chain. Missing history is retryable.
    async fn verify_link(
        &self,
        state: &AppState,
        target: &CheckpointTarget,
    ) -> Result<(), AbciError> {
        if state.last_height == target.height && state.parent.hash != target.hash {
            return Err(AbciError::SafetyHalt("durable checkpoint hash mismatch".into()));
        }
        let committed_comet = if target.height == 0 {
            B256::ZERO
        } else if target.height == state.last_height {
            state.last_comet_hash
        } else {
            self.store.load_comet_hash(target.height)?.ok_or_else(|| {
                AbciError::TrustControl(format!(
                    "missing committed Comet hash at {}",
                    target.height
                ))
            })?
        };
        if committed_comet != target.comet_hash {
            return Err(AbciError::SafetyHalt(format!(
                "committed checkpoint Comet hash mismatch at {}",
                target.height
            )));
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
                return Err(AbciError::SafetyHalt(format!(
                    "committed checkpoint hash mismatch at {number}"
                )));
            }
            expected = header.parent_hash;
        }
        Ok(())
    }

    /// Checks a derived candidate before settling it; Finalize alone never grants readiness.
    pub(super) fn check_trust_candidate(
        &self,
        height: u64,
        hash: B256,
        comet_hash: B256,
    ) -> Result<(), AbciError> {
        if let Some(target) = self.trust.snapshot().target &&
            height == target.height &&
            (hash != target.hash || comet_hash != target.comet_hash)
        {
            self.trust.revoke("decided checkpoint hash mismatch");
            return Err(AbciError::SafetyHalt(format!(
                "decided checkpoint hash mismatch at {height}"
            )));
        }
        Ok(())
    }
}

/// Binds a finalized proof to verified initialization identity, never query parameters.
fn check_identity(state: &AppState, target: &CheckpointTarget) -> Result<(), AbciError> {
    if target.generation != state.generation || target.inbox != state.inbox {
        return Err(AbciError::SafetyHalt(
            "checkpoint generation/Inbox differs from initialized chain".into(),
        ));
    }
    Ok(())
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

/// Adapter integrity failures must have the same fatal boundary as successful-but-invalid
/// proof/header values. Transport, missing history and unsupported-header capabilities remain
/// retryable: lack of data cannot prove a contradiction. Keep this local to startup trust.
fn classify_trust_error(error: AbciError) -> AbciError {
    use crate::{engine::EngineError, store::StoreError};
    let integrity = match &error {
        AbciError::L1(error) => error.is_integrity_failure(),
        AbciError::Store(StoreError::Corrupt { .. } | StoreError::CometConflict(_)) => true,
        AbciError::Engine(error) => matches!(
            error,
            EngineError::ErrorReply { code: -38100, .. } |
                EngineError::HeaderHashMismatch { .. } |
                EngineError::HeaderNumberMismatch { .. } |
                EngineError::BadReply(_)
        ),
        _ => false,
    };
    if integrity {
        AbciError::SafetyHalt(format!("checkpoint source integrity failure: {error}"))
    } else {
        error
    }
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
    }
}
