//! Tip catch-up implementation.
//!
//! This module implements the tip catch-up logic for synchronizing
//! preconfirmation commitments after normal L2 sync completes.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::P2pHandle;
use preconfirmation_types::{
    Bytes32, RawTxListGossip, SignedCommitment, u256_to_uint256, uint256_to_u256,
};
use protocol::preconfirmation::PreconfSignerResolver;
use tracing::{debug, info, warn};

use crate::{
    config::PreconfirmationClientConfig,
    error::{PreconfirmationClientError, Result},
    storage::CommitmentStore,
    validation::rules::{
        is_eop_only, validate_commitment_basic_with_signer, validate_lookahead,
        validate_parent_linkage, validate_txlist_response,
    },
};

/// Tip catch-up handler.
///
/// This component is responsible for synchronizing preconfirmation commitments
/// from the P2P network after the L2 execution layer has completed its sync.
pub struct TipCatchup {
    /// Configuration for the client.
    config: PreconfirmationClientConfig,
    /// Reference to the commitment store.
    store: Arc<dyn CommitmentStore>,
}

/// Seed commitments into the store after pre-validation during catch-up.
async fn seed_commitments(
    store: &dyn CommitmentStore,
    commitments: &[SignedCommitment],
    expected_slasher: Option<&preconfirmation_types::Bytes20>,
    lookahead_resolver: &(dyn PreconfSignerResolver + Send + Sync),
    allow_parentless: bool,
    parentless_block: U256,
) -> Result<(Vec<SignedCommitment>, Option<U256>)> {
    let mut seeded = Vec::new();
    let mut parentless_block_used = None;

    for commitment in commitments {
        let parent_hash =
            B256::from_slice(commitment.commitment.preconf.parent_preconfirmation_hash.as_ref());
        if parent_hash == B256::ZERO {
            debug!("ignoring genesis commitment during catch-up");
            continue;
        }

        // Validate basic commitment rules and recover signer.
        let recovered_signer =
            match validate_commitment_basic_with_signer(commitment, expected_slasher) {
                Ok(signer) => signer,
                Err(err) => {
                    warn!(error = %err, "dropping catch-up commitment with invalid basics");
                    continue;
                }
            };

        let timestamp = uint256_to_u256(&commitment.commitment.preconf.timestamp);
        let expected_slot_info = match lookahead_resolver.slot_info_for_timestamp(timestamp).await {
            Ok(info) => info,
            Err(err) => {
                warn!(timestamp = %timestamp, error = %err, "dropping catch-up commitment with lookahead error");
                continue;
            }
        };

        if let Err(err) = validate_lookahead(commitment, recovered_signer, &expected_slot_info) {
            warn!(error = %err, "dropping catch-up commitment with invalid lookahead");
            continue;
        }

        let current_block = uint256_to_u256(&commitment.commitment.preconf.block_number);
        let expected_parent = current_block.saturating_sub(U256::ONE);
        let parent = store.get_commitment(&expected_parent);

        if let Some(parent) = parent {
            if let Err(err) = validate_parent_linkage(commitment, &parent.commitment.preconf) {
                warn!(error = %err, "dropping catch-up commitment with invalid parent linkage");
                continue;
            }
            let parent_block = uint256_to_u256(&parent.commitment.preconf.block_number);
            let expected_block = parent_block + U256::ONE;
            if current_block != expected_block {
                warn!(
                    current = %current_block,
                    expected = %expected_block,
                    "dropping catch-up commitment with non-sequential block number"
                );
                continue;
            }
        } else if allow_parentless &&
            parentless_block_used.is_none() &&
            current_block == parentless_block
        {
            parentless_block_used = Some(current_block);
            warn!(
                block = %current_block,
                "accepting catch-up commitment without parent"
            );
        } else {
            warn!(
                block = %current_block,
                "dropping catch-up commitment without known parent"
            );
            continue;
        }

        store.insert_commitment(commitment.clone());
        seeded.push(commitment.clone());
    }

    Ok((seeded, parentless_block_used))
}

impl TipCatchup {
    /// Create a new tip catch-up handler.
    pub fn new(config: PreconfirmationClientConfig, store: Arc<dyn CommitmentStore>) -> Self {
        Self { config, store }
    }

