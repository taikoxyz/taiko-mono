//! Real CLI export and import. The published stores then run as ordinary ones: a normal EL on
//! `ready/el`, plain `abci` on `ready/app` and stock Comet on `ready/comet` (DATA-5.4-5/6).
use super::recovery::{
    CLIENT, Commands, Installed, package, process::Process, wait_checkpoint, wait_committed,
};
use crate::contracts_support::ContractFixture;
use abci::{Engine, ExecutionBlock, PayloadVerdict, RpcEngine};
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use serde_json::{Value, json};
use std::{
    fs,
    net::TcpListener,
    path::{Path, PathBuf},
    time::Duration,
};
use test_harness::{CmtClient, ContractConsensus, mine_l1_blocks, set_interval_mining};
use url::Url;

fn url(p: u16) -> Url {
    format!("http://127.0.0.1:{p}").parse().unwrap()
}
fn port() -> Result<u16> {
    Ok(TcpListener::bind("127.0.0.1:0")?.local_addr()?.port())
}
fn binary(name: &str, fallback: &str) -> Result<PathBuf> {
    Ok(std::env::var_os(name)
        .map(PathBuf::from)
        .unwrap_or_else(|| package().join("target/etna-signer").join(fallback))
        .canonicalize()?)
}
async fn el(
    bin: &Path,
    dir: &Path,
    chain: &Path,
    base: &Path,
    label: &str,
) -> Result<(Process, Url, Url, RpcEngine)> {
    let hp = port()?;
    let ap = port()?;
    let jwt = package().join("tests/docker/jwt.hex");
    let args = [
        "node",
        "--chain",
        chain.to_str().unwrap(),
        "--datadir",
        dir.to_str().unwrap(),
        "--db.growth-step",
        "4MB",
        "--devnet-etna-timestamp",
        "0",
        "--http",
        "--http.addr",
        "127.0.0.1",
        "--http.api",
        "eth,net,debug",
        "--http.port",
        &hp.to_string(),
        "--authrpc.port",
        &ap.to_string(),
        "--authrpc.jwtsecret",
        jwt.to_str().unwrap(),
        "--disable-discovery",
        "--port",
        "0",
        "--ipcdisable",
    ]
    .map(str::to_owned);
    let mut p = Process::spawn(bin, &args, base.join(format!("{label}.log")))?;
    let engine = RpcEngine::new(url(hp), url(ap), &jwt, Duration::from_secs(3))?;
    tokio::time::timeout(Duration::from_secs(90), async {
        loop {
            p.running()?;
            if engine.check_capabilities().await.is_ok() {
                return Ok::<_, anyhow::Error>(())
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await??;
    Ok((p, url(hp), url(ap), engine))
}
/// One `abci-import` command. Its stderr, with the diagnostics of the helpers it runs, is kept in
/// `<tag>.log`.
async fn cli(base: &Path, tag: &str, args: &[String]) -> Result<Value> {
    let started = std::time::Instant::now();
    let out = tokio::process::Command::new(CLIENT).arg("abci-import").args(args).output().await?;
    fs::write(base.join(format!("{tag}.log")), &out.stderr)?;
    eprintln!(
        "checkpoint_cli phase={tag} seconds={:.3} exit={}",
        started.elapsed().as_secs_f64(),
        out.status
    );
    ensure!(out.status.success(), "{tag}: {}", String::from_utf8_lossy(&out.stderr));
    Ok(serde_json::from_slice(&out.stdout)?)
}

/// The latest checkpoint, imported twice from one package (ACC §7.6, §7.7). Root A: a SIGKILL
/// mid-EL-install publishes nothing and the rerun discards the stage (DATA-5.4-5); stock P2P from
/// s + 1; an EL and app restart keeps the floor and the tip (DATA-5.4-6). Root B: the first post-s
/// FI skip, a cold replay over the retained post-s parent and the missing-parent-state halt. Its
/// checks drive ABCI by hand, so stock Comet cannot share its store.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_import_latest_full_node_restarts_forced_skips_and_retries() -> Result<()> {
    scenario(Scenario::Latest).await
}

/// An older checkpoint (s = 6, target 12) exported with the archived validator-state preimage
/// (DATA-5.4-3, SYNC-9-5c). The import leaves key, HRS, WAL and authority unchanged (DATA-5.4-7);
/// the supervisor on `ready` proposes in a later round, and the chain lands its block.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn registered_checkpoint_older_signs_proposes_and_lands() -> Result<()> {
    scenario(Scenario::RegisteredOlder).await
}

/// s = o (DATA-5.4-1): the import installs the original genesis and no app state, and plain
/// `abci` runs stock InitChain.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_import_fixed_origin_runs_original_stock_init_chain() -> Result<()> {
    scenario(Scenario::FixedOrigin).await
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Scenario {
    Latest,
    RegisteredOlder,
    FixedOrigin,
}

async fn scenario(kind: Scenario) -> Result<()> {
    test_harness::init_tracing();
    let registered = kind == Scenario::RegisteredOlder;
    let count = if registered { 4 } else { 1 };
    // U = 6 holds the latest source at 6 until it lands; both FI entries then come due after s.
    let unsettled = if kind == Scenario::Latest { 6 } else { 120 };
    let epoch_len = if registered { 6 } else { 8 };
    let f = ContractFixture::deploy_config(count, unsettled, epoch_len).await?;
    set_interval_mining(&f.anvil.provider, 1).await?;
    let dirs = (0..count).map(|i| f.signer_storage.path().join(i.to_string())).collect();
    let mut c =
        ContractConsensus::start_native(f.anvil.http.clone(), &f.l2, f.params.clone(), dirs)
            .await?;
    let commands = Commands::new(&f, &c)?;
    let result = match kind {
        Scenario::Latest => latest(&f, &mut c, &commands).await,
        Scenario::RegisteredOlder => registered_older(&f, &mut c, &commands).await,
        Scenario::FixedOrigin => fixed_origin(&f, &c, &commands).await,
    };
    if result.is_err() {
        commands.diagnostics();
    }
    c.stop().await?;
    result
}

async fn latest(f: &ContractFixture, c: &mut ContractConsensus, commands: &Commands) -> Result<()> {
    let s = 6;
    let base = commands.dir.path().canonicalize()?;
    c.wait_for_height(s).await?;
    forced::enqueue(f).await?;
    land(f, c, commands, s).await?;
    let blocks = source_blocks(&c.cmt, s).await?;
    let genesis = c.comet_home(0).canonicalize()?.join("config/genesis.json");
    let export =
        Export { s, comet_genesis: &genesis, recovery_bootstrap: None, validator_state: None };
    let x =
        import_fixture(f, c, commands, &base, &blocks, &c.comet_home(0), &c.cmt, export).await?;
    // The source decides both FI skips (s + 1, s + 2) before its only validator stops.
    c.wait_for_height(s + 3).await?;
    c.stop_node(0).await?;
    let hrs = c.signing_state_path(0);
    let wal = c.comet_home(0).join("data/cs.wal/wal");
    let signer = || -> Result<_> { Ok((fs::read(&hrs)?, fs::read(&wal)?)) };
    let original = signer()?;
    let a = base.join("import-a");
    crash_mid_install(f, commands, &x, &a).await?;
    ensure!(signer()? == original, "an interrupted import changed HRS or WAL");
    let ready = import(f, commands, &x, &a, "import-a").await?;
    ensure!(ready == json!({"phase": "ready", "generation": 0, "execution_floor": s}), "{ready}");
    ensure!(
        !a.join("ready/app").join(CRASH_LEFTOVER).exists(),
        "the rerun published the interrupted stage"
    );
    // A lost acknowledgement: the next run answers from the published stores.
    ensure!(import(f, commands, &x, &a, "import-a-again").await? == ready);
    let b = base.join("import-b");
    ensure!(import(f, commands, &x, &b, "import-b").await? == ready);
    ensure!(signer()? == original, "the import changed HRS or WAL");
    c.restart_node(0).await?;
    let run = Follow { s, target: s, generation: 0, floor: Some(s), restart: true };
    follow(f, c, commands, &x, &a, run).await?;
    forced::replay(f, c, commands, &x, &b, s).await
}

async fn registered_older(
    f: &ContractFixture,
    c: &mut ContractConsensus,
    commands: &Commands,
) -> Result<()> {
    let (s, target) = (6, 12);
    let base = commands.dir.path().canonicalize()?;
    c.wait_for_height(s).await?;
    // The app's sidecar is checksummed; its query answers the raw preimage the export takes.
    let preimage = tokio::time::timeout(Duration::from_secs(20), async {
        loop {
            // A transient RPC error keeps polling, as a refusal does.
            if let Some(preimage) = c.cmt.abci_query("/val_state/6").await.ok().flatten() {
                return preimage
            }
            tokio::time::sleep(Duration::from_millis(50)).await
        }
    })
    .await
    .context("source app must commit preimage 6")?;
    let archived = base.join("archived-val-state.bin");
    fs::write(&archived, preimage).context("archive live validator-state preimage")?;
    land(f, c, commands, target).await?;
    // Node 0 refuses 6 once its floor passes it, so the export needs the archived preimage.
    tokio::time::timeout(Duration::from_secs(90), async {
        while !matches!(c.cmt.abci_answer("/val_state/6").await, Ok(Err(_))) {
            tokio::time::sleep(Duration::from_millis(100)).await
        }
    })
    .await?;
    let blocks = source_blocks(&c.cmt, s).await?;
    let genesis = c.comet_home(0).canonicalize()?.join("config/genesis.json");
    let export = Export {
        s,
        comet_genesis: &genesis,
        recovery_bootstrap: None,
        validator_state: Some(&archived),
    };
    // Node 0 stops before the import, so the imported node peers with node 1.
    let x = import_fixture(f, c, commands, &base, &blocks, &c.comet_home(0), &c.peers[1], export)
        .await?;
    let mut config: toml::Table = toml::from_str(&fs::read_to_string(&x.config)?)?;
    config.insert("priv_validator_laddr".into(), "unix://run/signer.sock".into());
    fs::write(&x.config, toml::to_string(&config)?)?;
    c.stop_node(0).await?;
    let dir = f.signer_storage.path().join("0").canonicalize()?;
    let hrs = c.signing_state_path(0);
    let wal = c.comet_home(0).join("data/cs.wal/wal");
    let original = (fs::read(&hrs)?, fs::read(&wal)?);
    // The independent quorum can continue while the old validator is stopped. Wait for its
    // absent proposer turn so at least one original post-s decision uses a later round.
    let mut h =
        serde_json::from_slice::<Value>(&original.0)?["height"].as_str().unwrap().parse::<u64>()? +
            1;
    tokio::time::timeout(Duration::from_secs(90), async {
        loop {
            if c.peers[1].latest_height().await? > h {
                if c.peers[1].commit_round(h).await? > 0 {
                    break;
                }
                h += 1;
            } else {
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }
        Ok::<_, anyhow::Error>(())
    })
    .await
    .context("independent source must decide a nonzero round")??;
    let signer_files = [dir.join("key.json"), test_harness::signer_domains_log(&dir)];
    let before: Vec<_> = signer_files.iter().map(fs::read).collect::<std::io::Result<_>>()?;
    let root = base.join("import");
    let ready = import(f, commands, &x, &root, "import").await?;
    ensure!(ready == json!({"phase": "ready", "generation": 0, "execution_floor": s}), "{ready}");
    // DATA-5.4-7: signer state is never imported, and the import touches none of it.
    ensure!((fs::read(&hrs)?, fs::read(&wal)?) == original);
    for (path, bytes) in signer_files.iter().zip(&before) {
        ensure!(fs::read(path)? == *bytes, "checkpoint import changed {}", path.display());
    }
    registered_follow(f, c, commands, &x, &root, s, target, &original).await
}

/// s = o (DATA-5.4-1): no app state is installed, and InitChain starts from the original genesis.
async fn fixed_origin(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
) -> Result<()> {
    let base = commands.dir.path().canonicalize()?;
    let genesis = c.comet_home(0).canonicalize()?.join("config/genesis.json");
    let export =
        Export { s: 0, comet_genesis: &genesis, recovery_bootstrap: None, validator_state: None };
    let x = import_fixture(f, c, commands, &base, &[], &c.comet_home(0), &c.cmt, export).await?;
    let root = base.join("import");
    let ready = import(f, commands, &x, &root, "import").await?;
    ensure!(
        ready == json!({"phase": "ready", "generation": null, "execution_floor": null}),
        "{ready}"
    );
    ensure!(!root.join("ready/app").join(abci::store::STATE_FILE).exists());
    let run = Follow { s: 0, target: 0, generation: 0, floor: None, restart: false };
    follow(f, c, commands, &x, &root, run).await
}

/// Land `height` with the original lander, then let own L1 finalize it.
async fn land(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    height: u64,
) -> Result<()> {
    let mut lander = commands.old_lander(f, &c.cmt)?;
    wait_checkpoint(f, &mut lander, height).await?;
    lander.stop().await?;
    mine_l1_blocks(&f.anvil.provider, 4).await
}

async fn source_blocks(cmt: &CmtClient, s: u64) -> Result<Vec<ExecutionBlock>> {
    let mut blocks = vec![];
    for h in 1..=s {
        blocks.push(cmt.envelope(h).await?.block);
    }
    Ok(blocks)
}

/// A package exported at s and the local inputs that import it.
struct Fixture {
    base: PathBuf,
    package: PathBuf,
    /// A stopped EL datadir at s.
    source: PathBuf,
    el_chain: PathBuf,
    /// The stock Comet `config.toml` the import installs.
    config: PathBuf,
    /// The ABCI and Comet RPC ports that `config` names.
    proxy: u16,
    rpc: u16,
}

/// What `export` collects.
struct Export<'a> {
    s: u64,
    comet_genesis: &'a Path,
    recovery_bootstrap: Option<&'a Path>,
    validator_state: Option<&'a Path>,
}

/// The operator's own preparation, outside the importer, then `export`: replay `blocks` into a
/// donor EL and copy its stopped datadir, write a full-node Comet config that peers with `peer`,
/// and export the package at s. No old consensus or successor payload reaches the import.
#[allow(clippy::too_many_arguments)]
async fn import_fixture(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    base: &Path,
    blocks: &[ExecutionBlock],
    source_home: &Path,
    peer: &CmtClient,
    export: Export<'_>,
) -> Result<Fixture> {
    let elbin = binary("ETNA_EL_BIN", "alethia-reth")?;
    let el_chain = base.join("el-genesis.json");
    fs::write(&el_chain, &f.l2.genesis.json)?;
    let donor_dir = base.join("donor-data");
    let (mut donor, _, _, engine) = el(&elbin, &donor_dir, &el_chain, base, "donor").await?;
    for b in blocks {
        let h = b.header.number;
        ensure!(engine.new_payload(b).await? == PayloadVerdict::Valid, "donor replay {h}");
        let head = b.header.hash_slow();
        ensure!(
            engine.forkchoice(head, f.l2.genesis.hash, f.l2.genesis.hash).await? ==
                PayloadVerdict::Valid,
            "donor head {h}"
        );
    }
    donor.stop().await?;
    // A normal stop can leave reth's PID marker. Copy the dataset only after reaping the donor.
    let source = base.join("offline-state");
    fs::create_dir_all(source.join("db"))?;
    for name in ["mdbx.dat", "database.version"] {
        fs::copy(donor_dir.join("db").join(name), source.join("db").join(name))?;
    }
    let (config, proxy, rpc) = fullnode_template(base, source_home, peer).await?;
    let package = base.join("archive");
    let mut args = vec!["export".to_string()];
    args.extend(own(f, commands));
    for (flag, value) in [
        ("--comet.http", c.cmt.url().to_string()),
        ("--l2.http", f.l2.http.to_string()),
        ("--comet-genesis", export.comet_genesis.display().to_string()),
        ("--height", export.s.to_string()),
        ("--out", package.display().to_string()),
    ] {
        args.extend([flag.into(), value]);
    }
    if let Some(path) = export.recovery_bootstrap {
        args.extend(["--recovery-bootstrap".into(), path.display().to_string()]);
    }
    if let Some(path) = export.validator_state {
        args.extend(["--validator-state".into(), path.display().to_string()]);
    }
    let exported = cli(base, "export", &args).await?;
    ensure!(exported["phase"] == "exported" && exported["height"] == export.s, "{exported}");
    eprintln!(
        "checkpoint_fixture s={} frame_bytes={} metadata_bytes={}",
        export.s,
        package.join("blocks.jsonl").metadata()?.len(),
        package.join("package.json").metadata()?.len(),
    );
    Ok(Fixture { base: base.to_path_buf(), package, source, el_chain, config, proxy, rpc })
}

/// The own deployment and L1 that `export` and `import` authenticate against.
fn own(f: &ContractFixture, commands: &Commands) -> [String; 6] {
    [
        "--l1.http".into(),
        f.anvil.http.to_string(),
        "--l2.chain-id".into(),
        f.params.l2_chain_id.to_string(),
        "--chain-config".into(),
        commands.chain.display().to_string(),
    ]
}

fn import_args(
    f: &ContractFixture,
    commands: &Commands,
    x: &Fixture,
    root: &Path,
) -> Result<Vec<String>> {
    let mut args = vec!["import".to_string()];
    args.extend(own(f, commands));
    for (flag, path) in [
        ("--package", x.package.clone()),
        ("--root", root.to_path_buf()),
        ("--el-source", x.source.clone()),
        ("--el-chain", x.el_chain.clone()),
        ("--el-helper", binary("ETNA_EL_IMPORT_BIN", "etna-el-import")?),
        ("--comet-helper", package().join("target/etna-signer/etna-comet-import")),
        ("--comet-config", x.config.clone()),
    ] {
        args.extend([flag.into(), path.display().to_string()]);
    }
    Ok(args)
}

async fn import(
    f: &ContractFixture,
    commands: &Commands,
    x: &Fixture,
    root: &Path,
    tag: &str,
) -> Result<Value> {
    cli(&x.base, tag, &import_args(f, commands, x, root)?).await
}

async fn status(base: &Path, root: &Path, tag: &str) -> Result<Value> {
    cli(base, tag, &["status".into(), "--root".into(), root.display().to_string()]).await
}

/// A file left in the stage of a killed import. No published store may contain it.
const CRASH_LEFTOVER: &str = "left-by-killed-import";

/// SIGKILL `import` mid-EL-install, after the Comet stores (DATA-5.4-5, ACC §7.6). The EL helper
/// inherited the root lock and runs on. Once it exits, nothing is published, `status` reports the
/// root interrupted, and a marker is left in the stage for the rerun to discard.
async fn crash_mid_install(
    f: &ContractFixture,
    commands: &Commands,
    x: &Fixture,
    root: &Path,
) -> Result<()> {
    let mut args = vec!["abci-import".to_string()];
    args.extend(import_args(f, commands, x, root)?);
    let mut killed = Process::spawn(Path::new(CLIENT), &args, x.base.join("import-killed.log"))?;
    let el = root.join("stage/ready/el/db");
    tokio::time::timeout(Duration::from_secs(480), async {
        while !el.exists() {
            killed.running()?;
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        Ok::<_, anyhow::Error>(())
    })
    .await
    .context("import never reached the EL install")??;
    ensure!(
        root.join("stage/ready/comet/data/blockstore.db").is_dir(),
        "the Comet stores are installed before the EL"
    );
    killed.kill().await?;
    let started = std::time::Instant::now();
    tokio::time::timeout(Duration::from_secs(480), async {
        while !lock_free(root)? {
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
        Ok::<_, anyhow::Error>(())
    })
    .await
    .context("the surviving EL helper must release the root lock")??;
    eprintln!("checkpoint_crash seconds_to_quiescence={:.3}", started.elapsed().as_secs_f64());
    ensure!(!root.join("ready").exists(), "a killed import published stores");
    ensure!(status(&x.base, root, "status-killed").await?["phase"] == "interrupted");
    fs::write(root.join("stage/ready/app").join(CRASH_LEFTOVER), b"stage of a killed import")?;
    Ok(())
}

/// Whether nothing holds `ROOT/import.lock`: neither an import nor a helper that inherited it.
fn lock_free(root: &Path) -> Result<bool> {
    use std::os::fd::AsRawFd;
    let lock = fs::File::open(root.join("import.lock"))?;
    // SAFETY: flock on a descriptor this function owns; closing it releases the lock.
    Ok(unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } == 0)
}

/// Plain `abci` on `data_dir`, once it accepts connections on `proxy`.
async fn app(
    f: &ContractFixture,
    commands: &Commands,
    data_dir: &Path,
    (http, auth): (&Url, &Url),
    proxy: u16,
    log: PathBuf,
) -> Result<Process> {
    let args = [
        "abci".to_string(),
        "--data-dir".into(),
        data_dir.display().to_string(),
        "--l1.http".into(),
        f.anvil.http.to_string(),
        "--l2.http".into(),
        http.to_string(),
        "--l2.auth".into(),
        auth.to_string(),
        "--jwt.secret".into(),
        package().join("tests/docker/jwt.hex").display().to_string(),
        "--chain-config".into(),
        commands.chain.display().to_string(),
        "--abci.addr".into(),
        format!("tcp://127.0.0.1:{proxy}"),
        "--fee-recipient".into(),
        "0x0000000000000000000000000000000000000001".into(),
    ];
    let mut app = Process::spawn(Path::new(CLIENT), &args, log)?;
    tokio::time::timeout(Duration::from_secs(150), async {
        loop {
            app.running()?;
            if tokio::net::TcpStream::connect(("127.0.0.1", proxy)).await.is_ok() {
                return Ok::<_, anyhow::Error>(())
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .context("abci never listened")??;
    Ok(app)
}

/// The EL on `ready/el` and plain `abci` on `ready/app` of a published root.
struct Node {
    el: Process,
    app: Process,
    http: Url,
}
impl Node {
    async fn start(
        f: &ContractFixture,
        commands: &Commands,
        x: &Fixture,
        root: &Path,
        label: &str,
    ) -> Result<Self> {
        let elbin = binary("ETNA_EL_BIN", "alethia-reth")?;
        let ready = root.join("ready");
        let (el, http, auth, _) =
            el(&elbin, &ready.join("el"), &x.el_chain, &x.base, &format!("{label}-el")).await?;
        let log = x.base.join(format!("{label}-app.log"));
        let app = app(f, commands, &ready.join("app"), (&http, &auth), x.proxy, log).await?;
        Ok(Self { el, app, http })
    }
    fn running(&mut self) -> Result<()> {
        self.el.running()?;
        self.app.running()
    }
    async fn stop(&mut self) -> Result<()> {
        self.app.stop().await?;
        self.el.stop().await
    }
}

/// Stock Comet on `ready/comet` through the full-node launcher, as on any other store.
fn full_node(x: &Fixture, root: &Path, label: &str) -> Result<Process> {
    let vars = [
        format!("ETNA_COMET_BIN={}", binary("ETNA_COMET_BIN", "cometbft")?.display()),
        format!("ETNA_COMET_HOME={}", root.join("ready/comet").display()),
        "python3".into(),
        package().join("script/start_etna_full_node.py").display().to_string(),
    ];
    Process::spawn(Path::new("/usr/bin/env"), &vars, x.base.join(format!("{label}.log")))
}

/// How an imported node comes up.
struct Follow {
    s: u64,
    target: u64,
    generation: u64,
    /// The app's execution floor: `None` at a generation origin, whose state InitChain builds.
    floor: Option<u64>,
    /// Restart the EL and the app once after the handover.
    restart: bool,
}

/// Run a published root as an ordinary node. Comet syncs from s + 1 over stock P2P, the EL serves
/// each block, and the app reaches Ready trust at the target (DATA-5.4-6, SYNC-9).
async fn follow(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    x: &Fixture,
    root: &Path,
    run: Follow,
) -> Result<()> {
    let Follow { s, target, generation, floor, restart } = run;
    let rpc = CmtClient::new(url(x.rpc));
    let mut node = Node::start(f, commands, x, root, "imported").await?;
    let mut comet = full_node(x, root, "imported-comet")?;
    wait_committed(&rpc, target + 1, &mut comet).await?;
    trusted(&rpc, &mut comet, &mut node, generation, floor, target).await?;
    let source = c.cmt.envelope(s + 1).await?;
    ensure!(rpc.envelope(s + 1).await? == source, "stock P2P block s + 1");
    let reader = rpc::client::connect_http_with_timeout(node.http.clone(), Duration::from_secs(5));
    let served = reader.get_block_by_number((s + 1).into()).await?.context("EL block s + 1")?;
    ensure!(served.header.inner == source.block.header);
    handover(&rpc, &mut comet).await?;
    if restart {
        comet.stop().await?;
        let tip = reader
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
            .await?
            .context("EL tip before the restart")?
            .header;
        ensure!(tip.number > s);
        node.stop().await?;
        node = Node::start(f, commands, x, root, "restarted").await?;
        comet = full_node(x, root, "restarted-comet")?;
        // Ready again: the app checked the floor at startup, before it answered Comet.
        trusted(&rpc, &mut comet, &mut node, generation, floor, target).await?;
        let reader =
            rpc::client::connect_http_with_timeout(node.http.clone(), Duration::from_secs(5));
        let kept =
            reader.get_block_by_number(tip.number.into()).await?.context("tip after restart")?;
        ensure!(
            reader.get_block_number().await? >= tip.number && kept.header.hash == tip.hash,
            "a normal restart rolled the EL back to the import floor"
        );
        handover(&rpc, &mut comet).await?;
    }
    comet.stop().await?;
    node.stop().await?;
    let status = status(&x.base, root, "status-after-run").await?;
    ensure!(status["phase"] == "ready" && status["execution_floor"] == json!(floor), "{status}");
    Ok(())
}

/// Wait until the app reports Ready trust at the target, with its generation and floor.
async fn trusted(
    rpc: &CmtClient,
    comet: &mut Process,
    node: &mut Node,
    generation: u64,
    floor: Option<u64>,
    target: u64,
) -> Result<()> {
    tokio::time::timeout(Duration::from_secs(120), async {
        loop {
            comet.running()?;
            node.running()?;
            if let Ok(status) = rpc.abci_status().await &&
                status.execution_floor == floor &&
                status.generation == generation &&
                status.trust_phase == abci::app::trust::TrustPhase::Ready &&
                status.trust_target.is_some_and(|t| t.height >= target)
            {
                return Ok::<_, anyhow::Error>(())
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .context("the imported node never reached Ready trust at the target")?
}

/// Stock v0.40 can race PopRequest on shutdown during active blocksync: wait for the consensus
/// handover before stopping Comet.
async fn handover(rpc: &CmtClient, comet: &mut Process) -> Result<()> {
    tokio::time::timeout(Duration::from_secs(120), async {
        loop {
            comet.running()?;
            if rpc.call("status", &[]).await?["sync_info"]["catching_up"] == false {
                return Ok::<_, anyhow::Error>(())
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .context("Comet never left blocksync")?
}

#[allow(clippy::too_many_arguments)]
async fn registered_follow(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    x: &Fixture,
    root: &Path,
    s: u64,
    target: u64,
    original: &(Vec<u8>, Vec<u8>),
) -> Result<()> {
    let dir = f.signer_storage.path().join("0").canonicalize()?;
    let old_height = serde_json::from_slice::<Value>(&original.0)?["height"]
        .as_str()
        .context("source HRS")?
        .parse::<u64>()?;
    let ready = root.join("ready");
    let chain = c.chain_id()?;
    let hrs = test_harness::signer_hrs(&dir, &chain);
    let mut node = Node::start(f, commands, x, root, "registered").await?;
    ensure!(fs::read(&hrs)? == original.0);
    // The same chain_id keeps its one HRS state: the imported stores run the same signer
    // configuration as before the import (DATA-5.4-7, RECOV-8.2-1).
    let mut command =
        test_harness::supervisor_command(&ready.join("comet"), &ready.join("app"), &dir, &chain);
    command
        .env("ETNA_SIGNER_BIN", binary("ETNA_SIGNER_BIN", "etna-signer")?)
        .env("ETNA_COMET_BIN", binary("ETNA_COMET_BIN", "cometbft")?);
    let mut supervisor = Process::spawn_command(command, x.base.join("registered-supervisor.log"))?;
    let rpc = CmtClient::new(url(x.rpc));
    let reader = &c.peers[1];
    let address = f.keys[0].address();
    let new_height = tokio::time::timeout(Duration::from_secs(180), async {
        let mut candidate = old_height + 1;
        loop {
            supervisor.running()?;
            node.running()?;
            if let Ok(head) = rpc.latest_height().await &&
                head > candidate &&
                reader.latest_height().await? > candidate
            {
                if reader.proposer_address(candidate).await? == address &&
                    reader.commit_signers(candidate).await?.contains(&address)
                {
                    ensure!(rpc.envelope(candidate).await? == reader.envelope(candidate).await?);
                    break Ok::<_, anyhow::Error>(candidate)
                }
                candidate += 1;
                continue
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .with_context(|| {
        format!(
            "no new registered proposal after HRS {old_height}: {} / {}",
            supervisor.output(),
            node.app.output()
        )
    })??;
    let status = rpc.abci_status().await?;
    ensure!(
        status.generation == 0 &&
            rpc.call("status", &[]).await?["node_info"]["network"] == chain &&
            status.execution_floor == Some(s) &&
            status.trust_phase == abci::app::trust::TrustPhase::Ready &&
            status.trust_target.is_some_and(|t| t.height >= target)
    );
    let mut later_round = false;
    for h in s + 1..=new_height {
        ensure!(rpc.proposer_address(h).await? == reader.proposer_address(h).await?);
        let r = rpc.commit_round(h).await?;
        ensure!(r == reader.commit_round(h).await?);
        later_round |= r > 0;
    }
    ensure!(later_round, "stock differential includes a genuine later-round proposer");
    let grid = new_height / 6 * 6;
    ensure!(
        fs::read(ready.join(format!("app/val-state-{grid}.bin")))? ==
            fs::read(c.app_dir(1).join(format!("val-state-{grid}.bin")))?
    );
    let hrs = serde_json::from_slice::<Value>(&fs::read(&hrs)?)?["height"]
        .as_str()
        .context("imported HRS")?
        .parse::<u64>()?;
    ensure!(hrs >= new_height && new_height > old_height);
    let auth = supervisor.output();
    let first = auth
        .lines()
        .find(|l| l.contains("checkpoint_trust_authorized"))
        .context("private signer authorization")?;
    for field in ["committed_height", "target_height"] {
        let raw = first
            .split_once(&format!("{field}="))
            .context("authorization height")?
            .1
            .split_whitespace()
            .next()
            .unwrap();
        ensure!(raw.parse::<u64>()? >= target, "signature authorized before own current target");
    }
    let (http, auth) = c.execution_endpoints(1, &f.l2);
    let mut lander = commands.lander_with_execution(f, &rpc, &http, &auth)?;
    let next = new_height.div_ceil(6) * 6;
    wait_checkpoint(f, &mut lander, next).await?;
    lander.stop().await?;
    let (landed, hash) = f.checkpoint().await?;
    ensure!(
        landed >= new_height &&
            reader.envelope(landed).await?.block.header.hash_slow() == hash &&
            rpc.envelope(landed).await?.block.header.hash_slow() == hash
    );
    ensure!(fs::read(c.comet_home(0).join("data/cs.wal/wal"))? == original.1);
    eprintln!(
        "registered_import s={s} target={target} source_hrs={old_height} imported_proposer={new_height} hrs={hrs} landed={landed} hash={hash}"
    );
    supervisor.stop().await?;
    node.stop().await
}

async fn fullnode_template(
    base: &Path,
    source_home: &Path,
    cmt: &CmtClient,
) -> Result<(PathBuf, u16, u16)> {
    let proxy = port()?;
    let rp = port()?;
    let mut config: toml::Table =
        toml::from_str(&fs::read_to_string(source_home.join("config/config.toml"))?)?;
    config.insert("proxy_app".into(), format!("tcp://127.0.0.1:{proxy}").into());
    config.insert("priv_validator_laddr".into(), "".into());
    let status = cmt.call("status", &[]).await?;
    let peer = format!(
        "{}@{}",
        status["node_info"]["id"].as_str().context("peer id")?,
        status["node_info"]["listen_addr"]
            .as_str()
            .context("p2p addr")?
            .trim_start_matches("tcp://")
    );
    let p2p = config.get_mut("p2p").unwrap().as_table_mut().unwrap();
    p2p.insert("persistent_peers".into(), peer.into());
    p2p.insert("laddr".into(), format!("tcp://127.0.0.1:{}", port()?).into());
    config
        .get_mut("rpc")
        .unwrap()
        .as_table_mut()
        .unwrap()
        .insert("laddr".into(), format!("tcp://127.0.0.1:{rp}").into());
    let template = base.join("full.toml");
    fs::write(&template, toml::to_string(&config)?)?;
    Ok((template, proxy, rp))
}

/// Preserve real recovery grid preimages independently of the live runtime's prune floor.
pub fn enable_recovery_archive(commands: &mut Commands) -> Result<()> {
    let archive = commands.dir.path().canonicalize()?.join("grid-archive");
    fs::create_dir(&archive)?;
    commands.archive = Some(archive);
    Ok(())
}

/// Import a delayed generation-one full node at the fixed recovery origin (s = 6: no app state,
/// InitChain builds it, DATA-5.4-1 and RECOV-8.4) and at a later landing (s = 12: an ordinary
/// import). The operator's independent donor replay is outside the importer.
pub async fn recovered(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    installed: &Installed,
    old: &[ExecutionBlock],
) -> Result<()> {
    let parent = commands.dir.path().canonicalize()?;
    let home = &installed.home;
    let g = home.join("config/genesis.json");
    let doc: abci::GenesisDoc = serde_json::from_slice(&fs::read(&g)?)?;
    let bootstrap = installed.app.join("recovery-bootstrap.json");
    let history: abci::recovery::RecoveryBootstrap =
        serde_json::from_slice(&fs::read(&bootstrap)?)?;
    let old_anchor = history.verify(&f.params)?.anchor;
    let fixed = abci::genesis::verify_original_genesis(&doc, &f.params)?;
    ensure!(
        fixed.anchor.inbox.last_checkpoint_height == 6 &&
            old_anchor.inbox.last_checkpoint_height < 6
    );
    eprintln!(
        "fixed recovery R proves q={}, historical parent context previously proved q={}",
        fixed.anchor.inbox.last_checkpoint_height, old_anchor.inbox.last_checkpoint_height
    );
    let target = 12;
    ensure!(f.checkpoint().await?.0 >= target, "the recovered generation landed {target}");
    let archive = parent.join("grid-archive");
    let domain = alloy_primitives::keccak256(doc.chain_id.as_bytes());
    ensure!(old.len() == 6, "the original blocks 1..=6");
    for s in [6, 12] {
        let base = parent.join(format!("g1-cp-{s}"));
        fs::create_dir(&base)?;
        // The recovered Comet starts at 7; the original blocks up to the origin come from `old`.
        let mut blocks = old.to_vec();
        for h in 7..=s {
            blocks.push(c.cmt.envelope(h).await?.block);
        }
        let preimage = archive.join(format!("{domain}-{s}.bin"));
        let export = Export {
            s,
            comet_genesis: &g,
            recovery_bootstrap: Some(&bootstrap),
            validator_state: (s > 6).then_some(preimage.as_path()),
        };
        let x = import_fixture(f, c, commands, &base, &blocks, home, &c.cmt, export).await?;
        let root = base.join("import");
        let ready = import(f, commands, &x, &root, "import").await?;
        let installed: abci::GenesisDoc =
            serde_json::from_slice(&fs::read(root.join("ready/comet/config/genesis.json"))?)?;
        ensure!(installed == doc && installed.initial_height == "7");
        let app = root.join("ready/app");
        let floor = if s == 6 {
            ensure!(
                ready == json!({"phase": "ready", "generation": null, "execution_floor": null}),
                "{ready}"
            );
            ensure!(
                !app.join(abci::store::STATE_FILE).exists() &&
                    app.join("recovery-bootstrap.json").is_file(),
                "the recovery origin installs only the bootstrap"
            );
            None
        } else {
            ensure!(
                ready == json!({"phase": "ready", "generation": 1, "execution_floor": s}),
                "{ready}"
            );
            let installed: abci::store::AppState =
                serde_json::from_slice(&fs::read(app.join(abci::store::STATE_FILE))?)?;
            ensure!(installed.origin_height() == 6 && installed.last_height == s);
            Some(s)
        };
        let run = Follow { s, target, generation: 1, floor, restart: false };
        follow(f, c, commands, &x, &root, run).await?;
    }
    Ok(())
}

mod long_fence;

mod forced;
