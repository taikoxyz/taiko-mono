//! JSON-RPC server for the whitelist preconfirmation driver.

use std::{
    future::Future,
    net::SocketAddr,
    pin::Pin,
    sync::Arc,
    task::{Context, Poll},
};

use futures::{FutureExt, SinkExt, StreamExt, TryFutureExt};
use http::{
    Method, StatusCode,
    header::{
        AUTHORIZATION, CONNECTION, CONTENT_TYPE, SEC_WEBSOCKET_ACCEPT, SEC_WEBSOCKET_KEY, UPGRADE,
    },
};
use http_body_util::{BodyExt, BodyStream};
use hyper::upgrade;
use hyper_util::rt::TokioIo;
use jsonrpsee::{
    RpcModule,
    core::BoxError,
    server::{HttpBody, HttpRequest, HttpResponse, ServerBuilder, ServerConfig, ServerHandle},
    types::ErrorObjectOwned,
};
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode};
use metrics::{counter, histogram};
use tokio::sync::broadcast;
use tokio_tungstenite::{
    WebSocketStream,
    tungstenite::{Message, handshake::derive_accept_key, protocol::Role},
};
use tower::{Layer, Service};
use tracing::{info, warn};

use super::{
    WhitelistRpcApi,
    types::{
        BuildPreconfBlockRequest, BuildPreconfBlockRestRequest, EndOfSequencingNotification,
        RestStatus, WhitelistRpcErrorCode,
    },
};
use crate::{
    Result, error::WhitelistPreconfirmationDriverError,
    metrics::WhitelistPreconfirmationDriverMetrics,
};

/// JSON-RPC method name for building a preconfirmation block.
pub const METHOD_BUILD_PRECONF_BLOCK: &str = "whitelist_buildPreconfBlock";
/// JSON-RPC method name for querying whitelist driver status.
pub const METHOD_GET_STATUS: &str = "whitelist_getStatus";
/// JSON-RPC method name for health check.
pub const METHOD_HEALTHZ: &str = "whitelist_healthz";

/// Configuration for the whitelist preconfirmation RPC server.
#[derive(Debug, Clone)]
pub struct WhitelistRpcServerConfig {
    /// Socket address to listen on.
    pub listen_addr: SocketAddr,
    /// Whether HTTP JSON-RPC transport is enabled.
    pub enable_http: bool,
    /// Whether WebSocket JSON-RPC transport is enabled.
    pub enable_ws: bool,
    /// Optional shared secret used to validate `Authorization: Bearer <jwt>` on all routes.
    pub jwt_secret: Option<Vec<u8>>,
}

impl Default for WhitelistRpcServerConfig {
    fn default() -> Self {
        Self {
            listen_addr: "127.0.0.1:8552".parse().expect("valid default address"),
            enable_http: true,
            enable_ws: true,
            jwt_secret: None,
        }
    }
}

/// Running JSON-RPC server for whitelist preconfirmation operations.
///
/// The server accepts both HTTP and WebSocket transports on the same socket.
#[derive(Debug)]
pub struct WhitelistRpcServer {
    /// Socket address bound by the server.
    addr: SocketAddr,
    /// Keep-alive handle for the running server.
    handle: ServerHandle,
}

