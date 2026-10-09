//! Prometheus metrics of the ABCI app.
//!
//! The collectors live in the process-wide default registry, which the client's metrics server
//! exposes. They register on first use; [`AbciMetrics::init`] forces that at startup so every
//! series is exported from the beginning. A collector that cannot register (a name clash) is
//! logged and keeps counting unexported: metrics never stop the node.

use once_cell::sync::Lazy;
use prometheus::{Histogram, HistogramOpts, IntCounter, IntCounterVec, IntGauge, Opts};

/// Histogram buckets for handler latencies, in seconds.
pub const DURATION_SECONDS_BUCKETS: &[f64] =
    &[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0];

/// Accessors of the ABCI app's Prometheus collectors.
#[derive(Clone, Copy, Debug)]
pub struct AbciMetrics;

impl AbciMetrics {
    /// Registers every collector with the default registry (idempotent).
    pub fn init() {
        Lazy::force(&METRICS);
    }

    /// `abci_proposals_built_total`: `PrepareProposal` answers carrying a block.
    pub fn proposals_built() -> &'static IntCounter {
        &METRICS.proposals_built
    }

    /// `abci_proposals_empty_total`: `PrepareProposal` answers without transactions (the node
    /// could not or must not propose).
    pub fn proposals_empty() -> &'static IntCounter {
        &METRICS.proposals_empty
    }

    /// `abci_process_accepted_total`: `ProcessProposal` answers `ACCEPT`.
    pub fn process_accepted() -> &'static IntCounter {
        &METRICS.process_accepted
    }

    /// `abci_process_rejected_total{reason}`: `ProcessProposal` answers `REJECT`, labelled with
    /// [`Rejection::label`](crate::app::Rejection::label).
    pub fn process_rejected() -> &'static IntCounterVec {
        &METRICS.process_rejected
    }

    /// `abci_process_seconds`: `ProcessProposal` latency.
    pub fn process_seconds() -> &'static Histogram {
        &METRICS.process_seconds
    }

    /// `abci_finalize_seconds`: `FinalizeBlock` latency (EL retries included).
    pub fn finalize_seconds() -> &'static Histogram {
        &METRICS.finalize_seconds
    }

    /// `abci_head`: the last committed height (L2 block number).
    pub fn head() -> &'static IntGauge {
        &METRICS.head
    }

    /// `abci_epoch`: the epoch of the committed head.
    pub fn epoch() -> &'static IntGauge {
        &METRICS.epoch
    }

    /// `abci_generation`: the recovery generation of the running chain.
    pub fn generation() -> &'static IntGauge {
        &METRICS.generation
    }

    /// `abci_unsettled_depth`: committed head minus the anchored `lastCheckpoint.height`, in L2
    /// blocks (the back-pressure input).
    pub fn unsettled_depth() -> &'static IntGauge {
        &METRICS.unsettled_depth
    }

    /// `abci_l1_finality_lag`: the own L1 finalized block number minus the committed anchor's,
    /// in L1 blocks, as last seen by `PrepareProposal`.
    pub fn l1_finality_lag() -> &'static IntGauge {
        &METRICS.l1_finality_lag
    }

    /// `abci_halted`: 1 while the app refuses to make progress (the last proposal was refused,
    /// reason in `/status`, or a safety halt stopped it), 0 otherwise.
    pub fn halted() -> &'static IntGauge {
        &METRICS.halted
    }
}

/// Sets `gauge` to `value`, saturating at `i64::MAX`.
pub(crate) fn set_u64(gauge: &IntGauge, value: u64) {
    gauge.set(i64::try_from(value).unwrap_or(i64::MAX));
}

