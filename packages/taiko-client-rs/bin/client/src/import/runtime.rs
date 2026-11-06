//! Run an installed ABCI app and its actual native execution node as one foreground operation.
//! Application traffic uses both private Unix sockets with kernel peer credentials checked on
//! each connection. An optional loopback HTTP listener is for external readers only.
use super::{
    helpers::{Guarded, Holds},
    *,
};
use abci::{App, AppOptions, Engine, RpcEngine, Store};
use alloy_provider::{Provider, RootProvider};
use std::{
    fs::File,
    io::Read,
    os::{
        fd::AsRawFd,
        unix::{net::UnixStream, process::CommandExt},
    },
    process::Stdio,
    time::{Duration, Instant},
};

/// Native child and its unguessable, private IPC session. The guardian holds the leases until
/// the real child exits, including when its controller is killed.
pub(super) struct OwnedEngine {
    /// Foreground guardian which owns and reaps the real execution process.
    child: Guarded,
    /// Lifetime of the actual private socket names and temporary Engine JWT.
    _session: tempfile::TempDir,
    /// PID-bound regular IPC. The optional public HTTP listener is never used by the app.
    public: RootProvider,
    /// Normal RPC engine using the same peer identity for regular and authenticated IPC.
    pub(super) engine: RpcEngine,
}

