//! Metrics exposed by the driver runtime.

use once_cell::sync::Lazy;
use prometheus::{Gauge, Histogram, IntCounter};
use protocol::metrics::{DURATION_SECONDS_BUCKETS, counter, gauge, histogram};

/// Metric namespace for the driver.
pub struct DriverMetrics;

impl DriverMetrics {
    /// Register direct Prometheus collectors.
    pub fn init() {
        Lazy::force(&METRICS);
    }

    /// Return the local beacon-sync head gauge.
    pub(crate) fn beacon_sync_local_head_block() -> &'static Gauge {
        &METRICS.beacon_sync_local_head_block
    }

    /// Return the checkpoint beacon-sync head gauge.
    pub(crate) fn beacon_sync_checkpoint_head_block() -> &'static Gauge {
        &METRICS.beacon_sync_checkpoint_head_block
    }

    /// Return the beacon-sync head lag gauge.
    pub(crate) fn beacon_sync_head_lag_blocks() -> &'static Gauge {
        &METRICS.beacon_sync_head_lag_blocks
    }

    /// Return the beacon-sync remote submissions counter.
    pub(crate) fn beacon_sync_remote_submissions_total() -> &'static IntCounter {
        &METRICS.beacon_sync_remote_submissions_total
    }

    /// Return the event scanner batch counter.
    pub(crate) fn event_scanner_batches_total() -> &'static IntCounter {
        &METRICS.event_scanner_batches_total
    }

    /// Return the event scanner error counter.
    pub(crate) fn event_scanner_errors_total() -> &'static IntCounter {
        &METRICS.event_scanner_errors_total
    }

    /// Return the confirmed-sync probe error counter.
    pub(crate) fn event_confirmed_sync_probe_errors_total() -> &'static IntCounter {
        &METRICS.event_confirmed_sync_probe_errors_total
    }

    /// Return the proposal log counter.
    pub(crate) fn event_proposals_total() -> &'static IntCounter {
        &METRICS.event_proposals_total
    }

    /// Return the skipped proposal counter.
    pub(crate) fn event_proposals_skipped_total() -> &'static IntCounter {
        &METRICS.event_proposals_skipped_total
    }

    /// Return the orphaned proposal log counter.
    pub(crate) fn event_orphaned_proposal_logs_total() -> &'static IntCounter {
        &METRICS.event_orphaned_proposal_logs_total
    }

    /// Return the derived event block counter.
    pub(crate) fn event_derived_blocks_total() -> &'static IntCounter {
        &METRICS.event_derived_blocks_total
    }

    /// Return the canonical derivation hit counter.
    pub(crate) fn derivation_canonical_hits_total() -> &'static IntCounter {
        &METRICS.derivation_canonical_hits_total
    }

    /// Return the L1 origin update counter.
    pub(crate) fn derivation_l1_origin_updates_total() -> &'static IntCounter {
        &METRICS.derivation_l1_origin_updates_total
    }

    /// Return the finalized proposal id gauge.
    pub(crate) fn derivation_last_finalized_proposal_id() -> &'static Gauge {
        &METRICS.derivation_last_finalized_proposal_id
    }

    /// Return the successful preconfirmation injection counter.
    pub(crate) fn preconf_injection_success_total() -> &'static IntCounter {
        &METRICS.preconf_injection_success_total
    }

    /// Return the failed preconfirmation injection counter.
    pub(crate) fn preconf_injection_failures_total() -> &'static IntCounter {
        &METRICS.preconf_injection_failures_total
    }

    /// Return the preconfirmation injection duration histogram.
    pub(crate) fn preconf_injection_duration_seconds() -> &'static Histogram {
        &METRICS.preconf_injection_duration_seconds
    }

    /// Return the preconfirmation queue depth gauge.
    pub(crate) fn preconf_queue_depth() -> &'static Gauge {
        &METRICS.preconf_queue_depth
    }

    /// Return the preconfirmation enqueue timeout counter.
    pub(crate) fn preconf_enqueue_timeouts_total() -> &'static IntCounter {
        &METRICS.preconf_enqueue_timeouts_total
    }

    /// Return the preconfirmation enqueue failure counter.
    pub(crate) fn preconf_enqueue_failures_total() -> &'static IntCounter {
        &METRICS.preconf_enqueue_failures_total
    }

    /// Return the preconfirmation response timeout counter.
    pub(crate) fn preconf_response_timeouts_total() -> &'static IntCounter {
        &METRICS.preconf_response_timeouts_total
    }

    /// Return the dropped preconfirmation response counter.
    pub(crate) fn preconf_response_dropped_total() -> &'static IntCounter {
        &METRICS.preconf_response_dropped_total
    }

    /// Return the aggregate stale preconfirmation drop counter.
    pub(crate) fn preconf_stale_dropped_total() -> &'static IntCounter {
        &METRICS.preconf_stale_dropped_total
    }

    /// Return the before-enqueue stale preconfirmation drop counter.
    pub(crate) fn preconf_stale_dropped_before_enqueue_total() -> &'static IntCounter {
        &METRICS.preconf_stale_dropped_before_enqueue_total
    }

    /// Return the ingress stale preconfirmation drop counter.
    pub(crate) fn preconf_stale_dropped_ingress_total() -> &'static IntCounter {
        &METRICS.preconf_stale_dropped_ingress_total
    }

    /// Return the parent hash lookup duration histogram.
    pub(crate) fn preconf_parent_hash_lookup_duration_seconds() -> &'static Histogram {
        &METRICS.preconf_parent_hash_lookup_duration_seconds
    }

    /// Return the parent hash lookup failure counter.
    pub(crate) fn preconf_parent_hash_lookup_failures_total() -> &'static IntCounter {
        &METRICS.preconf_parent_hash_lookup_failures_total
    }

    /// Return the last canonical event proposal id gauge.
    pub(crate) fn event_last_canonical_proposal_id() -> &'static Gauge {
        &METRICS.event_last_canonical_proposal_id
    }

    /// Return the last canonical event block number gauge.
    pub(crate) fn event_last_canonical_block_number() -> &'static Gauge {
        &METRICS.event_last_canonical_block_number
    }
}

