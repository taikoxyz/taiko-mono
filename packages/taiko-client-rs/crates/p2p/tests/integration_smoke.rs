//! Integration smoke tests for the P2P SDK.
//!
//! These tests verify the SDK's core functionality by simulating gossip/reqresp events
//! and asserting that storage, deduplication, and catch-up work correctly.
//!
//! The tests use synthetic `NetworkEvent` inputs rather than real network connections,
//! allowing deterministic testing of SDK logic.

use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::Arc,
    time::Duration,
};

use alloy_primitives::{Address, B256, U256};
use p2p::{
    CatchupAction, CatchupConfig, CatchupPipeline, CatchupState, EventHandler, P2pClient,
    P2pClientConfig, SdkEvent,
    storage::{InMemoryStorage, compute_message_id},
};
use preconfirmation_net::NetworkEvent;
use preconfirmation_types::{
    Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, RawTxListGossip,
    SignedCommitment, TxListBytes, Uint256,
};
use rpc::MockPreconfEngine;

/// Test chain ID for Taiko.
const TEST_CHAIN_ID: u64 = 167000;

// ============================================================================
// Test Helpers
// ============================================================================

/// Creates a sample preconfirmation with the given parameters.
fn sample_preconfirmation(block_num: u64, parent_hash: [u8; 32]) -> Preconfirmation {
    Preconfirmation {
        eop: false,
        block_number: Uint256::from(block_num),
        timestamp: Uint256::from(1000u64 + block_num),
        gas_limit: Uint256::from(30_000_000u64),
        coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
        anchor_block_number: Uint256::from(block_num.saturating_sub(1)),
        raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
        parent_preconfirmation_hash: Bytes32::try_from(parent_hash.to_vec()).unwrap(),
        submission_window_end: Uint256::from(2000u64 + block_num),
        prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
        proposal_id: Uint256::from(block_num),
    }
}

/// Creates a sample signed commitment with the given block number and unique signature byte.
fn sample_commitment(block_num: u64, sig_byte: u8) -> SignedCommitment {
    SignedCommitment {
        commitment: PreconfCommitment {
            preconf: sample_preconfirmation(block_num, [0u8; 32]),
            slasher_address: Bytes20::try_from(vec![0xAAu8; 20]).unwrap(),
        },
        signature: Bytes65::try_from(vec![sig_byte; 65]).unwrap(),
    }
}

/// Creates a sample raw txlist with the given content byte.
///
/// The hash is computed from the content to ensure consistency.
fn sample_txlist(content_byte: u8) -> RawTxListGossip {
    let txlist_data = vec![content_byte; 100];
    let hash = preconfirmation_types::keccak256_bytes(&txlist_data);
    RawTxListGossip {
        raw_tx_list_hash: Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
        txlist: TxListBytes::try_from(txlist_data).unwrap(),
    }
}

// ============================================================================
// Smoke Tests
// ============================================================================

#[test]
fn api_event_handler_accepts_in_memory_storage() {
    let _ctor: fn(Arc<InMemoryStorage>, u64) -> EventHandler = EventHandler::new;
}

#[tokio::test]
async fn smoke_client_roundtrip() {
    // This test simulates a gossip/reqresp roundtrip and verifies storage updates.
    let storage: Arc<InMemoryStorage> = Arc::new(InMemoryStorage::default());
    let handler = EventHandler::new(storage.clone(), TEST_CHAIN_ID);

    let peer = libp2p::PeerId::random();

    // 1. Simulate receiving a raw txlist gossip
    let txlist = sample_txlist(0xAB);
    let txlist_hash = B256::from_slice(txlist.raw_tx_list_hash.as_ref());

    let event = handler.handle_txlist_gossip(peer, txlist.clone());
    assert!(event.is_some(), "first txlist should produce an event");
    assert!(matches!(event.unwrap(), SdkEvent::RawTxListGossip { .. }));

    // 2. Verify the txlist was stored
    let stored_txlist = storage.get_txlist(&txlist_hash);
    assert!(stored_txlist.is_some(), "txlist should be stored after gossip");
    assert_eq!(stored_txlist.unwrap().txlist.len(), 100);

    // 3. Verify deduplication works - sending same txlist should return None
    let duplicate_event = handler.handle_txlist_gossip(peer, txlist.clone());
    assert!(duplicate_event.is_none(), "duplicate txlist should be deduplicated");

    // 4. Verify a different txlist is accepted
    let txlist2 = sample_txlist(0xCD);
    let event2 = handler.handle_txlist_gossip(peer, txlist2);
    assert!(event2.is_some(), "different txlist should produce an event");
}

