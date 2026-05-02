//! Command implementations.

use std::{io::IsTerminal, net::SocketAddr};

use ::driver::config::DriverConfig;
use async_trait::async_trait;
use metrics_exporter_prometheus::PrometheusBuilder;
use rpc::client::ClientConfig;
use tracing::info;
use tracing_subscriber::EnvFilter;

use crate::{
    error::Result,
    flags::{common::CommonArgs, driver::DriverArgs},
};

pub mod driver;
pub mod preconfirmation_driver;
pub mod proposer;
pub mod whitelist_preconfirmation_driver;

/// Build a [`DriverConfig`] from the shared common/driver CLI flags.
///
/// The resulting config has `preconfirmation_enabled = false`; callers that need to enable
/// preconfirmation ingress should toggle that flag on the returned value.
pub fn build_driver_config(common: &CommonArgs, driver: &DriverArgs) -> Result<DriverConfig> {
    let client_cfg = ClientConfig {
        l1_provider_source: common.l1_provider_source()?,
        l2_provider_url: common.l2_http_endpoint.clone(),
        l2_auth_provider_url: common.l2_auth_endpoint.clone(),
        jwt_secret: common.l2_auth_jwt_secret.clone(),
        inbox_address: common.shasta_inbox_address,
    };

    Ok(DriverConfig::new(
        client_cfg,
        driver.retry_interval(),
        driver.l1_beacon_endpoint.clone(),
        driver.l2_checkpoint_endpoint.clone(),
        driver.blob_server_endpoint.clone(),
    ))
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

        PrometheusBuilder::new().with_http_listener(socket_addr).install()?;
        self.register_metrics()?;

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
