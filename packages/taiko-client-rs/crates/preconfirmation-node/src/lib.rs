//! Preconfirmation node SDK.
//!
//! This crate provides an embedded preconfirmation node SDK for participating in the
//! Taiko preconfirmation P2P network. It handles:
//! - P2P tip catch-up after normal L2 sync
//! - Subscribing to and publishing preconfirmation messages
//! - Validating commitments and transaction lists
//! - Passing validated preconfirmation inputs to the driver for ordered processing
//! - Hosting a user-facing JSON-RPC server for publishing and querying preconfirmations

/// Main client orchestrator.
pub mod client;
/// Txlist codec utilities.
pub mod codec;
/// Client configuration types.
pub mod config;
/// Driver integration traits.
pub mod driver_interface;
/// Error types surfaced by the SDK.
pub mod error;
/// Metrics exposed by the preconfirmation client.
pub mod metrics;
/// Preconfirmation node orchestration.
pub mod node;
/// User-facing JSON-RPC server.
pub mod rpc;
/// Storage helpers for commitments and txlists.
pub mod storage;
/// Subscription/event handling for inbound gossip.
pub mod subscription;
/// Tip catch-up helpers.
pub mod sync;
/// Validation rules for commitments and txlists.
pub mod validation;

pub use client::{EventLoop, PreconfirmationClient};
pub use config::PreconfirmationClientConfig;
pub use driver_interface::{DriverClient, EmbeddedDriverClient, PreconfirmationInput};
pub use error::{DriverApiError, PreconfirmationClientError, PreconfirmationNodeError, Result};
pub use metrics::PreconfirmationClientMetrics;
pub use node::{PreconfirmationNode, PreconfirmationNodeConfig};
pub use rpc::{PreconfRpcApiImpl, PreconfRpcServer, RpcServerConfig};
