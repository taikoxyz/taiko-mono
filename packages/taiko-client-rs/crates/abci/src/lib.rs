#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! ABCI++ application for the Etna PoS chain.
//!
//! Stock CometBFT orders and finalizes blocks; this crate builds and validates them and drives
//! the alethia-reth execution layer through the Engine API. Every L1 fact a block consumes travels
//! inside the block as an L1 header plus EIP-1186 proofs, so replay never calls L1.
//!
//! The `types`, `config` and `schedule` modules perform no I/O.

/// Chain parameters (built-in per L2 chain id, optional TOML override).
pub mod config;
/// Epoch schedule derived from the L1 activation record.
pub mod schedule;
/// Plain data shared across modules (witnesses, committee records, anchor and parent facts).
pub mod types;

pub use config::{ChainParams, ConfigError};
pub use schedule::{Schedule, ScheduleError};
pub use types::{
    AccountWitness, ActivationRecord, AnchorState, CommitteeRecord, InboxFacts, Member, ParentInfo,
    RegistryEntry, StorageProof,
};
