use preconfirmation_types::{
    GetCommitmentsByNumberResponse, GetRawTxListResponse, RawTxListGossip, SignedCommitment,
};

/// High-level events emitted by the network driver for consumption by the service.
///
/// These events abstract away the underlying libp2p details and provide a clean
/// interface for the network service to react to network activities.
#[derive(Debug)]
pub enum NetworkEvent {
    /// A peer successfully established a connection with the local node.
    PeerConnected(libp2p::PeerId),
    /// A peer disconnected from the local node.
    PeerDisconnected(libp2p::PeerId),
    /// An inbound gossipsub message carrying a signed preconfirmation commitment.
    GossipSignedCommitment {
        /// The `PeerId` of the peer from which the message was propagated.
        from: libp2p::PeerId,
        /// The boxed `SignedCommitment` message.
        msg: Box<SignedCommitment>,
    },
    /// An inbound gossipsub message carrying a raw transaction list blob.
    GossipRawTxList {
        /// The `PeerId` of the peer from which the message was propagated.
        from: libp2p::PeerId,
        /// The boxed `RawTxListGossip` message.
        msg: Box<RawTxListGossip>,
    },
    /// A response to our request for a range of commitments.
    ReqRespCommitments {
        /// The `PeerId` of the peer that sent the response.
        from: libp2p::PeerId,
        /// The `GetCommitmentsByNumberResponse` message.
        msg: GetCommitmentsByNumberResponse,
    },
    /// A response to our request for a raw transaction list.
    ReqRespRawTxList {
        /// The `PeerId` of the peer that sent the response.
        from: libp2p::PeerId,
        /// The `GetRawTxListResponse` message.
        msg: GetRawTxListResponse,
    },
    /// A response to our request for a peer's preconfirmation head.
    ReqRespHead {
        /// The `PeerId` of the peer that sent the response.
        from: libp2p::PeerId,
        /// The `PreconfHead` message.
        head: preconfirmation_types::PreconfHead,
    },
    /// An inbound request from a peer for commitments.
    InboundCommitmentsRequest {
        /// The `PeerId` of the peer that sent the request.
        from: libp2p::PeerId,
    },
    /// An inbound request from a peer for a raw transaction list.
    InboundRawTxListRequest {
        /// The `PeerId` of the peer that sent the request.
        from: libp2p::PeerId,
    },
    /// An inbound request from a peer for our preconfirmation head.
    InboundHeadRequest {
        /// The `PeerId` of the peer that sent the request.
        from: libp2p::PeerId,
    },
    /// The network driver has started successfully.
    Started,
    /// The network driver has stopped.
    Stopped,
    /// An error occurred within the network driver.
    Error(String),
}
