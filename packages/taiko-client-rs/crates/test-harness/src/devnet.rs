//! The Etna PoS docker devnet: anvil, alethia-reth and CometBFT containers plus in-process
//! `abci` apps (spec §9.2).

use std::{
    path::Path,
    sync::atomic::{AtomicU64, Ordering},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use abci::{ActivationRecord, ChainParams, GenesisDoc, RegistryEntry, Schedule, Status};
use alloy_primitives::U256;
use alloy_provider::RootProvider;
use anyhow::{Result, anyhow, ensure};
use rpc::client::connect_http_with_timeout;
use tempfile::TempDir;
use tracing_subscriber::EnvFilter;
use url::Url;

use crate::{
    app::AppNode,
    boot::{POLL, RPC_TIMEOUT, RethNode, VALIDATOR_STAKE, boot, local_url},
    cometbft::{CmtClient, CmtStatus},
    docker::{DockerEnv, docker, host_port},
    keys::ValidatorKey,
    l1::set_interval_mining,
    lander::Lander,
    planter::{Planter, registry_entry},
    wait::{Fatal, wait_until},
};

/// Shape of a devnet.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DevnetSpec {
    /// Validator keys generated (and nodes started); `>= 1`.
    pub validators: usize,
    /// How many of the first keys form the genesis committee `e_0`; `1..=validators`.
    pub initial_validators: usize,
    /// `L`: epoch length in L2 blocks.
    pub epoch_len: u64,
    /// `EPOCH_LEN_L1`: epoch length in L1 blocks.
    pub epoch_len_l1: u64,
    /// `D_MAX`.
    pub d_max: u64,
    /// `MARGIN_V`.
    pub margin_v: u64,
    /// CometBFT `timeout_commit`, in milliseconds.
    pub timeout_commit_ms: u64,
    /// Whether the fake lander plants committee records from the start (see
    /// [`Devnet::lander_land_committees`]).
    pub land_committees: bool,
}

impl Default for DevnetSpec {
    /// One validator, `L = 20`, `EPOCH_LEN_L1 = 10`, `D_MAX = 12`, `MARGIN_V = 2`, 1 s commits,
    /// committee records landed.
    fn default() -> Self {
        Self {
            validators: 1,
            initial_validators: 1,
            epoch_len: 20,
            epoch_len_l1: 10,
            d_max: 12,
            margin_v: 2,
            timeout_commit_ms: 1000,
            land_committees: true,
        }
    }
}

impl DevnetSpec {
    /// Checks the validator counts.
    fn validate(&self) -> Result<()> {
        ensure!(self.validators >= 1, "a devnet needs at least one validator");
        ensure!(
            (1..=self.validators).contains(&self.initial_validators),
            "initial_validators must be in 1..={}",
            self.validators
        );
        Ok(())
    }
}

/// Installs a `tracing` subscriber honouring `RUST_LOG` (default `info`) once per process.
pub fn init_tracing() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let _ = tracing_subscriber::fmt().with_env_filter(filter).with_test_writer().try_init();
}

/// A running devnet; see the crate docs.
#[derive(Debug)]
pub struct Devnet {
    /// The unique id in every docker name.
    id: String,
    /// The shape it was started with.
    spec: DevnetSpec,
    /// The fake lander (stopped first on teardown).
    lander: Lander,
    /// The apps, by validator index.
    apps: Vec<AppNode>,
    /// The CometBFT RPC clients, by validator index.
    cmt: Vec<CmtClient>,
    /// The alethia-reth nodes, by validator index.
    reth: Vec<RethNode>,
    /// anvil's JSON-RPC URL on the host.
    l1_http: Url,
    /// anvil provider.
    l1: RootProvider,
    /// The validator keys (the first `initial_validators` form `e_0`).
    keys: Vec<ValidatorKey>,
    /// The chain parameters the apps run with.
    params: ChainParams,
    /// The planted activation record.
    activation: ActivationRecord,
    /// The CometBFT genesis.
    genesis: GenesisDoc,
    /// Writes L1 state.
    planter: Planter,
    /// The containers and the network.
    docker: DockerEnv,
    /// CometBFT homes and app stores (deleted last).
    tmp: TempDir,
    /// Whether [`Devnet::stop`] succeeded; otherwise dropping prints the diagnostics.
    stopped: bool,
}