/// Direct Prometheus collector handles used by the driver.
static METRICS: Lazy<DriverMetricHandles> = Lazy::new(DriverMetricHandles::new);

/// Typed direct-Prometheus collectors owned by the driver crate.
struct DriverMetricHandles {
    /// Latest L2 head observed on the execution engine during beacon sync.
    beacon_sync_local_head_block: Gauge,
    /// Proof-finalized sync target block height read from the L1 inbox.
    beacon_sync_checkpoint_head_block: Gauge,
    /// Delta between the sync target and the local head.
    beacon_sync_head_lag_blocks: Gauge,
    /// Submitted checkpoint blocks.
    beacon_sync_remote_submissions_total: IntCounter,
    /// Batches of proposal logs received from the scanner.
    event_scanner_batches_total: IntCounter,
    /// Scanner stream errors.
    event_scanner_errors_total: IntCounter,
    /// Failures while probing confirmed-sync readiness.
    event_confirmed_sync_probe_errors_total: IntCounter,
    /// Proposal logs processed by the driver.
    event_proposals_total: IntCounter,
    /// Skipped proposals.
    event_proposals_skipped_total: IntCounter,
    /// Orphaned proposal logs skipped after L1 reorg detection.
    event_orphaned_proposal_logs_total: IntCounter,
    /// Derived or confirmed L2 blocks per proposal.
    event_derived_blocks_total: IntCounter,
    /// Proposals resolved entirely via canonical chain detection.
    derivation_canonical_hits_total: IntCounter,
    /// L1 origin rows written to the execution engine database.
    derivation_l1_origin_updates_total: IntCounter,
    /// Last finalized proposal id advertised by the inbox core state.
    derivation_last_finalized_proposal_id: Gauge,
    /// Successful preconfirmation payload injections.
    preconf_injection_success_total: IntCounter,
    /// Failed preconfirmation payload injections.
    preconf_injection_failures_total: IntCounter,
    /// End-to-end latency per preconfirmation payload.
    preconf_injection_duration_seconds: Histogram,
    /// Buffered preconfirmation jobs awaiting processing.
    preconf_queue_depth: Gauge,
    /// Preconfirmation enqueue timeouts.
    preconf_enqueue_timeouts_total: IntCounter,
    /// Preconfirmation enqueue failures.
    preconf_enqueue_failures_total: IntCounter,
    /// Preconfirmation response timeouts.
    preconf_response_timeouts_total: IntCounter,
    /// Preconfirmation responses dropped because the channel closed.
    preconf_response_dropped_total: IntCounter,
    /// Stale preconfirmation payloads dropped before processing.
    preconf_stale_dropped_total: IntCounter,
    /// Stale preconfirmation payloads dropped before enqueue.
    preconf_stale_dropped_before_enqueue_total: IntCounter,
    /// Stale preconfirmation payloads dropped in ingress processing.
    preconf_stale_dropped_ingress_total: IntCounter,
    /// Parent hash lookup duration.
    preconf_parent_hash_lookup_duration_seconds: Histogram,
    /// Parent hash lookup failures.
    preconf_parent_hash_lookup_failures_total: IntCounter,
    /// Last canonical proposal id from L1 events.
    event_last_canonical_proposal_id: Gauge,
    /// Last canonical L2 block number produced from L1 events.
    event_last_canonical_block_number: Gauge,
}

