//! Proposer Subcommand.
use std::time::Duration;

use alloy::transports::http::reqwest::Url as RpcUrl;
use anyhow::Result;
use clap::Parser;
use event_indexer::metrics::IndexerMetrics;
use metrics_exporter_prometheus::PrometheusBuilder;
use proposer::{config::ProposerConfigs, metrics::ProposerMetrics, proposer::Proposer};
use rpc::SubscriptionSource;
use tracing::info;

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
    pub fn init_logs(&self, args: &CommonArgs) -> anyhow::Result<()> {
        let log_level = args.log_level();
        let env_filter =
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                tracing_subscriber::EnvFilter::new(log_level.as_str().to_lowercase())
            });
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

    /// Initialize Prometheus metrics server.
    fn init_metrics(&self) -> Result<()> {
        if !self.common_flags.metrics_enabled {
            return Ok(());
        }

        let metrics_addr =
            format!("{}:{}", self.common_flags.metrics_addr, self.common_flags.metrics_port);

        let socket_addr: std::net::SocketAddr = metrics_addr.parse()?;
        PrometheusBuilder::new().with_http_listener(socket_addr).install()?;

        ProposerMetrics::init();
        IndexerMetrics::init();

        info!(
            target: "metrics",
            "Prometheus metrics server started at http://{}",
            metrics_addr
        );

        Ok(())
    }

    /// Run the proposer software.
    pub async fn run(&self) -> Result<()> {
        self.init_logs(self.common_flags())?;
        self.init_metrics()?;

        let l1_provider_source =
            SubscriptionSource::Ws(RpcUrl::parse(self.common_flags.l1_ws_endpoint.as_str())?);

        let cfg = ProposerConfigs {
            l1_provider_source,
            l2_provider_url: RpcUrl::parse(self.common_flags.l2_http_endpoint.as_str())?,
            l2_auth_provider_url: RpcUrl::parse(self.common_flags.l2_auth_endpoint.as_str())?,
            jwt_secret: self.common_flags.l2_auth_jwt_secret.clone(),
            inbox_address: self.common_flags.shasta_inbox_address,
            l2_suggested_fee_recipient: self.proposer_flags.l2_suggested_fee_recipient,
            propose_interval: Duration::from_secs(self.proposer_flags.propose_interval),
            l1_proposer_private_key: self.proposer_flags.l1_proposer_private_key,
            gas_limit: self.proposer_flags.gas_limit,
        };

        Proposer::new(cfg).await?.start().await.map_err(Into::into)
    }
}
