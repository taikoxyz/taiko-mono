//! L1 layer: the Inbox and staking-registry storage layout, EIP-1186 proof verification and the
//! decoding of verified Inbox witnesses into facts, plus the node's own L1 view ([`source`]).
//!
//! `layout`, `mpt` and `witness` perform no I/O.

/// Storage slots of the Inbox and staking registry (spec §6.2).
pub mod layout;
/// EIP-1186 account and storage proof verification (spec §6.3).
pub mod mpt;
/// The [`L1Source`] trait over the operator's own L1 node and its JSON-RPC implementation.
pub mod source;
/// Anchor and genesis Inbox witness verification into facts (spec §5.1, §5.4).
pub mod witness;

pub use mpt::{MptError, VerifiedStorage, verify_account_witness};
pub use source::{L1Error, L1Source, RpcL1Source, is_final_canonical};
pub use witness::{WitnessError, verify_anchor_witness, verify_genesis_inbox};
