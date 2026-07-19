use bytes::Bytes;
use http_body_util::Full;
use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};
use tokio::sync::broadcast;

use super::{
    PRECONF_BLOCKS_BODY_LIMIT_BYTES, WhitelistApiServer, WhitelistApiServerConfig,
    auth::{JwtAuth, validate_temporal_claims_at},
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

struct MockApi;

#[async_trait]
impl WhitelistApi for MockApi {
    async fn build_preconf_block(
        &self,
        _request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
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
        true
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
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
    WhitelistApiServer::start(config, api).await.expect("server should start")
}

#[tokio::test]
async fn server_start_stop() {
    let config = test_config();
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);

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
        cors_origins: vec!["https://example.com".to_string()],
        ..test_config()
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

/// Build an `Authorization: Bearer <jwt>` header map for the given claims.
fn bearer_headers(secret: &[u8], claims: &serde_json::Value) -> http::HeaderMap {
    let token = jsonwebtoken::encode(
        &jsonwebtoken::Header::new(jsonwebtoken::Algorithm::HS256),
        claims,
        &jsonwebtoken::EncodingKey::from_secret(secret),
    )
    .expect("token should encode");
    let mut headers = http::HeaderMap::new();
    headers.insert(
        http::header::AUTHORIZATION,
        format!("Bearer {token}").parse().expect("valid header value"),
    );
    headers
}

#[test]
fn jwt_auth_accepts_token_without_claims() {
    let secret = b"test-secret";
    let auth = JwtAuth::new(secret);
    let headers = bearer_headers(secret, &serde_json::json!({}));
    auth.validate_headers(&headers).expect("claimless token is accepted");
}

/// Current unix time in whole seconds, for minting test claims.
fn unix_now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("clock after epoch")
        .as_secs()
}

#[test]
fn jwt_auth_truncates_fractional_temporal_claims_to_seconds() {
    let now = 1_000.1;
    let fractional_boundary = 1_000.9;

    // golang-jwt's default TimePrecision truncates NumericDates to seconds,
    // so this becomes `exp == current second` and is already expired.
    let err = validate_temporal_claims_at(&serde_json::json!({ "exp": fractional_boundary }), now)
        .expect_err("fractional exp must be truncated");
    assert!(err.contains("token has expired"), "unexpected error: {err}");

    // The same truncation makes this `nbf == current second`, so it is valid.
    validate_temporal_claims_at(&serde_json::json!({ "nbf": fractional_boundary }), now)
        .expect("fractional nbf must be truncated");
}

#[test]
fn jwt_auth_rejects_expired_token() {
    let secret = b"test-secret";
    let auth = JwtAuth::new(secret);
    let now = unix_now();

    let headers = bearer_headers(secret, &serde_json::json!({ "exp": now - 60 }));
    let err = auth.validate_headers(&headers).expect_err("expired token must fail");
    assert!(err.contains("token has expired"));

    // golang-jwt requires `now < exp`, so a token expiring exactly now is
    // already expired.
    let headers = bearer_headers(secret, &serde_json::json!({ "exp": now }));
    let err = auth.validate_headers(&headers).expect_err("exp == now must fail");
    assert!(err.contains("token has expired"));

    // Negative numeric dates parse like Go NumericDates, and are long expired.
    let headers = bearer_headers(secret, &serde_json::json!({ "exp": -100 }));
    let err = auth.validate_headers(&headers).expect_err("negative exp must fail");
    assert!(err.contains("token has expired"));

    // A numeric-date value of zero is an absent claim in golang-jwt v5
    // (`MapClaims.parseNumericDate` returns nil for a zero float64).
    let headers = bearer_headers(secret, &serde_json::json!({ "exp": 0 }));
    auth.validate_headers(&headers).expect("zero exp is treated as absent");

    let headers = bearer_headers(secret, &serde_json::json!({ "exp": now + 600 }));
    auth.validate_headers(&headers).expect("unexpired token is accepted");

    // Fractional numeric dates are valid per RFC 7519.
    let headers = bearer_headers(secret, &serde_json::json!({ "exp": now as f64 + 600.5 }));
    auth.validate_headers(&headers).expect("fractional exp is accepted");
}

#[test]
fn jwt_auth_rejects_premature_token() {
    let secret = b"test-secret";
    let auth = JwtAuth::new(secret);
    let now = unix_now();

    let headers = bearer_headers(secret, &serde_json::json!({ "nbf": now + 600 }));
    let err = auth.validate_headers(&headers).expect_err("not-yet-valid token must fail");
    assert!(err.contains("token is not valid yet"));

    let headers = bearer_headers(secret, &serde_json::json!({ "nbf": now - 60 }));
    auth.validate_headers(&headers).expect("past nbf is accepted");

    // Zero follows the same absent-claim rule as `exp: 0`.
    let headers = bearer_headers(secret, &serde_json::json!({ "nbf": 0 }));
    auth.validate_headers(&headers).expect("zero nbf is treated as absent");
}

#[test]
fn jwt_auth_rejects_malformed_temporal_claims() {
    let secret = b"test-secret";
    let auth = JwtAuth::new(secret);

    for claims in [
        serde_json::json!({ "exp": "soon" }),
        serde_json::json!({ "exp": serde_json::Value::Null }),
        serde_json::json!({ "nbf": true }),
    ] {
        let headers = bearer_headers(secret, &claims);
        let err = auth
            .validate_headers(&headers)
            .expect_err("present-but-malformed temporal claim must fail");
        assert!(err.contains("must be a numeric date"), "unexpected error: {err}");
    }

    // Composite claim values abort claim parsing inside jsonwebtoken itself,
    // so they are refused at decode rather than by the manual check.
    let headers = bearer_headers(secret, &serde_json::json!({ "exp": [1, 2] }));
    let err = auth.validate_headers(&headers).expect_err("array exp must fail");
    assert!(err.contains("invalid bearer token"), "unexpected error: {err}");

    // Non-object claim payloads are refused at decode, like golang-jwt's
    // MapClaims parse.
    let headers = bearer_headers(secret, &serde_json::json!("not-an-object"));
    let err = auth.validate_headers(&headers).expect_err("non-object claims must fail");
    assert!(err.contains("invalid bearer token"), "unexpected error: {err}");
}

#[test]
fn jwt_auth_ignores_audience_when_none_configured() {
    // echo-jwt only checks `aud` when an expected audience is configured;
    // jsonwebtoken's default would reject every token carrying the claim.
    let secret = b"test-secret";
    let auth = JwtAuth::new(secret);
    let headers = bearer_headers(
        secret,
        &serde_json::json!({ "aud": "taiko-preconf", "exp": unix_now() + 600 }),
    );
    auth.validate_headers(&headers).expect("audience-bearing token is accepted");
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
async fn preconf_blocks_enforces_body_limit() {
    let config = test_config();
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
    let config = test_config();
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

#[tokio::test]
async fn get_status_returns_can_shutdown_field_in_camel_case() {
    let config = test_config();
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
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
    let api: Arc<dyn WhitelistApi> = Arc::new(MockApi);
    let server = WhitelistApiServer::start(config, api).await.expect("server should start");

    let response = reqwest::Client::new()
        .get(format!("{}/this-route-does-not-exist", server.http_url()))
        .send()
        .await
        .expect("request should succeed");
    assert_eq!(response.status(), reqwest::StatusCode::NOT_FOUND);

    server.stop().await;
}
