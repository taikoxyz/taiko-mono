//! SDK configuration types.
//!
//! This module provides [`P2pClientConfig`] which embeds the network-level
//! [`P2pConfig`](preconfirmation_net::P2pConfig) and adds SDK-specific knobs.

use std::{sync::Arc, time::Duration};

use alloy_primitives::Address;
use preconfirmation_net::P2pConfig;
use rpc::PreconfEngine;

/// Default maximum txlist size (128 KiB).
pub const DEFAULT_MAX_TXLIST_BYTES: usize = 131_072;

/// Configuration for the P2P SDK client.
///
/// This configuration embeds the network-level [`P2pConfig`] and adds
/// SDK-specific options like dedupe settings, catch-up backoff, and channel sizes.
#[derive(Clone)]
pub struct P2pClientConfig {
    /// Network-level P2P configuration.
    pub network: P2pConfig,
    /// Expected slasher address for commitment validation.
    pub expected_slasher: Option<Address>,
    /// Chain ID for topic/protocol derivation (redundant with network.chain_id, kept for clarity).
    pub chain_id: u64,
    /// Capacity of the SDK event channel.
    pub event_channel_size: usize,
    /// Capacity of the SDK command channel.
    pub command_channel_size: usize,
    /// Maximum number of entries in the dedupe cache.
    pub dedupe_cache_cap: usize,
    /// TTL for dedupe cache entries.
    pub dedupe_ttl: Duration,
    /// Maximum number of commitments per page for catch-up requests.
    pub max_commitments_per_page: u32,
    /// Maximum size of raw txlist bytes to accept.
    pub max_txlist_bytes: usize,
    /// Initial backoff duration for catch-up retries.
    pub catchup_initial_backoff: Duration,
    /// Maximum backoff duration for catch-up retries.
    pub catchup_max_backoff: Duration,
    /// Maximum number of catch-up retry attempts.
    pub catchup_max_retries: u32,
    /// Enable Prometheus metrics for the SDK.
    pub enable_metrics: bool,
    /// Optional preconfirmation execution engine.
    ///
    /// Required for applying validated commitments to the L2 execution layer.
    pub engine: Option<Arc<dyn PreconfEngine>>,
}

impl std::fmt::Debug for P2pClientConfig {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("P2pClientConfig")
            .field("network", &self.network)
            .field("expected_slasher", &self.expected_slasher)
            .field("chain_id", &self.chain_id)
            .field("event_channel_size", &self.event_channel_size)
            .field("command_channel_size", &self.command_channel_size)
            .field("dedupe_cache_cap", &self.dedupe_cache_cap)
            .field("dedupe_ttl", &self.dedupe_ttl)
            .field("max_commitments_per_page", &self.max_commitments_per_page)
            .field("max_txlist_bytes", &self.max_txlist_bytes)
            .field("catchup_initial_backoff", &self.catchup_initial_backoff)
            .field("catchup_max_backoff", &self.catchup_max_backoff)
            .field("catchup_max_retries", &self.catchup_max_retries)
            .field("enable_metrics", &self.enable_metrics)
            .field("engine", &self.engine.as_ref().map(|_| "<PreconfEngine>"))
            .finish()
    }
}

/// Default SDK configuration values.
impl Default for P2pClientConfig {
    fn default() -> Self {
        Self {
            network: P2pConfig::default(),
            expected_slasher: None,
            chain_id: 167_000, // Taiko mainnet placeholder
            event_channel_size: 1024,
            command_channel_size: 256,
            dedupe_cache_cap: 10_000,
            dedupe_ttl: Duration::from_secs(300), // 5 minutes
            max_commitments_per_page: 100,
            max_txlist_bytes: DEFAULT_MAX_TXLIST_BYTES,
            catchup_initial_backoff: Duration::from_millis(500),
            catchup_max_backoff: Duration::from_secs(30),
            catchup_max_retries: 10,
            enable_metrics: true,
            engine: None,
        }
    }
}

/// P2P client configuration helpers.
impl P2pClientConfig {
    /// Create a new configuration with the specified chain ID.
    pub fn with_chain_id(chain_id: u64) -> Self {
        let network = P2pConfig { chain_id, ..Default::default() };
        Self { chain_id, network, ..Default::default() }
    }

    /// Validate configuration invariants before constructing the client.
    ///
    /// This ensures:
    /// - SDK-level `chain_id` and network `chain_id` remain consistent, preventing mismatched
    ///   topics and protocol IDs.
    /// - An `engine` is provided.
    pub fn validate(&self) -> crate::P2pResult<()> {
        if self.chain_id != self.network.chain_id {
            return Err(crate::P2pClientError::Config(format!(
                "chain_id mismatch: sdk={} network={}",
                self.chain_id, self.network.chain_id
            )));
        }
        if self.engine.is_none() {
            return Err(crate::P2pClientError::Config(
                "no execution engine is provided".to_string(),
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_config_has_sane_values() {
        let config = P2pClientConfig::default();

        // Verify channel sizes are non-zero
        assert!(config.event_channel_size > 0);
        assert!(config.command_channel_size > 0);

        // Verify dedupe settings are reasonable
        assert!(config.dedupe_cache_cap > 0);
        assert!(config.dedupe_ttl > Duration::ZERO);

        // Verify catch-up settings
        assert!(config.max_commitments_per_page > 0);
        assert!(config.catchup_initial_backoff < config.catchup_max_backoff);
        assert!(config.catchup_max_retries > 0);
    }

    #[test]
    fn with_chain_id_sets_both_configs() {
        let config = P2pClientConfig::with_chain_id(12345);

        assert_eq!(config.chain_id, 12345);
        assert_eq!(config.network.chain_id, 12345);
    }

    #[test]
    fn config_embeds_network_config() {
        let config = P2pClientConfig::default();

        // Network config should be accessible and have sensible defaults
        assert!(config.network.request_timeout > Duration::ZERO);
    }

    #[test]
    fn config_rejects_chain_id_mismatch() {
        let mut config = P2pClientConfig::default();
        config.chain_id = 1;
        config.network.chain_id = 2;

        let result = config.validate();
        assert!(result.is_err());
    }

    #[test]
    fn config_requires_engine() {
        let config = P2pClientConfig::default();

        let result = config.validate();
        assert!(result.is_err());
    }
}
