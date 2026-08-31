//! Prometheus metrics for tracking proposer.

use base_tx_manager::TxMetrics;
use once_cell::sync::Lazy;
use prometheus::{Gauge, Histogram, IntCounter};
use protocol::metrics::{counter, gauge, histogram};

/// Histogram buckets for gas-count observations.
const GAS_BUCKETS: &[f64] = &[
    10_000.0,
    25_000.0,
    50_000.0,
    100_000.0,
    200_000.0,
    500_000.0,
    1_000_000.0,
    2_500_000.0,
    5_000_000.0,
    10_000_000.0,
];

/// Histogram buckets for fee observations expressed in gwei.
const GWEI_BUCKETS: &[f64] =
    &[1.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1_000.0, 5_000.0, 10_000.0];

/// Histogram buckets for transaction-manager send latency expressed in milliseconds.
const LATENCY_MILLISECONDS_BUCKETS: &[f64] =
    &[1.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1_000.0, 5_000.0, 10_000.0];

/// Metric namespace and direct Prometheus handles emitted by the proposer service.
#[derive(Debug, Clone)]
pub struct ProposerMetrics;

impl ProposerMetrics {
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
///
/// The proposer runs exactly one transaction manager, so the collectors are
/// plain scalars rather than `name`-labelled families.
#[derive(Debug, Clone)]
pub(crate) struct ProposerTxMetrics;

impl ProposerTxMetrics {
    /// Create a direct Prometheus metrics adapter for the transaction manager.
    pub(crate) fn new() -> Self {
        Lazy::force(&TX_MANAGER_METRICS);
        Self
    }
}

impl TxMetrics for ProposerTxMetrics {
    /// Record the maximum possible transaction fee in gwei.
    fn record_tx_max_fee(&self, fee_gwei: f64) {
        TX_MANAGER_METRICS.tx_max_fee_gwei.observe(fee_gwei);
    }

    /// Record one gas-bump event.
    fn record_gas_bump(&self) {
        TX_MANAGER_METRICS.tx_gas_bump_count.inc();
    }

    /// Record send-loop latency in milliseconds.
    fn record_send_latency(&self, latency_ms: u64) {
        TX_MANAGER_METRICS.tx_send_latency_ms.observe(latency_ms as f64);
    }

    /// Record the current transaction nonce.
    fn record_current_nonce(&self, nonce: u64) {
        TX_MANAGER_METRICS.current_nonce.set(nonce as f64);
    }

    /// Record one transaction publish error.
    fn record_publish_error(&self) {
        TX_MANAGER_METRICS.tx_publish_error_count.inc();
    }

    /// Record the current base fee in gwei.
    fn record_basefee(&self, basefee_gwei: f64) {
        TX_MANAGER_METRICS.basefee_gwei.set(basefee_gwei);
    }

    /// Record the current tip cap in gwei.
    fn record_tipcap(&self, tipcap_gwei: f64) {
        TX_MANAGER_METRICS.tipcap_gwei.set(tipcap_gwei);
    }

    /// Record the current blob fee cap in gwei.
    fn record_blob_fee(&self, blob_fee_gwei: f64) {
        TX_MANAGER_METRICS.blob_fee_gwei.set(blob_fee_gwei);
    }

    /// Record one RPC error.
    fn record_rpc_error(&self) {
        TX_MANAGER_METRICS.rpc_error_count.inc();
    }

    /// Record one confirmed transaction.
    fn record_tx_confirmed(&self) {
        TX_MANAGER_METRICS.tx_confirmed_count.inc();
    }

    /// Record one failed send attempt.
    fn record_tx_failed(&self) {
        TX_MANAGER_METRICS.tx_failed_count.inc();
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
                "taiko_proposer_tx_pool_size",
                "Size of the transaction pool fetched from L2 execution engine",
            ),
            proposals_sent: counter(
                "taiko_proposer_proposals_sent",
                "Total number of proposals sent to L1",
            ),
            proposals_success: counter(
                "taiko_proposer_proposals_success",
                "Number of successfully mined proposals",
            ),
            proposals_failed: counter(
                "taiko_proposer_proposals_failed",
                "Number of failed proposals",
            ),
            gas_used: histogram(
                "taiko_proposer_gas_used",
                "Gas used by successful proposals",
                GAS_BUCKETS,
            ),
        }
    }
}

