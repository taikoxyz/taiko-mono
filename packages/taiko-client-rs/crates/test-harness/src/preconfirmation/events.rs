//! Event waiter utilities for preconfirmation integration tests.
//!
//! This module provides async helpers for waiting on specific P2P events:
//! - [`wait_for_peer_connected`]: Waits until a peer connects.
//! - [`wait_for_commitment_and_txlist`]: Waits for both commitment and txlist.
//! - [`wait_for_commitments_and_txlists`]: Waits for multiple commitments/txlists.
//! - [`wait_for_synced`]: Waits for the synced event.

use preconfirmation_client::subscription::PreconfirmationEvent;
use tokio::sync::broadcast;

// ============================================================================
// Peer Connection Events
// ============================================================================

/// Waits for a peer connection event.
///
/// Blocks until `PreconfirmationEvent::PeerConnected` is received.
/// Panics if the event stream closes unexpectedly.
///
/// # Example
///
/// ```ignore
/// let mut events = client.subscribe();
/// wait_for_peer_connected(&mut events).await;
/// // Peer is now connected, safe to publish gossip
/// ```
pub async fn wait_for_peer_connected(events: &mut broadcast::Receiver<PreconfirmationEvent>) {
    loop {
        match events.recv().await {
            Ok(PreconfirmationEvent::PeerConnected(_)) => return,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

// ============================================================================
// Gossip Events
// ============================================================================

/// Waits for both a commitment and its transaction list to be received.
///
/// Blocks until both `NewCommitment` and `NewTxList` events have been seen.
/// The events may arrive in any order.
///
/// # Example
///
/// ```ignore
/// // After publishing gossip from external node
/// wait_for_commitment_and_txlist(&mut events).await;
/// // Both commitment and txlist have been received
/// ```
pub async fn wait_for_commitment_and_txlist(
    events: &mut broadcast::Receiver<PreconfirmationEvent>,
) {
    let mut saw_commitment = false;
    let mut saw_txlist = false;

    while !(saw_commitment && saw_txlist) {
        match events.recv().await {
            Ok(PreconfirmationEvent::NewCommitment(_)) => saw_commitment = true,
            Ok(PreconfirmationEvent::NewTxList(_)) => saw_txlist = true,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

/// Waits for multiple commitments and transaction lists to be received.
///
/// Blocks until at least `commitment_count` commitments and `txlist_count`
/// transaction lists have been received.
///
/// # Arguments
///
/// * `events` - The event receiver to listen on.
/// * `commitment_count` - Minimum number of commitments to wait for.
/// * `txlist_count` - Minimum number of transaction lists to wait for.
///
/// # Example
///
/// ```ignore
/// // Wait for 3 commitments and 3 txlists
/// wait_for_commitments_and_txlists(&mut events, 3, 3).await;
/// ```
pub async fn wait_for_commitments_and_txlists(
    events: &mut broadcast::Receiver<PreconfirmationEvent>,
    commitment_count: usize,
    txlist_count: usize,
) {
    let mut commitments_received = 0;
    let mut txlists_received = 0;

    while commitments_received < commitment_count || txlists_received < txlist_count {
        match events.recv().await {
            Ok(PreconfirmationEvent::NewCommitment(_)) => commitments_received += 1,
            Ok(PreconfirmationEvent::NewTxList(_)) => txlists_received += 1,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

// ============================================================================
// Sync Events
// ============================================================================

/// Waits for the synced event.
///
/// Blocks until `PreconfirmationEvent::Synced` is received, indicating
/// the preconfirmation client has caught up with the network.
///
/// # Example
///
/// ```ignore
/// let mut events = client.subscribe();
/// wait_for_synced(&mut events).await;
/// // Client is now synced and ready to process new commitments
/// ```
pub async fn wait_for_synced(events: &mut broadcast::Receiver<PreconfirmationEvent>) {
    loop {
        match events.recv().await {
            Ok(PreconfirmationEvent::Synced) => return,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}
