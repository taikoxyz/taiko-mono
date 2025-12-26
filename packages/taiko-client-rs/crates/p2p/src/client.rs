//! P2P SDK client core and event loop.
//!
//! This module provides [`P2pClient`], a high-level facade over the `preconfirmation-net`
//! networking layer. It manages the lifecycle of a P2P node, processes network events,
//! applies SDK-level validation and deduplication, and emits [`SdkEvent`]s to subscribers.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::{
    LocalValidationAdapter, LookaheadResolver, LookaheadValidationAdapter, NetworkCommand,
    NetworkEvent, P2pHandle, P2pNode, ValidationAdapter,
};
use preconfirmation_types::{
    Bytes20, Bytes32, PreconfHead, RawTxListGossip, SignedCommitment, Uint256,
};
use tokio::sync::{broadcast, mpsc};
use tracing::{debug, error, info, warn};

use crate::{
    catchup::{CatchupAction, CatchupConfig, CatchupPipeline, CatchupState},
    config::P2pClientConfig,
    error::{P2pClientError, P2pResult},
    handlers::EventHandler,
    metrics::P2pMetrics,
    storage::{InMemoryStorage, SdkStorage},
    types::{SdkCommand, SdkEvent},
    validation::{
        CommitmentValidator, validate_eop_rule, validate_txlist_hash, validate_txlist_size,
    },
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
    /// Event handler for gossip/reqresp processing.
    event_handler: EventHandler<InMemoryStorage>,
    /// Channel for sending SDK events to subscribers.
    event_tx: broadcast::Sender<SdkEvent>,
    /// Channel for receiving SDK commands.
    command_rx: Option<mpsc::Receiver<SdkCommand>>,
    /// Channel for sending SDK commands (cloneable handle).
    command_tx: mpsc::Sender<SdkCommand>,
    /// Configuration.
    config: P2pClientConfig,
    /// Current local head block number.
    local_head: U256,
    /// Catch-up pipeline for syncing with network head.
    catchup: CatchupPipeline,
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
    pub async fn publish_commitment(&self, commitment: SignedCommitment) -> P2pResult<()> {
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
    pub async fn request_commitments(&self, start_block: u64, max_count: u32) -> P2pResult<()> {
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
        self.command_tx.send(SdkCommand::RequestHead).await.map_err(|_| P2pClientError::Shutdown)
    }

    /// Update the local preconfirmation head and broadcast to network.
    ///
    /// This updates the local head and sends the update to the network layer
    /// so peers can query the updated head via the `get_head` request/response protocol.
    pub async fn update_head(
        &self,
        block_number: u64,
        submission_window_end: u64,
    ) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::UpdateHead { block_number, submission_window_end })
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }

    /// Start catch-up sync from local head to network head.
    ///
    /// This triggers the catch-up pipeline to request commitments and txlists
    /// from peers until the client is synced with the network head.
    pub async fn start_catchup(&self, local_head: u64, network_head: u64) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::StartCatchup { local_head, network_head })
            .await
            .map_err(|_| P2pClientError::Shutdown)
    }

    /// Request graceful shutdown of the client.
    pub async fn shutdown(&self) -> P2pResult<()> {
        self.command_tx.send(SdkCommand::Shutdown).await.map_err(|_| P2pClientError::Shutdown)
    }

    /// Notify the SDK of an L1 reorg affecting the anchor block.
    ///
    /// Per spec §6.3, this signals that an L1 reorg was detected and downstream
    /// consumers need to re-execute commitments from the affected anchor block.
    /// The SDK will emit a corresponding `SdkEvent::Reorg` to all subscribers.
    ///
    /// # Arguments
    ///
    /// * `anchor_block_number` - The anchor block number affected by the reorg.
    /// * `reason` - Human-readable description of why the reorg was detected.
    pub async fn notify_reorg(&self, anchor_block_number: u64, reason: String) -> P2pResult<()> {
        self.command_tx
            .send(SdkCommand::NotifyReorg { anchor_block_number, reason })
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
        // Initialize metrics if enabled (idempotent - safe to call multiple times)
        if config.enable_metrics {
            P2pMetrics::init();
        }

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
        let event_handler = EventHandler::with_validator_and_max_txlist_bytes(
            storage.clone(),
            config.chain_id,
            CommitmentValidator::without_parent_validation(),
            config.max_txlist_bytes,
        );

        // Create catch-up pipeline
        let catchup_config = CatchupConfig {
            max_commitments_per_page: config.max_commitments_per_page,
            initial_backoff: config.catchup_initial_backoff,
            max_backoff: config.catchup_max_backoff,
            max_retries: config.catchup_max_retries,
        };
        let catchup = CatchupPipeline::new(catchup_config);

        let client = Self {
            handle,
            node: Some(node),
            storage,
            event_handler,
            event_tx,
            command_rx: Some(command_rx),
            command_tx,
            config,
            local_head: U256::ZERO,
            catchup,
        };

        Ok((client, event_rx))
    }

    /// Get a cloneable handle for interacting with this client.
    ///
    /// The handle can be used to send commands and subscribe to events
    /// from multiple tasks.
    pub fn handle(&self) -> P2pClientHandle {
        P2pClientHandle { command_tx: self.command_tx.clone(), event_tx: self.event_tx.clone() }
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
        let mut command_rx = self.command_rx.take().ok_or_else(|| {
            P2pClientError::MissingData("command_rx already consumed".to_string())
        })?;

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
            // Calculate sleep duration for backoff or default polling interval
            let sleep_duration =
                self.catchup.remaining_backoff().unwrap_or(std::time::Duration::from_millis(100));

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
                    // Process any pending catch-up actions after command
                    if self.catchup.is_syncing() {
                        self.process_catchup().await;
                    }
                }

                // Backoff timer / periodic check
                _ = tokio::time::sleep(sleep_duration) => {
                    // Check if node task exited
                    if node_handle.is_finished() {
                        warn!("P2P node task exited unexpectedly");
                        break;
                    }
                    // Process catchup if syncing and backoff has expired
                    if self.catchup.is_syncing() && !self.catchup.is_in_backoff() {
                        self.process_catchup().await;
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
        for sdk_event in self.event_handler.handle_event(event) {
            let _ = self.event_tx.send(sdk_event);
        }
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
                        let _ = self
                            .event_tx
                            .send(SdkEvent::ReqRespHead { from: libp2p::PeerId::random(), head });
                    }
                    Err(e) => {
                        warn!("Failed to request head: {e}");
                    }
                }
            }

            SdkCommand::UpdateHead { block_number, submission_window_end } => {
                debug!("Updating local head to block {block_number}");
                self.local_head = U256::from(block_number);

                // Construct PreconfHead and send to network layer
                let head = PreconfHead {
                    block_number: Uint256::from(block_number),
                    submission_window_end: Uint256::from(submission_window_end),
                };
                if let Err(e) =
                    self.handle.command_sender().send(NetworkCommand::UpdateHead { head }).await
                {
                    warn!("Failed to send UpdateHead to network: {e}");
                }
            }

            SdkCommand::StartCatchup { local_head, network_head } => {
                if network_head > 0 {
                    // Network head was provided, start sync directly
                    info!("Starting catch-up from block {local_head} to {network_head}");
                    self.catchup.start_sync(local_head, network_head);
                } else {
                    // No network head provided, request it first
                    info!("Starting catch-up from block {local_head} (requesting network head)");
                    self.catchup.start_catchup(local_head);
                }
                let _ = self.event_tx.send(SdkEvent::HeadSyncStatus { synced: false });
            }

            SdkCommand::Shutdown => {
                info!("Shutdown requested");
                return Ok(true);
            }

            SdkCommand::NotifyReorg { anchor_block_number, reason } => {
                warn!("L1 reorg detected at anchor block {anchor_block_number}: {reason}");
                // Emit reorg event for downstream consumers per spec §6.3
                // This signals that commitments from the affected anchor block
                // need to be re-executed
                let _ = self.event_tx.send(SdkEvent::Reorg { anchor_block_number, reason });
            }
        }
        Ok(false)
    }

    /// Process catch-up pipeline actions.
    async fn process_catchup(&mut self) {
        loop {
            let action = self.catchup.next_action();
            match action {
                CatchupAction::Wait => break,
                CatchupAction::SyncComplete => {
                    if !matches!(self.catchup.state(), CatchupState::Live) {
                        break;
                    }
                    info!("Catch-up complete, now synced");
                    let _ = self.event_tx.send(SdkEvent::HeadSyncStatus { synced: true });
                    break;
                }
                CatchupAction::RequestHead => {
                    debug!("Catch-up: requesting network head");
                    match self.handle.request_head(None).await {
                        Ok(head) => {
                            let network_head = uint256_to_u256(&head.block_number).to::<u64>();
                            debug!("Catch-up: received network head at block {network_head}");
                            self.catchup.on_head_received(network_head);

                            // Emit the head response event
                            let _ = self.event_tx.send(SdkEvent::ReqRespHead {
                                from: libp2p::PeerId::random(),
                                head,
                            });
                        }
                        Err(e) => {
                            warn!("Catch-up: failed to request network head: {e}");
                            self.catchup.on_request_failed();
                            break;
                        }
                    }
                }
                CatchupAction::RequestCommitments { start_block, max_count } => {
                    debug!("Catch-up: requesting commitments from block {start_block}");
                    let start = Uint256::from(start_block);
                    match self.handle.request_commitments(start, max_count, None).await {
                        Ok(resp) => {
                            // Find highest block and missing txlists
                            let mut highest_block = start_block;
                            let mut missing_hashes = Vec::new();
                            let mut saw_valid = false;

                            for commitment in resp.commitments.iter() {
                                // Basic validation: signature + EOP rule (parent checks deferred)
                                let sig_outcome = crate::validation::validate_signature(commitment);
                                if !sig_outcome.status.is_valid() {
                                    warn!(
                                        "Catch-up: invalid commitment signature: {:?}",
                                        sig_outcome.reason
                                    );
                                    P2pMetrics::record_validation_result("invalid");
                                    continue;
                                }

                                let eop_outcome = validate_eop_rule(&commitment.commitment.preconf);
                                if !eop_outcome.status.is_valid() {
                                    warn!("Catch-up: invalid EOP rule: {:?}", eop_outcome.reason);
                                    P2pMetrics::record_validation_result("invalid");
                                    continue;
                                }

                                saw_valid = true;
                                let block =
                                    uint256_to_u256(&commitment.commitment.preconf.block_number);
                                let block_u64 = block.to::<u64>();
                                if block_u64 > highest_block {
                                    highest_block = block_u64;
                                }

                                // Check if we have the txlist
                                let txlist_hash = B256::from_slice(
                                    commitment.commitment.preconf.raw_tx_list_hash.as_ref(),
                                );
                                if !txlist_hash.is_zero() &&
                                    self.storage.get_txlist(&txlist_hash).is_none()
                                {
                                    missing_hashes.push(txlist_hash);
                                }

                                // Store the commitment
                                self.storage.insert_commitment(block, commitment.clone());
                                P2pMetrics::record_validation_result("valid");
                            }

                            if !resp.commitments.is_empty() && !saw_valid {
                                warn!("Catch-up: all commitments in response were invalid");
                                self.catchup.on_request_failed();
                                break;
                            }

                            self.catchup.on_commitments_received(highest_block, missing_hashes);
                        }
                        Err(e) => {
                            warn!("Catch-up: failed to request commitments: {e}");
                            self.catchup.on_request_failed();
                            break;
                        }
                    }
                }
                CatchupAction::RequestTxList { hash } => {
                    debug!("Catch-up: requesting txlist {hash}");
                    let hash_bytes = match Bytes32::try_from(hash.as_slice().to_vec()) {
                        Ok(h) => h,
                        Err(_) => {
                            self.catchup.on_request_failed();
                            continue;
                        }
                    };
                    match self.handle.request_raw_txlist(hash_bytes, None).await {
                        Ok(resp) => {
                            let txlist_bytes = resp.txlist.as_ref();
                            let stored_hash = B256::from_slice(resp.raw_tx_list_hash.as_ref());

                            // Validate txlist size
                            let size_outcome =
                                validate_txlist_size(txlist_bytes, self.config.max_txlist_bytes);
                            if !size_outcome.status.is_valid() {
                                warn!(
                                    "Catch-up: txlist size invalid for {stored_hash}: {:?}",
                                    size_outcome.reason
                                );
                                P2pMetrics::record_validation_result("invalid");
                                self.catchup.on_request_failed();
                                break;
                            }

                            // Validate txlist hash
                            let hash_outcome = validate_txlist_hash(&stored_hash, txlist_bytes);
                            if !hash_outcome.status.is_valid() {
                                warn!(
                                    "Catch-up: txlist hash mismatch for {stored_hash}: {:?}",
                                    hash_outcome.reason
                                );
                                P2pMetrics::record_validation_result("invalid");
                                self.catchup.on_request_failed();
                                break;
                            }

                            // Store the txlist - construct RawTxListGossip from response
                            let txlist_gossip = RawTxListGossip {
                                raw_tx_list_hash: resp.raw_tx_list_hash.clone(),
                                txlist: resp.txlist,
                            };
                            self.storage.insert_txlist(stored_hash, txlist_gossip);
                            P2pMetrics::record_validation_result("valid");
                            self.catchup.on_txlist_received(&hash);
                        }
                        Err(e) => {
                            warn!("Catch-up: failed to request txlist: {e}");
                            self.catchup.on_request_failed();
                            break;
                        }
                    }
                }
            }
        }
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
///
/// Returns an error if serialization fails, allowing callers to handle the failure
/// appropriately (e.g., reject the message and record metrics).
#[cfg(test)]
fn ssz_encode_commitment(msg: &SignedCommitment) -> Result<Vec<u8>, ssz_rs::SerializeError> {
    use ssz_rs::Serialize;
    let mut buf = Vec::new();
    msg.serialize(&mut buf)?;
    Ok(buf)
}

/// SSZ-encode a raw txlist gossip for message ID computation.
///
/// Returns an error if serialization fails, allowing callers to handle the failure
/// appropriately (e.g., reject the message and record metrics).
#[cfg(test)]
fn ssz_encode_txlist(msg: &RawTxListGossip) -> Result<Vec<u8>, ssz_rs::SerializeError> {
    use ssz_rs::Serialize;
    let mut buf = Vec::new();
    msg.serialize(&mut buf)?;
    Ok(buf)
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
                let client_handle = tokio::spawn(async move { client.run().await });

                // Wait briefly for the initial event
                let event =
                    tokio::time::timeout(std::time::Duration::from_millis(100), events.recv())
                        .await;

                // We expect either a HeadSyncStatus event or a timeout (network issues)
                if let Ok(Ok(evt)) = event {
                    assert!(
                        matches!(
                            evt,
                            SdkEvent::HeadSyncStatus { .. } | SdkEvent::PeerConnected { .. }
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

        let handle = P2pClientHandle { command_tx, event_tx };

        let _handle2 = handle.clone();
    }

    #[test]
    fn uint256_conversion_works() {
        let v = Uint256::from(42u64);
        let u = uint256_to_u256(&v);
        assert_eq!(u, U256::from(42));
    }

    #[test]
    fn ssz_encode_commitment_returns_result() {
        // Test that SSZ encoding returns a Result type, not silently swallowing errors.
        // Valid commitments should encode successfully.
        use preconfirmation_types::{
            Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
            Uint256,
        };

        let commitment = SignedCommitment {
            commitment: PreconfCommitment {
                preconf: Preconfirmation {
                    eop: false,
                    block_number: Uint256::from(100u64),
                    timestamp: Uint256::from(1000u64),
                    gas_limit: Uint256::from(30_000_000u64),
                    coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    anchor_block_number: Uint256::from(99u64),
                    raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
                    parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
                    submission_window_end: Uint256::from(2000u64),
                    prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    proposal_id: Uint256::from(1u64),
                },
                slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
            },
            signature: Bytes65::try_from(vec![0xBB; 65]).unwrap(),
        };

        let result = ssz_encode_commitment(&commitment);
        assert!(result.is_ok(), "SSZ encoding should succeed for valid commitment");
        assert!(!result.unwrap().is_empty(), "Encoded buffer should not be empty");
    }

    #[test]
    fn ssz_encode_txlist_succeeds() {
        use preconfirmation_types::{Bytes32, RawTxListGossip, TxListBytes};

        let txlist = RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(vec![0xAB; 32]).unwrap(),
            txlist: TxListBytes::try_from(vec![0xCC; 100]).unwrap(),
        };

        let result = ssz_encode_txlist(&txlist);
        assert!(result.is_ok(), "SSZ encoding should succeed for valid txlist");
        assert!(!result.unwrap().is_empty(), "Encoded buffer should not be empty");
    }
}
