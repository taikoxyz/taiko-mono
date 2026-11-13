use super::{
    install::{install, normalized_comet_config, parse_comet_template},
    plan::*,
    prepare::prepare,
    status::*,
    *,
};
use abci::{
    AccountWitness, ChainParams, Engine, EngineError, ExecutionBlock, L1Error, L1Source,
    RawL1Header,
    engine::{PayloadVerdict, PoolSelection},
    recovery::RecoveryWitness,
};
use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::{Header, TxEnvelope};
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use serde::Deserialize;
use std::{
    collections::VecDeque,
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::{Path, PathBuf},
    sync::Mutex,
};

/// A short canonical parent keeps Unix sockets usable on both macOS and Linux.
fn short_temp_parent() -> PathBuf {
    Path::new("/tmp").canonicalize().unwrap()
}

#[derive(Deserialize)]
struct Fixture {
    params: Deployment,
    witness: Bytes,
    blocks: Vec<Block>,
}
#[derive(Deserialize)]
struct Block {
    number: u64,
    header: Bytes,
    accounts: Vec<Account>,
}
#[derive(Deserialize)]
struct Account {
    address: Address,
    proof: Bytes,
}
struct Source {
    fixture: Fixture,
    finalized: Mutex<VecDeque<u64>>,
}
impl Source {
    fn new() -> Self {
        Self {
            fixture: serde_json::from_str(include_str!("testdata/recovery.json")).unwrap(),
            finalized: Mutex::new(VecDeque::new()),
        }
    }
    fn witness(&self) -> RecoveryWitness {
        alloy_rlp::decode_exact(&self.fixture.witness).unwrap()
    }
    fn params(&self) -> ChainParams {
        self.fixture.params.params().unwrap()
    }
    fn block(&self, n: u64) -> Result<&Block, L1Error> {
        self.fixture
            .blocks
            .iter()
            .find(|b| b.number == n)
            .ok_or_else(|| L1Error::DataUnavailable("fixture has no block".into()))
    }
    fn account(&self, address: Address, n: u64) -> Result<AccountWitness, L1Error> {
        let a = self
            .block(n)?
            .accounts
            .iter()
            .find(|a| a.address == address)
            .ok_or_else(|| L1Error::DataUnavailable("fixture has no account".into()))?;
        Ok(alloy_rlp::decode_exact(&a.proof).unwrap())
    }
}
#[async_trait::async_trait]
impl L1Source for Source {
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        Ok(self.finalized.lock().unwrap().pop_front().unwrap_or(110))
    }
    async fn canonical_hash(&self, n: u64) -> Result<B256, L1Error> {
        Ok(self.header(n).await?.hash())
    }
    async fn header(&self, n: u64) -> Result<RawL1Header, L1Error> {
        Ok(alloy_rlp::decode_exact(&self.block(n)?.header).unwrap())
    }
    async fn account_witness(
        &self,
        a: Address,
        slots: &[B256],
        n: u64,
    ) -> Result<AccountWitness, L1Error> {
        let mut proof = self.account(a, n)?;
        proof.storage = slots
            .iter()
            .map(|slot| {
                proof
                    .storage
                    .iter()
                    .find(|p| p.slot == *slot)
                    .cloned()
                    .ok_or_else(|| L1Error::DataUnavailable("fixture has no proof".into()))
            })
            .collect::<Result<_, _>>()?;
        Ok(proof)
    }
    async fn storage_at(&self, a: Address, slot: B256, n: u64) -> Result<U256, L1Error> {
        self.account(a, n)?
            .storage
            .iter()
            .find(|p| p.slot == slot)
            .map(|p| p.value)
            .ok_or_else(|| L1Error::DataUnavailable("fixture has no slot".into()))
    }
    async fn forced_transaction(&self, _: Address, _: u64, _: u64) -> Result<Bytes, L1Error> {
        panic!("prepare must not request forced transaction bytes")
    }
}
struct ReadEngine {
    headers: Vec<Header>,
    available: bool,
    calls: Mutex<Vec<String>>,
}
impl ReadEngine {
    fn new(source: &Source) -> Self {
        let w = source.witness();
        Self {
            headers: vec![w.parent_headers[0].clone(), w.el_header],
            available: true,
            calls: Mutex::new(vec![]),
        }
    }
}
#[async_trait::async_trait]
impl Engine for ReadEngine {
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        panic!("no authenticated Engine calls during prepare")
    }
    async fn pool_transactions(&self, _: PoolSelection) -> Result<Vec<TxEnvelope>, EngineError> {
        panic!("no pool selection")
    }
    async fn build_block(
        &self,
        _: B256,
        _: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError> {
        panic!("no build during prepare")
    }
    async fn new_payload(&self, _: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        panic!("no payload during prepare")
    }
    async fn forkchoice(&self, _: B256, _: B256, _: B256) -> Result<PayloadVerdict, EngineError> {
        panic!("no forkchoice during prepare")
    }
    async fn finalized_header(&self) -> Result<Option<Header>, EngineError> {
        panic!("prepare reads only the exact origin state, never the EL's finalized tag")
    }
    async fn historical_state_available(&self, h: B256) -> Result<bool, EngineError> {
        assert!(self.headers.iter().any(|p| p.hash_slow() == h));
        self.calls.lock().unwrap().push(format!("state:{h}"));
        Ok(self.available)
    }
    async fn header_by_number(&self, n: u64) -> Result<Option<Header>, EngineError> {
        self.calls.lock().unwrap().push(format!("header:{n}"));
        Ok(self.headers.iter().find(|h| h.number == n).cloned())
    }
}

