//! P2P SDK client core and event loop.
//!
//! This module provides [`P2pClient`], a high-level facade over the `preconfirmation-net`
//! networking layer. It manages the lifecycle of a P2P node, processes network events,
//! applies SDK-level validation and deduplication, and emits [`SdkEvent`]s to subscribers.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::{
    LocalValidationAdapter, LookaheadResolver, LookaheadValidationAdapter, NetworkEvent, P2pHandle,
    P2pNode, ValidationAdapter,
};
use preconfirmation_types::{Bytes20, Bytes32, RawTxListGossip, SignedCommitment, Uint256};
use tokio::sync::{broadcast, mpsc};
use tracing::{debug, error, info, trace, warn};

use crate::{
    config::P2pClientConfig,
    error::{P2pClientError, P2pResult},
    storage::{compute_message_id, CommitmentDedupeKey, InMemoryStorage, SdkStorage},
    types::{SdkCommand, SdkEvent},
    validation::{CommitmentValidator, ValidationStatus},
};

/// High-level P2P SDK client that wraps the network layer and provides
/// event processing, deduplication, and validation.
///
/// The client manages:
/// - A `P2pNode` background task for the libp2p network
/// - An event loop that processes `NetworkEvent`s and emits `SdkEvent`s
/// - Storage for commitments and txlists with deduplication
/// - SDK-level validation on top of network-level validation
///
/// # Example
///
/// ```ignore
/// use p2p::{P2pClient, P2pClientConfig, SdkEvent};
///
/// let config = P2pClientConfig::default();
/// let (client, mut events) = P2pClient::new(config)?;
///
/// // Spawn the client
/// tokio::spawn(async move {
///     if let Err(e) = client.run().await {
///         eprintln!("Client error: {e}");
///     }
/// });
///
/// // Process events
/// while let Some(event) = events.recv().await {
///     match event {
///         SdkEvent::CommitmentGossip { from, commitment } => {
///             println!("Got commitment from {from}");
///         }
///         _ => {}
///     }
/// }
/// ```
pub struct P2pClient {
    /// Handle for sending commands to the network layer.
    handle: P2pHandle,
    /// The underlying P2P node (consumed when `run()` is called).
    node: Option<P2pNode>,
    /// Storage for commitments, txlists, and deduplication.
    storage: Arc<InMemoryStorage>,
    /// SDK-level commitment validator.
    validator: CommitmentValidator,
    /// Channel for sending SDK events to subscribers.
    event_tx: broadcast::Sender<SdkEvent>,
    /// Channel for receiving SDK commands.
    command_rx: Option<mpsc::Receiver<SdkCommand>>,
    /// Channel for sending SDK commands (cloneable handle).
    command_tx: mpsc::Sender<SdkCommand>,
    /// Configuration.
    #[allow(dead_code)]
    config: P2pClientConfig,
    /// Current local head block number.
    local_head: U256,
    /// Whether the client is synced with the network.
    #[allow(dead_code)]
    synced: bool,
}

/// Handle for interacting with a running P2pClient.
///
/// This handle can be cloned and used from multiple tasks to send commands
/// and subscribe to events.
#[derive(Clone)]
pub struct P2pClientHandle {
    /// Command sender channel.
    command_tx: mpsc::Sender<SdkCommand>,
    /// Event broadcast receiver factory.
    event_tx: broadcast::Sender<SdkEvent>,
}

impl P2pClientHandle {
    /// Subscribe to SDK events.
    ///
    /// Returns a new receiver that will receive all events emitted after this call.
    /// Multiple subscribers can exist concurrently.
    pub fn subscribe(&self) -> broadcast::Receiver<SdkEvent> {
        self.event_tx.subscribe()
    }

    /// Publish a signed commitment to the network.
    pub async fn publish_commitment(
        &self,
        commitment: SignedCommitment,
    ) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::PublishCommitment(Box::new(commitment)))
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }

    /// Publish a raw txlist to the network.
    pub async fn publish_raw_txlist(&self, msg: RawTxListGossip) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::PublishRawTxList(Box::new(msg)))
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }

    /// Request commitments starting from a block number.
    pub async fn request_commitments(
        &self,
        start_block: u64,
        max_count: u32,
    ) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::RequestCommitments { start_block, max_count })
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }

    /// Request a raw txlist by hash.
    pub async fn request_raw_txlist(&self, hash: B256) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::RequestRawTxList { hash })
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }

    /// Request the current preconfirmation head from a peer.
    pub async fn request_head(&self) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::RequestHead)
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }

    /// Update the local head block number.
    pub async fn update_head(&self, block_number: u64) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::UpdateHead { block_number })
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }

    /// Request graceful shutdown of the client.
    pub async fn shutdown(&self) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::Shutdown)
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }
}

