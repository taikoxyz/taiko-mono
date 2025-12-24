//! P2P SDK for the permissionless preconfirmation networking stack.
//!
//! This crate provides a high-level SDK façade over `preconfirmation-net`, layering
//! SDK storage/dedupe/validation, a catch-up pipeline, and a typed event API.
//!
//! Network-level validation is provided by `preconfirmation-net` adapters; this SDK
//! adds spec-required invariants (parent linkage, pending buffering, EOP rules,
//! block parameter progression) before surfacing events or storing locally.

#![deny(missing_docs)]

mod config;
mod error;
pub mod storage;
mod types;

pub use config::P2pClientConfig;
pub use error::{P2pClientError, P2pResult};
// Re-export key network types so consumers can depend on this crate alone.
pub use preconfirmation_net::{
    LookaheadResolver, NetworkCommand, NetworkError, NetworkErrorKind, NetworkEvent, P2pConfig,
    P2pHandle, P2pNode, PreconfStorage,
};
pub use preconfirmation_types;
pub use types::{SdkCommand, SdkEvent};
