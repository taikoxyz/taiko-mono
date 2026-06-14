//! Prometheus metrics for tracking the prover.

use once_cell::sync::Lazy;
use prometheus::{Gauge, IntCounter};
use protocol::metrics::{counter, gauge};

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

    /// Aggregation submissions that failed to send (tx-manager error).
    pub fn submission_errors() -> &'static IntCounter {
        &METRICS.submission_errors
    }

    /// Prove transactions that reached confirmation depth but reverted on-chain.
    pub fn submission_reverted() -> &'static IntCounter {
        &METRICS.submission_reverted
    }

    /// Prove transactions the shadow mode would have submitted.
    pub fn shadow_would_submit() -> &'static IntCounter {
        &METRICS.shadow_would_submit
    }
}

/// Direct Prometheus collector handles used by the prover.
static METRICS: Lazy<ProverMetricHandles> = Lazy::new(ProverMetricHandles::new);

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
    /// Aggregation submissions that failed to send.
    submission_errors: IntCounter,
    /// Prove transactions that reached confirmation depth but reverted on-chain.
    submission_reverted: IntCounter,
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
                "Aggregation submissions that failed to send (tx-manager error)",
            ),
            submission_reverted: counter(
                "taiko_prover_submission_reverted",
                "Prove transactions that reached confirmation depth but reverted on-chain",
            ),
            shadow_would_submit: counter(
                "taiko_prover_shadow_would_submit",
                "Prove transactions shadow mode would have submitted",
            ),
        }
    }
}
