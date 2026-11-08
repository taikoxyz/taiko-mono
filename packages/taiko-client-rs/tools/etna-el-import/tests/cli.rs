use alloy_genesis::Genesis;
use etna_el_import::{ElTrust, HeaderManifest};
use reth_chainspec::EthChainSpec;
use reth_db::mdbx::DatabaseArguments;
use std::{
    path::{Path, PathBuf},
    process::Command,
};

struct Fixture {
    root: tempfile::TempDir,
    /// Stopped EL datadir holding the downloaded `db`.
    source: PathBuf,
    chain: PathBuf,
    manifest: PathBuf,
    trust: ElTrust,
}

impl Fixture {
    /// A fresh, absent install target beside the source.
    fn target(&self, name: &str) -> PathBuf {
        self.root.path().canonicalize().unwrap().join(name)
    }
}

fn fixture() -> Fixture {
    let root = tempfile::tempdir().unwrap();
    let source = root.path().canonicalize().unwrap().join("source");
    drop(
        reth_db::init_db(
            source.join("db"),
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
        chain_id: 167001,
        finalized_height: 0,
        finalized_hash: trust.genesis_hash,
        headers: vec![header],
    };
    let chain = root.path().join("chain.json");
    let manifest = root.path().join("headers.json");
    std::fs::write(&chain, serde_json::to_vec(&genesis).unwrap()).unwrap();
    std::fs::write(&manifest, serde_json::to_vec(&headers).unwrap()).unwrap();
    Fixture { root, source, chain, manifest, trust }
}

fn command(f: &Fixture, datadir: &Path, trusted: bool) -> Command {
    let mut command = Command::new(env!("CARGO_BIN_EXE_etna-el-import"));
    command
        .arg("install")
        .arg("--source")
        .arg(&f.source)
        .arg("--datadir")
        .arg(datadir)
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
    let data = f.target("el");
    let before = std::fs::metadata(f.source.join("db/mdbx.dat")).unwrap().modified().unwrap();
    let output = command(&f, &data, false).output().unwrap();
    assert_eq!(output.status.code(), Some(2));
    assert_eq!(
        std::fs::metadata(f.source.join("db/mdbx.dat")).unwrap().modified().unwrap(),
        before
    );
    assert!(!data.exists());
}

#[test]
fn installs_a_real_empty_state_once_and_refuses_an_existing_datadir() {
    let f = fixture();
    let data = f.target("el");
    let scratch = tempfile::tempdir().unwrap();
    let output =
        command(&f, &data, true).arg("--scratch-parent").arg(scratch.path()).output().unwrap();
    assert!(std::fs::read_dir(scratch.path()).unwrap().next().is_none());
    assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
    let receipt: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(receipt["helper_version"], "0.1.0");
    assert_eq!(receipt["height"], 0);
    assert_eq!(receipt["block_hash"], f.trust.terminal_hash.to_string());
    assert_eq!(receipt["state_root"], f.trust.state_root.to_string());
    for removed in ["installation_id", "manifest_hash", "installed", "state_floor"] {
        assert!(receipt.get(removed).is_none(), "{removed} is no longer reported");
    }
    let before = std::fs::metadata(data.join("db/mdbx.dat")).unwrap().modified().unwrap();
    let again = command(&f, &data, true).output().unwrap();
    assert_eq!(again.status.code(), Some(1), "{}", String::from_utf8_lossy(&again.stderr));
    assert_eq!(std::fs::metadata(data.join("db/mdbx.dat")).unwrap().modified().unwrap(), before);
}

#[test]
fn review_installs_from_a_readonly_source_with_private_external_scratch() {
    use std::os::unix::fs::PermissionsExt;
    let f = fixture();
    let database = f.source.join("db");
    let scratch = tempfile::tempdir().unwrap();
    let entries = |path: &Path| {
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
    let before = std::fs::metadata(&f.source).unwrap().modified().unwrap();
    for path in [&database, &f.source] {
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o500)).unwrap();
    }
    for (name, explicit) in [("implicit", false), ("explicit", true)] {
        let mut cmd = command(&f, &f.target(name), true);
        if explicit {
            cmd.arg("--scratch-parent").arg(scratch.path());
        }
        let output = cmd.output().unwrap();
        assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
        assert_eq!(entries(&database), contents);
        assert_eq!(std::fs::metadata(&f.source).unwrap().modified().unwrap(), before);
        assert!(entries(scratch.path()).is_empty());
    }
    for path in [&database, &f.source] {
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o700)).unwrap();
    }
}

#[test]
fn missing_code_is_incomplete_and_present_wrong_code_or_state_is_bad_input() {
    use alloy_primitives::{Address, Bytes, U256, keccak256};
    use reth_db_api::{
        Database, tables,
        transaction::{DbTx, DbTxMut},
    };
    use reth_primitives_traits::{Account, Bytecode};
    let f = fixture();
    let hash = keccak256([0x60, 0x01]);
    let set = |account: Account, wrong_code| {
        let db = reth_db::open_db(f.source.join("db"), DatabaseArguments::test()).unwrap();
        let tx = db.tx_mut().unwrap();
        tx.put::<tables::PlainAccountState>(Address::repeat_byte(0x34), account).unwrap();
        if wrong_code {
            tx.put::<tables::Bytecodes>(hash, Bytecode::new_raw(Bytes::from_static(&[0x60, 0x02])))
                .unwrap();
        }
        tx.commit().unwrap();
    };
    set(Account { balance: U256::from(1), ..Default::default() }, false);
    let root = command(&f, &f.target("root"), true).output().unwrap();
    assert_eq!(root.status.code(), Some(1), "{}", String::from_utf8_lossy(&root.stderr));
    assert!(String::from_utf8_lossy(&root.stderr).contains("differs from authenticated root"));
    let coded = Account { bytecode_hash: Some(hash), ..Default::default() };
    set(coded, false);
    let missing = command(&f, &f.target("missing"), true).output().unwrap();
    assert_eq!(missing.status.code(), Some(3), "{}", String::from_utf8_lossy(&missing.stderr));
    assert!(String::from_utf8_lossy(&missing.stderr).contains("missing referenced bytecode"));
    set(coded, true);
    let wrong = command(&f, &f.target("wrong"), true).output().unwrap();
    assert_eq!(wrong.status.code(), Some(1), "{}", String::from_utf8_lossy(&wrong.stderr));
    assert!(String::from_utf8_lossy(&wrong.stderr).contains("bytecode content does not match"));
}

#[test]
fn malformed_database_version_is_a_candidate_but_missing_file_is_unavailable() {
    let f = fixture();
    let version = f.source.join("db/database.version");
    std::fs::write(&version, [0xff]).unwrap();
    let bad = command(&f, &f.target("bad"), true).output().unwrap();
    assert_eq!(bad.status.code(), Some(1), "{}", String::from_utf8_lossy(&bad.stderr));
    std::fs::remove_file(version).unwrap();
    let missing = command(&f, &f.target("missing"), true).output().unwrap();
    assert_eq!(missing.status.code(), Some(3), "{}", String::from_utf8_lossy(&missing.stderr));
}
