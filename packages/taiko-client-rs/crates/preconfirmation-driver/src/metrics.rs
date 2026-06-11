//! Metrics exposed by the preconfirmation client.

use once_cell::sync::Lazy;
use prometheus::{
    Gauge, Histogram, HistogramVec, IntCounter, IntCounterVec, Opts, core::Collector,
};

/// Histogram buckets for operation durations expressed in seconds.
const DURATION_SECONDS_BUCKETS: &[f64] =
    &[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0];

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
        &METRICS.catchup_duration_seconds
    }

    /// Return the synced state transition counter.
    pub(crate) fn synced_total() -> &'static IntCounter {
        &METRICS.synced_total
    }

    /// Return the received commitments counter.
    pub(crate) fn commitments_received_total() -> &'static IntCounter {
        &METRICS.commitments_received_total
    }

    /// Return the received txlists counter.
    pub(crate) fn txlists_received_total() -> &'static IntCounter {
        &METRICS.txlists_received_total
    }

    /// Return the validation failure counter.
    pub(crate) fn validation_failures_total() -> &'static IntCounter {
        &METRICS.validation_failures_total
    }

    /// Return the successful driver submission counter.
    pub(crate) fn driver_submit_success_total() -> &'static IntCounter {
        &METRICS.driver_submit_success_total
    }

    /// Return the failed driver submission counter.
    pub(crate) fn driver_submit_failure_total() -> &'static IntCounter {
        &METRICS.driver_submit_failure_total
    }

    /// Return the head block gauge.
    pub(crate) fn head_block() -> &'static Gauge {
        &METRICS.head_block
    }

    /// Return the awaiting-txlist depth gauge.
    pub(crate) fn awaiting_txlist_depth() -> &'static Gauge {
        &METRICS.awaiting_txlist_depth
    }

    /// Return the catchup batch counter.
    pub(crate) fn catchup_batches_total() -> &'static IntCounter {
        &METRICS.catchup_batches_total
    }

    /// Return the catchup error counter.
    pub(crate) fn catchup_errors_total() -> &'static IntCounter {
        &METRICS.catchup_errors_total
    }

    /// Return the stored commitment count gauge.
    pub(crate) fn store_commitments_count() -> &'static Gauge {
        &METRICS.store_commitments_count
    }

    /// Return the stored txlist count gauge.
    pub(crate) fn store_txlists_count() -> &'static Gauge {
        &METRICS.store_txlists_count
    }

    /// Return the pending commitment count gauge.
    pub(crate) fn store_pending_commitments_count() -> &'static Gauge {
        &METRICS.store_pending_commitments_count
    }
}

/// Direct Prometheus collector handles used by the preconfirmation client.
static METRICS: Lazy<PreconfirmationMetricHandles> = Lazy::new(PreconfirmationMetricHandles::new);

