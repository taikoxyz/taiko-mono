use alloy_primitives::{Address, U256};
use alloy_provider::{RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers};

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
pub type LookaheadResolverWithDefaultProvider =
    LookaheadResolver<FillProvider<JoinedRecommendedFillers, RootProvider>>;

// Lookahead preconfirmation resolver.
//
// How `committer_for_timestamp` resolves a committer (parity with
// `LookaheadStore._determineProposerContext`):
// - If the current epoch lookahead is empty, use the whitelist operator for the entire epoch.
// - Otherwise pick the first current-epoch slot whose timestamp >= queried timestamp; if none and
//   the first slot of the next epoch is still ahead of the queried timestamp, use that first slot;
//   otherwise fall back to the current-epoch whitelist.
// - Blacklisted slots always fall back to the cached current-epoch whitelist (driven by live
//   Blacklisted/Unblacklisted events).
// - Whitelist fallback now follows live PreconfWhitelist events (OperatorAdded/Removed), seeded by
//   the initial LookaheadPosted snapshot; mid-epoch removals therefore change the fallback
//   committer without additional RPCs.
// - Lookups are bounded: timestamps earlier than `earliest_allowed_timestamp` (one full epoch
//   behind "now") are rejected as `TooOld`, and timestamps at or beyond `latest_allowed_timestamp`
//   (end of the current epoch) are rejected as `TooNew`.
//
// Integrators can call `committer_for_timestamp` to obtain the expected committer address for a
// given L1 timestamp, matching LookaheadStore/PreconfWhitelist semantics.
//
/// Resolves the expected signer for a preconfirmation commitment at a given L2 block timestamp.
///
/// P2P validation uses this to check that a received commitment was signed by the committer
/// scheduled for the L2 block containing `l2_block_timestamp`. Lookups are bounded: timestamps
/// earlier than the `earliest_allowed_timestamp` (one full epoch behind "now") are rejected as
/// `TooOld`, and timestamps at or beyond the `latest_allowed_timestamp` (end of the current epoch)
/// are rejected as `TooNew`.
#[async_trait]
pub trait PreconfSignerResolver {
    /// Return the address allowed to sign the commitment covering `l2_block_timestamp`.
    async fn signer_for_timestamp(&self, l2_block_timestamp: U256) -> Result<Address>;
}
