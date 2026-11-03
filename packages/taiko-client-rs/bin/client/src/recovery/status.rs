//! Redacted local observations; prepared plans never authorize startup or signing.
use super::{
    RecoveryCommandError,
    activate::{FinalizedLanding, finalized_landing, verify_committed},
    plan::Prerequisite,
    store::RecoveryStore,
};
use abci::{Engine, rules};
use alloy_primitives::B256;
use serde::{Deserialize, Serialize};
use std::time::Duration;

/// Durable orchestration observation, extended by activation without implying authorization.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActivationJournal {
    /// Supported journal schema.
    pub schema: u32,
    /// Exact immutable plan whose operation is observed.
    pub plan_id: B256,
    /// Last durable operation phase.
    pub phase: RecoveryPhase,
    /// Last active selector observed by this operation; never startup authorization.
    #[serde(default)]
    pub active: Option<super::store::ActiveDescriptor>,
    /// Last private-session progress, absent until live observation succeeds.
    #[serde(default)]
    pub progress: Option<ActivationProgress>,
    /// Last redacted reason that prevents progress.
    #[serde(default)]
    pub blocker: Option<ActivationBlocker>,
    /// Roles actually spawned during the recorded operation, never PID ownership.
    #[serde(default)]
    pub components: Vec<String>,
}
/// Compatibility name for the prepared observation journal.
pub type RecoveryJournal = ActivationJournal;
/// Compatibility name for recovery operation phases.
pub type RecoveryPhase = ActivationPhase;
impl ActivationJournal {
    /// Fresh observation without process, trust or signing authority.
    pub fn prepared(plan_id: B256) -> Self {
        Self {
            schema: 1,
            plan_id,
            phase: ActivationPhase::Prepared,
            active: None,
            progress: None,
            blocker: None,
            components: vec![],
        }
    }
}
/// Durable operation phases; callers must recheck real facts before any transition.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ActivationPhase {
    /// Only immutable evidence/configuration has been staged.
    Prepared,
    /// Old declared writers are being fenced.
    Stopping,
    /// All declared original/current writers are quiescent and reserved.
    Isolated,
    /// The retained origin state supported a real unpromoted build.
    ElOriginReady,
    /// The complete immutable bundle has an atomic active descriptor.
    Installed,
    /// Owned foreground children have been started.
    Running,
    /// An exact private runtime session was observed Ready.
    Trusted,
    /// Own finalized L1 authenticated a new-generation landing above c.
    Settled,
}
/// Public redacted report, separate from private executable and signer paths.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStatus {
    /// Exact content-addressed plan.
    pub plan_id: B256,
    /// Requested authenticated generation.
    pub generation: u64,
    /// Fixed retained L2 origin c.
    pub origin_height: u64,
    /// Fixed L1 recovery execution block R.
    pub recovery_l1_block: u64,
    /// Durable local phase, not a trust claim.
    pub phase: RecoveryPhase,
    /// Last authenticated L1-finalized checkpoint height, not a runtime commitment.
    pub landed_height: u64,
    /// Authenticated checkpoint the future runtime must meet before trust can be observed.
    pub trust_target_height: u64,
    /// No runtime session has been queried by this local status command.
    pub component_state: ComponentObservation,
    /// Committed height is unknown until a running owned session is observed.
    pub committed_height: Option<u64>,
    /// Missing preliminary and activation prerequisites.
    pub prerequisites: Vec<Prerequisite>,
    /// Always false for offline status: historical observations never authorize readiness.
    pub live_trust: bool,
    /// Last durable progress from a private session; potentially stale, never authorization.
    pub last_observation: Option<ActivationProgress>,
    /// Redacted actionable waiting/stop reason, never raw provider diagnostics.
    pub blocker: Option<ActivationBlocker>,
}
/// Local-only status cannot infer live component liveness from persisted plans.
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ComponentObservation {
    /// No current-session component observation has been performed.
    NotObserved,
}
/// Reads only local durable evidence; does not query trust or authorize a signer.
pub fn status(store: &RecoveryStore, id: B256) -> Result<RecoveryStatus, RecoveryCommandError> {
    let plan = store.load_plan(id)?;
    let witness = plan.validate()?;
    let checkpoint_slot =
        abci::l1::layout::inbox::slot(abci::l1::layout::inbox::LAST_CHECKPOINT_HEIGHT);
    let landed_height = witness
        .finalized_inbox
        .storage
        .iter()
        .find(|word| word.slot == checkpoint_slot)
        .ok_or(RecoveryCommandError::PlanMismatch)?
        .value
        .try_into()
        .map_err(|_| RecoveryCommandError::PlanMismatch)?;
    let journal = store.load_journal(id)?.unwrap_or_else(|| ActivationJournal::prepared(id));
    let phase = journal.phase;
    let observed = journal.progress.as_ref();
    Ok(RecoveryStatus {
        plan_id: id,
        generation: plan.origin.generation,
        origin_height: plan.origin.height,
        recovery_l1_block: plan.origin.l1_number,
        phase,
        landed_height: observed.map_or(landed_height, |p| p.landed_height),
        trust_target_height: observed.map_or(landed_height, |p| p.trust_target_height),
        component_state: ComponentObservation::NotObserved,
        committed_height: observed.and_then(|p| p.committed_height),
        prerequisites: plan.prerequisites,
        live_trust: false,
        last_observation: journal.progress,
        blocker: journal.blocker,
    })
}

