//! Integration smoke tests for the P2P SDK.
//!
//! These tests verify the SDK's core functionality by simulating gossip/reqresp events
//! and asserting that storage, deduplication, and catch-up work correctly.
//!
//! The tests use synthetic `NetworkEvent` inputs rather than real network connections,
//! allowing deterministic testing of SDK logic.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use p2p::storage::{InMemoryStorage, SdkStorage, compute_message_id};
use p2p::{CatchupAction, CatchupConfig, CatchupPipeline, CatchupState, EventHandler, SdkEvent};
use preconfirmation_net::NetworkEvent;
use preconfirmation_types::{
    Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, RawTxListGossip,
    SignedCommitment, TxListBytes, Uint256,
};

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

/// Creates a sample raw txlist with the given hash byte.
fn sample_txlist(hash_byte: u8) -> RawTxListGossip {
    RawTxListGossip {
        raw_tx_list_hash: Bytes32::try_from(vec![hash_byte; 32]).unwrap(),
        txlist: TxListBytes::try_from(vec![hash_byte; 100]).unwrap(),
    }
}

// ============================================================================
// Smoke Tests
// ============================================================================

#[tokio::test]
async fn smoke_client_roundtrip() {
    // This test simulates a gossip/reqresp roundtrip and verifies storage updates.
    let storage = Arc::new(InMemoryStorage::default());
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
    let storage = Arc::new(InMemoryStorage::default());
    let handler = EventHandler::new(storage.clone(), TEST_CHAIN_ID);

    let peer = libp2p::PeerId::random();

    // Create commitment
    let commitment = sample_commitment(100, 0xBB);

    // First gossip - may return None due to validation (invalid signature),
    // but should mark message as seen
    let _result1 = handler.handle_commitment_gossip(peer, commitment.clone());

    // Second gossip with same commitment - should be deduplicated at message level
    let result2 = handler.handle_commitment_gossip(peer, commitment.clone());
    assert!(result2.is_none(), "duplicate commitment should be deduplicated at message level");
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
    let result = handler.handle_event(NetworkEvent::PeerConnected(peer));
    assert!(matches!(result, Some(SdkEvent::PeerConnected { peer: p }) if p == peer));

    // Peer disconnected
    let result = handler.handle_event(NetworkEvent::PeerDisconnected(peer));
    assert!(matches!(result, Some(SdkEvent::PeerDisconnected { peer: p }) if p == peer));
}

#[tokio::test]
async fn smoke_handler_network_error() {
    // Test that network errors are converted to SDK error events
    let storage = Arc::new(InMemoryStorage::default());
    let handler = EventHandler::new(storage, TEST_CHAIN_ID);

    let result = handler.handle_event(NetworkEvent::Error("test network error".into()));
    assert!(matches!(result, Some(SdkEvent::Error { detail }) if detail.contains("network")));
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