#[tokio::test]
async fn smoke_message_id_deduplication() {
    // Test that message-level deduplication works via message ID
    let storage: Arc<InMemoryStorage> = Arc::new(InMemoryStorage::default());
    let handler = EventHandler::new(storage.clone(), TEST_CHAIN_ID);

    let peer = libp2p::PeerId::random();

    // Create commitment
    let commitment = sample_commitment(100, 0xBB);

    // First gossip - may return None due to validation (invalid signature),
    // but should mark message as seen
    let _events1 = handler.handle_commitment_gossip(peer, commitment.clone());

    // Second gossip with same commitment - should be deduplicated at message level
    let events2 = handler.handle_commitment_gossip(peer, commitment.clone());
    assert!(events2.is_empty(), "duplicate commitment should be deduplicated at message level");
}

#[tokio::test]
async fn smoke_catchup_state_machine() {
    // Test the catch-up pipeline state transitions
    let config = CatchupConfig::default();
    let mut catchup = CatchupPipeline::new(config);

    // Initially idle
    assert!(matches!(catchup.state(), CatchupState::Idle));
    assert!(!catchup.is_syncing());
    assert!(!catchup.is_synced());

    // Start catchup by requesting head first
    catchup.start_catchup(0);
    assert!(matches!(catchup.state(), CatchupState::AwaitingHead { local_head: 0 }));
    assert!(catchup.is_syncing());

    // Request head
    let action = catchup.next_action();
    assert!(matches!(action, CatchupAction::RequestHead));

    // Receive head at block 10
    catchup.on_head_received(10);
    assert!(matches!(
        catchup.state(),
        CatchupState::Syncing { current_block: 0, target_block: 10 }
    ));

    // Request commitments
    let action = catchup.next_action();
    assert!(
        matches!(action, CatchupAction::RequestCommitments { start_block: 0, .. }),
        "should request commitments from block 0"
    );

    // Simulate receiving commitments with missing txlists
    let missing_hashes = vec![B256::from([0x11; 32]), B256::from([0x22; 32])];
    catchup.on_commitments_received(5, missing_hashes.clone());

    // Should request first txlist
    let action = catchup.next_action();
    assert!(matches!(action, CatchupAction::RequestTxList { hash } if hash == missing_hashes[0]));

    // Receive first txlist
    catchup.on_txlist_received(&missing_hashes[0]);

    // Should request second txlist
    let action = catchup.next_action();
    assert!(matches!(action, CatchupAction::RequestTxList { hash } if hash == missing_hashes[1]));

    // Receive second txlist
    catchup.on_txlist_received(&missing_hashes[1]);

    // Should request more commitments (we're at block 6, target is 10)
    let action = catchup.next_action();
    assert!(
        matches!(action, CatchupAction::RequestCommitments { start_block: 6, .. }),
        "should request commitments from block 6"
    );

    // Receive final commitments up to block 10
    catchup.on_commitments_received(10, vec![]);

    // Should be synced (Live state)
    let action = catchup.next_action();
    assert!(matches!(action, CatchupAction::SyncComplete));
    assert!(catchup.is_synced());
    assert!(matches!(catchup.state(), CatchupState::Live));
}

