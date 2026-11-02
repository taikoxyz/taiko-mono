use super::{plan::*, profile::*, status::*, store::*, *};
use abci::{
    AccountWitness, Engine, EngineError, ExecutionBlock, L1Error, L1Source, RawL1Header,
    engine::{PayloadVerdict, PoolSelection},
    recovery::{RecoveryWitness, verify_recovery_witness},
};
use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::{Header, TxEnvelope};
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use serde::Deserialize;
use std::{
    collections::{BTreeMap, VecDeque},
    path::Path,
    sync::Mutex,
};

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
        Ok(self.headers.first().cloned())
    }
    async fn historical_state_available(&self, h: B256) -> Result<bool, EngineError> {
        assert!(self.headers.iter().any(|p| p.hash_slow() == h));
        Ok(self.available)
    }
    async fn header_by_number(&self, n: u64) -> Result<Option<Header>, EngineError> {
        self.calls.lock().unwrap().push(format!("header:{n}"));
        Ok(self.headers.iter().find(|h| h.number == n).cloned())
    }
}
fn profile(dir: &Path) -> RecoveryProfile {
    let executable = Executable {
        program: "/bin/false".into(),
        argv: vec!["secret-argument".into()],
        env: BTreeMap::new(),
    };
    let profile = RecoveryProfile {
        schema: 1,
        role: NodeRole::FullNode,
        l1_chain_id: U256::from(1),
        l2_chain_id: 167001,
        chain_config: dir.join("chain.toml"),
        l1_http: "http://alice:password@l1.test/secret-token".into(),
        l2_http: "http://el.test/".into(),
        l2_auth: "http://el.test:8551/".into(),
        jwt_secret: dir.join("jwt.hex"),
        app_data_dir: dir.join("old-app"),
        comet_home: dir.join("old-comet"),
        app: executable.clone(),
        comet: executable,
        peers: vec![],
        signer: None,
        lander: None,
        installation_parent: None,
        inspector: None,
    };
    std::fs::write(&profile.chain_config,"l1_chain_id = '1'\ninbox = '0x1111111111111111111111111111111111111111'\nregistry = '0x2222222222222222222222222222222222222222'\n").unwrap();
    std::fs::create_dir_all(profile.comet_home.join("config")).unwrap();
    std::fs::create_dir_all(&profile.app_data_dir).unwrap();
    std::fs::write(profile.comet_home.join("config/config.toml"),"proxy_app = 'tcp://127.0.0.1:26658'\npriv_validator_laddr = ''\n[p2p]\npersistent_peers = ''\n").unwrap();
    profile
}
async fn plan(profile: &RecoveryProfile, source: &Source) -> RecoveryPlan {
    let w = source.witness();
    let genesis = abci::recovery::build_recovery_genesis(
        source,
        &ReadEngine::new(source),
        &source.fixture.params.params().unwrap(),
        1,
    )
    .await
    .unwrap()
    .to_json_pretty()
    .into_bytes();
    RecoveryPlan {
        schema: 1,
        profile_digest: profile.digest(),
        deployment: source.fixture.params.clone(),
        witness: source.fixture.witness.clone(),
        origin: verify_recovery_witness(&w, &source.fixture.params.params().unwrap()).unwrap(),
        genesis: genesis.clone().into(),
        artifacts: BTreeMap::from([
            ("comet/config/genesis.json".into(), keccak256(&genesis)),
            ("app-chain.toml".into(), keccak256(toml::to_string(&source.fixture.params).unwrap())),
        ]),
        prerequisites: vec![
            Prerequisite::ActivationBuildProbe,
            Prerequisite::CometTemplate,
            Prerequisite::CometNodeKey,
        ],
        client_version: env!("CARGO_PKG_VERSION").into(),
    }
}
#[test]
fn recovery_profile_rejects_unknown_role_combinations_and_secret_errors() {
    let dir = tempfile::tempdir().unwrap();
    let mut p = profile(dir.path());
    assert!(p.validate().is_ok());
    p.role = NodeRole::Validator;
    assert!(p.validate().is_err(), "validator requires original private signer bindings");
    let bad = dir.path().join("bad.toml");
    std::fs::write(&bad, "credential_password = 'DO-NOT-PRINT'\n").unwrap();
    let e = RecoveryProfile::load(&bad).err().unwrap();
    assert!(!format!("{e:?} {e}").contains("DO-NOT-PRINT"));
}
#[tokio::test]
async fn recovery_publication_is_immutable_idempotent_and_bounded() {
    let dir = tempfile::tempdir().unwrap();
    let p = profile(dir.path());
    let s = Source::new();
    let p1 = plan(&p, &s).await;
    let store = RecoveryStore::new(&dir.path().join("recovery"));
    let artifacts = BTreeMap::from([
        ("comet/config/genesis.json".into(), p1.genesis.to_vec()),
        ("app-chain.toml".into(), toml::to_string(&s.fixture.params).unwrap().into_bytes()),
    ]);
    store.publish_plan(&p1, &p, &artifacts).unwrap();
    store.publish_plan(&p1, &p, &artifacts).unwrap();
    assert_eq!(store.load_plan(p1.id()).unwrap(), p1);
    let mut changed = p1.clone();
    changed.profile_digest = B256::repeat_byte(9);
    assert_ne!(changed.id(), p1.id());
    changed = p1.clone();
    changed.witness = [changed.witness.as_ref(), &[1]].concat().into();
    assert_ne!(changed.id(), p1.id());
    let path = store.plan_dir(p1.id()).join("plan.json");
    for bad in [b"{}".to_vec(), b"{\"schema\":".to_vec(), vec![b' '; MAX_PLAN_BYTES as usize + 1]] {
        std::fs::write(&path, bad).unwrap();
        assert!(store.load_plan(p1.id()).is_err());
        assert!(store.publish_plan(&p1, &p, &artifacts).is_err());
    }
}
#[tokio::test]
async fn recovery_prepare_authenticates_and_preserves_original_state() {
    let dir = tempfile::tempdir().unwrap();
    let mut p = profile(dir.path());
    let source = Source::new();
    let chain = source.fixture.params.params().unwrap();
    p.l1_chain_id = chain.l1_chain_id;
    std::fs::write(
        &p.chain_config,
        format!(
            "l1_chain_id = '{}'\ninbox = '{}'\nregistry = '{}'\nunsettled_limit = {}\n",
            chain.l1_chain_id, chain.inbox, chain.registry, chain.unsettled_limit
        ),
    )
    .unwrap();
    let marker = p.app_data_dir.join("original-state");
    std::fs::write(&marker, b"untouched").unwrap();
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let prepared = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert_eq!(
        (prepared.origin.generation, prepared.origin.height, prepared.origin.l1_number),
        (1, 6, 100)
    );
    assert!(prepared.prerequisites.contains(&Prerequisite::ActivationBuildProbe));
    assert_eq!(std::fs::read(marker).unwrap(), b"untouched");
    let report =
        serde_json::to_string(&status(&RecoveryStore::new(&root), prepared.id()).unwrap()).unwrap();
    for secret in ["alice", "password", "secret-token", "secret-argument"] {
        assert!(!report.contains(secret));
    }
}

