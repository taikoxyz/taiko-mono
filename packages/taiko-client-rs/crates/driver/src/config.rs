//! Driver configuration.

use std::{net::SocketAddr, path::PathBuf, time::Duration};

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
    /// Optional blob server endpoint used when beacon blobs are unavailable.
    pub blob_server_endpoint: Option<Url>,
    /// Enable preconfirmation handling (disabled by default).
    /// NOTE: will be changed to be decided by flag in future.
    pub preconfirmation_enabled: bool,
    /// Optional driver JSON-RPC server listen address (HTTP, JWT-protected).
    ///
    /// When configured, the driver exposes JWT-protected JSON-RPC methods that allow external
    /// components to submit preconfirmation payloads over HTTP.
    pub rpc_listen_addr: Option<SocketAddr>,
    /// Optional JWT secret path for the driver JSON-RPC server (HTTP only).
    ///
    /// When set, the driver RPC server authenticates HTTP requests using this secret instead of
    /// the L2 auth JWT secret.
    pub rpc_jwt_secret: Option<PathBuf>,
    /// Optional IPC socket path for the driver JSON-RPC server.
    ///
    /// When configured, the driver exposes JSON-RPC methods over a Unix domain socket.
    /// IPC uses filesystem permissions for access control (no JWT authentication).
    pub rpc_ipc_path: Option<PathBuf>,
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
            preconfirmation_enabled: false,
            rpc_listen_addr: None,
            rpc_jwt_secret: None,
            rpc_ipc_path: None,
        }
    }

    /// Returns `true` if at least one RPC endpoint (HTTP or IPC) is configured.
    pub fn has_rpc_endpoint(&self) -> bool {
        self.rpc_listen_addr.is_some() || self.rpc_ipc_path.is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::{IpAddr, Ipv4Addr};

    fn dummy_client_config() -> ClientConfig {
        use rpc::SubscriptionSource;
        ClientConfig {
            l1_provider_source: SubscriptionSource::Http(
                "http://localhost:8545".parse().expect("http url"),
            ),
            l2_provider_url: "http://localhost:8546".parse().expect("l2 url"),
            l2_auth_provider_url: "http://localhost:8551".parse().expect("auth url"),
            jwt_secret: PathBuf::from("/tmp/jwt.hex"),
            inbox_address: Default::default(),
        }
    }

    #[test]
    fn has_rpc_endpoint_returns_false_when_neither_configured() {
        let cfg = DriverConfig::new(
            dummy_client_config(),
            Duration::from_secs(12),
            "http://localhost:5052".parse().expect("beacon url"),
            None,
            None,
        );
        assert!(!cfg.has_rpc_endpoint());
    }

    #[test]
    fn has_rpc_endpoint_returns_true_when_http_configured() {
        let mut cfg = DriverConfig::new(
            dummy_client_config(),
            Duration::from_secs(12),
            "http://localhost:5052".parse().expect("beacon url"),
            None,
            None,
        );
        cfg.rpc_listen_addr = Some(SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 8080));
        assert!(cfg.has_rpc_endpoint());
    }

    #[test]
    fn has_rpc_endpoint_returns_true_when_ipc_configured() {
        let mut cfg = DriverConfig::new(
            dummy_client_config(),
            Duration::from_secs(12),
            "http://localhost:5052".parse().expect("beacon url"),
            None,
            None,
        );
        cfg.rpc_ipc_path = Some(PathBuf::from("/tmp/driver.ipc"));
        assert!(cfg.has_rpc_endpoint());
    }

    #[test]
    fn has_rpc_endpoint_returns_true_when_both_configured() {
        let mut cfg = DriverConfig::new(
            dummy_client_config(),
            Duration::from_secs(12),
            "http://localhost:5052".parse().expect("beacon url"),
            None,
            None,
        );
        cfg.rpc_listen_addr = Some(SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 8080));
        cfg.rpc_ipc_path = Some(PathBuf::from("/tmp/driver.ipc"));
        assert!(cfg.has_rpc_endpoint());
    }
}
