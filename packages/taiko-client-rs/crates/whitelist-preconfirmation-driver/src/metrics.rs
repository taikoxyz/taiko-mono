//! Metrics exposed by the whitelist preconfirmation driver runtime.

use metrics::Unit;

/// Metric namespace for the whitelist preconfirmation driver.
pub struct WhitelistPreconfirmationDriverMetrics;

impl WhitelistPreconfirmationDriverMetrics {
    // Runner lifecycle metrics
    /// Counter tracking runner starts.
    pub const RUNNER_START_TOTAL: &'static str = "whitelist_preconf_driver_runner_start_total";
    /// Counter tracking runner exits by reason.
    pub const RUNNER_EXIT_TOTAL: &'static str = "whitelist_preconf_driver_runner_exit_total";
    /// Histogram tracking how long we wait for event-sync ingress readiness.
    pub const EVENT_SYNC_WAIT_DURATION_SECONDS: &'static str =
        "whitelist_preconf_driver_event_sync_wait_duration_seconds";
    /// Counter tracking sync-ready transitions.
    pub const SYNC_READY_TRANSITIONS_TOTAL: &'static str =
        "whitelist_preconf_driver_sync_ready_transitions_total";
    /// Counter tracking sync-ready triggered import failures.
    pub const SYNC_READY_IMPORT_FAILURES_TOTAL: &'static str =
        "whitelist_preconf_driver_sync_ready_import_failures_total";

    // Network metrics
    /// Counter tracking inbound gossip/request messages by topic and decode status.
    pub const NETWORK_INBOUND_MESSAGES_TOTAL: &'static str =
        "whitelist_preconf_driver_network_inbound_messages_total";
    /// Counter tracking decode failures by topic.
    pub const NETWORK_DECODE_FAILURES_TOTAL: &'static str =
        "whitelist_preconf_driver_network_decode_failures_total";
    /// Counter tracking outbound publish commands by topic and result.
    pub const NETWORK_OUTBOUND_PUBLISH_TOTAL: &'static str =
        "whitelist_preconf_driver_network_outbound_publish_total";
    /// Counter tracking dial attempts by source.
    pub const NETWORK_DIAL_ATTEMPTS_TOTAL: &'static str =
        "whitelist_preconf_driver_network_dial_attempts_total";
    /// Counter tracking dial failures by source.
    pub const NETWORK_DIAL_FAILURES_TOTAL: &'static str =
        "whitelist_preconf_driver_network_dial_failures_total";
    /// Counter tracking event-forward failures into importer queue.
    pub const NETWORK_FORWARD_FAILURES_TOTAL: &'static str =
        "whitelist_preconf_driver_network_forward_failures_total";

    // Importer metrics
    /// Counter tracking importer event handling by event type and result.
    pub const IMPORTER_EVENTS_TOTAL: &'static str =
        "whitelist_preconf_driver_importer_events_total";
    /// Counter tracking validation failures by stage.
    pub const VALIDATION_FAILURES_TOTAL: &'static str =
        "whitelist_preconf_driver_validation_failures_total";
    /// Counter tracking whitelist contract lookup failures.
    pub const WHITELIST_LOOKUP_FAILURES_TOTAL: &'static str =
        "whitelist_preconf_driver_whitelist_lookup_failures_total";
    /// Counter tracking request-response lookup outcomes.
    pub const RESPONSE_LOOKUPS_TOTAL: &'static str =
        "whitelist_preconf_driver_response_lookups_total";
    /// Counter tracking cache import attempts.
    pub const CACHE_IMPORT_ATTEMPTS_TOTAL: &'static str =
        "whitelist_preconf_driver_cache_import_attempts_total";
    /// Counter tracking cache import outcomes.
    pub const CACHE_IMPORT_RESULTS_TOTAL: &'static str =
        "whitelist_preconf_driver_cache_import_results_total";
    /// Counter tracking driver submit outcomes.
    pub const DRIVER_SUBMIT_TOTAL: &'static str = "whitelist_preconf_driver_driver_submit_total";
    /// Histogram tracking duration of driver submission path.
    pub const DRIVER_SUBMIT_DURATION_SECONDS: &'static str =
        "whitelist_preconf_driver_driver_submit_duration_seconds";
    /// Counter tracking parent request outcomes (issued/throttled).
    pub const PARENT_REQUESTS_TOTAL: &'static str =
        "whitelist_preconf_driver_parent_requests_total";

