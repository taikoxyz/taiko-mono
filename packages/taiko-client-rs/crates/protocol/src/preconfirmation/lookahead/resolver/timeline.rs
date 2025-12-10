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
        let evt = if idx == 0 { self.events[0] } else { self.events[idx - 1] };
        matches!(evt.flag, BlacklistFlag::Listed)
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
}
