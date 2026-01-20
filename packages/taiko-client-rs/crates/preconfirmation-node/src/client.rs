//! Main preconfirmation client implementation.
//!
//! This module provides the `PreconfirmationClient` which orchestrates:
//! - P2P node management
//! - Tip catch-up after normal sync
//! - Event handling for gossip subscriptions
//! - Submitting preconfirmation inputs to the driver

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use tokio::{
    sync::{broadcast, mpsc},
    time::sleep,
};
use tokio_stream::StreamExt;
use tracing::{error, info, warn};

use preconfirmation_net::{
    LocalValidationAdapter, NetworkCommand, P2pHandle, P2pNode, PreconfStorage, ValidationAdapter,
};
use preconfirmation_types::MAX_TXLIST_BYTES;

use crate::{
    codec::ZlibTxListCodec,
    config::PreconfirmationClientConfig,
    driver_interface::DriverClient,
    error::{PreconfirmationClientError, Result},
    metrics::PreconfirmationClientMetrics,
    storage::{CommitmentStore, InMemoryCommitmentStore},
    subscription::{EventHandler, PreconfirmationEvent},
    sync::TipCatchup,
};

/// Capacity for the broadcast event channel used by the client.
const EVENT_CHANNEL_CAPACITY: usize = 16;
/// Base delay used when restarting the P2P event loop.
const P2P_RESTART_BACKOFF_BASE: Duration = Duration::from_secs(1);
/// Maximum delay between P2P event loop restarts.
const P2P_RESTART_BACKOFF_MAX: Duration = Duration::from_secs(12);

/// A ready-to-run client that has completed sync and catchup.
///
/// This struct holds the state needed to run the blocking event loop.
/// Call [`EventLoop::run_with_retry`] to start processing P2P events.
pub struct EventLoop<D>
where
    D: DriverClient + 'static,
{
    config: PreconfirmationClientConfig,
    p2p_storage: Arc<dyn PreconfStorage>,
    node_handle: tokio::task::JoinHandle<anyhow::Result<()>>,
    handle: P2pHandle,
    handler: EventHandler<D>,
}

impl<D> EventLoop<D>
where
    D: DriverClient + 'static,
{
    /// Run the event loop forever, retrying on errors with exponential backoff.
    pub async fn run_with_retry(mut self) -> Result<()> {
        let mut backoff = RetryBackoff::new(P2P_RESTART_BACKOFF_BASE, P2P_RESTART_BACKOFF_MAX);

        loop {
            match self.run().await {
                Ok(()) => {
                    warn!("event loop exited without error; restarting");
                }
                Err(err) => {
                    error!(error = %err, "event loop failed; restarting");
                }
            }

            sleep(backoff.next_delay()).await;
            self.rebuild_after_failure().await?;
        }
    }

    /// Run the event loop, returning on error (fail-fast).
    pub async fn run(&mut self) -> Result<()> {
        let node_handle = &mut self.node_handle;
        let handle = &mut self.handle;
        let handler = &self.handler;

        let mut events = handle.events();
        loop {
            tokio::select! {
                result = &mut *node_handle => {
                    return Err(PreconfirmationClientError::Network(match result {
                        Ok(Ok(())) => "p2p node exited unexpectedly".to_string(),
                        Ok(Err(err)) => format!("p2p node failed: {err}"),
                        Err(err) => format!("p2p node task panicked: {err}"),
                    }));
                }
                event = events.next() => {
                    let Some(event) = event else {
                        return Err(PreconfirmationClientError::Network(
                            "p2p event stream ended".to_string(),
                        ));
                    };
                    handler.handle_event(event).await?;
                }
            }
        }
    }

    /// Rebuild the event loop after a failure.
    async fn rebuild_after_failure(&mut self) -> Result<()> {
        self.node_handle.abort();

        let validator: Box<dyn ValidationAdapter> =
            Box::new(LocalValidationAdapter::new(self.config.expected_slasher.clone()));
        let (handle, node) = P2pNode::new_with_validator_and_storage(
            self.config.p2p.clone(),
            validator,
            self.p2p_storage.clone(),
        )
        .map_err(|err| PreconfirmationClientError::Network(err.to_string()))?;

        self.handle = handle;
        self.handler.set_command_sender(self.handle.command_sender());
        self.node_handle = tokio::spawn(async move { node.run().await });

        Ok(())
    }
}

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
    /// Txlist codec for decompression.
    codec: Arc<ZlibTxListCodec>,
    /// Driver client.
    driver: Arc<D>,
    /// P2P handle used by the event loop.
    handle: P2pHandle,
    /// P2P node used to run the P2P network.
    node: P2pNode,
    /// Storage shared with the P2P node.
    p2p_storage: Arc<dyn PreconfStorage>,
    /// Broadcast channel for outbound events.
    event_tx: broadcast::Sender<PreconfirmationEvent>,
}

