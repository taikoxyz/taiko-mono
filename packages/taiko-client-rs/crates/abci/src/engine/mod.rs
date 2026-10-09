//! The execution-layer side of the app: the [`Engine`] trait the ABCI handlers drive, its
//! JSON-RPC implementation [`RpcEngine`], and conversion between Engine API payloads and the
//! [`ExecutionBlock`] a CometBFT block carries.
//!
//! alethia-reth #248 is driven through `engine_forkchoiceUpdatedV3`, `engine_getPayloadV5` and
//! `engine_newPayloadV4` only. [`convert`] maps a built payload to the full EL header
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
    /// `attrs` must carry a `parentBeaconBlockRoot` (the anchor's L1 state root).
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
/// engine behaviour). Whether a retry of the call may succeed is [`EngineError::is_retryable`]:
/// transport failures and some JSON-RPC error codes are transient, every other failure is the
/// engine's (or this client's) answer to the call and repeats on a retry.
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
    /// A JSON-RPC exchange with the engine failed in transport: the endpoint could not be
    /// reached, the connection broke off, the HTTP layer answered with an error status, or the
    /// body was not JSON at all (e.g. a proxy's error page). The value names the method and
    /// endpoint and renders the cause. Transient: the same call may succeed later.
    #[error("engine RPC transport failed: {0}")]
    Transport(String),
    /// The engine answered a JSON-RPC call with an error object, e.g. `-38002` (invalid
    /// forkchoice state) or `-32603` (internal error). The code tells whether the engine refused
    /// the call itself, which it does again for the same call, or failed transiently
    /// ([`EngineError::is_retryable`]).
    #[error("{call} answered JSON-RPC error {code}: {message}")]
    ErrorReply {
        /// The method and the endpoint it was sent to.
        call: String,
        /// The JSON-RPC error code.
        code: i64,
        /// The JSON-RPC error message.
        message: String,
    },
    /// The engine answered with JSON this client cannot decode into the expected reply (e.g.
    /// an unknown payload status or a `null` result), or the request could not be encoded
    /// locally. The value names the method and endpoint and renders the cause; the same call
    /// fails the same way again.
    #[error("engine RPC gave no usable reply: {0}")]
    BadReply(String),
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
    /// The engine answered a request for block `requested` with block `got`.
    #[error("requested engine block {requested}, the engine answered block {got}")]
    HeaderNumberMismatch {
        /// The requested block number.
        requested: u64,
        /// The block number of the answer.
        got: u64,
    },
}

impl EngineError {
    /// Whether a retry of the call may succeed: `FinalizeBlock` retries such an error with
    /// backoff and halts on any other.
    ///
    /// | Error                                      | Retryable | Meaning                         |
    /// | ------------------------------------------ | --------- | ------------------------------- |
    /// | [`Transport`](Self::Transport)             | yes       | the exchange itself failed      |
    /// | `ErrorReply` `-38001..=-38005`             | no        | Engine API verdict on the call  |
    /// | `ErrorReply` `-32700`, `-32600..=-32602`   | no        | the call itself is malformed    |
    /// | `ErrorReply` `-32603`                      | yes       | internal error                  |
    /// | `ErrorReply` `-32099..=-32000`             | yes       | implementation-defined error    |
    /// | `ErrorReply`, any other code               | yes       | unknown, so not a known verdict |
    /// | [`BadReply`](Self::BadReply)               | no        | JSON of the wrong shape         |
    /// | every other variant                        | no        | malformed block, setup, verdict |
    ///
    /// The Engine API codes are unknown payload, invalid forkchoice state, invalid payload
    /// attributes, too large request and unsupported fork; the malformed-call codes are parse
    /// error, invalid request, method not found and invalid params. reth answers `-32603` when
    /// its engine task has stopped (e.g. during a shutdown) and on provider or database faults;
    /// a block it judged bad is answered `INVALID` instead.
    pub const fn is_retryable(&self) -> bool {
        match self {
            Self::Transport(_) => true,
            Self::ErrorReply { code, .. } => {
                !matches!(*code, -38005..=-38001 | -32700 | -32602..=-32600)
            }
            _ => false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A JSON-RPC error reply with `code`.
    fn reply(code: i64) -> EngineError {
        EngineError::ErrorReply {
            call: "engine_x at http://el.test/".into(),
            code,
            message: "m".into(),
        }
    }

    /// The retry classes of `EngineError::is_retryable`'s table: the Engine API's own codes and
    /// the JSON-RPC codes for a malformed call are the engine's verdict on the call; internal,
    /// server-range and unknown codes, and transport failures, are transient.
    #[test]
    fn is_retryable_follows_the_error_class_table() {
        for code in [-38001, -38002, -38003, -38004, -38005, -32700, -32600, -32601, -32602] {
            assert!(!reply(code).is_retryable(), "{code} is a verdict on the call");
        }
        for code in [
            -32603,
            -32000,
            -32001,
            -32050,
            -32099,
            -38000,
            -38006,
            -32604,
            -32100,
            -32768,
            -1,
            0,
            3,
            i64::MIN,
            i64::MAX,
        ] {
            assert!(reply(code).is_retryable(), "{code} is transient or unknown");
        }
        assert!(EngineError::Transport("connection refused".into()).is_retryable());
        for error in [
            EngineError::BadReply("null".into()),
            EngineError::Setup("jwt".into()),
            EngineError::BuildNotStarted("SYNCING".into()),
            EngineError::NotEtnaShaped("withdrawals_root"),
            EngineError::Withdrawals(1),
            EngineError::BlobGas { blob_gas_used: 1, excess_blob_gas: 0 },
            EngineError::BaseFeeOverflow(U256::MAX),
            EngineError::DifficultyOverflow(U256::MAX),
            EngineError::BlockHashMismatch { expected: B256::ZERO, computed: B256::ZERO },
            EngineError::HeaderHashMismatch {
                number: 1,
                reported: B256::ZERO,
                computed: B256::ZERO,
            },
        ] {
            assert!(!error.is_retryable(), "{error:?}");
        }
    }
}
