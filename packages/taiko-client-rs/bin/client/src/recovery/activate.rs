//! Foreground recovery activation; persisted phases never authorize signing.
use super::{RecoveryCommandError, status::monitor};
use abci::{
    ChainParams, Engine,
    recovery::RecoveryOrigin,
    rules::{self, HeaderInputs},
    types::{AnchorState, ParentInfo},
};
use alloy_primitives::Bytes;
use std::time::Duration;

/// Deadline for a complete stateful probe, including preliminary canonical/finality reads.
const PROBE_TIMEOUT: Duration = Duration::from_secs(30);

/// Proves usable origin state with an unpromoted empty candidate and normal expected header.
/// Caller must fence every writer first and authenticate the R-or-later anchor. An empty
/// provided transaction list selects the EL's given-list builder; it makes no FI/consensus
/// validity claim, consumes no cursor and is never passed to newPayload or promoted.
pub async fn probe_recovery_state<E: Engine + ?Sized>(
    engine: &E,
    params: &ChainParams,
    origin: &RecoveryOrigin,
    parent: &ParentInfo,
    anchor: &AnchorState,
) -> Result<(), RecoveryCommandError> {
    if parent.number != origin.height ||
        parent.hash != origin.el_hash ||
        anchor.number < origin.l1_number ||
        anchor.inbox.recovery_generation != origin.generation
    {
        return Err(RecoveryCommandError::Invalid);
    }
    tokio::time::timeout(PROBE_TIMEOUT, async {
        let header = engine
            .header_by_number(origin.height)
            .await
            .map_err(engine_error)?
            .ok_or(RecoveryCommandError::Missing("EL origin header"))?;
        if header.hash_slow() != origin.el_hash || header.state_root != origin.state_root {
            return Err(RecoveryCommandError::Invalid);
        }
        let finalized = engine
            .finalized_header()
            .await
            .map_err(engine_error)?
            .ok_or(RecoveryCommandError::Missing("EL finalized header"))?;
        if finalized.number > origin.height ||
            engine
                .header_by_number(finalized.number)
                .await
                .map_err(engine_error)?
                .is_none_or(|h| h.hash_slow() != finalized.hash_slow())
        {
            return Err(RecoveryCommandError::Invalid);
        }
        if !engine.historical_state_available(origin.el_hash).await.map_err(engine_error)? {
            return Err(RecoveryCommandError::Missing("usable origin state"));
        }
        let expected = rules::expected_header(&HeaderInputs {
            height: origin.height.checked_add(1).ok_or(RecoveryCommandError::Invalid)?,
            parent,
            anchor,
            bft_time_secs: anchor.timestamp,
            generation: origin.generation,
            beneficiary: params.fee_recipient,
            params,
            min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(params.l2_chain_id),
        })
        .map_err(|_| RecoveryCommandError::Invalid)?;
        let attributes =
            rules::payload_attributes(&expected, anchor.hash, Some(Bytes::from_static(&[0xc0])));
        let candidate =
            engine.build_block(origin.el_hash, attributes).await.map_err(engine_error)?;
        rules::check_header(&candidate.header, &expected)
            .map_err(|_| RecoveryCommandError::Invalid)?;
        if !candidate.transactions.is_empty() {
            return Err(RecoveryCommandError::Invalid);
        }
        Ok(())
    })
    .await
    .map_err(|_| RecoveryCommandError::Runtime("EL origin probe deadline"))?
}

/// Preserve integrity classification without exposing provider diagnostics or credentials.
fn engine_error(error: abci::EngineError) -> RecoveryCommandError {
    if error.is_integrity_failure() || !error.is_retryable_build() {
        RecoveryCommandError::Invalid
    } else {
        RecoveryCommandError::Runtime("EL origin probe")
    }
}

