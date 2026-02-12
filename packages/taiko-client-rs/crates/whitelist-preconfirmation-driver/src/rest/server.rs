//! REST/WS server for the whitelist preconfirmation driver.

use std::{net::SocketAddr, sync::Arc};

use axum::{
    Router,
    body::Body,
    extract::{
        Request, State,
        ws::{Message, WebSocket, WebSocketUpgrade},
    },
    http::{
        StatusCode,
        header::{AUTHORIZATION, CONTENT_TYPE},
    },
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use futures::StreamExt;
use http_body_util::{BodyExt, BodyStream};
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

/// `transactions` are hex-encoded in JSON (`0x` + 2 chars per byte), so payload limits must
/// account for expansion relative to compressed bytes on wire.
const PRECONF_BLOCKS_BODY_LIMIT_BYTES: usize = (MAX_COMPRESSED_TX_LIST_BYTES * 2) + (64 * 1024);

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
    /// Graceful-shutdown trigger for the running server.
    shutdown_tx: Option<oneshot::Sender<()>>,
    /// Background task running the axum server.
    task: JoinHandle<()>,
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

        let state = AppState {
            api: Arc::clone(&api),
            jwt_auth: config
                .jwt_secret
                .as_ref()
                .map(|secret| Arc::new(JwtAuth::new(secret.as_slice()))),
        };
        let app = build_router(state, config.enable_http, config.enable_ws);

        let listener = TcpListener::bind(config.listen_addr).await.map_err(|e| {
            WhitelistPreconfirmationDriverError::RestWsServerBind {
                listen_addr: config.listen_addr,
                reason: e.to_string(),
            }
        })?;

        let addr = listener.local_addr().map_err(|e| {
            WhitelistPreconfirmationDriverError::RestWsServerLocalAddr { reason: e.to_string() }
        })?;

        let (shutdown_tx, shutdown_rx) = oneshot::channel();
        let task = tokio::spawn(async move {
            let server = axum::serve(listener, app).with_graceful_shutdown(async move {
                let _ = shutdown_rx.await;
            });

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

#[derive(Clone)]
struct AppState {
    api: Arc<dyn WhitelistRestApi>,
    jwt_auth: Option<Arc<JwtAuth>>,
}

fn build_router(state: AppState, enable_http: bool, enable_ws: bool) -> Router {
    let mut router = Router::new();

    if enable_http {
        router = router
            .route("/", get(handle_root))
            .route("/healthz", get(handle_root))
            .route("/status", get(handle_status))
            .route("/preconfBlocks", post(handle_preconf_blocks));
    }

    if enable_ws {
        router = router.route("/ws", get(handle_websocket_upgrade));
    }

    router
        .fallback(handle_not_found)
        .layer(middleware::from_fn_with_state(state.clone(), auth_middleware))
        .with_state(state)
}

async fn auth_middleware(State(state): State<AppState>, request: Request, next: Next) -> Response {
    if let Some(jwt_auth) = state.jwt_auth.as_ref() &&
        let Err(err) = jwt_auth.validate_headers(request.headers())
    {
        return error_response(StatusCode::UNAUTHORIZED, err);
    }

    next.run(request).await
}

async fn handle_root() -> Response {
    no_content_response(StatusCode::OK)
}

async fn handle_status(State(state): State<AppState>) -> Response {
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
            json_response(StatusCode::OK, &response)
        }
        Err(err) => error_response(map_rest_error_status(&err), err.to_string()),
    }
}

async fn handle_preconf_blocks(State(state): State<AppState>, request: Request) -> Response {
    let body = match read_request_body(request.into_body(), PRECONF_BLOCKS_BODY_LIMIT_BYTES).await {
        Ok(body) => body,
        Err(ReadRequestBodyError::TooLarge { max_bytes }) => {
            return error_response(
                StatusCode::PAYLOAD_TOO_LARGE,
                format!("request body exceeds maximum of {max_bytes} bytes"),
            );
        }
        Err(err) => {
            return error_response(
                StatusCode::UNPROCESSABLE_ENTITY,
                format!("failed to read request body: {err}"),
            );
        }
    };

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

            json_response(StatusCode::OK, &BuildPreconfBlockRestResponse { block_header })
        }
        Err(err) => error_response(map_rest_error_status(&err), err.to_string()),
    }
}