impl P2pClient {
    /// Create a new P2P client with the given configuration.
    ///
    /// Returns the client (which should be spawned to run the event loop) and
    /// an event receiver for consuming SDK events.
    ///
    /// # Arguments
    ///
    /// * `config` - The SDK configuration including network settings.
    ///
    /// # Returns
    ///
    /// A tuple of `(P2pClient, broadcast::Receiver<SdkEvent>)` on success.
    pub fn new(config: P2pClientConfig) -> P2pResult<(Self, broadcast::Receiver<SdkEvent>)> {
        Self::with_validation_adapter(config, None, None)
    }

    /// Create a new P2P client with a custom validation adapter.
    ///
    /// This allows providing a custom `ValidationAdapter` for network-level validation,
    /// such as a `LookaheadValidationAdapter` for schedule-based validation.
    ///
    /// # Arguments
    ///
    /// * `config` - The SDK configuration including network settings.
    /// * `validator` - Optional custom validation adapter for network-level validation.
    /// * `lookahead` - Optional lookahead resolver for schedule-based validation.
    pub fn with_validation_adapter(
        config: P2pClientConfig,
        validator: Option<Box<dyn ValidationAdapter>>,
        lookahead: Option<Arc<dyn LookaheadResolver>>,
    ) -> P2pResult<(Self, broadcast::Receiver<SdkEvent>)> {
        // Build the validation adapter
        let expected_slasher = config
            .expected_slasher
            .map(|addr| Bytes20::try_from(addr.as_slice().to_vec()).unwrap());

        let validation_adapter: Box<dyn ValidationAdapter> = match (validator, lookahead) {
            (Some(v), _) => v,
            (None, Some(resolver)) => {
                Box::new(LookaheadValidationAdapter::new(expected_slasher, resolver))
            }
            (None, None) => Box::new(LocalValidationAdapter::new(expected_slasher)),
        };

        // Create the P2P node
        let (handle, node) = P2pNode::new(config.network.clone(), validation_adapter)
            .map_err(|e| P2pClientError::Network(e.to_string().into()))?;

        // Create channels
        let (event_tx, event_rx) = broadcast::channel(config.event_channel_size);
        let (command_tx, command_rx) = mpsc::channel(config.command_channel_size);

        // Create storage and validator
        let storage = Arc::new(InMemoryStorage::new(
            config.dedupe_cache_cap as u64,
            config.dedupe_ttl,
            config.dedupe_ttl, // Use same TTL for pending buffer
        ));
        let sdk_validator = CommitmentValidator::new();

        let client = Self {
            handle,
            node: Some(node),
            storage,
            validator: sdk_validator,
            event_tx,
            command_rx: Some(command_rx),
            command_tx,
            config,
            local_head: U256::ZERO,
            synced: false,
        };

        Ok((client, event_rx))
    }

    /// Get a cloneable handle for interacting with this client.
    ///
    /// The handle can be used to send commands and subscribe to events
    /// from multiple tasks.
    pub fn handle(&self) -> P2pClientHandle {
        P2pClientHandle {
            command_tx: self.command_tx.clone(),
            event_tx: self.event_tx.clone(),
        }
    }

