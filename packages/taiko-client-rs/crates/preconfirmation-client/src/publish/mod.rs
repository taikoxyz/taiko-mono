//! Publishing module for the preconfirmation client.
//!
//! This module provides functionality for publishing preconfirmation
//! commitments and txlists to the P2P network.

mod publisher;

pub use publisher::PreconfirmationPublisher;
