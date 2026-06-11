//! Shared helpers for whitelist preconfirmation driver E2E tests.
//!
//! Spawns full in-process [`WhitelistPreconfirmationDriverRunner`] instances against
//! the Docker L2 nodes provided by `tests/entrypoint.sh`, and drives them through
//! the public REST API exactly like an external sequencer (Catalyst) would.

#![allow(dead_code)]

use std::{
    net::{SocketAddr, TcpListener},
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256, hex};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, anyhow, ensure};
use driver::DriverConfig;
use libp2p::Multiaddr;
use protocol::{codec::ZlibTxListCodec, shasta::encode_extra_data};
use rpc::client::{ClientConfig, connect_provider_with_timeout};
use test_harness::{
    BeaconStubServer, ShastaEnv, build_preconf_txlist, compute_next_block_base_fee,
};
use tokio::task::JoinHandle;
use whitelist_preconfirmation_driver::{
    NetworkConfig, RunnerConfig, WhitelistPreconfirmationDriverRunner,
};

/// Compressed tx-list bound mirroring the driver's gossip codec limit.
const MAX_COMPRESSED_TX_LIST_BYTES: usize = 131_072 * 6;
/// Decompressed tx-list bound mirroring the driver's gossip codec limit.
const MAX_DECOMPRESSED_TX_LIST_BYTES: usize = 8 * 1024 * 1024;
/// How long to wait for a node's REST server to come up.
const REST_READY_TIMEOUT: Duration = Duration::from_secs(90);

/// Which Docker L2 execution node a driver instance should drive.
#[derive(Clone, Copy, Debug)]
pub enum L2Node {
    /// `l2_node_0` (`env.l2_ws_0` / `env.l2_auth_0`).
    Primary,
    /// `l2_node_1` (`env.l2_ws_1` / `env.l2_auth_1`).
    Secondary,
}

/// Handle to an in-process whitelist preconfirmation driver node.
pub struct WhitelistNode {
    /// Base URL of the node's REST server.
    pub rest_url: String,
    /// Dialable multiaddr of the node's P2P listener.
    pub p2p_addr: Multiaddr,
    /// Provider connected to the L2 execution node this driver drives.
    pub l2_provider: RootProvider,
    /// Background task running the driver runner.
    runner_handle: JoinHandle<()>,
}

impl WhitelistNode {
    /// Abort the driver runner task.
    ///
    /// Detached subtasks (REST server, swarm, event syncer) are cleaned up when the
    /// per-test process exits; restarted nodes always bind fresh ports.
    pub fn stop(&self) {
        self.runner_handle.abort();
    }
}

/// Allocate a free localhost TCP port by binding port 0 and dropping the listener.
fn free_port() -> Result<u16> {
    let listener = TcpListener::bind("127.0.0.1:0").context("binding ephemeral port")?;
    Ok(listener.local_addr()?.port())
}

/// Current UNIX timestamp in seconds.
pub fn unix_now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).expect("system clock before epoch").as_secs()
}

