//! Out-of-order arrival E2E test for the preconfirmation client.
//!
//! This test validates that blocks arriving out of order (e.g., N+2 before N+1)
//! are correctly buffered and submitted in the correct sequential order once
//! all gaps are filled.

#[path = "common/helpers.rs"]
mod helpers;
#[path = "common/mock_driver.rs"]
mod mock_driver;

use std::{sync::Arc, time::Duration};

use alloy_primitives::U256;
use helpers::{
    ExternalP2pNode, build_publish_payloads, compute_starting_block, derive_signer, test_p2p_config,
    wait_for_commitments_and_txlists, wait_for_peer_connected,
};
use mock_driver::MockDriver;
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, init_tracing, preconfirmation::StaticLookaheadResolver};
use tokio::time::sleep;

/// Test that blocks arriving out of order are buffered and submitted correctly.
///
/// This test:
/// 1. Publishes block N+1 first (should be buffered, not submitted)
/// 2. Publishes block N (fills the gap, both should be submitted in order)
/// 3. Verifies blocks are submitted in correct sequential order (N, N+1)
#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn out_of_order_blocks_buffered_and_submitted_in_order(
    _env: &mut ShastaEnv,
) -> anyhow::Result<()> {
    init_tracing("info");

    let driver_client = MockDriver::new(U256::ZERO, U256::ZERO);

    let (signer_sk, signer) = derive_signer(1);
    let submission_window_end = U256::from(1000u64);

    let starting_block_num = compute_starting_block(&driver_client).await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

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

    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    // Build blocks N and N+1.
    let gas_limit = 30_000_000u64;
    let base_timestamp = 100u64;

    let block_n = build_publish_payloads(
        &signer_sk,
        signer,
        starting_block_num,
        base_timestamp,
        gas_limit,
        submission_window_end,
        true,
    )?;

    let block_n_plus_1 = build_publish_payloads(
        &signer_sk,
        signer,
        starting_block_num + 1,
        base_timestamp + 1,
        gas_limit,
        submission_window_end,
        true,
    )?;

    // Publish block N+1 first (out of order).
    ext_node.handle.publish_raw_txlist(block_n_plus_1.txlist).await?;
    ext_node.handle.publish_commitment(block_n_plus_1.commitment).await?;

    // Give some time for the block to be received and buffered.
    sleep(Duration::from_millis(100)).await;

    // Verify no submissions yet (block N+1 should be buffered waiting for N).
    assert_eq!(driver_client.submission_count(), 0, "block N+1 should be buffered, not submitted");

    // Now publish block N (fills the gap).
    ext_node.handle.publish_raw_txlist(block_n.txlist).await?;
    ext_node.handle.publish_commitment(block_n.commitment).await?;

    // Wait for both blocks to be submitted.
    wait_for_commitments_and_txlists(&mut events, 2, 2).await;
    driver_client.wait_for_submissions(2).await;

    // Verify blocks were submitted in correct order.
    let submitted = driver_client.submitted_blocks();
    assert_eq!(submitted.len(), 2, "expected 2 submissions");
    assert_eq!(submitted[0], starting_block_num, "first submission should be block N");
    assert_eq!(submitted[1], starting_block_num + 1, "second submission should be block N+1");

    event_loop_handle.abort();
    ext_node.abort();
    Ok(())
}

/// Test that partial gap filling triggers sequential submission.
///
/// This test:
/// 1. Publishes blocks N+3 and N (N+1, N+2 missing, creating gaps)
/// 2. Verifies N is submitted but N+3 is buffered
/// 3. Publishes N+1 (N submits, but gap at N+2 still blocks N+3)
/// 4. Publishes N+2 to fill all gaps
/// 5. Verifies N+2 and N+3 are now submitted in order
#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn partial_gap_filled_triggers_submission(_env: &mut ShastaEnv) -> anyhow::Result<()> {
    init_tracing("info");

    let driver_client = MockDriver::new(U256::ZERO, U256::ZERO);

    let (signer_sk, signer) = derive_signer(5);
    let submission_window_end = U256::from(4000u64);

    let starting_block_num = compute_starting_block(&driver_client).await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

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

    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    // Build 4 blocks: N, N+1, N+2, N+3.
    let gas_limit = 30_000_000u64;
    let base_timestamp = 400u64;

    let mut blocks = Vec::with_capacity(4);
    for i in 0..4 {
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

    // Step 1: Publish N+3 (should be buffered).
    ext_node.handle.publish_raw_txlist(blocks[3].txlist.clone()).await?;
    ext_node.handle.publish_commitment(blocks[3].commitment.clone()).await?;
    sleep(Duration::from_millis(100)).await;

    assert_eq!(driver_client.submission_count(), 0, "N+3 should be buffered");

    // Step 2: Publish N (the first block, should trigger submission of N).
    ext_node.handle.publish_raw_txlist(blocks[0].txlist.clone()).await?;
    ext_node.handle.publish_commitment(blocks[0].commitment.clone()).await?;

    driver_client.wait_for_submissions(1).await;
    assert_eq!(driver_client.submission_count(), 1, "only N should be submitted");

    let submitted_so_far = driver_client.submitted_blocks();
    assert_eq!(submitted_so_far[0], starting_block_num, "first submission should be N");

    // Step 3: Publish N+1 (should trigger submission of N+1).
    ext_node.handle.publish_raw_txlist(blocks[1].txlist.clone()).await?;
    ext_node.handle.publish_commitment(blocks[1].commitment.clone()).await?;

    driver_client.wait_for_submissions(2).await;
    sleep(Duration::from_millis(100)).await;

    // N+3 should still be buffered (gap at N+2).
    assert_eq!(driver_client.submission_count(), 2, "N+3 should still be buffered (gap at N+2)");

    // Step 4: Publish N+2 to fill the gap.
    ext_node.handle.publish_raw_txlist(blocks[2].txlist.clone()).await?;
    ext_node.handle.publish_commitment(blocks[2].commitment.clone()).await?;

    // Now all 4 blocks should be submitted.
    wait_for_commitments_and_txlists(&mut events, 4, 4).await;
    driver_client.wait_for_submissions(4).await;

    let submitted = driver_client.submitted_blocks();
    assert_eq!(submitted.len(), 4);

    // Verify correct sequential order.
    for (i, &block_num) in submitted.iter().enumerate() {
        let expected = starting_block_num + i as u64;
        assert_eq!(block_num, expected, "block {} should be {}, got {}", i, expected, block_num);
    }

    event_loop_handle.abort();
    ext_node.abort();
    Ok(())
}
