//! A standalone, disposable anvil for actual-contract blob transaction integration tests.

use std::time::Duration;

use alloy_provider::{Provider, RootProvider};
use anyhow::{Result, ensure};
use rpc::client::{DEFAULT_HTTP_TIMEOUT, connect_http_with_timeout};
use url::Url;

use crate::{
    docker::{DockerEnv, host_port},
    wait::wait_until,
};

/// One anvil container on a privately owned Docker network.
///
/// This harness has no dependency on the lander. Dropping it removes all Docker resources;
/// failed tests print container logs using the same conventions as the ABCI devnet.
#[derive(Debug)]
pub struct StandaloneAnvil {
    /// Host HTTP endpoint.
    pub http: Url,
    /// Public RPC provider.
    pub provider: RootProvider,
    /// The network and its owned container.
    docker: DockerEnv,
    /// Whether explicit cleanup succeeded.
    stopped: bool,
}

impl StandaloneAnvil {
    /// Starts an Osaka anvil with chain id 31337, default ephemeral development accounts,
    /// automining, and the dedicated `LANDER_ANVIL_IMAGE` override. This version includes canonical
    /// zero-storage proofs; the older ABCI image is preserved independently.
    pub async fn start() -> Result<Self> {
        let id = tempfile::Builder::new().prefix("lander-").tempdir()?;
        let suffix =
            id.path().file_name().expect("temporary directory has a name").to_string_lossy();
        let name = format!("{suffix}-anvil");
        let mut docker = DockerEnv::create(format!("{suffix}-net")).await?;
        let image = std::env::var("LANDER_ANVIL_IMAGE")
            .unwrap_or_else(|_| "ghcr.io/foundry-rs/foundry:v1.8.5".into());
        docker
            .run(
                &name,
                &[
                    "-p",
                    "8545",
                    "--entrypoint",
                    "anvil",
                    &image,
                    "--host",
                    "0.0.0.0",
                    "--hardfork",
                    "osaka",
                    "--chain-id",
                    "31337",
                    "--slots-in-an-epoch",
                    "1",
                    "--gas-limit",
                    "200000000",
                ],
            )
            .await?;
        let http = Url::parse(&format!("http://127.0.0.1:{}", host_port(&name, 8545).await?))?;
        let provider = connect_http_with_timeout(http.clone(), DEFAULT_HTTP_TIMEOUT);
        let chain_id = wait_until(
            "standalone anvil RPC",
            Duration::from_secs(90),
            Duration::from_millis(250),
            || async { Ok(Some(provider.get_chain_id().await?)) },
        )
        .await?;
        ensure!(chain_id == 31337, "unexpected standalone anvil chain id {chain_id}");
        Ok(Self { http, provider, docker, stopped: false })
    }

    /// Prints the owned container's recent logs.
    pub fn dump_logs(&self) {
        self.docker.dump_logs();
    }

    /// Removes the container and private network explicitly. Drop retries failed cleanup.
    pub async fn stop(mut self) -> Result<()> {
        self.docker.cleanup().await?;
        self.stopped = true;
        Ok(())
    }
}

impl Drop for StandaloneAnvil {
    /// Failed tests retain diagnostics before DockerEnv removes every owned resource.
    fn drop(&mut self) {
        if !self.stopped && !self.docker.logs_dumped() {
            self.docker.dump_logs();
        }
    }
}
