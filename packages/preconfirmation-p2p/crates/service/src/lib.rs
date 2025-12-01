//! High-level async facade over the preconfirmation P2P networking layer.
//!
//! This crate owns the `preconfirmation-net` driver and exposes a small, ergonomic
//! API for sending `NetworkCommand`s and receiving `NetworkEvent`s. The facade keeps
//! callers away from libp2p details and hides the background task that polls the swarm.

use anyhow::Result;
use futures::future::poll_fn;
use tokio::{
    sync::{mpsc, oneshot},
    task::JoinHandle,
};

use libp2p::PeerId;
pub use preconfirmation_net::{NetworkCommand, NetworkConfig, NetworkDriver, NetworkEvent};
use preconfirmation_types::{
    GetCommitmentsByNumberResponse, GetRawTxListResponse, RawTxListGossip, SignedCommitment,
};

/// Application-facing callbacks for P2P events.
///
/// Implementors can plug business logic into these methods, allowing the
/// `P2pService` to hide libp2p details and dispatch high-level events.
pub trait P2pHandler: Send + Sync + 'static {
    /// Called when a signed commitment gossip message is received.
    fn on_signed_commitment(&self, _from: PeerId, _msg: SignedCommitment) {}
    /// Called when a raw transaction list gossip message is received.
    fn on_raw_txlist(&self, _from: PeerId, _msg: RawTxListGossip) {}
    /// Called when a response to a commitment request is received.
    fn on_commitments_response(&self, _from: PeerId, _msg: GetCommitmentsByNumberResponse) {}
    /// Called when a response to a raw transaction list request is received.
    fn on_raw_txlist_response(&self, _from: PeerId, _msg: GetRawTxListResponse) {}
    /// Called when a response to a head request is received.
    fn on_head_response(&self, _from: PeerId, _head: preconfirmation_types::PreconfHead) {}
    /// Called when an inbound request for commitments is received.
    fn on_inbound_commitments_request(&self, _from: PeerId) {}
    /// Called when an inbound request for a raw transaction list is received.
    fn on_inbound_raw_txlist_request(&self, _from: PeerId) {}
    /// Called when an inbound request for the preconfirmation head is received.
    fn on_inbound_head_request(&self, _from: PeerId) {}
    /// Called when a new peer connects.
    fn on_peer_connected(&self, _peer: PeerId) {}
    /// Called when a peer disconnects.
    fn on_peer_disconnected(&self, _peer: PeerId) {}
    /// Called when a network-level error occurs.
    fn on_error(&self, _err: &str) {}
}

/// Owned service wrapper.
///
/// It spawns the libp2p driver onto the tokio runtime and provides
/// convenience helpers to publish gossip, send requests, and consume events.
pub struct P2pService {
    /// Sender for `NetworkCommand`s to the `NetworkDriver`.
    command_tx: mpsc::Sender<NetworkCommand>,
    /// Receiver for `NetworkEvent`s from the `NetworkDriver`. This is an `Option`
    /// because it can be `take`n by `run_with_handler`.
    events_rx: Option<mpsc::Receiver<NetworkEvent>>,
    /// Sender for the shutdown signal to the `NetworkDriver` task.
    shutdown_tx: Option<oneshot::Sender<()>>,
    /// Handle to the `NetworkDriver`'s background task.
    join_handle: Option<JoinHandle<()>>,
}

