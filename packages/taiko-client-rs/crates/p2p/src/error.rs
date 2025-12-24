//! Error types for the P2P SDK.
//!
//! This module defines the SDK-level error type that wraps network-level errors
//! and adds SDK-specific failure modes.

use preconfirmation_net::NetworkError;
use thiserror::Error;

/// SDK-level error type wrapping network and application failures.
///
/// This enum captures all error conditions that can arise during P2P SDK
/// operations, including network-level failures from `preconfirmation-net`
/// and SDK-specific errors like validation failures and storage issues.
#[derive(Debug, Error)]
pub enum P2pClientError {
    /// Network-level error from the underlying P2P layer.
    #[error("network error: {0}")]
    Network(NetworkError),

    /// Validation failure for a message or commitment.
    #[error("validation error: {0}")]
    Validation(String),

    /// Storage operation failed.
    #[error("storage error: {0}")]
    Storage(String),

    /// Operation timed out.
    #[error("timeout: {0}")]
    Timeout(String),

    /// Channel backpressure - unable to send due to full channel.
    #[error("backpressure: {0}")]
    Backpressure(String),

    /// Failed to decode a message.
    #[error("decode error: {0}")]
    Decode(String),

    /// The SDK has been shut down.
    #[error("sdk shutdown")]
    Shutdown,

    /// Required data is missing.
    #[error("missing data: {0}")]
    MissingData(String),

    /// A spawned task panicked or was cancelled.
    #[error("join error: {0}")]
    Join(String),
}

impl From<NetworkError> for P2pClientError {
    fn from(err: NetworkError) -> Self {
        P2pClientError::Network(err)
    }
}

impl From<tokio::time::error::Elapsed> for P2pClientError {
    fn from(err: tokio::time::error::Elapsed) -> Self {
        P2pClientError::Timeout(err.to_string())
    }
}

impl<T> From<tokio::sync::mpsc::error::SendError<T>> for P2pClientError {
    fn from(err: tokio::sync::mpsc::error::SendError<T>) -> Self {
        P2pClientError::Backpressure(format!("channel send failed: {}", err))
    }
}

impl<T> From<tokio::sync::mpsc::error::TrySendError<T>> for P2pClientError {
    fn from(err: tokio::sync::mpsc::error::TrySendError<T>) -> Self {
        match err {
            tokio::sync::mpsc::error::TrySendError::Full(_) => {
                P2pClientError::Backpressure("channel full".to_string())
            }
            tokio::sync::mpsc::error::TrySendError::Closed(_) => {
                P2pClientError::Backpressure("channel closed".to_string())
            }
        }
    }
}

impl From<tokio::sync::oneshot::error::RecvError> for P2pClientError {
    fn from(_: tokio::sync::oneshot::error::RecvError) -> Self {
        P2pClientError::Shutdown
    }
}

impl From<tokio::task::JoinError> for P2pClientError {
    fn from(err: tokio::task::JoinError) -> Self {
        P2pClientError::Join(err.to_string())
    }
}

/// Result type alias for P2P SDK operations.
pub type P2pResult<T> = Result<T, P2pClientError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_converts_from_network_error() {
        use preconfirmation_net::{NetworkError, NetworkErrorKind};

        let err = NetworkError::new(NetworkErrorKind::Other, "boom");
        let sdk: P2pClientError = err.into();
        assert!(matches!(sdk, P2pClientError::Network(_)));
    }

    #[test]
    fn error_display_includes_context() {
        use preconfirmation_net::{NetworkError, NetworkErrorKind};

        let err = NetworkError::new(NetworkErrorKind::ReqRespTimeout, "request timed out");
        let sdk: P2pClientError = err.into();
        let display = format!("{}", sdk);
        assert!(display.contains("network error"));
    }

    #[test]
    fn all_variants_are_covered() {
        // Ensure all error variants can be constructed
        let _ = P2pClientError::Network(preconfirmation_net::NetworkError::new(
            preconfirmation_net::NetworkErrorKind::Other,
            "test",
        ));
        let _ = P2pClientError::Validation("invalid data".to_string());
        let _ = P2pClientError::Storage("storage failure".to_string());
        let _ = P2pClientError::Timeout("operation timed out".to_string());
        let _ = P2pClientError::Backpressure("channel full".to_string());
        let _ = P2pClientError::Decode("decode failure".to_string());
        let _ = P2pClientError::Shutdown;
        let _ = P2pClientError::MissingData("data not found".to_string());
        let _ = P2pClientError::Join("task panicked".to_string());
    }

    #[test]
    fn error_converts_from_send_error() {
        use tokio::sync::mpsc;

        // Create a channel and drop the receiver to force a send error
        let (tx, rx) = mpsc::channel::<u32>(1);
        drop(rx);

        // Try to send - this will fail because receiver is dropped
        let result = tx.try_send(42);
        if let Err(e) = result {
            let sdk: P2pClientError = e.into();
            assert!(matches!(sdk, P2pClientError::Backpressure(_)));
        }
    }

    #[test]
    fn error_converts_from_recv_error() {
        use tokio::sync::oneshot;

        let (tx, rx) = oneshot::channel::<u32>();
        drop(tx);

        // The receiver would error if we tried to await it
        // For the sync test, we use blocking_recv which returns an error
        let result = rx.blocking_recv();
        if let Err(e) = result {
            let sdk: P2pClientError = e.into();
            assert!(matches!(sdk, P2pClientError::Shutdown));
        }
    }

    #[test]
    fn result_type_alias_works() {
        fn example_fn() -> P2pResult<u32> {
            Ok(42)
        }

        fn failing_fn() -> P2pResult<u32> {
            Err(P2pClientError::Shutdown)
        }

        assert!(example_fn().is_ok());
        assert!(failing_fn().is_err());
    }
}
