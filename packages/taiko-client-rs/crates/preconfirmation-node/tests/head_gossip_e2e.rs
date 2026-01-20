//! Head update gossip E2E test for the preconfirmation client.
//!
//! This test validates that a node updates its served head after receiving
//! a new commitment, and that peers can observe the updated head via req/resp.

#[path = "common/helpers.rs"]
mod helpers;

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::U256;
use anyhow::{Result, anyhow};
use helpers::{
    ExternalP2pNode, PreparedBlock, build_publish_payloads, derive_signer, test_p2p_config,
    wait_for_commitment_and_txlist, wait_for_peer_connected,
};
use preconfirmation_net::P2pHandle;
use preconfirmation_types::uint256_to_u256;
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    ShastaEnv,
    preconfirmation::{RealDriverSetup, StaticLookaheadResolver},
    wait_for_block,
};
use tokio::time::sleep;

async fn wait_for_head(
    handle: &mut P2pHandle,
    expected_block: U256,
    timeout: Duration,
) -> Result<()> {
    let start = Instant::now();
    loop {
        if start.elapsed() > timeout {
            return Err(anyhow!("timed out waiting for head {expected_block}"));
        }

        if let Ok(head) = handle.request_head(None).await {
            let head_block = uint256_to_u256(&head.block_number);
            if head_block == expected_block {
                return Ok(());
            }
        }

        sleep(Duration::from_millis(50)).await;
    }
}

#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn head_update_propagates_to_peer(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let setup = RealDriverSetup::start(env).await?;

    let (signer_sk, signer) = derive_signer(7);
    let submission_window_end = U256::from(2500u64);

    let block_info = setup.compute_starting_block_info_full().await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    // External P2P node used to publish gossip and query head.
    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    // Internal preconfirmation client.
    let mut int_cfg = preconfirmation_node::PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(resolver),
    );
    int_cfg.p2p.pre_dial_peers = vec![ext_dial_addr];

    let internal_client =
        preconfirmation_node::PreconfirmationClient::new(int_cfg, setup.driver_client.clone())?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

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

    wait_for_commitment_and_txlist(&mut events).await;

    // Wait for actual block to be produced on chain.
    let block =
        wait_for_block(&setup.l2_provider, block_info.block_number, Duration::from_secs(30))
            .await?;
    assert_eq!(block.header.inner.number, block_info.block_number, "block number mismatch");

    // Verify head propagated to peer.
    let commitment_block = U256::from(block_info.block_number);
    wait_for_head(&mut ext_node.handle, commitment_block, Duration::from_secs(3)).await?;

    event_loop_handle.abort();
    ext_node.abort();
    setup.stop().await?;
    Ok(())
}
