//! Authenticated calldata forced inclusion classification. No I/O.

/// Pure proof, byte authentication and per-block classification.
pub mod calldata;

use alloy_primitives::B256;
pub use calldata::{
    ForcedContext, ForcedDecision, ForcedEntry, ForcedWitness, MAX_FORCED_TX_BYTES, check,
    decode_canonical, entry_slots, verify_entry,
};

/// Why a block breaks the forced inclusion rule.
#[derive(Debug, thiserror::Error, Clone, PartialEq, Eq)]
pub enum ForcedError {
    /// The queue holds entry `index` at the cursor, but the block carries no forced witness.
    #[error("the block lacks the forced inclusion witness of pending entry {index}")]
    MissingWitness {
        /// The cursor: the pending entry the block must name.
        index: u64,
    },
    /// The cursor has reached the anchor's queue tail, yet the block carries a forced witness.
    #[error("the block carries a forced inclusion witness, but no entry is pending")]
    UnexpectedWitness,
    /// The forced witness names another entry than the cursor.
    #[error("the forced inclusion witness names entry {got}, expected the cursor {expected}")]
    WrongIndex {
        /// The cursor.
        expected: u64,
        /// The witness's index.
        got: u64,
    },
    /// The forced transaction exceeds the Inbox's maximum byte length.
    #[error("forced transaction has {size} bytes, exceeding the {max}-byte limit")]
    TxTooLarge {
        /// Actual transaction byte length.
        size: usize,
        /// Maximum permitted transaction byte length.
        max: usize,
    },
    /// The exact transaction bytes do not match the authenticated entry hash.
    #[error("transaction hash {got} differs from the entry's {expected}")]
    TxHashMismatch {
        /// Hash stored in the proven queue entry.
        expected: B256,
        /// Keccak-256 of the carried transaction bytes.
        got: B256,
    },
    /// The entry proof does not verify against the anchor (another account, a wrong slot set or
    /// an invalid proof).
    #[error("forced inclusion entry proof rejected: {0}")]
    Entry(String),
}
