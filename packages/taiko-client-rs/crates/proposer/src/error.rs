//! Error types for proposer operations.

use alloy::transports::{RpcError, TransportErrorKind};
use alloy_eips::eip2718::Eip2718Error;
use base_tx_manager::TxManagerError;
use protocol::shasta::ProtocolError;
use rpc::RpcClientError;
use std::result::Result as StdResult;
use thiserror::Error;

/// Result type alias for proposer operations
pub type Result<T> = StdResult<T, ProposerError>;

/// Error types for proposer operations
#[derive(Debug, Error)]
pub enum ProposerError {
    /// Base fee conversion error
    #[error("base fee exceeds u64 maximum")]
    BaseFeeOverflow,

    /// Block not found error
    #[error("latest block not found")]
    LatestBlockNotFound,

    /// Parent block not found error
    #[error("parent block {0} not found")]
    ParentBlockNotFound(u64),
    /// Parent block is missing base fee required for EIP-4396 base-fee calculation.
    #[error("parent block {parent_block_number} missing base fee for EIP-4396 calculation")]
    MissingParentBaseFee {
        /// Parent block number whose header was missing `base_fee_per_gas`.
        parent_block_number: u64,
    },

    /// Failed to decode extra data from parent block.
    #[error("invalid extra data in parent block")]
    InvalidExtraData,

    /// FCU returned invalid status.
    #[error("forkchoice updated failed: {0}")]
    FcuFailed(String),

    /// FCU did not return a payload ID.
    #[error("FCU did not return payload ID (node may be syncing)")]
    NoPayloadId,

    /// Failed to decode transaction from RLP bytes.
    #[error("failed to decode transaction at index {index}: {source}")]
    TxDecode {
        /// Zero-based index in the decoded transaction list.
        index: usize,
        /// Underlying decoding error.
        source: Eip2718Error,
    },

    /// Failed to recover signer from transaction.
    #[error("failed to recover signer for transaction at index {index}: {message}")]
    SignerRecovery {
        /// Zero-based index in the transaction list.
        index: usize,
        /// Failure reason returned by signer recovery.
        message: String,
    },

    /// Anchor constructor not initialized (engine mode disabled).
    #[error("anchor constructor not initialized (engine mode is disabled)")]
    AnchorConstructorNotInitialized,

    /// Failed to build anchor transaction.
    #[error("anchor transaction construction failed: {0}")]
    AnchorConstruction(#[from] protocol::shasta::AnchorTxConstructorError),

    /// Contract error
    #[error("contract error: {0}")]
    Contract(#[from] alloy::contract::Error),

    /// Sidecar build error
    #[error("sidecar build error: {0}")]
    Sidecar(String),

    /// RPC error
    #[error("RPC error: {0}")]
    Rpc(String),

    /// Base tx-manager error
    #[error("tx-manager error: {0}")]
    TxManager(#[from] TxManagerError),

    /// JSON serialization error
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    /// Generic error
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

// Manual From implementations for types that don't play well with #[from]
impl From<RpcError<TransportErrorKind>> for ProposerError {
    /// Convert transport-layer RPC errors into the proposer RPC error variant.
    fn from(err: RpcError<TransportErrorKind>) -> Self {
        ProposerError::Rpc(err.to_string())
    }
}

// Manual From implementation for RpcClientError
impl From<RpcClientError> for ProposerError {
    /// Convert RPC client wrapper errors into the proposer RPC error variant.
    fn from(err: RpcClientError) -> Self {
        ProposerError::Rpc(err.to_string())
    }
}

// Manual From implementation for ProtocolError
impl From<ProtocolError> for ProposerError {
    /// Convert protocol-layer failures into the generic proposer error bucket.
    fn from(err: ProtocolError) -> Self {
        ProposerError::Other(err.into())
    }
}
