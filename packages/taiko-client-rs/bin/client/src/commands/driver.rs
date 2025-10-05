//! Driver subcommand.

use alloy::transports::http::reqwest::Url as RpcUrl;
use anyhow::Result;
use clap::Parser;
use driver::{Driver, DriverConfig, metrics::DriverMetrics};
use event_indexer::metrics::IndexerMetrics;
use metrics_exporter_prometheus::PrometheusBuilder;
use rpc::SubscriptionSource;
use tracing::info;

use crate::flags::{common::CommonArgs, driver::DriverArgs};

/// Command-line interface for running the driver service.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the Shasta driver")]
pub struct DriverSubCommand {
    #[command(flatten)]
    pub common_flags: CommonArgs,
    #[command(flatten)]
    pub driver_flags: DriverArgs,
}

impl DriverSubCommand {
    /// Initializes the logging system based on global arguments.
    pub fn init_logs(&self) -> anyhow::Result<()> {
        let log_level = self.common_flags.log_level();
        let env_filter =
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                tracing_subscriber::EnvFilter::new(log_level.as_str().to_lowercase())
            });
        let _ = tracing_subscriber::fmt().with_env_filter(env_filter).try_init();
        Ok(())
    }

    /// Initialize Prometheus metrics server.
    fn init_metrics(&self) -> Result<()> {
        if !self.common_flags.metrics_enabled {
            return Ok(());
        }

        let metrics_addr =
            format!("{}:{}", self.common_flags.metrics_addr, self.common_flags.metrics_port);
        let socket_addr: std::net::SocketAddr = metrics_addr.parse()?;
        PrometheusBuilder::new().with_http_listener(socket_addr).install()?;

        DriverMetrics::init();
        IndexerMetrics::init();

        info!(
            target: "metrics",
            "Prometheus metrics server started at http://{}",
            metrics_addr
        );

        Ok(())
    }

    fn build_config(&self) -> Result<DriverConfig> {
        let l1_source =
            SubscriptionSource::Ws(RpcUrl::parse(self.common_flags.l1_ws_endpoint.as_str())?);
        let l2_http = RpcUrl::parse(self.common_flags.l2_http_endpoint.as_str())?;
        let l2_auth = RpcUrl::parse(self.common_flags.l2_auth_endpoint.as_str())?;
        let l1_beacon = RpcUrl::parse(self.driver_flags.l1_beacon_endpoint.as_str())?;
        let l2_checkpoint = if let Some(url) = &self.driver_flags.l2_checkpoint_endpoint {
            Some(RpcUrl::parse(url.as_str())?)
        } else {
            None
        };

        Ok(DriverConfig::new(
            l1_source,
            l2_http,
            l2_auth,
            self.common_flags.l2_auth_jwt_secret.clone(),
            self.common_flags.shasta_inbox_address,
            self.driver_flags.retry_interval(),
            l1_beacon,
            l2_checkpoint,
        ))
    }

    /// Run the driver.
    pub async fn run(&self) -> Result<()> {
        self.init_logs()?;
        self.init_metrics()?;

        let cfg = self.build_config()?;
        Driver::new(cfg).await?.run().await.map_err(Into::into)
    }
}
