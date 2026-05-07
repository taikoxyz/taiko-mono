//! Pure helpers for deciding whether a local sequencer can stop safely.
//!
//! The tracker keeps a tiny epoch-to-operator ring and derives the slot ranges
//! where the local operator may be responsible for sequencing. Callers can use
//! the resulting snapshot as a shutdown-safety probe without coupling the probe
//! to RPC, storage, or task orchestration.

use std::collections::VecDeque;

use alloy_primitives::Address;

/// Default number of slots reserved for operator handover at the end of an epoch.
pub(crate) const DEFAULT_HANDOVER_SKIP_SLOTS: u64 = 8;

/// Maximum number of epoch operator records retained by the tracker.
const RING_CAPACITY: usize = 3;

/// Half-open slot interval used by sequencing-window checks.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct SlotRange {
    /// First global slot included in this range.
    pub(crate) start: u64,
    /// First global slot excluded from this range.
    pub(crate) end: u64,
}

impl SlotRange {
    /// Return whether `slot` falls inside this half-open range.
    pub(crate) fn contains(&self, slot: u64) -> bool {
        self.start <= slot && slot < self.end
    }
}

/// Operators that own the current and handover portions of one epoch.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct EpochOperators {
    /// Epoch number represented by this ring entry.
    epoch: u64,
    /// Operator responsible for the current portion of the epoch.
    current_operator: Address,
    /// Operator responsible for the handover portion of the epoch.
    next_operator: Address,
}

/// Derived sequencing-window view for one local operator.
#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct SequencingWindowSnapshot {
    /// Operator responsible for the current portion of `last_epoch_updated`.
    pub(crate) current_operator: Address,
    /// Operator responsible for the handover portion of `last_epoch_updated`.
    pub(crate) next_operator: Address,
    /// Global-slot ranges where the local operator is the current operator.
    pub(crate) current_ranges: Vec<SlotRange>,
    /// Global-slot ranges where the local operator is the next operator.
    pub(crate) next_ranges: Vec<SlotRange>,
    /// Epoch used to produce this snapshot.
    pub(crate) last_epoch_updated: u64,
}

/// Tracks the local operator's sequencing windows across a three-epoch ring.
#[derive(Debug)]
pub(crate) struct SequencingWindowTracker {
    /// Number of global slots in one L1 epoch.
    slots_per_epoch: u64,
    /// Number of end-of-epoch slots reserved for handover to the next operator.
    handover_skip_slots: u64,
    /// Three-entry ring of epoch operator assignments used for range derivation.
    ring: VecDeque<EpochOperators>,
    /// Last derived shutdown-safety view.
    snapshot: Option<SequencingWindowSnapshot>,
}

impl SequencingWindowTracker {
    /// Create an empty tracker for the configured epoch shape.
    pub(crate) fn new(slots_per_epoch: u64, handover_skip_slots: u64) -> Self {
        Self {
            slots_per_epoch,
            handover_skip_slots,
            ring: VecDeque::with_capacity(RING_CAPACITY),
            snapshot: None,
        }
    }

    /// Return whether the tracker should refresh for `current_epoch`.
    pub(crate) fn needs_refresh(&self, current_epoch: u64) -> bool {
        self.snapshot.as_ref().is_none_or(|snapshot| snapshot.last_epoch_updated != current_epoch)
    }

    /// Refresh the operator ring and derive ranges for `local_operator`.
    pub(crate) fn refresh(
        &mut self,
        current_epoch: u64,
        current_operator: Address,
        next_operator: Address,
        local_operator: Address,
    ) -> SequencingWindowSnapshot {
        self.upsert_epoch(current_epoch, current_operator, next_operator);
        self.upsert_epoch(current_epoch.saturating_add(1), next_operator, Address::ZERO);

        let mut current_ranges = Vec::new();
        let mut next_ranges = Vec::new();
        for entry in &self.ring {
            let (current_range, next_range) = self.epoch_ranges(entry.epoch);
            if entry.current_operator == local_operator && current_range.start < current_range.end {
                current_ranges.push(current_range);
            }
            if entry.next_operator == local_operator && next_range.start < next_range.end {
                next_ranges.push(next_range);
            }
        }

        let snapshot = SequencingWindowSnapshot {
            current_operator,
            next_operator,
            current_ranges: merge_ranges(current_ranges),
            next_ranges: merge_ranges(next_ranges),
            last_epoch_updated: current_epoch,
        };
        self.snapshot = Some(snapshot.clone());
        snapshot
    }

    /// Return whether `global_slot` is outside every tracked local-operator range.
    pub(crate) fn can_shutdown(&self, global_slot: u64) -> bool {
        self.snapshot.as_ref().is_none_or(|snapshot| {
            snapshot
                .current_ranges
                .iter()
                .chain(&snapshot.next_ranges)
                .all(|range| !range.contains(global_slot))
        })
    }

