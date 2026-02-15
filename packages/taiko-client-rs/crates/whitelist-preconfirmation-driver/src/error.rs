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
    /// Failed to bind the whitelist REST/WS server socket.
    #[error("failed to bind whitelist REST/WS server on {listen_addr}: {reason}")]
    RestWsServerBind {
        /// Configured listen address.
        listen_addr: std::net::SocketAddr,
        /// Underlying bind error description.
        reason: String,
    },
    /// Failed to resolve the local address from a started whitelist REST/WS server.
    #[error("failed to get whitelist REST/WS server local address: {reason}")]
    RestWsServerLocalAddr {
        /// Underlying local-address error description.
        reason: String,
    },
    /// Invalid transport configuration for the whitelist REST/WS server.
    #[error("whitelist REST/WS server requires at least one transport to be enabled")]
    RestWsServerNoTransportsEnabled,
    /// Failed to initialize the beacon client used by the whitelist REST/WS handler.
    #[error("failed to initialize beacon client for whitelist REST/WS: {reason}")]
    RestWsServerBeaconInit {
        /// Underlying beacon initialization error description.
        reason: String,
    },
    /// Signing error.
    #[error("signing error: {0}")]
    Signing(String),
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

/// Map a driver error to a whitelist preconfirmation driver error, preserving sync errors but
/// wrapping other variants.
pub(crate) fn map_driver_error(err: driver::DriverError) -> WhitelistPreconfirmationDriverError {
    match err {
        driver::DriverError::Sync(sync_err) => WhitelistPreconfirmationDriverError::Sync(sync_err),
        other => WhitelistPreconfirmationDriverError::Driver(other),
    }
}