impl Devnet {
    /// Starts a devnet of shape `spec` (see the crate docs). On failure, prints the containers'
    /// logs and removes everything it created.
    pub async fn start(spec: DevnetSpec) -> Result<Self> {
        init_tracing();
        spec.validate()?;
        let id = unique_id();
        let tmp = tempfile::Builder::new().prefix(&format!("abci-{id}-")).tempdir()?;
        let mut docker = DockerEnv::create(format!("abci-{id}")).await?;
        match boot(&id, &spec, &mut docker, tmp.path()).await {
            Ok(b) => {
                tracing::info!(id, network = docker.network(), "devnet started");
                Ok(Self {
                    id,
                    spec,
                    lander: b.lander,
                    apps: b.apps,
                    cmt: b.cmt,
                    reth: b.reth,
                    l1_http: b.l1_http,
                    l1: b.l1,
                    keys: b.keys,
                    params: b.params,
                    activation: b.activation,
                    genesis: b.genesis,
                    planter: b.planter,
                    docker,
                    tmp,
                    stopped: false,
                })
            }
            Err(e) => {
                eprintln!("devnet {id} failed to start: {e:#}");
                docker.dump_logs();
                if let Err(cleanup) = docker.cleanup().await {
                    eprintln!("devnet {id} cleanup: {cleanup:#}");
                }
                Err(e)
            }
        }
    }

    /// The unique id in every docker name of this devnet (`abci-<id>-…`).
    pub fn id(&self) -> &str {
        &self.id
    }

    /// The shape it was started with.
    pub fn spec(&self) -> &DevnetSpec {
        &self.spec
    }

    /// The chain parameters the apps run with.
    pub fn params(&self) -> &ChainParams {
        &self.params
    }

    /// The planted activation record.
    pub fn activation(&self) -> &ActivationRecord {
        &self.activation
    }

    /// The chain's epoch schedule.
    pub fn schedule(&self) -> Schedule {
        Schedule::from_activation(&self.activation)
    }

    /// The CometBFT genesis every node started from.
    pub fn genesis(&self) -> &GenesisDoc {
        &self.genesis
    }

    /// The validator keys; the first `initial_validators` form the genesis committee.
    pub fn keys(&self) -> &[ValidatorKey] {
        &self.keys
    }

    /// The registry entry the devnet plants for validator `i` (10 TAIKO, always active).
    pub fn registry_entry(&self, i: usize) -> RegistryEntry {
        registry_entry(self.keys[i].pubkey(), U256::from(VALIDATOR_STAKE))
    }

    /// anvil's JSON-RPC URL.
    pub fn l1_http(&self) -> Url {
        self.l1_http.clone()
    }

    /// A provider for anvil.
    pub fn l1(&self) -> &RootProvider {
        &self.l1
    }

    /// The public JSON-RPC URL of alethia-reth `i`.
    pub fn l2_http(&self, i: usize) -> Url {
        self.reth[i].http.clone()
    }

    /// A provider for alethia-reth `i`.
    pub fn l2_provider(&self, i: usize) -> RootProvider {
        connect_http_with_timeout(self.l2_http(i))
    }

    /// The RPC URL of CometBFT node `i`.
    pub fn cmt_rpc(&self, i: usize) -> Url {
        self.cmt[i].url()
    }

    /// The docker container name of CometBFT node `i`.
    pub fn cmt_container(&self, i: usize) -> String {
        format!("abci-{}-cmt-{i}", self.id)
    }

    /// Whether CometBFT node `i`'s container is running (it exits when its ABCI connection
    /// breaks).
    pub async fn cmt_running(&self, i: usize) -> Result<bool> {
        let name = self.cmt_container(i);
        Ok(docker(&["inspect", "-f", "{{.State.Running}}", &name]).await? == "true")
    }

    /// Restarts CometBFT node `i`'s container (`docker restart`; it also starts a container that
    /// exited, e.g. after losing its ABCI connection) and waits until its RPC answers again,
    /// i.e. until its handshake with the app (and any block replay) is done. The published RPC
    /// port changes on restart; every clone of [`Devnet::cmt`]`(i)` follows it.
    pub async fn cmt_restart(&self, i: usize) -> Result<()> {
        let name = self.cmt_container(i);
        docker(&["restart", "-t", "10", &name]).await?;
        let url = local_url(host_port(&name, 26657).await?)?;
        self.cmt[i].set_url(url);
        let client = &self.cmt[i];
        wait_until(&format!("{name} RPC after restart"), RPC_TIMEOUT, POLL, || async move {
            Ok(Some(client.latest_height().await?))
        })
        .await
        .map(drop)
    }

    /// The RPC client of CometBFT node `i`.
    pub fn cmt(&self, i: usize) -> &CmtClient {
        &self.cmt[i]
    }

    /// The devnet's temporary directory: `app-<i>/` holds app `i`'s store, `cmt-<i>/` CometBFT
    /// node `i`'s home.
    pub fn tmp_dir(&self) -> &Path {
        self.tmp.path()
    }

    /// The L1 state planter.
    pub fn planter(&self) -> &Planter {
        &self.planter
    }

    /// Pauses the fake lander: `lastCheckpoint` and `committee[·]` stop moving.
    pub fn lander_pause(&self) {
        self.lander.set_paused(true);
    }

