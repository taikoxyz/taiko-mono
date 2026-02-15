//! Error types for the preconfirmation driver node.

use alloy_contract::Error as ContractError;
use alloy_transport::TransportError;
use driver::DriverError as EmbeddedDriverError;
use rpc::RpcClientError;
use thiserror::Error;

/// Result alias for preconfirmation client operations.
pub type Result<T> = std::result::Result<T, PreconfirmationClientError>;

/// Errors from the preconfirmation driver node.
#[derive(Debug, Error)]
pub enum PreconfirmationClientError {
    /// Network error emitted by the P2P stack.
    #[error("network error: {0}")]
    Network(String),
    /// Validation failure for a commitment or txlist payload.
    #[error("validation error: {0}")]
    Validation(String),
    /// Storage layer failure (in-memory or persistent).
    #[error("storage error: {0}")]
    Storage(String),
    /// Error during driver interface operations (RPC, contract, or payload setup).
    #[error(transparent)]
    DriverInterface(#[from] DriverApiError),
    /// Codec error while decoding a txlist payload.
    #[error("codec error: {0}")]
    Codec(String),
    /// Catch-up error when syncing with peers.
    #[error("catchup error: {0}")]
    Catchup(String),
    /// Lookahead resolver error.
    #[error("lookahead error: {0}")]
    Lookahead(#[from] protocol::preconfirmation::LookaheadError),
    /// Invalid configuration parameter.
    #[error("config error: {0}")]
    Config(String),
}

/// Errors produced by driver interface operations.
#[derive(Debug, Error)]
pub enum DriverApiError {
    /// JSON-RPC error returned by the provider transport.
    #[error("rpc error: {0}")]
    Rpc(#[from] TransportError),
    /// Contract call error while fetching on-chain state.
    #[error("contract error: {0}")]
    Contract(#[from] ContractError),
    /// RPC client error returned by taiko-client-rs RPC wrappers.
    #[error("rpc client error: {0}")]
    RpcClient(#[from] RpcClientError),
    /// Embedded driver reported an error while evaluating sync state or tip.
    #[error("driver error: {0}")]
    Driver(#[from] EmbeddedDriverError),
    /// Requested block was not found.
    #[error("missing block {block_number}")]
    MissingBlock {
        /// Block number that was not found.
        block_number: u64,
    },
    /// Parent block missing the base fee field.
    #[error("missing base fee for parent block {parent_block_number}")]
    MissingBaseFee {
        /// Parent block number.
        parent_block_number: u64,
    },
    /// Safe block not found on the L2 provider.
    #[error("missing safe block")]
    MissingSafeBlock,
    /// Latest block not found on the L2 provider.
    #[error("missing latest block")]
    MissingLatestBlock,
    /// Event sync tip is unknown because canonical tip has not been established yet.
    #[error("event sync tip is unknown")]
    EventSyncTipUnknown,
    /// Missing transactions in the preconfirmation input.
    #[error("missing transactions for execution payload")]
    MissingTransactions,
    /// Proposal id exceeds the uint48 limit.
    #[error("proposal_id does not fit into uint48")]
    ProposalIdOverflow,
    /// Channel closed unexpectedly (used by embedded driver client).
    #[error("channel closed: {0}")]
    ChannelClosed(String),
}

impl From<preconfirmation_net::NetworkError> for PreconfirmationClientError {
    /// Convert a network error from the P2P layer.
    fn from(err: preconfirmation_net::NetworkError) -> Self {
        PreconfirmationClientError::Network(err.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::{DriverApiError, PreconfirmationClientError};
    use protocol::preconfirmation::LookaheadError;

    #[test]
    fn error_display_works() {
        // Create a validation error for formatting.
        let err = PreconfirmationClientError::Validation("bad signature".into());
        assert!(!err.to_string().is_empty());
    }

    #[test]
    fn driver_interface_error_display_works() {
        let err = DriverApiError::MissingBlock { block_number: 42 };
        assert_eq!(err.to_string(), "missing block 42");

        let wrapped = PreconfirmationClientError::DriverInterface(err);
        assert!(wrapped.to_string().contains("missing block 42"));
    }

    #[test]
    fn lookahead_error_preserves_variant() {
        let err = PreconfirmationClientError::from(LookaheadError::TooNew(123));
        match err {
            PreconfirmationClientError::Lookahead(LookaheadError::TooNew(ts)) => {
                assert_eq!(ts, 123);
            }
            other => panic!("unexpected error variant: {other}"),
        }
    }
}
