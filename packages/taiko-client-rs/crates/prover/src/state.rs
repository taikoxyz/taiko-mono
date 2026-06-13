//! Shared prover state guarded for concurrent access (Go
//! `prover/shared_state/state.go`).

use std::sync::atomic::{AtomicU64, Ordering};

/// Atomic cursors shared across the prover's event-handling tasks.
#[derive(Debug, Default)]
pub struct SharedState {
    /// Highest proposal id whose `Proposed` event has been handled.
    last_handled_proposal_id: AtomicU64,
    /// L1 block number of the scan cursor (Go tracks the full header; the
    /// number is all the Rust orchestrator needs).
    l1_current_block: AtomicU64,
}

impl SharedState {
    /// Create empty shared state.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Highest handled proposal id.
    #[must_use]
    pub fn last_handled_proposal_id(&self) -> u64 {
        self.last_handled_proposal_id.load(Ordering::Acquire)
    }

    /// Record `proposal_id` as handled if it advances the cursor; returns
    /// `true` when it was newly handled (Go dedups with
    /// `proposalID <= lastHandled`, `proposal.go:56`).
    pub fn mark_handled(&self, proposal_id: u64) -> bool {
        let mut current = self.last_handled_proposal_id.load(Ordering::Acquire);
        loop {
            if proposal_id <= current {
                return false;
            }
            match self.last_handled_proposal_id.compare_exchange_weak(
                current,
                proposal_id,
                Ordering::AcqRel,
                Ordering::Acquire,
            ) {
                Ok(_) => return true,
                Err(observed) => current = observed,
            }
        }
    }

    /// Current L1 scan-cursor block number.
    #[must_use]
    pub fn l1_current_block(&self) -> u64 {
        self.l1_current_block.load(Ordering::Acquire)
    }

    /// Set the L1 scan-cursor block number.
    pub fn set_l1_current_block(&self, block_number: u64) {
        self.l1_current_block.store(block_number, Ordering::Release);
    }
}

#[cfg(test)]
mod tests {
    use super::SharedState;

    #[test]
    fn mark_handled_advances_and_dedups() {
        let state = SharedState::new();
        assert!(state.mark_handled(5));
        assert_eq!(state.last_handled_proposal_id(), 5);

        // Equal or lower ids are already handled.
        assert!(!state.mark_handled(5));
        assert!(!state.mark_handled(3));
        assert_eq!(state.last_handled_proposal_id(), 5);

        assert!(state.mark_handled(6));
        assert_eq!(state.last_handled_proposal_id(), 6);
    }

    #[test]
    fn l1_current_block_round_trips() {
        let state = SharedState::new();
        assert_eq!(state.l1_current_block(), 0);
        state.set_l1_current_block(42);
        assert_eq!(state.l1_current_block(), 42);
    }
}
