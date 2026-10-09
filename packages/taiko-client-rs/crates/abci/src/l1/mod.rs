//! L1 layer: the Inbox and staking-registry storage layout and EIP-1186 proof verification.
//!
//! `layout` and `mpt` perform no I/O.

/// Storage slots of the Inbox and staking registry (spec §6.2).
pub mod layout;
/// EIP-1186 account and storage proof verification (spec §6.3).
pub mod mpt;

pub use mpt::{MptError, VerifiedStorage, verify_account_witness};
