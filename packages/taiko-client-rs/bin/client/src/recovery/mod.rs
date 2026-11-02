//! Immutable operator recovery preparation; persisted observations never grant authority.

pub mod plan;
pub mod prepare;
pub mod process;
pub mod profile;
pub mod status;
pub mod store;

use abci::recovery::RecoveryError;

/// Sanitized command failures: no paths, endpoint credentials, argv or provider source text.
#[derive(Debug, thiserror::Error)]
pub enum RecoveryCommandError {
    /// Unsupported or malformed private input.
    #[error("invalid recovery {0}")]
    Parse(&'static str),
    /// Filesystem operation failed; retain only its public operation label.
    #[error("recovery storage operation failed: {0}")]
    Io(&'static str),
    /// Another operation owns the exclusive publication/journal marker.
    #[error("recovery operation is busy")]
    Busy,
    /// Persisted bytes disagree with the selected immutable identity.
    #[error("recovery plan or staged artifact mismatch")]
    PlanMismatch,
    /// Missing material prevents preparation or activation.
    #[error("recovery prerequisite missing: {0}")]
    Missing(&'static str),
    /// Authenticated evidence contradicts the requested recovery.
    #[error("recovery evidence is invalid")]
    Invalid,
    /// Configured identity differs from authenticated identity.
    #[error("recovery deployment configuration mismatch")]
    ConfigMismatch,
    /// Own finalized L1 has a newer generation.
    #[error("recovery generation {requested} superseded by {current}")]
    Superseded {
        /// Requested target generation.
        requested: u64,
        /// Authenticated current generation.
        current: u64,
    },
    /// A bounded runtime read did not finish or returned an unavailable result.
    #[error("recovery runtime read unavailable: {0}")]
    Runtime(&'static str),
}

impl From<RecoveryError> for RecoveryCommandError {
    /// Retains safety classification while discarding potentially credential-bearing sources.
    fn from(error: RecoveryError) -> Self {
        match error {
            RecoveryError::Unavailable(_) => Self::Missing("authenticated L1/EL recovery history"),
            RecoveryError::Invalid(_) => Self::Invalid,
            RecoveryError::ConfigMismatch { .. } => Self::ConfigMismatch,
            RecoveryError::Superseded { requested, current } => {
                Self::Superseded { requested, current }
            }
        }
    }
}

#[cfg(test)]
mod tests;
