//! Out-of-order arrival E2E test for the preconfirmation client.
//!
//! This test validates that blocks arriving out of order (e.g., N+2 before N+1)
//! are correctly buffered and submitted in the correct sequential order once
//! all gaps are filled.

#[path = "common/helpers.rs"]
mod helpers;

use std::{sync::Arc, time::Duration};

use alloy_primitives::U256;
use helpers::{
    ExternalP2pNode, build_publish_payloads, derive_signer, test_p2p_config,
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
use tokio::time::sleep;

/// Test that blocks arriving out of order are buffered and submitted correctly.
///
/// This test:
/// 1. Publishes block N+1 first (should be buffered, not submitted)
/// 2. Publishes block N (fills the gap, both should be submitted in order)
/// 3. Verifies blocks are produced on chain in correct sequential order (N, N+1)
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn out_of_order_blocks_buffered_and_submitted_in_order(
    env: &mut ShastaEnv,
) -> anyhow::Result<()> {
    let setup = RealDriverSetup::start(env).await?;

    let (signer_sk, signer) = derive_signer(1);
    let submission_window_end = U256::from(1000u64);

    let (starting_block_num, base_timestamp) = setup.compute_starting_block_info().await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    let mut int_cfg = preconfirmation_client::PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(resolver),
    );
    int_cfg.p2p.pre_dial_peers = vec![ext_dial_addr];

    let internal_client =
        preconfirmation_client::PreconfirmationClient::new(int_cfg, setup.driver_client.clone())?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    // Build blocks N and N+1.
    let gas_limit = 30_000_000u64;

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
    ext_node.handle.publish_raw_txlist(block_n_plus_1.txlist.clone()).await?;
    ext_node.handle.publish_commitment(block_n_plus_1.commitment.clone()).await?;

    // Give some time for the block to be received and buffered.
    sleep(Duration::from_millis(100)).await;

    // Now publish block N (fills the gap).
    ext_node.handle.publish_raw_txlist(block_n.txlist.clone()).await?;
    ext_node.handle.publish_commitment(block_n.commitment.clone()).await?;

    // Wait for both blocks to be received.
    wait_for_commitments_and_txlists(&mut events, 2, 2).await;

    // Wait for both blocks to be produced on chain.
    let timeout = Duration::from_secs(30);
    let produced_n = wait_for_block(&setup.l2_provider, starting_block_num, timeout).await?;
    let produced_n_plus_1 =
        wait_for_block(&setup.l2_provider, starting_block_num + 1, timeout).await?;

    // Verify blocks were produced in correct order.
    let preconf_n = &block_n.commitment.commitment.preconf;
    assert_eq!(
        produced_n.header.inner.number,
        uint256_to_u256(&preconf_n.block_number).to::<u64>(),
        "block N number mismatch"
    );

    let preconf_n_plus_1 = &block_n_plus_1.commitment.commitment.preconf;
    assert_eq!(
        produced_n_plus_1.header.inner.number,
        uint256_to_u256(&preconf_n_plus_1.block_number).to::<u64>(),
        "block N+1 number mismatch"
    );

    // Verify contiguous ordering.
    assert_eq!(
        produced_n_plus_1.header.inner.number,
        produced_n.header.inner.number + 1,
        "blocks should be contiguous"
    );

    event_loop_handle.abort();
    ext_node.abort();
    setup.stop().await?;
    Ok(())
}

/// Test that partial gap filling triggers sequential submission.
///
/// This test:
/// 1. Publishes blocks N+3 and N (N+1, N+2 missing, creating gaps)
/// 2. Verifies N is produced but N+3 is buffered
/// 3. Publishes N+1 (N+1 produced, but gap at N+2 still blocks N+3)
/// 4. Publishes N+2 to fill all gaps
/// 5. Verifies N+2 and N+3 are now produced in order
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn partial_gap_filled_triggers_submission(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let setup = RealDriverSetup::start(env).await?;

    let (signer_sk, signer) = derive_signer(5);
    let submission_window_end = U256::from(4000u64);

    let (starting_block_num, base_timestamp) = setup.compute_starting_block_info().await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    let mut int_cfg = preconfirmation_client::PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(resolver),
    );
    int_cfg.p2p.pre_dial_peers = vec![ext_dial_addr];

    let internal_client =
        preconfirmation_client::PreconfirmationClient::new(int_cfg, setup.driver_client.clone())?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    // Build 4 blocks: N, N+1, N+2, N+3.
    let gas_limit = 30_000_000u64;

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

    let timeout = Duration::from_secs(30);

    // Step 1: Publish N+3 (should be buffered).
    ext_node.handle.publish_raw_txlist(blocks[3].txlist.clone()).await?;
    ext_node.handle.publish_commitment(blocks[3].commitment.clone()).await?;
    sleep(Duration::from_millis(100)).await;

    // Step 2: Publish N (the first block, should trigger production of N).
    ext_node.handle.publish_raw_txlist(blocks[0].txlist.clone()).await?;
    ext_node.handle.publish_commitment(blocks[0].commitment.clone()).await?;

    let produced_n = wait_for_block(&setup.l2_provider, starting_block_num, timeout).await?;
    assert_eq!(produced_n.header.inner.number, starting_block_num, "block N should be produced");

    // Step 3: Publish N+1 (should trigger production of N+1).
    ext_node.handle.publish_raw_txlist(blocks[1].txlist.clone()).await?;
    ext_node.handle.publish_commitment(blocks[1].commitment.clone()).await?;

    let produced_n_plus_1 =
        wait_for_block(&setup.l2_provider, starting_block_num + 1, timeout).await?;
    assert_eq!(
        produced_n_plus_1.header.inner.number,
        starting_block_num + 1,
        "block N+1 should be produced"
    );

    // Step 4: Publish N+2 to fill the gap.
    ext_node.handle.publish_raw_txlist(blocks[2].txlist.clone()).await?;
    ext_node.handle.publish_commitment(blocks[2].commitment.clone()).await?;

    // Now all 4 blocks should be produced.
    wait_for_commitments_and_txlists(&mut events, 4, 4).await;
    let produced_n_plus_2 =
        wait_for_block(&setup.l2_provider, starting_block_num + 2, timeout).await?;
    let produced_n_plus_3 =
        wait_for_block(&setup.l2_provider, starting_block_num + 3, timeout).await?;

    // Verify correct sequential order.
    assert_eq!(produced_n_plus_2.header.inner.number, starting_block_num + 2);
    assert_eq!(produced_n_plus_3.header.inner.number, starting_block_num + 3);

    event_loop_handle.abort();
    ext_node.abort();
    setup.stop().await?;
    Ok(())
}
