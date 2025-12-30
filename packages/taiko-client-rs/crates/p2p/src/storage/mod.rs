//! SDK-level storage with dedupe, pending buffer, and TTL expiry.
//!
//! This module provides:
//! - Internal storage abstraction for commitments, txlists, dedupe, and pending buffer
//! - `InMemoryStorage`: in-memory implementation with LRU/TTL-based caching
//! - Message ID helpers for deduplication

mod memory;

pub use memory::InMemoryStorage;

use alloy_primitives::{Address, B256, U256};
use preconfirmation_types::{RawTxListGossip, SignedCommitment};

/// Dedupe key for commitments: (slot/block_number, signer address).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub(crate) struct CommitmentDedupeKey {
    /// Block number (slot) of the commitment.
    pub block_number: U256,
    /// Signer address recovered from the commitment signature.
    pub signer: Address,
}

/// Dedupe key for raw txlists: (block_number, raw_tx_list_hash).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub(crate) struct TxListDedupeKey {
    /// Block number associated with the txlist.
    pub block_number: U256,
    /// Hash of the raw tx list.
    pub raw_tx_list_hash: B256,
}

/// SDK-level storage trait extending basic storage with dedupe and pending buffer.
///
/// Implementations must be Send+Sync for use in async contexts.
pub(crate) trait SdkStorage: Send + Sync {
    // --- Commitment storage ---

    /// Insert a commitment keyed by block number.
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment);

    /// Return up to `max` commitments starting from `start` (inclusive).
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment>;

    /// Get a commitment by block number, if present.
    fn get_commitment(&self, block: U256) -> Option<SignedCommitment>;

    // --- Txlist storage ---

    /// Insert a raw txlist keyed by its hash.
    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip);

    /// Fetch a raw txlist by hash, if present.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip>;

    // --- Message-ID dedupe ---

    /// Check if a message ID has been seen recently.
    /// Returns `true` if the message is a duplicate (already seen).
    fn is_duplicate_message(&self, message_id: &B256) -> bool;

    /// Mark a message ID as seen.
    fn mark_message_seen(&self, message_id: B256);

    // --- Commitment dedupe ---

    /// Check if a commitment with this (block_number, signer) has been seen.
    fn is_duplicate_commitment(&self, key: &CommitmentDedupeKey) -> bool;

    /// Mark a commitment dedupe key as seen.
    fn mark_commitment_seen(&self, key: CommitmentDedupeKey);

    // --- TxList dedupe ---

    /// Check if a txlist with this (block_number, hash) has been seen.
    fn is_duplicate_txlist(&self, key: &TxListDedupeKey) -> bool;

    /// Mark a txlist dedupe key as seen.
    fn mark_txlist_seen(&self, key: TxListDedupeKey);

    // --- Pending buffer (parent linkage) ---

    /// Add a commitment to the pending buffer, awaiting its parent.
    fn add_pending(&self, parent_hash: B256, commitment: SignedCommitment);

    /// Release all commitments waiting on the given parent hash.
    /// Returns the released commitments and removes them from the pending buffer.
    fn release_pending(&self, parent_hash: &B256) -> Vec<SignedCommitment>;

    /// Get the number of pending commitments (for metrics/debugging).
    fn pending_count(&self) -> usize;

    /// Clear all pending commitments awaiting parent linkage.
    ///
    /// Returns the number of commitments removed from the pending buffer.
    fn clear_pending(&self) -> usize;

    // --- Pending buffer (txlist availability) ---

    /// Add a commitment to the pending txlist buffer, awaiting its txlist by hash.
    ///
    /// Returns `true` if this is the first pending entry for the txlist hash.
    fn add_pending_txlist(&self, txlist_hash: B256, commitment: SignedCommitment) -> bool;

    /// Release all commitments waiting on the given txlist hash.
    ///
    /// Returns the released commitments and removes them from the pending buffer.
    fn release_pending_txlist(&self, txlist_hash: &B256) -> Vec<SignedCommitment>;

    /// Check whether any commitments are pending for the given txlist hash.
    fn has_pending_txlist(&self, txlist_hash: &B256) -> bool;

    /// Get the number of commitments waiting on txlist data.
    fn pending_txlist_count(&self) -> usize;

    /// Clear all commitments waiting on txlist data.
    ///
    /// Returns the number of commitments removed from the txlist pending buffer.
    fn clear_pending_txlists(&self) -> usize;

    // --- Cleanup ---

    /// Remove expired entries from caches (called periodically).
    fn cleanup_expired(&self);
}

