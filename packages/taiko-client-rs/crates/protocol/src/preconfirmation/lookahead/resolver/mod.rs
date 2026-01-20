//! Lookahead resolver submodules split for readability.
//!
//! Layout:
//! - `core.rs`: main resolver logic, ingest, adapters, and tests.
//! - `epoch.rs`: epoch/time utilities.
//! - `timeline.rs`: fallback/blacklist timelines.
//! - `types.rs`: data types and helpers.

mod core;
mod epoch;
pub mod scanner_handle;
mod timeline;
mod types;

pub use core::LookaheadResolver;
pub(crate) use epoch::{SECONDS_IN_EPOCH, SECONDS_IN_SLOT};
pub use types::LookaheadBroadcast;

use super::Result;
use alloy_primitives::Address;
use alloy_rpc_types::eth::Block as RpcBlock;
use async_trait::async_trait;

/// Abstraction over block lookups used by the resolver (latest and by-number).
#[async_trait]
pub trait BlockReader: Send + Sync {
    /// Return the latest block or None if unavailable.
    async fn latest_block(&self) -> Result<Option<RpcBlock>>;

    /// Return the block for a specific number or None if missing.
    async fn block_by_number(&self, number: u64) -> Result<Option<RpcBlock>>;
}

/// Abstraction over whitelist contract queries.
#[async_trait]
pub trait WhitelistClient: Send + Sync {
    /// Address of the whitelist contract.
    fn address(&self) -> Address;

    /// Operator allowed in the current epoch at the given block number.
    async fn current_operator(&self, block_number: u64) -> Result<Address>;

    /// Operator for the next epoch at the given block number.
    async fn next_operator(&self, block_number: u64) -> Result<Address>;
}

/// Abstraction over lookahead store contract queries.
#[async_trait]
pub trait LookaheadStoreClient: Send + Sync {
    /// Address of the lookahead store contract.
    fn address(&self) -> Address;
}
