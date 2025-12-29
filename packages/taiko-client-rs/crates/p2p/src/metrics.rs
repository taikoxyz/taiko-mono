//! Metrics for the P2P SDK.
//!
//! This module provides metric definitions and recording for gossip,
//! validation, request/response, and cache operations.
//!
//! Metrics exposed:
//! - Gossip: received/published counts by message type
//! - Validation: outcome counts (valid/pending/invalid)
//! - Request/Response: latency histograms and outcome counts
//! - Cache: dedupe hits, pending buffer size
//! - Head sync: current head gauge, sync status

use std::sync::Once;

use metrics::Unit;

/// Guard to ensure metrics are initialized only once.
static INIT_ONCE: Once = Once::new();

/// Metric namespace for the P2P SDK.
pub struct P2pMetrics;

impl P2pMetrics {
    // --- Gossip metrics ---

    /// Counter: gossip messages received by type (commitment, txlist).
    pub const GOSSIP_RECEIVED_TOTAL: &'static str = "p2p_gossip_received_total";
    /// Counter: gossip messages published by type.
    pub const GOSSIP_PUBLISHED_TOTAL: &'static str = "p2p_gossip_published_total";
    /// Counter: gossip messages stored after validation.
    pub const GOSSIP_STORED_TOTAL: &'static str = "p2p_gossip_stored_total";

    // --- Validation metrics ---

    /// Counter: validation outcomes by result (valid, pending, invalid).
    pub const VALIDATION_RESULTS_TOTAL: &'static str = "p2p_validation_results_total";

    // --- Execution metrics ---

    /// Counter: commitments successfully applied to the execution engine.
    pub const EXECUTION_APPLIED_TOTAL: &'static str = "p2p_execution_applied_total";
    /// Counter: commitments pending due to missing parents.
    pub const EXECUTION_PENDING_PARENT_TOTAL: &'static str = "p2p_execution_pending_parent_total";
    /// Counter: commitments pending due to missing txlists.
    pub const EXECUTION_PENDING_TXLIST_TOTAL: &'static str = "p2p_execution_pending_txlist_total";
    /// Counter: execution engine errors while applying commitments.
    pub const EXECUTION_ERRORS_TOTAL: &'static str = "p2p_execution_errors_total";
    /// Gauge: current number of commitments waiting on txlist data.
    pub const PENDING_TXLIST_BUFFER_SIZE: &'static str = "p2p_pending_txlist_buffer_size";

    // --- Dedupe/cache metrics ---

    /// Counter: dedupe cache hits by type (message, commitment, txlist).
    pub const DEDUPE_HITS_TOTAL: &'static str = "p2p_dedupe_hits_total";
    /// Gauge: current number of pending commitments awaiting parents.
    pub const PENDING_BUFFER_SIZE: &'static str = "p2p_pending_buffer_size";
    /// Counter: commitments released from pending buffer.
    pub const PENDING_RELEASED_TOTAL: &'static str = "p2p_pending_released_total";
    /// Counter: commitments added to pending buffer.
    pub const PENDING_BUFFERED_TOTAL: &'static str = "p2p_pending_buffered_total";

    // --- Request/Response metrics ---

    /// Counter: req/resp messages received by type.
    pub const REQRESP_RECEIVED_TOTAL: &'static str = "p2p_reqresp_received_total";
    /// Counter: req/resp messages sent by type.
    pub const REQRESP_SENT_TOTAL: &'static str = "p2p_reqresp_sent_total";
    /// Counter: inbound requests handled by type.
    pub const INBOUND_REQUESTS_TOTAL: &'static str = "p2p_inbound_requests_total";
    /// Histogram: req/resp latency in seconds by type.
    pub const REQRESP_LATENCY_SECONDS: &'static str = "p2p_reqresp_latency_seconds";
    /// Counter: req/resp failures by type and reason.
    pub const REQRESP_FAILURES_TOTAL: &'static str = "p2p_reqresp_failures_total";

    // --- Peer metrics ---

    /// Counter: peer connection events.
    pub const PEERS_CONNECTED_TOTAL: &'static str = "p2p_peers_connected_total";
    /// Counter: peer disconnection events.
    pub const PEERS_DISCONNECTED_TOTAL: &'static str = "p2p_peers_disconnected_total";
    /// Gauge: current number of connected peers.
    pub const PEERS_CONNECTED_CURRENT: &'static str = "p2p_peers_connected_current";

    // --- Head sync metrics ---

