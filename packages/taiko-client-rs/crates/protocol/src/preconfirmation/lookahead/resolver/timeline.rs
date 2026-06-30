use std::sync::{Arc, Mutex, MutexGuard};

use alloy_primitives::Address;
use tracing::warn;

/// Generic, timestamp-ordered history of payloads of type `T`, pruned to a lookback window while
/// retaining the last pre-cutoff entry as a baseline. Shared by the blacklist and fallback
/// timelines, which differ only in their payload type and lookup semantics.
#[derive(Debug, Clone)]
struct Timeline<T> {
    /// Timestamp-sorted `(at, payload)` pairs; the first entry acts as the baseline for lookups.
    events: Vec<(u64, T)>,
}

impl<T> Default for Timeline<T> {
    /// Create an empty timeline.
    fn default() -> Self {
        Self { events: Vec::new() }
    }
}

impl<T: Clone> Timeline<T> {
    /// Insert or replace the payload at `at`, keeping events ordered by timestamp. When an event
    /// already exists at `at`, `on_replace` is invoked with the previous payload before it is
    /// overwritten (used by the blacklist timeline to warn on conflicting flags).
    fn apply(&mut self, at: u64, payload: T, on_replace: impl FnOnce(&T)) {
        let idx = self.events.partition_point(|(event_at, _)| *event_at <= at);
        if idx > 0 && self.events[idx - 1].0 == at {
            on_replace(&self.events[idx - 1].1);
            self.events[idx - 1] = (at, payload);
        } else {
            self.events.insert(idx, (at, payload));
        }
    }

    /// Prune history older than `cutoff`, retaining the last event at or before cutoff to preserve
    /// the baseline state for subsequent queries.
    fn prune_before(&mut self, cutoff: u64) {
        if self.events.is_empty() {
            return;
        }

        let keep_from = self.events.partition_point(|(event_at, _)| *event_at < cutoff);
        if keep_from == 0 {
            return;
        }

        // Preserve the last pre-cutoff event as the new baseline.
        let last_before = self.events[keep_from - 1].clone();
        let baseline_idx = keep_from - 1;
        // Drop everything earlier than the baseline event.
        self.events.drain(..baseline_idx);
        if let Some(first) = self.events.get_mut(0) {
            *first = last_before;
        }
    }

    /// Return the payload of the last event at or before `ts`, or `None` if no such event exists.
    fn value_at(&self, ts: u64) -> Option<&T> {
        if self.events.is_empty() {
            return None;
        }

        let idx = self.events.partition_point(|(event_at, _)| *event_at <= ts);
        if idx == 0 {
            return None;
        }
        Some(&self.events[idx - 1].1)
    }

    /// Like [`value_at`](Self::value_at) but, when no event precedes `ts`, falls back to the
    /// earliest (baseline) event. Returns `None` only when the timeline is empty.
    fn value_at_or_baseline(&self, ts: u64) -> Option<&T> {
        if self.events.is_empty() {
            return None;
        }

        let idx = self.events.partition_point(|(event_at, _)| *event_at <= ts);
        let slot = if idx == 0 { 0 } else { idx - 1 };
        Some(&self.events[slot].1)
    }
}

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
    /// Timestamp-sorted blacklist flags for one registration root.
    inner: Timeline<BlacklistFlag>,
}

impl BlacklistTimeline {
    /// Apply (insert or replace) a blacklist event, keeping events ordered by timestamp.
    pub fn apply(&mut self, event: BlacklistEvent) {
        self.inner.apply(event.at, event.flag, |prev| {
            if *prev != event.flag {
                warn!(at = event.at, ?event.flag, prev = ?prev, "duplicate blacklist timestamp, overriding");
            }
        });
    }

    /// Prune history older than `cutoff`, retaining the last event at or before cutoff to preserve
    /// the baseline state for subsequent queries.
    pub fn prune_before(&mut self, cutoff: u64) {
        self.inner.prune_before(cutoff);
    }

    /// Return blacklist state at the supplied timestamp.
    pub fn was_blacklisted_at(&self, ts: u64) -> bool {
        matches!(self.inner.value_at(ts), Some(BlacklistFlag::Listed))
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
    /// Ordered fallback operators; the first entry is treated as baseline for lookups.
    inner: Timeline<Address>,
}

impl FallbackTimeline {
    /// Insert or replace a fallback event, preserving timestamp order.
    pub fn apply(&mut self, event: FallbackEvent) {
        self.inner.apply(event.at, event.operator, |_| {});
    }

    /// Ensure a baseline exists at or before `at`; if none, insert the provided operator at `at`.
    pub fn ensure_baseline(&mut self, at: u64, operator: Address) {
        if self.operator_at(at).is_none() {
            self.apply(FallbackEvent { at, operator });
        }
    }

    /// Remove history older than `cutoff`, keeping the last pre-cutoff entry as the new baseline.
    pub fn prune_before(&mut self, cutoff: u64) {
        self.inner.prune_before(cutoff);
    }

    /// Return the active fallback operator at `ts`, if any history exists.
    pub fn operator_at(&self, ts: u64) -> Option<Address> {
        self.inner.value_at_or_baseline(ts).copied()
    }
}

/// Shared handle to the whitelist fallback timeline. Clones share the same underlying state, so
/// updates recorded by the scanner ingest task are visible to every resolver clone.
#[derive(Debug, Default, Clone)]
pub struct FallbackTimelineStore {
    /// Timeline shared across all clones of the store.
    inner: Arc<Mutex<FallbackTimeline>>,
}

impl FallbackTimelineStore {
    /// Create a new store seeded with an empty timeline.
    pub fn new() -> Self {
        Self::default()
    }

    /// Insert or replace a fallback event, preserving timestamp order.
    pub fn apply(&self, event: FallbackEvent) {
        self.lock().apply(event);
    }

    /// Ensure a baseline exists at or before `at`; if none, insert the provided operator at `at`.
    pub fn ensure_baseline(&self, at: u64, operator: Address) {
        self.lock().ensure_baseline(at, operator);
    }

    /// Remove history older than `cutoff`, keeping the last pre-cutoff entry as the new baseline.
    pub fn prune_before(&self, cutoff: u64) {
        self.lock().prune_before(cutoff);
    }

    /// Return the active fallback operator at `ts`, if any history exists.
    pub fn operator_at(&self, ts: u64) -> Option<Address> {
        self.lock().operator_at(ts)
    }

    /// Lock the shared timeline.
    fn lock(&self) -> MutexGuard<'_, FallbackTimeline> {
        self.inner.lock().expect("fallback timeline lock poisoned")
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
    fn fallback_store_clones_share_state() {
        let store = FallbackTimelineStore::new();
        let clone = store.clone();
        let a = Address::from([1u8; 20]);

        clone.apply(FallbackEvent { at: 1_000, operator: a });

        // Events applied through one handle must be visible through every clone: the resolver is
        // cloned into the scanner ingest task, and whitelist operator changes recorded there must
        // be observable by queries on the original resolver.
        assert_eq!(store.operator_at(1_500), Some(a));
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
