#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Engine API wrappers and JSON-RPC provider helpers for the execution engine and L1.

pub mod auth;
pub mod client;
pub mod error;

pub use error::{Result, RpcClientError};
