//! Shared helpers backing the preconfirmation RPC API implementation.

use alloy_primitives::{B256, U256};
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{
    Bytes20, RawTxListGossip, SignedCommitment, TxListBytes, b256_to_bytes32, keccak256_bytes,
    uint256_to_u256,
};
use protocol::codec::ZlibTxListCodec;
use ssz_rs::Deserialize;
use tokio::sync::mpsc;
use tracing::{info, warn};

use crate::{
    Result,
    driver_interface::{DriverClient, InboxReader, PreconfirmationInput},
    error::{PreconfirmationClientError, ValidationErrorCode},
    metrics::PreconfirmationClientMetrics,
    rpc::{NodeStatus, PublishBlockRequest, PublishBlockResponse},
    validation::{is_eop_only, validate_commitment_with_signer, validate_lookahead},
};

/// Increment the counter tracking rejected preconfirmation inputs.
fn record_validation_failure() {
    PreconfirmationClientMetrics::validation_failures_total().inc();
}

/// Query the P2P network for the current peer count.
///
/// Returns 0 and logs a warning if the command channel is closed.
async fn query_peer_count(command_tx: &mpsc::Sender<NetworkCommand>) -> u64 {
    let (tx, rx) = tokio::sync::oneshot::channel();
    if command_tx.send(NetworkCommand::GetPeerCount { respond_to: tx }).await.is_err() {
        warn!("peer count query failed: P2P command channel closed");
        return 0;
    }
    rx.await.unwrap_or_else(|_| {
        warn!("peer count query failed: response channel dropped");
        0
    })
}

