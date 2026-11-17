//! Native CometBFT wire codecs, ordered validator slots, QC and body commitments.
//!
//! These checks do not authenticate a registry committee or execute an Etna envelope.
/// Canonical native protobuf/domain conversion.
pub mod codec;
/// Lossless native signature, block and evidence representations.
pub mod native;
/// Checked native validator slots, distinct from opaque evidence validators.
pub mod validators;
/// Deterministic certificate, body and ancestry verification.
pub mod verify;

/// Etna application version committed by native headers and reported by ABCI.
pub const APP_VERSION: u64 = 1;