fn configured_profile(dir: &Path, source: &Source) -> RecoveryProfile {
    let mut p = profile(dir);
    p.l1_chain_id = source.fixture.params.l1_chain_id;
    std::fs::write(&p.chain_config, toml::to_string(&source.fixture.params).unwrap()).unwrap();
    p
}

#[test]
fn recovery_private_profiles_require_private_permissions_and_reject_aliases() {
    use std::os::unix::fs::{PermissionsExt, symlink};
    let dir = tempfile::tempdir().unwrap();
    let mut p = profile(dir.path());
    let file = dir.path().join("private.toml");
    std::fs::write(&file, toml::to_string(&p).unwrap()).unwrap();
    std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o644)).unwrap();
    assert!(
        RecoveryProfile::load(&file).is_err(),
        "profile credentials must not be world readable"
    );
    std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o600)).unwrap();
    assert!(RecoveryProfile::load(&file).is_ok());
    let alias = dir.path().join("alias");
    symlink(&p.comet_home, &alias).unwrap();
    p.app_data_dir = alias;
    assert!(p.validate().is_err(), "aliases cannot create parallel component ownership");
}

#[tokio::test]
async fn recovery_rejects_aliased_staged_directories_and_journal_mismatches() {
    use std::os::unix::fs::symlink;
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let root = dir.path().join("recovery");
    let engine = ReadEngine::new(&source);
    let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    let store = RecoveryStore::new(&root);
    let journal = RecoveryJournal::prepared(plan.id());
    store.save_journal(&journal).unwrap();
    assert_eq!(store.load_journal(plan.id()).unwrap(), Some(journal));
    std::fs::write(
        store.plan_dir(plan.id()).join("journal.json"),
        serde_json::to_vec(&RecoveryJournal {
            schema: 1,
            plan_id: B256::ZERO,
            phase: RecoveryPhase::Prepared,
            ..RecoveryJournal::prepared(plan.id())
        })
        .unwrap(),
    )
    .unwrap();
    assert!(status(&store, plan.id()).is_err());
    let config = store.plan_dir(plan.id()).join("comet/config");
    let saved = store.plan_dir(plan.id()).join("saved-config");
    std::fs::rename(&config, &saved).unwrap();
    symlink(&saved, &config).unwrap();
    assert!(store.load_plan(plan.id()).is_err(), "staged config directory must not be an alias");
}

