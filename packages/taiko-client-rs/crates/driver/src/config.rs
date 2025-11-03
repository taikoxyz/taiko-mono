//! Driver configuration.

use std::time::Duration;

use alloy::transports::http::reqwest::Url;
use rpc::client::ClientConfig;

/// Configuration for the Shasta driver.
#[derive(Clone, Debug)]
pub struct DriverConfig {
    /// Underlying RPC client configuration shared with other components.
    pub client: ClientConfig,
    /// Interval between retry attempts when sync operations fail.
    pub retry_interval: Duration,
    /// L1 beacon endpoint used for lookahead / slot metadata.
    pub l1_beacon_endpoint: Url,
    /// Optional L2 checkpoint endpoint used for beacon sync.
    pub l2_checkpoint_url: Option<Url>,
    /// Optional override for the Shasta devnet fork activation timestamp.
    pub devnet_shasta_timestamp: u64,
}

impl DriverConfig {
    /// Build a [`DriverConfig`] from raw parameters.
    ///
    /// The `client` argument bundles all RPC endpoints and contract metadata, while the remaining
    /// parameters control retry behaviour and optional checkpointing resources.
    pub fn new(
        client: ClientConfig,
        retry_interval: Duration,
        l1_beacon_endpoint: Url,
        l2_checkpoint_url: Option<Url>,
        devnet_shasta_timestamp: u64,
    ) -> Self {
        Self {
            client,
            retry_interval,
            l1_beacon_endpoint,
            l2_checkpoint_url,
            devnet_shasta_timestamp,
        }
    }
}
