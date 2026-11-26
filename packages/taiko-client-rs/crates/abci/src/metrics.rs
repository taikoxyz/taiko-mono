//! Prometheus metrics of the ABCI app.
//!
//! The collectors live in the process-wide default registry, which the client's metrics server
//! exposes. They register on first use; [`AbciMetrics::init`] forces that at startup so every
//! series is exported from the beginning. A collector that cannot register (a name clash) is
//! logged and keeps counting unexported: metrics never stop the node.

use alloy_primitives::U256;
use once_cell::sync::Lazy;
use prometheus::{
    Gauge, Histogram, HistogramOpts, IntCounter, IntCounterVec, IntGauge, IntGaugeVec, Opts,
};

use crate::{
    committee::SignerSource,
    store::{FallbackReason, Signers},
};

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

    /// `abci_proposals_placeholder_total`: `PrepareProposal` answers with a placeholder proposal,
    /// one without transactions (RECOV-8-10: the node could not or must not propose).
    pub fn proposals_placeholder() -> &'static IntCounter {
        &METRICS.proposals_placeholder
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

    /// `abci_proposal_fallbacks_total{reason}`: proposals `PrepareProposal` built in a reduced
    /// form instead of the intended one, labelled with the reason (for example an anchor whose
    /// `lastCheckpoint` conflicts with the local chain, which keeps the parent anchor).
    pub fn proposal_fallbacks() -> &'static IntCounterVec {
        &METRICS.proposal_fallbacks
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

    /// `abci_generation`: the recovery generation of the running chain.
    pub fn generation() -> &'static IntGauge {
        &METRICS.generation
    }

    /// `abci_unsettled_depth`: committed head minus the anchored `lastCheckpoint.height`, in L2
    /// blocks (the back-pressure input).
    pub fn unsettled_depth() -> &'static IntGauge {
        &METRICS.unsettled_depth
    }

    /// `abci_signing_source{set}`: where the set that signs the height after the committed head
    /// (`set="next"`) and the one that signs the height after that (`set="after"`) come from: 0
    /// for the candidate snapshot, 1 for the fallback key list.
    pub fn signing_source() -> &'static IntGaugeVec {
        &METRICS.signing_source
    }

    /// `abci_fallback_reason{set,reason}`: 1 for the reason the fallback key list signs `set`
    /// (`next` or `after`, as [`AbciMetrics::signing_source`]), 0 for every other reason; all
    /// 0 while the candidate signs it. The reasons are [`FallbackReason::label`]s.
    pub fn fallback_reason() -> &'static IntGaugeVec {
        &METRICS.fallback_reason
    }

    /// `abci_candidate_total_stake`: the stored total stake of the candidate snapshot in the
    /// post-state of the committed head, which decided the set signing the second height after
    /// it, in base units, whether or not the candidate signs; 0 at a generation's origin, where
    /// no snapshot decides. A float gauge, since a uint256 total does not fit an integer one.
    pub fn candidate_total_stake() -> &'static Gauge {
        &METRICS.candidate_total_stake
    }

    /// `abci_min_total_stake`: the `minTotalStake` the committed head's anchor proves, which
    /// [`AbciMetrics::candidate_total_stake`] must reach for the candidate to sign, in base units
    /// (`2^256 − 1` hands every block to the fallback key list); 0 at a generation's origin.
    pub fn min_total_stake() -> &'static Gauge {
        &METRICS.min_total_stake
    }

    /// `abci_l1_finality_lag`: the own L1 finalized block number minus the committed anchor's,
    /// in L1 blocks, as last seen by `PrepareProposal`. The proposer moves the anchor once per
    /// 1,024 blocks (CONS-3.3-4), so it routinely reaches several hundred L1 blocks, up to about
    /// what `maxAnchorAge` spans.
    pub fn l1_finality_lag() -> &'static IntGauge {
        &METRICS.l1_finality_lag
    }

    /// `abci_checkpoint_trust_ready`: one only while the trust phase is `ready`, i.e. for a
    /// verified current session.
    pub fn checkpoint_trust_ready() -> &'static IntGauge {
        &METRICS.checkpoint_trust_ready
    }

    /// `abci_checkpoint_trust_phase`: acquiring=0, catching_up=1, ready=2, halted=3.
    pub fn checkpoint_trust_phase() -> &'static IntGauge {
        &METRICS.checkpoint_trust_phase
    }

    /// `abci_checkpoint_target_l1`: finalized proof snapshot number, or zero before acquisition.
    pub fn checkpoint_target_l1() -> &'static IntGauge {
        &METRICS.checkpoint_target_l1
    }

    /// `abci_checkpoint_target_l2`: pinned L2 checkpoint height, or zero before acquisition.
    pub fn checkpoint_target_l2() -> &'static IntGauge {
        &METRICS.checkpoint_target_l2
    }

    /// `abci_checkpoint_distance`: target height minus committed height, saturating at zero.
    pub fn checkpoint_distance() -> &'static IntGauge {
        &METRICS.checkpoint_distance
    }

    /// `abci_halted`: 1 while the app refuses to make progress, 0 otherwise. Despite the name it
    /// covers both a liveness pause (the last proposal was refused, reason in `/status`; the
    /// process keeps running) and a safety halt (the node stops).
    pub fn halted() -> &'static IntGauge {
        &METRICS.halted
    }
}

