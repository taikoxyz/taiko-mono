use bindings::lookahead_store::ILookaheadStore;

/// Type alias for on-chain lookahead payloads.
pub type LookaheadData = ILookaheadStore::LookaheadData;
/// Type alias for an individual lookahead slot.
pub type LookaheadSlot = ILookaheadStore::LookaheadSlot;
/// Type alias for the proposer context returned by `LookaheadStore`.
pub type ProposerContext = ILookaheadStore::ProposerContext;
