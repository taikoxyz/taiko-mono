//! HTTP JSON-RPC server for the preconfirmation driver node.

use std::{net::SocketAddr, sync::Arc, time::Instant};

use jsonrpsee::{
    RpcModule,
    server::{ServerBuilder, ServerHandle},
    types::{ErrorObjectOwned, Params},
};
use metrics::{counter, histogram};
use tracing::{debug, info, warn};

use super::{
    PreconfRpcApi, PublishCommitmentRequest, PublishTxListRequest, types::PreconfRpcErrorCode,
};
use crate::{Result, error::PreconfirmationClientError};

/// JSON-RPC method name for publishing commitments.
const METHOD_PUBLISH_COMMITMENT: &str = "preconf_publishCommitment";
/// JSON-RPC method name for publishing txlists.
const METHOD_PUBLISH_TX_LIST: &str = "preconf_publishTxList";
/// JSON-RPC method name for querying node status.
const METHOD_GET_STATUS: &str = "preconf_getStatus";
/// JSON-RPC method name for querying the current head.
const METHOD_GET_HEAD: &str = "preconf_getHead";
/// JSON-RPC method name for querying the preconfirmation tip.
const METHOD_PRECONF_TIP: &str = "preconf_tip";
/// JSON-RPC method name for querying the canonical proposal ID.
const METHOD_CANONICAL_PROPOSAL_ID: &str = "preconf_canonicalProposalId";

/// Metric name for total RPC requests.
const METRIC_REQUESTS_TOTAL: &str = "preconf_rpc_requests_total";
/// Metric name for total RPC errors.
const METRIC_ERRORS_TOTAL: &str = "preconf_rpc_errors_total";
/// Metric name for RPC duration histogram.
const METRIC_DURATION_SECONDS: &str = "preconf_rpc_duration_seconds";

/// Configuration for the preconfirmation RPC server.
#[derive(Debug, Clone)]
pub struct PreconfRpcServerConfig {
    /// Socket address to listen on (e.g., "127.0.0.1:8550").
    pub listen_addr: SocketAddr,
}

impl Default for PreconfRpcServerConfig {
    /// Build the default RPC server configuration.
    fn default() -> Self {
        Self { listen_addr: "127.0.0.1:8550".parse().expect("valid default address") }
    }
}

/// Running HTTP JSON-RPC server for preconfirmation operations.
#[derive(Debug)]
pub struct PreconfRpcServer {
    /// Socket address bound by the server.
    addr: SocketAddr,
    /// Handle used to control server lifecycle.
    handle: ServerHandle,
}

