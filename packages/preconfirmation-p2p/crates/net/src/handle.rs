//! Handle for interacting with the P2P network driver from application code.
//!
//! This module provides [`P2pHandle`], a minimal interface for sending commands
//! to the network and receiving events from it.

use anyhow::Result;
use futures::Stream;
use libp2p::PeerId;
use tokio::sync::{
    mpsc::{Receiver, Sender},
    oneshot,
};

use crate::{
    command::NetworkCommand,
    driver::NetworkHandle,
    event::{NetworkError, NetworkErrorKind, NetworkEvent},
};

/// Minimal handle for sending commands and consuming events.
///
/// This handle is the primary interface for application code to interact with the P2P
/// network layer. It provides methods to publish messages via gossipsub and make
/// request/response calls to peers.
///
/// # Example
///
/// ```ignore
/// let (handle, node) = P2pNode::new(config, validator)?;
/// tokio::spawn(async move { node.run().await });
///
/// // Publish a commitment
/// handle.publish_commitment(signed_commitment).await?;
///
/// // Request commitments from any peer
/// let response = handle.request_commitments(start_block, max_count, None).await?;
/// ```
pub struct P2pHandle {
    /// Channel for sending commands to the network driver.
    commands: Sender<NetworkCommand>,
    /// Channel for receiving events from the network driver.
    events: Receiver<NetworkEvent>,
}

impl P2pHandle {
    /// Create a new `P2pHandle` from the internal `NetworkHandle`.
    ///
    /// This is called internally by [`P2pNode::new`].
    pub(crate) fn new(handle: NetworkHandle) -> Self {
        Self { commands: handle.commands, events: handle.events }
    }

    /// Returns a clone of the command sender.
    ///
    /// This can be used to send commands from multiple tasks without holding
    /// a mutable reference to the handle.
    pub fn command_sender(&self) -> Sender<NetworkCommand> {
        self.commands.clone()
    }

    /// Returns a stream of network events.
    ///
    /// This stream yields events such as peer connections/disconnections,
    /// received gossip messages, and request/response results.
    pub fn events(&mut self) -> impl Stream<Item = NetworkEvent> + '_ {
        futures::stream::poll_fn(move |cx| self.events.poll_recv(cx))
    }

    /// Publish a signed commitment over gossipsub.
    ///
    /// The commitment will be serialized using SSZ and broadcast to all peers
    /// subscribed to the commitments topic.
    ///
    /// # Arguments
    ///
    /// * `msg` - The signed commitment to publish.
    ///
    /// # Returns
    ///
    /// `Ok(())` if the command was sent successfully, or an error if the channel is closed.
    pub async fn publish_commitment(
        &self,
        msg: preconfirmation_types::SignedCommitment,
    ) -> Result<()> {
        self.commands
            .send(NetworkCommand::PublishCommitment(msg))
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Publish a raw transaction list over gossipsub.
    ///
    /// The message will be serialized using SSZ and broadcast to all peers
    /// subscribed to the raw txlist topic.
    ///
    /// # Arguments
    ///
    /// * `msg` - The raw transaction list gossip message to publish.
    ///
    /// # Returns
    ///
    /// `Ok(())` if the command was sent successfully, or an error if the channel is closed.
    pub async fn publish_raw_txlist(
        &self,
        msg: preconfirmation_types::RawTxListGossip,
    ) -> Result<()> {
        self.commands
            .send(NetworkCommand::PublishRawTxList(msg))
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    /// Request commitments starting from a specific block number.
    ///
    /// This sends a request/response message to a peer and waits for the response.
    ///
    /// # Arguments
    ///
    /// * `start_block` - The starting block number for the commitment request.
    /// * `max_count` - Maximum number of commitments to return.
    /// * `peer` - Optional specific peer to request from. If `None`, any connected peer may be
    ///   used.
    ///
    /// # Returns
    ///
    /// The commitment response on success, or a `NetworkError` on failure (timeout, no peers,
    /// etc.).
    pub async fn request_commitments(
        &mut self,
        start_block: preconfirmation_types::Uint256,
        max_count: u32,
        peer: Option<PeerId>,
    ) -> Result<preconfirmation_types::GetCommitmentsByNumberResponse, NetworkError> {
        let (tx, rx) = oneshot::channel();
        self.commands
            .send(NetworkCommand::RequestCommitments {
                respond_to: Some(tx),
                start_block,
                max_count,
                peer,
            })
            .await
            .map_err(|e| {
                NetworkError::new(NetworkErrorKind::SendCommandFailed, format!("send command: {e}"))
            })?;

        rx.await.unwrap_or_else(|_| {
            Err(NetworkError::new(
                NetworkErrorKind::ReqRespTimeout,
                "service stopped before commitments response",
            ))
        })
    }

    /// Request a raw transaction list by its hash.
    ///
    /// This sends a request/response message to a peer and waits for the response.
    ///
    /// # Arguments
    ///
    /// * `hash` - The Keccak-256 hash of the raw transaction list.
    /// * `peer` - Optional specific peer to request from. If `None`, any connected peer may be
    ///   used.
    ///
    /// # Returns
    ///
    /// The raw txlist response on success, or a `NetworkError` on failure.
    pub async fn request_raw_txlist(
        &mut self,
        hash: preconfirmation_types::Bytes32,
        peer: Option<PeerId>,
    ) -> Result<preconfirmation_types::GetRawTxListResponse, NetworkError> {
        let (tx, rx) = oneshot::channel();
        self.commands
            .send(NetworkCommand::RequestRawTxList {
                respond_to: Some(tx),
                raw_tx_list_hash: hash,
                peer,
            })
            .await
            .map_err(|e| {
                NetworkError::new(NetworkErrorKind::SendCommandFailed, format!("send command: {e}"))
            })?;

        rx.await.unwrap_or_else(|_| {
            Err(NetworkError::new(
                NetworkErrorKind::ReqRespTimeout,
                "service stopped before raw-txlist response",
            ))
        })
    }

    /// Request the current preconfirmation head from a peer.
    ///
    /// This sends a request/response message to a peer and waits for the response.
    ///
    /// # Arguments
    ///
    /// * `peer` - Optional specific peer to request from. If `None`, any connected peer may be
    ///   used.
    ///
    /// # Returns
    ///
    /// The preconfirmation head on success, or a `NetworkError` on failure.
    pub async fn request_head(
        &mut self,
        peer: Option<PeerId>,
    ) -> Result<preconfirmation_types::PreconfHead, NetworkError> {
        let (tx, rx) = oneshot::channel();
        self.commands
            .send(NetworkCommand::RequestHead { respond_to: Some(tx), peer })
            .await
            .map_err(|e| {
                NetworkError::new(NetworkErrorKind::SendCommandFailed, format!("send command: {e}"))
            })?;

        rx.await.unwrap_or_else(|_| {
            Err(NetworkError::new(
                NetworkErrorKind::ReqRespTimeout,
                "service stopped before head response",
            ))
        })
    }
}
