//! L1 layer: the raw L1 header, the Inbox and staking-registry storage layout, EIP-1186 proof
//! verification and the decoding of verified Inbox witnesses into facts, plus the node's own L1
//! view ([`source`]), the committee-witness discovery over it ([`fetch`]) and the source of
//! forced inclusion blobs ([`blobs`]).
//!
//! `header`, `layout`, `mpt` and `witness` perform no I/O.

/// Committee-only archive state fallback with own-L1 finality authority.
pub mod archive;
/// The source forced inclusion blobs are fetched from (the L1 beacon node), by a proposer and
/// by a validator prefetching a pending entry's blob.
pub mod blobs;
/// Committee-witness discovery from the node's own L1 (proposers and the genesis builder).
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

pub use archive::CommitteeL1Source;
pub use blobs::{BeaconBlobs, BlobSource, LazyBeaconBlobs};
pub(crate) use fetch::{DiscoveryProgress, build_committee_witness_within};
pub use fetch::{FetchError, build_committee_witness, build_committee_witness_at_cutoff};
pub use header::{L1HeaderError, RawL1Header};
pub use mpt::{MptError, VerifiedStorage, verify_account_witness};
pub use source::{L1Error, L1Source, RpcL1Source, header_at, is_final_canonical};
pub use witness::{WitnessError, verify_anchor_witness, verify_genesis_inbox};