/// Authenticated own-finalized landing, acquired independently of the activation journal.
pub(super) struct FinalizedLanding {
    /// Own finalized L1 target proof and its exact checkpoint hashes.
    pub target: abci::app::trust::CheckpointTarget,
    /// Generation recorded in the checkpoint's landing mapping, distinct from current domain.
    pub landing_generation: u64,
}
/// Authenticate before and after reserving every declared original and selected runtime writer.
/// Existing owners are never adopted or killed; all surviving children retain the reservations.
pub(super) async fn isolate<L: abci::L1Source + ?Sized>(
    profile: &super::profile::RecoveryProfile,
    root: &std::path::Path,
    plan: &super::plan::RecoveryPlan,
    l1: &L,
) -> Result<super::process::OwnedRuntime, RecoveryCommandError> {
    use super::{process::OwnedRuntime, store::RecoveryStore};
    profile.validate()?;
    profile.validate_root(root)?;
    let store = RecoveryStore::new(root);
    if store.load_plan(plan.id())? != *plan || profile.digest() != plan.profile_digest {
        return Err(RecoveryCommandError::PlanMismatch);
    }
    revalidate(plan, l1).await?;
    let lease = abci::ownership::acquire_activation(root, plan.id())
        .map_err(|_| RecoveryCommandError::Busy)?;
    let mut runtime = OwnedRuntime::new(lease);
    let result = async {
        let installed = super::install::binding(profile, plan.id())?;
        super::install::reserve(&installed)?;
        runtime.fence(
            &abci::ownership::ComponentPaths::new(comet_role(profile), &installed.home)
                .map_err(|_| RecoveryCommandError::Busy)?,
        )?;
        fence_profile(&mut runtime, profile, &store.plan_dir(plan.id()))?;
        if let Some(active) = store.load_active()? &&
            active.plan_id != plan.id()
        {
            if active.generation >= plan.origin.generation {
                return Err(RecoveryCommandError::PlanMismatch);
            }
            let previous = store.load_profile(active.plan_id)?;
            runtime.fence(
                &abci::ownership::ComponentPaths::new(
                    comet_role(&previous),
                    &active.installation.home,
                )
                .map_err(|_| RecoveryCommandError::Busy)?,
            )?;
            fence_profile(&mut runtime, &previous, &store.plan_dir(active.plan_id))?;
        }
        // No persisted phase, descriptor or lock acquisition replaces this fresh own-L1 check.
        revalidate(plan, l1).await
    }
    .await;
    if let Err(error) = result {
        runtime.stop().await?;
        return Err(error);
    }
    Ok(runtime)
}

/// Reserve all original and selected component directories before the first Engine write.
fn fence_profile(
    runtime: &mut super::process::OwnedRuntime,
    profile: &super::profile::RecoveryProfile,
    bundle: &std::path::Path,
) -> Result<(), RecoveryCommandError> {
    use abci::ownership::{ComponentPaths, ComponentRole};
    let comet =
        if profile.signer.is_some() { ComponentRole::Supervisor } else { ComponentRole::Comet };
    for (role, path) in [
        (ComponentRole::App, profile.app_data_dir.clone()),
        (comet, profile.comet_home.clone()),
        (ComponentRole::App, bundle.join("app")),
        (comet, bundle.join("comet")),
    ] {
        runtime
            .fence(&ComponentPaths::new(role, &path).map_err(|_| RecoveryCommandError::Busy)?)?;
    }
    if let Some(lander) = &profile.lander {
        runtime.fence(
            &ComponentPaths::new(ComponentRole::Lander, &lander.data_dir)
                .map_err(|_| RecoveryCommandError::Busy)?,
        )?;
    }
    Ok(())
}

/// Bounded reauthentication of immutable c/R and the currently finalized governance domain.
async fn revalidate<L: abci::L1Source + ?Sized>(
    plan: &super::plan::RecoveryPlan,
    l1: &L,
) -> Result<(), RecoveryCommandError> {
    tokio::time::timeout(
        Duration::from_secs(120),
        abci::recovery::check_recovery_canonicality(
            l1,
            &plan.deployment.params()?,
            &plan.validate()?,
        ),
    )
    .await
    .map_err(|_| RecoveryCommandError::Runtime("recovery reauthentication deadline"))??;
    Ok(())
}

