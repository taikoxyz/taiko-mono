//! Metrics exposed by the driver runtime.

use once_cell::sync::Lazy;
use prometheus::{Gauge, Histogram, IntCounter, core::Collector};

/// Histogram buckets for operation durations expressed in seconds.
const DURATION_SECONDS_BUCKETS: &[f64] =
    &[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0];

/// Histogram buckets for retry-attempt counts.
const RETRY_ATTEMPT_BUCKETS: &[f64] = &[0.0, 1.0, 2.0, 3.0, 5.0, 8.0, 13.0, 21.0];

/// Metric namespace for the driver.
pub struct DriverMetrics;

impl DriverMetrics {
    /// Gauge tracking the latest L2 head observed on the execution engine.
    pub const BEACON_SYNC_LOCAL_HEAD_BLOCK: &'static str = "driver_beacon_sync_local_head_block";
    /// Gauge tracking the checkpoint node head height.
    pub const BEACON_SYNC_CHECKPOINT_HEAD_BLOCK: &'static str =
        "driver_beacon_sync_checkpoint_head_block";
    /// Gauge tracking the delta between checkpoint and local heads.
    pub const BEACON_SYNC_HEAD_LAG_BLOCKS: &'static str = "driver_beacon_sync_head_lag_blocks";
    /// Counter tracking submitted checkpoint blocks.
    pub const BEACON_SYNC_REMOTE_SUBMISSIONS_TOTAL: &'static str =
        "driver_beacon_sync_remote_submissions_total";
    /// Counter tracking batches of proposal logs received from the scanner.
    pub const EVENT_SCANNER_BATCHES_TOTAL: &'static str = "driver_event_scanner_batches_total";
    /// Counter tracking scanner stream errors.
    pub const EVENT_SCANNER_ERRORS_TOTAL: &'static str = "driver_event_scanner_errors_total";
    /// Counter tracking failures while probing confirmed-sync readiness.
    pub const EVENT_CONFIRMED_SYNC_PROBE_ERRORS_TOTAL: &'static str =
        "driver_event_confirmed_sync_probe_errors_total";
    /// Counter tracking proposal logs processed by the driver.
    pub const EVENT_PROPOSALS_TOTAL: &'static str = "driver_event_proposals_total";
    /// Counter tracking skipped proposals.
    pub const EVENT_PROPOSALS_SKIPPED_TOTAL: &'static str = "driver_event_proposals_skipped_total";
    /// Counter tracking orphaned proposal logs skipped after L1 reorg detection.
    pub const EVENT_ORPHANED_PROPOSAL_LOGS_TOTAL: &'static str =
        "driver_event_orphaned_proposal_logs_total";
    /// Counter tracking derived or confirmed L2 blocks per proposal.
    pub const EVENT_DERIVED_BLOCKS_TOTAL: &'static str = "driver_event_derived_blocks_total";
    /// Counter tracking proposals resolved entirely via canonical chain detection.
    pub const DERIVATION_CANONICAL_HITS_TOTAL: &'static str =
        "driver_derivation_canonical_hits_total";
    /// Counter tracking L1 origin rows written to the execution engine database.
    pub const DERIVATION_L1_ORIGIN_UPDATES_TOTAL: &'static str =
        "driver_derivation_l1_origin_updates_total";
    /// Gauge tracking the last finalized proposal id advertised by the inbox core state.
    pub const DERIVATION_LAST_FINALIZED_PROPOSAL_ID: &'static str =
        "driver_derivation_last_finalized_proposal_id";
    /// Counter tracking failed preconfirmation payload injections.
    pub const PRECONF_INJECTION_FAILURES_TOTAL: &'static str =
        "driver_preconf_injection_failures_total";
    /// Counter tracking successful preconfirmation payload injections.
    pub const PRECONF_INJECTION_SUCCESS_TOTAL: &'static str =
        "driver_preconf_injection_success_total";
    /// Histogram tracking end-to-end latency per preconfirmation payload.
    pub const PRECONF_INJECTION_DURATION_SECONDS: &'static str =
        "driver_preconf_injection_duration_seconds";
    /// Gauge tracking buffered preconfirmation jobs awaiting processing.
    pub const PRECONF_QUEUE_DEPTH: &'static str = "driver_preconf_queue_depth";
    /// Histogram tracking retry attempts per preconfirmation payload.
    pub const PRECONF_RETRY_ATTEMPTS: &'static str = "driver_preconf_retry_attempts";
    /// Gauge tracking the last canonical proposal id from L1 events.
    pub const EVENT_LAST_CANONICAL_PROPOSAL_ID: &'static str =
        "driver_event_last_canonical_proposal_id";
    /// Gauge tracking the last canonical L2 block number produced from L1 events.
    pub const EVENT_LAST_CANONICAL_BLOCK_NUMBER: &'static str =
        "driver_event_last_canonical_block_number";
    /// Counter for preconfirmation enqueue timeouts.
    pub const PRECONF_ENQUEUE_TIMEOUTS_TOTAL: &'static str =
        "driver_preconf_enqueue_timeouts_total";
    /// Counter for preconfirmation response timeouts.
    pub const PRECONF_RESPONSE_TIMEOUTS_TOTAL: &'static str =
        "driver_preconf_response_timeouts_total";
    /// Counter for preconfirmation enqueue failures.
    pub const PRECONF_ENQUEUE_FAILURES_TOTAL: &'static str =
        "driver_preconf_enqueue_failures_total";
    /// Counter for preconfirmation responses dropped because the channel closed.
    pub const PRECONF_RESPONSE_DROPPED_TOTAL: &'static str =
        "driver_preconf_response_dropped_total";
    /// Counter for stale preconfirmation payloads dropped before processing.
    pub const PRECONF_STALE_DROPPED_TOTAL: &'static str = "driver_preconf_stale_dropped_total";
    /// Counter for stale preconfirmation payloads dropped before enqueue.
    pub const PRECONF_STALE_DROPPED_BEFORE_ENQUEUE_TOTAL: &'static str =
        "driver_preconf_stale_dropped_before_enqueue_total";
    /// Counter for stale preconfirmation payloads dropped in ingress processing.
    pub const PRECONF_STALE_DROPPED_INGRESS_TOTAL: &'static str =
        "driver_preconf_stale_dropped_ingress_total";
    /// Counter for stale preconfirmation payloads dropped in the production path.
    pub const PRECONF_STALE_DROPPED_PRODUCTION_TOTAL: &'static str =
        "driver_preconf_stale_dropped_production_total";
    /// Histogram for parent hash lookup duration.
    pub const PRECONF_PARENT_HASH_LOOKUP_DURATION_SECONDS: &'static str =
        "driver_preconf_parent_hash_lookup_duration_seconds";
    /// Counter for parent hash lookup failures.
    pub const PRECONF_PARENT_HASH_LOOKUP_FAILURES_TOTAL: &'static str =
        "driver_preconf_parent_hash_lookup_failures_total";

