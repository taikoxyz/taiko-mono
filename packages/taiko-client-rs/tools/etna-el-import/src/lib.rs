#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
//! Offline local EL state verification and authenticated canonical-header installation.

/// Fresh offline dataset baseline, auxiliary-data quarantine and normal provider verification.
mod dataset;
/// Strict authenticated header range and caller-supplied trust roots.
mod headers;
/// Private offline MDBX snapshots and unbounded full scans.
mod offline;
/// Independent verification of accounts, storage and referenced bytecode.
mod state;
/// Pinned static-file and canonical number/hash index installation.
mod stores;

pub use dataset::{
    DatasetReport, install_dataset, install_dataset_with_scratch, verify_dataset,
    verify_dataset_with_scratch,
};
pub use headers::{ElTrust, HeaderManifest, VerifiedHeaders};
pub use state::{ImportError, StateReport, verify_state};
pub use stores::install_headers;

#[cfg(test)]
mod tests;