    /// Backfill commitments from the peer head using the provided P2P handle.
    pub async fn backfill_from_peer_head(
        &self,
        handle: &mut P2pHandle,
    ) -> Result<(Vec<SignedCommitment>, Option<U256>)> {
        info!("starting tip catch-up");

        // Request head from any connected peer.
        let peer_head = handle.request_head(None).await.map_err(|err| {
            PreconfirmationClientError::Catchup(format!("failed to get peer head: {err}"))
        })?;
        // Convert peer head to a block number.
        let peer_tip = uint256_to_u256(&peer_head.block_number);

        // Determine local head from storage.
        let local_head = self.store.latest_block_number().unwrap_or_default();
        if local_head >= peer_tip {
            info!("already synced to peer head");
            return Ok((Vec::new(), None));
        }

        // Start from the next block after local head.
        let mut current = local_head + U256::ONE;
        // Prepare the accumulator for fetched commitments.
        let mut fetched = Vec::new();
        let mut parentless_block = None;

        let mut allow_parentless = self.store.latest_block_number().is_none();

        while current <= peer_tip {
            // Compute remaining blocks to request.
            let remaining = peer_tip - current + U256::ONE;
            // Clamp batch size to the configured maximum.
            let batch_size = self.config.catchup_batch_size as u64;
            // Convert remaining to u64 for comparison.
            let remaining_u64: u64 = remaining.try_into().unwrap_or(batch_size);
            // Compute the count for this batch.
            let count = remaining_u64.min(batch_size) as u32;

            debug!(start = ?current, count, "requesting commitment batch");

            // Send the commitments request.
            let response = handle
                .request_commitments(u256_to_uint256(current), count, None)
                .await
                .map_err(|err| {
                    PreconfirmationClientError::Catchup(format!(
                        "failed to fetch commitments: {err}"
                    ))
                })?;

            if response.commitments.is_empty() {
                break;
            }

            // Seed the fetched commitments into storage.
            let (seeded, parentless_block_used) = seed_commitments(
                self.store.as_ref(),
                &response.commitments,
                self.config.expected_slasher.as_ref(),
                &self.config.lookahead_resolver,
                allow_parentless,
                current,
            )
            .await?;
            if parentless_block.is_none() {
                parentless_block = parentless_block_used;
            }
            if parentless_block.is_some() {
                allow_parentless = false;
            }
            fetched.extend(seeded);

            // Advance the current block number by the number fetched.
            current += U256::from(response.commitments.len() as u64);
        }

        // Fetch missing txlists for non-EOP commitments.
        for commitment in &fetched {
            // Skip EOP-only commitments (no txlist).
            if is_eop_only(commitment) {
                continue;
            }
            // Extract the txlist hash for request.
            let txlist_hash = commitment.commitment.preconf.raw_tx_list_hash.clone();
            // Request the raw txlist.
            let response =
                handle.request_raw_txlist(txlist_hash.clone(), None).await.map_err(|err| {
                    PreconfirmationClientError::Catchup(format!("failed to fetch txlist: {err}"))
                })?;
            // Validate the response payload.
            validate_txlist_response(&response)?;
            // Skip empty responses (txlist not found).
            if response.txlist.is_empty() {
                continue;
            }
            // Build a gossip-style container for storage.
            let gossip = RawTxListGossip { raw_tx_list_hash: txlist_hash, txlist: response.txlist };
            // Store the txlist by hash.
            let hash = B256::from_slice(gossip.raw_tx_list_hash.as_ref());
            self.store.insert_txlist(hash, gossip);
        }

        Ok((fetched, parentless_block))
    }

    /// Fetch a txlist by hash from peers.
    pub async fn fetch_txlist_from_peers(
        &self,
        handle: &mut P2pHandle,
        hash: Bytes32,
    ) -> Result<Vec<u8>> {
        // Request the raw txlist payload by hash.
        let response = handle.request_raw_txlist(hash, None).await.map_err(|err| {
            PreconfirmationClientError::Catchup(format!("failed to fetch txlist: {err}"))
        })?;
        // Validate the response payload.
        validate_txlist_response(&response)?;
        Ok(response.txlist.to_vec())
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex;

    use alloy_primitives::{Address, U256};
    use async_trait::async_trait;
    use preconfirmation_types::{
        Bytes20, Bytes32, PreconfCommitment, PreconfHead, Preconfirmation, RawTxListGossip,
        SignedCommitment, Uint256, preconfirmation_hash, public_key_to_address, sign_commitment,
        uint256_to_u256,
    };
    use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo};
    use secp256k1::{PublicKey, Secp256k1, SecretKey};

    use super::seed_commitments;
    use crate::storage::CommitmentStore;

    /// Commitment store that records inserted commitments for tests.
    #[derive(Default)]
    struct RecordingStore {
        inserted: Mutex<std::collections::BTreeMap<U256, SignedCommitment>>,
    }

    impl CommitmentStore for RecordingStore {
        /// Record the inserted commitment.
        fn insert_commitment(&self, commitment: SignedCommitment) {
            let block_number = uint256_to_u256(&commitment.commitment.preconf.block_number);
            self.inserted.lock().unwrap().insert(block_number, commitment);
        }

