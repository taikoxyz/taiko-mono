//! Shared retry-versus-stop error classification.

/// A lander result, retaining operational context in errors.
pub type Result<T> = std::result::Result<T, LanderError>;

/// Why preparation or submission cannot proceed.
#[derive(Debug, thiserror::Error)]
pub enum LanderError {
    /// Invalid operator configuration, schema, or contract identity.
    #[error("invalid lander configuration: {0}")]
    Configuration(String),
    /// Invalid source data or an authenticated-chain contradiction.
    #[error("lander safety check failed: {0}")]
    Safety(String),
    /// History is absent or pruned at the specified height or epoch.
    #[error("unavailable lander history: {0}")]
    Unavailable(String),
    /// A temporary endpoint or finality condition; safe to retry.
    #[error("temporary lander failure: {0}")]
    Temporary(String),
    /// Data cannot be represented within the explicit configured limits.
    #[error("lander capacity exceeded: {0}")]
    Capacity(String),
    /// Encoded batch or journal bytes are malformed or noncanonical.
    #[error("invalid lander encoding: {0}")]
    Encoding(String),
    /// A newer on-chain checkpoint made unbroadcast work obsolete.
    #[error("landing job became stale: {0}")]
    Stale(String),
    /// A transaction reverted without competing progress.
    #[error("landing transaction reverted: {0}")]
    Reverted(String),
    /// Durable state could not be read, written, or exclusively locked.
    #[error("lander journal failure: {0}")]
    Journal(String),
}

impl LanderError {
    /// Whether the runner may retry this condition with bounded backoff.
    pub const fn is_retryable(&self) -> bool {
        matches!(self, Self::Temporary(_) | Self::Unavailable(_) | Self::Stale(_))
    }
}
