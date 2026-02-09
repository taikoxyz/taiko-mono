//! Error types for whitelist preconfirmation driver.

use std::result::Result as StdResult;

use thiserror::Error;

/// Result alias for whitelist preconfirmation driver operations.
pub type Result<T> = StdResult<T, WhitelistPreconfirmationDriverError>;

/// Errors emitted by the whitelist preconfirmation driver.
#[derive(Debug, Error)]
pub enum WhitelistPreconfirmationDriverError {
    /// Event syncer exited before preconfirmation ingress was ready.
    #[error("event syncer exited before preconfirmation ingress was ready")]
    EventSyncerExited,
    /// Event syncer task failed.
    #[error("event syncer failed: {0}")]
    EventSyncerFailed(String),
    /// Whitelist preconfirmation node task failed.
    #[error("whitelist preconfirmation node task failed: {0}")]
    NodeTaskFailed(String),
    /// Preconfirmation ingress was not enabled on the driver.
    #[error("preconfirmation ingress not enabled on driver")]
    PreconfIngressNotEnabled,
    /// Driver preconfirmation ingress is not ready.
    #[error("driver preconfirmation ingress not ready")]
    PreconfIngressNotReady,
    /// Unsupported chain for whitelist preconfirmation mode.
    #[error(
        "whitelist preconfirmation mode currently supports only chain_id={expected}, got {actual}"
    )]
    UnsupportedChain {
        /// Expected chain id.
        expected: u64,
        /// Actual chain id.
        actual: u64,
    },
    /// Missing execution payload in envelope.
    #[error("missing execution payload")]
    MissingExecutionPayload,
    /// Invalid or unsupported payload format.
    #[error("invalid payload format: {0}")]
    InvalidPayload(String),
    /// Signature validation failed.
    #[error("signature validation failed: {0}")]
    InvalidSignature(String),
    /// Envelope insertion produced an unexpected hash.
    #[error(
        "inserted block hash mismatch at block {block_number}: expected {expected}, got {actual}"
    )]
    InsertedBlockHashMismatch {
        /// Block number.
        block_number: u64,
        /// Expected hash.
        expected: alloy_primitives::B256,
        /// Actual hash.
        actual: alloy_primitives::B256,
    },
    /// Missing inserted block after successful submission.
    #[error("missing inserted block at number {0}")]
    MissingInsertedBlock(u64),
    /// Failed to resolve preconfirmation whitelist operators.
    #[error("whitelist operator lookup failed: {0}")]
    WhitelistLookup(String),
    /// P2P network error.
    #[error("p2p error: {0}")]
    P2p(String),
    /// Driver sync error.
    #[error(transparent)]
    Sync(#[from] driver::sync::SyncError),
    /// Driver error.
    #[error(transparent)]
    Driver(#[from] driver::DriverError),
    /// RPC client error.
    #[error(transparent)]
    Rpc(#[from] rpc::RpcClientError),
}
