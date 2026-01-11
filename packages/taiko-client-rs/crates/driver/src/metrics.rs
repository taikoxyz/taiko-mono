//! Metrics exposed by the driver runtime.

use metrics::Unit;

/// Metric namespace for the driver.
pub struct DriverMetrics;

impl DriverMetrics {
    /// Gauge tracking the latest L2 head observed on the execution engine.
    pub const BEACON_SYNC_LOCAL_HEAD_BLOCK: &'static str = "driver_beacon_sync_local_head_block";
    /// Gauge tracking the checkpoint node head height.
    pub const BEACON_SYNC_CHECKPOINT_HEAD_BLOCK: &'static str =
        "driver_beacon_sync_checkpoint_head_block";
    /// Gauge tracking the delta between checkpoint and local heads.
    pub const BEACON_SYNC_HEAD_LAG_BLOCKS: &'static str = "driver_beacon_sync_head_lag_blocks";
    /// Counter tracking submitted checkpoint blocks.
    pub const BEACON_SYNC_REMOTE_SUBMISSIONS_TOTAL: &'static str =
        "driver_beacon_sync_remote_submissions_total";
    /// Counter tracking batches of proposal logs received from the scanner.
    pub const EVENT_SCANNER_BATCHES_TOTAL: &'static str = "driver_event_scanner_batches_total";
    /// Counter tracking scanner stream errors.
    pub const EVENT_SCANNER_ERRORS_TOTAL: &'static str = "driver_event_scanner_errors_total";
    /// Counter tracking proposal logs processed by the driver.
    pub const EVENT_PROPOSALS_TOTAL: &'static str = "driver_event_proposals_total";
    /// Counter tracking skipped proposals (e.g. zero ID, below initial ID).
    pub const EVENT_PROPOSALS_SKIPPED_TOTAL: &'static str = "driver_event_proposals_skipped_total";
    /// Counter tracking derived or confirmed L2 blocks per proposal.
    pub const EVENT_DERIVED_BLOCKS_TOTAL: &'static str = "driver_event_derived_blocks_total";
    /// Counter tracking proposals resolved entirely via canonical chain detection.
    pub const DERIVATION_CANONICAL_HITS_TOTAL: &'static str =
        "driver_derivation_canonical_hits_total";
    /// Counter tracking L1 origin rows written to the execution engine database.
    pub const DERIVATION_L1_ORIGIN_UPDATES_TOTAL: &'static str =
        "driver_derivation_l1_origin_updates_total";
    /// Gauge tracking the last finalized proposal id advertised by the inbox core state.
    pub const DERIVATION_LAST_FINALIZED_PROPOSAL_ID: &'static str =
        "driver_derivation_last_finalized_proposal_id";
    /// Counter tracking failed preconfirmation payload injections.
    pub const PRECONF_INJECTION_FAILURES_TOTAL: &'static str =
        "driver_preconf_injection_failures_total";
    /// Counter tracking successful preconfirmation payload injections.
    pub const PRECONF_INJECTION_SUCCESS_TOTAL: &'static str =
        "driver_preconf_injection_success_total";
    /// Histogram tracking end-to-end latency per preconfirmation payload (seconds).
    pub const PRECONF_INJECTION_DURATION_SECONDS: &'static str =
        "driver_preconf_injection_duration_seconds";
    /// Gauge tracking buffered preconfirmation jobs awaiting processing.
    pub const PRECONF_QUEUE_DEPTH: &'static str = "driver_preconf_queue_depth";
    /// Histogram tracking retry attempts per preconfirmation payload.
    pub const PRECONF_RETRY_ATTEMPTS: &'static str = "driver_preconf_retry_attempts";

    // RPC method-specific metrics
    /// Counter for submit_preconfirmation_payload requests.
    pub const RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_REQUESTS_TOTAL: &'static str =
        "driver_rpc_submit_preconfirmation_payload_requests_total";
    /// Counter for submit_preconfirmation_payload errors.
    pub const RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_ERRORS_TOTAL: &'static str =
        "driver_rpc_submit_preconfirmation_payload_errors_total";
    /// Histogram for submit_preconfirmation_payload duration.
    pub const RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_DURATION_SECONDS: &'static str =
        "driver_rpc_submit_preconfirmation_payload_duration_seconds";
    /// Counter for last_canonical_proposal_id requests.
    pub const RPC_LAST_CANONICAL_PROPOSAL_ID_REQUESTS_TOTAL: &'static str =
        "driver_rpc_last_canonical_proposal_id_requests_total";
    /// Counter for last_canonical_proposal_id errors.
    pub const RPC_LAST_CANONICAL_PROPOSAL_ID_ERRORS_TOTAL: &'static str =
        "driver_rpc_last_canonical_proposal_id_errors_total";
    /// Histogram for last_canonical_proposal_id duration.
    pub const RPC_LAST_CANONICAL_PROPOSAL_ID_DURATION_SECONDS: &'static str =
        "driver_rpc_last_canonical_proposal_id_duration_seconds";
    /// Counter for unauthorized RPC requests.
    pub const RPC_UNAUTHORIZED_TOTAL: &'static str = "driver_rpc_unauthorized_total";

