//! Error and event surfaces for the preconfirmation P2P driver.

use libp2p::Multiaddr;
use preconfirmation_types::{
    GetCommitmentsByNumberResponse, GetRawTxListResponse, RawTxListGossip, SignedCommitment,
};
use std::{error::Error, fmt};

/// Classification of driver-level failures.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NetworkErrorKind {
    /// Failed to deserialize an inbound gossip frame.
    GossipDecode,
    /// Application-level validation rejected a gossip payload.
    GossipValidation,
    /// Gossip payload was malformed or violated protocol rules.
    GossipInvalid,
    /// Request/response body failed validation.
    ReqRespValidation,
    /// Request/response codec failed (framing/SSZ/varint).
    ReqRespCodec,
    /// Request was dropped by rate limiting.
    ReqRespRateLimited,
    /// Request could not be sent due to backpressure.
    ReqRespBackpressure,
    /// Remote returned/triggered a generic req/resp failure.
    ReqRespFailure,
    /// Request/response timed out.
    ReqRespTimeout,
    /// Dial attempt failed.
    DialFailed,
    /// Peer disconnected unexpectedly.
    Disconnect,
    /// Kona gater or blocklist rejected the peer.
    GateBlocked,
    /// Failed to publish a gossip message.
    PublishFailure,
    /// Failed to enqueue a driver command.
    SendCommandFailed,
    /// Internal channel backpressure dropped an event.
    ChannelBackpressure,
    /// Catch-all for uncategorized errors.
    Other,
}

impl NetworkErrorKind {
    /// String label used for metrics/logs.
    pub fn as_str(&self) -> &'static str {
        match self {
            NetworkErrorKind::GossipDecode => "gossip_decode",
            NetworkErrorKind::GossipValidation => "gossip_validation",
            NetworkErrorKind::GossipInvalid => "gossip_invalid",
            NetworkErrorKind::ReqRespValidation => "reqresp_validation",
            NetworkErrorKind::ReqRespCodec => "reqresp_codec",
            NetworkErrorKind::ReqRespRateLimited => "reqresp_rate_limited",
            NetworkErrorKind::ReqRespBackpressure => "reqresp_backpressure",
            NetworkErrorKind::ReqRespFailure => "reqresp_failure",
            NetworkErrorKind::ReqRespTimeout => "reqresp_timeout",
            NetworkErrorKind::DialFailed => "dial_failed",
            NetworkErrorKind::Disconnect => "disconnect",
            NetworkErrorKind::GateBlocked => "gate_blocked",
            NetworkErrorKind::PublishFailure => "publish_failure",
            NetworkErrorKind::SendCommandFailed => "send_command_failed",
            NetworkErrorKind::ChannelBackpressure => "channel_backpressure",
            NetworkErrorKind::Other => "other",
        }
    }
}

/// Categorized network error surfaced to callers.
#[derive(Debug, Clone)]
pub struct NetworkError {
    /// Classification of the error.
    pub kind: NetworkErrorKind,
    /// Human-readable context.
    pub detail: String,
}

impl NetworkError {
    /// Construct a new error with the given kind and detail.
    pub fn new(kind: NetworkErrorKind, detail: impl Into<String>) -> Self {
        Self { kind, detail: detail.into() }
    }
}

impl From<String> for NetworkError {
    /// Convert a string message into a generic network error.
    fn from(detail: String) -> Self {
        Self { kind: NetworkErrorKind::Other, detail }
    }
}

impl From<&str> for NetworkError {
    /// Convert a string slice into a generic network error.
    fn from(detail: &str) -> Self {
        Self { kind: NetworkErrorKind::Other, detail: detail.to_owned() }
    }
}

impl fmt::Display for NetworkError {
    /// Format the error for human-readable output.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.kind.as_str(), self.detail)
    }
}

impl Error for NetworkError {}

/// High-level events emitted by the network driver for consumption by the service.
#[derive(Debug, Clone)]
pub enum NetworkEvent {
    /// A new listening address was registered by the swarm.
    NewListenAddr(Multiaddr),
    /// A peer successfully connected.
    PeerConnected(libp2p::PeerId),
    /// A peer disconnected.
    PeerDisconnected(libp2p::PeerId),
    /// Received a signed commitment over gossip.
    GossipSignedCommitment { from: libp2p::PeerId, msg: Box<SignedCommitment> },
    /// Received a raw txlist gossip payload.
    GossipRawTxList { from: libp2p::PeerId, msg: Box<RawTxListGossip> },
    /// Received a commitments response to an outbound request.
    ReqRespCommitments { from: libp2p::PeerId, msg: GetCommitmentsByNumberResponse },
    /// Received a raw-txlist response to an outbound request.
    ReqRespRawTxList { from: libp2p::PeerId, msg: GetRawTxListResponse },
    /// Received a head response to an outbound request.
    ReqRespHead { from: libp2p::PeerId, head: preconfirmation_types::PreconfHead },
    /// Inbound commitments request arrived.
    InboundCommitmentsRequest { from: libp2p::PeerId },
    /// Inbound raw-txlist request arrived.
    InboundRawTxListRequest { from: libp2p::PeerId },
    /// Inbound head request arrived.
    InboundHeadRequest { from: libp2p::PeerId },
    /// Driver started.
    Started,
    /// Driver stopped.
    Stopped,
    /// Driver emitted an error.
    Error(NetworkError),
}
