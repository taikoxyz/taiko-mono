//! Read-only stock Comet metadata and app/bootstrap consistency at supported crash boundaries.
use super::{
    RecoveryCommandError,
    install::InstalledComet,
    plan::RecoveryPlan,
    profile::Executable,
    store::{MAX_PLAN_BYTES, RecoveryStore, read_bounded},
};
use alloy_primitives::{B256, Bytes};
use serde::Deserialize;

/// Bounded schema-one output of the pinned stock-library inspector.
#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Inspection {
    /// Supported helper output schema.
    pub schema: u32,
    /// No decoded Comet state or stored block exists.
    pub empty: bool,
    /// Stored consensus deployment identity.
    pub chain_id: String,
    /// Fixed first generation height c+1.
    pub initial_height: u64,
    /// Stock committed state height, zero before its first block.
    pub state_height: u64,
    /// Stock state's committed ABCI app hash.
    pub state_app_hash: B256,
    /// Stock state's last block ID hash.
    pub state_comet_hash: B256,
    /// Highest block durably stored, at most one ahead of state.
    pub blockstore_height: u64,
    /// Validator set for the next consensus block.
    pub validators_hash: B256,
    /// Validator set for the following consensus block.
    pub next_validators_hash: B256,
    /// Current/next native blocks relevant to replay; no WAL parsing.
    pub blocks: Vec<StoredBlock>,
}
/// Relevant native block fields decoded by stock Comet types.
#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StoredBlock {
    /// Native consensus block number.
    pub height: u64,
    /// Native block's full chain ID.
    pub chain_id: String,
    /// Stock block hash, checked against blockstore metadata.
    pub hash: B256,
    /// Parent ABCI app hash carried by this block's header.
    pub app_hash: B256,
    /// Previous native block ID, zero for the first generation block.
    pub parent_hash: B256,
    /// Raw consensus transactions containing the Etna envelope.
    pub transactions: Vec<Bytes>,
}
/// Two stock maximum-size 22,020,096-byte blocks, hex encoded, plus JSON metadata headroom.
const INSPECTION_LIMIT: usize = 4 * 22_020_096 + 64 * 1024;

