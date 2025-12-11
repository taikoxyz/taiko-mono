use std::sync::Arc;

use alloy_primitives::Address;
use arc_swap::ArcSwap;
use tracing::warn;

/// Blacklist status change for a single operator at a specific timestamp.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BlacklistFlag {
    /// Operator became blacklisted at this timestamp.
    Listed,
    /// Operator was cleared from the blacklist at this timestamp.
    Cleared,
}

/// Timestamped blacklist event used to rebuild historical state.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BlacklistEvent {
    /// Seconds since UNIX epoch when the event occurred (log timestamp).
    pub at: u64,
    /// Blacklist state transition applied at `at`.
    pub flag: BlacklistFlag,
}

/// Per-operator history of blacklist transitions, kept in chronological order and pruned to the
/// allowed lookback window while preserving the last pre-cutoff state for accurate queries.
#[derive(Debug, Default, Clone)]
pub struct BlacklistTimeline {
    pub(crate) events: Vec<BlacklistEvent>,
}

impl BlacklistTimeline {
    /// Apply (insert or replace) a blacklist event, keeping events ordered by timestamp.
    pub fn apply(&mut self, event: BlacklistEvent) {
        let idx = self.events.partition_point(|e| e.at <= event.at);
        if idx > 0 && self.events[idx - 1].at == event.at {
            if self.events[idx - 1].flag != event.flag {
                warn!(at = event.at, ?event.flag, prev = ?self.events[idx - 1].flag, "duplicate blacklist timestamp, overriding");
            }
            self.events[idx - 1] = event;
        } else {
            self.events.insert(idx, event);
        }
    }

    /// Prune history older than `cutoff`, retaining the last event at or before cutoff to preserve
    /// the baseline state for subsequent queries.
    pub fn prune_before(&mut self, cutoff: u64) {
        if self.events.is_empty() {
            return;
        }

        let keep_from = self.events.partition_point(|e| e.at < cutoff);
        if keep_from == 0 {
            return;
        }

        // Preserve the last pre-cutoff event as the new baseline.
        let last_before = self.events[keep_from - 1];
        let baseline_idx = keep_from - 1;
        // Drop everything earlier than the baseline event.
        self.events.drain(..baseline_idx);
        if let Some(first) = self.events.get_mut(0) {
            *first = last_before;
        }
    }

    /// Return blacklist state at the supplied timestamp.
    pub fn was_blacklisted_at(&self, ts: u64) -> bool {
        if self.events.is_empty() {
            return false;
        }

        let idx = self.events.partition_point(|e| e.at <= ts);
        if idx == 0 {
            return false;
        }

        let evt = self.events[idx - 1];
        matches!(evt.flag, BlacklistFlag::Listed)
    }
}

/// Timestamped fallback change for the preconf whitelist operator.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FallbackEvent {
    /// Seconds since UNIX epoch when the change was observed (block timestamp).
    pub at: u64,
    /// Whitelist operator valid from `at` until the next recorded change.
    pub operator: Address,
}

/// Chronological history of whitelist fallback operators, kept small by pruning to the
/// resolver's lookback window while retaining the last pre-cutoff state as baseline.
#[derive(Debug, Default, Clone)]
pub struct FallbackTimeline {
    /// Ordered fallback changes; first entry is treated as baseline for lookups.
    events: Vec<FallbackEvent>,
}

impl FallbackTimeline {
    /// Insert or replace a fallback event, preserving timestamp order.
    pub fn apply(&mut self, event: FallbackEvent) {
        let idx = self.events.partition_point(|e| e.at <= event.at);
        if idx > 0 && self.events[idx - 1].at == event.at {
            self.events[idx - 1] = event;
        } else {
            self.events.insert(idx, event);
        }
    }

    /// Ensure a baseline exists at or before `at`; if none, insert the provided operator at `at`.
    pub fn ensure_baseline(&mut self, at: u64, operator: Address) {
        if self.operator_at(at).is_none() {
            self.apply(FallbackEvent { at, operator });
        }
    }

    /// Remove history older than `cutoff`, keeping the last pre-cutoff entry as the new baseline.
    pub fn prune_before(&mut self, cutoff: u64) {
        if self.events.is_empty() {
            return;
        }

        let keep_from = self.events.partition_point(|e| e.at < cutoff);
        if keep_from == 0 {
            return;
        }

        let last_before = self.events[keep_from - 1];
        let baseline_idx = keep_from - 1;
        self.events.drain(..baseline_idx);
        if let Some(first) = self.events.get_mut(0) {
            *first = last_before;
        }
    }

    /// Return the active fallback operator at `ts`, if any history exists.
    pub fn operator_at(&self, ts: u64) -> Option<Address> {
        if self.events.is_empty() {
            return None;
        }

        let idx = self.events.partition_point(|e| e.at <= ts);
        let evt = if idx == 0 { self.events[0] } else { self.events[idx - 1] };
        Some(evt.operator)
    }
}

/// Copy-on-write wrapper over `FallbackTimeline` providing lock-free reads and atomic updates.
#[derive(Debug, Default)]
pub struct FallbackTimelineStore {
    inner: ArcSwap<FallbackTimeline>,
}

impl Clone for FallbackTimelineStore {
    /// Clone the store, sharing the underlying timeline.
    fn clone(&self) -> Self {
        Self { inner: ArcSwap::from(self.inner.load_full()) }
    }
}

