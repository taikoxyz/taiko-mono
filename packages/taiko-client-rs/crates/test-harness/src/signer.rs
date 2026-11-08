//! Host guarded-signer processes; only ephemeral test initialization creates a key, and every
//! HRS state comes from `etna-signer init-state`.

use std::{
    collections::BTreeMap,
    fs,
    os::unix::fs::{DirBuilderExt, PermissionsExt},
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    sync::{Mutex, OnceLock},
};

use anyhow::{Context, Result, ensure};

use crate::{docker::docker_executable, keys::ValidatorKey};

/// Runs an existing stopped Comet container in the foreground for the supervisor:
/// `sh -c DOCKER_COMET docker-comet <docker> <container>`. `docker start --attach` forwards
/// SIGTERM to Comet but then exits at once with status 0, without waiting for Comet (Docker
/// 29). So on SIGTERM this stops the container (SIGKILL after 10 s) itself, and it always exits
/// with the container's status once Comet has exited.
const DOCKER_COMET: &str = r#"trap '"$1" stop --time 10 "$2" >/dev/null' TERM
"$1" start --attach "$2" &
wait $!
exit "$("$1" wait "$2" || echo 1)""#;

/// How the supervisor runs stock Comet.
#[derive(Debug)]
pub(crate) enum CometLaunch {
    /// This existing, stopped Docker container: the TCP signer transport, as Unix sockets do
    /// not cross the Docker Desktop VM.
    Docker(String),
    /// The pinned host binary `ETNA_COMET_BIN`, over the production Unix signer transport.
    Native,
}

/// A validator directory's per-chain HRS state, `<key_dir>/hrs/<chain_id>.json`.
pub fn signer_hrs(key_dir: &Path, chain_id: &str) -> PathBuf {
    key_dir.join("hrs").join(format!("{chain_id}.json"))
}

/// A validator directory's domains log, `<key_dir>/domains/domains.log`, kept in another
/// directory than the HRS states, as `etna-signer` requires.
pub fn signer_domains_log(key_dir: &Path) -> PathBuf {
    key_dir.join("domains/domains.log")
}

/// The `etna-signer` binary: `ETNA_SIGNER_BIN` or the `just signer` output.
pub fn signer_binary() -> Result<PathBuf> {
    let binary = std::env::var_os("ETNA_SIGNER_BIN").map(PathBuf::from).unwrap_or_else(|| {
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/etna-signer/etna-signer")
    });
    ensure!(
        binary.is_file(),
        "guarded signer missing at {}; run just signer or tests/entrypoint.sh",
        binary.display()
    );
    Ok(binary)
}

/// Runs one `etna-signer` command to success.
fn run_signer(args: &[&std::ffi::OsStr]) -> Result<()> {
    let output = Command::new(signer_binary()?).args(args).output()?;
    ensure!(
        output.status.success(),
        "etna-signer {:?}: {}",
        args.first(),
        String::from_utf8_lossy(&output.stderr)
    );
    Ok(())
}

/// `etna-signer init-domains-log` in `key_dir`, run once per key, after creating the private
/// `hrs/` and `domains/` directories.
pub fn init_signer_domains_log(key_dir: &Path) -> Result<()> {
    for dir in [key_dir.join("hrs"), key_dir.join("domains")] {
        fs::DirBuilder::new().mode(0o700).create(&dir)?;
    }
    let log = signer_domains_log(key_dir);
    run_signer(&["init-domains-log".as_ref(), "--domains-log".as_ref(), log.as_os_str()])
}

/// `etna-signer init-state` for `chain_id` in `key_dir`, as an operator runs it once per
/// chain_id with that key's signer stopped: it creates the zero HRS and logs the chain, and
/// refuses a chain already initialized (RECOV-8.2-1).
pub fn init_signer_state(key_dir: &Path, chain_id: &str) -> Result<()> {
    let (key, hrs, log) =
        (key_dir.join("key.json"), signer_hrs(key_dir, chain_id), signer_domains_log(key_dir));
    run_signer(&[
        "init-state".as_ref(),
        "--chain-id".as_ref(),
        chain_id.as_ref(),
        "--priv-key".as_ref(),
        key.as_os_str(),
        "--priv-state".as_ref(),
        hrs.as_os_str(),
        "--domains-log".as_ref(),
        log.as_os_str(),
    ])
}

