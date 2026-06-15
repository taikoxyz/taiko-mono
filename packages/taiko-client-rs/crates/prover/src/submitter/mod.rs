//! Proof submission: transaction building and (in later modules) the
//! request → buffer → aggregate → submit pipeline.

pub mod monitor;
#[allow(clippy::module_inception)]
pub mod submitter;
pub mod transaction;
pub mod tx_manager_adapter;

pub use submitter::{
    Pipeline, ProofRequestMeta, ProofSubmitter, SubmitterChannels, SubmitterConfig,
};
pub use transaction::{BuildProveTxInput, build_prove_batches_tx};