async fn handle_websocket_upgrade(
    State(state): State<AppState>,
    websocket_upgrade: std::result::Result<
        WebSocketUpgrade,
        axum::extract::ws::rejection::WebSocketUpgradeRejection,
    >,
) -> Response {
    let websocket_upgrade = match websocket_upgrade {
        Ok(upgrade) => upgrade,
        Err(_) => {
            return error_response(
                StatusCode::BAD_REQUEST,
                "websocket upgrade headers are required".to_string(),
            );
        }
    };

    let notifications = state.api.subscribe_end_of_sequencing();
    websocket_upgrade
        .on_upgrade(move |socket| async move {
            serve_websocket_notifications(socket, notifications).await;
        })
        .into_response()
}

async fn handle_not_found() -> Response {
    error_response(StatusCode::NOT_FOUND, "route not found".to_string())
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
    fn validate_headers(&self, headers: &http::HeaderMap) -> std::result::Result<(), String> {
        let header = headers
            .get(AUTHORIZATION)
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

/// Push EOS notifications over a connected websocket until disconnect.
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
                                if websocket.send(Message::Text(payload)).await.is_err() {
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
                    Some(Ok(Message::Close(_))) => break,
                    Some(Ok(Message::Ping(payload))) => {
                        if websocket.send(Message::Pong(payload)).await.is_err() {
                            break;
                        }
                    }
                    Some(Ok(_)) => {}
                    Some(Err(_)) | None => break,
                }
            }
        }
    }
}

fn no_content_response(status: StatusCode) -> Response {
    Response::builder().status(status).body(Body::empty()).expect("valid response")
}

fn error_response(status: StatusCode, message: String) -> Response {
    #[derive(serde::Serialize)]
    struct ErrorBody {
        error: String,
    }
    json_response(status, &ErrorBody { error: message })
}

fn json_response<T: serde::Serialize>(status: StatusCode, value: &T) -> Response {
    let bytes = serde_json::to_vec(value)
        .unwrap_or_else(|_| b"{\"error\":\"serialization failed\"}".to_vec());
    Response::builder()
        .status(status)
        .header(CONTENT_TYPE, "application/json")
        .body(Body::from(bytes))
        .expect("valid response")
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

#[derive(Debug)]
enum ReadRequestBodyError {
    Read(String),
    TooLarge { max_bytes: usize },
}

impl std::fmt::Display for ReadRequestBodyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Read(reason) => write!(f, "{reason}"),
            Self::TooLarge { max_bytes } => {
                write!(f, "payload exceeds configured body limit of {max_bytes} bytes")
            }
        }
    }
}

