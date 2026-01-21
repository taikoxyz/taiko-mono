//! User-facing JSON-RPC API for the preconfirmation node.
//!
//! This module provides a user-friendly RPC interface for interacting with
//! the preconfirmation node. Unlike the internal driver RPC which accepts
//! raw `TaikoPayloadAttributes`, this API accepts higher-level requests
//! that are easier for external clients to construct.
//!
//! # API Methods
//!
//! - `preconf_publishCommitment`: Publish a signed preconfirmation commitment
//! - `preconf_publishTxList`: Publish a raw transaction list
//! - `preconf_getStatus`: Get current node status
//! - `preconf_getHead`: Get the current preconfirmation head
//! - `preconf_getLookahead`: Get current lookahead information
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
/// RPC server implementation.
pub mod server;
/// Request and response types.
pub mod types;

pub use api::PreconfRpcApi;
pub use server::{PreconfRpcServer, PreconfRpcServerConfig};
pub use types::{
    LookaheadInfo, NodeStatus, PreconfHead, PreconfRpcErrorCode, PublishCommitmentRequest,
    PublishCommitmentResponse, PublishTxListRequest, PublishTxListResponse,
};
