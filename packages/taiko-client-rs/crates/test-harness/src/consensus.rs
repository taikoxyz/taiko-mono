//! Real multi-validator consensus over caller-owned deployed contracts and execution genesis.
use crate::{
    CmtClient, StandaloneReth,
    app::{AppConfig, AppNode, free_port},
    boot::{RethNode, host_user, jwt_path, local_url, make_world_writable},
    cometbft::{HomeConfig, write_home},
    docker::{DockerEnv, host_port},
    signer::SignerNode,
    wait_until,
};
use abci::{ChainParams, RpcL1Source, build_genesis};
use anyhow::{Result, ensure};
use std::{path::PathBuf, time::Duration};
use tempfile::TempDir;
use url::Url;

/// Owns only consensus resources; never plants contracts or advances L1 checkpoints.
pub struct ContractConsensus {
    /// First validator RPC used by batch collection.
    pub cmt: CmtClient,
    /// Native RPC for every independent validator.
    pub peers: Vec<CmtClient>,
    /// Exact authenticated genesis bytes shared by all Comet nodes.
    pub genesis_json: String,
    /// Running ABCI apps and their retained stores.
    apps: Vec<AppNode>,
    /// Supervisors using caller-owned registered signing files.
    signers: Vec<SignerNode>,
    /// Owned Comet container names.
    names: Vec<String>,
    /// Independent execution replicas for all peers after the first.
    extra_el: Vec<StandaloneReth>,
    /// Scoped Comet network and container lifecycle.
    docker: DockerEnv,
    /// Retained Comet homes and private app history for this scenario.
    tmp: TempDir,
    /// Suppresses failure diagnostics after clean teardown.
    stopped: bool,
}
impl ContractConsensus {
    /// Start one independently executing validator for each authoritative bootstrap directory.
    pub async fn start(
        l1_http: Url,
        l2: &StandaloneReth,
        params: ChainParams,
        signer_dirs: Vec<PathBuf>,
    ) -> Result<Self> {
        ensure!(!signer_dirs.is_empty(), "validators required");
        let tmp = tempfile::Builder::new().prefix("real-consensus-").tempdir_in("/tmp")?;
        let name = tmp.path().file_name().unwrap().to_string_lossy().into_owned();
        let mut docker = DockerEnv::create(format!("{name}-net")).await?;
        let provider =
            rpc::client::connect_http_with_timeout(l1_http.clone(), Duration::from_secs(10));
        let genesis_doc = build_genesis(&RpcL1Source::new(provider), &params).await?;
        let genesis_json = genesis_doc.to_json_pretty();
        let n = signer_dirs.len();
        let names: Vec<_> = (0..n).map(|i| format!("{name}-{i}")).collect();
        let nodes = crate::node_keys(n);
        let mut apps = Vec::new();
        let mut signers = Vec::new();
        let mut peers = Vec::new();
        let mut extra_el = Vec::new();
        let image = std::env::var("COMETBFT_IMAGE").unwrap_or_else(|_| "cometbft/cometbft:v0.40.0@sha256:0703fb881dac0987c8e41a5810cc09dbcb503bb59ac91705f6936c4b972ac798".into());
        let user = host_user().await?;
        for i in 0..n {
            if i > 0 {
                extra_el.push(StandaloneReth::start().await?);
            }
            let el = if i == 0 { l2 } else { &extra_el[i - 1] };
            let app = AppNode::start(AppConfig {
                index: i,
                reth: RethNode { http: el.http.clone(), auth: el.auth.clone() },
                l1_http: l1_http.clone(),
                params: params.clone(),
                jwt: jwt_path()?,
                store_dir: tmp.path().join(format!("app-{i}")),
                port: free_port()?,
            })
            .await?;
            let home = tmp.path().join(format!("comet-{i}"));
            let persistent_peers = (0..n)
                .filter(|j| *j != i)
                .map(|j| format!("{}@{}:26656", nodes[j].node_id(), names[j]))
                .collect::<Vec<_>>()
                .join(",");
            write_home(
                &home,
                &HomeConfig {
                    moniker: &names[i],
                    proxy_app: &format!("tcp://host.docker.internal:{}", app.port()),
                    timeout_commit_ms: 1000,
                    persistent_peers: &persistent_peers,
                    genesis_json: &genesis_json,
                    signer_addr: "tcp://0.0.0.0:26659",
                    node: &nodes[i],
                },
            )?;
            let signer = SignerNode::existing(
                signer_dirs[i].clone(),
                tmp.path().join(format!("app-{i}/checkpoint-trust.sock")),
                genesis_doc.chain_id.clone(),
            )?
            .supervised(home.clone(), names[i].clone());
            make_world_writable(&home)?;
            let mount = format!("{}:/cometbft", home.display());
            let rpc = format!("127.0.0.1:{}:26657", free_port()?);
            let pv = format!("127.0.0.1:{}:26659", free_port()?);
            docker
                .run(
                    &names[i],
                    &[
                        "--add-host",
                        "host.docker.internal:host-gateway",
                        "--user",
                        &user,
                        "-p",
                        &rpc,
                        "-p",
                        &pv,
                        "-v",
                        &mount,
                        "--entrypoint",
                        "/usr/bin/cometbft",
                        &image,
                        "start",
                        "--home",
                        "/cometbft",
                    ],
                )
                .await?;
            signer.start(host_port(&names[i], 26659).await?)?;
            peers.push(CmtClient::new(local_url(host_port(&names[i], 26657).await?)?));
            apps.push(app);
            signers.push(signer);
        }
        let this = Self {
            cmt: peers[0].clone(),
            peers,
            genesis_json,
            apps,
            signers,
            names,
            extra_el,
            docker,
            tmp,
            stopped: false,
        };
        this.wait_for_height(1).await?;
        Ok(this)
    }

