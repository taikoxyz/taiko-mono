//! P2P integration test for the preconfirmation client.
//!
//! This test validates that P2P gossip messages received from an external node
//! trigger driver submission and result in actual block production.

#[path = "common/helpers.rs"]
mod helpers;

use std::time::Duration;

use alloy_primitives::U256;
use helpers::{
    ExternalP2pNode, PreparedBlock, build_publish_payloads, derive_signer, start_preconf_client,
    wait_for_commitment_and_txlist,
};
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, preconfirmation::RealDriverSetup, wait_for_block};

/// Tests that P2P gossip messages received from an external node trigger block production.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn p2p_gossip_submits_preconfirmation(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let setup = RealDriverSetup::start(env).await?;

    let (signer_sk, signer) = derive_signer(1);
    let submission_window_end = U256::from(1000u64);

    let block_info = setup.compute_starting_block_info().await?;

    // External P2P node used to publish gossip.
    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    // Internal preconfirmation client with real driver.
    let (mut events, event_loop_handle, _) = start_preconf_client(
        signer,
        submission_window_end,
        vec![ext_dial_addr],
        setup.driver_client.clone(),
    )
    .await?;
    ext_node.handle.wait_for_peer_connected().await?;

    // Publish txlist + commitment from external client.
    let PreparedBlock { txlist, commitment } = build_publish_payloads(
        &signer_sk,
        signer,
        block_info.block_number,
        block_info.base_timestamp,
        block_info.parent_gas_limit,
        submission_window_end,
        false,
    )?;
    ext_node.handle.publish_raw_txlist(txlist).await?;
    ext_node.handle.publish_commitment(commitment).await?;

    // Internal client should observe txlist + commitment.
    wait_for_commitment_and_txlist(&mut events).await;

    // Verify actual block was produced on chain.
    let block =
        wait_for_block(&setup.l2_provider, block_info.block_number, Duration::from_secs(30))
            .await?;
    assert_eq!(block.header.inner.number, block_info.block_number, "block number mismatch");

    event_loop_handle.abort();
    ext_node.abort();
    setup.stop().await?;

    Ok(())
}