#[tokio::test]
async fn recovery_new_generation_at_second_or_final_check_aborts_without_publication() {
    for first_reads in [1, 5] {
        let dir = tempfile::tempdir().unwrap();
        let source = Source::new();
        let p = configured_profile(dir.path(), &source);
        let engine = ReadEngine::new(&source);
        let root = dir.path().join("recovery");
        source.finalized.lock().unwrap().extend(std::iter::repeat_n(110, first_reads).chain([130]));
        assert!(matches!(
            prepare::prepare(&p, 1, &root, &source, &engine).await,
            Err(RecoveryCommandError::Superseded { requested: 1, current: 2 })
        ));
        assert!(!root.exists(), "superseded preparation must not publish or activate");
    }
}

#[tokio::test]
async fn recovery_later_checkpoint_keeps_fixed_genesis_and_changes_observation_id() {
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let first = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    source.finalized.lock().unwrap().extend(std::iter::repeat_n(120, 20));
    let later = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert_eq!(first.genesis, later.genesis);
    assert_eq!(first.origin, later.origin);
    assert_ne!(first.id(), later.id());
    assert_eq!(RecoveryStore::new(&root).load_plan(first.id()).unwrap(), first);
}

#[tokio::test]
async fn recovery_missing_state_reports_prerequisite_and_does_not_touch_signer_or_start_child() {
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let mut p = configured_profile(dir.path(), &source);
    let mut engine = ReadEngine::new(&source);
    engine.available = false;
    let key = dir.path().join("registered-key.json");
    let state = dir.path().join("original-hrs.json");
    let authority = dir.path().join("private-authority");
    std::fs::write(&key, b"registered-key").unwrap();
    std::fs::write(&state, b"never lower HRS").unwrap();
    std::fs::create_dir(&authority).unwrap();
    std::fs::write(authority.join("authority.json"), b"original-authority").unwrap();
    let child_marker = dir.path().join("child-started");
    p.app.program = "/usr/bin/touch".into();
    p.app.argv = vec![child_marker.to_string_lossy().into_owned()];
    p.signer = Some(SignerProfile {
        key: key.clone(),
        state: state.clone(),
        authority: authority.clone(),
        executable: p.comet.clone(),
        supervisor: p.comet.clone(),
    });
    assert!(p.validate().is_err(), "full node forbids registered signer");
    p.role = NodeRole::Validator;
    std::fs::write(p.comet_home.join("config/config.toml"),"proxy_app='tcp://127.0.0.1:26658'\npriv_validator_laddr='unix://run/old.sock'\n[p2p]\npersistent_peers=''\n").unwrap();
    let root = dir.path().join("recovery");
    let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    let config: toml::Table = toml::from_str(
        &std::fs::read_to_string(
            RecoveryStore::new(&root).plan_dir(plan.id()).join("comet/config/config.toml"),
        )
        .unwrap(),
    )
    .unwrap();
    assert_eq!(config["priv_validator_key_file"].as_str(), Some("config/priv_validator_key.json"));
    assert_eq!(
        config["priv_validator_state_file"].as_str(),
        Some("data/priv_validator_state.json")
    );
    assert_eq!(config["priv_validator_laddr"].as_str(), Some("unix://run/signer.sock"));
    let report = status(&RecoveryStore::new(&root), plan.id()).unwrap();
    assert_eq!(report.phase, RecoveryPhase::Prepared);
    assert!(report.prerequisites.contains(&Prerequisite::HistoricalState));
    assert!(report.prerequisites.contains(&Prerequisite::ActivationBuildProbe));
    assert!(!child_marker.exists());
    assert_eq!(std::fs::read(key).unwrap(), b"registered-key");
    assert_eq!(std::fs::read(state).unwrap(), b"never lower HRS");
    assert_eq!(std::fs::read(authority.join("authority.json")).unwrap(), b"original-authority");
    let public = serde_json::to_string(&plan).unwrap();
    for secret in [
        "registered-key.json",
        "original-hrs.json",
        "private-authority",
        "alice",
        "password",
        "secret-token",
    ] {
        assert!(!public.contains(secret));
    }
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
async fn recovery_staged_chain_must_match_the_authenticated_deployment() {
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let original = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    let store = RecoveryStore::new(&root);
    let mut artifacts: BTreeMap<String, Vec<u8>> = original
        .artifacts
        .keys()
        .map(|n| (n.clone(), std::fs::read(store.plan_dir(original.id()).join(n)).unwrap()))
        .collect();
    let mut tampered = original.clone();
    let bytes = b"l1_chain_id = '999'\n".to_vec();
    tampered.artifacts.insert("app-chain.toml".into(), keccak256(&bytes));
    artifacts.insert("app-chain.toml".into(), bytes);
    assert!(
        store.publish_plan(&tampered, &p, &artifacts).is_err(),
        "hashing an unrelated config cannot make a consistent bundle"
    );
}

#[tokio::test]
async fn recovery_status_reports_proven_checkpoint_without_claiming_runtime_trust() {
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    let report =
        serde_json::to_value(status(&RecoveryStore::new(&root), plan.id()).unwrap()).unwrap();
    assert_eq!(report["landed_height"], 12);
    assert_eq!(report["trust_target_height"], 12);
    assert!(report["committed_height"].is_null());
    assert_eq!(report["component_state"], "not-observed");
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

#[tokio::test]
async fn recovery_comet_staging_replaces_old_runtime_paths_and_rejects_state_sync() {
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let template = "proxy_app='tcp://127.0.0.1:26658'\npriv_validator_laddr=''\ndb_dir='/old-private/database'\nnode_key_file='/old-private/key'\n[p2p]\naddr_book_file='/old-private/addrbook'\n[mempool]\nwal_dir='/old-private/mempool'\n[consensus]\nwal_file='/old-private/wal'\n[statesync]\nenable=false\ntemp_dir='/old-private/snapshots'\n";
    let config_path = p.comet_home.join("config/config.toml");
    std::fs::write(&config_path, template).unwrap();
    let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    let store = RecoveryStore::new(&root);
    let staged = String::from_utf8(
        std::fs::read(store.plan_dir(plan.id()).join("comet/config/config.toml")).unwrap(),
    )
    .unwrap();
    assert!(!staged.contains("/old-private"), "new config must never write to old runtime paths");
    assert_eq!(std::fs::read_to_string(&config_path).unwrap(), template);
    std::fs::write(&config_path, template.replace("enable=false", "enable=true")).unwrap();
    let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert!(plan.prerequisites.contains(&Prerequisite::CometTemplate));
    assert!(!plan.artifacts.contains_key("comet/config/config.toml"));

    let mut accepted = Vec::new();
    for (case, listeners) in [
        ("grpc", "grpc_laddr='unix:///old-comet/run/grpc.sock'"),
        ("mixed RPC", "laddr='tcp://127.0.0.1:26657,unix:///old-comet/run/rpc.sock'"),
        ("trimmed RPC", "laddr='  unix:///old-comet/run/rpc.sock  '"),
        ("trimmed grpc", "grpc_laddr='  unix:///old-comet/run/grpc.sock  '"),
        (
            "trimmed mixed RPC",
            "laddr='  tcp://127.0.0.1:26657  ,  unix:///old-comet/run/rpc.sock  '",
        ),
        ("Unix-first RPC", "laddr='unix:///old-comet/run/rpc.sock,tcp://127.0.0.1:26657'"),
        ("packet RPC", "laddr='unixpacket:///old-comet/run/rpc.sock'"),
        ("mixed packet RPC", "laddr='tcp://127.0.0.1:26657,unixpacket:///old-comet/run/rpc.sock'"),
        ("trimmed packet grpc", "grpc_laddr='  unixpacket:///old-comet/run/grpc.sock  '"),
    ] {
        std::fs::write(&config_path, format!("{template}[rpc]\n{listeners}\n")).unwrap();
        let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
        if !plan.prerequisites.contains(&Prerequisite::CometTemplate) ||
            plan.artifacts.contains_key("comet/config/config.toml") ||
            store.plan_dir(plan.id()).join("comet/config/config.toml").exists()
        {
            accepted.push(case);
        }
    }
    assert!(accepted.is_empty(), "unsafe Unix listener templates published: {accepted:?}");

    std::fs::write(&config_path, format!("{template}[rpc]\nladdr=' tcp://127.0.0.1:26657 , tcp://127.0.0.1:26659 '\ngrpc_laddr=' tcp://127.0.0.1:26660 '\n")).unwrap();
    let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert!(!plan.prerequisites.contains(&Prerequisite::CometTemplate));
    assert!(plan.artifacts.contains_key("comet/config/config.toml"));
}

#[tokio::test]
async fn recovery_optional_lander_is_pending_without_touching_its_journal() {
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let mut p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let journal_dir = dir.path().join("original-lander");
    std::fs::create_dir(&journal_dir).unwrap();
    let journal = journal_dir.join("journal.json");
    std::fs::write(&journal, b"immutable signed transaction bytes").unwrap();
    p.lander = Some(LanderProfile { data_dir: journal_dir, executable: p.comet.clone() });
    let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert!(plan.prerequisites.contains(&Prerequisite::LanderReconciliation));
    assert_eq!(std::fs::read(journal).unwrap(), b"immutable signed transaction bytes");
}

#[test]
fn recovery_profile_unknown_fields_and_full_width_deployment_are_strict() {
    use std::os::unix::fs::PermissionsExt;
    let dir = tempfile::tempdir().unwrap();
    let p = profile(dir.path());
    let file = dir.path().join("profile.toml");
    let text = toml::to_string(&p).unwrap();
    std::fs::write(&file, format!("unexpected = 'SECRET-UNKNOWN'\n{text}")).unwrap();
    std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o600)).unwrap();
    assert!(RecoveryProfile::load(&file).is_err());
    assert!(!RecoveryProfile::load(&file).err().unwrap().to_string().contains("SECRET-UNKNOWN"));
    let source = Source::new();
    let mut deployment = source.fixture.params;
    deployment.l1_chain_id = U256::MAX;
    let encoded = serde_json::to_vec(&deployment).unwrap();
    let decoded: Deployment = serde_json::from_slice(&encoded).unwrap();
    assert_eq!(decoded.params().unwrap().l1_chain_id, U256::MAX);
    assert_eq!(Deployment::from(&decoded.params().unwrap()), deployment);
}

