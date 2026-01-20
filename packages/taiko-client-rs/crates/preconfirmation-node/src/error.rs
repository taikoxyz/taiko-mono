//! Error types for the preconfirmation node SDK.

use alloy_contract::Error as ContractError;
use alloy_transport::TransportError;
use driver::error::DriverError;
use thiserror::Error;

/// Result alias for preconfirmation node operations.
pub type Result<T> = std::result::Result<T, PreconfirmationNodeError>;

/// Errors surfaced by the preconfirmation node SDK.
#[derive(Debug, Error)]
pub enum PreconfirmationNodeError {
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
    /// Lookahead resolver initialization failed.
    #[error("lookahead error: {0}")]
    Lookahead(String),
    /// Invalid configuration parameter.
    #[error("config error: {0}")]
    Config(String),
    /// Embedded driver error.
    #[error("embedded driver error: {0}")]
    Driver(#[from] DriverError),
    /// JSON-RPC server error.
    #[error("rpc server error: {0}")]
    RpcServer(String),
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
    /// Missing transactions in the preconfirmation input.
    #[error("missing transactions for execution payload")]
    MissingTransactions,
    /// Proposal id exceeds the uint48 limit.
    #[error("proposal_id does not fit into uint48")]
    ProposalIdOverflow,
}

/// Legacy type alias for backwards compatibility.
pub type PreconfirmationClientError = PreconfirmationNodeError;

impl From<preconfirmation_net::NetworkError> for PreconfirmationClientError {
    /// Convert a network error from the P2P layer.
    fn from(err: preconfirmation_net::NetworkError) -> Self {
        PreconfirmationClientError::Network(err.to_string())
    }
}

impl From<protocol::preconfirmation::LookaheadError> for PreconfirmationClientError {
    /// Convert a lookahead resolver error into an SDK error.
    fn from(err: protocol::preconfirmation::LookaheadError) -> Self {
        PreconfirmationClientError::Lookahead(err.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::{DriverApiError, PreconfirmationClientError};

    /// Ensure error variants format correctly.
    #[test]
    fn error_display_works() {
        let err = PreconfirmationClientError::Validation("bad signature".into());
        assert!(!err.to_string().is_empty());
    }

    /// Ensure driver interface errors bubble with context.
    #[test]
    fn driver_interface_error_display_works() {
        let err = DriverApiError::MissingBlock { block_number: 42 };
        assert_eq!(err.to_string(), "missing block 42");

        let wrapped = PreconfirmationClientError::DriverInterface(err);
        assert!(wrapped.to_string().contains("missing block 42"));
    }
}