impl WhitelistRpcServer {
    /// Start the JSON-RPC server.
    pub async fn start(
        config: WhitelistRpcServerConfig,
        api: Arc<dyn WhitelistRpcApi>,
    ) -> Result<Self> {
        let server_config = match (config.enable_http, config.enable_ws) {
            (true, true) => ServerConfig::builder().build(),
            (true, false) => ServerConfig::builder().http_only().build(),
            (false, true) => ServerConfig::builder().ws_only().build(),
            (false, false) => {
                warn!(
                    "both HTTP and WebSocket transports are disabled; defaulting to both enabled"
                );
                ServerConfig::builder().build()
            }
        };
        let http_middleware = tower::ServiceBuilder::new().layer(RestCompatLayer {
            api: Arc::clone(&api),
            jwt_auth: config
                .jwt_secret
                .as_ref()
                .map(|secret| Arc::new(JwtAuth::new(secret.as_slice()))),
        });

        let server = ServerBuilder::with_config(server_config)
            .set_http_middleware(http_middleware)
            .build(config.listen_addr)
            .await
            .map_err(|e| WhitelistPreconfirmationDriverError::RpcServerBind {
                listen_addr: config.listen_addr,
                reason: e.to_string(),
            })?;

        let addr = server.local_addr().map_err(|e| {
            WhitelistPreconfirmationDriverError::RpcServerLocalAddr { reason: e.to_string() }
        })?;

        let handle = server.start(build_rpc_module(api));

        info!(
            addr = %addr,
            enable_http = config.enable_http,
            enable_ws = config.enable_ws,
            jwt_enabled = config.jwt_secret.is_some(),
            http_url = %format!("http://{addr}"),
            ws_url = %format!("ws://{addr}"),
            "started whitelist preconfirmation RPC server"
        );
        Ok(Self { addr, handle })
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
    pub async fn stop(self) {
        if let Err(err) = self.handle.stop() {
            warn!(error = %err, "whitelist preconfirmation RPC server already stopped");
        }
        let _ = self.handle.stopped().await;
        info!("whitelist preconfirmation RPC server stopped");
    }
}

/// Internal context passed to all RPC method handlers.
#[derive(Clone)]
struct RpcContext {
    /// The API implementation backing RPC calls.
    api: Arc<dyn WhitelistRpcApi>,
}

/// HTTP middleware layer that adds Go-compatible REST routes.
#[derive(Clone)]
struct RestCompatLayer {
    api: Arc<dyn WhitelistRpcApi>,
    jwt_auth: Option<Arc<JwtAuth>>,
}

impl<S> Layer<S> for RestCompatLayer {
    type Service = RestCompat<S>;

    fn layer(&self, service: S) -> Self::Service {
        RestCompat { service, api: Arc::clone(&self.api), jwt_auth: self.jwt_auth.clone() }
    }
}

/// Middleware service implementing REST compatibility paths.
#[derive(Clone)]
struct RestCompat<S> {
    service: S,
    api: Arc<dyn WhitelistRpcApi>,
    jwt_auth: Option<Arc<JwtAuth>>,
}

impl<S, B> Service<HttpRequest<B>> for RestCompat<S>
where
    S: Service<HttpRequest, Response = HttpResponse>,
    S::Response: 'static,
    S::Error: Into<BoxError> + 'static,
    S::Future: Send + 'static,
    B: http_body::Body<Data = bytes::Bytes> + Send + Unpin + 'static,
    B::Data: Send,
    B::Error: Into<BoxError>,
{
    type Response = S::Response;
    type Error = BoxError;
    type Future =
        Pin<Box<dyn Future<Output = std::result::Result<Self::Response, Self::Error>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<std::result::Result<(), Self::Error>> {
        self.service.poll_ready(cx).map_err(Into::into)
    }

    fn call(&mut self, req: HttpRequest<B>) -> Self::Future {
        let path = req.uri().path().to_string();
        let method = req.method().clone();

        if let Some(jwt_auth) = self.jwt_auth.as_ref() {
            if let Err(err) = jwt_auth.validate_headers(req.headers()) {
                return async move { Ok(error_response(StatusCode::UNAUTHORIZED, err)) }.boxed();
            }
        }

        if method == Method::GET && (path == "/" || path == "/healthz") {
            return async move { Ok(no_content_response(StatusCode::OK)) }.boxed();
        }

        if method == Method::GET && path == "/ws" {
            let eos_notification_rx = self.api.subscribe_end_of_sequencing();
            let response = handle_websocket_upgrade(req, eos_notification_rx);
            return async move { Ok(response) }.boxed();
        }

        if method == Method::GET && path == "/status" {
            let api = Arc::clone(&self.api);
            return async move {
                match api.get_status().await {
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
                        Ok(json_response(StatusCode::OK, &response))
                    }
                    Err(err) => Ok(error_response(map_rest_error_status(&err), err.to_string())),
                }
            }
            .boxed();
        }

        if method == Method::POST && path == "/preconfBlocks" {
            let api = Arc::clone(&self.api);
            return async move {
                let body = match read_request_body(req.into_body()).await {
                    Ok(body) => body,
                    Err(err) => {
                        return Ok(error_response(
                            StatusCode::UNPROCESSABLE_ENTITY,
                            format!("failed to read request body: {err}"),
                        ));
                    }
                };

                let rest_request: BuildPreconfBlockRestRequest = match serde_json::from_slice(&body)
                {
                    Ok(value) => value,
                    Err(err) => {
                        return Ok(error_response(
                            StatusCode::UNPROCESSABLE_ENTITY,
                            format!("failed to parse request body: {err}"),
                        ));
                    }
                };

                let request = match rest_request.into_rpc_request() {
                    Ok(request) => request,
                    Err(err) => return Ok(error_response(StatusCode::BAD_REQUEST, err)),
                };

                match api.build_preconf_block(request).await {
                    Ok(response) => {
                        let Some(block_header) = response.block_header else {
                            return Ok(error_response(
                                StatusCode::INTERNAL_SERVER_ERROR,
                                "missing block header in build_preconf_block response".to_string(),
                            ));
                        };

                        #[derive(serde::Serialize)]
                        #[serde(rename_all = "camelCase")]
                        struct BuildPreconfBlockRestResponse {
                            block_header: alloy_rpc_types::Header,
                        }

                        Ok(json_response(
                            StatusCode::OK,
                            &BuildPreconfBlockRestResponse { block_header },
                        ))
                    }
                    Err(err) => Ok(error_response(map_rest_error_status(&err), err.to_string())),
                }
            }
            .boxed();
        }

        let req = req.map(HttpBody::new);
        self.service.call(req).map_err(Into::into).boxed()
    }
}

