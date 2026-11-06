//! Local runtime consistency across an atomic publication; none of these markers grant trust.
use super::*;
use std::{collections::BTreeMap, os::unix::fs::MetadataExt};

/// A single published set of canonical component identities. Directory inodes survive normal
/// writes.
#[derive(Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct Boundary {
    /// Strict marker version.
    schema: u32,
    /// Local operation ID.
    installation_id: B256,
    /// Path to which the complete tree, including all siblings, was published.
    ready: PathBuf,
    /// Filesystem object IDs of component directories and stable baseline database directories.
    components: BTreeMap<String, (u64, u64)>,
    /// Native guard used to start the installed participants.
    client_binary: PathBuf,
    /// Native guarded signer for an imported validator.
    native_signer: Option<PathBuf>,
    /// Bound native stock server and verifier paths. Their hashes live in the immutable intent.
    native_comet: PathBuf,
    /// Helper used for read-only in-database identity checks before a writer starts.
    stock_helper: PathBuf,
    /// Actual configured stock OS identity (directory group inheritance is not process identity).
    comet_identity: (u32, u32),
    /// Baseline execution floor.
    height: u64,
    /// Original generation-qualified Comet domain.
    chain_id: String,
    /// Original fixed stock genesis bytes.
    genesis_hash: B256,
    /// Normalized stock runtime config, including database, WAL, genesis and signer paths.
    config_hash: B256,
    /// Local journal identity at exactly the installed height.
    state_hash: B256,
}
/// Check stable identity without hashing databases which legitimately change after startup.
fn objects(base: &Path) -> R<BTreeMap<String, (u64, u64)>> {
    let mut map = BTreeMap::new();
    for s in [
        "app",
        "comet",
        "el",
        "comet/config",
        "comet/data",
        "el/db",
        "el/static_files",
        "el/rocksdb",
        "comet/data/state.db",
        "comet/data/evidence.db",
        "comet/data/blockstore.db",
    ] {
        let p = base.join(s);
        files::canonical(&p)?;
        let m = p.metadata().map_err(io)?;
        if !m.is_dir() {
            return Err(bad("incomplete checkpoint component directory"))
        }
        map.insert(s.to_owned(), (m.dev(), m.ino()));
    }
    let m = files::file(&base.join("el/db/mdbx.dat"))?.metadata().map_err(io)?;
    map.insert("el/db/mdbx.dat".into(), (m.dev(), m.ino()));
    Ok(map)
}
/// Write guards before publication; the final directory rename is the only commit point.
pub(super) fn seal(
    stage: &Path,
    root: &Path,
    plan: &Plan,
    v: &VerifiedImport,
    install: &Installation,
) -> R<()> {
    let marker = Boundary {
        schema: 1,
        installation_id: plan.installation_id,
        ready: root.join("ready"),
        client_binary: std::env::current_exe().map_err(io)?.canonicalize().map_err(io)?,
        components: objects(stage)?,
        native_signer: install.signer_binary.clone(),
        native_comet: install.comet_binary.clone(),
        stock_helper: install.comet_helper.clone(),
        height: plan.height,
        comet_identity: (
            install.comet_uid.unwrap_or_else(|| unsafe { libc::geteuid() }),
            install.comet_gid.unwrap_or_else(|| unsafe { libc::getegid() }),
        ),
        chain_id: v.state().chain_id.clone(),
        genesis_hash: files::keccak_file(&stage.join("comet/config/genesis.json"))?,
        state_hash: plan.state_hash,
        config_hash: files::keccak_file(&stage.join("comet/config/config.toml"))?,
    };
    for name in ["app", "comet", "el"] {
        files::put(&stage.join(name).join(".etna-checkpoint.json"), &marker)?
    }
    files::put(&stage.join(".etna-checkpoint-completed.json"), &marker)
}
/// Refuse selected staging/copied/mixed directories before starting runtime services. Ordinary
/// stores have no marker; their strict legacy journal decoder independently rejects imported state.
pub(crate) fn check(component: &Path) -> R<Option<(B256, u64)>> {
    let Some(base) = component.parent() else { return Ok(None) };
    let marker = component.join(".etna-checkpoint.json");
    let root = base.parent();
    if !files::exists(&marker)? &&
        !files::exists(&base.join(".etna-checkpoint-completed.json"))? &&
        !root.is_some_and(|p| matches!(base.file_name().and_then(|s|s.to_str()),Some("ready"|".checkpoint-work")) && p.join("intent.json").exists())
    {
        let journal = component.join(abci::store::STATE_FILE);
        if files::exists(&journal)? {
            // Legacy --data-dir may be relative or an existing symlink. Inspect only
            // the tag without changing its normal decoder, paths or allocation policy.
            #[derive(Deserialize)]
            struct JournalKind {
                /// Present only in the imported envelope; do not retain the state payload.
                installation_id:Option<serde::de::IgnoredAny>,
            }
            let f=fs::File::open(&journal).map_err(io)?;
            if !f.metadata().map_err(io)?.is_file(){return Err(bad("invalid app journal file type"))}
            let shape:JournalKind=serde_json::from_reader(std::io::BufReader::new(f)).map_err(|_|bad("invalid local app journal"))?;
            if shape.installation_id.is_some() {
                return Err(bad("detached checkpoint journal without completed stores"))
            }
        }
        return Ok(None)
    }
    files::canonical(component)?;
    let root = root.ok_or_else(|| bad("missing checkpoint root"))?;
    let intent = Intent::load(root)?;
    check_latch(root)?;
    let descriptor: Boundary = files::json(&base.join(".etna-checkpoint-completed.json"))?;
    let plan: Plan = files::json(&root.join("plan.json"))?;
    if base != root.join("ready") ||
        descriptor.ready != base ||
        descriptor.schema != 1 ||
        descriptor.installation_id != intent.id() ||
        plan.installation_id != descriptor.installation_id ||
        plan.schema != 1 ||
        plan.height != descriptor.height ||
        plan.state_hash != descriptor.state_hash
    {
        return Err(bad("incomplete or moved checkpoint components"))
    }
    if !["app", "comet", "el"].iter().any(|s| base.join(s) == component) {
        return Err(bad("unexpected checkpoint component path"))
    }
    for dir in [base.join("comet"), base.join("comet/config")] {
        for entry in fs::read_dir(&dir).map_err(io)? {
            let name = entry.map_err(io)?.file_name();
            let name = name.to_string_lossy().to_ascii_lowercase();
            if name.starts_with("config.") && !(dir.ends_with("config") && name == "config.toml") {
                return Err(bad("shadowing stock Comet configuration"))
            }
        }
    }
    for s in ["app", "comet", "el"] {
        let own: Boundary = files::json(&base.join(s).join(".etna-checkpoint.json"))?;
        if own != descriptor {
            return Err(bad("mismatched checkpoint component identity"))
        }
    }
    let state: abci::store::ImportedState =
        files::json(&base.join("app").join(abci::store::STATE_FILE))?;
    if state.schema != 1 ||
        state.installation_id != descriptor.installation_id ||
        state.state.chain_id != descriptor.chain_id ||
        state.state.generation != plan.generation ||
        state.state.last_height < plan.height ||
        (state.state.last_height == plan.height &&
            keccak256(serde_json::to_vec(&state.state).map_err(bad)?) != plan.state_hash) ||
        base.join("comet").metadata().map_err(io)?.uid() != descriptor.comet_identity.0 ||
        descriptor.components != objects(base)? ||
        files::keccak_file(&base.join("comet/config/config.toml"))? != descriptor.config_hash ||
        files::keccak_file(&base.join("comet/config/genesis.json"))? != descriptor.genesis_hash
    {
        return Err(bad("checkpoint baseline or component storage mismatch"))
    }
    Ok(Some((intent.id(), plan.height)))
}
/// Validate the explicit app and Comet pairing used by an external supervisor/full node.
pub(crate) async fn check_pair(app: &Path, comet: &Path) -> R<Value> {
    let a = check(app)?;
    let c = check(comet)?;
    if a != c ||
        a.is_some() &&
            (app.file_name() != Some("app".as_ref()) ||
                comet.file_name() != Some("comet".as_ref()) ||
                app.parent() != comet.parent())
    {
        return Err(bad("mixed app and Comet checkpoint stores"))
    }
    let Some((id, _)) = a else { return Ok(json!({"live_trust":false,"comet_identity":null})) };
    let d: Boundary = files::json(&comet.join(".etna-checkpoint.json"))?;
    let intent = Intent::load(d.ready.parent().ok_or_else(|| bad("missing checkpoint root"))?)?;
    if std::env::current_exe().map_err(io)?.canonicalize().map_err(io)? != d.client_binary {
        return Err(bad("different runtime client executable"))
    }
    for (name, path) in [
        ("client_binary", &d.client_binary),
        ("comet_binary", &d.native_comet),
        ("comet_helper", &d.stock_helper),
    ]
    .into_iter()
    .chain(d.native_signer.as_ref().map(|p| ("signer_binary", p)))
    {
        if intent.inputs.get(name) != Some(&files::local_digest(path, None).await?) {
            return Err(bad("native stock executable changed since prepare"))
        }
    }
    let out = tokio::process::Command::new(&d.stock_helper)
        .env_clear()
        .args(["check-stores", "--home"])
        .arg(comet)
        .arg("--installation-id")
        .arg(id.to_string())
        .kill_on_drop(true)
        .output()
        .await
        .map_err(io)?;
    if !out.status.success() || serde_json::from_slice::<Value>(&out.stdout).ok() != Some(json!({}))
    {
        return Err(bad("stock databases busy or installation identity mismatch"))
    }
    Ok(
        json!({"live_trust":false,"installation_id":id,"comet_identity":d.comet_identity,"comet_binary":d.native_comet,"signer_binary":d.native_signer}),
    )
}

