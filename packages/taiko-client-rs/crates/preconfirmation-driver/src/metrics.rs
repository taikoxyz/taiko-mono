//! Metrics exposed by the preconfirmation client.

use once_cell::sync::Lazy;
use prometheus::{Gauge, Histogram, HistogramVec, IntCounter, IntCounterVec};
use protocol::metrics::{
    DURATION_SECONDS_BUCKETS, counter, counter_vec, gauge, histogram, histogram_vec,
};

/// Metric namespace for the preconfirmation client.
pub struct PreconfirmationClientMetrics;

impl PreconfirmationClientMetrics {
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
                "preconf_client_synced_total",
                "Number of times the client reached synced state",
            ),
            commitments_received_total: counter(
                "preconf_client_commitments_received_total",
                "Total commitments received from the P2P network",
            ),
            txlists_received_total: counter(
                "preconf_client_txlists_received_total",
                "Total txlists received from the P2P network",
            ),
            validation_failures_total: counter(
                "preconf_client_validation_failures_total",
                "Total validation failures for commitments or txlists",
            ),
            driver_submit_success_total: counter(
                "preconf_client_driver_submit_success_total",
                "Successful submissions to the driver",
            ),
            driver_submit_failure_total: counter(
                "preconf_client_driver_submit_failure_total",
                "Failed submissions to the driver",
            ),
            catchup_batches_total: counter(
                "preconf_client_catchup_batches_total",
                "Commitment batches fetched during tip catch-up",
            ),
            catchup_errors_total: counter(
                "preconf_client_catchup_errors_total",
                "Errors encountered during tip catch-up",
            ),
            head_block: gauge(
                "preconf_client_head_block",
                "Current head block number tracked by the client",
            ),
            awaiting_txlist_depth: gauge(
                "preconf_client_awaiting_txlist_depth",
                "Number of commitments awaiting their txlist payload",
            ),
            store_commitments_count: gauge(
                "preconf_client_store_commitments_count",
                "Number of commitments in the store",
            ),
            store_txlists_count: gauge(
                "preconf_client_store_txlists_count",
                "Number of txlists in the store",
            ),
            store_pending_commitments_count: gauge(
                "preconf_client_store_pending_commitments_count",
                "Number of pending commitments in the store",
            ),
            catchup_duration_seconds: histogram(
                "preconf_client_catchup_duration_seconds",
                "Time spent performing tip catch-up",
                DURATION_SECONDS_BUCKETS,
            ),
            rpc_requests_total: counter_vec(
                "preconf_rpc_requests_total",
                "Total preconfirmation RPC requests by method",
                &["method"],
            ),
            rpc_errors_total: counter_vec(
                "preconf_rpc_errors_total",
                "Total preconfirmation RPC errors by method",
                &["method"],
            ),
            rpc_duration_seconds: histogram_vec(
                "preconf_rpc_duration_seconds",
                "Preconfirmation RPC request duration by method",
                &["method"],
                DURATION_SECONDS_BUCKETS,
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::PreconfirmationClientMetrics;

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
            .find(|family| family.get_name() == "preconf_client_catchup_duration_seconds")
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