    // Event syncer metrics
    /// Gauge tracking the last canonical proposal id from L1 events.
    pub const EVENT_LAST_CANONICAL_PROPOSAL_ID: &'static str =
        "driver_event_last_canonical_proposal_id";

    // Preconf queue metrics
    /// Counter for preconfirmation enqueue timeouts.
    pub const PRECONF_ENQUEUE_TIMEOUTS_TOTAL: &'static str =
        "driver_preconf_enqueue_timeouts_total";
    /// Counter for preconfirmation response timeouts.
    pub const PRECONF_RESPONSE_TIMEOUTS_TOTAL: &'static str =
        "driver_preconf_response_timeouts_total";
    /// Counter for preconfirmation enqueue failures.
    pub const PRECONF_ENQUEUE_FAILURES_TOTAL: &'static str =
        "driver_preconf_enqueue_failures_total";
    /// Counter for preconfirmation responses dropped (channel closed).
    pub const PRECONF_RESPONSE_DROPPED_TOTAL: &'static str =
        "driver_preconf_response_dropped_total";

    // Production path metrics
    /// Histogram for parent hash lookup duration.
    pub const PRECONF_PARENT_HASH_LOOKUP_DURATION_SECONDS: &'static str =
        "driver_preconf_parent_hash_lookup_duration_seconds";
    /// Counter for parent hash lookup failures.
    pub const PRECONF_PARENT_HASH_LOOKUP_FAILURES_TOTAL: &'static str =
        "driver_preconf_parent_hash_lookup_failures_total";