/// Confirm the configured runtime actually serves the authenticated execution floor before
/// opening the ABCI or signer control sockets. Unavailability is not a proof of contradiction.
pub(crate) async fn check_engine(
    app: &Path,
    engine: &impl abci::Engine,
    params: &abci::ChainParams,
    own: &abci::RpcL1Source,
) -> R<()> {
    let root =
        app.parent().and_then(Path::parent).ok_or_else(|| bad("missing completed import"))?;
    let plan: Plan = files::json(&root.join("plan.json"))?;
    let h = match engine.header_by_number(plan.height).await {
        Ok(Some(h)) => h,
        Ok(None) => {
            return Err(ImportError::Unavailable(
                "runtime execution checkpoint header absent".into(),
            ))
        }
        Err(e) if e.is_integrity_failure() => {
            return latch(
                root,
                Err(ImportError::Safety(format!(
                    "malformed own EL checkpoint header at {}",
                    plan.height
                ))),
            )
        }
        Err(_) => return Err(ImportError::Unavailable("runtime execution checkpoint".into())),
    };
    if h.hash_slow() != plan.el_hash {
        // A disk marker alone is not authenticated safety evidence. Re-open own L1 at the
        // current generation before classifying a structurally valid competing EL header.
        let verified = latch(root, package::verify(&root.join("package"), params, own).await)?;
        if verified.landing().height != plan.height ||
            verified.landing().el_hash != plan.el_hash ||
            verified.window_hash() != plan.window_hash
        {
            return Err(bad("published metadata disagrees with reauthenticated checkpoint"))
        }
        return latch(
            root,
            Err(ImportError::Safety(format!(
                "own EL serves {} at {}, finalized landing proves {}",
                h.hash_slow(),
                plan.height,
                verified.landing().el_hash
            ))),
        )
    }
    Ok(())
}
