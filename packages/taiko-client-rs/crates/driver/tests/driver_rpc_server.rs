//! Driver JSON-RPC server tests.
//!
//! These tests require the standalone RPC feature.
#![cfg(feature = "standalone-rpc")]

use std::{
    error::Error,
    net::SocketAddr,
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_rpc_types_engine::{Claims, JwtSecret};
use async_trait::async_trait;
use driver::{
    error::DriverError,
    jsonrpc::{DriverIpcServer, DriverRpcApi, DriverRpcServer},
};
use http_body_util::{BodyExt, Full};
use hyper::{Request, StatusCode, body::Bytes};
use hyper_util::{client::legacy::Client as HyperClient, rt::TokioExecutor};
use serde_json::{Value, from_slice, json, to_vec};

/// Result type used by driver RPC server tests.
type TestResult<T = ()> = Result<T, Box<dyn Error>>;

/// Minimal RPC API stub for server tests.
#[derive(Default)]
struct StubApi {
    /// Latest canonical proposal id exposed by the stub.
    last: AtomicU64,
}

#[async_trait]
impl DriverRpcApi for StubApi {
    /// Accept any payload without processing.
    async fn submit_execution_payload_v2(
        &self,
        _payload: TaikoPayloadAttributes,
    ) -> Result<(), DriverError> {
        Ok(())
    }

    /// Return the stored canonical proposal id.
    fn last_canonical_proposal_id(&self) -> u64 {
        self.last.load(Ordering::Relaxed)
    }
}

/// Build a JSON-RPC request body for the given method and params.
fn jsonrpc_request(method: &str, params: Value) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params,
    })
}

/// Ensure requests without JWT are rejected.
#[test_log::test(tokio::test)]
async fn rejects_requests_without_jwt() -> TestResult {
    let secret = JwtSecret::random();
    let api = Arc::new(StubApi::default());
    let server = DriverRpcServer::start("127.0.0.1:0".parse::<SocketAddr>()?, secret, api).await?;

    let client: HyperClient<_, Full<Bytes>> =
        HyperClient::builder(TokioExecutor::new()).build_http();

    let body =
        to_vec(&jsonrpc_request("preconf_lastCanonicalProposalId", Value::Array(Vec::new())))?;
    let req = Request::post(server.http_url())
        .header("content-type", "application/json")
        .body(Full::new(Bytes::from(body)))?;
    let resp = client.request(req).await?;
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    Ok(())
}

/// Ensure the server returns the last canonical proposal id.
#[test_log::test(tokio::test)]
async fn last_canonical_proposal_id_is_exposed_over_rpc() -> TestResult {
    let secret = JwtSecret::random();
    let api = Arc::new(StubApi::default());
    api.last.store(42, Ordering::Relaxed);
    let server = DriverRpcServer::start("127.0.0.1:0".parse::<SocketAddr>()?, secret, api).await?;

    let client: HyperClient<_, Full<Bytes>> =
        HyperClient::builder(TokioExecutor::new()).build_http();
    let jwt = secret.encode(&Claims::default())?;
    let body =
        to_vec(&jsonrpc_request("preconf_lastCanonicalProposalId", Value::Array(Vec::new())))?;
    let req = Request::post(server.http_url())
        .header("content-type", "application/json")
        .header("authorization", format!("Bearer {jwt}"))
        .body(Full::new(Bytes::from(body)))?;
    let resp = client.request(req).await?;
    assert_eq!(resp.status(), StatusCode::OK);

    let bytes = resp.into_body().collect().await?.to_bytes();
    let value: Value = from_slice(&bytes)?;
    assert_eq!(value["result"].as_u64(), Some(42));
    Ok(())
}

/// Ensure the IPC server can start and stop successfully.
#[test_log::test(tokio::test)]
async fn ipc_server_starts_and_stops() -> TestResult {
    let ipc_path = PathBuf::from(format!("/tmp/driver-test-{}.ipc", std::process::id()));
    let _ = std::fs::remove_file(&ipc_path);

    let api = Arc::new(StubApi::default());
    api.last.store(99, Ordering::Relaxed);

    let server = DriverIpcServer::start(ipc_path.clone(), api).await?;
    assert_eq!(server.ipc_path(), &ipc_path);

    server.stop().await;
    assert!(!ipc_path.exists(), "IPC socket should be removed on shutdown");
    Ok(())
}