impl<D> PreconfirmationClient<D>
where
    D: DriverClient + 'static,
{
    /// Create a new preconfirmation client and underlying P2P node.
    pub fn new(config: PreconfirmationClientConfig, driver: D) -> Result<Self> {
        PreconfirmationClientMetrics::init();

        // Validate config parameters.
        config.validate()?;
        // Build the commitment store (shared with the P2P node storage).
        let store = Arc::new(InMemoryCommitmentStore::with_retention_limit(config.retention_limit));
        let p2p_storage: Arc<dyn PreconfStorage> = store.clone();
        let store: Arc<dyn CommitmentStore> = store;
        // Build the txlist codec using the protocol constant.
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        // Build the network validator.
        let validator: Box<dyn ValidationAdapter> =
            Box::new(LocalValidationAdapter::new(config.expected_slasher.clone()));
        // Create the P2P handle and node.
        let (handle, node) = P2pNode::new_with_validator_and_storage(
            config.p2p.clone(),
            validator,
            p2p_storage.clone(),
        )
        .map_err(|err| PreconfirmationClientError::Network(err.to_string()))?;
        // Build the broadcast channel for events.
        let (event_tx, _event_rx) = broadcast::channel(EVENT_CHANNEL_CAPACITY);

        Ok(Self {
            config,
            store,
            codec,
            driver: Arc::new(driver),
            handle,
            node,
            p2p_storage,
            event_tx,
        })
    }

    /// Subscribe to client events.
    pub fn subscribe(&self) -> broadcast::Receiver<PreconfirmationEvent> {
        self.event_tx.subscribe()
    }

    /// Get the command sender for outbound messages.
    pub fn command_sender(&self) -> mpsc::Sender<NetworkCommand> {
        self.handle.command_sender()
    }

    /// Get the commitment store for local cache access.
    pub fn store(&self) -> Arc<dyn CommitmentStore> {
        Arc::clone(&self.store)
    }

    /// Wait for driver event sync to complete, perform catchup, and return an event loop.
    ///
    /// This method consumes the client and:
    /// 1. Waits for the driver event sync completion.
    /// 2. Fetches the driver event sync tip to bound preconfirmation catch-up.
    /// 3. Performs preconfirmation tip catch-up to synchronize preconfirmation commitments /
    ///    txlists.
    /// 4. Emits a synced event.
    /// 5. Returns a [`EventLoop`] that can be used to run the blocking event loop.
    pub async fn sync_and_catchup(self) -> Result<EventLoop<D>> {
        let PreconfirmationClient {
            config,
            store,
            codec,
            driver,
            mut handle,
            node,
            p2p_storage,
            event_tx,
        } = self;

        info!("waiting for driver event sync to complete");
        // Wait for the driver to report event sync completion.
        driver.wait_event_sync().await?;

        // Read the driver event sync tip to determine catch-up bounds.
        let event_sync_tip = driver.event_sync_tip().await?;

        info!(event_sync_tip = %event_sync_tip, "driver event sync complete, starting preconfirmation client");

        // Build the event handler for gossip processing.
        let handler = EventHandler::new(
            store.clone(),
            codec.clone(),
            driver.clone(),
            config.expected_slasher.clone(),
            event_tx.clone(),
            handle.command_sender(),
            Arc::clone(&config.lookahead_resolver),
        );

        // Spawn the P2P node loop before running catch-up.
        let node_handle = tokio::spawn(async move { node.run().await });

        // If pre-dial peers are configured, dial them and wait for a connection
        // before attempting catch-up. Use the pre_dial_timeout if configured.
        let pre_dial_result: Result<()> = async {
            if !config.p2p.pre_dial_peers.is_empty() {
                for addr in config.p2p.pre_dial_peers.iter().cloned() {
                    handle.dial(addr).await?;
                }
                let peer_id = handle
                    .wait_for_peer_connected_with_timeout(config.p2p.pre_dial_timeout)
                    .await?;
                info!(peer_id = %peer_id, "peer connected before catch-up");
                if let Err(err) =
                    event_tx.send(PreconfirmationEvent::PeerConnected(peer_id.to_string()))
                {
                    warn!(error = %err, "failed to emit peer connected event");
                }
            }
            Ok(())
        }
        .await;

        if let Err(err) = pre_dial_result {
            node_handle.abort();
            return Err(err);
        }

        // Run the catch-up flow.
        let catchup_result = async {
            let catchup_start = Instant::now();
            let catchup = TipCatchup::new(config.clone(), store.clone());
            let commitments = catchup.backfill_from_peer_head(&mut handle, event_sync_tip).await?;

            // Process each catch-up commitment through the handler.
            let mut commit_iter = commitments.into_iter();
            if let Some(first) = commit_iter.next() {
                handler.handle_catchup_commitment(first).await?;
            }
            for commitment in commit_iter {
                handler.handle_commitment(commitment).await?;
            }

            metrics::histogram!(PreconfirmationClientMetrics::CATCHUP_DURATION_SECONDS)
                .record(catchup_start.elapsed().as_secs_f64());

            Ok(())
        }
        .await;

        if let Err(err) = catchup_result {
            node_handle.abort();
            return Err(err);
        }

        // Emit the synced event.
        if let Err(err) = event_tx.send(PreconfirmationEvent::Synced) {
            warn!(error = %err, "failed to emit synced event");
        }
        metrics::counter!(PreconfirmationClientMetrics::SYNCED_TOTAL).increment(1);

        Ok(EventLoop { config, p2p_storage, node_handle, handle, handler })
    }
}

/// Simple exponential backoff helper for P2P restarts.
struct RetryBackoff {
    current: Duration,
    max: Duration,
}

impl RetryBackoff {
    /// Create a new `RetryBackoff` with the given base and maximum durations.
    fn new(base: Duration, max: Duration) -> Self {
        Self { current: base, max }
    }

    /// Get the next delay duration, doubling the current delay up to the maximum.
    fn next_delay(&mut self) -> Duration {
        let delay = self.current.min(self.max);
        self.current = (self.current * 2).min(self.max);
        delay
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::RetryBackoff;

    #[test]
    fn retry_backoff_doubles_until_max() {
        let base = Duration::from_millis(100);
        let max = Duration::from_secs(1);
        let mut backoff = RetryBackoff::new(base, max);

        assert_eq!(backoff.next_delay(), base);
        assert_eq!(backoff.next_delay(), base + base);
        assert_eq!(backoff.next_delay(), base + base + base + base);
        assert_eq!(backoff.next_delay(), Duration::from_millis(800));
        assert_eq!(backoff.next_delay(), max);
        assert_eq!(backoff.next_delay(), max);
    }
}
