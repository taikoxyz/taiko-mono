use bytes::Bytes;
use http_body_util::Full;
use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};
use tokio::sync::broadcast;

use super::{
    PRECONF_BLOCKS_BODY_LIMIT_BYTES, WhitelistApiServer, WhitelistApiServerConfig,
    auth::JwtAuth,
    http::{RequestBodyReadError, read_request_body},
};
use crate::{
    Result,
    api::{
        WhitelistApi,
        types::{
            ApiStatus, BuildPreconfBlockRequest, BuildPreconfBlockResponse,
            EndOfSequencingNotification, ExecutableData,
        },
    },
};
use alloy_primitives::{Address, B256, Bytes as RpcBytes};
use async_trait::async_trait;

/// Configurable [`WhitelistApi`] test double (replaces the former `MockApi` +
/// `SyncReadyApi`). `sync_ready` drives the sync-ready gate; `build_calls`
/// counts `build_preconf_block` invocations (what `SyncReadyApi` tracked) and is
/// an `Arc` so a clone can be retained to assert the count after the server has
/// taken ownership of the `Arc<dyn WhitelistApi>`.
#[derive(Clone)]
struct TestApi {
    /// Value returned from the sync-ready gate.
    sync_ready: bool,
    /// Counts `build_preconf_block` calls.
    build_calls: Arc<AtomicUsize>,
}

impl Default for TestApi {
    /// A sync-ready double with a fresh call counter — the common case.
    fn default() -> Self {
        Self { sync_ready: true, build_calls: Arc::new(AtomicUsize::new(0)) }
    }
}

#[async_trait]
impl WhitelistApi for TestApi {
    async fn build_preconf_block(
        &self,
        _request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        self.build_calls.fetch_add(1, Ordering::SeqCst);
        Ok(BuildPreconfBlockResponse { block_header: Default::default() })
    }

    async fn get_status(&self) -> Result<ApiStatus> {
        Ok(ApiStatus {
            highest_unsafe_l2_payload_block_id: 100,
            end_of_sequencing_block_hash: B256::ZERO.to_string(),
            can_shutdown: true,
        })
    }

    fn is_sync_ready(&self) -> bool {
        self.sync_ready
    }

    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
        let (_tx, rx) = broadcast::channel(1);
        rx
    }
}

fn sample_preconf_request() -> Vec<u8> {
    let request = BuildPreconfBlockRequest {
        executable_data: Some(ExecutableData {
            parent_hash: B256::ZERO,
            fee_recipient: Address::ZERO,
            block_number: 1,
            gas_limit: 30_000_000,
            timestamp: 1_735_000_000,
            transactions: RpcBytes::from(vec![0x00]),
            extra_data: RpcBytes::default(),
            base_fee_per_gas: 1_000_000_000,
        }),
        end_of_sequencing: Some(false),
        is_forced_inclusion: Some(false),
    };
    serde_json::to_vec(&request).expect("sample preconf request should serialize")
}

fn test_config() -> WhitelistApiServerConfig {
    WhitelistApiServerConfig {
        listen_addr: "127.0.0.1:0".parse().expect("valid loopback address"),
        jwt_secret: None,
        cors_origins: vec!["*".to_string()],
    }
}

/// Start a server configured with a JWT secret so probe-route auth-skip
/// behavior and protected-route enforcement can be exercised.
async fn start_jwt_server() -> WhitelistApiServer {
    let config =
        WhitelistApiServerConfig { jwt_secret: Some(b"test-secret".to_vec()), ..test_config() };
    let api: Arc<dyn WhitelistApi> = Arc::new(TestApi::default());
    WhitelistApiServer::start(config, api).await.expect("server should start")
}

#[tokio::test]
async fn server_start_stop() {
    let config = test_config();
    let api: Arc<dyn WhitelistApi> = Arc::new(TestApi::default());

    let server = WhitelistApiServer::start(config, api).await.expect("server should start");
    assert_eq!(server.local_addr().ip().to_string(), "127.0.0.1");
    assert_ne!(server.local_addr().port(), 0);
    assert!(server.http_url().starts_with("http://127.0.0.1:"));
    assert!(server.ws_url().starts_with("ws://127.0.0.1:"));
    server.stop().await;
}

