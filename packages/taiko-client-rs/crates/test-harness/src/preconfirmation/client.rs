//! Preconfirmation client setup utilities for E2E tests.
//!
//! This module provides helpers for spawning preconfirmation clients in tests:
//! - [`RunningPreconfClient`]: A running client with event receiver and task handle.
//! - [`TestPreconfClientConfig`]: Configuration options for test clients.
//! - [`spawn_test_preconf_client`]: Spawns a configured preconf client.

use std::sync::Arc;

use alloy_primitives::{Address, U256};
use anyhow::Result;
use preconfirmation_net::Multiaddr;
use preconfirmation_node::{
    DriverClient, PreconfirmationClient, PreconfirmationClientConfig,
    subscription::PreconfirmationEvent,
};
use secp256k1::SecretKey;
use tokio::{
    sync::{broadcast, oneshot},
    task::JoinHandle,
};

use super::{StaticLookaheadResolver, derive_signer, test_p2p_config};

/// A running preconfirmation client with its event loop and subscriptions.
///
/// This bundles together all the pieces needed for a preconf client test:
/// - The event receiver for observing gossip events
/// - The spawned event loop task
/// - Optional oneshot channel to detect event loop errors
pub struct RunningPreconfClient {
    /// Event receiver for P2P gossip events.
    pub events: broadcast::Receiver<PreconfirmationEvent>,
    /// Handle to the spawned event loop task.
    pub task: JoinHandle<()>,
    /// Optional channel to receive event loop result (for select! patterns).
    pub result_rx: Option<oneshot::Receiver<anyhow::Result<()>>>,
}

impl RunningPreconfClient {
    /// Aborts the event loop task.
    pub fn abort(&self) {
        self.task.abort();
    }
}

/// Configuration for spawning a test preconfirmation client.
#[derive(Clone)]
pub struct TestPreconfClientConfig {
    /// Signer seed byte for `derive_signer()` (default: 1).
    pub signer_seed: u8,
    /// Submission window end value (default: U256::from(1000)).
    pub submission_window_end: U256,
    /// Peers to dial on startup.
    pub pre_dial_peers: Vec<Multiaddr>,
    /// Whether to use oneshot channel for error detection in select!.
    pub with_result_channel: bool,
}

impl Default for TestPreconfClientConfig {
    fn default() -> Self {
        Self {
            signer_seed: 1,
            submission_window_end: U256::from(1000u64),
            pre_dial_peers: Vec::new(),
            with_result_channel: false,
        }
    }
}

/// Spawns a preconfirmation client with mock lookahead for testing.
///
/// This handles the common boilerplate of:
/// 1. Deriving a test signer
/// 2. Creating a static lookahead resolver
/// 3. Building the client configuration
/// 4. Spawning the client and event loop
///
/// # Arguments
///
/// * `driver_client` - The driver client implementation (real or mock).
/// * `config` - Test configuration options.
///
/// # Returns
///
/// A tuple of (running client, signer secret key, signer address).
///
/// # Example
///
/// ```ignore
/// let config = TestPreconfClientConfig {
///     pre_dial_peers: vec![ext_dial_addr],
///     ..Default::default()
/// };
/// let (mut client, signer_sk, signer) = spawn_test_preconf_client(
///     driver_client,
///     config,
/// ).await?;
///
/// wait_for_peer_connected(&mut client.events).await;
///
/// // Build and publish preconfirmation using signer_sk/signer
/// let block = build_publish_payloads(&signer_sk, signer, ...)?;
///
/// client.abort();
/// ```
pub async fn spawn_test_preconf_client<D>(
    driver_client: D,
    config: TestPreconfClientConfig,
) -> Result<(RunningPreconfClient, SecretKey, Address)>
where
    D: DriverClient + Send + Sync + 'static,
{
    let (signer_sk, signer) = derive_signer(config.signer_seed);
    let resolver = StaticLookaheadResolver::new(signer, config.submission_window_end);

    let mut p2p_cfg =
        PreconfirmationClientConfig::new_with_resolver(test_p2p_config(), Arc::new(resolver));
    p2p_cfg.p2p.pre_dial_peers = config.pre_dial_peers;

    let client = PreconfirmationClient::new(p2p_cfg, driver_client)?;
    let events = client.subscribe();
    let mut event_loop = client.sync_and_catchup().await?;

    let (task, result_rx) = if config.with_result_channel {
        let (tx, rx) = oneshot::channel();
        let task = tokio::spawn(async move {
            let _ = tx.send(event_loop.run().await.map_err(Into::into));
        });
        (task, Some(rx))
    } else {
        let task = tokio::spawn(async move {
            let _ = event_loop.run().await;
        });
        (task, None)
    };

    Ok((RunningPreconfClient { events, task, result_rx }, signer_sk, signer))
}
