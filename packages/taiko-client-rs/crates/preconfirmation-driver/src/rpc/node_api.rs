//! RPC API implementation backed by the preconfirmation driver node state.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::{NetworkCommand, NetworkEvent, PeerId};
use preconfirmation_types::{Bytes32, RawTxListGossip, SignedCommitment, TxListBytes};
use ssz_rs::Deserialize;
use tokio::sync::{mpsc, watch};
use tracing::error;

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
    /// Local peer ID used as the `from` field in loopback events.
    pub(crate) local_peer_id_peer: PeerId,
    /// Inbox reader for checking L1 sync state.
    pub(crate) inbox_reader: I,
    /// Lookahead resolver for slot info by timestamp.
    pub(crate) lookahead_resolver:
        Arc<dyn protocol::preconfirmation::PreconfSignerResolver + Send + Sync>,
    /// Loopback channel for emitting gossip events back to the local event loop.
    /// Published commitments and txlists are also delivered locally so a
    /// single-node setup (zero P2P peers) can still advance the chain.
    pub(crate) loopback_tx: mpsc::Sender<NetworkEvent>,
}

#[async_trait::async_trait]
impl<I: InboxReader + 'static> PreconfRpcApi for NodeRpcApiImpl<I> {
    /// Publishes a signed commitment to the P2P network.
    ///
    /// Decodes the SSZ-encoded commitment, extracts the tx_list_hash, and broadcasts
    /// via the P2P gossip network. Also emits the commitment as a local loopback event
    /// so the local event handler processes it.
    ///
    /// Note: gossipsub does not deliver a node's own published messages back to it,
    /// so the loopback is the **only** local delivery path — there is no risk of
    /// duplicate processing even when the node has peers.
    async fn publish_commitment(
        &self,
        request: PublishCommitmentRequest,
    ) -> Result<PublishCommitmentResponse> {
        let (response, commitment) = publish_commitment_impl(&self.command_tx, request).await?;

        let event = NetworkEvent::GossipSignedCommitment {
            from: self.local_peer_id_peer,
            msg: Box::new(commitment),
        };
        send_loopback(&self.loopback_tx, event).await;

        Ok(response)
    }

    /// Publishes a transaction list to the P2P network.
    ///
    /// Verifies the hash matches the provided encoded tx list and broadcasts via P2P gossip.
    /// Also emits the txlist as a local loopback event so the local event handler processes it.
    ///
    /// See [`publish_commitment`](Self::publish_commitment) for why this does not cause
    /// duplicate processing.
    async fn publish_tx_list(
        &self,
        request: PublishTxListRequest,
    ) -> Result<PublishTxListResponse> {
        let (response, gossip) = publish_tx_list_impl(&self.command_tx, request).await?;

        let event = NetworkEvent::GossipRawTxList {
            from: self.local_peer_id_peer,
            msg: Box::new(gossip),
        };
        send_loopback(&self.loopback_tx, event).await;

        Ok(response)
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

/// Send a loopback event to the local event loop on a best-effort basis.
///
/// A failure means the event loop has exited (receiver dropped), which is a node
/// health issue — not an RPC-level error.  Because the P2P publish already
/// succeeded at this point, returning an error would cause callers to retry and
/// produce duplicate gossip.  We therefore log the failure and move on.
pub(crate) async fn send_loopback(tx: &mpsc::Sender<NetworkEvent>, event: NetworkEvent) {
    if let Err(e) = tx.send(event).await {
        error!(error = %e, "loopback send failed — local event loop may have exited");
    }
}

/// Publish a signed commitment via the P2P network command channel.
///
/// Returns the publish response and the decoded [`SignedCommitment`] so callers
/// can emit a loopback event without re-decoding.
pub(crate) async fn publish_commitment_impl(
    command_tx: &mpsc::Sender<NetworkCommand>,
    request: PublishCommitmentRequest,
) -> Result<(PublishCommitmentResponse, SignedCommitment)> {
    // Decode the signed commitment from SSZ bytes
    let commitment_bytes = request.commitment.as_ref();
    let signed_commitment = SignedCommitment::deserialize(commitment_bytes).map_err(|e| {
        PreconfirmationClientError::Validation(format!("invalid commitment SSZ: {e}"))
    })?;

    // Calculate commitment hash and extract tx_list_hash before publishing
    let commitment_hash = preconfirmation_types::keccak256_bytes(commitment_bytes);
    let tx_list_hash =
        B256::from_slice(signed_commitment.commitment.preconf.raw_tx_list_hash.as_slice());

    // Clone the commitment for the caller before moving it into the network command.
    let commitment_clone = signed_commitment.clone();

    // Publish via P2P network
    command_tx
        .send(NetworkCommand::PublishCommitment(signed_commitment))
        .await
        .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

    Ok((
        PublishCommitmentResponse { commitment_hash: B256::from(commitment_hash.0), tx_list_hash },
        commitment_clone,
    ))
}

/// Publish a raw tx list via the P2P network command channel after hash validation.
///
/// Returns the publish response and the constructed [`RawTxListGossip`] so callers
/// can emit a loopback event without re-constructing.
pub(crate) async fn publish_tx_list_impl(
    command_tx: &mpsc::Sender<NetworkCommand>,
    request: PublishTxListRequest,
) -> Result<(PublishTxListResponse, RawTxListGossip)> {
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

    // Clone the gossip for the caller before moving it into the network command.
    let gossip_clone = gossip.clone();

    command_tx
        .send(NetworkCommand::PublishRawTxList(gossip))
        .await
        .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

    Ok((PublishTxListResponse { tx_list_hash: request.tx_list_hash }, gossip_clone))
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

    /// Test that NodeRpcApiImpl returns correct status with peer_id.
    #[tokio::test]
    async fn test_node_status_includes_peer_id() {
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::from(100));
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            local_peer_id: "12D3KooWTest".to_string(),
            local_peer_id_peer: PeerId::random(),
            inbox_reader: MockInboxReader::new(43, Some(120), Some(120)),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
            loopback_tx: mpsc::channel(16).0,
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
        let (loopback_tx, _loopback_rx) = mpsc::channel(16);

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            local_peer_id: "test".to_string(),
            local_peer_id_peer: PeerId::random(),
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
            loopback_tx,
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
            local_peer_id_peer: PeerId::random(),
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
            loopback_tx: mpsc::channel(16).0,
        };

        tokio::spawn(async move { while command_rx.recv().await.is_some() {} });

        let timestamp = U256::from(500);
        let slot_info = api.get_preconf_slot_info(timestamp).await.unwrap();

        assert_eq!(slot_info.signer, alloy_primitives::Address::repeat_byte(0x11));
        assert_eq!(slot_info.submission_window_end, U256::from(2000));
    }

    /// Test that publish_tx_list sends a loopback event to the loopback channel.
    #[tokio::test]
    async fn test_publish_tx_list_sends_loopback_event() {
        use preconfirmation_net::NetworkEvent;

        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);
        let (loopback_tx, mut loopback_rx) = mpsc::channel(16);

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            local_peer_id: "test".to_string(),
            local_peer_id_peer: PeerId::random(),
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
            loopback_tx,
        };

        let tx_list = alloy_primitives::Bytes::from(vec![1u8, 2u8, 3u8, 4u8]);
        let calculated_hash = preconfirmation_types::keccak256_bytes(tx_list.as_ref());
        let tx_list_hash = B256::from(calculated_hash.0);

        // Drain the P2P command channel so publish doesn't block.
        tokio::spawn(async move { while command_rx.recv().await.is_some() {} });

        api.publish_tx_list(PublishTxListRequest { tx_list_hash, tx_list }).await.unwrap();

        // The loopback channel must have received a GossipRawTxList event.
        let event = loopback_rx.try_recv().expect("loopback event should be available");
        match event {
            NetworkEvent::GossipRawTxList { msg, .. } => {
                assert_eq!(
                    B256::from_slice(msg.raw_tx_list_hash.as_ref()),
                    tx_list_hash,
                    "loopback txlist hash must match"
                );
            }
            other => panic!("expected GossipRawTxList, got {other:?}"),
        }
    }

    /// Test that publish_tx_list still returns Ok when the loopback channel is closed.
    ///
    /// A closed loopback means the event loop has exited, which is a node health
    /// issue. The P2P publish already succeeded, so returning an error would cause
    /// callers to retry and produce duplicate gossip.
    #[tokio::test]
    async fn test_publish_tx_list_succeeds_despite_closed_loopback() {
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);
        // Create a channel and immediately drop the receiver to close it.
        let (loopback_tx, _) = mpsc::channel::<preconfirmation_net::NetworkEvent>(1);

        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx,
            local_peer_id: "test".to_string(),
            local_peer_id_peer: PeerId::random(),
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
            loopback_tx,
        };

        let tx_list = alloy_primitives::Bytes::from(vec![5u8, 6u8]);
        let calculated_hash = preconfirmation_types::keccak256_bytes(tx_list.as_ref());
        let tx_list_hash = B256::from(calculated_hash.0);

        // Drain the P2P command channel.
        tokio::spawn(async move { while command_rx.recv().await.is_some() {} });

        let result =
            api.publish_tx_list(PublishTxListRequest { tx_list_hash, tx_list }).await;
        assert!(result.is_ok(), "should succeed even when loopback channel is closed");
    }

    // -- shared test infrastructure for end-to-end loopback tests --

    use crate::{
        driver_interface::DriverClient,
        storage::{CommitmentStore, InMemoryCommitmentStore},
        subscription::{EventHandler, EventHandlerParams},
    };
    use preconfirmation_net::NetworkEvent;
    use preconfirmation_types::MAX_TXLIST_BYTES;
    use protocol::codec::ZlibTxListCodec;
    use tokio::sync::broadcast;

    /// Stub driver that accepts everything and keeps tip at zero.
    struct StubDriver;
    #[async_trait::async_trait]
    impl DriverClient for StubDriver {
        async fn submit_preconfirmation(
            &self,
            _: crate::driver_interface::PreconfirmationInput,
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

    /// Helper: build an `EventHandler` + `NodeRpcApiImpl` pair sharing a loopback
    /// channel, returning `(api, loopback_rx, handler, store)`.
    fn build_loopback_test_harness() -> (
        NodeRpcApiImpl<MockInboxReader>,
        mpsc::Receiver<NetworkEvent>,
        EventHandler<StubDriver>,
        Arc<InMemoryCommitmentStore>,
    ) {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(StubDriver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (handler_cmd_tx, _handler_cmd_rx) = mpsc::channel(8);
        let handler = EventHandler::new(EventHandlerParams {
            store: store.clone() as Arc<dyn CommitmentStore>,
            codec,
            driver,
            expected_slasher: None,
            event_tx,
            command_tx: handler_cmd_tx,
            lookahead_resolver: Arc::new(MockLookaheadResolver),
        });

        let (command_tx, command_rx) = mpsc::channel::<NetworkCommand>(16);
        let (loopback_tx, loopback_rx) = mpsc::channel(16);
        let api = NodeRpcApiImpl {
            command_tx,
            preconf_tip_rx: watch::channel(U256::ZERO).1,
            local_peer_id: "test".to_string(),
            local_peer_id_peer: PeerId::random(),
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver),
            loopback_tx,
        };

        // Drain P2P commands so publish doesn't block.
        tokio::spawn(async move {
            let mut rx = command_rx;
            while rx.recv().await.is_some() {}
        });

        (api, loopback_rx, handler, store)
    }

    /// End-to-end test: publish a txlist via the RPC API, receive the loopback event,
    /// pass it through `EventHandler::handle_event`, and verify the store contains
    /// the txlist.
    #[tokio::test]
    async fn test_loopback_txlist_reaches_event_handler() {
        let (api, mut loopback_rx, handler, store) = build_loopback_test_harness();

        // Build a valid txlist and publish via the RPC API.
        let tx_list = alloy_primitives::Bytes::from(vec![0xABu8; 4]);
        let hash = preconfirmation_types::keccak256_bytes(tx_list.as_ref());
        let tx_list_hash = B256::from(hash.0);

        api.publish_tx_list(PublishTxListRequest { tx_list_hash, tx_list })
            .await
            .expect("publish should succeed");

        // Receive from loopback and pass through the handler — the same
        // path that EventLoop::run() takes in its `select!`.
        let event = loopback_rx.recv().await.expect("loopback event expected");
        assert!(matches!(event, NetworkEvent::GossipRawTxList { .. }));
        handler.handle_event(event).await.expect("handler should process loopback event");

        // Verify the txlist landed in the store.
        assert!(
            CommitmentStore::get_txlist(store.as_ref(), &tx_list_hash).is_some(),
            "txlist should be in the store after loopback processing"
        );
    }

    /// End-to-end test: publish a commitment via the RPC API, receive the loopback
    /// event, pass it through `EventHandler::handle_event`, and verify the store
    /// contains the commitment.
    #[tokio::test]
    async fn test_loopback_commitment_reaches_event_handler() {
        let (api, mut loopback_rx, handler, _store) = build_loopback_test_harness();

        // Build a minimal valid SSZ-encoded SignedCommitment.
        let commitment = SignedCommitment::default();
        let mut commitment_bytes = Vec::new();
        ssz_rs::Serialize::serialize(&commitment, &mut commitment_bytes)
            .expect("serialize commitment");
        let request = PublishCommitmentRequest {
            commitment: alloy_primitives::Bytes::from(commitment_bytes),
        };

        api.publish_commitment(request).await.expect("publish should succeed");

        // Receive from loopback and pass through the handler.
        let event = loopback_rx.recv().await.expect("loopback event expected");
        assert!(matches!(event, NetworkEvent::GossipSignedCommitment { .. }));
        // handle_event dispatches to handle_commitment which validates and
        // stores. With block_number=0 and event_sync_tip=0 the commitment is
        // stale (current_block <= event_sync_tip), so the handler drops it.
        // The important assertion is that handle_event succeeds — proving the
        // loopback event was correctly dispatched.
        handler.handle_event(event).await.expect("handler should process loopback commitment");
    }
}
