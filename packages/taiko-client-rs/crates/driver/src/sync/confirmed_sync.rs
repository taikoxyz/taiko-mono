//! Confirmed event-sync state derived from core state and custom execution tables.

use std::future::Future;

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

/// Build a strict confirmed-sync snapshot using caller-provided data sources.
///
/// For `target_proposal_id == 0`, the target block lookup is skipped and the snapshot records
/// `target_block = None`.
pub async fn build_confirmed_sync_snapshot<E, FT, FH, TargetLookup, HeadLookup>(
    target_proposal_id: u64,
    lookup_target_block: TargetLookup,
    lookup_head_l1_origin_block_id: HeadLookup,
) -> Result<ConfirmedSyncSnapshot, E>
where
    FT: Future<Output = Result<Option<u64>, E>>,
    FH: Future<Output = Result<Option<u64>, E>>,
    TargetLookup: FnOnce(u64) -> FT,
    HeadLookup: FnOnce() -> FH,
{
    let target_block = if target_proposal_id == 0 {
        None
    } else {
        lookup_target_block(target_proposal_id).await?
    };
    let head_l1_origin_block_id = lookup_head_l1_origin_block_id().await?;
    Ok(ConfirmedSyncSnapshot::new(target_proposal_id, target_block, head_l1_origin_block_id))
}

#[cfg(test)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    };

    use super::{ConfirmedSyncSnapshot, build_confirmed_sync_snapshot};

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

    #[tokio::test]
    async fn build_confirmed_sync_snapshot_ignores_target_lookup_for_zero_target() {
        let target_lookup_called = Arc::new(AtomicBool::new(false));
        let lookup_marker = target_lookup_called.clone();

        let snapshot = build_confirmed_sync_snapshot(
            0,
            move |_| {
                let lookup_marker = lookup_marker.clone();
                async move {
                    lookup_marker.store(true, Ordering::Relaxed);
                    Ok::<Option<u64>, ()>(Some(15))
                }
            },
            || async { Ok::<Option<u64>, ()>(Some(9)) },
        )
        .await
        .expect("snapshot should be built");

        assert_eq!(snapshot, ConfirmedSyncSnapshot::new(0, None, Some(9)));
        assert!(!target_lookup_called.load(Ordering::Relaxed));
    }

    #[tokio::test]
    async fn build_confirmed_sync_snapshot_uses_target_lookup_for_nonzero_target() {
        let snapshot = build_confirmed_sync_snapshot(
            7,
            |_| async { Ok::<Option<u64>, ()>(Some(11)) },
            || async { Ok::<Option<u64>, ()>(Some(15)) },
        )
        .await
        .expect("snapshot should be built");

        assert_eq!(snapshot, ConfirmedSyncSnapshot::new(7, Some(11), Some(15)));
    }
}