/// The fixture's generation-one plan: c = 6, R = 100, later finalized observation at 12.
async fn fixture_plan(source: &Source) -> RecoveryPlan {
    prepare(&source.params(), 1, source, &ReadEngine::new(source)).await.unwrap()
}

fn mode(path: &Path) -> u32 {
    std::fs::symlink_metadata(path).unwrap().permissions().mode() & 0o7777
}

/// A stock validator template: the signer address only selects the external-signer role.
const VALIDATOR_TEMPLATE: &str = "proxy_app = 'tcp://127.0.0.1:26658'\npriv_validator_laddr = 'tcp://127.0.0.1:26659'\ndb_dir = '/old-private/database'\nnode_key_file = '/old-private/key'\n[rpc]\nladdr = 'tcp://127.0.0.1:26657'\n[p2p]\nladdr = 'tcp://0.0.0.0:26656'\npersistent_peers = 'abcd@peer.example:26656'\naddr_book_file = '/old-private/addrbook'\n[mempool]\nwal_dir = '/old-private/mempool'\n[consensus]\nwal_file = '/old-private/wal'\n[statesync]\nenable = false\ntemp_dir = '/old-private/snapshots'\n";
/// A full-node template has no signer.
const FULL_NODE_TEMPLATE: &str = "proxy_app = 'tcp://127.0.0.1:26658'\npriv_validator_laddr = ''\n[p2p]\npersistent_peers = ''\n";

