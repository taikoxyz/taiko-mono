#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! ABCI++ application for the Etna PoS chain.
//!
//! Stock CometBFT orders and finalizes blocks; this crate builds and validates them and drives
//! the alethia-reth execution layer through the Engine API. Every L1 fact a block consumes travels
//! inside the block as a raw L1 header plus EIP-1186 proofs, so replay reads no L1 state; it only
//! confirms that a moved anchor header is final and canonical in the node's own L1.
//!
//! The `types`, `config`, `envelope`, `l1::header`, `l1::layout`, `l1::mpt`, `l1::witness`,
//! `committee`, `forced`, `rules`, `valstate` and `engine::convert` modules and the genesis
//! `app_state` codec perform no I/O; `l1::source`, `l1::forced_tx`, `engine` and `elsync` hold
//! the L1 and execution-engine adapters, `fallback` (fallback key lists by hash) and the genesis
//! builder read L1 through them, `app` answers CometBFT's ABCI requests on top of them, and
//! `server` serves the app on CometBFT's ABCI socket.

/// The ABCI++ application: request dispatch and the per-method handlers.
pub mod app;
/// The signing set decision and validator updates, from the portable Etna rules.
pub mod committee;
/// Chain parameters: etna-core's definition, built in per L2 chain id, optional TOML override.
pub mod config;
/// Execution-layer sync to a trusted head over devp2p.
pub mod elsync;
/// The execution-engine adapter (Engine API) and payload conversion for alethia-reth.
pub mod engine;
/// The CometBFT block envelope codec (`0x06 || rlp([block, anchor, forced])`).
pub mod envelope;
/// Fallback key lists obtained by their hash from the own L1, and the Inbox ABI around them.
pub mod fallback;
/// Etna calldata forced inclusion: authenticated entry proofs and per-block classification.
pub mod forced;
/// The CometBFT genesis: the `app_state` genesis witness, its codec, and the builder of the
/// whole `genesis.json` from L1.
pub mod genesis;
/// L1 storage layout, EIP-1186 proof verification, Inbox witness decoding and the L1 source.
pub mod l1;
/// Prometheus metrics of the ABCI app.
pub mod metrics;
/// Canonical private process ownership shared by participating startup paths.
pub mod ownership;
/// Authenticated fixed governance-recovery origins.
pub mod recovery;
/// Header derivation and block-validity predicates.
pub mod rules;
/// The tower-abci socket server: one sequential app worker behind CometBFT's four connections.
pub mod server;
/// The persisted app state and its atomic file store.
pub mod store;
/// Own-finalized Unzen origin evidence handed from the complete derivation driver to the app.
pub mod switch;
/// Plain data shared across modules (witnesses, genesis records, anchor and parent facts).
pub mod types;
/// Stock CometBFT transport with native secp256k1eth keys.
pub mod wire;

#[cfg(test)]
pub(crate) mod test_utils;

#[cfg(test)]
mod proptests;

/// `type(uint48).max`: the largest generation, L2 height and anchor L1 block number the
/// protocol encodes.
pub use etna_core::params::UINT48_MAX;
/// The deployment signing domain, the validated secp256k1eth consensus identities, the
/// `EtnaStaking` storage layout and the stock CometBFT v0.40.0 validator-state arithmetic,
/// from the portable Etna rules.
pub use etna_core::{domain, key, staking, valstate};

pub use app::{AbciError, App, AppHashReport, AppOptions, Status};
pub use config::{ChainParams, ChainParamsExt, ConfigError, ParamsError, SwitchConfig};
pub use elsync::{ElSyncError, ensure_block};
pub use engine::{
    Engine, EngineError, PayloadVerdict, RpcEngine, block_from_payload, payload_from_block,
};
pub use envelope::{
    AnchorWitness, ENVELOPE_VERSION, EnvelopeError, EtnaEnvelope, ExecutionBlock, ForcedWitness,
    single_envelope,
};
pub use genesis::{
    AppStateJson, BootstrapWitness, GenesisDoc, GenesisError, GenesisValidator, GenesisWitness,
    build_genesis, decode_bootstrap_state,
};
pub use l1::{
    L1Error, L1HeaderError, L1Source, OwnFinality, RawL1Header, RpcL1Source, header_at,
    own_finality,
};
pub use metrics::AbciMetrics;
pub use recovery::{
    RecoveryError, RecoveryOrigin, RecoveryWitness, authenticate_recovery, build_recovery_genesis,
    check_recovery_canonicality, verify_recovery_witness,
};
pub use rules::{ExpectedHeader, GenerationCheck, HeaderInputs, RuleViolation};
pub use server::{
    AbciHandler, AppService, ConnectionEpoch, ExitProcess, HaltHook, ListenAddr,
    SAFETY_HALT_EXIT_CODE, ServerError, serve, serve_with,
};
pub use store::{
    AppState, ExecutionFloor, FallbackReason, SignerStatus, Signers, Store, StoreError,
};
pub use switch::{SwitchOrigin, l2_signal_service_address};
pub use types::{
    AccountWitness, AnchorState, GenesisRecord, InboxFacts, OriginRecord, ParentInfo, StorageProof,
};
