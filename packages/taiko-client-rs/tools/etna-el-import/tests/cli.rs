use alloy_genesis::Genesis;
use alloy_primitives::B256;
use etna_el_import::{ElTrust, HeaderManifest};
use reth_chainspec::EthChainSpec;
use reth_db::mdbx::DatabaseArguments;
use std::{path::PathBuf, process::Command};

struct Fixture {
    _root: tempfile::TempDir,
    data: PathBuf,
    chain: PathBuf,
    manifest: PathBuf,
    headers: HeaderManifest,
    trust: ElTrust,
}

fn fixture() -> Fixture {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("el");
    std::fs::create_dir(&data).unwrap();
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(&data, std::fs::Permissions::from_mode(0o700)).unwrap();
    drop(
        reth_db::init_db(
            data.join("db"),
            DatabaseArguments::default().with_growth_step(Some(4 * 1024 * 1024)),
        )
        .unwrap(),
    );
    let genesis: Genesis = serde_json::from_value(serde_json::json!({
        "config":{"chainId":167001},"gasLimit":"0x2aea540","difficulty":"0x0",
        "timestamp":"0x0","extraData":"0x","alloc":{}
    }))
    .unwrap();
    let spec = alethia_reth_chainspec::spec::TaikoChainSpec::from(genesis.clone());
    let header = spec.genesis_header().clone();
    let trust = ElTrust {
        chain_id: 167001,
        genesis_hash: header.hash_slow(),
        terminal_hash: header.hash_slow(),
        state_root: header.state_root,
    };
    let headers = HeaderManifest {
        schema: 1,
        installation_id: B256::repeat_byte(0x72),
        chain_id: 167001,
        origin: 0,
        unsettled_limit: 6,
        finalized_height: 0,
        finalized_hash: trust.genesis_hash,
        headers: vec![header],
    };
    let chain = root.path().join("chain.json");
    let manifest = root.path().join("headers.json");
    std::fs::write(&chain, serde_json::to_vec(&genesis).unwrap()).unwrap();
    std::fs::write(&manifest, serde_json::to_vec(&headers).unwrap()).unwrap();
    Fixture { _root: root, data: data.canonicalize().unwrap(), chain, manifest, headers, trust }
}

fn command(f: &Fixture, mode: &str, trusted: bool) -> Command {
    let mut command = Command::new(env!("CARGO_BIN_EXE_etna-el-import"));
    command
        .arg(mode)
        .arg("--datadir")
        .arg(&f.data)
        .arg("--chain")
        .arg(&f.chain)
        .arg("--manifest")
        .arg(&f.manifest)
        .args(["--chain-id", "167001"]);
    if trusted {
        command.args([
            "--trusted-el-hash",
            &f.trust.terminal_hash.to_string(),
            "--trusted-state-root",
            &f.trust.state_root.to_string(),
            "--trusted-genesis-hash",
            &f.trust.genesis_hash.to_string(),
        ]);
    }
    command
}

#[test]
fn refuses_self_described_roots_without_trusted_caller_arguments() {
    let f = fixture();
    let before = std::fs::metadata(f.data.join("db/mdbx.dat")).unwrap().modified().unwrap();
    let output = command(&f, "verify", false).output().unwrap();
    assert_eq!(output.status.code(), Some(2));
    assert_eq!(std::fs::metadata(f.data.join("db/mdbx.dat")).unwrap().modified().unwrap(), before);
}

#[test]
fn verifies_then_installs_a_real_empty_state_and_refuses_reinstallation() {
    let f = fixture();
    let output = command(&f, "verify", true).output().unwrap();
    assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
    let receipt: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(receipt["installed"], false);
    assert_eq!(receipt["state_floor"], serde_json::Value::Null);
    let claim = serde_json::json!({"schema":1,"installation_id":f.headers.installation_id,
        "manifest_hash":f.headers.verify(&f.trust).unwrap().manifest_hash().unwrap()});
    let path = f.data.join(".etna-el-import-staging.json");
    std::fs::write(&path, serde_json::to_vec(&claim).unwrap()).unwrap();
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600)).unwrap();
    let scratch = tempfile::tempdir().unwrap();
    let output =
        command(&f, "install", true).arg("--scratch-parent").arg(scratch.path()).output().unwrap();
    assert!(std::fs::read_dir(scratch.path()).unwrap().next().is_none());
    assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
    let receipt: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(receipt["installed"], true);
    assert_eq!(receipt["state_floor"], 0);
    assert_eq!(receipt["helper_version"], "0.1.0");
    let before = std::fs::metadata(f.data.join("db/mdbx.dat")).unwrap().modified().unwrap();
    assert!(!command(&f, "install", true).output().unwrap().status.success());
    assert_eq!(std::fs::metadata(f.data.join("db/mdbx.dat")).unwrap().modified().unwrap(), before);
}

