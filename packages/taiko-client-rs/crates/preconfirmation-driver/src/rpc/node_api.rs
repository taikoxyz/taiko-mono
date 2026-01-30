//! RPC API implementation backed by the preconfirmation driver node state.

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
        NodeStatus, PreconfRpcApi, PublishCommitmentRequest, PublishCommitmentResponse,
        PublishTxListRequest, PublishTxListResponse,
    },
};

/// Internal RPC API implementation backed by the preconfirmation driver node state.
pub(crate) struct NodeRpcApiImpl<I: InboxReader> {
    /// Command tx for issuing commands to the P2P network layer.
    pub(crate) command_tx: mpsc::Sender<NetworkCommand>,
    /// Watch receiver for the canonical proposal ID.
    pub(crate) canonical_proposal_id_rx: watch::Receiver<u64>,
    /// Watch receiver for the preconfirmation tip.
    pub(crate) preconf_tip_rx: watch::Receiver<U256>,
    /// Local peer ID string for status responses.
    pub(crate) local_peer_id: String,
    /// Inbox reader for checking L1 sync state.
    pub(crate) inbox_reader: I,
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
        self.command_tx
            .send(NetworkCommand::PublishCommitment(signed_commitment))
            .await
            .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

        Ok(PublishCommitmentResponse {
            commitment_hash: B256::from(commitment_hash.0),
            tx_list_hash,
        })
    }

    /// Publishes a transaction list to the P2P network.
    ///
    /// Verifies the hash matches the provided encoded tx list and broadcasts via P2P gossip.
    async fn publish_tx_list(
        &self,
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

        let raw_tx_list_hash = Bytes32::try_from(calculated_hash.0.to_vec())
            .expect("keccak256 always produces 32 bytes");
        let gossip = RawTxListGossip { raw_tx_list_hash, txlist: raw_tx_list };

        self.command_tx
            .send(NetworkCommand::PublishRawTxList(gossip))
            .await
            .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

        Ok(PublishTxListResponse { tx_list_hash: request.tx_list_hash })
    }

    /// Returns the current status of the preconfirmation driver node.
    ///
    /// Queries the P2P layer for peer count and returns sync state information.
    async fn get_status(&self) -> Result<NodeStatus> {
        let canonical_proposal_id = *self.canonical_proposal_id_rx.borrow();

        // Query peer count via command channel
        let (tx, rx) = tokio::sync::oneshot::channel();
        let peer_count =
            match self.command_tx.send(NetworkCommand::GetPeerCount { respond_to: tx }).await {
                Ok(()) => rx.await.unwrap_or(0),
                Err(_) => 0,
            };

        // Compute sync status using same logic as wait_event_sync
        let next_proposal_id = self.inbox_reader.get_next_proposal_id().await?;
        let is_synced_with_inbox =
            next_proposal_id == 0 || canonical_proposal_id >= next_proposal_id.saturating_sub(1);

        Ok(NodeStatus {
            is_synced_with_inbox,
            preconf_tip: *self.preconf_tip_rx.borrow(),
            canonical_proposal_id,
            peer_count,
            peer_id: self.local_peer_id.clone(),
        })
    }

    /// Returns the current preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip_rx.borrow())
    }

    /// Returns the last canonical proposal ID from L1 events.
    async fn canonical_proposal_id(&self) -> Result<u64> {
        Ok(*self.canonical_proposal_id_rx.borrow())
    }
}

#[cfg(test)]
pub(crate) const NODE_RPC_API_MARKER: () = ();

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};

    /// Mock inbox reader for testing.
    #[derive(Clone)]
    struct MockInboxReader {
        next_proposal_id: std::sync::Arc<AtomicU64>,
    }

    impl MockInboxReader {
        fn new(next_proposal_id: u64) -> Self {
            Self { next_proposal_id: std::sync::Arc::new(AtomicU64::new(next_proposal_id)) }
        }
    }

    #[async_trait::async_trait]
    impl InboxReader for MockInboxReader {
        async fn get_next_proposal_id(&self) -> Result<u64> {
            Ok(self.next_proposal_id.load(Ordering::SeqCst))
        }
    }

    /// Test that NodeRpcApiImpl returns correct status with peer_id.
    #[tokio::test]
    async fn test_node_status_includes_peer_id() {
        let (_canonical_id_tx, canonical_id_rx) = watch::channel(42u64);
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::from(100));
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        // MockInboxReader returns 43, so with canonical_id=42, target=42, we should be synced
        let api = NodeRpcApiImpl {
            command_tx,
            canonical_proposal_id_rx: canonical_id_rx,
            preconf_tip_rx,
            local_peer_id: "12D3KooWTest".to_string(),
            inbox_reader: MockInboxReader::new(43),
        };

        // Spawn a handler to respond to GetPeerCount command
        tokio::spawn(async move {
            if let Some(NetworkCommand::GetPeerCount { respond_to }) = command_rx.recv().await {
                let _ = respond_to.send(5);
            }
        });

        let status = api.get_status().await.unwrap();
        assert_eq!(status.peer_id, "12D3KooWTest");
        assert_eq!(status.canonical_proposal_id, 42);
        assert_eq!(status.peer_count, 5);
        assert!(status.is_synced_with_inbox); // canonical_id (42) >= target (43-1=42)
    }

    /// Test that publish_tx_list accepts pre-encoded tx list bytes.
    #[tokio::test]
    async fn test_publish_tx_list_accepts_encoded_bytes() {
        let (_canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        let api = NodeRpcApiImpl {
            command_tx,
            canonical_proposal_id_rx: canonical_id_rx,
            preconf_tip_rx,
            local_peer_id: "test".to_string(),
            inbox_reader: MockInboxReader::new(0),
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
}
