//! Metrics exposed by the whitelist preconfirmation driver runtime.

use once_cell::sync::Lazy;
use prometheus::{Gauge, Histogram, HistogramOpts, HistogramVec, IntCounter, IntCounterVec, Opts};

/// Histogram buckets for operation durations expressed in seconds.
const DURATION_SECONDS_BUCKETS: &[f64] =
    &[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0];

/// Process-wide whitelist preconfirmation metrics registered with Prometheus.
static METRICS: Lazy<WhitelistPreconfirmationMetricHandles> =
    Lazy::new(WhitelistPreconfirmationMetricHandles::register);

/// Typed handles for whitelist preconfirmation metric families.
struct WhitelistPreconfirmationMetricHandles {
    /// Counters without labels.
    counters: Vec<(&'static str, IntCounter)>,
    /// Counters grouped by stable label dimensions.
    counter_vecs: Vec<(&'static str, IntCounterVec)>,
    /// Gauges without labels.
    gauges: Vec<(&'static str, Gauge)>,
    /// Histograms without labels.
    histograms: Vec<(&'static str, Histogram)>,
    /// RPC request counter grouped by method.
    rpc_requests_total: IntCounterVec,
    /// RPC error counter grouped by method.
    rpc_errors_total: IntCounterVec,
    /// RPC duration histogram grouped by method.
    rpc_duration_seconds: HistogramVec,
}

impl WhitelistPreconfirmationMetricHandles {
    /// Register every whitelist preconfirmation collector with the default registry.
    fn register() -> Self {
        Self {
            counters: vec![
                counter(
                    WhitelistPreconfirmationDriverMetrics::RUNNER_START_TOTAL,
                    "Runner start count",
                ),
                counter(
                    WhitelistPreconfirmationDriverMetrics::SYNC_READY_TRANSITIONS_TOTAL,
                    "Number of sync-ready state transitions",
                ),
                counter(
                    WhitelistPreconfirmationDriverMetrics::NETWORK_FORWARD_FAILURES_TOTAL,
                    "Failures forwarding network events to importer",
                ),
                counter(
                    WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL,
                    "Whitelist contract lookup failures",
                ),
                counter(
                    WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_ATTEMPTS_TOTAL,
                    "Cache import attempts",
                ),
            ],
            counter_vecs: vec![
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
                    "Runner exits grouped by reason",
                    &["reason"],
                ),
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
                    "Inbound network messages by topic and decode result",
                    &["topic", "result"],
                ),
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                    "Outbound publish command outcomes by topic",
                    &["topic", "result"],
                ),
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_ATTEMPTS_TOTAL,
                    "Dial attempts by source and result",
                    &["source", "result"],
                ),
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                    "Importer event handling outcomes",
                    &["event_type", "result"],
                ),
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
                    "Unsafe request lookup outcomes",
                    &["result"],
                ),
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                    "Cache import results",
                    &["result"],
                ),
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::DRIVER_SUBMIT_TOTAL,
                    "Driver submission outcomes",
                    &["result"],
                ),
                counter_vec(
                    WhitelistPreconfirmationDriverMetrics::PARENT_REQUESTS_TOTAL,
                    "Parent request outcomes",
                    &["result"],
                ),
            ],
            gauges: vec![
                gauge(
                    WhitelistPreconfirmationDriverMetrics::CACHE_PENDING_COUNT,
                    "Pending cache size",
                ),
                gauge(
                    WhitelistPreconfirmationDriverMetrics::CACHE_RECENT_COUNT,
                    "Recent cache size",
                ),
            ],
            histograms: vec![
                histogram(
                    WhitelistPreconfirmationDriverMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS,
                    "Time spent waiting for preconfirmation ingress readiness",
                    DURATION_SECONDS_BUCKETS,
                ),
                histogram(
                    WhitelistPreconfirmationDriverMetrics::DRIVER_SUBMIT_DURATION_SECONDS,
                    "Duration for driver submission path",
                    DURATION_SECONDS_BUCKETS,
                ),
                histogram(
                    WhitelistPreconfirmationDriverMetrics::BUILD_PRECONF_BLOCK_DURATION_SECONDS,
                    "Duration for build_preconf_block RPC calls",
                    DURATION_SECONDS_BUCKETS,
                ),
            ],
            rpc_requests_total: counter_vec(
                WhitelistPreconfirmationDriverMetrics::RPC_REQUESTS_TOTAL,
                "Total whitelist RPC requests by method",
                &["method"],
            )
            .1,
            rpc_errors_total: counter_vec(
                WhitelistPreconfirmationDriverMetrics::RPC_ERRORS_TOTAL,
                "Total whitelist RPC errors by method",
                &["method"],
            )
            .1,
            rpc_duration_seconds: histogram_vec(
                WhitelistPreconfirmationDriverMetrics::RPC_DURATION_SECONDS,
                "Whitelist RPC request duration by method",
                &["method"],
                DURATION_SECONDS_BUCKETS,
            ),
        }
    }
}

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
    // Network metrics
    /// Counter tracking inbound gossip/request messages by topic and decode status.
    pub const NETWORK_INBOUND_MESSAGES_TOTAL: &'static str =
        "whitelist_preconf_driver_network_inbound_messages_total";
    /// Counter tracking outbound publish commands by topic and result.
    pub const NETWORK_OUTBOUND_PUBLISH_TOTAL: &'static str =
        "whitelist_preconf_driver_network_outbound_publish_total";
    /// Counter tracking dial attempts by source and result.
    pub const NETWORK_DIAL_ATTEMPTS_TOTAL: &'static str =
        "whitelist_preconf_driver_network_dial_attempts_total";
    /// Counter tracking event-forward failures into importer queue.
    pub const NETWORK_FORWARD_FAILURES_TOTAL: &'static str =
        "whitelist_preconf_driver_network_forward_failures_total";

    // Importer metrics
    /// Counter tracking importer event handling by event type and result.
    pub const IMPORTER_EVENTS_TOTAL: &'static str =
        "whitelist_preconf_driver_importer_events_total";
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

    /// Register metric collectors with the process-wide Prometheus registry.
    pub fn init() {
        Lazy::force(&METRICS);
    }

    /// Return a scalar counter by its exported metric name.
    pub(crate) fn counter(name: &'static str) -> IntCounter {
        find(&METRICS.counters, name)
    }

    /// Return a labelled counter family by its exported metric name.
    pub(crate) fn counter_vec(name: &'static str) -> IntCounterVec {
        find(&METRICS.counter_vecs, name)
    }

    /// Return a scalar gauge by its exported metric name.
    pub(crate) fn gauge(name: &'static str) -> Gauge {
        find(&METRICS.gauges, name)
    }

    /// Return a scalar histogram by its exported metric name.
    pub(crate) fn histogram(name: &'static str) -> Histogram {
        find(&METRICS.histograms, name)
    }

    /// Record one REST RPC request outcome.
    pub(crate) fn record_rpc(method: &str, failed: bool, duration_secs: f64) {
        METRICS.rpc_duration_seconds.with_label_values(&[method]).observe(duration_secs);
        METRICS.rpc_requests_total.with_label_values(&[method]).inc();
        if failed {
            METRICS.rpc_errors_total.with_label_values(&[method]).inc();
        }
    }

    /// Increment the runner start counter.
    pub(crate) fn inc_runner_start() {
        Self::counter(Self::RUNNER_START_TOTAL).inc();
    }

    /// Increment a runner exit counter for the given reason.
    pub(crate) fn inc_runner_exit(reason: &str) {
        Self::counter_vec(Self::RUNNER_EXIT_TOTAL).with_label_values(&[reason]).inc();
    }

    /// Observe time spent waiting for event-sync readiness.
    pub(crate) fn observe_event_sync_wait_duration(duration_secs: f64) {
        Self::histogram(Self::EVENT_SYNC_WAIT_DURATION_SECONDS).observe(duration_secs);
    }

    /// Increment the sync-ready transition counter.
    pub(crate) fn inc_sync_ready_transition() {
        Self::counter(Self::SYNC_READY_TRANSITIONS_TOTAL).inc();
    }

    /// Increment an inbound network message counter.
    pub(crate) fn inc_network_inbound_message(topic: &str, result: &str) {
        Self::counter_vec(Self::NETWORK_INBOUND_MESSAGES_TOTAL)
            .with_label_values(&[topic, result])
            .inc();
    }

    /// Increment an outbound network publish counter.
    pub(crate) fn inc_network_outbound_publish(topic: &str, result: &str) {
        Self::counter_vec(Self::NETWORK_OUTBOUND_PUBLISH_TOTAL)
            .with_label_values(&[topic, result])
            .inc();
    }

    /// Increment a network dial attempt counter.
    pub(crate) fn inc_network_dial_attempt(source: &str, result: &str) {
        Self::counter_vec(Self::NETWORK_DIAL_ATTEMPTS_TOTAL)
            .with_label_values(&[source, result])
            .inc();
    }

    /// Increment the network forward failure counter.
    pub(crate) fn inc_network_forward_failure() {
        Self::counter(Self::NETWORK_FORWARD_FAILURES_TOTAL).inc();
    }

    /// Increment an importer event counter.
    pub(crate) fn inc_importer_event(event_type: &str, result: &str) {
        Self::counter_vec(Self::IMPORTER_EVENTS_TOTAL)
            .with_label_values(&[event_type, result])
            .inc();
    }

    /// Increment the whitelist lookup failure counter.
    pub(crate) fn inc_whitelist_lookup_failure() {
        Self::counter(Self::WHITELIST_LOOKUP_FAILURES_TOTAL).inc();
    }

    /// Increment a response lookup counter.
    pub(crate) fn inc_response_lookup(result: &str) {
        Self::counter_vec(Self::RESPONSE_LOOKUPS_TOTAL).with_label_values(&[result]).inc();
    }

    /// Increment the cache import attempt counter.
    pub(crate) fn inc_cache_import_attempt() {
        Self::counter(Self::CACHE_IMPORT_ATTEMPTS_TOTAL).inc();
    }

    /// Increment a cache import result counter.
    pub(crate) fn inc_cache_import_result(result: &str) {
        Self::counter_vec(Self::CACHE_IMPORT_RESULTS_TOTAL).with_label_values(&[result]).inc();
    }

    /// Increment a driver submission result counter.
    pub(crate) fn inc_driver_submit(result: &str) {
        Self::counter_vec(Self::DRIVER_SUBMIT_TOTAL).with_label_values(&[result]).inc();
    }

    /// Observe driver submission duration.
    pub(crate) fn observe_driver_submit_duration(duration_secs: f64) {
        Self::histogram(Self::DRIVER_SUBMIT_DURATION_SECONDS).observe(duration_secs);
    }

    /// Increment a parent request counter.
    pub(crate) fn inc_parent_request(result: &str) {
        Self::counter_vec(Self::PARENT_REQUESTS_TOTAL).with_label_values(&[result]).inc();
    }

    /// Observe build_preconf_block duration.
    pub(crate) fn observe_build_preconf_block_duration(duration_secs: f64) {
        Self::histogram(Self::BUILD_PRECONF_BLOCK_DURATION_SECONDS).observe(duration_secs);
    }

    /// Set the pending cache gauge.
    pub(crate) fn set_cache_pending_count(count: usize) {
        Self::gauge(Self::CACHE_PENDING_COUNT).set(count as f64);
    }

    /// Set the recent cache gauge.
    pub(crate) fn set_cache_recent_count(count: usize) {
        Self::gauge(Self::CACHE_RECENT_COUNT).set(count as f64);
    }
}

