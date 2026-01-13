//! Minimal node wrapper providing the simplified P2P API.
//!
//! This module provides [`P2pNode`], a high-level abstraction over the network driver
//! that simplifies running a preconfirmation P2P node.

use anyhow::Result;
use futures::future::poll_fn;
use std::sync::Arc;

use crate::{
    config::{NetworkConfig, P2pConfig},
    driver::NetworkDriver,
    handle::P2pHandle,
    storage::PreconfStorage,
    validation::ValidationAdapter,
};

/// Minimal node wrapper around the network driver.
///
/// This struct provides a simplified interface for running a preconfirmation P2P node.
/// It encapsulates the [`NetworkDriver`] and provides a `run` method that drives
/// the network event loop.
///
/// # Example
///
/// ```ignore
/// let config = P2pConfig::default();
/// let validator = Box::new(LocalValidationAdapter::new(expected_slasher));
/// let (handle, node) = P2pNode::new(config, validator)?;
///
/// // Spawn the node to run in the background
/// tokio::spawn(async move {
///     if let Err(e) = node.run().await {
///         eprintln!("Node error: {e}");
///     }
/// });
///
/// // Use the handle to interact with the network
/// handle.publish_commitment(commitment).await?;
/// ```
pub struct P2pNode {
    /// The underlying network driver that manages the libp2p swarm.
    driver: NetworkDriver,
}

impl P2pNode {
    /// Create a new P2P node with the given configuration and validation adapter.
    ///
    /// This initializes the libp2p transport, behaviours, and driver, returning
    /// both a handle for interacting with the network and the node itself.
    ///
    /// # Arguments
    ///
    /// * `cfg` - The P2P configuration specifying listen addresses, bootnodes, etc.
    /// * `validator` - A validation adapter for verifying inbound messages.
    ///
    /// # Returns
    ///
    /// A tuple of `(P2pHandle, P2pNode)` on success, where the handle can be used
    /// to send commands and receive events, and the node should be run in a background task.
    pub fn new(cfg: P2pConfig, validator: Box<dyn ValidationAdapter>) -> Result<(P2pHandle, Self)> {
        let net_cfg: NetworkConfig = cfg.into();
        let (driver, handle) = NetworkDriver::new_with_validator(net_cfg, validator)?;
        Ok((P2pHandle::new(handle), Self { driver }))
    }

    /// Create a new P2P node with the given configuration, validation adapter, and storage.
    pub fn new_with_validator_and_storage(
        cfg: P2pConfig,
        validator: Box<dyn ValidationAdapter>,
        storage: Arc<dyn PreconfStorage>,
    ) -> Result<(P2pHandle, Self)> {
        let net_cfg: NetworkConfig = cfg.into();
        let (driver, handle) =
            NetworkDriver::new_with_validator_and_storage(net_cfg, validator, Some(storage))?;
        Ok((P2pHandle::new(handle), Self { driver }))
    }

    /// Run the P2P node, driving the network event loop until shutdown.
    ///
    /// This method continuously polls the network driver, processing incoming
    /// network events and dispatching commands. It does not return unless an
    /// unrecoverable error occurs.
    ///
    /// This should typically be spawned as a background task.
    pub async fn run(mut self) -> Result<()> {
        loop {
            poll_fn(|cx| self.driver.poll(cx)).await;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{storage::InMemoryStorage, validation::LocalValidationAdapter};
    use std::net::{IpAddr, Ipv4Addr, SocketAddr};

    fn test_config() -> P2pConfig {
        let mut cfg = P2pConfig::default();
        cfg.listen_addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
        cfg.discovery_listen = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
        cfg.enable_discovery = false;
        cfg
    }

    #[tokio::test]
    async fn new_with_validator_and_storage_returns_ok() {
        let cfg = test_config();
        let validator: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
        let storage: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());

        P2pNode::new_with_validator_and_storage(cfg, validator, storage)
            .unwrap_or_else(|err| panic!("{:#}", err));
    }

    #[tokio::test]
    async fn p2p_handle_exposes_local_peer_id() {
        let cfg = test_config();
        let validator: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
        let storage: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());

        let (handle, _node) = P2pNode::new_with_validator_and_storage(cfg, validator, storage)
            .expect("node creation failed");

        // Verify local_peer_id is accessible and non-zero
        let peer_id = handle.local_peer_id();
        assert!(!peer_id.to_bytes().is_empty());
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn p2p_handle_dial_and_wait_for_connection() {
        // Create two nodes
        let cfg1 = test_config();
        let cfg2 = test_config();

        let validator1: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
        let validator2: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
        let storage1: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());
        let storage2: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());

        let (mut handle1, node1) =
            P2pNode::new_with_validator_and_storage(cfg1, validator1, storage1)
                .expect("node1 creation failed");
        let (mut handle2, node2) =
            P2pNode::new_with_validator_and_storage(cfg2, validator2, storage2)
                .expect("node2 creation failed");

        // Spawn both nodes
        let node1_handle = tokio::spawn(async move { node1.run().await });
        let node2_handle = tokio::spawn(async move { node2.run().await });

        // Get node2's dialable address
        let addr2 = handle2.dialable_addr().await.expect("failed to get dialable addr");

        // Node1 dials node2
        handle1.dial(addr2).await.expect("dial failed");

        // Wait for peer connection on handle1
        let connected_peer = handle1
            .wait_for_peer_connected()
            .await
            .expect("event stream closed while waiting for peer connection");

        // Verify the connected peer is node2
        assert_eq!(connected_peer, handle2.local_peer_id());

        // Clean up
        node1_handle.abort();
        node2_handle.abort();
    }
}