    /// Resumes the fake lander.
    pub fn lander_resume(&self) {
        self.lander.set_paused(false);
    }

    /// Makes the fake lander plant (`true`) or skip (`false`) the `committee[t]` records while
    /// it keeps moving `lastCheckpoint`; skipped records are planted once re-enabled.
    pub fn lander_land_committees(&self, land: bool) {
        self.lander.set_land_committees(land);
    }

    /// The reason of app `i`'s safety halt, if it halted.
    pub fn app_halt(&self, i: usize) -> Option<String> {
        self.apps[i].halt()
    }

    /// Whether app `i` is running.
    pub fn app_running(&self, i: usize) -> bool {
        self.apps[i].is_running()
    }

    /// Stops app `i` completely: its runtime shuts down, closing the listener and CometBFT's
    /// ABCI connections (CometBFT node `i` then exits; see [`Devnet::cmt_restart`]). A no-op when
    /// it is not running.
    pub async fn app_stop(&mut self, i: usize) {
        self.apps[i].stop().await;
    }

    /// Starts the stopped app `i` again with the same store directory and port; returns once it
    /// listens.
    pub async fn app_start(&mut self, i: usize) -> Result<()> {
        self.apps[i].launch().await
    }

    /// Pauses anvil's interval mining: no L1 block (hence no new `finalized`) until
    /// [`Devnet::l1_resume`]. Planting with [`Planter::next_block`] resumes it on commit.
    pub async fn l1_pause(&self) -> Result<()> {
        set_interval_mining(&self.l1, 0).await
    }

    /// Resumes anvil's interval mining at one block per second.
    pub async fn l1_resume(&self) -> Result<()> {
        set_interval_mining(&self.l1, 1).await
    }

    /// Waits until CometBFT node `i` committed height `h`; returns the height reached. Fails on
    /// timeout, or at once when app `i` halts; on failure it first prints each app's halt reason
    /// and the tail of every container's log.
    pub async fn wait_for_height(&self, i: usize, h: u64, timeout: Duration) -> Result<u64> {
        let what = format!("CometBFT node {i} at height {h}");
        wait_until(&what, timeout, POLL, || async move {
            if let Some(reason) = self.app_halt(i) {
                return Err(Fatal(anyhow!("app {i} halted: {reason}")).into());
            }
            let height = self.cmt[i].latest_height().await?;
            Ok((height >= h).then_some(height))
        })
        .await
        .inspect_err(|e| {
            eprintln!("devnet {}: {e:#}", self.id);
            self.print_statuses();
            self.docker.dump_logs();
        })
    }

    /// CometBFT node `i`'s latest height and validator set.
    pub async fn cmt_status(&self, i: usize) -> Result<CmtStatus> {
        self.cmt[i].status().await
    }

    /// App `i`'s `/status`, queried through its CometBFT node.
    pub async fn abci_status(&self, i: usize) -> Result<Status> {
        self.cmt[i].abci_status().await
    }

    /// Prints `docker logs --tail 200` of every container (a later drop without a successful
    /// [`Devnet::stop`] does not print them again).
    pub fn dump_logs(&self) {
        self.docker.dump_logs();
    }

    /// Stops the devnet: the lander and the apps, then every container and the network; the
    /// temporary directories go when `self` drops. Only a successful stop spares the drop's
    /// diagnostics.
    pub async fn stop(mut self) -> Result<()> {
        self.lander.stop();
        for app in &mut self.apps {
            app.stop().await;
        }
        self.docker.cleanup().await?;
        self.stopped = true;
        Ok(())
    }

    /// Prints each app's halt reason (best effort, for failure diagnostics).
    fn print_statuses(&self) {
        for (i, app) in self.apps.iter().enumerate() {
            if let Some(reason) = app.halt() {
                eprintln!("app {i} safety halt: {reason}");
            }
        }
    }
}

impl Drop for Devnet {
    /// Stops the lander, then, when [`Devnet::stop`] did not succeed (the scenario panicked or
    /// returned an error), prints each app's halt reason and the tail of every container's log
    /// while everything still runs, unless a failed [`Devnet::wait_for_height`] or
    /// [`Devnet::dump_logs`] already printed the logs. The apps then stop as they drop (joining
    /// their threads), the docker environment removes the containers and the temporary
    /// directories go.
    fn drop(&mut self) {
        self.lander.stop();
        if !self.stopped && !self.docker.logs_dumped() {
            eprintln!("devnet {} dropped without a successful stop()", self.id);
            self.print_statuses();
            self.docker.dump_logs();
        }
    }
}

/// A process-unique, run-unique id for docker names.
fn unique_id() -> String {
    static NEXT: AtomicU64 = AtomicU64::new(0);
    let nanos = SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.subsec_nanos());
    format!("{:08x}{}", nanos ^ std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed))
}