/// Operator inputs beside a fresh home and app directory, all under one short private parent.
struct Inputs {
    dir: tempfile::TempDir,
    template: PathBuf,
    node_key: PathBuf,
    home: PathBuf,
    app: PathBuf,
}
fn inputs(template: &str) -> Inputs {
    let dir = tempfile::Builder::new().prefix("ri-").tempdir_in(short_temp_parent()).unwrap();
    let template_path = dir.path().join("config.toml");
    std::fs::write(&template_path, template).unwrap();
    let node_key = dir.path().join("node_key.json");
    std::fs::write(
        &node_key,
        serde_json::to_vec(&test_harness::node_keys(1)[0].node_key_json()).unwrap(),
    )
    .unwrap();
    let home = dir.path().join("comet-g1");
    let app = dir.path().join("app-g1");
    Inputs { dir, template: template_path, node_key, home, app }
}
impl Inputs {
    fn install(&self, plan: &RecoveryPlan) -> Result<(), RecoveryCommandError> {
        install(plan, &self.template, &self.node_key, &self.home, &self.app)
    }
    /// The exact config.toml install writes: the shared template helper's output.
    fn expected_config(&self) -> Vec<u8> {
        normalized_comet_config(
            parse_comet_template(&std::fs::read(&self.template).unwrap()).unwrap(),
        )
        .unwrap()
    }
    /// Every entry beside the operator inputs, so a test sees anything install leaves behind.
    fn entries(&self) -> Vec<String> {
        let mut names: Vec<_> = std::fs::read_dir(self.dir.path())
            .unwrap()
            .map(|e| e.unwrap().file_name().to_string_lossy().into_owned())
            .collect();
        names.sort();
        names
    }
}

#[tokio::test]
async fn prepare_authenticates_fixed_origin_and_genesis() {
    // RECOV-8.2-4, RECOV-8.4-2/7/9, START-10-15
    let source = Source::new();
    let params = source.params();
    let engine = ReadEngine::new(&source);
    let plan = prepare(&params, 1, &source, &engine).await.unwrap();
    assert_eq!((plan.origin.generation, plan.origin.height, plan.origin.l1_number), (1, 6, 100));
    let doc: abci::GenesisDoc = serde_json::from_slice(&plan.genesis).unwrap();
    assert_eq!(doc.chain_id, abci::rules::chain_id_for(&params, 1).unwrap());
    assert_eq!(doc.chain_id.len(), 48);
    assert_eq!(doc.initial_height, "7"); // c + 1
    assert_eq!(doc.app_hash, alloy_primitives::hex::encode_upper(plan.origin.el_hash)); // ELHash(c)
    assert_eq!(
        doc.genesis_time,
        tendermint::Time::from_unix_timestamp(plan.origin.l1_timestamp as i64, 0)
            .unwrap()
            .to_rfc3339()
    );
    assert_eq!(doc.validators.len(), plan.origin.committee.members.len());
    // The only EL state read is the exact origin c; no build, payload or forkchoice.
    assert!(
        engine.calls.lock().unwrap().contains(&format!("state:{}", plan.origin.el_hash)),
        "prepare requires usable EL state at c"
    );
    let dir = tempfile::tempdir().unwrap();
    let out = dir.path().join("plan.json");
    plan.write_new(&out).unwrap();
    assert_eq!(mode(&out) & 0o777, 0o600);
    assert!(plan.write_new(&out).is_err(), "never clobbers an existing plan");
    assert_eq!(RecoveryPlan::load(&out).unwrap(), plan);
    // The plan never carries endpoints, a JWT path or credentials: these four fields only.
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(&out).unwrap()).unwrap();
    let mut keys: Vec<_> = value.as_object().unwrap().keys().cloned().collect();
    keys.sort();
    assert_eq!(keys, ["deployment", "genesis", "origin", "witness"]);
    // A torn or edited file never loads.
    let torn = dir.path().join("torn.json");
    let bytes = std::fs::read(&out).unwrap();
    std::fs::write(&torn, &bytes[..bytes.len() / 2]).unwrap();
    assert!(RecoveryPlan::load(&torn).is_err());
    let mut unknown = value.clone();
    unknown["l1_http"] = "http://alice:password@l1.test/".into();
    std::fs::write(&torn, serde_json::to_vec(&unknown).unwrap()).unwrap();
    assert!(RecoveryPlan::load(&torn).is_err(), "single strict format");
}

#[tokio::test]
async fn prepare_superseded_at_final_check_returns_no_plan() {
    // RECOV-8-14: a newer generation on own finalized L1, at a second read or the final recheck.
    for first_reads in [1, 5] {
        let source = Source::new();
        let engine = ReadEngine::new(&source);
        source.finalized.lock().unwrap().extend(std::iter::repeat_n(110, first_reads).chain([130]));
        assert!(matches!(
            prepare(&source.params(), 1, &source, &engine).await,
            Err(RecoveryCommandError::Superseded { requested: 1, current: 2 })
        ));
    }
}

