//! The execution-layer side of the app: conversion between Engine API payloads and the
//! [`ExecutionBlock`](crate::envelope::ExecutionBlock) a CometBFT block carries.
//!
//! alethia-reth #248 is driven through `engine_forkchoiceUpdatedV3`, `engine_getPayloadV5` and
//! `engine_newPayloadV4` only (spec §2). [`convert`] maps a built payload to the full EL header
//! the envelope carries and back.

use alloy_primitives::{B256, U256};

/// Payload ⇄ [`ExecutionBlock`](crate::envelope::ExecutionBlock) conversion (pure).
pub mod convert;

pub use convert::{block_from_payload, payload_from_block};

/// Why an Engine API exchange or a payload conversion failed.
///
/// Every variant except [`EngineError::Rpc`] means the payload or block itself is malformed for
/// Etna: a block from a peer failing with one of them is invalid, not a local fault.
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
}
