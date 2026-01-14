//! Catch-up E2E test for the preconfirmation client.
//!
//! This test validates that a late-joining node can backfill commitments via
//! request/response, fetch missing txlists, and submit the contiguous chain
//! in order.

#[path = "common/helpers.rs"]
mod helpers;
#[path = "common/mock_driver.rs"]
mod mock_driver;

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use anyhow::anyhow;
use helpers::{
    ExternalP2pNode, build_commitment_chain, compute_starting_block, derive_signer,
    test_p2p_config, wait_for_peer_connected, wait_for_synced,
};
use mock_driver::MockDriver;
use preconfirmation_client::{PreconfirmationClient, PreconfirmationClientConfig};
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{PreconfHead, u256_to_uint256, uint256_to_u256};
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, init_tracing, preconfirmation::StaticLookaheadResolver};

/// Catch-up should backfill commitments, fetch txlists, and submit in order.
#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn catchup_backfills_and_fetches_txlists(_env: &mut ShastaEnv) -> anyhow::Result<()> {
    init_tracing("info");

    let driver_client = MockDriver::new(U256::ZERO, U256::ZERO);

    let (signer_sk, signer) = derive_signer(9);
    let submission_window_end = U256::from(5000u64);

    let start_block_num = compute_starting_block(&driver_client).await?;

    let chain_len = 3;
    let chain = build_commitment_chain(
        &signer_sk,
        signer,
        submission_window_end,
        start_block_num,
        chain_len,
    )?;

    // External P2P node seeded with commitments and txlists.
    let mut ext_node = ExternalP2pNode::spawn()?;

    for block in &chain {
        let block_u256 = uint256_to_u256(&block.commitment.commitment.preconf.block_number);
        ext_node.storage.insert_commitment(block_u256, block.commitment.clone());
        let hash = B256::from_slice(block.txlist.raw_tx_list_hash.as_ref());
        ext_node.storage.insert_txlist(hash, block.txlist.clone());
    }

    let tip_block_num = start_block_num + chain_len as u64 - 1;
    let head = PreconfHead {
        block_number: u256_to_uint256(U256::from(tip_block_num)),
        submission_window_end: u256_to_uint256(submission_window_end),
    };
    ext_node
        .handle
        .command_sender()
        .send(NetworkCommand::UpdateHead { head })
        .await
        .map_err(|err| anyhow!("update head failed: {err}"))?;

    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);
    let mut int_cfg =
        PreconfirmationClientConfig::new_with_resolver(test_p2p_config(), Arc::new(resolver));
    int_cfg.p2p.pre_dial_peers = vec![ext_dial_addr];

    let internal_client = PreconfirmationClient::new(int_cfg, driver_client.clone())?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    wait_for_peer_connected(&mut events).await;
    wait_for_synced(&mut events).await;

    driver_client.wait_for_submissions(chain_len).await;

    let submitted = driver_client.submitted_blocks();
    assert_eq!(submitted.len(), chain_len);
    for (i, &block_num) in submitted.iter().enumerate() {
        let expected = start_block_num + i as u64;
        assert_eq!(block_num, expected, "block {} should be {}, got {}", i, expected, block_num);
    }

    event_loop_handle.abort();
    ext_node.abort();
    Ok(())
}
