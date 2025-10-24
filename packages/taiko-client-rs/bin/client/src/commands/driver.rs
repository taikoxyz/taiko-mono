//! Driver subcommand.

use alloy::transports::http::reqwest::Url as RpcUrl;
use anyhow::Result;
use async_trait::async_trait;
use clap::Parser;
use driver::{Driver, DriverConfig, metrics::DriverMetrics};
use event_indexer::metrics::IndexerMetrics;
use rpc::SubscriptionSource;

use crate::{
    commands::Subcommand,
    flags::{common::CommonArgs, driver::DriverArgs},
};

/// Command-line interface for running the driver service.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the driver software")]
pub struct DriverSubCommand {
    #[command(flatten)]
    pub common_flags: CommonArgs,
    #[command(flatten)]
    pub driver_flags: DriverArgs,
}

impl DriverSubCommand {
    // Build driver configuration from command-line arguments.
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

        let client_cfg = rpc::client::ClientConfig {
            l1_provider_source: l1_source,
            l2_provider_url: l2_http,
            l2_auth_provider_url: l2_auth,
            jwt_secret: self.common_flags.l2_auth_jwt_secret.clone(),
            inbox_address: self.common_flags.shasta_inbox_address,
        };

        Ok(DriverConfig::new(
            client_cfg,
            self.driver_flags.retry_interval(),
            l1_beacon,
            l2_checkpoint,
        ))
    }

    /// Run the driver.
    pub async fn run(&self) -> Result<()> {
        <Self as Subcommand>::run(self).await
    }
}

#[async_trait]
impl Subcommand for DriverSubCommand {
    // Return a reference to the common CLI arguments.
    fn common_args(&self) -> &CommonArgs {
        &self.common_flags
    }

    // Register driver and indexer metrics.
    fn register_metrics(&self) -> Result<()> {
        DriverMetrics::init();
        IndexerMetrics::init();
        Ok(())
    }

    // Run the driver.
    async fn run(&self) -> Result<()> {
        self.init_logs()?;
        self.init_metrics()?;

        let cfg = self.build_config()?;
        Driver::new(cfg).await?.run().await.map_err(Into::into)
    }
}
