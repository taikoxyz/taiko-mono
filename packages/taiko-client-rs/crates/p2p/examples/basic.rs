//! Minimal, demo-safe P2P SDK example.
//!
//! This compiles by default and shows the basic flow:
//! config → client start → event subscription → publish/request → graceful shutdown.
//!
//! To actually run the networked example, set `P2P_EXAMPLE_RUN=1` and configure
//! the network settings (listen addresses, bootnodes, keys) as needed.

use alloy_primitives::Address;
use p2p::{P2pClient, P2pClientConfig, P2pResult, SdkEvent};
use preconfirmation_types::RawTxListGossip;

#[tokio::main]
async fn main() -> P2pResult<()> {
    // 1) Configure the SDK. Customize `config.network` for real deployments.
    let mut config = P2pClientConfig::with_chain_id(167_000);
    config.expected_slasher = Some(Address::ZERO);

    // 2) Create the client and a handle for commands.
    let (client, _events) = P2pClient::new(config)?;
    let handle = client.handle();

    // Demo-safe: skip network startup unless explicitly enabled.
    if std::env::var("P2P_EXAMPLE_RUN").is_err() {
        eprintln!("P2P_EXAMPLE_RUN not set; example is compile-only by default.\n");
        eprintln!("Set P2P_EXAMPLE_RUN=1 and configure config.network to run the node.");
        return Ok(());
    }

    // 3) Subscribe to SDK events.
    let mut events = handle.subscribe();
    let event_task = tokio::spawn(async move {
        while let Ok(event) = events.recv().await {
            match event {
                SdkEvent::PeerConnected { peer } => {
                    println!("peer connected: {peer}");
                }
                SdkEvent::CommitmentGossip { .. } => {
                    println!("commitment gossip received");
                }
                SdkEvent::HeadSyncStatus { synced } => {
                    println!("head sync status: {synced}");
                }
                _ => {}
            }
        }
    });

    // 4) Start the client event loop.
    let client_task = tokio::spawn(async move { client.run().await });

    // 5) Publish/request examples (demo-safe payloads).
    // In real usage, construct valid commitments/txlists per spec.
    handle.request_head().await?;
    handle.request_commitments(0, 10).await?;

    let raw_txlist = RawTxListGossip::default();
    handle.publish_raw_txlist(raw_txlist).await?;

    // 6) Graceful shutdown.
    handle.shutdown().await?;
    client_task.await??;
    event_task.abort();

    Ok(())
}
