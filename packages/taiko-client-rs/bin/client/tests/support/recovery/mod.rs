//! Real contracts and the actual recovery commands: `prepare`, `install`, then an operator-style
//! start of the app, the supervisor or stock Comet, and the lander. No fabricated RPC or store.
pub mod full_node;
pub mod linux;
pub mod process;
use self::process::Process;
use crate::contracts_support::{
    ContractFixture,
    contracts::{EtnaInbox, IEtnaInbox, transact, view},
};
use abci::ChainParams;
use alloy::{primitives::aliases::U48, sol_types::SolCall};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use serde_json::Value;
use std::{
    fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    time::Duration,
};
use test_harness::{CmtClient, ContractConsensus, DEV_KEY, mine_l1_blocks};
use url::Url;

pub const CLIENT: &str = env!("CARGO_BIN_EXE_taiko-client");
pub fn package() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..").canonicalize().unwrap()
}
pub fn write_private(path: &Path, bytes: impl AsRef<[u8]>) -> Result<()> {
    fs::write(path, bytes)?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
    Ok(())
}
/// A native helper from `ETNA_<NAME>_BIN` or the default `just signer` output.
fn helper(variable: &str, name: &str) -> PathBuf {
    std::env::var_os(variable)
        .map(PathBuf::from)
        .unwrap_or_else(|| package().join("target/etna-signer").join(name))
}

/// A started node whose liveness and logs the waits check.
pub trait Liveness {
    fn running(&mut self) -> Result<()>;
    fn output(&self) -> String;
}
impl Liveness for Process {
    fn running(&mut self) -> Result<()> {
        Process::running(self)
    }
    fn output(&self) -> String {
        Process::output(self)
    }
}

/// The stores `install` wrote.
pub struct Installed {
    pub home: PathBuf,
    pub app: PathBuf,
}
impl Installed {
    /// The installed Comet config.
    pub fn config(&self) -> Result<toml::Table> {
        Ok(toml::from_str(&fs::read_to_string(self.home.join("config/config.toml"))?)?)
    }
    /// The installed genesis chain ID, the supervisor's `ETNA_CHAIN_ID`.
    pub fn chain_id(&self) -> Result<String> {
        let doc: abci::GenesisDoc =
            serde_json::from_slice(&fs::read(self.home.join("config/genesis.json"))?)?;
        Ok(doc.chain_id)
    }
}

/// A recovered node the operator started: the app, then the supervisor (validator) or stock
/// Comet (full node), then the optional lander (START-10-6).
pub struct RecoveredNode {
    app: Process,
    consensus: Process,
    lander: Option<Process>,
}
impl RecoveredNode {
    pub fn new(app: Process, consensus: Process, lander: Option<Process>) -> Self {
        Self { app, consensus, lander }
    }
    /// Stops in reverse order: lander, then supervisor or Comet, then the app.
    pub async fn stop(&mut self) -> Result<()> {
        if let Some(lander) = &mut self.lander {
            lander.stop().await?;
        }
        self.consensus.stop().await?;
        self.app.stop().await
    }
}
impl Liveness for RecoveredNode {
    fn running(&mut self) -> Result<()> {
        self.app.running()?;
        self.consensus.running()?;
        self.lander.as_mut().map_or(Ok(()), Process::running)
    }
    fn output(&self) -> String {
        [Some(&self.app), Some(&self.consensus), self.lander.as_ref()]
            .into_iter()
            .flatten()
            .map(Process::output)
            .collect::<Vec<_>>()
            .join("\n")
    }
}

