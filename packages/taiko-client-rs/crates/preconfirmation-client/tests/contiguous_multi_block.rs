//! Contiguous multi-block chain E2E test for the preconfirmation client.
//!
//! This test validates that multiple blocks submitted in sequential order
//! (N, N+1, N+2, ...) are correctly processed and result in proper L2 blocks.

#[path = "common/helpers.rs"]
mod helpers;
#[path = "common/mock_driver.rs"]
mod mock_driver;

use std::sync::Arc;

use alloy_primitives::U256;
use helpers::{
    ExternalP2pNode, PreparedBlock, build_publish_payloads, compute_starting_block, derive_signer,
    test_p2p_config, wait_for_commitments_and_txlists, wait_for_peer_connected,
};
use mock_driver::MockDriver;
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, init_tracing, preconfirmation::StaticLookaheadResolver};

/// Test that multiple blocks submitted in sequential order are processed correctly.
///
/// This test:
/// 1. Sets up a P2P network with an external publisher and internal subscriber
/// 2. Publishes 3 blocks (N, N+1, N+2) in sequential order
/// 3. Verifies all blocks are submitted to the driver in correct order
#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn contiguous_blocks_submitted_in_order(_env: &mut ShastaEnv) -> anyhow::Result<()> {
    init_tracing("info");

    let driver_client = MockDriver::new(U256::ZERO, U256::ZERO);

    let (signer_sk, signer) = derive_signer(1);
    let submission_window_end = U256::from(1000u64);

    let starting_block_num = compute_starting_block(&driver_client).await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    // External P2P node used to publish gossip.
    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    // Internal preconfirmation client.
    let mut int_cfg = preconfirmation_client::PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(resolver),
    );
    int_cfg.p2p.pre_dial_peers = vec![ext_dial_addr];

    let internal_client =
        preconfirmation_client::PreconfirmationClient::new(int_cfg, driver_client.clone())?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    // Wait for peer connection.
    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    // Build and publish 3 contiguous blocks in sequential order: N, N+1, N+2.
    let block_count = 3;
    let gas_limit = 30_000_000u64;
    let base_timestamp = 100u64;

    let mut blocks = Vec::with_capacity(block_count);
    for i in 0..block_count {
        let block = build_publish_payloads(
            &signer_sk,
            signer,
            starting_block_num + i as u64,
            base_timestamp + i as u64,
            gas_limit,
            submission_window_end,
            true,
        )?;
        blocks.push(block);
    }

    // Publish blocks in sequential order.
    for PreparedBlock { txlist, commitment } in &blocks {
        ext_node.handle.publish_raw_txlist(txlist.clone()).await?;
        ext_node.handle.publish_commitment(commitment.clone()).await?;
    }

    // Wait for all commitments and txlists to be received.
    wait_for_commitments_and_txlists(&mut events, block_count, block_count).await;

    // Wait for all blocks to be submitted to the driver.
    driver_client.wait_for_submissions(block_count).await;

    // Verify blocks were submitted in correct order.
    let submitted = driver_client.submitted_blocks();
    assert_eq!(submitted.len(), block_count, "expected {} submissions", block_count);

    for (i, &block_num) in submitted.iter().enumerate() {
        let expected = starting_block_num + i as u64;
        assert_eq!(block_num, expected, "block {} should be {}, got {}", i, expected, block_num);
    }

    // Verify contiguous ordering (each block follows the previous).
    for i in 1..submitted.len() {
        assert_eq!(
            submitted[i],
            submitted[i - 1] + 1,
            "blocks should be contiguous: {} should follow {}",
            submitted[i],
            submitted[i - 1]
        );
    }

    // Cleanup.
    event_loop_handle.abort();
    ext_node.abort();
    Ok(())
}
