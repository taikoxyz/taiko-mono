//! Preconfirmation client SDK.
//!
//! This crate provides a sidecar SDK for participating in the Taiko preconfirmation
//! P2P network. It handles:
//! - P2P tip catch-up after normal L2 sync
//! - Subscribing to and publishing preconfirmation messages
//! - Validating commitments and transaction lists
//! - Passing validated preconfirmation inputs to the driver for ordered processing

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
/// Storage helpers for commitments and txlists.
pub mod storage;
/// Subscription/event handling for inbound gossip.
pub mod subscription;
/// Tip catch-up helpers.
pub mod sync;
/// Validation rules for commitments and txlists.
pub mod validation;

pub use client::PreconfirmationClient;
pub use config::PreconfirmationClientConfig;
pub use driver_interface::{DriverClient, PreconfirmationInput};
pub use error::{PreconfirmationClientError, Result};
