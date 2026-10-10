//! Error types for the CLI.
//!
//! This module defines the unified error type [`CliError`] used throughout the CLI binary.
//! It consolidates errors from downstream crates (rpc, abci) as well as CLI-specific errors like
//! runtime initialization, signal handling and metrics setup.

use std::path::PathBuf;

use thiserror::Error;

/// Errors that can occur during CLI execution.
///
/// This enum covers all error cases in the CLI binary, including:
/// - Errors propagated from downstream crates (rpc, abci)
/// - Configuration errors (socket address parsing, chain parameters)
/// - Runtime errors (tokio runtime initialization, shutdown signal handlers, I/O)
/// - Metrics initialization errors
#[derive(Debug, Error)]
pub enum CliError {
    /// Error from the RPC client crate.
    ///
    /// Wraps [`rpc::RpcClientError`] for errors occurring during RPC client
    /// initialization and provider communication.
    #[error(transparent)]
    Rpc(#[from] rpc::RpcClientError),

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

    /// The ABCI app failed to start (e.g. an inconsistent persisted state); boxed, as the app
    /// error is large.
    #[error(transparent)]
    Abci(Box<abci::AbciError>),

    /// The chain parameters are not built in for the L2 chain id, or the `--chain-config`
    /// override is malformed or invalid.
    #[error("chain parameters: {0}")]
    ChainConfig(#[from] abci::ConfigError),

    /// The `--chain-config` file could not be read.
    #[error("cannot read the chain config {path}: {source}")]
    ChainConfigRead {
        /// The `--chain-config` path.
        path: PathBuf,
        /// The read error.
        source: std::io::Error,
    },

    /// The execution-engine client could not be built or lacks a required Engine API method.
    #[error("execution engine: {0}")]
    Engine(#[from] abci::EngineError),

    /// The ABCI server failed (bad address, listener failure, or the app worker stopped).
    #[error(transparent)]
    AbciServer(#[from] abci::ServerError),

    /// The genesis could not be built from L1 (an L1 read failed, the activation record is not
    /// final or active, or the L1 facts fail the `InitChain` checks).
    #[error("genesis: {0}")]
    Genesis(#[from] abci::GenesisError),

    /// The activation's committee record could not be computed (an L1 read failed, the proving
    /// block is not after the genesis cutoff, or no registry entry is eligible at it).
    #[error("committee record: {0}")]
    CommitteeRecord(#[from] abci::CommitteeRecordError),

    /// The `--out` genesis file could not be written.
    #[error("cannot write the genesis to {path}: {source}")]
    GenesisWrite {
        /// The `--out` path.
        path: PathBuf,
        /// The write error.
        source: std::io::Error,
    },
}

impl From<abci::AbciError> for CliError {
    /// Wraps the app error in [`CliError::Abci`].
    fn from(e: abci::AbciError) -> Self {
        Self::Abci(Box::new(e))
    }
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
    /// hints, which the derived `Debug` output omits.
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
    use rpc::RpcClientError;

    /// An error whose message leaves out its source.
    #[derive(Debug, thiserror::Error)]
    #[error("could not bind the metrics port")]
    struct BindError(#[source] std::io::Error);

    #[test]
    fn report_skips_a_cause_the_message_already_embeds() {
        let report = CliError::from(std::io::Error::other("disk full")).report();

        assert_eq!(report, "runtime error: disk full");
    }

    #[test]
    fn report_lists_causes_the_message_leaves_out() {
        let err = std::io::Error::other(BindError(std::io::Error::other("address in use")));
        let report = CliError::from(err).report();

        assert_eq!(
            report,
            "runtime error: could not bind the metrics port\n  caused by: address in use"
        );
    }

    #[test]
    fn report_keeps_a_plain_message() {
        assert_eq!(
            CliError::from(RpcClientError::RpcMessage("missing L2 latest block".to_string()))
                .report(),
            "RPC error: missing L2 latest block"
        );
    }
}
