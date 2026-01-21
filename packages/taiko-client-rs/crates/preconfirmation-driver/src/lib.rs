//! Preconfirmation driver integration library.
//!
//! This crate provides the preconfirmation integration layer for the Taiko driver.
//! It combines P2P network participation with embedded driver communication via channels.
//!
//! # Architecture
//!
//! The preconfirmation driver consists of:
//!
//! - **PreconfirmationClient**: Handles P2P network operations including gossip, commitment
//!   validation, and tip catch-up.
//!
//! - **EmbeddedDriverClient**: Communicates directly with the driver via channels, bypassing
//!   JSON-RPC serialization.
//!
//! - **PreconfRpcServer**: Exposes a user-friendly JSON-RPC API for external clients to submit
//!   preconfirmations.
//!
//! # Features
//!
//! - P2P tip catch-up after normal L2 sync
//! - Subscribing to and publishing preconfirmation messages
//! - Validating commitments and transaction lists
//! - Passing validated preconfirmation inputs to the driver for ordered processing
//! - User-facing RPC API for commitment publication

/// Main client orchestrator.
pub mod client;
/// Txlist codec utilities.
pub mod codec;
/// Client configuration types.
pub mod config;
/// Driver integration traits and clients.
pub mod driver_interface;
/// Error types.
pub mod error;
/// Metrics exposed by the preconfirmation node.
pub mod metrics;
/// Preconfirmation node combining all components.
pub mod node;
/// User-facing JSON-RPC API.
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
pub use error::{DriverApiError, PreconfirmationClientError, Result};
pub use metrics::PreconfirmationClientMetrics;
pub use node::{DriverChannels, PreconfirmationNode, PreconfirmationNodeConfig};
pub use rpc::{PreconfRpcApi, PreconfRpcServer, PreconfRpcServerConfig};
