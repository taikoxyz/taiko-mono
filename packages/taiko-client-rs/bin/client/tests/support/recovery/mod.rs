//! Real contracts and actual recovery command inputs; no fabricated RPC or database state.
pub mod full_node;
pub mod linux;
pub mod process;
use self::process::Process;
use crate::contracts_support::{
    ContractFixture,
    contracts::{EtnaInbox, IEtnaInbox, transact, view},
};
use alloy::{primitives::aliases::U48, sol_types::SolCall};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use serde_json::{Value, json};
use std::{
    fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    time::Duration,
};
use test_harness::{CmtClient, ContractConsensus, DEV_KEY, mine_l1_blocks};

pub const CLIENT: &str = env!("CARGO_BIN_EXE_taiko-client");
pub fn package() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..").canonicalize().unwrap()
}
fn executable(program: &Path, argv: Vec<String>) -> Value {
    json!({"program": program, "argv": argv, "env": {}})
}
pub fn write_private(path: &Path, bytes: impl AsRef<[u8]>) -> Result<()> {
    fs::write(path, bytes)?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
    Ok(())
}

pub struct Commands {
    pub dir: tempfile::TempDir,
    pub profile: PathBuf,
    pub root: PathBuf,
    pub journal: PathBuf,
    pub chain: PathBuf,
    pub key: PathBuf,
    pub origin: u64,
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
        let root = base.join("recovery");
        let profile = base.join("profile.toml");
        let journal = base.join("lander");
        fs::create_dir(&journal)?;
        let signer = f.signer_storage.path().join(index.to_string()).canonicalize()?;
        let (l2_http, l2_auth) = c.execution_endpoints(index, &f.l2);
        let pkg = package();
        let python = std::process::Command::new("python3")
            .args(["-c", "import sys; print(sys.executable)"])
            .output()?;
        ensure!(python.status.success(), "Python3 supervisor interpreter");
        let python = PathBuf::from(String::from_utf8(python.stdout)?.trim());
        let comet = std::env::var_os("ETNA_COMET_BIN").context("native stock ETNA_COMET_BIN")?;
        let value = json!({
            "schema":1, "role":"validator", "l1_chain_id":f.params.l1_chain_id,
            "l2_chain_id":f.params.l2_chain_id, "chain_config":chain,
            "l1_http":f.anvil.http, "l2_http":l2_http, "l2_auth":l2_auth,
            "jwt_secret":pkg.join("tests/docker/jwt.hex"),
            "app_data_dir":c.app_dir(index).canonicalize()?, "comet_home":c.comet_home(index).canonicalize()?,
            "app":executable(Path::new(CLIENT), vec!["abci".into()]),
            "comet":executable(Path::new(&comet), vec!["start".into()]), "peers":[],
            "installation_parent":base,
            "inspector":executable(&pkg.join("target/etna-signer/etna-comet-inspect"), vec![]),
            "signer":{"key":signer.join("key.json"), "state":signer.join("state.json"),
                "authority":signer.join("authority"),
                "executable":executable(&pkg.join("target/etna-signer/etna-signer"),vec![]),
                "supervisor":executable(&python,vec![pkg.join("script/etna_validator.py").display().to_string()])},
            "lander":{"data_dir":journal, "executable":executable(Path::new(CLIENT), Self::lander_prefix(&key))}
        });
        write_private(&profile, toml::to_string(&value)?)?;
        Ok(Self { dir, profile, root, journal, chain, key, origin: 6 })
    }
    fn lander_prefix(key: &Path) -> Vec<String> {
        [
            "lander",
            "--signing-key",
            &key.display().to_string(),
            "--max-blocks",
            "6",
            "--max-blobs",
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
            package().join("tests/docker/jwt.hex").display().to_string(),
            "--comet.http".into(),
            c.url().to_string(),
            "--data-dir".into(),
            self.journal.display().to_string(),
            "--chain-config".into(),
            self.chain.display().to_string(),
        ]);
        Process::spawn(Path::new(CLIENT), &args, self.dir.path().join("original-lander.log"))
    }
    pub async fn prepare_command(&self, generation: u64) -> Result<String> {
        let args = vec![
            "abci-recover".into(),
            "prepare".into(),
            "--profile".into(),
            self.profile.display().to_string(),
            "--root".into(),
            self.root.display().to_string(),
            "--generation".into(),
            generation.to_string(),
            "--json".into(),
        ];
        let mut process = Process::spawn(
            Path::new(CLIENT),
            &args,
            self.dir.path().join(format!("prepare-{generation}.log")),
        )?;
        let output = process.completed().await?;
        let report: Value = output
            .lines()
            .rev()
            .find_map(|line| serde_json::from_str(line).ok())
            .context("prepare JSON")?;
        ensure!(
            report["origin_height"] == self.origin,
            "prepare must retain actual origin: {report}"
        );
        Ok(report["plan_id"].as_str().context("plan ID")?.into())
    }
    pub fn activate_command(&self, plan: &str, name: &str) -> Result<Process> {
        let args = vec![
            "abci-recover".into(),
            "activate".into(),
            "--profile".into(),
            self.profile.display().to_string(),
            "--root".into(),
            self.root.display().to_string(),
            "--plan".into(),
            plan.into(),
        ];
        Process::spawn(
            Path::new(CLIENT),
            &args,
            self.dir.path().join(format!("activate-{name}.log")),
        )
    }
    pub fn plan_dir(&self, id: &str) -> PathBuf {
        self.root.join("plans").join(&id.trim_start_matches("0x")[..16])
    }
    pub async fn private_trust(&self, plan: &str) -> Result<Value> {
        use tokio::io::{AsyncBufReadExt, AsyncWriteExt};
        let mut stream =
            tokio::net::UnixStream::connect(self.plan_dir(plan).join("app/checkpoint-trust.sock"))
                .await?;
        stream.write_all(b"{\"schema_version\":2,\"op\":\"observe\"}\n").await?;
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
    process: &mut Process,
    height: u64,
) -> Result<()> {
    tokio::time::timeout(Duration::from_secs(120), async {
        loop {
            process.running()?;
            if f.checkpoint().await?.0 >= height {
                return Ok::<_, anyhow::Error>(());
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .with_context(|| format!("landing {height} timed out\n{}", process.output()))?
}
pub async fn wait_committed(c: &CmtClient, height: u64, process: &mut Process) -> Result<()> {
    tokio::time::timeout(Duration::from_secs(120), async {
        loop {
            process.running()?;
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
    .with_context(|| format!("stock Comet height {height} timeout\n{}", process.output()))?
}