#[tokio::test]
async fn prepare_later_checkpoint_keeps_fixed_genesis() {
    // RECOV-8.4-15, SYNC-9-9: a later finalized observation never moves the genesis or origin.
    let source = Source::new();
    let engine = ReadEngine::new(&source);
    let first = prepare(&source.params(), 1, &source, &engine).await.unwrap();
    source.finalized.lock().unwrap().extend(std::iter::repeat_n(120, 20));
    let later = prepare(&source.params(), 1, &source, &engine).await.unwrap();
    assert_eq!(first.genesis, later.genesis);
    assert_eq!(first.origin, later.origin);
    assert_ne!(first.witness, later.witness, "the latest observation is still recorded");
}

#[tokio::test]
async fn prepare_requires_el_state_at_origin() {
    // SYNC-9-16, RECOV-8.4-8
    let source = Source::new();
    let mut engine = ReadEngine::new(&source);
    engine.available = false;
    assert!(matches!(
        prepare(&source.params(), 1, &source, &engine).await,
        Err(RecoveryCommandError::Missing(_))
    ));
    for generation in [0, 1 << 48] {
        assert!(matches!(
            prepare(&source.params(), generation, &source, &ReadEngine::new(&source)).await,
            Err(RecoveryCommandError::Parse(_))
        ));
    }
}

#[tokio::test]
async fn install_writes_genesis_config_and_p2p_key_into_fresh_stores() {
    let source = Source::new();
    let plan = fixture_plan(&source).await;
    for (template, validator) in [(VALIDATOR_TEMPLATE, true), (FULL_NODE_TEMPLATE, false)] {
        let x = inputs(template);
        let node_key = std::fs::read(&x.node_key).unwrap();
        x.install(&plan).unwrap();
        let read = |name: &str| std::fs::read(x.home.join(name)).unwrap();
        assert_eq!(read("config/genesis.json"), plan.genesis);
        assert_eq!(read("config/node_key.json"), node_key);
        assert_eq!(read("config/config.toml"), x.expected_config());
        let config: toml::Table =
            toml::from_str(&String::from_utf8(read("config/config.toml")).unwrap()).unwrap();
        // The signer address only selects the role; the supervisor assigns the real socket.
        let signer = if validator { "unix://run/signer.sock" } else { "" };
        assert_eq!(config["priv_validator_laddr"].as_str(), Some(signer));
        assert_eq!(
            config["priv_validator_key_file"].as_str(),
            Some("config/priv_validator_key.json")
        );
        assert_eq!(
            config["priv_validator_state_file"].as_str(),
            Some("data/priv_validator_state.json")
        );
        assert!(!String::from_utf8(read("config/config.toml")).unwrap().contains("/old-private"));
        if validator {
            assert_eq!(config["p2p"]["persistent_peers"].as_str(), Some("abcd@peer.example:26656"));
        }
        // Fresh stores only: no registered key, HRS, WAL or history enters the new home.
        let names = |dir: &Path| {
            let mut names: Vec<_> = std::fs::read_dir(dir)
                .unwrap()
                .map(|e| e.unwrap().file_name().to_string_lossy().into_owned())
                .collect();
            names.sort();
            names
        };
        assert_eq!(names(&x.home), ["config", "data", "run"]);
        assert_eq!(names(&x.home.join("config")), ["config.toml", "genesis.json", "node_key.json"]);
        assert!(names(&x.home.join("data")).is_empty() && names(&x.home.join("run")).is_empty());
        assert!(x.app.is_dir() && x.app.read_dir().unwrap().next().is_none());
        // I3: run/ always exists, private, for the supervisor's per-start signer sockets.
        for dir in
            [&x.home, &x.home.join("config"), &x.home.join("data"), &x.home.join("run"), &x.app]
        {
            assert_eq!(mode(dir), 0o700, "{}", dir.display());
        }
        for file in ["config.toml", "genesis.json", "node_key.json"] {
            assert_eq!(mode(&x.home.join("config").join(file)), 0o600, "{file}");
        }
        // Nothing outside home/app is created or changed.
        assert_eq!(x.entries(), ["app-g1", "comet-g1", "config.toml", "node_key.json"]);
        assert_eq!(std::fs::read_to_string(&x.template).unwrap(), template);
        assert_eq!(std::fs::read(&x.node_key).unwrap(), node_key);
    }
}

