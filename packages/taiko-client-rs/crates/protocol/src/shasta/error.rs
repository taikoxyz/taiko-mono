//! Error types for Shasta protocol operations.

use std::result::Result as StdResult;
use thiserror::Error;

/// Result type alias for protocol operations
pub type Result<T> = StdResult<T, ProtocolError>;

/// Error types for Shasta protocol operations
#[derive(Debug, Error)]
pub enum ProtocolError {
    /// A number does not fit the 6-byte big-endian `uint48` field of the Etna `extraData`.
    #[error("Etna extraData field {field} value {value} does not fit in uint48")]
    EtnaExtraDataFieldOverflow {
        /// Name of the overflowing field (`generation` or `anchor_block_number`).
        field: &'static str,
        /// Rejected value.
        value: u64,
    },
}
