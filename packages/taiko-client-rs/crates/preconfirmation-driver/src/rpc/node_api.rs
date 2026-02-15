//! RPC API implementation backed by the preconfirmation driver node state.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{Bytes32, RawTxListGossip, SignedCommitment, TxListBytes};
use ssz_rs::Deserialize;
use tokio::sync::{mpsc, watch};

use crate::{
    Result,
    driver_interface::InboxReader,
    error::PreconfirmationClientError,
    rpc::{
        NodeStatus, PreconfRpcApi, PreconfSlotInfo, PublishCommitmentRequest,
        PublishCommitmentResponse, PublishTxListRequest, PublishTxListResponse,
    },
};

/// Internal RPC API implementation backed by the preconfirmation driver node state.
pub(crate) struct NodeRpcApiImpl<I: InboxReader> {
    /// Command tx for issuing commands to the P2P network layer.
    pub(crate) command_tx: mpsc::Sender<NetworkCommand>,
    /// Watch receiver for the preconfirmation tip.
    pub(crate) preconf_tip_rx: watch::Receiver<U256>,
    /// Local peer ID string for status responses.
    pub(crate) local_peer_id: String,
    /// Inbox reader for checking L1 sync state.
    pub(crate) inbox_reader: I,
    /// Lookahead resolver for slot info by timestamp.
    pub(crate) lookahead_resolver:
        Arc<dyn protocol::preconfirmation::PreconfSignerResolver + Send + Sync>,
}

#[async_trait::async_trait]
impl<I: InboxReader + 'static> PreconfRpcApi for NodeRpcApiImpl<I> {
    /// Publishes a signed commitment to the P2P network.
    ///
    /// Decodes the SSZ-encoded commitment, extracts the tx_list_hash, and broadcasts
    /// via the P2P gossip network.
    async fn publish_commitment(
        &self,
        request: PublishCommitmentRequest,
    ) -> Result<PublishCommitmentResponse> {
        publish_commitment_impl(&self.command_tx, request).await
    }

    /// Publishes a transaction list to the P2P network.
    ///
    /// Verifies the hash matches the provided encoded tx list and broadcasts via P2P gossip.
    async fn publish_tx_list(
        &self,
        request: PublishTxListRequest,
    ) -> Result<PublishTxListResponse> {
        publish_tx_list_impl(&self.command_tx, request).await
    }

    /// Returns the current status of the preconfirmation driver node.
    ///
    /// Queries the P2P layer for peer count and returns sync state information.
    async fn get_status(&self) -> Result<NodeStatus> {
        let preconf_tip = *self.preconf_tip_rx.borrow();

        build_node_status(&self.command_tx, &self.inbox_reader, preconf_tip, &self.local_peer_id)
            .await
    }

    /// Returns the current preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip_rx.borrow())
    }

    /// Returns the preconfirmation slot info (signer and submission window end) for the given L2
    /// block timestamp.
    async fn get_preconf_slot_info(&self, timestamp: U256) -> Result<PreconfSlotInfo> {
        let info = self.lookahead_resolver.slot_info_for_timestamp(timestamp).await?;
        Ok(PreconfSlotInfo {
            signer: info.signer,
            submission_window_end: info.submission_window_end,
        })
    }
}

/// Publish a signed commitment via the P2P network command channel.
pub(crate) async fn publish_commitment_impl(
    command_tx: &mpsc::Sender<NetworkCommand>,
    request: PublishCommitmentRequest,
) -> Result<PublishCommitmentResponse> {
    // Decode the signed commitment from SSZ bytes
    let commitment_bytes = request.commitment.as_ref();
    let signed_commitment = SignedCommitment::deserialize(commitment_bytes).map_err(|e| {
        PreconfirmationClientError::Validation(format!("invalid commitment SSZ: {e}"))
    })?;

    // Calculate commitment hash and extract tx_list_hash before publishing
    let commitment_hash = preconfirmation_types::keccak256_bytes(commitment_bytes);
    let tx_list_hash =
        B256::from_slice(signed_commitment.commitment.preconf.raw_tx_list_hash.as_slice());

    // Publish via P2P network
    command_tx
        .send(NetworkCommand::PublishCommitment(signed_commitment))
        .await
        .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

    Ok(PublishCommitmentResponse { commitment_hash: B256::from(commitment_hash.0), tx_list_hash })
}

/// Publish a raw tx list via the P2P network command channel after hash validation.
pub(crate) async fn publish_tx_list_impl(
    command_tx: &mpsc::Sender<NetworkCommand>,
    request: PublishTxListRequest,
) -> Result<PublishTxListResponse> {
    let raw_tx_list = TxListBytes::try_from(request.tx_list.to_vec())
        .map_err(|_| PreconfirmationClientError::Validation("txlist too large".into()))?;

    let calculated_hash = preconfirmation_types::keccak256_bytes(&raw_tx_list);
    if calculated_hash.0 != request.tx_list_hash.0 {
        return Err(PreconfirmationClientError::Validation(format!(
            "tx_list_hash mismatch: expected {}, got {}",
            request.tx_list_hash, calculated_hash
        )));
    }

    let raw_tx_list_hash =
        Bytes32::try_from(calculated_hash.0.to_vec()).expect("keccak256 always produces 32 bytes");
    let gossip = RawTxListGossip { raw_tx_list_hash, txlist: raw_tx_list };

    command_tx
        .send(NetworkCommand::PublishRawTxList(gossip))
        .await
        .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

    Ok(PublishTxListResponse { tx_list_hash: request.tx_list_hash })
}