#[tokio::test]
async fn install_is_idempotent_and_completes_after_interruption() {
    let source = Source::new();
    let plan = fixture_plan(&source).await;
    let x = inputs(VALIDATOR_TEMPLATE);
    // An interrupted install: config.toml already written, a torn temporary genesis, no marker.
    std::fs::create_dir_all(x.home.join("config")).unwrap();
    std::fs::write(x.home.join("config/config.toml"), x.expected_config()).unwrap();
    std::fs::write(x.home.join("config/.genesis.json.tmp"), b"torn").unwrap();
    x.install(&plan).unwrap();
    assert_eq!(std::fs::read(x.home.join("config/genesis.json")).unwrap(), plan.genesis);
    assert!(!x.home.join("config/.genesis.json.tmp").exists());
    let inode = |name: &str| std::fs::metadata(x.home.join(name)).unwrap().ino();
    let before: Vec<_> =
        ["config/config.toml", "config/node_key.json", "config/genesis.json"].map(inode).to_vec();
    // A second install is a no-op: nothing is rewritten.
    x.install(&plan).unwrap();
    let after: Vec<_> =
        ["config/config.toml", "config/node_key.json", "config/genesis.json"].map(inode).to_vec();
    assert_eq!(before, after);
    assert!(x.app.read_dir().unwrap().next().is_none());
}

