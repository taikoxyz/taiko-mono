//! Metrics helpers for the P2P client.
//!
//! This module centralizes metric names and small helper functions so callers
//! can instrument events consistently without duplicating label sets.

use metrics::{counter, describe_counter, describe_gauge, describe_histogram, gauge, histogram};

use crate::validation::ValidationOutcome;

/// Metric name constants used across the client.
#[derive(Debug, Clone, Copy)]
pub struct P2pMetrics;

impl P2pMetrics {
    /// Counter: gossip messages by topic/direction/outcome.
    pub const GOSSIP_MESSAGES_TOTAL: &'static str = "taiko_p2p_gossip_messages_total";
    /// Counter: gossip bytes by topic/direction/outcome.
    pub const GOSSIP_BYTES_TOTAL: &'static str = "taiko_p2p_gossip_bytes_total";
    /// Counter: validation outcomes by reason.
    pub const VALIDATION_OUTCOMES_TOTAL: &'static str = "taiko_p2p_validation_outcomes_total";
    /// Counter: cache accesses by kind/hit.
    pub const CACHE_ACCESSES_TOTAL: &'static str = "taiko_p2p_cache_accesses_total";
    /// Histogram: req/resp latency in seconds by protocol/outcome.
    pub const REQRESP_LATENCY_SECONDS: &'static str = "taiko_p2p_reqresp_latency_seconds";
    /// Counter: req/resp outcomes by protocol/outcome.
    pub const REQRESP_OUTCOMES_TOTAL: &'static str = "taiko_p2p_reqresp_outcomes_total";
    /// Gauge: latest local head height observed during head sync.
    pub const HEAD_SYNC_LOCAL: &'static str = "taiko_p2p_head_sync_local";
    /// Gauge: target head height discovered during head sync.
    pub const HEAD_SYNC_REMOTE: &'static str = "taiko_p2p_head_sync_remote";
    /// Gauge: placeholder for peer score snapshots.
    pub const PEER_SCORE_GAUGE: &'static str = "taiko_p2p_peer_score";
}

/// Describe all metrics to make exporters self-documenting.
pub fn register_metrics() {
    describe_counter!(
        P2pMetrics::GOSSIP_MESSAGES_TOTAL,
        "Count of gossip messages by topic, direction, and outcome."
    );
    describe_counter!(
        P2pMetrics::GOSSIP_BYTES_TOTAL,
        "Sum of gossip payload bytes by topic, direction, and outcome."
    );
    describe_counter!(
        P2pMetrics::VALIDATION_OUTCOMES_TOTAL,
        "Count of validation outcomes by reason."
    );
    describe_counter!(
        P2pMetrics::CACHE_ACCESSES_TOTAL,
        "Count of cache accesses by kind and hit/miss."
    );
    describe_counter!(
        P2pMetrics::REQRESP_OUTCOMES_TOTAL,
        "Count of req/resp outcomes by protocol and result."
    );
    describe_histogram!(
        P2pMetrics::REQRESP_LATENCY_SECONDS,
        "Request/response latency in seconds by protocol and outcome."
    );
    describe_gauge!(
        P2pMetrics::HEAD_SYNC_LOCAL,
        "Current local preconfirmation head during head sync."
    );
    describe_gauge!(
        P2pMetrics::HEAD_SYNC_REMOTE,
        "Remote target preconfirmation head during head sync."
    );
    describe_gauge!(P2pMetrics::PEER_SCORE_GAUGE, "Peer score snapshot (if exposed by driver).");
}

/// Record a gossip observation.
pub fn record_gossip(direction: &str, topic: &str, outcome: &str, bytes: usize) {
    let dir = direction.to_owned();
    let topic_v = topic.to_owned();
    let outcome_v = outcome.to_owned();
    counter!(P2pMetrics::GOSSIP_MESSAGES_TOTAL, "direction" => dir.clone(), "topic" => topic_v.clone(), "outcome" => outcome_v.clone()).increment(1);
    counter!(P2pMetrics::GOSSIP_BYTES_TOTAL, "direction" => dir, "topic" => topic_v, "outcome" => outcome_v).increment(bytes as u64);
}

/// Record a validation result.
pub fn record_validation(outcome: &ValidationOutcome) {
    let (reason, penalize) = match outcome {
        ValidationOutcome::Accept => ("accept", false),
        ValidationOutcome::IgnoreSelf => ("ignore_self", false),
        ValidationOutcome::SoftReject { reason, .. } => (*reason, false),
        ValidationOutcome::RejectPeer { reason, .. } => (*reason, true),
    };
    counter!(P2pMetrics::VALIDATION_OUTCOMES_TOTAL, "reason" => reason, "penalize" => penalize.to_string()).increment(1);
}

/// Record a cache access hit or miss for the given kind.
pub fn record_cache(kind: &str, hit: bool) {
    let kind_v = kind.to_owned();
    let outcome_v = if hit { "hit" } else { "miss" };
    counter!(P2pMetrics::CACHE_ACCESSES_TOTAL, "kind" => kind_v, "outcome" => outcome_v)
        .increment(1);
}

/// Record a req/resp latency in seconds.
pub fn record_reqresp_latency(protocol: &str, outcome: &str, seconds: f64) {
    let proto = protocol.to_owned();
    let out = outcome.to_owned();
    histogram!(P2pMetrics::REQRESP_LATENCY_SECONDS, "protocol" => proto, "outcome" => out)
        .record(seconds);
}

/// Record a req/resp outcome counter.
pub fn record_reqresp_outcome(protocol: &str, outcome: &str) {
    let proto = protocol.to_owned();
    let out = outcome.to_owned();
    counter!(P2pMetrics::REQRESP_OUTCOMES_TOTAL, "protocol" => proto, "outcome" => out)
        .increment(1);
}

/// Update the peer score gauge (placeholder for future driver integration).
pub fn set_peer_score(score: f64) {
    gauge!(P2pMetrics::PEER_SCORE_GAUGE).set(score);
}

/// Update head sync gauges for observability.
pub fn set_head_sync(local: u64, remote: u64) {
    gauge!(P2pMetrics::HEAD_SYNC_LOCAL).set(local as f64);
    gauge!(P2pMetrics::HEAD_SYNC_REMOTE).set(remote as f64);
}
