//! Shared types for the driver P2P sidecar.

use alloy::primitives::B256;

/// Canonical block outcome emitted by the event syncer.
#[derive(Clone, Debug)]
pub struct CanonicalOutcome {
    /// Canonical L2 block number.
    pub block_number: u64,
    /// Canonical L2 block hash.
    pub block_hash: B256,
}

/// Metadata tracked for a pending preconfirmation block.
#[derive(Clone, Debug)]
pub struct PendingPreconf {
    /// Hash of the preconfirmation execution payload.
    pub block_hash: B256,
    /// Submission window end timestamp carried by the commitment.
    pub submission_window_end: u64,
}

/// Result of comparing a canonical outcome with pending preconfirmation state.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ConfirmationDecision {
    /// Canonical outcome confirms a pending preconfirmation.
    Confirmed {
        /// Confirmed block number.
        block_number: u64,
        /// Submission window end timestamp for head update.
        submission_window_end: u64,
    },
    /// Canonical outcome disagrees with a pending preconfirmation.
    Reorg {
        /// Block number that diverged.
        block_number: u64,
        /// Pending preconfirmation hash.
        expected_hash: B256,
        /// Canonical hash that caused divergence.
        actual_hash: B256,
    },
    /// No pending entry matched the canonical outcome.
    Noop,
}
