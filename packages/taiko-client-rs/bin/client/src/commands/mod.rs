//! Command implementations.

use std::{io::IsTerminal, net::SocketAddr, path::Path};

use ::abci::ChainParams;
use async_trait::async_trait;
use tracing::info;
use tracing_subscriber::EnvFilter;

use crate::{
    error::{CliError, Result},
    flags::common::CommonArgs,
};

pub mod abci;
pub mod abci_committee_record;
pub mod abci_genesis;

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

    /// Initializes the logging system based on global arguments.
    fn init_logs(&self) -> Result<()> {
        let log_level = self.common_args().log_level();
        let env_filter = EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| EnvFilter::new(log_level.as_str().to_lowercase()));
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

    /// Initialize Prometheus metrics server.
    fn init_metrics(&self) -> Result<()> {
        if !self.common_args().metrics_enabled {
            return Ok(());
        }

        let metrics_addr =
            format!("{}:{}", self.common_args().metrics_addr, self.common_args().metrics_port);
        let socket_addr: SocketAddr = metrics_addr.parse()?;

        self.register_metrics()?;
        crate::metrics::version::VersionInfo::new(env!("CARGO_PKG_VERSION"))
            .register_version_metrics();
        crate::metrics::spawn_server(socket_addr)?;

        info!(
            target: "metrics",
            "Prometheus metrics server started at http://{}",
            metrics_addr
        );

        Ok(())
    }

    /// Hook for registering metrics after the exporter has started.
    fn register_metrics(&self) -> Result<()> {
        Ok(())
    }

    /// Execute the subcommand.
    async fn run(&self) -> Result<()>;
}
