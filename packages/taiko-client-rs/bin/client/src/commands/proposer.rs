//! Proposer Subcommand.
use std::time::Duration;

use alloy::transports::http::reqwest::Url as RpcUrl;
use anyhow::Result;
use async_trait::async_trait;
use clap::Parser;
use proposer::{config::ProposerConfigs, metrics::ProposerMetrics, proposer::Proposer};
use rpc::SubscriptionSource;

use crate::{
    commands::Subcommand,
    flags::{common::CommonArgs, proposer::ProposerArgs},
};

/// Command-line interface for running a proposer.
///
/// The `ProposerSubCommand` struct defines all the configuration options needed to start and run
/// a proposer software for Taiko protocol.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the proposer software")]
pub struct ProposerSubCommand {
    /// Common CLI arguments.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    #[command(flatten)]
    pub proposer_flags: ProposerArgs,
}

impl ProposerSubCommand {
    /// Build proposer configuration from command-line arguments.
    fn build_config(&self) -> Result<ProposerConfigs> {
        let l1_provider_source =
            SubscriptionSource::Ws(RpcUrl::parse(self.common_flags.l1_ws_endpoint.as_str())?);

        Ok(ProposerConfigs {
            l1_provider_source,
            l2_provider_url: RpcUrl::parse(self.common_flags.l2_http_endpoint.as_str())?,
            l2_auth_provider_url: RpcUrl::parse(self.common_flags.l2_auth_endpoint.as_str())?,
            jwt_secret: self.common_flags.l2_auth_jwt_secret.clone(),
            inbox_address: self.common_flags.shasta_inbox_address,
            l2_suggested_fee_recipient: self.proposer_flags.l2_suggested_fee_recipient,
            propose_interval: Duration::from_secs(self.proposer_flags.propose_interval),
            l1_proposer_private_key: self.proposer_flags.l1_proposer_private_key,
            gas_limit: self.proposer_flags.gas_limit,
            use_engine_mode: self.proposer_flags.use_engine_mode,
        })
    }

    /// Return a reference to the proposer-specific CLI arguments.
    pub fn proposer_flags(&self) -> &ProposerArgs {
        &self.proposer_flags
    }

    /// Run the proposer software.
    pub async fn run(&self) -> Result<()> {
        <Self as Subcommand>::run(self).await
    }
}

#[async_trait]
impl Subcommand for ProposerSubCommand {
    // Return a reference to the common CLI arguments.
    fn common_args(&self) -> &CommonArgs {
        &self.common_flags
    }

    // Register proposer and indexer metrics.
    fn register_metrics(&self) -> Result<()> {
        ProposerMetrics::init();
        Ok(())
    }

    // Run the proposer software.
    async fn run(&self) -> Result<()> {
        self.init_logs()?;
        self.init_metrics()?;

        let cfg = self.build_config()?;

        Proposer::new(cfg).await?.start().await.map_err(Into::into)
    }
}
