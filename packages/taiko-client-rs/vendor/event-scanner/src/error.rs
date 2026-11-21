use std::{mem::discriminant, sync::Arc};

use alloy::transports::{RpcError, TransportErrorKind};
use thiserror::Error;

use crate::types::ScannerResult;

use robust_provider::Error as RobustProviderError;

/// Errors emitted by the scanner.
///
/// `ScannerError` values can be returned by builder `connect()` methods and are also yielded by
/// subscription streams (as `Err(ScannerError)` items).
///
/// All errors except [`ScannerError::Lagged`] are terminal and will halt further stream processing.
#[derive(Error, Debug, Clone)]
pub enum ScannerError {
    /// The underlying RPC transport returned an error.
    #[error("RPC error: {0}")]
    RpcError(Arc<RpcError<TransportErrorKind>>),

    /// A requested block (by number, hash or tag) could not be retrieved.
    #[error("Block not found")]
    BlockNotFound,

    /// A timeout elapsed while waiting for an RPC response.
    #[error("Operation timed out")]
    Timeout,

    /// A configured block parameter exceeds the latest known block.
    #[error("{0} {1} exceeds the latest block {2}")]
    BlockExceedsLatest(&'static str, u64, u64),

    /// The requested event count is invalid (must be greater than zero).
    #[error("Event count must be greater than 0")]
    InvalidEventCount,

    /// The configured maximum block range is invalid (must be greater than zero).
    #[error("Max block range must be greater than 0")]
    InvalidMaxBlockRange,

    /// The configured stream buffer capacity is invalid (must be greater than zero).
    #[error("Stream buffer capacity must be greater than 0")]
    InvalidBufferCapacity,

    /// The configured maximum number of concurrent fetches is invalid (must be greater than
    /// zero).
    #[error("Max concurrent fetches must be greater than 0")]
    InvalidMaxConcurrentFetches,

    /// A block subscription ended (for example, the underlying WebSocket subscription closed).
    #[error("Subscription closed")]
    SubscriptionClosed,

    /// A subscription consumer could not keep up and some internal messages were skipped.
    ///
    /// The contained value is the number of skipped messages reported by the underlying channel.
    /// After emitting this error, the subscription stream may continue with newer items.
    #[error("Subscription lagged")]
    Lagged(u64),
}

impl From<RobustProviderError> for ScannerError {
    fn from(error: RobustProviderError) -> ScannerError {
        match error {
            RobustProviderError::Timeout => ScannerError::Timeout,
            RobustProviderError::RpcError(err) => ScannerError::RpcError(Arc::new(err)),
            RobustProviderError::BlockNotFound => ScannerError::BlockNotFound,
            RobustProviderError::Lagged(blocks) => ScannerError::Lagged(blocks),
            RobustProviderError::Closed => ScannerError::SubscriptionClosed,
        }
    }
}

impl From<RpcError<TransportErrorKind>> for ScannerError {
    fn from(error: RpcError<TransportErrorKind>) -> Self {
        ScannerError::RpcError(Arc::new(error))
    }
}

impl<T: Clone> PartialEq<ScannerError> for ScannerResult<T> {
    fn eq(&self, other: &ScannerError) -> bool {
        match self {
            Ok(_) => false,
            Err(err) => discriminant(err) == discriminant(other),
        }
    }
}
