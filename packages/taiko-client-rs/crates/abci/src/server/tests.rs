//! Server tests: raw CometBFT socket-protocol clients against [`serve_with`], and the
//! sequential worker behind [`AppService`].

use std::{
    path::Path,
    sync::{Arc, Mutex},
    time::Duration,
};

use prost::Message;
use tendermint::v0_38::abci::{request, response};
use tendermint_proto::v0_38::abci as pb;
use tokio::{
    io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt},
    net::TcpStream,
    sync::mpsc::UnboundedReceiver,
};
use tower::ServiceExt;

use super::*;
use crate::{
    app::APP_NAME,
    test_utils::{Fixture, MockEngine, MockL1, in_own_process},
};

/// How long a test waits for the server or the worker.
const WAIT: Duration = Duration::from_secs(10);

/// A localhost port that was free a moment ago.
fn free_port() -> u16 {
    std::net::TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap().port()
}

/// A halt hook that reports every halt reason on the returned channel.
fn recording_hook() -> (impl HaltHook, UnboundedReceiver<String>) {
    let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
    (move |reason: &str| tx.send(reason.to_string()).unwrap(), rx)
}

/// Serves `handler` on a free localhost port with `halt`; returns the server task and a
/// connected client.
async fn start<H: AbciHandler, K: HaltHook>(
    handler: H,
    halt: K,
) -> (JoinHandle<Result<(), ServerError>>, TcpStream) {
    let port = free_port();
    let addr = format!("tcp://127.0.0.1:{port}");
    let server = tokio::spawn(async move { serve_with(handler, &addr, halt).await });
    let deadline = tokio::time::Instant::now() + WAIT;
    loop {
        match TcpStream::connect(("127.0.0.1", port)).await {
            Ok(stream) => return (server, stream),
            Err(e) if tokio::time::Instant::now() < deadline => {
                assert!(!server.is_finished(), "server stopped early: {e}");
                tokio::time::sleep(Duration::from_millis(20)).await;
            }
            Err(e) => panic!("cannot connect to the ABCI server: {e}"),
        }
    }
}

/// An uninitialized fixture app over a store in `dir`.
fn fixture_app(dir: &Path) -> App<MockL1, MockEngine> {
    Fixture::genesis(1).app(dir)
}

/// `Echo(message)` on the wire.
fn pb_echo(message: &str) -> pb::Request {
    pb::Request {
        value: Some(pb::request::Value::Echo(pb::RequestEcho { message: message.into() })),
    }
}

/// `Info` on the wire, as CometBFT v0.40 sends it.
fn pb_info() -> pb::Request {
    pb::Request {
        value: Some(pb::request::Value::Info(pb::RequestInfo {
            version: "0.40.0".into(),
            block_version: 11,
            p2p_version: 9,
            abci_version: "2.2.0".into(),
        })),
    }
}

/// `Flush` on the wire.
fn pb_flush() -> pb::Request {
    pb::Request { value: Some(pb::request::Value::Flush(pb::RequestFlush {})) }
}

/// Writes `requests` varint-length-prefixed, in one write.
async fn send(stream: &mut (impl AsyncWrite + Unpin), requests: &[pb::Request]) {
    let mut bytes = Vec::new();
    for req in requests {
        bytes.extend(req.encode_length_delimited_to_vec());
    }
    stream.write_all(&bytes).await.unwrap();
}

/// Reads one varint-length-prefixed response, buffering surplus bytes in `buf`; `None` when
/// the server closed the connection.
async fn recv(stream: &mut (impl AsyncRead + Unpin), buf: &mut Vec<u8>) -> Option<pb::Response> {
    loop {
        let mut cursor = &buf[..];
        if let Ok(len) = prost::encoding::decode_varint(&mut cursor) {
            let head = buf.len() - cursor.len();
            let len = usize::try_from(len).unwrap();
            if cursor.len() >= len {
                let resp = pb::Response::decode(&cursor[..len]).unwrap();
                buf.drain(..head + len);
                return Some(resp);
            }
        }
        let mut chunk = [0u8; 4096];
        let n = tokio::time::timeout(WAIT, stream.read(&mut chunk))
            .await
            .expect("the server answers in time")
            .unwrap_or(0);
        if n == 0 {
            return None;
        }
        buf.extend_from_slice(&chunk[..n]);
    }
}

/// Reads one response and returns its value.
async fn recv_value(
    stream: &mut (impl AsyncRead + Unpin),
    buf: &mut Vec<u8>,
) -> pb::response::Value {
    recv(stream, buf).await.expect("a response").value.expect("a response value")
}