/// Acquire and authenticate the latest landing against this node's own finalized L1.
pub(super) async fn finalized_landing<L: abci::L1Source + ?Sized>(
    l1: &L,
    plan: &super::plan::RecoveryPlan,
) -> Result<FinalizedLanding, RecoveryCommandError> {
    use abci::l1::{
        layout::{inbox, word_u48},
        mpt::verify_account_witness,
    };
    use alloy_primitives::{B256, U256};
    let params = plan.deployment.params()?;
    tokio::time::timeout(Duration::from_secs(120), async {
        let number = l1.finalized_number().await.map_err(l1_error)?;
        if number < plan.origin.l1_number {
            return Err(RecoveryCommandError::Runtime("recovery not finalized"));
        }
        let header = l1.header(number).await.map_err(l1_error)?;
        if header.number() != number {
            return Err(RecoveryCommandError::Invalid);
        }
        let anchor = abci::l1::verify_anchor_witness(
            &abci::AnchorWitness {
                l1_header: header.clone(),
                inbox: l1
                    .account_witness(params.inbox, &inbox::anchor_slots(), number)
                    .await
                    .map_err(l1_error)?,
            },
            params.inbox,
        )
        .map_err(|_| RecoveryCommandError::Invalid)?;
        let facts = &anchor.inbox;
        if facts.recovery_generation > plan.origin.generation {
            return Err(RecoveryCommandError::Superseded {
                requested: plan.origin.generation,
                current: facts.recovery_generation,
            });
        }
        if facts.recovery_generation != plan.origin.generation ||
            facts.last_checkpoint_height < plan.origin.height
        {
            return Err(RecoveryCommandError::Invalid);
        }
        let slots = inbox::landing_slots(facts.last_checkpoint_height);
        let proof = l1.account_witness(params.inbox, &slots, number).await.map_err(l1_error)?;
        if proof.address != params.inbox {
            return Err(RecoveryCommandError::Invalid);
        }
        let words = verify_account_witness(header.state_root(), &proof, &slots)
            .map_err(|_| RecoveryCommandError::Invalid)?;
        let packed = words.get(slots[0]).ok_or(RecoveryCommandError::Invalid)?;
        let hash = B256::from(words.get(slots[1]).ok_or(RecoveryCommandError::Invalid)?);
        let comet_hash = B256::from(words.get(slots[2]).ok_or(RecoveryCommandError::Invalid)?);
        let val_state_hash = B256::from(words.get(slots[3]).ok_or(RecoveryCommandError::Invalid)?);
        let landing_generation = word_u48(packed, 48);
        let parent = word_u48(packed, 0);
        let o = &plan.origin;
        let retained = facts.last_checkpoint_height == o.height &&
            hash == o.el_hash &&
            comet_hash == o.comet_hash &&
            val_state_hash == o.val_state_hash &&
            word_u48(packed, 96) == o.forced_cursor &&
            landing_generation < o.generation;
        if hash != facts.last_checkpoint_hash ||
            hash.is_zero() ||
            packed >> 144 != U256::ZERO ||
            word_u48(packed, 96) != facts.forced_inclusion_head ||
            (landing_generation != o.generation && !retained) ||
            (facts.last_checkpoint_height == 0 &&
                (parent != 0 || !comet_hash.is_zero() || !val_state_hash.is_zero())) ||
            (facts.last_checkpoint_height > 0 &&
                (parent >= facts.last_checkpoint_height || comet_hash.is_zero()))
        {
            return Err(RecoveryCommandError::Invalid);
        }
        if l1.canonical_hash(number).await.map_err(l1_error)? != header.hash() {
            return Err(RecoveryCommandError::Invalid);
        }
        if l1.finalized_number().await.map_err(l1_error)? < number {
            return Err(RecoveryCommandError::Runtime("own finality regressed"));
        }
        Ok(FinalizedLanding {
            landing_generation,
            target: abci::app::trust::CheckpointTarget {
                l1_number: number,
                l1_hash: header.hash(),
                height: facts.last_checkpoint_height,
                hash,
                comet_hash,
                val_state_hash,
                generation: facts.recovery_generation,
                inbox: params.inbox,
            },
        })
    })
    .await
    .map_err(|_| RecoveryCommandError::Runtime("finalized landing deadline"))?
}

