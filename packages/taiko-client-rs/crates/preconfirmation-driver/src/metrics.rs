//! Metrics exposed by the preconfirmation client.

use once_cell::sync::Lazy;
use prometheus::{
    Gauge, Histogram, HistogramVec, IntCounter, IntCounterVec, Opts, core::Collector,
};

/// Metric namespace for the preconfirmation client.
pub struct PreconfirmationClientMetrics;

impl PreconfirmationClientMetrics {
    /// Histogram tracking catchup duration in seconds.
    pub const CATCHUP_DURATION_SECONDS: &'static str = "preconf_client_catchup_duration_seconds";
    /// Counter tracking the number of times the client reached synced state.
    pub const SYNCED_TOTAL: &'static str = "preconf_client_synced_total";
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
    /// Counter tracking commitment batches fetched during catchup.
    pub const CATCHUP_BATCHES_TOTAL: &'static str = "preconf_client_catchup_batches_total";
    /// Counter tracking errors during catchup.
    pub const CATCHUP_ERRORS_TOTAL: &'static str = "preconf_client_catchup_errors_total";
    /// Gauge tracking stored commitment count.
    pub const STORE_COMMITMENTS_COUNT: &'static str = "preconf_client_store_commitments_count";
    /// Gauge tracking stored txlist count.
    pub const STORE_TXLISTS_COUNT: &'static str = "preconf_client_store_txlists_count";
    /// Gauge tracking pending commitment count.
    pub const STORE_PENDING_COMMITMENTS_COUNT: &'static str =
        "preconf_client_store_pending_commitments_count";
    /// Histogram tracking payload build duration in seconds.
    pub const PAYLOAD_BUILD_DURATION_SECONDS: &'static str =
        "preconf_client_payload_build_duration_seconds";
    /// Counter tracking payload build failures.
    pub const PAYLOAD_BUILD_FAILURES_TOTAL: &'static str =
        "preconf_client_payload_build_failures_total";
    /// Histogram tracking event sync wait duration in seconds.
    pub const EVENT_SYNC_WAIT_DURATION_SECONDS: &'static str =
        "preconf_client_event_sync_wait_duration_seconds";
    /// Counter tracking RPC requests by method.
    pub const RPC_REQUESTS_TOTAL: &'static str = "preconf_rpc_requests_total";
    /// Counter tracking RPC errors by method.
    pub const RPC_ERRORS_TOTAL: &'static str = "preconf_rpc_errors_total";
    /// Histogram tracking RPC duration by method.
    pub const RPC_DURATION_SECONDS: &'static str = "preconf_rpc_duration_seconds";

    /// Register direct Prometheus collectors.
    pub fn init() {
        Lazy::force(&METRICS);
    }

    /// Return a registered counter by its public metric name.
    pub(crate) fn counter(name: &str) -> &IntCounter {
        METRICS.counter(name)
    }

    /// Return a registered gauge by its public metric name.
    pub(crate) fn gauge(name: &str) -> &Gauge {
        METRICS.gauge(name)
    }

    /// Return a registered histogram by its public metric name.
    pub(crate) fn histogram(name: &str) -> &Histogram {
        METRICS.histogram(name)
    }

    /// Record one RPC request outcome.
    pub(crate) fn record_rpc(method: &str, failed: bool, duration_secs: f64) {
        METRICS.rpc_duration_seconds.with_label_values(&[method]).observe(duration_secs);
        METRICS.rpc_requests_total.with_label_values(&[method]).inc();
        if failed {
            METRICS.rpc_errors_total.with_label_values(&[method]).inc();
        }
    }

