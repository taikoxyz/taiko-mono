use std::time::Duration;

use preconfirmation_service::NetworkConfig;

/// High-level SDK configuration wrapping the underlying network config and
/// providing SDK-specific knobs for buffering and catch-up behavior.
#[derive(Debug, Clone)]
pub struct P2pSdkConfig {
    pub network: NetworkConfig,
    pub chain_id: u64,
    pub command_buffer: usize,
    pub event_buffer: usize,
    pub commitment_cache: usize,
    pub raw_txlist_cache_bytes: usize,
    pub request_timeout: Duration,
    pub max_commitments_per_page: u32,
}

impl Default for P2pSdkConfig {
    fn default() -> Self {
        Self {
            network: NetworkConfig::default(),
            chain_id: 0,
            command_buffer: 256,
            event_buffer: 256,
            commitment_cache: 1024,
            raw_txlist_cache_bytes: 16 * 1024 * 1024, // 16 MiB
            request_timeout: Duration::from_secs(10),
            max_commitments_per_page: 256,
        }
    }
}

impl P2pSdkConfig {
    pub fn with_chain_id(mut self, chain_id: u64) -> Self {
        self.chain_id = chain_id;
        self
    }

    pub fn with_network(mut self, network: NetworkConfig) -> Self {
        self.network = network;
        self
    }
}

