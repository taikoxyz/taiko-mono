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
use async_trait::async_trait;
use thiserror::Error;

mod client;
mod resolver;
mod scanner;

pub use bindings::lookahead_store::ILookaheadStore::{
    LookaheadData, LookaheadSlot, ProposerContext,
};
pub use client::LookaheadClient;
pub use resolver::{LookaheadBroadcast, LookaheadResolver};

/// Errors emitted by the lookahead client.
#[derive(Debug, Error)]
pub enum LookaheadError {
    /// Failed to fetch or decode Inbox configuration.
    #[error("failed to fetch inbox config: {0}")]
    InboxConfig(alloy_contract::Error),
    /// Failure when querying the LookaheadStore.
    #[error("failed to call lookahead store: {0}")]
    Lookahead(alloy_contract::Error),
    /// Failure when querying the preconfirmation whitelist.
    #[error("failed to call preconf whitelist: {0}")]
    PreconfWhitelist(alloy_contract::Error),
    /// Failure when fetching a block by number from the provider.
    #[error("failed to fetch block {block_number}: {reason}")]
    BlockLookup { block_number: u64, reason: String },
    /// Required log metadata was missing when ingesting events.
    #[error("missing log field '{field}' while {context}")]
    MissingLogField { field: &'static str, context: &'static str },
    /// Decoding of a lookahead event failed.
    #[error("failed to decode lookahead event: {0}")]
    EventDecode(String),
    /// Event scanner initialization failed.
    #[error("failed to initialize event scanner: {0}")]
    EventScanner(String),
    /// The requested timestamp lies before the configured genesis.
    #[error("timestamp {0} is before beacon genesis")]
    BeforeGenesis(u64),
    /// The requested timestamp is older than the supported lookback window.
    #[error("timestamp {0} is older than the allowed lookback window")]
    TooOld(u64),
    /// The requested timestamp lies in a future epoch (beyond the current epoch boundary).
    #[error("timestamp {0} is beyond the current epoch window")]
    TooNew(u64),
    /// Chain reorg detected while locating a block.
    #[error("chain reorg detected while locating block for epoch")]
    ReorgDetected,
    /// System clock produced an invalid (pre-UNIX) timestamp.
    #[error("system time error: {0}")]
    SystemTime(String),
    /// Chain ID not recognised for genesis timestamp resolution.
    #[error("unsupported chain id {0} for preconf genesis lookup")]
    UnknownChain(u64),
    /// Cached lookahead data for the epoch was not available.
    #[error("no lookahead data cached for epoch starting at {0}")]
    MissingLookahead(u64),
    /// Cached lookahead slots were internally inconsistent (index out of bounds).
    #[error(
        "lookahead cache corrupt for epoch starting at {epoch_start}: slot index {index} out of bounds (len {len})"
    )]
    CorruptLookaheadCache { epoch_start: u64, index: usize, len: usize },
}

/// Result alias for lookahead operations.
pub type Result<T> = std::result::Result<T, LookaheadError>;

/// Convenience alias for the default provider stack used by lookahead clients/resolvers.
pub type LookaheadResolverWithDefaultProvider = LookaheadResolver;

/// Resolved signer plus canonical submission window end for a preconfirmation slot.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PreconfSlotInfo {
    /// Address allowed to sign the commitment for the slot.
    pub signer: Address,
    /// Canonical end of the submission window for the slot.
    pub submission_window_end: U256,
}

/// Resolves the expected signer for a preconfirmation commitment at a given L2 block timestamp,
/// matching the documented lookahead resolver behavior above.
#[async_trait]
pub trait PreconfSignerResolver {
    /// Return the address allowed to sign the commitment covering `l2_block_timestamp`.
    async fn signer_for_timestamp(&self, l2_block_timestamp: U256) -> Result<Address>;

    /// Return the signer plus canonical submission window end for `l2_block_timestamp`.
    async fn slot_info_for_timestamp(&self, l2_block_timestamp: U256) -> Result<PreconfSlotInfo>;
}
