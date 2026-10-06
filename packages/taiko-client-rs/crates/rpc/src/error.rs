//! Error types for RPC operations.

use alloy::transports::TransportError;
use alloy_primitives::B256;
use anyhow::anyhow;
use protocol::{shasta::error::ForkConfigError, subscription_source::SubscriptionSourceError};
use std::result::Result as StdResult;
use thiserror::Error;

use crate::client::EtnaScheduleHead;

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

    /// Contract error
    #[error("contract error: {0}")]
    Contract(String),

    /// The Etna activation time of the client's chain cannot be resolved.
    #[error("cannot resolve the Etna fork schedule of chain {chain_id}")]
    EtnaScheduleUnresolved {
        /// Chain id whose fork schedule was consulted.
        chain_id: u64,
        /// Underlying fork-configuration error.
        #[source]
        source: ForkConfigError,
    },

    /// The L2 head contradicts the client's Etna fork schedule.
    #[error(
        "L2 head block {} (timestamp {}, parentBeaconBlockRoot {}, extraData length {}) is {}, \
         but the client's fork schedule expects {expected_fork} at that timestamp: the client's \
         Etna activation time must match the execution engine's (on a devnet, set \
         --devnet-etna-timestamp to the execution engine's Etna time)",
        head.number,
        head.timestamp,
        display_root(head.parent_beacon_block_root),
        head.extra_data_len,
        head_fork(head),
    )]
    EtnaScheduleMismatch {
        /// The L2 head that contradicts the schedule.
        head: EtnaScheduleHead,
        /// The fork the client's schedule expects at the head's timestamp.
        expected_fork: &'static str,
    },

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

/// Render an optional `parentBeaconBlockRoot` for error messages (`none` when absent).
fn display_root(root: Option<B256>) -> String {
    root.map_or_else(|| "none".to_string(), |root| root.to_string())
}

/// Describe the fork a schedule-check head belongs to, by its header shape.
fn head_fork(head: &EtnaScheduleHead) -> &'static str {
    if head.is_etna_block() { "an Etna block" } else { "a pre-Etna block" }
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
    }
}
