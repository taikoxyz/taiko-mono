//! REST/WS server for the whitelist preconfirmation driver.

use std::{net::SocketAddr, sync::Arc};

use axum::{
    Json, Router,
    body::Bytes,
    extract::{
        DefaultBodyLimit, Request, State,
        ws::{Message, WebSocket, WebSocketUpgrade, rejection::WebSocketUpgradeRejection},
    },
    http::{HeaderMap, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use futures::StreamExt;
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode};
use tokio::{
    net::TcpListener,
    sync::{broadcast, oneshot},
    task::JoinHandle,
};
use tracing::{info, warn};

use super::{
    WhitelistRestApi,
    types::{BuildPreconfBlockRestRequest, EndOfSequencingNotification, RestStatus},
};
use crate::{
    Result, error::WhitelistPreconfirmationDriverError, importer::MAX_COMPRESSED_TX_LIST_BYTES,
};

/// Max accepted body size for `POST /preconfBlocks` requests.
///
/// The tx list payload itself is capped by `MAX_COMPRESSED_TX_LIST_BYTES`; we reserve
/// a small overhead for JSON envelope fields.
const MAX_PRECONF_BLOCK_REST_BODY_BYTES: usize = MAX_COMPRESSED_TX_LIST_BYTES + 64 * 1024;

/// Configuration for the whitelist preconfirmation REST/WS server.
#[derive(Debug, Clone)]
pub struct WhitelistRestWsServerConfig {
    /// Socket address to listen on.
    pub listen_addr: SocketAddr,
    /// Whether HTTP transport is enabled.
    pub enable_http: bool,
    /// Whether WebSocket transport is enabled.
    pub enable_ws: bool,
    /// Optional shared secret used to validate `Authorization: Bearer <jwt>` on all routes.
    pub jwt_secret: Option<Vec<u8>>,
}

impl Default for WhitelistRestWsServerConfig {
    fn default() -> Self {
        Self {
            listen_addr: "127.0.0.1:8552".parse().expect("valid default address"),
            enable_http: true,
            enable_ws: true,
            jwt_secret: None,
        }
    }
}

/// Running REST/WS server for whitelist preconfirmation operations.
///
/// The server serves Go-compatible REST routes and `/ws` notifications on one socket.
#[derive(Debug)]
pub struct WhitelistRestWsServer {
    /// Socket address bound by the server.
    addr: SocketAddr,
    /// Signal channel for graceful shutdown.
    shutdown_tx: Option<oneshot::Sender<()>>,
    /// Join handle for the running server task.
    task: JoinHandle<()>,
}

#[derive(Clone)]
struct RestWsState {
    api: Arc<dyn WhitelistRestApi>,
    jwt_auth: Option<Arc<JwtAuth>>,
}

impl WhitelistRestWsServer {
    /// Start the REST/WS server.
    pub async fn start(
        config: WhitelistRestWsServerConfig,
        api: Arc<dyn WhitelistRestApi>,
    ) -> Result<Self> {
        if !config.enable_http && !config.enable_ws {
            return Err(WhitelistPreconfirmationDriverError::RestWsServerNoTransportsEnabled);
        }

        let listener = TcpListener::bind(config.listen_addr).await.map_err(|e| {
            WhitelistPreconfirmationDriverError::RestWsServerBind {
                listen_addr: config.listen_addr,
                reason: e.to_string(),
            }
        })?;

        let addr = listener.local_addr().map_err(|e| {
            WhitelistPreconfirmationDriverError::RestWsServerLocalAddr { reason: e.to_string() }
        })?;

        let state = RestWsState {
            api,
            jwt_auth: config
                .jwt_secret
                .as_ref()
                .map(|secret| Arc::new(JwtAuth::new(secret.as_slice()))),
        };

        let app = build_router(&config, state);

        let (shutdown_tx, shutdown_rx) = oneshot::channel();
        let server = axum::serve(listener, app).with_graceful_shutdown(async {
            let _ = shutdown_rx.await;
        });

        let task = tokio::spawn(async move {
            if let Err(err) = server.await {
                warn!(error = %err, "whitelist preconfirmation REST/WS server terminated with error");
            }
        });

        info!(
            addr = %addr,
            enable_http = config.enable_http,
            enable_ws = config.enable_ws,
            jwt_enabled = config.jwt_secret.is_some(),
            http_url = %format!("http://{addr}"),
            ws_url = %format!("ws://{addr}"),
            "started whitelist preconfirmation REST/WS server"
        );

        Ok(Self { addr, shutdown_tx: Some(shutdown_tx), task })
    }

    /// Return the bound socket address.
    pub const fn local_addr(&self) -> SocketAddr {
        self.addr
    }

    /// Return the HTTP URL for this server.
    pub fn http_url(&self) -> String {
        format!("http://{}", self.addr)
    }

    /// Return the WebSocket URL for this server.
    pub fn ws_url(&self) -> String {
        format!("ws://{}", self.addr)
    }

    /// Stop the server gracefully.
    pub async fn stop(mut self) {
        if let Some(shutdown_tx) = self.shutdown_tx.take() {
            let _ = shutdown_tx.send(());
        }

        if let Err(err) = self.task.await {
            warn!(error = %err, "whitelist preconfirmation REST/WS server task join failed");
        }

        info!("whitelist preconfirmation REST/WS server stopped");
    }
}

fn build_router(config: &WhitelistRestWsServerConfig, state: RestWsState) -> Router {
    let mut router = Router::new();

    if config.enable_http {
        router = router
            .route("/", get(health_handler))
            .route("/healthz", get(health_handler))
            .route("/status", get(status_handler))
            .route(
                "/preconfBlocks",
                post(build_preconf_block_handler)
                    .layer(DefaultBodyLimit::max(MAX_PRECONF_BLOCK_REST_BODY_BYTES)),
            );
    }

    if config.enable_ws {
        router = router.route("/ws", get(ws_handler));
    }

    router
        .fallback(not_found_handler)
        .layer(middleware::from_fn_with_state(state.clone(), jwt_auth_middleware))
        .with_state(state)
}

/// Shared auth middleware for REST and WS endpoints.
async fn jwt_auth_middleware(
    State(state): State<RestWsState>,
    request: Request,
    next: Next,
) -> Response {
    if let Some(jwt_auth) = state.jwt_auth.as_ref() &&
        let Err(err) = jwt_auth.validate_headers(request.headers())
    {
        return error_response(StatusCode::UNAUTHORIZED, err);
    }

    next.run(request).await
}

async fn health_handler() -> Response {
    StatusCode::OK.into_response()
}

async fn status_handler(State(state): State<RestWsState>) -> Response {
    match state.api.get_status().await {
        Ok(status) => {
            let response = RestStatus {
                lookahead: status.lookahead,
                total_cached: status.total_cached.unwrap_or_default(),
                highest_unsafe_l2_payload_block_id: status
                    .highest_unsafe_l2_payload_block_id
                    .or(status.highest_unsafe_block_number)
                    .unwrap_or_default(),
                end_of_sequencing_block_hash: status
                    .end_of_sequencing_block_hash
                    .unwrap_or_else(|| alloy_primitives::B256::ZERO.to_string()),
            };
            (StatusCode::OK, Json(response)).into_response()
        }
        Err(err) => error_response(map_rest_error_status(&err), err.to_string()),
    }
}

async fn build_preconf_block_handler(State(state): State<RestWsState>, body: Bytes) -> Response {
    let rest_request: BuildPreconfBlockRestRequest = match serde_json::from_slice(&body) {
        Ok(value) => value,
        Err(err) => {
            return error_response(
                StatusCode::UNPROCESSABLE_ENTITY,
                format!("failed to parse request body: {err}"),
            );
        }
    };

    let request = match rest_request.into_rpc_request() {
        Ok(request) => request,
        Err(err) => return error_response(StatusCode::BAD_REQUEST, err),
    };

    match state.api.build_preconf_block(request).await {
        Ok(response) => {
            let Some(block_header) = response.block_header else {
                return error_response(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "missing block header in build_preconf_block response".to_string(),
                );
            };

            #[derive(serde::Serialize)]
            #[serde(rename_all = "camelCase")]
            struct BuildPreconfBlockRestResponse {
                block_header: alloy_rpc_types::Header,
            }

            (StatusCode::OK, Json(BuildPreconfBlockRestResponse { block_header })).into_response()
        }
        Err(err) => error_response(map_rest_error_status(&err), err.to_string()),
    }
}

async fn ws_handler(
    State(state): State<RestWsState>,
    ws: std::result::Result<WebSocketUpgrade, WebSocketUpgradeRejection>,
) -> Response {
    let ws = match ws {
        Ok(ws) => ws,
        Err(err) => {
            warn!(error = %err, "websocket upgrade rejected");
            return error_response(
                StatusCode::BAD_REQUEST,
                "websocket upgrade headers are required".to_string(),
            );
        }
    };

    let notifications = state.api.subscribe_end_of_sequencing();
    ws.on_upgrade(move |socket| serve_websocket_notifications(socket, notifications))
        .into_response()
}

async fn serve_websocket_notifications(
    mut websocket: WebSocket,
    mut notifications: broadcast::Receiver<EndOfSequencingNotification>,
) {
    loop {
        tokio::select! {
            notification = notifications.recv() => {
                match notification {
                    Ok(notification) => {
                        match serde_json::to_string(&notification) {
                            Ok(payload) => {
                                if websocket.send(Message::Text(payload.into())).await.is_err() {
                                    break;
                                }
                            }
                            Err(err) => {
                                warn!(error = %err, "failed to serialize websocket EOS notification");
                            }
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(skipped)) => {
                        warn!(skipped, "whitelist websocket subscriber lagged behind EOS notifications");
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                }
            }
            incoming = websocket.next() => {
                match incoming {
                    Some(Ok(message)) => {
                        if let Message::Close(_) = message {
                            break;
                        }
                        if let Message::Ping(payload) = message
                            && websocket.send(Message::Pong(payload)).await.is_err()
                        {
                            break;
                        }
                    }
                    Some(Err(_)) | None => break,
                }
            }
        }
    }
}

async fn not_found_handler() -> Response {
    error_response(StatusCode::NOT_FOUND, "route not found".to_string())
}

fn error_response(status: StatusCode, message: String) -> Response {
    #[derive(serde::Serialize)]
    struct ErrorBody {
        error: String,
    }

    (status, Json(ErrorBody { error: message })).into_response()
}

fn map_rest_error_status(err: &WhitelistPreconfirmationDriverError) -> StatusCode {
    match err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_) |
        WhitelistPreconfirmationDriverError::PreconfIngressNotReady |
        WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfIngressNotReady,
        ) |
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(_)) => {
            StatusCode::BAD_REQUEST
        }
        _ => StatusCode::INTERNAL_SERVER_ERROR,
    }
}