/// Spawn an in-process whitelist preconfirmation driver against the given L2 node.
///
/// The node signs gossip with the harness proposer key, which the deploy script
/// registers as a whitelist operator, so peers accept its blocks. The REST server
/// runs without JWT (auth coverage lives in the crate's unit tests).
pub async fn spawn_whitelist_node(
    env: &ShastaEnv,
    beacon: &BeaconStubServer,
    l2_node: L2Node,
    pre_dial_peers: Vec<Multiaddr>,
) -> Result<WhitelistNode> {
    let whitelist_address: Address = std::env::var("SHASTA_PRECONF_WHITELIST")
        .context("SHASTA_PRECONF_WHITELIST env var is required")?
        .parse()
        .context("invalid SHASTA_PRECONF_WHITELIST address")?;

    let (l2_ws, l2_auth) = match l2_node {
        L2Node::Primary => (env.l2_ws_0.clone(), env.l2_auth_0.clone()),
        L2Node::Secondary => (env.l2_ws_1.clone(), env.l2_auth_1.clone()),
    };

    let mut driver_config = DriverConfig::new(
        ClientConfig {
            l1_provider_source: env.l1_source.clone(),
            l2_provider_url: l2_ws.clone(),
            l2_auth_provider_url: l2_auth,
            jwt_secret: env.jwt_secret.clone(),
            inbox_address: env.inbox_address,
        },
        Duration::from_millis(50),
        beacon.endpoint().clone(),
        None,
        None,
    );
    driver_config.preconfirmation_enabled = true;

    let p2p_port = free_port()?;
    let rest_port = free_port()?;
    let p2p_config = NetworkConfig {
        listen_addr: SocketAddr::from(([127, 0, 0, 1], p2p_port)),
        discovery_listen: SocketAddr::from(([127, 0, 0, 1], 0)),
        enable_discovery: false,
        pre_dial_peers,
        ..Default::default()
    };

    let runner_config = RunnerConfig {
        driver_config,
        p2p_config,
        whitelist_address,
        rpc_listen_addr: Some(SocketAddr::from(([127, 0, 0, 1], rest_port))),
        rpc_jwt_secret: None,
        rpc_cors_origins: Vec::new(),
        p2p_signer_key: Some(env.l1_proposer_private_key.to_string()),
    };

    let runner_handle = tokio::spawn(async move {
        if let Err(err) = WhitelistPreconfirmationDriverRunner::new(runner_config).run().await {
            tracing::warn!(error = %err, "whitelist driver runner exited");
        }
    });

    let rest_url = format!("http://127.0.0.1:{rest_port}");
    wait_for_healthz(&rest_url, REST_READY_TIMEOUT).await?;

    let l2_provider = connect_provider_with_timeout(l2_ws).await?;
    let p2p_addr: Multiaddr =
        format!("/ip4/127.0.0.1/tcp/{p2p_port}").parse().context("building node multiaddr")?;

    Ok(WhitelistNode { rest_url, p2p_addr, l2_provider, runner_handle })
}