/// Validate, mine, and gossip a preconfirmation block atomically.
///
/// 1. SSZ-decode the commitment
/// 2. Validate txlist hash (request + commitment consistency)
/// 3. Validate commitment signature + recover signer
/// 4. Validate lookahead
/// 5. Reject stale commitments (block_number <= event_sync_tip)
/// 6. Build `PreconfirmationInput`
/// 7. Submit to driver (mine the block)
/// 8. Gossip to P2P (sequential, best-effort after successful mine)
pub(crate) async fn publish_block_impl(
    command_tx: &mpsc::Sender<NetworkCommand>,
    driver: &dyn DriverClient,
    codec: &ZlibTxListCodec,
    expected_slasher: Option<&Bytes20>,
    lookahead_resolver: &(dyn protocol::preconfirmation::PreconfSignerResolver + Send + Sync),
    request: PublishBlockRequest,
) -> Result<PublishBlockResponse> {
    // 1. SSZ-decode the commitment.
    let signed_commitment = SignedCommitment::deserialize(request.commitment.as_ref())
        .inspect_err(|_| {
            record_validation_failure();
        })
        .map_err(|e| {
            PreconfirmationClientError::Validation(format!("invalid commitment SSZ: {e}"))
        })?;

    // 2a. Validate txlist hash matches the provided bytes.
    let raw_tx_list = TxListBytes::try_from(request.tx_list.to_vec()).map_err(|_| {
        record_validation_failure();
        PreconfirmationClientError::Validation("txlist too large".into())
    })?;
    let calculated_hash = keccak256_bytes(&raw_tx_list);
    if calculated_hash != request.tx_list_hash {
        record_validation_failure();
        return Err(PreconfirmationClientError::Validation(format!(
            "tx_list_hash mismatch: expected {}, got {}",
            request.tx_list_hash, calculated_hash
        )));
    }

    // 2b. Validate that the commitment's embedded raw_tx_list_hash matches for non-EOP.
    let eop_only = is_eop_only(&signed_commitment);
    if !eop_only {
        let embedded_hash =
            B256::from_slice(signed_commitment.commitment.preconf.raw_tx_list_hash.as_slice());
        if embedded_hash != calculated_hash {
            record_validation_failure();
            return Err(PreconfirmationClientError::Validation(format!(
                "commitment raw_tx_list_hash mismatch: commitment contains {}, txlist hashes to {}",
                embedded_hash, calculated_hash
            )));
        }
    }

    // 3. Validate commitment signature + recover signer.
    let signer = validate_commitment_with_signer(&signed_commitment, expected_slasher)
        .inspect_err(|_| {
            record_validation_failure();
        })?;

    log_publish_block_entry(&signed_commitment, signer, request.tx_list_hash);

    // 4. Validate lookahead.
    let timestamp = uint256_to_u256(&signed_commitment.commitment.preconf.timestamp);
    let slot_info = lookahead_resolver
        .slot_info_for_timestamp(timestamp)
        .await
        .map_err(PreconfirmationClientError::from)?;
    validate_lookahead(&signed_commitment, signer, &slot_info).inspect_err(|_| {
        record_validation_failure();
    })?;

    // 5. Reject stale commitments whose block is already covered by confirmed sync.
    let current_block = uint256_to_u256(&signed_commitment.commitment.preconf.block_number);
    let event_sync_tip = driver.event_sync_tip().await?;
    if current_block <= event_sync_tip {
        record_validation_failure();
        return Err(PreconfirmationClientError::validation_error(
            ValidationErrorCode::StaleCommitment,
            format!(
                "stale commitment: block {} <= event_sync_tip {}",
                current_block, event_sync_tip
            ),
        ));
    }

    // 6. Build PreconfirmationInput.
    let input = if eop_only {
        PreconfirmationInput::new(signed_commitment.clone(), None, None)
    } else {
        let transactions = codec.decode(raw_tx_list.as_ref()).map_err(|e| {
            record_validation_failure();
            PreconfirmationClientError::Codec(e.to_string())
        })?;
        PreconfirmationInput::new(
            signed_commitment.clone(),
            Some(transactions),
            Some(raw_tx_list.to_vec()),
        )
    };

    // 7. Submit to driver and gossip to P2P in parallel.
    let commitment_hash = keccak256_bytes(request.commitment.as_ref());
    let raw_tx_list_hash = b256_to_bytes32(calculated_hash);
    let raw_tx_list_for_gossip = raw_tx_list.clone();
    let command_tx_for_commitment = command_tx.clone();
    let command_tx_for_txlist = command_tx.clone();

    let commitment_gossip = async move {
        command_tx_for_commitment
            .send(NetworkCommand::PublishCommitment(signed_commitment))
            .await
            .map_err(|e| {
                warn!(error = %e, "gossip commitment failed");
                PreconfirmationClientError::Network(format!("failed to publish commitment: {e}"))
            })
    };

    let txlist_gossip = async move {
        if eop_only {
            // Skip txlist gossip for EOP-only commitments — there is no meaningful
            // txlist to broadcast and no follower will match the zero hash.
            return Ok(());
        }

        let gossip = RawTxListGossip { raw_tx_list_hash, txlist: raw_tx_list_for_gossip };
        command_tx_for_txlist.send(NetworkCommand::PublishRawTxList(gossip)).await.map_err(|e| {
            warn!(error = %e, "gossip txlist failed");
            PreconfirmationClientError::Network(format!("failed to publish txlist: {e}"))
        })
    };

    let driver_submit = async {
        // 7a. Submit to driver — mine the block.
        driver.submit_preconfirmation(input).await.inspect_err(|_| {
            PreconfirmationClientMetrics::driver_submit_failure_total().inc();
        })?;
        PreconfirmationClientMetrics::driver_submit_success_total().inc();
        Ok(())
    };

    tokio::try_join!(driver_submit, commitment_gossip, txlist_gossip)?;

    Ok(PublishBlockResponse { commitment_hash, tx_list_hash: calculated_hash })
}

/// Emit an entry log for a preconfirmation JSON-RPC block publish request.
fn log_publish_block_entry(
    commitment: &SignedCommitment,
    signer: alloy_primitives::Address,
    tx_list_hash: B256,
) {
    let preconf = &commitment.commitment.preconf;
    info!(
        block_id = %uint256_to_u256(&preconf.block_number),
        signer = %signer,
        timestamp = %uint256_to_u256(&preconf.timestamp),
        submission_window_end = %uint256_to_u256(&preconf.submission_window_end),
        raw_tx_list_hash = %B256::from_slice(preconf.raw_tx_list_hash.as_ref()),
        request_tx_list_hash = %tx_list_hash,
        eop = preconf.eop,
        "🏗️ New preconfirmation block publish request"
    );
}

