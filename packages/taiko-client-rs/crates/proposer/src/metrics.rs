//! Prometheus metrics for tracking proposer.

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

/// Direct Prometheus collector handles used by the proposer.
static METRICS: Lazy<ProposerMetricHandles> = Lazy::new(ProposerMetricHandles::new);

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

#[cfg(test)]
mod tests {
    use super::ProposerMetrics;

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
