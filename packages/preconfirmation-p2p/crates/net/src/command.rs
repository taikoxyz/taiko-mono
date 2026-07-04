//! Network command definitions for the preconfirmation P2P layer.
//!
//! This module defines the [`NetworkCommand`] enum, which represents actions
//! that the service layer can request from the network driver.

use libp2p::{Multiaddr, PeerId};
use preconfirmation_types::{Bytes32, RawTxListGossip, SignedCommitment, Uint256};
use tokio::sync::oneshot;

/// Snapshot of peer state exposed for operator-facing logs and status checks.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PeerInfoSnapshot {
    /// Local peer ID for this node.
    pub local_peer_id: PeerId,
    /// Currently connected peer IDs.
    pub peers: Vec<PeerId>,
    /// Known remote addresses for currently connected peers.
    pub addr_info: Vec<Multiaddr>,
    /// Current local listening addresses.
    pub listen_addrs: Vec<Multiaddr>,
    /// Current externally observed addresses for this swarm.
    pub external_addrs: Vec<Multiaddr>,
}

impl PeerInfoSnapshot {
    /// Return the number of connected peers represented in this snapshot.
    pub fn peers_len(&self) -> usize {
        self.peers.len()
    }
}

/// Commands the service can issue to the network driver.
///
/// These commands instruct the network layer to perform actions such as publishing
/// messages, requesting data from peers, or updating internal state.
#[derive(Debug)]
pub enum NetworkCommand {
    /// Publish a signed commitment over gossipsub.
    /// The `SignedCommitment` will be serialized and broadcast to subscribed peers.
    PublishCommitment(SignedCommitment),
    /// Publish a raw transaction list blob over gossipsub.
    /// The `RawTxListGossip` will be serialized and broadcast to subscribed peers.
    PublishRawTxList(RawTxListGossip),
    /// Request a range of commitments starting at `start_block` (up to `max_count`)
    /// from a specific `peer` (if specified) or any suitable peer.
    RequestCommitments {
        /// Optional responder to deliver the response or error to the caller.
        respond_to: Option<
            oneshot::Sender<
                Result<
                    preconfirmation_types::GetCommitmentsByNumberResponse,
                    crate::event::NetworkError,
                >,
            >,
        >,
        /// The starting block number for the commitment request.
        start_block: Uint256,
        /// The maximum number of commitments to request.
        max_count: u32,
        /// The `PeerId` of the specific peer to send the request to. If `None`,
        /// the request can be sent to any connected peer.
        peer: Option<PeerId>,
    },
    /// Request a raw transaction list by its hash from a specific `peer` (if specified)
    /// or any suitable peer.
    RequestRawTxList {
        /// Optional responder to deliver the response or error to the caller.
        respond_to: Option<
            oneshot::Sender<
                Result<preconfirmation_types::GetRawTxListResponse, crate::event::NetworkError>,
            >,
        >,
        /// The hash of the raw transaction list to request.
        raw_tx_list_hash: Bytes32,
        /// The `PeerId` of the specific peer to send the request to. If `None`,
        /// the request can be sent to any connected peer.
        peer: Option<PeerId>,
    },
    /// Request the peer's current preconfirmation head (spec §10) from a specific
    /// `peer` (if specified) or any suitable peer.
    RequestHead {
        /// Optional responder to deliver the response or error to the caller.
        respond_to: Option<
            oneshot::Sender<Result<preconfirmation_types::PreconfHead, crate::event::NetworkError>>,
        >,
        /// The `PeerId` of the specific peer to send the request to. If `None`,
        /// the request can be sent to any connected peer.
        peer: Option<PeerId>,
    },
    /// Update the locally served preconfirmation head. This head is used to answer
    /// `get_head` requests from other peers.
    UpdateHead {
        /// The new `PreconfHead` to be served.
        head: preconfirmation_types::PreconfHead,
    },
    /// Dial a peer at the given multiaddr.
    Dial {
        /// The multiaddr to dial. Should include the peer ID suffix (e.g., `/p2p/<peer_id>`).
        addr: Multiaddr,
        /// Optional responder to notify when the dial attempt completes.
        /// Returns `Ok(())` if the dial was initiated, or an error string if it failed.
        respond_to: Option<oneshot::Sender<Result<(), String>>>,
    },
    /// Get the current listening addresses.
    GetListeningAddrs {
        /// Responder to deliver the listening addresses.
        respond_to: oneshot::Sender<Vec<Multiaddr>>,
    },
    /// Get the current connected peer count.
    GetPeerCount {
        /// Responder to deliver the peer count.
        respond_to: oneshot::Sender<u64>,
    },
    /// Get a snapshot of connected peers and known peer/local addresses.
    GetPeerInfo {
        /// Responder to deliver the peer information snapshot.
        respond_to: oneshot::Sender<PeerInfoSnapshot>,
    },
}
