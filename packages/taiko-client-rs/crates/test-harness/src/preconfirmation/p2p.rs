//! P2P test utilities for preconfirmation integration tests.
//!
//! This module provides helpers for setting up P2P nodes in test environments:
//! - [`test_p2p_config`]: Creates a local-only P2P configuration with ephemeral ports.
//! - [`ExternalP2pNode`]: A spawned P2P node for publishing gossip in tests.
//! - [`ConnectedP2pMesh`]: A connected pair of external and internal P2P nodes.
//! - [`spawn_connected_p2p_mesh`]: Spawns and connects external + internal nodes.

use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::Arc,
};

use alloy_primitives::{Address, U256};
use anyhow::Result;
use preconfirmation_client::DriverClient;
use preconfirmation_net::{
    InMemoryStorage, LocalValidationAdapter, P2pConfig, P2pHandle, P2pNode, PreconfStorage,
    ValidationAdapter,
};
use secp256k1::SecretKey;
use tokio::task::JoinHandle;

use super::{
    RunningPreconfClient, TestPreconfClientConfig, spawn_test_preconf_client,
    wait_for_peer_connected,
};

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

/// A connected P2P test mesh with external publisher and internal client.
///
/// This bundles the common setup pattern where:
/// - An external node publishes gossip (simulating another preconfirmer)
/// - An internal client receives and processes gossip
/// - Both are connected and ready for testing
///
/// # Example
///
/// ```ignore
/// let mesh = spawn_connected_p2p_mesh(driver_client, Default::default()).await?;
///
/// // Publish from external node
/// let block = build_publish_payloads(&mesh.signer_sk, mesh.signer, ...)?;
/// mesh.external.handle.publish_raw_txlist(block.txlist).await?;
/// mesh.external.handle.publish_commitment(block.commitment).await?;
///
/// // Wait for internal client to receive
/// wait_for_commitment_and_txlist(&mut mesh.internal.events).await;
///
/// mesh.abort();
/// ```
pub struct ConnectedP2pMesh {
    /// External node for publishing gossip.
    pub external: ExternalP2pNode,
    /// Running internal preconf client.
    pub internal: RunningPreconfClient,
    /// Signer secret key for building commitments.
    pub signer_sk: SecretKey,
    /// Signer address.
    pub signer: Address,
    /// Submission window end used for the resolver.
    pub submission_window_end: U256,
}

impl ConnectedP2pMesh {
    /// Aborts both the external node and internal client.
    pub fn abort(&self) {
        self.external.abort();
        self.internal.abort();
    }
}

/// Spawns a connected P2P mesh for testing.
///
/// This handles the boilerplate of:
/// 1. Spawning an external P2P node
/// 2. Creating an internal preconf client configured to dial the external node
/// 3. Waiting for both peers to connect
///
/// # Arguments
///
/// * `driver_client` - The driver client implementation.
/// * `config` - Test configuration options.
///
/// # Returns
///
/// A connected mesh ready for publishing and receiving gossip.
///
/// # Example
///
/// ```ignore
/// let mesh = spawn_connected_p2p_mesh(driver_client, Default::default()).await?;
///
/// let block = build_publish_payloads(&mesh.signer_sk, mesh.signer, block_num, ...)?;
/// mesh.external.handle.publish_raw_txlist(block.txlist).await?;
/// mesh.external.handle.publish_commitment(block.commitment).await?;
///
/// wait_for_commitment_and_txlist(&mut mesh.internal.events).await;
/// mesh.abort();
/// ```
pub async fn spawn_connected_p2p_mesh<D>(
    driver_client: D,
    config: TestPreconfClientConfig,
) -> Result<ConnectedP2pMesh>
where
    D: DriverClient + Send + Sync + 'static,
{
    let mut external = ExternalP2pNode::spawn()?;
    let ext_dial_addr = external.handle.dialable_addr().await?;
    let submission_window_end = config.submission_window_end;

    let internal_config = TestPreconfClientConfig { pre_dial_peers: vec![ext_dial_addr], ..config };
    let (mut internal, signer_sk, signer) =
        spawn_test_preconf_client(driver_client, internal_config).await?;

    wait_for_peer_connected(&mut internal.events).await;
    external.handle.wait_for_peer_connected().await?;

    Ok(ConnectedP2pMesh { external, internal, signer_sk, signer, submission_window_end })
}

/// Spawns a connected mesh with result channel for select! error handling.
///
/// Use this variant when you need to detect event loop errors during block waits.
pub async fn spawn_connected_p2p_mesh_with_error_handling<D>(
    driver_client: D,
    config: TestPreconfClientConfig,
) -> Result<ConnectedP2pMesh>
where
    D: DriverClient + Send + Sync + 'static,
{
    let config = TestPreconfClientConfig { with_result_channel: true, ..config };
    spawn_connected_p2p_mesh(driver_client, config).await
}
