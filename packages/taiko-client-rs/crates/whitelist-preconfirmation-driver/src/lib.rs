#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Whitelist preconfirmation driver integration.

mod api;
mod cache;
/// Shared core helpers for whitelist preconfirmation orchestration.
mod core {
    pub(crate) mod authority;
    pub(crate) mod build;
    pub(crate) mod import;
    pub(crate) mod pending;
    pub(crate) mod state;
}
mod error;
mod importer;
pub mod metrics;
mod network;
mod runner;
mod tx_list_codec;
/// Frozen wire-contract definitions for Go-compatible gossipsub topics.
mod wire;

pub use error::{Result, WhitelistPreconfirmationDriverError};
pub use metrics::WhitelistPreconfirmationDriverMetrics;
pub use runner::{RunnerConfig, WhitelistPreconfirmationDriverRunner};
pub(crate) use wire::codec;
