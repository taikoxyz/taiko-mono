//! Tip catch-up implementation.
//!
//! This module implements the tip catch-up logic for synchronizing
//! preconfirmation commitments after normal L2 sync completes.

use std::{collections::HashMap, sync::Arc};

use alloy_primitives::{B256, U256};
use preconfirmation_net::P2pHandle;
use preconfirmation_types::{
    Bytes32, RawTxListGossip, SignedCommitment, preconfirmation_hash, u256_to_uint256,
    uint256_to_u256,
};
use protocol::preconfirmation::PreconfSignerResolver;
use tokio::task::JoinSet;
use tracing::{debug, error, info, warn};

use crate::{
    config::PreconfirmationClientConfig,
    error::{PreconfirmationClientError, Result},
    metrics::PreconfirmationClientMetrics,
    storage::CommitmentStore,
    validation::{is_eop_only, validate_commitment_with_signer, validate_lookahead},
};

use super::txlist_fetch::fetch_txlist;

/// Default concurrent txlist fetches when not configured.
const DEFAULT_TXLIST_FETCH_CONCURRENCY: usize = 4;

/// Tip catch-up handler.
pub struct TipCatchup {
    /// Configuration snapshot used for catch-up parameters.
    config: PreconfirmationClientConfig,
    /// Commitment store used to persist fetched data.
    store: Arc<dyn CommitmentStore>,
}

impl TipCatchup {
    /// Create a new tip catch-up handler.
    pub fn new(config: PreconfirmationClientConfig, store: Arc<dyn CommitmentStore>) -> Self {
        Self { config, store }
    }

    /// Backfill commitments from the peer head using backward chaining.
    pub async fn backfill_from_peer_head(
        &self,
        handle: &mut P2pHandle,
        event_sync_tip: U256,
    ) -> Result<Vec<SignedCommitment>> {
        info!(event_sync_tip = %event_sync_tip, "starting tip catch-up");

        // 1) Fetch the peer head so we know the upper bound for backfill.
        let peer_head = handle.request_head(None).await.map_err(|err| {
            PreconfirmationClientError::Catchup(format!("failed to get peer head: {err}"))
        })?;
        let peer_tip = uint256_to_u256(&peer_head.block_number);

        // 2) Compute the first block after event sync; stop if we're already caught up.
        let catchup_start_block = event_sync_tip.saturating_add(U256::ONE);
        if catchup_start_block > peer_tip {
            info!(
                catchup_start_block = %catchup_start_block,
                peer_tip = %peer_tip,
                "already caught up; start block ahead of peer tip"
            );
            return Ok(Vec::new());
        }

        // 3) Fetch the tip commitment to anchor the backward chain.
        let tip_response =
            handle.request_commitments(u256_to_uint256(peer_tip), 1, None).await.map_err(
                |err| PreconfirmationClientError::Catchup(format!("failed to fetch tip: {err}")),
            )?;

        let tip = tip_response.commitments.first().cloned().ok_or_else(|| {
            PreconfirmationClientError::Catchup(format!(
                "peer returned no commitment for tip at {peer_tip}"
            ))
        })?;

        // 4) Page through commitments between stop_block and the tip.
        let mut fetched = Vec::new();
        let mut current = catchup_start_block;
        let end = peer_tip.saturating_sub(U256::ONE);

        while current <= end {
            let remaining = end - current + U256::ONE;
            let batch_size = self.config.catchup_batch_size as u64;
            let count = remaining.try_into().unwrap_or(batch_size).min(batch_size) as u32;

            debug!(start = ?current, count, "requesting commitment batch");

            let response = handle
                .request_commitments(u256_to_uint256(current), count, None)
                .await
                .map_err(|err| {
                    metrics::counter!(PreconfirmationClientMetrics::CATCHUP_ERRORS_TOTAL)
                        .increment(1);
                    PreconfirmationClientError::Catchup(format!(
                        "failed to fetch commitments: {err}"
                    ))
                })?;

            metrics::counter!(PreconfirmationClientMetrics::CATCHUP_BATCHES_TOTAL).increment(1);

            if response.commitments.is_empty() {
                error!(start = ?current, count, "peer returned empty commitment batch during catch-up");
                metrics::counter!(PreconfirmationClientMetrics::CATCHUP_ERRORS_TOTAL).increment(1);
                return Err(PreconfirmationClientError::Catchup(
                    "peer returned empty commitment batch during catch-up".to_string(),
                ));
            }

            let fetched_count = response.commitments.len();
            fetched.extend(response.commitments.iter().cloned());
            current += U256::from(fetched_count as u64);
        }

        // 5) Build a contiguous, validated chain from the tip back to catchup_start_block.
        let mut chain = chain_from_tip(
            tip,
            &map_commitments(fetched),
            catchup_start_block,
            self.config.expected_slasher.as_ref(),
            self.config.lookahead_resolver.as_ref(),
        )
        .await;

        if chain.is_empty() {
            metrics::counter!(PreconfirmationClientMetrics::CATCHUP_ERRORS_TOTAL).increment(1);
            return Err(PreconfirmationClientError::Catchup(
                "no valid commitments found during catch-up".to_string(),
            ));
        }

        chain.reverse();

        // 6) Ensure the chain starts at the expected boundary before accepting it.
        let boundary_block = chain
            .first()
            .map(|commitment| uint256_to_u256(&commitment.commitment.preconf.block_number));

        ensure_catchup_boundary(catchup_start_block, boundary_block)?;

        // 7) Persist fetched commitments before attempting txlist fetches.
        for commitment in &chain {
            self.store.insert_commitment(commitment.clone());
        }

        // 8) Fetch and persist txlists for non-EOP commitments.
        let txlist_hashes: Vec<Bytes32> = chain
            .iter()
            .filter(|commitment| !is_eop_only(commitment))
            .map(|commitment| commitment.commitment.preconf.raw_tx_list_hash.clone())
            .collect();

        let concurrency =
            self.config.txlist_fetch_concurrency.unwrap_or(DEFAULT_TXLIST_FETCH_CONCURRENCY).max(1);

        if !txlist_hashes.is_empty() {
            let command_tx = handle.command_sender();
            let mut join_set: JoinSet<Result<Option<RawTxListGossip>>> = JoinSet::new();
            let mut pending = txlist_hashes.into_iter();

            for _ in 0..concurrency {
                if let Some(hash) = pending.next() {
                    let command_tx = command_tx.clone();
                    join_set.spawn(async move { fetch_txlist(command_tx, hash).await });
                }
            }

            while let Some(result) = join_set.join_next().await {
                match result {
                    Ok(Ok(Some(gossip))) => {
                        let hash = B256::from_slice(gossip.raw_tx_list_hash.as_ref());
                        self.store.insert_txlist(hash, gossip);
                    }
                    Ok(Ok(None)) => {}
                    Ok(Err(err)) => return Err(err),
                    Err(err) => {
                        return Err(PreconfirmationClientError::Catchup(format!(
                            "txlist task failed: {err}"
                        )));
                    }
                }

                if let Some(hash) = pending.next() {
                    let command_tx = command_tx.clone();
                    join_set.spawn(async move { fetch_txlist(command_tx, hash).await });
                }
            }
        }

        Ok(chain)
    }
}