    /// Broadcast the same signed transaction into the isolated peers' real pools.
    pub async fn broadcast_to_peers(&self, raw: &[u8]) -> Result<()> {
        use alloy_provider::Provider;
        for el in &self.extra_el {
            let _ = el.provider.send_raw_transaction(raw).await?;
        }
        Ok(())
    }
    /// Private durable application store for a validator.
    pub fn app_dir(&self, i: usize) -> PathBuf {
        self.tmp.path().join(format!("app-{i}"))
    }
    /// Retained Comet WAL/blockstore directory for a validator.
    pub fn comet_home(&self, i: usize) -> PathBuf {
        self.tmp.path().join(format!("comet-{i}"))
    }
    /// Reads authoritative HRS without modifying it.
    pub fn signing_state(&self, i: usize) -> Result<serde_json::Value> {
        self.signers[i].state()
    }

    /// A controlled restart retains exact authoritative HRS, Comet WAL and app history.
    pub async fn stop_node(&mut self, i: usize) -> Result<()> {
        self.signers[i].stop();
        self.apps[i].stop().await;
        Ok(())
    }
    /// Restarts app then supervised consensus, preserving every storage directory.
    pub async fn restart_node(&mut self, i: usize) -> Result<()> {
        self.apps[i].launch().await?;
        crate::docker::docker(&["start", &self.names[i]]).await?;
        self.signers[i].start(host_port(&self.names[i], 26659).await?)?;
        Ok(())
    }
    /// Waits for the first validator while surfacing terminal app failures.
    pub async fn wait_for_height(&self, height: u64) -> Result<()> {
        wait_until(
            "real consensus height",
            Duration::from_secs(120),
            Duration::from_millis(100),
            || async {
                for app in &self.apps {
                    check_app_running(app.halt(), app.exited())?;
                }
                Ok((self.cmt.latest_height().await? >= height).then_some(()))
            },
        )
        .await
    }
    /// Stops supervisors and apps, then removes this fixture’s Docker resources.
    pub async fn stop(mut self) -> Result<()> {
        for i in 0..self.apps.len() {
            self.stop_node(i).await?;
        }
        self.docker.cleanup().await?;
        for el in self.extra_el.drain(..) {
            el.stop().await?;
        }
        self.stopped = true;
        Ok(())
    }
}
impl Drop for ContractConsensus {
    /// Dumps failures and reaps only resources owned by this fixture.
    fn drop(&mut self) {
        if !self.stopped {
            for app in &self.apps {
                eprintln!("real consensus app halt: {:?}", app.halt());
            }
            for signer in &self.signers {
                signer.dump_logs();
            }
            self.docker.dump_logs();
        }
        for signer in &self.signers {
            signer.stop();
        }
        self.docker.cleanup_blocking();
    }
}

/// Terminal app failures must escape readiness polling rather than appear as transient RPC lag.
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
    #[test]
    fn terminal_consensus_app_state_is_fatal() {
        for (halt, exited) in [(Some("safety halt".to_owned()), false), (None, true)] {
            assert!(check_app_running(halt, exited).unwrap_err().is::<crate::wait::Fatal>());
        }
        assert!(check_app_running(None, false).is_ok());
    }
}