/// Optional Bearer JWT validation shared by REST/RPC routes.
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

/// Handle a `GET /ws` upgrade request and spawn a notification push task.
fn handle_websocket_upgrade<B>(
    mut request: HttpRequest<B>,
    notification_rx: broadcast::Receiver<EndOfSequencingNotification>,
) -> HttpResponse
where
    B: http_body::Body + Send + 'static,
{
    if !is_websocket_upgrade_request(&request) {
        return error_response(
            StatusCode::BAD_REQUEST,
            "websocket upgrade headers are required".to_string(),
        );
    }

    let Some(sec_websocket_key) =
        request.headers().get(SEC_WEBSOCKET_KEY).and_then(|value| value.to_str().ok())
    else {
        return error_response(StatusCode::BAD_REQUEST, "missing sec-websocket-key".to_string());
    };

    let accept_key = derive_accept_key(sec_websocket_key.as_bytes());
    let on_upgrade = upgrade::on(&mut request);
    let mut client_notifications = notification_rx;

    tokio::spawn(async move {
        match on_upgrade.await {
            Ok(upgraded) => {
                let io = TokioIo::new(upgraded);
                let websocket = WebSocketStream::from_raw_socket(io, Role::Server, None).await;
                serve_websocket_notifications(websocket, &mut client_notifications).await;
            }
            Err(err) => {
                warn!(error = %err, "whitelist preconfirmation websocket upgrade failed");
            }
        }
    });

    HttpResponse::builder()
        .status(StatusCode::SWITCHING_PROTOCOLS)
        .header(CONNECTION, "Upgrade")
        .header(UPGRADE, "websocket")
        .header(SEC_WEBSOCKET_ACCEPT, accept_key)
        .body(HttpBody::empty())
        .expect("valid websocket upgrade response")
}

/// Return true when request headers indicate a websocket upgrade.
fn is_websocket_upgrade_request<B>(request: &HttpRequest<B>) -> bool {
    request.method() == Method::GET
        && header_contains_token(request.headers(), CONNECTION, "upgrade")
        && request
            .headers()
            .get(UPGRADE)
            .and_then(|value| value.to_str().ok())
            .is_some_and(|value| value.eq_ignore_ascii_case("websocket"))
}