    /// Register direct Prometheus collectors.
    pub fn init() {
        Lazy::force(&METRICS);
    }

    /// Return a registered counter by its public metric name.
    pub(crate) fn counter(name: &str) -> &IntCounter {
        METRICS.counter(name)
    }

    /// Return a registered gauge by its public metric name.
    pub(crate) fn gauge(name: &str) -> &Gauge {
        METRICS.gauge(name)
    }

    /// Return a registered histogram by its public metric name.
    pub(crate) fn histogram(name: &str) -> &Histogram {
        METRICS.histogram(name)
    }

    /// Return the local beacon-sync head gauge.
    pub(crate) fn beacon_sync_local_head_block() -> &'static Gauge {
        Self::gauge(Self::BEACON_SYNC_LOCAL_HEAD_BLOCK)
    }

    /// Return the checkpoint beacon-sync head gauge.
    pub(crate) fn beacon_sync_checkpoint_head_block() -> &'static Gauge {
        Self::gauge(Self::BEACON_SYNC_CHECKPOINT_HEAD_BLOCK)
    }

    /// Return the beacon-sync head lag gauge.
    pub(crate) fn beacon_sync_head_lag_blocks() -> &'static Gauge {
        Self::gauge(Self::BEACON_SYNC_HEAD_LAG_BLOCKS)
    }

    /// Return the beacon-sync remote submissions counter.
    pub(crate) fn beacon_sync_remote_submissions_total() -> &'static IntCounter {
        Self::counter(Self::BEACON_SYNC_REMOTE_SUBMISSIONS_TOTAL)
    }

    /// Return the event scanner batch counter.
    pub(crate) fn event_scanner_batches_total() -> &'static IntCounter {
        Self::counter(Self::EVENT_SCANNER_BATCHES_TOTAL)
    }

    /// Return the event scanner error counter.
    pub(crate) fn event_scanner_errors_total() -> &'static IntCounter {
        Self::counter(Self::EVENT_SCANNER_ERRORS_TOTAL)
    }

    /// Return the confirmed-sync probe error counter.
    pub(crate) fn event_confirmed_sync_probe_errors_total() -> &'static IntCounter {
        Self::counter(Self::EVENT_CONFIRMED_SYNC_PROBE_ERRORS_TOTAL)
    }

    /// Return the proposal log counter.
    pub(crate) fn event_proposals_total() -> &'static IntCounter {
        Self::counter(Self::EVENT_PROPOSALS_TOTAL)
    }

    /// Return the skipped proposal counter.
    pub(crate) fn event_proposals_skipped_total() -> &'static IntCounter {
        Self::counter(Self::EVENT_PROPOSALS_SKIPPED_TOTAL)
    }

    /// Return the orphaned proposal log counter.
    pub(crate) fn event_orphaned_proposal_logs_total() -> &'static IntCounter {
        Self::counter(Self::EVENT_ORPHANED_PROPOSAL_LOGS_TOTAL)
    }

    /// Return the derived event block counter.
    pub(crate) fn event_derived_blocks_total() -> &'static IntCounter {
        Self::counter(Self::EVENT_DERIVED_BLOCKS_TOTAL)
    }

    /// Return the canonical derivation hit counter.
    pub(crate) fn derivation_canonical_hits_total() -> &'static IntCounter {
        Self::counter(Self::DERIVATION_CANONICAL_HITS_TOTAL)
    }

    /// Return the L1 origin update counter.
    pub(crate) fn derivation_l1_origin_updates_total() -> &'static IntCounter {
        Self::counter(Self::DERIVATION_L1_ORIGIN_UPDATES_TOTAL)
    }

    /// Return the finalized proposal id gauge.
    pub(crate) fn derivation_last_finalized_proposal_id() -> &'static Gauge {
        Self::gauge(Self::DERIVATION_LAST_FINALIZED_PROPOSAL_ID)
    }

    /// Return the successful preconfirmation injection counter.
    pub(crate) fn preconf_injection_success_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_INJECTION_SUCCESS_TOTAL)
    }

    /// Return the failed preconfirmation injection counter.
    pub(crate) fn preconf_injection_failures_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_INJECTION_FAILURES_TOTAL)
    }

    /// Return the preconfirmation injection duration histogram.
    pub(crate) fn preconf_injection_duration_seconds() -> &'static Histogram {
        Self::histogram(Self::PRECONF_INJECTION_DURATION_SECONDS)
    }

    /// Return the preconfirmation queue depth gauge.
    pub(crate) fn preconf_queue_depth() -> &'static Gauge {
        Self::gauge(Self::PRECONF_QUEUE_DEPTH)
    }

    /// Return the preconfirmation enqueue timeout counter.
    pub(crate) fn preconf_enqueue_timeouts_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_ENQUEUE_TIMEOUTS_TOTAL)
    }

    /// Return the preconfirmation enqueue failure counter.
    pub(crate) fn preconf_enqueue_failures_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_ENQUEUE_FAILURES_TOTAL)
    }

    /// Return the preconfirmation response timeout counter.
    pub(crate) fn preconf_response_timeouts_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_RESPONSE_TIMEOUTS_TOTAL)
    }

    /// Return the dropped preconfirmation response counter.
    pub(crate) fn preconf_response_dropped_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_RESPONSE_DROPPED_TOTAL)
    }

    /// Return the aggregate stale preconfirmation drop counter.
    pub(crate) fn preconf_stale_dropped_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_STALE_DROPPED_TOTAL)
    }

    /// Return the before-enqueue stale preconfirmation drop counter.
    pub(crate) fn preconf_stale_dropped_before_enqueue_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_STALE_DROPPED_BEFORE_ENQUEUE_TOTAL)
    }

    /// Return the ingress stale preconfirmation drop counter.
    pub(crate) fn preconf_stale_dropped_ingress_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_STALE_DROPPED_INGRESS_TOTAL)
    }

    /// Return the parent hash lookup duration histogram.
    pub(crate) fn preconf_parent_hash_lookup_duration_seconds() -> &'static Histogram {
        Self::histogram(Self::PRECONF_PARENT_HASH_LOOKUP_DURATION_SECONDS)
    }

    /// Return the parent hash lookup failure counter.
    pub(crate) fn preconf_parent_hash_lookup_failures_total() -> &'static IntCounter {
        Self::counter(Self::PRECONF_PARENT_HASH_LOOKUP_FAILURES_TOTAL)
    }

    /// Return the last canonical event proposal id gauge.
    pub(crate) fn event_last_canonical_proposal_id() -> &'static Gauge {
        Self::gauge(Self::EVENT_LAST_CANONICAL_PROPOSAL_ID)
    }

    /// Return the last canonical event block number gauge.
    pub(crate) fn event_last_canonical_block_number() -> &'static Gauge {
        Self::gauge(Self::EVENT_LAST_CANONICAL_BLOCK_NUMBER)
    }
}

