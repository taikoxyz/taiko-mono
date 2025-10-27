//! Error types for proposer operations.

use alloy::{
    providers::PendingTransactionError,
    transports::{RpcError, TransportErrorKind},
};
use event_indexer::error::IndexerError;
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

    /// Failed to read propose input from event indexer
    #[error("failed to read propose input from event indexer")]
    ProposeInputUnavailable,

    /// L1 head is too low to propose
    #[error("current L1 head {current} is too low to propose, must be greater than {minimum}")]
    L1HeadTooLow { current: u64, minimum: u64 },

    /// Contract error
    #[error("contract error: {0}")]
    Contract(#[from] alloy::contract::Error),

    /// Sidecar build error
    #[error("sidecar build error: {0}")]
    Sidecar(String),

    /// RPC error
    #[error("RPC error: {0}")]
    Rpc(String),

    /// Pending transaction error
    #[error("pending transaction error: {0}")]
    PendingTransaction(String),

    /// JSON serialization error
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    /// Event indexer error
    #[error("event indexer error: {0}")]
    Indexer(#[from] IndexerError),

    /// Generic error
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

// Manual From implementations for types that don't play well with #[from]
impl From<RpcError<TransportErrorKind>> for ProposerError {
    fn from(err: RpcError<TransportErrorKind>) -> Self {
        ProposerError::Rpc(err.to_string())
    }
}

// Manual From implementation for PendingTransactionError
impl From<PendingTransactionError> for ProposerError {
    fn from(err: PendingTransactionError) -> Self {
        ProposerError::PendingTransaction(err.to_string())
    }
}

// Manual From implementation for RpcClientError
impl From<RpcClientError> for ProposerError {
    fn from(err: RpcClientError) -> Self {
        ProposerError::Rpc(err.to_string())
    }
}

// Manual From implementation for ProtocolError
impl From<ProtocolError> for ProposerError {
    fn from(err: ProtocolError) -> Self {
        ProposerError::Other(err.into())
    }
}