impl FallbackTimelineStore {
    /// Create a new store seeded with an empty timeline.
    pub fn new() -> Self {
        Self { inner: ArcSwap::from_pointee(FallbackTimeline::default()) }
    }

    /// Insert or replace a fallback event, preserving timestamp order.
    pub fn apply(&self, event: FallbackEvent) {
        self.update(|timeline| timeline.apply(event));
    }

    /// Ensure a baseline exists at or before `at`; if none, insert the provided operator at `at`.
    pub fn ensure_baseline(&self, at: u64, operator: Address) {
        // Fast-path read: skip COW if an event at or before `at` already exists.
        if self.operator_at(at).is_some() {
            let earliest = self.inner.load_full().events.first().copied();
            if earliest.is_some_and(|evt| evt.at <= at) {
                return;
            }
        }
        self.update(|timeline| timeline.ensure_baseline(at, operator));
    }

    /// Remove history older than `cutoff`, keeping the last pre-cutoff entry as the new baseline.
    pub fn prune_before(&self, cutoff: u64) {
        self.update(|timeline| timeline.prune_before(cutoff));
    }

    /// Return the active fallback operator at `ts`, if any history exists.
    pub fn operator_at(&self, ts: u64) -> Option<Address> {
        let timeline = self.inner.load_full();
        timeline.operator_at(ts)
    }

    /// Internal helper to perform a copy-on-write update.
    fn update(&self, f: impl FnOnce(&mut FallbackTimeline)) {
        let mut next = (*self.inner.load_full()).clone();
        f(&mut next);
        self.inner.store(Arc::new(next));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blacklist_timeline_applies_and_prunes() {
        let mut timeline = BlacklistTimeline::default();
        timeline.apply(BlacklistEvent { at: 50, flag: BlacklistFlag::Listed });
        timeline.apply(BlacklistEvent { at: 100, flag: BlacklistFlag::Cleared });
        timeline.apply(BlacklistEvent { at: 200, flag: BlacklistFlag::Listed });
        timeline.apply(BlacklistEvent { at: 300, flag: BlacklistFlag::Cleared });

        assert!(timeline.was_blacklisted_at(75));
        assert!(!timeline.was_blacklisted_at(150));
        assert!(timeline.was_blacklisted_at(250));

        timeline.prune_before(150);

        // After pruning, baseline begins at the last pre-cutoff event (100, cleared).
        assert!(!timeline.was_blacklisted_at(125));
        assert!(timeline.was_blacklisted_at(250));

        timeline.prune_before(280);
        assert!(!timeline.was_blacklisted_at(300));
    }

    #[test]
    fn blacklist_timeline_future_event_does_not_apply_to_past() {
        let mut timeline = BlacklistTimeline::default();
        timeline.apply(BlacklistEvent { at: 100, flag: BlacklistFlag::Listed });

        assert!(!timeline.was_blacklisted_at(50));
        assert!(timeline.was_blacklisted_at(150));
    }

    #[test]
    fn blacklist_timeline_respects_list_and_clear_sequence() {
        let mut timeline = BlacklistTimeline::default();
        timeline.apply(BlacklistEvent { at: 100, flag: BlacklistFlag::Listed });
        timeline.apply(BlacklistEvent { at: 150, flag: BlacklistFlag::Cleared });

        assert!(timeline.was_blacklisted_at(120));
        assert!(!timeline.was_blacklisted_at(151));
        assert!(!timeline.was_blacklisted_at(200));
    }

    #[test]
    fn blacklist_timeline_baseline_after_prune_handles_pre_history_queries() {
        let mut timeline = BlacklistTimeline::default();
        timeline.apply(BlacklistEvent { at: 50, flag: BlacklistFlag::Listed });
        timeline.apply(BlacklistEvent { at: 100, flag: BlacklistFlag::Cleared });
        timeline.apply(BlacklistEvent { at: 200, flag: BlacklistFlag::Listed });

        timeline.prune_before(125);

        // Baseline event is the cleared entry at 100; times before it should not be blacklisted.
        assert!(!timeline.was_blacklisted_at(80));
        assert!(!timeline.was_blacklisted_at(150));
        assert!(timeline.was_blacklisted_at(220));
    }

    #[test]
    fn fallback_timeline_tracks_mid_epoch_changes() {
        let mut timeline = FallbackTimeline::default();
        let a = Address::from([1u8; 20]);
        let b = Address::from([2u8; 20]);

        timeline.ensure_baseline(1_000, a);
        timeline.apply(FallbackEvent { at: 1_500, operator: b });

        assert_eq!(timeline.operator_at(1_200), Some(a));
        assert_eq!(timeline.operator_at(1_600), Some(b));
    }

    #[test]
    fn fallback_timeline_prunes_preserving_baseline() {
        let mut timeline = FallbackTimeline::default();
        let a = Address::from([1u8; 20]);
        let b = Address::from([2u8; 20]);

        timeline.apply(FallbackEvent { at: 1_000, operator: a });
        timeline.apply(FallbackEvent { at: 2_000, operator: b });

        timeline.prune_before(1_500);

        assert_eq!(timeline.operator_at(1_600), Some(a));
        assert_eq!(timeline.operator_at(2_100), Some(b));
    }
}
