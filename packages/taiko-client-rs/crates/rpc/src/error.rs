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

    /// Typed RPC error from the transport stack.
    #[error("RPC error: {0}")]
    Rpc(#[from] TransportError),

    /// RPC error already enriched with local context.
    #[error("RPC error: {0}")]
    RpcMessage(String),

    /// Contract error
    #[error("contract error: {0}")]
    Contract(String),

    /// Generic error
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

impl From<TransportError<TransportErrorKind>> for RpcClientError {
    /// Convert low-level transport errors while preserving retryable transport failures.
    ///
    /// `ErrorResp` is flattened to a stringified `RpcMessage` so callers can treat it as a
    /// non-retryable RPC response; all other variants stay typed under `Rpc(_)` so transport
    /// failures remain distinguishable for retry classification.
    fn from(err: TransportError<TransportErrorKind>) -> Self {
        match err {
            RpcError::ErrorResp(err) => RpcClientError::RpcMessage(err.to_string()),
            RpcError::NullResp => RpcClientError::Rpc(RpcError::NullResp),
            RpcError::UnsupportedFeature(feature) => {
                RpcClientError::Rpc(RpcError::UnsupportedFeature(feature))
            }
            RpcError::LocalUsageError(err) => RpcClientError::Rpc(RpcError::LocalUsageError(err)),
            RpcError::SerError(err) => RpcClientError::Rpc(RpcError::SerError(err)),
            RpcError::DeserError { err, text } => {
                RpcClientError::Rpc(RpcError::DeserError { err, text })
            }
            RpcError::Transport(err) => RpcClientError::Rpc(RpcError::Transport(err)),
        }
    }
}

// Manual From implementation for alloy contract Error
impl From<alloy::contract::Error> for RpcClientError {
    /// Convert contract call errors into the contract-specific RPC client variant.
    fn from(err: alloy::contract::Error) -> Self {
        RpcClientError::Contract(err.to_string())
    }
}

impl From<SubscriptionSourceError> for RpcClientError {
    /// Convert subscription source errors into RPC client error variants.
    fn from(err: SubscriptionSourceError) -> Self {
        match err {
            SubscriptionSourceError::Connection(msg) => RpcClientError::Connection(msg),
            SubscriptionSourceError::Wallet(msg) => RpcClientError::Other(anyhow!(msg)),
            other => RpcClientError::Other(anyhow!(other)),
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
