//! The execution-layer side of the app: the [`Engine`] trait the ABCI handlers drive, its
//! JSON-RPC implementation [`RpcEngine`], and conversion between Engine API payloads and the
//! [`ExecutionBlock`] a CometBFT block carries.
//!
//! alethia-reth #248 is driven through `engine_forkchoiceUpdatedV3`, `engine_getPayloadV5` and
//! `engine_newPayloadV4` only (spec §2). [`convert`] maps a built payload to the full EL header
//! the envelope carries and back.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::Header;
use alloy_primitives::{B256, U256};
use async_trait::async_trait;

use crate::envelope::ExecutionBlock;

/// Payload ⇄ [`ExecutionBlock`] conversion (pure).
pub mod convert;
/// [`Engine`] over the `rpc` crate's Engine API wrappers and an L2 JSON-RPC provider.
pub mod rpc_engine;

pub use convert::{block_from_payload, payload_from_block};
pub use rpc_engine::RpcEngine;

/// The execution engine's verdict on a payload or forkchoice update.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PayloadVerdict {
    /// `VALID`: executed (or already known) and valid; for a forkchoice update, the head is
    /// now canonical.
    Valid,
    /// `INVALID`; the value is the engine's `validationError` (or `"INVALID"` when it gave
    /// none).
    Invalid(String),
    /// `SYNCING` or `ACCEPTED`: the engine could not execute the block yet (missing ancestors,
    /// side chain, or an active sync).
    Syncing,
}

/// The Engine API operations the ABCI app needs from its execution engine.
#[async_trait]
pub trait Engine: Send + Sync + 'static {
    /// Fails unless the engine serves every Engine API method this client calls.
    async fn check_capabilities(&self) -> Result<(), EngineError>;

    /// Builds a block on top of `parent_hash` from `attrs` and returns it with its full header.
    ///
    /// `attrs` must carry a `parentBeaconBlockRoot` (the anchor's L1 state root, spec §4.2).
    async fn build_block(
        &self,
        parent_hash: B256,
        attrs: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError>;

    /// Executes `block` and reports the engine's verdict.
    async fn new_payload(&self, block: &ExecutionBlock) -> Result<PayloadVerdict, EngineError>;

    /// Moves the engine's forkchoice to `head`, `safe` and `finalized` (each `B256::ZERO` for
    /// "unknown") without starting a build, and reports the engine's verdict on `head`.
    async fn forkchoice(
        &self,
        head: B256,
        safe: B256,
        finalized: B256,
    ) -> Result<PayloadVerdict, EngineError>;

    /// The engine's canonical header at `number`, or `None` if it has none; checked to hash to
    /// the block hash the engine reports.
    async fn header_by_number(&self, number: u64) -> Result<Option<Header>, EngineError>;
}

/// Why an Engine API exchange or a payload conversion failed.
///
/// [`EngineError::BlockHashMismatch`] through [`EngineError::NotEtnaShaped`] mean the payload or
/// block itself is malformed for Etna: a block from a peer failing with one of them is invalid,
/// not a local fault. The remaining variants are local faults (engine endpoint, configuration or
/// engine behaviour).
#[derive(Debug, thiserror::Error, Clone, PartialEq, Eq)]
pub enum EngineError {
    /// The header rebuilt from a payload does not hash to the payload's `blockHash`.
    #[error("payload block hash {expected} differs from the rebuilt header hash {computed}")]
    BlockHashMismatch {
        /// The `blockHash` the payload claims.
        expected: B256,
        /// `keccak256(rlp(header))` of the header rebuilt from the payload.
        computed: B256,
    },
    /// The payload carries withdrawals; Etna blocks have none (PRF-06). The value is how many.
    #[error("payload carries {0} withdrawals, expected none")]
    Withdrawals(usize),
    /// The payload's blob gas fields are not both zero; Etna blocks carry no blobs (PRF-06).
    #[error(
        "payload blob gas must be zero, got blob_gas_used {blob_gas_used} and excess_blob_gas \
         {excess_blob_gas}"
    )]
    BlobGas {
        /// The payload's `blobGasUsed`.
        blob_gas_used: u64,
        /// The payload's `excessBlobGas`.
        excess_blob_gas: u64,
    },
    /// The payload's `baseFeePerGas` does not fit in a `u64` header field.
    #[error("base fee {0} does not fit in u64")]
    BaseFeeOverflow(U256),
    /// The block's zk gas (its header `difficulty`) does not fit in a `u64`, so it cannot be sent
    /// as `engine_newPayloadV4`'s `headerDifficulty`.
    #[error("difficulty (zk gas) {0} does not fit in u64")]
    DifficultyOverflow(U256),
    /// A header field has a value alethia-reth #248 never assembles for an Etna block (or does
    /// not match the block's transactions); the value names the field.
    #[error("header field `{0}` is not Etna-shaped")]
    NotEtnaShaped(&'static str),
    /// A JSON-RPC call to the execution engine failed (transport, auth or a JSON-RPC error
    /// response); the value is the rendered cause.
    #[error("engine RPC failed: {0}")]
    Rpc(String),
    /// The engine client cannot be used: an endpoint with an unsupported URL scheme, an
    /// unreadable JWT secret, or an engine missing required Engine API methods.
    #[error("engine setup failed: {0}")]
    Setup(String),
    /// A forkchoice update with payload attributes did not start a build (status other than
    /// `VALID`, or no payload id); the value describes the reply.
    #[error("engine did not start a payload build: {0}")]
    BuildNotStarted(String),
    /// The engine reported a block hash its own header does not hash to.
    #[error("engine block {number} reported hash {reported}, but its header hashes to {computed}")]
    HeaderHashMismatch {
        /// The requested block number.
        number: u64,
        /// The `hash` field of the RPC response.
        reported: B256,
        /// `keccak256(rlp(header))` of the returned header fields.
        computed: B256,
    },
}
