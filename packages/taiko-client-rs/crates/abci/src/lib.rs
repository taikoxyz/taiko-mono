#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! ABCI++ application for the Etna PoS chain.
//!
//! Stock CometBFT orders and finalizes blocks; this crate builds and validates them and drives
//! the alethia-reth execution layer through the Engine API. Every L1 fact a block consumes travels
//! inside the block as an L1 header plus EIP-1186 proofs, so replay never calls L1.
//!
//! The `types`, `config`, `schedule`, `envelope`, `l1::layout`, `l1::mpt`, `l1::witness`,
//! `committee`, `rules`, `engine::convert` and `genesis` modules perform no I/O; `l1::source`,
//! `engine` and `elsync` hold the L1 and execution-engine adapters, and `app` answers CometBFT's
//! ABCI requests on top of them.

/// The ABCI++ application: request dispatch and the per-method handlers (spec §5).
pub mod app;
/// Committee derivation from staking-registry snapshots, MEM-08 set roots and record hashes.
pub mod committee;
/// Chain parameters (built-in per L2 chain id, optional TOML override).
pub mod config;
/// Execution-layer sync to a trusted head over devp2p.
pub mod elsync;
/// The execution-engine adapter (Engine API) and payload conversion for alethia-reth #248.
pub mod engine;
/// The CometBFT block envelope codec (`0x01 || rlp([block, anchor, committee])`).
pub mod envelope;
/// The CometBFT genesis `app_state` (the genesis witness) and its codec.
pub mod genesis;
/// L1 storage layout, EIP-1186 proof verification, Inbox witness decoding and the L1 source.
pub mod l1;
/// Header derivation and block-validity predicates (spec §4.2, §5.4).
pub mod rules;
/// Epoch schedule derived from the L1 activation record.
pub mod schedule;
/// The persisted app state and its atomic file store.
pub mod store;
/// Plain data shared across modules (witnesses, committee records, anchor and parent facts).
pub mod types;

#[cfg(test)]
pub(crate) mod test_utils;

pub use app::{AbciError, App, AppOptions, Status};
pub use committee::{CommitteeError, Snapshot};
pub use config::{ChainParams, ConfigError};
pub use elsync::{ElSyncError, ensure_block};
pub use engine::{
    Engine, EngineError, PayloadVerdict, RpcEngine, block_from_payload, payload_from_block,
};
pub use envelope::{
    AnchorWitness, CommitteeWitness, ENVELOPE_VERSION, EnvelopeError, EtnaEnvelope, ExecutionBlock,
    single_envelope,
};
pub use genesis::{AppStateJson, GenesisError, GenesisWitness, decode_app_state, encode_app_state};
pub use l1::{L1Error, L1Source, RpcL1Source, is_final_canonical};
pub use rules::{ExpectedHeader, GenerationCheck, HeaderInputs, RuleViolation};
pub use schedule::{Schedule, ScheduleError};
pub use store::{AppState, CommitteeState, Store, StoreError};
pub use types::{
    AccountWitness, ActivationRecord, AnchorState, CommitteeRecord, InboxFacts, Member, ParentInfo,
    RegistryEntry, StorageProof,
};
