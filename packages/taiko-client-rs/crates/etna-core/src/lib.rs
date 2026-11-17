#![no_std]
#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
//! Portable deterministic Etna protocol witnesses and verification.
//!
//! This foundation authenticates account/storage witnesses; it is not a complete range verifier.

extern crate alloc;
#[cfg(test)]
extern crate std;

/// Checked account/storage trie verification with identical aborting and unwinding behavior.
pub mod mpt;
/// Canonical EIP-1186 witnesses shared by the node and portable verifier.
pub mod witness;

pub use mpt::{MptError, VerifiedStorage, verify_account_witness};
pub use witness::{AccountWitness, StorageProof};

#[cfg(test)]
mod test_utils;