#[test]
fn default_config() {
    let config = WhitelistApiServerConfig::default();
    assert_eq!(config.listen_addr.port(), 8552);
    assert!(config.jwt_secret.is_none());
    assert_eq!(config.cors_origins, vec!["*".to_string()]);
}

#[tokio::test]
async fn cors_layer_allows_configured_origin() {
    let config = WhitelistApiServerConfig {
        cors_origins: vec!["https://example.com".to_string()],
        ..test_config()
    };
    let api: Arc<dyn WhitelistApi> = Arc::new(TestApi::default());

    let server = WhitelistApiServer::start(config, api).await.expect("server should start");
    let response = reqwest::Client::new()
        .get(format!("{}/status", server.http_url()))
        .header(reqwest::header::ORIGIN, "https://example.com")
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(
        response
            .headers()
            .get(reqwest::header::ACCESS_CONTROL_ALLOW_ORIGIN)
            .unwrap()
            .to_str()
            .unwrap(),
        "https://example.com"
    );

    server.stop().await;
}

#[tokio::test]
async fn preconf_blocks_is_rejected_when_not_sync_ready() {
    let build_calls = Arc::new(AtomicUsize::new(0));
    let config = WhitelistApiServerConfig {
        cors_origins: vec!["https://example.com".to_string()],
        ..test_config()
    };
    let api = TestApi { sync_ready: false, build_calls: build_calls.clone() };
    let server =
        WhitelistApiServer::start(config, Arc::new(api)).await.expect("server should start");

    let response = reqwest::Client::new()
        .post(format!("{}/preconfBlocks", server.http_url()))
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .body(sample_preconf_request())
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::BAD_REQUEST);
    assert_eq!(build_calls.load(Ordering::SeqCst), 0);

    server.stop().await;
}

#[tokio::test]
async fn read_request_body_accepts_payload_within_limit() {
    let payload = vec![0xABu8; 64];
    let body =
        read_request_body(Full::new(Bytes::from(payload.clone())), 128).await.expect("read body");
    assert_eq!(body, payload);
}

#[tokio::test]
async fn read_request_body_rejects_oversized_payload() {
    let payload = vec![0xCDu8; PRECONF_BLOCKS_BODY_LIMIT_BYTES + 1];
    let err = read_request_body(Full::new(Bytes::from(payload)), PRECONF_BLOCKS_BODY_LIMIT_BYTES)
        .await
        .expect_err("payload exceeding limit must be rejected");

    assert!(matches!(err, RequestBodyReadError::TooLarge { .. }));
}

#[test]
fn jwt_auth_rejects_missing_header() {
    let auth = JwtAuth::new(b"test-secret");
    let headers = http::HeaderMap::new();
    let err = auth.validate_headers(&headers).expect_err("missing header must fail");
    assert!(err.contains("missing bearer authorization header"));
}

#[tokio::test]
async fn jwt_auth_is_required_when_secret_configured() {
    let server = start_jwt_server().await;

    let response = reqwest::Client::new()
        .post(format!("{}/preconfBlocks", server.http_url()))
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .body(sample_preconf_request())
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::UNAUTHORIZED);

    server.stop().await;
}

#[tokio::test]
async fn websocket_route_rejects_non_upgrade_requests() {
    let config = test_config();
    let api: Arc<dyn WhitelistApi> = Arc::new(TestApi::default());
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let response = reqwest::Client::new()
        .get(format!("{}/ws", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::BAD_REQUEST);

    server.stop().await;
}

#[tokio::test]
async fn preconf_blocks_enforces_body_limit() {
    let config = test_config();
    let api: Arc<dyn WhitelistApi> = Arc::new(TestApi::default());
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let oversized_body = vec![b'a'; PRECONF_BLOCKS_BODY_LIMIT_BYTES + 1];
    let response = reqwest::Client::new()
        .post(format!("{}/preconfBlocks", server.http_url()))
        .body(oversized_body)
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::PAYLOAD_TOO_LARGE);
    let payload: serde_json::Value = response.json().await.expect("json body expected");
    let error = payload
        .get("error")
        .and_then(serde_json::Value::as_str)
        .expect("error field should be a string");
    assert!(error.starts_with("request body exceeds maximum of "));

    server.stop().await;
}