/// Direct Prometheus collector handles used by the driver.
static METRICS: Lazy<DriverMetricHandles> = Lazy::new(DriverMetricHandles::new);

/// Typed direct-Prometheus collectors owned by the driver crate.
struct DriverMetricHandles {
    /// Driver counters keyed by their stable exported names.
    counters: Vec<(&'static str, IntCounter)>,
    /// Driver gauges keyed by their stable exported names.
    gauges: Vec<(&'static str, Gauge)>,
    /// Driver histograms keyed by their stable exported names.
    histograms: Vec<(&'static str, Histogram)>,
}

impl DriverMetricHandles {
    /// Construct and register all driver collectors.
    fn new() -> Self {
        Self {
            counters: vec![
                counter(
                    DriverMetrics::BEACON_SYNC_REMOTE_SUBMISSIONS_TOTAL,
                    "Checkpoint blocks submitted during beacon sync",
                ),
                counter(
                    DriverMetrics::EVENT_SCANNER_BATCHES_TOTAL,
                    "Proposal log batches received from the event scanner",
                ),
                counter(
                    DriverMetrics::EVENT_SCANNER_ERRORS_TOTAL,
                    "Errors emitted by the event scanner stream",
                ),
                counter(
                    DriverMetrics::EVENT_CONFIRMED_SYNC_PROBE_ERRORS_TOTAL,
                    "Errors emitted while probing confirmed-sync readiness in event sync",
                ),
                counter(
                    DriverMetrics::EVENT_PROPOSALS_TOTAL,
                    "Total proposal logs dispatched to derivation",
                ),
                counter(
                    DriverMetrics::EVENT_PROPOSALS_SKIPPED_TOTAL,
                    "Proposal logs skipped before derivation",
                ),
                counter(
                    DriverMetrics::EVENT_ORPHANED_PROPOSAL_LOGS_TOTAL,
                    "Proposal logs skipped because their source L1 block was reorged away",
                ),
                counter(
                    DriverMetrics::EVENT_DERIVED_BLOCKS_TOTAL,
                    "L2 blocks derived or confirmed from proposals",
                ),
                counter(
                    DriverMetrics::DERIVATION_CANONICAL_HITS_TOTAL,
                    "Proposals resolved via canonical block detection",
                ),
                counter(
                    DriverMetrics::DERIVATION_L1_ORIGIN_UPDATES_TOTAL,
                    "L1 origin updates written during derivation",
                ),
                counter(
                    DriverMetrics::PRECONF_INJECTION_FAILURES_TOTAL,
                    "Preconfirmation payload injections that failed",
                ),
                counter(
                    DriverMetrics::PRECONF_INJECTION_SUCCESS_TOTAL,
                    "Preconfirmation payload injections that succeeded",
                ),
                counter(
                    DriverMetrics::PRECONF_ENQUEUE_TIMEOUTS_TOTAL,
                    "Preconfirmation enqueue operations that timed out",
                ),
                counter(
                    DriverMetrics::PRECONF_RESPONSE_TIMEOUTS_TOTAL,
                    "Preconfirmation response waits that timed out",
                ),
                counter(
                    DriverMetrics::PRECONF_ENQUEUE_FAILURES_TOTAL,
                    "Preconfirmation enqueue operations that failed",
                ),
                counter(
                    DriverMetrics::PRECONF_RESPONSE_DROPPED_TOTAL,
                    "Preconfirmation responses dropped due to channel closure",
                ),
                counter(
                    DriverMetrics::PRECONF_STALE_DROPPED_TOTAL,
                    "Aggregate stale preconfirmation payload drops across all decision points",
                ),
                counter(
                    DriverMetrics::PRECONF_STALE_DROPPED_BEFORE_ENQUEUE_TOTAL,
                    "Stale preconfirmation payloads dropped before enqueue",
                ),
                counter(
                    DriverMetrics::PRECONF_STALE_DROPPED_INGRESS_TOTAL,
                    "Stale preconfirmation payloads dropped in the ingress loop",
                ),
                counter(
                    DriverMetrics::PRECONF_STALE_DROPPED_PRODUCTION_TOTAL,
                    "Stale preconfirmation payloads dropped in the production path",
                ),
                counter(
                    DriverMetrics::PRECONF_PARENT_HASH_LOOKUP_FAILURES_TOTAL,
                    "Parent hash lookup failures during preconfirmation",
                ),
            ],
            gauges: vec![
                gauge(
                    DriverMetrics::BEACON_SYNC_LOCAL_HEAD_BLOCK,
                    "Latest L2 head height observed during beacon sync",
                ),
                gauge(
                    DriverMetrics::BEACON_SYNC_CHECKPOINT_HEAD_BLOCK,
                    "Checkpoint node head height sampled during beacon sync",
                ),
                gauge(
                    DriverMetrics::BEACON_SYNC_HEAD_LAG_BLOCKS,
                    "Checkpoint vs local head lag tracked by beacon sync",
                ),
                gauge(
                    DriverMetrics::DERIVATION_LAST_FINALIZED_PROPOSAL_ID,
                    "Last finalized proposal id observed from the core state",
                ),
                gauge(
                    DriverMetrics::PRECONF_QUEUE_DEPTH,
                    "Buffered preconfirmation jobs awaiting processing",
                ),
                gauge(
                    DriverMetrics::EVENT_LAST_CANONICAL_PROPOSAL_ID,
                    "Last canonical proposal id processed from L1 events",
                ),
                gauge(
                    DriverMetrics::EVENT_LAST_CANONICAL_BLOCK_NUMBER,
                    "Last canonical L2 block number produced from L1 events",
                ),
            ],
            histograms: vec![
                histogram(
                    DriverMetrics::PRECONF_INJECTION_DURATION_SECONDS,
                    "Wall-clock time to process a preconfirmation payload",
                    DURATION_SECONDS_BUCKETS,
                ),
                histogram(
                    DriverMetrics::PRECONF_RETRY_ATTEMPTS,
                    "Retry attempts per preconfirmation payload",
                    RETRY_ATTEMPT_BUCKETS,
                ),
                histogram(
                    DriverMetrics::PRECONF_PARENT_HASH_LOOKUP_DURATION_SECONDS,
                    "Duration of parent hash lookups for preconfirmation",
                    DURATION_SECONDS_BUCKETS,
                ),
            ],
        }
    }

    /// Resolve a registered counter.
    fn counter(&self, name: &str) -> &IntCounter {
        find(&self.counters, name)
    }

    /// Resolve a registered gauge.
    fn gauge(&self, name: &str) -> &Gauge {
        find(&self.gauges, name)
    }

    /// Resolve a registered histogram.
    fn histogram(&self, name: &str) -> &Histogram {
        find(&self.histograms, name)
    }
}

/// Construct and register an integer counter.
fn counter(name: &'static str, help: &'static str) -> (&'static str, IntCounter) {
    let metric = IntCounter::new(name, help)
        .unwrap_or_else(|error| panic!("failed to create Prometheus counter {name}: {error}"));
    register(metric.clone());
    (name, metric)
}

/// Construct and register a floating-point gauge.
fn gauge(name: &'static str, help: &'static str) -> (&'static str, Gauge) {
    let metric = Gauge::new(name, help)
        .unwrap_or_else(|error| panic!("failed to create Prometheus gauge {name}: {error}"));
    register(metric.clone());
    (name, metric)
}

/// Construct and register a histogram.
fn histogram(name: &'static str, help: &'static str, buckets: &[f64]) -> (&'static str, Histogram) {
    let metric =
        Histogram::with_opts(prometheus::HistogramOpts::new(name, help).buckets(buckets.to_vec()))
            .unwrap_or_else(|error| {
                panic!("failed to create Prometheus histogram {name}: {error}")
            });
    register(metric.clone());
    (name, metric)
}

/// Register one collector with the process-wide Prometheus registry.
fn register<C>(collector: C)
where
    C: Collector + Clone + 'static,
{
    prometheus::register(Box::new(collector))
        .unwrap_or_else(|error| panic!("failed to register Prometheus collector: {error}"));
}

/// Find a collector by its exported metric name.
fn find<'a, C>(collectors: &'a [(&str, C)], name: &str) -> &'a C {
    collectors
        .iter()
        .find_map(|(metric_name, collector)| (*metric_name == name).then_some(collector))
        .unwrap_or_else(|| panic!("unknown driver metric: {name}"))
}

#[cfg(test)]
mod tests {
    use super::DriverMetrics;

    #[test]
    fn stale_drop_metrics_are_split_by_location() {
        let submit = DriverMetrics::PRECONF_STALE_DROPPED_BEFORE_ENQUEUE_TOTAL;
        let ingress = DriverMetrics::PRECONF_STALE_DROPPED_INGRESS_TOTAL;
        let production = DriverMetrics::PRECONF_STALE_DROPPED_PRODUCTION_TOTAL;

        assert_ne!(submit, ingress, "submit and ingress stale-drop metrics must differ");
        assert_ne!(submit, production, "submit and production stale-drop metrics must differ");
        assert_ne!(ingress, production, "ingress and production stale-drop metrics must differ");
    }

    #[test]
    fn duration_histograms_include_long_running_operation_buckets() {
        DriverMetrics::init();

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| family.get_name() == DriverMetrics::PRECONF_INJECTION_DURATION_SECONDS)
            .expect("preconfirmation injection duration histogram should be exported");
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
