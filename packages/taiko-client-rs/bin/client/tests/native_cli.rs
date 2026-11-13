//! Actual CLI process coverage of the fresh native deployment interface, without Docker.

use axum::{Json, Router, routing::post};
use serde_json::{Value, json};
use std::{
    os::unix::fs::PermissionsExt,
    process::Output,
    sync::{Arc, Mutex},
};
use tokio::process::Command;

async fn run(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_taiko-client"))
        .env_clear()
        .args(args)
        .output()
        .await
        .expect("CLI process")
}

fn stderr(output: &Output) -> String {
    String::from_utf8(output.stderr.clone()).unwrap()
}

struct Rpc {
    url: String,
    methods: Arc<Mutex<Vec<String>>>,
    task: tokio::task::JoinHandle<()>,
}
impl Drop for Rpc {
    fn drop(&mut self) {
        self.task.abort();
    }
}
async fn rpc(chain_id: &'static str) -> Rpc {
    let methods = Arc::new(Mutex::new(Vec::new()));
    let recorded = methods.clone();
    let app = Router::new().route(
        "/",
        post(move |Json(body): Json<Value>| {
            let recorded = recorded.clone();
            async move {
                let method = body["method"].as_str().unwrap();
                recorded.lock().unwrap().push(method.to_owned());
                Json(json!({"jsonrpc":"2.0", "id":body["id"], "result":
                if method == "eth_chainId" { json!(chain_id) } else { Value::Null }}))
            }
        }),
    );
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", listener.local_addr().unwrap());
    let task = tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    Rpc { url, methods, task }
}

#[tokio::test]
async fn help_lists_every_command() {
    let help = run(&["--help"]).await;
    assert!(help.status.success());
    let help = String::from_utf8(help.stdout).unwrap();
    for command in ["abci", "abci-genesis", "abci-committee-record", "lander"] {
        assert!(help.contains(command));
    }
}

#[tokio::test]
async fn both_bootstrap_commands_accept_full_l1_id_before_authenticated_state_reads() {
    for command in ["abci-genesis", "abci-committee-record"] {
        let rpc = rpc("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff").await;
        let mut args = vec![command, "--l1.http", &rpc.url, "--l2.chain-id", "167001"];
        if command == "abci-committee-record" {
            args.extend(["--genesis-cutoff", "0"]);
        }
        let output = run(&args).await;
        assert!(!output.status.success(), "fixture has no initialized Inbox or final block");
        let methods = rpc.methods.lock().unwrap();
        assert_eq!(methods[0], "eth_chainId");
        assert!(
            methods.iter().any(|method| method == "eth_getBlockByNumber"),
            "full-width ID must reach authenticated state reads: {}",
            stderr(&output)
        );
        assert!(output.stdout.is_empty(), "failed bootstrap must not publish partial JSON");
    }
}

#[tokio::test]
async fn unknown_configuration_is_rejected_without_rpc_or_output_replacement() {
    let rpc = rpc("0x1").await;
    let dir = tempfile::tempdir().unwrap();
    let config = dir.path().join("chain.toml");
    let out = dir.path().join("genesis.json");
    std::fs::write(&out, b"existing genesis").unwrap();
    std::fs::write(&config, "unknown_key = 12").unwrap();
    let result = run(&[
        "abci-genesis",
        "--l1.http",
        &rpc.url,
        "--l2.chain-id",
        "167001",
        "--chain-config",
        config.to_str().unwrap(),
        "--out",
        out.to_str().unwrap(),
    ])
    .await;
    assert!(!result.status.success());
    assert!(stderr(&result).contains("unknown field"), "{}", stderr(&result));
    assert!(rpc.methods.lock().unwrap().is_empty());
    assert_eq!(std::fs::read(&out).unwrap(), b"existing genesis");
}

#[tokio::test]
async fn proposer_requires_explicit_beneficiary_and_checks_l2_id_without_truncation() {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("app");
    let endpoint = rpc("0x100028c59").await; // 2^32 + 167001, never the builtin devnet.
    let base = [
        "abci",
        "--l1.http",
        &endpoint.url,
        "--l2.http",
        &endpoint.url,
        "--l2.auth",
        &endpoint.url,
        "--jwt.secret",
        "/not-read",
        "--data-dir",
        data.to_str().unwrap(),
    ];
    let missing = run(&base).await;
    assert!(!missing.status.success());
    assert!(stderr(&missing).contains("--fee-recipient"));
    assert!(endpoint.methods.lock().unwrap().is_empty());
    let mut args = base.to_vec();
    args.extend(["--fee-recipient", "0x7777777777777777777777777777777777777777"]);
    let result = run(&args).await;
    assert!(!result.status.success());
    assert!(stderr(&result).contains("4295134297"), "{}", stderr(&result));
    assert_eq!(*endpoint.methods.lock().unwrap(), ["eth_chainId"]);

    let huge = rpc("0x10000000000000000").await;
    let result = run(&[
        "abci",
        "--l1.http",
        &huge.url,
        "--l2.http",
        &huge.url,
        "--l2.auth",
        &huge.url,
        "--jwt.secret",
        "/not-read",
        "--data-dir",
        data.to_str().unwrap(),
        "--fee-recipient",
        "0x7777777777777777777777777777777777777777",
    ])
    .await;
    assert!(!result.status.success());
    assert!(stderr(&result).contains("exceeds the supported uint64"), "{}", stderr(&result));
}

