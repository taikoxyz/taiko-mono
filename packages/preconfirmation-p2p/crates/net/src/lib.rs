//! Networking layer for the preconfirmation P2P stack.
//!
//! This crate wires libp2p + discv5 into a small, service-friendly API. It provides:
//! - Transport/builder for libp2p (TCP/QUIC-ready) and a combined behaviour (ping, identify,
//!   gossipsub, request-response, gating).
//! - Discovery scaffold (backed by `reth-discv5` when enabled).
//! - Reputation + per-peer fixed-window request rate limiting (default 10s window / 8 requests;
//!   Kona mesh/score defaults).
//! - Driver emitting `NetworkEvent`s and receiving `NetworkCommand`s for the service facade.

mod behaviour;
mod builder;
mod codec;
mod command;
mod config;
mod discovery;
mod driver;
pub mod event;
mod handle;
mod node;
mod reputation;
mod storage;
mod validation;

pub use command::NetworkCommand;
pub use config::{NetworkConfig, P2pConfig, RateLimitConfig};
pub use discovery::spawn_discovery;
pub use driver::{NetworkDriver, NetworkHandle};
pub use event::{NetworkError, NetworkErrorKind, NetworkEvent};
pub use handle::P2pHandle;
pub use node::P2pNode;
pub use reputation::{
    PeerAction, PeerReputation, PeerScore, ReputationConfig, ReputationEvent, ReqRespKind,
    RequestRateLimiter,
};
pub use storage::{InMemoryStorage, PreconfStorage};
pub use validation::{
    LocalValidationAdapter, LookaheadResolver, LookaheadValidationAdapter, ValidationAdapter,
};
