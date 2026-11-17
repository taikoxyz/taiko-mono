//! Driver configuration.

use std::{fmt, time::Duration};

use alloy::transports::http::reqwest::Url;
use rpc::client::ClientConfig;

/// Configuration for the Shasta driver.
#[derive(Clone)]
pub struct DriverConfig {
    /// Underlying RPC client configuration shared with other components.
    pub client: ClientConfig,
    /// Maximum interval between retry attempts when sync operations fail; the event scanner
    /// reconnect backs off exponentially from one second up to this cap, while beacon-sync
    /// polling uses it as a flat interval.
    pub retry_interval: Duration,
    /// L1 beacon endpoint used for lookahead / slot metadata.
    pub l1_beacon_endpoint: Url,
    /// Optional L2 checkpoint endpoint used as an untrusted block-body source for beacon sync.
    pub l2_checkpoint_url: Option<Url>,
    /// Optional blob server endpoint used when beacon blobs are unavailable.
    pub blob_server_endpoint: Option<Url>,
    /// Enable preconfirmation ingress handling.
    pub preconfirmation_enabled: bool,
}

impl fmt::Debug for DriverConfig {
    /// Report startup settings without endpoints or JWT paths that may contain credentials.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DriverConfig")
            .field("inbox_address", &self.client.inbox_address)
            .field("retry_interval", &self.retry_interval)
            .field("preconfirmation_enabled", &self.preconfirmation_enabled)
            .field("checkpoint_configured", &self.l2_checkpoint_url.is_some())
            .field("blob_server_configured", &self.blob_server_endpoint.is_some())
            .finish_non_exhaustive()
    }
}

impl DriverConfig {
    /// Build a [`DriverConfig`] from raw parameters.
    ///
    /// The `client` argument bundles all RPC endpoints and contract metadata, while the remaining
    /// parameters control retry behaviour, optional checkpointing resources, and whether the
    /// preconfirmation ingress path is enabled.
    pub fn new(
        client: ClientConfig,
        retry_interval: Duration,
        l1_beacon_endpoint: Url,
        l2_checkpoint_url: Option<Url>,
        blob_server_endpoint: Option<Url>,
        preconfirmation_enabled: bool,
    ) -> Self {
        Self {
            client,
            retry_interval,
            l1_beacon_endpoint,
            l2_checkpoint_url,
            blob_server_endpoint,
            preconfirmation_enabled,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::Address;
    use rpc::SubscriptionSource;

    #[test]
    fn debug_omits_all_endpoint_credentials() {
        let endpoint = |secret: &str| {
            Url::parse(&format!(
                "https://user:password@provider.example/{secret}?key=query-key#fragment"
            ))
            .unwrap()
        };
        let config = DriverConfig::new(
            ClientConfig {
                l1_provider_source: SubscriptionSource::Http(endpoint("l1-secret")),
                l2_provider_url: endpoint("l2-secret"),
                l2_auth_provider_url: endpoint("engine-secret"),
                jwt_secret: "/jwt-secret-path".into(),
                inbox_address: Address::ZERO,
            },
            Duration::from_secs(3),
            endpoint("beacon-secret"),
            Some(endpoint("checkpoint-secret")),
            Some(endpoint("blob-secret")),
            true,
        );

        let output = format!("{config:?}");

        for secret in [
            "password",
            "query-key",
            "l1-secret",
            "l2-secret",
            "engine-secret",
            "beacon-secret",
            "checkpoint-secret",
            "blob-secret",
            "jwt-secret-path",
        ] {
            assert!(!output.contains(secret), "configuration Debug exposes {secret}");
        }
        assert!(output.contains("retry_interval"));
        assert!(output.contains("preconfirmation_enabled"));
    }
}
