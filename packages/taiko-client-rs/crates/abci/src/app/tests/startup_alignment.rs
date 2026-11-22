//! The committed boundary is established before the ABCI socket opens (CONS-3.1-9): a lagging
//! EL is re-executed from the app's retained inputs before stock CometBFT can connect, missing
//! material is reported and retried without serving, and a contradiction stops startup.

use std::time::Duration;

use prost::Message;
use tendermint_proto::v0_38::abci as pb;
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpStream,
};

use super::{proposal::step, *};
use crate::{
    app::trust::TrustPhase,
    server::{ServerError, serve_with},
    store::AppState,
};

/// How long a test waits for the server to open or answer.
const WAIT: Duration = Duration::from_secs(30);

/// A localhost port that was free a moment ago.
fn free_port() -> u16 {
    std::net::TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap().port()
}

/// Commits three blocks in `dir`, then reopens the app over the same store on an EL that lost
/// every block above `keep` (whose state it retains) and has no peers. Returns the reopened app
/// and its committed state.
async fn lagging_el(
    fx: &Fixture,
    dir: &Path,
    keep: impl FnOnce(&AppState) -> u64,
    opts: AppOptions,
) -> (App<MockL1, MockEngine>, AppState) {
    let mut app = initialized(fx, dir).await;
    for _ in 0..3 {
        step(&mut app).await;
    }
    let committed = app.state().unwrap().clone();
    let keep = keep(&committed);
    let engine = app.engine().reopen();
    {
        let mut state = engine.state();
        state.chain.retain(|number, _| *number <= keep);
        state.known.retain(|_, header| header.number <= keep);
        let ancestor = state.chain[&keep].hash_slow();
        state.historical_state.insert(ancestor);
        state.require_payload_parent = true;
        assert!(state.backfill.is_empty(), "no peer-provided blocks");
    }
    drop(app);
    (app_with(fx.l1(), engine, fx.params.clone(), dir, opts), committed)
}

/// Connects to `port` once; `None` while nothing listens.
async fn try_connect(port: u16) -> Option<TcpStream> {
    TcpStream::connect(("127.0.0.1", port)).await.ok()
}

/// The handshake's `Info`, as CometBFT v0.40 sends it, over `stream`.
async fn handshake_info(stream: &mut TcpStream) -> pb::ResponseInfo {
    let request = pb::Request {
        value: Some(pb::request::Value::Info(pb::RequestInfo {
            version: "0.40.0".into(),
            block_version: 11,
            p2p_version: 9,
            abci_version: "2.2.0".into(),
        })),
    };
    stream.write_all(&request.encode_length_delimited_to_vec()).await.unwrap();
    let mut buf = Vec::new();
    loop {
        if let Ok(response) = pb::Response::decode_length_delimited(buf.as_slice()) {
            match response.value {
                Some(pb::response::Value::Info(info)) => return info,
                other => panic!("Info answered {other:?}"),
            }
        }
        let mut chunk = [0u8; 4096];
        let n = tokio::time::timeout(WAIT, stream.read(&mut chunk)).await.unwrap().unwrap();
        assert_ne!(n, 0, "the server closed the connection");
        buf.extend_from_slice(&chunk[..n]);
    }
}

/// Vector 9.n: the EL lost the last two committed blocks and the app retains their bodies. The
/// server re-executes them, with signing closed, before it binds the ABCI socket, so the first
/// connection CometBFT can make already finds an EL serving the committed head, and the
/// handshake `Info` reports it.
#[tokio::test]
async fn startup_re_executes_a_lagging_el_before_the_abci_socket_opens() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (app, committed) =
        lagging_el(&fx, dir.path(), |s| s.last_height - 2, crate::test_utils::test_options()).await;
    // Slow every EL call, so that the re-execution clearly spans the time a socket bound too
    // early would accept a connection.
    app.engine().state().delay = Some(Duration::from_millis(200));
    let engine = Arc::clone(&app.engine);
    let trust = app.trust_handle();
    let port = free_port();
    let addr = format!("tcp://127.0.0.1:{port}");
    let server = tokio::spawn(async move { serve_with(app, &addr, |_: &str| {}).await });

    let deadline = tokio::time::Instant::now() + WAIT;
    let (mut stream, refused) = {
        let mut refused = 0;
        loop {
            if let Some(stream) = try_connect(port).await {
                break (stream, refused);
            }
            assert!(!server.is_finished(), "server stopped early: {:?}", server.await);
            assert_ne!(trust.snapshot().phase, TrustPhase::Ready, "signing stays closed");
            assert!(tokio::time::Instant::now() < deadline, "the ABCI socket never opened");
            refused += 1;
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
    };
    assert!(refused > 0, "the socket must stay closed while the EL is re-executed");
    // At the first accepted connection the EL already serves the committed head, re-executed
    // from the retained bodies of the two lost blocks, with no peer sync.
    {
        let state = engine.state();
        assert_eq!(state.chain[&committed.last_height].hash_slow(), committed.parent.hash);
        let replayed: Vec<_> = state
            .calls
            .iter()
            .filter(|call| matches!(call, EngineCall::NewPayload(_)))
            .cloned()
            .collect();
        assert_eq!(replayed.len(), 2, "{:?}", state.calls);
    }
    let info = handshake_info(&mut stream).await;
    assert_eq!(u64::try_from(info.last_block_height).unwrap(), committed.last_height);
    assert_eq!(info.last_block_app_hash.as_ref(), crate::app::app_hash(&committed).as_bytes());
    assert!(!dir.path().join("fatal-evidence.txt").exists());
    server.abort();
}

