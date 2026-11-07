//! Offline installation is a source-verification operation, never a signing authority.
use abci::ownership::{ActivationLease, acquire_activation};
use alloy_primitives::{B256, U256, keccak256};
use lander::checkpoint_import::{ImportError, VerifiedImport};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    fs,
    path::{Path, PathBuf},
};
use url::Url;

/// Component publication and runtime selection guards.
pub(crate) mod boundary;
/// Collection of publishable app packages from read-only archive RPC.
pub mod export;
/// Private canonical filesystem primitives.
mod files;
/// Private lifetime guard for the normal EL smoke process.
pub(crate) mod guardian;
/// Independent verifier processes and normal EL startup probe.
mod helpers;
/// Bounded portable input and stock framing.
mod package;
/// Supported live app and private owned EL runtime.
pub(crate) mod runtime;

/// Candidate/unavailable failures never create a terminal latch.
type R<T> = Result<T, ImportError>;
/// Reject untrusted or inconsistent local inputs.
fn bad(m: impl ToString) -> ImportError {
    ImportError::Candidate(m.to_string())
}
/// Storage diagnostics disclose only portable I/O kinds.
fn io(e: std::io::Error) -> ImportError {
    ImportError::Unavailable(format!("storage: {:?}", e.kind()))
}
/// Private schema-one deployment and archive endpoints.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Profile {
    /// Only schema one has defined source and process semantics.
    schema: u32,
    /// Explicit deployment L1 identity, including high bits.
    l1_chain_id: U256,
    /// Explicit local EL chain ID.
    l2_chain_id: u64,
    /// Own L1 provider, never a package hint.
    l1_http: Url,
    /// Optional consensus configuration override.
    chain_config: Option<PathBuf>,
    /// Export-only archival sources.
    archive: Option<Archive>,
    /// Local offline EL inputs and pinned helpers.
    install: Option<Installation>,
}
/// Archival endpoints and fixed original genesis inputs.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Archive {
    /// Pinned stock helper for independent archival verification.
    comet_helper: PathBuf,
    /// Stock read-only Comet RPC.
    comet_http: Url,
    /// Canonical EL archive, header reads only.
    l2_http: Url,
    /// Original stock genesis.json for this generation.
    comet_genesis: PathBuf,
    /// Required for a recovery generation; raw stored bootstrap JSON.
    recovery_bootstrap: Option<PathBuf>,
}
/// Programs and immutable offline inputs; arbitrary child argv are intentionally unavailable.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Installation {
    /// Optional explicit OS identity for a separately privileged stock Comet process.
    comet_uid: Option<u32>,
    /// Primary group of that stock process; both fields must be provided together.
    comet_gid: Option<u32>,
    /// Effective stopped EL directory containing db/mdbx.dat.
    el_source: PathBuf,
    /// Original deployment EL chain specification used by the runtime.
    el_chain: PathBuf,
    /// Native guarded signer for validator templates, absent for a full-node runtime.
    signer_binary: Option<PathBuf>,
    /// Approved native stock Comet server executable.
    comet_binary: PathBuf,
    /// Pinned stock verifier/installer executable.
    comet_helper: PathBuf,
    /// Pinned native execution state/index installer.
    el_helper: PathBuf,
    /// Reviewed normal execution node executable for the private post-install startup.
    el_binary: PathBuf,
    /// Whether the original execution chain activates Etna by devnet timestamp override.
    devnet_etna_timestamp: Option<u64>,
    /// Operator-approved, non-secret stock runtime settings (no key material is imported).
    comet_config: PathBuf,
}
impl Profile {
    /// Read protected configuration without exposing credentials in diagnostics.
    fn load(p: &Path) -> R<(Self, B256)> {
        crate::recovery::store::check_private_file(p)
            .map_err(|_| bad("private profile required"))?;
        let b = files::read(p, 1 << 20)?;
        let profile: Self =
            serde_json::from_slice(&b).map_err(|_| bad("invalid import profile"))?;
        if profile.schema != 1 {
            return Err(bad("unsupported profile schema"))
        }
        Ok((profile, keccak256(b)))
    }
    /// Recheck actual own endpoint identity before constructing the proof-reading source.
    async fn own(&self) -> R<(abci::ChainParams, abci::RpcL1Source)> {
        if let Some(p) = &self.chain_config {
            files::file(p)?;
        }
        let (mut params, expected) =
            crate::commands::load_chain_params(self.l2_chain_id, self.chain_config.as_deref())
                .map_err(|_| bad("deployment configuration"))?;
        let actual = crate::commands::rpc_chain_id(&self.l1_http, "l1.http")
            .await
            .map_err(|_| ImportError::Unavailable("own L1 chain ID".into()))?;
        if actual != self.l1_chain_id || expected.is_some_and(|id| id != actual) {
            return Err(bad("own L1 chain ID mismatch"))
        }
        params.l1_chain_id = actual;
        Ok((
            params,
            abci::RpcL1Source::new(rpc::client::connect_http_with_limits(
                self.l1_http.clone(),
                rpc::client::DEFAULT_HTTP_TIMEOUT,
                32 << 20,
            )),
        ))
    }
}
/// Stable operation bindings fixed before preparation; no deserializable trust token.
#[derive(Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct Intent {
    /// Strict lifecycle version.
    schema: u32,
    /// Canonical operation root, also bound into all components.
    root: PathBuf,
    /// Original strict package source; only named files are ever archived.
    source: PathBuf,
    /// Exact private operator profile bytes.
    profile_hash: B256,
    /// Metadata and original ascending frame file hashes.
    package: [B256; 2],
    /// Immutable program/config/dataset contents, including remote-independent chain overrides.
    inputs: std::collections::BTreeMap<String, B256>,
}
impl Intent {
    /// Installation identity covers exact paths, source content and process inputs.
    fn id(&self) -> B256 {
        keccak256(serde_json::to_vec(self).expect("plain metadata"))
    }
    /// Validate strict local schema and path binding on every resume.
    fn load(root: &Path) -> R<Self> {
        files::protected_root(root)?;
        let intent: Self = files::json(&root.join("intent.json"))?;
        if intent.schema != 1 || intent.root != root {
            return Err(bad("unknown intent schema or moved root"))
        }
        Ok(intent)
    }
}
/// Local record of an independent finalized observation; advisory only on restart.
#[derive(Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct Plan {
    /// Strict plan version.
    schema: u32,
    /// Binding of immutable source, binaries and local paths.
    installation_id: B256,
    /// Current generation when independently authenticated.
    generation: u64,
    /// Selected checkpoint/execution floor.
    height: u64,
    /// Authenticated EL hash at the execution floor; startup checks the actual engine.
    el_hash: B256,
    /// Own L1 proof root observation block hash.
    l1_hash: B256,
    /// Own L1 proof observation block number.
    l1_number: u64,
    /// Latest independently observed admission target.
    target: u64,
    /// Original app state, terminal identity and fixed genesis digest.
    state_hash: B256,
    /// Rust digest of full verified frame sequence.
    window_hash: B256,
    /// Independently verified stock package identity (none at fixed genesis).
    stock_hash: Option<B256>,
}
impl Plan {
    /// Compare immutable facts while allowing latest finalized observations to advance.
    fn agrees(&self, other: &Self) -> bool {
        self.schema == 1 &&
            self.installation_id == other.installation_id &&
            self.generation == other.generation &&
            self.height == other.height &&
            self.el_hash == other.el_hash &&
            self.state_hash == other.state_hash &&
            self.window_hash == other.window_hash &&
            self.stock_hash == other.stock_hash
    }
}
/// Historical observation made immediately before committing the group. Offline status never
/// treats it as current trust.
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Observation {
    /// Local receipt format.
    schema: u32,
    /// Source/binary/path binding of the installation.
    installation_id: B256,
    /// Own-finalized generation at the observation.
    generation: u64,
    /// Finalized L1 block containing the landing proof.
    l1_number: u64,
    /// Exact canonical L1 block hash.
    l1_hash: B256,
    /// Latest landed height at that pinned block, possibly ahead of the installed state.
    target: u64,
}
/// Reject a foreign or unknown plan before any stage or helper process is started.
fn load_plan(root: &Path, id: B256) -> R<Option<Plan>> {
    if !files::exists(&root.join("plan.json"))? {
        return Ok(None)
    }
    let plan: Plan = files::json(&root.join("plan.json"))?;
    if plan.schema != 1 || plan.installation_id != id {
        return Err(bad("plan identity"))
    }
    Ok(Some(plan))
}
/// Persist only verifier-derived contradictions, outside all disposable stage directories.
fn latch<T>(root: &Path, r: R<T>) -> R<T> {
    if let Err(e @ ImportError::Safety(detail)) = &r {
        let path = root.join("halted.json");
        let save = || -> R<()> {
            if !files::exists(&path)? {
                files::put(&path, e)?;
            }
            Ok(())
        };
        if let Err(storage) = save() {
            if let Err(prior @ ImportError::Safety(_)) = check_latch(root) {
                return Err(prior)
            }
            return Err(ImportError::Safety(format!(
                "{detail}; failed to persist terminal evidence: {storage}"
            )))
        }
    }
    r
}
/// Refuse all further mutation after an authenticated contradiction.
fn check_latch(root: &Path) -> R<()> {
    if files::exists(&root.join("halted.json"))? {
        let e: ImportError = files::json(&root.join("halted.json"))?;
        return Err(match e {
            ImportError::Safety(_) => e,
            _ => bad("invalid safety latch"),
        })
    }
    Ok(())
}
/// Nonmutating inspection of a prepared, interrupted, completed, or halted installation.
pub fn status(root: &Path) -> R<Value> {
    let i = Intent::load(root)?;
    let id = i.id();
    let plan = load_plan(root, id)?;
    let ready = files::exists(&root.join("ready"))?;

    let halted = match check_latch(root) {
        Err(ImportError::Safety(_)) => true,
        Ok(()) => false,
        Err(e) => return Err(e),
    };
    if ready && !halted {
        boundary::check(&root.join("ready/app"))?;
    }
    let observation = if ready {
        let observed: Observation = files::json(&root.join("ready/publication-observation.json"))?;
        if observed.schema != 1 ||
            observed.installation_id != id ||
            plan.as_ref().is_none_or(|p| {
                p.generation != observed.generation || p.height > observed.target
            })
        {
            return Err(bad("publication observation mismatch"))
        }
        Some(observed)
    } else {
        None
    };
    let interrupted = files::exists(&root.join(".checkpoint-work"))?;
    let phase = if halted {
        "halted"
    } else if ready {
        "installed"
    } else if plan.is_some() && interrupted {
        "staging"
    } else if plan.is_some() {
        "prepared"
    } else {
        "preparing"
    };
    Ok(
        json!({"schema":1,"phase":phase,"installation_id":id,"generation":plan.as_ref().map(|p|p.generation),"execution_floor":plan.as_ref().map(|p|p.height),"observed_latest_target":observation.as_ref().map(|o|o.target).or_else(||plan.as_ref().map(|p|p.target)),"observed_l1_hash":observation.as_ref().map(|o|o.l1_hash).or_else(||plan.as_ref().map(|p|p.l1_hash)),"observed_l1_number":observation.as_ref().map(|o|o.l1_number).or_else(||plan.as_ref().map(|p|p.l1_number)),"live_trust":false}),
    )
}

