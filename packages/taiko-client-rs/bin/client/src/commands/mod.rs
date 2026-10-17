//! Command implementations.

use std::{io::IsTerminal, net::SocketAddr, path::Path};

use ::abci::ChainParams;
use async_trait::async_trait;
use tracing::info;
use tracing_subscriber::EnvFilter;

use crate::{
    error::{CliError, Result},
    flags::common::{CommonArgs, ObservabilityArgs},
};

pub mod abci;
pub mod abci_committee_record;
pub mod abci_genesis;
pub mod lander;

/// The chain parameters of `l2_chain_id`: the built-in ones, overridden by the TOML file at
/// `chain_config` when given, validated.
pub fn load_chain_params(l2_chain_id: u64, chain_config: Option<&Path>) -> Result<ChainParams> {
    let mut params = ChainParams::builtin(l2_chain_id)?;
    if let Some(path) = chain_config {
        let toml = std::fs::read_to_string(path)
            .map_err(|source| CliError::ChainConfigRead { path: path.to_path_buf(), source })?;
        params = params.with_overrides(&toml)?;
    }
    params.validate()?;
    Ok(params)
}

/// Shared behaviour for CLI subcommands.
#[async_trait]
pub trait Subcommand {
    /// Access the common CLI arguments.
    fn common_args(&self) -> &CommonArgs;

    /// Initializes the logging system based on shared observability arguments.
    fn init_logs(&self) -> Result<()> {
        init_logs(&self.common_args().observability)
    }

    /// Initialize the Prometheus exporter after registering command metrics.
    fn init_metrics(&self) -> Result<()> {
        if self.common_args().observability.metrics_enabled {
            self.register_metrics()?;
        }
        init_metrics(&self.common_args().observability)
    }

    /// Hook for registering metrics after the exporter has started.
    fn register_metrics(&self) -> Result<()> {
        Ok(())
    }

    /// Execute the subcommand.
    async fn run(&self) -> Result<()>;
}

/// Initialize tracing for a command that does not require Engine API arguments.
pub fn init_logs(args: &ObservabilityArgs) -> Result<()> {
    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(args.log_level().as_str().to_lowercase()));
    let ansi = match std::env::var("RUST_LOG_STYLE") {
        Ok(value) => match value.to_lowercase().as_str() {
            "always" => true,
            "never" => false,
            _ => std::io::stdout().is_terminal(),
        },
        Err(_) => std::io::stdout().is_terminal(),
    };
    let _ = tracing_subscriber::fmt().with_env_filter(env_filter).with_ansi(ansi).try_init();
    Ok(())
}

/// Start the shared Prometheus exporter when explicitly enabled.
pub fn init_metrics(args: &ObservabilityArgs) -> Result<()> {
    if !args.metrics_enabled {
        return Ok(());
    }
    let metrics_addr = format!("{}:{}", args.metrics_addr, args.metrics_port);
    let socket_addr: SocketAddr = metrics_addr.parse()?;
    crate::metrics::version::VersionInfo::new(env!("CARGO_PKG_VERSION")).register_version_metrics();
    crate::metrics::spawn_server(socket_addr)?;
    info!(target: "metrics", "Prometheus metrics server started at http://{}", metrics_addr);
    Ok(())
}

/// Independent L2 reward claims.
pub mod lander_claim;
