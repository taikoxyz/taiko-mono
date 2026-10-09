//! L1 layer: the Inbox and staking-registry storage layout, EIP-1186 proof verification and the
//! decoding of verified Inbox witnesses into facts.
//!
//! `layout`, `mpt` and `witness` perform no I/O.

/// Storage slots of the Inbox and staking registry (spec §6.2).
pub mod layout;
/// EIP-1186 account and storage proof verification (spec §6.3).
pub mod mpt;
/// Anchor and genesis Inbox witness verification into facts (spec §5.1, §5.4).
pub mod witness;

pub use mpt::{MptError, VerifiedStorage, verify_account_witness};
pub use witness::{WitnessError, verify_anchor_witness, verify_genesis_inbox};