#[tokio::test]
async fn install_refuses_foreign_home_used_app_store_tampered_plan_or_registered_key() {
    let source = Source::new();
    let plan = fixture_plan(&source).await;

    // A home holding another genesis is never overwritten, and nothing else is written there.
    let x = inputs(VALIDATOR_TEMPLATE);
    std::fs::create_dir_all(x.home.join("config")).unwrap();
    std::fs::write(x.home.join("config/genesis.json"), b"{\"chain_id\":\"other\"}").unwrap();
    assert!(matches!(x.install(&plan), Err(RecoveryCommandError::PlanMismatch)));
    assert_eq!(
        std::fs::read(x.home.join("config/genesis.json")).unwrap(),
        b"{\"chain_id\":\"other\"}"
    );
    assert_eq!(std::fs::read_dir(x.home.join("config")).unwrap().count(), 1);
    assert!(!x.app.exists());

    // A home a Comet already ran in is not fresh.
    let x = inputs(VALIDATOR_TEMPLATE);
    std::fs::create_dir_all(x.home.join("data")).unwrap();
    std::fs::write(x.home.join("data/priv_validator_state.json"), b"{}").unwrap();
    assert!(x.install(&plan).is_err());
    assert!(!x.home.join("config").exists() && !x.app.exists());

    // An app dir from an earlier generation keeps its latches and records: never reused
    // (RECOV-8-14/16; SYNC-9-5c: a record from an earlier generation does not count).
    for latch in ["fatal-evidence.txt", "validator-supervisor.halted", "val-state-6.bin"] {
        let x = inputs(VALIDATOR_TEMPLATE);
        std::fs::create_dir(&x.app).unwrap();
        std::fs::write(x.app.join(latch), b"old generation").unwrap();
        assert!(x.install(&plan).is_err(), "{latch}");
        assert!(!x.home.exists(), "{latch}: refused before the home is created");
        assert_eq!(std::fs::read(x.app.join(latch)).unwrap(), b"old generation");
    }

    // A tampered plan is refused before anything is created.
    let mut doc: serde_json::Value = serde_json::from_slice(&plan.genesis).unwrap();
    doc["initial_height"] = "8".into();
    let mut edited_genesis = plan.clone();
    edited_genesis.genesis = serde_json::to_vec_pretty(&doc).unwrap().into();
    let mut witness = plan.witness.to_vec();
    let last = witness.len() - 1;
    witness[last] ^= 1;
    let mut edited_witness = plan.clone();
    edited_witness.witness = witness.into();
    for tampered in [edited_genesis, edited_witness] {
        let x = inputs(VALIDATOR_TEMPLATE);
        assert!(matches!(x.install(&tampered), Err(RecoveryCommandError::PlanMismatch)));
        assert!(!x.home.exists() && !x.app.exists());
    }

    // RECOV-8.2-2: the registered consensus key (FilePV, secp256k1) is never a P2P identity.
    let x = inputs(VALIDATOR_TEMPLATE);
    let registered = test_harness::validator_keys(1)[0].priv_validator_key_json();
    let transport_shaped = serde_json::json!({"priv_key": registered["priv_key"].clone()});
    for key in [registered, transport_shaped] {
        std::fs::write(&x.node_key, serde_json::to_vec(&key).unwrap()).unwrap();
        assert!(
            matches!(x.install(&plan), Err(RecoveryCommandError::Parse(m)) if m.starts_with("Comet node key")),
            "{key}"
        );
        assert!(!x.home.exists() && !x.app.exists());
    }

    // Unsupported templates: state sync, Unix listeners, custom TLS, a custom home.
    let template = FULL_NODE_TEMPLATE.replace("[p2p]", "[statesync]\nenable = true\n[p2p]");
    let mut unsupported = vec![template];
    for listeners in [
        "grpc_laddr = 'unix:///old-comet/run/grpc.sock'",
        "laddr = 'tcp://127.0.0.1:26657,unix:///old-comet/run/rpc.sock'",
        "laddr = '  unix:///old-comet/run/rpc.sock  '",
        "laddr = 'unixpacket:///old-comet/run/rpc.sock'",
        "tls_key_file = 'key.pem'",
    ] {
        unsupported.push(format!("{FULL_NODE_TEMPLATE}[rpc]\n{listeners}\n"));
    }
    unsupported.push(format!("home = '/old-comet'\n{FULL_NODE_TEMPLATE}"));
    for template in unsupported {
        let x = inputs(&template);
        assert!(x.install(&plan).is_err(), "{template}");
        assert!(!x.home.exists() && !x.app.exists());
    }
    let x = inputs(&format!(
        "{FULL_NODE_TEMPLATE}[rpc]\nladdr = ' tcp://127.0.0.1:26657 , tcp://127.0.0.1:26659 '\n"
    ));
    x.install(&plan).unwrap();
}

#[tokio::test]
async fn install_refuses_socket_paths_beyond_the_unix_limit() {
    // Unix socket paths hold at most 103 bytes plus NUL on macOS (108 on Linux). The supervisor
    // binds home/run/signer-<16 hex>.sock and the app binds app/checkpoint-trust.sock.
    let source = Source::new();
    let plan = fixture_plan(&source).await;
    let x = inputs(VALIDATOR_TEMPLATE);
    let parent = x.dir.path().to_path_buf();
    let room = |suffix: usize| 103 - parent.as_os_str().len() - 1 - suffix;
    let long_home = parent.join("h".repeat(room("/run/signer-0000000000000000.sock".len()) + 1));
    let fitting_home = parent.join("h".repeat(room("/run/signer-0000000000000000.sock".len())));
    let long_app = parent.join("a".repeat(room("/checkpoint-trust.sock".len()) + 1));
    assert!(matches!(
        install(&plan, &x.template, &x.node_key, &long_home, &x.app),
        Err(RecoveryCommandError::Missing(_))
    ));
    assert!(!long_home.exists() && !x.app.exists());
    assert!(matches!(
        install(&plan, &x.template, &x.node_key, &x.home, &long_app),
        Err(RecoveryCommandError::Missing(_))
    ));
    assert!(!x.home.exists() && !long_app.exists());
    install(&plan, &x.template, &x.node_key, &fitting_home, &x.app).unwrap();
    // A full node never binds the signer socket, so only the app's socket bounds it.
    let full = inputs(FULL_NODE_TEMPLATE);
    let full_home = full.dir.path().join("h".repeat(80));
    install(&plan, &full.template, &full.node_key, &full_home, &full.app).unwrap();
}

