//! Configuration types for the driver P2P sidecar.

use p2p::P2pClientConfig;

/// Configuration for the in-process P2P sidecar.
#[derive(Clone, Debug)]
pub struct P2pSidecarConfig {
    /// Enable or disable the sidecar.
    pub enabled: bool,
    /// Base P2P client configuration (engine injected at runtime).
    pub client: P2pClientConfig,
}

impl P2pSidecarConfig {
    /// Construct a disabled sidecar configuration from a base client config.
    pub fn disabled(client: P2pClientConfig) -> Self {
        Self { enabled: false, client }
    }
}
