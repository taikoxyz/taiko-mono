//! Prometheus metrics for tracking event indexer performance.

#[derive(Debug, Clone)]
pub struct IndexerMetrics;

impl IndexerMetrics {
    /// Counter for total Proposed events received.
    pub const PROPOSED_EVENTS: &'static str = "taiko_indexer_proposed_events_total";

    /// Counter for total Proved events received.
    pub const PROVED_EVENTS: &'static str = "taiko_indexer_proved_events_total";

    /// Gauge for current number of cached proposals.
    pub const CACHED_PROPOSALS: &'static str = "taiko_indexer_cached_proposals";

    /// Gauge for current number of cached proofs.
    pub const CACHED_PROOFS: &'static str = "taiko_indexer_cached_proofs";

    /// Gauge for latest indexed block number.
    pub const LATEST_BLOCK: &'static str = "taiko_indexer_latest_block";

    pub const PROPOSED_EVENT_ERRORS: &'static str = "taiko_indexer_proposed_event_errors_total";
    pub const PROVED_EVENT_ERRORS: &'static str = "taiko_indexer_proved_event_errors_total";
    pub const DROPPED_EVENTS: &'static str = "taiko_indexer_dropped_events_total";

    /// Describes metrics used in the indexer.
    pub fn describe() {
        metrics::describe_counter!(
            Self::PROPOSED_EVENTS,
            "Total number of Proposed events received and processed"
        );

        metrics::describe_counter!(
            Self::PROVED_EVENTS,
            "Total number of Proved events received and processed"
        );

        metrics::describe_gauge!(
            Self::CACHED_PROPOSALS,
            "Current number of proposals cached in memory"
        );

        metrics::describe_gauge!(Self::CACHED_PROOFS, "Current number of proofs cached in memory");

        metrics::describe_gauge!(Self::LATEST_BLOCK, "Latest L1 block number indexed");

        metrics::describe_counter!(
            Self::PROPOSED_EVENT_ERRORS,
            "Total number of Proposed event handling failures"
        );
        metrics::describe_counter!(
            Self::PROVED_EVENT_ERRORS,
            "Total number of Proved event handling failures"
        );
        metrics::describe_counter!(Self::DROPPED_EVENTS, "Total number of dropped inbox events");
    }

    /// Initializes metrics to 0 so they can be queried immediately.
    pub fn init() {
        Self::describe();
        Self::zero();
    }

    /// Initializes all counters to 0.
    fn zero() {
        metrics::counter!(Self::PROPOSED_EVENTS).absolute(0);
        metrics::counter!(Self::PROVED_EVENTS).absolute(0);
        metrics::gauge!(Self::CACHED_PROPOSALS).set(0.0);
        metrics::gauge!(Self::CACHED_PROOFS).set(0.0);
        metrics::gauge!(Self::LATEST_BLOCK).set(0.0);
        metrics::counter!(Self::PROPOSED_EVENT_ERRORS).absolute(0);
        metrics::counter!(Self::PROVED_EVENT_ERRORS).absolute(0);
        metrics::counter!(Self::DROPPED_EVENTS).absolute(0);
    }
}
