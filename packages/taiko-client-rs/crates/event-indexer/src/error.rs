//! Error types for the event indexer

use alloy::transports::TransportErrorKind;
use alloy_json_rpc::RpcError;
use event_scanner::event_scanner::EventScannerError;
use std::result::Result as StdResult;
use thiserror::Error;

/// Result type alias for indexer operations
pub type Result<T> = StdResult<T, IndexerError>;

/// Error types for event indexer operations
#[derive(Debug, Error)]
pub enum IndexerError {
    /// Contract error
    #[error("contract error: {0}")]
    Contract(#[from] alloy::contract::Error),

    /// RPC error
    #[error("RPC error: {0}")]
    Rpc(Box<RpcError<TransportErrorKind>>),

    /// Event scanner error
    #[error("event scanner error: {0}")]
    EventScanner(#[from] EventScannerError),

    /// Log decode error
    #[error("log decode error: {0}")]
    LogDecode(Box<alloy::sol_types::Error>),

    /// Generic error
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

// Manual From implementations for types that don't play well with #[from]
impl From<RpcError<TransportErrorKind>> for IndexerError {
    fn from(err: RpcError<TransportErrorKind>) -> Self {
        IndexerError::Rpc(Box::new(err))
    }
}

// Manual From implementations for types that don't play well with #[from]
impl From<alloy::sol_types::Error> for IndexerError {
    fn from(err: alloy::sol_types::Error) -> Self {
        IndexerError::LogDecode(Box::new(err))
    }
}