#[test]
fn listen_addr_parses_tcp_and_unix() {
    assert_eq!(
        ListenAddr::parse("tcp://127.0.0.1:26658").unwrap(),
        ListenAddr::Tcp("127.0.0.1:26658".into())
    );
    assert_eq!(
        ListenAddr::parse("tcp://abci.local:1").unwrap(),
        ListenAddr::Tcp("abci.local:1".into())
    );
    assert_eq!(
        ListenAddr::parse("unix:///run/abci.sock").unwrap(),
        ListenAddr::Unix("/run/abci.sock".into())
    );
    assert_eq!(ListenAddr::parse(DEFAULT_ADDR).unwrap(), ListenAddr::Tcp("127.0.0.1:26658".into()));
    for bad in [
        "",
        "127.0.0.1:26658",
        "http://127.0.0.1:26658",
        "tcp://",
        "tcp://127.0.0.1",
        "tcp://:26658",
        "tcp://127.0.0.1:port",
        "tcp://127.0.0.1:70000",
        "unix://",
    ] {
        assert!(
            matches!(ListenAddr::parse(bad), Err(ServerError::InvalidAddr(a)) if a == bad),
            "{bad:?}"
        );
    }
}

#[tokio::test]
async fn invalid_address_fails_before_serving() {
    let dir = tempfile::tempdir().unwrap();
    let (hook, _halts) = recording_hook();
    let err = serve_with(fixture_app(dir.path()), "localhost:26658", hook).await.unwrap_err();
    assert!(matches!(err, ServerError::InvalidAddr(_)), "{err:?}");
}

#[tokio::test]
async fn answers_echo_and_info_over_tcp() {
    let dir = tempfile::tempdir().unwrap();
    let (hook, mut halts) = recording_hook();
    let (server, mut stream) = start(fixture_app(dir.path()), hook).await;
    let mut buf = Vec::new();

    send(&mut stream, &[pb_echo("ping")]).await;
    match recv_value(&mut stream, &mut buf).await {
        pb::response::Value::Echo(echo) => assert_eq!(echo.message, "ping"),
        other => panic!("Echo answered {other:?}"),
    }

    send(&mut stream, &[pb_info()]).await;
    match recv_value(&mut stream, &mut buf).await {
        pb::response::Value::Info(info) => {
            assert_eq!(info.data, APP_NAME);
            assert_eq!(info.last_block_height, 0, "an uninitialized app reports height 0");
            assert!(info.last_block_app_hash.is_empty());
        }
        other => panic!("Info answered {other:?}"),
    }
    assert!(!server.is_finished());
    assert!(halts.try_recv().is_err(), "no halt");
}

/// Connects to the unix socket at `path`, retrying until the server listens.
#[cfg(unix)]
async fn connect_unix(
    path: &Path,
    server: &JoinHandle<Result<(), ServerError>>,
) -> tokio::net::UnixStream {
    let deadline = tokio::time::Instant::now() + WAIT;
    loop {
        match tokio::net::UnixStream::connect(path).await {
            Ok(stream) => return stream,
            Err(e) if tokio::time::Instant::now() < deadline => {
                assert!(!server.is_finished(), "server stopped early: {e}");
                tokio::time::sleep(Duration::from_millis(20)).await;
            }
            Err(e) => panic!("cannot connect to the ABCI socket: {e}"),
        }
    }
}

/// A process that exits (e.g. after a safety halt) leaves its socket file behind; the next
/// start replaces that stale socket instead of failing to bind with `AddrInUse`.
#[cfg(unix)]
#[tokio::test]
async fn serves_over_unix_replacing_a_stale_socket() {
    let dir = tempfile::tempdir().unwrap();
    let sock = dir.path().join("abci.sock");
    drop(std::os::unix::net::UnixListener::bind(&sock).unwrap());
    assert!(sock.exists(), "dropping a listener leaves the socket file behind");

    let (hook, _halts) = recording_hook();
    let app = fixture_app(dir.path());
    let addr = format!("unix://{}", sock.display());
    let server = tokio::spawn(async move { serve_with(app, &addr, hook).await });
    let mut stream = connect_unix(&sock, &server).await;
    let mut buf = Vec::new();
    send(&mut stream, &[pb_echo("over uds")]).await;
    match recv_value(&mut stream, &mut buf).await {
        pb::response::Value::Echo(echo) => assert_eq!(echo.message, "over uds"),
        other => panic!("Echo answered {other:?}"),
    }
    assert!(!server.is_finished());
    server.abort();
}