    /// Gauge: current local head block number.
    pub const HEAD_LOCAL_BLOCK: &'static str = "p2p_head_local_block";
    /// Gauge: current network head block number.
    pub const HEAD_NETWORK_BLOCK: &'static str = "p2p_head_network_block";
    /// Gauge: sync status (0 = syncing, 1 = synced).
    pub const HEAD_SYNC_STATUS: &'static str = "p2p_head_sync_status";

    // --- Error metrics ---

    /// Counter: network errors encountered.
    pub const NETWORK_ERRORS_TOTAL: &'static str = "p2p_network_errors_total";

    /// Initialize all metric descriptors.
    ///
    /// Call this once at startup to register metric descriptions and units.
    /// This function is idempotent - multiple calls are safe and only the
    /// first call will actually register the metrics.
    pub fn init() {
        INIT_ONCE.call_once(Self::init_inner);
    }

    /// Internal initialization logic, called at most once.
    fn init_inner() {
        // Gossip metrics
        metrics::describe_counter!(
            Self::GOSSIP_RECEIVED_TOTAL,
            Unit::Count,
            "Total gossip messages received by type"
        );
        metrics::describe_counter!(
            Self::GOSSIP_PUBLISHED_TOTAL,
            Unit::Count,
            "Total gossip messages published by type"
        );
        metrics::describe_counter!(
            Self::GOSSIP_STORED_TOTAL,
            Unit::Count,
            "Total gossip messages stored after validation"
        );

        // Validation metrics
        metrics::describe_counter!(
            Self::VALIDATION_RESULTS_TOTAL,
            Unit::Count,
            "Validation outcomes by result type"
        );

        // Execution metrics
        metrics::describe_counter!(
            Self::EXECUTION_APPLIED_TOTAL,
            Unit::Count,
            "Commitments applied to the execution engine"
        );
        metrics::describe_counter!(
            Self::EXECUTION_PENDING_PARENT_TOTAL,
            Unit::Count,
            "Commitments pending parent availability"
        );
        metrics::describe_counter!(
            Self::EXECUTION_PENDING_TXLIST_TOTAL,
            Unit::Count,
            "Commitments pending txlist availability"
        );
        metrics::describe_counter!(
            Self::EXECUTION_ERRORS_TOTAL,
            Unit::Count,
            "Execution engine errors while applying commitments"
        );
        metrics::describe_gauge!(
            Self::PENDING_TXLIST_BUFFER_SIZE,
            Unit::Count,
            "Current commitments awaiting txlist data"
        );

        // Dedupe/cache metrics
        metrics::describe_counter!(
            Self::DEDUPE_HITS_TOTAL,
            Unit::Count,
            "Dedupe cache hits by cache type"
        );
        metrics::describe_gauge!(
            Self::PENDING_BUFFER_SIZE,
            Unit::Count,
            "Current pending commitments awaiting parent arrival"
        );
        metrics::describe_counter!(
            Self::PENDING_RELEASED_TOTAL,
            Unit::Count,
            "Commitments released from pending buffer"
        );
        metrics::describe_counter!(
            Self::PENDING_BUFFERED_TOTAL,
            Unit::Count,
            "Commitments added to pending buffer"
        );

        // Request/Response metrics
        metrics::describe_counter!(
            Self::REQRESP_RECEIVED_TOTAL,
            Unit::Count,
            "Request/response messages received by type"
        );
        metrics::describe_counter!(
            Self::REQRESP_SENT_TOTAL,
            Unit::Count,
            "Request/response messages sent by type"
        );
        metrics::describe_counter!(
            Self::INBOUND_REQUESTS_TOTAL,
            Unit::Count,
            "Inbound requests handled by type"
        );
        metrics::describe_histogram!(
            Self::REQRESP_LATENCY_SECONDS,
            Unit::Seconds,
            "Request/response latency by type"
        );
        metrics::describe_counter!(
            Self::REQRESP_FAILURES_TOTAL,
            Unit::Count,
            "Request/response failures by type and reason"
        );

        // Peer metrics
        metrics::describe_counter!(
            Self::PEERS_CONNECTED_TOTAL,
            Unit::Count,
            "Total peer connection events"
        );
        metrics::describe_counter!(
            Self::PEERS_DISCONNECTED_TOTAL,
            Unit::Count,
            "Total peer disconnection events"
        );
        metrics::describe_gauge!(
            Self::PEERS_CONNECTED_CURRENT,
            Unit::Count,
            "Current number of connected peers"
        );

        // Head sync metrics
        metrics::describe_gauge!(
            Self::HEAD_LOCAL_BLOCK,
            Unit::Count,
            "Current local head block number"
        );
        metrics::describe_gauge!(
            Self::HEAD_NETWORK_BLOCK,
            Unit::Count,
            "Current network head block number"
        );
        metrics::describe_gauge!(
            Self::HEAD_SYNC_STATUS,
            Unit::Count,
            "Head sync status (0=syncing, 1=synced)"
        );

        // Error metrics
        metrics::describe_counter!(
            Self::NETWORK_ERRORS_TOTAL,
            Unit::Count,
            "Total network errors encountered"
        );

        // Initialize counters to zero
        metrics::counter!(Self::GOSSIP_RECEIVED_TOTAL, "type" => "commitment").absolute(0);
        metrics::counter!(Self::GOSSIP_RECEIVED_TOTAL, "type" => "txlist").absolute(0);
        metrics::counter!(Self::GOSSIP_PUBLISHED_TOTAL, "type" => "commitment").absolute(0);
        metrics::counter!(Self::GOSSIP_PUBLISHED_TOTAL, "type" => "txlist").absolute(0);
        metrics::counter!(Self::VALIDATION_RESULTS_TOTAL, "result" => "valid").absolute(0);
        metrics::counter!(Self::VALIDATION_RESULTS_TOTAL, "result" => "pending").absolute(0);
        metrics::counter!(Self::VALIDATION_RESULTS_TOTAL, "result" => "invalid").absolute(0);
        metrics::counter!(Self::EXECUTION_APPLIED_TOTAL).absolute(0);
        metrics::counter!(Self::EXECUTION_PENDING_PARENT_TOTAL).absolute(0);
        metrics::counter!(Self::EXECUTION_PENDING_TXLIST_TOTAL).absolute(0);
        metrics::counter!(Self::EXECUTION_ERRORS_TOTAL).absolute(0);
        metrics::counter!(Self::DEDUPE_HITS_TOTAL, "type" => "message").absolute(0);
        metrics::counter!(Self::DEDUPE_HITS_TOTAL, "type" => "commitment").absolute(0);
        metrics::counter!(Self::DEDUPE_HITS_TOTAL, "type" => "txlist").absolute(0);
        metrics::counter!(Self::PEERS_CONNECTED_TOTAL).absolute(0);
        metrics::counter!(Self::PEERS_DISCONNECTED_TOTAL).absolute(0);
        metrics::counter!(Self::NETWORK_ERRORS_TOTAL).absolute(0);
        metrics::gauge!(Self::PENDING_BUFFER_SIZE).set(0.0);
        metrics::gauge!(Self::PENDING_TXLIST_BUFFER_SIZE).set(0.0);
        metrics::gauge!(Self::PEERS_CONNECTED_CURRENT).set(0.0);
        metrics::gauge!(Self::HEAD_SYNC_STATUS).set(0.0);
    }

