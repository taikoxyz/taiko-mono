//! Dual-driver E2E test for preconfirmation client.
//!
//! This test validates that the DualDriverSetup helper correctly spawns
//! two P2P nodes with distinct ports and establishes peer connections between them.

#[path = "common/helpers.rs"]
mod helpers;

use helpers::DualDriverSetup;
use serial_test::serial;

/// Tests that DualDriverSetup correctly spawns two P2P nodes and establishes peer connections.
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn dual_driver_setup_spawns_two_peers() -> anyhow::Result<()> {
    let mut setup = DualDriverSetup::spawn().await?;

    assert!(
        setup.handle_a.dialable_addr().await.is_ok(),
        "node A should expose a dialable address"
    );
    assert!(
        setup.handle_b.dialable_addr().await.is_ok(),
        "node B should expose a dialable address"
    );

    setup.handle_a.wait_for_peer_connected().await?;

    setup.abort();

    Ok(())
}
