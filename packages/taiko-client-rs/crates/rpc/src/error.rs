//! Error types for RPC operations.

use alloy::transports::TransportError;
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

    /// The execution engine does not advertise every Engine API method the client calls.
    #[error(
        "the execution engine does not serve {missing:?} (it advertises {advertised:?}); this \
         client calls only engine_forkchoiceUpdatedV3, engine_getPayloadV5 and \
         engine_newPayloadV4, so it needs an alethia-reth release with the Osaka Engine API"
    )]
    EngineMethodsUnsupported {
        /// Required methods missing from the engine's list.
        missing: Vec<&'static str>,
        /// Methods the engine advertised through `engine_exchangeCapabilities`.
        advertised: Vec<String>,
    },

    /// Generic error
    #[error(transparent)]
    Other(#[from] anyhow::Error),
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
    }
}