async fn read_request_body<B>(
    body: B,
    max_bytes: usize,
) -> std::result::Result<Vec<u8>, ReadRequestBodyError>
where
    B: http_body::Body<Data = bytes::Bytes> + Send + Unpin + 'static,
    B::Data: Send,
    B::Error: Into<axum::BoxError>,
{
    let mut stream = BodyStream::new(body);
    let mut bytes = Vec::new();
    while let Some(frame) = stream.frame().await {
        let data = frame
            .map_err(|err| {
                let err: axum::BoxError = err.into();
                ReadRequestBodyError::Read(err.to_string())
            })?
            .into_data()
            .map_err(|_| {
                ReadRequestBodyError::Read("unexpected non-data frame in request body".to_string())
            })?;

        if bytes.len().saturating_add(data.len()) > max_bytes {
            return Err(ReadRequestBodyError::TooLarge { max_bytes });
        }

        bytes.extend_from_slice(&data);
    }
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use bytes::Bytes;
    use http_body_util::Full;

    use super::*;
    use crate::rest::types::{
        BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
        WhitelistStatus,
    };
    use alloy_primitives::B256;
    use async_trait::async_trait;

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

    #[tokio::test]
    async fn server_start_stop() {
        let config = WhitelistRestWsServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            ..Default::default()
        };
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);

        let server = WhitelistRestWsServer::start(config, api).await.expect("server should start");
        assert_eq!(server.local_addr().ip().to_string(), "127.0.0.1");
        assert_ne!(server.local_addr().port(), 0);
        assert!(server.http_url().starts_with("http://127.0.0.1:"));
        assert!(server.ws_url().starts_with("ws://127.0.0.1:"));
        server.stop().await;
    }

    #[tokio::test]
    async fn server_start_fails_when_no_transports_enabled() {
        let config = WhitelistRestWsServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            enable_http: false,
            enable_ws: false,
            jwt_secret: None,
        };
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);

        let err = WhitelistRestWsServer::start(config, api)
            .await
            .expect_err("server must fail when both transports are disabled");
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

    #[tokio::test]
    async fn read_request_body_accepts_payload_within_limit() {
        let payload = vec![0xABu8; 64];
        let body = read_request_body(Full::new(Bytes::from(payload.clone())), 128)
            .await
            .expect("read body");
        assert_eq!(body, payload);
    }

    #[tokio::test]
    async fn read_request_body_rejects_oversized_payload() {
        let payload = vec![0xCDu8; PRECONF_BLOCKS_BODY_LIMIT_BYTES + 1];
        let err =
            read_request_body(Full::new(Bytes::from(payload)), PRECONF_BLOCKS_BODY_LIMIT_BYTES)
                .await
                .expect_err("payload exceeding limit must be rejected");

        assert!(matches!(err, ReadRequestBodyError::TooLarge { .. }));
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
        let config = WhitelistRestWsServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            enable_http: true,
            enable_ws: false,
            jwt_secret: Some(b"test-secret".to_vec()),
        };
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);
        let server = WhitelistRestWsServer::start(config, api).await.expect("server should start");

        let response = reqwest::Client::new()
            .get(format!("{}/status", server.http_url()))
            .send()
            .await
            .expect("request should succeed");
        assert_eq!(response.status(), reqwest::StatusCode::UNAUTHORIZED);

        server.stop().await;
    }

    #[tokio::test]
    async fn websocket_route_rejects_non_upgrade_requests() {
        let config = WhitelistRestWsServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            enable_http: false,
            enable_ws: true,
            jwt_secret: None,
        };
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);
        let server = WhitelistRestWsServer::start(config, api).await.expect("server should start");

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
        let config = WhitelistRestWsServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            enable_http: true,
            enable_ws: false,
            jwt_secret: None,
        };
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);
        let server = WhitelistRestWsServer::start(config, api).await.expect("server should start");

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
        let config = WhitelistRestWsServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            enable_http: false,
            enable_ws: true,
            jwt_secret: None,
        };
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);
        let server = WhitelistRestWsServer::start(config, api).await.expect("server should start");

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
        let config = WhitelistRestWsServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            enable_http: true,
            enable_ws: false,
            jwt_secret: None,
        };
        let api: Arc<dyn WhitelistRestApi> = Arc::new(MockApi);
        let server = WhitelistRestWsServer::start(config, api).await.expect("server should start");

        let oversized_body = vec![b'a'; PRECONF_BLOCKS_BODY_LIMIT_BYTES + 1];
        let response = reqwest::Client::new()
            .post(format!("{}/preconfBlocks", server.http_url()))
            .body(oversized_body)
            .send()
            .await
            .expect("request should succeed");
        assert_eq!(response.status(), reqwest::StatusCode::PAYLOAD_TOO_LARGE);

        server.stop().await;
    }
}