        /// Return None for missing commitments.
        fn get_commitment(&self, _block_number: &U256) -> Option<SignedCommitment> {
            self.inserted.lock().unwrap().get(_block_number).cloned()
        }

        /// Return None for latest commitment.
        fn latest_commitment(&self) -> Option<SignedCommitment> {
            self.inserted.lock().unwrap().values().next_back().cloned()
        }

        /// Return None for latest block number.
        fn latest_block_number(&self) -> Option<U256> {
            self.inserted.lock().unwrap().keys().next_back().cloned()
        }

        /// Return an empty range for commitments.
        fn commitments_from(&self, _start: U256, _max: usize) -> Vec<SignedCommitment> {
            Vec::new()
        }

        /// Ignore inserted txlists.
        fn insert_txlist(&self, _hash: alloy_primitives::B256, _txlist: RawTxListGossip) {}

        /// Return None for missing txlists.
        fn get_txlist(&self, _hash: &alloy_primitives::B256) -> Option<RawTxListGossip> {
            None
        }

        /// Ignore head updates.
        fn set_head(&self, _head: PreconfHead) {}

        /// Return None for head.
        fn head(&self) -> Option<PreconfHead> {
            None
        }
    }

    struct MockResolver {
        signer: Address,
        submission_window_end: U256,
    }

    #[async_trait]
    impl PreconfSignerResolver for MockResolver {
        async fn signer_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<Address> {
            Ok(self.signer)
        }

        async fn slot_info_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<PreconfSlotInfo> {
            Ok(PreconfSlotInfo {
                signer: self.signer,
                submission_window_end: self.submission_window_end,
            })
        }
    }

    fn make_commitment(
        block_number: u64,
        parent_hash: Bytes32,
        submission_window_end: u64,
        timestamp: u64,
        sk: &SecretKey,
    ) -> SignedCommitment {
        let preconf = Preconfirmation {
            eop: false,
            block_number: Uint256::from(block_number),
            timestamp: Uint256::from(timestamp),
            submission_window_end: Uint256::from(submission_window_end),
            parent_preconfirmation_hash: parent_hash,
            coinbase: Bytes20::try_from(vec![0u8; 20]).expect("coinbase"),
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).expect("txlist hash"),
            ..Default::default()
        };
        let commitment = PreconfCommitment { preconf, ..Default::default() };
        let signature = sign_commitment(&commitment, sk).expect("sign commitment");
        SignedCommitment { commitment, signature }
    }

    /// Seeded commitments include the parentless block and a valid child.
    #[tokio::test]
    async fn seed_commitments_accepts_parentless_and_child() {
        let store = RecordingStore::default();
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let secp = Secp256k1::new();
        let pk = PublicKey::from_secret_key(&secp, &sk);
        let signer = public_key_to_address(&pk);
        let resolver = MockResolver { signer, submission_window_end: U256::from(1000u64) };

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let parentless = make_commitment(1, parent_hash, 1000, 10, &sk);
        let parentless_hash =
            preconfirmation_hash(&parentless.commitment.preconf).expect("hash parentless");
        let child_parent =
            Bytes32::try_from(parentless_hash.as_slice().to_vec()).expect("hash length 32");
        let child = make_commitment(2, child_parent, 1000, 20, &sk);

        let (seeded, parentless_block_used) =
            seed_commitments(&store, &[parentless, child], None, &resolver, true, U256::ONE)
                .await
                .expect("seed commitments");

        assert_eq!(parentless_block_used, Some(U256::ONE));
        assert_eq!(seeded.len(), 2);
        assert_eq!(store.inserted.lock().unwrap().len(), 2);
    }

    /// Seeded commitments skip children with invalid parent linkage.
    #[tokio::test]
    async fn seed_commitments_skips_invalid_parent() {
        let store = RecordingStore::default();
        let sk = SecretKey::from_slice(&[2u8; 32]).expect("secret key");
        let secp = Secp256k1::new();
        let pk = PublicKey::from_secret_key(&secp, &sk);
        let signer = public_key_to_address(&pk);
        let resolver = MockResolver { signer, submission_window_end: U256::from(1000u64) };

        let parent_hash = Bytes32::try_from(vec![2u8; 32]).expect("parent hash");
        let parent = make_commitment(1, parent_hash, 1000, 10, &sk);
        store.insert_commitment(parent);

        let bad_parent = Bytes32::try_from(vec![9u8; 32]).expect("bad parent");
        let child = make_commitment(2, bad_parent, 1000, 20, &sk);

        let (seeded, parentless_block_used) =
            seed_commitments(&store, &[child], None, &resolver, false, U256::from(2u64))
                .await
                .expect("seed commitments");

        assert!(parentless_block_used.is_none());
        assert!(seeded.is_empty());
        assert_eq!(store.inserted.lock().unwrap().len(), 1);
    }
}