/// Vector 9.u: re-executing needs a retained body the app lost, and the EL has no peers. The
/// server reports the missing height as the closed trust session's reason, keeps the ABCI
/// socket closed and retries outside any handshake; once the body is back it aligns and serves.
#[tokio::test]
async fn startup_reports_the_missing_height_and_retries_without_serving() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let opts = AppOptions {
        elsync_timeout: Duration::from_millis(500),
        ..crate::test_utils::test_options()
    };
    let (app, committed) = lagging_el(&fx, dir.path(), |s| s.last_height - 2, opts).await;
    let missing = committed.last_height - 1;
    let saved = app.store.execution_blocks().remove(missing).expect("the body is retained");
    let store = app.store.clone();
    let trust = app.trust_handle();
    let port = free_port();
    let addr = format!("tcp://127.0.0.1:{port}");
    let server = tokio::spawn(async move { serve_with(app, &addr, |_: &str| {}).await });

    let reported = format!("re-execute height {missing} is unavailable");
    let deadline = tokio::time::Instant::now() + WAIT;
    while !trust.snapshot().reason.is_some_and(|reason| reason.contains(&reported)) {
        assert!(tokio::time::Instant::now() < deadline, "{:?}", trust.snapshot());
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    // Several retries later the socket is still closed, signing closed, and nothing is fatal.
    tokio::time::sleep(Duration::from_secs(2)).await;
    assert!(try_connect(port).await.is_none(), "an unaligned app must not serve the handshake");
    assert!(!server.is_finished());
    let snapshot = trust.snapshot();
    assert_eq!(snapshot.phase, TrustPhase::Acquiring);
    assert!(snapshot.reason.unwrap().contains(&reported));
    assert!(!dir.path().join("fatal-evidence.txt").exists());

    // The material is acquired: the next retry aligns and the socket opens.
    store.execution_blocks().append(missing, &saved).unwrap();
    let deadline = tokio::time::Instant::now() + WAIT;
    let mut stream = loop {
        if let Some(stream) = try_connect(port).await {
            break stream;
        }
        assert!(!server.is_finished(), "server stopped: {:?}", server.await);
        assert!(tokio::time::Instant::now() < deadline, "the ABCI socket never opened");
        tokio::time::sleep(Duration::from_millis(50)).await;
    };
    let info = handshake_info(&mut stream).await;
    assert_eq!(u64::try_from(info.last_block_height).unwrap(), committed.last_height);
    assert_eq!(info.last_block_app_hash.as_ref(), crate::app::app_hash(&committed).as_bytes());
    server.abort();
}

/// An EL serving another block at the committed height contradicts the committed chain: startup
/// stops with a safety halt for investigation, recorded as fatal evidence, and the ABCI socket
/// never opens.
#[tokio::test]
async fn startup_stops_on_a_contradicting_el() {
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let (app, committed) =
        lagging_el(&fx, dir.path(), |s| s.last_height, crate::test_utils::test_options()).await;
    {
        let mut engine = app.engine().state();
        let mut other = engine.chain[&committed.last_height].clone();
        other.timestamp += 1;
        engine.known.insert(other.hash_slow(), other.clone());
        engine.chain.insert(committed.last_height, other);
    }
    let trust = app.trust_handle();
    let port = free_port();
    let addr = format!("tcp://127.0.0.1:{port}");
    let (tx, mut halts) = tokio::sync::mpsc::unbounded_channel();
    let hook = move |reason: &str| tx.send(reason.to_string()).unwrap();
    let result = tokio::time::timeout(WAIT, serve_with(app, &addr, hook)).await.unwrap();
    let Err(ServerError::Alignment(message)) = result else {
        panic!("startup went on: {result:?}");
    };
    assert!(message.contains("safety halt"), "{message}");
    assert_eq!(halts.try_recv().unwrap(), message, "the halt hook runs once");
    assert!(halts.try_recv().is_err());
    assert!(try_connect(port).await.is_none(), "the ABCI socket never opened");
    assert_eq!(trust.snapshot().phase, TrustPhase::Halted);
    let evidence = std::fs::read_to_string(dir.path().join("fatal-evidence.txt")).unwrap();
    assert!(evidence.contains(&committed.last_height.to_string()), "{evidence}");
}
