//! Governance recovery commands: `prepare` writes a plan file, `install` writes fresh stores
//! from it and `status` summarizes it offline. Stopping and starting services is the operator's.
use crate::{
    commands::{bind_l1_chain_id, load_chain_params, rpc_chain_id},
    error::Result,
    flags::common::CommonArgs,
    recovery::{
        RecoveryCommandError,
        install::install,
        plan::RecoveryPlan,
        prepare::prepare,
        status::{RecoveryStatus, status},
    },
};
use clap::{Parser, Subcommand};
use std::path::PathBuf;

/// Recovery actions.
#[derive(Parser, Clone, Debug)]
pub struct AbciRecoverSubCommand {
    /// Exact requested recovery operation.
    #[command(subcommand)]
    pub action: RecoveryAction,
}
/// Each action is one-shot; none starts, stops or signals a service.
#[derive(Subcommand, Clone, Debug)]
pub enum RecoveryAction {
    /// Authenticate a requested generation on own finalized L1 and write its plan file.
    Prepare {
        /// The node's own L1 and EL endpoints, spelled as for `abci`.
        #[command(flatten)]
        endpoints: Box<CommonArgs>,
        /// Path to a TOML file overriding the built-in chain parameters, as for `abci`.
        #[arg(long = "chain-config")]
        chain_config: Option<PathBuf>,
        /// Explicit nonzero generation; never inferred from the latest node state.
        #[arg(long)]
        generation: u64,
        /// New plan file; an existing path is never overwritten.
        #[arg(long)]
        out: PathBuf,
        /// Print the plan summary as JSON.
        #[arg(long)]
        json: bool,
    },
    /// Write a fresh Comet home and an empty app directory for a prepared plan.
    Install {
        /// Plan file written by `prepare`.
        #[arg(long)]
        plan: PathBuf,
        /// The node's stock Comet config.toml, used as the template.
        #[arg(long = "comet-config")]
        comet_config: PathBuf,
        /// The node's existing Ed25519 P2P key (config/node_key.json), never a registered key.
        #[arg(long = "node-key")]
        node_key: PathBuf,
        /// New Comet home, absent or empty.
        #[arg(long)]
        home: PathBuf,
        /// New app data directory, absent or empty.
        #[arg(long = "app-dir")]
        app_dir: PathBuf,
    },
    /// Summarize a plan offline and, with a home, whether it is installed there.
    Status {
        /// Plan file written by `prepare`.
        #[arg(long)]
        plan: PathBuf,
        /// Comet home to check for this plan's genesis.
        #[arg(long)]
        home: Option<PathBuf>,
        /// Print the summary as JSON.
        #[arg(long)]
        json: bool,
    },
}
impl AbciRecoverSubCommand {
    /// Runs the selected one-shot action.
    pub async fn run(&self) -> Result<()> {
        match &self.action {
            RecoveryAction::Prepare { endpoints, chain_config, generation, out, json } => {
                if *generation == 0 || *generation >= 1 << 48 {
                    return Err(RecoveryCommandError::Parse("nonzero uint48 generation").into());
                }
                if std::fs::symlink_metadata(out).is_ok() {
                    return Err(RecoveryCommandError::Parse("--out: an existing plan file").into());
                }
                // Parameters load exactly as `abci` loads them.
                let l2_id = super::abci::l2_chain_id(&endpoints.l2_http_endpoint).await?;
                let (mut params, expected_l1) = load_chain_params(l2_id, chain_config.as_deref())?;
                bind_l1_chain_id(
                    &mut params,
                    expected_l1,
                    rpc_chain_id(&endpoints.l1_http_endpoint, "l1.http").await?,
                )?;
                let l1 = abci::RpcL1Source::new(rpc::client::connect_http_with_timeout(
                    endpoints.l1_http_endpoint.clone(),
                    rpc::client::DEFAULT_HTTP_TIMEOUT,
                ));
                let engine = abci::RpcEngine::new(
                    endpoints.l2_http_endpoint.clone(),
                    endpoints.l2_auth_endpoint.clone(),
                    &endpoints.l2_auth_jwt_secret,
                    rpc::client::DEFAULT_HTTP_TIMEOUT,
                )
                .map_err(|_| RecoveryCommandError::Missing("EL JWT configuration"))?;
                let plan = prepare(&params, *generation, &l1, &engine).await?;
                plan.write_new(out)?;
                print(&status(&plan, None)?, *json)
            }
            RecoveryAction::Install { plan, comet_config, node_key, home, app_dir } => {
                install(&RecoveryPlan::load(plan)?, comet_config, node_key, home, app_dir)?;
                println!("Installed the plan's Comet home and app directory");
                Ok(())
            }
            RecoveryAction::Status { plan, home, json } => {
                print(&status(&RecoveryPlan::load(plan)?, home.as_deref())?, *json)
            }
        }
    }
}

/// Prints one summary line, or the JSON report.
fn print(report: &RecoveryStatus, json: bool) -> Result<()> {
    if json {
        println!(
            "{}",
            serde_json::to_string(report).map_err(|_| RecoveryCommandError::Parse("status"))?
        );
    } else {
        println!(
            "Recovery plan: generation {}, chain_id {}, c={}, R={}, genesis_hash {}, {} validators, observed checkpoint {}, installed {}",
            report.generation,
            report.chain_id,
            report.origin_height,
            report.recovery_l1_block,
            report.genesis_hash,
            report.validators,
            report.observed_checkpoint_height,
            report.installed.map_or("unchecked", |installed| if installed { "yes" } else { "no" }),
        );
    }
    Ok(())
}
