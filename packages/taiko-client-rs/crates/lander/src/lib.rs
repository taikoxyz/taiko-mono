#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Permissionless Etna landing: authenticated batches, bound blobs and durable submission.

/// Blob sidecars sharing the protocol's Kona-compatible payload encoding.
pub mod blob;
/// Canonical execution-only public DA with bounded private certificate projection.
pub mod codec;
/// zlib helpers of the V6 landing payload.
pub mod compression;
/// Generated bindings from the pinned Etna Inbox interface snapshot.
pub mod contracts;
/// Classified errors shared by the lander's components.
pub mod error;
/// Asynchronous proof-provider boundary and explicitly dummy implementation.
pub mod proof;
/// Exact V1 public statement encoding and hashing.
pub mod statement;
/// Immutable contexts shared by collectors, proof providers and persistence.
pub mod types;

pub use error::{LanderError, Result};
pub use proof::{DummyProofProvider, ProofError, ProofProvider, ProofRequest};
pub use types::{CertifiedBlock, LandingSnapshot, Limits, PreparedBatch, SidecarMode};

#[cfg(test)]
pub(crate) mod test_utils;

#[cfg(test)]
mod proptests;

/// Operator limits, fees, deadlines and endpoint validation.
pub mod config;
/// Hash-pinned L1 and public L2 source adapters.
pub mod l1;
/// Atomic journal with exclusive data-directory ownership.
pub mod store;
/// Signing and submission of a complete blob transaction.
pub mod tx;

/// Immutable authenticated batch assembly and complete-prefix selection.
pub mod batch;
/// Bounded HTTP CometBFT source and read-only collector trait.
pub mod comet;
/// Reconstruction and authentication of full Etna committees.
pub mod committee;
/// CometBFT certificate and exact block consistency validation.
pub mod validate;

/// Prometheus gauges for progress, durable transaction phases and retries.
pub mod metrics;

/// Polling and reconciliation of one durable job and outstanding nonce.
pub mod runner;

/// Pure checkpoint-bound execution ancestry and derivation snapshots.
pub mod history;

/// Lossless native stock-Comet certificates and key-bearing block evidence.
pub mod native;