/// Only a stale socket is removed: a regular file at the path, or a socket another process
/// still listens on, is left alone and the server refuses to start.
#[cfg(unix)]
#[tokio::test]
async fn refuses_a_unix_path_that_is_no_stale_socket() {
    let dir = tempfile::tempdir().unwrap();
    let file = dir.path().join("abci.sock");
    std::fs::write(&file, b"not a socket").unwrap();
    let (hook, _halts) = recording_hook();
    let addr = format!("unix://{}", file.display());
    let err = serve_with(fixture_app(dir.path()), &addr, hook).await.unwrap_err();
    assert!(matches!(&err, ServerError::SocketPath { path, .. } if *path == file), "{err:?}");
    assert!(err.to_string().contains("not a socket"), "{err}");
    assert_eq!(std::fs::read(&file).unwrap(), b"not a socket", "the file is kept");

    let live = dir.path().join("live.sock");
    let listener = std::os::unix::net::UnixListener::bind(&live).unwrap();
    let (hook, _halts) = recording_hook();
    let addr = format!("unix://{}", live.display());
    let err = serve_with(fixture_app(dir.path()), &addr, hook).await.unwrap_err();
    assert!(matches!(&err, ServerError::SocketPath { path, .. } if *path == live), "{err:?}");
    assert!(err.to_string().contains("listens"), "{err}");
    std::os::unix::net::UnixStream::connect(&live).expect("the live socket still accepts");
    drop(listener);
}

/// Only a refused connection proves a socket stale: a socket the server cannot even probe (here
/// one without write permission, `EACCES`) may still belong to a live process, so it is left in
/// place and the server refuses to start.
#[cfg(unix)]
#[tokio::test]
async fn refuses_a_socket_it_cannot_probe() {
    use std::os::unix::fs::PermissionsExt;

    let dir = tempfile::tempdir().unwrap();
    let sock = dir.path().join("abci.sock");
    drop(std::os::unix::net::UnixListener::bind(&sock).unwrap());
    std::fs::set_permissions(&sock, std::fs::Permissions::from_mode(0o000)).unwrap();
    match std::os::unix::net::UnixStream::connect(&sock) {
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {}
        other => {
            eprintln!("skipped: a mode-000 socket answered {other:?} (privileged user?)");
            return;
        }
    }

    let (hook, _halts) = recording_hook();
    let addr = format!("unix://{}", sock.display());
    let err = tokio::time::timeout(WAIT, serve_with(fixture_app(dir.path()), &addr, hook))
        .await
        .expect("refuses at once instead of serving")
        .unwrap_err();
    assert!(matches!(&err, ServerError::SocketPath { path, .. } if *path == sock), "{err:?}");
    assert!(err.to_string().contains("ermission denied"), "{err}");
    assert!(std::fs::symlink_metadata(&sock).is_ok(), "the socket file is kept");
}

#[tokio::test]
async fn back_to_back_requests_are_answered_in_order() {
    let dir = tempfile::tempdir().unwrap();
    let (hook, _halts) = recording_hook();
    let (_server, mut stream) = start(fixture_app(dir.path()), hook).await;
    let mut buf = Vec::new();

    send(&mut stream, &[pb_echo("first"), pb_info(), pb_echo("second"), pb_flush()]).await;
    match recv_value(&mut stream, &mut buf).await {
        pb::response::Value::Echo(echo) => assert_eq!(echo.message, "first"),
        other => panic!("first answer {other:?}"),
    }
    assert!(matches!(recv_value(&mut stream, &mut buf).await, pb::response::Value::Info(_)));
    match recv_value(&mut stream, &mut buf).await {
        pb::response::Value::Echo(echo) => assert_eq!(echo.message, "second"),
        other => panic!("third answer {other:?}"),
    }
    assert!(matches!(recv_value(&mut stream, &mut buf).await, pb::response::Value::Flush(_)));
}

/// Echoes, sleeping first on `slow`, and logs when each request starts and ends.
struct Recorder {
    /// `start <message>` / `end <message>` entries.
    log: Arc<Mutex<Vec<String>>>,
}

impl AbciHandler for Recorder {
    fn handle_request(
        &mut self,
        req: Request,
    ) -> impl Future<Output = Result<Response, AbciError>> + Send {
        let log = self.log.clone();
        async move {
            let Request::Echo(echo) = req else { panic!("unexpected {req:?}") };
            log.lock().unwrap().push(format!("start {}", echo.message));
            if echo.message == "slow" {
                tokio::time::sleep(Duration::from_millis(50)).await;
            }
            log.lock().unwrap().push(format!("end {}", echo.message));
            Ok(Response::Echo(response::Echo { message: echo.message }))
        }
    }
}