impl DriverMetricHandles {
    /// Construct and register all driver collectors.
    fn new() -> Self {
        Self {
            beacon_sync_local_head_block: gauge(
                "driver_beacon_sync_local_head_block",
                "Latest L2 head height observed during beacon sync",
            ),
            beacon_sync_checkpoint_head_block: gauge(
                "driver_beacon_sync_checkpoint_head_block",
                "Proof-finalized sync target block height read from the L1 inbox",
            ),
            beacon_sync_head_lag_blocks: gauge(
                "driver_beacon_sync_head_lag_blocks",
                "Sync target vs local head lag tracked by beacon sync",
            ),
            beacon_sync_remote_submissions_total: counter(
                "driver_beacon_sync_remote_submissions_total",
                "Checkpoint blocks submitted during beacon sync",
            ),
            event_scanner_batches_total: counter(
                "driver_event_scanner_batches_total",
                "Proposal log batches received from the event scanner",
            ),
            event_scanner_errors_total: counter(
                "driver_event_scanner_errors_total",
                "Errors emitted by the event scanner stream",
            ),
            event_confirmed_sync_probe_errors_total: counter(
                "driver_event_confirmed_sync_probe_errors_total",
                "Errors emitted while probing confirmed-sync readiness in event sync",
            ),
            event_proposals_total: counter(
                "driver_event_proposals_total",
                "Total proposal logs dispatched to derivation",
            ),
            event_proposals_skipped_total: counter(
                "driver_event_proposals_skipped_total",
                "Proposal logs skipped before derivation",
            ),
            event_orphaned_proposal_logs_total: counter(
                "driver_event_orphaned_proposal_logs_total",
                "Proposal logs skipped because their source L1 block was reorged away",
            ),
            event_derived_blocks_total: counter(
                "driver_event_derived_blocks_total",
                "L2 blocks derived or confirmed from proposals",
            ),
            derivation_canonical_hits_total: counter(
                "driver_derivation_canonical_hits_total",
                "Proposals resolved via canonical block detection",
            ),
            derivation_l1_origin_updates_total: counter(
                "driver_derivation_l1_origin_updates_total",
                "L1 origin updates written during derivation",
            ),
            derivation_last_finalized_proposal_id: gauge(
                "driver_derivation_last_finalized_proposal_id",
                "Last finalized proposal id observed from the core state",
            ),
            preconf_injection_success_total: counter(
                "driver_preconf_injection_success_total",
                "Preconfirmation payload injections that succeeded",
            ),
            preconf_injection_failures_total: counter(
                "driver_preconf_injection_failures_total",
                "Preconfirmation payload injections that failed",
            ),
            preconf_injection_duration_seconds: histogram(
                "driver_preconf_injection_duration_seconds",
                "Wall-clock time to process a preconfirmation payload",
                DURATION_SECONDS_BUCKETS,
            ),
            preconf_queue_depth: gauge(
                "driver_preconf_queue_depth",
                "Buffered preconfirmation jobs awaiting processing",
            ),
            preconf_enqueue_timeouts_total: counter(
                "driver_preconf_enqueue_timeouts_total",
                "Preconfirmation enqueue operations that timed out",
            ),
            preconf_enqueue_failures_total: counter(
                "driver_preconf_enqueue_failures_total",
                "Preconfirmation enqueue operations that failed",
            ),
            preconf_response_timeouts_total: counter(
                "driver_preconf_response_timeouts_total",
                "Preconfirmation response waits that timed out",
            ),
            preconf_response_dropped_total: counter(
                "driver_preconf_response_dropped_total",
                "Preconfirmation responses dropped due to channel closure",
            ),
            preconf_stale_dropped_total: counter(
                "driver_preconf_stale_dropped_total",
                "Aggregate stale preconfirmation payload drops across all decision points",
            ),
            preconf_stale_dropped_before_enqueue_total: counter(
                "driver_preconf_stale_dropped_before_enqueue_total",
                "Stale preconfirmation payloads dropped before enqueue",
            ),
            preconf_stale_dropped_ingress_total: counter(
                "driver_preconf_stale_dropped_ingress_total",
                "Stale preconfirmation payloads dropped in the ingress loop",
            ),
            preconf_parent_hash_lookup_duration_seconds: histogram(
                "driver_preconf_parent_hash_lookup_duration_seconds",
                "Duration of parent hash lookups for preconfirmation",
                DURATION_SECONDS_BUCKETS,
            ),
            preconf_parent_hash_lookup_failures_total: counter(
                "driver_preconf_parent_hash_lookup_failures_total",
                "Parent hash lookup failures during preconfirmation",
            ),
            event_last_canonical_proposal_id: gauge(
                "driver_event_last_canonical_proposal_id",
                "Last canonical proposal id processed from L1 events",
            ),
            event_last_canonical_block_number: gauge(
                "driver_event_last_canonical_block_number",
                "Last canonical L2 block number produced from L1 events",
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::DriverMetrics;

    #[test]
    fn duration_histograms_include_long_running_operation_buckets() {
        DriverMetrics::init();

        let families = prometheus::gather();
        let family = families
            .iter()
            .find(|family| family.get_name() == "driver_preconf_injection_duration_seconds")
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