    /// Return the catchup duration histogram.
    pub(crate) fn catchup_duration_seconds() -> &'static Histogram {
        Self::histogram(Self::CATCHUP_DURATION_SECONDS)
    }

    /// Return the synced state transition counter.
    pub(crate) fn synced_total() -> &'static IntCounter {
        Self::counter(Self::SYNCED_TOTAL)
    }

    /// Return the received commitments counter.
    pub(crate) fn commitments_received_total() -> &'static IntCounter {
        Self::counter(Self::COMMITMENTS_RECEIVED_TOTAL)
    }

    /// Return the received txlists counter.
    pub(crate) fn txlists_received_total() -> &'static IntCounter {
        Self::counter(Self::TXLISTS_RECEIVED_TOTAL)
    }

    /// Return the validation failure counter.
    pub(crate) fn validation_failures_total() -> &'static IntCounter {
        Self::counter(Self::VALIDATION_FAILURES_TOTAL)
    }

    /// Return the successful driver submission counter.
    pub(crate) fn driver_submit_success_total() -> &'static IntCounter {
        Self::counter(Self::DRIVER_SUBMIT_SUCCESS_TOTAL)
    }

    /// Return the failed driver submission counter.
    pub(crate) fn driver_submit_failure_total() -> &'static IntCounter {
        Self::counter(Self::DRIVER_SUBMIT_FAILURE_TOTAL)
    }

    /// Return the head block gauge.
    pub(crate) fn head_block() -> &'static Gauge {
        Self::gauge(Self::HEAD_BLOCK)
    }

    /// Return the awaiting-txlist depth gauge.
    pub(crate) fn awaiting_txlist_depth() -> &'static Gauge {
        Self::gauge(Self::AWAITING_TXLIST_DEPTH)
    }

    /// Return the catchup batch counter.
    pub(crate) fn catchup_batches_total() -> &'static IntCounter {
        Self::counter(Self::CATCHUP_BATCHES_TOTAL)
    }

    /// Return the catchup error counter.
    pub(crate) fn catchup_errors_total() -> &'static IntCounter {
        Self::counter(Self::CATCHUP_ERRORS_TOTAL)
    }

    /// Return the stored commitment count gauge.
    pub(crate) fn store_commitments_count() -> &'static Gauge {
        Self::gauge(Self::STORE_COMMITMENTS_COUNT)
    }

    /// Return the stored txlist count gauge.
    pub(crate) fn store_txlists_count() -> &'static Gauge {
        Self::gauge(Self::STORE_TXLISTS_COUNT)
    }

    /// Return the pending commitment count gauge.
    pub(crate) fn store_pending_commitments_count() -> &'static Gauge {
        Self::gauge(Self::STORE_PENDING_COMMITMENTS_COUNT)
    }
}

/// Direct Prometheus collector handles used by the preconfirmation client.
static METRICS: Lazy<PreconfirmationMetricHandles> = Lazy::new(PreconfirmationMetricHandles::new);

