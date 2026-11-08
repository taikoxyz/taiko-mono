//! Offline checkpoint import (DATA-5.4-5): authenticate a package against own finalized L1,
//! install fresh app, stock Comet and EL stores in a private stage, then publish them together by
//! one rename. The import never reads or writes signer files, and completion alone grants no
//! signing authority (DATA-5.4-7): the published stores run as ordinary ones.
//!
//! Root layout:
//! - `ROOT/import.lock`: the one flock. `import` holds it and its helper children inherit it.
//! - `ROOT/halted.json`: the Safety latch, the serialized [`ImportError`].
//! - `ROOT/stage/`: the private 0700 working tree (`ready/{app,comet,el}`, `stock/`,
//!   `headers.json`, `scratch/`).
//! - `ROOT/ready/{app,comet,el}`: published by one `rename(stage/ready, ROOT/ready)`.
use alloy_primitives::B256;
use lander::checkpoint_import::{ImportError, VerifiedImport};
use serde_json::{Value, json};
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    os::unix::fs::{DirBuilderExt, OpenOptionsExt},
    path::{Path, PathBuf},
};
use url::Url;

/// Collection of publishable app packages from read-only archive RPC.
pub mod export;
/// The stock Comet and EL install helpers.
mod helpers;
/// Bounded package input and the stock dir.
mod package;

/// Candidate and unavailable failures never create a terminal latch.
type R<T> = Result<T, ImportError>;
/// Reject untrusted or inconsistent inputs.
fn bad(m: impl ToString) -> ImportError {
    ImportError::Candidate(m.to_string())
}
/// Missing material or a local failure: retry without advancing the import.
fn unavailable(m: impl ToString) -> ImportError {
    ImportError::Unavailable(m.to_string())
}
/// Storage diagnostics disclose only portable I/O kinds.
fn io(e: std::io::Error) -> ImportError {
    unavailable(format!("storage: {:?}", e.kind()))
}

/// The Safety latch beside the stage.
const HALTED: &str = "halted.json";

/// The deployment and own L1 the import and export authenticate against. The L1 endpoint must be
/// the operator's own node: it supplies every finality and proof read.
#[derive(clap::Args, Clone, Debug)]
pub struct Own {
    /// HTTP RPC endpoint of the operator's own L1 node. It must serve the finalized Inbox proofs
    /// and the historical L1 headers the checkpoint needs.
    #[arg(long = "l1.http", value_parser = crate::flags::common::http_url)]
    pub l1_http: Url,
    /// L2 chain id selecting the built-in chain parameters.
    #[arg(long = "l2.chain-id")]
    pub l2_chain_id: u64,
    /// Optional TOML file overriding the built-in chain parameters (devnet only).
    #[arg(long = "chain-config")]
    pub chain_config: Option<PathBuf>,
}

