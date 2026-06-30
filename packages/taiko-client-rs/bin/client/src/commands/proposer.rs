//! Proposer Subcommand.
use std::time::Duration;

use crate::error::Result;
use async_trait::async_trait;
use clap::Parser;
use proposer::{config::ProposerConfigs, metrics::ProposerMetrics, proposer::Proposer};
use protocol::shasta::set_devnet_unzen_override;

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
    /// Proposer-specific CLI arguments.
    #[command(flatten)]
    pub proposer_flags: ProposerArgs,
}

impl ProposerSubCommand {
    /// Build proposer configuration from command-line arguments.
    fn build_config(&self) -> Result<ProposerConfigs> {
        let l1_provider_source = self.common_flags.l1_provider_source()?;

        Ok(ProposerConfigs {
            l1_provider_source,
            l2_provider_url: self.common_flags.l2_http_endpoint.clone(),
            l2_auth_provider_url: self.common_flags.l2_auth_endpoint.clone(),
            jwt_secret: self.common_flags.l2_auth_jwt_secret.clone(),
            inbox_address: self.common_flags.shasta_inbox_address,
            l2_suggested_fee_recipient: self.proposer_flags.l2_suggested_fee_recipient,
            propose_interval: Duration::from_secs(self.proposer_flags.propose_interval),
            l1_proposer_private_key: self.proposer_flags.l1_proposer_private_key,
            gas_limit: self.proposer_flags.gas_limit,
            use_engine_mode: self.proposer_flags.use_engine_mode,
            retry_interval: Duration::from_secs(self.proposer_flags.retry_interval),
            confirmation_timeout: Duration::from_secs(self.proposer_flags.confirmation_timeout),
            receipt_query_interval: None,
            min_tip_cap_gwei: self.proposer_flags.min_tip_cap_gwei,
            min_base_fee_gwei: self.proposer_flags.min_base_fee_gwei,
            min_blob_fee_gwei: self.proposer_flags.min_blob_fee_gwei,
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
    /// Return a reference to the common CLI arguments.
    fn common_args(&self) -> &CommonArgs {
        &self.common_flags
    }

    /// Register proposer metrics before runtime startup.
    fn register_metrics(&self) -> Result<()> {
        ProposerMetrics::init();
        Ok(())
    }

    /// Execute the proposer subcommand flow.
    async fn run(&self) -> Result<()> {
        self.init_logs()?;
        set_devnet_unzen_override(self.common_flags.devnet_unzen_timestamp);
        self.init_metrics()?;

        let cfg = self.build_config()?;

        Proposer::new(cfg).await?.start().await.map_err(Into::into)
    }
}