/// Sets `gauge` to `value`, saturating at `i64::MAX`.
pub(crate) fn set_u64(gauge: &IntGauge, value: u64) {
    gauge.set(i64::try_from(value).unwrap_or(i64::MAX));
}

/// Publishes where the two signing sets `signers` come from ([`AbciMetrics::signing_source`],
/// [`AbciMetrics::fallback_reason`]) and the candidate total stake and minimum that decided the
/// later one ([`AbciMetrics::candidate_total_stake`], [`AbciMetrics::min_total_stake`]).
pub(crate) fn publish_signers(signers: &Signers) {
    for (set, status) in [("next", &signers.next), ("after", &signers.after)] {
        let source = match status.source {
            SignerSource::Candidate => 0,
            SignerSource::Fallback => 1,
        };
        AbciMetrics::signing_source().with_label_values(&[set]).set(source);
        for reason in FallbackReason::ALL {
            let raised = i64::from(status.fallback_reason == Some(reason));
            AbciMetrics::fallback_reason().with_label_values(&[set, reason.label()]).set(raised);
        }
    }
    let float = |value: Option<U256>| value.map_or(0.0, f64::from);
    AbciMetrics::candidate_total_stake().set(float(signers.after.total_stake));
    AbciMetrics::min_total_stake().set(float(signers.after.min_total_stake));
}

/// The ABCI app's collectors.
struct Metrics {
    /// See [`AbciMetrics::proposals_built`].
    proposals_built: IntCounter,
    /// See [`AbciMetrics::proposals_placeholder`].
    proposals_placeholder: IntCounter,
    /// See [`AbciMetrics::process_accepted`].
    process_accepted: IntCounter,
    /// See [`AbciMetrics::process_rejected`].
    process_rejected: IntCounterVec,
    /// See [`AbciMetrics::proposal_fallbacks`].
    proposal_fallbacks: IntCounterVec,
    /// See [`AbciMetrics::process_seconds`].
    process_seconds: Histogram,
    /// See [`AbciMetrics::finalize_seconds`].
    finalize_seconds: Histogram,
    /// See [`AbciMetrics::head`].
    head: IntGauge,
    /// See [`AbciMetrics::generation`].
    generation: IntGauge,
    /// See [`AbciMetrics::unsettled_depth`].
    unsettled_depth: IntGauge,
    /// See [`AbciMetrics::signing_source`].
    signing_source: IntGaugeVec,
    /// See [`AbciMetrics::fallback_reason`].
    fallback_reason: IntGaugeVec,
    /// See [`AbciMetrics::candidate_total_stake`].
    candidate_total_stake: Gauge,
    /// See [`AbciMetrics::min_total_stake`].
    min_total_stake: Gauge,
    /// See [`AbciMetrics::l1_finality_lag`].
    l1_finality_lag: IntGauge,
    /// See [`AbciMetrics::checkpoint_trust_ready`].
    checkpoint_trust_ready: IntGauge,
    /// See [`AbciMetrics::checkpoint_trust_phase`].
    checkpoint_trust_phase: IntGauge,
    /// See [`AbciMetrics::checkpoint_target_l1`].
    checkpoint_target_l1: IntGauge,
    /// See [`AbciMetrics::checkpoint_target_l2`].
    checkpoint_target_l2: IntGauge,
    /// See [`AbciMetrics::checkpoint_distance`].
    checkpoint_distance: IntGauge,
    /// See [`AbciMetrics::halted`].
    halted: IntGauge,
}