#[tokio::test]
async fn explicit_l1_domain_mismatch_refuses_bootstrap_before_contract_reads() {
    let endpoint = rpc("0x2").await;
    let dir = tempfile::tempdir().unwrap();
    let config = dir.path().join("chain.toml");
    std::fs::write(&config, "l1_chain_id = '1'\n").unwrap();
    for command in ["abci-genesis", "abci-committee-record"] {
        endpoint.methods.lock().unwrap().clear();
        let mut args = vec![
            command,
            "--l1.http",
            &endpoint.url,
            "--l2.chain-id",
            "167001",
            "--chain-config",
            config.to_str().unwrap(),
        ];
        if command == "abci-committee-record" {
            args.extend(["--genesis-cutoff", "0"]);
        }
        let result = run(&args).await;
        assert!(!result.status.success());
        assert!(
            stderr(&result).contains("configured L1 chain id 1 differs from RPC chain id 2"),
            "{}",
            stderr(&result)
        );
        assert_eq!(*endpoint.methods.lock().unwrap(), ["eth_chainId"]);
    }
}

#[tokio::test]
async fn recovery_prepare_requires_explicit_target() {
    let output = run(&[
        "abci-recover",
        "prepare",
        "--l1.http",
        "http://127.0.0.1:1/",
        "--l2.http",
        "http://127.0.0.1:1/",
        "--l2.auth",
        "http://127.0.0.1:1/",
        "--jwt.secret",
        "/missing-jwt",
        "--out",
        "/not-created/plan.json",
    ])
    .await;
    assert!(!output.status.success());
    assert!(stderr(&output).contains("--generation"), "{}", stderr(&output));
    for action in ["install", "status"] {
        let output = run(&["abci-recover", action, "--help"]).await;
        assert!(output.status.success(), "{action}: {}", stderr(&output));
    }
}

#[tokio::test]
async fn recovery_rejects_zero_before_network_and_redacts_private_input() {
    // L2 answers eth_chainId (167001), so the failure is on the credential-bearing L1 endpoint.
    let l2 = rpc("0x28c59").await;
    let dir = tempfile::tempdir().unwrap();
    let out = dir.path().join("plan.json");
    let out = out.to_str().unwrap();
    let prepare = |l1: &'static str, generation: &'static str| {
        let args = [
            "abci-recover",
            "prepare",
            "--l1.http",
            l1,
            "--l2.http",
            &l2.url,
            "--l2.auth",
            "http://127.0.0.1:1/",
            "--jwt.secret",
            "/missing-jwt",
            "--generation",
            generation,
            "--out",
            out,
            "--json",
        ]
        .map(str::to_owned);
        async move { run(&args.iter().map(String::as_str).collect::<Vec<_>>()).await }
    };
    let zero = prepare("http://127.0.0.1:1/", "0").await;
    assert!(!zero.status.success());
    assert!(stderr(&zero).contains("nonzero"), "{}", stderr(&zero));
    assert!(l2.methods.lock().unwrap().is_empty(), "the generation is checked before any RPC");
    let result = prepare("http://alice:password@127.0.0.1:1/secret-token", "1").await;
    assert!(!result.status.success());
    assert!(result.stdout.is_empty());
    assert!(stderr(&result).contains("l1.http"), "{}", stderr(&result));
    for secret in ["alice", "password", "secret-token"] {
        assert!(!stderr(&result).contains(secret), "{}", stderr(&result));
    }
    assert_eq!(*l2.methods.lock().unwrap(), ["eth_chainId"]);
    assert!(!std::path::Path::new(out).exists());
    let result = run(&["abci-recover", "status", "--plan", "/missing", "--json"]).await;
    assert!(!result.status.success());
    assert!(result.stdout.is_empty());
}

#[tokio::test]
async fn recovery_app_refuses_external_owner_before_rpc() {
    use std::{fs::OpenOptions, os::unix::fs::OpenOptionsExt};
    let root = tempfile::tempdir().unwrap();
    let directory = root.path().join("app");
    std::fs::create_dir(&directory).unwrap();
    let file = OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .mode(0o600)
        .open(
            abci::ownership::ComponentPaths::new(abci::ownership::ComponentRole::App, &directory)
                .unwrap()
                .lock_path()
                .unwrap(),
        )
        .unwrap();
    file.try_lock().unwrap();
    let output = run(&[
        "abci",
        "--l1.http",
        "http://127.0.0.1:1",
        "--l2.http",
        "http://127.0.0.1:1",
        "--l2.auth",
        "http://127.0.0.1:1",
        "--jwt.secret",
        "/not-read",
        "--data-dir",
        directory.to_str().unwrap(),
        "--fee-recipient",
        "0x7777777777777777777777777777777777777777",
    ])
    .await;
    assert!(!output.status.success());
    assert!(stderr(&output).contains("ownership is busy"), "{}", stderr(&output));
}