#[tokio::test]
async fn smoke_catchup_backoff_on_failure() {
    // Test that catch-up applies backoff on failure
    let config = CatchupConfig {
        initial_backoff: std::time::Duration::from_millis(10),
        max_backoff: std::time::Duration::from_millis(100),
        max_retries: 3,
        ..Default::default()
    };
    let mut catchup = CatchupPipeline::new(config);

    catchup.start_sync(0, 10);

    // Get initial action
    let _action = catchup.next_action();

    // Simulate failure
    catchup.on_request_failed();
    assert_eq!(catchup.retry_count(), 1);
    assert!(catchup.is_in_backoff());

    // While in backoff, should return Wait
    let action = catchup.next_action();
    assert!(matches!(action, CatchupAction::Wait));

    // Wait for backoff to expire
    tokio::time::sleep(std::time::Duration::from_millis(30)).await;

    // Should no longer be in backoff
    assert!(!catchup.is_in_backoff());

    // After max retries, should return to Idle
    catchup.on_request_failed(); // retry 2
    catchup.on_request_failed(); // retry 3 - exceeds max

    assert!(matches!(catchup.state(), CatchupState::Idle));
}

/// Ensure reorg notifications are forwarded to the execution engine.
#[tokio::test]
async fn smoke_reorg_notifies_engine() {
    let engine = Arc::new(MockPreconfEngine::default());
    let mut config = P2pClientConfig::with_chain_id(TEST_CHAIN_ID);
    config.expected_slasher = Some(Address::from([0x11; 20]));
    config.engine = Some(engine.clone());
    config.enable_metrics = false;
    config.network.listen_addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    config.network.discovery_listen = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    config.network.enable_discovery = false;
    config.network.enable_quic = false;

    let (client, mut events) = P2pClient::new(config).expect("client should start");
    let handle = client.handle();
    let client_task = tokio::spawn(async move { client.run().await });

    handle.notify_reorg(42, "test reorg".to_string()).await.expect("reorg notify should send");

    let mut saw_reorg = false;
    let recv_result = tokio::time::timeout(Duration::from_millis(500), async {
        while let Ok(event) = events.recv().await {
            if let SdkEvent::Reorg { anchor_block_number, .. } = event {
                saw_reorg = anchor_block_number == 42;
                break;
            }
        }
    })
    .await;

    assert!(recv_result.is_ok(), "expected to receive a reorg event");
    assert!(saw_reorg, "expected reorg event for anchor block 42");
    assert_eq!(engine.reorgs(), vec![42], "engine should record reorg");

    handle.shutdown().await.expect("shutdown should send");
    client_task.abort();
}

#[tokio::test]
async fn smoke_storage_commitment_ordering() {
    // Test that commitments are stored and retrieved in order
    let storage = InMemoryStorage::default();

    // Insert commitments out of order
    storage.insert_commitment(U256::from(5), sample_commitment(5, 0x55));
    storage.insert_commitment(U256::from(2), sample_commitment(2, 0x22));
    storage.insert_commitment(U256::from(8), sample_commitment(8, 0x88));
    storage.insert_commitment(U256::from(3), sample_commitment(3, 0x33));

    // Retrieve from block 3, max 2
    let commitments = storage.commitments_from(U256::from(3), 2);

    assert_eq!(commitments.len(), 2, "should return exactly 2 commitments");
    // Should be blocks 3 and 5 in order
    assert_eq!(commitments[0].signature[0], 0x33);
    assert_eq!(commitments[1].signature[0], 0x55);

    // Retrieve all from block 0
    let all_commitments = storage.commitments_from(U256::from(0), 100);
    assert_eq!(all_commitments.len(), 4);

    // Should be ordered: 2, 3, 5, 8
    assert_eq!(all_commitments[0].signature[0], 0x22);
    assert_eq!(all_commitments[1].signature[0], 0x33);
    assert_eq!(all_commitments[2].signature[0], 0x55);
    assert_eq!(all_commitments[3].signature[0], 0x88);
}

#[tokio::test]
async fn smoke_pending_buffer_parent_release() {
    // Test that pending commitments are released when parent arrives
    let storage = Arc::new(InMemoryStorage::default());

    let parent_hash = B256::from([0x11; 32]);

    // Add children waiting for parent
    let child1 = sample_commitment(101, 0xC1);
    let child2 = sample_commitment(102, 0xC2);

    storage.add_pending(parent_hash, child1.clone());
    storage.add_pending(parent_hash, child2.clone());

    assert_eq!(storage.pending_count(), 2);

    // Release pending when parent arrives
    let released = storage.release_pending(&parent_hash);

    assert_eq!(released.len(), 2);
    assert_eq!(storage.pending_count(), 0);

    // Releasing again should return empty
    let released_again = storage.release_pending(&parent_hash);
    assert!(released_again.is_empty());
}