/// Typed direct-Prometheus collectors owned by the preconfirmation client crate.
struct PreconfirmationMetricHandles {
    /// Scalar counters keyed by their stable exported names.
    counters: Vec<(&'static str, IntCounter)>,
    /// Scalar gauges keyed by their stable exported names.
    gauges: Vec<(&'static str, Gauge)>,
    /// Scalar histograms keyed by their stable exported names.
    histograms: Vec<(&'static str, Histogram)>,
    /// RPC request counter grouped by method.
    rpc_requests_total: IntCounterVec,
    /// RPC error counter grouped by method.
    rpc_errors_total: IntCounterVec,
    /// RPC duration histogram grouped by method.
    rpc_duration_seconds: HistogramVec,
}

impl PreconfirmationMetricHandles {
    /// Construct and register all preconfirmation client collectors.
    fn new() -> Self {
        Self {
            counters: vec![
                counter(
                    PreconfirmationClientMetrics::SYNCED_TOTAL,
                    "Number of times the client reached synced state",
                ),
                counter(
                    PreconfirmationClientMetrics::COMMITMENTS_RECEIVED_TOTAL,
                    "Total commitments received from the P2P network",
                ),
                counter(
                    PreconfirmationClientMetrics::TXLISTS_RECEIVED_TOTAL,
                    "Total txlists received from the P2P network",
                ),
                counter(
                    PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL,
                    "Total validation failures for commitments or txlists",
                ),
                counter(
                    PreconfirmationClientMetrics::DRIVER_SUBMIT_SUCCESS_TOTAL,
                    "Successful submissions to the driver",
                ),
                counter(
                    PreconfirmationClientMetrics::DRIVER_SUBMIT_FAILURE_TOTAL,
                    "Failed submissions to the driver",
                ),
                counter(
                    PreconfirmationClientMetrics::CATCHUP_BATCHES_TOTAL,
                    "Commitment batches fetched during tip catch-up",
                ),
                counter(
                    PreconfirmationClientMetrics::CATCHUP_ERRORS_TOTAL,
                    "Errors encountered during tip catch-up",
                ),
                counter(
                    PreconfirmationClientMetrics::PAYLOAD_BUILD_FAILURES_TOTAL,
                    "Total payload build failures",
                ),
            ],
            gauges: vec![
                gauge(
                    PreconfirmationClientMetrics::HEAD_BLOCK,
                    "Current head block number tracked by the client",
                ),
                gauge(
                    PreconfirmationClientMetrics::AWAITING_TXLIST_DEPTH,
                    "Number of commitments awaiting their txlist payload",
                ),
                gauge(
                    PreconfirmationClientMetrics::STORE_COMMITMENTS_COUNT,
                    "Number of commitments in the store",
                ),
                gauge(
                    PreconfirmationClientMetrics::STORE_TXLISTS_COUNT,
                    "Number of txlists in the store",
                ),
                gauge(
                    PreconfirmationClientMetrics::STORE_PENDING_COMMITMENTS_COUNT,
                    "Number of pending commitments in the store",
                ),
            ],
            histograms: vec![
                histogram(
                    PreconfirmationClientMetrics::CATCHUP_DURATION_SECONDS,
                    "Time spent performing tip catch-up",
                ),
                histogram(
                    PreconfirmationClientMetrics::PAYLOAD_BUILD_DURATION_SECONDS,
                    "Time spent building execution payload",
                ),
                histogram(
                    PreconfirmationClientMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS,
                    "Time spent waiting for driver event sync",
                ),
            ],
            rpc_requests_total: counter_vec(
                PreconfirmationClientMetrics::RPC_REQUESTS_TOTAL,
                "Total preconfirmation RPC requests by method",
                &["method"],
            ),
            rpc_errors_total: counter_vec(
                PreconfirmationClientMetrics::RPC_ERRORS_TOTAL,
                "Total preconfirmation RPC errors by method",
                &["method"],
            ),
            rpc_duration_seconds: histogram_vec(
                PreconfirmationClientMetrics::RPC_DURATION_SECONDS,
                "Preconfirmation RPC request duration by method",
                &["method"],
            ),
        }
    }

    /// Resolve a registered counter.
    fn counter(&self, name: &str) -> &IntCounter {
        find(&self.counters, name)
    }

    /// Resolve a registered gauge.
    fn gauge(&self, name: &str) -> &Gauge {
        find(&self.gauges, name)
    }

    /// Resolve a registered histogram.
    fn histogram(&self, name: &str) -> &Histogram {
        find(&self.histograms, name)
    }
}

/// Construct and register an integer counter.
fn counter(name: &'static str, help: &'static str) -> (&'static str, IntCounter) {
    let metric = IntCounter::new(name, help)
        .unwrap_or_else(|error| panic!("failed to create Prometheus counter {name}: {error}"));
    register(metric.clone());
    (name, metric)
}

/// Construct and register an integer counter vector.
fn counter_vec(name: &'static str, help: &'static str, labels: &[&str]) -> IntCounterVec {
    let metric = IntCounterVec::new(Opts::new(name, help), labels).unwrap_or_else(|error| {
        panic!("failed to create Prometheus counter vector {name}: {error}")
    });
    register(metric.clone());
    metric
}

/// Construct and register a floating-point gauge.
fn gauge(name: &'static str, help: &'static str) -> (&'static str, Gauge) {
    let metric = Gauge::new(name, help)
        .unwrap_or_else(|error| panic!("failed to create Prometheus gauge {name}: {error}"));
    register(metric.clone());
    (name, metric)
}

/// Construct and register a histogram.
fn histogram(name: &'static str, help: &'static str) -> (&'static str, Histogram) {
    let metric = Histogram::with_opts(prometheus::HistogramOpts::new(name, help))
        .unwrap_or_else(|error| panic!("failed to create Prometheus histogram {name}: {error}"));
    register(metric.clone());
    (name, metric)
}

/// Construct and register a histogram vector.
fn histogram_vec(name: &'static str, help: &'static str, labels: &[&str]) -> HistogramVec {
    let metric = HistogramVec::new(prometheus::HistogramOpts::new(name, help), labels)
        .unwrap_or_else(|error| {
            panic!("failed to create Prometheus histogram vector {name}: {error}")
        });
    register(metric.clone());
    metric
}

/// Register one collector with the process-wide Prometheus registry.
fn register<C>(collector: C)
where
    C: Collector + Clone + 'static,
{
    prometheus::register(Box::new(collector))
        .unwrap_or_else(|error| panic!("failed to register Prometheus collector: {error}"));
}

/// Find a collector by its exported metric name.
fn find<'a, C>(collectors: &'a [(&str, C)], name: &str) -> &'a C {
    collectors
        .iter()
        .find_map(|(metric_name, collector)| (*metric_name == name).then_some(collector))
        .unwrap_or_else(|| panic!("unknown preconfirmation client metric: {name}"))
}

#[cfg(test)]
mod tests {
    use super::PreconfirmationClientMetrics;

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

    #[test]
    fn init_does_not_panic() {
        PreconfirmationClientMetrics::init();
    }

    #[test]
    fn payload_builder_metrics_have_correct_prefix() {
        assert_eq!(
            PreconfirmationClientMetrics::PAYLOAD_BUILD_DURATION_SECONDS,
            "preconf_client_payload_build_duration_seconds"
        );
        assert_eq!(
            PreconfirmationClientMetrics::PAYLOAD_BUILD_FAILURES_TOTAL,
            "preconf_client_payload_build_failures_total"
        );
    }

    #[test]
    fn event_sync_metrics_have_correct_prefix() {
        assert_eq!(
            PreconfirmationClientMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS,
            "preconf_client_event_sync_wait_duration_seconds"
        );
    }
}
