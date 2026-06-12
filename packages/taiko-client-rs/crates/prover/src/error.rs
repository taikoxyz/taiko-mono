//! Error types for the prover crate.

use base_tx_manager::TxManagerError;
use rpc::RpcClientError;

/// Convenience result alias for prover operations.
pub type Result<T> = std::result::Result<T, ProverError>;

/// Top-level error type for prover operations.
#[derive(Debug, thiserror::Error)]
pub enum ProverError {
    /// RPC client failure (transport or contract call).
    #[error(transparent)]
    Rpc(#[from] RpcClientError),
    /// Transaction manager failure during proof submission.
    #[error(transparent)]
    TxManager(#[from] TxManagerError),
    /// A submitted aggregation contained proposals that are already proven.
    #[error("aggregation contains already-proven or reorged proposals")]
    InvalidProof,
    /// Proposal is outside the configured proving range (deferred, retried later).
    #[error("proposal {0} out of allowed proving range")]
    ProposalOutOfRange(u64),
    /// Configuration error.
    #[error("invalid prover configuration: {0}")]
    Config(String),
    /// Catch-all for contextual failures.
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}
