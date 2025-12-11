use thiserror::Error;

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
