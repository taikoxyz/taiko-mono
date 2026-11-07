//! Real CLI export, independent frozen MDBX, normal EL restart, P2P continuation and readiness.
use super::recovery::{
    CLIENT, Commands, package, process::Process, wait_checkpoint, wait_committed, write_private,
};
use crate::contracts_support::ContractFixture;
use abci::{Engine, PayloadVerdict, RpcEngine};
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
async fn cli(base: &Path, tag: &str, args: &[&str]) -> Result<Value> {
    let started = std::time::Instant::now();
    let log = base.join(format!("{tag}.log"));
    let cmd = std::process::Command::new(CLIENT).arg("abci-import").args(args).output()?;
    fs::write(&log, &cmd.stderr)?;
    eprintln!(
        "checkpoint_cli phase={tag} seconds={:.3} exit={}",
        started.elapsed().as_secs_f64(),
        cmd.status
    );
    if !cmd.status.success() {
        let work = base.join("import/.checkpoint-work");
        if std::env::var_os("ETNA_CAPTURE_OFFLINE_FIXTURE").is_some() &&
            work.join("el/db/mdbx.dat").is_file()
        {
            let captured = tempfile::Builder::new()
                .prefix("etna-real-db-schema-")
                .tempdir_in("/private/tmp")?
                .keep();
            fs::create_dir_all(captured.join("el/db"))?;
            for name in ["mdbx.dat", "database.version"] {
                fs::copy(
                    base.join("offline-state/db").join(name),
                    captured.join("el/db").join(name),
                )?;
            }
            for (from, to) in [
                (base.join("el-genesis.json"), "genesis.json"),
                (work.join("headers.json"), "headers.json"),
            ] {
                fs::copy(from, captured.join(to))?;
            }
            eprintln!("real frozen EL reproduction: {}", captured.display());
        }
        for name in ["el-verify.stderr", "el-install.stderr", "el-startup.log"] {
            if let Ok(raw) = fs::read(work.join(name)) {
                eprintln!(
                    "{name}: {}",
                    String::from_utf8_lossy(&raw[raw.len().saturating_sub(8192)..])
                );
            }
        }
        if let Ok(raw) = fs::read(work.join("headers.json")) {
            let m: Value = serde_json::from_slice(&raw)?;
            eprintln!(
                "manifest origin={} finalized_height={} finalized_hash={}",
                m["origin"], m["finalized_height"], m["finalized_hash"]
            );
        }
    }
    ensure!(cmd.status.success(), "{tag}: {}", String::from_utf8_lossy(&cmd.stderr));
    Ok(serde_json::from_slice(&cmd.stdout)?)
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_import_older_archive_restarts_and_syncs_stock_peer() -> Result<()> {
    scenario(6, 12).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_import_latest_restarts_and_syncs_stock_peer() -> Result<()> {
    scenario(6, 6).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_import_fixed_origin_runs_original_stock_init_chain() -> Result<()> {
    scenario(0, 0).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn registered_checkpoint_latest_signs_proposes_and_lands() -> Result<()> {
    run_scenario(6, 6, Mode::Validator).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn registered_checkpoint_older_signs_proposes_and_lands() -> Result<()> {
    run_scenario(6, 12, Mode::Validator).await
}

async fn scenario(height: u64, target: u64) -> Result<()> {
    run_scenario(height, target, Mode::FullNode).await
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Mode {
    FullNode,
    Validator,
    Forced,
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_import_first_and_cold_post_floor_forced_skips() -> Result<()> {
    run_scenario(6, 6, Mode::Forced).await
}

async fn run_scenario(height: u64, target: u64, mode: Mode) -> Result<()> {
    test_harness::init_tracing();
    let registered = mode == Mode::Validator;
    let count = if registered { 4 } else { 1 };
    let epoch_len = match (mode, target) {
        (Mode::Validator, 6) => 7,
        (Mode::Validator, 12) => 6,
        _ => 8,
    };
    let f = ContractFixture::deploy_config(
        count,
        if mode == Mode::Forced { 6 } else { 120 },
        epoch_len,
    )
    .await?;
    set_interval_mining(&f.anvil.provider, 1).await?;
    let dirs = (0..count).map(|i| f.signer_storage.path().join(i.to_string())).collect();
    let mut c = if registered {
        ContractConsensus::start_registered(f.anvil.http.clone(), &f.l2, f.params.clone(), dirs)
            .await?
    } else {
        ContractConsensus::start_native(f.anvil.http.clone(), &f.l2, f.params.clone(), dirs).await?
    };
    let commands = Commands::new(&f, &c)?;
    let result = roundtrip(&f, &mut c, &commands, height, target, mode).await;
    if result.is_err() {
        commands.diagnostics();
        if let Ok(files) = fs::read_dir(commands.dir.path().join("import/.checkpoint-work")) {
            for f in files.flatten() {
                if matches!(f.path().extension().and_then(|s| s.to_str()), Some("stderr" | "log")) {
                    let raw = fs::read(f.path())?;
                    eprintln!(
                        "checkpoint {}: {}",
                        f.file_name().to_string_lossy(),
                        String::from_utf8_lossy(&raw[raw.len().saturating_sub(8192)..])
                    );
                }
            }
        }
    }
    c.stop().await?;
    result
}

async fn roundtrip(
    f: &ContractFixture,
    c: &mut ContractConsensus,
    commands: &Commands,
    s: u64,
    target: u64,
    mode: Mode,
) -> Result<()> {
    let base = commands.dir.path().canonicalize()?;
    c.wait_for_height(s).await?;
    if mode == Mode::Forced {
        forced::enqueue(f).await?;
    }
    let archived = base.join("archived-val-state.bin");
    if s > 0 {
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
        fs::write(&archived, preimage).context("archive live validator-state preimage")?;
        let mut lander = commands.old_lander(f, &c.cmt)?;
        wait_checkpoint(f, &mut lander, target).await?;
        lander.stop().await?;
        mine_l1_blocks(&f.anvil.provider, 4).await?;
        if target > s {
            // Node 0 may keep the sidecar of 6 as the recompute base below its floor, but its
            // query refuses 6 once the floor passes it.
            tokio::time::timeout(Duration::from_secs(90), async {
                while !matches!(c.cmt.abci_answer("/val_state/6").await, Ok(Err(_))) {
                    tokio::time::sleep(Duration::from_millis(100)).await
                }
            })
            .await?;
        }
    }
    let elbin = binary("ETNA_EL_BIN", "alethia-reth")?;
    let helper = std::env::var_os("ETNA_EL_IMPORT_BIN")
        .map(PathBuf::from)
        .unwrap_or_else(|| package().join("target/etna-signer/etna-el-import"));
    let el_chain = base.join("el-genesis.json");
    fs::write(&el_chain, &f.l2.genesis.json)?;
    let donor_dir = base.join("donor-data");
    let (mut donor, _, _, engine) = el(&elbin, &donor_dir, &el_chain, &base, "donor").await?;
    // Independent source acquisition by fixture operator, outside the importer. No old
    // consensus, state execution or successor payload is supplied to the installation.
    for h in 1..=s {
        let b = c.cmt.envelope(h).await?.block;
        ensure!(engine.new_payload(&b).await? == PayloadVerdict::Valid, "donor replay {h}");
        let hash = b.header.hash_slow();
        ensure!(
            engine.forkchoice(hash, f.l2.genesis.hash, f.l2.genesis.hash).await? ==
                PayloadVerdict::Valid
        );
    }
    donor.stop().await?;
    // A normal stop can leave reth's PID marker. Materialize a physically independent
    // dataset only after reaping the donor, never remove or reinterpret its lock.
    let source = base.join("offline-state");
    fs::create_dir_all(source.join("db"))?;
    for name in ["mdbx.dat", "database.version"] {
        fs::copy(donor_dir.join("db").join(name), source.join("db").join(name))?;
    }

    let registered = c.peers.len() > 1;
    let peer = if registered { &c.peers[1] } else { &c.cmt };
    let (template, proxy, rp) = fullnode_template(&base, &c.comet_home(0), peer).await?;
    if registered {
        let mut config: toml::Table = toml::from_str(&fs::read_to_string(&template)?)?;
        config.insert("priv_validator_laddr".into(), "unix://run/signer.sock".into());
        fs::write(&template, toml::to_string(&config)?)?;
    }
    let stock = package().join("target/etna-signer/etna-comet-import");
    let profile = base.join("import.json");
    write_private(
        &profile,
        serde_json::to_vec(
            &json!({"schema":1,"l1_chain_id":f.params.l1_chain_id,"l2_chain_id":f.params.l2_chain_id,"l1_http":f.anvil.http,"chain_config":commands.chain,"archive":{"comet_http":c.cmt.url(),"l2_http":f.l2.http,"comet_genesis":c.comet_home(0).canonicalize()?.join("config/genesis.json"),"comet_helper":stock},"install":{"signer_binary":if registered {Some(binary("ETNA_SIGNER_BIN","etna-signer")?)} else {None},"comet_binary":binary("ETNA_COMET_BIN","cometbft")?,"el_source":source,"el_chain":el_chain,"devnet_etna_timestamp":0,"comet_config":template,"comet_helper":stock,"el_helper":helper,"el_binary":elbin}}),
        )?,
    )?;
    let package_dir = base.join("archive");
    let root = base.join("import");
    let paths = [&profile, &package_dir, &root, &archived].map(|p| p.to_str().unwrap());
    let [profile, pkg, r, arch] = paths;
    let hs = s.to_string();
    let mut export = vec!["export", "--profile", profile, "--height", &hs, "--out", pkg];
    if s < target {
        export.extend(["--validator-state", arch]);
    }
    cli(&base, "export", &export).await?;
    use std::os::unix::fs::MetadataExt;
    let db = source.join("db/mdbx.dat").metadata()?;
    eprintln!(
        "checkpoint_fixture s={s} target={target} frame_bytes={} metadata_bytes={} source_mdbx_logical={} source_mdbx_allocated={}",
        package_dir.join("blocks.jsonl").metadata()?.len(),
        package_dir.join("package.json").metadata()?.len(),
        db.len(),
        db.blocks() * 512
    );
    if s < target && !registered {
        helper_failures::code_preimages(
            &base,
            Path::new(profile),
            &package_dir,
            &source,
            &donor_dir,
        )
        .await?;
        memdb_refused(&base, Path::new(profile), &package_dir)?;
        crash_stock_export(&base, Path::new(profile), &archived).await?;
    }
    if mode == Mode::Forced {
        c.wait_for_height(s + 3).await?;
    }
    c.stop_node(0).await?;
    let hrs = f.signer_storage.path().join("0/state.json");
    let wal = c.comet_home(0).join("data/cs.wal/wal");
    let original = (fs::read(&hrs)?, fs::read(&wal)?);
    if registered {
        // The independent quorum can continue while the old validator is stopped. Wait for
        // its absent proposer turn so at least one original post-s decision uses a later round.
        let mut h = serde_json::from_slice::<Value>(&original.0)?["height"]
            .as_str()
            .unwrap()
            .parse::<u64>()? +
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
    }
    let authority = f.signer_storage.path().join("0");
    let marker_files = [
        "key.json",
        "authority/manifest.json",
        "key.json.authority.json",
        "state.json.authority.json",
    ];
    let authority_before: Vec<_> = if registered {
        marker_files
            .iter()
            .map(|name| fs::read(authority.join(name)))
            .collect::<std::io::Result<_>>()?
    } else {
        vec![]
    };
    if s < target && !registered {
        interrupted(
            &root,
            &["prepare", "--profile", profile, "--package", pkg, "--root", r],
            "el/db/mdbx.dat",
        )
        .await?;
    }
    let prepared =
        cli(&base, "prepare", &["prepare", "--profile", profile, "--package", pkg, "--root", r])
            .await?;
    ensure!(
        prepared["phase"] == "prepared" &&
            prepared["observed_latest_target"].as_u64().unwrap() == target &&
            prepared["live_trust"] == false
    );
    if s < target && !registered {
        helper_failures::occupied_stock_output(&base, &root, profile).await?;
        for boundary in [
            "comet/data/blockstore.db",
            "el/.etna-el-import-completed.json",
            "app/abci-state.json",
            ".etna-checkpoint-completed.json",
        ] {
            interrupted(&root, &["install", "--profile", profile, "--root", r], boundary).await?;
            ensure!(fs::read(&hrs)? == original.0 && fs::read(&wal)? == original.1);
        }
    }
    let ready = cli(&base, "install", &["install", "--profile", profile, "--root", r]).await?;
    ensure!(
        ready["phase"] == "installed" &&
            ready["execution_floor"] == s &&
            ready["live_trust"] == false
    );
    ensure!(
        root.join("ready/el/db/mdbx.dat").metadata()?.len() <= 128 * 1024 * 1024,
        "post-smoke native runtime expanded the small offline fixture"
    );
    if s < target && !registered {
        // A caller that lost the completion acknowledgement must reopen the published group.
        ensure!(
            cli(&base, "install-retry", &["install", "--profile", profile, "--root", r]).await? ==
                ready
        );
    }
    assert_eq!((fs::read(&hrs)?, fs::read(&wal)?), original);
    if s < target && !registered {
        mixed_components_refused(&root, &source)?;
    }
    if registered {
        for (name, bytes) in marker_files.iter().zip(&authority_before) {
            ensure!(
                fs::read(authority.join(name))? == *bytes,
                "checkpoint operation changed existing authority {name}"
            );
        }
        return registered_follow(
            f,
            c,
            commands,
            Follow { base: &base, root: &root, s, target, generation: 0, ports: (proxy, rp) },
            &original,
        )
        .await;
    }
    c.restart_node(0).await?;
    if mode == Mode::Forced {
        return forced::replay(f, c, &base, &root, s, proxy).await;
    }
    follow(
        f,
        c,
        commands,
        Follow { base: &base, root: &root, s, target, generation: 0, ports: (proxy, rp) },
    )
    .await
}

async fn registered_follow(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    context: Follow<'_>,
    original: &(Vec<u8>, Vec<u8>),
) -> Result<()> {
    let Follow { base, root, s, target, ports: (proxy, rp), .. } = context;
    let dir = f.signer_storage.path().join("0").canonicalize()?;
    let old_height = serde_json::from_slice::<Value>(&original.0)?["height"]
        .as_str()
        .context("source HRS")?
        .parse::<u64>()?;
    let comet = root.join("ready/comet");
    let app = root.join("ready/app");
    let domain: Value = serde_json::from_str(&c.genesis_json)?;
    let chain = domain["chain_id"].as_str().context("deployment chain")?;
    let args = [
        "abci-import",
        "run-app",
        "--root",
        root.to_str().unwrap(),
        "--profile",
        base.join("import.json").to_str().unwrap(),
        "--fee-recipient",
        "0x0000000000000000000000000000000000000001",
        "--el-http-port",
        &port()?.to_string(),
    ]
    .map(str::to_owned);
    let mut runtime = Process::spawn(Path::new(CLIENT), &args, base.join("registered-app.log"))?;
    tokio::time::timeout(Duration::from_secs(90), async {
        loop {
            runtime.running()?;
            if app.join(".owner.sock").exists() &&
                tokio::net::TcpStream::connect(("127.0.0.1", proxy)).await.is_ok()
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    ensure!(fs::read(dir.join("state.json"))? == original.0);
    let vars = [
        format!("ETNA_COMET_HOME={}", comet.display()),
        format!("ETNA_APP_STORE={}", app.display()),
        format!("ETNA_PRIV_KEY={}", dir.join("key.json").display()),
        format!("ETNA_PRIV_STATE={}", dir.join("state.json").display()),
        format!("ETNA_AUTHORITY_ROOT={}", dir.join("authority").display()),
        format!("ETNA_CHAIN_ID={chain}"),
        format!("ETNA_L1_CHAIN_ID={}", f.params.l1_chain_id),
        format!("ETNA_L2_CHAIN_ID={}", f.params.l2_chain_id),
        format!("ETNA_INBOX={:#x}", f.params.inbox),
        "ETNA_GENERATION=0".into(),
        "ETNA_ENROLL_LEGACY=0".into(),
        format!("ETNA_CLIENT_BIN={CLIENT}"),
        "python3".into(),
        package().join("script/etna_validator.py").display().to_string(),
    ];
    let mut supervisor =
        Process::spawn(Path::new("/usr/bin/env"), &vars, base.join("registered-supervisor.log"))?;
    let rpc = CmtClient::new(url(rp));
    let reader = &c.peers[1];
    let address = f.keys[0].address();
    let new_height = tokio::time::timeout(Duration::from_secs(180), async {
        let mut candidate = old_height + 1;
        loop {
            supervisor.running()?;
            runtime.running()?;
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
            runtime.output()
        )
    })??;
    let status = rpc.abci_status().await?;
    ensure!(
        status.generation == 0 &&
            rpc.call("status", &[]).await?["node_info"]["network"] == chain &&
            status.execution_floor == Some(s) &&
            status.trust_ready &&
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
        fs::read(app.join(format!("val-state-{grid}.bin")))? ==
            fs::read(c.app_dir(1).join(format!("val-state-{grid}.bin")))?
    );
    let hrs = serde_json::from_slice::<Value>(&fs::read(dir.join("state.json"))?)?["height"]
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
    runtime.stop().await?;
    Ok(())
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

struct Follow<'a> {
    base: &'a Path,
    root: &'a Path,
    s: u64,
    target: u64,
    generation: u64,
    ports: (u16, u16),
}
async fn follow(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    context: Follow<'_>,
) -> Result<()> {
    let Follow { base, root, s, target, generation, ports: (proxy, rp) } = context;
    let r = root.to_str().unwrap();
    let base_ready = root.join("ready");
    let app = base_ready.join("app");
    let comet = base_ready.join("comet");
    let el_port = port()?;
    let http = url(el_port);
    if s == 0 || (generation == 1 && s == 6) {
        fixed_origin_store_swaps(base, root, false)?;
    }
    let args = [
        "abci-import",
        "run-app",
        "--root",
        r,
        "--profile",
        base.join("import.json").to_str().unwrap(),
        "--fee-recipient",
        "0x0000000000000000000000000000000000000001",
        "--el-http-port",
        &el_port.to_string(),
    ]
    .map(str::to_owned);
    let mut app_process = Process::spawn(Path::new(CLIENT), &args, base.join("imported-app.log"))?;
    tokio::time::timeout(Duration::from_secs(150), async {
        loop {
            app_process.running()?;
            if app.join(".owner.sock").exists() &&
                tokio::net::TcpStream::connect(("127.0.0.1", proxy)).await.is_ok()
            {
                break
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    let comet_bin = binary("ETNA_COMET_BIN", "cometbft")?;
    cli(
        base,
        "check",
        &[
            "check-runtime",
            "--app-dir",
            app.to_str().unwrap(),
            "--comet-home",
            comet.to_str().unwrap(),
        ],
    )
    .await?;
    let wrapper = package().join("script/start_etna_full_node.py");
    let foreign = base.join("sentinel-old-comet");
    fs::create_dir(&foreign)?;
    let sentinel = foreign.join("wal");
    fs::write(&sentinel, b"stopped old home")?;
    if generation == 0 && s == 6 && target > s {
        refuse_ambiguous_launchers(base, &app, &comet)?;
    }
    let vars = [
        format!("CMTHOME={}", foreign.display()),
        format!("TMHOME={}", foreign.display()),
        "CMT_DB_BACKEND=memdb".into(),
        format!("CMTDBDIR={}", foreign.display()),
        format!("TM_DB_DIR={}", foreign.display()),
        format!("ETNA_CLIENT_BIN={CLIENT}"),
        format!("ETNA_COMET_BIN={}", comet_bin.display()),
        format!("ETNA_APP_STORE={}", app.display()),
        format!("ETNA_COMET_HOME={}", comet.display()),
        "python3".into(),
        wrapper.display().to_string(),
    ];
    let mut follower =
        Process::spawn(Path::new("/usr/bin/env"), &vars, base.join("imported-comet.log"))?;
    let rpc = CmtClient::new(url(rp));
    wait_committed(&rpc, target + 1, &mut follower).await?;
    tokio::time::timeout(Duration::from_secs(90), async {
        loop {
            follower.running()?;
            app_process.running()?;
            if let Ok(status) = rpc.abci_status().await &&
                status.execution_floor == Some(s) &&
                status.generation == generation &&
                status.trust_ready &&
                status.trust_target.is_some_and(|t| t.height >= target)
            {
                break
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    ensure!(rpc.envelope(s + 1).await? == c.cmt.envelope(s + 1).await?);
    use alloy_provider::Provider;
    let reader = rpc::client::connect_http_with_timeout(http.clone(), Duration::from_secs(5));
    ensure!(
        reader
            .get_block_by_number((s + 1).into())
            .await?
            .context("retained first new block")?
            .header
            .inner ==
            c.cmt.envelope(s + 1).await?.block.header
    );
    if generation == 0 && s > 0 {
        crosswired_refused(&app, &comet, &http, f, commands, proxy).await?;
    }
    // Stock v0.40 can race PopRequest on shutdown during active blocksync. Wait for
    // the genuine consensus handover as well as the independently asserted app trust.
    tokio::time::timeout(Duration::from_secs(120), async {
        loop {
            follower.running()?;
            if rpc.call("status", &[]).await?["sync_info"]["catching_up"] == false {
                break
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    follower.stop().await?;
    let durable_tip = reader
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .context("owned execution tip before shutdown")?
        .header;
    app_process.stop().await?;
    if generation == 0 && s > 0 && s < target {
        let mut restarted =
            Process::spawn(Path::new(CLIENT), &args, base.join("restarted-owned-app.log"))?;
        tokio::time::timeout(Duration::from_secs(60), async {
            loop {
                restarted.running()?;
                let guard = tokio::process::Command::new(CLIENT)
                    .args(["abci-import", "check-runtime", "--live", "--app-dir"])
                    .arg(&app)
                    .arg("--comet-home")
                    .arg(&comet)
                    .output()
                    .await?;
                if guard.status.success() {
                    break
                }
                tokio::time::sleep(Duration::from_millis(150)).await;
            }
            Ok::<_, anyhow::Error>(())
        })
        .await??;
        ensure!(
            durable_tip.number > s &&
                reader.get_block_number().await? >= durable_tip.number &&
                reader
                    .get_block_by_number(durable_tip.number.into())
                    .await?
                    .context("later head after restart")?
                    .header
                    .hash ==
                    durable_tip.hash,
            "normal restart rolled forkchoice back to imported floor"
        );
        restarted.stop().await?;
        ensure!(
            root.join("ready/el/db/mdbx.dat").metadata()?.len() <= 128 * 1024 * 1024,
            "ordinary restart expanded the small imported fixture"
        );
    }
    ensure!(
        fs::read(&sentinel)? == b"stopped old home" && fs::read_dir(&foreign)?.count() == 1,
        "ambient home override reached the stock child"
    );
    if s == 0 || (generation == 1 && s == 6) {
        fixed_origin_store_swaps(base, root, true)?;
    }

    ensure!(cli(base, "offline-status", &["status", "--root", r]).await?["live_trust"] == false);
    Ok(())
}

async fn interrupted(root: &Path, args: &[&str], at: &str) -> Result<()> {
    use std::process::Stdio;
    let started = std::time::Instant::now();
    let mut cmd = tokio::process::Command::new(CLIENT)
        .arg("abci-import")
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .spawn()?;
    tokio::time::timeout(Duration::from_secs(480), async {
        loop {
            if root.join(".checkpoint-work").join(at).exists() {
                break
            }
            if let Some(s) = cmd.try_wait()? {
                use tokio::io::AsyncReadExt;
                let mut msg = String::new();
                cmd.stderr.take().unwrap().read_to_string(&mut msg).await?;
                anyhow::bail!("import exited before crash boundary {at}: {s}: {msg}")
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    let crash_at = started.elapsed();
    cmd.start_kill()?;
    ensure!(!cmd.wait().await?.success());
    tokio::time::timeout(Duration::from_secs(90), async {
        loop {
            if abci::ownership::acquire_activation(root, alloy_primitives::B256::ZERO).is_ok() {
                break
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
    })
    .await
    .context("surviving helper must relinquish its inherited ownership barrier")?;
    eprintln!(
        "checkpoint_crash boundary={at} seconds_to_crash={:.3} seconds_to_quiescence={:.3}",
        crash_at.as_secs_f64(),
        (started.elapsed() - crash_at).as_secs_f64()
    );
    ensure!(!root.join("ready").exists(), "interrupted stage must not be published");
    let rejected = std::process::Command::new(CLIENT)
        .args(["abci-import", "check-runtime", "--app-dir"])
        .arg(root.join(".checkpoint-work/app"))
        .arg("--comet-home")
        .arg(root.join(".checkpoint-work/comet"))
        .output()?;
    ensure!(!rejected.status.success());
    Ok(())
}

fn mixed_components_refused(root: &Path, donor: &Path) -> Result<()> {
    let ready = root.join("ready");
    let check = || {
        std::process::Command::new(CLIENT)
            .args(["abci-import", "check-runtime", "--app-dir"])
            .arg(ready.join("app"))
            .arg("--comet-home")
            .arg(ready.join("comet"))
            .output()
    };
    let marker = ready.join("el/.etna-checkpoint.json");
    let original = fs::read(&marker)?;
    let mut other: Value = serde_json::from_slice(&original)?;
    other["installation_id"] = json!(alloy_primitives::B256::ZERO);
    fs::write(&marker, serde_json::to_vec(&other)?)?;
    ensure!(!check()?.status.success(), "foreign component accepted");
    fs::write(&marker, original)?;
    let db = ready.join("el/db/mdbx.dat");
    let held = ready.join("saved-installed-db");
    fs::rename(&db, &held)?;
    fs::copy(donor.join("db/mdbx.dat"), &db)?;
    ensure!(!check()?.status.success(), "foreign database under matching directory accepted");
    fs::rename(&held, &db)?;
    let config = ready.join("comet/config/config.toml");
    let bytes = fs::read(&config)?;
    fs::write(&config, b"db_dir='/other/writable/component'")?;
    ensure!(!check()?.status.success(), "redirected database path accepted");
    fs::write(&config, bytes)?;
    ensure!(check()?.status.success());
    Ok(())
}

/// Preserve real recovery grid preimages independently of the live runtime's prune floor.
pub fn enable_recovery_archive(commands: &Commands) -> Result<()> {
    let archive = commands.dir.path().canonicalize()?.join("grid-archive");
    fs::create_dir(&archive)?;
    let mut cfg: toml::Table = toml::from_str(&fs::read_to_string(&commands.profile)?)?;
    cfg["app"]["argv"]
        .as_array_mut()
        .context("recovery app argv")?
        .extend(["--checkpoint-archive-dir".into(), archive.to_string_lossy().to_string().into()]);
    write_private(&commands.profile, toml::to_string(&cfg)?)
}

/// Bootstrap a real delayed generation-one full node from the fixed R boundary and from
/// a later landing. The operator's independent donor replay is external to the importer.
pub async fn recovered(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    plan: &str,
    old: &[abci::envelope::ExecutionBlock],
) -> Result<()> {
    let parent = commands.dir.path().canonicalize()?;
    let active: Value = serde_json::from_slice(&fs::read(commands.root.join("active.json"))?)?;
    let home =
        PathBuf::from(active["installation"]["home"].as_str().context("installed recovered home")?);
    let g = home.join("config/genesis.json");
    let doc: abci::GenesisDoc = serde_json::from_slice(&fs::read(&g)?)?;
    let bootstrap = commands.plan_dir(plan).join("app/recovery-bootstrap.json");
    let history: abci::recovery::RecoveryBootstrap =
        serde_json::from_slice(&fs::read(&bootstrap)?)?;
    let (_, old_anchor) = history.verify(&f.params)?;
    let fixed = abci::genesis::verify_original_genesis(&doc, &f.params)?;
    ensure!(
        fixed.anchor.inbox.last_checkpoint_height == 6 &&
            old_anchor.inbox.last_checkpoint_height < 6
    );
    eprintln!(
        "fixed recovery R proves q={}, historical parent context previously proved q={}",
        fixed.anchor.inbox.last_checkpoint_height, old_anchor.inbox.last_checkpoint_height
    );
    let archive = parent.join("grid-archive");
    let domain = alloy_primitives::keccak256(doc.chain_id.as_bytes());
    let elbin = binary("ETNA_EL_BIN", "alethia-reth")?;
    let helper = binary("ETNA_EL_IMPORT_BIN", "etna-el-import")?;
    let stock = package().join("target/etna-signer/etna-comet-import");
    for s in [6, 12] {
        let base = parent.join(format!("g1-cp-{s}"));
        fs::create_dir(&base)?;
        let el_chain = base.join("el-genesis.json");
        fs::write(&el_chain, &f.l2.genesis.json)?;
        let donor_dir = base.join("donor-data");
        let (mut donor, _, _, engine) = el(&elbin, &donor_dir, &el_chain, &base, "donor").await?;
        for h in 1..=s {
            let b =
                if h <= 6 { old[(h - 1) as usize].clone() } else { c.cmt.envelope(h).await?.block };
            ensure!(
                engine.new_payload(&b).await? == PayloadVerdict::Valid,
                "independent recovery donor block {h}"
            );
            ensure!(
                engine
                    .forkchoice(b.header.hash_slow(), f.l2.genesis.hash, f.l2.genesis.hash)
                    .await? ==
                    PayloadVerdict::Valid
            );
        }
        donor.stop().await?;
        let source = base.join("offline-state");
        fs::create_dir_all(source.join("db"))?;
        for name in ["mdbx.dat", "database.version"] {
            fs::copy(donor_dir.join("db").join(name), source.join("db").join(name))?;
        }
        let (template, proxy, rp) = fullnode_template(&base, &home, &c.cmt).await?;
        let profile = base.join("import.json");
        write_private(
            &profile,
            serde_json::to_vec(
                &json!({"schema":1,"l1_chain_id":f.params.l1_chain_id,"l2_chain_id":f.params.l2_chain_id,"l1_http":f.anvil.http,"chain_config":commands.chain,"archive":{"comet_http":c.cmt.url(),"l2_http":f.l2.http,"comet_genesis":g,"recovery_bootstrap":bootstrap,"comet_helper":stock},"install":{"comet_binary":binary("ETNA_COMET_BIN","cometbft")?,"el_source":source,"el_chain":el_chain,"devnet_etna_timestamp":0,"comet_config":template,"comet_helper":stock,"el_helper":helper,"el_binary":elbin}}),
            )?,
        )?;
        let pkg = base.join("archive");
        let root = base.join("import");
        let preimage = archive.join(format!("{domain}-{s}.bin"));
        let [pf, pkg_path, r] = [&profile, &pkg, &root].map(|p| p.to_str().unwrap());
        let selected = s.to_string();
        let mut export = vec!["export", "--profile", pf, "--height", &selected, "--out", pkg_path];
        if s > 6 {
            export.extend(["--validator-state", preimage.to_str().unwrap()]);
        }
        cli(&base, "export", &export).await?;
        let prepared = cli(
            &base,
            "prepare",
            &["prepare", "--profile", pf, "--package", pkg_path, "--root", r],
        )
        .await?;
        ensure!(prepared["generation"] == 1 && prepared["execution_floor"] == s);
        let status = cli(&base, "install", &["install", "--profile", pf, "--root", r]).await?;
        let target = status["observed_latest_target"].as_u64().context("own latest checkpoint")?;
        ensure!(target >= 12 && status["phase"] == "installed" && status["live_trust"] == false);
        let tagged: abci::store::ImportedState =
            serde_json::from_slice(&fs::read(root.join("ready/app/abci-state.json"))?)?;
        ensure!(tagged.state.origin_height() == 6 && tagged.state.last_height == s);
        let installed: abci::GenesisDoc =
            serde_json::from_slice(&fs::read(root.join("ready/comet/config/genesis.json"))?)?;
        ensure!(installed == doc && installed.initial_height == "7");
        follow(
            f,
            c,
            commands,
            Follow { base: &base, root: &root, s, target, generation: 1, ports: (proxy, rp) },
        )
        .await?;
    }
    Ok(())
}

/// Try the same-chain public node with a different live auth endpoint and every wrong store
/// role. All must fail before opening a new app journal or making an Engine request.
async fn crosswired_refused(
    app: &Path,
    comet: &Path,
    http: &Url,
    f: &ContractFixture,
    commands: &Commands,
    proxy: u16,
) -> Result<()> {
    use alloy_provider::Provider;
    let reader = rpc::client::connect_http_with_timeout(http.clone(), Duration::from_secs(5));
    ensure!(reader.get_chain_id().await? == f.l2.provider.get_chain_id().await?);
    let ready = app.parent().unwrap();
    let sibling = ready.join("wrong-sibling");
    fs::create_dir(&sibling)?;
    for path in [app, comet, &ready.join("el"), &sibling] {
        let out = tokio::process::Command::new(CLIENT)
            .args([
                "abci",
                "--abci.addr",
                &format!("tcp://127.0.0.1:{proxy}"),
                "--fee-recipient",
                "0x0000000000000000000000000000000000000001",
                "--data-dir",
                path.to_str().unwrap(),
                "--l1.http",
                f.anvil.http.as_str(),
                "--l2.http",
                http.as_str(),
                "--l2.auth",
                f.l2.auth.as_str(),
                "--jwt.secret",
                package().join("tests/docker/jwt.hex").to_str().unwrap(),
                "--chain-config",
                commands.chain.to_str().unwrap(),
            ])
            .output()
            .await?;
        ensure!(
            out.status.code() == Some(1) &&
                String::from_utf8_lossy(&out.stderr).contains("checkpoint"),
            "cross-wired engine or wrong app role: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        if path != app {
            ensure!(!path.join("abci-state.json").exists())
        }
    }
    Ok(())
}

fn memdb_refused(base: &Path, profile: &Path, package: &Path) -> Result<()> {
    let mut config: Value = serde_json::from_slice(&fs::read(profile)?)?;
    let template = Path::new(config["install"]["comet_config"].as_str().unwrap());
    let template: toml::Table = toml::from_str(&fs::read_to_string(template)?)?;
    let foreign = base.join("config-redirect-sentinel");
    fs::create_dir(&foreign)?;
    fs::write(foreign.join("wal"), b"preserved old WAL")?;
    let aliases = [
        ("db_backend", toml::Value::from("memdb"), "goleveldb"),
        ("DB_BACKEND", toml::Value::from("memdb"), "ambiguous"),
        ("DB_DIR", toml::Value::from(foreign.display().to_string()), "ambiguous"),
        ("statesync.enable", toml::Value::from(true), "ambiguous"),
        (
            "consensus.wal_file",
            toml::Value::from(foreign.join("wal").display().to_string()),
            "ambiguous",
        ),
        (
            "CONSENSUS",
            toml::Value::Table(toml::Table::from_iter([("TIMEOUT_PROPOSE".into(), "-1s".into())])),
            "ambiguous",
        ),
    ];
    let invalid = base.join("ambiguous-template.toml");
    let profile = base.join("ambiguous-profile.json");
    config["install"]["comet_config"] = json!(invalid);
    write_private(&profile, serde_json::to_vec(&config)?)?;
    for (key, value, reason) in aliases {
        let mut candidate = template.clone();
        candidate.insert(key.into(), value);
        fs::write(&invalid, toml::to_string(&candidate)?)?;
        let root = base.join("refused-comet-template");
        let out = std::process::Command::new(CLIENT)
            .args(["abci-import", "prepare", "--profile"])
            .arg(&profile)
            .arg("--root")
            .arg(&root)
            .arg("--package")
            .arg(package)
            .output()?;
        ensure!(
            out.status.code() == Some(1) &&
                String::from_utf8_lossy(&out.stderr).contains(reason) &&
                !root.exists(),
            "effective stock alias {key}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
    }
    ensure!(
        fs::read(foreign.join("wal"))? == b"preserved old WAL" &&
            fs::read_dir(&foreign)?.count() == 1
    );
    let generated = native_config_controls(base)?;
    config["install"]["comet_config"] = json!(generated);
    write_private(&profile, serde_json::to_vec(&config)?)?;
    let out = std::process::Command::new(CLIENT)
        .args(["abci-import", "prepare", "--profile"])
        .arg(&profile)
        .arg("--root")
        .arg(base.join("accepted-stock-default"))
        .arg("--package")
        .arg(package)
        .output()?;
    ensure!(
        out.status.success(),
        "stock-generated default configuration rejected: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    Ok(())
}

/// Pin this differential to the real stock process. The intentional missing genesis stops
/// inspect immediately after native DB opening. All paths and WALs belong to the fixture.
fn native_config_controls(base: &Path) -> Result<PathBuf> {
    let binary = binary("ETNA_COMET_BIN", "cometbft")?;
    for (name, config, db, error) in [
        ("default", "", "data", "GenesisDoc"),
        ("persistent", "db_backend='goleveldb'", "data", "GenesisDoc"),
        ("uppercase-memdb", "DB_BACKEND='memdb'", "", "GenesisDoc"),
        ("uppercase-directory", "DB_DIR='redirected'", "redirected", "GenesisDoc"),
        ("dotted-sync", "\"statesync.enable\"=true\n[statesync]\nenable=false", "", "rpc_servers"),
        ("uppercase-consensus", "[CONSENSUS]\nTIMEOUT_PROPOSE='-1s'", "", "timeout_propose"),
    ] {
        let home = base.join(format!("stock-parser-{name}"));
        fs::create_dir_all(home.join("config"))?;
        fs::write(home.join("config/config.toml"), config)?;
        let out = std::process::Command::new(&binary)
            .env_clear()
            .env("HOME", &home)
            .env("CMTHOME", &home)
            .arg("inspect")
            .arg("--home")
            .arg(&home)
            .output()?;
        ensure!(
            !out.status.success() && String::from_utf8_lossy(&out.stderr).contains(error),
            "{name}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        for storage in ["data", "redirected"] {
            for role in ["state.db", "blockstore.db"] {
                ensure!(
                    home.join(storage).join(role).is_dir() == (db == storage),
                    "unexpected stock {name}/{storage}/{role}"
                );
            }
        }
    }
    let home = base.join("generated-stock-template");
    fs::create_dir(&home)?;
    let output = std::process::Command::new(binary)
        .env_clear()
        .env("HOME", &home)
        .env("CMTHOME", &home)
        .arg("inspect")
        .arg("--home")
        .arg(&home)
        .output()?;
    ensure!(
        !output.status.success() && String::from_utf8_lossy(&output.stderr).contains("GenesisDoc")
    );
    let generated = home.join("config/config.toml");
    ensure!(generated.metadata()?.len() > 10_000);
    Ok(generated)
}

fn refuse_ambiguous_launchers(base: &Path, app: &Path, comet: &Path) -> Result<()> {
    for (script, overrides) in [
        (
            "script/start_etna_full_node.py",
            &["ETNA_COMET_ENV_JSON", "ETNA_COMET_CONTAINER", "ETNA_COMET_COMMAND_JSON"][..],
        ),
        (
            "script/etna_validator.py",
            &["ETNA_SIGNER_COMMAND_JSON", "ETNA_COMET_ENV_JSON", "ETNA_SIGNER_ADDR"][..],
        ),
    ] {
        for name in overrides {
            let out = std::process::Command::new("python3")
                .arg(package().join(script))
                .env("ETNA_CLIENT_BIN", CLIENT)
                .env("ETNA_APP_STORE", app)
                .env("ETNA_COMET_HOME", comet)
                .env(name, "{}")
                .output()?;
            ensure!(
                !out.status.success() &&
                    String::from_utf8_lossy(&out.stderr).contains("refuses launch override"),
                "opaque imported adapter reached signer access: {}",
                String::from_utf8_lossy(&out.stderr)
            );
        }
    }
    // A byte-for-byte equivalent decoded imported state remains tagged after a publisher
    // reorders the root fields, escapes a property name or inserts legal JSON whitespace.
    let journal: Value = serde_json::from_slice(&fs::read(app.join("abci-state.json"))?)?;
    let alternate = format!(
        "{}{{\"state\":{},\"schema\":1,\"installa\\u0074ion_id\":{}}}",
        " ".repeat(2 << 20),
        journal["state"],
        journal["installation_id"]
    );
    ensure!(serde_json::from_str::<Value>(&alternate)? == journal);
    let detached = base.join("detached-journal");
    let empty = base.join("detached-comet");
    fs::create_dir(&detached)?;
    fs::create_dir_all(empty.join("config"))?;
    fs::write(detached.join("abci-state.json"), alternate)?;
    fs::write(empty.join("config/config.toml"), "priv_validator_laddr=''")?;
    for script in ["start_etna_full_node.py", "etna_validator.py"] {
        let out = std::process::Command::new("python3")
            .arg(package().join("script").join(script))
            .env("ETNA_APP_STORE", &detached)
            .env("ETNA_COMET_HOME", &empty)
            .env("ETNA_COMET_BIN", "/usr/bin/true")
            .output()?;
        ensure!(
            !out.status.success() &&
                String::from_utf8_lossy(&out.stderr)
                    .contains("incomplete or mixed import paths"),
            "detached full imported journal fell through to legacy launcher: {script}"
        );
    }
    let shadow = comet.join("config.toml");
    fs::write(&shadow, "db_backend = 'memdb'")?;
    let out = std::process::Command::new(CLIENT)
        .args(["abci-import", "check-runtime", "--app-dir"])
        .arg(app)
        .arg("--comet-home")
        .arg(comet)
        .output()?;
    fs::rename(shadow, base.join("refused-shadow.toml"))?;
    ensure!(!out.status.success() && String::from_utf8_lossy(&out.stderr).contains("shadowing"));
    Ok(())
}

fn fixed_origin_store_swaps(base: &Path, root: &Path, after_progress: bool) -> Result<()> {
    let home = root.join("ready/comet");
    let check = || {
        std::process::Command::new(CLIENT)
            .args(["abci-import", "check-runtime", "--app-dir"])
            .arg(root.join("ready/app"))
            .arg("--comet-home")
            .arg(&home)
            .output()
    };
    let different = base.join(if after_progress { "foreign-after" } else { "foreign-before" });
    fs::create_dir_all(different.join("data"))?;
    let id = alloy_primitives::B256::repeat_byte(0x45);
    write_private(
        &different.join(".etna-stock-staging.json"),
        serde_json::to_vec(&json!({"schema":1,"installation_id":id,"fixed_origin":true}))?,
    )?;
    let out = std::process::Command::new(package().join("target/etna-signer/etna-comet-import"))
        .args(["bind-stores", "--home"])
        .arg(&different)
        .arg("--installation-id")
        .arg(id.to_string())
        .arg("--fixed-origin")
        .output()?;
    ensure!(
        out.status.success(),
        "foreign fixture creation: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    let roles =
        if after_progress { &["evidence"][..] } else { &["state", "blockstore", "evidence"][..] };
    for role in roles {
        let db = home.join(format!("data/{role}.db"));
        let other = different.join(format!("data/{role}.db"));
        let save = different.join(format!("original-{role}"));
        fs::create_dir(&save)?;
        move_contents(&db, &save)?;
        move_contents(&other, &db)?;
        let out = check()?;
        move_contents(&db, &other)?;
        move_contents(&save, &db)?;
        ensure!(
            !out.status.success(),
            "foreign {role} contents accepted inside original DB directory"
        );
        ensure!(
            out.status.code() == Some(1) &&
                String::from_utf8_lossy(&out.stderr).contains("database"),
            "unexpected refusal for foreign {role} ({:?}): {}",
            out.status.code(),
            String::from_utf8_lossy(&out.stderr)
        );
    }
    ensure!(check()?.status.success());
    Ok(())
}
fn move_contents(from: &Path, to: &Path) -> Result<()> {
    for entry in fs::read_dir(from)? {
        let entry = entry?;
        fs::rename(entry.path(), to.join(entry.file_name()))?;
    }
    Ok(())
}

async fn crash_stock_export(base: &Path, original: &Path, preimage: &Path) -> Result<()> {
    use std::{
        ffi::CString,
        io::Write,
        os::unix::{
            ffi::OsStrExt,
            fs::{OpenOptionsExt, PermissionsExt},
        },
        process::Stdio,
    };
    let mut profile: Value = serde_json::from_slice(&fs::read(original)?)?;
    let native = profile["archive"]["comet_helper"].as_str().unwrap();
    let fifo = base.join("crash-stock.fifo");
    let pid = base.join("native-go.pid");
    let inject = base.join("inject-stock");
    fs::write(&inject, b"1")?;
    let name = CString::new(fifo.as_os_str().as_bytes())?;
    ensure!(unsafe { libc::mkfifo(name.as_ptr(), 0o600) } == 0);
    let wrapper = base.join("test-stock-exec");
    // A testing interposer changes only the input FD to a deliberately incomplete FIFO;
    // the final executable is the actual pinned Go helper, including its signal handler.
    let script = format!(
        "#!/usr/bin/python3\nimport os,sys\nfrom pathlib import Path\nnative={}\nargs=[native]+sys.argv[1:]\nif Path({}).exists():\n Path({}).write_text(str(os.getpid()))\n args.extend(['--package',{}])\nos.execv(native,args)\n",
        serde_json::to_string(native)?,
        serde_json::to_string(&inject)?,
        serde_json::to_string(&pid)?,
        serde_json::to_string(&fifo)?
    );
    fs::write(&wrapper, script)?;
    fs::set_permissions(&wrapper, fs::Permissions::from_mode(0o700))?;
    profile["archive"]["comet_helper"] = json!(wrapper);
    let pf = base.join("fault-export.json");
    write_private(&pf, serde_json::to_vec(&profile)?)?;
    let target = base.join("fault-archive");
    let op = base.join(".fault-archive.etna-export");
    let work = op.join(".checkpoint-work/go");
    let args = [
        "abci-import",
        "export",
        "--profile",
        pf.to_str().unwrap(),
        "--height",
        "6",
        "--out",
        target.to_str().unwrap(),
        "--validator-state",
        preimage.to_str().unwrap(),
    ];
    for quit in [true, false] {
        let mut child = tokio::process::Command::new(CLIENT)
            .args(args)
            .stderr(Stdio::piped())
            .stdout(Stdio::null())
            .kill_on_drop(true)
            .spawn()?;
        let mut writer = tokio::time::timeout(Duration::from_secs(40), async {
            loop {
                if let Ok(f) =
                    fs::OpenOptions::new().write(true).custom_flags(libc::O_NONBLOCK).open(&fifo)
                {
                    return Ok::<_, anyhow::Error>(f)
                }
                ensure!(
                    child.try_wait()?.is_none(),
                    "stock export exited before reading test FIFO"
                );
                tokio::time::sleep(Duration::from_millis(5)).await;
            }
        })
        .await??;
        writer.write_all(
            br#"{"schema":1,"blocks":[{"block":"0x01","commit":"0x02","validators":[]},"#,
        )?;
        let spool = tokio::time::timeout(Duration::from_secs(10), async {
            loop {
                for e in fs::read_dir(&work)? {
                    let e = e?;
                    if e.file_name().to_string_lossy().starts_with("etna-comet-import-") {
                        let b = e.path().join("blocks");
                        if b.metadata().is_ok_and(|m| m.len() > 4) {
                            return Ok::<_, anyhow::Error>(b)
                        }
                    }
                }
                tokio::time::sleep(Duration::from_millis(5)).await
            }
        })
        .await??;
        if quit {
            let native_pid = fs::read_to_string(&pid)?.parse()?;
            ensure!(unsafe { libc::kill(native_pid, libc::SIGQUIT) } == 0);
        } else {
            child.start_kill()?;
        }
        let out = tokio::time::timeout(Duration::from_secs(20), child.wait_with_output()).await??;
        if quit {
            ensure!(
                out.status.code() == Some(1) &&
                    String::from_utf8_lossy(&out.stderr)
                        .contains("without a bound contradiction receipt"),
                "Go crash fabricated safety: {}",
                String::from_utf8_lossy(&out.stderr)
            );
        }
        ensure!(
            spool.is_file() &&
                !target.exists() &&
                !base.join(".fault-archive.checkpoint-halted.json").exists()
        );
        tokio::time::timeout(Duration::from_secs(20), async {
            loop {
                if abci::ownership::acquire_activation(&op, alloy_primitives::B256::ZERO).is_ok() {
                    break
                }
                tokio::time::sleep(Duration::from_millis(10)).await
            }
        })
        .await?;
        drop(writer);
        ensure!(spool.is_file(), "real native interruption must leave its spool in owned staging");
    }
    fs::remove_file(inject)?;
    let output = tokio::process::Command::new(CLIENT).args(args).output().await?;
    ensure!(
        output.status.success() &&
            target.join("blocks.jsonl").is_file() &&
            !op.join(".checkpoint-work").exists(),
        "failed to reclaim private stock spool: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    Ok(())
}

mod long_fence;

mod forced;

mod helper_failures;
