//! Driver integration traits and data types.
//!
//! This module provides the [`EmbeddedDriverClient`] for direct in-process
//! communication with the driver via channels.

/// Embedded driver client for direct in-process communication.
pub mod embedded;
/// Execution payload builder.
pub mod payload;
/// Driver-facing traits and input structures.
pub mod traits;

pub use embedded::EmbeddedDriverClient;
pub use traits::{DriverClient, PreconfirmationInput};