impl PreconfRpcServer {
    /// Start the HTTP JSON-RPC server.
    pub async fn start(
        config: PreconfRpcServerConfig,
        api: Arc<dyn PreconfRpcApi>,
    ) -> Result<Self> {
        let server = ServerBuilder::new().build(config.listen_addr).await.map_err(|e| {
            PreconfirmationClientError::Config(format!("failed to bind server: {e}"))
        })?;

        let addr = server.local_addr().map_err(|e| {
            PreconfirmationClientError::Config(format!("failed to get local addr: {e}"))
        })?;

        let handle = server.start(build_rpc_module(api));

        info!(addr = %addr, "started preconfirmation RPC server");
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

    /// Stop the server gracefully.
    pub async fn stop(self) {
        if let Err(err) = self.handle.stop() {
            warn!(error = %err, "preconfirmation RPC server already stopped");
        }
        let _ = self.handle.stopped().await;
        info!("preconfirmation RPC server stopped");
    }
}

/// Macro to register an RPC method with metrics and error handling.
macro_rules! register_method {
    // For methods that take a parameter
    ($module:expr, $method:expr, |$params:ident, $ctx:ident| $call:expr) => {
        $module
            .register_async_method(
                $method,
                |$params: Params<'static>, $ctx: Arc<RpcContext>, _| async move {
                    let start = Instant::now();
                    debug!(method = $method, "received preconfirmation RPC request");
                    let result = $call;
                    record_metrics($method, &result, start.elapsed().as_secs_f64());
                    result.map_err(api_error_to_rpc)
                },
            )
            .expect("method registration should succeed");
    };
    // For methods without parameters
    ($module:expr, $method:expr, |$ctx:ident| $call:expr) => {
        $module
            .register_async_method(
                $method,
                |_: Params<'static>, $ctx: Arc<RpcContext>, _| async move {
                    let start = Instant::now();
                    debug!(method = $method, "received preconfirmation RPC request");
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
    api: Arc<dyn PreconfRpcApi>,
}

/// Builds the JSON-RPC module with all preconfirmation methods registered.
fn build_rpc_module(api: Arc<dyn PreconfRpcApi>) -> RpcModule<RpcContext> {
    let mut module = RpcModule::new(RpcContext { api });

    register_method!(module, METHOD_PUBLISH_COMMITMENT, |params, ctx| {
        let request: PublishCommitmentRequest = params.one()?;
        ctx.api.publish_commitment(request).await
    });

    register_method!(module, METHOD_PUBLISH_TX_LIST, |params, ctx| {
        let request: PublishTxListRequest = params.one()?;
        ctx.api.publish_tx_list(request).await
    });

    register_method!(module, METHOD_GET_STATUS, |ctx| ctx.api.get_status().await);
    register_method!(module, METHOD_GET_HEAD, |ctx| ctx.api.get_head().await);
    register_method!(module, METHOD_PRECONF_TIP, |ctx| ctx.api.preconf_tip().await);
    register_method!(module, METHOD_CANONICAL_PROPOSAL_ID, |ctx| ctx
        .api
        .canonical_proposal_id()
        .await);

    module
}

/// Records Prometheus metrics for an RPC request (duration, request count, error count).
/// Record request metrics for a single RPC call.
fn record_metrics<T>(method: &str, result: &Result<T>, duration_secs: f64) {
    histogram!(METRIC_DURATION_SECONDS, "method" => method.to_string()).record(duration_secs);
    counter!(METRIC_REQUESTS_TOTAL, "method" => method.to_string()).increment(1);

    if let Err(err) = result {
        counter!(METRIC_ERRORS_TOTAL, "method" => method.to_string()).increment(1);
        warn!(method, ?err, duration_secs, "RPC request failed");
    }
}

/// Converts a preconfirmation client error to a JSON-RPC error object.
/// Map a domain error into a JSON-RPC error object.
fn api_error_to_rpc(err: PreconfirmationClientError) -> ErrorObjectOwned {
    use PreconfRpcErrorCode::*;
    use PreconfirmationClientError::*;

    let code = match &err {
        Validation(_) => InvalidCommitment,
        Codec(_) => InvalidTxList,
        Catchup(_) => NotSynced,
        Lookahead(_) => InvalidSigner,
        Network(_) | Storage(_) | DriverInterface(_) | Config(_) => InternalError,
    };

    ErrorObjectOwned::owned(code.code(), err.to_string(), None::<()>)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::rpc::types::{
        NodeStatus, PreconfHead, PublishCommitmentResponse, PublishTxListResponse,
    };
    use alloy_primitives::{B256, U256};
    use async_trait::async_trait;

    /// Mock API implementation for testing.
    struct MockApi;

    #[async_trait]
    impl PreconfRpcApi for MockApi {
        async fn publish_commitment(
            &self,
            _request: PublishCommitmentRequest,
        ) -> Result<PublishCommitmentResponse> {
            Ok(PublishCommitmentResponse { commitment_hash: B256::ZERO, tx_list_hash: B256::ZERO })
        }

        async fn publish_tx_list(
            &self,
            _request: PublishTxListRequest,
        ) -> Result<PublishTxListResponse> {
            Ok(PublishTxListResponse { tx_list_hash: B256::ZERO })
        }

        async fn get_status(&self) -> Result<NodeStatus> {
            Ok(NodeStatus {
                is_synced_with_inbox: true,
                preconf_tip: U256::from(100),
                canonical_proposal_id: 42,
                peer_count: 5,
                peer_id: "test-peer".to_string(),
            })
        }

        async fn get_head(&self) -> Result<PreconfHead> {
            Ok(PreconfHead {
                block_number: U256::from(100),
                submission_window_end: U256::from(1000),
            })
        }

        async fn preconf_tip(&self) -> Result<U256> {
            Ok(U256::from(100))
        }

        async fn canonical_proposal_id(&self) -> Result<u64> {
            Ok(42)
        }
    }

    /// Test that the server can start and stop.
    #[tokio::test]
    async fn test_server_start_stop() {
        let config = PreconfRpcServerConfig { listen_addr: "127.0.0.1:0".parse().unwrap() };
        let api: Arc<dyn PreconfRpcApi> = Arc::new(MockApi);

        let server = PreconfRpcServer::start(config, api).await.expect("server should start");
        assert!(server.http_url().starts_with("http://127.0.0.1:"));

        server.stop().await;
    }

    /// Test the default configuration.
    #[test]
    fn test_default_config() {
        let config = PreconfRpcServerConfig::default();
        assert_eq!(config.listen_addr.port(), 8550);
    }
}
