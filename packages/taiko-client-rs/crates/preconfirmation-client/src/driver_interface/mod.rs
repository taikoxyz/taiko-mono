//! Driver integration traits and data types.

/// JSON-RPC driver client implementation.
pub mod jsonrpc;
/// Execution payload builder.
pub mod payload;
/// Driver-facing traits and input structures.
pub mod traits;

pub use jsonrpc::{JsonRpcDriverClient, JsonRpcDriverClientConfig};
pub use traits::{DriverClient, PreconfirmationInput};
