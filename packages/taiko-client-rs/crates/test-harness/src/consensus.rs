//! Run real ABCI/Comet consensus over caller-owned deployed contracts and execution node.
use crate::{
    CmtClient, StandaloneReth, ValidatorKey,
    app::{AppConfig, AppNode, free_port},
    boot::{RethNode, host_user, jwt_path, local_url, make_world_writable},
    cometbft::{HomeConfig, write_home},
    docker::{DockerEnv, host_port},
    signer::SignerNode,
    wait_until,
};
use abci::{ChainParams, RpcL1Source, build_genesis};
use anyhow::Result;
use std::time::Duration;
use tempfile::TempDir;
use url::Url;

/// Owns only consensus resources; it never plants storage or advances L1 checkpoints.
pub struct ContractConsensus {
    /// Live stock CometBFT endpoint.
    pub cmt: CmtClient,
    app: AppNode,
    signer: SignerNode,
    docker: DockerEnv,
    _tmp: TempDir,
    stopped: bool,
}
impl ContractConsensus {
    /// Bootstrap from the deployed registry/Inbox and drive the existing custom-genesis EL.
    pub async fn start(
        l1_http: Url,
        l2: &StandaloneReth,
        params: ChainParams,
        validator: ValidatorKey,
    ) -> Result<Self> {
        let tmp = tempfile::Builder::new().prefix("real-consensus-").tempdir_in("/tmp")?;
        let name = tmp.path().file_name().unwrap().to_string_lossy().into_owned();
        let mut docker = DockerEnv::create(format!("{name}-net")).await?;
        let provider =
            rpc::client::connect_http_with_timeout(l1_http.clone(), Duration::from_secs(10));
        let genesis_doc = build_genesis(&RpcL1Source::new(provider), &params).await?;
        let genesis = genesis_doc.to_json_pretty();
        let app = AppNode::start(AppConfig {
            index: 0,
            reth: RethNode { http: l2.http.clone(), auth: l2.auth.clone() },
            l1_http,
            params,
            jwt: jwt_path()?,
            store_dir: tmp.path().join("app"),
            port: free_port()?,
        })
        .await?;
        let home = tmp.path().join("comet");
        write_home(
            &home,
            &HomeConfig {
                moniker: &name,
                proxy_app: &format!("tcp://host.docker.internal:{}", app.port()),
                timeout_commit_ms: 1000,
                persistent_peers: "",
                genesis_json: &genesis,
                signer_addr: "tcp://0.0.0.0:26659",
                node: &crate::keys::NodeKey::derive("real-node", 0),
            },
        )?;
        let signer = SignerNode::ephemeral(
            tmp.path().join("signer"),
            tmp.path().join("app/checkpoint-trust.sock"),
            genesis_doc.chain_id.clone(),
            &validator,
        )?;
        make_world_writable(&home)?;
        let mount = format!("{}:/cometbft", home.display());
        let user = host_user().await?;
        let image =
            std::env::var("COMETBFT_IMAGE").unwrap_or_else(|_| "cometbft/cometbft:v0.40.0".into());
        docker
            .run(
                &name,
                &[
                    "--add-host",
                    "host.docker.internal:host-gateway",
                    "--user",
                    &user,
                    "-p",
                    "127.0.0.1::26657",
                    "-p",
                    "127.0.0.1::26659",
                    "-v",
                    &mount,
                    "--entrypoint",
                    "cometbft",
                    &image,
                    "start",
                ],
            )
            .await?;
        signer.start(host_port(&name, 26659).await?)?;
        let cmt = CmtClient::new(local_url(host_port(&name, 26657).await?)?);
        let this = Self { cmt, app, signer, docker, _tmp: tmp, stopped: false };
        this.wait_for_height(1).await?;
        Ok(this)
    }
    /// Wait for a genuinely decided Comet height, retaining app/container failure evidence.
    pub async fn wait_for_height(&self, height: u64) -> Result<()> {
        wait_until(
            "real consensus height",
            Duration::from_secs(60),
            Duration::from_millis(100),
            || async {
                check_app_running(self.app.halt(), self.app.exited())?;
                Ok((self.cmt.latest_height().await? >= height).then_some(()))
            },
        )
        .await
    }
    /// Stop Comet before joining the ABCI runtime and deleting its store.
    pub async fn stop(mut self) -> Result<()> {
        self.docker.cleanup().await?;
        self.signer.stop();
        self.app.stop().await;
        self.stopped = true;
        Ok(())
    }
}
impl Drop for ContractConsensus {
    fn drop(&mut self) {
        if !self.stopped {
            eprintln!("real consensus app halt: {:?}", self.app.halt());
            self.signer.dump_logs();
            self.docker.dump_logs();
        }
        self.docker.cleanup_blocking();
        self.signer.stop();
    }
}

/// Classify terminal consensus-app failure before retrying an RPC readiness probe.
fn check_app_running(halt: Option<String>, exited: bool) -> Result<()> {
    if let Some(reason) = halt {
        return Err(crate::wait::Fatal(anyhow::anyhow!("ABCI halted: {reason}")).into());
    }
    if exited {
        return Err(crate::wait::Fatal(anyhow::anyhow!("ABCI stopped on its own")).into());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::wait::Fatal;

    #[test]
    fn terminal_consensus_app_state_is_fatal() {
        for (halt, exited) in [(Some("safety halt".to_owned()), false), (None, true)] {
            let err = check_app_running(halt, exited).expect_err("terminal app failure");
            assert!(err.is::<Fatal>(), "terminal app failures must not be retried: {err}");
        }
        assert!(check_app_running(None, false).is_ok());
    }
}
