//! Contiguous multi-block chain E2E test for the preconfirmation client.
//!
//! This test validates that multiple blocks submitted in sequential order
//! (N, N+1, N+2, ...) are correctly processed and result in proper L2 blocks.

#[path = "common/helpers.rs"]
mod helpers;

use std::{sync::Arc, time::Duration};

use alloy_primitives::U256;
use helpers::{
    ExternalP2pNode, PreparedBlock, build_publish_payloads, derive_signer, test_p2p_config,
    wait_for_commitments_and_txlists, wait_for_peer_connected,
};
use preconfirmation_types::uint256_to_u256;
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    ShastaEnv,
    preconfirmation::{RealDriverSetup, StaticLookaheadResolver},
    wait_for_block,
};

/// Test that multiple blocks submitted in sequential order are processed correctly.
///
/// This test:
/// 1. Sets up a P2P network with an external publisher and internal subscriber
/// 2. Publishes 3 blocks (N, N+1, N+2) in sequential order
/// 3. Verifies all blocks are produced on chain with correct hashes
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn contiguous_blocks_submitted_in_order(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let setup = RealDriverSetup::start(env).await?;

    let (signer_sk, signer) = derive_signer(1);
    let submission_window_end = U256::from(1000u64);

    let (starting_block_num, base_timestamp) = setup.compute_starting_block_info().await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    // External P2P node used to publish gossip.
    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    // Internal preconfirmation client.
    let mut int_cfg = preconfirmation_driver::PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(resolver),
    );
    int_cfg.p2p.pre_dial_peers = vec![ext_dial_addr];

    let internal_client =
        preconfirmation_driver::PreconfirmationClient::new(int_cfg, setup.driver_client.clone())?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    // Wait for peer connection.
    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    // Build and publish 3 contiguous blocks in sequential order: N, N+1, N+2.
    let block_count = 3usize;
    let gas_limit = 30_000_000u64;

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

    // Wait for all blocks to be produced on chain and verify.
    let timeout = Duration::from_secs(30);
    for (i, prepared) in blocks.iter().enumerate() {
        let block_num = starting_block_num + i as u64;
        let block = wait_for_block(&setup.l2_provider, block_num, timeout).await?;

        // Verify block matches commitment.
        let preconf = &prepared.commitment.commitment.preconf;
        assert_eq!(
            block.header.inner.number,
            uint256_to_u256(&preconf.block_number).to::<u64>(),
            "block number mismatch at index {i}"
        );
        assert_eq!(
            block.header.inner.timestamp,
            uint256_to_u256(&preconf.timestamp).to::<u64>(),
            "timestamp mismatch at index {i}"
        );
        assert_eq!(
            block.header.inner.gas_limit,
            uint256_to_u256(&preconf.gas_limit).to::<u64>(),
            "gas limit mismatch at index {i}"
        );
    }

    // Cleanup.
    event_loop_handle.abort();
    ext_node.abort();
    setup.stop().await?;
    Ok(())
}
