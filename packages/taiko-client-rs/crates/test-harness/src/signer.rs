//! Host guarded-signer processes; only ephemeral test initialization creates FilePV files.

use std::{
    collections::BTreeMap,
    fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    sync::{Mutex, OnceLock},
};

use anyhow::{Context, Result, ensure};

use crate::keys::ValidatorKey;

/// Process-owned children, shared with signal cleanup before the test runtime disappears.
pub(crate) fn processes() -> &'static Mutex<BTreeMap<u32, Child>> {
    static CHILDREN: OnceLock<Mutex<BTreeMap<u32, Child>>> = OnceLock::new();
    CHILDREN.get_or_init(Mutex::default)
}

/// One helper's immutable configuration and process, separate from its Comet-mounted home.
#[derive(Debug)]
pub(crate) struct SignerNode {
    dir: PathBuf,
    control: PathBuf,
    key_dir: Mutex<PathBuf>,
    chain_id: String,
    pid: Mutex<Option<u32>>,
}

impl SignerNode {
    /// Initializes ephemeral test signing files once; production startup never does this.
    pub(crate) fn ephemeral(
        dir: PathBuf,
        control: PathBuf,
        chain_id: String,
        key: &ValidatorKey,
    ) -> Result<Self> {
        ensure!(!dir.exists(), "test signer directory already exists");
        fs::create_dir_all(&dir)?;
        fs::set_permissions(&dir, fs::Permissions::from_mode(0o700))?;
        fs::write(
            dir.join("key.json"),
            serde_json::to_vec_pretty(&key.priv_validator_key_json())?,
        )?;
        fs::write(dir.join("state.json"), r#"{"height":"0","round":0,"step":0}"#)?;
        for name in ["key.json", "state.json"] {
            fs::set_permissions(dir.join(name), fs::Permissions::from_mode(0o600))?;
        }
        Ok(Self { key_dir: Mutex::new(dir.clone()), dir, control, chain_id, pid: Mutex::new(None) })
    }

    /// Starts with the current Docker-published signer port, retaining the same signing state.
    pub(crate) fn start(&self, port: u16) -> Result<()> {
        self.stop();
        let binary = std::env::var_os("ETNA_SIGNER_BIN").map(PathBuf::from).unwrap_or_else(|| {
            Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/etna-signer/etna-signer")
        });
        ensure!(
            binary.is_file(),
            "guarded signer missing at {}; run just signer or tests/entrypoint.sh",
            binary.display()
        );
        let log =
            fs::OpenOptions::new().create(true).append(true).open(self.dir.join("signer.log"))?;
        let key_dir = self.key_dir.lock().expect("signer key directory").clone();
        let mut owned = processes().lock().expect("signer process registry");
        let child = Command::new(binary)
            .arg("--comet-signer-addr")
            .arg(format!("tcp://127.0.0.1:{port}"))
            .arg("--trust-socket")
            .arg(&self.control)
            .arg("--chain-id")
            .arg(&self.chain_id)
            .arg("--priv-key")
            .arg(key_dir.join("key.json"))
            .arg("--priv-state")
            .arg(key_dir.join("state.json"))
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::from(log))
            .spawn()
            .context("starting guarded FilePV signer")?;
        let pid = child.id();
        owned.insert(pid, child);
        *self.pid.lock().expect("signer pid") = Some(pid);
        Ok(())
    }

    /// Reaps this helper only. FilePV writes are atomic and the same state survives restart.
    pub(crate) fn stop(&self) {
        if let Some(pid) = self.pid.lock().expect("signer pid").take() &&
            let Some(mut child) =
                processes().lock().expect("signer process registry").remove(&pid)
        {
            let _ = child.kill();
            let _ = child.wait();
        }
    }

    /// The actual anti-double-sign record, retained independently of the Comet home.
    pub(crate) fn state(&self) -> Result<serde_json::Value> {
        Ok(serde_json::from_slice(&fs::read(
            self.key_dir.lock().expect("signer key directory").join("state.json"),
        )?)?)
    }

    /// Swap two existing ephemeral identities between stopped helpers. Each identity keeps
    /// its original anti-double-sign files; neither Comet home nor WAL is changed.
    pub(crate) fn swap_identity(&self, source: &Self) {
        source.stop();
        self.stop();
        let mut destination = self.key_dir.lock().expect("signer key directory");
        let mut source = source.key_dir.lock().expect("source key directory");
        std::mem::swap(&mut *destination, &mut *source);
    }

    /// Recorded fresh authorizations for Docker trust-boundary assertions.
    pub(crate) fn authorizations(&self) -> Result<usize> {
        let text = fs::read_to_string(self.dir.join("signer.log"))?;
        Ok(text.lines().filter(|line| line.contains("checkpoint_trust_authorized")).count())
    }

    /// Print only helper diagnostics, never the private key or signing-state contents.
    pub(crate) fn dump_logs(&self) {
        if let Ok(text) = fs::read_to_string(self.dir.join("signer.log")) {
            for line in text.lines().rev().take(30).collect::<Vec<_>>().into_iter().rev() {
                eprintln!("etna-signer: {line}");
            }
        }
    }
}

impl Drop for SignerNode {
    fn drop(&mut self) {
        self.stop();
    }
}
