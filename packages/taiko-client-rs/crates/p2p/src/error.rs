use std::time::Duration;

use preconfirmation_service::NetworkError;
use thiserror::Error;

pub type Result<T> = std::result::Result<T, P2pSdkError>;

#[derive(Debug, Error)]
pub enum P2pSdkError {
    #[error("network: {0}")]
    Network(#[from] NetworkError),
    #[error("validation: {0}")]
    Validation(String),
    #[error("storage: {0}")]
    Storage(String),
    #[error("timeout after {0:?}")]
    Timeout(Duration),
    #[error("backpressure: channel full")]
    Backpressure,
    #[error("shutdown")]
    Shutdown,
    #[error("other: {0}")]
    Other(String),
}

impl From<&str> for P2pSdkError {
    fn from(value: &str) -> Self {
        Self::Other(value.to_owned())
    }
}

