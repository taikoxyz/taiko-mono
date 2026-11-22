//! L1 layer: the raw L1 header, the Inbox and staking-registry storage layout, EIP-1186 proof
//! verification and the decoding of verified Inbox witnesses into facts, plus the node's own L1
//! view ([`source`]), the initial committee's registry-witness discovery ([`fetch`]) and calldata
//! event reads ([`forced_tx`]).
//!
//! `header`, `layout`, `mpt` and `witness` perform no I/O.

/// The initial committee's registry-witness discovery from the node's own L1 (the genesis
/// builder, recovery acquisition and the lander).
pub mod fetch;
/// Exact-block calldata forced inclusion event acquisition.
pub mod forced_tx;
/// The raw L1 header witnesses carry, read by position.
pub mod header;
/// Storage slots of the Inbox and staking registry.
pub mod layout;
/// EIP-1186 account and storage proof verification.
pub mod mpt;
/// The [`L1Source`] trait over the operator's own L1 node and its JSON-RPC implementation.
pub mod source;
/// Anchor and genesis Inbox witness verification into facts.
pub mod witness;

pub use fetch::{FetchError, build_committee_witness_at_cutoff};
pub use header::{L1HeaderError, RawL1Header};
pub use mpt::{MptError, VerifiedStorage, verify_account_witness};
pub use source::{
    L1Error, L1Source, OwnFinality, RpcL1Source, header_at, own_finality, own_finality_at,
};
pub use witness::{WitnessError, verify_anchor_witness, verify_genesis_inbox};
