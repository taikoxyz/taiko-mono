//! Error types for Shasta protocol operations.

use std::result::Result as StdResult;
use thiserror::Error;

/// Result type alias for protocol operations
pub type Result<T> = StdResult<T, ProtocolError>;

/// Error types for Shasta protocol operations
#[derive(Debug, Error)]
pub enum ProtocolError {
    /// Compression error
    #[error("compression error: {0}")]
    Compression(String),

    /// Invalid payload format
    #[error("invalid payload format: {0}")]
    InvalidPayload(String),

    /// A number does not fit the 6-byte big-endian `uint48` field of the Etna `extraData`.
    #[error("Etna extraData field {field} value {value} does not fit in uint48")]
    EtnaExtraDataFieldOverflow {
        /// Name of the overflowing field (`proposal_id` or `anchor_block_number`).
        field: &'static str,
        /// Rejected value.
        value: u64,
    },

    /// A non-genesis Etna block's `extraData` is not exactly 13 bytes long.
    #[error("Etna block {block_number} has {length}-byte extraData, expected 13 bytes")]
    InvalidEtnaExtraDataLength {
        /// Number of the block whose `extraData` was decoded.
        block_number: u64,
        /// Length of the rejected `extraData`.
        length: usize,
    },
}

/// Result type alias for fork configuration lookups.
pub type ForkConfigResult<T> = StdResult<T, ForkConfigError>;

/// Errors returned when resolving fork activation metadata.
#[derive(Debug, Error)]
pub enum ForkConfigError {
    /// Chain ID is not recognised.
    #[error("unsupported chain id {0} for fork configuration")]
    UnsupportedChainId(u64),
    /// The fork activation does not have a timestamp.
    #[error("unsupported fork activation condition")]
    UnsupportedActivation,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = ProtocolError::InvalidPayload("bad format".to_string());
        assert_eq!(err.to_string(), "invalid payload format: bad format");

        let err = ProtocolError::Compression("zlib error".to_string());
        assert_eq!(err.to_string(), "compression error: zlib error");
    }
}
