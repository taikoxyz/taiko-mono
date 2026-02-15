//! Confirmed event-sync state derived from core state and custom execution tables.

/// Snapshot of the strict confirmed-sync gate state.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ConfirmedSyncSnapshot {
    /// Target proposal id being tracked (`nextProposalId.saturating_sub(1)`).
    pub target_proposal_id: u64,
    /// Last L2 block mapped from `target_proposal_id` via `lastBlockIDByBatchID`.
    pub target_block: Option<u64>,
    /// Confirmed L2 head from `head_l1_origin`.
    pub head_l1_origin_block_id: Option<u64>,
}

impl ConfirmedSyncSnapshot {
    /// Build a confirmed-sync snapshot from observed target/head values.
    pub const fn new(
        target_proposal_id: u64,
        target_block: Option<u64>,
        head_l1_origin_block_id: Option<u64>,
    ) -> Self {
        Self { target_proposal_id, target_block, head_l1_origin_block_id }
    }

    /// Returns true when strict confirmed-sync readiness is satisfied.
    ///
    /// Rules:
    /// - `target_proposal_id == 0` is immediately ready.
    /// - otherwise both `target_block` and `head_l1_origin_block_id` must exist and
    ///   `head_l1_origin_block_id >= target_block`.
    pub fn is_ready(&self) -> bool {
        if self.target_proposal_id == 0 {
            return true;
        }

        match (self.target_block, self.head_l1_origin_block_id) {
            (Some(target_block), Some(head_block)) => head_block >= target_block,
            _ => false,
        }
    }

    /// Returns the confirmed event-sync tip (head L1 origin block id), if known.
    pub const fn event_sync_tip(&self) -> Option<u64> {
        self.head_l1_origin_block_id
    }
}

#[cfg(test)]
mod tests {
    use super::ConfirmedSyncSnapshot;

    #[test]
    fn confirmed_sync_ready_when_target_is_zero() {
        assert!(ConfirmedSyncSnapshot::new(0, None, None).is_ready());
    }

    #[test]
    fn confirmed_sync_ready_requires_head_l1_origin_for_nonzero_target() {
        assert!(!ConfirmedSyncSnapshot::new(7, Some(11), None).is_ready());
    }

    #[test]
    fn confirmed_sync_ready_requires_target_batch_mapping_for_nonzero_target() {
        assert!(!ConfirmedSyncSnapshot::new(7, None, Some(11)).is_ready());
    }

    #[test]
    fn confirmed_sync_ready_is_false_when_head_is_behind_target_block() {
        assert!(!ConfirmedSyncSnapshot::new(7, Some(12), Some(11)).is_ready());
    }

    #[test]
    fn confirmed_sync_ready_is_true_when_head_reaches_target_block() {
        assert!(ConfirmedSyncSnapshot::new(7, Some(12), Some(12)).is_ready());
        assert!(ConfirmedSyncSnapshot::new(7, Some(12), Some(15)).is_ready());
    }
}
