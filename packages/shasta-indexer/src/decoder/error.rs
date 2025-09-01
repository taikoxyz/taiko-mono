use std::fmt;

/// Custom error type for decoding operations
#[derive(Debug, Clone)]
pub enum DecodeError {
    /// Not enough data available to decode the expected type
    InsufficientData {
        expected: usize,
        available: usize,
        field: String,
    },
    /// Invalid data format or value
    InvalidData { field: String, details: String },
    /// Generic decoding error with message
    DecodingFailed(String),
}

impl fmt::Display for DecodeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DecodeError::InsufficientData {
                expected,
                available,
                field,
            } => {
                write!(
                    f,
                    "Insufficient data for {}: expected {} bytes, got {} bytes",
                    field, expected, available
                )
            }
            DecodeError::InvalidData { field, details } => {
                write!(f, "Invalid data for {}: {}", field, details)
            }
            DecodeError::DecodingFailed(msg) => {
                write!(f, "Decoding failed: {}", msg)
            }
        }
    }
}

impl std::error::Error for DecodeError {}

// Conversion from alloy::sol_types::Error for convenience
impl From<alloy::sol_types::Error> for DecodeError {
    fn from(err: alloy::sol_types::Error) -> Self {
        DecodeError::DecodingFailed(format!("Alloy decoding error: {}", err))
    }
}
