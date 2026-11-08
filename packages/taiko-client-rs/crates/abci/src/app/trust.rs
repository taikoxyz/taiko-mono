//! Node-local checkpoint authentication and durable committed-chain trust.
//!
//! Readiness metadata never enters the app hash. Comet block IDs persist with committed state.
//! A session pins an own-finalized L1
//! proof, permits deterministic replay while closed, and refreshes once before becoming ready.
use std::{
    io::Read,
    sync::{Arc, Mutex, PoisonError},
};

use alloy_primitives::{Address, B256, keccak256};
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
    valstate::ValState,
};

/// One authenticated checkpoint at an immutable finalized L1 snapshot.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CheckpointTarget {
    /// Own finalized L1 block number used for the proof.
    pub l1_number: u64,
    /// Hash of the raw header authenticating the proof's state root.
    pub l1_hash: B256,
    /// Checkpoint L2 height.
    pub height: u64,
    /// Checkpoint L2 block hash.
    pub hash: B256,
    /// Comet block ID authenticated by the checkpoint landing record (zero at height zero).
    pub comet_hash: B256,
    /// Validator-state hash (appendix A's `valStateHash`) authenticated by the checkpoint
    /// landing record's word 4 (zero at height zero).
    pub val_state_hash: B256,
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
    /// Initial independently derived committee set root.
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
    /// Whether this snapshot authorizes signing and serving: only after durable committed-chain
    /// verification and refresh, which is exactly [`TrustPhase::Ready`].
    pub fn is_ready(&self) -> bool {
        self.phase == TrustPhase::Ready
    }

    /// Latches the first fatal reason and revokes this snapshot. Callers hold the state mutex.
    /// Returns false when an earlier fatal failure already revoked authorization.
    fn halt(&mut self, reason: String) -> bool {
        if self.phase == TrustPhase::Halted {
            return false;
        }
        self.phase = TrustPhase::Halted;
        self.trusted_consensus_head = None;
        self.reason = Some(bounded_reason(reason));
        self.publish_metrics();
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
            schema_version: CONTROL_SCHEMA_VERSION,
            session_id: format!("{nonce}:0"),
            chain_id: state.map(|s| s.chain_id.clone()),
            generation: state.map(|s| s.generation),
            recovery_origin: None,
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
                    // Committed anchors authenticate the EL hash; this floor's Comet and
                    // validator-state hashes are unknown until the first slot-285 proof is
                    // acquired.
                    comet_hash: B256::ZERO,
                    val_state_hash: B256::ZERO,
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
        state.snapshot.trusted_consensus_head = None;
        state.snapshot.publish_metrics();
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
            snapshot.reason = Some(bounded_reason(reason));
        }
        snapshot.trusted_consensus_head = None;
        snapshot.publish_metrics();
    }

    /// Returns closed for a stale session without altering the current session: only the
    /// returned copy reports [`TrustPhase::Acquiring`]; a fatal halt stays visible.
    pub(crate) fn check_session(&self, session: &str) -> TrustSnapshot {
        let mut snapshot = self.snapshot();
        if snapshot.session_id != session {
            if snapshot.phase != TrustPhase::Halted {
                snapshot.phase = TrustPhase::Acquiring;
            }
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
                            target.comet_hash != floor.comet_hash) ||
                        (!floor.val_state_hash.is_zero() &&
                            target.val_state_hash != floor.val_state_hash)))
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
        if snapshot.is_ready() {
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
    /// unavailability remains closed. Contradictions are fatal, independently of proposal halt:
    /// an error [`classify`] calls [`ErrorClass::Contradiction`] halts (SYNC-9-7), any other is
    /// published as the retry reason.
    pub(crate) async fn refresh_trust(&mut self) -> Result<(), AbciError> {
        let mut snapshot = self.trust.snapshot();
        if snapshot.phase == TrustPhase::Halted ||
            (snapshot.phase == TrustPhase::Ready &&
                self.state.as_ref().is_none_or(|s| s.recovery.is_none()))
        {
            return Ok(());
        }
        let result = self.try_trust(&mut snapshot).await;
        let superseded = match &result {
            Err(AbciError::Recovery(crate::RecoveryError::Superseded { requested, current }))
                if self.state.as_ref().is_some_and(|state| state.generation == *requested) =>
            {
                Some(*current)
            }
            _ => None,
        };
        match result {
            Ok(()) => self.trust.publish(snapshot),
            Err(error) if classify(&error) == ErrorClass::Contradiction => {
                let error = contradiction_halt(error);
                // A stale result cannot halt or authorize a newer session.
                if self.trust.revoke_if_session(&snapshot.session_id, error.to_string()) {
                    if let (Some(current), Some(state)) = (superseded, self.state.as_ref()) {
                        self.store.record_supersession(state, current, &error.to_string())?;
                    } else {
                        self.store.record_fatal(&error.to_string())?;
                    }
                    return Err(error);
                }
            }
            Err(error) => {
                if self.state.as_ref().is_some_and(|s| s.recovery.is_some()) {
                    snapshot.phase = TrustPhase::Acquiring;
                    snapshot.trusted_consensus_head = None;
                }
                snapshot.reason = Some(bounded_reason(error.to_string()));
                self.trust.publish(snapshot);
            }
        }
        Ok(())
    }

    /// Acquires a fixed target, proves durable linkage, refreshes, then publishes Ready.
    async fn try_trust(&self, snapshot: &mut TrustSnapshot) -> Result<(), AbciError> {
        if self.state.as_ref().is_some_and(|s| s.recovery.is_some()) {
            let bootstrap = self.store.load_recovery_bootstrap()?.ok_or_else(|| {
                AbciError::SafetyHalt("missing recovery bootstrap evidence".into())
            })?;
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
                committee_hash: origin.committee.record.set_root,
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
                OwnFinality::Canonical => {}
                OwnFinality::NotFinal { .. } => {
                    return Err(AbciError::TrustControl(
                        "historical anchor is not final in own L1".into(),
                    ));
                }
                OwnFinality::OffChain { .. } => {
                    return Err(AbciError::SafetyHalt("historical recovery anchor changed".into()));
                }
            }
        }
        // A ready session already authenticates its sequentially committed head. Recheck
        // governance above without rescanning the entire settled prefix on every commit/tick.
        if snapshot.phase == TrustPhase::Ready {
            return Ok(());
        }
        let pinned = snapshot.target.clone();
        let target = match pinned.filter(|t| !names_pruned_history(self.state.as_ref(), t.height)) {
            Some(target) => target,
            None => {
                let target = self.acquire_target().await?;
                if names_pruned_history(self.state.as_ref(), target.height) {
                    snapshot.target = None;
                    return Err(AbciError::TrustControl(
                        "own finalized checkpoint precedes the retained Comet history".into(),
                    ));
                }
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
                (refreshed.hash != target.hash ||
                    refreshed.comet_hash != target.comet_hash ||
                    refreshed.val_state_hash != target.val_state_hash))
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
        snapshot.trusted_consensus_head = snapshot.committed_head.clone();
        snapshot.reason = None;
        Ok(())
    }

    /// Authenticates the exact own-finalized header/root and full Inbox anchor slot set, and
    /// the four-word slot 285 record of its checkpoint (the start record holds Comet and
    /// validator-state hashes 0).
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
        // A recovery keeps its origin's older landing record. Authenticate supersession from
        // the own-finalized Inbox before interpreting that record in the old generation.
        if let Some(state) = &self.state &&
            facts.recovery_generation > state.generation
        {
            self.confirm_target_header(&header).await?;
            return Err(AbciError::Recovery(crate::RecoveryError::Superseded {
                requested: state.generation,
                current: facts.recovery_generation,
            }));
        }
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
        let val_state_hash = B256::from(storage.get(slots[3]).expect("verified exact slots"));
        let parent = word_u48(packed, 0);
        let landing_generation = word_u48(packed, 48);
        let retained_origin =
            self.state.as_ref().and_then(|s| s.recovery.as_ref()).is_some_and(|origin| {
                facts.recovery_generation == origin.generation &&
                    facts.last_checkpoint_height == origin.height &&
                    el_hash == origin.el_hash &&
                    comet_hash == origin.comet_hash &&
                    val_state_hash == origin.val_state_hash &&
                    word_u48(packed, 96) == origin.forced_cursor &&
                    landing_generation < origin.generation
            });
        if self.state.is_none() && landing_generation < facts.recovery_generation {
            return Err(AbciError::TrustControl(
                "recovery origin requires independently verified InitChain".into(),
            ));
        }
        if el_hash != facts.last_checkpoint_hash ||
            (landing_generation != facts.recovery_generation && !retained_origin) ||
            packed >> 144 != alloy_primitives::U256::ZERO ||
            word_u48(packed, 96) != facts.forced_inclusion_head ||
            (facts.last_checkpoint_height == 0 &&
                (parent != 0 || !comet_hash.is_zero() || !val_state_hash.is_zero())) ||
            (facts.last_checkpoint_height > 0 &&
                (parent >= facts.last_checkpoint_height || comet_hash.is_zero()))
        {
            return Err(AbciError::SafetyHalt("invalid checkpoint landing record".into()));
        }
        self.confirm_target_header(&header).await?;
        if facts.last_checkpoint_hash.is_zero() || facts.last_checkpoint_height > i64::MAX as u64 {
            return Err(AbciError::SafetyHalt("invalid finalized Inbox checkpoint/status".into()));
        }
        Ok(CheckpointTarget {
            l1_number: number,
            l1_hash: header.hash(),
            height: facts.last_checkpoint_height,
            hash: facts.last_checkpoint_hash,
            comet_hash,
            val_state_hash,
            generation: facts.recovery_generation,
            inbox: self.params.inbox,
        })
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

    /// Starts at the durable app hash and follows every parentHash to the target. A genuine
    /// target somewhere else in the EL cannot satisfy this chain. Missing history is retryable.
    ///
    /// Above the generation origin, once the EL ancestry links, the landed validator-state hash
    /// must equal the hash of the node's own validator state there (SYNC-9-5): the head state,
    /// or the record it made when it committed that height, recomputed from an earlier exact
    /// record and the update records since when that record is missing or corrupt
    /// ([`App::val_state_preimage`], SYNC-9-5c). Stock CometBFT's stored validator-set lookup
    /// is never a source. The origin's record does not hold this generation's state and is not
    /// compared. A mismatch halts (SYNC-9-5b); a state the node cannot record or recompute is
    /// missing data and keeps it untrusted and retrying, like missing Comet history (SYNC-9-7).
    async fn verify_link(
        &self,
        state: &AppState,
        target: &CheckpointTarget,
    ) -> Result<(), AbciError> {
        if state.last_height == target.height && state.parent.hash != target.hash {
            return Err(AbciError::SafetyHalt("durable checkpoint hash mismatch".into()));
        }
        if target.height < state.origin_height() {
            return Err(AbciError::SafetyHalt("checkpoint precedes fixed generation origin".into()));
        }
        let committed_comet = if let Some(origin) = &state.recovery &&
            target.height == origin.height
        {
            if target.hash != origin.el_hash {
                return Err(AbciError::SafetyHalt("checkpoint contradicts retained origin".into()));
            }
            origin.comet_hash
        } else if target.height == 0 {
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
        // After the EL walk, so an EL divergence is named as such even when the validator
        // states differ too.
        if target.height != state.origin_height() {
            let preimage = self.val_state_preimage(target.height).map_err(|error| {
                AbciError::TrustControl(format!(
                    "validator state unavailable at {}: {error} (SYNC-9-5c)",
                    target.height
                ))
            })?;
            if keccak256(preimage) != target.val_state_hash {
                return Err(AbciError::SafetyHalt(format!(
                    "validator_state_mismatch: the landed validator-state hash at {} differs \
                     from the committed one",
                    target.height
                )));
            }
        }
        Ok(())
    }

    /// Checks a derived candidate, with the validator state `val_state` after it, before
    /// settling it; Finalize alone never grants readiness.
    pub(super) fn check_trust_candidate(
        &self,
        height: u64,
        hash: B256,
        comet_hash: B256,
        val_state: &ValState,
    ) -> Result<(), AbciError> {
        let Some(target) = self.trust.snapshot().target.filter(|t| t.height == height) else {
            return Ok(());
        };
        let reason = if hash != target.hash || comet_hash != target.comet_hash {
            format!("decided checkpoint hash mismatch at {height}")
        } else if val_state.hash() != target.val_state_hash {
            format!(
                "validator_state_mismatch: the decided validator state at {height} differs from \
                 the landed one"
            )
        } else {
            return Ok(());
        };
        self.trust.revoke(reason.clone());
        Err(AbciError::SafetyHalt(reason))
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
/// [`AppState::comet_history_floor`]. Such a checkpoint is never verified, only re-acquired.
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
}