/// Check whether a comma-separated header contains a token (case-insensitive).
fn header_contains_token(
    headers: &http::HeaderMap,
    header_name: http::header::HeaderName,
    token: &str,
) -> bool {
    headers
        .get(header_name)
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| value.split(',').any(|entry| entry.trim().eq_ignore_ascii_case(token)))
}

/// Push EOS notifications over a connected websocket until disconnect.
async fn serve_websocket_notifications(
    mut websocket: WebSocketStream<TokioIo<hyper::upgrade::Upgraded>>,
    notifications: &mut broadcast::Receiver<EndOfSequencingNotification>,
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
                        if message.is_close() {
                            break;
                        }
                        if let Message::Ping(payload) = message {
                            if websocket.send(Message::Pong(payload)).await.is_err() {
                                break;
                            }
                        }
                    }
                    Some(Err(_)) | None => break,
                }
            }
        }
    }
}

fn no_content_response(status: StatusCode) -> HttpResponse {
    HttpResponse::builder().status(status).body(HttpBody::empty()).expect("valid response")
}

fn error_response(status: StatusCode, message: String) -> HttpResponse {
    #[derive(serde::Serialize)]
    struct ErrorBody {
        error: String,
    }
    json_response(status, &ErrorBody { error: message })
}

fn json_response<T: serde::Serialize>(status: StatusCode, value: &T) -> HttpResponse {
    let bytes = serde_json::to_vec(value)
        .unwrap_or_else(|_| b"{\"error\":\"serialization failed\"}".to_vec());
    HttpResponse::builder()
        .status(status)
        .header(CONTENT_TYPE, "application/json")
        .body(HttpBody::from(bytes))
        .expect("valid response")
}

fn map_rest_error_status(err: &WhitelistPreconfirmationDriverError) -> StatusCode {
    match err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_)
        | WhitelistPreconfirmationDriverError::PreconfIngressNotReady
        | WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfIngressNotReady,
        )
        | WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(_)) => {
            StatusCode::BAD_REQUEST
        }
        _ => StatusCode::INTERNAL_SERVER_ERROR,
    }
}

async fn read_request_body<B>(body: B) -> std::result::Result<Vec<u8>, BoxError>
where
    B: http_body::Body<Data = bytes::Bytes> + Send + Unpin + 'static,
    B::Data: Send,
    B::Error: Into<BoxError>,
{
    let mut stream = BodyStream::new(body);
    let mut bytes = Vec::new();
    while let Some(frame) = stream.frame().await {
        let data = frame
            .map_err(Into::into)?
            .into_data()
            .map_err(|_| std::io::Error::other("unexpected non-data frame in request body"))?;
        bytes.extend_from_slice(&data);
    }
    Ok(bytes)
}

/// Builds the JSON-RPC module with all whitelist methods registered.
fn build_rpc_module(api: Arc<dyn WhitelistRpcApi>) -> RpcModule<RpcContext> {
    let mut module = RpcModule::new(RpcContext { api });

    rpc::register_rpc_method!(
        module,
        METHOD_BUILD_PRECONF_BLOCK,
        RpcContext,
        |params, ctx| {
            let request: BuildPreconfBlockRequest = params.one()?;
            ctx.api.build_preconf_block(request).await
        },
        record_metrics,
        api_error_to_rpc,
        "received whitelist RPC request"
    );

    rpc::register_rpc_method!(
        module,
        METHOD_GET_STATUS,
        RpcContext,
        |ctx| ctx.api.get_status().await,
        record_metrics,
        api_error_to_rpc,
        "received whitelist RPC request"
    );
    rpc::register_rpc_method!(
        module,
        METHOD_HEALTHZ,
        RpcContext,
        |ctx| ctx.api.healthz().await,
        record_metrics,
        api_error_to_rpc,
        "received whitelist RPC request"
    );

    module
}

