//! Driver configuration.

use std::{path::PathBuf, time::Duration};

use alloy::{primitives::Address, transports::http::reqwest::Url};
use rpc::{SubscriptionSource, client::ClientConfig};

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
}

impl DriverConfig {
    /// Build a [`DriverConfig`] from raw parameters.
    pub fn new(
        l1_source: SubscriptionSource,
        l2_http_endpoint: Url,
        l2_auth_endpoint: Url,
        jwt_secret: PathBuf,
        inbox_address: Address,
        retry_interval: Duration,
        l1_beacon_endpoint: Url,
        l2_checkpoint_url: Option<Url>,
    ) -> Self {
        let client = ClientConfig {
            l1_provider_source: l1_source,
            l2_provider_url: l2_http_endpoint,
            l2_auth_provider_url: l2_auth_endpoint,
            jwt_secret,
            inbox_address,
        };

        Self { client, retry_interval, l1_beacon_endpoint, l2_checkpoint_url }
    }
}
