//! Shared prover state guarded for concurrent access (Go
//! `prover/shared_state/state.go`).

use std::sync::atomic::{AtomicU64, Ordering};

/// Atomic cursor shared across the prover's event-handling tasks.
#[derive(Debug, Default)]
pub struct SharedState {
    /// Highest proposal id whose `Proposed` event has been handled.
    last_handled_proposal_id: AtomicU64,
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
        self.last_handled_proposal_id
            .fetch_update(Ordering::AcqRel, Ordering::Acquire, |current| {
                (proposal_id > current).then_some(proposal_id)
            })
            .is_ok()
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
}