#[tokio::test]
async fn preconf_blocks_rejects_invalid_json() {
    let config = test_config();
    let api: Arc<dyn WhitelistApi> = Arc::new(TestApi::default());
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let response = reqwest::Client::new()
        .post(format!("{}/preconfBlocks", server.http_url()))
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .body("{")
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::UNPROCESSABLE_ENTITY);

    let payload: serde_json::Value = response.json().await.expect("json body expected");
    let error = payload
        .get("error")
        .and_then(serde_json::Value::as_str)
        .expect("error field should be a string");
    assert!(error.starts_with("failed to parse request body: "));

    server.stop().await;
}

#[tokio::test]
async fn get_status_returns_can_shutdown_field_in_camel_case() {
    let config = test_config();
    let api: Arc<dyn WhitelistApi> = Arc::new(TestApi::default());
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let response = reqwest::Client::new()
        .get(format!("{}/status", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::OK);
    let payload: serde_json::Value = response.json().await.expect("json body expected");
    assert_eq!(
        payload.get("canShutdown").and_then(serde_json::Value::as_bool),
        Some(true),
        "GET /status response must serialize canShutdown as a camelCase boolean field; got {payload:?}"
    );

    server.stop().await;
}

#[tokio::test]
async fn status_path_skips_jwt_when_secret_configured() {
    let server = start_jwt_server().await;

    let response = reqwest::Client::new()
        .get(format!("{}/status", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(
        response.status(),
        reqwest::StatusCode::OK,
        "GET /status must succeed without auth so that busybox k8s probes can hit it"
    );

    server.stop().await;
}

#[tokio::test]
async fn healthz_path_skips_jwt_when_secret_configured() {
    let server = start_jwt_server().await;

    let response = reqwest::Client::new()
        .get(format!("{}/healthz", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::OK);

    server.stop().await;
}

#[tokio::test]
async fn root_path_skips_jwt_when_secret_configured() {
    let server = start_jwt_server().await;

    let response = reqwest::Client::new()
        .get(format!("{}/", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::OK);

    server.stop().await;
}

#[tokio::test]
async fn preconf_blocks_still_requires_jwt_when_configured() {
    let server = start_jwt_server().await;

    let response = reqwest::Client::new()
        .post(format!("{}/preconfBlocks", server.http_url()))
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .body(sample_preconf_request())
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(
        response.status(),
        reqwest::StatusCode::UNAUTHORIZED,
        "POST /preconfBlocks must remain JWT-protected"
    );

    server.stop().await;
}

#[tokio::test]
async fn ws_still_requires_jwt_when_configured() {
    let server = start_jwt_server().await;

    let response = reqwest::Client::new()
        .get(format!("{}/ws", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(
        response.status(),
        reqwest::StatusCode::UNAUTHORIZED,
        "GET /ws upgrades must remain JWT-protected"
    );

    server.stop().await;
}

#[tokio::test]
async fn unknown_path_requires_jwt_when_secret_configured() {
    let server = start_jwt_server().await;

    let response = reqwest::Client::new()
        .get(format!("{}/this-route-does-not-exist", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(
        response.status(),
        reqwest::StatusCode::UNAUTHORIZED,
        "unknown paths must stay JWT-gated to avoid widening unauthenticated route probing"
    );

    server.stop().await;
}

#[tokio::test]
async fn unknown_path_returns_not_found_when_no_jwt_secret() {
    let config = test_config();
    let api: Arc<dyn WhitelistApi> = Arc::new(TestApi::default());
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let response = reqwest::Client::new()
        .get(format!("{}/this-route-does-not-exist", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::NOT_FOUND);

    server.stop().await;
}
