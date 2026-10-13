#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Engine API wrappers and JSON-RPC provider helpers for the execution engine and L1, and the
//! beacon client the ABCI proposer fetches forced inclusion blobs with.

pub mod auth;
pub mod beacon;
pub mod blob;
pub mod client;
pub mod error;
#[cfg(test)]
mod test_utils;

pub use error::{Result, RpcClientError};
