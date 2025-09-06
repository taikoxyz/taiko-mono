use std::fmt;

/// Custom error type for handler operations
#[derive(Debug)]
pub enum HandlerError {
    /// Database operation failed
    DatabaseError(String),
    /// Failed to decode event data
    DecodeError(crate::decoder::error::DecodeError),
    /// Transaction failed
    TransactionError(String),
    /// Event processing failed
    ProcessingError(String),
}

impl fmt::Display for HandlerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            HandlerError::DatabaseError(msg) => write!(f, "Database error: {}", msg),
            HandlerError::DecodeError(err) => write!(f, "Decode error: {}", err),
            HandlerError::TransactionError(msg) => write!(f, "Transaction error: {}", msg),
            HandlerError::ProcessingError(msg) => write!(f, "Processing error: {}", msg),
        }
    }
}

impl std::error::Error for HandlerError {}

impl From<crate::decoder::error::DecodeError> for HandlerError {
    fn from(err: crate::decoder::error::DecodeError) -> Self {
        HandlerError::DecodeError(err)
    }
}

impl From<Box<dyn std::error::Error + Send + Sync>> for HandlerError {
    fn from(err: Box<dyn std::error::Error + Send + Sync>) -> Self {
        HandlerError::DatabaseError(err.to_string())
    }
}

/// Result type for handler operations
pub type HandlerResult<T> = Result<T, HandlerError>;
