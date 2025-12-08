use alloy_primitives::{Address, U256};
use alloy_provider::{RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers};

mod client;
mod error;
mod resolver;
mod scanner;

pub use bindings::lookahead_store::ILookaheadStore::{
    LookaheadData, LookaheadSlot, ProposerContext,
};
pub use client::LookaheadClient;
pub use error::{LookaheadError, Result};
pub use resolver::LookaheadResolver;

/// Convenience alias for the default provider stack used by lookahead clients/resolvers.
pub type LookaheadResolverDefaultProvider =
    LookaheadResolver<FillProvider<JoinedRecommendedFillers, RootProvider>>;

// Lookahead preconfirmation resolver.
//
// How `committer_for_timestamp` resolves a committer:
// - Finds the first lookahead slot whose timestamp >= queried timestamp; if none, tries the first
//   slot of the next epoch; otherwise falls back to the whitelist.
// - If the chosen slot's registration root is currently blacklisted on-chain, it falls back to the
//   whitelist operator instead.
// - Whitelist fallback operators themselves are **not** blacklist-checked.
// - Blacklist is evaluated at call time (current chain state) on slot committers; whitelist
//   fallback operators are not blacklist-checked (mirrors contracts).
//
// Integrators can call `committer_for_timestamp` to obtain the expected committer address for a
// given L1 timestamp, matching LookaheadStore/PreconfWhitelist semantics.
//
/// Resolves the expected signer for a preconfirmation commitment at a given L2 block timestamp.
///
/// P2P validation uses this to check that a received commitment was signed by the committer
/// scheduled for the L2 block containing `l2_block_timestamp`.
pub trait PreconfSignerResolver {
    /// Return the address allowed to sign the commitment covering `l2_block_timestamp`.
    fn signer_for_timestamp(&self, l2_block_timestamp: U256) -> Result<Address>;
}
