//! Staged forced inclusion decisions over authenticated scalar facts.

/// Inbox maximum transaction size, in bytes.
pub const MAX_FORCED_TX_BYTES: u64 = 8192;

/// The scalar classification; NeedsSkip alone never authorizes consumption.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ForcedDecision {
    /// No entry consumed.
    Ordinary,
    /// The matching canonical first transaction consumes its index.
    Included(u64),
    /// Authenticated due invalid input consumes its index.
    SkippedInvalid(u64),
    /// Due canonical input requires a completed singleton check.
    NeedsSkip(u64),
}

/// Authenticated facts after witness presence, index and proof verification.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ForcedFacts {
    /// Parent queue cursor, equal to the authenticated entry index.
    pub cursor: u64,
    /// Entry submission timestamp, in seconds.
    pub timestamp: u64,
    /// Genesis delay, in seconds.
    pub delay: u64,
    /// Authenticated anchor timestamp, in seconds.
    pub anchor_timestamp: u64,
    /// Actual supplied preimage length, including zero for omission.
    pub preimage_len: u64,
    /// Keccak of supplied bytes equals the authenticated entry hash.
    pub preimage_hash_matches: bool,
    /// Canonical supplied bytes; required only when due, hash-matching and not included.
    pub preimage_canonical: bool,
    /// First block transaction is canonical, within the byte limit and hash-matching.
    pub first_matches: bool,
}

/// Failures of the scalar forced rule; adapters retain richer diagnostic values.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ForcedError {
    /// A pending entry has no witness.
    MissingWitness(u64),
    /// An exhausted queue carries a witness.
    UnexpectedWitness,
    /// Witness or consumption names a different index than the cursor.
    WrongIndex {
        /// Expected parent cursor.
        expected: u64,
        /// Supplied index.
        got: u64,
    },
    /// Supplied preimage exceeds the byte cap.
    TooLarge(u64),
    /// Supplied preimage hash differs from the proven entry hash.
    HashMismatch,
    /// A canonical skip still needs a completed singleton result.
    NeedsSingleton,
    /// A verified singleton retained a transaction.
    Retained,
    /// Incrementing the cursor exceeds u64.
    CursorOverflow,
}

/// A singleton outcome supplied only after exact-parent build and header verification.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SingletonOutcome {
    /// No singleton result has completed; never interpreted as empty.
    NotBuilt,
    /// Completed authenticated singleton contains no transactions.
    Empty,
    /// Completed authenticated singleton retained at least one transaction.
    Retained,
}

/// Validates queue/witness presence and index before expensive entry proof verification.
pub fn pending_entry(
    cursor: u64,
    tail: u64,
    witness_index: Option<u64>,
) -> Result<bool, ForcedError> {
    if cursor >= tail {
        return match witness_index {
            None => Ok(false),
            Some(_) => Err(ForcedError::UnexpectedWitness),
        };
    }
    match witness_index {
        None => Err(ForcedError::MissingWitness(cursor)),
        Some(got) if got != cursor => Err(ForcedError::WrongIndex { expected: cursor, got }),
        Some(_) => Ok(true),
    }
}

/// Checks byte length before the nonempty compatibility hash check, before first-tx decoding.
pub fn check_preimage(size: u64, hash_matches: bool) -> Result<(), ForcedError> {
    if size > MAX_FORCED_TX_BYTES {
        return Err(ForcedError::TooLarge(size));
    }
    if size != 0 && !hash_matches {
        return Err(ForcedError::HashMismatch);
    }
    Ok(())
}

/// Inclusive due boundary using wide arithmetic; overflow cannot make an entry prematurely due.
pub fn is_due(timestamp: u64, delay: u64, anchor_timestamp: u64) -> bool {
    anchor_timestamp as u128 >= timestamp as u128 + delay as u128
}

/// Classifies authenticated input, preserving length/hash/inclusion/due/preimage ordering.
pub fn classify_forced(facts: ForcedFacts) -> Result<ForcedDecision, ForcedError> {
    check_preimage(facts.preimage_len, facts.preimage_hash_matches)?;
    if facts.first_matches {
        return Ok(ForcedDecision::Included(facts.cursor));
    }
    if !is_due(facts.timestamp, facts.delay, facts.anchor_timestamp) {
        return Ok(ForcedDecision::Ordinary);
    }
    if !facts.preimage_hash_matches {
        return Err(ForcedError::HashMismatch);
    }
    if facts.preimage_canonical {
        Ok(ForcedDecision::NeedsSkip(facts.cursor))
    } else {
        Ok(ForcedDecision::SkippedInvalid(facts.cursor))
    }
}

/// Resolves consumption only from a completed decision or verified empty singleton outcome.
pub fn resolve_forced(
    decision: ForcedDecision,
    outcome: SingletonOutcome,
) -> Result<Option<u64>, ForcedError> {
    match decision {
        ForcedDecision::Ordinary => Ok(None),
        ForcedDecision::Included(index) | ForcedDecision::SkippedInvalid(index) => Ok(Some(index)),
        ForcedDecision::NeedsSkip(index) => match outcome {
            SingletonOutcome::NotBuilt => Err(ForcedError::NeedsSingleton),
            SingletonOutcome::Empty => Ok(Some(index)),
            SingletonOutcome::Retained => Err(ForcedError::Retained),
        },
    }
}

/// Advances exactly the consumed parent cursor; no consumption preserves the cursor.
pub fn advance_cursor(cursor: u64, consumed: Option<u64>) -> Result<u64, ForcedError> {
    match consumed {
        None => Ok(cursor),
        Some(got) if got != cursor => Err(ForcedError::WrongIndex { expected: cursor, got }),
        Some(_) => match cursor.checked_add(1) {
            Some(next) => Ok(next),
            None => Err(ForcedError::CursorOverflow),
        },
    }
}
