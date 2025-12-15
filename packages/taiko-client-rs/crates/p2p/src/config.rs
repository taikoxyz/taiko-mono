//! Configuration for the sidecar-facing P2P client.
//!
//! This module wraps the lower-level `preconfirmation_service::NetworkConfig` with
//! Client-specific knobs controlling buffer sizes, cache limits, and request bounds
//! required by the permissionless preconfirmation workflow.

use std::time::Duration;

use preconfirmation_service::NetworkConfig;

/// High-level client configuration.
///
/// All fields are documented to make operational tuning explicit. Default values
/// mirror the conservative Kona/reth presets provided by `NetworkConfig::default`
/// while adding client-specific limits for caching and pagination.
#[derive(Debug, Clone)]
pub struct P2pClientConfig {
    /// Underlying libp2p/discv5/reputation configuration.
    pub network: NetworkConfig,
    /// Chain ID used to derive gossip topics and protocol IDs.
    pub chain_id: u64,
    /// Maximum buffered commands awaiting delivery to the network driver.
    pub command_buffer: usize,
    /// Maximum buffered client events fanned out to subscribers.
    pub event_buffer: usize,
    /// Maximum number of commitments retained in the in-memory cache.
    pub commitment_cache: usize,
    /// Soft byte cap for raw txlist cache (compressed bytes), used by storage.
    pub raw_txlist_cache_bytes: usize,
    /// Maximum parent entries retained for pending-child commitments.
    pub pending_parent_cache: usize,
    /// TTL for pending-child commitments awaiting their parent.
    pub pending_parent_ttl: Duration,
    /// Timeout applied to request/response interactions (head/commitments/txlist).
    pub request_timeout: Duration,
    /// Maximum commitments requested per page during catch-up.
    pub max_commitments_per_page: u32,
    /// Maximum number of message ids retained for deduplication.
    pub message_id_cache: usize,
    /// Time-to-live for message ids used in deduplication.
    pub message_id_ttl: Duration,
    /// Whether client metrics should be recorded (if the `metrics` recorder is configured).
    pub enable_metrics: bool,
    /// Whether gossipsub validation failures should be treated as soft rejects rather than peer
    /// penalties.
    pub gossipsub_validation_soft_fail: bool,
    /// Grace window for executor slot drift when comparing submission window end timestamps.
    pub executor_slot_grace: Duration,
    /// Placeholder toggle for disk-backed storage; currently unused but reserved for future
    /// implementations.
    pub disk_storage_enabled: bool,
    /// Minimum backoff duration for catch-up retries.
    pub catchup_backoff_min: Duration,
    /// Maximum backoff duration for catch-up retries.
    pub catchup_backoff_max: Duration,
    /// Maximum number of retries before canceling a catch-up request.
    pub catchup_retry_budget: u32,
    /// Per-peer req/resp rate limit within the configured window.
    pub reqresp_rate_limit: u32,
    /// Sliding window duration for rate limiting.
    pub reqresp_rate_window: Duration,
}

impl Default for P2pClientConfig {
    /// Provide conservative defaults suitable for local development.
    fn default() -> Self {
        Self {
            network: NetworkConfig::default(),
            chain_id: 0,
            command_buffer: 256,
            event_buffer: 256,
            commitment_cache: 1024,
            raw_txlist_cache_bytes: 16 * 1024 * 1024, // 16 MiB
            pending_parent_cache: 512,
            pending_parent_ttl: Duration::from_secs(300),
            request_timeout: Duration::from_secs(10),
            max_commitments_per_page: 256,
            message_id_cache: 4096,
            message_id_ttl: Duration::from_secs(120),
            enable_metrics: true,
            gossipsub_validation_soft_fail: false,
            executor_slot_grace: Duration::from_secs(1),
            disk_storage_enabled: false,
            catchup_backoff_min: Duration::from_secs(2),
            catchup_backoff_max: Duration::from_secs(30),
            catchup_retry_budget: 5,
            reqresp_rate_limit: 50,
            reqresp_rate_window: Duration::from_secs(10),
        }
    }
}

impl P2pClientConfig {
    /// Override the chain ID used for topics and protocol IDs.
    pub fn with_chain_id(mut self, chain_id: u64) -> Self {
        self.chain_id = chain_id;
        self
    }

    /// Override the underlying network configuration.
    pub fn with_network(mut self, network: NetworkConfig) -> Self {
        self.network = network;
        self
    }

    /// Override the request timeout used by blocking helpers and catch-up.
    pub fn with_request_timeout(mut self, timeout: Duration) -> Self {
        self.request_timeout = timeout;
        self
    }

    /// Override the maximum commitments requested per page during catch-up.
    pub fn with_max_commitments_per_page(mut self, max: u32) -> Self {
        self.max_commitments_per_page = max;
        self
    }

    /// Enable or disable metrics emission.
    pub fn with_metrics(mut self, enabled: bool) -> Self {
        self.enable_metrics = enabled;
        self
    }

    /// Control whether gossipsub validation failures are soft (no peer penalty).
    pub fn with_gossipsub_soft_fail(mut self, soft: bool) -> Self {
        self.gossipsub_validation_soft_fail = soft;
        self
    }

    /// Configure the executor slot grace window for timestamp drift.
    pub fn with_executor_slot_grace(mut self, grace: Duration) -> Self {
        self.executor_slot_grace = grace;
        self
    }

    /// Override message-id cache sizing for deduplication.
    pub fn with_message_id_cache(mut self, cap: usize, ttl: Duration) -> Self {
        self.message_id_cache = cap;
        self.message_id_ttl = ttl;
        self
    }

    /// Configure catch-up retry backoff.
    pub fn with_catchup_backoff(mut self, min: Duration, max: Duration, retries: u32) -> Self {
        self.catchup_backoff_min = min;
        self.catchup_backoff_max = max;
        self.catchup_retry_budget = retries;
        self
    }

    /// Configure req/resp per-peer rate limits.
    pub fn with_reqresp_rate_limit(mut self, limit: u32, window: Duration) -> Self {
        self.reqresp_rate_limit = limit;
        self.reqresp_rate_window = window;
        self
    }
}
