//! Driver configuration.

use std::time::Duration;

use alloy::transports::http::reqwest::Url;
use rpc::client::ClientConfig;

/// Default maximum number of event-sync retries for transient processing failures.
pub const DEFAULT_EVENT_SYNC_MAX_RETRIES: usize = 10;

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
    /// Optional blob server endpoint used when beacon blobs are unavailable.
    pub blob_server_endpoint: Option<Url>,
    /// Maximum number of retries for transient event-sync processing failures.
    pub event_sync_max_retries: usize,
    /// Enable preconfirmation handling (disabled by default).
    /// NOTE: will be changed to be decided by flag in future.
    pub preconfirmation_enabled: bool,
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
        blob_server_endpoint: Option<Url>,
        event_sync_max_retries: usize,
    ) -> Self {
        Self {
            client,
            retry_interval,
            l1_beacon_endpoint,
            l2_checkpoint_url,
            blob_server_endpoint,
            event_sync_max_retries,
            preconfirmation_enabled: false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rpc::SubscriptionSource;
    use std::path::PathBuf;

    #[test]
    fn driver_config_defaults_event_sync_retry_limit() {
        let client = ClientConfig {
            l1_provider_source: SubscriptionSource::Http(
                Url::parse("http://localhost:8545").expect("valid l1 url"),
            ),
            l2_provider_url: Url::parse("http://localhost:9545").expect("valid l2 http url"),
            l2_auth_provider_url: Url::parse("http://localhost:9551").expect("valid l2 auth url"),
            jwt_secret: PathBuf::from("/tmp/jwt.hex"),
            inbox_address: alloy::primitives::Address::ZERO,
        };

        let cfg = DriverConfig::new(
            client,
            Duration::from_secs(12),
            Url::parse("http://localhost:5052").expect("valid beacon url"),
            None,
            None,
            DEFAULT_EVENT_SYNC_MAX_RETRIES,
        );

        assert_eq!(cfg.event_sync_max_retries, DEFAULT_EVENT_SYNC_MAX_RETRIES);
    }
}
