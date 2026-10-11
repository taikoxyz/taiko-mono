//! Bounded Prometheus labels for landing progress and durable transaction recovery.
//!
//! Transaction hashes belong in logs rather than metric labels. No collector contains key
//! material, endpoint credentials, job hashes or arbitrary RPC error messages.

use std::sync::LazyLock;

use prometheus::{IntCounterVec, IntGauge, IntGaugeVec, Opts};

use crate::LanderError;

/// Observable phase of the runner's one durable transaction.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransactionPhase {
    /// No outstanding prepared job or nonce.
    Idle,
    /// Immutable job and proof are durable, but no transaction has been signed.
    Prepared,
    /// Complete signed bytes are durable, before or after an ambiguous broadcast.
    Signed,
    /// The durable transaction's nonce remains outstanding.
    Pending,
    /// A canonical receipt is waiting for the configured confirmation depth.
    Confirming,
}

impl TransactionPhase {
    /// Finite Prometheus label independent of job or RPC contents.
    pub const fn label(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Prepared => "prepared",
            Self::Signed => "signed",
            Self::Pending => "pending",
            Self::Confirming => "confirming",
        }
    }
}

/// Idempotent access to the process-wide default-registry collectors.
#[derive(Clone, Copy, Debug)]
pub struct LanderMetrics;

impl LanderMetrics {
    /// Register every collector and explicitly mark the only provider as dummy.
    pub fn init() {
        LazyLock::force(&METRICS);
        METRICS.dummy_provider.set(1);
    }

    /// Observe the coherent on-chain checkpoint and latest collected decided height.
    pub fn progress(landed: u64, decided: u64) {
        set_u64(&METRICS.landed_height, landed);
        set_u64(&METRICS.decided_height, decided);
        set_u64(&METRICS.unsettled_depth, decided.saturating_sub(landed));
    }

    /// Observe complete encoded blocks and ordered blobs of the current prepared job.
    pub fn batch(blocks: usize, blobs: usize, payload_bytes: usize) {
        set_u64(&METRICS.batch_blocks, u64::try_from(blocks).unwrap_or(u64::MAX));
        set_u64(&METRICS.batch_blobs, u64::try_from(blobs).unwrap_or(u64::MAX));
        set_u64(&METRICS.payload_bytes, u64::try_from(payload_bytes).unwrap_or(u64::MAX));
    }

    /// Observe exactly one transaction phase and its nonce; `-1` means no nonce is outstanding.
    pub fn transaction(phase: TransactionPhase, nonce: Option<u64>) {
        for label in ["idle", "prepared", "signed", "pending", "confirming"] {
            METRICS
                .transaction_phase
                .with_label_values(&[label])
                .set(i64::from(label == phase.label()));
        }
        METRICS.pending_nonce.set(nonce.map_or(-1, |n| i64::try_from(n).unwrap_or(i64::MAX)));
    }

    /// Observe canonical confirmations of the outstanding transaction, zero before a receipt.
    pub fn confirmations(count: u64) {
        set_u64(&METRICS.confirmations, count);
    }

    /// Count a retry using only the shared finite operational classification.
    pub fn retry(error: &LanderError) {
        let reason = match error {
            LanderError::Temporary(_) => "rpc_or_finality",
            LanderError::Unavailable(_) => "history_unavailable",
            LanderError::Stale(_) => "competing_checkpoint_or_reference",
            _ => return,
        };
        METRICS.retries.with_label_values(&[reason]).inc();
    }
}

/// The runner's collectors; all gauges saturate rather than wrap at the signed metric limit.
struct Metrics {
    /// Explicit dummy-proof-provider indicator.
    dummy_provider: IntGauge,
    /// Latest coherent Inbox checkpoint height.
    landed_height: IntGauge,
    /// Latest collected CometBFT decided height.
    decided_height: IntGauge,
    /// Decided height minus landed height.
    unsettled_depth: IntGauge,
    /// Complete blocks in the current prepared batch.
    batch_blocks: IntGauge,
    /// Blobs in the current prepared batch.
    batch_blobs: IntGauge,
    /// Encoded V1 payload size before blob field-element coding.
    payload_bytes: IntGauge,
    /// One-hot bounded durable transaction phase.
    transaction_phase: IntGaugeVec,
    /// Outstanding sender nonce, or minus one.
    pending_nonce: IntGauge,
    /// Canonical receipt confirmations so far.
    confirmations: IntGauge,
    /// Retry attempts by finite operational class.
    retries: IntCounterVec,
}

