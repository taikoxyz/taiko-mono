//! Driver integration traits and data types.

/// Embedded driver client implementation.
pub mod embedded;
/// Execution payload builder.
pub mod payload;
/// Driver-facing traits and input structures.
pub mod traits;

pub use embedded::EmbeddedDriverClient;
pub use traits::{DriverClient, PreconfirmationInput};
