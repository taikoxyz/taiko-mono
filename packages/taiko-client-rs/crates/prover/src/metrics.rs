//! Prometheus metrics for tracking the prover.

use std::time::Duration;

use once_cell::sync::Lazy;
use prometheus::{Counter, Gauge, IntCounter};
use protocol::metrics::{counter, float_counter, gauge};

use crate::raiko::ProofType;

/// Metric namespace and direct Prometheus handles emitted by the prover.
///
/// A zero-sized namespace whose methods are all associated functions; it is
/// never instantiated, so it carries no `Debug`/`Clone` derives.
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

    /// Set the ZK backlog drain-mode gauge (1 = draining via SGX, 0 = ZK).
    pub fn set_zk_backlog_sgx_mode(draining: bool) {
        METRICS.zk_backlog_sgx_mode.set(if draining { 1.0 } else { 0.0 });
    }

    /// Count one fired ZK backlog clear.
    pub fn inc_zk_backlog_clear() {
        METRICS.zk_backlog_clear.inc();
    }

    /// Record one completed proof generation of `elapsed` for `proof_type`,
    /// distinguishing single proofs from aggregations, mirroring Go's
    /// `updateProvingMetrics` (`prover/proof_producer/common.go:139-189`):
    /// it sets the last generation-time gauge, adds to the cumulative-time
    /// counter, and increments the generated counter. Placeholder types
    /// (`ZkAny`, which raiko always resolves to a concrete type before a proof
    /// exists) are ignored with a warning, like Go's default branch.
    pub fn record_proof_generation(proof_type: ProofType, is_aggregation: bool, elapsed: Duration) {
        let target = match (proof_type, is_aggregation) {
            (ProofType::SgxGeth, false) => &METRICS.sgx_geth_single,
            (ProofType::SgxGeth, true) => &METRICS.sgx_geth_aggregation,
            (ProofType::Sgx, false) => &METRICS.sgx_single,
            (ProofType::Sgx, true) => &METRICS.sgx_aggregation,
            (ProofType::Risc0, false) => &METRICS.r0_single,
            (ProofType::Risc0, true) => &METRICS.r0_aggregation,
            (ProofType::Sp1, false) => &METRICS.sp1_single,
            (ProofType::Sp1, true) => &METRICS.sp1_aggregation,
            (ProofType::ZkAny, _) => {
                tracing::warn!(?proof_type, "no generation metric for proof type");
                return;
            }
        };
        target.record(elapsed.as_secs_f64());
    }
}

/// Per-(proof type, mode) generation collectors: the most recent generation
/// time, the cumulative generation time, and the number generated. Mirrors the
/// triples Go's `updateProvingMetrics` maintains per proof type.
struct GenerationMetrics {
    /// Most recent generation time in seconds.
    time: Gauge,
    /// Cumulative generation time in seconds.
    time_sum: Counter,
    /// Number of proofs generated.
    count: IntCounter,
}

impl GenerationMetrics {
    /// Register the three collectors as `{prefix}_generation_time`,
    /// `{prefix}_generation_time_sum`, and `{prefix}_generated`. `label` is the
    /// human-readable proof description used in the help text.
    fn new(prefix: &str, label: &str) -> Self {
        Self {
            time: gauge(
                &format!("{prefix}_generation_time"),
                &format!("Most recent {label} proof generation time in seconds"),
            ),
            time_sum: float_counter(
                &format!("{prefix}_generation_time_sum"),
                &format!("Cumulative {label} proof generation time in seconds"),
            ),
            count: counter(
                &format!("{prefix}_generated"),
                &format!("Number of {label} proofs generated"),
            ),
        }
    }

    /// Record one completed generation lasting `elapsed_secs` seconds.
    fn record(&self, elapsed_secs: f64) {
        self.time.set(elapsed_secs);
        self.time_sum.inc_by(elapsed_secs);
        self.count.inc();
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
    /// 1 while draining the ZK backlog via SGX, 0 while proving via ZK.
    zk_backlog_sgx_mode: Gauge,
    /// Number of ZK backlog clear requests fired on entering SGX-draining mode.
    zk_backlog_clear: IntCounter,
    /// sgxgeth single-proof generation collectors.
    sgx_geth_single: GenerationMetrics,
    /// sgx single-proof generation collectors.
    sgx_single: GenerationMetrics,
    /// risc0 single-proof generation collectors.
    r0_single: GenerationMetrics,
    /// sp1 single-proof generation collectors.
    sp1_single: GenerationMetrics,
    /// sgxgeth aggregation generation collectors.
    sgx_geth_aggregation: GenerationMetrics,
    /// sgx aggregation generation collectors.
    sgx_aggregation: GenerationMetrics,
    /// risc0 aggregation generation collectors.
    r0_aggregation: GenerationMetrics,
    /// sp1 aggregation generation collectors.
    sp1_aggregation: GenerationMetrics,
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
            zk_backlog_sgx_mode: gauge(
                "taiko_prover_zk_backlog_sgx_mode",
                "1 while draining the ZK backlog via SGX, 0 while proving via ZK",
            ),
            zk_backlog_clear: counter(
                "taiko_prover_zk_backlog_clear",
                "ZK backlog clear requests fired on entering SGX-draining mode",
            ),
            sgx_geth_single: GenerationMetrics::new("taiko_prover_proof_sgx_geth", "sgxgeth"),
            sgx_single: GenerationMetrics::new("taiko_prover_proof_sgx", "sgx"),
            r0_single: GenerationMetrics::new("taiko_prover_proof_r0", "risc0"),
            sp1_single: GenerationMetrics::new("taiko_prover_proof_sp1", "sp1"),
            sgx_geth_aggregation: GenerationMetrics::new(
                "taiko_prover_proof_sgx_geth_aggregation",
                "sgxgeth aggregation",
            ),
            sgx_aggregation: GenerationMetrics::new(
                "taiko_prover_proof_sgx_aggregation",
                "sgx aggregation",
            ),
            r0_aggregation: GenerationMetrics::new(
                "taiko_prover_proof_r0_aggregation",
                "risc0 aggregation",
            ),
            sp1_aggregation: GenerationMetrics::new(
                "taiko_prover_proof_sp1_aggregation",
                "sp1 aggregation",
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::ProverMetrics;

    #[test]
    fn zk_backlog_setters_are_callable_after_init() {
        ProverMetrics::init();
        // Exercising the setters must not panic and must be idempotent.
        ProverMetrics::set_zk_backlog_sgx_mode(true);
        ProverMetrics::set_zk_backlog_sgx_mode(false);
        ProverMetrics::inc_zk_backlog_clear();
        ProverMetrics::inc_zk_backlog_clear();
    }
}