/// Build a NodeStatus by querying peer count and computing sync state.
pub(crate) async fn build_node_status<I: InboxReader>(
    command_tx: &mpsc::Sender<NetworkCommand>,
    inbox_reader: &I,
    preconf_tip: U256,
    local_peer_id: &str,
) -> Result<NodeStatus> {
    let confirmed_sync = inbox_reader.confirmed_sync_snapshot().await?;
    let peer_count = query_peer_count(command_tx).await;

    Ok(NodeStatus {
        is_synced_with_inbox: confirmed_sync.is_ready(),
        event_sync_tip: confirmed_sync.event_sync_tip().map(U256::from),
        preconf_tip,
        peer_count,
        peer_id: local_peer_id.to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Mock lookahead resolver for testing.
    struct MockLookaheadResolver;

    #[async_trait::async_trait]
    impl protocol::preconfirmation::PreconfSignerResolver for MockLookaheadResolver {
        async fn signer_for_timestamp(
            &self,
            _: U256,
        ) -> protocol::preconfirmation::Result<alloy_primitives::Address> {
            Ok(alloy_primitives::Address::repeat_byte(0x11))
        }
        async fn slot_info_for_timestamp(
            &self,
            _: U256,
        ) -> protocol::preconfirmation::Result<protocol::preconfirmation::PreconfSlotInfo> {
            Ok(protocol::preconfirmation::PreconfSlotInfo {
                signer: alloy_primitives::Address::repeat_byte(0x11),
                submission_window_end: U256::from(2000),
            })
        }
    }

    /// Stub driver that accepts everything and keeps tip at zero.
    struct StubDriver;
    #[async_trait::async_trait]
    impl DriverClient for StubDriver {
        async fn submit_preconfirmation(&self, _: PreconfirmationInput) -> Result<()> {
            Ok(())
        }
        async fn wait_event_sync(&self) -> Result<()> {
            Ok(())
        }
        async fn event_sync_tip(&self) -> Result<U256> {
            Ok(U256::ZERO)
        }
        async fn preconf_tip(&self) -> Result<U256> {
            Ok(U256::ZERO)
        }
    }

    #[tokio::test]
    async fn test_publish_block_rejects_hash_mismatch() {
        let (command_tx, _command_rx) = mpsc::channel::<NetworkCommand>(16);
        let driver = StubDriver;
        let codec = ZlibTxListCodec::new(preconfirmation_types::MAX_TXLIST_BYTES);

        let commitment = SignedCommitment::default();
        let mut commitment_bytes = Vec::new();
        ssz_rs::Serialize::serialize(&commitment, &mut commitment_bytes)
            .expect("serialize commitment");

        let request = PublishBlockRequest {
            commitment: alloy_primitives::Bytes::from(commitment_bytes),
            tx_list_hash: B256::ZERO,
            tx_list: alloy_primitives::Bytes::from(vec![1u8, 2u8, 3u8]),
        };

        let result =
            publish_block_impl(&command_tx, &driver, &codec, None, &MockLookaheadResolver, request)
                .await;

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("tx_list_hash mismatch"));
    }

    #[tokio::test]
    async fn test_publish_block_rejects_commitment_hash_mismatch() {
        let (command_tx, _command_rx) = mpsc::channel::<NetworkCommand>(16);
        let driver = StubDriver;
        let codec = ZlibTxListCodec::new(preconfirmation_types::MAX_TXLIST_BYTES);

        let mut commitment = SignedCommitment::default();
        commitment.commitment.preconf.raw_tx_list_hash =
            preconfirmation_types::Bytes32::try_from(vec![0xAAu8; 32]).unwrap();
        let mut commitment_bytes = Vec::new();
        ssz_rs::Serialize::serialize(&commitment, &mut commitment_bytes)
            .expect("serialize commitment");

        let tx_list = alloy_primitives::Bytes::from(vec![1u8, 2u8, 3u8]);
        let tx_list_hash = keccak256_bytes(tx_list.as_ref());

        let request = PublishBlockRequest {
            commitment: alloy_primitives::Bytes::from(commitment_bytes),
            tx_list_hash,
            tx_list,
        };

        let result =
            publish_block_impl(&command_tx, &driver, &codec, None, &MockLookaheadResolver, request)
                .await;

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("commitment raw_tx_list_hash mismatch"));
    }
}
