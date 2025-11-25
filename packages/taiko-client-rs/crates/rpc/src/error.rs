//! Error types for RPC operations.

use alloy::transports::{RpcError, TransportError, TransportErrorKind};
use anyhow::anyhow;
use protocol::subscription_source::SubscriptionSourceError;
use std::result::Result as StdResult;
use thiserror::Error;

/// Result type alias for RPC operations
pub type Result<T> = StdResult<T, RpcClientError>;

/// Error types for RPC operations
#[derive(Debug, Error)]
pub enum RpcClientError {
    /// Failed to read JWT secret
    #[error("failed to read JWT secret from {0}")]
    JwtSecretReadFailed(String),

    /// Invalid JWT secret format
    #[error("invalid JWT secret format")]
    InvalidJwtSecret,

    /// Connection error
    #[error("connection error: {0}")]
    Connection(String),

    /// Provider error
    #[error("provider error: {0}")]
    Provider(String),

    /// RPC error
    #[error("RPC error: {0}")]
    Rpc(String),

    /// Contract error
    #[error("contract error: {0}")]
    Contract(String),

    /// Generic error
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

// Manual From implementation for RpcError
impl From<RpcError<TransportErrorKind>> for RpcClientError {
    fn from(err: RpcError<TransportErrorKind>) -> Self {
        RpcClientError::Rpc(err.to_string())
    }
}

impl From<TransportError<TransportErrorKind>> for RpcClientError {
    fn from(err: TransportError<TransportErrorKind>) -> Self {
        RpcClientError::Rpc(err.to_string())
    }
}

// Manual From implementation for alloy contract Error
impl From<alloy::contract::Error> for RpcClientError {
    fn from(err: alloy::contract::Error) -> Self {
        RpcClientError::Contract(err.to_string())
    }
}

impl From<SubscriptionSourceError> for RpcClientError {
    fn from(err: SubscriptionSourceError) -> Self {
        match err {
            SubscriptionSourceError::Connection(msg) => RpcClientError::Connection(msg),
            SubscriptionSourceError::Wallet(msg) => RpcClientError::Other(anyhow!(msg)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = RpcClientError::JwtSecretReadFailed("/path/to/jwt.hex".to_string());
        assert_eq!(err.to_string(), "failed to read JWT secret from /path/to/jwt.hex");

        let err = RpcClientError::InvalidJwtSecret;
        assert_eq!(err.to_string(), "invalid JWT secret format");
    }
}