    // --- Recording helpers ---

    /// Record a gossip message received.
    pub fn record_gossip_received(msg_type: &str) {
        metrics::counter!(Self::GOSSIP_RECEIVED_TOTAL, "type" => msg_type.to_string()).increment(1);
    }

    /// Record a gossip message published.
    pub fn record_gossip_published(msg_type: &str) {
        metrics::counter!(Self::GOSSIP_PUBLISHED_TOTAL, "type" => msg_type.to_string())
            .increment(1);
    }

    /// Record a gossip message stored after validation.
    pub fn record_gossip_stored(msg_type: &str) {
        metrics::counter!(Self::GOSSIP_STORED_TOTAL, "type" => msg_type.to_string()).increment(1);
    }

    /// Record a validation result.
    pub fn record_validation_result(result: &str) {
        metrics::counter!(Self::VALIDATION_RESULTS_TOTAL, "result" => result.to_string())
            .increment(1);
    }

    /// Record a commitment applied to the execution engine.
    pub fn record_execution_applied() {
        metrics::counter!(Self::EXECUTION_APPLIED_TOTAL).increment(1);
    }

    /// Record a commitment pending due to missing parent.
    pub fn record_execution_pending_parent() {
        metrics::counter!(Self::EXECUTION_PENDING_PARENT_TOTAL).increment(1);
    }

    /// Record a commitment pending due to missing txlist.
    pub fn record_execution_pending_txlist() {
        metrics::counter!(Self::EXECUTION_PENDING_TXLIST_TOTAL).increment(1);
    }

    /// Record an execution engine error.
    pub fn record_execution_error() {
        metrics::counter!(Self::EXECUTION_ERRORS_TOTAL).increment(1);
    }