/// One node's recovery inputs: its own endpoints, its stopped Comet home (template and P2P key)
/// and, for a validator, its registered key/HRS directory.
pub struct Commands {
    pub dir: tempfile::TempDir,
    pub journal: PathBuf,
    pub chain: PathBuf,
    pub key: PathBuf,
    pub origin: u64,
    pub params: ChainParams,
    pub l1_http: Url,
    pub l2_http: Url,
    pub l2_auth: Url,
    pub jwt: PathBuf,
    /// The stopped node's Comet home; `install` reads its config.toml and node_key.json.
    pub old_home: PathBuf,
    /// The registered key/HRS directory; `None` for a full node.
    pub signer: Option<PathBuf>,
    /// Whether `start_recovered` also starts the lander on the original journal.
    pub lander: bool,
    /// The recovered app's `--checkpoint-archive-dir`.
    pub archive: Option<PathBuf>,
}
impl Drop for Commands {
    fn drop(&mut self) {
        if std::thread::panicking() {
            self.diagnostics();
        }
    }
}
impl Commands {
    pub fn new(f: &ContractFixture, c: &ContractConsensus) -> Result<Self> {
        Self::for_node(f, c, 0)
    }
    pub fn for_node(f: &ContractFixture, c: &ContractConsensus, index: usize) -> Result<Self> {
        let dir = tempfile::Builder::new().prefix("rc-").tempdir_in("/tmp")?;
        let base = dir.path().canonicalize()?;
        let chain = base.join("chain.toml");
        write_private(
            &chain,
            format!(
                "inbox = \"{}\"\nregistry = \"{}\"\nunsettled_limit = {}\nn_max = {}\nl1_chain_id = \"{}\"\n",
                f.inbox, f.registry, f.params.unsettled_limit, f.params.n_max, f.params.l1_chain_id
            ),
        )?;
        let key = base.join("account.hex");
        write_private(&key, DEV_KEY.to_string())?;
        let journal = base.join("lander");
        fs::create_dir(&journal)?;
        let (l2_http, l2_auth) = c.execution_endpoints(index, &f.l2);
        Ok(Self {
            dir,
            journal,
            chain,
            key,
            origin: 6,
            params: f.params.clone(),
            l1_http: f.anvil.http.clone(),
            l2_http,
            l2_auth,
            jwt: package().join("tests/docker/jwt.hex"),
            old_home: c.comet_home(index).canonicalize()?,
            signer: Some(f.signer_storage.path().join(index.to_string()).canonicalize()?),
            lander: true,
            archive: None,
        })
    }
    pub fn lander_prefix(key: &Path) -> Vec<String> {
        [
            "lander",
            "--signing-key",
            &key.display().to_string(),
            "--max-blocks",
            "6",
            "--sidecar",
            "eip7594",
            "--poll.interval",
            "100",
            "--confirmations",
            "1",
            "--max-fee-per-gas",
            "100000000000",
            "--max-priority-fee-per-gas",
            "1000000000",
            "--max-fee-per-blob-gas",
            "100000000000",
        ]
        .map(String::from)
        .to_vec()
    }
    pub fn old_lander(&self, f: &ContractFixture, c: &CmtClient) -> Result<Process> {
        self.lander_with_execution(f, c, &f.l2.http, &f.l2.auth)
    }

