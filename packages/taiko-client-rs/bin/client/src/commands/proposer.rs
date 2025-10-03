//! Proposer Subcommand.
use alloy::transports::http::reqwest::Url as RpcUrl;
use anyhow::Result;
use clap::Parser;
use proposer::config::ProposerConfigs;
use rpc::SubscriptionSource;

use crate::flags::{common::CommonArgs, proposer::ProposerArgs};

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
    /// Initializes the logging system based on global arguments.
    pub fn init_logs(&self, _args: &CommonArgs) -> anyhow::Result<()> {
        let env_filter = tracing_subscriber::EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("debug"));
        let _ = tracing_subscriber::fmt().with_env_filter(env_filter).try_init();
        Ok(())
    }

    /// Return a reference to the common CLI arguments.
    pub fn common_flags(&self) -> &CommonArgs {
        &self.common_flags
    }

    /// Return a reference to the proposer-specific CLI arguments.
    pub fn proposer_flags(&self) -> &ProposerArgs {
        &self.proposer_flags
    }

    /// Run the proposer software.
    pub async fn run(&self) -> Result<()> {
        let l1_provider =
            SubscriptionSource::Ws(RpcUrl::parse(self.common_flags.l1_ws_endpoint.as_str())?);
        let l2_provider =
            SubscriptionSource::Ws(RpcUrl::parse(self.common_flags.l2_http_endpoint.as_str())?);

        let cfg = ProposerConfigs {
            l1_provider,
            l2_provider,
            inbox_address: self.common_flags.taiko_inbox_address,
            l2_suggested_fee_recipient: self.proposer_flags.l2_suggested_fee_recipient,
            propose_interval: std::time::Duration::from_secs(6),
        };

        proposer::Proposer::new(cfg).await?.start().await
    }
}