#[tokio::test]
async fn recovery_profile_changes_create_new_id_and_short_names_check_full_identity() {
    use std::os::unix::fs::PermissionsExt;
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let mut p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let first = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    p.peers.push("0123456789012345678901234567890123456789@127.0.0.1:26656".into());
    let second = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert_ne!(first.id(), second.id());
    assert_eq!(first.genesis, second.genesis);
    let store = RecoveryStore::new(&root);
    assert_eq!(
        std::fs::metadata(store.plan_dir(first.id()).join("profile.json"))
            .unwrap()
            .permissions()
            .mode() &
            0o777,
        0o600
    );
    let mut collision = first.id();
    collision[31] ^= 1;
    assert_eq!(store.plan_dir(first.id()), store.plan_dir(collision));
    assert!(store.load_plan(collision).is_err());
    assert_eq!(store.load_plan(first.id()).unwrap(), first);
    let journal = RecoveryJournal::prepared(first.id());
    store.save_journal(&journal).unwrap();
    let lock = std::fs::File::open(store.plan_dir(first.id()).join("journal.lock")).unwrap();
    lock.try_lock().unwrap();
    assert!(matches!(store.save_journal(&journal), Err(RecoveryCommandError::Busy)));
}

#[tokio::test]
async fn recovery_socket_paths_report_overlong_roots_and_keep_short_roots_usable() {
    let dir = tempfile::Builder::new().prefix("r7").tempdir_in("/private/tmp").unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("r");
    let short = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert!(!short.prerequisites.contains(&Prerequisite::RuntimeSocketPath));
    assert!(
        RecoveryStore::new(&root)
            .plan_dir(short.id())
            .join("app/checkpoint-trust.sock")
            .as_os_str()
            .as_encoded_bytes()
            .len() <=
            103
    );
    let long =
        prepare::prepare(&p, 1, &dir.path().join("x".repeat(120)), &source, &engine).await.unwrap();
    assert!(long.prerequisites.contains(&Prerequisite::RuntimeSocketPath));
}

