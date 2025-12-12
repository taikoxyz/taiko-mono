use libp2p::PeerId;
pub use preconfirmation_types::{
    Bytes32, GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse, GetRawTxListRequest,
    GetRawTxListResponse, PreconfCommitment, PreconfHead, Preconfirmation, RawTxListGossip,
    SignedCommitment, Uint256,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HeadSyncStatus {
    Idle,
    Syncing { local: Uint256, remote: Uint256 },
    Live { head: Uint256 },
}

#[derive(Debug, Clone)]
pub enum SdkEvent {
    GossipCommitment { from: PeerId, msg: SignedCommitment },
    GossipRawTxList { from: PeerId, msg: RawTxListGossip },
    ReqRespCommitments { from: PeerId, msg: GetCommitmentsByNumberResponse },
    ReqRespRawTxList { from: PeerId, msg: GetRawTxListResponse },
    ReqRespHead { from: PeerId, head: PreconfHead },
    InboundCommitmentsRequest { from: PeerId },
    InboundRawTxListRequest { from: PeerId },
    InboundHeadRequest { from: PeerId },
    PeerConnected(PeerId),
    PeerDisconnected(PeerId),
    HeadSync(HeadSyncStatus),
    Error(String),
    Started,
    Stopped,
}

#[derive(Debug, Clone)]
pub enum SdkCommand {
    PublishCommitment(SignedCommitment),
    PublishRawTxList(RawTxListGossip),
    RequestCommitments { start_block: Uint256, max_count: u32 },
    RequestRawTxList { raw_tx_list_hash: Bytes32 },
    RequestHead,
    UpdateServedHead(PreconfHead),
}