    pub fn lander_with_execution(
        &self,
        f: &ContractFixture,
        c: &CmtClient,
        http: &url::Url,
        auth: &url::Url,
    ) -> Result<Process> {
        let mut args = Self::lander_prefix(&self.key);
        args.extend([
            "--l1.http".into(),
            f.anvil.http.to_string(),
            "--l2.http".into(),
            http.to_string(),
            "--l2.auth".into(),
            auth.to_string(),
            "--jwt.secret".into(),
            self.jwt.display().to_string(),
            "--comet.http".into(),
            c.url().to_string(),
            "--data-dir".into(),
            self.journal.display().to_string(),
            "--chain-config".into(),
            self.chain.display().to_string(),
        ]);
        Process::spawn(Path::new(CLIENT), &args, self.dir.path().join("original-lander.log"))
    }
    /// This node's own endpoint flags, spelled as for `abci`.
    fn endpoints(&self) -> Vec<String> {
        vec![
            "--l1.http".into(),
            self.l1_http.to_string(),
            "--l2.http".into(),
            self.l2_http.to_string(),
            "--l2.auth".into(),
            self.l2_auth.to_string(),
            "--jwt.secret".into(),
            self.jwt.display().to_string(),
        ]
    }
    async fn cli(&self, args: Vec<String>, log: &str) -> Result<String> {
        Process::spawn(Path::new(CLIENT), &args, self.dir.path().join(format!("{log}.log")))?
            .completed()
            .await
    }
    /// `abci-recover status --json` for `plan`, optionally checking `home`.
    pub async fn status(&self, plan: &Path, home: Option<&Path>, log: &str) -> Result<Value> {
        let mut args = vec!["abci-recover".into(), "status".into(), "--plan".into()];
        args.push(plan.display().to_string());
        if let Some(home) = home {
            args.extend(["--home".into(), home.display().to_string()]);
        }
        args.push("--json".into());
        let output = self.cli(args, log).await?;
        output.lines().rev().find_map(|line| serde_json::from_str(line).ok()).context("status JSON")
    }
    /// `prepare` against this node's own L1 and EL, then `status`: the plan keeps the actual
    /// origin c.
    pub async fn prepare_command(&self, generation: u64) -> Result<PathBuf> {
        let plan = self.dir.path().join(format!("plan-g{generation}.json"));
        let mut args = vec!["abci-recover".into(), "prepare".into()];
        args.extend(self.endpoints());
        for (flag, value) in [
            ("--chain-config", self.chain.display().to_string()),
            ("--generation", generation.to_string()),
            ("--out", plan.display().to_string()),
        ] {
            args.extend([flag.into(), value]);
        }
        self.cli(args, &format!("prepare-{generation}")).await?;
        let report = self.status(&plan, None, &format!("status-{generation}")).await?;
        ensure!(
            report["origin_height"] == self.origin && report["generation"] == generation,
            "prepare must retain the actual origin: {report}"
        );
        Ok(plan)
    }
    /// `install` into a new home and app directory, from the stopped node's own Comet config
    /// and P2P key.
    pub async fn install_command(&self, plan: &Path, name: &str) -> Result<Installed> {
        let home = self.dir.path().canonicalize()?.join(format!("comet-{name}"));
        let app = self.dir.path().canonicalize()?.join(format!("app-{name}"));
        let mut args = vec!["abci-recover".to_string(), "install".into()];
        for (flag, value) in [
            ("--plan", plan.to_path_buf()),
            ("--comet-config", self.old_home.join("config/config.toml")),
            ("--node-key", self.old_home.join("config/node_key.json")),
            ("--home", home.clone()),
            ("--app-dir", app.clone()),
        ] {
            args.extend([flag.into(), value.display().to_string()]);
        }
        self.cli(args, &format!("install-{name}")).await?;
        let report = self.status(plan, Some(&home), &format!("installed-{name}")).await?;
        ensure!(report["installed"] == true, "install completes: {report}");
        let installed = Installed { home, app };
        if let Some(key_dir) = &self.signer {
            init_signer_state(key_dir, &installed.chain_id()?)?;
        }
        Ok(installed)
    }
    /// The operator's restart on the installed stores (START-10-6): the app on the new
    /// directory, then the supervisor on the new chain_id (or stock Comet for a full node), then
    /// the lander on its original journal.
    pub async fn start_recovered(
        &self,
        installed: &Installed,
        name: &str,
    ) -> Result<RecoveredNode> {
        let config = installed.config()?;
        let proxy = config["proxy_app"].as_str().context("installed proxy_app")?.to_owned();
        let mut args =
            vec!["abci".into(), "--data-dir".into(), installed.app.display().to_string()];
        args.extend(self.endpoints());
        for (flag, value) in [
            ("--chain-config", self.chain.display().to_string()),
            ("--abci.addr", proxy.clone()),
            ("--fee-recipient", self.params.fee_recipient.to_string()),
        ] {
            args.extend([flag.into(), value]);
        }
        if let Some(archive) = &self.archive {
            args.extend(["--checkpoint-archive-dir".into(), archive.display().to_string()]);
        }
        let log = |role: &str| self.dir.path().join(format!("{name}-{role}.log"));
        let mut app = Process::spawn(Path::new(CLIENT), &args, log("app"))?;
        let address = proxy.trim_start_matches("tcp://").to_owned();
        tokio::time::timeout(Duration::from_secs(150), async {
            loop {
                app.running()?;
                if tokio::net::TcpStream::connect(&address).await.is_ok() {
                    return Ok::<_, anyhow::Error>(());
                }
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        })
        .await
        .context("recovered app never listened")??;
        let comet = std::env::var_os("ETNA_COMET_BIN").context("native stock ETNA_COMET_BIN")?;
        let consensus = match &self.signer {
            Some(key_dir) => {
                let mut supervisor = test_harness::supervisor_command(
                    &installed.home,
                    &installed.app,
                    key_dir,
                    &installed.chain_id()?,
                );
                supervisor
                    .env("ETNA_SIGNER_BIN", helper("ETNA_SIGNER_BIN", "etna-signer"))
                    .env("ETNA_COMET_BIN", &comet);
                Process::spawn_command(supervisor, log("supervisor"))?
            }
            None => Process::spawn(
                Path::new(&comet),
                &["start".into(), "--home".into(), installed.home.display().to_string()],
                log("comet"),
            )?,
        };
        let lander = if self.lander {
            let rpc = config["rpc"]["laddr"].as_str().context("installed rpc.laddr")?;
            let mut args = Self::lander_prefix(&self.key);
            args.extend(self.endpoints());
            for (flag, value) in [
                ("--chain-config", self.chain.display().to_string()),
                ("--comet.http", rpc.replace("tcp://", "http://")),
                ("--data-dir", self.journal.display().to_string()),
            ] {
                args.extend([flag.into(), value]);
            }
            Some(Process::spawn(Path::new(CLIENT), &args, log("lander"))?)
        } else {
            None
        };
        Ok(RecoveredNode::new(app, consensus, lander))
    }
    /// One observation over the recovered app's private trust socket.
    pub async fn private_trust(&self, installed: &Installed) -> Result<Value> {
        use tokio::io::{AsyncBufReadExt, AsyncWriteExt};
        let mut stream =
            tokio::net::UnixStream::connect(installed.app.join("checkpoint-trust.sock")).await?;
        stream.write_all(b"{\"schema_version\":1,\"op\":\"observe\"}\n").await?;
        let mut line = String::new();
        tokio::io::BufReader::new(stream).read_line(&mut line).await?;
        Ok(serde_json::from_str(&line)?)
    }
    pub fn diagnostics(&self) {
        eprintln!("recovery logs: {}", self.dir.path().display());
        if let Ok(files) = fs::read_dir(self.dir.path()) {
            for file in files.flatten() {
                if file.path().extension().is_some_and(|ext| ext == "log") {
                    eprintln!(
                        "{}\n{}",
                        file.path().display(),
                        fs::read_to_string(file.path()).unwrap_or_default()
                    );
                }
            }
        }
    }
}

/// The runbook's signer step for a new generation (RECOV-8.2-1/8.2-5): `etna-signer init-state`
/// for the new chain_id with the same key, state directory and domains log, the old signer
/// stopped. It adds exactly the new chain's zero HRS and log line; every earlier HRS keeps its
/// bytes and is never reused.
pub fn init_signer_state(key_dir: &Path, chain_id: &str) -> Result<()> {
    let log = test_harness::signer_domains_log(key_dir);
    let hrs = key_dir.join("hrs");
    let (log_before, states_before) = (fs::read(&log)?, snapshot(&[&hrs])?);
    test_harness::init_signer_state(key_dir, chain_id)?;
    let mut expected = log_before;
    expected.extend_from_slice(format!("{chain_id}\n").as_bytes());
    ensure!(fs::read(&log)? == expected, "init-state appends exactly the new chain_id");
    let created = test_harness::signer_hrs(key_dir, chain_id);
    let zero: Value = serde_json::from_slice(&fs::read(&created)?)?;
    ensure!(zero == serde_json::json!({"height": "0", "round": 0, "step": 0}), "{zero}");
    let mut states_after = snapshot(&[&hrs])?;
    states_after.retain(|(path, _)| *path != created);
    ensure!(states_after == states_before, "init-state changed an earlier generation's HRS");
    Ok(())
}

/// Every regular file under `dirs` with its bytes, to show later that nothing rewrote them.
pub fn snapshot(dirs: &[&Path]) -> Result<Vec<(PathBuf, Vec<u8>)>> {
    let mut files = vec![];
    let mut pending: Vec<PathBuf> = dirs.iter().map(|dir| dir.to_path_buf()).collect();
    while let Some(dir) = pending.pop() {
        for entry in fs::read_dir(&dir)? {
            let entry = entry?;
            let kind = entry.file_type()?;
            if kind.is_dir() {
                pending.push(entry.path());
            } else if kind.is_file() {
                files.push((entry.path(), fs::read(entry.path())?));
            }
        }
    }
    files.sort();
    Ok(files)
}

pub async fn recover_and_finalize(f: &ContractFixture, generation: u64, c: u64) -> Result<()> {
    recover_with_lists(f, generation, c, vec![], vec![]).await
}

pub async fn recover_with_lists(
    f: &ContractFixture,
    generation: u64,
    c: u64,
    exclusions: Vec<IEtnaInbox::Exclusion>,
    fi_to_clear: Vec<U256>,
) -> Result<()> {
    let p = &f.anvil.provider;
    let nonce = view(p, f.inbox, EtnaInbox::recoveryNonceCall {}, None).await?;
    let now =
        p.get_block_by_number(BlockNumberOrTag::Latest).await?.context("L1 head")?.header.timestamp;
    transact(
        p,
        view(p, f.inbox, EtnaInbox::ownerCall {}, None).await?,
        f.inbox,
        EtnaInbox::recoverCall {
            _expectedGeneration: U48::from(generation),
            _expectedC: U256::from(c),
            _expectedRecoveryNonce: nonce,
            _validUntil: U256::from(now + 3600),
            _exclusions: exclusions,
            _fiToClear: fi_to_clear,
            _rules: U48::ZERO,
        }
        .abi_encode(),
    )
    .await?;
    mine_l1_blocks(p, 3).await?;
    Ok(())
}

pub async fn wait_checkpoint(
    f: &ContractFixture,
    node: &mut impl Liveness,
    height: u64,
) -> Result<()> {
    tokio::time::timeout(Duration::from_secs(120), async {
        loop {
            node.running()?;
            if f.checkpoint().await?.0 >= height {
                return Ok::<_, anyhow::Error>(());
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .with_context(|| format!("landing {height} timed out\n{}", node.output()))?
}
pub async fn wait_committed(c: &CmtClient, height: u64, node: &mut impl Liveness) -> Result<()> {
    tokio::time::timeout(Duration::from_secs(120), async {
        loop {
            node.running()?;
            // Stock blockstore publication precedes the ABCI Commit callback and EL FCU.
            // Wait on the application's durable committed boundary as well.
            if c.latest_height().await.is_ok_and(|current| current >= height) &&
                c.abci_status().await.is_ok_and(|status| status.head >= height)
            {
                return Ok::<_, anyhow::Error>(());
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .with_context(|| format!("stock Comet height {height} timeout\n{}", node.output()))?
}
