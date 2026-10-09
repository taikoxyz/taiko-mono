#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Taiko protocol constants and types.

/// Shasta-specific protocol types, constants, and builders.
pub mod shasta;
/// Deterministic fixed-k secp256k1 signer. Depends only on `alloy-primitives`/`k256`, so it is
/// available without the `net` feature for zkVM guests (e.g. raiko2) that must regenerate the
/// canonical golden-touch anchor signature.
pub mod signer;

pub use signer::{FixedKSigner, FixedKSignerError};
