//! Metrics exposed by the preconfirmation client.

use metrics::Unit;

/// Metric namespace for the preconfirmation client.
pub struct PreconfirmationClientMetrics;

impl PreconfirmationClientMetrics {
    // Client lifecycle metrics
    /// Histogram tracking catchup duration in seconds.
    pub const CATCHUP_DURATION_SECONDS: &'static str = "preconf_client_catchup_duration_seconds";
    /// Counter tracking the number of times the client reached synced state.
    pub const SYNCED_TOTAL: &'static str = "preconf_client_synced_total";

    // Event handler metrics
    /// Counter tracking received commitments.
    pub const COMMITMENTS_RECEIVED_TOTAL: &'static str =
        "preconf_client_commitments_received_total";
    /// Counter tracking received txlists.
    pub const TXLISTS_RECEIVED_TOTAL: &'static str = "preconf_client_txlists_received_total";
    /// Counter tracking validation failures.
    pub const VALIDATION_FAILURES_TOTAL: &'static str = "preconf_client_validation_failures_total";
    /// Counter tracking successful driver submissions.
    pub const DRIVER_SUBMIT_SUCCESS_TOTAL: &'static str =
        "preconf_client_driver_submit_success_total";
    /// Counter tracking failed driver submissions.
    pub const DRIVER_SUBMIT_FAILURE_TOTAL: &'static str =
        "preconf_client_driver_submit_failure_total";
    /// Gauge tracking the head block number.
    pub const HEAD_BLOCK: &'static str = "preconf_client_head_block";
    /// Gauge tracking the number of commitments awaiting txlists.
    pub const AWAITING_TXLIST_DEPTH: &'static str = "preconf_client_awaiting_txlist_depth";

    // Tip catchup metrics
    /// Counter tracking commitment batches fetched during catchup.
    pub const CATCHUP_BATCHES_TOTAL: &'static str = "preconf_client_catchup_batches_total";
    /// Counter tracking errors during catchup.
    pub const CATCHUP_ERRORS_TOTAL: &'static str = "preconf_client_catchup_errors_total";

    // Storage metrics
    /// Gauge tracking stored commitment count.
    pub const STORE_COMMITMENTS_COUNT: &'static str = "preconf_client_store_commitments_count";
    /// Gauge tracking stored txlist count.
    pub const STORE_TXLISTS_COUNT: &'static str = "preconf_client_store_txlists_count";
    /// Gauge tracking pending commitment count.
    pub const STORE_PENDING_COMMITMENTS_COUNT: &'static str =
        "preconf_client_store_pending_commitments_count";

    // Payload builder metrics
    /// Histogram tracking payload build duration in seconds.
    pub const PAYLOAD_BUILD_DURATION_SECONDS: &'static str =
        "preconf_client_payload_build_duration_seconds";
    /// Counter tracking payload build failures.
    pub const PAYLOAD_BUILD_FAILURES_TOTAL: &'static str =
        "preconf_client_payload_build_failures_total";

    // Driver RPC metrics
    /// Histogram tracking driver RPC submit preconfirmation duration in seconds.
    pub const DRIVER_RPC_SUBMIT_DURATION_SECONDS: &'static str =
        "preconf_client_driver_rpc_submit_duration_seconds";
    /// Counter tracking driver RPC submit preconfirmation errors.
    pub const DRIVER_RPC_SUBMIT_ERRORS_TOTAL: &'static str =
        "preconf_client_driver_rpc_submit_errors_total";
    /// Histogram tracking driver RPC last canonical proposal id duration in seconds.
    pub const DRIVER_RPC_LAST_CANONICAL_DURATION_SECONDS: &'static str =
        "preconf_client_driver_rpc_last_canonical_duration_seconds";
    /// Counter tracking driver RPC last canonical proposal id errors.
    pub const DRIVER_RPC_LAST_CANONICAL_ERRORS_TOTAL: &'static str =
        "preconf_client_driver_rpc_last_canonical_errors_total";
    /// Histogram tracking event sync wait duration in seconds.
    pub const EVENT_SYNC_WAIT_DURATION_SECONDS: &'static str =
        "preconf_client_event_sync_wait_duration_seconds";

