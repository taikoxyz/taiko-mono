//! Test utilities for preconfirmation integration tests.
//!
//! This module provides utilities for testing the preconfirmation client:
//!
//! ## Driver Implementations
//! - [`MockDriverClient`]: A mock driver client that records submissions for verification.
//! - [`SafeTipDriverClient`]: Wraps a real driver client with safe-tip fallback.
//! - [`RealDriverSetup`]: Full driver setup for E2E tests with actual block production.
//!
//! ## Lookahead Resolvers
//! - [`StaticLookaheadResolver`]: A static lookahead resolver for deterministic tests.
//! - [`EchoLookaheadResolver`]: A resolver that echoes the timestamp as submission window end.
//!
//! ## P2P Testing
//! - [`test_p2p_config`]: Creates a local-only P2P config for isolated tests.
//! - [`ExternalP2pNode`]: A spawned P2P node for publishing gossip.
//!
//! ## Client Setup
//! - [`RunningPreconfClient`]: A running client with event receiver and task handle.
//! - [`TestPreconfClientConfig`]: Configuration options for test clients.
//! - [`spawn_test_preconf_client`]: Spawns a configured preconf client.
//!
//! ## Event Waiting
//! - [`wait_for_peer_connected`]: Waits for a P2P peer connection.
//! - [`wait_for_commitment_and_txlist`]: Waits for gossip to arrive.
//! - [`wait_for_synced`]: Waits for sync completion.
//!
//! ## Payload Building
//! - [`PreparedBlock`]: A txlist + commitment pair for publishing.
//! - [`build_publish_payloads`]: Assembles preconfirmation payloads.
//! - [`derive_signer`]: Creates deterministic test signers.

mod client;
mod driver;
mod events;
mod lookahead;
mod p2p;
mod payloads;
mod rpc_client;

pub use client::{RunningPreconfClient, TestPreconfClientConfig, spawn_test_preconf_client};
pub use driver::{MockDriverClient, RealDriverSetup, SafeTipDriverClient, StartingBlockInfo};
pub use events::{
    wait_for_commitment_and_txlist, wait_for_commitments_and_txlists, wait_for_peer_connected,
    wait_for_synced,
};
pub use lookahead::{EchoLookaheadResolver, StaticLookaheadResolver};
pub use p2p::{
    ConnectedP2pMesh, ExternalP2pNode, spawn_connected_p2p_mesh,
    spawn_connected_p2p_mesh_with_error_handling, test_p2p_config,
};
pub use payloads::{
    PreparedBlock, build_commitment_chain, build_empty_txlist, build_publish_payloads,
    build_publish_payloads_with_txs, build_txlist_bytes, compute_starting_block,
    compute_txlist_hash, derive_signer,
};
pub use rpc_client::{DriverEndpoint, RpcDriverClient, RpcDriverClientConfig};
