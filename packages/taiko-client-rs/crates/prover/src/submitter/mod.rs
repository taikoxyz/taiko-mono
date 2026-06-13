//! Proof submission: transaction building and (in later modules) the
//! request → buffer → aggregate → submit pipeline.

pub mod transaction;

pub use transaction::{BuildProveTxInput, build_prove_batches_tx};
