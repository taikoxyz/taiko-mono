//! The Etna PoS docker devnet: anvil, alethia-reth and CometBFT containers plus in-process
//! `abci` apps.

use std::{
    fs,
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use abci::{
    AppState, ChainParams, GenesisRecord, RegistryEntry, Schedule, Status, store::STATE_FILE,
};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{B256, U256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, anyhow, ensure};
use rpc::client::{DEFAULT_HTTP_TIMEOUT, connect_http_with_timeout};
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
    /// `forcedInclusionDelay`, in seconds, planted at Inbox slot 282.
    pub forced_inclusion_delay: u64,
    /// `maxAnchorAge`, in seconds, planted at Inbox slot 282.
    pub max_anchor_age: u64,
}

impl Default for DevnetSpec {
    /// One validator, `L = 20`, `EPOCH_LEN_L1 = 10`, `D_MAX = 12`, `MARGIN_V = 2`, 1 s commits,
    /// forced inclusion delay 1 h, maximum anchor age 2 h, fake lander advancing checkpoints.
    fn default() -> Self {
        Self {
            validators: 1,
            initial_validators: 1,
            epoch_len: 20,
            epoch_len_l1: 10,
            d_max: 12,
            margin_v: 2,
            timeout_commit_ms: 1000,
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
        }
    }
}

impl DevnetSpec {
    /// How long a scenario watches a stalled chain to confirm it stays put: three commit
    /// timeouts plus 2 s of slack.
    pub fn stall_hold(&self) -> Duration {
        Duration::from_millis(3 * self.timeout_commit_ms) + Duration::from_secs(2)
    }

    /// Checks the validator counts and indices.
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
    /// The fake lander (stopped first on teardown).
    lander: Lander,
    /// The apps, by validator index.
    apps: Vec<AppNode>,
    /// The CometBFT RPC clients, by validator index.
    cmt: Vec<CmtClient>,
    /// The alethia-reth nodes, by validator index.
    reth: Vec<RethNode>,
    /// anvil provider.
    l1: RootProvider,
    /// The validator keys (the first `initial_validators` form `e_0`).
    keys: Vec<ValidatorKey>,
    /// The chain parameters the apps run with.
    params: ChainParams,
    /// The planted genesis record.
    genesis: GenesisRecord,
    /// Writes L1 state.
    planter: Planter,
    /// The containers and the network.
    docker: DockerEnv,
    /// CometBFT homes and app stores, held only so that they are deleted last, when the
    /// devnet drops.
    _tmp: TempDir,
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
                    lander: b.lander,
                    apps: b.apps,
                    cmt: b.cmt,
                    reth: b.reth,
                    l1: b.l1,
                    keys: b.keys,
                    params: b.params,
                    genesis: b.genesis,
                    planter: b.planter,
                    docker,
                    _tmp: tmp,
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

    /// The app's persisted data directory inside this devnet's temporary workspace.
    pub fn app_data_dir(&self, i: usize) -> PathBuf {
        assert!(i < self.apps.len(), "app index out of range");
        self._tmp.path().join(format!("app-{i}"))
    }

    /// The chain parameters the apps run with.
    pub fn params(&self) -> &ChainParams {
        &self.params
    }

    /// The planted genesis record.
    pub fn genesis(&self) -> &GenesisRecord {
        &self.genesis
    }

    /// The chain's epoch schedule.
    pub fn schedule(&self) -> Schedule {
        Schedule::from_genesis(&self.genesis)
    }

    /// The validator keys; the first `initial_validators` form the genesis committee.
    pub fn keys(&self) -> &[ValidatorKey] {
        &self.keys
    }

    /// The registry entry the devnet plants for validator `i` (10 TAIKO, always active).
    pub fn registry_entry(&self, i: usize) -> RegistryEntry {
        registry_entry(self.keys[i].pubkey(), U256::from(VALIDATOR_STAKE))
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
        connect_http_with_timeout(self.l2_http(i), DEFAULT_HTTP_TIMEOUT)
    }

    /// Returns a real Engine client after the validator app has stopped.
    pub fn rpc_engine(&self, i: usize) -> Result<abci::RpcEngine> {
        self.apps[i].rpc_engine()
    }

    /// Builds an isolated app over a test-owned saved parent and Engine adapter.
    pub fn detached_app<E: abci::Engine>(
        &self,
        i: usize,
        store: abci::Store,
        engine: E,
    ) -> Result<abci::App<abci::RpcL1Source, E>> {
        self.apps[i].detached_app(store, engine)
    }

    /// The hashes of blocks `1..=head` of alethia-reth `i`.
    pub async fn l2_block_hashes(&self, i: usize, head: u64) -> Result<Vec<B256>> {
        let l2 = self.l2_provider(i);
        let mut hashes = Vec::new();
        for h in 1..=head {
            let block = l2
                .get_block_by_number(BlockNumberOrTag::Number(h))
                .await?
                .with_context(|| format!("L2 block {h} missing on alethia-reth {i}"))?;
            hashes.push(block.header.hash);
        }
        Ok(hashes)
    }

    /// The docker container name of CometBFT node `i`.
    pub fn cmt_container(&self, i: usize) -> String {
        format!("abci-{}-cmt-{i}", self.id)
    }