/// Historical private runtime observations, never a reusable session/trust grant.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActivationProgress {
    /// Opaque exact private app session observed by the foreground controller.
    pub session_id: String,
    /// Ready at the instant of observation; offline readers must not treat it as live.
    pub trusted: bool,
    /// Actual new-generation committed height; None at logical origin c before first Commit.
    pub committed_height: Option<u64>,
    /// Latest authenticated checkpoint required by the observed session.
    pub trust_target_height: u64,
    /// Fresh own-finalized L1 checkpoint height.
    pub landed_height: u64,
    /// Own finalized L1 block authenticating the observed landing.
    pub finalized_l1_height: u64,
}
/// Closed set of sanitized wait reasons; contains no paths, argv, keys or RPC error text.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ActivationBlocker {
    /// Declared external services or surviving children still own their resources.
    ExternalOwner,
    /// Own L1/EL could not supply bounded authenticated evidence.
    EvidenceUnavailable,
    /// Private app control is unavailable or a session is still acquiring trust.
    WaitingForTrust,
    /// A safety halt must be investigated without clearing its evidence.
    SafetyHalt,
    /// A directly retained owned child exited unexpectedly.
    ComponentExited,
    /// Normal foreground cancellation finished ordered child shutdown.
    Stopped,
}

/// Exchange one bounded schema-two private control frame. Only a full-node controller may
/// request BeginSession; validator controllers use Observe so the guarded signer owns it.
pub async fn private_snapshot(
    path: &std::path::Path,
    begin: bool,
) -> Result<abci::app::trust::TrustSnapshot, RecoveryCommandError> {
    use std::os::unix::fs::{FileTypeExt, MetadataExt};
    use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};
    let metadata = std::fs::symlink_metadata(path)
        .map_err(|_| RecoveryCommandError::Runtime("private app control"))?;
    if !metadata.file_type().is_socket() ||
        metadata.mode() & 0o077 != 0 ||
        metadata.uid() != unsafe { libc::geteuid() }
    {
        return Err(RecoveryCommandError::Invalid)
    }
    tokio::time::timeout(std::time::Duration::from_secs(2), async {
        let mut stream = tokio::net::UnixStream::connect(path)
            .await
            .map_err(|_| RecoveryCommandError::Runtime("private app control"))?;
        let op = if begin { "begin_session" } else { "observe" };
        let request = format!("{{\"schema_version\":2,\"op\":\"{op}\"}}\n");
        stream
            .write_all(request.as_bytes())
            .await
            .map_err(|_| RecoveryCommandError::Runtime("private control request"))?;
        let mut bytes = Vec::new();
        BufReader::new(stream)
            .take(16 * 1024 + 1)
            .read_until(b'\n', &mut bytes)
            .await
            .map_err(|_| RecoveryCommandError::Runtime("private control response"))?;
        if bytes.len() > 16 * 1024 || bytes.last() != Some(&b'\n') {
            return Err(RecoveryCommandError::Invalid)
        }
        serde_json::from_slice(&bytes).map_err(|_| RecoveryCommandError::Invalid)
    })
    .await
    .map_err(|_| RecoveryCommandError::Runtime("private control deadline"))?
}