    // RPC metrics
    /// Counter tracking total RPC requests by method.
    pub const RPC_REQUESTS_TOTAL: &'static str = "whitelist_preconf_driver_rpc_requests_total";
    /// Counter tracking total RPC errors by method.
    pub const RPC_ERRORS_TOTAL: &'static str = "whitelist_preconf_driver_rpc_errors_total";
    /// Histogram tracking RPC request duration by method.
    pub const RPC_DURATION_SECONDS: &'static str = "whitelist_preconf_driver_rpc_duration_seconds";
    /// Histogram tracking build_preconf_block request duration.
    pub const BUILD_PRECONF_BLOCK_DURATION_SECONDS: &'static str =
        "whitelist_preconf_driver_build_preconf_block_duration_seconds";

    // Cache gauges
    /// Gauge tracking pending cache size.
    pub const CACHE_PENDING_COUNT: &'static str = "whitelist_preconf_driver_cache_pending_count";
    /// Gauge tracking recent cache size.
    pub const CACHE_RECENT_COUNT: &'static str = "whitelist_preconf_driver_cache_recent_count";

    /// Register metric descriptors and initialise counters/gauges.
    pub fn init() {
        metrics::describe_counter!(Self::RUNNER_START_TOTAL, Unit::Count, "Runner start count");
        metrics::describe_counter!(
            Self::RUNNER_EXIT_TOTAL,
            Unit::Count,
            "Runner exits grouped by reason"
        );
        metrics::describe_histogram!(
            Self::EVENT_SYNC_WAIT_DURATION_SECONDS,
            Unit::Seconds,
            "Time spent waiting for preconfirmation ingress readiness"
        );
        metrics::describe_counter!(
            Self::SYNC_READY_TRANSITIONS_TOTAL,
            Unit::Count,
            "Number of sync-ready state transitions"
        );
        metrics::describe_counter!(
            Self::SYNC_READY_IMPORT_FAILURES_TOTAL,
            Unit::Count,
            "Sync-ready triggered cache import failures"
        );

        metrics::describe_counter!(
            Self::NETWORK_INBOUND_MESSAGES_TOTAL,
            Unit::Count,
            "Inbound network messages by topic and decode result"
        );
        metrics::describe_counter!(
            Self::NETWORK_DECODE_FAILURES_TOTAL,
            Unit::Count,
            "Network decode failures by topic"
        );
        metrics::describe_counter!(
            Self::NETWORK_OUTBOUND_PUBLISH_TOTAL,
            Unit::Count,
            "Outbound publish command outcomes by topic"
        );
        metrics::describe_counter!(
            Self::NETWORK_DIAL_ATTEMPTS_TOTAL,
            Unit::Count,
            "Dial attempts by source"
        );
        metrics::describe_counter!(
            Self::NETWORK_DIAL_FAILURES_TOTAL,
            Unit::Count,
            "Dial failures by source"
        );
        metrics::describe_counter!(
            Self::NETWORK_FORWARD_FAILURES_TOTAL,
            Unit::Count,
            "Failures forwarding network events to importer"
        );

        metrics::describe_counter!(
            Self::IMPORTER_EVENTS_TOTAL,
            Unit::Count,
            "Importer event handling outcomes"
        );
        metrics::describe_counter!(
            Self::VALIDATION_FAILURES_TOTAL,
            Unit::Count,
            "Payload/response validation failures"
        );
        metrics::describe_counter!(
            Self::WHITELIST_LOOKUP_FAILURES_TOTAL,
            Unit::Count,
            "Whitelist contract lookup failures"
        );
        metrics::describe_counter!(
            Self::RESPONSE_LOOKUPS_TOTAL,
            Unit::Count,
            "Unsafe request lookup outcomes"
        );
        metrics::describe_counter!(
            Self::CACHE_IMPORT_ATTEMPTS_TOTAL,
            Unit::Count,
            "Cache import attempts"
        );
        metrics::describe_counter!(
            Self::CACHE_IMPORT_RESULTS_TOTAL,
            Unit::Count,
            "Cache import results"
        );
        metrics::describe_counter!(
            Self::DRIVER_SUBMIT_TOTAL,
            Unit::Count,
            "Driver submission outcomes"
        );
        metrics::describe_histogram!(
            Self::DRIVER_SUBMIT_DURATION_SECONDS,
            Unit::Seconds,
            "Duration for driver submission path"
        );
        metrics::describe_counter!(
            Self::PARENT_REQUESTS_TOTAL,
            Unit::Count,
            "Parent request outcomes"
        );

        metrics::describe_counter!(
            Self::RPC_REQUESTS_TOTAL,
            Unit::Count,
            "Total whitelist RPC requests by method"
        );
        metrics::describe_counter!(
            Self::RPC_ERRORS_TOTAL,
            Unit::Count,
            "Total whitelist RPC errors by method"
        );
        metrics::describe_histogram!(
            Self::RPC_DURATION_SECONDS,
            Unit::Seconds,
            "Whitelist RPC request duration by method"
        );
        metrics::describe_histogram!(
            Self::BUILD_PRECONF_BLOCK_DURATION_SECONDS,
            Unit::Seconds,
            "Duration for build_preconf_block RPC calls"
        );

        metrics::describe_gauge!(Self::CACHE_PENDING_COUNT, Unit::Count, "Pending cache size");
        metrics::describe_gauge!(Self::CACHE_RECENT_COUNT, Unit::Count, "Recent cache size");

        metrics::counter!(Self::RUNNER_START_TOTAL).absolute(0);
        metrics::counter!(Self::RUNNER_EXIT_TOTAL).absolute(0);
        metrics::counter!(Self::SYNC_READY_TRANSITIONS_TOTAL).absolute(0);
        metrics::counter!(Self::SYNC_READY_IMPORT_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::NETWORK_INBOUND_MESSAGES_TOTAL).absolute(0);
        metrics::counter!(Self::NETWORK_DECODE_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::NETWORK_OUTBOUND_PUBLISH_TOTAL).absolute(0);
        metrics::counter!(Self::NETWORK_DIAL_ATTEMPTS_TOTAL).absolute(0);
        metrics::counter!(Self::NETWORK_DIAL_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::NETWORK_FORWARD_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::IMPORTER_EVENTS_TOTAL).absolute(0);
        metrics::counter!(Self::VALIDATION_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::WHITELIST_LOOKUP_FAILURES_TOTAL).absolute(0);
        metrics::counter!(Self::RESPONSE_LOOKUPS_TOTAL).absolute(0);
        metrics::counter!(Self::CACHE_IMPORT_ATTEMPTS_TOTAL).absolute(0);
        metrics::counter!(Self::CACHE_IMPORT_RESULTS_TOTAL).absolute(0);
        metrics::counter!(Self::DRIVER_SUBMIT_TOTAL).absolute(0);
        metrics::counter!(Self::PARENT_REQUESTS_TOTAL).absolute(0);
        metrics::counter!(Self::RPC_REQUESTS_TOTAL).absolute(0);
        metrics::counter!(Self::RPC_ERRORS_TOTAL).absolute(0);

        metrics::gauge!(Self::CACHE_PENDING_COUNT).set(0.0);
        metrics::gauge!(Self::CACHE_RECENT_COUNT).set(0.0);
    }
}