impl P2pService {
    /// Starts the P2P service by constructing a `NetworkDriver` and spawning it
    /// as a background task on the tokio runtime.
    ///
    /// This function initializes the entire network stack and provides a handle
    /// for sending commands and receiving events.
    ///
    /// # Arguments
    ///
    /// * `config` - The `NetworkConfig` used to configure the underlying network driver.
    ///
    /// # Returns
    ///
    /// A `Result` which is `Ok(Self)` on successful startup, or an `anyhow::Error`
    /// if the network driver fails to initialize.
    pub fn start(config: NetworkConfig) -> Result<Self> {
        let (mut driver, handle) = NetworkDriver::new(config)?;
        let (shutdown_tx, mut shutdown_rx) = oneshot::channel();

        let events_rx = Some(handle.events);
        let command_tx = handle.commands;

        // Spawn the driver loop so callers interact via channels without owning the swarm task.
        let join_handle = tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = &mut shutdown_rx => {
                        break;
                    }
                    // Poll the driver once; it will park until the swarm wakes it.
                    _ = poll_fn(|cx| driver.poll(cx)) => {}
                }
            }
        });

        Ok(Self {
            command_tx,
            events_rx,
            shutdown_tx: Some(shutdown_tx),
            join_handle: Some(join_handle),
        })
    }

    /// Returns a clone of the command sender.
    ///
    /// This allows multiple callers to enqueue network actions to the `P2pService`.
    ///
    /// # Returns
    ///
    /// An `mpsc::Sender<NetworkCommand>` that can be used to send commands.
    pub fn command_sender(&self) -> mpsc::Sender<NetworkCommand> {
        self.command_tx.clone()
    }

    /// Publishes a signed commitment over gossipsub.
    ///
    /// This sends a `PublishCommitment` command to the network driver.
    ///
    /// # Arguments
    ///
    /// * `msg` - The `SignedCommitment` to publish.
    ///
    /// # Returns
    ///
    /// A `Result` indicating success or failure of sending the command.
    pub async fn publish_commitment(&self, msg: SignedCommitment) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::PublishCommitment(msg))
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Publishes a raw transaction list gossip message over gossipsub.
    ///
    /// This sends a `PublishRawTxList` command to the network driver.
    ///
    /// # Arguments
    ///
    /// * `msg` - The `RawTxListGossip` message to publish.
    ///
    /// # Returns
    ///
    /// A `Result` indicating success or failure of sending the command.
    pub async fn publish_raw_txlist(&self, msg: RawTxListGossip) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::PublishRawTxList(msg))
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Requests a range of commitments via the request-response protocol.
    ///
    /// If `peer` is `None`, the network driver selects a suitable peer.
    /// This sends a `RequestCommitments` command to the network driver.
    ///
    /// # Arguments
    ///
    /// * `start_block` - The starting block number for the commitment range.
    /// * `max_count` - The maximum number of commitments to request.
    /// * `peer` - An optional `PeerId` to target the request to a specific peer.
    ///
    /// # Returns
    ///
    /// A `Result` indicating success or failure of sending the command.
    pub async fn request_commitments(
        &self,
        start_block: preconfirmation_types::Uint256,
        max_count: u32,
        peer: Option<PeerId>,
    ) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::RequestCommitments { start_block, max_count, peer })
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Requests a raw transaction list by its hash via the request-response protocol.
    ///
    /// If `peer` is `None`, the network driver selects a suitable peer.
    /// This sends a `RequestRawTxList` command to the network driver.
    ///
    /// # Arguments
    ///
    /// * `hash` - The `Bytes32` hash of the raw transaction list to request.
    /// * `peer` - An optional `PeerId` to target the request to a specific peer.
    ///
    /// # Returns
    ///
    /// A `Result` indicating success or failure of sending the command.
    pub async fn request_raw_txlist(
        &self,
        hash: preconfirmation_types::Bytes32,
        peer: Option<PeerId>,
    ) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::RequestRawTxList { raw_tx_list_hash: hash, peer })
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Updates the locally served preconfirmation head.
    ///
    /// This head is used to answer inbound `get_head` requests from other peers.
    /// This sends an `UpdateHead` command to the network driver.
    ///
    /// # Arguments
    ///
    /// * `head` - The new `PreconfHead` to be served.
    ///
    /// # Returns
    ///
    /// A `Result` indicating success or failure of sending the command.
    pub async fn update_head(&self, head: preconfirmation_types::PreconfHead) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::UpdateHead { head })
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Requests a peer's preconfirmation head using the `get_head` request-response protocol (spec §11).
    ///
    /// If `peer` is `None`, the network driver selects a suitable peer.
    /// This sends a `RequestHead` command to the network driver.
    ///
    /// # Arguments
    ///
    /// * `peer` - An optional `PeerId` to target the request to a specific peer.
    ///
    /// # Returns
    ///
    /// A `Result` indicating success or failure of sending the command.
    pub async fn request_head(&self, peer: Option<PeerId>) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::RequestHead { peer })
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Receives the next network event.
    ///
    /// This is a convenience wrapper around `mpsc::Receiver::recv`.
    ///
    /// # Returns
    ///
    /// An `Option<NetworkEvent>` which is `Some` if an event is received,
    /// or `None` if the event channel has been closed.
    pub async fn next_event(&mut self) -> Option<NetworkEvent> {
        match self.events_rx.as_mut() {
            Some(rx) => rx.recv().await,
            None => None,
        }
    }

    /// Provides mutable access to the underlying event receiver.
    ///
    /// Callers can use this if they prefer manual polling or streaming of events.
    /// Note that once `run_with_handler` is called, the receiver is moved,
    /// and this method will panic if called afterwards.
    ///
    /// # Panics
    ///
    /// Panics if the events receiver has already been taken (e.g., by `run_with_handler`).
    ///
    /// # Returns
    ///
    /// A mutable reference to the `mpsc::Receiver<NetworkEvent>`.
    pub fn events(&mut self) -> &mut mpsc::Receiver<NetworkEvent> {
        self.events_rx.as_mut().expect("events receiver already taken")
    }

    /// Spawns a background task that consumes network events and invokes the provided handler.
    ///
    /// Once invoked, the internal events receiver is moved out of the `P2pService`,
    /// making `events()` and `next_event()` unavailable.
    ///
    /// # Type Parameters
    ///
    /// * `H` - A type that implements the `P2pHandler` trait.
    ///
    /// # Arguments
    ///
    /// * `handler` - An instance of `P2pHandler` that will process network events.
    ///
    /// # Panics
    ///
    /// Panics if the events receiver has already been taken (e.g., by a previous call to this method).
    ///
    /// # Returns
    ///
    /// A `JoinHandle` for the spawned event processing task.
    pub fn run_with_handler<H: P2pHandler>(&mut self, handler: H) -> JoinHandle<()> {
        let mut rx = self.events_rx.take().expect("events receiver already taken");
        tokio::spawn(async move {
            while let Some(ev) = rx.recv().await {
                match ev {
                    NetworkEvent::GossipSignedCommitment { from, msg } => {
                        handler.on_signed_commitment(from, *msg)
                    }
                    NetworkEvent::GossipRawTxList { from, msg } => {
                        handler.on_raw_txlist(from, *msg)
                    }
                    NetworkEvent::ReqRespCommitments { from, msg } => {
                        handler.on_commitments_response(from, msg)
                    }
                    NetworkEvent::ReqRespRawTxList { from, msg } => {
                        handler.on_raw_txlist_response(from, msg)
                    }
                    NetworkEvent::ReqRespHead { from, head } => {
                        handler.on_head_response(from, head)
                    }
                    NetworkEvent::InboundCommitmentsRequest { from } => {
                        handler.on_inbound_commitments_request(from)
                    }
                    NetworkEvent::InboundRawTxListRequest { from } => {
                        handler.on_inbound_raw_txlist_request(from)
                    }
                    NetworkEvent::InboundHeadRequest { from } => {
                        handler.on_inbound_head_request(from)
                    }
                    NetworkEvent::PeerConnected(peer) => handler.on_peer_connected(peer),
                    NetworkEvent::PeerDisconnected(peer) => handler.on_peer_disconnected(peer),
                    NetworkEvent::Error(err) => handler.on_error(&err),
                    NetworkEvent::Started | NetworkEvent::Stopped => {}
                }
            }
        })
    }

    /// Triggers a graceful shutdown of the network driver and waits for its background task to finish.
    ///
    /// This method sends a shutdown signal to the driver's task and then awaits
    /// its completion, ensuring all resources are properly released.
    pub async fn shutdown(&mut self) {
        if let Some(tx) = self.shutdown_tx.take() {
            // If the driver is still alive, request a graceful stop; ignore if already dropped.
            let _ = tx.send(());
        }
        if let Some(handle) = self.join_handle.take() {
            let _ = handle.await;
        }
    }
}

impl Drop for P2pService {
    /// Implements the `Drop` trait to ensure proper shutdown of the `P2pService`.
    ///
    /// If `shutdown` was not explicitly called, this will send a shutdown signal
    /// and abort the driver's background task to prevent resource leaks.
    fn drop(&mut self) {
        if self.shutdown_tx.is_some() {
            // Fire and forget shutdown if user didn't call it.
            if let Some(tx) = self.shutdown_tx.take() {
                let _ = tx.send(());
            }
        }

        if let Some(handle) = self.join_handle.take() {
            handle.abort();
        }
    }
}

// ---------- Tests ----------

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn service_starts_and_stops() {
        let cfg = NetworkConfig::default();
        let mut svc = P2pService::start(cfg).expect("service starts");

        // It's OK if there are no events; ensure the API is usable.
        let _ = svc.command_sender();
        let _ = svc.next_event().await;

        svc.shutdown().await;
    }
}
