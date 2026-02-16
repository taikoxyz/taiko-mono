#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Taiko Shasta driver implementation.
//!
//! This crate provides the driver component responsible for:
//! - Syncing with L1 beacon chain for checkpoint sync
//! - Processing L1 inbox events to derive L2 blocks
//! - Handling preconfirmation payloads for block production

/// Driver runtime configuration types.
pub mod config;
/// L1-to-L2 derivation pipelines and manifest handling.
pub mod derivation;
/// Top-level driver orchestration loop.
pub mod driver;
/// Driver-specific error types and conversions.
pub mod error;
/// Metrics emitted by the driver.
pub mod metrics;
/// Production path routing and payload wrappers.
pub mod production;
/// Synchronization stages and event scanning.
pub mod sync;

pub use config::DriverConfig;
pub use driver::Driver;
pub use error::{DriverError, map_driver_error};
pub use production::PreconfPayload;
pub use sync::{CanonicalTipState, SyncPipeline, SyncStage, event::EventSyncer};

// Re-export signer from protocol crate for backward compatibility
pub use protocol::signer;
