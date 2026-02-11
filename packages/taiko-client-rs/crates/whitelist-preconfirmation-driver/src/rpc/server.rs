//! JSON-RPC server for the whitelist preconfirmation driver.

use std::{net::SocketAddr, sync::Arc};

use jsonrpsee::{
    RpcModule,
    server::{ServerBuilder, ServerHandle},
    types::ErrorObjectOwned,
};
use metrics::{counter, histogram};
use tracing::{info, warn};

use super::{WhitelistRpcApi, types::WhitelistRpcErrorCode};
use crate::{
    Result, error::WhitelistPreconfirmationDriverError,
    metrics::WhitelistPreconfirmationDriverMetrics, rpc::types::BuildPreconfBlockRequest,
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
}

impl Default for WhitelistRpcServerConfig {
    fn default() -> Self {
        Self { listen_addr: "127.0.0.1:8552".parse().expect("valid default address") }
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
    _handle: ServerHandle,
}

impl WhitelistRpcServer {
    /// Start the JSON-RPC server.
    pub async fn start(
        config: WhitelistRpcServerConfig,
        api: Arc<dyn WhitelistRpcApi>,
    ) -> Result<Self> {
        let server = ServerBuilder::new().build(config.listen_addr).await.map_err(|e| {
            WhitelistPreconfirmationDriverError::RpcServerBind {
                listen_addr: config.listen_addr,
                reason: e.to_string(),
            }
        })?;

        let addr = server.local_addr().map_err(|e| {
            WhitelistPreconfirmationDriverError::RpcServerLocalAddr { reason: e.to_string() }
        })?;

        let handle = server.start(build_rpc_module(api));

        info!(
            addr = %addr,
            http_url = %format!("http://{addr}"),
            ws_url = %format!("ws://{addr}"),
            "started whitelist preconfirmation RPC server"
        );
        Ok(Self { addr, _handle: handle })
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
}

/// Internal context passed to all RPC method handlers.
#[derive(Clone)]
struct RpcContext {
    /// The API implementation backing RPC calls.
    api: Arc<dyn WhitelistRpcApi>,
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
    use crate::rpc::types::{BuildPreconfBlockResponse, HealthResponse, WhitelistStatus};
    use alloy_primitives::B256;
    use async_trait::async_trait;

    struct MockApi;

    #[async_trait]
    impl WhitelistRpcApi for MockApi {
        async fn build_preconf_block(
            &self,
            _request: BuildPreconfBlockRequest,
        ) -> Result<BuildPreconfBlockResponse> {
            Ok(BuildPreconfBlockResponse { block_hash: B256::ZERO, block_number: 1 })
        }

        async fn get_status(&self) -> Result<WhitelistStatus> {
            Ok(WhitelistStatus {
                head_l1_origin_block_id: Some(42),
                highest_unsafe_block_number: Some(100),
                peer_id: "test-peer".to_string(),
                sync_ready: true,
            })
        }

        async fn healthz(&self) -> Result<HealthResponse> {
            Ok(HealthResponse { ok: true })
        }
    }

    #[tokio::test]
    async fn server_start_stop() {
        let config = WhitelistRpcServerConfig { listen_addr: "127.0.0.1:0".parse().unwrap() };
        let api: Arc<dyn WhitelistRpcApi> = Arc::new(MockApi);

        let server = WhitelistRpcServer::start(config, api).await.expect("server should start");
        assert_eq!(server.local_addr().ip().to_string(), "127.0.0.1");
        assert_ne!(server.local_addr().port(), 0);
        assert!(server.http_url().starts_with("http://127.0.0.1:"));
        assert!(server.ws_url().starts_with("ws://127.0.0.1:"));
    }

    #[test]
    fn default_config() {
        let config = WhitelistRpcServerConfig::default();
        assert_eq!(config.listen_addr.port(), 8552);
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
