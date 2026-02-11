//! HTTP JSON-RPC server for the preconfirmation driver node.

use std::{net::SocketAddr, sync::Arc};

use jsonrpsee::{
    RpcModule,
    server::{ServerBuilder, ServerHandle},
    types::{ErrorCode, ErrorObjectOwned},
};
use metrics::{counter, histogram};
use protocol::preconfirmation::LookaheadError;
use tracing::{info, warn};

use super::{
    PreconfRpcApi, PublishCommitmentRequest, PublishTxListRequest, types::PreconfRpcErrorCode,
};
use crate::{Result, error::PreconfirmationClientError};

/// JSON-RPC method name for publishing commitments.
pub const METHOD_PUBLISH_COMMITMENT: &str = "preconf_publishCommitment";
/// JSON-RPC method name for publishing txlists.
pub const METHOD_PUBLISH_TX_LIST: &str = "preconf_publishTxList";
/// JSON-RPC method name for querying node status.
pub const METHOD_GET_STATUS: &str = "preconf_getStatus";
/// JSON-RPC method name for querying the preconfirmation tip.
pub const METHOD_PRECONF_TIP: &str = "preconf_tip";
/// JSON-RPC method name for querying the canonical proposal ID.
pub const METHOD_CANONICAL_PROPOSAL_ID: &str = "preconf_canonicalProposalId";
/// JSON-RPC method name for querying preconfirmation slot info by timestamp.
pub const METHOD_GET_PRECONF_SLOT_INFO: &str = "preconf_getPreconfSlotInfo";

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

/// Internal context passed to all RPC method handlers.
#[derive(Clone)]
struct RpcContext {
    /// The API implementation backing RPC calls.
    api: Arc<dyn PreconfRpcApi>,
}

/// Builds the JSON-RPC module with all preconfirmation methods registered.
fn build_rpc_module(api: Arc<dyn PreconfRpcApi>) -> RpcModule<RpcContext> {
    let mut module = RpcModule::new(RpcContext { api });

    rpc::register_rpc_method!(
        module,
        METHOD_PUBLISH_COMMITMENT,
        RpcContext,
        |params, ctx| {
            let request: PublishCommitmentRequest = params.one()?;
            ctx.api.publish_commitment(request).await
        },
        record_metrics,
        api_error_to_rpc,
        "received preconfirmation RPC request"
    );

    rpc::register_rpc_method!(
        module,
        METHOD_PUBLISH_TX_LIST,
        RpcContext,
        |params, ctx| {
            let request: PublishTxListRequest = params.one()?;
            ctx.api.publish_tx_list(request).await
        },
        record_metrics,
        api_error_to_rpc,
        "received preconfirmation RPC request"
    );

    rpc::register_rpc_method!(
        module,
        METHOD_GET_STATUS,
        RpcContext,
        |ctx| ctx.api.get_status().await,
        record_metrics,
        api_error_to_rpc,
        "received preconfirmation RPC request"
    );
    rpc::register_rpc_method!(
        module,
        METHOD_PRECONF_TIP,
        RpcContext,
        |ctx| ctx.api.preconf_tip().await,
        record_metrics,
        api_error_to_rpc,
        "received preconfirmation RPC request"
    );
    rpc::register_rpc_method!(
        module,
        METHOD_CANONICAL_PROPOSAL_ID,
        RpcContext,
        |ctx| ctx.api.canonical_proposal_id().await,
        record_metrics,
        api_error_to_rpc,
        "received preconfirmation RPC request"
    );
    rpc::register_rpc_method!(
        module,
        METHOD_GET_PRECONF_SLOT_INFO,
        RpcContext,
        |params, ctx| {
            let timestamp: alloy_primitives::U256 = params.one()?;
            ctx.api.get_preconf_slot_info(timestamp).await
        },
        record_metrics,
        api_error_to_rpc,
        "received preconfirmation RPC request"
    );

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
    let code = match &err {
        PreconfirmationClientError::Validation(_) => PreconfRpcErrorCode::InvalidCommitment.code(),
        PreconfirmationClientError::Codec(_) => PreconfRpcErrorCode::InvalidTxList.code(),
        PreconfirmationClientError::Catchup(_) => PreconfRpcErrorCode::NotSynced.code(),
        PreconfirmationClientError::Lookahead(lookahead_err) => match lookahead_err {
            LookaheadError::BeforeGenesis(_) |
            LookaheadError::TooOld(_) |
            LookaheadError::TooNew(_) => ErrorCode::InvalidParams.code(),
            LookaheadError::InboxConfig(_) |
            LookaheadError::Lookahead(_) |
            LookaheadError::PreconfWhitelist(_) |
            LookaheadError::BlockLookup { .. } |
            LookaheadError::MissingLogField { .. } |
            LookaheadError::EventDecode(_) |
            LookaheadError::EventScanner(_) |
            LookaheadError::ReorgDetected |
            LookaheadError::SystemTime(_) |
            LookaheadError::UnknownChain(_) |
            LookaheadError::MissingLookahead(_) |
            LookaheadError::CorruptLookaheadCache { .. } => {
                PreconfRpcErrorCode::LookaheadUnavailable.code()
            }
        },
        PreconfirmationClientError::Network(_) |
        PreconfirmationClientError::Storage(_) |
        PreconfirmationClientError::DriverInterface(_) |
        PreconfirmationClientError::Config(_) => PreconfRpcErrorCode::InternalError.code(),
    };

    ErrorObjectOwned::owned(code, err.to_string(), None::<()>)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        error::PreconfirmationClientError,
        rpc::types::{
            NodeStatus, PreconfSlotInfo, PublishCommitmentResponse, PublishTxListResponse,
        },
    };
    use alloy_primitives::{B256, U256};
    use async_trait::async_trait;
    use jsonrpsee::types::error::ErrorCode;
    use protocol::preconfirmation::LookaheadError;

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

        async fn preconf_tip(&self) -> Result<U256> {
            Ok(U256::from(100))
        }

        async fn canonical_proposal_id(&self) -> Result<u64> {
            Ok(42)
        }

        async fn get_preconf_slot_info(&self, _timestamp: U256) -> Result<PreconfSlotInfo> {
            Ok(PreconfSlotInfo {
                signer: alloy_primitives::Address::repeat_byte(0x11),
                submission_window_end: U256::from(2000),
            })
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

    #[test]
    fn test_lookahead_timestamp_bounds_map_to_invalid_params() {
        let errors = [
            LookaheadError::BeforeGenesis(100),
            LookaheadError::TooOld(100),
            LookaheadError::TooNew(100),
        ];

        for err in errors {
            let rpc_error = api_error_to_rpc(PreconfirmationClientError::from(err));
            assert_eq!(rpc_error.code(), ErrorCode::InvalidParams.code());
        }
    }

    #[test]
    fn test_non_timestamp_lookahead_errors_map_to_lookahead_unavailable() {
        let errors = [
            LookaheadError::MissingLookahead(100),
            LookaheadError::UnknownChain(167_001),
            LookaheadError::ReorgDetected,
        ];

        for err in errors {
            let rpc_error = api_error_to_rpc(PreconfirmationClientError::from(err));
            assert_eq!(rpc_error.code(), PreconfRpcErrorCode::LookaheadUnavailable.code());
        }
    }
}