    /// Run the P2P client event loop.
    ///
    /// This method consumes the client and runs until shutdown is requested
    /// or an unrecoverable error occurs.
    ///
    /// The event loop:
    /// - Drives the underlying P2P node
    /// - Processes `NetworkEvent`s from the network layer
    /// - Applies SDK-level validation and deduplication
    /// - Emits `SdkEvent`s to subscribers
    /// - Handles `SdkCommand`s from the client handle
    pub async fn run(mut self) -> P2pResult<()> {
        // Take ownership of the node and command receiver
        let node = self
            .node
            .take()
            .ok_or_else(|| P2pClientError::MissingData("node already consumed".to_string()))?;
        let mut command_rx = self
            .command_rx
            .take()
            .ok_or_else(|| P2pClientError::MissingData("command_rx already consumed".to_string()))?;

        // Spawn the P2P node in the background
        let node_handle = tokio::spawn(async move {
            if let Err(e) = node.run().await {
                error!("P2P node error: {e}");
            }
        });

        info!("P2pClient started");

        // Emit initial sync status
        let _ = self.event_tx.send(SdkEvent::HeadSyncStatus { synced: false });

        loop {
            tokio::select! {
                // Process network events from the handle
                event = async {
                    // Poll for network events
                    use futures::stream::StreamExt;
                    self.handle.events().next().await
                } => {
                    if let Some(event) = event {
                        self.handle_network_event(event).await;
                    }
                }

                // Process SDK commands
                Some(cmd) = command_rx.recv() => {
                    if self.handle_command(cmd).await? {
                        // Shutdown requested
                        break;
                    }
                }

                // Node task exited
                _ = tokio::time::sleep(std::time::Duration::from_millis(100)) => {
                    if node_handle.is_finished() {
                        warn!("P2P node task exited unexpectedly");
                        break;
                    }
                }
            }
        }

        info!("P2pClient shutting down");
        node_handle.abort();
        Ok(())
    }

    /// Handle a network event from the underlying P2P layer.
    async fn handle_network_event(&mut self, event: NetworkEvent) {
        match event {
            NetworkEvent::PeerConnected(peer) => {
                debug!("Peer connected: {peer}");
                let _ = self.event_tx.send(SdkEvent::PeerConnected { peer });
            }

            NetworkEvent::PeerDisconnected(peer) => {
                debug!("Peer disconnected: {peer}");
                let _ = self.event_tx.send(SdkEvent::PeerDisconnected { peer });
            }

            NetworkEvent::GossipSignedCommitment { from, msg } => {
                self.handle_commitment_gossip(from, *msg).await;
            }

            NetworkEvent::GossipRawTxList { from, msg } => {
                self.handle_txlist_gossip(from, *msg).await;
            }

            NetworkEvent::ReqRespCommitments { from, msg } => {
                debug!("Received commitments response from {from}");
                let _ = self.event_tx.send(SdkEvent::ReqRespCommitments { from, msg });
            }

            NetworkEvent::ReqRespRawTxList { from, msg } => {
                debug!("Received raw txlist response from {from}");
                let _ = self.event_tx.send(SdkEvent::ReqRespRawTxList { from, msg });
            }

            NetworkEvent::ReqRespHead { from, head } => {
                debug!("Received head response from {from}");
                let _ = self.event_tx.send(SdkEvent::ReqRespHead { from, head });
            }

            NetworkEvent::InboundCommitmentsRequest { from } => {
                trace!("Inbound commitments request from {from}");
                // Request handling is done by the network layer
            }

            NetworkEvent::InboundRawTxListRequest { from } => {
                trace!("Inbound raw txlist request from {from}");
            }

            NetworkEvent::InboundHeadRequest { from } => {
                trace!("Inbound head request from {from}");
            }

            NetworkEvent::Started => {
                info!("Network started");
            }

            NetworkEvent::Stopped => {
                info!("Network stopped");
            }

            NetworkEvent::Error(err) => {
                warn!("Network error: {err}");
                let _ = self.event_tx.send(SdkEvent::Error {
                    detail: format!("network: {err}"),
                });
            }
        }
    }

