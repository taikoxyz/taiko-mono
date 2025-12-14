//! Client-level types and events.

use libp2p::PeerId;
pub use preconfirmation_types::{
    Bytes32, GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse, GetRawTxListRequest,
    GetRawTxListResponse, PreconfCommitment, PreconfHead, Preconfirmation, RawTxListGossip,
    SignedCommitment, Uint256,
};
use std::hash::{Hash, Hasher};

/// Progress state for the preconfirmation head catch-up process.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HeadSyncStatus {
    /// No catch-up in progress (either idle pre-start or fully live).
    Idle,
    /// Paging commitments from peers. `local` and `remote` track block numbers.
    Syncing {
        /// Local preconfirmation block number already processed.
        local: Uint256,
        /// Remote head reported by the peer.
        remote: Uint256,
    },
    /// Live gossip mode with the current known head.
    Live {
        /// Current preconfirmation head height.
        head: Uint256,
    },
}

/// High-level events surfaced by the client to sidecar consumers.
#[derive(Debug, Clone)]
#[allow(clippy::large_enum_variant)]
pub enum SdkEvent {
    /// Received a gossip `SignedCommitment` from a peer.
    GossipCommitment {
        /// Sender peer ID.
        from: PeerId,
        /// Commitment payload.
        msg: SignedCommitment,
    },
    /// Received a gossip `RawTxListGossip` from a peer.
    GossipRawTxList {
        /// Sender peer ID.
        from: PeerId,
        /// Raw txlist payload.
        msg: RawTxListGossip,
    },
    /// Response to a commitments range request.
    ReqRespCommitments {
        /// Responder peer ID.
        from: PeerId,
        /// Response payload containing commitments.
        msg: GetCommitmentsByNumberResponse,
    },
    /// Response to a raw txlist request.
    ReqRespRawTxList {
        /// Responder peer ID.
        from: PeerId,
        /// Response payload containing the raw txlist.
        msg: GetRawTxListResponse,
    },
    /// Response to a head request.
    ReqRespHead {
        /// Responder peer ID.
        from: PeerId,
        /// Reported preconfirmation head.
        head: PreconfHead,
    },
    /// Inbound commitments request served to us.
    InboundCommitmentsRequest {
        /// Requester peer ID.
        from: PeerId,
    },
    /// Inbound raw txlist request served to us.
    InboundRawTxListRequest {
        /// Requester peer ID.
        from: PeerId,
    },
    /// Inbound head request served to us.
    InboundHeadRequest {
        /// Requester peer ID.
        from: PeerId,
    },
    /// Peer connection lifecycle events.
    PeerConnected(PeerId),
    /// Peer disconnection lifecycle events.
    PeerDisconnected(PeerId),
    /// Catch-up status updates emitted by the client.
    HeadSync(HeadSyncStatus),
    /// Recoverable or reportable error surfaced to the consumer.
    Error(String),
    /// Network driver started.
    Started,
    /// Network driver stopped.
    Stopped,
}

/// Gossip topics supported by the client.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MessageTopic {
    /// Signed commitment gossipsub topic.
    Commitment,
    /// Raw tx list gossipsub topic.
    RawTxList,
}

/// Stable identifier for gossip messages used for deduplication.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MessageId {
    /// Topic the message belongs to.
    pub topic: MessageTopic,
    /// 32-byte content hash or identifier for the message payload.
    pub hash: [u8; 32],
}

impl MessageId {
    /// Construct a commitment message id from a payload hash.
    pub fn commitment(hash: [u8; 32]) -> Self {
        Self { topic: MessageTopic::Commitment, hash }
    }

    /// Construct a raw tx list message id from a payload hash.
    pub fn raw_txlist(hash: [u8; 32]) -> Self {
        Self { topic: MessageTopic::RawTxList, hash }
    }
}

impl Hash for MessageId {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.topic.hash(state);
        state.write(&self.hash);
    }
}

/// Intentions issued by callers to the client.
#[derive(Debug, Clone)]
#[allow(clippy::large_enum_variant)]
pub enum SdkCommand {
    /// Publish a signed commitment to gossipsub.
    PublishCommitment(SignedCommitment),
    /// Publish a raw txlist blob to gossipsub.
    PublishRawTxList(RawTxListGossip),
    /// Request a page of commitments starting at `start_block`.
    RequestCommitments {
        /// First block number to request (inclusive).
        start_block: Uint256,
        /// Maximum number of commitments to request.
        max_count: u32,
    },
    /// Request a raw txlist by hash.
    RequestRawTxList {
        /// Content hash of the desired raw txlist.
        raw_tx_list_hash: Bytes32,
    },
    /// Request peer head via req/resp.
    RequestHead,
    /// Update the head we serve to inbound `get_head` requests.
    UpdateServedHead(PreconfHead),
}