/// Register a scalar counter and return it with its exported name.
fn counter(name: &'static str, help: &'static str) -> (&'static str, IntCounter) {
    let metric = IntCounter::new(name, help).expect("valid counter definition");
    prometheus::register(Box::new(metric.clone())).expect("counter registration must succeed");
    (name, metric)
}

/// Register a labelled counter family and return it with its exported name.
fn counter_vec(
    name: &'static str,
    help: &'static str,
    labels: &'static [&'static str],
) -> (&'static str, IntCounterVec) {
    let metric =
        IntCounterVec::new(Opts::new(name, help), labels).expect("valid counter definition");
    prometheus::register(Box::new(metric.clone())).expect("counter registration must succeed");
    (name, metric)
}

/// Register a scalar gauge and return it with its exported name.
fn gauge(name: &'static str, help: &'static str) -> (&'static str, Gauge) {
    let metric = Gauge::new(name, help).expect("valid gauge definition");
    prometheus::register(Box::new(metric.clone())).expect("gauge registration must succeed");
    (name, metric)
}

/// Register a scalar histogram and return it with its exported name.
fn histogram(name: &'static str, help: &'static str, buckets: &[f64]) -> (&'static str, Histogram) {
    let metric = Histogram::with_opts(HistogramOpts::new(name, help).buckets(buckets.to_vec()))
        .expect("valid histogram definition");
    prometheus::register(Box::new(metric.clone())).expect("histogram registration must succeed");
    (name, metric)
}