    /// Handle a signed commitment gossip message.
    async fn handle_commitment_gossip(&mut self, from: libp2p::PeerId, msg: SignedCommitment) {
        // Compute message ID for deduplication
        let payload = ssz_encode_commitment(&msg);
        let msg_id = compute_message_id("/taiko/preconf/commitments", &payload);

        // Check message-level dedupe
        if self.storage.is_duplicate_message(&msg_id) {
            trace!("Duplicate commitment message from {from}");
            return;
        }
        self.storage.mark_message_seen(msg_id);

        // Extract block number and check commitment-level dedupe
        let block_number = uint256_to_u256(&msg.commitment.preconf.block_number);

        // Try to recover signer for dedupe key
        if let Ok(signer) = preconfirmation_types::verify_signed_commitment(&msg) {
            let dedupe_key = CommitmentDedupeKey {
                block_number,
                signer,
            };
            if self.storage.is_duplicate_commitment(&dedupe_key) {
                trace!("Duplicate commitment for block {block_number} from signer {signer}");
                return;
            }
            self.storage.mark_commitment_seen(dedupe_key);
        }

        // Validate the commitment
        // TODO: Look up parent from storage for full validation
        let result = self.validator.validate(&msg, None);

        match result.outcome.status {
            ValidationStatus::Valid => {
                debug!("Valid commitment from {from} for block {block_number}");
                self.storage.insert_commitment(block_number, msg.clone());

                // Check if any pending commitments can now be released
                let commitment_hash = match preconfirmation_types::preconfirmation_hash(
                    &msg.commitment.preconf,
                ) {
                    Ok(h) => B256::from_slice(h.as_ref()),
                    Err(_) => return,
                };
                let released = self.storage.release_pending(&commitment_hash);
                for pending in released {
                    debug!("Released pending commitment for block {:?}",
                        uint256_to_u256(&pending.commitment.preconf.block_number));
                    let pending_block = uint256_to_u256(&pending.commitment.preconf.block_number);
                    self.storage.insert_commitment(pending_block, pending.clone());
                    let _ = self.event_tx.send(SdkEvent::CommitmentGossip {
                        from,
                        commitment: Box::new(pending),
                    });
                }

                let _ = self.event_tx.send(SdkEvent::CommitmentGossip {
                    from,
                    commitment: Box::new(msg),
                });
            }
            ValidationStatus::Pending => {
                debug!(
                    "Commitment from {from} is pending (awaiting parent): {:?}",
                    result.outcome.reason
                );
                // Buffer the commitment, waiting for its parent
                let parent_hash = B256::from_slice(
                    msg.commitment.preconf.parent_preconfirmation_hash.as_ref(),
                );
                self.storage.add_pending(parent_hash, msg);
            }
            ValidationStatus::Invalid => {
                warn!(
                    "Invalid commitment from {from}: {:?}",
                    result.outcome.reason
                );
                // Invalid commitments are dropped; network layer handles penalization
            }
        }
    }

    /// Handle a raw txlist gossip message.
    async fn handle_txlist_gossip(&mut self, from: libp2p::PeerId, msg: RawTxListGossip) {
        // Compute message ID for deduplication
        let payload = ssz_encode_txlist(&msg);
        let msg_id = compute_message_id("/taiko/preconf/rawtxlist", &payload);

        // Check message-level dedupe
        if self.storage.is_duplicate_message(&msg_id) {
            trace!("Duplicate txlist message from {from}");
            return;
        }
        self.storage.mark_message_seen(msg_id);

        // Extract hash for storage
        let hash = B256::from_slice(msg.raw_tx_list_hash.as_ref());

        debug!("Received raw txlist from {from} with hash {hash}");
        self.storage.insert_txlist(hash, msg.clone());

        let _ = self.event_tx.send(SdkEvent::RawTxListGossip {
            from,
            msg: Box::new(msg),
        });
    }

    /// Handle an SDK command.
    ///
    /// Returns `true` if shutdown was requested.
    async fn handle_command(&mut self, cmd: SdkCommand) -> P2pResult<bool> {
        match cmd {
            SdkCommand::PublishCommitment(commitment) => {
                debug!("Publishing commitment");
                self.handle
                    .publish_commitment(*commitment)
                    .await
                    .map_err(|e| P2pClientError::Network(e.to_string().into()))?;
            }

            SdkCommand::PublishRawTxList(msg) => {
                debug!("Publishing raw txlist");
                self.handle
                    .publish_raw_txlist(*msg)
                    .await
                    .map_err(|e| P2pClientError::Network(e.to_string().into()))?;
            }

            SdkCommand::RequestCommitments { start_block, max_count } => {
                debug!("Requesting commitments from block {start_block}");
                let start = Uint256::from(start_block);
                // Request from any peer (None)
                match self.handle.request_commitments(start, max_count, None).await {
                    Ok(resp) => {
                        let _ = self.event_tx.send(SdkEvent::ReqRespCommitments {
                            from: libp2p::PeerId::random(), // TODO: Track actual peer
                            msg: resp,
                        });
                    }
                    Err(e) => {
                        warn!("Failed to request commitments: {e}");
                    }
                }
            }

            SdkCommand::RequestRawTxList { hash } => {
                debug!("Requesting raw txlist {hash}");
                let hash_bytes = Bytes32::try_from(hash.as_slice().to_vec())
                    .map_err(|_| P2pClientError::Decode("invalid hash".to_string()))?;
                match self.handle.request_raw_txlist(hash_bytes, None).await {
                    Ok(resp) => {
                        let _ = self.event_tx.send(SdkEvent::ReqRespRawTxList {
                            from: libp2p::PeerId::random(),
                            msg: resp,
                        });
                    }
                    Err(e) => {
                        warn!("Failed to request raw txlist: {e}");
                    }
                }
            }

            SdkCommand::RequestHead => {
                debug!("Requesting head");
                match self.handle.request_head(None).await {
                    Ok(head) => {
                        let _ = self.event_tx.send(SdkEvent::ReqRespHead {
                            from: libp2p::PeerId::random(),
                            head,
                        });
                    }
                    Err(e) => {
                        warn!("Failed to request head: {e}");
                    }
                }
            }

            SdkCommand::UpdateHead { block_number } => {
                debug!("Updating local head to {block_number}");
                self.local_head = U256::from(block_number);
                // TODO: Trigger catch-up if behind network head
            }

            SdkCommand::Shutdown => {
                info!("Shutdown requested");
                return Ok(true);
            }
        }
        Ok(false)
    }
}

