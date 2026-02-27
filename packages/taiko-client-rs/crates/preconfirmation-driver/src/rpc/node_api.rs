//! RPC API implementation backed by the preconfirmation driver node state.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{
    Bytes20, Bytes32, RawTxListGossip, SignedCommitment, TxListBytes, keccak256_bytes,
    uint256_to_u256,
};
use protocol::codec::ZlibTxListCodec;
use ssz_rs::Deserialize;
use tokio::sync::{mpsc, watch};

use crate::{
    Result,
    driver_interface::{DriverClient, InboxReader, PreconfirmationInput},
    error::PreconfirmationClientError,
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

/// Query the P2P network for the current peer count, returning 0 if the command channel is closed.
async fn query_peer_count(command_tx: &mpsc::Sender<NetworkCommand>) -> u64 {
    let (tx, rx) = tokio::sync::oneshot::channel();
    if command_tx.send(NetworkCommand::GetPeerCount { respond_to: tx }).await.is_err() {
        return 0;
    }

    rx.await.unwrap_or(0)
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
/// 8. Gossip to P2P (parallel, propagate failures)
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
        .map_err(|e| PreconfirmationClientError::Validation(format!("invalid commitment SSZ: {e}")))?;

    // 2a. Validate txlist hash matches the provided bytes.
    let raw_tx_list = TxListBytes::try_from(request.tx_list.to_vec())
        .map_err(|_| PreconfirmationClientError::Validation("txlist too large".into()))?;
    let calculated_hash = keccak256_bytes(&raw_tx_list);
    if calculated_hash != request.tx_list_hash {
        return Err(PreconfirmationClientError::Validation(format!(
            "tx_list_hash mismatch: expected {}, got {}",
            request.tx_list_hash, calculated_hash
        )));
    }

    // 2b. Validate that the commitment's embedded raw_tx_list_hash matches for non-EOP commitments.
    let is_eop_only = is_eop_only(&signed_commitment);
    if !is_eop_only {
        let embedded_hash =
            B256::from_slice(signed_commitment.commitment.preconf.raw_tx_list_hash.as_slice());
        if embedded_hash != calculated_hash {
            return Err(PreconfirmationClientError::Validation(format!(
                "commitment raw_tx_list_hash mismatch: commitment contains {}, txlist hashes to {}",
                embedded_hash, calculated_hash
            )));
        }
    }

    // 3. Validate commitment signature + recover signer.
    let signer = validate_commitment_with_signer(&signed_commitment, expected_slasher)?;

    // 4. Validate lookahead.
    let timestamp = uint256_to_u256(&signed_commitment.commitment.preconf.timestamp);
    let slot_info = lookahead_resolver
        .slot_info_for_timestamp(timestamp)
        .await
        .map_err(PreconfirmationClientError::from)?;
    validate_lookahead(&signed_commitment, signer, &slot_info)?;

    // 5. Reject stale commitments whose block is already covered by confirmed sync.
    let current_block = uint256_to_u256(&signed_commitment.commitment.preconf.block_number);
    let event_sync_tip = driver.event_sync_tip().await?;
    if current_block <= event_sync_tip {
        return Err(PreconfirmationClientError::Validation(format!(
            "stale commitment: block {} <= event_sync_tip {}",
            current_block, event_sync_tip
        )));
    }

    // 6. Build PreconfirmationInput.
    let input = if is_eop_only {
        PreconfirmationInput::new(signed_commitment.clone(), None, None)
    } else {
        let transactions = codec
            .decode(raw_tx_list.as_ref())
            .map_err(|e| PreconfirmationClientError::Codec(e.to_string()))?;
        PreconfirmationInput::new(
            signed_commitment.clone(),
            Some(transactions),
            Some(raw_tx_list.to_vec()),
        )
    };

    // 7. Submit to driver — mine the block.
    driver.submit_preconfirmation(input).await?;

    // 8. Gossip to P2P (parallel, propagate failures).
    // Note: these gossip sends run after submission; if one fails, the block may
    // already be mined and accepted. Retrying can therefore submit the same input again.
    let commitment_hash = keccak256_bytes(request.commitment.as_ref());
    let raw_tx_list_hash =
        Bytes32::try_from(calculated_hash.0.to_vec()).expect("keccak256 always produces 32 bytes");
    let gossip = RawTxListGossip { raw_tx_list_hash, txlist: raw_tx_list };
    let (r1, r2) = tokio::join!(
        command_tx.send(NetworkCommand::PublishCommitment(signed_commitment)),
        command_tx.send(NetworkCommand::PublishRawTxList(gossip)),
    );
    r1.map_err(|e| PreconfirmationClientError::Network(format!("gossip commitment failed: {e}")))?;
    r2.map_err(|e| PreconfirmationClientError::Network(format!("gossip txlist failed: {e}")))?;

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
        async fn submit_preconfirmation(
            &self,
            _: PreconfirmationInput,
        ) -> Result<()> {
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

    /// Test that NodeRpcApiImpl returns correct status with peer_id.
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

        // Spawn a handler to respond to GetPeerCount command
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

    /// Test that get_preconf_slot_info delegates to the lookahead resolver and maps the result.
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

        let timestamp = U256::from(500);
        let slot_info = api.get_preconf_slot_info(timestamp).await.unwrap();

        assert_eq!(slot_info.signer, alloy_primitives::Address::repeat_byte(0x11));
        assert_eq!(slot_info.submission_window_end, U256::from(2000));
    }

    /// Test that publish_block_impl rejects tx_list_hash mismatch.
    #[tokio::test]
    async fn test_publish_block_rejects_hash_mismatch() {
        let (command_tx, _command_rx) = mpsc::channel::<NetworkCommand>(16);
        let driver = StubDriver;
        let codec = ZlibTxListCodec::new(preconfirmation_types::MAX_TXLIST_BYTES);

        // Build a minimal valid SSZ-encoded SignedCommitment.
        let commitment = SignedCommitment::default();
        let mut commitment_bytes = Vec::new();
        ssz_rs::Serialize::serialize(&commitment, &mut commitment_bytes)
            .expect("serialize commitment");

        let request = PublishBlockRequest {
            commitment: alloy_primitives::Bytes::from(commitment_bytes),
            tx_list_hash: B256::ZERO, // wrong hash
            tx_list: alloy_primitives::Bytes::from(vec![1u8, 2u8, 3u8]),
        };

        let result = publish_block_impl(
            &command_tx,
            &driver,
            &codec,
            None,
            &MockLookaheadResolver,
            request,
        )
        .await;

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("tx_list_hash mismatch"));
    }

    /// Test that publish_block_impl rejects when commitment's embedded raw_tx_list_hash
    /// differs from the provided txlist.
    #[tokio::test]
    async fn test_publish_block_rejects_commitment_hash_mismatch() {
        let (command_tx, _command_rx) = mpsc::channel::<NetworkCommand>(16);
        let driver = StubDriver;
        let codec = ZlibTxListCodec::new(preconfirmation_types::MAX_TXLIST_BYTES);

        // Build a commitment with a non-zero raw_tx_list_hash that won't match the txlist.
        let mut commitment = SignedCommitment::default();
        commitment.commitment.preconf.raw_tx_list_hash =
            preconfirmation_types::Bytes32::try_from(vec![0xAAu8; 32]).unwrap();
        let mut commitment_bytes = Vec::new();
        ssz_rs::Serialize::serialize(&commitment, &mut commitment_bytes)
            .expect("serialize commitment");

        // Provide a txlist whose hash matches tx_list_hash but NOT the commitment.
        let tx_list = alloy_primitives::Bytes::from(vec![1u8, 2u8, 3u8]);
        let tx_list_hash = keccak256_bytes(tx_list.as_ref());

        let request = PublishBlockRequest {
            commitment: alloy_primitives::Bytes::from(commitment_bytes),
            tx_list_hash,
            tx_list,
        };

        let result = publish_block_impl(
            &command_tx,
            &driver,
            &codec,
            None,
            &MockLookaheadResolver,
            request,
        )
        .await;

        assert!(result.is_err());
        assert!(
            result.unwrap_err().to_string().contains("commitment raw_tx_list_hash mismatch"),
        );
    }

    /// Test that EOP-only commitments with zero raw_tx_list_hash can be submitted.
    #[tokio::test]
    async fn test_publish_block_accepts_eop_only_commitment() {
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);
        let driver = StubDriver;
        let codec = ZlibTxListCodec::new(preconfirmation_types::MAX_TXLIST_BYTES);

        let tx_list = alloy_primitives::Bytes::from(vec![1u8, 2u8, 3u8]);
        let tx_list_hash = keccak256_bytes(tx_list.as_ref());

        let mut commitment = SignedCommitment::default();
        commitment.commitment.preconf.eop = true;
        commitment.commitment.preconf.block_number = preconfirmation_types::Uint256::from(1u64);
        commitment.commitment.preconf.timestamp = preconfirmation_types::Uint256::from(42u64);
        commitment.commitment.preconf.submission_window_end =
            preconfirmation_types::Uint256::from(2000u64);
        commitment.commitment.preconf.raw_tx_list_hash =
            preconfirmation_types::Bytes32::try_from(vec![0u8; 32]).unwrap();

        let secret_key = secp256k1::SecretKey::from_slice(&[42u8; 32])
            .expect("valid deterministic test secret key");
        let signer = {
            let secp = secp256k1::Secp256k1::new();
            preconfirmation_types::public_key_to_address(&secp256k1::PublicKey::from_secret_key(
                &secp,
                &secret_key,
            ))
        };
        commitment.signature =
            preconfirmation_types::sign_commitment(&commitment.commitment, &secret_key)
                .expect("valid test signature");

        let mut commitment_bytes = Vec::new();
        ssz_rs::Serialize::serialize(&commitment, &mut commitment_bytes)
            .expect("serialize commitment");

        // Consume gossip commands sent by publish_block_impl so `send` does not fail.
        tokio::spawn(async move {
            while command_rx.recv().await.is_some() {}
        });

        struct TestResolver(alloy_primitives::Address);

        #[async_trait::async_trait]
        impl protocol::preconfirmation::PreconfSignerResolver for TestResolver {
            async fn signer_for_timestamp(
                &self,
                _timestamp: U256,
            ) -> protocol::preconfirmation::Result<alloy_primitives::Address> {
                Ok(self.0)
            }

            async fn slot_info_for_timestamp(
                &self,
                _timestamp: U256,
            ) -> protocol::preconfirmation::Result<protocol::preconfirmation::PreconfSlotInfo> {
                Ok(protocol::preconfirmation::PreconfSlotInfo {
                    signer: self.0,
                    submission_window_end: U256::from(2000),
                })
            }
        }

        let request = PublishBlockRequest {
            commitment: alloy_primitives::Bytes::from(commitment_bytes),
            tx_list_hash,
            tx_list,
        };

        let result = publish_block_impl(
            &command_tx,
            &driver,
            &codec,
            None,
            &TestResolver(signer),
            request,
        )
        .await;

        assert!(result.is_ok());
    }
}
