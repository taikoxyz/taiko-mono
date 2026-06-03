//! Prometheus metrics for tracking proposer.

use base_tx_manager::TxMetrics;
use once_cell::sync::Lazy;
use prometheus::{
    Gauge, GaugeVec, Histogram, HistogramVec, IntCounter, IntCounterVec, Opts, core::Collector,
};

/// Metric keys and direct Prometheus handles emitted by the proposer service.
#[derive(Debug, Clone)]
pub struct ProposerMetrics;

impl ProposerMetrics {
    /// Gauge tracking the size of the transaction pool fetched from L2.
    pub const TX_POOL_SIZE: &'static str = "taiko_proposer_tx_pool_size";
    /// Counter for the total number of proposals sent to L1.
    pub const PROPOSALS_SENT: &'static str = "taiko_proposer_proposals_sent";
    /// Counter for the number of successfully mined proposals.
    pub const PROPOSALS_SUCCESS: &'static str = "taiko_proposer_proposals_success";
    /// Counter for the number of failed proposals.
    pub const PROPOSALS_FAILED: &'static str = "taiko_proposer_proposals_failed";
    /// Histogram tracking the gas used by successful proposals.
    pub const GAS_USED: &'static str = "taiko_proposer_gas_used";

    /// Register direct Prometheus collectors.
    pub fn init() {
        Lazy::force(&METRICS);
    }

    /// Return the transaction-pool size gauge.
    pub(crate) fn tx_pool_size() -> &'static Gauge {
        &METRICS.tx_pool_size
    }

    /// Return the proposals-sent counter.
    pub(crate) fn proposals_sent() -> &'static IntCounter {
        &METRICS.proposals_sent
    }

    /// Return the successful-proposals counter.
    pub(crate) fn proposals_success() -> &'static IntCounter {
        &METRICS.proposals_success
    }

    /// Return the failed-proposals counter.
    pub(crate) fn proposals_failed() -> &'static IntCounter {
        &METRICS.proposals_failed
    }

    /// Return the gas-used histogram.
    pub(crate) fn gas_used() -> &'static Histogram {
        &METRICS.gas_used
    }
}

/// Direct Prometheus metrics adapter for the base transaction manager.
#[derive(Debug, Clone)]
pub(crate) struct ProposerTxMetrics {
    /// Label value identifying this transaction-manager instance.
    name: &'static str,
}

impl ProposerTxMetrics {
    /// Create a direct Prometheus metrics adapter for one transaction-manager instance.
    pub(crate) fn new(name: &'static str) -> Self {
        Lazy::force(&TX_MANAGER_METRICS);
        Self { name }
    }
}

impl TxMetrics for ProposerTxMetrics {
    /// Record the maximum possible transaction fee in gwei.
    fn record_tx_max_fee(&self, fee_gwei: f64) {
        TX_MANAGER_METRICS.tx_max_fee_gwei.with_label_values(&[self.name]).observe(fee_gwei);
    }

    /// Record one gas-bump event.
    fn record_gas_bump(&self) {
        TX_MANAGER_METRICS.tx_gas_bump_count.with_label_values(&[self.name]).inc();
    }

    /// Record send-loop latency in milliseconds.
    fn record_send_latency(&self, latency_ms: u64) {
        TX_MANAGER_METRICS
            .tx_send_latency_ms
            .with_label_values(&[self.name])
            .observe(latency_ms as f64);
    }

    /// Record the current transaction nonce.
    fn record_current_nonce(&self, nonce: u64) {
        TX_MANAGER_METRICS.current_nonce.with_label_values(&[self.name]).set(nonce as f64);
    }

    /// Record one transaction publish error.
    fn record_publish_error(&self) {
        TX_MANAGER_METRICS.tx_publish_error_count.with_label_values(&[self.name]).inc();
    }

    /// Record the current base fee in gwei.
    fn record_basefee(&self, basefee_gwei: f64) {
        TX_MANAGER_METRICS.basefee_gwei.with_label_values(&[self.name]).set(basefee_gwei);
    }

    /// Record the current tip cap in gwei.
    fn record_tipcap(&self, tipcap_gwei: f64) {
        TX_MANAGER_METRICS.tipcap_gwei.with_label_values(&[self.name]).set(tipcap_gwei);
    }

    /// Record the current blob fee cap in gwei.
    fn record_blob_fee(&self, blob_fee_gwei: f64) {
        TX_MANAGER_METRICS.blob_fee_gwei.with_label_values(&[self.name]).set(blob_fee_gwei);
    }

    /// Record one RPC error.
    fn record_rpc_error(&self) {
        TX_MANAGER_METRICS.rpc_error_count.with_label_values(&[self.name]).inc();
    }

    /// Record one confirmed transaction.
    fn record_tx_confirmed(&self) {
        TX_MANAGER_METRICS.tx_confirmed_count.with_label_values(&[self.name]).inc();
    }

    /// Record one failed send attempt.
    fn record_tx_failed(&self) {
        TX_MANAGER_METRICS.tx_failed_count.with_label_values(&[self.name]).inc();
    }
}

/// Direct Prometheus collector handles used by the proposer.
static METRICS: Lazy<ProposerMetricHandles> = Lazy::new(ProposerMetricHandles::new);

/// Direct Prometheus collector handles used by the tx-manager adapter.
static TX_MANAGER_METRICS: Lazy<ProposerTxMetricHandles> = Lazy::new(ProposerTxMetricHandles::new);

/// Typed direct-Prometheus collectors owned by the proposer crate.
struct ProposerMetricHandles {
    /// Current transaction-pool size.
    tx_pool_size: Gauge,
    /// Total number of proposal submission attempts.
    proposals_sent: IntCounter,
    /// Total number of successful proposals.
    proposals_success: IntCounter,
    /// Total number of failed proposals.
    proposals_failed: IntCounter,
    /// Gas consumed by successful proposals.
    gas_used: Histogram,
}

