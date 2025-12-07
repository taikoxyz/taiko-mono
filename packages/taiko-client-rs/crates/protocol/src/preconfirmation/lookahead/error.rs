use thiserror::Error;

/// Errors emitted by the lookahead client.
#[derive(Debug, Error)]
pub enum LookaheadError {
    /// Failed to fetch or decode Inbox configuration.
    #[error("failed to fetch inbox config: {0}")]
    InboxConfig(alloy_contract::Error),
    /// Failure when querying the LookaheadStore.
    #[error("failed to call lookahead store: {0}")]
    Lookahead(alloy_contract::Error),
}

/// Result alias for lookahead operations.
pub type Result<T> = std::result::Result<T, LookaheadError>;
