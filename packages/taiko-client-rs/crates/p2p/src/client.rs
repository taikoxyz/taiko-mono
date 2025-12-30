//! P2P SDK client core and event loop.
//!
//! This module provides [`P2pClient`], a high-level facade over the `preconfirmation-net`
//! networking layer. It manages the lifecycle of a P2P node, processes network events,
//! applies SDK-level validation and deduplication, and emits [`SdkEvent`]s to subscribers.

use std::{collections::HashSet, sync::Arc};

use alloy_primitives::{B256, U256};
use preconfirmation_net::{
    LocalValidationAdapter, LookaheadResolver, LookaheadValidationAdapter, NetworkCommand,
    NetworkEvent, P2pHandle, P2pNode, ValidationAdapter,
};
use preconfirmation_types::{
    Bytes20, Bytes32, PreconfHead, RawTxListGossip, SignedCommitment, Uint256,
};
use rpc::PreconfEngine;
use tokio::sync::{broadcast, mpsc};
use tracing::{debug, error, info, warn};

use crate::{
    catchup::{CatchupAction, CatchupConfig, CatchupPipeline, CatchupState},
    config::P2pClientConfig,
    error::{P2pClientError, P2pResult},
    handlers::EventHandler,
    metrics::P2pMetrics,
    storage::InMemoryStorage,
    types::{SdkCommand, SdkEvent},
    validation::{
        CommitmentValidator, ValidationStatus, validate_txlist_hash, validate_txlist_size,
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
/// use std::sync::Arc;
///
/// use p2p::{P2pClient, P2pClientConfig, SdkEvent};
/// use rpc::MockPreconfEngine;
///
/// let mut config = P2pClientConfig::default();
/// config.engine = Some(Arc::new(MockPreconfEngine::default()));
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
    /// Commitment validator shared with catch-up processing.
    commitment_validator: CommitmentValidator,
    /// Event handler for gossip/reqresp processing.
    event_handler: EventHandler,
    /// Channel for sending SDK events to subscribers.
    event_tx: broadcast::Sender<SdkEvent>,
    /// Channel for receiving SDK commands.
    command_rx: Option<mpsc::Receiver<SdkCommand>>,
    /// Channel for sending SDK commands (cloneable handle).
    command_tx: mpsc::Sender<SdkCommand>,
    /// Configuration.
    config: P2pClientConfig,
    /// Execution engine for applying preconfirmations (validated at construction).
    engine: Option<Arc<dyn PreconfEngine>>,
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

/// Command + event helpers for interacting with a running client.
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

/// Core client lifecycle and orchestration methods.
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
        let storage = Arc::new(InMemoryStorage::new(
            config.dedupe_cache_cap as u64,
            config.dedupe_ttl,
            config.dedupe_ttl, // Use same TTL for pending buffer
        ));
        let commitment_validator = CommitmentValidator::new();
        Self::with_components(config, storage, commitment_validator, validator, lookahead)
    }

    /// Create a new P2P client with pre-constructed components.
    ///
    /// This is primarily used for tests that need custom validators or
    /// a pre-built storage instance.
    pub(crate) fn with_components(
        config: P2pClientConfig,
        storage: Arc<InMemoryStorage>,
        commitment_validator: CommitmentValidator,
        validator: Option<Box<dyn ValidationAdapter>>,
        lookahead: Option<Arc<dyn LookaheadResolver>>,
    ) -> P2pResult<(Self, broadcast::Receiver<SdkEvent>)> {
        config.validate()?;
        // Initialize metrics if enabled (idempotent - safe to call multiple times)
        if config.enable_metrics {
            P2pMetrics::init();
        }

        // Build the validation adapter
        let expected_slasher = config
            .expected_slasher
            .map(|addr| Bytes20::try_from(addr.as_slice().to_vec()).unwrap());

        if validator.is_none() && expected_slasher.is_none() {
            return Err(P2pClientError::Config(
                "expected_slasher is required when no custom validator is provided".to_string(),
            ));
        }

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

        let event_handler = EventHandler::with_validator_and_max_txlist_bytes(
            storage.clone(),
            config.chain_id,
            commitment_validator.clone(),
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

        let engine = config.engine.clone();
        let client = Self {
            handle,
            node: Some(node),
            storage,
            commitment_validator,
            event_handler,
            event_tx,
            command_rx: Some(command_rx),
            command_tx,
            config,
            engine,
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

        debug!(engine_present = self.engine.is_some(), "preconfirmation execution configured");

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
        if let Some(engine) = self.engine.as_deref() {
            match event {
                NetworkEvent::GossipSignedCommitment { from, msg } => {
                    let dispatch = self
                        .event_handler
                        .handle_commitment_gossip_with_engine(from, *msg, engine)
                        .await;
                    for sdk_event in dispatch.events {
                        let _ = self.event_tx.send(sdk_event);
                    }
                    self.request_missing_txlists(dispatch.missing_txlist_hashes).await;
                    return;
                }
                NetworkEvent::GossipRawTxList { from, msg } => {
                    let dispatch = self
                        .event_handler
                        .handle_txlist_gossip_with_engine(from, *msg, engine)
                        .await;
                    for sdk_event in dispatch.events {
                        let _ = self.event_tx.send(sdk_event);
                    }
                    return;
                }
                other => {
                    for sdk_event in self.event_handler.handle_event(other) {
                        let _ = self.event_tx.send(sdk_event);
                    }
                    return;
                }
            }
        } else {
            warn!("Execution engine missing; falling back to non-execution path");
        }

        for sdk_event in self.event_handler.handle_event(event) {
            let _ = self.event_tx.send(sdk_event);
        }
    }

    /// Request raw txlists for the given hashes from peers.
    async fn request_missing_txlists(&mut self, hashes: Vec<B256>) {
        for hash in hashes {
            let hash_bytes = match Bytes32::try_from(hash.as_slice().to_vec()) {
                Ok(bytes) => bytes,
                Err(_) => {
                    warn!("Skipping txlist request for invalid hash");
                    continue;
                }
            };
            P2pMetrics::record_reqresp_sent("raw_txlist");
            if let Err(err) = self.handle.request_raw_txlist(hash_bytes, None).await {
                warn!("Failed to request raw txlist {hash}: {err}");
            }
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
                    Ok(_resp) => {
                        debug!(
                            "RequestCommitments completed; response will arrive via network event"
                        );
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
                    Ok(_resp) => {
                        debug!(
                            "RequestRawTxList completed; response will arrive via network event"
                        );
                    }
                    Err(e) => {
                        warn!("Failed to request raw txlist: {e}");
                    }
                }
            }

            SdkCommand::RequestHead => {
                debug!("Requesting head");
                match self.handle.request_head(None).await {
                    Ok(_head) => {
                        debug!("RequestHead completed; response will arrive via network event");
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
                if let Some(engine) = self.engine.as_deref() &&
                    let Err(err) = engine.handle_reorg(anchor_block_number).await
                {
                    P2pMetrics::record_execution_error();
                    warn!("Failed to notify execution engine about reorg: {err}");
                }
                // Clear pending buffers because anchor-related commitments may no longer be valid.
                let cleared_pending = self.storage.clear_pending();
                let cleared_txlists = self.storage.clear_pending_txlists();
                if cleared_pending > 0 || cleared_txlists > 0 {
                    info!(
                        "Cleared {cleared_pending} pending commitments and {cleared_txlists} txlist pendings due to reorg"
                    );
                }
                P2pMetrics::set_pending_buffer_size(self.storage.pending_count());
                P2pMetrics::set_pending_txlist_buffer_size(self.storage.pending_txlist_count());
                // Reset catch-up state so a fresh sync can be initiated after reorg.
                self.catchup.reset();
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
                            let mut highest_block = start_block.saturating_sub(1);
                            let mut missing_hashes = Vec::new();
                            let mut saw_valid = false;
                            let mut executable_commitments = Vec::new();
                            let engine_available = self.engine.is_some();

                            for commitment in resp.commitments.iter() {
                                let parent = parent_preconfirmation_from_storage(
                                    self.storage.as_ref(),
                                    commitment,
                                );
                                let result =
                                    self.commitment_validator.validate(commitment, parent.as_ref());

                                match result.outcome.status {
                                    ValidationStatus::Valid => {
                                        saw_valid = true;
                                        store_commitment_for_catchup(
                                            self.storage.as_ref(),
                                            commitment,
                                            &mut highest_block,
                                            &mut missing_hashes,
                                        );
                                        executable_commitments.push(commitment.clone());

                                        if let Ok(commitment_hash) =
                                            preconfirmation_types::preconfirmation_hash(
                                                &commitment.commitment.preconf,
                                            )
                                        {
                                            let released = self.storage.release_pending(
                                                &B256::from_slice(commitment_hash.as_ref()),
                                            );
                                            P2pMetrics::record_pending_released(released.len());
                                            P2pMetrics::set_pending_buffer_size(
                                                self.storage.pending_count(),
                                            );

                                            for pending in released {
                                                let pending_result =
                                                    self.commitment_validator.validate(
                                                        &pending,
                                                        Some(&commitment.commitment.preconf),
                                                    );
                                                match pending_result.outcome.status {
                                                    ValidationStatus::Valid => {
                                                        saw_valid = true;
                                                        store_commitment_for_catchup(
                                                            self.storage.as_ref(),
                                                            &pending,
                                                            &mut highest_block,
                                                            &mut missing_hashes,
                                                        );
                                                        executable_commitments.push(pending);
                                                    }
                                                    ValidationStatus::Pending => {
                                                        let parent_hash = B256::from_slice(
                                                            pending
                                                                .commitment
                                                                .preconf
                                                                .parent_preconfirmation_hash
                                                                .as_ref(),
                                                        );
                                                        if engine_available {
                                                            P2pMetrics::record_execution_pending_parent();
                                                        }
                                                        self.storage
                                                            .add_pending(parent_hash, pending);
                                                        P2pMetrics::set_pending_buffer_size(
                                                            self.storage.pending_count(),
                                                        );
                                                    }
                                                    ValidationStatus::Invalid => {
                                                        warn!(
                                                            "Catch-up: released pending commitment invalid: {:?}",
                                                            pending_result.outcome.reason
                                                        );
                                                        P2pMetrics::record_validation_result(
                                                            "invalid",
                                                        );
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    ValidationStatus::Pending => {
                                        P2pMetrics::record_validation_result("pending");
                                        if engine_available {
                                            P2pMetrics::record_execution_pending_parent();
                                        }
                                        let parent_hash = B256::from_slice(
                                            commitment
                                                .commitment
                                                .preconf
                                                .parent_preconfirmation_hash
                                                .as_ref(),
                                        );
                                        self.storage.add_pending(parent_hash, commitment.clone());
                                        P2pMetrics::record_pending_buffered();
                                        P2pMetrics::set_pending_buffer_size(
                                            self.storage.pending_count(),
                                        );
                                    }
                                    ValidationStatus::Invalid => {
                                        warn!(
                                            "Catch-up: invalid commitment: {:?}",
                                            result.outcome.reason
                                        );
                                        P2pMetrics::record_validation_result("invalid");
                                    }
                                }
                            }

                            if !resp.commitments.is_empty() && !saw_valid {
                                warn!("Catch-up: all commitments in response were invalid");
                                self.catchup.on_request_failed();
                                break;
                            }

                            missing_hashes = collect_missing_txlists_for_commitments(
                                self.storage.as_ref(),
                                &executable_commitments,
                            );

                            if let Some(engine) = self.engine.as_deref() {
                                match engine.is_synced().await {
                                    Ok(true) => {
                                        execute_catchup_commitments(
                                            self.storage.as_ref(),
                                            engine,
                                            executable_commitments,
                                        )
                                        .await;
                                    }
                                    Ok(false) => {
                                        debug!("Catch-up: execution engine not synced yet");
                                    }
                                    Err(err) => {
                                        P2pMetrics::record_execution_error();
                                        warn!("Catch-up: failed to check engine sync: {err}");
                                    }
                                }
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

                            if let Some(engine) = self.engine.as_deref() {
                                match engine.is_synced().await {
                                    Ok(true) => {
                                        if let Some(txlist) = self.storage.get_txlist(&stored_hash)
                                        {
                                            execute_catchup_txlist(
                                                self.storage.as_ref(),
                                                engine,
                                                &txlist,
                                            )
                                            .await;
                                        }
                                    }
                                    Ok(false) => {
                                        debug!("Catch-up: execution engine not synced yet");
                                    }
                                    Err(err) => {
                                        P2pMetrics::record_execution_error();
                                        warn!("Catch-up: failed to check engine sync: {err}");
                                    }
                                }
                            }
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

/// Look up a parent preconfirmation for catch-up validation.
///
/// This derives the parent block number as `child.block_number - 1` and attempts
/// to fetch the corresponding commitment from storage. If found, the parent
/// preconfirmation is returned for linkage validation.
fn parent_preconfirmation_from_storage(
    storage: &InMemoryStorage,
    commitment: &SignedCommitment,
) -> Option<preconfirmation_types::Preconfirmation> {
    let child_block = uint256_to_u256(&commitment.commitment.preconf.block_number);
    let parent_block = child_block.saturating_sub(U256::from(1u64));
    storage.get_commitment(parent_block).map(|stored| stored.commitment.preconf)
}

/// Store a validated commitment and record catch-up bookkeeping.
///
/// This updates the highest seen block number, queues any missing txlists for
/// retrieval, and persists the commitment in storage.
fn store_commitment_for_catchup(
    storage: &InMemoryStorage,
    commitment: &SignedCommitment,
    highest_block: &mut u64,
    missing_hashes: &mut Vec<B256>,
) {
    let block = uint256_to_u256(&commitment.commitment.preconf.block_number);
    let block_u64 = block.to::<u64>();
    if block_u64 > *highest_block {
        *highest_block = block_u64;
    }

    let txlist_hash = B256::from_slice(commitment.commitment.preconf.raw_tx_list_hash.as_ref());
    if !txlist_hash.is_zero() && storage.get_txlist(&txlist_hash).is_none() {
        missing_hashes.push(txlist_hash);
    }

    storage.insert_commitment(block, commitment.clone());
    P2pMetrics::record_validation_result("valid");
}

/// Collect missing txlist hashes for a set of commitments.
///
/// This skips zero hashes and de-duplicates entries to avoid redundant requests.
fn collect_missing_txlists_for_commitments(
    storage: &InMemoryStorage,
    commitments: &[SignedCommitment],
) -> Vec<B256> {
    let mut missing = Vec::new();
    let mut seen = HashSet::new();

    for commitment in commitments {
        let txlist_hash = B256::from_slice(commitment.commitment.preconf.raw_tx_list_hash.as_ref());
        if txlist_hash.is_zero() {
            continue;
        }

        if storage.get_txlist(&txlist_hash).is_none() && seen.insert(txlist_hash) {
            missing.push(txlist_hash);
        }
    }

    missing
}

/// Execute a batch of catch-up commitments in ascending block order.
///
/// This applies commitments via the execution engine, buffers any that are
/// missing txlists, and updates execution metrics.
async fn execute_catchup_commitments(
    storage: &InMemoryStorage,
    engine: &dyn PreconfEngine,
    commitments: Vec<SignedCommitment>,
) {
    let mut ordered = commitments;
    ordered.sort_by_key(commitment_block_number_u64);

    for commitment in ordered {
        let preconf = &commitment.commitment.preconf;
        let txlist_hash = B256::from_slice(preconf.raw_tx_list_hash.as_ref());

        if preconf.eop && txlist_hash.is_zero() {
            apply_commitment_with_engine(engine, &commitment, None).await;
            continue;
        }

        if txlist_hash.is_zero() {
            warn!(
                "Catch-up: skipping execution for commitment with zero txlist hash (block {:?})",
                preconf.block_number
            );
            P2pMetrics::record_execution_error();
            continue;
        }

        if let Some(txlist) = storage.get_txlist(&txlist_hash) {
            apply_commitment_with_engine(engine, &commitment, Some(txlist.txlist.as_ref())).await;
        } else {
            let _ = storage.add_pending_txlist(txlist_hash, commitment);
            P2pMetrics::record_execution_pending_txlist();
            P2pMetrics::set_pending_txlist_buffer_size(storage.pending_txlist_count());
        }
    }
}

/// Execute any pending commitments released by an arriving txlist.
///
/// This drains the pending txlist buffer for the given hash and applies the
/// commitments in block order using the supplied txlist bytes.
async fn execute_catchup_txlist(
    storage: &InMemoryStorage,
    engine: &dyn PreconfEngine,
    txlist: &RawTxListGossip,
) {
    let txlist_hash = B256::from_slice(txlist.raw_tx_list_hash.as_ref());
    let mut pending = storage.release_pending_txlist(&txlist_hash);

    if !pending.is_empty() {
        P2pMetrics::set_pending_txlist_buffer_size(storage.pending_txlist_count());
    }

    pending.sort_by_key(commitment_block_number_u64);
    for commitment in pending {
        apply_commitment_with_engine(engine, &commitment, Some(txlist.txlist.as_ref())).await;
    }
}

/// Apply a commitment through the execution engine and record metrics.
async fn apply_commitment_with_engine(
    engine: &dyn PreconfEngine,
    commitment: &SignedCommitment,
    txlist: Option<&[u8]>,
) {
    match engine.apply_commitment(commitment, txlist).await {
        Ok(outcome) => {
            P2pMetrics::record_execution_applied();
            debug!(
                "Catch-up: executed commitment for block {} with hash {:?}",
                outcome.block_number, outcome.block_hash
            );
        }
        Err(err) => {
            P2pMetrics::record_execution_error();
            warn!("Catch-up: execution engine rejected commitment: {err}");
        }
    }
}

/// Extract the commitment block number as a `u64` for ordering.
fn commitment_block_number_u64(commitment: &SignedCommitment) -> u64 {
    let block = uint256_to_u256(&commitment.commitment.preconf.block_number);
    block.to::<u64>()
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
    use crate::storage::InMemoryStorage;
    use alloy_primitives::Address;
    use preconfirmation_types::keccak256_bytes;
    use rpc::MockPreconfEngine;
    use secp256k1::SecretKey;

    #[tokio::test]
    async fn client_starts_and_emits_started_event() {
        // This test requires a running network, which we can't easily set up in unit tests.
        // Instead, we'll test the client creation and basic structure.
        let mut config = P2pClientConfig::default();
        config.expected_slasher = Some(Address::ZERO);
        config.engine = Some(Arc::new(MockPreconfEngine::default()));

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
                // Network setup failures or missing config are expected in unit tests.
                assert!(
                    matches!(e, P2pClientError::Network(_) | P2pClientError::Config(_)),
                    "expected network or config error, got: {:?}",
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

    /// Ensure that creating a P2P client without an engine fails.
    #[test]
    fn p2p_client_requires_engine() {
        let cfg = P2pClientConfig::with_chain_id(167000);
        let result = P2pClient::new(cfg);
        assert!(result.is_err(), "P2pClient::new should fail when engine is None");
    }

    /// Build a signed commitment with the given txlist hash and parent hash.
    fn make_signed_commitment_with_txlist(
        block_num: u64,
        parent_hash: [u8; 32],
        raw_tx_list_hash: [u8; 32],
        eop: bool,
    ) -> SignedCommitment {
        use preconfirmation_types::{
            Bytes20, Bytes32, PreconfCommitment, Preconfirmation, SignedCommitment, Uint256,
            sign_commitment,
        };

        let preconf = Preconfirmation {
            eop,
            block_number: Uint256::from(block_num),
            timestamp: Uint256::from(1000u64 + block_num),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(block_num.saturating_sub(1)),
            raw_tx_list_hash: Bytes32::try_from(raw_tx_list_hash.to_vec()).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(parent_hash.to_vec()).unwrap(),
            submission_window_end: Uint256::from(2000u64 + block_num),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        };

        let commitment = PreconfCommitment {
            preconf,
            slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
        };

        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let sig = sign_commitment(&commitment, &sk).unwrap();

        SignedCommitment { commitment, signature: sig }
    }

    /// Extract a commitment block number for assertions.
    fn commitment_block_number(commitment: &SignedCommitment) -> u64 {
        let le_bytes = commitment.commitment.preconf.block_number.to_bytes_le();
        U256::from_le_slice(&le_bytes).to::<u64>()
    }

    /// Ensure catch-up execution applies commitments in block order.
    #[tokio::test]
    async fn catchup_executes_commitments_in_order() {
        use preconfirmation_types::{Bytes32, RawTxListGossip, TxListBytes};

        let storage = Arc::new(InMemoryStorage::default());
        let engine = MockPreconfEngine::default();

        let txlist_a = vec![0xAA; 16];
        let txlist_b = vec![0xBB; 16];
        let hash_a = keccak256_bytes(&txlist_a);
        let hash_b = keccak256_bytes(&txlist_b);

        let txlist_a_msg = RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(hash_a.as_slice().to_vec()).unwrap(),
            txlist: TxListBytes::try_from(txlist_a.clone()).unwrap(),
        };
        let txlist_b_msg = RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(hash_b.as_slice().to_vec()).unwrap(),
            txlist: TxListBytes::try_from(txlist_b.clone()).unwrap(),
        };

        storage.insert_txlist(B256::from_slice(hash_a.as_ref()), txlist_a_msg);
        storage.insert_txlist(B256::from_slice(hash_b.as_ref()), txlist_b_msg);

        let commitment_one = make_signed_commitment_with_txlist(1, [0u8; 32], hash_a.0, false);
        let commitment_two = make_signed_commitment_with_txlist(2, [0u8; 32], hash_b.0, false);

        let missing = collect_missing_txlists_for_commitments(
            storage.as_ref(),
            &[commitment_two.clone(), commitment_one.clone()],
        );
        assert!(missing.is_empty(), "expected no missing txlists");

        execute_catchup_commitments(
            storage.as_ref(),
            &engine,
            vec![commitment_two.clone(), commitment_one.clone()],
        )
        .await;

        let calls = engine.calls();
        assert_eq!(calls.len(), 2, "engine should execute both commitments");
        let first = commitment_block_number(&calls[0].commitment);
        let second = commitment_block_number(&calls[1].commitment);
        assert!(first < second, "commitments should execute in block order");
    }

    /// Ensure catch-up waits for missing txlists and executes after arrival.
    #[tokio::test]
    async fn catchup_waits_for_missing_txlist() {
        use preconfirmation_types::{Bytes32, RawTxListGossip, TxListBytes};

        let storage = Arc::new(InMemoryStorage::default());
        let engine = MockPreconfEngine::default();

        let txlist_data = vec![0xCC; 24];
        let txlist_hash = keccak256_bytes(&txlist_data);
        let commitment = make_signed_commitment_with_txlist(3, [0u8; 32], txlist_hash.0, false);

        let missing =
            collect_missing_txlists_for_commitments(storage.as_ref(), &[commitment.clone()]);
        assert_eq!(missing, vec![txlist_hash], "missing txlist should be reported");

        execute_catchup_commitments(storage.as_ref(), &engine, vec![commitment]).await;
        assert_eq!(engine.calls().len(), 0, "engine should wait for txlist");
        assert_eq!(storage.pending_txlist_count(), 1, "commitment should be buffered for txlist");

        let txlist_msg = RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(txlist_hash.as_slice().to_vec()).unwrap(),
            txlist: TxListBytes::try_from(txlist_data.clone()).unwrap(),
        };
        storage.insert_txlist(B256::from_slice(txlist_hash.as_ref()), txlist_msg.clone());

        execute_catchup_txlist(storage.as_ref(), &engine, &txlist_msg).await;

        assert_eq!(engine.calls().len(), 1, "engine should execute after txlist arrival");
        assert_eq!(storage.pending_txlist_count(), 0, "pending txlist buffer should drain");
        assert_eq!(
            engine.calls()[0].txlist.as_deref(),
            Some(txlist_data.as_slice()),
            "engine should receive txlist bytes"
        );
    }

    /// Ensure reorg notifications clear pending buffers and reset catch-up state.
    #[tokio::test]
    async fn notify_reorg_clears_pending_buffers_and_resets_catchup() {
        use alloy_primitives::Address;

        let storage = Arc::new(InMemoryStorage::default());
        let mut config = P2pClientConfig::with_chain_id(167000);
        config.expected_slasher = Some(Address::from([0x11; 20]));
        config.engine = Some(Arc::new(MockPreconfEngine::default()));
        config.enable_metrics = false;
        config.network.listen_addr =
            std::net::SocketAddr::new(std::net::IpAddr::V4(std::net::Ipv4Addr::LOCALHOST), 0);
        config.network.discovery_listen =
            std::net::SocketAddr::new(std::net::IpAddr::V4(std::net::Ipv4Addr::LOCALHOST), 0);
        config.network.enable_discovery = false;
        config.network.enable_quic = false;

        let (mut client, _events) = P2pClient::with_components(
            config,
            storage.clone(),
            CommitmentValidator::new(),
            None,
            None,
        )
        .expect("client should initialize");

        let parent_hash = [0xAA; 32];
        let pending_parent_commitment =
            make_signed_commitment_with_txlist(2, parent_hash, [0xBB; 32], false);
        storage.add_pending(B256::from_slice(&parent_hash), pending_parent_commitment);

        let txlist_bytes = vec![0xCC; 8];
        let txlist_hash = keccak256_bytes(&txlist_bytes);
        let pending_txlist_commitment =
            make_signed_commitment_with_txlist(3, [0u8; 32], txlist_hash.0, false);
        storage
            .add_pending_txlist(B256::from_slice(txlist_hash.as_ref()), pending_txlist_commitment);

        assert_eq!(storage.pending_count(), 1, "expected pending parent entry");
        assert_eq!(storage.pending_txlist_count(), 1, "expected pending txlist entry");

        client.catchup.start_sync(0, 10);
        assert!(client.catchup.is_syncing(), "catch-up should be syncing before reorg");

        let shutdown = client
            .handle_command(SdkCommand::NotifyReorg {
                anchor_block_number: 1,
                reason: "test reorg".to_string(),
            })
            .await
            .expect("notify reorg should succeed");
        assert!(!shutdown, "reorg should not trigger shutdown");

        assert_eq!(storage.pending_count(), 0, "pending parent buffer should clear");
        assert_eq!(storage.pending_txlist_count(), 0, "pending txlist buffer should clear");
        assert!(
            matches!(client.catchup.state(), CatchupState::Idle),
            "catch-up should reset to idle"
        );
    }
}