/// Preserve source integrity failures while redacting unavailable provider details.
fn l1_error(error: abci::L1Error) -> RecoveryCommandError {
    if error.is_integrity_failure() {
        RecoveryCommandError::Invalid
    } else {
        RecoveryCommandError::Runtime("own finalized L1 evidence")
    }
}

/// Role of the locally supervised stock consensus subtree.
fn comet_role(profile: &super::profile::RecoveryProfile) -> abci::ownership::ComponentRole {
    if profile.signer.is_some() {
        abci::ownership::ComponentRole::Supervisor
    } else {
        abci::ownership::ComponentRole::Comet
    }
}

/// Exact supervisor reference to a typed first-cause app sidecar; plain legacy text is blocked.
#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
struct SupersessionLatch {
    /// Supported structured terminal record schema.
    schema: u32,
    /// Only expected-generation-supersession is automatically acknowledgeable.
    kind: String,
    /// Exact previous app/signing domain.
    chain_id: String,
    /// Previous authenticated app generation.
    previous_generation: u64,
    /// Higher generation observed by the stopped old app.
    current_generation: u64,
    /// SHA-256 of the exact typed sidecar bytes.
    evidence_digest: String,
}
/// Preserve every prior safety record; acknowledge only a hash-bound first-cause supersession
/// after the caller independently authenticated the exact current plan against own finalized L1.
/// Earlier sole-cause supersessions remain valid history across subsequent authenticated
/// recoveries; the evidence must strictly advance its old domain without exceeding the current
/// generation.
pub(super) fn check_prior_halt(
    directory: &std::path::Path,
    plan: &super::plan::RecoveryPlan,
) -> Result<(), RecoveryCommandError> {
    use super::store::{MAX_PLAN_BYTES, read_bounded};
    use abci::recovery::supersession::{SUPERSESSION_FILE, SupersessionEvidence, digest};
    let fatal = directory.join("fatal-evidence.txt");
    let evidence = directory.join(SUPERSESSION_FILE);
    let latch = directory.join("validator-supervisor.halted");
    if [&fatal, &evidence, &latch].iter().all(|p| {
        std::fs::symlink_metadata(p).is_err_and(|e| e.kind() == std::io::ErrorKind::NotFound)
    }) {
        return Ok(())
    }
    let result = (|| {
        let fatal_bytes = read_bounded(&fatal, 1024 * 1024)?;
        let evidence_bytes = read_bounded(&evidence, 1024 * 1024)?;
        let evidence: SupersessionEvidence =
            serde_json::from_slice(&evidence_bytes).map_err(|_| RecoveryCommandError::Halted)?;
        let state = read_bounded(&directory.join(abci::store::STATE_FILE), MAX_PLAN_BYTES)?;
        let chain = rules::chain_id_for(&plan.deployment.params()?, evidence.previous_generation)
            .map_err(|_| RecoveryCommandError::Halted)?;
        if !evidence.validates(&state, &fatal_bytes) ||
            evidence.current_generation > plan.origin.generation ||
            evidence.chain_id != chain ||
            evidence.inbox != plan.deployment.inbox
        {
            return Err(RecoveryCommandError::Halted)
        }
        if std::fs::symlink_metadata(&latch).is_ok() {
            let latch: SupersessionLatch =
                serde_json::from_slice(&read_bounded(&latch, 1024 * 1024)?)
                    .map_err(|_| RecoveryCommandError::Halted)?;
            if latch.schema != 1 ||
                latch.kind != "expected-generation-supersession" ||
                latch.chain_id != chain ||
                latch.previous_generation != evidence.previous_generation ||
                latch.current_generation != evidence.current_generation ||
                latch.evidence_digest != digest(&evidence_bytes)
            {
                return Err(RecoveryCommandError::Halted)
            }
        }
        Ok(())
    })();
    result.map_err(|_| RecoveryCommandError::Halted)
}

