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
    http_utils::{RequestBodyReadError, read_request_body},
};
use crate::{
    Result,
    api::{
        WhitelistApi,
        types::{
            BuildPreconfBlockApiRequest, BuildPreconfBlockRequest, BuildPreconfBlockResponse,
            EndOfSequencingNotification, ExecutableData, WhitelistStatus,
        },
    },
    error::WhitelistPreconfirmationDriverError,
};
use alloy_primitives::{Address, B256, Bytes as RpcBytes};
use async_trait::async_trait;

struct MockApi;

#[async_trait]
impl WhitelistApi for MockApi {
    async fn build_preconf_block(
        &self,
        _request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        Ok(BuildPreconfBlockResponse { block_header: Default::default() })
    }

    async fn get_status(&self) -> Result<WhitelistStatus> {
        Ok(WhitelistStatus {
            head_l1_origin_block_id: Some(1),
            highest_unsafe_block_number: 100,
            peer_id: "test-peer".to_string(),
            sync_ready: true,
            highest_unsafe_l2_payload_block_id: 100,
            end_of_sequencing_block_hash: Some(B256::ZERO.to_string()),
            can_shutdown: true,
        })
    }

    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
        let (_tx, rx) = broadcast::channel(1);
        rx
    }
}

#[derive(Clone)]
struct SyncReadyApi {
    build_preconf_calls: Arc<AtomicUsize>,
    sync_ready: bool,
}

#[async_trait]
impl WhitelistApi for SyncReadyApi {
    async fn build_preconf_block(
        &self,
        _request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        self.build_preconf_calls.fetch_add(1, Ordering::SeqCst);
        Ok(BuildPreconfBlockResponse { block_header: Default::default() })
    }

    async fn get_status(&self) -> Result<WhitelistStatus> {
        Ok(WhitelistStatus {
            head_l1_origin_block_id: Some(1),
            highest_unsafe_block_number: 100,
            peer_id: "test-peer".to_string(),
            sync_ready: self.sync_ready,
            highest_unsafe_l2_payload_block_id: 100,
            end_of_sequencing_block_hash: Some(B256::ZERO.to_string()),
            can_shutdown: true,
        })
    }

    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
        let (_tx, rx) = broadcast::channel(1);
        rx
    }
}

fn sample_preconf_request() -> Vec<u8> {
    let request = BuildPreconfBlockApiRequest {
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

fn test_config(enable_http: bool, enable_ws: bool) -> WhitelistApiServerConfig {
    WhitelistApiServerConfig {
        listen_addr: "127.0.0.1:0".parse().expect("valid loopback address"),
        enable_http,
        enable_ws,
        jwt_secret: None,
        cors_origins: vec!["*".to_string()],
    }
}

#[tokio::test]
async fn server_start_stop() {
    let config = test_config(true, true);
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);

    let server = WhitelistApiServer::start(config, api).await.expect("server should start");
    assert_eq!(server.local_addr().ip().to_string(), "127.0.0.1");
    assert_ne!(server.local_addr().port(), 0);
    assert!(server.http_url().starts_with("http://127.0.0.1:"));
    assert!(server.ws_url().starts_with("ws://127.0.0.1:"));
    server.stop().await;
}

#[tokio::test]
async fn server_start_fails_when_no_transports_enabled() {
    let config = test_config(false, false);
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);

    let err = WhitelistApiServer::start(config, api)
        .await
        .expect_err("server must fail when both transports are disabled");
    assert!(matches!(err, WhitelistPreconfirmationDriverError::RestWsServerNoTransportsEnabled));
}

#[test]
fn default_config() {
    let config = WhitelistApiServerConfig::default();
    assert_eq!(config.listen_addr.port(), 8552);
    assert!(config.enable_http);
    assert!(config.enable_ws);
    assert!(config.jwt_secret.is_none());
    assert_eq!(config.cors_origins, vec!["*".to_string()]);
}

#[tokio::test]
async fn cors_layer_allows_configured_origin() {
    let config = WhitelistApiServerConfig {
        listen_addr: "127.0.0.1:0".parse().expect("valid loopback address"),
        cors_origins: vec!["https://example.com".to_string()],
        ..test_config(true, true)
    };
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);

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
    let build_preconf_calls = Arc::new(AtomicUsize::new(0));
    let config = WhitelistApiServerConfig {
        listen_addr: "127.0.0.1:0".parse().expect("valid loopback address"),
        cors_origins: vec!["https://example.com".to_string()],
        ..test_config(true, false)
    };
    let api = SyncReadyApi { build_preconf_calls: build_preconf_calls.clone(), sync_ready: false };
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
    assert_eq!(build_preconf_calls.load(Ordering::SeqCst), 0);

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
async fn jwt_auth_skips_probe_routes_when_secret_configured() {
    let config = WhitelistApiServerConfig {
        listen_addr: "127.0.0.1:0".parse().expect("valid loopback address"),
        jwt_secret: Some(b"test-secret".to_vec()),
        ..test_config(true, false)
    };
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    for path in ["/", "/healthz", "/status"] {
        let response = reqwest::Client::new()
            .get(format!("{}{}", server.http_url(), path))
            .send()
            .await
            .expect("request should succeed");
        assert_eq!(response.status(), reqwest::StatusCode::OK, "route {path} should be public");
    }

    server.stop().await;
}

#[tokio::test]
async fn jwt_auth_is_required_for_protected_routes_when_secret_configured() {
    let config = WhitelistApiServerConfig {
        listen_addr: "127.0.0.1:0".parse().expect("valid loopback address"),
        jwt_secret: Some(b"test-secret".to_vec()),
        ..test_config(true, true)
    };
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let protected_routes = [
        (reqwest::Method::POST, "/preconfBlocks"),
        (reqwest::Method::GET, "/ws"),
        (reqwest::Method::GET, "/anything-else"),
    ];
    for (method, path) in protected_routes {
        let response = reqwest::Client::new()
            .request(method, format!("{}{}", server.http_url(), path))
            .send()
            .await
            .expect("request should succeed");
        assert_eq!(
            response.status(),
            reqwest::StatusCode::UNAUTHORIZED,
            "route {path} should require JWT"
        );
    }

    server.stop().await;
}

#[tokio::test]
async fn websocket_route_rejects_non_upgrade_requests() {
    let config = test_config(false, true);
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
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
async fn ws_route_is_not_served_when_ws_transport_is_disabled() {
    let config = test_config(true, false);
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let response = reqwest::Client::new()
        .get(format!("{}/ws", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::NOT_FOUND);

    server.stop().await;
}

#[tokio::test]
async fn http_routes_are_not_served_when_http_transport_is_disabled() {
    let config = test_config(false, true);
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let response = reqwest::Client::new()
        .get(format!("{}/status", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::NOT_FOUND);

    server.stop().await;
}

#[tokio::test]
async fn preconf_blocks_enforces_body_limit() {
    let config = test_config(true, false);
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
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
    let config = test_config(true, false);
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
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
