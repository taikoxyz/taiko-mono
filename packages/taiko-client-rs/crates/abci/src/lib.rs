#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! ABCI++ application for the Etna PoS chain.
//!
//! Stock CometBFT orders and finalizes blocks; this crate builds and validates them and drives
//! the alethia-reth execution layer through the Engine API. Every L1 fact a block consumes travels
//! inside the block as an L1 header plus EIP-1186 proofs, so replay never calls L1.
//!
//! The `types`, `config`, `schedule`, `envelope`, `l1::layout`, `l1::mpt`, `l1::witness` and
//! `committee` modules perform no I/O.

/// Committee derivation from staking-registry snapshots, MEM-08 set roots and record hashes.
pub mod committee;
/// Chain parameters (built-in per L2 chain id, optional TOML override).
pub mod config;
/// The CometBFT block envelope codec (`0x01 || rlp([block, anchor, committee])`).
pub mod envelope;
/// L1 storage layout, EIP-1186 proof verification and Inbox witness decoding.
pub mod l1;
/// Epoch schedule derived from the L1 activation record.
pub mod schedule;
/// Plain data shared across modules (witnesses, committee records, anchor and parent facts).
pub mod types;

#[cfg(test)]
pub(crate) mod test_utils;

pub use committee::{CommitteeError, Snapshot};
pub use config::{ChainParams, ConfigError};
pub use envelope::{
    AnchorWitness, CommitteeWitness, ENVELOPE_VERSION, EnvelopeError, EtnaEnvelope, ExecutionBlock,
    single_envelope,
};
pub use schedule::{Schedule, ScheduleError};
pub use types::{
    AccountWitness, ActivationRecord, AnchorState, CommitteeRecord, InboxFacts, Member, ParentInfo,
    RegistryEntry, StorageProof,
};
