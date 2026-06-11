//! E2E test for whitelist preconfirmation gossip import and late-join catch-up.
//!
//! Node A builds blocks through the REST API and gossips them; node B joins late
//! and must recover the blocks it missed through the `requestPreconfBlocks` /
//! `responsePreconfBlocks` missing-parent walk before importing the live tip.

mod common;

use std::time::{Duration, Instant};

use alloy_provider::Provider;
use anyhow::{Result, ensure};
use serial_test::serial;
use test_context::test_context;
use test_harness::{BeaconStubServer, ShastaEnv, wait_for_block};
use tracing::info;

use common::{
    L2Node, block_hash_at, build_preconf_block, get_status, parent_from_latest,
    spawn_whitelist_node,
};

/// Blocks built on node A before node B joins the network.
const PRE_JOIN_BLOCKS: usize = 3;
/// Overall deadline for node B to converge onto node A's preconf chain.
const CATCH_UP_DEADLINE: Duration = Duration::from_secs(90);
/// Per-block wait while probing node B for convergence between builds.
const PER_BLOCK_PROBE: Duration = Duration::from_secs(5);

#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn gossip_import_and_late_join_catchup(env: &mut ShastaEnv) -> Result<()> {
    let beacon = BeaconStubServer::start().await?;
    let http = reqwest::Client::new();

    info!("starting whitelist driver node A (L2 node 0)");
    let node_a = spawn_whitelist_node(env, &beacon, L2Node::Primary, Vec::new()).await?;

    // Build a few blocks before node B exists; B must later backfill these.
    let mut parent = parent_from_latest(&node_a.l2_provider).await?;
    let first_built = parent.number + 1;
    for _ in 0..PRE_JOIN_BLOCKS {
        parent = build_preconf_block(&http, &node_a, env, &parent, false).await?;
    }
    info!(tip = parent.number, "built pre-join blocks on node A");

    let status_a = get_status(&http, &node_a).await?;
    ensure!(
        status_a["highestUnsafeL2PayloadBlockId"].as_u64() == Some(parent.number),
        "node A status should report the built tip (got {status_a})"
    );

    info!("starting whitelist driver node B (L2 node 1), late join");
    let node_b =
        spawn_whitelist_node(env, &beacon, L2Node::Secondary, vec![node_a.p2p_addr.clone()])
            .await?;
    let b_head = node_b.l2_provider.get_block_number().await?;
    ensure!(b_head < first_built, "node B should start behind the preconf chain (head {b_head})");

    // Keep sequencing on A until B converges: each freshly gossiped block triggers
    // B's missing-parent request walk, which backfills everything built pre-join.
    let deadline = Instant::now() + CATCH_UP_DEADLINE;
    let tip = loop {
        parent = build_preconf_block(&http, &node_a, env, &parent, false).await?;
        if wait_for_block(&node_b.l2_provider, parent.number, PER_BLOCK_PROBE).await.is_ok() {
            break parent;
        }
        ensure!(
            Instant::now() < deadline,
            "node B failed to catch up to the preconf tip {} in time",
            parent.number
        );
    };
    info!(tip = tip.number, "node B reached the preconf tip");

    // Every preconf block must be identical on both nodes.
    for number in first_built..=tip.number {
        let hash_a = block_hash_at(&node_a.l2_provider, number).await?;
        let hash_b = block_hash_at(&node_b.l2_provider, number).await?;
        ensure!(hash_a == hash_b, "block {number} hash mismatch: node A {hash_a}, node B {hash_b}");
    }

    let status_b = get_status(&http, &node_b).await?;
    ensure!(
        status_b["highestUnsafeL2PayloadBlockId"].as_u64() == Some(tip.number),
        "node B status should report the imported tip (got {status_b})"
    );

    node_b.stop();
    node_a.stop();
    beacon.shutdown().await?;
    Ok(())
}