/// Initialized once per process, independently of whether the HTTP exporter is enabled.
static METRICS: LazyLock<Metrics> = LazyLock::new(|| {
    let transaction_phase = register(
        IntGaugeVec::new(
            Opts::new("lander_transaction_phase", "Current durable transaction phase"),
            &["phase"],
        )
        .expect("valid phase metric"),
    );
    for phase in ["idle", "prepared", "signed", "pending", "confirming"] {
        transaction_phase.with_label_values(&[phase]).set(i64::from(phase == "idle"));
    }
    let retries = register(
        IntCounterVec::new(
            Opts::new("lander_retries_total", "Retry attempts by operational class"),
            &["reason"],
        )
        .expect("valid retry metric"),
    );
    for reason in
        ["rpc_or_finality", "history_unavailable", "competing_checkpoint_or_reference", "fatal"]
    {
        let _ = retries.with_label_values(&[reason]);
    }
    let pending_nonce = gauge("lander_pending_nonce", "Outstanding sender nonce; -1 when absent");
    pending_nonce.set(-1);
    Metrics {
        dummy_provider: gauge(
            "lander_dummy_provider",
            "1 when using the dummy 0x00 proof provider",
        ),
        landed_height: gauge("lander_landed_height", "Latest coherent Inbox checkpoint height"),
        decided_height: gauge("lander_decided_height", "Latest CometBFT decided height"),
        unsettled_depth: gauge("lander_unsettled_depth", "Decided minus landed L2 height"),
        batch_blocks: gauge("lander_batch_blocks", "Complete blocks in the prepared batch"),
        batch_blobs: gauge("lander_batch_blobs", "Blobs in the prepared batch"),
        payload_bytes: gauge("lander_payload_bytes", "Encoded batch bytes before blob coding"),
        transaction_phase,
        pending_nonce,
        confirmations: gauge("lander_confirmations", "Canonical receipt confirmations"),
        retries,
    }
});

/// Register an integer gauge with invariant static options.
fn gauge(name: &str, help: &str) -> IntGauge {
    register(IntGauge::new(name, help).expect("valid lander gauge"))
}

/// Register lazily; instrumentation failures cannot stop checkpoint or nonce reconciliation.
fn register<C: prometheus::core::Collector + Clone + 'static>(collector: C) -> C {
    if let Err(error) = prometheus::register(Box::new(collector.clone())) {
        tracing::warn!(%error, "could not register a lander Prometheus collector");
    }
    collector
}

/// Saturate a u64 observation at the largest signed Prometheus sample.
fn set_u64(gauge: &IntGauge, value: u64) {
    gauge.set(i64::try_from(value).unwrap_or(i64::MAX));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn observations_saturate_without_wrapping() {
        let gauge =
            IntGauge::new("lander_local_saturation_test", "Unregistered test gauge").unwrap();
        set_u64(&gauge, 42);
        assert_eq!(gauge.get(), 42);
        set_u64(&gauge, u64::MAX);
        assert_eq!(gauge.get(), i64::MAX);
    }

    #[test]
    fn exports_dummy_progress_and_durable_phase_without_unbounded_labels() {
        LanderMetrics::init();
        LanderMetrics::progress(10, 14);
        LanderMetrics::batch(4, 2, 160_000);
        LanderMetrics::transaction(TransactionPhase::Pending, Some(3));
        LanderMetrics::confirmations(2);
        LanderMetrics::retry(&LanderError::Temporary("arbitrary source error".into()));
        let names: Vec<_> =
            prometheus::gather().iter().map(|family| family.get_name().to_string()).collect();
        for name in [
            "lander_dummy_provider",
            "lander_landed_height",
            "lander_decided_height",
            "lander_unsettled_depth",
            "lander_batch_blocks",
            "lander_batch_blobs",
            "lander_payload_bytes",
            "lander_transaction_phase",
            "lander_pending_nonce",
            "lander_confirmations",
            "lander_retries_total",
        ] {
            assert!(names.iter().any(|n| n == name), "missing {name}");
        }
    }
}