/// Optional Bearer JWT validation shared by REST/WS routes.
struct JwtAuth {
    decoding_key: DecodingKey,
    validation: Validation,
}

impl JwtAuth {
    /// Build a validator from a shared secret.
    fn new(secret: &[u8]) -> Self {
        let mut validation = Validation::new(Algorithm::HS256);
        // Match Go `echo-jwt` behaviour: verify signature; claims like `exp` stay optional.
        validation.required_spec_claims.clear();
        validation.validate_exp = false;
        validation.validate_nbf = false;
        Self { decoding_key: DecodingKey::from_secret(secret), validation }
    }

    /// Validate `Authorization: Bearer <jwt>`.
    fn validate_headers(&self, headers: &HeaderMap) -> std::result::Result<(), String> {
        let header = headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .ok_or_else(|| "missing bearer authorization header".to_string())?;
        let token = header
            .strip_prefix("Bearer ")
            .ok_or_else(|| "authorization header must use bearer token".to_string())?;

        decode::<serde_json::Value>(token, &self.decoding_key, &self.validation)
            .map_err(|err| format!("invalid bearer token: {err}"))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::rpc::types::{
        BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
        WhitelistStatus,
    };
    use alloy_primitives::B256;
    use async_trait::async_trait;
    use jsonwebtoken::{EncodingKey, Header, encode};
    use reqwest::Client;
    use serde_json::json;

    struct MockApi;

    #[async_trait]
    impl WhitelistRestApi for MockApi {
        async fn build_preconf_block(
            &self,
            _request: BuildPreconfBlockRequest,
        ) -> Result<BuildPreconfBlockResponse> {
            Ok(BuildPreconfBlockResponse {
                block_hash: B256::ZERO,
                block_number: 1,
                block_header: None,
            })
        }

        async fn get_status(&self) -> Result<WhitelistStatus> {
            Ok(WhitelistStatus {
                head_l1_origin_block_id: Some(42),
                highest_unsafe_block_number: Some(100),
                peer_id: "test-peer".to_string(),
                sync_ready: true,
                lookahead: None,
                total_cached: Some(0),
                highest_unsafe_l2_payload_block_id: Some(100),
                end_of_sequencing_block_hash: Some(B256::ZERO.to_string()),
            })
        }

        fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
            let (_tx, rx) = broadcast::channel(1);
            rx
        }
    }

