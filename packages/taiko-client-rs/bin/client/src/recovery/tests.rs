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
    sync::{Arc, Mutex},
    time::Duration,
};

/// The fixture's `L1_0`, where Inbox initialization stored the origin fallback key list.
const L1_0: u64 = 64;
/// The fixture's R, 21 log queries of 10,000 blocks above block 0.
const R: u64 = 200_000;
/// The fixture's finalized L1 block.
const FINALIZED: u64 = R + 10;

/// A short canonical parent keeps Unix sockets usable on both macOS and Linux.
fn short_temp_parent() -> PathBuf {
    Path::new("/tmp").canonicalize().unwrap()
}

#[derive(Deserialize)]
struct Fixture {
    params: Deployment,
    witness: Bytes,
    blocks: Vec<Block>,
    /// The list whose hash the origin record holds, which the Inbox answers
    /// `getFallbackKeys()` with.
    fallback_keys: abci::fallback::FallbackKeys,
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
    /// Whether `getFallbackKeys()` fails, as on an L1 without archive state at R: the origin
    /// list then comes only from its `FallbackKeysUpdated` log at [`L1_0`].
    pruned: bool,
    /// How long each log query takes.
    log_delay: Duration,
    /// The block ranges of the log queries made, in order.
    log_ranges: Mutex<Vec<(u64, u64)>>,
}
impl Source {
    fn new() -> Arc<Self> {
        Arc::new(Self::serving())
    }
    /// The fixture L1, whose `getFallbackKeys()` returns the origin list.
    fn serving() -> Self {
        Self {
            fixture: serde_json::from_str(include_str!("testdata/recovery.json")).unwrap(),
            finalized: Mutex::new(VecDeque::new()),
            pruned: false,
            log_delay: Duration::ZERO,
            log_ranges: Mutex::new(vec![]),
        }
    }
    fn witness(&self) -> RecoveryWitness {
        alloy_rlp::decode_exact(&self.fixture.witness).unwrap()
    }
    fn params(&self) -> ChainParams {
        self.fixture.params.params().unwrap()
    }
    fn header_hash(&self, block: &Block) -> B256 {
        alloy_rlp::decode_exact::<RawL1Header>(&block.header).unwrap().hash()
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
        Ok(self.finalized.lock().unwrap().pop_front().unwrap_or(FINALIZED))
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
    async fn call_at(&self, address: Address, input: Bytes, hash: B256) -> Result<Bytes, L1Error> {
        use alloy::sol_types::SolCall;
        assert!(self.fixture.blocks.iter().any(|b| self.header_hash(b) == hash));
        if address != self.params().inbox ||
            input[..] != abci::fallback::getFallbackKeysCall::SELECTOR[..]
        {
            return Err(L1Error::Rpc("fixture answers getFallbackKeys() only".into()));
        }
        if self.pruned {
            return Err(L1Error::Rpc("missing trie node".into()));
        }
        Ok(self.fixture.fallback_keys.abi_encode().into())
    }
    async fn inbox_logs(
        &self,
        inbox: Address,
        topic0: B256,
        topic1: B256,
        from: u64,
        to: u64,
    ) -> Result<Vec<Bytes>, L1Error> {
        tokio::time::sleep(self.log_delay).await;
        self.log_ranges.lock().unwrap().push((from, to));
        let keys = &self.fixture.fallback_keys;
        let stored = inbox == self.params().inbox &&
            topic0 == abci::fallback::FALLBACK_KEYS_UPDATED &&
            topic1 == keys.hash() &&
            (from..=to).contains(&L1_0);
        Ok(if stored { vec![keys.abi_encode().into()] } else { vec![] })
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
    async fn storage_at(&self, _: Address, _: &[B256], _: B256) -> Result<Vec<U256>, EngineError> {
        panic!("prepare reads no contract storage")
    }
    async fn header_by_number(&self, n: u64) -> Result<Option<Header>, EngineError> {
        self.calls.lock().unwrap().push(format!("header:{n}"));
        Ok(self.headers.iter().find(|h| h.number == n).cloned())
    }
}

/// The fixture's generation-one plan: c = 6, R = [`R`], later finalized observation at 12.
async fn fixture_plan(source: &Arc<Source>) -> RecoveryPlan {
    prepare(&source.params(), 1, source.clone(), &ReadEngine::new(source)).await.unwrap()
}

fn mode(path: &Path) -> u32 {
    std::fs::symlink_metadata(path).unwrap().permissions().mode() & 0o7777
}

/// A stock validator template: the signer address only selects the external-signer role.
const VALIDATOR_TEMPLATE: &str = "proxy_app = 'tcp://127.0.0.1:26658'\npriv_validator_laddr = 'tcp://127.0.0.1:26659'\ndb_dir = '/old-private/database'\nnode_key_file = '/old-private/key'\n[rpc]\nladdr = 'tcp://127.0.0.1:26657'\n[p2p]\nladdr = 'tcp://0.0.0.0:26656'\npersistent_peers = 'abcd@peer.example:26656'\nunconditional_peer_ids = 'abcd'\npex = false\nmax_num_inbound_peers = 0\naddr_book_file = '/old-private/addrbook'\n[mempool]\nwal_dir = '/old-private/mempool'\n[consensus]\nwal_file = '/old-private/wal'\n[statesync]\nenable = false\ntemp_dir = '/old-private/snapshots'\n";
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
    let plan = prepare(&params, 1, source.clone(), &engine).await.unwrap();
    assert_eq!((plan.origin.generation, plan.origin.height, plan.origin.l1_number), (1, 6, R));
    let doc: abci::GenesisDoc = serde_json::from_slice(&plan.genesis).unwrap();
    assert_eq!(doc.chain_id, abci::rules::chain_id_for(&params, 1).unwrap());
    assert_eq!(doc.chain_id.len(), 48);
    assert_eq!(doc.initial_height, "7"); // c + 1
    // appHash(c): ELHash(c) with the origin fallback keys' genesis validator state at c, each
    // key at power 1.
    let keys = &source.fixture.fallback_keys;
    assert_eq!(keys.hash(), plan.origin.fallback_keys_hash);
    let val_state =
        abci::valstate::ValState::genesis(plan.origin.height, &keys.validator_set()).unwrap();
    assert_eq!(
        doc.app_hash,
        alloy_primitives::hex::encode_upper(abci::valstate::app_hash(
            plan.origin.el_hash,
            val_state.hash()
        ))
    );
    assert_eq!(
        doc.genesis_time,
        tendermint::Time::from_unix_timestamp(plan.origin.l1_timestamp as i64, 0)
            .unwrap()
            .to_rfc3339()
    );
    let validators: Vec<_> =
        doc.validators.iter().map(|v| (v.pub_key.0, v.power.as_str())).collect();
    assert_eq!(validators, keys.keys().iter().map(|key| (*key, "1")).collect::<Vec<_>>());
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
    // The plan never carries endpoints, a JWT path or credentials: these five fields only.
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(&out).unwrap()).unwrap();
    let mut keys: Vec<_> = value.as_object().unwrap().keys().cloned().collect();
    keys.sort();
    assert_eq!(keys, ["deployment", "genesis", "origin", "schema_version", "witness"]);
    assert_eq!(value["schema_version"], 2);
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
        source
            .finalized
            .lock()
            .unwrap()
            .extend(std::iter::repeat_n(FINALIZED, first_reads).chain([R + 30]));
        assert!(matches!(
            prepare(&source.params(), 1, source.clone(), &engine).await,
            Err(RecoveryCommandError::Superseded { requested: 1, current: 2 })
        ));
    }
}

