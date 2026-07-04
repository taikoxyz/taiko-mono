// Each integration test file `#[path]`-includes this module as a private `mod
// helpers`, so a given test binary only uses a subset of the re-exports below;
// the union across all includers covers every symbol. Allow unused imports so
// each binary compiles without warnings.
#![allow(unused_imports)]
//! Test-only helpers for preconfirmation-driver integration tests.
//!
//! This module re-exports shared helpers from test-harness used by the
//! integration tests that `#[path]`-include it.

// Re-export the shared P2P helpers from test-harness used by the integration tests.
pub use test_harness::preconfirmation::{
    ExternalP2pNode, PreparedBlock, build_commitment_chain, build_publish_payloads, derive_signer,
    test_p2p_config, wait_for_commitment_and_txlist, wait_for_commitments_and_txlists,
    wait_for_peer_connected, wait_for_synced,
};

use std::sync::Arc;

use alloy_primitives::{Address, U256};
use preconfirmation_driver::{
    PreconfirmationClient, PreconfirmationClientConfig, subscription::PreconfirmationEvent,
};
use preconfirmation_net::Multiaddr;
use test_harness::preconfirmation::{LoggingDriverClient, StaticLookaheadResolver};
use tokio::{
    sync::{broadcast, oneshot},
    task::JoinHandle,
};

/// Boots a preconfirmation client against a running driver and waits for the first peer
/// connection.
///
/// The client is configured with a [`StaticLookaheadResolver`] for the given signer and
/// submission window end, pre-dials the given peers, performs sync + catch-up, and spawns
/// the event loop.
///
/// Returns the event receiver, the spawned event-loop task handle, and a oneshot receiver
/// that yields the event-loop result when it exits. Call sites that do not monitor the
/// event loop can discard the receiver with `_`.
pub async fn start_preconf_client(
    signer: Address,
    submission_window_end: U256,
    pre_dial_peers: Vec<Multiaddr>,
    driver_client: LoggingDriverClient,
) -> anyhow::Result<(
    broadcast::Receiver<PreconfirmationEvent>,
    JoinHandle<()>,
    oneshot::Receiver<anyhow::Result<()>>,
)> {
    let mut cfg = PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(StaticLookaheadResolver::new(signer, submission_window_end)),
    );
    cfg.p2p.pre_dial_peers = pre_dial_peers;

    let client = PreconfirmationClient::new(cfg, driver_client)?;
    let mut events = client.subscribe();

    let mut event_loop = client.sync_and_catchup().await?;
    let (event_loop_tx, event_loop_rx) = oneshot::channel::<anyhow::Result<()>>();
    let event_loop_handle = tokio::spawn(async move {
        let _ = event_loop_tx.send(event_loop.run().await.map_err(Into::into));
    });

    wait_for_peer_connected(&mut events).await;

    Ok((events, event_loop_handle, event_loop_rx))
}
