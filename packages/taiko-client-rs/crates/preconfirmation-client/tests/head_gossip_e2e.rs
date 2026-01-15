//! Head update gossip E2E test for the preconfirmation client.
//!
//! This test validates that a node updates its served head after receiving
//! a new commitment, and that peers can observe the updated head via req/resp.

#[path = "common/helpers.rs"]
mod helpers;
#[path = "common/mock_driver.rs"]
mod mock_driver;

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::U256;
use anyhow::{Result, anyhow};
use helpers::{
    ExternalP2pNode, PreparedBlock, build_publish_payloads, compute_starting_block, derive_signer,
    test_p2p_config, wait_for_commitment_and_txlist, wait_for_peer_connected,
};
use mock_driver::MockDriver;
use preconfirmation_net::P2pHandle;
use preconfirmation_types::uint256_to_u256;
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, preconfirmation::StaticLookaheadResolver};
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
async fn head_update_propagates_to_peer(_env: &mut ShastaEnv) -> anyhow::Result<()> {
    let driver_client = MockDriver::new(U256::ZERO, U256::ZERO);

    let (signer_sk, signer) = derive_signer(7);
    let submission_window_end = U256::from(2500u64);

    let commitment_block_num = compute_starting_block(&driver_client).await?;
    let commitment_block = U256::from(commitment_block_num);

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    // External P2P node used to publish gossip and query head.
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

    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    let PreparedBlock { txlist, commitment } = build_publish_payloads(
        &signer_sk,
        signer,
        commitment_block_num,
        1,
        30_000_000,
        submission_window_end,
        false,
    )?;
    ext_node.handle.publish_raw_txlist(txlist).await?;
    ext_node.handle.publish_commitment(commitment).await?;

    wait_for_commitment_and_txlist(&mut events).await;
    driver_client.wait_for_submissions(1).await;

    wait_for_head(&mut ext_node.handle, commitment_block, Duration::from_secs(3)).await?;

    event_loop_handle.abort();
    ext_node.abort();
    Ok(())
}