#[tokio::test]
async fn smoke_handler_peer_events() {
    // Test that peer connect/disconnect events are passed through
    let storage = Arc::new(InMemoryStorage::default());
    let handler = EventHandler::new(storage, TEST_CHAIN_ID);

    let peer = libp2p::PeerId::random();

    // Peer connected
    let events = handler.handle_event(NetworkEvent::PeerConnected(peer));
    assert_eq!(events.len(), 1);
    if let SdkEvent::PeerConnected { peer: event_peer } = &events[0] {
        assert_eq!(event_peer, &peer);
    } else {
        panic!("expected PeerConnected event");
    }

    // Peer disconnected
    let events = handler.handle_event(NetworkEvent::PeerDisconnected(peer));
    assert_eq!(events.len(), 1);
    if let SdkEvent::PeerDisconnected { peer: event_peer } = &events[0] {
        assert_eq!(event_peer, &peer);
    } else {
        panic!("expected PeerDisconnected event");
    }
}

#[tokio::test]
async fn smoke_handler_network_error() {
    // Test that network errors are converted to SDK error events
    let storage = Arc::new(InMemoryStorage::default());
    let handler = EventHandler::new(storage, TEST_CHAIN_ID);

    let events = handler.handle_event(NetworkEvent::Error("test network error".into()));
    assert_eq!(events.len(), 1);
    if let SdkEvent::Error { detail } = &events[0] {
        assert!(detail.contains("network"));
    } else {
        panic!("expected Error event");
    }
}

#[tokio::test]
async fn smoke_multiple_txlist_storage() {
    // Test storing and retrieving multiple txlists
    let storage = InMemoryStorage::default();

    let txlist1 = sample_txlist(0xAA);
    let txlist2 = sample_txlist(0xBB);
    let txlist3 = sample_txlist(0xCC);

    let hash1 = B256::from_slice(txlist1.raw_tx_list_hash.as_ref());
    let hash2 = B256::from_slice(txlist2.raw_tx_list_hash.as_ref());
    let hash3 = B256::from_slice(txlist3.raw_tx_list_hash.as_ref());

    storage.insert_txlist(hash1, txlist1.clone());
    storage.insert_txlist(hash2, txlist2.clone());
    storage.insert_txlist(hash3, txlist3.clone());

    // Verify all are stored and retrievable
    assert!(storage.get_txlist(&hash1).is_some());
    assert!(storage.get_txlist(&hash2).is_some());
    assert!(storage.get_txlist(&hash3).is_some());

    // Verify non-existent hash returns None
    let missing_hash = B256::from([0xFF; 32]);
    assert!(storage.get_txlist(&missing_hash).is_none());
}

#[tokio::test]
async fn smoke_catchup_already_synced() {
    // Test that catch-up correctly handles being already synced
    let config = CatchupConfig::default();
    let mut catchup = CatchupPipeline::new(config);

    // Start catchup from block 10
    catchup.start_catchup(10);

    // Request head
    let action = catchup.next_action();
    assert!(matches!(action, CatchupAction::RequestHead));

    // Receive head at block 10 (same as local) - should be immediately synced
    catchup.on_head_received(10);

    assert!(matches!(catchup.state(), CatchupState::Live));
    assert!(catchup.is_synced());

    let action = catchup.next_action();
    assert!(matches!(action, CatchupAction::SyncComplete));
}

#[tokio::test]
async fn smoke_message_id_computation() {
    // Test that message ID computation is deterministic
    let topic = "/taiko/167000/0/preconfirmationCommitments";
    let payload = b"test payload";

    let id1 = compute_message_id(topic, payload);
    let id2 = compute_message_id(topic, payload);

    assert_eq!(id1, id2, "message ID should be deterministic");

    // Different topic or payload should produce different ID
    let id3 = compute_message_id("/different/topic", payload);
    assert_ne!(id1, id3, "different topic should produce different ID");

    let id4 = compute_message_id(topic, b"different payload");
    assert_ne!(id1, id4, "different payload should produce different ID");
}

