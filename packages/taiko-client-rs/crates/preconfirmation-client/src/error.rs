//! Error types for the preconfirmation client SDK.

use thiserror::Error;

/// Result alias for preconfirmation client operations.
pub type Result<T> = std::result::Result<T, PreconfirmationClientError>;

/// Errors surfaced by the preconfirmation client SDK.
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
    /// Error returned by the driver client callback.
    #[error("driver client error: {0}")]
    DriverClient(String),
    /// Codec error while decoding a txlist payload.
    #[error("codec error: {0}")]
    Codec(String),
    /// Catch-up error when syncing with peers.
    #[error("catchup error: {0}")]
    Catchup(String),
    /// Parent commitment is missing; the commitment should be buffered.
    #[error("parent commitment missing: {0}")]
    ParentMissing(String),
    /// Lookahead resolver initialization failed.
    #[error("lookahead error: {0}")]
    Lookahead(String),
    /// Invalid configuration parameter.
    #[error("config error: {0}")]
    Config(String),
}

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
    use super::PreconfirmationClientError;

    #[test]
    fn error_display_works() {
        // Create a validation error for formatting.
        let err = PreconfirmationClientError::Validation("bad signature".into());
        assert!(!err.to_string().is_empty());
    }
}