/// The ABCI app's collectors.
struct Metrics {
    /// See [`AbciMetrics::proposals_built`].
    proposals_built: IntCounter,
    /// See [`AbciMetrics::proposals_empty`].
    proposals_empty: IntCounter,
    /// See [`AbciMetrics::process_accepted`].
    process_accepted: IntCounter,
    /// See [`AbciMetrics::process_rejected`].
    process_rejected: IntCounterVec,
    /// See [`AbciMetrics::process_seconds`].
    process_seconds: Histogram,
    /// See [`AbciMetrics::finalize_seconds`].
    finalize_seconds: Histogram,
    /// See [`AbciMetrics::head`].
    head: IntGauge,
    /// See [`AbciMetrics::epoch`].
    epoch: IntGauge,
    /// See [`AbciMetrics::generation`].
    generation: IntGauge,
    /// See [`AbciMetrics::unsettled_depth`].
    unsettled_depth: IntGauge,
    /// See [`AbciMetrics::l1_finality_lag`].
    l1_finality_lag: IntGauge,
    /// See [`AbciMetrics::halted`].
    halted: IntGauge,
}

/// The collectors, registered on first use.
static METRICS: Lazy<Metrics> = Lazy::new(|| Metrics {
    proposals_built: counter(
        "abci_proposals_built_total",
        "PrepareProposal answers carrying a block",
    ),
    proposals_empty: counter(
        "abci_proposals_empty_total",
        "PrepareProposal answers without transactions",
    ),
    process_accepted: counter("abci_process_accepted_total", "ProcessProposal ACCEPT answers"),
    process_rejected: register(
        IntCounterVec::new(
            Opts::new("abci_process_rejected_total", "ProcessProposal REJECT answers by reason"),
            &["reason"],
        )
        .expect("valid counter vector options"),
    ),
    process_seconds: histogram("abci_process_seconds", "ProcessProposal latency in seconds"),
    finalize_seconds: histogram("abci_finalize_seconds", "FinalizeBlock latency in seconds"),
    head: gauge("abci_head", "Last committed height"),
    epoch: gauge("abci_epoch", "Epoch of the committed head"),
    generation: gauge("abci_generation", "Recovery generation of the running chain"),
    unsettled_depth: gauge(
        "abci_unsettled_depth",
        "Committed head minus the anchored lastCheckpoint height, in L2 blocks",
    ),
    l1_finality_lag: gauge(
        "abci_l1_finality_lag",
        "Own L1 finalized block minus the committed anchor block, in L1 blocks",
    ),
    halted: gauge("abci_halted", "1 while the app refuses to make progress, 0 otherwise"),
});

/// A registered integer counter.
fn counter(name: &str, help: &str) -> IntCounter {
    register(IntCounter::new(name, help).expect("valid counter options"))
}

/// A registered integer gauge.
fn gauge(name: &str, help: &str) -> IntGauge {
    register(IntGauge::new(name, help).expect("valid gauge options"))
}

/// A registered latency histogram over [`DURATION_SECONDS_BUCKETS`].
fn histogram(name: &str, help: &str) -> Histogram {
    let opts = HistogramOpts::new(name, help).buckets(DURATION_SECONDS_BUCKETS.to_vec());
    register(Histogram::with_opts(opts).expect("valid histogram options"))
}

/// Registers `collector` with the default registry and returns it; a failed registration is
/// logged and the collector returned unexported.
fn register<C: prometheus::core::Collector + Clone + 'static>(collector: C) -> C {
    if let Err(error) = prometheus::register(Box::new(collector.clone())) {
        tracing::warn!(%error, "could not register an abci Prometheus collector");
    }
    collector
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn init_registers_every_series() {
        AbciMetrics::init();
        AbciMetrics::process_rejected().with_label_values(&["envelope"]).inc();
        let names: Vec<String> =
            prometheus::gather().iter().map(|family| family.get_name().to_string()).collect();
        for name in [
            "abci_proposals_built_total",
            "abci_proposals_empty_total",
            "abci_process_accepted_total",
            "abci_process_rejected_total",
            "abci_process_seconds",
            "abci_finalize_seconds",
            "abci_head",
            "abci_epoch",
            "abci_generation",
            "abci_unsettled_depth",
            "abci_l1_finality_lag",
            "abci_halted",
        ] {
            assert!(names.iter().any(|n| n == name), "{name} missing from {names:?}");
        }
    }

    #[test]
    fn set_u64_saturates() {
        let gauge = IntGauge::new("abci_set_u64_test", "test").unwrap();
        set_u64(&gauge, 7);
        assert_eq!(gauge.get(), 7);
        set_u64(&gauge, u64::MAX);
        assert_eq!(gauge.get(), i64::MAX);
    }
}
