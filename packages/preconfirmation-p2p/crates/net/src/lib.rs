//! Networking layer for the preconfirmation P2P stack.
//!
//! This crate wires libp2p + discv5 into a small, service-friendly API. It provides:
//! - Transport/builder for libp2p (TCP/QUIC-ready) and a combined behaviour (ping, identify,
//!   gossipsub, request-response, gating).
//! - Discovery scaffold (backed by `reth-discv5` when enabled).
//! - Reputation + per-peer fixed-window request rate limiting (default 10s window / 8 requests;
//!   optional reth peer IDs; optional Kona mesh/score presets).
//! - Driver emitting `NetworkEvent`s and receiving `NetworkCommand`s for the service facade.

mod behaviour;
mod builder;
mod codec;
mod command;
mod config;
mod discovery;
mod driver;
pub mod event;
mod reputation;
mod validation;

pub use command::NetworkCommand;
pub use config::NetworkConfig;
pub use discovery::{Discovery, DiscoveryConfig, DiscoveryEvent};
pub use driver::{NetworkDriver, NetworkHandle};
pub use event::{NetworkError, NetworkErrorKind, NetworkEvent};
pub use reputation::{PeerAction, PeerReputation, PeerScore, ReputationEvent};
pub use validation::LookaheadResolver;
