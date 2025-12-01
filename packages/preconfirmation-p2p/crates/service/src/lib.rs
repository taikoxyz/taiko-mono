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

/// Application-facing callbacks for P2P events. Implementors can plug business logic while the
/// service hides libp2p details.
pub trait P2pHandler: Send + Sync + 'static {
    fn on_signed_commitment(&self, _from: PeerId, _msg: SignedCommitment) {}
    fn on_raw_txlist(&self, _from: PeerId, _msg: RawTxListGossip) {}
    fn on_commitments_response(&self, _from: PeerId, _msg: GetCommitmentsByNumberResponse) {}
    fn on_raw_txlist_response(&self, _from: PeerId, _msg: GetRawTxListResponse) {}
    fn on_head_response(&self, _from: PeerId, _head: preconfirmation_types::PreconfHead) {}
    fn on_inbound_commitments_request(&self, _from: PeerId) {}
    fn on_inbound_raw_txlist_request(&self, _from: PeerId) {}
    fn on_inbound_head_request(&self, _from: PeerId) {}
    fn on_peer_connected(&self, _peer: PeerId) {}
    fn on_peer_disconnected(&self, _peer: PeerId) {}
    fn on_error(&self, _err: &str) {}
}

/// Owned service wrapper. It spawns the libp2p driver onto the tokio runtime and provides
/// convenience helpers to publish gossip, send requests, and consume events.
pub struct P2pService {
    command_tx: mpsc::Sender<NetworkCommand>,
    events_rx: Option<mpsc::Receiver<NetworkEvent>>,
    shutdown_tx: Option<oneshot::Sender<()>>,
    join_handle: Option<JoinHandle<()>>,
}

impl P2pService {
    /// Start the P2P service by constructing a `NetworkDriver` and spawning it in the
    /// background using tokio. Returns a handle for sending commands and receiving events.
    pub fn start(config: NetworkConfig) -> Result<Self> {
        let (mut driver, handle) = NetworkDriver::new(config)?;
        let (shutdown_tx, mut shutdown_rx) = oneshot::channel();

        let events_rx = Some(handle.events);
        let command_tx = handle.commands;

        // Spawn the driver loop. It waits on swarm activity or shutdown.
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

    /// Get a clone of the command sender so callers can enqueue network actions.
    pub fn command_sender(&self) -> mpsc::Sender<NetworkCommand> {
        self.command_tx.clone()
    }

    /// Publish a signed commitment over gossipsub.
    pub async fn publish_commitment(&self, msg: SignedCommitment) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::PublishCommitment(msg))
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Publish a raw tx list gossip message over gossipsub.
    pub async fn publish_raw_txlist(&self, msg: RawTxListGossip) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::PublishRawTxList(msg))
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Request a commitment range via req/resp. If `peer` is `None`, the driver selects a peer.
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

    /// Request a raw tx list by hash via req/resp. If `peer` is `None`, the driver selects a peer.
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

    /// Update the locally served preconfirmation head for answering inbound get_head requests.
    pub async fn update_head(&self, head: preconfirmation_types::PreconfHead) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::UpdateHead { head })
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Request the peer's preconfirmation head (spec §11 get_head).
    pub async fn request_head(&self, peer: Option<PeerId>) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::RequestHead { peer })
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Receive the next network event. Convenience wrapper around `mpsc::Receiver::recv`.
    pub async fn next_event(&mut self) -> Option<NetworkEvent> {
        match self.events_rx.as_mut() {
            Some(rx) => rx.recv().await,
            None => None,
        }
    }

    /// Access the underlying event receiver if callers prefer manual polling/streaming.
    pub fn events(&mut self) -> &mut mpsc::Receiver<NetworkEvent> {
        self.events_rx.as_mut().expect("events receiver already taken")
    }

    /// Spawn a background task that consumes network events and invokes the provided handler.
    /// Once invoked, the internal events receiver is moved and `events()` / `next_event()`
    /// become unavailable.
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

    /// Trigger a graceful shutdown and wait for the background task to finish.
    pub async fn shutdown(&mut self) {
        if let Some(tx) = self.shutdown_tx.take() {
            let _ = tx.send(());
        }
        if let Some(handle) = self.join_handle.take() {
            let _ = handle.await;
        }
    }
}

impl Drop for P2pService {
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