/// Invoke the explicitly configured read-only helper with bounded output and cancellation.
pub async fn inspect(
    executable: &Executable,
    installed: &InstalledComet,
) -> Result<Inspection, RecoveryCommandError> {
    use tokio::io::AsyncReadExt;
    let mut child = tokio::process::Command::new(&executable.program)
        .args(&executable.argv)
        .envs(&executable.env)
        .args(["--home"])
        .arg(&installed.home)
        .args(["--backend", "goleveldb"])
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .kill_on_drop(true)
        .spawn()
        .map_err(|_| RecoveryCommandError::Missing("pinned Comet inspector"))?;

    tokio::time::timeout(std::time::Duration::from_secs(10), async {
        let mut output = Vec::new();
        child
            .stdout
            .take()
            .ok_or(RecoveryCommandError::Runtime("inspector stdout"))?
            .take(INSPECTION_LIMIT as u64 + 1)
            .read_to_end(&mut output)
            .await
            .map_err(|_| RecoveryCommandError::Runtime("inspector read"))?;
        if output.len() > INSPECTION_LIMIT {
            return Err(RecoveryCommandError::Invalid)
        }
        if !child
            .wait()
            .await
            .map_err(|_| RecoveryCommandError::Runtime("inspector wait"))?
            .success()
        {
            return Err(RecoveryCommandError::Missing("read-only Comet store inspection"))
        }
        serde_json::from_slice(&output).map_err(|_| RecoveryCommandError::Invalid)
    })
    .await
    .map_err(|_| RecoveryCommandError::Runtime("Comet inspection deadline"))?
}
/// Reject foreign/mixed app and Comet stores before any production writer starts.
pub fn validate_stores(
    store: &RecoveryStore,
    plan: &RecoveryPlan,
    report: &Inspection,
) -> Result<Option<abci::store::AppState>, RecoveryCommandError> {
    let params = plan.deployment.params()?;
    let chain = abci::rules::chain_id_for(&params, plan.origin.generation)
        .map_err(|_| RecoveryCommandError::Invalid)?;
    let app = store.plan_dir(plan.id()).join("app");
    let state_path = app.join(abci::store::STATE_FILE);
    let state: Option<abci::store::AppState> =
        if state_path.try_exists().map_err(|_| RecoveryCommandError::Io("inspect app state"))? {
            Some(
                serde_json::from_slice(&read_bounded(&state_path, MAX_PLAN_BYTES)?)
                    .map_err(|_| RecoveryCommandError::PlanMismatch)?,
            )
        } else {
            None
        };
    let bootstrap = app.join("recovery-bootstrap.json");
    let mut bootstrap_anchor = None;
    if bootstrap.try_exists().map_err(|_| RecoveryCommandError::Io("inspect bootstrap"))? {
        let bootstrap: abci::recovery::RecoveryBootstrap =
            serde_json::from_slice(&read_bounded(&bootstrap, MAX_PLAN_BYTES)?)
                .map_err(|_| RecoveryCommandError::PlanMismatch)?;
        let (witness, anchor) = bootstrap.verify(&params)?;
        bootstrap_anchor = Some(anchor);
        if abci::recovery::verify_recovery_witness(&witness, &params)? != plan.origin {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    } else if state.is_some() {
        return Err(RecoveryCommandError::Missing("installed recovery bootstrap"))
    }
    if let Some(state) = &state {
        let witness = plan.validate()?;
        let (genesis, _, _) = abci::l1::verify_genesis_inbox(
            witness.genesis.l1_header.state_root(),
            &witness.genesis.inbox,
            params.inbox,
        )
        .map_err(|_| RecoveryCommandError::Invalid)?;
        if state.schema_version != abci::store::STATE_SCHEMA_VERSION ||
            state.app_version != abci::app::APP_VERSION ||
            state.chain_id != chain ||
            state.generation != plan.origin.generation ||
            state.inbox != params.inbox ||
            state.genesis != genesis ||
            state.recovery.as_ref() != Some(&plan.origin) ||
            state.parent.number != state.last_height ||
            state.last_height < plan.origin.height
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
        // At the origin the validator state is CometBFT's genesis state of the R committee.
        let genesis_val_state = || {
            let members: Vec<_> =
                plan.origin.committee.members.iter().map(|m| (m.pubkey, m.power)).collect();
            abci::valstate::ValState::genesis(plan.origin.height, &members)
                .map_err(|_| RecoveryCommandError::Invalid)
        };
        if state.last_height == plan.origin.height &&
            (state.parent != abci::recovery::recovery_parent(&witness) ||
                bootstrap_anchor.as_ref() != Some(&state.anchor) ||
                state.forced_cursor != plan.origin.forced_cursor ||
                !state.last_comet_hash.is_zero() ||
                state.committees.len() != 1 ||
                state.committee_at(plan.origin.height + 1) != Some(&plan.origin.committee) ||
                state.val_state != genesis_val_state()?)
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    }
    if report.schema != 1 || report.blocks.len() > 2 {
        return Err(RecoveryCommandError::Invalid)
    }
    if report.empty {
        if report.state_height != 0 ||
            report.blockstore_height != 0 ||
            !report.blocks.is_empty() ||
            state.as_ref().is_some_and(|s| s.last_height > plan.origin.height)
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
        return Ok(state)
    }
    if (report.state_height == 0 &&
        (report.state_app_hash != plan.origin.el_hash || !report.state_comet_hash.is_zero())) ||
        report.chain_id != chain ||
        report.initial_height != plan.origin.height + 1 ||
        (report.state_height != 0 && report.state_height < report.initial_height)
    {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    let effective = if report.state_height == 0 { plan.origin.height } else { report.state_height };
    let next = effective.checked_add(1).ok_or(RecoveryCommandError::Invalid)?;
    if ![report.state_height, next].contains(&report.blockstore_height) {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    let app_height = state.as_ref().map_or(plan.origin.height, |s| s.last_height);
    let app_hash = state.as_ref().map_or(plan.origin.el_hash, |s| s.parent.hash);
    if app_height < effective ||
        app_height > next ||
        (app_height == next && report.blockstore_height != next) ||
        (app_height == effective && report.state_app_hash != app_hash) ||
        (state.is_none() && report.blockstore_height != 0)
    {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    for height in [next, next.checked_add(1).ok_or(RecoveryCommandError::Invalid)?] {
        let members = match &state {
            Some(s) => &s.committee_at(height).ok_or(RecoveryCommandError::PlanMismatch)?.members,
            None => &plan.origin.committee.members,
        };
        let expected =
            abci::wire::validators_hash(members).map_err(|_| RecoveryCommandError::Invalid)?;
        let observed =
            if height == next { report.validators_hash } else { report.next_validators_hash };
        if observed != expected {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    }
    for block in &report.blocks {
        if block.chain_id != chain ||
            block.height < report.initial_height ||
            ![report.state_height, report.blockstore_height].contains(&block.height)
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
        let envelope = abci::envelope::single_envelope(&block.transactions)
            .map_err(|_| RecoveryCommandError::Invalid)?;
        let header = &envelope.block.header;
        let (_, generation, _) = abci::rules::decode_extra_data(&header.extra_data)
            .map_err(|_| RecoveryCommandError::Invalid)?;
        if header.number != block.height ||
            generation != plan.origin.generation ||
            header.parent_hash != block.app_hash ||
            (block.height == report.initial_height && !block.parent_hash.is_zero())
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
        if block.height == report.state_height &&
            (block.hash != report.state_comet_hash ||
                header.hash_slow() != report.state_app_hash)
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
        if block.height == next &&
            (block.app_hash != report.state_app_hash ||
                block.parent_hash != report.state_comet_hash)
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
        if let Some(state) = &state &&
            block.height == state.last_height &&
            (header.hash_slow() != state.parent.hash || block.hash != state.last_comet_hash)
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    }
    for height in [report.state_height, report.blockstore_height] {
        if height != 0 && !report.blocks.iter().any(|b| b.height == height) {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    }
    Ok(state)
}