#[test]
fn review_verifies_readonly_source_with_private_external_scratch() {
    use std::os::unix::fs::PermissionsExt;
    let f = fixture();
    let database = f.data.join("db");
    let scratch = tempfile::tempdir().unwrap();
    let entries = |path: &std::path::Path| {
        let mut names: Vec<_> =
            std::fs::read_dir(path).unwrap().map(|e| e.unwrap().file_name()).collect();
        names.sort();
        names
    };
    let lock = database.join("mdbx.lck");
    if lock.exists() {
        std::fs::remove_file(lock).unwrap();
    }
    let contents = entries(&database);
    let before = std::fs::metadata(&f.data).unwrap().modified().unwrap();
    for path in [&database, &f.data] {
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o500)).unwrap();
    }
    for explicit in [false, true] {
        let mut cmd = command(&f, "verify", true);
        if explicit {
            cmd.arg("--scratch-parent").arg(scratch.path());
        }
        let output = cmd.output().unwrap();
        assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
        assert_eq!(entries(&database), contents);
        assert_eq!(std::fs::metadata(&f.data).unwrap().modified().unwrap(), before);
        assert!(entries(scratch.path()).is_empty());
    }
    for path in [&database, &f.data] {
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o700)).unwrap();
    }
}

#[test]
fn missing_code_is_incomplete_and_present_wrong_code_is_bad_input() {
    use alloy_primitives::{Address, Bytes, keccak256};
    use reth_db_api::{
        Database, tables,
        transaction::{DbTx, DbTxMut},
    };
    use reth_primitives_traits::{Account, Bytecode};
    let f = fixture();
    let hash = keccak256([0x60, 0x01]);
    let set = |wrong_code| {
        let db = reth_db::open_db(f.data.join("db"), DatabaseArguments::test()).unwrap();
        let tx = db.tx_mut().unwrap();
        tx.put::<tables::PlainAccountState>(
            Address::repeat_byte(0x34),
            Account { bytecode_hash: Some(hash), ..Default::default() },
        )
        .unwrap();
        if wrong_code {
            tx.put::<tables::Bytecodes>(hash, Bytecode::new_raw(Bytes::from_static(&[0x60, 0x02])))
                .unwrap();
        }
        tx.commit().unwrap();
    };
    set(false);
    let missing = command(&f, "verify", true).output().unwrap();
    assert_eq!(missing.status.code(), Some(3), "{}", String::from_utf8_lossy(&missing.stderr));
    assert!(String::from_utf8_lossy(&missing.stderr).contains("missing referenced bytecode"));
    set(true);
    let wrong = command(&f, "verify", true).output().unwrap();
    assert_eq!(wrong.status.code(), Some(1), "{}", String::from_utf8_lossy(&wrong.stderr));
    assert!(String::from_utf8_lossy(&wrong.stderr).contains("bytecode content does not match"));
}

#[test]
fn malformed_database_version_is_a_candidate_but_missing_file_is_unavailable() {
    let f = fixture();
    let version = f.data.join("db/database.version");
    std::fs::write(&version, [0xff]).unwrap();
    let bad = command(&f, "verify", true).output().unwrap();
    assert_eq!(bad.status.code(), Some(1), "{}", String::from_utf8_lossy(&bad.stderr));
    std::fs::remove_file(version).unwrap();
    let missing = command(&f, "verify", true).output().unwrap();
    assert_eq!(missing.status.code(), Some(3), "{}", String::from_utf8_lossy(&missing.stderr));
}