#[tokio::test]
async fn prepare_later_checkpoint_keeps_fixed_genesis() {
    // RECOV-8.4-15, SYNC-9-9: a later finalized observation never moves the genesis or origin.
    let source = Source::new();
    let engine = ReadEngine::new(&source);
    let first = prepare(&source.params(), 1, source.clone(), &engine).await.unwrap();
    source.finalized.lock().unwrap().extend(std::iter::repeat_n(R + 20, 20));
    let later = prepare(&source.params(), 1, source.clone(), &engine).await.unwrap();
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
        prepare(&source.params(), 1, source.clone(), &engine).await,
        Err(RecoveryCommandError::Missing(_))
    ));
    for generation in [0, 1 << 48] {
        assert!(matches!(
            prepare(&source.params(), generation, source.clone(), &ReadEngine::new(&source)).await,
            Err(RecoveryCommandError::Parse(_))
        ));
    }
}

#[tokio::test]
async fn prepare_reports_an_el_without_the_settled_block_at_c_as_missing() {
    // RECOV-8.1-7/8.1-8: another block at c (vector 7.l) or none (7.i) is not invalid evidence.
    let source = Source::new();
    let w = source.witness();
    let settled = w.el_header.hash_slow();
    let own = Header { timestamp: w.el_header.timestamp + 1, ..w.el_header.clone() };
    for headers in [vec![w.parent_headers[0].clone(), own], vec![w.parent_headers[0].clone()]] {
        let mut engine = ReadEngine::new(&source);
        engine.headers = headers;
        let error = prepare(&source.params(), 1, source.clone(), &engine).await.unwrap_err();
        let message = error.to_string();
        assert!(
            matches!(
                error,
                RecoveryCommandError::OriginNotHeld { height: 6, el_hash } if el_hash == settled
            ),
            "{error:?}"
        );
        assert!(
            message.contains(&settled.to_string()) &&
                message.contains("docs/governance-recovery.md"),
            "{message}"
        );
        // The runbook quotes the message it points to, with an illustrative hash.
        let quoted = message.replace(&settled.to_string(), "0x…");
        assert!(RUNBOOK.contains(&format!("```text\n{quoted}\n```")), "{quoted}");
    }
    assert!(RUNBOOK.contains("\n## Take the settled EL state at c\n"));
}

