//! P2P SDK wrapper for the permissionless preconfirmation networking stack.
//!
//! This crate provides a sidecar-friendly façade over the `preconfirmation-service`
//! networking layer. It will grow orchestration for bootstrap catch-up, validation,
//! storage, and metrics. Currently it exposes the basic types and stubbed structs
//! needed to compile while the full implementation is developed.

pub mod config;
pub mod error;
pub mod types;
pub mod storage;
pub mod resolver;
pub mod validation;
pub mod sdk;
pub mod catchup;
pub mod handlers;
pub mod metrics;

pub use crate::config::P2pSdkConfig;
pub use crate::error::{P2pSdkError, Result};
pub use crate::sdk::P2pSdk;
pub use crate::types::{HeadSyncStatus, SdkCommand, SdkEvent};

// Re-export key network types so consumers can depend on this crate alone.
pub use preconfirmation_service::{
    LookaheadResolver, NetworkCommand, NetworkConfig, NetworkEvent, NetworkError,
    NetworkErrorKind, P2pService, PreconfStorage,
};
pub use preconfirmation_types;

