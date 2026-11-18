//! Portable Etna consensus primitives for Raiko2 and native clients.
//!
//! [`committee::derive`] computes a candidate committee from snapshot data.
//! [`comet::validators::Validators::from_members`] checks validator identities and power.
//! Consumers separately authenticate the committee for the applicable epoch and generation.
//! [`committee::verify_committee_at_cutoff`] is available for verifying registry witnesses
//! against an authenticated L1 state root.
//!
//! The Comet certificate and body helpers verify individual consensus commitments. Consumers
//! compose these checks with generation and range validation, execution and forced inclusion
//! rules, and their own state and witness handling.

#![cfg_attr(not(test), no_std)]
#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
extern crate alloc;
#[cfg(test)]
extern crate std;
/// Native Comet codecs, QC and original body commitments.
pub mod comet;
/// Complete committee authentication, derivation and commitments.
pub mod committee;
/// Deployment and generation signing domain.
pub mod domain;
/// Validated consensus identities and stock key JSON.
pub mod key;
/// Canonical deployment data and pure parameter validation.
pub mod params;
/// Registry storage layout without a proof-engine dependency.
pub mod registry;
/// Epoch schedule and H+2 activation arithmetic.
pub mod schedule;
#[cfg(any(test, feature = "test-utils"))]
mod test_utils;
/// Canonical shared committee and generation-start records.
pub mod types;
/// Stock native validator protobuf and commitments.
pub mod validator;
/// Stock per-height validator-state transitions and canonical preimages.
pub mod valstate;
pub use params::GRID_INTERVAL;
