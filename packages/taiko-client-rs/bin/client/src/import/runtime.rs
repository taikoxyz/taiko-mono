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
            match check_owned_capabilities(&result.engine).await {
                Ok(()) if result.chain_id().await.is_ok() => return Ok(result),
                Err(e @ ImportError::Safety(_)) => return Err(e),
                _ => {}
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
/// A missing method/transport prevents startup. A malformed reply from the authenticated
/// native Engine is a local integrity failure during both startup and subsequent launches.
async fn check_owned_capabilities(engine: &impl Engine) -> R<()> {
    engine.check_capabilities().await.map_err(|e| {
        if e.is_integrity_failure() {
            ImportError::Safety(format!("malformed own Engine capability reply: {e}"))
        } else {
            ImportError::Unavailable(format!("owned Engine capabilities unavailable: {e}"))
        }
    })
}

/// Classify reads of the owned EL's header indexes or corresponding retained state.
/// BlockHashMismatch is terminal in this context, independently of peer-payload handling.
pub(super) fn own_header<T>(
    result: Result<Option<T>, abci::EngineError>,
    what: impl std::fmt::Display,
) -> R<T> {
    match result {
        Ok(Some(value)) => Ok(value),
        Ok(None) => Err(ImportError::Unavailable(format!("owned EL has no {what}"))),
        Err(e)
            if e.is_integrity_failure() ||
                matches!(e, abci::EngineError::BlockHashMismatch { .. }) =>
        {
            Err(ImportError::Safety(format!("inconsistent own EL {what}: {e}")))
        }
        Err(e) => Err(ImportError::Unavailable(format!("owned EL {what}: {e}"))),
    }
}

/// Hash-addressed admission requires both the matching header and an actual state read.
pub(super) async fn retained_state(engine: &impl Engine, hash: B256) -> R<()> {
    let available =
        engine.historical_state_available(hash).await.map(|present| present.then_some(()));
    own_header(available, format_args!("retained state at {hash}"))
}

/// Stop admission on the first unavailable state or durable own-EL contradiction. The
/// independently verified floor and the latest committed parent may be different after sync.
async fn admit_retained(root: &Path, engine: &impl Engine, hashes: [B256; 2]) -> R<()> {
    for hash in hashes {
        latch(root, retained_state(engine, hash).await)?;
    }
    Ok(())
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
    let mut owned =
        latch(root, OwnedEngine::start(i, &ready.join("el"), &holds, http_port, None).await)?;
    if owned.chain_id().await? != U256::from(params.l2_chain_id) {
        return Err(bad("owned execution chain identity differs").into())
    }
    boundary::check_engine(&app_dir, &owned.engine, &params, &l1).await?;
    let state = Store::imported(app_dir.clone(), id, floor)
        .load()
        .map_err(bad)?
        .ok_or_else(|| bad("imported runtime has no committed state"))?;
    let plan: Plan = files::json(&root.join("plan.json"))?;
    admit_retained(root, &owned.engine, [plan.el_hash, state.parent.hash]).await?;
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
    let result = tokio::select! {
        result=abci::serve(app,addr)=>{result?;Ok(())},
        result=live_guard(listener,owned.engine.clone(),id,plan.el_hash)=>result,
        failure=async{loop{if owned.exited()?{return Err::<(),ImportError>(ImportError::Unavailable("owned execution process exited".into()))}tokio::time::sleep(Duration::from_millis(100)).await;}}=>failure
    };
    // Dropping the serving future revokes signer trust and aborts the ABCI/control tasks.
    // Keep the ownership leases until permanent evidence is durable and the EL is reaped.
    latch(root, result)?;
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
            check_owned_capabilities(&engine).await?;
            retained_state(&engine, hash).await?;
            socket
                .write_all(keccak256([challenge.as_slice(), id.as_slice()].concat()).as_slice())
                .await
                .map_err(io)
        };
        if let Ok(Err(error @ ImportError::Safety(_))) =
            tokio::time::timeout(Duration::from_secs(12), probe).await
        {
            return Err(error)
        }
        // A failed caller handshake, deadline or unavailable dependency denies only this launch.
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::transports::mock::Asserter;
    use alloy_provider::ProviderBuilder;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    fn mocked() -> (RpcEngine, Asserter, Asserter) {
        let public = Asserter::new();
        let auth = Asserter::new();
        (
            RpcEngine::from_parts(
                ProviderBuilder::default().connect_mocked_client(public.clone()),
                "public".into(),
                ProviderBuilder::default().connect_mocked_client(auth.clone()),
                "auth".into(),
            ),
            public,
            auth,
        )
    }

    #[tokio::test]
    async fn live_guard_exits_on_inconsistent_by_hash_after_healthy_by_number() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("owner.sock");
        let listener = tokio::net::UnixListener::bind(&path).unwrap();
        let (engine, public, auth) = mocked();
        let header = alloy_consensus::Header { number: 6, ..Default::default() };
        let hash = header.hash_slow();
        public.push_success(&Value::Null);
        public.push_success(&alloy_primitives::Bytes::from(alloy_rlp::encode(&header)));
        assert_eq!(engine.header_by_number(6).await.unwrap(), Some(header.clone()));
        let changed = alloy_consensus::Header { state_root: B256::repeat_byte(5), ..header };
        public.push_success(&Value::Null);
        public.push_success(&alloy_primitives::Bytes::from(alloy_rlp::encode(changed)));
        auth.push_success(&rpc::auth::REQUIRED_ENGINE_METHODS);
        let id = B256::repeat_byte(2);
        let client = async {
            let mut s = tokio::net::UnixStream::connect(&path).await.unwrap();
            s.write_all(&[1; 32]).await.unwrap();
            let mut reply = vec![];
            s.read_to_end(&mut reply).await.unwrap();
            assert!(reply.is_empty());
        };
        let (result, ()) = tokio::join!(
            tokio::time::timeout(Duration::from_secs(2), live_guard(listener, engine, id, hash)),
            client
        );
        assert!(
            matches!(result, Ok(Err(ImportError::Safety(_)))),
            "live guard must terminate: {result:?}"
        );
    }
    fn root_with_intent(dir: &Path) -> PathBuf {
        use std::os::unix::fs::PermissionsExt;
        let root = dir.canonicalize().unwrap();
        fs::set_permissions(&root, fs::Permissions::from_mode(0o700)).unwrap();
        let intent = Intent {
            schema: 1,
            root: root.clone(),
            source: root.join("source"),
            profile_hash: B256::ZERO,
            package: [B256::ZERO; 2],
            inputs: Default::default(),
        };
        files::put(&root.join("intent.json"), &intent).unwrap();
        fs::create_dir_all(root.join("ready/app")).unwrap();
        root
    }

    #[tokio::test]
    async fn startup_checks_floor_and_advanced_parent_and_latches_integrity_failures() {
        let floor = alloy_consensus::Header { number: 6, ..Default::default() };
        let advanced =
            alloy_consensus::Header { number: 7, parent_hash: floor.hash_slow(), ..floor.clone() };
        for problem in ["missing", "transport", "malformed", "mismatch"] {
            let dir = tempfile::tempdir().unwrap();
            let root = root_with_intent(dir.path());
            let (engine, public, _) = mocked();
            public.push_success(&Value::Null);
            public.push_success(&alloy_primitives::Bytes::from(alloy_rlp::encode(&floor)));
            public.push_success(&"0x0");
            public.push_success(&Value::Null);
            match problem {
                "missing" => public.push_success(&Value::Null),
                "transport" => public.push_failure_msg("state source offline"),
                "malformed" => public.push_success(&alloy_primitives::Bytes::from_static(&[0xc0])),
                _ => public.push_success(&alloy_primitives::Bytes::from(alloy_rlp::encode(&floor))),
            }
            let hashes = [floor.hash_slow(), advanced.hash_slow()];
            let r = admit_retained(&root, &engine, hashes).await;
            if matches!(problem, "missing" | "transport") {
                assert!(matches!(r, Err(ImportError::Unavailable(_))), "{problem}: {r:?}");
                check_latch(&root).unwrap();
                // Same bound engine and unchanged durable root may recover when its state does.
                for h in [&floor, &advanced] {
                    public.push_success(&Value::Null);
                    public.push_success(&alloy_primitives::Bytes::from(alloy_rlp::encode(h)));
                    public.push_success(&"0x0");
                }
                admit_retained(&root, &engine, hashes).await.unwrap();
            } else {
                assert!(matches!(r, Err(ImportError::Safety(_))), "{problem}: {r:?}");
                let restart = boundary::check(&root.join("ready/app"));
                assert!(
                    matches!(&restart,Err(ImportError::Safety(detail)) if detail.contains(&advanced.hash_slow().to_string())),
                    "{restart:?}"
                );
            }
        }
    }

    #[tokio::test]
    async fn live_guard_denies_missing_or_transport_then_recovers_and_stops_on_malformed_state() {
        let dir = tempfile::tempdir().unwrap();
        let root = root_with_intent(dir.path());
        let path = root.join("probe.sock");
        let listener = tokio::net::UnixListener::bind(&path).unwrap();
        let (engine, public, auth) = mocked();
        let h = alloy_consensus::Header { number: 6, ..Default::default() };
        for _ in 0..4 {
            auth.push_success(&rpc::auth::REQUIRED_ENGINE_METHODS);
        }
        public.push_success(&Value::Null);
        public.push_success(&Value::Null);
        public.push_failure_msg("transport unavailable");
        public.push_success(&Value::Null);
        public.push_success(&alloy_primitives::Bytes::from(alloy_rlp::encode(&h)));
        public.push_success(&"0x0");
        public.push_success(&Value::Null);
        public.push_success(&alloy_primitives::Bytes::from_static(&[0xc0]));
        let id = B256::repeat_byte(3);
        let client = async {
            for i in 0..4 {
                let mut socket = tokio::net::UnixStream::connect(&path).await.unwrap();
                let challenge = [i; 32];
                socket.write_all(&challenge).await.unwrap();
                let mut response = vec![];
                socket.read_to_end(&mut response).await.unwrap();
                if i == 2 {
                    assert_eq!(
                        response,
                        keccak256([challenge.as_slice(), id.as_slice()].concat()).as_slice()
                    );
                } else {
                    assert!(response.is_empty());
                }
                if i < 3 {
                    check_latch(&root).unwrap();
                }
            }
        };
        let guard = async { latch(&root, live_guard(listener, engine, id, h.hash_slow()).await) };
        let ((), result) =
            tokio::time::timeout(Duration::from_secs(3), async { tokio::join!(client, guard) })
                .await
                .unwrap();
        assert!(matches!(result, Err(ImportError::Safety(_))));
        let restart = boundary::check(&root.join("ready/app"));
        assert!(matches!(restart, Err(ImportError::Safety(_))), "{restart:?}");
    }
    #[tokio::test]
    async fn own_numbered_and_finalized_header_integrity_is_distinct_from_unavailable() {
        use alloy_primitives::Bytes;
        for finalized in [false, true] {
            let (engine, public, _) = mocked();
            let read = || async {
                let result = if finalized {
                    engine.finalized_header().await
                } else {
                    engine.header_by_number(6).await
                };
                own_header(result, "probe header")
            };
            public.push_success(&Value::Null);
            public.push_success(&Value::Null);
            assert!(matches!(read().await, Err(ImportError::Unavailable(_))));
            public.push_failure_msg("EL transport down");
            assert!(matches!(read().await, Err(ImportError::Unavailable(_))));
            public.push_success(&Value::Null);
            public.push_success(&Bytes::from_static(&[0xc0]));
            assert!(matches!(read().await, Err(ImportError::Safety(_))));
            let mut block = serde_json::from_str::<Value>(include_str!(
                "../../../../crates/abci/src/l1/testdata/anvil_get_proof.json"
            ))
            .unwrap()["block"]
                .clone();
            block["hash"] = json!(B256::repeat_byte(0x44));
            public.push_success(&block);
            assert!(matches!(read().await, Err(ImportError::Safety(_))));
        }
    }
}
