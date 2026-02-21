//! Commitment storage and pending buffer implementation.
//!
//! This module provides:
//! - `CommitmentStore` trait for accessing stored commitments and txlists.
//! - `InMemoryCommitmentStore` for caching commitments in memory.
//! - `CommitmentsAwaitingTxList` for buffering commitments awaiting txlists.

mod awaiting;
mod store;

pub use store::{CommitmentStore, InMemoryCommitmentStore};

#[cfg(test)]
mod tests {
    use super::{CommitmentStore, InMemoryCommitmentStore};
    use alloy_primitives::{B256, U256};
    use preconfirmation_net::PreconfStorage;
    use preconfirmation_types::{
        Bytes32, RawTxListGossip, SignedCommitment, TxListBytes, u256_to_uint256,
    };

    fn commitment_with_block(block: U256) -> SignedCommitment {
        let mut commitment = SignedCommitment::default();
        commitment.commitment.preconf.block_number = u256_to_uint256(block);
        commitment
    }

    fn txlist_with_byte(byte: u8) -> RawTxListGossip {
        let raw_tx_list_hash = Bytes32::try_from(vec![byte; 32]).expect("32-byte hash");
        let txlist = TxListBytes::try_from(vec![byte; 3]).expect("txlist bytes");
        RawTxListGossip { raw_tx_list_hash, txlist }
    }

    fn commitment_with_block_and_hash(block: U256, hash: Bytes32) -> SignedCommitment {
        let mut commitment = SignedCommitment::default();
        commitment.commitment.preconf.block_number = u256_to_uint256(block);
        commitment.commitment.preconf.raw_tx_list_hash = hash;
        commitment
    }

    fn txlist_with_hash(hash: Bytes32) -> RawTxListGossip {
        let txlist = TxListBytes::try_from(vec![0xAB; 3]).expect("txlist bytes");
        RawTxListGossip { raw_tx_list_hash: hash, txlist }
    }

    #[test]
    fn commitments_awaiting_txlist_evicts_oldest() {
        let store = InMemoryCommitmentStore::with_retention_limit(3);

        let txlist_hash = Bytes32::try_from(vec![1u8; 32]).expect("txlist hash");
        store.add_awaiting_txlist(&txlist_hash, commitment_with_block(U256::from(10u64)));
        store.add_awaiting_txlist(&txlist_hash, commitment_with_block(U256::from(5u64)));
        store.add_awaiting_txlist(&txlist_hash, commitment_with_block(U256::from(15u64)));

        store.add_awaiting_txlist(&txlist_hash, commitment_with_block(U256::from(20u64)));

        let waiting = store.take_awaiting_txlist(&txlist_hash);
        assert_eq!(waiting.len(), 3);

        let blocks: Vec<u64> = waiting
            .iter()
            .map(|c| {
                let block =
                    preconfirmation_types::uint256_to_u256(&c.commitment.preconf.block_number);
                block.try_into().unwrap()
            })
            .collect();
        assert!(!blocks.contains(&5u64));
        assert!(blocks.contains(&10u64));
        assert!(blocks.contains(&15u64));
        assert!(blocks.contains(&20u64));
    }

    #[test]
    fn store_roundtrip_commitment() {
        let store = InMemoryCommitmentStore::new();
        assert!(store.latest_commitment().is_none());
    }

    #[test]
    fn pending_commitment_hidden_until_accepted() {
        let store = InMemoryCommitmentStore::new();
        let block = U256::from(7);
        let commitment = commitment_with_block(block);

        PreconfStorage::insert_commitment(&store, block, commitment.clone());

        assert!(store.latest_commitment().is_none());
        assert!(PreconfStorage::commitments_from(&store, block, 1).is_empty());

        CommitmentStore::insert_commitment(&store, commitment.clone());

        let commitments = PreconfStorage::commitments_from(&store, block, 1);
        assert_eq!(commitments, vec![commitment]);
    }

    #[test]
    fn pending_txlist_hidden_until_accepted() {
        let store = InMemoryCommitmentStore::new();
        let txlist = txlist_with_byte(0xAB);
        let hash = B256::from_slice(txlist.raw_tx_list_hash.as_ref());

        PreconfStorage::insert_txlist(&store, hash, txlist.clone());

        assert!(PreconfStorage::get_txlist(&store, &hash).is_none());

        CommitmentStore::insert_txlist(&store, hash, txlist.clone());

        assert_eq!(PreconfStorage::get_txlist(&store, &hash), Some(txlist));
    }

    #[test]
    fn retention_prunes_oldest_commitment_and_txlist() {
        let store = InMemoryCommitmentStore::with_retention_limit(2);
        let first_block = U256::from(1u64);
        let second_block = U256::from(2u64);
        let third_block = U256::from(3u64);

        let first_hash = Bytes32::try_from(vec![0x11; 32]).expect("hash");
        let second_hash = Bytes32::try_from(vec![0x22; 32]).expect("hash");
        let third_hash = Bytes32::try_from(vec![0x33; 32]).expect("hash");

        CommitmentStore::insert_commitment(
            &store,
            commitment_with_block_and_hash(first_block, first_hash.clone()),
        );
        CommitmentStore::insert_commitment(
            &store,
            commitment_with_block_and_hash(second_block, second_hash.clone()),
        );
        CommitmentStore::insert_commitment(
            &store,
            commitment_with_block_and_hash(third_block, third_hash.clone()),
        );

        CommitmentStore::insert_txlist(
            &store,
            B256::from_slice(first_hash.as_ref()),
            txlist_with_hash(first_hash.clone()),
        );
        CommitmentStore::insert_txlist(
            &store,
            B256::from_slice(second_hash.as_ref()),
            txlist_with_hash(second_hash.clone()),
        );
        CommitmentStore::insert_txlist(
            &store,
            B256::from_slice(third_hash.as_ref()),
            txlist_with_hash(third_hash.clone()),
        );

        assert!(CommitmentStore::get_commitment(&store, &first_block).is_none());
        assert!(
            CommitmentStore::get_txlist(&store, &B256::from_slice(first_hash.as_ref())).is_none()
        );
        assert!(CommitmentStore::get_commitment(&store, &second_block).is_some());
        assert!(CommitmentStore::get_commitment(&store, &third_block).is_some());
        assert!(
            CommitmentStore::get_txlist(&store, &B256::from_slice(second_hash.as_ref())).is_some()
        );
        assert!(
            CommitmentStore::get_txlist(&store, &B256::from_slice(third_hash.as_ref())).is_some()
        );
    }

    #[test]
    fn retention_prunes_pending_buffers() {
        let store = InMemoryCommitmentStore::with_retention_limit(1);
        let first_block = U256::from(10u64);
        let second_block = U256::from(11u64);
        let first_hash = Bytes32::try_from(vec![0x44; 32]).expect("hash");
        let second_hash = Bytes32::try_from(vec![0x55; 32]).expect("hash");

        PreconfStorage::insert_commitment(
            &store,
            first_block,
            commitment_with_block_and_hash(first_block, first_hash.clone()),
        );
        PreconfStorage::insert_commitment(
            &store,
            second_block,
            commitment_with_block_and_hash(second_block, second_hash.clone()),
        );

        PreconfStorage::insert_txlist(
            &store,
            B256::from_slice(first_hash.as_ref()),
            txlist_with_hash(first_hash.clone()),
        );
        PreconfStorage::insert_txlist(
            &store,
            B256::from_slice(second_hash.as_ref()),
            txlist_with_hash(second_hash.clone()),
        );

        assert!(store.pending_commitments_len() <= 1);
        assert!(store.pending_txlists_len() <= 1);
    }
}