/// Ensure the IPC server auto-creates missing parent directories.
#[test_log::test(tokio::test)]
async fn ipc_server_creates_parent_directory() -> TestResult {
    let base_dir = PathBuf::from(format!("/tmp/driver-test-nested-{}/subdir", std::process::id()));
    let ipc_path = base_dir.join("driver.ipc");

    let _ = std::fs::remove_dir_all(&base_dir);
    assert!(!base_dir.exists(), "Parent directory should not exist before test");

    let api = Arc::new(StubApi::default());
    let server = DriverIpcServer::start(ipc_path.clone(), api).await?;

    assert!(base_dir.exists(), "IPC server should auto-create missing parent directories");
    assert!(ipc_path.exists(), "IPC socket should exist after start");

    server.stop().await;

    let _ = std::fs::remove_dir_all(PathBuf::from(format!(
        "/tmp/driver-test-nested-{}",
        std::process::id()
    )));
    Ok(())
}

/// Ensure the IPC server removes a stale socket file on startup.
#[cfg(unix)]
#[test_log::test(tokio::test)]
async fn ipc_server_removes_stale_socket_on_startup() -> TestResult {
    use std::os::unix::net::UnixListener;

    let ipc_path = PathBuf::from(format!("/tmp/driver-test-stale-{}.ipc", std::process::id()));

    {
        let _ = std::fs::remove_file(&ipc_path);
        let _listener = UnixListener::bind(&ipc_path)?;
    }
    assert!(ipc_path.exists(), "Stale socket should exist before test");

    let api = Arc::new(StubApi::default());
    let server = DriverIpcServer::start(ipc_path.clone(), api).await?;

    assert!(ipc_path.exists(), "New IPC socket should exist after start");

    server.stop().await;
    Ok(())
}

/// Ensure starting a second IPC server on an active socket fails.
#[cfg(unix)]
#[test_log::test(tokio::test)]
async fn ipc_server_rejects_active_socket() -> TestResult {
    let ipc_path = PathBuf::from(format!("/tmp/driver-test-active-{}.ipc", std::process::id()));
    let _ = std::fs::remove_file(&ipc_path);

    let api = Arc::new(StubApi::default());
    let server = DriverIpcServer::start(ipc_path.clone(), api).await?;

    let api2 = Arc::new(StubApi::default());
    let result = DriverIpcServer::start(ipc_path.clone(), api2).await;

    assert!(
        matches!(result, Err(DriverError::IpcSocketInUse { .. })),
        "expected IpcSocketInUse error"
    );
    assert!(ipc_path.exists(), "socket should not be removed while in use");

    server.stop().await;
    Ok(())
}

/// Ensure the IPC server errors if a non-socket file exists at the path.
#[cfg(unix)]
#[test_log::test(tokio::test)]
async fn ipc_server_errors_on_non_socket_file() -> TestResult {
    let ipc_path = PathBuf::from(format!("/tmp/driver-test-regular-{}.ipc", std::process::id()));

    std::fs::write(&ipc_path, "not a socket")?;
    assert!(ipc_path.exists(), "Regular file should exist before test");

    let api = Arc::new(StubApi::default());
    let result = DriverIpcServer::start(ipc_path.clone(), api).await;

    assert!(result.is_err(), "IPC server should error if non-socket file exists at path");

    let _ = std::fs::remove_file(&ipc_path);
    Ok(())
}

/// Ensure the IPC socket file is removed on shutdown.
#[test_log::test(tokio::test)]
async fn ipc_socket_removed_on_shutdown() -> TestResult {
    let ipc_path = PathBuf::from(format!("/tmp/driver-test-cleanup-{}.ipc", std::process::id()));
    let _ = std::fs::remove_file(&ipc_path);

    let api = Arc::new(StubApi::default());
    let server = DriverIpcServer::start(ipc_path.clone(), api).await?;

    assert!(ipc_path.exists(), "IPC socket should exist after start");

    server.stop().await;

    assert!(!ipc_path.exists(), "IPC socket should be removed after stop()");
    Ok(())
}
