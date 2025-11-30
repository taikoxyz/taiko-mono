use preconfirmation_types::{
    GetCommitmentsByNumberResponse, GetRawTxListResponse, RawTxListGossip, SignedCommitment,
};

/// High-level events emitted by the network driver for consumption by the service.
#[derive(Debug)]
pub enum NetworkEvent {
    /// A peer successfully established a connection.
    PeerConnected(libp2p::PeerId),
    /// A peer disconnected.
    PeerDisconnected(libp2p::PeerId),
    /// Inbound gossipsub message carrying a signed commitment.
    GossipSignedCommitment {
        from: libp2p::PeerId,
        msg: SignedCommitment,
    },
    /// Inbound gossipsub message carrying a raw tx list blob.
    GossipRawTxList {
        from: libp2p::PeerId,
        msg: RawTxListGossip,
    },
    /// Response to our commitment range request.
    ReqRespCommitments {
        from: libp2p::PeerId,
        msg: GetCommitmentsByNumberResponse,
    },
    /// Response to our raw-txlist request.
    ReqRespRawTxList {
        from: libp2p::PeerId,
        msg: GetRawTxListResponse,
    },
    /// Response to our get_head request.
    ReqRespHead {
        from: libp2p::PeerId,
        head: preconfirmation_types::PreconfHead,
    },
    /// Peer asked us for commitments (payload currently defaulted).
    InboundCommitmentsRequest {
        from: libp2p::PeerId,
    },
    /// Peer asked us for a raw tx list (payload currently defaulted).
    InboundRawTxListRequest {
        from: libp2p::PeerId,
    },
    /// Peer asked us for our preconfirmation head.
    InboundHeadRequest {
        from: libp2p::PeerId,
    },
    /// Driver lifecycle events.
    Started,
    Stopped,
    /// Driver-level error surfaced for observability.
    Error(String),
}