    /// Register metric descriptors and initialise gauges/counters.
    pub fn init() {
        metrics::describe_histogram!(
            Self::CATCHUP_DURATION_SECONDS,
            Unit::Seconds,
            "Time spent performing tip catch-up"
        );
        metrics::describe_counter!(
            Self::SYNCED_TOTAL,
            Unit::Count,
            "Number of times the client reached synced state"
        );
        metrics::describe_counter!(
            Self::COMMITMENTS_RECEIVED_TOTAL,
            Unit::Count,
            "Total commitments received from the P2P network"
        );
        metrics::describe_counter!(
            Self::TXLISTS_RECEIVED_TOTAL,
            Unit::Count,
            "Total txlists received from the P2P network"
        );
        metrics::describe_counter!(
            Self::VALIDATION_FAILURES_TOTAL,
            Unit::Count,
            "Total validation failures for commitments or txlists"
        );
        metrics::describe_counter!(
            Self::DRIVER_SUBMIT_SUCCESS_TOTAL,
            Unit::Count,
            "Successful submissions to the driver"
        );
        metrics::describe_counter!(
            Self::DRIVER_SUBMIT_FAILURE_TOTAL,
            Unit::Count,
            "Failed submissions to the driver"
        );
        metrics::describe_gauge!(
            Self::HEAD_BLOCK,
            Unit::Count,
            "Current head block number tracked by the client"
        );
        metrics::describe_gauge!(
            Self::AWAITING_TXLIST_DEPTH,
            Unit::Count,
            "Number of commitments awaiting their txlist payload"
        );
        metrics::describe_counter!(
            Self::CATCHUP_BATCHES_TOTAL,
            Unit::Count,
            "Commitment batches fetched during tip catch-up"
        );
        metrics::describe_counter!(
            Self::CATCHUP_ERRORS_TOTAL,
            Unit::Count,
            "Errors encountered during tip catch-up"
        );
        metrics::describe_gauge!(
            Self::STORE_COMMITMENTS_COUNT,
            Unit::Count,
            "Number of commitments in the store"
        );
        metrics::describe_gauge!(
            Self::STORE_TXLISTS_COUNT,
            Unit::Count,
            "Number of txlists in the store"
        );
        metrics::describe_gauge!(
            Self::STORE_PENDING_COMMITMENTS_COUNT,
            Unit::Count,
            "Number of pending commitments in the store"
        );

        // Payload builder metrics
        metrics::describe_histogram!(
            Self::PAYLOAD_BUILD_DURATION_SECONDS,
            Unit::Seconds,
            "Time spent building execution payload"
        );
        metrics::describe_counter!(
            Self::PAYLOAD_BUILD_FAILURES_TOTAL,
            Unit::Count,
            "Total payload build failures"
        );

        // Driver RPC metrics
        metrics::describe_histogram!(
            Self::DRIVER_RPC_SUBMIT_DURATION_SECONDS,
            Unit::Seconds,
            "Time spent on driver RPC submit preconfirmation calls"
        );
        metrics::describe_counter!(
            Self::DRIVER_RPC_SUBMIT_ERRORS_TOTAL,
            Unit::Count,
            "Driver RPC submit preconfirmation errors"
        );
        metrics::describe_histogram!(
            Self::DRIVER_RPC_LAST_CANONICAL_DURATION_SECONDS,
            Unit::Seconds,
            "Time spent on driver RPC last canonical proposal id calls"
        );
        metrics::describe_counter!(
            Self::DRIVER_RPC_LAST_CANONICAL_ERRORS_TOTAL,
            Unit::Count,
            "Driver RPC last canonical proposal id errors"
        );
        metrics::describe_histogram!(
            Self::EVENT_SYNC_WAIT_DURATION_SECONDS,
            Unit::Seconds,
            "Time spent waiting for driver event sync"
        );

        // Reset counters to zero.
        metrics::counter!(Self::SYNCED_TOTAL).absolute(0);
        metrics::counter!(Self::COMMITMENTS_RECEIVED_TOTAL).absolute(0);
        metrics::counter!(Self::TXLISTS_RECEIVED_TOTAL).absolute(0);
        metrics::counter!(Self::VALIDATION_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::DRIVER_SUBMIT_SUCCESS_TOTAL).absolute(0);
        metrics::counter!(Self::DRIVER_SUBMIT_FAILURE_TOTAL).absolute(0);
        metrics::counter!(Self::CATCHUP_BATCHES_TOTAL).absolute(0);
        metrics::counter!(Self::CATCHUP_ERRORS_TOTAL).absolute(0);
        metrics::counter!(Self::PAYLOAD_BUILD_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::DRIVER_RPC_SUBMIT_ERRORS_TOTAL).absolute(0);
        metrics::counter!(Self::DRIVER_RPC_LAST_CANONICAL_ERRORS_TOTAL).absolute(0);

        // Reset gauges to zero.
        metrics::gauge!(Self::HEAD_BLOCK).set(0.0);
        metrics::gauge!(Self::AWAITING_TXLIST_DEPTH).set(0.0);
        metrics::gauge!(Self::STORE_COMMITMENTS_COUNT).set(0.0);
        metrics::gauge!(Self::STORE_TXLISTS_COUNT).set(0.0);
        metrics::gauge!(Self::STORE_PENDING_COMMITMENTS_COUNT).set(0.0);
    }
}

#[cfg(test)]
mod tests {
    use super::PreconfirmationClientMetrics;

