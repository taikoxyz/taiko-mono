//! Tip catch-up implementation.
//!
//! This module implements the tip catch-up logic for synchronizing
//! preconfirmation commitments after normal L2 sync completes.

use std::{collections::HashMap, sync::Arc};

use alloy_primitives::{B256, U256};
use preconfirmation_net::{NetworkCommand, NetworkError, NetworkErrorKind, P2pHandle};
use preconfirmation_types::{
    Bytes32, RawTxListGossip, SignedCommitment, preconfirmation_hash, u256_to_uint256,
    uint256_to_u256,
};
use protocol::preconfirmation::PreconfSignerResolver;
use tokio::{
    sync::{mpsc::Sender, oneshot},
    task::JoinSet,
};
use tracing::{debug, error, info, warn};

use crate::{
    config::PreconfirmationClientConfig,
    error::{PreconfirmationClientError, Result},
    metrics::PreconfirmationClientMetrics,
    storage::CommitmentStore,
    validation::{is_eop_only, validate_commitment_with_signer, validate_lookahead},
};

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
async fn validate_commitment(
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
fn map_commitments(commitments: Vec<SignedCommitment>) -> HashMap<B256, SignedCommitment> {
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

/// Build a contiguous commitment chain by walking backwards from the tip.
async fn chain_from_tip(
    tip: SignedCommitment,
    commitments_by_hash: &HashMap<B256, SignedCommitment>,
    stop_block: U256,
    expected_slasher: Option<&preconfirmation_types::Bytes20>,
    lookahead_resolver: &(dyn PreconfSignerResolver + Send + Sync),
) -> Vec<SignedCommitment> {
    let mut chain = Vec::new();

    let mut current = match validate_commitment(&tip, expected_slasher, lookahead_resolver).await {
        Some(commitment) => commitment,
        None => return chain,
    };
    chain.push(current.clone());

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
fn ensure_catchup_boundary(stop_block: U256, boundary_block: Option<U256>) -> Result<()> {
    if boundary_block == Some(stop_block) {
        Ok(())
    } else {
        Err(PreconfirmationClientError::Catchup(format!(
            "catch-up chain did not reach the driver sync boundary: expected {stop_block}, got {boundary_block:?}"
        )))
    }
}

/// Request a raw txlist from the network using a command tx.
async fn request_raw_txlist_with_tx(
    command_tx: Sender<NetworkCommand>,
    hash: Bytes32,
) -> Result<preconfirmation_types::GetRawTxListResponse> {
    let (tx, rx) = oneshot::channel();
    command_tx
        .send(NetworkCommand::RequestRawTxList {
            respond_to: Some(tx),
            raw_tx_list_hash: hash,
            peer: None,
        })
        .await
        .map_err(|err| PreconfirmationClientError::Catchup(format!("send command: {err}")))?;

    rx.await
        .unwrap_or_else(|_| {
            Err(NetworkError::new(
                NetworkErrorKind::ReqRespTimeout,
                "service stopped before raw-txlist response",
            ))
        })
        .map_err(|err| PreconfirmationClientError::Catchup(err.to_string()))
}

/// Fetch and validate a txlist for a commitment hash.
async fn fetch_txlist(
    command_tx: Sender<NetworkCommand>,
    hash: Bytes32,
) -> Result<Option<RawTxListGossip>> {
    let hash_hex = B256::from_slice(hash.as_ref());
    let response = request_raw_txlist_with_tx(command_tx, hash.clone()).await.map_err(|err| {
        warn!(hash = %hash_hex, error = %err, "failed to fetch txlist during catch-up");
        err
    })?;
    preconfirmation_types::validate_raw_txlist_response(&response).map_err(|err| {
        warn!(hash = %hash_hex, error = %err, "txlist validation failed during catch-up");
        PreconfirmationClientError::Validation(format!("txlist {hash_hex}: {err}"))
    })?;
    if response.txlist.is_empty() {
        return Ok(None);
    }
    if response.raw_tx_list_hash.as_ref() != hash.as_ref() {
        let actual = B256::from_slice(response.raw_tx_list_hash.as_ref());
        return Err(PreconfirmationClientError::Validation(format!(
            "txlist hash mismatch: requested {hash_hex} got {actual}"
        )));
    }
    Ok(Some(RawTxListGossip { raw_tx_list_hash: hash, txlist: response.txlist }))
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Address, U256};
    use async_trait::async_trait;
    use preconfirmation_types::{
        Bytes20, Bytes32, PreconfCommitment, Preconfirmation, SignedCommitment, Uint256,
        preconfirmation_hash, public_key_to_address, sign_commitment, uint256_to_u256,
    };
    use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo};
    use secp256k1::{PublicKey, Secp256k1, SecretKey};

    use super::{chain_from_tip, ensure_catchup_boundary, map_commitments, validate_commitment};
    use crate::error::PreconfirmationClientError;

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

    #[tokio::test]
    async fn validate_commitment_accepts_valid() {
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let secp = Secp256k1::new();
        let pk = PublicKey::from_secret_key(&secp, &sk);
        let signer = public_key_to_address(&pk);
        let resolver = MockResolver { signer, submission_window_end: U256::from(1000u64) };

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let commitment = make_commitment(1, parent_hash, 1000, 10, &sk);

        let result = validate_commitment(&commitment, None, &resolver).await;
        assert!(result.is_some());
    }

    #[tokio::test]
    async fn validate_commitment_rejects_wrong_signer() {
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let resolver = MockResolver {
            signer: Address::repeat_byte(0x42),
            submission_window_end: U256::from(1000u64),
        };

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let commitment = make_commitment(1, parent_hash, 1000, 10, &sk);

        let result = validate_commitment(&commitment, None, &resolver).await;
        assert!(result.is_none());
    }

    #[tokio::test]
    async fn validate_commitment_accepts_genesis() {
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let secp = Secp256k1::new();
        let pk = PublicKey::from_secret_key(&secp, &sk);
        let signer = public_key_to_address(&pk);
        let resolver = MockResolver { signer, submission_window_end: U256::from(1000u64) };

        let zero_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero hash");
        let commitment = make_commitment(0, zero_hash, 1000, 10, &sk);

        let result = validate_commitment(&commitment, None, &resolver).await;
        assert!(result.is_some());
    }

    #[test]
    fn catchup_boundary_mismatch_returns_error() {
        let stop_block = U256::from(10u64);
        let boundary_block = Some(U256::from(9u64));

        let err = ensure_catchup_boundary(stop_block, boundary_block).expect_err("must error");
        assert!(err.to_string().contains("catch-up chain did not reach"));
    }

    #[test]
    fn empty_catchup_chain_returns_error() {
        let err = PreconfirmationClientError::Catchup(
            "no valid commitments found during catch-up".to_string(),
        );
        assert!(err.to_string().contains("no valid commitments found"));
    }

    #[tokio::test]
    async fn chain_from_tip_follows_parent_hashes() {
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let secp = Secp256k1::new();
        let pk = PublicKey::from_secret_key(&secp, &sk);
        let signer = public_key_to_address(&pk);
        let resolver = MockResolver { signer, submission_window_end: U256::from(1000u64) };

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let block1 = make_commitment(1, parent_hash, 1000, 10, &sk);
        let hash1 = preconfirmation_hash(&block1.commitment.preconf).expect("hash block1");
        let block2_parent = Bytes32::try_from(hash1.as_slice().to_vec()).expect("hash length 32");
        let block2 = make_commitment(2, block2_parent, 1000, 20, &sk);
        let hash2 = preconfirmation_hash(&block2.commitment.preconf).expect("hash block2");
        let block3_parent = Bytes32::try_from(hash2.as_slice().to_vec()).expect("hash length 32");
        let tip = make_commitment(3, block3_parent, 1000, 30, &sk);

        let map = map_commitments(vec![block1.clone(), block2.clone()]);
        let chain = chain_from_tip(tip, &map, U256::ONE, None, &resolver).await;

        assert_eq!(chain.len(), 3);
        assert_eq!(uint256_to_u256(&chain[0].commitment.preconf.block_number), U256::from(3));
        assert_eq!(uint256_to_u256(&chain[2].commitment.preconf.block_number), U256::ONE);
    }
}