    async fn start_test_server(mut config: WhitelistRestWsServerConfig) -> WhitelistRestWsServer {
        config.listen_addr = "127.0.0.1:0".parse().unwrap();
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);
        WhitelistRestWsServer::start(config, api).await.expect("server should start")
    }

    #[tokio::test]
    async fn server_start_stop() {
        let server = start_test_server(WhitelistRestWsServerConfig::default()).await;
        assert_eq!(server.local_addr().ip().to_string(), "127.0.0.1");
        assert_ne!(server.local_addr().port(), 0);
        assert!(server.http_url().starts_with("http://127.0.0.1:"));
        assert!(server.ws_url().starts_with("ws://127.0.0.1:"));
        server.stop().await;
    }

    #[tokio::test]
    async fn jwt_auth_is_required_when_secret_configured() {
        let secret = b"test-secret".to_vec();
        let server = start_test_server(WhitelistRestWsServerConfig {
            jwt_secret: Some(secret.clone()),
            ..Default::default()
        })
        .await;
        let client = Client::new();

        let unauthenticated = client
            .get(format!("{}/healthz", server.http_url()))
            .send()
            .await
            .expect("request should complete");
        assert_eq!(unauthenticated.status(), StatusCode::UNAUTHORIZED);

        let token =
            encode(&Header::default(), &json!({}), &EncodingKey::from_secret(secret.as_slice()))
                .expect("token encoding should work");

        let authenticated = client
            .get(format!("{}/healthz", server.http_url()))
            .header("Authorization", format!("Bearer {token}"))
            .send()
            .await
            .expect("request should complete");
        assert_eq!(authenticated.status(), StatusCode::OK);

        server.stop().await;
    }

    #[tokio::test]
    async fn websocket_route_rejects_non_upgrade_requests() {
        let server = start_test_server(WhitelistRestWsServerConfig::default()).await;
        let client = Client::new();

        let response = client
            .get(format!("{}/ws", server.http_url()))
            .send()
            .await
            .expect("request should complete");
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);

        server.stop().await;
    }

    #[tokio::test]
    async fn preconf_blocks_enforces_body_limit() {
        let server = start_test_server(WhitelistRestWsServerConfig::default()).await;
        let client = Client::new();
        let oversized_body = vec![b'a'; MAX_PRECONF_BLOCK_REST_BODY_BYTES + 1];

        let response = client
            .post(format!("{}/preconfBlocks", server.http_url()))
            .header("content-type", "application/json")
            .body(oversized_body)
            .send()
            .await
            .expect("request should complete");
        assert_eq!(response.status(), StatusCode::PAYLOAD_TOO_LARGE);

        server.stop().await;
    }

    #[tokio::test]
    async fn server_start_fails_when_no_transports_enabled() {
        let config = WhitelistRestWsServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            enable_http: false,
            enable_ws: false,
            ..Default::default()
        };
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);

        let err = WhitelistRestWsServer::start(config, api).await.expect_err("server should fail");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::RestWsServerNoTransportsEnabled
        ));
    }

    #[test]
    fn default_config() {
        let config = WhitelistRestWsServerConfig::default();
        assert_eq!(config.listen_addr.port(), 8552);
        assert!(config.enable_http);
        assert!(config.enable_ws);
        assert!(config.jwt_secret.is_none());
    }
}