    /// Verify that all metric constants have the correct prefix.
    #[test]
    fn metric_constants_have_correct_prefix() {
        assert!(
            PreconfirmationClientMetrics::CATCHUP_DURATION_SECONDS.starts_with("preconf_client_")
        );
        assert!(PreconfirmationClientMetrics::SYNCED_TOTAL.starts_with("preconf_client_"));
        assert!(
            PreconfirmationClientMetrics::COMMITMENTS_RECEIVED_TOTAL.starts_with("preconf_client_")
        );
        assert!(
            PreconfirmationClientMetrics::TXLISTS_RECEIVED_TOTAL.starts_with("preconf_client_")
        );
        assert!(
            PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL.starts_with("preconf_client_")
        );
        assert!(
            PreconfirmationClientMetrics::DRIVER_SUBMIT_SUCCESS_TOTAL
                .starts_with("preconf_client_")
        );
        assert!(
            PreconfirmationClientMetrics::DRIVER_SUBMIT_FAILURE_TOTAL
                .starts_with("preconf_client_")
        );
        assert!(PreconfirmationClientMetrics::HEAD_BLOCK.starts_with("preconf_client_"));
        assert!(PreconfirmationClientMetrics::AWAITING_TXLIST_DEPTH.starts_with("preconf_client_"));
        assert!(PreconfirmationClientMetrics::CATCHUP_BATCHES_TOTAL.starts_with("preconf_client_"));
        assert!(PreconfirmationClientMetrics::CATCHUP_ERRORS_TOTAL.starts_with("preconf_client_"));
        assert!(
            PreconfirmationClientMetrics::STORE_COMMITMENTS_COUNT.starts_with("preconf_client_")
        );
        assert!(PreconfirmationClientMetrics::STORE_TXLISTS_COUNT.starts_with("preconf_client_"));
        assert!(
            PreconfirmationClientMetrics::STORE_PENDING_COMMITMENTS_COUNT
                .starts_with("preconf_client_")
        );
    }

    /// Verify that init can be called without panic.
    #[test]
    fn init_does_not_panic() {
        PreconfirmationClientMetrics::init();
    }

    /// Verify that payload builder metrics have correct names.
    #[test]
    fn payload_builder_metrics_have_correct_prefix() {
        assert!(
            PreconfirmationClientMetrics::PAYLOAD_BUILD_DURATION_SECONDS
                .starts_with("preconf_client_")
        );
        assert_eq!(
            PreconfirmationClientMetrics::PAYLOAD_BUILD_DURATION_SECONDS,
            "preconf_client_payload_build_duration_seconds"
        );
        assert!(
            PreconfirmationClientMetrics::PAYLOAD_BUILD_FAILURES_TOTAL
                .starts_with("preconf_client_")
        );
        assert_eq!(
            PreconfirmationClientMetrics::PAYLOAD_BUILD_FAILURES_TOTAL,
            "preconf_client_payload_build_failures_total"
        );
    }

    /// Verify that driver RPC metrics have correct names.
    #[test]
    fn driver_rpc_metrics_have_correct_prefix() {
        assert!(
            PreconfirmationClientMetrics::DRIVER_RPC_SUBMIT_DURATION_SECONDS
                .starts_with("preconf_client_")
        );
        assert_eq!(
            PreconfirmationClientMetrics::DRIVER_RPC_SUBMIT_DURATION_SECONDS,
            "preconf_client_driver_rpc_submit_duration_seconds"
        );
        assert!(
            PreconfirmationClientMetrics::DRIVER_RPC_SUBMIT_ERRORS_TOTAL
                .starts_with("preconf_client_")
        );
        assert_eq!(
            PreconfirmationClientMetrics::DRIVER_RPC_SUBMIT_ERRORS_TOTAL,
            "preconf_client_driver_rpc_submit_errors_total"
        );
        assert!(
            PreconfirmationClientMetrics::DRIVER_RPC_LAST_CANONICAL_DURATION_SECONDS
                .starts_with("preconf_client_")
        );
        assert_eq!(
            PreconfirmationClientMetrics::DRIVER_RPC_LAST_CANONICAL_DURATION_SECONDS,
            "preconf_client_driver_rpc_last_canonical_duration_seconds"
        );
        assert!(
            PreconfirmationClientMetrics::DRIVER_RPC_LAST_CANONICAL_ERRORS_TOTAL
                .starts_with("preconf_client_")
        );
        assert_eq!(
            PreconfirmationClientMetrics::DRIVER_RPC_LAST_CANONICAL_ERRORS_TOTAL,
            "preconf_client_driver_rpc_last_canonical_errors_total"
        );
        assert!(
            PreconfirmationClientMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS
                .starts_with("preconf_client_")
        );
        assert_eq!(
            PreconfirmationClientMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS,
            "preconf_client_event_sync_wait_duration_seconds"
        );
    }
}
