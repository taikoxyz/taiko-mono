//! Whitelist preconfirmation driver subcommand.

use alloy::transports::http::reqwest::Url as RpcUrl;
use alloy_primitives::Address;
use async_trait::async_trait;
use clap::Parser;
use driver::{DriverConfig, metrics::DriverMetrics};
use preconfirmation_net::P2pConfig;
use rpc::{SubscriptionSource, client::ClientConfig};
use tracing::warn;
use whitelist_preconfirmation_driver::{
    RunnerConfig, WhitelistPreconfirmationDriverMetrics, WhitelistPreconfirmationDriverRunner,
};

use crate::{
    commands::Subcommand,
    error::Result,
    flags::{common::CommonArgs, driver::DriverArgs, preconfirmation::PreconfirmationArgs},
};

/// Command-line interface for running the whitelist preconfirmation driver.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the whitelist preconfirmation driver with whitelist P2P protocol")]
pub struct WhitelistPreconfirmationDriverSubCommand {
    /// Common CLI arguments shared across all subcommands.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    /// Driver-specific CLI arguments.
    #[command(flatten)]
    pub driver_flags: DriverArgs,
    /// Preconfirmation-specific CLI arguments.
    #[command(flatten)]
    pub preconf_flags: PreconfirmationArgs,
    /// Whitelist P2P chain id for topic derivation.
    #[clap(long = "p2p.chain-id", env = "P2P_CHAIN_ID")]
    pub p2p_chain_id: Option<u64>,
    /// Shasta preconfirmation whitelist contract address.
    #[clap(long = "shasta.preconf-whitelist", env = "SHASTA_PRECONF_WHITELIST", required = true)]
    pub shasta_preconf_whitelist_address: Address,
}

impl WhitelistPreconfirmationDriverSubCommand {
    /// Build driver configuration from command-line arguments.
    fn build_driver_config(&self) -> Result<DriverConfig> {
        let l1_source =
            SubscriptionSource::Ws(RpcUrl::parse(self.common_flags.l1_ws_endpoint.as_str())?);
        let l2_http = RpcUrl::parse(self.common_flags.l2_http_endpoint.as_str())?;
        let l2_auth = RpcUrl::parse(self.common_flags.l2_auth_endpoint.as_str())?;
        let l1_beacon = RpcUrl::parse(self.driver_flags.l1_beacon_endpoint.as_str())?;

        let l2_checkpoint = self
            .driver_flags
            .l2_checkpoint_endpoint
            .as_ref()
            .map(|url| RpcUrl::parse(url.as_str()))
            .transpose()?;

        let blob_server = self
            .driver_flags
            .blob_server_endpoint
            .as_ref()
            .map(|url| RpcUrl::parse(url.as_str()))
            .transpose()?;

        let client_cfg = ClientConfig {
            l1_provider_source: l1_source,
            l2_provider_url: l2_http,
            l2_auth_provider_url: l2_auth,
            jwt_secret: self.common_flags.l2_auth_jwt_secret.clone(),
            inbox_address: self.common_flags.shasta_inbox_address,
        };

        let mut cfg = DriverConfig::new(
            client_cfg,
            self.driver_flags.retry_interval(),
            l1_beacon,
            l2_checkpoint,
            blob_server,
        );

        // Enable preconfirmation ingress so whitelist payload imports can reuse the driver queue.
        cfg.preconfirmation_enabled = true;

        Ok(cfg)
    }

    /// Build P2P configuration from command-line arguments.
    fn build_p2p_config(&self) -> P2pConfig {
        let pre_dial_peers = self
            .preconf_flags
            .p2p_static_peers
            .iter()
            .filter_map(|peer| {
                peer.parse().map_err(|_| warn!(peer, "failed to parse static peer address")).ok()
            })
            .collect();

        let mut cfg = P2pConfig {
            listen_addr: self.preconf_flags.p2p_listen,
            discovery_listen: self.preconf_flags.p2p_discovery_addr,
            enable_discovery: !self.preconf_flags.p2p_disable_discovery,
            bootnodes: self.preconf_flags.p2p_bootnodes.clone(),
            pre_dial_peers,
            ..Default::default()
        };

        if let Some(chain_id) = self.p2p_chain_id {
            cfg.chain_id = chain_id;
        }

        cfg
    }

    /// Run the whitelist preconfirmation driver.
    pub async fn run(&self) -> Result<()> {
        <Self as Subcommand>::run(self).await
    }
}

#[async_trait]
impl Subcommand for WhitelistPreconfirmationDriverSubCommand {
    /// Returns a reference to the common CLI arguments.
    fn common_args(&self) -> &CommonArgs {
        &self.common_flags
    }

    /// Registers driver metrics with the global registry.
    fn register_metrics(&self) -> Result<()> {
        DriverMetrics::init();
        WhitelistPreconfirmationDriverMetrics::init();
        Ok(())
    }

    /// Runs the whitelist preconfirmation driver.
    async fn run(&self) -> Result<()> {
        self.init_logs()?;
        self.init_metrics()?;

        let driver_config = self.build_driver_config()?;
        let p2p_config = self.build_p2p_config();

        let runner_config =
            RunnerConfig::new(driver_config, p2p_config, self.shasta_preconf_whitelist_address);

        WhitelistPreconfirmationDriverRunner::new(runner_config).run().await?;
        Ok(())
    }
}