impl ProposerMetricHandles {
    /// Construct and register all proposer collectors.
    fn new() -> Self {
        Self {
            tx_pool_size: gauge(
                ProposerMetrics::TX_POOL_SIZE,
                "Size of the transaction pool fetched from L2 execution engine",
            ),
            proposals_sent: counter(
                ProposerMetrics::PROPOSALS_SENT,
                "Total number of proposals sent to L1",
            ),
            proposals_success: counter(
                ProposerMetrics::PROPOSALS_SUCCESS,
                "Number of successfully mined proposals",
            ),
            proposals_failed: counter(
                ProposerMetrics::PROPOSALS_FAILED,
                "Number of failed proposals",
            ),
            gas_used: histogram(ProposerMetrics::GAS_USED, "Gas used by successful proposals"),
        }
    }
}

/// Typed direct-Prometheus collectors for the base tx-manager metric contract.
struct ProposerTxMetricHandles {
    /// Maximum possible transaction fee in gwei.
    tx_max_fee_gwei: HistogramVec,
    /// Number of gas bump events.
    tx_gas_bump_count: IntCounterVec,
    /// Send-loop latency in milliseconds.
    tx_send_latency_ms: HistogramVec,
    /// Current nonce value.
    current_nonce: GaugeVec,
    /// Transaction publish error count.
    tx_publish_error_count: IntCounterVec,
    /// Base fee in gwei.
    basefee_gwei: GaugeVec,
    /// Tip cap in gwei.
    tipcap_gwei: GaugeVec,
    /// Blob fee cap in gwei.
    blob_fee_gwei: GaugeVec,
    /// RPC error count.
    rpc_error_count: IntCounterVec,
    /// Confirmed transaction count.
    tx_confirmed_count: IntCounterVec,
    /// Failed transaction count.
    tx_failed_count: IntCounterVec,
}

impl ProposerTxMetricHandles {
    /// Construct and register all tx-manager collectors.
    fn new() -> Self {
        Self {
            tx_max_fee_gwei: histogram_vec(
                "base_tx_manager_tx_max_fee_gwei",
                "Maximum possible transaction fee in gwei (gas_limit * fee_cap)",
            ),
            tx_gas_bump_count: counter_vec(
                "base_tx_manager_tx_gas_bump_count",
                "Number of gas bump events",
            ),
            tx_send_latency_ms: histogram_vec(
                "base_tx_manager_tx_send_latency_ms",
                "Send-loop latency in milliseconds",
            ),
            current_nonce: gauge_vec("base_tx_manager_current_nonce", "Current nonce value"),
            tx_publish_error_count: counter_vec(
                "base_tx_manager_tx_publish_error_count",
                "Number of transaction publish errors",
            ),
            basefee_gwei: gauge_vec("base_tx_manager_basefee_gwei", "Base fee in gwei"),
            tipcap_gwei: gauge_vec("base_tx_manager_tipcap_gwei", "Tip cap in gwei"),
            blob_fee_gwei: gauge_vec("base_tx_manager_blob_fee_gwei", "Blob fee cap in gwei"),
            rpc_error_count: counter_vec("base_tx_manager_rpc_error_count", "Number of RPC errors"),
            tx_confirmed_count: counter_vec(
                "base_tx_manager_tx_confirmed_count",
                "Number of confirmed transactions",
            ),
            tx_failed_count: counter_vec(
                "base_tx_manager_tx_failed_count",
                "Number of failed send attempts (includes timeouts where the tx may still confirm)",
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

/// Construct and register an integer counter vector grouped by tx-manager instance name.
fn counter_vec(name: &'static str, help: &'static str) -> IntCounterVec {
    let metric = IntCounterVec::new(Opts::new(name, help), &["name"]).unwrap_or_else(|error| {
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

/// Construct and register a gauge vector grouped by tx-manager instance name.
fn gauge_vec(name: &'static str, help: &'static str) -> GaugeVec {
    let metric = GaugeVec::new(Opts::new(name, help), &["name"])
        .unwrap_or_else(|error| panic!("failed to create Prometheus gauge vector {name}: {error}"));
    register(metric.clone());
    metric
}

/// Construct and register a histogram.
fn histogram(name: &'static str, help: &'static str) -> Histogram {
    let metric = Histogram::with_opts(prometheus::HistogramOpts::new(name, help))
        .unwrap_or_else(|error| panic!("failed to create Prometheus histogram {name}: {error}"));
    register(metric.clone());
    metric
}

/// Construct and register a histogram vector grouped by tx-manager instance name.
fn histogram_vec(name: &'static str, help: &'static str) -> HistogramVec {
    let metric = HistogramVec::new(prometheus::HistogramOpts::new(name, help), &["name"])
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

#[cfg(test)]
mod tests {
    use base_tx_manager::TxMetrics;

    use super::{ProposerMetrics, ProposerTxMetrics};

    #[test]
    fn tx_manager_metrics_are_registered_with_direct_prometheus_registry() {
        ProposerMetrics::init();
        let metrics = ProposerTxMetrics::new("proposer_test");

        metrics.record_gas_bump();

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| family.get_name() == "base_tx_manager_tx_gas_bump_count")
            .expect("tx-manager gas bump counter should be exported");

        let metric = family
            .get_metric()
            .iter()
            .find(|metric| {
                metric
                    .get_label()
                    .iter()
                    .any(|label| label.get_name() == "name" && label.get_value() == "proposer_test")
            })
            .expect("tx-manager gas bump counter should include proposer label");

        assert_eq!(metric.get_counter().get_value(), 1.0);
    }
}
