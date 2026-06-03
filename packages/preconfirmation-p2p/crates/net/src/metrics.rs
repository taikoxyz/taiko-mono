//! Direct Prometheus collectors for the preconfirmation P2P stack.

use once_cell::sync::Lazy;
use prometheus::{
    Gauge, HistogramOpts, HistogramVec, IntCounter, IntCounterVec, Opts, core::Collector,
};

/// Increment a registered scalar counter.
pub(crate) fn inc(name: &'static str) {
    counter_handle(name).inc();
}

/// Increment a registered labelled counter.
pub(crate) fn inc_vec(name: &'static str, labels: &[&str]) {
    counter_vec_handle(name).with_label_values(labels).inc();
}

/// Set a registered scalar gauge.
pub(crate) fn set_gauge(name: &'static str, value: f64) {
    gauge_handle(name).set(value);
}

/// Observe a registered labelled histogram.
pub(crate) fn observe_vec(name: &'static str, labels: &[&str], value: f64) {
    histogram_vec_handle(name).with_label_values(labels).observe(value);
}

/// Return a registered scalar counter by exported name.
fn counter_handle(name: &'static str) -> IntCounter {
    find(&METRICS.counters, name)
}

/// Return a registered labelled counter family by exported name.
fn counter_vec_handle(name: &'static str) -> IntCounterVec {
    find(&METRICS.counter_vecs, name)
}

/// Return a registered scalar gauge by exported name.
fn gauge_handle(name: &'static str) -> Gauge {
    find(&METRICS.gauges, name)
}

/// Return a registered labelled histogram family by exported name.
fn histogram_vec_handle(name: &'static str) -> HistogramVec {
    find(&METRICS.histogram_vecs, name)
}

/// Process-wide P2P collectors registered lazily with Prometheus.
static METRICS: Lazy<P2pMetricHandles> = Lazy::new(P2pMetricHandles::register);

/// Typed handles for P2P metric families.
struct P2pMetricHandles {
    /// Scalar counters without labels.
    counters: Vec<(&'static str, IntCounter)>,
    /// Labelled counter families.
    counter_vecs: Vec<(&'static str, IntCounterVec)>,
    /// Scalar gauges without labels.
    gauges: Vec<(&'static str, Gauge)>,
    /// Labelled histogram families.
    histogram_vecs: Vec<(&'static str, HistogramVec)>,
}

impl P2pMetricHandles {
    /// Register every P2P collector with the default registry.
    fn register() -> Self {
        Self {
            counters: vec![
                counter("p2p_gossip_dropped_banned", "Gossip messages dropped from banned peers"),
                counter("p2p_reputation_ban", "Peers newly marked as banned"),
                counter("p2p_reputation_greylist", "Peers newly marked as greylisted"),
            ],
            counter_vecs: vec![
                counter_vec(
                    "p2p_conn_error",
                    "Connection errors by direction and reason",
                    &["direction", "reason"],
                ),
                counter_vec(
                    "p2p_conn_rejected_total",
                    "Rejected connections by direction and reason",
                    &["direction", "reason"],
                ),
                counter_vec(
                    "p2p_dial_throttled_total",
                    "Throttled dial attempts by reason",
                    &["reason"],
                ),
                counter_vec(
                    "p2p_gossip_publish_error",
                    "Gossip publish errors by payload kind",
                    &["kind"],
                ),
                counter_vec(
                    "p2p_reqresp_error",
                    "Request-response errors by kind and reason",
                    &["kind", "reason"],
                ),
                counter_vec("p2p_gossip_valid", "Valid gossip messages by payload kind", &["kind"]),
                counter_vec(
                    "p2p_gossip_invalid",
                    "Invalid gossip messages by kind and reason",
                    &["kind", "reason"],
                ),
                counter_vec("p2p_dial_blocked", "Blocked dial attempts by source", &["source"]),
                counter_vec("p2p_discovery_event", "Discovery events by kind", &["kind"]),
                counter_vec(
                    "p2p_event_dropped",
                    "Dropped network events by surface, reason, and kind",
                    &["surface", "reason", "kind"],
                ),
                counter_vec(
                    "p2p_reqresp_dropped",
                    "Dropped request-response messages by kind and reason",
                    &["kind", "reason"],
                ),
                counter_vec(
                    "p2p_reqresp_rate_limited",
                    "Rate-limited request-response messages by kind",
                    &["kind"],
                ),
                counter_vec(
                    "p2p_reqresp_success",
                    "Successful request-response messages by kind and direction",
                    &["kind", "direction"],
                ),
                counter_vec(
                    "p2p_reqresp_not_found",
                    "Request-response lookups missing data by kind and direction",
                    &["kind", "direction"],
                ),
            ],
            gauges: vec![gauge("p2p_connected_peers", "Number of currently connected peers")],
            histogram_vecs: vec![
                histogram_vec(
                    "p2p_discovery_lookup_latency_seconds",
                    "Discovery lookup latency by outcome",
                    &["outcome"],
                ),
                histogram_vec(
                    "p2p_reqresp_rtt_seconds",
                    "Request-response round-trip time by protocol and outcome",
                    &["protocol", "outcome"],
                ),
            ],
        }
    }
}

/// Register a scalar counter and return it with its exported name.
fn counter(name: &'static str, help: &'static str) -> (&'static str, IntCounter) {
    let metric = IntCounter::new(name, help).expect("valid counter definition");
    register(metric.clone());
    (name, metric)
}

/// Register a labelled counter family and return it with its exported name.
fn counter_vec(
    name: &'static str,
    help: &'static str,
    labels: &'static [&'static str],
) -> (&'static str, IntCounterVec) {
    let metric =
        IntCounterVec::new(Opts::new(name, help), labels).expect("valid counter definition");
    register(metric.clone());
    (name, metric)
}

/// Register a scalar gauge and return it with its exported name.
fn gauge(name: &'static str, help: &'static str) -> (&'static str, Gauge) {
    let metric = Gauge::new(name, help).expect("valid gauge definition");
    register(metric.clone());
    (name, metric)
}

/// Register a labelled histogram family and return it with its exported name.
fn histogram_vec(
    name: &'static str,
    help: &'static str,
    labels: &'static [&'static str],
) -> (&'static str, HistogramVec) {
    let metric = HistogramVec::new(HistogramOpts::new(name, help), labels)
        .expect("valid histogram definition");
    register(metric.clone());
    (name, metric)
}

/// Register one collector with the process-wide Prometheus registry.
fn register<C>(collector: C)
where
    C: Collector + Clone + 'static,
{
    prometheus::register(Box::new(collector)).expect("collector registration must succeed");
}

/// Clone a registered collector by exported metric name.
fn find<T: Clone>(metrics: &[(&'static str, T)], name: &'static str) -> T {
    metrics
        .iter()
        .find(|(metric_name, _)| *metric_name == name)
        .expect("registered metric")
        .1
        .clone()
}