impl OwnedEngine {
    /// Launch one exact native executable with a fixed effective datadir and no inherited
    /// endpoint/config overrides. Obtain its PID on an anonymous channel from its guardian.
    pub(super) async fn start(
        i: &Installation,
        datadir: &Path,
        holds: &Holds,
        http_port: Option<u16>,
        diagnostics: Option<&Path>,
    ) -> R<Self> {
        let temp = std::env::temp_dir().canonicalize().map_err(io)?;
        let session = files::stage(&temp, "etna-ipc-")?;
        let public_socket = session.path().join("public");
        let engine_socket = session.path().join("engine");
        let jwt = session.path().join("jwt");
        let mut secret = [0; 32];
        File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut secret)).map_err(io)?;
        files::write(&jwt, alloy_primitives::hex::encode(secret).as_bytes())?;
        let (mut read, write) = UnixStream::pair().map_err(io)?;
        read.set_read_timeout(Some(Duration::from_secs(10))).map_err(io)?;
        let fd = write.as_raw_fd();
        let mut cmd = holds.command(&i.el_binary)?;
        cmd.env("ETNA_CHILD_ANNOUNCE_FD", fd.to_string())
            .env("HOME", session.path())
            .arg("node")
            .arg("--chain")
            .arg(&i.el_chain)
            .arg("--datadir")
            .arg(datadir)
            // Match the offline helper geometry when reopening an imported MDBX environment.
            .args(["--db.growth-step", "64MB"])
            .arg("--datadir.static-files")
            .arg(datadir.join("static_files"))
            .arg("--datadir.rocksdb")
            .arg(datadir.join("rocksdb"))
            .arg("--config")
            .arg(session.path().join("reth.toml"))
            .arg("--ipcpath")
            .arg(&public_socket)
            .args(["--ipc.permissions", "0600", "--auth-ipc", "--auth-ipc.path"])
            .arg(&engine_socket)
            .args(["--authrpc.addr", "127.0.0.1", "--authrpc.port", "0", "--authrpc.jwtsecret"])
            .arg(&jwt)
            .args([
                "--addr",
                "127.0.0.1",
                "--port",
                "0",
                "--disable-discovery",
                "--trusted-only",
                "--no-persist-peers",
            ])
            .current_dir(datadir);
        if let Some(port) = http_port {
            cmd.args([
                "--http",
                "--http.addr",
                "127.0.0.1",
                "--http.api",
                "eth,net,debug",
                "--http.port",
            ])
            .arg(port.to_string());
        }
        if let Some(t) = i.devnet_etna_timestamp {
            cmd.arg("--devnet-etna-timestamp").arg(t.to_string());
        }
        if let Some(path) = diagnostics {
            let log = files::create(path)?;
            cmd.stdout(log.try_clone().map_err(io)?).stderr(log);
        } else {
            cmd.stdout(Stdio::inherit()).stderr(Stdio::inherit());
        }
        // SAFETY: only the forked guardian inherits the live announcement FD. Its exec of the
        // actual EL closes this extra descriptor; it is never a persisted PID record.
        unsafe {
            cmd.pre_exec(move || {
                if libc::fcntl(fd, libc::F_SETFD, 0) < 0 {
                    Err(std::io::Error::last_os_error())
                } else {
                    Ok(())
                }
            });
        }
        let child = Guarded(cmd.spawn().map_err(io)?);
        drop(write);
        let mut bytes = [0; 4];
        read.read_exact(&mut bytes).map_err(io)?;
        let pid = u32::from_be_bytes(bytes);
        use std::os::unix::fs::MetadataExt;
        let actual =
            process_executable(i32::try_from(pid).map_err(bad)?)?.metadata().map_err(io)?;
        let selected = files::file(&i.el_binary)?.metadata().map_err(io)?;
        if (actual.dev(), actual.ino()) != (selected.dev(), selected.ino()) {
            return Err(bad("execution process image differs from bound native binary"));
        }
        let uid = unsafe { libc::geteuid() };
        let timeout = Duration::from_secs(12);
        let public = rpc::owned_ipc::connect_owned_ipc(&public_socket, pid, uid, timeout);
        let auth = rpc::owned_ipc::connect_owned_ipc(&engine_socket, pid, uid, timeout);
        let engine = RpcEngine::from_parts(
            public.clone(),
            "owned EL IPC".into(),
            auth,
            "owned Engine IPC".into(),
        );
        let mut result = Self { child, _session: session, public, engine };
        let deadline = Instant::now() + Duration::from_secs(120);
        loop {
            if result.exited()? {
                return Err(bad("owned native execution node exited during startup"))
            }
            if result.engine.check_capabilities().await.is_ok() && result.chain_id().await.is_ok() {
                return Ok(result)
            }
            if Instant::now() >= deadline {
                return Err(ImportError::Unavailable(
                    "owned EL private sockets or required methods unavailable".into(),
                ))
            }
            tokio::time::sleep(Duration::from_millis(150)).await;
        }
    }
    /// Check full EVM identity through the same authenticated kernel peer as future reads.
    pub(super) async fn chain_id(&self) -> R<U256> {
        self.public
            .raw_request("eth_chainId".into(), ())
            .await
            .map_err(|_| bad("owned execution chain ID unavailable"))
    }
    /// Observe only the retained guardian, never a PID read from disk or a listening port.
    pub(super) fn exited(&mut self) -> R<bool> {
        Ok(self.child.0.try_wait().map_err(io)?.is_some())
    }
    /// Close the lifetime pipe and confirm a clean shutdown before publishing a staged store.
    pub(super) async fn stop(&mut self) -> R<()> {
        self.child.0.stdin.take();
        let end = Instant::now() + Duration::from_secs(65);
        loop {
            if let Some(s) = self.child.0.try_wait().map_err(io)? {
                return if s.success() {
                    Ok(())
                } else {
                    Err(bad("owned execution node did not stop cleanly"))
                }
            }
            if Instant::now() > end {
                return Err(bad("owned execution node shutdown timed out"))
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
    }
}
/// Start a completed installation with its real EL. This command has no external execution
/// endpoint parameters and never sends a forkchoice at the imported height on restart.
pub(crate) async fn run(
    profile: &Path,
    root: &Path,
    fee_recipient: alloy_primitives::Address,
    http_port: Option<u16>,
    archive_dir: Option<PathBuf>,
) -> crate::error::Result<()> {
    let intent = Intent::load(root)?;
    let (p, hash) = Profile::load(profile)?;
    if hash != intent.profile_hash {
        return Err(bad("runtime profile differs from checked installation").into())
    }
    let i = p.install.as_ref().ok_or_else(|| bad("missing installed runtime profile"))?;
    for (name, path) in [("el_binary", &i.el_binary), ("el_chain", &i.el_chain)]
        .into_iter()
        .chain(p.chain_config.as_ref().map(|c| ("chain_config", c)))
    {
        if intent.inputs.get(name) != Some(&files::local_digest(path, None).await?) {
            return Err(bad("runtime executable or chainspec changed since prepare").into())
        }
    }
    let ready = root.join("ready");
    let app_dir = ready.join("app");
    let (id, floor) =
        boundary::check(&app_dir)?.ok_or_else(|| bad("completed imported app required"))?;
    let holds = Holds::installed(root, &ready, id)?;
    boundary::check_pair(&app_dir, &ready.join("comet")).await?;
    let source = files::read(&ready.join("comet/config/config.toml"), 1 << 20)?;
    let config: toml::Table = std::str::from_utf8(&source)
        .ok()
        .and_then(|t| t.parse().ok())
        .ok_or_else(|| bad("invalid installed Comet runtime"))?;
    let addr = config
        .get("proxy_app")
        .and_then(|v| v.as_str())
        .ok_or_else(|| bad("missing installed ABCI address"))?;
    let (mut params, l1) = p.own().await?;
    params.fee_recipient = fee_recipient;
    let mut owned = OwnedEngine::start(i, &ready.join("el"), &holds, http_port, None).await?;
    if owned.chain_id().await? != U256::from(params.l2_chain_id) {
        return Err(bad("owned execution chain identity differs").into())
    }
    boundary::check_engine(&app_dir, &owned.engine, &params, &l1).await?;
    let state = Store::imported(app_dir.clone(), id, floor)
        .load()
        .map_err(bad)?
        .ok_or_else(|| bad("imported runtime has no committed state"))?;
    let plan: Plan = files::json(&root.join("plan.json"))?;
    for hash in [plan.el_hash, state.parent.hash] {
        if !owned
            .engine
            .historical_state_available(hash)
            .await
            .map_err(|_| ImportError::Unavailable("owned EL retained state read failed".into()))?
        {
            return Err(
                ImportError::Unavailable("owned EL has no retained execution state".into()).into()
            )
        }
    }
    let sock = app_dir.join(".owner.sock");
    if files::exists(&sock)? {
        use std::os::unix::fs::FileTypeExt;
        if !sock.symlink_metadata().map_err(io)?.file_type().is_socket() ||
            tokio::net::UnixStream::connect(&sock).await.is_ok()
        {
            return Err(bad("occupied import owner socket").into())
        }
        fs::remove_file(&sock).map_err(io)?;
    }
    let listener = tokio::net::UnixListener::bind(&sock).map_err(io)?;
    let app = App::new(
        l1,
        owned.engine.clone(),
        params,
        Store::imported(app_dir, id, floor).with_val_archive(archive_dir),
        AppOptions::default(),
    )?;
    tokio::select! {
        result=abci::serve(app,addr)=>result?,
        result=live_guard(listener,owned.engine.clone(),id,plan.el_hash)=>result?,
        failure=async{loop{if owned.exited()?{return Err::<(),ImportError>(ImportError::Unavailable("owned execution process exited".into()))}tokio::time::sleep(Duration::from_millis(100)).await;}}=>failure?
    }
    owned.stop().await?;
    Ok(())
}

/// Private live guard for stock startup. The selected socket is created only after both real EL
/// transports and retained state passed checks. Its peer must be the very same native client.
pub(crate) async fn check_live(app: &Path) -> R<()> {
    use std::os::unix::fs::MetadataExt;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let (id, _) = boundary::check(app)?.ok_or_else(|| bad("expected imported runtime"))?;
    let check = async {
        let mut socket =
            tokio::net::UnixStream::connect(app.join(".owner.sock")).await.map_err(io)?;
        let cred = socket.peer_cred().map_err(io)?;
        let pid = cred.pid().ok_or_else(|| bad("missing app owner peer credentials"))?;
        let path = process_executable(pid)?;
        let peer = path.metadata().map_err(io)?;
        let current = std::env::current_exe().map_err(io)?.metadata().map_err(io)?;
        if cred.uid() != unsafe { libc::geteuid() } ||
            (peer.dev(), peer.ino()) != (current.dev(), current.ino())
        {
            return Err(bad("unexpected app owner executable"))
        }
        let mut challenge = [0u8; 32];
        File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut challenge)).map_err(io)?;
        socket.write_all(&challenge).await.map_err(io)?;
        let mut response = [0; 32];
        socket.read_exact(&mut response).await.map_err(io)?;
        if response != keccak256([challenge.as_slice(), id.as_slice()].concat()).0 {
            return Err(bad("live import session mismatch"))
        }
        Ok(())
    };
    tokio::time::timeout(Duration::from_secs(20), check)
        .await
        .map_err(|_| ImportError::Unavailable("live import owner did not respond".into()))?
}

