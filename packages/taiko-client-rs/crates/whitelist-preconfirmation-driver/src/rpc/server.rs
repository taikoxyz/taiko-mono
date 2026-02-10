//! HTTP JSON-RPC server for the whitelist preconfirmation driver.

use std::{net::SocketAddr, sync::Arc, time::Instant};

use jsonrpsee::{
    RpcModule,
    server::{ServerBuilder, ServerHandle},
    types::{ErrorObjectOwned, Params},
};
use metrics::{counter, histogram};
use tracing::{debug, info, warn};

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

/// Running HTTP JSON-RPC server for whitelist preconfirmation operations.
#[derive(Debug)]
pub struct WhitelistRpcServer {
    /// Socket address bound by the server.
    addr: SocketAddr,
    /// Handle used to control server lifecycle.
    handle: ServerHandle,
}

impl WhitelistRpcServer {
    /// Start the HTTP JSON-RPC server.
    pub async fn start(
        config: WhitelistRpcServerConfig,
        api: Arc<dyn WhitelistRpcApi>,
    ) -> Result<Self> {
        let server = ServerBuilder::new().build(config.listen_addr).await.map_err(|e| {
            WhitelistPreconfirmationDriverError::RpcServer(format!("failed to bind server: {e}"))
        })?;

        let addr = server.local_addr().map_err(|e| {
            WhitelistPreconfirmationDriverError::RpcServer(format!("failed to get local addr: {e}"))
        })?;

        let handle = server.start(build_rpc_module(api));

        info!(addr = %addr, "started whitelist preconfirmation RPC server");
        Ok(Self { addr, handle })
    }

    /// Return the bound socket address.
    pub const fn local_addr(&self) -> SocketAddr {
        self.addr
    }

    /// Return the HTTP URL for this server.
    #[allow(dead_code)]
    pub fn http_url(&self) -> String {
        format!("http://{}", self.addr)
    }

    /// Stop the server gracefully.
    #[allow(dead_code)]
    pub async fn stop(self) {
        if let Err(err) = self.handle.stop() {
            warn!(error = %err, "whitelist preconfirmation RPC server already stopped");
        }
        let _ = self.handle.stopped().await;
        info!("whitelist preconfirmation RPC server stopped");
    }
}

/// Macro to register an RPC method with metrics and error handling.
macro_rules! register_method {
    ($module:expr, $method:expr, |$params:ident, $ctx:ident| $call:expr) => {
        $module
            .register_async_method(
                $method,
                |$params: Params<'static>, $ctx: Arc<RpcContext>, _| async move {
                    let start = Instant::now();
                    debug!(method = $method, "received whitelist RPC request");
                    let result = $call;
                    record_metrics($method, &result, start.elapsed().as_secs_f64());
                    result.map_err(api_error_to_rpc)
                },
            )
            .expect("method registration should succeed");
    };
    ($module:expr, $method:expr, |$ctx:ident| $call:expr) => {
        $module
            .register_async_method(
                $method,
                |_: Params<'static>, $ctx: Arc<RpcContext>, _| async move {
                    let start = Instant::now();
                    debug!(method = $method, "received whitelist RPC request");
                    let result = $call;
                    record_metrics($method, &result, start.elapsed().as_secs_f64());
                    result.map_err(api_error_to_rpc)
                },
            )
            .expect("method registration should succeed");
    };
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

    register_method!(module, METHOD_BUILD_PRECONF_BLOCK, |params, ctx| {
        let request: BuildPreconfBlockRequest = params.one()?;
        ctx.api.build_preconf_block(request).await
    });

    register_method!(module, METHOD_GET_STATUS, |ctx| ctx.api.get_status().await);
    register_method!(module, METHOD_HEALTHZ, |ctx| ctx.api.healthz().await);

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
        WhitelistPreconfirmationDriverError::EventSyncerExited |
        WhitelistPreconfirmationDriverError::PreconfIngressNotReady |
        WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfIngressNotReady,
        ) |
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(_)) => {
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
        assert!(server.http_url().starts_with("http://127.0.0.1:"));

        server.stop().await;
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
