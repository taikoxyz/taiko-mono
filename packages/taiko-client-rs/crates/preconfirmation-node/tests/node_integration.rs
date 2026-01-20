//! Integration tests for `PreconfirmationNode`.

use preconfirmation_node::{PreconfirmationNode, PreconfirmationNodeConfig, RpcServerConfig};

/// Verify that the node can be constructed and its RPC server can start.
#[tokio::test]
#[ignore]
async fn test_node_starts_and_exposes_rpc() {
    // TODO: Implement with proper test harness setup.
    let _ = (std::mem::size_of::<PreconfirmationNode>(), RpcServerConfig::default());
    let _ = std::mem::size_of::<PreconfirmationNodeConfig>();
}

/// Verify publishing a commitment via RPC.
#[tokio::test]
#[ignore]
async fn test_publish_commitment_via_rpc() {
    // TODO: Implement.
}

/// Verify retrieving commitments from local cache via RPC.
#[tokio::test]
#[ignore]
async fn test_get_commitments_from_cache() {
    // TODO: Implement.
}

/// Verify the status endpoint responds with current tips.
#[tokio::test]
#[ignore]
async fn test_get_status() {
    // TODO: Implement.
}