/// Poll `GET /healthz` until the REST server responds or the timeout elapses.
async fn wait_for_healthz(rest_url: &str, timeout: Duration) -> Result<()> {
    let http = reqwest::Client::new();
    let deadline = Instant::now() + timeout;
    loop {
        if let Ok(resp) = http.get(format!("{rest_url}/healthz")).send().await &&
            resp.status().is_success()
        {
            return Ok(());
        }
        ensure!(Instant::now() < deadline, "timed out waiting for REST server at {rest_url}");
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
}

/// Header fields of a built block needed to chain the next build request.
#[derive(Clone, Debug)]
pub struct BuiltBlock {
    /// Block number.
    pub number: u64,
    /// Block hash.
    pub hash: B256,
    /// Block timestamp.
    pub timestamp: u64,
    /// Block gas limit.
    pub gas_limit: u64,
}

/// Fetch the latest block of a provider as a [`BuiltBlock`] build parent.
pub async fn parent_from_latest(provider: &RootProvider) -> Result<BuiltBlock> {
    let block = provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .await?
        .ok_or_else(|| anyhow!("latest L2 block missing"))?;
    Ok(BuiltBlock {
        number: block.header.inner.number,
        hash: block.header.hash,
        timestamp: block.header.inner.timestamp,
        gas_limit: block.header.inner.gas_limit,
    })
}

/// Build one preconfirmation block via `POST /preconfBlocks`, the way Catalyst does.
///
/// The tx list is the harness anchor transaction plus funded test transfers,
/// zlib-compressed; the request body pins the externally documented camelCase
/// wire format rather than reusing the crate's serde types.
pub async fn build_preconf_block(
    http: &reqwest::Client,
    node: &WhitelistNode,
    env: &ShastaEnv,
    parent: &BuiltBlock,
    end_of_sequencing: bool,
) -> Result<BuiltBlock> {
    let block_number = parent.number + 1;
    // Wall-clock timestamps keep EOS epoch math meaningful while still satisfying
    // the engine's strictly-increasing timestamp rule.
    let timestamp = unix_now().max(parent.timestamp + 1);
    let base_fee = compute_next_block_base_fee(&node.l2_provider, parent.number).await?;

    let txlist = build_preconf_txlist(&env.client, parent.hash, block_number, base_fee).await?;
    let raw_txs: Vec<Vec<u8>> = txlist.raw_tx_bytes.iter().map(|tx| tx.to_vec()).collect();
    let compressed = ZlibTxListCodec::new_with_limits(
        MAX_COMPRESSED_TX_LIST_BYTES,
        MAX_DECOMPRESSED_TX_LIST_BYTES,
    )
    .encode(&raw_txs)
    .map_err(|err| anyhow!("compressing tx list: {err}"))?;

    // Valid Shasta extra data (basefee sharing pctg + proposal id) like Catalyst
    // sends: the event syncer decodes the proposal id from the resume block when
    // restarting on top of these chains, so a placeholder byte would break any
    // later driver started against the same L2 node. These tests run on genesis
    // cold-start chains with no L1 proposals, hence proposal id zero.
    let extra_data = encode_extra_data(0, 0);

    let body = serde_json::json!({
        "executableData": {
            "parentHash": parent.hash,
            "feeRecipient": env.l2_suggested_fee_recipient,
            "blockNumber": block_number,
            "gasLimit": parent.gas_limit,
            "timestamp": timestamp,
            "transactions": format!("0x{}", hex::encode(&compressed)),
            "extraData": extra_data,
            "baseFeePerGas": base_fee,
        },
        "endOfSequencing": end_of_sequencing,
    });

    let resp = http.post(format!("{}/preconfBlocks", node.rest_url)).json(&body).send().await?;
    let status = resp.status();
    let text = resp.text().await?;
    ensure!(status.is_success(), "build of block {block_number} failed: {status} {text}");

    let value: serde_json::Value =
        serde_json::from_str(&text).context("parsing build response JSON")?;
    let header: alloy_rpc_types::Header =
        serde_json::from_value(value["blockHeader"].clone()).context("decoding blockHeader")?;

    Ok(BuiltBlock {
        number: header.inner.number,
        hash: header.hash,
        timestamp: header.inner.timestamp,
        gas_limit: header.inner.gas_limit,
    })
}

/// Fetch a node's `GET /status` response as JSON.
pub async fn get_status(http: &reqwest::Client, node: &WhitelistNode) -> Result<serde_json::Value> {
    let resp = http.get(format!("{}/status", node.rest_url)).send().await?;
    ensure!(resp.status().is_success(), "status request failed: {}", resp.status());
    Ok(resp.json().await?)
}

/// Poll a node's `/status` until `endOfSequencingBlockHash` equals the expected hash.
pub async fn wait_for_eos_status(
    http: &reqwest::Client,
    node: &WhitelistNode,
    expected: B256,
    timeout: Duration,
) -> Result<()> {
    let expected = expected.to_string();
    let deadline = Instant::now() + timeout;
    loop {
        let status = get_status(http, node).await?;
        if status["endOfSequencingBlockHash"].as_str() == Some(expected.as_str()) {
            return Ok(());
        }
        ensure!(
            Instant::now() < deadline,
            "timed out waiting for EOS hash {expected} in {} status (last: {status})",
            node.rest_url
        );
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

/// Fetch the canonical block hash at `number` from a provider.
pub async fn block_hash_at(provider: &RootProvider, number: u64) -> Result<B256> {
    Ok(provider
        .get_block_by_number(BlockNumberOrTag::Number(number))
        .await?
        .ok_or_else(|| anyhow!("missing block {number}"))?
        .header
        .hash)
}
