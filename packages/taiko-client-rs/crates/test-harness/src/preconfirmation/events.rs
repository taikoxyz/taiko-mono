//! Event waiter utilities for preconfirmation integration tests.
//!
//! This module provides async helpers for waiting on specific P2P events:
//! - [`wait_for_peer_connected`]: Waits until a peer connects.
//! - [`wait_for_commitment_and_txlist`]: Waits for both commitment and txlist.
//! - [`wait_for_commitments_and_txlists`]: Waits for multiple commitments/txlists.
//! - [`wait_for_synced`]: Waits for the synced event.
//!
//! Every waiter is bounded by [`EVENT_WAIT_TIMEOUT`]. Without a bound, a missed
//! event (for example a gossip message dropped before the gossipsub mesh forms)
//! would block the test until the CI job-level timeout while discarding the
//! test's captured logs. Failing fast with a descriptive panic turns an opaque
//! multi-minute hang into an immediately diagnosable test failure that names the
//! event that never arrived.

use std::time::Duration;

use preconfirmation_driver::subscription::PreconfirmationEvent;
use tokio::{sync::broadcast, time::timeout};

/// Maximum time any single event-wait helper blocks before failing the test.
///
/// Healthy waits resolve within seconds; this bound only trips on a genuinely
/// missed event. It is kept below the nextest `terminate-after` budget so the
/// descriptive panic below fires (and is reported) before nextest hard-kills the
/// process.
const EVENT_WAIT_TIMEOUT: Duration = Duration::from_secs(60);

// ============================================================================
// Peer Connection Events
// ============================================================================

/// Waits for a peer connection event.
///
/// Blocks until `PreconfirmationEvent::PeerConnected` is received.
/// Panics if the event stream closes unexpectedly or [`EVENT_WAIT_TIMEOUT`] elapses.
///
/// # Example
///
/// ```ignore
/// let mut events = client.subscribe();
/// wait_for_peer_connected(&mut events).await;
/// // Peer is now connected, safe to publish gossip
/// ```
pub async fn wait_for_peer_connected(events: &mut broadcast::Receiver<PreconfirmationEvent>) {
    let wait = async {
        loop {
            match events.recv().await {
                Ok(PreconfirmationEvent::PeerConnected(_)) => return,
                Ok(_) => continue,
                Err(err) => panic!("preconfirmation event stream closed: {err}"),
            }
        }
    };

    if timeout(EVENT_WAIT_TIMEOUT, wait).await.is_err() {
        panic!("timed out after {}s waiting for PeerConnected event", EVENT_WAIT_TIMEOUT.as_secs());
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
/// Panics if the event stream closes unexpectedly or [`EVENT_WAIT_TIMEOUT`]
/// elapses; the timeout message reports which of the two events was still
/// outstanding.
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

    let wait = async {
        while !(saw_commitment && saw_txlist) {
            match events.recv().await {
                Ok(PreconfirmationEvent::NewCommitment(_)) => saw_commitment = true,
                Ok(PreconfirmationEvent::NewTxList(_)) => saw_txlist = true,
                Ok(_) => continue,
                Err(err) => panic!("preconfirmation event stream closed: {err}"),
            }
        }
    };

    if timeout(EVENT_WAIT_TIMEOUT, wait).await.is_err() {
        panic!(
            "timed out after {}s waiting for commitment+txlist gossip \
             (saw_commitment={saw_commitment}, saw_txlist={saw_txlist})",
            EVENT_WAIT_TIMEOUT.as_secs()
        );
    }
}

/// Waits for multiple commitments and transaction lists to be received.
///
/// Blocks until at least `commitment_count` commitments and `txlist_count`
/// transaction lists have been received.
///
/// Panics if the event stream closes unexpectedly or [`EVENT_WAIT_TIMEOUT`]
/// elapses; the timeout message reports the received-vs-expected counts.
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

    let wait = async {
        while commitments_received < commitment_count || txlists_received < txlist_count {
            match events.recv().await {
                Ok(PreconfirmationEvent::NewCommitment(_)) => commitments_received += 1,
                Ok(PreconfirmationEvent::NewTxList(_)) => txlists_received += 1,
                Ok(_) => continue,
                Err(err) => panic!("preconfirmation event stream closed: {err}"),
            }
        }
    };

    if timeout(EVENT_WAIT_TIMEOUT, wait).await.is_err() {
        panic!(
            "timed out after {}s waiting for {commitment_count} commitments and \
             {txlist_count} txlists (received {commitments_received} commitments, \
             {txlists_received} txlists)",
            EVENT_WAIT_TIMEOUT.as_secs()
        );
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
/// Panics if the event stream closes unexpectedly or [`EVENT_WAIT_TIMEOUT`] elapses.
///
/// # Example
///
/// ```ignore
/// let mut events = client.subscribe();
/// wait_for_synced(&mut events).await;
/// // Client is now synced and ready to process new commitments
/// ```
pub async fn wait_for_synced(events: &mut broadcast::Receiver<PreconfirmationEvent>) {
    let wait = async {
        loop {
            match events.recv().await {
                Ok(PreconfirmationEvent::Synced) => return,
                Ok(_) => continue,
                Err(err) => panic!("preconfirmation event stream closed: {err}"),
            }
        }
    };

    if timeout(EVENT_WAIT_TIMEOUT, wait).await.is_err() {
        panic!("timed out after {}s waiting for Synced event", EVENT_WAIT_TIMEOUT.as_secs());
    }
}
