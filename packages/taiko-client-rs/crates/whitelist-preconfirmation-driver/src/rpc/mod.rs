//! Whitelist preconfirmation JSON-RPC API.

mod api;
mod server;
pub(crate) mod types;

pub(crate) use api::WhitelistRpcApi;
pub(crate) use server::{WhitelistRpcServer, WhitelistRpcServerConfig};