/// Record request metrics for a single RPC call.
fn record_metrics<T>(method: &str, result: &Result<T>, duration_secs: f64) {
    histogram!(
        WhitelistPreconfirmationDriverMetrics::RPC_DURATION_SECONDS,
        "method" => method.to_string(),
    )
    .record(duration_secs);
    counter!(
        WhitelistPreconfirmationDriverMetrics::RPC_REQUESTS_TOTAL,
        "method" => method.to_string(),
    )
    .increment(1);

    if let Err(err) = result {
        counter!(
            WhitelistPreconfirmationDriverMetrics::RPC_ERRORS_TOTAL,
            "method" => method.to_string(),
        )
        .increment(1);
        warn!(method, ?err, duration_secs, "whitelist RPC request failed");
    }
}

/// Map a domain error into a JSON-RPC error object.
fn api_error_to_rpc(err: WhitelistPreconfirmationDriverError) -> ErrorObjectOwned {
    let code = match &err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_) => {
            WhitelistRpcErrorCode::InvalidPayload.code()
        }
        WhitelistPreconfirmationDriverError::Signing(_) => {
            WhitelistRpcErrorCode::SigningFailed.code()
        }
        WhitelistPreconfirmationDriverError::P2p(_) => WhitelistRpcErrorCode::PublishFailed.code(),
        WhitelistPreconfirmationDriverError::EventSyncerExited
        | WhitelistPreconfirmationDriverError::PreconfIngressNotReady
        | WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfIngressNotReady,
        )
        | WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(_)) => {
            WhitelistRpcErrorCode::NotSynced.code()
        }
        _ => WhitelistRpcErrorCode::InternalError.code(),
    };

    ErrorObjectOwned::owned(code, err.to_string(), None::<()>)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::rpc::types::{
        BuildPreconfBlockResponse, EndOfSequencingNotification, HealthResponse, WhitelistStatus,
    };
    use alloy_primitives::B256;
    use async_trait::async_trait;

    struct MockApi;

    #[async_trait]
    impl WhitelistRpcApi for MockApi {
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

        async fn healthz(&self) -> Result<HealthResponse> {
            Ok(HealthResponse { ok: true })
        }

        fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
            let (_tx, rx) = broadcast::channel(1);
            rx
        }
    }

    #[tokio::test]
    async fn server_start_stop() {
        let config = WhitelistRpcServerConfig {
            listen_addr: "127.0.0.1:0".parse().unwrap(),
            ..Default::default()
        };
        let api: Arc<dyn WhitelistRpcApi> = Arc::new(MockApi);

        let server = WhitelistRpcServer::start(config, api).await.expect("server should start");
        assert_eq!(server.local_addr().ip().to_string(), "127.0.0.1");
        assert_ne!(server.local_addr().port(), 0);
        assert!(server.http_url().starts_with("http://127.0.0.1:"));
        assert!(server.ws_url().starts_with("ws://127.0.0.1:"));
        server.stop().await;
    }

    #[test]
    fn default_config() {
        let config = WhitelistRpcServerConfig::default();
        assert_eq!(config.listen_addr.port(), 8552);
        assert!(config.enable_http);
        assert!(config.enable_ws);
        assert!(config.jwt_secret.is_none());
    }

    #[test]
    fn error_code_mapping() {
        let err = WhitelistPreconfirmationDriverError::InvalidPayload("bad".to_string());
        let rpc_err = api_error_to_rpc(err);
        assert_eq!(rpc_err.code(), WhitelistRpcErrorCode::InvalidPayload.code());

        let err = WhitelistPreconfirmationDriverError::Signing("fail".to_string());
        let rpc_err = api_error_to_rpc(err);
        assert_eq!(rpc_err.code(), WhitelistRpcErrorCode::SigningFailed.code());

        let err = WhitelistPreconfirmationDriverError::P2p("network".to_string());
        let rpc_err = api_error_to_rpc(err);
        assert_eq!(rpc_err.code(), WhitelistRpcErrorCode::PublishFailed.code());

        let err = WhitelistPreconfirmationDriverError::EventSyncerExited;
        let rpc_err = api_error_to_rpc(err);
        assert_eq!(rpc_err.code(), WhitelistRpcErrorCode::NotSynced.code());

        let err = WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfIngressNotReady,
        );
        let rpc_err = api_error_to_rpc(err);
        assert_eq!(rpc_err.code(), WhitelistRpcErrorCode::NotSynced.code());
    }
}
