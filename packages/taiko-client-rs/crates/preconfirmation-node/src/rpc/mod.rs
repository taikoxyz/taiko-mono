//! User-facing JSON-RPC server for preconfirmation operations.

/// RPC API trait and implementation.
pub mod api;
/// JSON-RPC server wrapper.
pub mod server;
/// Request/response types used by the RPC API.
pub mod types;

pub use api::{PreconfRpcApiImpl, PreconfRpcApiServer};
pub use server::{PreconfRpcServer, RpcServerConfig};
pub use types::*;
