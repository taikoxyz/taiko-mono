//! Driver configuration.

use std::time::Duration;

use alloy::transports::http::reqwest::Url;
use rpc::client::ClientConfig;

use crate::p2p_sidecar::P2pSidecarConfig;

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
    /// Optional P2P sidecar configuration.
    pub p2p_sidecar: Option<P2pSidecarConfig>,
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
    ) -> Self {
        Self {
            client,
            retry_interval,
            l1_beacon_endpoint,
            l2_checkpoint_url,
            blob_server_endpoint,
            p2p_sidecar: None,
            preconfirmation_enabled: false,
        }
    }
}
