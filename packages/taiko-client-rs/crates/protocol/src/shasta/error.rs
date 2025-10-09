//! Error types for Shasta protocol operations.

use std::result::Result as StdResult;
use thiserror::Error;

/// Result type alias for protocol operations
pub type Result<T> = StdResult<T, ProtocolError>;

/// Error types for Shasta protocol operations
#[derive(Debug, Error)]
pub enum ProtocolError {
    /// IO error during encoding/decoding
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    /// RLP encoding/decoding error
    #[error("RLP error: {0}")]
    Rlp(String),

    /// Compression error
    #[error("compression error: {0}")]
    Compression(String),

    /// Invalid payload format
    #[error("invalid payload format: {0}")]
    InvalidPayload(String),

    /// Generic error
    #[error(transparent)]
    Other(#[from] anyhow::Error),
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
