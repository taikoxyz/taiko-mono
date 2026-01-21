//! Catch-up E2E test for the preconfirmation client.
//!
//! This test validates that a late-joining node can backfill commitments via
//! request/response, fetch missing txlists, and submit the contiguous chain
//! in order.

#[path = "common/helpers.rs"]
mod helpers;

use std::{sync::Arc, time::Duration};

use alloy_primitives::{B256, U256};
use anyhow::anyhow;
use helpers::{
    ExternalP2pNode, build_commitment_chain, derive_signer, test_p2p_config,
    wait_for_peer_connected, wait_for_synced,
};
use preconfirmation_net::NetworkCommand;
use preconfirmation_node::{PreconfirmationClient, PreconfirmationClientConfig};
use preconfirmation_types::{PreconfHead, u256_to_uint256, uint256_to_u256};
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    ShastaEnv,
    preconfirmation::{RealDriverSetup, StaticLookaheadResolver},
    wait_for_block,
};

/// Catch-up should backfill commitments, fetch txlists, and produce blocks in order.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn catchup_backfills_and_fetches_txlists(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let setup = RealDriverSetup::start(env).await?;

    let (signer_sk, signer) = derive_signer(9);
    let submission_window_end = U256::from(5000u64);

    let (start_block_num, base_timestamp) = setup.compute_starting_block_info().await?;

    let chain_len = 3usize;
    let chain = build_commitment_chain(
        &signer_sk,
        signer,
        submission_window_end,
        start_block_num,
        chain_len,
        base_timestamp,
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

    let internal_client = PreconfirmationClient::new(int_cfg, setup.driver_client.clone())?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    wait_for_peer_connected(&mut events).await;
    wait_for_synced(&mut events).await;

    // Wait for all blocks to be produced on chain.
    let timeout = Duration::from_secs(30);
    for i in 0..chain_len {
        let block_num = start_block_num + i as u64;
        let block = wait_for_block(&setup.l2_provider, block_num, timeout).await?;
        assert_eq!(
            block.header.inner.number, block_num,
            "block {} should be {}, got {}",
            i, block_num, block.header.inner.number
        );
    }

    event_loop_handle.abort();
    ext_node.abort();
    setup.stop().await?;
    Ok(())
}
