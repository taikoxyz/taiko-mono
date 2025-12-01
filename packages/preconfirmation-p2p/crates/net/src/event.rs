use preconfirmation_types::{
    GetCommitmentsByNumberResponse, GetRawTxListResponse, RawTxListGossip, SignedCommitment,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NetworkErrorKind {
    GossipDecode,
    GossipValidation,
    GossipInvalid,
    ReqRespValidation,
    ReqRespCodec,
    ReqRespRateLimited,
    ReqRespBackpressure,
    ReqRespFailure,
    ReqRespTimeout,
    Discovery,
    DialFailed,
    Disconnect,
    GateBlocked,
    PublishFailure,
    SendCommandFailed,
    ChannelBackpressure,
    Other,
}

impl NetworkErrorKind {
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
            NetworkErrorKind::Discovery => "discovery",
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
    pub kind: NetworkErrorKind,
    pub detail: String,
}

impl NetworkError {
    pub fn new(kind: NetworkErrorKind, detail: impl Into<String>) -> Self {
        Self { kind, detail: detail.into() }
    }
}

impl From<String> for NetworkError {
    fn from(detail: String) -> Self {
        Self { kind: NetworkErrorKind::Other, detail }
    }
}

impl From<&str> for NetworkError {
    fn from(detail: &str) -> Self {
        Self { kind: NetworkErrorKind::Other, detail: detail.to_owned() }
    }
}

impl std::fmt::Display for NetworkError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.kind.as_str(), self.detail)
    }
}

impl std::error::Error for NetworkError {}

/// High-level events emitted by the network driver for consumption by the service.
#[derive(Debug, Clone)]
pub enum NetworkEvent {
    PeerConnected(libp2p::PeerId),
    PeerDisconnected(libp2p::PeerId),
    GossipSignedCommitment { from: libp2p::PeerId, msg: Box<SignedCommitment> },
    GossipRawTxList { from: libp2p::PeerId, msg: Box<RawTxListGossip> },
    ReqRespCommitments { from: libp2p::PeerId, msg: GetCommitmentsByNumberResponse },
    ReqRespRawTxList { from: libp2p::PeerId, msg: GetRawTxListResponse },
    ReqRespHead { from: libp2p::PeerId, head: preconfirmation_types::PreconfHead },
    InboundCommitmentsRequest { from: libp2p::PeerId },
    InboundRawTxListRequest { from: libp2p::PeerId },
    InboundHeadRequest { from: libp2p::PeerId },
    Started,
    Stopped,
    Error(NetworkError),
}