/// The guarded validator supervisor (`script/etna_validator.py`) for Comet `home`, the app's
/// `app_store` and the registered key, HRS states and domains log in `key_dir`, serving
/// `chain_id`. The caller adds `ETNA_SIGNER_BIN` and how Comet is run. The one place the Rust
/// tests spell the supervisor's environment.
pub fn supervisor_command(
    home: &Path,
    app_store: &Path,
    key_dir: &Path,
    chain_id: &str,
) -> Command {
    let mut command = Command::new("python3");
    command
        .arg(Path::new(env!("CARGO_MANIFEST_DIR")).join("../../script/etna_validator.py"))
        .env("ETNA_COMET_HOME", home)
        .env("ETNA_APP_STORE", app_store)
        .env("ETNA_PRIV_KEY", key_dir.join("key.json"))
        .env("ETNA_PRIV_STATE_DIR", key_dir.join("hrs"))
        .env("ETNA_DOMAINS_LOG", signer_domains_log(key_dir))
        .env("ETNA_CHAIN_ID", chain_id);
    command
}

/// Process-owned children, shared with signal cleanup before the test runtime disappears.
pub(crate) fn processes() -> &'static Mutex<BTreeMap<u32, Child>> {
    static CHILDREN: OnceLock<Mutex<BTreeMap<u32, Child>>> = OnceLock::new();
    CHILDREN.get_or_init(Mutex::default)
}

/// One helper's immutable configuration and process, separate from its Comet-mounted home.
#[derive(Debug)]
pub(crate) struct SignerNode {
    /// Private fixture directory containing diagnostics and bootstrap identity.
    dir: PathBuf,
    /// App-owned private trust socket.
    control: PathBuf,
    /// Authoritative key, HRS and domains-log directory, never a Comet home.
    key_dir: Mutex<PathBuf>,
    /// Exact deployment-domain Comet chain ID.
    chain_id: String,
    /// Owned supervisor PID in the cleanup registry.
    pid: Mutex<Option<u32>>,
    /// The supervised Comet: its retained home and how the supervisor launches it.
    runtime: Option<(PathBuf, CometLaunch)>,
}

