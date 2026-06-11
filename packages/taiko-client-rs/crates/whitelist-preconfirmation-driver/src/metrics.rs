//! Metrics exposed by the whitelist preconfirmation driver runtime.

use once_cell::sync::Lazy;
use prometheus::{Gauge, Histogram, HistogramOpts, HistogramVec, IntCounter, IntCounterVec, Opts};

/// Histogram buckets for operation durations expressed in seconds.
const DURATION_SECONDS_BUCKETS: &[f64] =
    &[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0];

/// Process-wide whitelist preconfirmation metrics registered with Prometheus.
static METRICS: Lazy<Metrics> = Lazy::new(Metrics::register);

/// Typed handles for whitelist preconfirmation metric families.
struct Metrics {
    /// Inbound network messages by topic and decode result.
    network_inbound_messages: IntCounterVec,
    /// Outbound publish command outcomes by topic.
    network_outbound_publish: IntCounterVec,
    /// Dial attempts by source and result.
    network_dial_attempts: IntCounterVec,
    /// Failures forwarding network events to the importer.
    network_forward_failures: IntCounter,
    /// Importer event handling outcomes by event type and result.
    importer_events: IntCounterVec,
    /// Whitelist contract lookup failures.
    whitelist_lookup_failures: IntCounter,
    /// Unsafe request lookup outcomes.
    response_lookups: IntCounterVec,
    /// Cache import results.
    cache_import_results: IntCounterVec,
    /// Duration for the driver submission path, labelled by submission result.
    driver_submit_duration: HistogramVec,
    /// Parent request outcomes.
    parent_requests: IntCounterVec,
    /// RPC error counter grouped by method.
    rpc_errors: IntCounterVec,
    /// RPC duration histogram grouped by method.
    rpc_duration: HistogramVec,
    /// Duration for `build_preconf_block` RPC calls.
    build_preconf_block_duration: Histogram,
    /// Pending cache size.
    cache_pending: Gauge,
    /// Recent cache size.
    cache_recent: Gauge,
}

impl Metrics {
    /// Register every whitelist preconfirmation collector with the default registry.
    fn register() -> Self {
        Self {
            network_inbound_messages: counter_vec(
                "whitelist_preconf_driver_network_inbound_messages_total",
                "Inbound network messages by topic and decode result",
                &["topic", "result"],
            ),
            network_outbound_publish: counter_vec(
                "whitelist_preconf_driver_network_outbound_publish_total",
                "Outbound publish command outcomes by topic",
                &["topic", "result"],
            ),
            network_dial_attempts: counter_vec(
                "whitelist_preconf_driver_network_dial_attempts_total",
                "Dial attempts by source and result",
                &["source", "result"],
            ),
            network_forward_failures: counter(
                "whitelist_preconf_driver_network_forward_failures_total",
                "Failures forwarding network events to importer",
            ),
            importer_events: counter_vec(
                "whitelist_preconf_driver_importer_events_total",
                "Importer event handling outcomes",
                &["event_type", "result"],
            ),
            whitelist_lookup_failures: counter(
                "whitelist_preconf_driver_whitelist_lookup_failures_total",
                "Whitelist contract lookup failures",
            ),
            response_lookups: counter_vec(
                "whitelist_preconf_driver_response_lookups_total",
                "Unsafe request lookup outcomes",
                &["result"],
            ),
            cache_import_results: counter_vec(
                "whitelist_preconf_driver_cache_import_results_total",
                "Cache import results",
                &["result"],
            ),
            driver_submit_duration: histogram_vec(
                "whitelist_preconf_driver_driver_submit_duration_seconds",
                "Duration for driver submission path by result",
                &["result"],
            ),
            parent_requests: counter_vec(
                "whitelist_preconf_driver_parent_requests_total",
                "Parent request outcomes",
                &["result"],
            ),
            rpc_errors: counter_vec(
                "whitelist_preconf_driver_rpc_errors_total",
                "Total whitelist RPC errors by method",
                &["method"],
            ),
            rpc_duration: histogram_vec(
                "whitelist_preconf_driver_rpc_duration_seconds",
                "Whitelist RPC request duration by method",
                &["method"],
            ),
            build_preconf_block_duration: histogram(
                "whitelist_preconf_driver_build_preconf_block_duration_seconds",
                "Duration for build_preconf_block RPC calls",
            ),
            cache_pending: gauge(
                "whitelist_preconf_driver_cache_pending_count",
                "Pending cache size",
            ),
            cache_recent: gauge("whitelist_preconf_driver_cache_recent_count", "Recent cache size"),
        }
    }
}

/// Metric namespace for the whitelist preconfirmation driver.
pub struct WhitelistPreconfirmationDriverMetrics;

impl WhitelistPreconfirmationDriverMetrics {
    /// Register metric collectors with the process-wide Prometheus registry.
    pub fn init() {
        Lazy::force(&METRICS);
    }

    /// Record one REST RPC request outcome.
    ///
    /// Request totals are derivable from the duration histogram's `_count`.
    pub(crate) fn record_rpc(method: &str, failed: bool, duration_secs: f64) {
        METRICS.rpc_duration.with_label_values(&[method]).observe(duration_secs);
        if failed {
            METRICS.rpc_errors.with_label_values(&[method]).inc();
        }
    }