/// Activate an exact authenticated plan in the foreground until cancellation or a safety stop.
/// Signal handling owns ordered shutdown; the runtime and its leases never become detached.
pub async fn activate(
    profile: super::profile::RecoveryProfile,
    root: std::path::PathBuf,
    plan_id: alloy_primitives::B256,
) -> Result<(), RecoveryCommandError> {
    use tokio::signal::unix::{SignalKind, signal};
    let mut interrupt = signal(SignalKind::interrupt())
        .map_err(|_| RecoveryCommandError::Runtime("SIGINT handler"))?;
    let mut terminate = signal(SignalKind::terminate())
        .map_err(|_| RecoveryCommandError::Runtime("SIGTERM handler"))?;
    let store = super::store::RecoveryStore::new(&root);
    let plan = store.load_plan(plan_id)?;
    if profile.digest() != plan.profile_digest {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    let l1_url = profile.l1_http.parse().map_err(|_| RecoveryCommandError::Parse("L1 endpoint"))?;
    let l2_url = profile.l2_http.parse().map_err(|_| RecoveryCommandError::Parse("EL endpoint"))?;
    let chain = async {
        let l1 = crate::commands::rpc_chain_id(&l1_url, "l1.http")
            .await
            .map_err(|_| RecoveryCommandError::Runtime("L1 identity"))?;
        let l2 = crate::commands::rpc_chain_id(&l2_url, "l2.http")
            .await
            .map_err(|_| RecoveryCommandError::Runtime("EL identity"))?;
        if l1 != profile.l1_chain_id || l2 != alloy_primitives::U256::from(profile.l2_chain_id) {
            return Err(RecoveryCommandError::ConfigMismatch)
        }
        Ok(())
    };
    tokio::select! {result=chain=>result?,_=interrupt.recv()=>return Ok(()),_=terminate.recv()=>return Ok(())}
    let l1 = abci::RpcL1Source::new(rpc::client::connect_http_with_timeout(
        l1_url,
        rpc::client::DEFAULT_HTTP_TIMEOUT,
    ));
    let engine = abci::RpcEngine::new(
        l2_url,
        profile.l2_auth.parse().map_err(|_| RecoveryCommandError::Parse("Engine endpoint"))?,
        &profile.jwt_secret,
        rpc::client::DEFAULT_HTTP_TIMEOUT,
    )
    .map_err(|_| RecoveryCommandError::Missing("EL JWT configuration"))?;
    activate_with(profile, root, plan_id, &l1, &engine, async {
        tokio::select! {_=interrupt.recv()=>{},_=terminate.recv()=>{}}
    })
    .await
}

/// Injectable read sources and cancellation for native orchestration tests; all real ownership,
/// durable phases, store inspection, child launches and monitor operations remain production.
pub(super) async fn activate_with<L: abci::L1Source + ?Sized, E: Engine + ?Sized>(
    profile: super::profile::RecoveryProfile,
    root: std::path::PathBuf,
    id: alloy_primitives::B256,
    l1: &L,
    engine: &E,
    cancel: impl std::future::Future<Output = ()>,
) -> Result<(), RecoveryCommandError> {
    use super::{
        status::{ActivationBlocker, ActivationJournal},
        store::RecoveryStore,
    };
    let store = RecoveryStore::new(&root);
    let plan = store.load_plan(id)?;
    let mut journal = store.load_journal(id)?.unwrap_or_else(|| ActivationJournal::prepared(id));
    let mut runtime = None;
    let outcome = tokio::select! {
        result=run_activation(&profile,&root,&plan,l1,engine,&mut runtime,&mut journal)=>result,
        _=cancel=>Ok(()),
    };
    if let Some(runtime) = runtime.as_mut() {
        let stopped = runtime.quiesce().await;
        journal.blocker = Some(match (&outcome, &stopped) {
            (_, Err(_)) => ActivationBlocker::ExternalOwner,
            (Ok(()), _) => ActivationBlocker::Stopped,
            (Err(RecoveryCommandError::ComponentExited), _) => ActivationBlocker::ComponentExited,
            (
                Err(
                    RecoveryCommandError::Invalid |
                    RecoveryCommandError::Halted |
                    RecoveryCommandError::SessionChanged |
                    RecoveryCommandError::PlanMismatch |
                    RecoveryCommandError::Superseded { .. },
                ),
                _,
            ) => ActivationBlocker::SafetyHalt,
            _ => journal.blocker.unwrap_or(ActivationBlocker::EvidenceUnavailable),
        });
        if let Some(progress) = &mut journal.progress {
            progress.trusted = false;
        }
        // Locks remain held through this final write, including uncertain-descendant failure.
        let saved = store.save_journal(&journal);
        stopped?;
        let released = runtime.stop().await;
        saved?;
        released?;
    }
    outcome
}

/// Ordered activation after every retry, with phases recorded only after their actual effects.
async fn run_activation<L: abci::L1Source + ?Sized, E: Engine + ?Sized>(
    profile: &super::profile::RecoveryProfile,
    root: &std::path::Path,
    plan: &super::plan::RecoveryPlan,
    l1: &L,
    engine: &E,
    owned: &mut Option<super::process::OwnedRuntime>,
    journal: &mut super::status::ActivationJournal,
) -> Result<(), RecoveryCommandError> {
    use super::{
        inspect, install, process,
        status::{ActivationBlocker, ActivationPhase},
        store::{ActiveDescriptor, RecoveryStore},
    };
    let store = RecoveryStore::new(root);
    let inspector = profile
        .inspector
        .as_ref()
        .ok_or(RecoveryCommandError::Missing("explicit pinned read-only Comet inspector"))?;
    for name in
        ["comet/config/config.toml", "comet/config/genesis.json", "comet/config/node_key.json"]
    {
        if !plan.artifacts.contains_key(name) {
            return Err(RecoveryCommandError::Missing(
                "immutable Comet prerequisites; prepare again",
            ))
        }
    }
    process::validated_template(profile, &store, plan)?;
    if store.plan_dir(plan.id()).join("app/checkpoint-trust.sock").as_os_str().len() > 103 {
        return Err(RecoveryCommandError::Missing("shorter private recovery root"))
    }
    let installed = install::binding(profile, plan.id())?;
    *owned = Some(isolate(profile, root, plan, l1).await?);
    let runtime = owned.as_mut().ok_or(RecoveryCommandError::Busy)?;
    let prior_phase = journal.phase;
    let active = store.load_active()?;
    if active.as_ref().is_some_and(|a| a.plan_id == plan.id() && a.installation != installed) {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    if matches!(
        prior_phase,
        ActivationPhase::Installed |
            ActivationPhase::Running |
            ActivationPhase::Trusted |
            ActivationPhase::Settled
    ) && active.as_ref().is_none_or(|a| a.plan_id != plan.id())
    {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    journal.phase = ActivationPhase::Stopping;
    journal.blocker = None;
    store.save_journal(journal)?;
    let bundle = store.plan_dir(plan.id());
    let mut apps = vec![profile.app_data_dir.clone(), bundle.join("app")];
    let mut homes = vec![profile.comet_home.clone(), installed.home.clone()];
    if let Some(previous) = active.as_ref().filter(|a| a.plan_id != plan.id()) {
        let old = store.load_profile(previous.plan_id)?;
        let old_apps = vec![old.app_data_dir.clone(), store.plan_dir(previous.plan_id).join("app")];
        let old_homes = vec![old.comet_home.clone(), previous.installation.home.clone()];
        process::legacy_quiescent(&old, &old_homes, &old_apps).await?;
        apps.extend(old_apps);
        homes.extend(old_homes);
    }
    process::legacy_quiescent(profile, &homes, &apps).await?;
    for app in &apps {
        check_prior_halt(app, plan)?;
    }
    journal.phase = ActivationPhase::Isolated;
    store.save_journal(journal)?;
    // Reject unsupported templates before the first stateful Engine call.
    let specifications = process::specifications(profile, &store, plan, &installed)?;
    let report = inspect::inspect(inspector, &installed).await?;
    let state = inspect::validate_stores(&store, plan, &report)?;
    if active.as_ref().is_none_or(|a| a.plan_id != plan.id()) &&
        (state.is_some() ||
            !report.empty ||
            std::fs::read_dir(bundle.join("app"))
                .map_err(|_| RecoveryCommandError::Io("inspect fresh app"))?
                .next()
                .is_some())
    {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    if matches!(prior_phase, ActivationPhase::Trusted | ActivationPhase::Settled) && state.is_none()
    {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    if prior_phase == ActivationPhase::Settled &&
        state.as_ref().is_none_or(|s| s.last_height <= plan.origin.height)
    {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    if let Some(state) = state.as_ref().filter(|s| s.has_generation_commit()) {
        // Genuine recovered progress is resumed, never replaced by an origin rewind/probe.
        verify_committed(engine, plan, state.last_height, state.parent.hash).await?;
        let finalized = engine
            .finalized_header()
            .await
            .map_err(engine_error)?
            .ok_or(RecoveryCommandError::Missing("EL finalized header"))?;
        if finalized.number > state.last_height ||
            engine
                .header_by_number(finalized.number)
                .await
                .map_err(engine_error)?
                .is_none_or(|h| h.hash_slow() != finalized.hash_slow())
        {
            return Err(RecoveryCommandError::Invalid)
        }
    } else {
        let witness = plan.validate()?;
        let anchor = abci::l1::verify_anchor_witness(
            &abci::AnchorWitness {
                l1_header: witness.recovery_header.clone(),
                inbox: l1
                    .account_witness(
                        plan.deployment.inbox,
                        &abci::l1::layout::inbox::anchor_slots(),
                        plan.origin.l1_number,
                    )
                    .await
                    .map_err(l1_error)?,
            },
            plan.deployment.inbox,
        )
        .map_err(|_| RecoveryCommandError::Invalid)?;
        probe_recovery_state(
            engine,
            &plan.deployment.params()?,
            &plan.origin,
            &abci::recovery::recovery_parent(&witness),
            &anchor,
        )
        .await?;
    }
    journal.phase = ActivationPhase::ElOriginReady;
    store.save_journal(journal)?;
    revalidate(plan, l1).await?;
    install::install(&store, plan, &installed)?;
    let descriptor = ActiveDescriptor::for_plan(plan, installed.clone());
    store.publish_active(&descriptor, active.as_ref())?;
    journal.active = Some(descriptor);
    journal.phase = ActivationPhase::Installed;
    store.save_journal(journal)?;
    journal.components.clear();
    journal.progress = None;
    for spec in &specifications {
        runtime.spawn(spec.paths.role, spec)?;
        journal.components.push(spec.paths.role.tag().into());
    }
    journal.phase = ActivationPhase::Running;
    journal.blocker = Some(ActivationBlocker::WaitingForTrust);
    store.save_journal(journal)?;
    monitor(profile, &store, plan, l1, engine, runtime, journal).await
}

/// Verify actual canonical new-generation EL progress, never an old precommit head above c.
pub(super) async fn verify_committed<E: Engine + ?Sized>(
    engine: &E,
    plan: &super::plan::RecoveryPlan,
    height: u64,
    hash: alloy_primitives::B256,
) -> Result<(), RecoveryCommandError> {
    let header = engine
        .header_by_number(height)
        .await
        .map_err(engine_error)?
        .ok_or(RecoveryCommandError::Runtime("committed EL header"))?;
    let origin = engine
        .header_by_number(plan.origin.height)
        .await
        .map_err(engine_error)?
        .ok_or(RecoveryCommandError::Runtime("committed EL ancestry"))?;
    if origin.hash_slow() != plan.origin.el_hash ||
        header.hash_slow() != hash ||
        height <= plan.origin.height ||
        rules::decode_extra_data(&header.extra_data)
            .map_err(|_| RecoveryCommandError::Invalid)?
            .1 !=
            plan.origin.generation
    {
        return Err(RecoveryCommandError::Invalid)
    }
    Ok(())
}
