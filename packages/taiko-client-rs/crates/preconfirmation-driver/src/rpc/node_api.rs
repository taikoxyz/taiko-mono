//! RPC API implementation backed by the preconfirmation driver node state.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{
    Bytes20, RawTxListGossip, SignedCommitment, TxListBytes, keccak256_bytes,
    b256_to_bytes32, uint256_to_u256,
};
use protocol::codec::ZlibTxListCodec;
use ssz_rs::Deserialize;
use tokio::sync::{mpsc, watch};
use tracing::warn;

use crate::{
    Result,
    driver_interface::{DriverClient, InboxReader, PreconfirmationInput},
    error::PreconfirmationClientError,
    metrics::PreconfirmationClientMetrics,
    rpc::{
        NodeStatus, PreconfRpcApi, PreconfSlotInfo, PublishBlockRequest, PublishBlockResponse,
    },
    validation::{is_eop_only, validate_commitment_with_signer, validate_lookahead},
};

/// Internal RPC API implementation backed by the preconfirmation driver node state.
pub(crate) struct NodeRpcApiImpl<I: InboxReader, D: DriverClient> {
    /// Command tx for issuing commands to the P2P network layer.
    pub(crate) command_tx: mpsc::Sender<NetworkCommand>,
    /// Watch receiver for the preconfirmation tip.
    pub(crate) preconf_tip_rx: watch::Receiver<U256>,
    /// Inbox reader for checking L1 sync state.
    pub(crate) inbox_reader: I,
    /// Lookahead resolver for slot info by timestamp.
    pub(crate) lookahead_resolver:
        Arc<dyn protocol::preconfirmation::PreconfSignerResolver + Send + Sync>,
    /// Driver client for submitting preconfirmation inputs.
    pub(crate) driver: Arc<D>,
    /// Txlist codec for decompression.
    pub(crate) codec: Arc<ZlibTxListCodec>,
    /// Expected slasher address for commitment validation.
    pub(crate) expected_slasher: Option<Bytes20>,
    /// Local peer ID string used in status responses.
    pub(crate) local_peer_id: String,
}

#[async_trait::async_trait]
impl<I: InboxReader + 'static, D: DriverClient + 'static> PreconfRpcApi for NodeRpcApiImpl<I, D> {
    async fn publish_block(&self, request: PublishBlockRequest) -> Result<PublishBlockResponse> {
        publish_block_impl(
            &self.command_tx,
            self.driver.as_ref(),
            &self.codec,
            self.expected_slasher.as_ref(),
            self.lookahead_resolver.as_ref(),
            request,
        )
        .await
    }