/// Register a labelled histogram family and return it.
fn histogram_vec(
    name: &'static str,
    help: &'static str,
    labels: &'static [&'static str],
    buckets: &[f64],
) -> HistogramVec {
    let metric =
        HistogramVec::new(HistogramOpts::new(name, help).buckets(buckets.to_vec()), labels)
            .expect("valid histogram definition");
    prometheus::register(Box::new(metric.clone())).expect("histogram registration must succeed");
    metric
}

/// Clone a registered collector by its exported metric name.
fn find<T: Clone>(metrics: &[(&'static str, T)], name: &'static str) -> T {
    metrics
        .iter()
        .find(|(metric_name, _)| *metric_name == name)
        .expect("registered metric")
        .1
        .clone()
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
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_ATTEMPTS_TOTAL,
            WhitelistPreconfirmationDriverMetrics::NETWORK_FORWARD_FAILURES_TOTAL,
            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
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

    #[test]
    fn duration_histograms_include_long_running_operation_buckets() {
        WhitelistPreconfirmationDriverMetrics::init();

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| {
                family.get_name() ==
                    WhitelistPreconfirmationDriverMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS
            })
            .expect("event-sync wait duration histogram should be exported");
        let metric = family.get_metric().first().expect("duration histogram should have a metric");

        assert!(
            metric
                .get_histogram()
                .get_bucket()
                .iter()
                .any(|bucket| bucket.get_upper_bound() >= 120.0),
            "duration histograms should retain precision above the default 10s bucket"
        );
    }

    #[test]
    fn rpc_metrics_are_recorded_with_method_label() {
        WhitelistPreconfirmationDriverMetrics::init();

        WhitelistPreconfirmationDriverMetrics::record_rpc("status", true, 0.25);

        let families = prometheus::gather();
        let requests = families
            .iter()
            .find(|family| {
                family.get_name() == WhitelistPreconfirmationDriverMetrics::RPC_REQUESTS_TOTAL
            })
            .expect("RPC request counter should be exported");
        let request_metric = requests
            .get_metric()
            .iter()
            .find(|metric| {
                metric
                    .get_label()
                    .iter()
                    .any(|label| label.get_name() == "method" && label.get_value() == "status")
            })
            .expect("RPC request counter should include method label");

        assert!(request_metric.get_counter().get_value() >= 1.0);
    }
}