/// An L1 without archive state at R: `getFallbackKeys()` at R fails and the origin list was
/// stored at `L1_0`, so it comes only from its log, 20 queries of 10,000 blocks below R. Each
/// query takes 7 s, within the deadline of one read, and the 140 s scan completes: no deadline
/// bounds the acquisition as a whole.
#[tokio::test(start_paused = true)]
async fn prepare_obtains_an_old_origin_list_from_logs_far_below_r() {
    let source =
        Arc::new(Source { pruned: true, log_delay: Duration::from_secs(7), ..Source::serving() });
    let engine = ReadEngine::new(&source);
    let start = tokio::time::Instant::now();
    let plan = prepare(&source.params(), 1, source.clone(), &engine).await.unwrap();
    assert!(start.elapsed() >= Duration::from_secs(140), "{:?}", start.elapsed());
    let ranges = source.log_ranges.lock().unwrap().clone();
    assert_eq!(ranges.len(), 20, "{ranges:?}");
    assert_eq!(ranges[0], (R - 9_999, R));
    assert_eq!(ranges.last(), Some(&(1, 10_000)));
    let keys = &source.fixture.fallback_keys;
    assert_eq!(plan.origin.fallback_keys_hash, keys.hash());
    let doc: abci::GenesisDoc = serde_json::from_slice(&plan.genesis).unwrap();
    let validators: Vec<_> =
        doc.validators.iter().map(|v| (v.pub_key.0, v.power.as_str())).collect();
    assert_eq!(validators, keys.keys().iter().map(|key| (*key, "1")).collect::<Vec<_>>());
}

/// A log query that outlasts the deadline of one L1 read fails the scan: the history is missing,
/// and no plan is written.
#[tokio::test(start_paused = true)]
async fn prepare_reports_a_timed_out_list_read_as_missing() {
    let source =
        Arc::new(Source { pruned: true, log_delay: Duration::from_secs(31), ..Source::serving() });
    let engine = ReadEngine::new(&source);
    assert!(matches!(
        prepare(&source.params(), 1, source.clone(), &engine).await,
        Err(RecoveryCommandError::Missing(_))
    ));
    assert!(source.log_ranges.lock().unwrap().is_empty(), "the first query timed out");
}

