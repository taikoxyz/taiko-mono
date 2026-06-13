//! Error types for the prover crate.

use base_tx_manager::TxManagerError;
use rpc::RpcClientError;
use thiserror::Error;

/// Convenience result alias for prover operations.
pub type Result<T> = std::result::Result<T, ProverError>;

/// Top-level error type for prover operations.
#[derive(Debug, Error)]
pub enum ProverError {
    /// RPC client failure (transport or contract call).
    #[error("RPC client error: {0}")]
    Rpc(#[from] RpcClientError),

    /// Transaction manager failure during proof submission.
    #[error("tx-manager error: {0}")]
    TxManager(#[from] TxManagerError),

    /// raiko request failure (HTTP or response validation).
    #[error("raiko error: {0}")]
    Raiko(#[from] crate::raiko::RaikoError),

    /// A submitted aggregation contained proposals that are already proven or were reorged out.
    #[error("aggregation contains already-proven or reorged proposals")]
    InvalidProof,

    /// Configuration error.
    #[error("invalid prover configuration: {0}")]
    Config(String),

    /// Catch-all for contextual failures.
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}
