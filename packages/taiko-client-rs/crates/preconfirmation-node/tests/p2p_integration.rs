//! P2P integration test for the preconfirmation client.
//!
//! This test validates that P2P gossip messages received from an external node
//! trigger driver submission and result in actual block production.

#[path = "common/helpers.rs"]
mod helpers;

use std::{sync::Arc, time::Duration};

use alloy_primitives::U256;
use helpers::{
    ExternalP2pNode, PreparedBlock, build_publish_payloads, derive_signer, test_p2p_config,
    wait_for_commitment_and_txlist, wait_for_peer_connected,
};
use preconfirmation_node::{PreconfirmationClient, PreconfirmationClientConfig};
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    ShastaEnv,
    preconfirmation::{RealDriverSetup, StaticLookaheadResolver},
    wait_for_block,
};

/// Tests that P2P gossip messages received from an external node trigger block production.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn p2p_gossip_submits_preconfirmation(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let setup = RealDriverSetup::start(env).await?;

    let (signer_sk, signer) = derive_signer(1);
    let submission_window_end = U256::from(1000u64);

    let block_info = setup.compute_starting_block_info_full().await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    // External P2P node used to publish gossip.
    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    // Internal preconfirmation client with real driver.
    let mut int_cfg =
        PreconfirmationClientConfig::new_with_resolver(test_p2p_config(), Arc::new(resolver));
    int_cfg.p2p.pre_dial_peers = vec![ext_dial_addr];

    let internal_client = PreconfirmationClient::new(int_cfg, setup.driver_client.clone())?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    // Wait for both peers to connect.
    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    // Publish txlist + commitment from external client.
    let PreparedBlock { txlist, commitment } = build_publish_payloads(
        &signer_sk,
        signer,
        block_info.block_number,
        block_info.base_timestamp,
        block_info.gas_limit,
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