#[tokio::test]
async fn status_is_offline_and_reports_install_state() {
    let source = Source::new();
    let plan = fixture_plan(&source).await;
    let x = inputs(VALIDATOR_TEMPLATE);
    let s = status(&plan, None).unwrap();
    assert_eq!(
        (s.generation, s.origin_height, s.recovery_l1_block, s.observed_checkpoint_height),
        (1, 6, 100, 12)
    );
    assert_eq!(s.genesis_hash, keccak256(&plan.genesis));
    let doc: abci::GenesisDoc = serde_json::from_slice(&plan.genesis).unwrap();
    assert_eq!(
        (s.chain_id.as_str(), s.genesis_time.as_str()),
        (&*doc.chain_id, &*doc.genesis_time)
    );
    assert_eq!(s.validators, plan.origin.committee.members.len());
    assert_eq!(s.installed, None);
    assert_eq!(status(&plan, Some(&x.home)).unwrap().installed, Some(false));
    assert!(!x.home.exists(), "status never writes");
    x.install(&plan).unwrap();
    assert_eq!(status(&plan, Some(&x.home)).unwrap().installed, Some(true));
    std::fs::write(x.home.join("config/genesis.json"), b"{}").unwrap();
    assert!(matches!(status(&plan, Some(&x.home)), Err(RecoveryCommandError::PlanMismatch)));
}

#[test]
fn recovery_errors_never_render_nested_provider_credentials() {
    for error in [
        abci::recovery::RecoveryError::Unavailable(
            "https://alice:password@private.example/secret-token".into(),
        ),
        abci::recovery::RecoveryError::Invalid("private-key secret-token".into()),
    ] {
        let error = crate::error::CliError::from(RecoveryCommandError::from(error));
        let report = error.report();
        for secret in ["alice", "password", "secret-token", "private-key"] {
            assert!(!report.contains(secret));
            assert!(!format!("{error:?}").contains(secret));
        }
    }
}

#[tokio::test]
async fn recovery_engine_reads_use_finalized_tag_and_exact_historical_hash() {
    use serde_json::{Value, json};
    use std::sync::Arc;
    let block: Value = serde_json::from_str::<Value>(include_str!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../crates/abci/src/l1/testdata/anvil_get_proof.json"
    )))
    .unwrap()["block"]
        .clone();
    let hash: B256 = serde_json::from_value(block["hash"].clone()).unwrap();
    let requests = Arc::new(Mutex::new(Vec::<Value>::new()));
    let seen = requests.clone();
    let app=axum::Router::new().route("/",axum::routing::post(move|axum::Json(body):axum::Json<Value>|{
        let block=block.clone();let seen=seen.clone();async move{
            seen.lock().unwrap().push(body.clone());
            axum::Json(json!({"jsonrpc":"2.0","id":body["id"],"result":if body["method"]=="eth_getBalance"{json!("0x0")}else{block}}))
        }
    }));
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", listener.local_addr().unwrap());
    let task = tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    let dir = tempfile::tempdir().unwrap();
    let jwt = dir.path().join("jwt");
    std::fs::write(&jwt, "11".repeat(32)).unwrap();
    let engine = abci::RpcEngine::new(
        url.parse().unwrap(),
        "http://127.0.0.1:9/".parse().unwrap(),
        &jwt,
        std::time::Duration::from_secs(20),
    )
    .unwrap();
    assert_eq!(engine.finalized_header().await.unwrap().unwrap().hash_slow(), hash);
    assert!(engine.historical_state_available(hash).await.unwrap());
    let requests = requests.lock().unwrap();
    assert_eq!(requests.len(), 3);
    assert_eq!(requests[0]["method"], "eth_getBlockByNumber");
    assert_eq!(requests[0]["params"], json!(["finalized", false]));
    assert_eq!(requests[1]["method"], "eth_getBlockByHash");
    assert_eq!(requests[1]["params"], json!([hash, false]));
    assert_eq!(requests[2]["method"], "eth_getBalance");
    assert_eq!(
        requests[2]["params"],
        json!([Address::ZERO,{"blockHash":hash,"requireCanonical":true}])
    );
    task.abort();
}