impl Own {
    /// Bind the chain parameters to the endpoint's full-width L1 chain id and connect to it.
    async fn connect(&self) -> R<(abci::ChainParams, abci::RpcL1Source)> {
        let (mut params, expected) =
            crate::commands::load_chain_params(self.l2_chain_id, self.chain_config.as_deref())
                .map_err(|e| bad(format!("deployment configuration: {e}")))?;
        let actual = crate::commands::rpc_chain_id(&self.l1_http, "l1.http")
            .await
            .map_err(|_| unavailable("own L1 chain id (l1.http)"))?;
        crate::commands::bind_l1_chain_id(&mut params, expected, actual).map_err(bad)?;
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

/// The local inputs of one import. None of them may lie inside ROOT.
#[derive(clap::Args, Clone, Debug)]
pub struct Inputs {
    /// Package directory holding `package.json` and `blocks.jsonl` (from `export`).
    #[arg(long)]
    pub package: PathBuf,
    /// A stopped EL datadir holding the state at the checkpoint. No alethia-reth may run on it
    /// for the duration of the import; it is copied and never written.
    #[arg(long)]
    pub el_source: PathBuf,
    /// The original deployment's EL chain JSON (alethia-reth `--chain`).
    #[arg(long)]
    pub el_chain: PathBuf,
    /// The `etna-el-import` helper.
    #[arg(long)]
    pub el_helper: PathBuf,
    /// The `etna-comet-import` helper.
    #[arg(long)]
    pub comet_helper: PathBuf,
    /// Stock Comet `config.toml`, copied verbatim to `ready/comet/config/config.toml`. Its
    /// `db_backend` must be absent or `goleveldb`.
    #[arg(long)]
    pub comet_config: PathBuf,
}

impl Inputs {
    /// Every input path, for the ROOT overlap check.
    fn paths(&self) -> [&Path; 6] {
        [
            &self.package,
            &self.el_source,
            &self.el_chain,
            &self.el_helper,
            &self.comet_helper,
            &self.comet_config,
        ]
    }
}

/// Open and exclusively lock `ROOT/import.lock` without waiting. A held lock means another import
/// or a helper of an earlier, killed one still runs: it is reported as unavailable.
pub fn lock_root(root: &Path) -> R<File> {
    use std::os::fd::AsRawFd;
    let lock = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .open(root.join("import.lock"))
        .map_err(io)?;
    // SAFETY: flock on a descriptor this function owns.
    if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
        let error = std::io::Error::last_os_error();
        return Err(if error.kind() == std::io::ErrorKind::WouldBlock {
            unavailable(
                "import root is busy: another import, or a helper of an interrupted one, holds \
                 ROOT/import.lock; rerun once it exits",
            )
        } else {
            io(error)
        });
    }
    Ok(lock)
}

/// A helper process that inherits the root lock: until the helper exits, no rerun can discard
/// the stage it writes, even if this process is killed. stdout carries the helper's receipt and
/// stderr its diagnostics.
pub fn helper_command(lock: &File, program: &Path) -> tokio::process::Command {
    use std::os::fd::AsRawFd;
    let fd = lock.as_raw_fd();
    let mut command = tokio::process::Command::new(program);
    command
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::inherit())
        .kill_on_drop(true);
    // SAFETY: only the async-signal-safe fcntl runs in the forked child.
    unsafe {
        command.pre_exec(move || {
            if libc::fcntl(fd, libc::F_SETFD, 0) < 0 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    command
}

/// Where a run under the root lock starts.
enum Begun {
    /// The held root lock and a fresh, empty, private stage.
    Stage(File, PathBuf),
    /// An earlier run already published `ready`: a lost acknowledgement is answered from it.
    AlreadyReady,
}

/// Take the root lock, then: refuse a halted root; answer a published one; refuse `inputs` that
/// overlap ROOT; and discard any interrupted stage for a fresh one (DATA-5.4-5: "discard its
/// staging area").
fn begin(root: &Path, inputs: &[&Path]) -> R<Begun> {
    let lock = lock_root(root)?;
    check_latch(root)?;
    let stage = root.join("stage");
    if exists(&root.join("ready"))? {
        // A crash between the publishing rename and the stage removal leaves the rest behind.
        remove_tree(&stage)?;
        return Ok(Begun::AlreadyReady);
    }
    for input in inputs {
        let path = fs::canonicalize(input)
            .map_err(|e| unavailable(format!("local input {}: {:?}", input.display(), e.kind())))?;
        if path.starts_with(root) || root.starts_with(&path) {
            return Err(bad(format!("input {} overlaps the import root", input.display())));
        }
    }
    remove_tree(&stage)?;
    mkdir(&stage)?;
    Ok(Begun::Stage(lock, stage))
}

/// Make the complete `stage/ready` durable, publish it as `ROOT/ready` by one rename, then drop
/// the rest of the stage. The caller holds the root lock.
fn publish(root: &Path) -> R<()> {
    let stage = root.join("stage");
    // Also flushes stage/ready itself, whose entries the helpers created.
    sync_tree(&stage.join("ready"))?;
    fs::rename(stage.join("ready"), root.join("ready")).map_err(io)?;
    sync(root)?;
    remove_tree(&stage)?;
    sync(root)
}

/// Persist an authenticated contradiction as the root's first cause; other failures pass through.
fn latch<T>(root: &Path, r: R<T>) -> R<T> {
    if let Err(e @ ImportError::Safety(detail)) = &r {
        let bytes = serde_json::to_vec(e).expect("plain error");
        if let Err(storage) = write_first(&root.join(HALTED), &bytes) {
            return Err(ImportError::Safety(format!(
                "{detail}; failed to persist {HALTED}: {storage}"
            )));
        }
    }
    r
}

/// Refuse every run of a root that holds authenticated contradiction evidence.
fn check_latch(root: &Path) -> R<()> {
    let path = root.join(HALTED);
    if !exists(&path)? {
        return Ok(());
    }
    match serde_json::from_slice(&read(&path, 1 << 20)?) {
        Ok(e @ ImportError::Safety(_)) => Err(e),
        _ => Err(bad(format!("invalid safety latch {}", path.display()))),
    }
}

/// The root's phase, and the generation and execution floor of a published app store, as one
/// JSON object. A fixed-origin import has no AppState until InitChain, so both are null.
/// Read-only: it takes no lock and changes nothing.
pub fn status(root: &Path) -> R<Value> {
    let ready = root.join("ready");
    let phase = match check_latch(root) {
        Err(ImportError::Safety(_)) => "halted",
        Err(e) => return Err(e),
        Ok(()) if exists(&ready)? => "ready",
        Ok(()) if exists(&root.join("stage"))? => "interrupted",
        Ok(()) => "absent",
    };
    // A plain read: `Store::load` would remove a running app's in-flight temporary file.
    let path = ready.join("app").join(abci::store::STATE_FILE);
    let state: Option<abci::store::AppState> = if phase == "ready" && exists(&path)? {
        let bytes = read(&path, 64 << 20)?;
        Some(serde_json::from_slice(&bytes).map_err(|e| bad(format!("installed app state: {e}")))?)
    } else {
        None
    };
    Ok(json!({
        "phase": phase,
        "generation": state.as_ref().map(|s| s.generation),
        "execution_floor": state.and_then(|s| s.execution_floor).map(|f| f.number),
    }))
}

/// Import one checkpoint package into `ROOT/ready` (DATA-5.4-5), or answer an earlier
/// publication. Every step writes only inside the stage; `ready` appears by one rename at the end.
pub async fn import(own: &Own, inputs: &Inputs, root: &Path) -> R<Value> {
    fs::DirBuilder::new().recursive(true).mode(0o700).create(root).map_err(io)?;
    let root = &fs::canonicalize(root).map_err(io)?;
    let (lock, stage) = match begin(root, &inputs.paths())? {
        Begun::Stage(lock, stage) => (lock, stage),
        Begun::AlreadyReady => return status(root),
    };
    let config = comet_config(&inputs.comet_config)?;
    let (params, l1) = own.connect().await?;
    let stock = stage.join("stock");
    mkdir(&stock)?;
    // The one authentication (DATA-5.4-2). It writes stock/blocks.jsonl from exactly the frames
    // it verifies, so nothing is read from the package again.
    let v = latch(root, package::verify(&inputs.package, &params, &l1, Some(&stock)).await)?;
    let ready = stage.join("ready");
    mkdir(&ready)?;
    mkdir(&ready.join("app"))?;
    let comet = ready.join("comet");
    if v.first_height().is_some() {
        package::write_stock_dir(&stock, &v)?;
        helpers::comet_install(&lock, &inputs.comet_helper, &comet, &stock, &v).await?;
    } else {
        // DATA-5.4-1: s = o starts from the original genesis through stock InitChain.
        mkdir(&comet)?;
        mkdir(&comet.join("config"))?;
        mkdir(&comet.join("data"))?;
        write_new(
            &comet.join("config/genesis.json"),
            &serde_json::to_vec(v.genesis()).map_err(bad)?,
        )?;
    }
    mkdir(&comet.join("run"))?;
    write_new(&comet.join("config/config.toml"), &config)?;
    mkdir(&stage.join("scratch"))?;
    let manifest = latch(root, helpers::Manifest::new(&params, &v))?;
    helpers::el_install(&lock, inputs, &stage, &manifest, &params, &v).await?;
    let store = abci::Store::new(ready.join("app"));
    let stored = if v.first_height().is_some() {
        store.install_import(v.state(), v.recovery_bootstrap())
    } else {
        // InitChain authenticates the origin itself (DATA-5.4-1, RECOV-8.4).
        v.recovery_bootstrap().map_or(Ok(()), |b| store.save_recovery_bootstrap(b))
    };
    stored.map_err(|e| unavailable(format!("app store: {e}")))?;
    publish(root)?;
    drop(lock);
    status(root)
}

/// Read the stock Comet config to install. Checkpoint stores are GoLevelDB; CometBFT reads its
/// keys case-insensitively, so every spelling of `db_backend` must name it.
fn comet_config(path: &Path) -> R<Vec<u8>> {
    let bytes = read(path, 1 << 20)?;
    let table: toml::Table = std::str::from_utf8(&bytes)
        .ok()
        .and_then(|text| text.parse().ok())
        .ok_or_else(|| bad("invalid Comet config TOML"))?;
    if table.iter().any(|(key, value)| {
        key.eq_ignore_ascii_case("db_backend") && value.as_str() != Some("goleveldb")
    }) {
        return Err(bad("checkpoint import requires db_backend = \"goleveldb\""));
    }
    Ok(bytes)
}

/// Read at most `limit` bytes of a local file.
fn read(path: &Path, limit: u64) -> R<Vec<u8>> {
    let mut bytes = Vec::new();
    File::open(path)
        .map_err(|e| unavailable(format!("local input {}: {:?}", path.display(), e.kind())))?
        .take(limit + 1)
        .read_to_end(&mut bytes)
        .map_err(io)?;
    if bytes.len() as u64 > limit {
        return Err(bad(format!("{} exceeds {limit} bytes", path.display())));
    }
    Ok(bytes)
}

/// Whether `path` exists; an inaccessible path is an error, not absence.
fn exists(path: &Path) -> R<bool> {
    match fs::symlink_metadata(path) {
        Ok(_) => Ok(true),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(false),
        Err(e) => Err(io(e)),
    }
}

/// Create one private directory; an existing one is refused.
fn mkdir(path: &Path) -> R<()> {
    fs::DirBuilder::new().mode(0o700).create(path).map_err(io)
}

/// Create a new private file. Durability comes from [`sync_tree`] before publication.
fn create(path: &Path) -> R<File> {
    OpenOptions::new().create_new(true).write(true).mode(0o600).open(path).map_err(io)
}

/// Create a new private file holding `bytes`.
fn write_new(path: &Path, bytes: &[u8]) -> R<()> {
    create(path)?.write_all(bytes).map_err(io)
}

/// Durably create `path` holding `bytes` through a fsynced temporary file and its directory. An
/// existing `path` is kept unchanged: the first write wins.
fn write_first(path: &Path, bytes: &[u8]) -> R<()> {
    let dir = path.parent().expect("a file in a directory");
    let mut file = tempfile::NamedTempFile::new_in(dir).map_err(io)?;
    file.write_all(bytes).and_then(|()| file.as_file().sync_all()).map_err(io)?;
    match file.persist_noclobber(path) {
        Err(e) if e.error.kind() != std::io::ErrorKind::AlreadyExists => return Err(io(e.error)),
        _ => {}
    }
    sync(dir)
}

/// Remove a directory tree, if present. Links are removed, never followed.
fn remove_tree(path: &Path) -> R<()> {
    match fs::remove_dir_all(path) {
        Err(e) if e.kind() != std::io::ErrorKind::NotFound => Err(io(e)),
        _ => Ok(()),
    }
}

/// Make a file's contents, or a directory's entries, durable.
fn sync(path: &Path) -> R<()> {
    File::open(path).and_then(|f| f.sync_all()).map_err(io)
}

/// fsync every file and directory under `path`, children before their directory, then `path`.
fn sync_tree(path: &Path) -> R<()> {
    let meta = fs::symlink_metadata(path).map_err(io)?;
    if meta.is_dir() {
        for entry in fs::read_dir(path).map_err(io)? {
            sync_tree(&entry.map_err(io)?.path())?;
        }
    } else if !meta.is_file() {
        return Err(unavailable(format!("unexpected link or special file {}", path.display())));
    }
    sync(path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;

    /// A fresh canonical ROOT inside a temporary parent that holds neighbouring operator files.
    fn root() -> (tempfile::TempDir, PathBuf) {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().canonicalize().unwrap().join("root");
        fs::create_dir(&root).unwrap();
        (dir, root)
    }

    fn staged(begun: Begun) -> (std::fs::File, PathBuf) {
        match begun {
            Begun::Stage(lock, stage) => (lock, stage),
            Begun::AlreadyReady => panic!("expected a fresh stage"),
        }
    }

    /// DATA-5.4-5: an interrupted import discards its staging area and never publishes it.
    #[test]
    fn rerun_discards_an_interrupted_stage_and_never_publishes_it() {
        let (dir, root) = root();
        let outside = dir.path().join("outside");
        fs::create_dir(&outside).unwrap();
        fs::write(outside.join("sentinel"), b"operator data").unwrap();
        assert_eq!(status(&root).unwrap()["phase"], "absent");
        for component in ["app", "comet", "el"] {
            let path = root.join("stage/ready").join(component);
            fs::create_dir_all(&path).unwrap();
            fs::write(path.join("junk"), b"interrupted").unwrap();
        }
        // Discarding the stage removes a link, never what it points at.
        std::os::unix::fs::symlink(&outside, root.join("stage/ready/el/link")).unwrap();
        assert_eq!(
            status(&root).unwrap(),
            json!({"phase":"interrupted","generation":null,"execution_floor":null})
        );
        let (_lock, stage) = staged(begin(&root, &[]).unwrap());
        assert_eq!(stage, root.join("stage"));
        assert_eq!(fs::read_dir(&stage).unwrap().count(), 0);
        assert_eq!(stage.metadata().unwrap().permissions().mode() & 0o777, 0o700);
        assert!(!root.join("ready").exists());
        assert_eq!(fs::read(outside.join("sentinel")).unwrap(), b"operator data");
    }

    #[test]
    fn publish_renames_the_complete_stage_and_reruns_report_ready() {
        let (_dir, root) = root();
        let (lock, stage) = staged(begin(&root, &[]).unwrap());
        fs::create_dir_all(stage.join("ready/app")).unwrap();
        fs::write(stage.join("ready/app/x"), b"x").unwrap();
        fs::create_dir(stage.join("stock")).unwrap();
        publish(&root).unwrap();
        drop(lock);
        assert_eq!(fs::read(root.join("ready/app/x")).unwrap(), b"x");
        assert!(!root.join("stage").exists());
        // A fixed-origin import has no AppState yet.
        assert_eq!(
            status(&root).unwrap(),
            json!({"phase":"ready","generation":null,"execution_floor":null})
        );
        // A crash after the rename leaves the rest of the stage; a rerun only removes it.
        fs::create_dir_all(root.join("stage/stock")).unwrap();
        assert!(matches!(begin(&root, &[]).unwrap(), Begun::AlreadyReady));
        assert!(!root.join("stage").exists());
        assert_eq!(fs::read(root.join("ready/app/x")).unwrap(), b"x");
        assert_eq!(status(&root).unwrap()["phase"], "ready");
    }

    /// Only an authenticated contradiction is terminal (SYNC-9-7); it survives every rerun.
    #[test]
    fn halted_latch_survives_and_blocks_every_rerun() {
        let (_dir, root) = root();
        for error in [bad("publisher"), ImportError::Unavailable("missing state".into())] {
            assert_eq!(latch::<()>(&root, Err(error.clone())), Err(error));
            assert!(!root.join("halted.json").exists());
        }
        assert!(matches!(begin(&root, &[]), Ok(Begun::Stage(..))));
        let fatal = ImportError::Safety("own finalized contradiction".into());
        assert_eq!(latch::<()>(&root, Err(fatal.clone())), Err(fatal.clone()));
        let later = ImportError::Safety("a later contradiction".into());
        assert_eq!(latch::<()>(&root, Err(later.clone())), Err(later));
        for _ in 0..2 {
            assert_eq!(begin(&root, &[]).err(), Some(fatal.clone()));
        }
        // The halted run's stage is evidence: it is kept, not discarded.
        assert!(root.join("stage").exists());
        assert_eq!(status(&root).unwrap()["phase"], "halted");
        fs::write(root.join("halted.json"), br#"{"class":"candidate","detail":"x"}"#).unwrap();
        assert!(matches!(begin(&root, &[]), Err(ImportError::Candidate(_))));
    }

    /// Without inheritance, a SIGKILLed import could have its stage deleted by a rerun while one
    /// of its helpers still writes there.
    #[tokio::test]
    async fn helpers_inherit_the_root_lock_until_they_exit() {
        let (_dir, root) = root();
        let lock = lock_root(&root).unwrap();
        assert!(matches!(lock_root(&root), Err(ImportError::Unavailable(_))));
        let mut child =
            helper_command(&lock, Path::new("/bin/sh")).args(["-c", "sleep 2"]).spawn().unwrap();
        drop(lock);
        assert!(matches!(lock_root(&root), Err(ImportError::Unavailable(_))));
        assert!(matches!(begin(&root, &[]), Err(ImportError::Unavailable(_))));
        assert!(child.wait().await.unwrap().success());
        drop(lock_root(&root).unwrap());
    }

    #[test]
    fn comet_config_requires_goleveldb_stores() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("config.toml");
        for (body, accepted) in [
            ("", true),
            ("moniker = \"a\"\n[p2p]\nladdr = \"tcp://0.0.0.0:26656\"\n", true),
            ("db_backend = \"goleveldb\"\n", true),
            ("db_backend = \"memdb\"\n", false),
            // CometBFT reads config keys case-insensitively.
            ("DB_Backend = \"memdb\"\n", false),
            ("db_backend = = \"goleveldb\"\n", false),
        ] {
            fs::write(&path, body).unwrap();
            match comet_config(&path) {
                Ok(bytes) if accepted => assert_eq!(bytes, body.as_bytes()),
                Err(ImportError::Candidate(_)) if !accepted => {}
                other => panic!("{body:?}: {other:?}"),
            }
        }
    }

    /// The import owns ROOT: an input there could be deleted with the stage.
    #[test]
    fn inputs_inside_root_are_refused() {
        let (dir, root) = root();
        let outside = dir.path().join("package");
        fs::create_dir(&outside).unwrap();
        fs::create_dir_all(root.join("stage/el-source")).unwrap();
        fs::create_dir_all(root.join("package")).unwrap();
        let alias = dir.path().join("alias");
        std::os::unix::fs::symlink(root.join("package"), &alias).unwrap();
        for inside in [
            root.join("stage/el-source"),
            root.join("package"),
            root.clone(),
            alias,
            dir.path().into(),
        ] {
            assert!(
                matches!(begin(&root, &[&outside, &inside]), Err(ImportError::Candidate(_))),
                "{}",
                inside.display()
            );
        }
        assert!(root.join("stage/el-source").exists());
        assert!(matches!(
            begin(&root, &[&dir.path().join("absent")]),
            Err(ImportError::Unavailable(_))
        ));
        assert!(matches!(begin(&root, &[&outside]), Ok(Begun::Stage(..))));
    }
}
