//! Errors specific to block production routing.

use crate::error::DriverError;

use super::kind::ProductionPathKind;

/// Errors emitted by production routing and path selection.
#[derive(thiserror::Error, Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProductionError {
    /// Input was dispatched to a path that does not support it.
    #[error("{input:?} input is unsupported by {path:?} path")]
    UnsupportedInput { path: ProductionPathKind, input: ProductionPathKind },

    /// No registered path can handle the requested input kind.
    #[error("no production path registered for input {kind:?}")]
    MissingPath { kind: ProductionPathKind },
}

impl From<ProductionError> for DriverError {
    /// Convert a `ProductionError` into a generic `DriverError::Other`.
    fn from(err: ProductionError) -> Self {
        DriverError::Other(err.into())
    }
}
