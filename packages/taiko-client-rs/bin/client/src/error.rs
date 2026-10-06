//! Error types for the CLI.
//!
//! This module defines the unified error type [`CliError`] used throughout the CLI binary.
//! It consolidates errors from downstream crates (driver, proposer, rpc)
//! and whitelist-preconfirmation-driver, as well as CLI-specific errors like URL parsing, runtime
//! initialization, and metrics setup.

use thiserror::Error;

/// Errors that can occur during CLI execution.
///
/// This enum covers all error cases in the CLI binary, including:
/// - Errors propagated from downstream crates (driver, proposer, rpc,
///   whitelist-preconfirmation-driver)
/// - Configuration errors (URL parsing, socket address parsing)
/// - Runtime errors (tokio runtime initialization, shutdown signal handlers, I/O)
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

    /// Error from the whitelist preconfirmation driver.
    ///
    /// Wraps [`whitelist_preconfirmation_driver::WhitelistPreconfirmationDriverError`] for
    /// whitelist preconfirmation message validation and insertion failures.
    #[error(transparent)]
    WhitelistPreconfirmation(
        #[from] whitelist_preconfirmation_driver::WhitelistPreconfirmationDriverError,
    ),

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

    /// The shutdown signal handlers could not be installed, or stopped working.
    ///
    /// Occurs when the SIGINT or SIGTERM handler cannot be registered with the tokio signal
    /// driver at startup, or when the SIGTERM stream closes later. Both are fatal: tokio
    /// registers handlers process-wide and never removes them, so continuing could leave a
    /// half-installed set behind that swallows a signal nobody is listening for.
    #[error("shutdown signal handler failure: {0}")]
    SignalHandler(std::io::Error),

    /// Failed to parse a socket address.
    ///
    /// Occurs when parsing metrics server addresses from command-line arguments fails.
    #[error("invalid socket address: {0}")]
    AddrParse(#[from] std::net::AddrParseError),

    /// Invalid L1 transport configuration.
    ///
    /// Occurs when CLI arguments or programmatic construction provide either zero or multiple
    /// L1 endpoints.
    #[error("configure exactly one of --l1.http / L1_HTTP or --l1.ws / L1_WS")]
    InvalidL1EndpointConfig,
}

/// Result alias for CLI operations.
///
/// This type alias simplifies function signatures throughout the CLI binary
/// by using [`CliError`] as the default error type.
pub type Result<T> = std::result::Result<T, CliError>;

impl CliError {
    /// Render the error for an operator: its message, then each underlying cause on its own
    /// line.
    ///
    /// A cause is skipped when the message before it already contains its text, since most
    /// wrappers embed their source in their own message. The messages carry the remediation
    /// hints (e.g. for `--devnet-etna-timestamp`), which the derived `Debug` output omits.
    pub fn report(&self) -> String {
        let mut report = self.to_string();
        let mut previous = report.clone();
        let mut source = std::error::Error::source(self);
        while let Some(cause) = source {
            let message = cause.to_string();
            if !previous.contains(&message) {
                report.push_str("\n  caused by: ");
                report.push_str(&message);
            }
            previous = message;
            source = cause.source();
        }
        report
    }
}

#[cfg(test)]
mod tests {
    use super::CliError;
    use driver::{
        DriverError,
        derivation::DerivationError,
        sync::{SyncError, error::EngineSubmissionError},
    };
    use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;
    use rpc::{
        RpcClientError,
        client::{EtnaScheduleHead, check_etna_schedule_for_head},
    };

    #[test]
    fn report_shows_the_schedule_hint_once() {
        let head = EtnaScheduleHead {
            number: 5,
            timestamp: 1_000,
            parent_beacon_block_root: None,
            extra_data_len: 7,
        };
        let mismatch =
            check_etna_schedule_for_head(TAIKO_DEVNET_CHAIN_ID, Some(1_000), head).unwrap_err();
        let report = CliError::from(DriverError::Rpc(mismatch)).report();

        assert!(report.starts_with("rpc error: L2 head block 5"), "{report}");
        assert_eq!(report.matches("--devnet-etna-timestamp").count(), 1, "{report}");
        assert!(!report.contains("caused by"), "{report}");
    }

    #[test]
    fn report_lists_causes_the_message_leaves_out() {
        let err = DriverError::Sync(SyncError::Derivation(DerivationError::Engine(
            EngineSubmissionError::InvalidBlock(7, "bad state root".to_string()),
        )));
        let report = CliError::from(err).report();

        assert_eq!(
            report,
            "derivation failed\n  caused by: execution engine rejected block 7: bad state root"
        );
        assert!(!report.contains("RpcClientError"), "{report}");
    }

    #[test]
    fn report_keeps_a_plain_message() {
        assert_eq!(
            CliError::from(RpcClientError::Provider("missing L2 latest block".to_string()))
                .report(),
            "provider error: missing L2 latest block"
        );
    }
}
