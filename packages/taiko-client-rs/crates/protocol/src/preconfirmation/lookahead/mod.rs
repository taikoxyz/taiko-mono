//! Lookahead preconfirmation resolver and supporting types.
//!
//! Behavior mirrors `LookaheadStore._determineProposerContext`:
//! - If the current epoch lookahead is empty, use the whitelist operator for the entire epoch.
//! - Otherwise pick the first current-epoch slot whose timestamp >= queried timestamp; if none and
//!   the first slot of the next epoch is still ahead of the queried timestamp, use that first slot;
//!   otherwise fall back to the current-epoch whitelist.
//! - Blacklisted slots always fall back to the cached current-epoch whitelist (driven by live
//!   `Blacklisted`/`Unblacklisted` events).
//! - Whitelist fallback follows live `PreconfWhitelist` events (OperatorAdded/Removed), seeded by
//!   the initial `LookaheadPosted` snapshot; mid-epoch removals therefore change the fallback
//!   committer without additional RPCs.
//! - Lookups are bounded: timestamps earlier than `earliest_allowed_timestamp` (one full epoch
//!   behind "now") are rejected as `TooOld`, and timestamps at or beyond `latest_allowed_timestamp`
//!   (end of the current epoch) are rejected as `TooNew`.

use alloy_primitives::{Address, U256};

mod client;
mod error;
mod resolver;
mod scanner;

use async_trait::async_trait;
pub use bindings::lookahead_store::ILookaheadStore::{
    LookaheadData, LookaheadSlot, ProposerContext,
};
pub use client::LookaheadClient;
pub use error::{LookaheadError, Result};
pub use resolver::{LookaheadBroadcast, LookaheadResolver};

/// Convenience alias for the default provider stack used by lookahead clients/resolvers.
pub type LookaheadResolverWithDefaultProvider = LookaheadResolver;

/// Resolves the expected signer for a preconfirmation commitment at a given L2 block timestamp,
/// matching the documented lookahead resolver behavior above.
#[async_trait]
pub trait PreconfSignerResolver {
    /// Return the address allowed to sign the commitment covering `l2_block_timestamp`.
    async fn signer_for_timestamp(&self, l2_block_timestamp: U256) -> Result<Address>;
}
