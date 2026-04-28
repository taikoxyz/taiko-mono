#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Taiko protocol constants and types.

/// Byte-level encoding and decoding helpers shared across protocol crates.
pub mod codec;
/// Lookahead resolver and preconfirmation helpers.
#[cfg(feature = "net")]
pub mod preconfirmation;
/// Shasta-specific protocol types, constants, and builders.
pub mod shasta;
/// Deterministic signer used by network protocol flows.
#[cfg(feature = "net")]
pub mod signer;
/// Provider/event-scanner subscription source abstraction.
#[cfg(feature = "net")]
pub mod subscription_source;

#[cfg(feature = "net")]
pub use signer::{FixedKSigner, FixedKSignerError};
