//! Error types for RPC operations.

use alloy::transports::TransportError;
use std::result::Result as StdResult;
use thiserror::Error;

/// Result type alias for RPC operations
pub type Result<T> = StdResult<T, RpcClientError>;

/// Error types for RPC operations
#[derive(Debug, Error)]
pub enum RpcClientError {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = RpcClientError::RpcMessage("eth_chainId failed".to_string());
        assert_eq!(err.to_string(), "RPC error: eth_chainId failed");
    }
}
