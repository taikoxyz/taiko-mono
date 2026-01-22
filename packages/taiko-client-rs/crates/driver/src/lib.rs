//! Taiko Shasta driver implementation.
//!
//! This crate provides the driver component responsible for:
//! - Syncing with L1 beacon chain for checkpoint sync
//! - Processing L1 inbox events to derive L2 blocks
//! - Handling preconfirmation payloads for block production

pub mod config;
pub mod derivation;
pub mod driver;
pub mod error;
pub mod metrics;
pub mod production;
pub mod sync;

pub use config::DriverConfig;
pub use driver::Driver;
pub use error::DriverError;
pub use production::PreconfPayload;
pub use sync::{SyncPipeline, SyncStage, event::EventSyncer};

// Re-export signer from protocol crate for backward compatibility
pub use protocol::signer;
