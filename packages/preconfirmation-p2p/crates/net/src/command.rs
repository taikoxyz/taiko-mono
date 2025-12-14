use libp2p::PeerId;
use preconfirmation_types::{Bytes32, RawTxListGossip, SignedCommitment, Uint256};

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
        /// Caller-provided correlation id surfaced back with the response/error.
        request_id: Option<u64>,
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
        /// Caller-provided correlation id surfaced back with the response/error.
        request_id: Option<u64>,
        /// The hash of the raw transaction list to request.
        raw_tx_list_hash: Bytes32,
        /// The `PeerId` of the specific peer to send the request to. If `None`,
        /// the request can be sent to any connected peer.
        peer: Option<PeerId>,
    },
    /// Request the peer's current preconfirmation head (spec §10) from a specific
    /// `peer` (if specified) or any suitable peer.
    RequestHead {
        /// Caller-provided correlation id surfaced back with the response/error.
        request_id: Option<u64>,
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
    /// TODO: lookahead wiring temporarily disabled; retained for API compatibility.
    SetScheduleReady {
        /// True when schedule data is available for validation.
        ready: bool,
    },
    /// TODO: lookahead wiring temporarily disabled; retained for API compatibility.
    UpsertParentPreconf {
        /// Hash of the parent preconfirmation.
        hash: Bytes32,
        /// Parent preconfirmation body.
        preconf: preconfirmation_types::Preconfirmation,
    },
}