/// Validate a commitment using the lookahead resolver.
pub(crate) async fn validate_commitment(
    commitment: &SignedCommitment,
    expected_slasher: Option<&preconfirmation_types::Bytes20>,
    lookahead_resolver: &(dyn PreconfSignerResolver + Send + Sync),
) -> Option<SignedCommitment> {
    let recovered_signer = match validate_commitment_with_signer(commitment, expected_slasher) {
        Ok(signer) => signer,
        Err(err) => {
            warn!(error = %err, "dropping catch-up commitment with invalid basics");
            return None;
        }
    };

    let timestamp = uint256_to_u256(&commitment.commitment.preconf.timestamp);
    let expected_slot_info = match lookahead_resolver.slot_info_for_timestamp(timestamp).await {
        Ok(info) => info,
        Err(err) => {
            warn!(timestamp = %timestamp, error = %err, "dropping catch-up commitment with lookahead error");
            return None;
        }
    };

    if let Err(err) = validate_lookahead(commitment, recovered_signer, &expected_slot_info) {
        warn!(error = %err, "dropping catch-up commitment with invalid lookahead");
        return None;
    }

    Some(commitment.clone())
}

/// Map commitments by their preconfirmation hash.
/// Index commitments by their commitment hash.
pub(crate) fn map_commitments(
    commitments: Vec<SignedCommitment>,
) -> HashMap<B256, SignedCommitment> {
    commitments
        .into_iter()
        .filter_map(|commitment| {
            preconfirmation_hash(&commitment.commitment.preconf)
                .map_err(|err| warn!(error = %err, "dropping commitment with invalid preconfirmation hash"))
                .ok()
                .map(|hash| (hash, commitment))
        })
        .collect()
}

/// Build a contiguous chain from the tip backward to the stop block.
pub(crate) async fn chain_from_tip(
    tip: SignedCommitment,
    commitments_by_hash: &HashMap<B256, SignedCommitment>,
    stop_block: U256,
    expected_slasher: Option<&preconfirmation_types::Bytes20>,
    lookahead_resolver: &(dyn PreconfSignerResolver + Send + Sync),
) -> Vec<SignedCommitment> {
    let mut chain = Vec::new();
    let mut current = tip;

    let tip_block = uint256_to_u256(&current.commitment.preconf.block_number);
    if tip_block <= stop_block {
        return Vec::new();
    }

    let tip = match validate_commitment(&current, expected_slasher, lookahead_resolver).await {
        Some(commitment) => commitment,
        None => return Vec::new(),
    };

    chain.push(tip.clone());
    current = tip;

    loop {
        let current_block = uint256_to_u256(&current.commitment.preconf.block_number);
        if current_block <= stop_block {
            break;
        }

        let parent_hash =
            B256::from_slice(current.commitment.preconf.parent_preconfirmation_hash.as_ref());
        if parent_hash == B256::ZERO {
            break;
        }

        let parent = match commitments_by_hash.get(&parent_hash) {
            Some(parent) => parent.clone(),
            None => {
                warn!(current = %current_block, "missing parent commitment during catch-up");
                break;
            }
        };

        let parent = match validate_commitment(&parent, expected_slasher, lookahead_resolver).await
        {
            Some(commitment) => commitment,
            None => {
                warn!(current = %current_block, "parent commitment failed validation");
                break;
            }
        };

        chain.push(parent.clone());
        current = parent;
    }

    chain
}

/// Ensure the catch-up chain starts at the expected stop block.
pub(crate) fn ensure_catchup_boundary(
    stop_block: U256,
    boundary_block: Option<U256>,
) -> Result<()> {
    if boundary_block == Some(stop_block) {
        Ok(())
    } else {
        Err(PreconfirmationClientError::Catchup(format!(
            "catch-up chain did not reach the driver sync boundary: expected {stop_block}, got {boundary_block:?}"
        )))
    }
}

#[cfg(test)]
pub(crate) const CATCHUP_MODULE_MARKER: () = ();
