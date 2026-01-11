use std::{
    error::Error,
    net::SocketAddr,
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
    jsonrpc::{DriverRpcApi, DriverRpcServer},
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
#[tokio::test]
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
#[tokio::test]
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