/// `Echo(message)`.
fn echo(message: &str) -> Request {
    Request::Echo(request::Echo { message: message.into() })
}

#[tokio::test]
async fn requests_run_one_at_a_time_in_call_order() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let (hook, _halts) = recording_hook();
    let (mut service, _worker) = AppService::spawn(Recorder { log: log.clone() }, hook);

    let slow = service.ready().await.unwrap().call(echo("slow"));
    let fast = service.ready().await.unwrap().call(echo("fast"));
    // Await the later call first: it still runs only after the earlier one finished.
    assert_eq!(fast.await.unwrap(), Response::Echo(response::Echo { message: "fast".into() }));
    assert_eq!(slow.await.unwrap(), Response::Echo(response::Echo { message: "slow".into() }));
    assert_eq!(*log.lock().unwrap(), ["start slow", "end slow", "start fast", "end fast"]);
}

#[tokio::test]
async fn other_errors_are_answered_and_the_worker_keeps_serving() {
    let dir = tempfile::tempdir().unwrap();
    let (hook, mut halts) = recording_hook();
    let (mut service, worker) = AppService::spawn(fixture_app(dir.path()), hook);

    let err = service.ready().await.unwrap().call(Request::Commit).await.unwrap_err();
    assert_eq!(err.to_string(), AbciError::NothingToCommit.to_string());
    let resp = service.ready().await.unwrap().call(echo("still here")).await.unwrap();
    assert_eq!(resp, Response::Echo(response::Echo { message: "still here".into() }));
    assert!(halts.try_recv().is_err(), "an ordinary error is no safety halt");
    assert!(!worker.is_finished());
}

#[tokio::test]
async fn safety_halt_answers_runs_the_halt_hook_and_stops_the_worker() {
    // An initialized app whose EL serves another block at the committed height: `Info`
    // reconciles the EL and halts.
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = fx.app(dir.path());
    app.handle(Request::InitChain(fx.request.clone())).await.expect("InitChain succeeds");
    drop(app);
    let mut other = fx.el_chain.clone();
    other[1].gas_used += 1;
    let app = App::new(
        fx.l1(),
        MockEngine::with_chain(other),
        fx.params.clone(),
        crate::store::Store::new(dir.path().to_path_buf()),
        crate::app::AppOptions::default(),
    )
    .unwrap();

    let (hook, mut halts) = recording_hook();
    let (server, mut stream) = start(app, hook).await;
    let mut buf = Vec::new();
    send(&mut stream, &[pb_info()]).await;

    assert_eq!(recv(&mut stream, &mut buf).await, None, "the failed connection closes");
    let reason = tokio::time::timeout(WAIT, halts.recv()).await.unwrap().expect("halt hook ran");
    assert!(reason.starts_with("safety halt in Info: "), "{reason}");
    assert!(reason.contains("execution engine serves"), "{reason}");
    match tokio::time::timeout(WAIT, server).await.unwrap().unwrap() {
        Err(ServerError::WorkerStopped(stopped)) => assert_eq!(stopped, reason),
        other => panic!("serve returned {other:?}"),
    }
}

#[tokio::test]
async fn a_stopped_worker_fails_further_calls() {
    if !in_own_process(module_path!(), "a_stopped_worker_fails_further_calls") {
        return;
    }
    let (hook, _halts) = recording_hook();
    let (mut service, worker) = AppService::spawn(Halting, hook);
    let err = service.ready().await.unwrap().call(echo("boom")).await.unwrap_err();
    assert!(err.to_string().contains("boom"), "{err}");
    assert_eq!(tokio::time::timeout(WAIT, worker).await.unwrap().unwrap(), err.to_string());
    assert_eq!(AbciMetrics::halted().get(), 1, "a safety halt raises the halted gauge");
    assert!(service.ready().await.is_err(), "a stopped worker is never ready again");
    let err = service.call(echo("late")).await.unwrap_err();
    assert_eq!(err.to_string(), WorkerGone.to_string());
}

/// Safety-halts on every request, with the echoed message as the reason.
struct Halting;

impl AbciHandler for Halting {
    async fn handle_request(&mut self, req: Request) -> Result<Response, AbciError> {
        let Request::Echo(echo) = req else { panic!("unexpected {req:?}") };
        Err(AbciError::SafetyHalt(echo.message))
    }
}
