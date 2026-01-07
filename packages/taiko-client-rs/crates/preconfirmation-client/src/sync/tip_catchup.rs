//! Tip catch-up implementation.
//!
//! This module implements the tip catch-up logic for synchronizing
//! preconfirmation commitments after normal L2 sync completes.

use std::sync::Arc;

use alloy_primitives::U256;
use preconfirmation_net::P2pHandle;
use preconfirmation_types::{
    Bytes32, RawTxListGossip, SignedCommitment, bytes32_to_b256, u256_to_uint256, uint256_to_u256,
};
use tracing::{debug, info};

use crate::{
    config::PreconfirmationClientConfig,
    error::{PreconfirmationClientError, Result},
    storage::CommitmentStore,
    validation::rules,
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

impl TipCatchup {
    /// Create a new tip catch-up handler.
    pub fn new(config: PreconfirmationClientConfig, store: Arc<dyn CommitmentStore>) -> Self {
        Self { config, store }
    }

    /// Run the catch-up process using the provided P2P handle.
    pub async fn run(&self, handle: &mut P2pHandle) -> Result<Vec<SignedCommitment>> {
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
            return Ok(Vec::new());
        }

        // Start from the next block after local head.
        let mut current = local_head + U256::ONE;
        // Prepare the accumulator for fetched commitments.
        let mut fetched = Vec::new();

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

            // Store and accumulate commitments.
            for commitment in response.commitments.iter() {
                // Clone the commitment for storage and output.
                let commitment = commitment.clone();
                // Store the commitment.
                self.store.insert_commitment(commitment.clone());
                // Push into the output list.
                fetched.push(commitment);
            }

            // Advance the current block number by the number fetched.
            current += U256::from(response.commitments.len() as u64);
        }

        // Fetch missing txlists for non-EOP commitments.
        for commitment in &fetched {
            // Skip EOP-only commitments (no txlist).
            if rules::is_eop_only(commitment) {
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
            rules::validate_txlist_response(&response)?;
            // Skip empty responses (txlist not found).
            if response.txlist.is_empty() {
                continue;
            }
            // Build a gossip-style container for storage.
            let gossip = RawTxListGossip { raw_tx_list_hash: txlist_hash, txlist: response.txlist };
            // Store the txlist by hash.
            self.store.insert_txlist(bytes32_to_b256(&gossip.raw_tx_list_hash), gossip);
        }

        // Update the stored head snapshot.
        self.store.set_head(peer_head);

        Ok(fetched)
    }

    /// Fetch a txlist by hash from peers.
    pub async fn fetch_txlist(&self, handle: &mut P2pHandle, hash: Bytes32) -> Result<Vec<u8>> {
        // Request the raw txlist payload by hash.
        let response = handle.request_raw_txlist(hash, None).await.map_err(|err| {
            PreconfirmationClientError::Catchup(format!("failed to fetch txlist: {err}"))
        })?;
        // Validate the response payload.
        rules::validate_txlist_response(&response)?;
        Ok(response.txlist.to_vec())
    }
}