    async fn get_status(&self) -> Result<NodeStatus> {
        let preconf_tip = *self.preconf_tip_rx.borrow();
        build_node_status(&self.command_tx, &self.inbox_reader, preconf_tip, &self.local_peer_id)
            .await
    }

    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip_rx.borrow())
    }

    async fn get_preconf_slot_info(&self, timestamp: U256) -> Result<PreconfSlotInfo> {
        self.lookahead_resolver
            .slot_info_for_timestamp(timestamp)
            .await
            .map(PreconfSlotInfo::from)
            .map_err(Into::into)
    }
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
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
        })
        .map_err(|e| PreconfirmationClientError::Validation(format!("invalid commitment SSZ: {e}")))?;

    // 2a. Validate txlist hash matches the provided bytes.
    let raw_tx_list = TxListBytes::try_from(request.tx_list.to_vec()).map_err(|_| {
        metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
        PreconfirmationClientError::Validation("txlist too large".into())
    })?;
    let calculated_hash = keccak256_bytes(&raw_tx_list);
    if calculated_hash != request.tx_list_hash {
        metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
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
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL)
                .increment(1);
            return Err(PreconfirmationClientError::Validation(format!(
                "commitment raw_tx_list_hash mismatch: commitment contains {}, txlist hashes to {}",
                embedded_hash, calculated_hash
            )));
        }
    }

    // 3. Validate commitment signature + recover signer.
    let signer = validate_commitment_with_signer(&signed_commitment, expected_slasher)
        .inspect_err(|_| {
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL)
                .increment(1);
        })
        ?;

    // 4. Validate lookahead.
    let timestamp = uint256_to_u256(&signed_commitment.commitment.preconf.timestamp);
    let slot_info = lookahead_resolver
        .slot_info_for_timestamp(timestamp)
        .await
        .map_err(PreconfirmationClientError::from)?;
    validate_lookahead(&signed_commitment, signer, &slot_info)
        .inspect_err(|_| {
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
        })
        ?;

    // 5. Reject stale commitments whose block is already covered by confirmed sync.
    let current_block = uint256_to_u256(&signed_commitment.commitment.preconf.block_number);
    let event_sync_tip = driver.event_sync_tip().await?;
    if current_block <= event_sync_tip {
        metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
        return Err(PreconfirmationClientError::Validation(format!(
            "stale commitment: block {} <= event_sync_tip {}",
            current_block, event_sync_tip
        )));
    }

    // 6. Build PreconfirmationInput.
    let input = if eop_only {
        PreconfirmationInput::new(signed_commitment.clone(), None, None)
    } else {
        let transactions = codec.decode(raw_tx_list.as_ref()).map_err(|e| {
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL)
                .increment(1);
            PreconfirmationClientError::Codec(e.to_string())
        })?;
        PreconfirmationInput::new(
            signed_commitment.clone(),
            Some(transactions),
            Some(raw_tx_list.to_vec()),
        )
    };

    // 7. Submit to driver — mine the block.
    driver
        .submit_preconfirmation(input)
        .await
        .inspect_err(|_| {
            metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_FAILURE_TOTAL)
                .increment(1);
        })?;
    metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_SUCCESS_TOTAL).increment(1);

    // 8. Gossip to P2P (sequential, best-effort after successful mine).
    //
    // The block is already mined at this point. Gossip failures are logged
    // but do not fail the RPC — returning an error after a successful mine
    // would cause callers to retry and produce duplicate driver submissions.
    let commitment_hash = keccak256_bytes(request.commitment.as_ref());

    if let Err(e) = command_tx
        .send(NetworkCommand::PublishCommitment(signed_commitment))
        .await
    {
        warn!(error = %e, "gossip commitment failed after successful mine");
    }

    // Skip txlist gossip for EOP-only commitments — there is no meaningful
    // txlist to broadcast and no follower will match the zero hash.
    if !eop_only {
        let raw_tx_list_hash = b256_to_bytes32(calculated_hash);
        let gossip = RawTxListGossip { raw_tx_list_hash, txlist: raw_tx_list };
        if let Err(e) = command_tx.send(NetworkCommand::PublishRawTxList(gossip)).await {
            warn!(error = %e, "gossip txlist failed after successful mine");
        }
    }

    Ok(PublishBlockResponse { commitment_hash, tx_list_hash: calculated_hash })
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
    use std::sync::atomic::{AtomicU64, Ordering};

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

    /// Mock inbox reader for testing.
    #[derive(Clone)]
    struct MockInboxReader {
        next_proposal_id: std::sync::Arc<AtomicU64>,
        target_block: std::sync::Arc<AtomicU64>,
        head_l1_origin_block_id: std::sync::Arc<AtomicU64>,
    }

    const NONE_SENTINEL: u64 = u64::MAX;

    impl MockInboxReader {
        fn new(
            next_proposal_id: u64,
            target_block: Option<u64>,
            head_l1_origin: Option<u64>,
        ) -> Self {
            Self {
                next_proposal_id: std::sync::Arc::new(AtomicU64::new(next_proposal_id)),
                target_block: std::sync::Arc::new(AtomicU64::new(
                    target_block.unwrap_or(NONE_SENTINEL),
                )),
                head_l1_origin_block_id: std::sync::Arc::new(AtomicU64::new(
                    head_l1_origin.unwrap_or(NONE_SENTINEL),
                )),
            }
        }

        fn read_optional(value: u64) -> Option<u64> {
            (value != NONE_SENTINEL).then_some(value)
        }
    }

    #[async_trait::async_trait]
    impl InboxReader for MockInboxReader {
        async fn get_next_proposal_id(&self) -> Result<u64> {
            Ok(self.next_proposal_id.load(Ordering::SeqCst))
        }

        async fn get_last_block_id_by_batch_id(&self, _proposal_id: u64) -> Result<Option<u64>> {
            Ok(Self::read_optional(self.target_block.load(Ordering::SeqCst)))
        }

        async fn get_head_l1_origin_block_id(&self) -> Result<Option<u64>> {
            Ok(Self::read_optional(self.head_l1_origin_block_id.load(Ordering::SeqCst)))
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
    async fn test_node_status_includes_peer_id() {
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::from(100));
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);
        let local_peer_id = "test-peer-id".to_string();

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            inbox_reader: MockInboxReader::new(43, Some(120), Some(120)),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
            driver: Arc::new(StubDriver),
            codec: Arc::new(ZlibTxListCodec::new(preconfirmation_types::MAX_TXLIST_BYTES)),
            expected_slasher: None,
            local_peer_id: local_peer_id.clone(),
        };

        tokio::spawn(async move {
            if let Some(NetworkCommand::GetPeerCount { respond_to }) = command_rx.recv().await {
                let _ = respond_to.send(5);
            }
        });

        let status = api.get_status().await.unwrap();
        assert_eq!(status.peer_id, local_peer_id);
        assert_eq!(status.peer_count, 5);
        assert!(status.is_synced_with_inbox);
        assert_eq!(status.event_sync_tip, Some(U256::from(120)));
    }

    #[tokio::test]
    async fn test_get_preconf_slot_info_returns_resolver_output() {
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
            driver: Arc::new(StubDriver),
            codec: Arc::new(ZlibTxListCodec::new(preconfirmation_types::MAX_TXLIST_BYTES)),
            expected_slasher: None,
            local_peer_id: "test".to_string(),
        };

        tokio::spawn(async move { while command_rx.recv().await.is_some() {} });

        let slot_info = api.get_preconf_slot_info(U256::from(500)).await.unwrap();
        assert_eq!(slot_info.signer, alloy_primitives::Address::repeat_byte(0x11));
        assert_eq!(slot_info.submission_window_end, U256::from(2000));
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

        let result = publish_block_impl(
            &command_tx, &driver, &codec, None, &MockLookaheadResolver, request,
        )
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

        let result = publish_block_impl(
            &command_tx, &driver, &codec, None, &MockLookaheadResolver, request,
        )
        .await;

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("commitment raw_tx_list_hash mismatch"));
    }
}