/// Compute a message ID as keccak256(topic || payload).
///
/// This provides a unique identifier for deduplication across gossip messages.
pub fn compute_message_id(topic: &str, payload: &[u8]) -> B256 {
    use sha3::{Digest, Keccak256};
    let mut hasher = Keccak256::new();
    hasher.update(topic.as_bytes());
    hasher.update(payload);
    B256::from_slice(&hasher.finalize())
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::Address;
    use preconfirmation_types::{
        Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
        TxListBytes, Uint256,
    };

    fn sample_preconfirmation(block_num: u64, parent_hash: [u8; 32]) -> Preconfirmation {
        Preconfirmation {
            eop: false,
            block_number: Uint256::from(block_num),
            timestamp: Uint256::from(1000u64),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(block_num.saturating_sub(1)),
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(parent_hash.to_vec()).unwrap(),
            submission_window_end: Uint256::from(2000u64),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        }
    }

    fn sample_commitment(block_num: u64, parent_hash: [u8; 32]) -> SignedCommitment {
        SignedCommitment {
            commitment: PreconfCommitment {
                preconf: sample_preconfirmation(block_num, parent_hash),
                slasher_address: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            },
            signature: Bytes65::try_from(vec![0xAA; 65]).unwrap(),
        }
    }

    fn sample_commitment_with_sig(block_num: u64, sig_byte: u8) -> SignedCommitment {
        SignedCommitment {
            commitment: PreconfCommitment {
                preconf: sample_preconfirmation(block_num, [0u8; 32]),
                slasher_address: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            },
            signature: Bytes65::try_from(vec![sig_byte; 65]).unwrap(),
        }
    }

    fn sample_txlist(hash_byte: u8) -> RawTxListGossip {
        RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(vec![hash_byte; 32]).unwrap(),
            txlist: TxListBytes::try_from(vec![hash_byte; 100]).unwrap(),
        }
    }

    // --- Pending buffer tests ---

    #[test]
    fn pending_commitments_release_on_parent() {
        let store = InMemoryStorage::default();

        // Create parent hash
        let parent_hash = B256::from([0x11; 32]);

        // Add child commitment waiting for parent
        let child = sample_commitment(2, [0x11; 32]);
        store.add_pending(parent_hash, child.clone());

        // Verify pending count
        assert_eq!(store.pending_count(), 1);

        // Release pending when parent arrives
        let released = store.release_pending(&parent_hash);

        // Child should be released
        assert_eq!(released.len(), 1);
        assert_eq!(released[0].signature, child.signature);

        // Pending count should be zero
        assert_eq!(store.pending_count(), 0);

        // Releasing again should return empty
        let released_again = store.release_pending(&parent_hash);
        assert!(released_again.is_empty());
    }

    #[test]
    fn pending_buffer_handles_multiple_children() {
        let store = InMemoryStorage::default();

        let parent_hash = B256::from([0x22; 32]);

        // Add multiple children waiting for same parent
        let child1 = sample_commitment_with_sig(2, 0xAA);
        let child2 = sample_commitment_with_sig(3, 0xBB);
        let child3 = sample_commitment_with_sig(4, 0xCC);

        store.add_pending(parent_hash, child1);
        store.add_pending(parent_hash, child2);
        store.add_pending(parent_hash, child3);

        assert_eq!(store.pending_count(), 3);

        // Release all at once
        let released = store.release_pending(&parent_hash);
        assert_eq!(released.len(), 3);
        assert_eq!(store.pending_count(), 0);
    }

    #[test]
    fn pending_buffer_separates_by_parent_hash() {
        let store = InMemoryStorage::default();

        let parent1 = B256::from([0x11; 32]);
        let parent2 = B256::from([0x22; 32]);

        let child1 = sample_commitment_with_sig(2, 0xAA);
        let child2 = sample_commitment_with_sig(3, 0xBB);

        store.add_pending(parent1, child1);
        store.add_pending(parent2, child2);

        assert_eq!(store.pending_count(), 2);

        // Release only parent1's children
        let released1 = store.release_pending(&parent1);
        assert_eq!(released1.len(), 1);
        assert_eq!(store.pending_count(), 1);

        // Release parent2's children
        let released2 = store.release_pending(&parent2);
        assert_eq!(released2.len(), 1);
        assert_eq!(store.pending_count(), 0);
    }

    // --- Commitment storage tests ---

    #[test]
    fn commitment_insert_and_get() {
        let store = InMemoryStorage::default();

        let commitment = sample_commitment_with_sig(100, 0xDD);
        store.insert_commitment(U256::from(100), commitment.clone());

        let retrieved = store.get_commitment(U256::from(100));
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().signature, commitment.signature);
    }

    #[test]
    fn commitments_from_returns_ordered_range() {
        let store = InMemoryStorage::default();

        // Insert out of order
        store.insert_commitment(U256::from(3), sample_commitment_with_sig(3, 0x33));
        store.insert_commitment(U256::from(1), sample_commitment_with_sig(1, 0x11));
        store.insert_commitment(U256::from(2), sample_commitment_with_sig(2, 0x22));
        store.insert_commitment(U256::from(5), sample_commitment_with_sig(5, 0x55));

        // Get range from block 2
        let commitments = store.commitments_from(U256::from(2), 2);
        assert_eq!(commitments.len(), 2);

        // Should be ordered: block 2, then block 3
        assert_eq!(commitments[0].signature[0], 0x22);
        assert_eq!(commitments[1].signature[0], 0x33);
    }

    // --- Txlist storage tests ---

    #[test]
    fn txlist_insert_and_get() {
        let store = InMemoryStorage::default();

        let hash = B256::from([0xAB; 32]);
        let txlist = sample_txlist(0xAB);

        store.insert_txlist(hash, txlist.clone());

        let retrieved = store.get_txlist(&hash);
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().txlist.len(), txlist.txlist.len());
    }

    #[test]
    fn txlist_get_missing_returns_none() {
        let store = InMemoryStorage::default();
        let hash = B256::from([0xFF; 32]);
        assert!(store.get_txlist(&hash).is_none());
    }

    // --- Message-ID dedupe tests ---

    #[test]
    fn message_dedupe_detects_duplicates() {
        let store = InMemoryStorage::default();

        let msg_id = B256::from([0x99; 32]);

        // First time: not a duplicate
        assert!(!store.is_duplicate_message(&msg_id));

        // Mark as seen
        store.mark_message_seen(msg_id);

        // Second time: is a duplicate
        assert!(store.is_duplicate_message(&msg_id));
    }

    #[test]
    fn message_dedupe_different_ids_independent() {
        let store = InMemoryStorage::default();

        let msg1 = B256::from([0x11; 32]);
        let msg2 = B256::from([0x22; 32]);

        store.mark_message_seen(msg1);

        assert!(store.is_duplicate_message(&msg1));
        assert!(!store.is_duplicate_message(&msg2));
    }

    // --- Commitment dedupe tests ---

    #[test]
    fn commitment_dedupe_by_block_and_signer() {
        let store = InMemoryStorage::default();

        let key = CommitmentDedupeKey {
            block_number: U256::from(100),
            signer: Address::from([0xAA; 20]),
        };

        assert!(!store.is_duplicate_commitment(&key));
        store.mark_commitment_seen(key.clone());
        assert!(store.is_duplicate_commitment(&key));
    }

    #[test]
    fn commitment_dedupe_different_signers_independent() {
        let store = InMemoryStorage::default();

        let key1 = CommitmentDedupeKey {
            block_number: U256::from(100),
            signer: Address::from([0xAA; 20]),
        };
        let key2 = CommitmentDedupeKey {
            block_number: U256::from(100),
            signer: Address::from([0xBB; 20]),
        };

        store.mark_commitment_seen(key1.clone());

        assert!(store.is_duplicate_commitment(&key1));
        assert!(!store.is_duplicate_commitment(&key2));
    }

    #[test]
    fn commitment_dedupe_different_blocks_independent() {
        let store = InMemoryStorage::default();

        let key1 = CommitmentDedupeKey {
            block_number: U256::from(100),
            signer: Address::from([0xAA; 20]),
        };
        let key2 = CommitmentDedupeKey {
            block_number: U256::from(101),
            signer: Address::from([0xAA; 20]),
        };

        store.mark_commitment_seen(key1.clone());

        assert!(store.is_duplicate_commitment(&key1));
        assert!(!store.is_duplicate_commitment(&key2));
    }

    // --- Txlist dedupe tests ---

    #[test]
    fn txlist_dedupe_by_block_and_hash() {
        let store = InMemoryStorage::default();

        let key = TxListDedupeKey {
            block_number: U256::from(100),
            raw_tx_list_hash: B256::from([0xCC; 32]),
        };

        assert!(!store.is_duplicate_txlist(&key));
        store.mark_txlist_seen(key.clone());
        assert!(store.is_duplicate_txlist(&key));
    }

    #[test]
    fn txlist_dedupe_different_hashes_independent() {
        let store = InMemoryStorage::default();

        let key1 = TxListDedupeKey {
            block_number: U256::from(100),
            raw_tx_list_hash: B256::from([0xCC; 32]),
        };
        let key2 = TxListDedupeKey {
            block_number: U256::from(100),
            raw_tx_list_hash: B256::from([0xDD; 32]),
        };

        store.mark_txlist_seen(key1.clone());

        assert!(store.is_duplicate_txlist(&key1));
        assert!(!store.is_duplicate_txlist(&key2));
    }

    // --- Message ID computation tests ---

    #[test]
    fn compute_message_id_deterministic() {
        // Use chain-specific topic format (chain_id = 167000 for Taiko mainnet)
        let topic = "/taiko/167000/0/preconfirmationCommitments";
        let payload = b"test payload data";

        let id1 = compute_message_id(topic, payload);
        let id2 = compute_message_id(topic, payload);

        assert_eq!(id1, id2);
    }

    #[test]
    fn compute_message_id_different_topics() {
        let payload = b"same payload";

        let id1 = compute_message_id("/topic1", payload);
        let id2 = compute_message_id("/topic2", payload);

        assert_ne!(id1, id2);
    }

    #[test]
    fn compute_message_id_different_payloads() {
        let topic = "/same/topic";

        let id1 = compute_message_id(topic, b"payload1");
        let id2 = compute_message_id(topic, b"payload2");

        assert_ne!(id1, id2);
    }
}
