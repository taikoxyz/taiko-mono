//! Error types for the CLI.
//!
//! This module defines the unified error type [`CliError`] used throughout the CLI binary.
//! It consolidates errors from downstream crates (driver, proposer, rpc, preconfirmation-driver)
//! as well as CLI-specific errors like URL parsing, runtime initialization, and metrics setup.

use thiserror::Error;

/// Errors that can occur during CLI execution.
///
/// This enum covers all error cases in the CLI binary, including:
/// - Errors propagated from downstream crates (driver, proposer, rpc, preconfirmation-driver)
/// - Configuration errors (URL parsing, socket address parsing)
/// - Runtime errors (tokio runtime initialization, I/O)
/// - Metrics initialization errors
#[derive(Debug, Error)]
pub enum CliError {
    /// Error from the driver crate.
    ///
    /// Wraps [`driver::DriverError`] for errors occurring during driver operations
    /// such as event syncing, block derivation, and execution engine communication.
    #[error(transparent)]
    Driver(#[from] driver::DriverError),

    /// Error from the driver sync module.
    ///
    /// Wraps [`driver::sync::SyncError`] for errors occurring during event syncer
    /// initialization and synchronization operations.
    #[error(transparent)]
    Sync(#[from] driver::sync::SyncError),

    /// Error from the proposer crate.
    ///
    /// Wraps [`proposer::error::ProposerError`] for errors occurring during block proposal
    /// operations such as transaction building and L1 submission.
    #[error(transparent)]
    Proposer(#[from] proposer::error::ProposerError),

    /// Error from the RPC client crate.
    ///
    /// Wraps [`rpc::RpcClientError`] for errors occurring during RPC client
    /// initialization and provider communication.
    #[error(transparent)]
    Rpc(#[from] rpc::RpcClientError),

    /// Error from the preconfirmation driver crate.
    ///
    /// Wraps [`preconfirmation_driver::PreconfirmationClientError`] for errors
    /// occurring during P2P networking, commitment validation, and catchup sync.
    #[error(transparent)]
    Preconfirmation(#[from] preconfirmation_driver::PreconfirmationClientError),

    /// Error from the preconfirmation driver runner.
    ///
    /// Wraps [`preconfirmation_driver::RunnerError`] for errors occurring during
    /// preconfirmation driver orchestration.
    #[error(transparent)]
    PreconfirmationRunner(#[from] preconfirmation_driver::RunnerError),

    /// Failed to parse a URL.
    ///
    /// Occurs when parsing endpoint URLs from command-line arguments fails.
    /// Common causes include malformed URLs or unsupported schemes.
    #[error("failed to parse URL: {0}")]
    UrlParse(#[from] url::ParseError),

    /// Runtime initialization or I/O error.
    ///
    /// Wraps [`std::io::Error`] for errors occurring during tokio runtime
    /// initialization or general I/O operations.
    #[error("runtime error: {0}")]
    Runtime(#[from] std::io::Error),

    /// Failed to parse a socket address.
    ///
    /// Occurs when parsing metrics server addresses from command-line arguments fails.
    #[error("invalid socket address: {0}")]
    AddrParse(#[from] std::net::AddrParseError),

    /// Failed to initialize the metrics exporter.
    ///
    /// Occurs when the Prometheus metrics exporter fails to start,
    /// typically due to port binding issues or configuration errors.
    #[error("metrics initialization failed: {0}")]
    MetricsInit(#[from] metrics_exporter_prometheus::BuildError),

    /// Preconfirmation ingress was not enabled on the driver.
    ///
    /// Occurs when the preconfirmation driver command is run but the underlying
    /// event syncer does not have preconfirmation ingress enabled. This typically
    /// indicates a configuration mismatch.
    #[error("preconfirmation ingress not enabled on driver")]
    PreconfIngressNotEnabled,
}

/// Result alias for CLI operations.
///
/// This type alias simplifies function signatures throughout the CLI binary
/// by using [`CliError`] as the default error type.
pub type Result<T> = std::result::Result<T, CliError>;
