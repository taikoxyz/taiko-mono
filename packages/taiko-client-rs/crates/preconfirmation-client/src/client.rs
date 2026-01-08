//! Main preconfirmation client implementation.
//!
//! This module provides the `PreconfirmationClient` which orchestrates:
//! - P2P node management
//! - Tip catch-up after normal sync
//! - Event handling for gossip subscriptions
//! - Submitting preconfirmation inputs to the driver

use std::sync::Arc;

use tokio::sync::{broadcast, mpsc::Sender};
use tokio_stream::StreamExt;
use tracing::{error, info};

use preconfirmation_net::{
    LocalValidationAdapter, NetworkCommand, P2pHandle, P2pNode, PreconfStorage, ValidationAdapter,
};
use preconfirmation_types::MAX_TXLIST_BYTES;

use crate::{
    codec::ZlibTxListCodec,
    config::PreconfirmationClientConfig,
    driver_interface::DriverClient,
    error::{PreconfirmationClientError, Result},
    storage::{
        CommitmentStore, InMemoryCommitmentStore, PendingCommitmentBuffer, PendingTxListBuffer,
    },
    subscription::{EventHandler, PreconfirmationEvent},
    sync::tip_catchup::TipCatchup,
};

/// The main preconfirmation client.
///
/// This client manages the P2P network connection, handles gossip events,
/// performs tip catch-up synchronization, and submits preconfirmation inputs
/// to the driver.
pub struct PreconfirmationClient<D>
where
    D: DriverClient + 'static,
{
    /// Client configuration.
    config: PreconfirmationClientConfig,
    /// Commitment store.
    store: Arc<dyn CommitmentStore>,
    /// Pending commitment buffer for missing parents.
    pending_parents: Arc<PendingCommitmentBuffer>,
    /// Pending commitment buffer for missing txlists.
    pending_txlists: Arc<PendingTxListBuffer>,
    /// Txlist codec for decompression.
    codec: Arc<ZlibTxListCodec>,
    /// Driver client.
    driver: Arc<D>,
    /// Command sender for publishing and req/resp.
    command_sender: Sender<NetworkCommand>,
    /// P2P handle used by the event loop.
    handle: P2pHandle,
    /// P2P node used to run the network driver.
    node: P2pNode,
    /// Broadcast channel for outbound events.
    event_tx: broadcast::Sender<PreconfirmationEvent>,
}

impl<D> PreconfirmationClient<D>
where
    D: DriverClient + 'static,
{
    /// Create a new preconfirmation client and underlying P2P node.
    pub fn new(config: PreconfirmationClientConfig, driver: D) -> Result<Self> {
        // Build the commitment store (shared with the P2P node storage).
        let store_impl =
            Arc::new(InMemoryCommitmentStore::with_retention_limit(config.retention_limit));
        let store: Arc<dyn CommitmentStore> = store_impl.clone();
        let p2p_storage: Arc<dyn PreconfStorage> = store_impl;
        // Build the pending parent buffer.
        let pending_parents = Arc::new(PendingCommitmentBuffer::new());
        // Build the pending txlist buffer.
        let pending_txlists = Arc::new(PendingTxListBuffer::new());
        // Build the txlist codec using the protocol constant.
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        // Build the network validator.
        let validator: Box<dyn ValidationAdapter> =
            Box::new(LocalValidationAdapter::new(config.expected_slasher.clone()));
        // Create the P2P handle and node.
        let (handle, node) =
            P2pNode::new_with_validator_and_storage(config.p2p.clone(), validator, p2p_storage)
                .map_err(|err| PreconfirmationClientError::Network(err.to_string()))?;
        // Capture the command sender for publishing.
        let command_sender = handle.command_sender();
        // Build the broadcast channel for events.
        let (event_tx, _event_rx) = broadcast::channel(16);

        Ok(Self {
            config,
            store,
            pending_parents,
            pending_txlists,
            codec,
            driver: Arc::new(driver),
            command_sender,
            handle,
            node,
            event_tx,
        })
    }

    /// Subscribe to client events.
    pub fn subscribe(&self) -> broadcast::Receiver<PreconfirmationEvent> {
        self.event_tx.subscribe()
    }

    /// Get the command sender for outbound messages.
    pub fn command_sender(&self) -> Sender<NetworkCommand> {
        self.command_sender.clone()
    }

    /// Run the client after the driver event sync has completed.
    ///
    /// This method consumes the client and:
    /// 1. Waits for the driver event sync completion signal.
    /// 2. Fetches the driver event sync tip to bound catch-up.
    /// 3. Performs tip catch-up to synchronize preconfirmation commitments.
    /// 4. Emits a synced event.
    pub async fn run_after_event_sync(self) -> Result<()> {
        info!("waiting for driver event sync to complete");
        // Wait for the driver to report event sync completion.
        self.driver.wait_event_sync().await?;

        // Read the driver event sync tip to determine catch-up bounds.
        let event_sync_tip = self.driver.event_sync_tip().await?;

        info!(event_sync_tip = %event_sync_tip, "driver event sync complete, starting preconfirmation client");

        let mut handle = self.handle;

        // Spawn the P2P node driver loop.
        tokio::spawn(async move {
            // Log any P2P driver errors.
            if let Err(err) = self.node.run().await {
                error!(error = %err, "p2p node exited");
            }
        });

        // Run the catch-up flow.
        let catchup = TipCatchup::new(self.config.clone(), self.store.clone());
        // Fetch commitments and txlists from the network tip.
        let (commitments, catchup_boundary) =
            catchup.backfill_from_peer_head(&mut handle, event_sync_tip).await?;

        // Build the event handler for gossip processing.
        let handler = EventHandler::new(
            self.store.clone(),
            self.pending_parents.clone(),
            self.pending_txlists.clone(),
            self.codec.clone(),
            self.driver.clone(),
            self.config.expected_slasher.clone(),
            self.event_tx.clone(),
            self.command_sender.clone(),
            Arc::new(self.config.lookahead_resolver.clone()),
        );

        // Process each catch-up commitment through the handler.
        let mut commit_iter = commitments.into_iter();
        if catchup_boundary && let Some(first) = commit_iter.next() {
            handler.handle_catchup_commitment(first, true).await?;
        }
        for commitment in commit_iter {
            handler.handle_commitment(commitment).await?;
        }

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
