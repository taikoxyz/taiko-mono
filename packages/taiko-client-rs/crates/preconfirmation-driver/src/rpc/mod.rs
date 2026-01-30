//! Preconfirmation sidecar JSON-RPC API for the preconfirmation driver node.
//!
//! This module provides a preconfirmation sidecar JSON-RPC interface for interacting
//! with the preconfirmation driver node. Unlike the internal driver RPC which accepts
//! raw `TaikoPayloadAttributes`, this API accepts higher-level requests
//! that are easier for external clients to construct.
//!
//! # API Methods
//!
//! - `preconf_publishCommitment`: Publish a signed preconfirmation commitment
//! - `preconf_publishTxList`: Publish an encoded transaction list (RLP + zlib)
//! - `preconf_getStatus`: Get current node status
//!
//! # Example
//!
//! ```ignore
//! use preconfirmation_driver::rpc::{PreconfRpcServer, PreconfRpcServerConfig};
//!
//! let config = PreconfRpcServerConfig {
//!     listen_addr: "127.0.0.1:8550".parse()?,
//! };
//! let server = PreconfRpcServer::start(config, api_impl).await?;
//! ```

/// API trait and implementation.
pub mod api;
pub(crate) mod node_api;
/// RPC server implementation.
pub mod server;
/// Request and response types.
pub mod types;

pub use api::PreconfRpcApi;
pub use server::{PreconfRpcServer, PreconfRpcServerConfig};
pub use types::{
    NodeStatus, PreconfRpcErrorCode, PublishCommitmentRequest, PublishCommitmentResponse,
    PublishTxListRequest, PublishTxListResponse,
};

#[cfg(test)]
mod tests {
    use super::node_api;

    #[test]
    fn node_api_module_exists() {
        let _ = core::mem::size_of::<Option<fn()>>();
        let _ = &node_api::NODE_RPC_API_MARKER;
    }
}
