#![allow(dead_code)]
#![allow(unused_imports)]
//! Test-only helpers for preconfirmation-node integration tests.
//!
//! This module re-exports shared helpers from test-harness and provides
//! any test-local utilities specific to preconfirmation-node tests.

// Re-export all shared P2P helpers from test-harness.
pub use test_harness::preconfirmation::{
    ExternalP2pNode, PreparedBlock, build_commitment_chain, build_empty_txlist,
    build_publish_payloads, build_txlist_bytes, compute_starting_block, compute_txlist_hash,
    derive_signer, test_p2p_config, wait_for_commitment_and_txlist,
    wait_for_commitments_and_txlists, wait_for_peer_connected, wait_for_synced,
};

// Re-export DualDriverSetup which is specific to multi-client P2P tests.
// This struct remains here as it's only used by preconfirmation-node tests.
use std::sync::Arc;

use anyhow::Result;
use preconfirmation_net::{
    InMemoryStorage, LocalValidationAdapter, P2pHandle, P2pNode, PreconfStorage, ValidationAdapter,
};
use tokio::task::JoinHandle;

/// Dual-driver test setup for spawning two interconnected P2P nodes.
///
/// This helper creates two P2P nodes with distinct ports and connects them
/// via manual dial, forming a P2P mesh suitable for dual-driver testing scenarios.
pub struct DualDriverSetup {
    /// P2P handle for node A.
    pub handle_a: P2pHandle,
    /// P2P handle for node B.
    pub handle_b: P2pHandle,
    /// Storage for node A.
    pub storage_a: Arc<dyn PreconfStorage>,
    /// Storage for node B.
    pub storage_b: Arc<dyn PreconfStorage>,
    /// Background task for node A.
    task_a: JoinHandle<anyhow::Result<()>>,
    /// Background task for node B.
    task_b: JoinHandle<anyhow::Result<()>>,
}

impl DualDriverSetup {
    /// Spawn two P2P nodes with distinct ports and connect them.
    pub async fn spawn() -> Result<Self> {
        let validator_a: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
        let storage_a: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());
        let (mut handle_a, node_a) = P2pNode::new_with_validator_and_storage(
            test_p2p_config(),
            validator_a,
            storage_a.clone(),
        )?;
        let task_a = tokio::spawn(async move { node_a.run().await });

        let addr_a = handle_a.dialable_addr().await?;

        let validator_b: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
        let storage_b: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());
        let (handle_b, node_b) = P2pNode::new_with_validator_and_storage(
            test_p2p_config(),
            validator_b,
            storage_b.clone(),
        )?;
        let task_b = tokio::spawn(async move { node_b.run().await });

        handle_b.dial(addr_a).await?;

        Ok(Self { handle_a, handle_b, storage_a, storage_b, task_a, task_b })
    }

    /// Abort both P2P node background tasks.
    pub fn abort(&self) {
        self.task_a.abort();
        self.task_b.abort();
    }
}
