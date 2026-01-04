//! Driver subcommand.

use alloy::transports::http::reqwest::Url as RpcUrl;
use anyhow::Result;
use async_trait::async_trait;
use clap::Parser;
use driver::{Driver, DriverConfig, metrics::DriverMetrics, p2p_sidecar::P2pSidecarConfig};
use p2p::P2pClientConfig;
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
        // L1 provider subscription source for event scanning.
        let l1_source =
            SubscriptionSource::Ws(RpcUrl::parse(self.common_flags.l1_ws_endpoint.as_str())?);
        // L2 public provider HTTP URL.
        let l2_http = RpcUrl::parse(self.common_flags.l2_http_endpoint.as_str())?;
        // L2 authenticated provider HTTP URL.
        let l2_auth = RpcUrl::parse(self.common_flags.l2_auth_endpoint.as_str())?;
        // L1 beacon HTTP endpoint.
        let l1_beacon = RpcUrl::parse(self.driver_flags.l1_beacon_endpoint.as_str())?;
        // Optional L2 checkpoint URL.
        let l2_checkpoint = if let Some(url) = &self.driver_flags.l2_checkpoint_endpoint {
            Some(RpcUrl::parse(url.as_str())?)
        } else {
            None
        };
        // Optional blob server URL.
        let blob_server = if let Some(url) = &self.driver_flags.blob_server_endpoint {
            Some(RpcUrl::parse(url.as_str())?)
        } else {
            None
        };

        // RPC client configuration used by the driver.
        let client_cfg = rpc::client::ClientConfig {
            l1_provider_source: l1_source,
            l2_provider_url: l2_http,
            l2_auth_provider_url: l2_auth,
            jwt_secret: self.common_flags.l2_auth_jwt_secret.clone(),
            inbox_address: self.common_flags.shasta_inbox_address,
        };

        // Base driver configuration.
        let mut cfg = DriverConfig::new(
            client_cfg,
            self.driver_flags.retry_interval(),
            l1_beacon,
            l2_checkpoint,
            blob_server,
        );

        if self.driver_flags.p2p_sidecar_enabled {
            // Chain id override for P2P config.
            let chain_id = self.driver_flags.p2p_chain_id;
            // Base P2P client configuration.
            let mut p2p_cfg = if let Some(chain_id) = chain_id {
                P2pClientConfig::with_chain_id(chain_id)
            } else {
                P2pClientConfig::default()
            };
            if let Some(listen_addr) = self.driver_flags.p2p_listen_addr {
                // Override listen address.
                p2p_cfg.network.listen_addr = listen_addr;
            }
            if !self.driver_flags.p2p_bootnodes.is_empty() {
                p2p_cfg.network.bootnodes = self.driver_flags.p2p_bootnodes.clone();
            }
            if let Some(enable_discovery) = self.driver_flags.p2p_enable_discovery {
                // Override discovery flag.
                p2p_cfg.network.enable_discovery = enable_discovery;
            }
            // Optional expected slasher address.
            let expected_slasher = self.driver_flags.p2p_expected_slasher;
            p2p_cfg.expected_slasher = expected_slasher;
            // Optional txlist byte limit override.
            let max_txlist_bytes = self.driver_flags.p2p_max_txlist_bytes;
            if let Some(max_txlist_bytes) = max_txlist_bytes {
                // Override txlist byte limit.
                p2p_cfg.max_txlist_bytes = max_txlist_bytes;
            }
            // Sidecar configuration injected into the driver.
            let sidecar_cfg = P2pSidecarConfig { enabled: true, client: p2p_cfg };
            cfg.p2p_sidecar = Some(sidecar_cfg);
            cfg.preconfirmation_enabled = true;
        }

        Ok(cfg)
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
