//! Explicit-generation operator recovery preparation and redacted local status.
use crate::{
    error::Result,
    recovery::{
        RecoveryCommandError, prepare::prepare, profile::RecoveryProfile, status::status,
        store::RecoveryStore,
    },
};
use alloy_primitives::B256;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

/// Recovery actions; activation is deliberately separate from immutable preparation.
#[derive(Parser, Clone, Debug)]
pub struct AbciRecoverSubCommand {
    /// Exact requested recovery operation.
    #[command(subcommand)]
    pub action: RecoveryAction,
}
/// CLI arguments contain file selectors only, never endpoint credentials or executable argv.
#[derive(Subcommand, Clone, Debug)]
pub enum RecoveryAction {
    /// Authenticate a requested generation and stage an immutable private bundle.
    Prepare {
        /// Private schema-one TOML profile.
        #[arg(long)]
        profile: PathBuf,
        /// Explicit nonzero generation; never inferred from the latest node state.
        #[arg(long)]
        generation: u64,
        /// Private directory containing plans and operation journals.
        #[arg(long)]
        root: PathBuf,
        /// Emit a redacted structured report.
        #[arg(long)]
        json: bool,
    },
    /// Activate or resume an exact prepared plan, retaining foreground ownership until stopped.
    Activate {
        /// Private profile must match the exact immutable prepared profile commitment.
        #[arg(long)]
        profile: PathBuf,
        /// Existing private recovery root.
        #[arg(long)]
        root: PathBuf,
        /// Full immutable plan identifier, never inferred from an observed generation.
        #[arg(long)]
        plan: B256,
    },
    /// Read immutable evidence and local durable phase without granting trust.
    Status {
        /// Existing private recovery root.
        #[arg(long)]
        root: PathBuf,
        /// Exact content-addressed plan identifier.
        #[arg(long)]
        plan: B256,
        /// Emit a redacted structured report.
        #[arg(long)]
        json: bool,
    },
}
impl AbciRecoverSubCommand {
    /// Runs the selected foreground operation or prints sanitized historical status.
    pub async fn run(&self) -> Result<()> {
        let (report, json) = match &self.action {
            RecoveryAction::Prepare { profile, generation, root, json } => {
                if *generation == 0 || *generation >= 1 << 48 {
                    return Err(RecoveryCommandError::Parse("nonzero uint48 generation").into());
                }
                let profile = RecoveryProfile::load(profile)?;
                profile.validate_root(root)?;
                let l1_url = profile
                    .l1_http
                    .parse()
                    .map_err(|_| RecoveryCommandError::Parse("L1 endpoint"))?;
                let l2_url = profile
                    .l2_http
                    .parse()
                    .map_err(|_| RecoveryCommandError::Parse("EL endpoint"))?;
                let l1_id = super::rpc_chain_id(&l1_url, "l1.http")
                    .await
                    .map_err(|_| RecoveryCommandError::Runtime("L1 identity"))?;
                let l2_id = super::rpc_chain_id(&l2_url, "l2.http")
                    .await
                    .map_err(|_| RecoveryCommandError::Runtime("EL identity"))?;
                if l1_id != profile.l1_chain_id ||
                    l2_id != alloy_primitives::U256::from(profile.l2_chain_id)
                {
                    return Err(RecoveryCommandError::ConfigMismatch.into());
                }
                let l1 = abci::RpcL1Source::new(rpc::client::connect_http_with_timeout(
                    l1_url,
                    rpc::client::DEFAULT_HTTP_TIMEOUT,
                ));
                let engine = abci::RpcEngine::new(
                    l2_url,
                    profile
                        .l2_auth
                        .parse()
                        .map_err(|_| RecoveryCommandError::Parse("Engine endpoint"))?,
                    &profile.jwt_secret,
                    rpc::client::DEFAULT_HTTP_TIMEOUT,
                )
                .map_err(|_| RecoveryCommandError::Missing("EL JWT configuration"))?;
                let plan = prepare(&profile, *generation, root, &l1, &engine).await?;
                (status(&RecoveryStore::new(root), plan.id())?, *json)
            }
            RecoveryAction::Activate { profile, root, plan } => {
                crate::recovery::activate::activate(
                    RecoveryProfile::load(profile)?,
                    root.clone(),
                    *plan,
                )
                .await?;
                return Ok(());
            }
            RecoveryAction::Status { root, plan, json } => {
                (status(&RecoveryStore::new(root), *plan)?, *json)
            }
        };
        if json {
            println!(
                "{}",
                serde_json::to_string(&report)
                    .map_err(|_| RecoveryCommandError::Parse("status"))?
            );
        } else {
            println!(
                "Plan {}: generation {}, c={}, R={}, phase={:?}; last landed={}, trust target={}, committed={:?}, live-trust=false, blocker={:?}; pending prerequisites: {:?}",
                report.plan_id,
                report.generation,
                report.origin_height,
                report.recovery_l1_block,
                report.phase,
                report.landed_height,
                report.trust_target_height,
                report.committed_height,
                report.blocker,
                report.prerequisites
            );
        }
        Ok(())
    }
}