/// Record an exact private session observation; this never grants signature authorization.
pub(super) fn record_observation(
    plan: &super::plan::RecoveryPlan,
    journal: &mut super::status::ActivationJournal,
    snapshot: &abci::app::trust::TrustSnapshot,
    session: &str,
    landing: &FinalizedLanding,
) -> Result<(), RecoveryCommandError> {
    use super::status::{ActivationPhase, ActivationProgress};
    use abci::app::trust::{RecoveryTrustOrigin, TrustPhase};
    clear_observation(journal);
    if snapshot.schema_version != 2 || session.is_empty() || snapshot.session_id != session {
        return Err(RecoveryCommandError::Runtime("current private session"));
    }
    let o = &plan.origin;
    let params = plan.deployment.params()?;
    let chain =
        rules::chain_id_for(&params, o.generation).map_err(|_| RecoveryCommandError::Invalid)?;
    if snapshot.chain_id.as_ref().is_some_and(|id| id != &chain) ||
        snapshot.generation.is_some_and(|generation| generation != o.generation) ||
        snapshot.phase == TrustPhase::Halted
    {
        return Err(RecoveryCommandError::Invalid);
    }
    let expected = RecoveryTrustOrigin {
        generation: o.generation,
        height: o.height,
        l1_number: o.l1_number,
        l1_hash: plan.validate()?.recovery_header.hash(),
        l1_timestamp: o.l1_timestamp,
        el_hash: o.el_hash,
        comet_hash: o.comet_hash,
        forced_cursor: o.forced_cursor,
        committee_hash: o.committee.record.set_root,
    };
    if snapshot.recovery_origin.as_ref().is_some_and(|origin| origin != &expected) {
        return Err(RecoveryCommandError::Invalid);
    }
    if snapshot.chain_id.is_none() ||
        snapshot.generation.is_none() ||
        snapshot.recovery_origin.is_none()
    {
        return Err(RecoveryCommandError::Runtime("private initialization"));
    }
    let Some(target) = snapshot.target.as_ref() else {
        return Ok(());
    };
    let committed = snapshot.committed_head.as_ref();
    if target.generation != o.generation ||
        target.inbox != params.inbox ||
        committed.is_some_and(|head| {
            head.height < o.height || (head.height == o.height && head.hash != o.el_hash)
        })
    {
        return Err(RecoveryCommandError::Invalid);
    }
    let trusted = snapshot.trust_ready &&
        !snapshot.syncing &&
        snapshot.phase == TrustPhase::Ready &&
        snapshot.trusted_consensus_head == snapshot.committed_head &&
        committed.is_some_and(|head| head.height >= target.height) &&
        committed.is_some_and(|head| head.height >= landing.target.height) &&
        (target.height != landing.target.height ||
            (target.hash == landing.target.hash &&
                target.comet_hash == landing.target.comet_hash));
    journal.progress = Some(ActivationProgress {
        session_id: session.into(),
        trusted,
        committed_height: committed.filter(|head| head.height > o.height).map(|head| head.height),
        trust_target_height: target.height.max(landing.target.height),
        landed_height: landing.target.height,
        finalized_l1_height: landing.target.l1_number,
    });
    if trusted {
        journal.blocker = None;
        journal.phase =
            if landing.target.height > o.height && landing.landing_generation == o.generation {
                ActivationPhase::Settled
            } else {
                ActivationPhase::Trusted
            };
    }
    Ok(())
}

/// Close historical readiness before checking an observation or a transitioning incarnation.
fn clear_observation(journal: &mut ActivationJournal) {
    journal.phase = ActivationPhase::Running;
    journal.blocker = Some(ActivationBlocker::WaitingForTrust);
    if let Some(progress) = &mut journal.progress {
        progress.trusted = false;
    }
}

/// Require the same app boot and a nondecreasing canonical session counter.
/// A later signer session is only a candidate until its private incarnation also matches.
fn check_incarnation(previous: &str, current: &str) -> Result<(), RecoveryCommandError> {
    let parse = |session: &str| {
        let (boot, counter) =
            session.split_once(':').ok_or(RecoveryCommandError::SessionChanged)?;
        if boot.is_empty() || counter.is_empty() || !counter.bytes().all(|b| b.is_ascii_digit()) {
            return Err(RecoveryCommandError::SessionChanged)
        }
        let counter: u64 = counter.parse().map_err(|_| RecoveryCommandError::SessionChanged)?;
        Ok((boot.to_owned(), counter))
    };
    let (previous_boot, previous_counter) = parse(previous)?;
    let (boot, counter) = parse(current)?;
    if boot != previous_boot ||
        counter < previous_counter ||
        (counter == previous_counter && current != previous)
    {
        return Err(RecoveryCommandError::SessionChanged)
    }
    Ok(())
}

