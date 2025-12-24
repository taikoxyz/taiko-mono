//! Minimal node wrapper providing the simplified P2P API.
//!
//! This module provides [`P2pNode`], a high-level abstraction over the network driver
//! that simplifies running a preconfirmation P2P node.

use anyhow::Result;
use futures::future::poll_fn;

use crate::{
    config::{NetworkConfig, P2pConfig},
    driver::NetworkDriver,
    handle::P2pHandle,
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
