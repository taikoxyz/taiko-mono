//! Actual CLI process coverage of the fresh native deployment interface, without Docker.

use axum::{Json, Router, routing::post};
use serde_json::{Value, json};
use std::{
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
    let data = tempfile::tempdir().unwrap();
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
        data.path().to_str().unwrap(),
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
        data.path().to_str().unwrap(),
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
    let output =
        run(&["abci-recover", "prepare", "--profile", "node.toml", "--root", "private"]).await;
    assert!(!output.status.success());
    assert!(stderr(&output).contains("--generation"), "{}", stderr(&output));
    let output = run(&["abci-recover", "status", "--help"]).await;
    assert!(output.status.success());
}

#[tokio::test]
async fn recovery_rejects_zero_before_profile_or_network_and_redacts_private_input() {
    let zero = run(&[
        "abci-recover",
        "prepare",
        "--profile",
        "/missing-private-profile",
        "--generation",
        "0",
        "--root",
        "/not-created",
    ])
    .await;
    assert!(!zero.status.success());
    assert!(stderr(&zero).contains("nonzero"), "{}", stderr(&zero));
    let dir = tempfile::tempdir().unwrap();
    let profile = dir.path().join("profile.toml");
    std::fs::write(
        &profile,
        "l1_http = 'https://alice:password@example.test/secret-token'\nunknown = 'PRIVATE-KEY'\n",
    )
    .unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&profile, std::fs::Permissions::from_mode(0o600)).unwrap();
    }
    let root = dir.path().join("not-created");
    let result = run(&[
        "abci-recover",
        "prepare",
        "--profile",
        profile.to_str().unwrap(),
        "--generation",
        "1",
        "--root",
        root.to_str().unwrap(),
        "--json",
    ])
    .await;
    assert!(!result.status.success());
    assert!(result.stdout.is_empty());
    assert!(!root.exists());
    for secret in ["alice", "password", "secret-token", "PRIVATE-KEY"] {
        assert!(!stderr(&result).contains(secret));
    }
    let result = run(&[
        "abci-recover",
        "status",
        "--root",
        root.to_str().unwrap(),
        "--plan",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "--json",
    ])
    .await;
    assert!(!result.status.success());
    assert!(result.stdout.is_empty());
    assert!(!root.exists());
}

#[tokio::test]
async fn recovery_app_refuses_external_owner_before_rpc() {
    use std::{fs::OpenOptions, os::unix::fs::OpenOptionsExt};
    let dir = tempfile::tempdir().unwrap();
    let file = OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .mode(0o600)
        .open(
            abci::ownership::ComponentPaths::new(abci::ownership::ComponentRole::App, dir.path())
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
        dir.path().to_str().unwrap(),
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
    let _owner = ComponentLease::acquire(&paths, None).unwrap();
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
        "--max-blobs",
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

#[tokio::test]
async fn recovery_native_app_joins_only_its_matching_inherited_grant() {
    use abci::ownership::{
        ComponentLease, ComponentPaths, ComponentRole, OwnerGrant, acquire_activation,
    };
    use alloy_primitives::B256;
    let root = tempfile::tempdir().unwrap();
    let directory = root.path().join("app");
    std::fs::create_dir(&directory).unwrap();
    let activation = acquire_activation(root.path(), B256::ZERO).unwrap();
    let paths = ComponentPaths::new(ComponentRole::App, &directory).unwrap();
    let leases = [ComponentLease::acquire(&paths, None).unwrap()];
    let grant = OwnerGrant::for_child(&activation, &leases, 0).unwrap();
    let descriptors = grant.descriptors();
    let mut command = Command::new(env!("CARGO_BIN_EXE_taiko-client"));
    command.env_clear().envs(grant.environment()).args([
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
    ]);
    unsafe {
        command.pre_exec(move || {
            for fd in &descriptors {
                if libc::fcntl(*fd, libc::F_SETFD, 0) == -1 {
                    return Err(std::io::Error::last_os_error());
                }
            }
            Ok(())
        });
    }
    let output = command.output().await.unwrap();
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("l2.http"),
        "matching grant must reach RPC: {}",
        stderr(&output)
    );
    assert!(!stderr(&output).contains("ownership is busy"));
    assert!(ComponentLease::acquire(&paths, None).is_err());
}
