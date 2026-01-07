//! Main preconfirmation client implementation.
//!
//! This module provides the `PreconfirmationClient` which orchestrates:
//! - P2P node management
//! - Tip catch-up after normal sync
//! - Event handling for gossip subscriptions
//! - Submitting preconfirmation inputs to the driver

use std::{future::Future, sync::Arc};

use tokio::sync::{RwLock, broadcast};
use tokio_stream::StreamExt;
use tracing::{error, info};

use preconfirmation_net::{
    LocalValidationAdapter, NetworkCommand, P2pHandle, P2pNode, ValidationAdapter,
};
use preconfirmation_types::MAX_TXLIST_BYTES;

use crate::{
    codec::{TxListCodec, ZlibTxListCodec},
    config::PreconfirmationClientConfig,
    driver_interface::DriverSubmitter,
    error::{PreconfirmationClientError, Result},
    publish::PreconfirmationPublisher,
    state::PreconfirmationState,
    storage::{
        CommitmentStore, InMemoryCommitmentStore, PendingCommitmentBuffer, PendingTxListBuffer,
    },
    subscription::{EventHandler, EventHandlerDeps, PreconfirmationEvent},
    sync::tip_catchup::TipCatchup,
};

/// The main preconfirmation client.
///
/// This client manages the P2P network connection, handles gossip events,
/// performs tip catch-up synchronization, and submits preconfirmation inputs
/// to the driver.
///
/// **Important:** The SDK does NOT call the engine API directly. It constructs
/// `PreconfirmationInput` and hands it to the driver via the `DriverSubmitter` trait.
pub struct PreconfirmationClient<D>
where
    D: DriverSubmitter + 'static,
{
    /// Client configuration.
    config: PreconfirmationClientConfig,
    /// Shared client state (head, sync status, peers).
    state: Arc<RwLock<PreconfirmationState>>,
    /// Commitment store.
    store: Arc<dyn CommitmentStore>,
    /// Pending commitment buffer for missing parents.
    pending_parents: Arc<PendingCommitmentBuffer>,
    /// Pending commitment buffer for missing txlists.
    pending_txlists: Arc<PendingTxListBuffer>,
    /// Txlist codec for decompression.
    codec: Arc<dyn TxListCodec>,
    /// Driver submitter.
    driver: Arc<D>,
    /// Command sender for publishing and req/resp.
    command_sender: tokio::sync::mpsc::Sender<NetworkCommand>,
    /// Optional P2P handle used by the event loop.
    handle: Option<P2pHandle>,
    /// Optional P2P node used to run the network driver.
    node: Option<P2pNode>,
    /// Broadcast channel for outbound events.
    event_tx: broadcast::Sender<PreconfirmationEvent>,
}

impl<D> PreconfirmationClient<D>
where
    D: DriverSubmitter + 'static,
{
    /// Create a new preconfirmation client and underlying P2P node.
    pub fn new(config: PreconfirmationClientConfig, driver: D) -> Result<Self> {
        // Build the commitment store.
        let store: Arc<dyn CommitmentStore> = Arc::new(InMemoryCommitmentStore::new());
        // Build the pending parent buffer.
        let pending_parents = Arc::new(PendingCommitmentBuffer::new());
        // Build the pending txlist buffer.
        let pending_txlists = Arc::new(PendingTxListBuffer::new());
        // Build the txlist codec using the protocol constant.
        let codec: Arc<dyn TxListCodec> = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        // Build the network validator.
        let validator: Box<dyn ValidationAdapter> =
            Box::new(LocalValidationAdapter::new(config.expected_slasher.clone()));
        // Create the P2P handle and node.
        let (handle, node) = P2pNode::new(config.p2p.clone(), validator)
            .map_err(|err| PreconfirmationClientError::Network(err.to_string()))?;
        // Capture the command sender for publishing.
        let command_sender = handle.command_sender();
        // Build the broadcast channel for events.
        let (event_tx, _event_rx) = broadcast::channel(16);
        // Build the shared state container.
        let state = Arc::new(RwLock::new(PreconfirmationState::default()));

        Ok(Self {
            config,
            state,
            store,
            pending_parents,
            pending_txlists,
            codec,
            driver: Arc::new(driver),
            command_sender,
            handle: Some(handle),
            node: Some(node),
            event_tx,
        })
    }

    /// Subscribe to client events.
    pub fn subscribe(&self) -> broadcast::Receiver<PreconfirmationEvent> {
        self.event_tx.subscribe()
    }

    /// Get a publisher for outbound messages.
    pub fn publisher(&self) -> PreconfirmationPublisher {
        PreconfirmationPublisher::new(self.command_sender.clone())
    }

    /// Run the client after the L2 sync has completed.
    ///
    /// This method:
    /// 1. Waits for the sync_done signal.
    /// 2. Performs tip catch-up to synchronize preconfirmation commitments.
    /// 3. Enters the event loop to process gossip events.
    pub async fn run_after_sync<F>(mut self, sync_done: F) -> Result<()>
    where
        F: Future<Output = ()>,
    {
        info!("waiting for L2 sync to complete");
        // Wait for sync to complete.
        sync_done.await;

        info!("L2 sync complete, starting preconfirmation client");

        // Take ownership of the handle and node for the runtime.
        let mut handle = self.handle.take().ok_or(PreconfirmationClientError::Shutdown)?;
        // Take ownership of the node for the runtime.
        let node = self.node.take().ok_or(PreconfirmationClientError::Shutdown)?;

        // Spawn the P2P node driver loop.
        tokio::spawn(async move {
            // Log any P2P driver errors.
            if let Err(err) = node.run().await {
                error!(error = %err, "p2p node exited");
            }
        });

        // Run the catch-up flow.
        let catchup = TipCatchup::new(self.config.clone(), self.store.clone());
        // Fetch commitments from the network tip.
        let commitments = catchup.run(&mut handle).await?;

        // Bundle dependencies for the event handler.
        let deps = EventHandlerDeps {
            state: self.state.clone(),
            store: self.store.clone(),
            pending_parents: self.pending_parents.clone(),
            pending_txlists: self.pending_txlists.clone(),
            codec: self.codec.clone(),
            driver: self.driver.clone(),
            expected_slasher: self.config.expected_slasher.clone(),
            event_tx: self.event_tx.clone(),
            lookahead_resolver: Arc::new(self.config.lookahead_resolver.clone()),
        };
        // Build the event handler for gossip processing.
        let handler = EventHandler::new(deps);

        // Process each catch-up commitment through the handler.
        for commitment in commitments {
            handler.handle_commitment(commitment).await?;
        }

        // Mark the client as synced.
        // Acquire a mutable state guard.
        let mut guard = self.state.write().await;
        guard.set_synced(true);
        // Emit the synced event.
        let _ = self.event_tx.send(PreconfirmationEvent::Synced);

        // Enter the gossip event loop.
        let mut events = handle.events();
        while let Some(event) = events.next().await {
            handler.handle_event(event).await?;
        }

        Ok(())
    }
}