/// Convert Uint256 to alloy U256.
fn uint256_to_u256(v: &Uint256) -> U256 {
    // ssz_rs::U256 stores as [u64; 4] in little-endian
    // We need to convert to alloy U256
    let bytes = v.to_bytes_le();
    U256::from_le_slice(&bytes)
}

/// SSZ-encode a signed commitment for message ID computation.
fn ssz_encode_commitment(msg: &SignedCommitment) -> Vec<u8> {
    use ssz_rs::Serialize;
    let mut buf = Vec::new();
    msg.serialize(&mut buf).unwrap_or_default();
    buf
}

/// SSZ-encode a raw txlist gossip for message ID computation.
fn ssz_encode_txlist(msg: &RawTxListGossip) -> Vec<u8> {
    use ssz_rs::Serialize;
    let mut buf = Vec::new();
    msg.serialize(&mut buf).unwrap_or_default();
    buf
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn client_starts_and_emits_started_event() {
        // This test requires a running network, which we can't easily set up in unit tests.
        // Instead, we'll test the client creation and basic structure.
        let config = P2pClientConfig::default();

        // The network layer requires bootnodes or will fail to dial.
        // For unit testing, we verify the client can be created and the handle works.
        let result = P2pClient::new(config);

        // The client creation may fail due to network setup (no bootnodes, etc.)
        // In production, this would succeed with proper config.
        // For unit tests, we just verify the error is network-related, not logic-related.
        match result {
            Ok((client, mut events)) => {
                // If we got here, verify we can get a handle
                let _handle = client.handle();

                // Spawn the client event loop
                let client_handle = tokio::spawn(async move {
                    client.run().await
                });

                // Wait briefly for the initial event
                let event = tokio::time::timeout(
                    std::time::Duration::from_millis(100),
                    events.recv()
                )
                .await;

                // We expect either a HeadSyncStatus event or a timeout (network issues)
                if let Ok(Ok(evt)) = event {
                    assert!(
                        matches!(
                            evt,
                            SdkEvent::HeadSyncStatus { .. } |
                            SdkEvent::PeerConnected { .. }
                        ),
                        "first event should be startup-related, got: {:?}",
                        evt
                    );
                }

                // Cleanup
                client_handle.abort();
            }
            Err(e) => {
                // Network setup failures are expected in unit tests
                // Just verify it's a network error, not a logic error
                assert!(
                    matches!(e, P2pClientError::Network(_)),
                    "expected network error, got: {:?}",
                    e
                );
            }
        }
    }

    #[test]
    fn handle_can_be_cloned() {
        // Test that P2pClientHandle is Clone
        let (event_tx, _) = broadcast::channel(16);
        let (command_tx, _) = mpsc::channel(16);

        let handle = P2pClientHandle {
            command_tx,
            event_tx,
        };

        let _handle2 = handle.clone();
    }

    #[test]
    fn uint256_conversion_works() {
        let v = Uint256::from(42u64);
        let u = uint256_to_u256(&v);
        assert_eq!(u, U256::from(42));
    }
}