/// The plan format is schema 2: a plan with another `schema_version`, or without one as the
/// earlier format was written, is refused, never migrated.
#[tokio::test]
async fn plan_without_schema_2_is_refused() {
    let source = Source::new();
    let plan = fixture_plan(&source).await;
    assert_eq!(plan.schema_version, 2);
    plan.validate().unwrap();
    for version in [0, 1, 3] {
        assert!(matches!(
            RecoveryPlan { schema_version: version, ..plan.clone() }.validate(),
            Err(RecoveryCommandError::Parse("plan schema"))
        ));
    }
    let dir = tempfile::tempdir().unwrap();
    let value = serde_json::to_value(&plan).unwrap();
    let mut unversioned = value.clone();
    unversioned.as_object_mut().unwrap().remove("schema_version");
    let mut version_1 = value.clone();
    version_1["schema_version"] = 1.into();
    for (name, value) in
        [("unversioned", unversioned), ("version-1", version_1), ("current", value)]
    {
        let path = dir.path().join(format!("{name}.json"));
        std::fs::write(&path, serde_json::to_vec_pretty(&value).unwrap()).unwrap();
        assert_eq!(RecoveryPlan::load(&path).is_ok(), name == "current", "{name}");
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
        // data/ holds only a fresh store instance ID (RECOV-8.2-2).
        assert_eq!(names(&x.home.join("data")), [crate::store_instance::FILE]);
        assert!(crate::store_instance::valid(&read("data/etna-store-instance")));
        assert_eq!(mode(&x.home.join("data/etna-store-instance")), 0o600);
        assert!(names(&x.home.join("run")).is_empty());
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
    let files = [
        "config/config.toml",
        "config/node_key.json",
        "config/genesis.json",
        "data/etna-store-instance",
    ];
    let before: Vec<_> = files.map(inode).to_vec();
    let id = std::fs::read(x.home.join("data/etna-store-instance")).unwrap();
    // A second install is a no-op: nothing is rewritten, the store instance ID included.
    x.install(&plan).unwrap();
    let after: Vec<_> = files.map(inode).to_vec();
    assert_eq!(before, after);
    assert_eq!(std::fs::read(x.home.join("data/etna-store-instance")).unwrap(), id);
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
    let snapshots = "val-state-00000000000000000000.log";
    for latch in ["fatal-evidence.txt", "validator-supervisor.halted", snapshots] {
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
    let s = status(&plan, None, None).unwrap();
    assert_eq!(
        (s.generation, s.origin_height, s.recovery_l1_block, s.observed_checkpoint_height),
        (1, 6, R, 12)
    );
    assert_eq!(s.genesis_hash, keccak256(&plan.genesis));
    let doc: abci::GenesisDoc = serde_json::from_slice(&plan.genesis).unwrap();
    assert_eq!(
        (s.chain_id.as_str(), s.genesis_time.as_str()),
        (&*doc.chain_id, &*doc.genesis_time)
    );
    assert_eq!(s.installed, None);
    assert_eq!(status(&plan, Some(&x.home), None).unwrap().installed, Some(false));
    assert!(!x.home.exists(), "status never writes");
    x.install(&plan).unwrap();
    assert_eq!(status(&plan, Some(&x.home), None).unwrap().installed, Some(true));
    std::fs::write(x.home.join("config/genesis.json"), b"{}").unwrap();
    assert!(matches!(status(&plan, Some(&x.home), None), Err(RecoveryCommandError::PlanMismatch)));
}

/// The report names who signs the new generation's first two blocks: the origin record's
/// `fallbackKeysHash` and the keys of the list with that hash, in order. It shows the
/// `minTotalStake` that the proof at R holds, for display only, and, given this node's
/// public key, whether that key is one of the origin keys.
#[tokio::test]
async fn status_lists_origin_keys_and_marks_the_local_key() {
    let source = Source::new();
    let plan = fixture_plan(&source).await;
    let keys = source.fixture.fallback_keys.keys().to_vec();
    let s = status(&plan, None, None).unwrap();
    assert_eq!(s.fallback_keys_hash, plan.origin.fallback_keys_hash);
    assert_eq!(s.fallback_keys_hash, source.fixture.fallback_keys.hash());
    assert_eq!(s.origin_keys, keys);
    let witness: RecoveryWitness = alloy_rlp::decode_exact(&plan.witness).unwrap();
    let slot = abci::l1::layout::inbox::slot(abci::l1::layout::inbox::MIN_TOTAL_STAKE);
    let at_r = witness.recovery_inbox.storage.iter().find(|word| word.slot == slot).unwrap();
    assert_eq!(s.min_total_stake, at_r.value);
    // The fixture's Inbox holds 2^256 - 1 there, which the text report names as such.
    assert_eq!(at_r.value, U256::MAX);
    assert!(s.to_string().contains("minTotalStake at R: 2^256-1"), "{s}");
    assert_eq!(s.local_key_is_origin_key, None);
    for key in &keys {
        assert_eq!(status(&plan, None, Some(*key)).unwrap().local_key_is_origin_key, Some(true));
    }
    // The secp256k1 generator, whose private key is 1, is not in the fixture's list.
    let other = abci::key::ConsensusKey::from_slice(&alloy_primitives::hex!(
        "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    ))
    .unwrap();
    assert!(!keys.contains(&other));
    assert_eq!(status(&plan, None, Some(other)).unwrap().local_key_is_origin_key, Some(false));
    // The text summary lists every origin key on its own line and says what the local key is.
    let text = status(&plan, None, Some(keys[1])).unwrap().to_string();
    assert!(text.contains(&s.fallback_keys_hash.to_string()), "{text}");
    for key in &keys {
        assert!(text.lines().any(|line| line.trim() == key.to_string()), "{text}");
    }
    assert!(text.contains("local key is an origin key"), "{text}");
    let text = status(&plan, None, Some(other)).unwrap().to_string();
    assert!(text.contains("local key is not an origin key"), "{text}");
    assert!(s.to_string().contains("local key unchecked"));
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
            RecoveryAction::Status { home: Some(_), public_key: Some(_), json: true, .. }
        ]
    ));
    // `--public-key` takes only a valid compressed secp256k1 key.
    let words: Vec<_> = commands[2].split_whitespace().collect();
    let key = words[words.iter().position(|word| *word == "--public-key").unwrap() + 1];
    for bad in
        [&key[..key.len() - 2], &format!("0x{}", "00".repeat(33)), &format!("0x04{}", &key[4..])]
    {
        let command = commands[2].replace(key, bad);
        assert!(Cli::try_parse_from(command.split_whitespace()).is_err(), "{bad}");
    }
}

#[tokio::test]
async fn recovery_runbook_status_json_matches_actual_output() {
    let source = Source::new();
    let plan = fixture_plan(&source).await;
    let x = inputs(VALIDATOR_TEMPLATE);
    x.install(&plan).unwrap();
    // The runbook's command passes the fixture's first origin key.
    let local = source.fixture.fallback_keys.keys()[0];
    assert!(runbook_blocks("sh")[2].contains(&format!("--public-key {local} ")));
    let mut actual =
        serde_json::to_value(status(&plan, Some(&x.home), Some(local)).unwrap()).unwrap();
    let example: serde_json::Value = serde_json::from_str(runbook_blocks("json")[0]).unwrap();
    // Illustrative values that depend on the real deployment and R.
    for field in ["chain_id", "genesis_hash", "genesis_time", "recovery_l1_block"] {
        actual[field] = example[field].clone();
    }
    assert_eq!(actual, example);
    let _: RecoveryStatus = serde_json::from_value(example).unwrap();
}