/// Stay in the foreground after settlement, polling retained children even during slow L1 reads.
pub(super) async fn monitor<L: abci::L1Source + ?Sized, E: Engine + ?Sized>(
    profile: &super::profile::RecoveryProfile,
    store: &super::store::RecoveryStore,
    plan: &super::plan::RecoveryPlan,
    l1: &L,
    engine: &E,
    runtime: &mut super::process::OwnedRuntime,
    journal: &mut super::status::ActivationJournal,
) -> Result<(), RecoveryCommandError> {
    use super::status::{ActivationBlocker, ActivationPhase};
    let app = store.plan_dir(plan.id()).join("app");
    let mut session = None;
    let mut tick = tokio::time::interval(Duration::from_millis(250));
    loop {
        check_current_halt(&app)?;
        // Immediately completed evidence failures must not starve child-exit checks.
        if runtime.exited_role()?.is_some() {
            return Err(RecoveryCommandError::ComponentExited)
        }
        let observed = {
            let round = observation_round(profile, store, plan, l1, engine, &mut session, journal);
            tokio::pin!(round);
            loop {
                tokio::select! {
                    result=&mut round=>break result,
                    _=tick.tick()=>{check_current_halt(&app)?;if runtime.exited_role()?.is_some(){break Err(RecoveryCommandError::ComponentExited)}},
                }
            }
        };
        if runtime.exited_role()?.is_some() {
            return Err(RecoveryCommandError::ComponentExited)
        }
        check_current_halt(&app)?;
        match observed {
            Ok(()) => {}
            Err(RecoveryCommandError::Runtime(_) | RecoveryCommandError::Missing(_)) => {
                journal.phase = ActivationPhase::Running;
                journal.blocker = Some(ActivationBlocker::WaitingForTrust);
                if let Some(progress) = &mut journal.progress {
                    progress.trusted = false;
                }
            }
            Err(error) => return Err(error),
        }
        store.save_journal(journal)?;
        // Settlement is an observation, not permission to abandon owned child supervision.
        tick.tick().await;
    }
}

/// Any current-generation terminal record closes observation; historical supersession is
/// evaluated separately during activation. Unreadable/aliased paths cannot prove absence.
fn check_current_halt(app: &std::path::Path) -> Result<(), RecoveryCommandError> {
    for name in [
        "fatal-evidence.txt",
        "validator-supervisor.halted",
        abci::recovery::supersession::SUPERSESSION_FILE,
    ] {
        if !std::fs::symlink_metadata(app.join(name))
            .is_err_and(|error| error.kind() == std::io::ErrorKind::NotFound)
        {
            return Err(RecoveryCommandError::Halted);
        }
    }
    Ok(())
}

