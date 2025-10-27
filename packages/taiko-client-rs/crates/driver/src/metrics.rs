//! Metrics exposed by the driver runtime.

use metrics::{Unit, describe_gauge};

/// Metric namespace for the driver.
pub struct DriverMetrics;

impl DriverMetrics {
    /// Gauge tracking the latest L1 origin block ID seen on the execution engine.
    pub const BEACON_HEAD_BLOCK_ID: &'static str = "driver_beacon_head_block_id";
    /// Gauge tracking the next proposal ID reported by the inbox core state.
    pub const NEXT_PROPOSAL_ID: &'static str = "driver_next_proposal_id";
    /// Gauge tracking the last finalized proposal ID.
    pub const LAST_FINALIZED_PROPOSAL_ID: &'static str = "driver_last_finalized_proposal_id";
    /// Gauge tracking the highest proposal ID observed from events.
    pub const LAST_SEEN_PROPOSAL_ID: &'static str = "driver_last_seen_proposal_id";
    /// Gauge tracking the number of pending transitions waiting for finalization.
    pub const TRANSITION_QUEUE_DEPTH: &'static str = "driver_transition_queue_depth";

    /// Register metric descriptors.
    pub fn init() {
        describe_gauge!(
            Self::BEACON_HEAD_BLOCK_ID,
            Unit::Count,
            "Latest L1 origin block ID known by the execution engine"
        );
        describe_gauge!(
            Self::NEXT_PROPOSAL_ID,
            Unit::Count,
            "Next proposal ID expected to be proposed on L1"
        );
        describe_gauge!(
            Self::LAST_FINALIZED_PROPOSAL_ID,
            Unit::Count,
            "Last finalized proposal ID tracked by the protocol"
        );
        describe_gauge!(
            Self::LAST_SEEN_PROPOSAL_ID,
            Unit::Count,
            "Highest proposal ID observed from Shasta inbox events"
        );
        describe_gauge!(
            Self::TRANSITION_QUEUE_DEPTH,
            Unit::Count,
            "Number of cached transition records ready for finalization"
        );
    }
}