#[tokio::test]
async fn recovery_lander_refuses_external_owner_before_key_or_rpc() {
    use abci::ownership::{ComponentLease, ComponentPaths, ComponentRole};
    let root = tempfile::tempdir().unwrap();
    let directory = root.path().join("lander");
    std::fs::create_dir(&directory).unwrap();
    let paths = ComponentPaths::new(ComponentRole::Lander, &directory).unwrap();
    let _owner = ComponentLease::acquire(&paths).unwrap();
    std::fs::write(directory.join("lander-state.json"), "immutable signed landing bytes").unwrap();
    let output = run(&[
        "lander",
        "--l1.http",
        "http://127.0.0.1:1",
        "--l2.http",
        "http://127.0.0.1:1",
        "--l2.auth",
        "http://127.0.0.1:1",
        "--jwt.secret",
        "/not-read",
        "--comet.http",
        "http://127.0.0.1:1",
        "--signing-key",
        "/not-read",
        "--data-dir",
        directory.to_str().unwrap(),
        "--max-blocks",
        "6",
        "--max-fee-per-gas",
        "2",
        "--max-priority-fee-per-gas",
        "1",
        "--max-fee-per-blob-gas",
        "1",
        "--sidecar",
        "eip4844",
    ])
    .await;
    assert!(!output.status.success());
    assert!(stderr(&output).contains("ownership is busy"), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(directory.join("lander-state.json")).unwrap(),
        "immutable signed landing bytes"
    );
}

/// `status` only reads: it reports an absent or interrupted root and never creates, locks or
/// changes anything beside it.
#[tokio::test]
async fn import_status_reports_absent_and_interrupted_roots_without_touching_neighbours() {
    let dir = tempfile::tempdir().unwrap();
    let parent = dir.path().canonicalize().unwrap();
    let hrs = parent.join("priv_validator_state.json");
    let wal = parent.join("wal");
    std::fs::write(&hrs, b"existing signing state").unwrap();
    std::fs::write(&wal, b"existing consensus wal").unwrap();
    let root = parent.join("import");
    let args = ["abci-import", "status", "--root", root.to_str().unwrap()];
    let status = || run(&args);
    let out = status().await;
    assert!(out.status.success(), "{}", stderr(&out));
    let view: Value = serde_json::from_slice(&out.stdout).unwrap();
    assert_eq!(view, json!({"phase":"absent","generation":null,"execution_floor":null}));
    assert!(!root.exists());
    std::fs::create_dir_all(root.join("stage/ready/app")).unwrap();
    std::fs::write(root.join("stage/ready/app/abci-state.json"), b"{\"half").unwrap();
    let out = status().await;
    assert!(out.status.success(), "{}", stderr(&out));
    let view: Value = serde_json::from_slice(&out.stdout).unwrap();
    assert_eq!(view, json!({"phase":"interrupted","generation":null,"execution_floor":null}));
    assert!(!root.join("import.lock").exists());
    assert!(!root.join("ready").exists());
    assert_eq!(std::fs::read(&hrs).unwrap(), b"existing signing state");
    assert_eq!(std::fs::read(&wal).unwrap(), b"existing consensus wal");
}

/// A Safety latch is terminal: `import` refuses before reading any input or contacting L1.
#[tokio::test]
async fn halted_import_stays_terminal_even_if_sources_are_offline() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path().canonicalize().unwrap();
    std::fs::set_permissions(&root, std::fs::Permissions::from_mode(0o700)).unwrap();
    std::fs::write(
        root.join("halted.json"),
        br#"{"class":"safety","detail":"conflicting authenticated roots"}"#,
    )
    .unwrap();
    let out = run(&[
        "abci-import",
        "import",
        "--l1.http",
        "http://127.0.0.1:1",
        "--l2.chain-id",
        "167001",
        "--package",
        "/nonexistent/package",
        "--root",
        root.to_str().unwrap(),
        "--el-source",
        "/nonexistent/el",
        "--el-chain",
        "/nonexistent/chain.json",
        "--el-helper",
        "/nonexistent/etna-el-import",
        "--comet-helper",
        "/nonexistent/etna-comet-import",
        "--comet-config",
        "/nonexistent/config.toml",
    ])
    .await;
    assert_eq!(out.status.code(), Some(2), "{}", stderr(&out));
    assert!(stderr(&out).contains("conflicting authenticated roots"), "{}", stderr(&out));
    assert!(out.stdout.is_empty());
    assert!(!root.join("stage").exists());
    let status = run(&["abci-import", "status", "--root", root.to_str().unwrap()]).await;
    assert!(status.status.success());
    let view: Value = serde_json::from_slice(&status.stdout).unwrap();
    assert_eq!(view["phase"], "halted");
}