    /// Increment an inbound network message counter.
    pub(crate) fn inc_network_inbound_message(topic: &str, result: &str) {
        METRICS.network_inbound_messages.with_label_values(&[topic, result]).inc();
    }

    /// Increment an outbound network publish counter.
    pub(crate) fn inc_network_outbound_publish(topic: &str, result: &str) {
        METRICS.network_outbound_publish.with_label_values(&[topic, result]).inc();
    }

    /// Increment a network dial attempt counter.
    pub(crate) fn inc_network_dial_attempt(source: &str, result: &str) {
        METRICS.network_dial_attempts.with_label_values(&[source, result]).inc();
    }

    /// Increment the network forward failure counter.
    pub(crate) fn inc_network_forward_failure() {
        METRICS.network_forward_failures.inc();
    }

    /// Increment an importer event counter.
    pub(crate) fn inc_importer_event(event_type: &str, result: &str) {
        METRICS.importer_events.with_label_values(&[event_type, result]).inc();
    }

    /// Increment the whitelist lookup failure counter.
    pub(crate) fn inc_whitelist_lookup_failure() {
        METRICS.whitelist_lookup_failures.inc();
    }

    /// Increment a response lookup counter.
    pub(crate) fn inc_response_lookup(result: &str) {
        METRICS.response_lookups.with_label_values(&[result]).inc();
    }

    /// Increment a cache import result counter.
    pub(crate) fn inc_cache_import_result(result: &str) {
        METRICS.cache_import_results.with_label_values(&[result]).inc();
    }

    /// Observe driver submission duration for the given submission result.
    pub(crate) fn observe_driver_submit(result: &str, duration_secs: f64) {
        METRICS.driver_submit_duration.with_label_values(&[result]).observe(duration_secs);
    }

    /// Increment a parent request counter.
    pub(crate) fn inc_parent_request(result: &str) {
        METRICS.parent_requests.with_label_values(&[result]).inc();
    }

    /// Observe build_preconf_block duration.
    pub(crate) fn observe_build_preconf_block_duration(duration_secs: f64) {
        METRICS.build_preconf_block_duration.observe(duration_secs);
    }

    /// Set the pending cache gauge.
    pub(crate) fn set_cache_pending_count(count: usize) {
        METRICS.cache_pending.set(count as f64);
    }

    /// Set the recent cache gauge.
    pub(crate) fn set_cache_recent_count(count: usize) {
        METRICS.cache_recent.set(count as f64);
    }
}

/// Register a scalar counter with the default registry.
fn counter(name: &str, help: &str) -> IntCounter {
    let metric = IntCounter::new(name, help).expect("valid counter definition");
    prometheus::register(Box::new(metric.clone())).expect("counter registration must succeed");
    metric
}

/// Register a labelled counter family with the default registry.
fn counter_vec(name: &str, help: &str, labels: &[&str]) -> IntCounterVec {
    let metric =
        IntCounterVec::new(Opts::new(name, help), labels).expect("valid counter definition");
    prometheus::register(Box::new(metric.clone())).expect("counter registration must succeed");
    metric
}

/// Register a scalar gauge with the default registry.
fn gauge(name: &str, help: &str) -> Gauge {
    let metric = Gauge::new(name, help).expect("valid gauge definition");
    prometheus::register(Box::new(metric.clone())).expect("gauge registration must succeed");
    metric
}

/// Register a scalar duration histogram with the default registry.
fn histogram(name: &str, help: &str) -> Histogram {
    let metric = Histogram::with_opts(
        HistogramOpts::new(name, help).buckets(DURATION_SECONDS_BUCKETS.to_vec()),
    )
    .expect("valid histogram definition");
    prometheus::register(Box::new(metric.clone())).expect("histogram registration must succeed");
    metric
}

/// Register a labelled duration histogram family with the default registry.
fn histogram_vec(name: &str, help: &str, labels: &[&str]) -> HistogramVec {
    let metric = HistogramVec::new(
        HistogramOpts::new(name, help).buckets(DURATION_SECONDS_BUCKETS.to_vec()),
        labels,
    )
    .expect("valid histogram definition");
    prometheus::register(Box::new(metric.clone())).expect("histogram registration must succeed");
    metric
}

#[cfg(test)]
mod tests {
    use super::WhitelistPreconfirmationDriverMetrics;

    #[test]
    fn init_does_not_panic() {
        WhitelistPreconfirmationDriverMetrics::init();
    }

    #[test]
    fn duration_histograms_include_long_running_operation_buckets() {
        WhitelistPreconfirmationDriverMetrics::init();
        WhitelistPreconfirmationDriverMetrics::observe_driver_submit("success", 0.1);

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| {
                family.get_name() == "whitelist_preconf_driver_driver_submit_duration_seconds"
            })
            .expect("driver submit duration histogram should be exported");
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
        let errors = families
            .iter()
            .find(|family| family.get_name() == "whitelist_preconf_driver_rpc_errors_total")
            .expect("RPC error counter should be exported");
        let error_metric = errors
            .get_metric()
            .iter()
            .find(|metric| {
                metric
                    .get_label()
                    .iter()
                    .any(|label| label.get_name() == "method" && label.get_value() == "status")
            })
            .expect("RPC error counter should include method label");

        assert!(error_metric.get_counter().get_value() >= 1.0);
    }
}