#[tokio::test(start_paused = true)]
async fn recovery_engine_read_deadlines_bound_a_stalled_public_endpoint() {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", listener.local_addr().unwrap());
    let task = tokio::spawn(async move {
        let (_socket, _) = listener.accept().await.unwrap();
        std::future::pending::<()>().await;
    });
    let dir = tempfile::tempdir().unwrap();
    let jwt = dir.path().join("jwt");
    std::fs::write(&jwt, "11".repeat(32)).unwrap();
    let engine = abci::RpcEngine::new(
        url.parse().unwrap(),
        "http://127.0.0.1:9/".parse().unwrap(),
        &jwt,
        std::time::Duration::from_secs(60),
    )
    .unwrap();
    let start = tokio::time::Instant::now();
    assert!(engine.finalized_header().await.is_err());
    assert!(start.elapsed() <= std::time::Duration::from_secs(10));
    let start = tokio::time::Instant::now();
    assert!(engine.historical_state_available(B256::repeat_byte(9)).await.is_err());
    assert!(start.elapsed() <= std::time::Duration::from_secs(10));
    task.abort();
}

const RUNBOOK: &str = include_str!("../../../../docs/governance-recovery.md");

fn runbook_blocks(language: &str) -> Vec<&str> {
    RUNBOOK
        .split(&format!("```{language}\n"))
        .skip(1)
        .map(|section| section.split("```").next().unwrap())
        .collect()
}

#[test]
fn recovery_runbook_commands_parse_exactly() {
    use crate::{
        cli::{Cli, Commands},
        commands::abci_recover::RecoveryAction,
    };
    use clap::Parser;
    let commands = runbook_blocks("sh");
    assert_eq!(commands.len(), 3, "exactly prepare, install and status");
    let actions: Vec<_> = commands
        .iter()
        .map(|command| match Cli::try_parse_from(command.split_whitespace()).unwrap().subcommand {
            Commands::AbciRecover(command) => command.action,
            other => panic!("not a recovery command: {other:?}"),
        })
        .collect();
    assert!(matches!(
        actions.as_slice(),
        [
            RecoveryAction::Prepare { .. },
            RecoveryAction::Install { .. },
            RecoveryAction::Status { home: Some(_), json: true, .. }
        ]
    ));
}

#[tokio::test]
async fn recovery_runbook_status_json_matches_actual_output() {
    let source = Source::new();
    let plan = fixture_plan(&source).await;
    let x = inputs(VALIDATOR_TEMPLATE);
    x.install(&plan).unwrap();
    let mut actual = serde_json::to_value(status(&plan, Some(&x.home)).unwrap()).unwrap();
    let example: serde_json::Value = serde_json::from_str(runbook_blocks("json")[0]).unwrap();
    // Illustrative values that depend on the real deployment and R.
    for field in ["chain_id", "genesis_hash", "genesis_time"] {
        actual[field] = example[field].clone();
    }
    assert_eq!(actual, example);
    let _: RecoveryStatus = serde_json::from_value(example).unwrap();
}