/// One private incarnation and independent finalized-landing/canonical-chain observation.
pub(super) async fn observation_round<L: abci::L1Source + ?Sized, E: Engine + ?Sized>(
    profile: &super::profile::RecoveryProfile,
    store: &super::store::RecoveryStore,
    plan: &super::plan::RecoveryPlan,
    l1: &L,
    engine: &E,
    session: &mut Option<String>,
    journal: &mut super::status::ActivationJournal,
) -> Result<(), RecoveryCommandError> {
    clear_observation(journal);
    let landing = finalized_landing(l1, plan).await?;
    let app = store.plan_dir(plan.id()).join("app");
    let control = app.join("checkpoint-trust.sock");
    let snapshot = super::status::private_snapshot(&control, false).await?;
    // Validate exact identity without publishing readiness before incarnation correlation.
    let mut checked = ActivationJournal::prepared(plan.id());
    record_observation(plan, &mut checked, &snapshot, &snapshot.session_id, &landing)?;
    check_incarnation(&snapshot.session_id, &snapshot.session_id)?;
    if session.is_none() {
        if snapshot.generation.is_some_and(|g| g != plan.origin.generation) {
            return Err(RecoveryCommandError::Invalid)
        }
        if snapshot.generation.is_none() || snapshot.recovery_origin.is_none() {
            return Err(RecoveryCommandError::Runtime("authenticated InitChain"))
        }
        if profile.signer.is_some() {
            let signer = signer_session(&app)?;
            if signer != snapshot.session_id {
                return Err(RecoveryCommandError::Runtime("guarded signer session"))
            }
            *session = Some(signer);
        } else {
            // Full nodes have no guarded signer. Only this controller rearms their own session,
            // after InitChain has established the authenticated immutable recovery identity.
            let fresh = super::status::private_snapshot(&control, true).await?;
            if fresh.generation != snapshot.generation ||
                fresh.chain_id != snapshot.chain_id ||
                fresh.recovery_origin != snapshot.recovery_origin ||
                fresh.phase == abci::app::trust::TrustPhase::Halted ||
                fresh.session_id.split(':').next() != snapshot.session_id.split(':').next()
            {
                return Err(RecoveryCommandError::SessionChanged)
            }
            *session = Some(fresh.session_id);
            return Err(RecoveryCommandError::Runtime("fresh full-node session"))
        }
    }
    let expected = session.as_deref().ok_or(RecoveryCommandError::Runtime("private session"))?;
    check_incarnation(expected, &snapshot.session_id)?;
    if profile.signer.is_some() {
        // The owned supervisor may replace its signer after a refusal. The controller only
        // observes the matching private incarnation; publication races remain closed waiting.
        let signer = signer_session(&app)?;
        check_incarnation(expected, &signer)?;
        if signer != snapshot.session_id {
            return Err(RecoveryCommandError::Runtime("guarded signer session publication"))
        }
        if snapshot.session_id != expected {
            *session = Some(signer);
            journal.progress = None;
            return Err(RecoveryCommandError::Runtime("fresh guarded signer session"))
        }
    } else if snapshot.session_id != expected {
        return Err(RecoveryCommandError::SessionChanged)
    }
    if let Some(head) = snapshot.committed_head.as_ref().filter(|h| h.height > plan.origin.height) {
        verify_committed(engine, plan, head.height, head.hash).await?;
        if landing.target.height > plan.origin.height && head.height >= landing.target.height {
            verify_committed(engine, plan, landing.target.height, landing.target.hash).await?;
            let comet = abci::Store::new(app.clone())
                .load_comet_hash(landing.target.height)
                .map_err(|_| RecoveryCommandError::Invalid)?
                .ok_or(RecoveryCommandError::Runtime("committed landing Comet history"))?;
            if comet != landing.target.comet_hash {
                return Err(RecoveryCommandError::Invalid)
            }
        }
    }
    // Slow L1/EL reads or atomic signer publication must not publish an old Ready snapshot.
    let current = private_snapshot(&control, false).await?;
    record_observation(plan, &mut checked, &current, &current.session_id, &landing)?;
    check_incarnation(expected, &current.session_id)?;
    if current.session_id != expected && profile.signer.is_none() {
        return Err(RecoveryCommandError::SessionChanged)
    }
    if current != snapshot || (profile.signer.is_some() && signer_session(&app)? != expected) {
        return Err(RecoveryCommandError::Runtime("private observation changed"))
    }
    check_current_halt(&app)?;
    record_observation(plan, journal, &snapshot, expected, &landing)
}

/// Read the guarded signer's private sequence-zero/current incarnation record, never rearm it.
fn signer_session(app: &std::path::Path) -> Result<String, RecoveryCommandError> {
    let path = app.join("signer-denial.json");
    super::store::check_private_file(&path)
        .map_err(|_| RecoveryCommandError::Runtime("signer incarnation"))?;
    let event: serde_json::Value =
        serde_json::from_slice(&super::store::read_bounded(&path, 16 * 1024)?)
            .map_err(|_| RecoveryCommandError::Invalid)?;
    if event.get("sequence").and_then(serde_json::Value::as_u64).is_none() {
        return Err(RecoveryCommandError::Invalid)
    }
    event
        .get("session_id")
        .and_then(serde_json::Value::as_str)
        .filter(|s| !s.is_empty())
        .map(str::to_owned)
        .ok_or(RecoveryCommandError::Invalid)
}
