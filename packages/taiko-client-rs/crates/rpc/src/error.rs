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

    /// Contract error preserving the underlying call failure (including revert data).
    #[error("contract error: {0}")]
    Contract(#[from] alloy::contract::Error),

    /// Generic error
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

impl RpcClientError {
    /// Return whether the error is the execution client reporting that no finalized block
    /// exists yet (e.g. fresh devnets before the beacon chain finalized its first epoch).
    ///
    /// Inspects the structured JSON-RPC error payload instead of the stringified error chain so
    /// wrapper formatting changes cannot break the detection. The message wording itself is
    /// client-specific (geth) and intentionally centralized here.
    pub fn is_finalized_block_unavailable(&self) -> bool {
        match self {
            Self::Rpc(err) | Self::Contract(alloy::contract::Error::TransportError(err)) => {
                transport_error_reports_missing_finalized_block(err)
            }
            _ => false,
        }
    }
}

/// Check a transport error's JSON-RPC payload for geth's missing-finalized-block message.
fn transport_error_reports_missing_finalized_block(err: &TransportError) -> bool {
    err.as_error_resp().is_some_and(|payload| payload.message.contains(FINALIZED_BLOCK_NOT_FOUND))
}

/// JSON-RPC error message fragment geth returns while the chain has no finalized block.
const FINALIZED_BLOCK_NOT_FOUND: &str = "finalized block not found";

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

    /// Build the JSON-RPC error geth reports before the first finalized block exists.
    fn missing_finalized_block_transport_error() -> TransportError {
        TransportError::ErrorResp(alloy::rpc::json_rpc::ErrorPayload {
            code: -32000,
            message: FINALIZED_BLOCK_NOT_FOUND.into(),
            data: None,
        })
    }

    #[test]
    fn finalized_block_unavailable_detected_on_transport_error() {
        let err = RpcClientError::Rpc(missing_finalized_block_transport_error());
        assert!(err.is_finalized_block_unavailable());
    }

    #[test]
    fn finalized_block_unavailable_detected_through_contract_error() {
        let err = RpcClientError::Contract(alloy::contract::Error::TransportError(
            missing_finalized_block_transport_error(),
        ));
        assert!(err.is_finalized_block_unavailable());
    }

    #[test]
    fn finalized_block_unavailable_ignores_other_errors() {
        let other_resp = TransportError::ErrorResp(alloy::rpc::json_rpc::ErrorPayload {
            code: -32000,
            message: "execution aborted".into(),
            data: None,
        });
        assert!(!RpcClientError::Rpc(other_resp).is_finalized_block_unavailable());
        assert!(!RpcClientError::Connection("boom".into()).is_finalized_block_unavailable());
    }
}
