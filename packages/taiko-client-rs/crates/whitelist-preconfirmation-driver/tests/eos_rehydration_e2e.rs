//! E2E test for end-of-sequencing status propagation and restart rehydration.
//!
//! Node A builds an EOS-marked block; both nodes must expose its hash via
//! `GET /status`. Node B is then restarted: its in-memory EOS marker is lost, and
//! the startup rehydration task must recover it from node A through the
//! `requestEndOfSequencingPreconfBlocks` gossip topic.

mod common;

use std::time::{Duration, Instant};

use alloy_provider::Provider;
use anyhow::{Result, ensure};
use serial_test::serial;
use test_context::test_context;
use test_harness::{BeaconStubServer, ShastaEnv, wait_for_block};
use tracing::info;

use common::{
    L2Node, build_preconf_block, parent_from_latest, spawn_whitelist_node, unix_now,
    wait_for_eos_status,
};

/// Overall deadline for node B to converge before the EOS block is built.
const WARMUP_DEADLINE: Duration = Duration::from_secs(60);
/// Per-block wait while probing node B for convergence between builds.
const PER_BLOCK_PROBE: Duration = Duration::from_secs(5);
/// Deadline for the restarted node to recover the EOS marker from its peer.
///
/// EOS requests for an epoch are content-identical gossip messages, and the EOS
/// block builder publishes one itself, so every mesh member's gossipsub
/// seen-cache (120s) drops the restarted node's re-request until the window
/// expires. Worst-case recovery is therefore ~120s plus one retry interval (8s)
/// plus serve/poll latency; 210s leaves headroom on slow CI machines.
const REHYDRATE_DEADLINE: Duration = Duration::from_secs(210);

#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn eos_status_propagates_and_rehydrates_after_restart(env: &mut ShastaEnv) -> Result<()> {
    // Align beacon genesis to "now" so the whole test runs inside epoch 0: EOS
    // markers are keyed by the epoch of the block timestamp and `/status` reports
    // the wall-clock current epoch, so a fixed genesis would make this test flaky
    // near real epoch boundaries. Both nodes share the stub so epoch math agrees.
    let beacon = BeaconStubServer::start_with_genesis_time(unix_now().saturating_sub(1)).await?;
    let http = reqwest::Client::new();

    info!("starting whitelist driver nodes A and B");
    let node_a = spawn_whitelist_node(env, &beacon, L2Node::Primary, Vec::new()).await?;
    let node_b =
        spawn_whitelist_node(env, &beacon, L2Node::Secondary, vec![node_a.p2p_addr.clone()])
            .await?;

    // Warm up: build until B follows the tip so the gossip mesh is known-good
    // before the EOS block is produced.
    let mut parent = parent_from_latest(&node_a.l2_provider).await?;
    let deadline = Instant::now() + WARMUP_DEADLINE;
    loop {
        parent = build_preconf_block(&http, &node_a, env, &parent, false).await?;
        if wait_for_block(&node_b.l2_provider, parent.number, PER_BLOCK_PROBE).await.is_ok() {
            break;
        }
        ensure!(Instant::now() < deadline, "node B failed to follow the preconf tip in time");
    }

    info!(parent = parent.number, "building end-of-sequencing block on node A");
    let eos = build_preconf_block(&http, &node_a, env, &parent, true).await?;

    // The builder records the marker synchronously; the peer records it when the
    // gossiped envelope is ingested.
    wait_for_eos_status(&http, &node_a, eos.hash, Duration::from_secs(10)).await?;
    wait_for_block(&node_b.l2_provider, eos.number, Duration::from_secs(30)).await?;
    wait_for_eos_status(&http, &node_b, eos.hash, Duration::from_secs(30)).await?;
    info!(eos_block = eos.number, hash = %eos.hash, "EOS marker visible on both nodes");

    // Restart node B: the L2 chain survives, but the in-memory EOS marker is lost.
    // The startup rehydration task must request it back from node A.
    node_b.stop();
    info!("node B stopped; starting replacement node B2");
    let node_b2 =
        spawn_whitelist_node(env, &beacon, L2Node::Secondary, vec![node_a.p2p_addr.clone()])
            .await?;
    let b2_head = node_b2.l2_provider.get_block_number().await?;
    ensure!(b2_head >= eos.number, "node B2 should still have the preconf chain (head {b2_head})");

    wait_for_eos_status(&http, &node_b2, eos.hash, REHYDRATE_DEADLINE).await?;
    info!("restarted node recovered the EOS marker from its peer");

    node_b2.stop();
    node_a.stop();
    beacon.shutdown().await?;
    Ok(())
}