/// Bind local inputs with the same policy during preparation and runtime checks.
/// Only the read-only current client permits Cargo's executable hardlinks.
async fn input_digest(name: &str, path: &Path) -> R<B256> {
    let result = if name == "client_binary" {
        files::client_digest(path).await
    } else {
        files::local_digest(path, None).await
    };
    result.map_err(|error| match error {
        ImportError::Candidate(detail) | ImportError::Unavailable(detail) => {
            ImportError::Unavailable(format!("local input {name} at {}: {detail}", path.display()))
        }
        safety @ ImportError::Safety(_) => safety,
    })
}

/// Rehash immutable external inputs. Databases must come from stopped isolated copies;
/// stock's writer lock is an extra refusal signal, never permission to adopt an existing node.
async fn inputs(
    profile: &Profile,
    i: &Installation,
) -> R<std::collections::BTreeMap<String, B256>> {
    let mut hashes = std::collections::BTreeMap::new();
    files::canonical(&i.el_source)?;
    if files::exists(&i.el_source.join("db/lock"))? {
        return Err(bad("EL dataset has a writer lock; require quiesced offline data"))
    }
    for (name, path) in [
        ("client_binary", std::env::current_exe().map_err(io)?.canonicalize().map_err(io)?),
        ("database", i.el_source.join("db/mdbx.dat")),
        ("database_version", i.el_source.join("db/database.version")),
        ("el_chain", i.el_chain.clone()),
        ("comet_config", i.comet_config.clone()),
        ("el_helper", i.el_helper.clone()),
        ("comet_helper", i.comet_helper.clone()),
        ("comet_binary", i.comet_binary.clone()),
        ("el_binary", i.el_binary.clone()),
    ]
    .into_iter()
    .chain(profile.chain_config.clone().map(|p| ("chain_config", p)))
    .chain(i.signer_binary.clone().map(|p| ("signer_binary", p)))
    {
        hashes.insert(name.to_owned(), input_digest(name, &path).await?);
    }
    Ok(hashes)
}
/// Archive the original package before authenticating it. The entire root, including its
/// immutable intent, first appears by no-replace rename; an unrelated root cannot be adopted.
async fn initialize(
    root: &Path,
    source: &Path,
    i: &Installation,
    profile_hash: B256,
    hashes: &std::collections::BTreeMap<String, B256>,
) -> R<()> {
    let parent = files::parent(root)?;
    for x in [source, &i.el_source] {
        if root.starts_with(x) || x.starts_with(root) {
            return Err(bad("input and output directories overlap"))
        }
    }
    let intent = Intent {
        schema: 1,
        root: root.to_owned(),
        source: source.to_owned(),
        profile_hash,
        package: package::identity(source).await?,
        inputs: hashes.clone(),
    };
    if files::exists(root)? {
        if Intent::load(root)? != intent {
            return Err(bad("root belongs to another import"))
        }
        return Ok(())
    }
    let separate = files::comet_identity(i, parent)?.is_some();
    let stage = files::stage(parent, ".checkpoint-init-")?;
    if separate {
        files::searchable(stage.path())?;
    }
    files::put(&stage.path().join("intent.json"), &intent)?;
    files::publish_dir(stage.path(), root)?;
    files::sync(parent)
}
/// Copy the original portable bytes under the root lease. Large interrupted copies are
/// already in an identifiable owned tree and never need to be recovered by filename alone.
async fn archive_package(root: &Path, intent: &Intent) -> R<()> {
    let id = intent.id();
    let stage = files::restart_stage(root, id)?;
    let source = &intent.source;
    let archive = stage.join("package");
    files::mkdir(&archive)?;
    for (name, hash) in ["package.json", "blocks.jsonl"].into_iter().zip(intent.package) {
        if files::local_digest(&source.join(name), Some(&archive.join(name))).await? != hash {
            return Err(bad("package changed during archival copy"))
        }
    }
    files::sync(&archive)?;
    files::publish_dir(&archive, &root.join("package"))?;
    files::sync(root)?;
    files::discard(root, id)
}
/// Copy the only allowed state artifacts into a completely independent destination, validating
/// the bytes while copying. No mutable MDBX file is ever hardlinked to the source.
async fn copy_dataset(i: &Installation, work: &Path, intent: &Intent) -> R<()> {
    let db = work.join("el/db");
    files::mkdir(&db)?;
    for (name, key) in [("mdbx.dat", "database"), ("database.version", "database_version")] {
        if files::local_digest(&i.el_source.join("db").join(name), Some(&db.join(name))).await? !=
            intent.inputs[key]
        {
            return Err(bad("stopped EL source changed during copy"))
        }
    }
    if files::exists(&i.el_source.join("db/lock"))? {
        return Err(bad("EL source writer appeared"))
    }
    files::sync(&db)
}
/// Validate the actual template before creating a plan. Stock database installation is
/// compatible only with Comet's persistent GoLevelDB backend.
fn stock_config(i: &Installation) -> R<Vec<u8>> {
    let config = files::read(&i.comet_config, 1 << 20)?;
    let table = crate::recovery::prepare::parse_comet_template(&config).map_err(bad)?;
    if table.get("db_backend").is_some_and(|v| v.as_str() != Some("goleveldb")) {
        return Err(bad("checkpoint import requires db_backend=goleveldb"))
    }
    let validator = table
        .get("priv_validator_laddr")
        .and_then(toml::Value::as_str)
        .is_some_and(|a| !a.is_empty());
    if validator != i.signer_binary.is_some() {
        return Err(bad(
            "validator templates require a bound signer_binary; full nodes require no signer",
        ))
    }
    if let Some(signer) = &i.signer_binary {
        native_program(signer)?;
    }
    crate::recovery::prepare::normalized_comet_config(table, validator, None).map_err(bad)
}
/// Reject scripts, command prefixes and non-native launch adapters before binding the program.
fn native_program(binary: &Path) -> R<()> {
    let mut magic = [0; 4];
    {
        use std::io::Read;
        files::file(binary)?.read_exact(&mut magic).map_err(io)?;
    }
    if !matches!(
        u32::from_be_bytes(magic),
        0x7f454c46 | 0xfeedfacf | 0xcffaedfe | 0xcafebabe | 0xcafebabf
    ) {
        return Err(bad("checkpoint runtime requires a native executable"))
    }
    Ok(())
}
/// Check the pinned stock build and protocol versions in a disposable home. Both the
/// upstream Makefile's abbreviated git stamp and the host builder's full stamp are accepted.
async fn verify_stock_program(binary: &Path) -> R<()> {
    const REVISION: &str = "0880b4d378f347ab16e54ec677ff50d803f37d62";
    native_program(binary)?;
    let private =
        files::stage(&std::env::temp_dir().canonicalize().map_err(io)?, "stock-version-")?;
    let output = tokio::time::timeout(
        std::time::Duration::from_secs(10),
        tokio::process::Command::new(binary)
            .args(["version", "--verbose"])
            .env_clear()
            .env("HOME", private.path())
            .env("CMTHOME", private.path())
            .current_dir(private.path())
            .kill_on_drop(true)
            .output(),
    )
    .await
    .map_err(|_| bad("stock version check timed out"))?
    .map_err(io)?;
    let version: Value = serde_json::from_slice(&output.stdout)
        .map_err(|_| bad("invalid native Comet version report"))?;
    let stamp = version["cometbft"].as_str().and_then(|v| v.strip_prefix("0.39.0+")).unwrap_or("");
    if !output.status.success() ||
        stamp.len() < 7 ||
        !REVISION.starts_with(stamp) ||
        version["abci"] != "2.0.0" ||
        version["block_protocol"] != 11 ||
        version["p2p_protocol"] != 8
    {
        return Err(bad("checkpoint import requires pinned stock Comet v0.40.0"))
    }
    Ok(())
}
/// Driver for an explicit prepare or install. Rechecks external bytes, retained bytes,
/// binaries and live own-finalized generation on every call (including installed retries).
pub async fn operate(profile: &Path, source: Option<&Path>, root: &Path) -> R<Value> {
    // Terminal evidence is actionable even if the donor, profile or own L1 has disappeared.
    if files::exists(root)? {
        Intent::load(root)?;
        check_latch(root)?;
    }
    let (p, profile_hash) = Profile::load(profile)?;
    let i = p.install.as_ref().ok_or_else(|| bad("install profile required"))?;
    native_program(&i.el_binary)?;
    verify_stock_program(&i.comet_binary).await?;
    let config = stock_config(i)?;
    files::canonical(&i.el_source)?;
    let source_lease = abci::ownership::ComponentLease::acquire(
        &abci::ownership::ComponentPaths::new(
            abci::ownership::ComponentRole::Execution,
            &i.el_source,
        )
        .map_err(bad)?,
        None,
    )
    .map_err(bad)?;
    let hashes = inputs(&p, i).await?;
    if let Some(source) = source {
        initialize(root, source, i, profile_hash, &hashes).await?
    }
    let intent = Intent::load(root)?;
    let id = intent.id();
    let activation = acquire_activation(root, id).map_err(bad)?;
    check_latch(root)?;
    let old = load_plan(root, id)?;
    let install = source.is_none();
    if install && old.is_none() {
        return Err(bad("prepare must complete before install"))
    }
    if !files::exists(&root.join("package"))? {
        if source.is_none() || intent.profile_hash != profile_hash {
            return Err(bad("prepare must finish archival first"))
        }
        archive_package(root, &intent).await?;
    }
    if intent.profile_hash != profile_hash ||
        intent.inputs != hashes ||
        intent.package != package::identity(&root.join("package")).await?
    {
        return Err(bad("immutable inputs, binary or profile changed"))
    }
    let (params, l1) = p.own().await?;
    let v = latch(root, package::verify(&root.join("package"), &params, &l1).await)?;
    let published = files::exists(&root.join("ready"))?;
    if published {
        boundary::check(&root.join("ready/app"))?;
        files::sync(root)?;
        return status(root)
    }
    // No stage is ever adopted. A SIGKILL can leave private unpublished trees; exact owner
    // and inode are bound in their claim. All children retain the activation descriptor.
    let work = files::restart_stage(root, id)?;
    let dir = work.as_path();
    let holds = helpers::Holds::acquire(&activation, dir, vec![source_lease])?;
    let stock = dir.join("stock.json");
    let stock_hash = if v.first_height().is_some() {
        let hash = package::stock(&root.join("package"), &stock, &v).await?;
        if !install {
            latch(root, helpers::comet(&i.comet_helper, &stock, hash, None, &v, &holds).await)?;
        }
        Some(hash)
    } else {
        None
    };
    let target = v.admission_target();
    let plan = Plan {
        schema: 1,
        installation_id: id,
        generation: v.state().generation,
        height: v.landing().height,
        el_hash: v.landing().el_hash,
        l1_hash: target.l1_block_hash,
        l1_number: target.l1_block_number,
        target: target.checkpoint_height,
        state_hash: keccak256(serde_json::to_vec(v.state()).map_err(bad)?),
        window_hash: v.window_hash(),
        stock_hash,
    };
    if old.as_ref().is_some_and(|o| !o.agrees(&plan)) {
        return Err(bad("authenticated checkpoint no longer matches prepared operation"))
    }
    copy_dataset(i, dir, &intent).await?;
    let manifest = latch(root, helpers::Manifest::new(id, &params, &v))?;
    if !install {
        manifest.run(i, dir, &v, &holds, false).await?;
        if old.is_none() {
            files::put(&root.join("plan.json"), &plan)?
        }
        files::discard(root, id)?;
        return status(root)
    }
    let home = dir.join("comet");
    if let Some(expected) = stock_hash {
        if latch(
            root,
            helpers::comet(&i.comet_helper, &stock, expected, Some(&home), &v, &holds).await,
        )? != expected
        {
            return Err(bad("stock verify/install identity mismatch"))
        }
    } else {
        files::mkdir(&home)?;
        files::mkdir(&home.join("config"))?;
        files::mkdir(&home.join("data"))?;
        files::put(&home.join("config/genesis.json"), v.genesis())?;
    }
    helpers::bind_stock(&i.comet_helper, &home, id, v.first_height().is_none(), &holds).await?;
    files::mkdir(&home.join("run"))?;
    files::write(&home.join("config/config.toml"), &config)?;
    manifest.run(i, dir, &v, &holds, true).await?;
    let store = abci::Store::imported(dir.join("app"), id, plan.height);
    if let Some(bootstrap) = v.recovery_bootstrap() {
        store.save_recovery_bootstrap(bootstrap).map_err(bad)?
    }
    if v.first_height().is_some() {
        store.save_comet_hash(plan.height, v.landing().comet_hash).map_err(bad)?;
        store.save_val_state(&v.state().val_state).map_err(bad)?
    }
    if let Some(w) = v.anchor_witness() {
        files::write(&dir.join("app/anchor-witness.rlp"), w)?;
    }
    store.save(v.state()).map_err(bad)?;
    latch(root, manifest.smoke(i, dir, &holds, &params, &l1).await)?;
    if files::exists(&stock)? {
        fs::remove_file(&stock).map_err(io)?;
    }
    sync_tree(dir)?;
    boundary::seal(dir, root, &plan, &v, i)?;
    if let Some((uid, gid)) = files::comet_identity(i, files::parent(root)?)? {
        files::assign_tree(&dir.join("comet"), uid, gid)?;
        files::searchable(dir)?;
    }
    // Reopen the actual immutable source before final publication. A later generation, or
    // a removed/rolled-back landing, must never authorize publishing the old operation.
    if intent.inputs != inputs(&p, i).await? ||
        intent.package != package::identity(&root.join("package")).await?
    {
        return Err(bad("immutable inputs changed before publication"))
    }
    let (params, l1) = p.own().await?;
    let last = latch(root, v.current_landing(&params, &l1).await)?;
    files::put(
        &dir.join("publication-observation.json"),
        &Observation {
            schema: 1,
            installation_id: id,
            generation: plan.generation,
            l1_hash: last.l1_block_hash,
            l1_number: last.l1_block_number,
            target: last.checkpoint_height,
        },
    )?;
    files::sync(dir)?;
    files::publish_dir(dir, &root.join("ready"))?;
    files::sync(root)?;
    status(root)
}
/// Flush closed native stores and parent directory entries before selecting the group.
fn sync_tree(path: &Path) -> R<()> {
    let meta = fs::symlink_metadata(path).map_err(io)?;
    if meta.is_dir() {
        for e in fs::read_dir(path).map_err(io)? {
            sync_tree(&e.map_err(io)?.path())?
        }
    } else if !meta.is_file() {
        return Err(bad("unexpected alias or special file in staged stores"))
    }
    files::sync(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn local_inputs(root: &Path) -> Profile {
        fs::create_dir_all(root.join("offline/db")).unwrap();
        for name in ["offline/db/mdbx.dat", "offline/db/database.version", "local-file"] {
            fs::write(root.join(name), b"local input").unwrap();
        }
        let local = root.join("local-file");
        serde_json::from_value(json!({
            "schema": 1,
            "l1_chain_id": "0x1",
            "l2_chain_id": 167001,
            "l1_http": "http://127.0.0.1:1",
            "install": {
                "el_source": root.join("offline"),
                "el_chain": local,
                "comet_config": local,
                "el_helper": local,
                "comet_helper": local,
                "comet_binary": local,
                "el_binary": local
            }
        }))
        .unwrap()
    }

    #[tokio::test]
    async fn local_inputs_accept_the_cargo_hardlinked_client_executable() {
        use std::os::unix::fs::MetadataExt;
        let client = std::env::current_exe().unwrap().canonicalize().unwrap();
        let temp = tempfile::tempdir_in(client.parent().unwrap()).unwrap();
        let root = temp.path().canonicalize().unwrap();
        fs::hard_link(&client, root.join("cargo-client-alias")).unwrap();
        assert!(client.metadata().unwrap().nlink() >= 2);
        let profile = local_inputs(&root);
        let hashes = inputs(&profile, profile.install.as_ref().unwrap()).await.unwrap();
        assert_ne!(hashes["client_binary"], B256::ZERO);
    }

    #[tokio::test]
    async fn local_inputs_identify_the_hardlinked_dataset_as_a_local_failure() {
        let temp = tempfile::tempdir().unwrap();
        let root = temp.path().canonicalize().unwrap();
        let profile = local_inputs(&root);
        let database = root.join("offline/db/mdbx.dat");
        fs::hard_link(&database, root.join("database-alias")).unwrap();
        let error = inputs(&profile, profile.install.as_ref().unwrap()).await.unwrap_err();
        let ImportError::Unavailable(detail) = error else {
            panic!("local dataset failure must not blame checkpoint candidate: {error}")
        };
        assert!(detail.contains("local input database"), "{detail}");
        assert!(detail.contains(database.to_str().unwrap()), "{detail}");
        assert!(detail.contains("singly linked regular file"), "{detail}");
    }

    #[test]
    fn crashes_cannot_select_partial_component_writes_or_consume_foreign_state() {
        let temp = tempfile::tempdir().unwrap();
        let root = temp.path().canonicalize().unwrap();
        fs::set_permissions(&root, std::os::unix::fs::PermissionsExt::from_mode(0o700)).unwrap();
        let intent = Intent {
            schema: 1,
            root: root.clone(),
            source: root.join("source"),
            profile_hash: B256::ZERO,
            package: [B256::ZERO; 2],
            inputs: Default::default(),
        };
        files::put(&root.join("intent.json"), &intent).unwrap();
        let hrs = root.join("original-hrs");
        let wal = root.join("old-wal");
        fs::write(&hrs, b"signed-round").unwrap();
        fs::write(&wal, b"old consensus wal").unwrap();
        let lease = acquire_activation(&root, intent.id()).unwrap();
        for stop in 0..5 {
            let stage = files::restart_stage(&root, intent.id()).unwrap();
            let components = ["app", "comet", "el", ".etna-checkpoint-completed.json"];
            for c in components.iter().take(stop) {
                fs::write(stage.join(c), b"interrupted component").unwrap()
            }
            assert!(!root.join("ready").exists());
            assert!(boundary::check(&stage.join("app")).is_err());
            assert_eq!(status(&root).unwrap()["live_trust"], false);
            assert_eq!(fs::read(&hrs).unwrap(), b"signed-round");
            assert_eq!(fs::read(&wal).unwrap(), b"old consensus wal");
        }
        let stage = root.join(".checkpoint-work");
        fs::write(stage.join("owner.json"), b"{}").unwrap();
        assert!(files::restart_stage(&root, intent.id()).is_err());
        assert!(stage.join("el").exists());
        drop(lease);
    }
    #[test]
    fn only_authenticated_safety_survives_stage_reconstruction() {
        let temp = tempfile::tempdir().unwrap();
        let root = temp.path().canonicalize().unwrap();
        for error in [bad("publisher"), ImportError::Unavailable("missing state".into())] {
            assert_eq!(latch::<()>(&root, Err(error.clone())), Err(error));
            assert!(!root.join("halted.json").exists())
        }
        let fatal = ImportError::Safety("own finalized contradiction".into());
        assert_eq!(latch::<()>(&root, Err(fatal.clone())), Err(fatal.clone()));
        assert_eq!(check_latch(&root), Err(fatal));
    }
    #[tokio::test]
    async fn package_refuses_aliases_and_never_silently_accepts_short_last_frame() {
        let temp = tempfile::tempdir().unwrap();
        let dir = temp.path().canonicalize().unwrap();
        fs::write(dir.join("package.json"), b"{}").unwrap();
        fs::write(dir.join("blocks.jsonl"), b"{}").unwrap();
        assert!(package::frames(&dir).unwrap().next().unwrap().is_err());
        fs::hard_link(dir.join("blocks.jsonl"), dir.join("alias")).unwrap();
        assert!(package::identity(&dir).await.is_err());
        let external = tempfile::tempdir().unwrap();
        fs::rename(dir.join("alias"), external.path().join("foreign")).unwrap();
        assert!(package::identity(&dir).await.is_err());
    }
}