/// The collectors, registered on first use.
static METRICS: Lazy<Metrics> = Lazy::new(|| Metrics {
    proposals_built: counter(
        "abci_proposals_built_total",
        "PrepareProposal answers carrying a block",
    ),
    proposals_placeholder: counter(
        "abci_proposals_placeholder_total",
        "PrepareProposal answers with a placeholder proposal (no transactions)",
    ),
    process_accepted: counter("abci_process_accepted_total", "ProcessProposal ACCEPT answers"),
    process_rejected: register(
        IntCounterVec::new(
            Opts::new("abci_process_rejected_total", "ProcessProposal REJECT answers by reason"),
            &["reason"],
        )
        .expect("valid counter vector options"),
    ),
    proposal_fallbacks: register(
        IntCounterVec::new(
            Opts::new(
                "abci_proposal_fallbacks_total",
                "PrepareProposal blocks built in a reduced form, by reason",
            ),
            &["reason"],
        )
        .expect("valid counter vector options"),
    ),
    process_seconds: histogram("abci_process_seconds", "ProcessProposal latency in seconds"),
    finalize_seconds: histogram("abci_finalize_seconds", "FinalizeBlock latency in seconds"),
    head: gauge("abci_head", "Last committed height"),
    generation: gauge("abci_generation", "Recovery generation of the running chain"),
    unsettled_depth: gauge(
        "abci_unsettled_depth",
        "Committed head minus the anchored lastCheckpoint height, in L2 blocks",
    ),
    signing_source: register(
        IntGaugeVec::new(
            Opts::new(
                "abci_signing_source",
                "Source of the set signing head+1 (set=next) and head+2 (set=after): \
                 candidate=0 fallback=1",
            ),
            &["set"],
        )
        .expect("valid gauge vector options"),
    ),
    fallback_reason: register(
        IntGaugeVec::new(
            Opts::new(
                "abci_fallback_reason",
                "1 for the reason the fallback keys sign the set (next or after), 0 otherwise",
            ),
            &["set", "reason"],
        )
        .expect("valid gauge vector options"),
    ),
    candidate_total_stake: register(
        Gauge::new(
            "abci_candidate_total_stake",
            "Stored total stake of the candidate snapshot that decided the set signing head+2, \
             in base units",
        )
        .expect("valid gauge options"),
    ),
    min_total_stake: register(
        Gauge::new(
            "abci_min_total_stake",
            "minTotalStake the head's anchor proves, which the candidate total stake must reach",
        )
        .expect("valid gauge options"),
    ),
    l1_finality_lag: gauge(
        "abci_l1_finality_lag",
        "Own L1 finalized block minus the committed anchor block, in L1 blocks",
    ),
    checkpoint_trust_ready: gauge(
        "abci_checkpoint_trust_ready",
        "Current checkpoint session is ready",
    ),
    checkpoint_trust_phase: gauge(
        "abci_checkpoint_trust_phase",
        "Acquiring=0 catching_up=1 ready=2 halted=3",
    ),
    checkpoint_target_l1: gauge("abci_checkpoint_target_l1", "Finalized L1 checkpoint proof block"),
    checkpoint_target_l2: gauge("abci_checkpoint_target_l2", "Pinned L2 checkpoint height"),
    checkpoint_distance: gauge(
        "abci_checkpoint_distance",
        "Pinned checkpoint height minus committed height",
    ),
    halted: gauge(
        "abci_halted",
        "1 during a liveness pause (last proposal refused) or after a safety halt, 0 otherwise",
    ),
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
        AbciMetrics::proposal_fallbacks().with_label_values(&["checkpoint_conflict"]).inc();
        AbciMetrics::signing_source().with_label_values(&["next"]).set(1);
        AbciMetrics::fallback_reason().with_label_values(&["next", "stale_snapshot"]).set(1);
        let names: Vec<String> =
            prometheus::gather().iter().map(|family| family.get_name().to_string()).collect();
        for name in [
            "abci_proposals_built_total",
            "abci_proposals_placeholder_total",
            "abci_process_accepted_total",
            "abci_process_rejected_total",
            "abci_proposal_fallbacks_total",
            "abci_process_seconds",
            "abci_finalize_seconds",
            "abci_head",
            "abci_generation",
            "abci_unsettled_depth",
            "abci_signing_source",
            "abci_fallback_reason",
            "abci_candidate_total_stake",
            "abci_min_total_stake",
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