    /// Whether CometBFT node `i`'s container is running. An ABCI disconnect alone does not
    /// guarantee exit: the pinned socket client can leave consensus waiting during shutdown.
    pub async fn cmt_running(&self, i: usize) -> Result<bool> {
        let name = self.cmt_container(i);
        Ok(docker(&["inspect", "-f", "{{.State.Running}}", &name]).await? == "true")
    }

    /// Stops CometBFT before the app, keeping ABCI available while consensus drains.
    /// Docker grants ten seconds before SIGKILL, so an already disconnected or unresponsive
    /// Comet process cannot hold the fixture open indefinitely. The app is also stopped when
    /// Docker reports an error; callers must not read or replace its store until this succeeds.
    pub async fn node_stop(&mut self, i: usize) -> Result<()> {
        let name = self.cmt_container(i);
        let stopped = docker(&["stop", "--time", "10", &name]).await;
        self.app_stop(i).await;
        stopped?;
        let exit = docker(&["inspect", "--format", "{{.State.ExitCode}}", &name]).await?;
        if exit == "137" {
            tracing::warn!(node = i, container = %name, "CometBFT stopped with SIGKILL; inspect its shutdown logs");
        }
        Ok(())
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

    /// The L1 state planter.
    pub fn planter(&self) -> &Planter {
        &self.planter
    }

    /// Pauses the fake lander: `lastCheckpoint` stops moving. Returns once a
    /// landing already in flight has been mined, so L1 holds the frozen values.
    pub async fn lander_pause(&self) {
        self.lander.pause().await;
    }

    /// Resumes the fake lander.
    pub fn lander_resume(&self) {
        self.lander.resume();
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
    /// ABCI connections. This intentionally models an app crash; CometBFT may remain stuck
    /// after the disconnect. Use [`Devnet::node_stop`] for controlled shutdown and before
    /// restarting the pair. A no-op when the app is not running.
    pub async fn app_stop(&mut self, i: usize) {
        self.apps[i].stop().await;
    }

    /// Starts the stopped app `i` again with the same store directory and port; returns once it
    /// listens.
    pub async fn app_start(&mut self, i: usize) -> Result<()> {
        self.apps[i].launch().await
    }

    /// Crash-replays validator `i` after its app state is lost; returns the state it had
    /// persisted and the state the replay rebuilt.
    ///
    /// Pauses the fake lander (freezing `lastCheckpoint`), stops app `i`, waits for CometBFT node
    /// `i` to stop through the bounded supervisor, reads the app's state file and moves it aside
    /// (`abci-state.saved.json`), then starts the app and CometBFT again: the app starts
    /// without state, so the handshake replays every block from `InitChain` on through a
    /// `FinalizeBlock` without a `ProcessProposal` verdict. Once node `i` is back at the old
    /// head, the rebuilt state is read and the EL's blocks `1..=` the old head must be
    /// unchanged; the lander then resumes and node `i` must commit three blocks past the old
    /// head.
    pub async fn replay_after_state_loss(&mut self, i: usize) -> Result<(AppState, AppState)> {
        self.lander_pause().await;
        self.app_stop(i).await;
        self.node_stop(i).await?;
        let file = self.app_data_dir(i).join(STATE_FILE);
        let before: AppState = serde_json::from_slice(&fs::read(&file)?)?;
        let old_head = before.last_height;
        let old_hashes = self.l2_block_hashes(i, old_head).await?;
        fs::rename(&file, self.app_data_dir(i).join("abci-state.saved.json"))?;
        ensure!(!file.exists(), "app {i} would start with a state file");

        self.app_start(i).await?;
        self.cmt_restart(i).await?;
        self.wait_for_height(i, old_head, Duration::from_secs(60)).await?;
        let restored: AppState = serde_json::from_slice(&fs::read(&file)?)?;
        ensure!(
            restored.last_height >= old_head,
            "app {i} replayed to {}, below its old head {old_head}",
            restored.last_height
        );
        ensure!(
            self.l2_block_hashes(i, old_head).await? == old_hashes,
            "alethia-reth {i} changed below the old head {old_head}"
        );
        self.lander_resume();
        self.wait_for_height(i, old_head + 3, Duration::from_secs(60)).await?;
        Ok((before, restored))
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
    /// timeout, or at once when an app halts or its thread exits on its own (an app the test
    /// stopped with [`Devnet::app_stop`] does not count); on failure it first prints each app's
    /// halt reason and the tail of every container's log.
    pub async fn wait_for_height(&self, i: usize, h: u64, timeout: Duration) -> Result<u64> {
        let what = format!("CometBFT node {i} at height {h}");
        wait_until(&what, timeout, POLL, || async move {
            for (j, app) in self.apps.iter().enumerate() {
                if let Some(reason) = app.halt() {
                    return Err(Fatal(anyhow!("app {j} halted: {reason}")).into());
                }
                if app.exited() {
                    return Err(Fatal(anyhow!("app {j} stopped on its own")).into());
                }
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

    /// Stops the devnet: the lander, each Comet/app pair, then every container and network; the
    /// temporary directories go when `self` drops. Only a successful stop spares the drop's
    /// diagnostics.
    pub async fn stop(mut self) -> Result<()> {
        self.lander.stop();
        for i in 0..self.apps.len() {
            self.node_stop(i).await?;
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