/// Kernel identity of a connected process, never used to signal or adopt it.
#[cfg(target_os = "linux")]
fn process_executable(pid: i32) -> R<PathBuf> {
    Ok(PathBuf::from(format!("/proc/{pid}/exe")))
}
/// Darwin peer identity used with LOCAL_PEEREPID to verify the loaded native client.
#[cfg(target_os = "macos")]
fn process_executable(pid: i32) -> R<PathBuf> {
    use std::os::unix::ffi::OsStrExt;
    let mut buffer = vec![0u8; 4096];
    let n = unsafe { libc::proc_pidpath(pid, buffer.as_mut_ptr().cast(), buffer.len() as u32) };
    if n <= 0 {
        return Err(io(std::io::Error::last_os_error()))
    }
    let bytes = buffer.split(|b| *b == 0).next().ok_or_else(|| bad("missing native app path"))?;
    Ok(PathBuf::from(std::ffi::OsStr::from_bytes(bytes)))
}
/// Serve fresh stock-launch challenges without granting signing readiness. Both EL sockets
/// must still reach the owned process and the installed floor must remain usable.
async fn live_guard(
    listener: tokio::net::UnixListener,
    engine: RpcEngine,
    id: B256,
    hash: B256,
) -> R<()> {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    loop {
        let (mut socket, _) = listener.accept().await.map_err(io)?;
        let probe = async {
            let mut challenge = [0u8; 32];
            socket.read_exact(&mut challenge).await.map_err(io)?;
            engine.check_capabilities().await.map_err(bad)?;
            if !engine.historical_state_available(hash).await.map_err(bad)? {
                return Err(bad("retained execution state unavailable"))
            }
            socket
                .write_all(keccak256([challenge.as_slice(), id.as_slice()].concat()).as_slice())
                .await
                .map_err(io)
        };
        let _ = tokio::time::timeout(Duration::from_secs(12), probe).await;
    }
}