impl SignerNode {
    /// Initializes an ephemeral test validator once, as an operator does: the key, then
    /// `init-domains-log` and `init-state` for `chain_id`. Production startup never does this.
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
        fs::set_permissions(dir.join("key.json"), fs::Permissions::from_mode(0o600))?;
        init_signer_domains_log(&dir)?;
        init_signer_state(&dir, &chain_id)?;
        Self::existing(dir, control, chain_id)
    }

    /// Uses an already initialized validator directory; no runtime creation or height-zero
    /// fallback.
    pub(crate) fn existing(dir: PathBuf, control: PathBuf, chain_id: String) -> Result<Self> {
        ensure!(
            dir.join("key.json").is_file() &&
                signer_hrs(&dir, &chain_id).is_file() &&
                signer_domains_log(&dir).is_file(),
            "authoritative signer files missing"
        );
        Ok(Self {
            key_dir: Mutex::new(dir.clone()),
            dir,
            control,
            chain_id,
            pid: Mutex::new(None),
            runtime: None,
        })
    }

    /// Runs the same supervisor as the supported image against stock Comet launched by `launch`.
    pub(crate) fn supervised(mut self, home: PathBuf, launch: CometLaunch) -> Self {
        self.runtime = Some((home, launch));
        self
    }

    /// Uses stock foreground Comet on this host, preserving the supervisor lifecycle.
    pub(crate) fn native(self, home: PathBuf) -> Self {
        self.supervised(home, CometLaunch::Native)
    }

    /// Starts the supervisor, which starts the signer and Comet, retaining the same signing state.
    pub(crate) fn start(&self) -> Result<()> {
        self.stop();
        let (home, launch) = self.runtime.as_ref().context("signer has no supervised Comet")?;
        let binary = signer_binary()?;
        let log =
            fs::OpenOptions::new().create(true).append(true).open(self.dir.join("signer.log"))?;
        let key_dir = self.key_dir.lock().expect("signer key directory").clone();
        let mut command = supervisor_command(
            home,
            self.control.parent().expect("app store"),
            &key_dir,
            &self.chain_id,
        );
        command.env("ETNA_SIGNER_BIN", &binary);
        match launch {
            CometLaunch::Docker(container) => {
                let docker = docker_executable()?.display().to_string();
                let argv = ["/bin/sh", "-c", DOCKER_COMET, "docker-comet", &docker, container];
                command.env("ETNA_COMET_COMMAND_JSON", serde_json::to_string(&argv)?);
            }
            CometLaunch::Native => {
                let comet = std::env::var_os("ETNA_COMET_BIN")
                    .context("ETNA_COMET_BIN required for native stock consensus")?;
                command.env("ETNA_COMET_BIN", comet);
            }
        }
        let mut owned = processes().lock().expect("signer process registry");
        let child = command
            .stdin(Stdio::null())
            .stdout(Stdio::from(log.try_clone()?))
            .stderr(Stdio::from(log))
            .spawn()
            .context("starting guarded validator supervisor")?;
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
            let _ = Command::new("kill").args(["-TERM", &pid.to_string()]).status();
            let deadline = std::time::Instant::now() + std::time::Duration::from_secs(30);
            while child.try_wait().ok().flatten().is_none() && std::time::Instant::now() < deadline
            {
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
            let _ = child.kill();
            let _ = child.wait();
        }
    }

    /// This chain's HRS path in the current key directory.
    pub(crate) fn state_path(&self) -> PathBuf {
        signer_hrs(&self.key_dir.lock().expect("signer key directory"), &self.chain_id)
    }

    /// The actual anti-double-sign record, retained independently of the Comet home.
    pub(crate) fn state(&self) -> Result<serde_json::Value> {
        Ok(serde_json::from_slice(&fs::read(self.state_path())?)?)
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    /// A Docker CLI stand-in: `start --attach` returns only when Comet exits, `stop` stops it
    /// gracefully with status 7, and `wait` prints the exit status once it exited.
    const FAKE_DOCKER: &str = r#"#!/bin/sh
dir=$(dirname "$0")
echo "$1" >> "$dir/calls"
case "$1" in
  start) while [ ! -e "$dir/exited" ]; do sleep 0.05; done ;;
  stop) sleep 0.3; echo 7 > "$dir/status"; touch "$dir/exited" ;;
  wait) while [ ! -e "$dir/exited" ]; do sleep 0.05; done; cat "$dir/status" ;;
esac
"#;

    fn wait_for(path: &Path) {
        let deadline = Instant::now() + Duration::from_secs(5);
        while !path.exists() {
            assert!(Instant::now() < deadline, "{} never appeared", path.display());
            std::thread::sleep(Duration::from_millis(20));
        }
    }

    #[test]
    fn docker_comet_exits_with_the_container_status_after_it_stopped() {
        let dir = tempfile::tempdir().unwrap();
        let docker = dir.path().join("docker");
        fs::write(&docker, FAKE_DOCKER).unwrap();
        fs::set_permissions(&docker, fs::Permissions::from_mode(0o755)).unwrap();
        let calls = dir.path().join("calls");
        let comet = || {
            Command::new("/bin/sh")
                .args(["-c", DOCKER_COMET, "docker-comet"])
                .arg(&docker)
                .arg("comet")
                .spawn()
                .unwrap()
        };

        // The supervisor's SIGTERM stops the container and waits for Comet's exit.
        let mut child = comet();
        wait_for(&calls);
        let sent = Instant::now();
        assert!(
            Command::new("kill")
                .args(["-TERM", &child.id().to_string()])
                .status()
                .unwrap()
                .success()
        );
        assert_eq!(child.wait().unwrap().code(), Some(7));
        assert!(sent.elapsed() >= Duration::from_millis(300), "returned before Comet exited");
        assert_eq!(fs::read_to_string(&calls).unwrap(), "start\nstop\nwait\n");

        // A Comet that exits on its own reports its own status, without a stop.
        for name in ["calls", "exited"] {
            fs::remove_file(dir.path().join(name)).unwrap();
        }
        let mut child = comet();
        wait_for(&calls);
        fs::write(dir.path().join("status"), "5\n").unwrap();
        fs::write(dir.path().join("exited"), "").unwrap();
        assert_eq!(child.wait().unwrap().code(), Some(5));
        assert_eq!(fs::read_to_string(&calls).unwrap(), "start\nwait\n");
    }
}