    /// Insert or replace the operator assignment for `epoch`.
    fn upsert_epoch(&mut self, epoch: u64, current_operator: Address, next_operator: Address) {
        if let Some(entry) = self.ring.iter_mut().find(|entry| entry.epoch == epoch) {
            entry.current_operator = current_operator;
            entry.next_operator = next_operator;
        } else {
            self.ring.push_back(EpochOperators { epoch, current_operator, next_operator });
        }

        self.ring.make_contiguous().sort_by_key(|entry| entry.epoch);
        while self.ring.len() > RING_CAPACITY {
            self.ring.pop_front();
        }
    }

    /// Return the current and next-operator ranges for `epoch`.
    fn epoch_ranges(&self, epoch: u64) -> (SlotRange, SlotRange) {
        let epoch_start = epoch.saturating_mul(self.slots_per_epoch);
        let threshold = self.slots_per_epoch.saturating_sub(self.handover_skip_slots);
        let handover_start = epoch_start.saturating_add(threshold);
        let epoch_end = epoch.saturating_add(1).saturating_mul(self.slots_per_epoch);

        (
            SlotRange { start: epoch_start, end: handover_start },
            SlotRange { start: handover_start, end: epoch_end },
        )
    }
}

/// Merge sorted, overlapping, or adjacent slot ranges into compact intervals.
fn merge_ranges(mut ranges: Vec<SlotRange>) -> Vec<SlotRange> {
    ranges.retain(|range| range.start < range.end);
    ranges.sort_by_key(|range| (range.start, range.end));

    let mut merged: Vec<SlotRange> = Vec::new();
    for range in ranges {
        if let Some(last) = merged.last_mut() &&
            range.start <= last.end
        {
            last.end = last.end.max(range.end);
            continue;
        }
        merged.push(range);
    }

    merged
}

#[cfg(test)]
mod tests {
    use alloy_primitives::Address;

    use super::{DEFAULT_HANDOVER_SKIP_SLOTS, SequencingWindowTracker, SlotRange, merge_ranges};

    fn address(byte: u8) -> Address {
        Address::from([byte; 20])
    }

    #[test]
    fn merge_ranges_coalesces_overlapping_and_adjacent_ranges() {
        let merged = merge_ranges(vec![
            SlotRange { start: 10, end: 20 },
            SlotRange { start: 30, end: 35 },
            SlotRange { start: 7, end: 9 },
            SlotRange { start: 20, end: 25 },
            SlotRange { start: 3, end: 8 },
        ]);

        assert_eq!(
            merged,
            vec![
                SlotRange { start: 3, end: 9 },
                SlotRange { start: 10, end: 25 },
                SlotRange { start: 30, end: 35 },
            ]
        );
    }

    #[test]
    fn refresh_derives_current_next_and_next_epoch_current_ranges() {
        let local_operator = address(0x22);
        let current_operator = address(0x11);
        let mut tracker = SequencingWindowTracker::new(32, DEFAULT_HANDOVER_SKIP_SLOTS);

        let snapshot = tracker.refresh(7, current_operator, local_operator, local_operator);

        assert_eq!(snapshot.current_operator, current_operator);
        assert_eq!(snapshot.next_operator, local_operator);
        assert_eq!(snapshot.last_epoch_updated, 7);
        assert_eq!(snapshot.next_ranges, vec![SlotRange { start: 248, end: 256 }]);
        assert_eq!(snapshot.current_ranges, vec![SlotRange { start: 256, end: 280 }]);
    }

    #[test]
    fn can_shutdown_is_false_inside_current_or_next_ranges() {
        let local_operator = address(0x33);
        let mut tracker = SequencingWindowTracker::new(32, DEFAULT_HANDOVER_SKIP_SLOTS);

        tracker.refresh(3, local_operator, local_operator, local_operator);

        assert!(tracker.can_shutdown(95));
        assert!(!tracker.can_shutdown(96));
        assert!(!tracker.can_shutdown(119));
        assert!(!tracker.can_shutdown(120));
        assert!(!tracker.can_shutdown(127));
        assert!(!tracker.can_shutdown(128));
        assert!(!tracker.can_shutdown(151));
        assert!(tracker.can_shutdown(152));
    }

    #[test]
    fn can_shutdown_is_true_before_initial_refresh() {
        let tracker = SequencingWindowTracker::new(10, DEFAULT_HANDOVER_SKIP_SLOTS);

        assert!(tracker.can_shutdown(0));
        assert!(tracker.can_shutdown(100));
    }

    #[test]
    fn needs_refresh_tracks_initialization_and_epoch_changes() {
        let local_operator = address(0x44);
        let mut tracker = SequencingWindowTracker::new(10, DEFAULT_HANDOVER_SKIP_SLOTS);

        assert!(tracker.needs_refresh(5));

        tracker.refresh(5, local_operator, Address::ZERO, local_operator);

        assert!(!tracker.needs_refresh(5));
        assert!(tracker.needs_refresh(6));
    }
}