    /// Register metric descriptors and initialise gauges/counters.
    pub fn init() {
        metrics::describe_gauge!(
            Self::BEACON_SYNC_LOCAL_HEAD_BLOCK,
            Unit::Count,
            "Latest L2 head height observed during beacon sync"
        );
        metrics::describe_gauge!(
            Self::BEACON_SYNC_CHECKPOINT_HEAD_BLOCK,
            Unit::Count,
            "Checkpoint node head height sampled during beacon sync"
        );
        metrics::describe_gauge!(
            Self::BEACON_SYNC_HEAD_LAG_BLOCKS,
            Unit::Count,
            "Checkpoint vs local head lag tracked by beacon sync"
        );
        metrics::describe_counter!(
            Self::BEACON_SYNC_REMOTE_SUBMISSIONS_TOTAL,
            Unit::Count,
            "Checkpoint blocks submitted during beacon sync"
        );
        metrics::describe_counter!(
            Self::EVENT_SCANNER_BATCHES_TOTAL,
            Unit::Count,
            "Proposal log batches received from the event scanner"
        );
        metrics::describe_counter!(
            Self::EVENT_SCANNER_ERRORS_TOTAL,
            Unit::Count,
            "Errors emitted by the event scanner stream"
        );
        metrics::describe_counter!(
            Self::EVENT_PROPOSALS_TOTAL,
            Unit::Count,
            "Total proposal logs dispatched to derivation"
        );
        metrics::describe_counter!(
            Self::EVENT_PROPOSALS_SKIPPED_TOTAL,
            Unit::Count,
            "Proposal logs skipped before derivation"
        );
        metrics::describe_counter!(
            Self::EVENT_DERIVED_BLOCKS_TOTAL,
            Unit::Count,
            "L2 blocks derived or confirmed from proposals"
        );
        metrics::describe_counter!(
            Self::DERIVATION_CANONICAL_HITS_TOTAL,
            Unit::Count,
            "Proposals resolved via canonical block detection"
        );
        metrics::describe_counter!(
            Self::DERIVATION_L1_ORIGIN_UPDATES_TOTAL,
            Unit::Count,
            "L1 origin updates written during derivation"
        );
        metrics::describe_gauge!(
            Self::DERIVATION_LAST_FINALIZED_PROPOSAL_ID,
            Unit::Count,
            "Last finalized proposal id observed from the core state"
        );
        metrics::describe_counter!(
            Self::PRECONF_INJECTION_FAILURES_TOTAL,
            Unit::Count,
            "Preconfirmation payload injections that failed"
        );
        metrics::describe_counter!(
            Self::PRECONF_INJECTION_SUCCESS_TOTAL,
            Unit::Count,
            "Preconfirmation payload injections that succeeded"
        );
        metrics::describe_histogram!(
            Self::PRECONF_INJECTION_DURATION_SECONDS,
            Unit::Seconds,
            "Wall-clock time to process a preconfirmation payload"
        );
        metrics::describe_gauge!(
            Self::PRECONF_QUEUE_DEPTH,
            Unit::Count,
            "Buffered preconfirmation jobs awaiting processing"
        );
        metrics::describe_histogram!(
            Self::PRECONF_RETRY_ATTEMPTS,
            Unit::Count,
            "Retry attempts per preconfirmation payload"
        );

        // RPC method-specific metrics
        metrics::describe_counter!(
            Self::RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_REQUESTS_TOTAL,
            Unit::Count,
            "Total submit_preconfirmation_payload requests"
        );
        metrics::describe_counter!(
            Self::RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_ERRORS_TOTAL,
            Unit::Count,
            "Failed submit_preconfirmation_payload requests"
        );
        metrics::describe_histogram!(
            Self::RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_DURATION_SECONDS,
            Unit::Seconds,
            "Duration of submit_preconfirmation_payload requests"
        );
        metrics::describe_counter!(
            Self::RPC_LAST_CANONICAL_PROPOSAL_ID_REQUESTS_TOTAL,
            Unit::Count,
            "Total last_canonical_proposal_id requests"
        );
        metrics::describe_counter!(
            Self::RPC_LAST_CANONICAL_PROPOSAL_ID_ERRORS_TOTAL,
            Unit::Count,
            "Failed last_canonical_proposal_id requests"
        );
        metrics::describe_histogram!(
            Self::RPC_LAST_CANONICAL_PROPOSAL_ID_DURATION_SECONDS,
            Unit::Seconds,
            "Duration of last_canonical_proposal_id requests"
        );
        metrics::describe_counter!(
            Self::RPC_UNAUTHORIZED_TOTAL,
            Unit::Count,
            "Unauthorized RPC requests rejected by JWT validation"
        );

        // Event syncer metrics
        metrics::describe_gauge!(
            Self::EVENT_LAST_CANONICAL_PROPOSAL_ID,
            Unit::Count,
            "Last canonical proposal id processed from L1 events"
        );

        // Preconf queue metrics
        metrics::describe_counter!(
            Self::PRECONF_ENQUEUE_TIMEOUTS_TOTAL,
            Unit::Count,
            "Preconfirmation enqueue operations that timed out"
        );
        metrics::describe_counter!(
            Self::PRECONF_RESPONSE_TIMEOUTS_TOTAL,
            Unit::Count,
            "Preconfirmation response waits that timed out"
        );
        metrics::describe_counter!(
            Self::PRECONF_ENQUEUE_FAILURES_TOTAL,
            Unit::Count,
            "Preconfirmation enqueue operations that failed"
        );
        metrics::describe_counter!(
            Self::PRECONF_RESPONSE_DROPPED_TOTAL,
            Unit::Count,
            "Preconfirmation responses dropped due to channel closure"
        );

        // Production path metrics
        metrics::describe_histogram!(
            Self::PRECONF_PARENT_HASH_LOOKUP_DURATION_SECONDS,
            Unit::Seconds,
            "Duration of parent hash lookups for preconfirmation"
        );
        metrics::describe_counter!(
            Self::PRECONF_PARENT_HASH_LOOKUP_FAILURES_TOTAL,
            Unit::Count,
            "Parent hash lookup failures during preconfirmation"
        );

        // Reset counters to zero.
        metrics::counter!(Self::BEACON_SYNC_REMOTE_SUBMISSIONS_TOTAL).absolute(0);
        metrics::counter!(Self::EVENT_SCANNER_BATCHES_TOTAL).absolute(0);
        metrics::counter!(Self::EVENT_SCANNER_ERRORS_TOTAL).absolute(0);
        metrics::counter!(Self::EVENT_PROPOSALS_TOTAL).absolute(0);
        metrics::counter!(Self::EVENT_PROPOSALS_SKIPPED_TOTAL).absolute(0);
        metrics::counter!(Self::EVENT_DERIVED_BLOCKS_TOTAL).absolute(0);
        metrics::counter!(Self::DERIVATION_CANONICAL_HITS_TOTAL).absolute(0);
        metrics::counter!(Self::DERIVATION_L1_ORIGIN_UPDATES_TOTAL).absolute(0);
        metrics::counter!(Self::PRECONF_INJECTION_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::PRECONF_INJECTION_SUCCESS_TOTAL).absolute(0);
        metrics::gauge!(Self::PRECONF_QUEUE_DEPTH).set(0.0);

        // Reset new RPC counters
        metrics::counter!(Self::RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_REQUESTS_TOTAL).absolute(0);
        metrics::counter!(Self::RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_ERRORS_TOTAL).absolute(0);
        metrics::counter!(Self::RPC_LAST_CANONICAL_PROPOSAL_ID_REQUESTS_TOTAL).absolute(0);
        metrics::counter!(Self::RPC_LAST_CANONICAL_PROPOSAL_ID_ERRORS_TOTAL).absolute(0);
        metrics::counter!(Self::RPC_UNAUTHORIZED_TOTAL).absolute(0);

        // Reset new preconf queue counters
        metrics::counter!(Self::PRECONF_ENQUEUE_TIMEOUTS_TOTAL).absolute(0);
        metrics::counter!(Self::PRECONF_RESPONSE_TIMEOUTS_TOTAL).absolute(0);
        metrics::counter!(Self::PRECONF_ENQUEUE_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::PRECONF_RESPONSE_DROPPED_TOTAL).absolute(0);

        // Reset production path counters
        metrics::counter!(Self::PRECONF_PARENT_HASH_LOOKUP_FAILURES_TOTAL).absolute(0);

        // Reset event syncer gauge
        metrics::gauge!(Self::EVENT_LAST_CANONICAL_PROPOSAL_ID).set(0.0);
    }
}