/// Build a NodeStatus by querying peer count and computing sync state.
pub(crate) async fn build_node_status<I: InboxReader>(
    command_tx: &mpsc::Sender<NetworkCommand>,
    inbox_reader: &I,
    preconf_tip: U256,
    local_peer_id: &str,
) -> Result<NodeStatus> {
    // Query peer count via command channel
    let (tx, rx) = tokio::sync::oneshot::channel();
    let peer_count = match command_tx.send(NetworkCommand::GetPeerCount { respond_to: tx }).await {
        Ok(()) => rx.await.unwrap_or(0),
        Err(_) => 0,
    };

    // Compute sync status using same strict readiness logic as wait_event_sync.
    let next_proposal_id = inbox_reader.get_next_proposal_id().await?;
    let target_proposal_id = next_proposal_id.saturating_sub(1);
    let (is_synced_with_inbox, event_sync_tip) = if target_proposal_id == 0 {
        (true, inbox_reader.get_head_l1_origin_block_id().await?.map(U256::from))
    } else {
        let target_block = inbox_reader.get_last_block_id_by_batch_id(target_proposal_id).await?;
        let head_l1_origin_block_id = inbox_reader.get_head_l1_origin_block_id().await?;
        let ready = matches!(
            (target_block, head_l1_origin_block_id),
            (Some(target_block), Some(head_block)) if head_block >= target_block
        );
        (ready, head_l1_origin_block_id.map(U256::from))
    };

    Ok(NodeStatus {
        is_synced_with_inbox,
        event_sync_tip,
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

    /// Test that NodeRpcApiImpl returns correct status with peer_id.
    #[tokio::test]
    async fn test_node_status_includes_peer_id() {
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::from(100));
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            local_peer_id: "12D3KooWTest".to_string(),
            inbox_reader: MockInboxReader::new(43, Some(120), Some(120)),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
        };

        // Spawn a handler to respond to GetPeerCount command
        tokio::spawn(async move {
            if let Some(NetworkCommand::GetPeerCount { respond_to }) = command_rx.recv().await {
                let _ = respond_to.send(5);
            }
        });

        let status = api.get_status().await.unwrap();
        assert_eq!(status.peer_id, "12D3KooWTest");
        assert_eq!(status.peer_count, 5);
        assert!(status.is_synced_with_inbox);
        assert_eq!(status.event_sync_tip, Some(U256::from(120)));
    }

    /// Test that publish_tx_list accepts pre-encoded tx list bytes.
    #[tokio::test]
    async fn test_publish_tx_list_accepts_encoded_bytes() {
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            local_peer_id: "test".to_string(),
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
        };

        let tx_list = alloy_primitives::Bytes::from(vec![1u8, 2u8, 3u8, 4u8]);
        let calculated_hash = preconfirmation_types::keccak256_bytes(tx_list.as_ref());
        let tx_list_hash = B256::from(calculated_hash.0);
        let expected_raw_hash =
            Bytes32::try_from(calculated_hash.0.to_vec()).expect("keccak256 always 32 bytes");
        let expected_txlist =
            TxListBytes::try_from(tx_list.to_vec()).expect("tx list within size limit");

        let receiver = tokio::spawn(async move {
            match command_rx.recv().await {
                Some(NetworkCommand::PublishRawTxList(gossip)) => {
                    assert_eq!(gossip.raw_tx_list_hash, expected_raw_hash);
                    assert_eq!(gossip.txlist, expected_txlist);
                }
                other => panic!("unexpected network command: {other:?}"),
            }
        });

        let response =
            api.publish_tx_list(PublishTxListRequest { tx_list_hash, tx_list }).await.unwrap();

        assert_eq!(response.tx_list_hash, tx_list_hash);
        receiver.await.unwrap();
    }

    /// Test that get_preconf_slot_info delegates to the lookahead resolver and maps the result.
    #[tokio::test]
    async fn test_get_preconf_slot_info_returns_resolver_output() {
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            local_peer_id: "test".to_string(),
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
        };

        tokio::spawn(async move { while command_rx.recv().await.is_some() {} });

        let timestamp = U256::from(500);
        let slot_info = api.get_preconf_slot_info(timestamp).await.unwrap();

        assert_eq!(slot_info.signer, alloy_primitives::Address::repeat_byte(0x11));
        assert_eq!(slot_info.submission_window_end, U256::from(2000));
    }
}
