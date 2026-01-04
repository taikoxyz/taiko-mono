//! In-process P2P sidecar for preconfirmation ingestion.

pub mod config;
pub mod engine;
pub mod runner;
pub mod types;

pub use config::P2pSidecarConfig;
pub use engine::SidecarPreconfEngine;
pub use runner::P2pSidecar;
pub use types::{CanonicalOutcome, ConfirmationDecision, PendingPreconf};