/// Typed direct-Prometheus collectors for the base tx-manager metric contract.
struct ProposerTxMetricHandles {
    /// Maximum possible transaction fee in gwei.
    tx_max_fee_gwei: Histogram,
    /// Number of gas bump events.
    tx_gas_bump_count: IntCounter,
    /// Send-loop latency in milliseconds.
    tx_send_latency_ms: Histogram,
    /// Current nonce value.
    current_nonce: Gauge,
    /// Transaction publish error count.
    tx_publish_error_count: IntCounter,
    /// Base fee in gwei.
    basefee_gwei: Gauge,
    /// Tip cap in gwei.
    tipcap_gwei: Gauge,
    /// Blob fee cap in gwei.
    blob_fee_gwei: Gauge,
    /// RPC error count.
    rpc_error_count: IntCounter,
    /// Confirmed transaction count.
    tx_confirmed_count: IntCounter,
    /// Failed transaction count.
    tx_failed_count: IntCounter,
}

impl ProposerTxMetricHandles {
    /// Construct and register all tx-manager collectors.
    fn new() -> Self {
        Self {
            tx_max_fee_gwei: histogram(
                "base_tx_manager_tx_max_fee_gwei",
                "Maximum possible transaction fee in gwei (gas_limit * fee_cap)",
                GWEI_BUCKETS,
            ),
            tx_gas_bump_count: counter(
                "base_tx_manager_tx_gas_bump_count",
                "Number of gas bump events",
            ),
            tx_send_latency_ms: histogram(
                "base_tx_manager_tx_send_latency_ms",
                "Send-loop latency in milliseconds",
                LATENCY_MILLISECONDS_BUCKETS,
            ),
            current_nonce: gauge("base_tx_manager_current_nonce", "Current nonce value"),
            tx_publish_error_count: counter(
                "base_tx_manager_tx_publish_error_count",
                "Number of transaction publish errors",
            ),
            basefee_gwei: gauge("base_tx_manager_basefee_gwei", "Base fee in gwei"),
            tipcap_gwei: gauge("base_tx_manager_tipcap_gwei", "Tip cap in gwei"),
            blob_fee_gwei: gauge("base_tx_manager_blob_fee_gwei", "Blob fee cap in gwei"),
            rpc_error_count: counter("base_tx_manager_rpc_error_count", "Number of RPC errors"),
            tx_confirmed_count: counter(
                "base_tx_manager_tx_confirmed_count",
                "Number of confirmed transactions",
            ),
            tx_failed_count: counter(
                "base_tx_manager_tx_failed_count",
                "Number of failed send attempts (includes timeouts where the tx may still confirm)",
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use base_tx_manager::TxMetrics;

    use super::{ProposerMetrics, ProposerTxMetrics};

    #[test]
    fn tx_manager_metrics_are_registered_with_direct_prometheus_registry() {
        ProposerMetrics::init();
        let metrics = ProposerTxMetrics::new();

        metrics.record_gas_bump();

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| family.get_name() == "base_tx_manager_tx_gas_bump_count")
            .expect("tx-manager gas bump counter should be exported");
        let metric =
            family.get_metric().first().expect("tx-manager gas bump counter should have a metric");

        assert!(metric.get_counter().get_value() >= 1.0);
    }

    #[test]
    fn gas_used_histogram_has_gas_scale_buckets() {
        ProposerMetrics::init();

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| family.get_name() == "taiko_proposer_gas_used")
            .expect("gas-used histogram should be exported");
        let metric = family.get_metric().first().expect("gas-used histogram should have a metric");

        assert!(
            metric
                .get_histogram()
                .get_bucket()
                .iter()
                .any(|bucket| bucket.get_upper_bound() >= 30_000.0),
            "gas-used histogram should include buckets large enough for proposal gas"
        );
    }
}