    /// Record a dedupe cache hit.
    pub fn record_dedupe_hit(cache_type: &str) {
        metrics::counter!(Self::DEDUPE_HITS_TOTAL, "type" => cache_type.to_string()).increment(1);
    }

    /// Update the pending buffer size gauge.
    pub fn set_pending_buffer_size(size: usize) {
        metrics::gauge!(Self::PENDING_BUFFER_SIZE).set(size as f64);
    }

    /// Update the pending txlist buffer size gauge.
    pub fn set_pending_txlist_buffer_size(size: usize) {
        metrics::gauge!(Self::PENDING_TXLIST_BUFFER_SIZE).set(size as f64);
    }

    /// Record commitments released from pending buffer.
    pub fn record_pending_released(count: usize) {
        if count > 0 {
            metrics::counter!(Self::PENDING_RELEASED_TOTAL).increment(count as u64);
        }
    }

    /// Record a commitment added to pending buffer.
    pub fn record_pending_buffered() {
        metrics::counter!(Self::PENDING_BUFFERED_TOTAL).increment(1);
    }

    /// Record a req/resp message received.
    pub fn record_reqresp_received(msg_type: &str) {
        metrics::counter!(Self::REQRESP_RECEIVED_TOTAL, "type" => msg_type.to_string())
            .increment(1);
    }

    /// Record a req/resp message sent.
    pub fn record_reqresp_sent(msg_type: &str) {
        metrics::counter!(Self::REQRESP_SENT_TOTAL, "type" => msg_type.to_string()).increment(1);
    }

    /// Record an inbound request handled.
    pub fn record_inbound_request(req_type: &str) {
        metrics::counter!(Self::INBOUND_REQUESTS_TOTAL, "type" => req_type.to_string())
            .increment(1);
    }

    /// Record req/resp latency.
    pub fn record_reqresp_latency(msg_type: &str, latency_secs: f64) {
        metrics::histogram!(Self::REQRESP_LATENCY_SECONDS, "type" => msg_type.to_string())
            .record(latency_secs);
    }

    /// Record a req/resp failure.
    pub fn record_reqresp_failure(msg_type: &str, reason: &str) {
        metrics::counter!(
            Self::REQRESP_FAILURES_TOTAL,
            "type" => msg_type.to_string(),
            "reason" => reason.to_string()
        )
        .increment(1);
    }

    /// Record a peer connected event.
    pub fn record_peer_connected() {
        metrics::counter!(Self::PEERS_CONNECTED_TOTAL).increment(1);
    }

    /// Record a peer disconnected event.
    pub fn record_peer_disconnected() {
        metrics::counter!(Self::PEERS_DISCONNECTED_TOTAL).increment(1);
    }

    /// Set the current connected peers count.
    pub fn set_peers_connected(count: usize) {
        metrics::gauge!(Self::PEERS_CONNECTED_CURRENT).set(count as f64);
    }

    /// Set the local head block number.
    pub fn set_local_head(block: u64) {
        metrics::gauge!(Self::HEAD_LOCAL_BLOCK).set(block as f64);
    }

    /// Set the network head block number.
    pub fn set_network_head(block: u64) {
        metrics::gauge!(Self::HEAD_NETWORK_BLOCK).set(block as f64);
    }

    /// Set the sync status (true = synced, false = syncing).
    pub fn set_sync_status(synced: bool) {
        metrics::gauge!(Self::HEAD_SYNC_STATUS).set(if synced { 1.0 } else { 0.0 });
    }