#[cfg(test)]
mod tests {
    use super::WhitelistPreconfirmationDriverMetrics;

    #[test]
    fn metric_constants_have_expected_prefix() {
        let names = [
            WhitelistPreconfirmationDriverMetrics::RUNNER_START_TOTAL,
            WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
            WhitelistPreconfirmationDriverMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS,
            WhitelistPreconfirmationDriverMetrics::SYNC_READY_TRANSITIONS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::SYNC_READY_IMPORT_FAILURES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_DECODE_FAILURES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_ATTEMPTS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_FAILURES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_FORWARD_FAILURES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_ATTEMPTS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::DRIVER_SUBMIT_TOTAL,
            WhitelistPreconfirmationDriverMetrics::DRIVER_SUBMIT_DURATION_SECONDS,
            WhitelistPreconfirmationDriverMetrics::PARENT_REQUESTS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::RPC_REQUESTS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::RPC_ERRORS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::RPC_DURATION_SECONDS,
            WhitelistPreconfirmationDriverMetrics::BUILD_PRECONF_BLOCK_DURATION_SECONDS,
            WhitelistPreconfirmationDriverMetrics::CACHE_PENDING_COUNT,
            WhitelistPreconfirmationDriverMetrics::CACHE_RECENT_COUNT,
        ];

        assert!(names.into_iter().all(|name| name.starts_with("whitelist_preconf_driver_")));
    }

    #[test]
    fn init_does_not_panic() {
        WhitelistPreconfirmationDriverMetrics::init();
    }
}
