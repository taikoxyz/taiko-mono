//! Prometheus metrics for tracking the prover.

use base_tx_manager::TxMetrics;
use once_cell::sync::Lazy;
use prometheus::{Gauge, Histogram, IntCounter};
use protocol::metrics::{counter, gauge, histogram};

/// Histogram buckets for fee observations expressed in gwei.
const GWEI_BUCKETS: &[f64] =
    &[1.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1_000.0, 5_000.0, 10_000.0];

/// Histogram buckets for transaction-manager send latency in milliseconds.
const LATENCY_MILLISECONDS_BUCKETS: &[f64] =
    &[1.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1_000.0, 5_000.0, 10_000.0];

/// Metric namespace and direct Prometheus handles emitted by the prover.
#[derive(Debug, Clone)]
pub struct ProverMetrics;

impl ProverMetrics {
    /// Register direct Prometheus collectors.
    pub fn init() {
        Lazy::force(&METRICS);
    }

    /// Latest `Proposed` event proposal id received.
    pub fn received_proposed_id() -> &'static Gauge {
        &METRICS.received_proposed_id
    }

    /// Proposals this prover decided to prove.
    pub fn proofs_assigned() -> &'static IntCounter {
        &METRICS.proofs_assigned
    }

    /// Highest L2 block id covered by a submitted proof.
    pub fn latest_proven_block_id() -> &'static Gauge {
        &METRICS.latest_proven_block_id
    }

    /// Latest finalized proposal id observed from `Proved` events.
    pub fn latest_verified_id() -> &'static Gauge {
        &METRICS.latest_verified_id
    }

    /// Proposals covered by successfully submitted aggregations.
    pub fn proofs_sent() -> &'static IntCounter {
        &METRICS.proofs_sent
    }

    /// Aggregation submissions that errored (reverted or failed to send).
    pub fn submission_errors() -> &'static IntCounter {
        &METRICS.submission_errors
    }

    /// Prove transactions the shadow mode would have submitted.
    pub fn shadow_would_submit() -> &'static IntCounter {
        &METRICS.shadow_would_submit
    }
}

/// Direct Prometheus metrics adapter for the base transaction manager.
///
/// The prover runs exactly one transaction manager, so the collectors are
/// plain scalars rather than `name`-labelled families.
#[derive(Debug, Clone)]
pub struct ProverTxMetrics;

impl ProverTxMetrics {
    /// Create a direct Prometheus metrics adapter for the transaction manager.
    pub fn new() -> Self {
        Lazy::force(&TX_MANAGER_METRICS);
        Self
    }
}

impl Default for ProverTxMetrics {
    fn default() -> Self {
        Self::new()
    }
}

impl TxMetrics for ProverTxMetrics {
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

    /// Record the current blob fee cap in gwei (unused: prove txs carry no blobs).
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

/// Direct Prometheus collector handles used by the prover.
static METRICS: Lazy<ProverMetricHandles> = Lazy::new(ProverMetricHandles::new);

/// Direct Prometheus collector handles used by the tx-manager adapter.
static TX_MANAGER_METRICS: Lazy<ProverTxMetricHandles> = Lazy::new(ProverTxMetricHandles::new);

/// Typed direct-Prometheus collectors owned by the prover crate.
struct ProverMetricHandles {
    /// Latest `Proposed` event proposal id received.
    received_proposed_id: Gauge,
    /// Proposals this prover decided to prove.
    proofs_assigned: IntCounter,
    /// Highest L2 block id covered by a submitted proof.
    latest_proven_block_id: Gauge,
    /// Latest finalized proposal id observed from `Proved` events.
    latest_verified_id: Gauge,
    /// Proposals covered by successfully submitted aggregations.
    proofs_sent: IntCounter,
    /// Aggregation submissions that errored.
    submission_errors: IntCounter,
    /// Prove transactions shadow mode would have submitted.
    shadow_would_submit: IntCounter,
}

impl ProverMetricHandles {
    /// Construct and register all prover collectors.
    fn new() -> Self {
        Self {
            received_proposed_id: gauge(
                "taiko_prover_received_proposed_id",
                "Latest Proposed event proposal id received",
            ),
            proofs_assigned: counter(
                "taiko_prover_proofs_assigned",
                "Proposals this prover decided to prove",
            ),
            latest_proven_block_id: gauge(
                "taiko_prover_latest_proven_block_id",
                "Highest L2 block id covered by a submitted proof",
            ),
            latest_verified_id: gauge(
                "taiko_prover_latest_verified_id",
                "Latest finalized proposal id observed from Proved events",
            ),
            proofs_sent: counter(
                "taiko_prover_proofs_sent",
                "Proposals covered by successfully submitted aggregations",
            ),
            submission_errors: counter(
                "taiko_prover_submission_errors",
                "Aggregation submissions that reverted or failed to send",
            ),
            shadow_would_submit: counter(
                "taiko_prover_shadow_would_submit",
                "Prove transactions shadow mode would have submitted",
            ),
        }
    }
}

/// Typed direct-Prometheus collectors for the base tx-manager metric contract.
struct ProverTxMetricHandles {
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

impl ProverTxMetricHandles {
    /// Construct and register all tx-manager collectors. Metric names carry a
    /// `prover` prefix so a prover and proposer sharing a process or dashboard
    /// stay distinguishable.
    fn new() -> Self {
        Self {
            tx_max_fee_gwei: histogram(
                "prover_tx_manager_tx_max_fee_gwei",
                "Maximum possible transaction fee in gwei (gas_limit * fee_cap)",
                GWEI_BUCKETS,
            ),
            tx_gas_bump_count: counter(
                "prover_tx_manager_tx_gas_bump_count",
                "Number of gas bump events",
            ),
            tx_send_latency_ms: histogram(
                "prover_tx_manager_tx_send_latency_ms",
                "Send-loop latency in milliseconds",
                LATENCY_MILLISECONDS_BUCKETS,
            ),
            current_nonce: gauge("prover_tx_manager_current_nonce", "Current nonce value"),
            tx_publish_error_count: counter(
                "prover_tx_manager_tx_publish_error_count",
                "Number of transaction publish errors",
            ),
            basefee_gwei: gauge("prover_tx_manager_basefee_gwei", "Base fee in gwei"),
            tipcap_gwei: gauge("prover_tx_manager_tipcap_gwei", "Tip cap in gwei"),
            blob_fee_gwei: gauge("prover_tx_manager_blob_fee_gwei", "Blob fee cap in gwei"),
            rpc_error_count: counter("prover_tx_manager_rpc_error_count", "Number of RPC errors"),
            tx_confirmed_count: counter(
                "prover_tx_manager_tx_confirmed_count",
                "Number of confirmed transactions",
            ),
            tx_failed_count: counter(
                "prover_tx_manager_tx_failed_count",
                "Number of failed send attempts (includes timeouts where the tx may still confirm)",
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use base_tx_manager::TxMetrics;

    use super::{ProverMetrics, ProverTxMetrics};

    #[test]
    fn tx_manager_metrics_are_registered_with_direct_prometheus_registry() {
        ProverMetrics::init();
        let metrics = ProverTxMetrics::new();

        metrics.record_gas_bump();

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| family.get_name() == "prover_tx_manager_tx_gas_bump_count")
            .expect("tx-manager gas bump counter should be exported");
        let metric =
            family.get_metric().first().expect("tx-manager gas bump counter should have a metric");

        assert!(metric.get_counter().get_value() >= 1.0);
    }
}