// ============================================================================
// Spec Blocker Tests (Task 1)
// ============================================================================

/// Creates a preconfirmation with specific EOP and hash values for testing.
fn sample_preconfirmation_with_eop(block_num: u64, eop: bool, zero_hash: bool) -> Preconfirmation {
    let hash = if zero_hash { [0u8; 32] } else { [1u8; 32] };
    Preconfirmation {
        eop,
        block_number: Uint256::from(block_num),
        timestamp: Uint256::from(1000u64 + block_num),
        gas_limit: Uint256::from(30_000_000u64),
        coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
        anchor_block_number: Uint256::from(block_num.saturating_sub(1)),
        raw_tx_list_hash: Bytes32::try_from(hash.to_vec()).unwrap(),
        parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
        submission_window_end: Uint256::from(2000u64 + block_num),
        prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
        proposal_id: Uint256::from(block_num),
    }
}

#[test]
fn eop_true_allows_nonzero_hash() {
    use p2p::validation::validate_eop_rule;

    // EOP=true with non-zero hash should be VALID per relaxed spec.
    // An EOP commitment can still reference a txlist - EOP just means
    // "end of proposal" marker, not "must have no txlist".
    let preconf = sample_preconfirmation_with_eop(100, true, false); // eop=true, nonzero hash
    let outcome = validate_eop_rule(&preconf);
    assert!(
        outcome.status.is_valid(),
        "EOP=true with nonzero hash should be valid; got: {:?}",
        outcome.reason
    );
}

#[tokio::test]
async fn handler_rejects_txlist_with_hash_mismatch() {
    use preconfirmation_types::keccak256_bytes;

    let storage = Arc::new(InMemoryStorage::default());
    let handler = EventHandler::new(storage.clone(), TEST_CHAIN_ID);

    let peer = libp2p::PeerId::random();

    // Create a txlist with a hash that doesn't match the declared hash
    let txlist_data = vec![0xCC; 100];
    let _actual_hash = keccak256_bytes(&txlist_data);
    let wrong_hash = Bytes32::try_from(vec![0xDE; 32]).unwrap(); // Deliberately wrong

    let msg = RawTxListGossip {
        raw_tx_list_hash: wrong_hash.clone(),
        txlist: TxListBytes::try_from(txlist_data).unwrap(),
    };

    // Should reject due to hash mismatch
    let result = handler.handle_txlist_gossip(peer, msg);
    assert!(result.is_none(), "txlist with mismatched hash should be rejected");

    // Verify it was NOT stored
    let hash = B256::from_slice(wrong_hash.as_ref());
    assert!(
        storage.get_txlist(&hash).is_none(),
        "txlist with mismatched hash should not be stored"
    );
}

#[tokio::test]
async fn handler_rejects_oversized_txlist() {
    use p2p::P2pClientConfig;

    let storage = Arc::new(InMemoryStorage::default());

    // Get the default max size from config
    let config = P2pClientConfig::default();
    let max_size = config.max_txlist_bytes;

    // Create handler with the max size limit
    let handler = EventHandler::with_max_txlist_bytes(storage.clone(), TEST_CHAIN_ID, max_size);

    let peer = libp2p::PeerId::random();

    // Create an oversized txlist (exceeds max_txlist_bytes)
    let oversized_data = vec![0xDD; max_size + 1];
    let hash = preconfirmation_types::keccak256_bytes(&oversized_data);
    let hash_bytes = Bytes32::try_from(hash.as_slice().to_vec()).unwrap();

    let msg = RawTxListGossip {
        raw_tx_list_hash: hash_bytes.clone(),
        txlist: TxListBytes::try_from(oversized_data).unwrap(),
    };

    // Should reject due to size limit
    let result = handler.handle_txlist_gossip(peer, msg);
    assert!(result.is_none(), "oversized txlist should be rejected");

    // Verify it was NOT stored
    let stored_hash = B256::from_slice(hash_bytes.as_ref());
    assert!(storage.get_txlist(&stored_hash).is_none(), "oversized txlist should not be stored");
}
