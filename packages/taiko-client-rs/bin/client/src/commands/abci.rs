//! `abci` subcommand: serves the Etna PoS chain's ABCI++ app to CometBFT.

use abci::{AbciMetrics, App, Engine, RpcEngine, RpcL1Source, Store, serve};
use alloy_provider::Provider;
use async_trait::async_trait;
use clap::Parser;
use rpc::{
    RpcClientError,
    client::{DEFAULT_HTTP_TIMEOUT, connect_http_with_timeout, http_timeout_for},
};
use tracing::info;
use url::Url;

use crate::{
    commands::{Subcommand, load_chain_params},
    error::{CliError, Result},
    flags::{abci::AbciArgs, common::CommonArgs},
};

/// Command-line interface of the ABCI app.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the ABCI++ application of the Etna PoS chain for CometBFT")]
pub struct AbciSubCommand {
    /// Common CLI arguments shared across all subcommands.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    /// ABCI-specific CLI arguments.
    #[command(flatten)]
    pub abci_flags: AbciArgs,
}

impl AbciSubCommand {
    /// Runs the ABCI app until the server fails (a safety halt exits the process with
    /// [`abci::SAFETY_HALT_EXIT_CODE`]).
    pub async fn run(&self) -> Result<()> {
        <Self as Subcommand>::run(self).await
    }
}

/// `eth_chainId` of the L2 execution engine's public endpoint `url`.
async fn l2_chain_id(url: &Url) -> Result<u64> {
    connect_http_with_timeout(url.clone(), DEFAULT_HTTP_TIMEOUT).get_chain_id().await.map_err(|e| {
        CliError::from(RpcClientError::RpcMessage(format!(
            "L2 HTTP RPC (l2.http) failed to get chain id from {url}: {e}"
        )))
    })
}

#[async_trait]
impl Subcommand for AbciSubCommand {
    /// Return a reference to the common CLI arguments.
    fn common_args(&self) -> &CommonArgs {
        &self.common_flags
    }

    /// Register the ABCI app metrics.
    fn register_metrics(&self) -> Result<()> {
        AbciMetrics::init();
        Ok(())
    }

    /// Connects to the EL and L1, loads the app state and serves the app.
    ///
    /// In order: logs and metrics; the L2 chain id from `--l2.http`; the chain parameters for it;
    /// the Engine API client and its capability check; the L1 provider (`--l1.http`); the app
    /// over the state in `--data-dir`; the ABCI server on `--abci.addr`.
    async fn run(&self) -> Result<()> {
        self.init_logs()?;
        self.init_metrics()?;

        let common = &self.common_flags;
        let flags = &self.abci_flags;
        let chain_id = l2_chain_id(&common.l2_http_endpoint).await?;
        let params = load_chain_params(chain_id, flags.chain_config.as_deref())?;
        let opts = flags.app_options();
        let engine = RpcEngine::new(
            common.l2_http_endpoint.clone(),
            common.l2_auth_endpoint.clone(),
            &common.l2_auth_jwt_secret,
            opts.engine_timeout,
        )?;
        engine.check_capabilities().await?;
        let l1 = RpcL1Source::new(connect_http_with_timeout(
            common.l1_http_endpoint.clone(),
            http_timeout_for(opts.l1_timeout),
        ));
        let app = App::new(l1, engine, params, Store::new(flags.data_dir.clone()), opts)?;
        info!(
            chain_id,
            addr = %flags.addr,
            data_dir = %flags.data_dir.display(),
            head = ?app.status().map(|s| s.head),
            "serving the ABCI app"
        );
        serve(app, &flags.addr).await?;
        Ok(())
    }
}
