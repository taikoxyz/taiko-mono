//! Derivation pipeline implementations per protocol fork.

/// Shared derivation error type.
mod error;
/// Shasta fork derivation pipeline implementation.
pub mod shasta;

pub use error::DerivationError;
pub use shasta::ShastaDerivationPipeline;