    /// Record a network error.
    pub fn record_network_error() {
        metrics::counter!(Self::NETWORK_ERRORS_TOTAL).increment(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn metrics_init_does_not_panic() {
        // Just ensure init() doesn't panic
        P2pMetrics::init();
    }

    #[test]
    fn metrics_init_only_once() {
        // Calling init() multiple times should be safe and idempotent.
        // This test verifies that multiple calls don't panic or cause issues.
        P2pMetrics::init();
        P2pMetrics::init();
        P2pMetrics::init();
        // If we got here without panic, the test passes.
        // The Once guard ensures only the first call registers metrics.
    }

    #[test]
    fn record_helpers_do_not_panic() {
        // These all just call the metrics macros, which are no-ops without a recorder
        P2pMetrics::record_gossip_received("commitment");
        P2pMetrics::record_gossip_published("txlist");
        P2pMetrics::record_gossip_stored("commitment");
        P2pMetrics::record_validation_result("valid");
        P2pMetrics::record_validation_result("pending");
        P2pMetrics::record_validation_result("invalid");
        P2pMetrics::record_execution_applied();
        P2pMetrics::record_execution_pending_parent();
        P2pMetrics::record_execution_pending_txlist();
        P2pMetrics::record_execution_error();
        P2pMetrics::record_dedupe_hit("message");
        P2pMetrics::record_dedupe_hit("commitment");
        P2pMetrics::record_dedupe_hit("txlist");
        P2pMetrics::set_pending_buffer_size(10);
        P2pMetrics::set_pending_txlist_buffer_size(5);
        P2pMetrics::record_pending_released(5);
        P2pMetrics::record_pending_buffered();
        P2pMetrics::record_reqresp_received("commitments");
        P2pMetrics::record_reqresp_sent("head");
        P2pMetrics::record_inbound_request("raw_txlist");
        P2pMetrics::record_reqresp_latency("head", 0.5);
        P2pMetrics::record_reqresp_failure("commitments", "timeout");
        P2pMetrics::record_peer_connected();
        P2pMetrics::record_peer_disconnected();
        P2pMetrics::set_peers_connected(5);
        P2pMetrics::set_local_head(12345);
        P2pMetrics::set_network_head(12350);
        P2pMetrics::set_sync_status(true);
        P2pMetrics::set_sync_status(false);
        P2pMetrics::record_network_error();
    }

    #[test]
    fn metric_names_follow_convention() {
        // All metrics should start with p2p_ prefix
        assert!(P2pMetrics::GOSSIP_RECEIVED_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::GOSSIP_PUBLISHED_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::VALIDATION_RESULTS_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::EXECUTION_APPLIED_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::EXECUTION_PENDING_PARENT_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::EXECUTION_PENDING_TXLIST_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::EXECUTION_ERRORS_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::PENDING_TXLIST_BUFFER_SIZE.starts_with("p2p_"));
        assert!(P2pMetrics::DEDUPE_HITS_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::PENDING_BUFFER_SIZE.starts_with("p2p_"));
        assert!(P2pMetrics::REQRESP_RECEIVED_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::REQRESP_LATENCY_SECONDS.starts_with("p2p_"));
        assert!(P2pMetrics::PEERS_CONNECTED_TOTAL.starts_with("p2p_"));
        assert!(P2pMetrics::HEAD_LOCAL_BLOCK.starts_with("p2p_"));
        assert!(P2pMetrics::NETWORK_ERRORS_TOTAL.starts_with("p2p_"));
    }

    #[test]
    fn metric_names_are_unique() {
        let names = [
            P2pMetrics::GOSSIP_RECEIVED_TOTAL,
            P2pMetrics::GOSSIP_PUBLISHED_TOTAL,
            P2pMetrics::GOSSIP_STORED_TOTAL,
            P2pMetrics::VALIDATION_RESULTS_TOTAL,
            P2pMetrics::EXECUTION_APPLIED_TOTAL,
            P2pMetrics::EXECUTION_PENDING_PARENT_TOTAL,
            P2pMetrics::EXECUTION_PENDING_TXLIST_TOTAL,
            P2pMetrics::EXECUTION_ERRORS_TOTAL,
            P2pMetrics::DEDUPE_HITS_TOTAL,
            P2pMetrics::PENDING_BUFFER_SIZE,
            P2pMetrics::PENDING_RELEASED_TOTAL,
            P2pMetrics::PENDING_BUFFERED_TOTAL,
            P2pMetrics::PENDING_TXLIST_BUFFER_SIZE,
            P2pMetrics::REQRESP_RECEIVED_TOTAL,
            P2pMetrics::REQRESP_SENT_TOTAL,
            P2pMetrics::INBOUND_REQUESTS_TOTAL,
            P2pMetrics::REQRESP_LATENCY_SECONDS,
            P2pMetrics::REQRESP_FAILURES_TOTAL,
            P2pMetrics::PEERS_CONNECTED_TOTAL,
            P2pMetrics::PEERS_DISCONNECTED_TOTAL,
            P2pMetrics::PEERS_CONNECTED_CURRENT,
            P2pMetrics::HEAD_LOCAL_BLOCK,
            P2pMetrics::HEAD_NETWORK_BLOCK,
            P2pMetrics::HEAD_SYNC_STATUS,
            P2pMetrics::NETWORK_ERRORS_TOTAL,
        ];

        let mut unique = std::collections::HashSet::new();
        for name in &names {
            assert!(unique.insert(*name), "duplicate metric name: {}", name);
        }
    }
}