#[test]
fn recovery_rejects_unresolvable_signer_aliases() {
    use std::os::unix::fs::symlink;
    let dir = tempfile::tempdir().unwrap();
    let mut p = profile(dir.path());
    p.role = NodeRole::Validator;
    let dangling = dir.path().join("signer-link");
    symlink(p.comet_home.join("missing-key"), &dangling).unwrap();
    p.signer = Some(SignerProfile {
        key: dangling,
        state: dir.path().join("hrs"),
        authority: dir.path().join("authority"),
        executable: p.comet.clone(),
        supervisor: p.comet.clone(),
    });
    assert!(p.validate().is_err(), "an unresolved alias may hide a signer key inside Comet mounts");
}

#[tokio::test]
async fn recovery_preserves_p2p_peer_identity_privately_and_requires_missing_keys() {
    use std::os::unix::fs::PermissionsExt;
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let mut p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let key = test_harness::node_keys(1).remove(0);
    let key_json = key.node_key_json();
    let key_bytes = serde_json::to_vec(&key_json).unwrap();
    let key_path = p.comet_home.join("config/node_key.json");
    std::fs::write(&key_path, &key_bytes).unwrap();
    std::fs::set_permissions(&key_path, std::fs::Permissions::from_mode(0o600)).unwrap();
    p.peers.push(format!("{}@127.0.0.1:26656", key.node_id()));
    let plan = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    let bundle = RecoveryStore::new(&root).plan_dir(plan.id());
    assert_eq!(std::fs::read(bundle.join("comet/config/node_key.json")).unwrap(), key_bytes);
    assert_eq!(
        std::fs::metadata(bundle.join("comet/config/node_key.json")).unwrap().permissions().mode() &
            0o777,
        0o600
    );
    let config: toml::Table =
        toml::from_str(&std::fs::read_to_string(bundle.join("comet/config/config.toml")).unwrap())
            .unwrap();
    assert_eq!(config["p2p"]["persistent_peers"].as_str().unwrap(), p.peers[0]);
    assert!(
        !serde_json::to_string(&plan)
            .unwrap()
            .contains(key_json["priv_key"]["value"].as_str().unwrap())
    );
    std::fs::remove_file(&key_path).unwrap();
    let missing = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert!(missing.prerequisites.contains(&Prerequisite::CometNodeKey));
    std::fs::write(
        &key_path,
        serde_json::to_vec(&test_harness::validator_keys(1)[0].priv_validator_key_json()).unwrap(),
    )
    .unwrap();
    std::fs::set_permissions(&key_path, std::fs::Permissions::from_mode(0o600)).unwrap();
    let invalid = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    assert!(invalid.prerequisites.contains(&Prerequisite::CometNodeKey));
}

#[tokio::test]
async fn recovery_publication_enforces_the_same_profile_bound_as_loading() {
    let dir = tempfile::tempdir().unwrap();
    let source = Source::new();
    let mut p = configured_profile(dir.path(), &source);
    let engine = ReadEngine::new(&source);
    let root = dir.path().join("recovery");
    let original = prepare::prepare(&p, 1, &root, &source, &engine).await.unwrap();
    let store = RecoveryStore::new(&root);
    let artifacts = original
        .artifacts
        .keys()
        .map(|n| (n.clone(), std::fs::read(store.plan_dir(original.id()).join(n)).unwrap()))
        .collect();
    p.app.env.insert("PRIVATE_ENV".into(), "x".repeat(1024 * 1024));
    let mut oversized = original.clone();
    oversized.profile_digest = p.digest();
    assert!(
        store.publish_plan(&oversized, &p, &artifacts).is_err(),
        "publication must not create a bundle the bounded reader cannot load"
    );
    assert!(!store.plan_dir(oversized.id()).exists());
}

#[path = "activation_tests.rs"]
mod activation_tests;