/// Typed direct-Prometheus collectors owned by the preconfirmation client crate.
struct PreconfirmationMetricHandles {
    /// Number of times the client reached synced state.
    synced_total: IntCounter,
    /// Total commitments received from the P2P network.
    commitments_received_total: IntCounter,
    /// Total txlists received from the P2P network.
    txlists_received_total: IntCounter,
    /// Total validation failures for commitments or txlists.
    validation_failures_total: IntCounter,
    /// Successful submissions to the driver.
    driver_submit_success_total: IntCounter,
    /// Failed submissions to the driver.
    driver_submit_failure_total: IntCounter,
    /// Commitment batches fetched during tip catch-up.
    catchup_batches_total: IntCounter,
    /// Errors encountered during tip catch-up.
    catchup_errors_total: IntCounter,
    /// Current head block number tracked by the client.
    head_block: Gauge,
    /// Number of commitments awaiting their txlist payload.
    awaiting_txlist_depth: Gauge,
    /// Number of commitments in the store.
    store_commitments_count: Gauge,
    /// Number of txlists in the store.
    store_txlists_count: Gauge,
    /// Number of pending commitments in the store.
    store_pending_commitments_count: Gauge,
    /// Time spent performing tip catch-up.
    catchup_duration_seconds: Histogram,
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
            synced_total: counter(
                PreconfirmationClientMetrics::SYNCED_TOTAL,
                "Number of times the client reached synced state",
            ),
            commitments_received_total: counter(
                PreconfirmationClientMetrics::COMMITMENTS_RECEIVED_TOTAL,
                "Total commitments received from the P2P network",
            ),
            txlists_received_total: counter(
                PreconfirmationClientMetrics::TXLISTS_RECEIVED_TOTAL,
                "Total txlists received from the P2P network",
            ),
            validation_failures_total: counter(
                PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL,
                "Total validation failures for commitments or txlists",
            ),
            driver_submit_success_total: counter(
                PreconfirmationClientMetrics::DRIVER_SUBMIT_SUCCESS_TOTAL,
                "Successful submissions to the driver",
            ),
            driver_submit_failure_total: counter(
                PreconfirmationClientMetrics::DRIVER_SUBMIT_FAILURE_TOTAL,
                "Failed submissions to the driver",
            ),
            catchup_batches_total: counter(
                PreconfirmationClientMetrics::CATCHUP_BATCHES_TOTAL,
                "Commitment batches fetched during tip catch-up",
            ),
            catchup_errors_total: counter(
                PreconfirmationClientMetrics::CATCHUP_ERRORS_TOTAL,
                "Errors encountered during tip catch-up",
            ),
            head_block: gauge(
                PreconfirmationClientMetrics::HEAD_BLOCK,
                "Current head block number tracked by the client",
            ),
            awaiting_txlist_depth: gauge(
                PreconfirmationClientMetrics::AWAITING_TXLIST_DEPTH,
                "Number of commitments awaiting their txlist payload",
            ),
            store_commitments_count: gauge(
                PreconfirmationClientMetrics::STORE_COMMITMENTS_COUNT,
                "Number of commitments in the store",
            ),
            store_txlists_count: gauge(
                PreconfirmationClientMetrics::STORE_TXLISTS_COUNT,
                "Number of txlists in the store",
            ),
            store_pending_commitments_count: gauge(
                PreconfirmationClientMetrics::STORE_PENDING_COMMITMENTS_COUNT,
                "Number of pending commitments in the store",
            ),
            catchup_duration_seconds: histogram(
                PreconfirmationClientMetrics::CATCHUP_DURATION_SECONDS,
                "Time spent performing tip catch-up",
                DURATION_SECONDS_BUCKETS,
            ),
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
                DURATION_SECONDS_BUCKETS,
            ),
        }
    }
}

/// Construct and register an integer counter.
fn counter(name: &'static str, help: &'static str) -> IntCounter {
    let metric = IntCounter::new(name, help)
        .unwrap_or_else(|error| panic!("failed to create Prometheus counter {name}: {error}"));
    register(metric.clone());
    metric
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
fn gauge(name: &'static str, help: &'static str) -> Gauge {
    let metric = Gauge::new(name, help)
        .unwrap_or_else(|error| panic!("failed to create Prometheus gauge {name}: {error}"));
    register(metric.clone());
    metric
}

/// Construct and register a histogram.
fn histogram(name: &'static str, help: &'static str, buckets: &[f64]) -> Histogram {
    let metric =
        Histogram::with_opts(prometheus::HistogramOpts::new(name, help).buckets(buckets.to_vec()))
            .unwrap_or_else(|error| {
                panic!("failed to create Prometheus histogram {name}: {error}")
            });
    register(metric.clone());
    metric
}

/// Construct and register a histogram vector.
fn histogram_vec(
    name: &'static str,
    help: &'static str,
    labels: &[&str],
    buckets: &[f64],
) -> HistogramVec {
    let metric = HistogramVec::new(
        prometheus::HistogramOpts::new(name, help).buckets(buckets.to_vec()),
        labels,
    )
    .unwrap_or_else(|error| panic!("failed to create Prometheus histogram vector {name}: {error}"));
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
    fn duration_histograms_include_long_running_operation_buckets() {
        PreconfirmationClientMetrics::init();

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| {
                family.get_name() == PreconfirmationClientMetrics::CATCHUP_DURATION_SECONDS
            })
            .expect("catchup duration histogram should be exported");
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
}
