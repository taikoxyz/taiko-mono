//! P2P test utilities for preconfirmation integration tests.
//!
//! This module provides helpers for setting up P2P nodes in test environments:
//! - [`test_p2p_config`]: Creates a local-only P2P configuration with ephemeral ports.
//! - [`ExternalP2pNode`]: A spawned P2P node for publishing gossip in tests.

use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::Arc,
};

use anyhow::Result;
use preconfirmation_net::{
    InMemoryStorage, LocalValidationAdapter, P2pConfig, P2pHandle, P2pNode, PreconfStorage,
    ValidationAdapter,
};
use tokio::task::JoinHandle;

// ============================================================================
// P2P Configuration
// ============================================================================

/// Creates a local-only P2P config for tests.
///
/// This configuration:
/// - Uses ephemeral ports (port 0) for both listen and discovery addresses.
/// - Disables peer discovery to keep tests isolated.
/// - Reads chain ID from `L2_CHAIN_ID` env var (defaults to 167001).
///
/// # Example
///
/// ```ignore
/// let config = test_p2p_config();
/// let (handle, node) = P2pNode::new(config)?;
/// ```
pub fn test_p2p_config() -> P2pConfig {
    let localhost_ephemeral = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    let chain_id =
        std::env::var("L2_CHAIN_ID").ok().and_then(|v| v.parse().ok()).unwrap_or(167_001);

    P2pConfig {
        chain_id,
        listen_addr: localhost_ephemeral,
        discovery_listen: localhost_ephemeral,
        enable_discovery: false,
        ..P2pConfig::default()
    }
}

// ============================================================================
// External P2P Node
// ============================================================================

/// A spawned P2P node for testing gossip publishing.
///
/// This struct wraps a P2P node with its handle, storage, and background task,
/// making it easy to publish commitments and txlists from an "external" node
/// that the system under test can subscribe to.
///
/// # Example
///
/// ```ignore
/// let mut ext_node = ExternalP2pNode::spawn()?;
/// let dial_addr = ext_node.handle.dialable_addr().await?;
///
/// // Connect your preconfirmation client to this address
/// config.p2p.pre_dial_peers = vec![dial_addr];
///
/// // Publish gossip
/// ext_node.handle.publish_commitment(commitment).await?;
/// ext_node.handle.publish_raw_txlist(txlist).await?;
///
/// // Clean up
/// ext_node.abort();
/// ```
pub struct ExternalP2pNode {
    /// Handle for interacting with the P2P node (dialing, publishing, etc.).
    pub handle: P2pHandle,
    /// In-memory storage backing this node.
    pub storage: Arc<dyn PreconfStorage>,
    /// Background task running the P2P event loop.
    task: JoinHandle<anyhow::Result<()>>,
}

impl ExternalP2pNode {
    /// Spawns a new external P2P node with in-memory storage.
    ///
    /// The node starts running immediately in a background task.
    /// Use `handle.dialable_addr()` to get an address other nodes can dial.
    pub fn spawn() -> Result<Self> {
        Self::spawn_with_config(test_p2p_config())
    }

    /// Spawns a new external P2P node with a custom configuration.
    pub fn spawn_with_config(config: P2pConfig) -> Result<Self> {
        let validator: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
        let storage: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());
        let (handle, node) =
            P2pNode::new_with_validator_and_storage(config, validator, storage.clone())?;
        let task = tokio::spawn(async move { node.run().await });
        Ok(Self { handle, storage, task })
    }

    /// Aborts the background task running this node.
    ///
    /// Call this during test cleanup to ensure the node stops.
    pub fn abort(&self) {
        self.task.abort();
    }
}
