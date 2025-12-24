//! Public types for the P2P SDK.
//!
//! This module defines the SDK-level event and command types that layer on top
//! of the network-level types from `preconfirmation-net`.

use alloy_primitives::B256;
use preconfirmation_types::{
    GetCommitmentsByNumberResponse, GetRawTxListResponse, PreconfHead, RawTxListGossip,
    SignedCommitment,
};

/// High-level events emitted by the P2P SDK for consumption by application code.
///
/// These events wrap the lower-level [`NetworkEvent`](preconfirmation_net::NetworkEvent)
/// variants and add SDK-specific events like head sync status.
#[derive(Debug, Clone)]
pub enum SdkEvent {
    /// A peer successfully connected.
    PeerConnected {
        /// The connected peer's ID.
        peer: libp2p::PeerId,
    },
    /// A peer disconnected.
    PeerDisconnected {
        /// The disconnected peer's ID.
        peer: libp2p::PeerId,
    },
    /// Received a signed commitment over gossip.
    CommitmentGossip {
        /// Peer that sent the gossip message.
        from: libp2p::PeerId,
        /// The signed commitment received.
        commitment: Box<SignedCommitment>,
    },
    /// Received a raw txlist gossip payload.
    RawTxListGossip {
        /// Peer that sent the gossip message.
        from: libp2p::PeerId,
        /// The raw txlist gossip message.
        msg: Box<RawTxListGossip>,
    },
    /// Received a commitments response to an outbound request.
    ReqRespCommitments {
        /// Peer that responded.
        from: libp2p::PeerId,
        /// The commitments response.
        msg: GetCommitmentsByNumberResponse,
    },
    /// Received a raw-txlist response to an outbound request.
    ReqRespRawTxList {
        /// Peer that responded.
        from: libp2p::PeerId,
        /// The raw txlist response.
        msg: GetRawTxListResponse,
    },
    /// Received a head response to an outbound request.
    ReqRespHead {
        /// Peer that responded.
        from: libp2p::PeerId,
        /// The preconfirmation head.
        head: PreconfHead,
    },
    /// Head sync status changed.
    HeadSyncStatus {
        /// Whether the SDK is synced with the network head.
        synced: bool,
    },
    /// An error occurred in the SDK.
    Error {
        /// Human-readable error description.
        detail: String,
    },
    /// An L1 reorg was detected that affects the anchor block.
    ///
    /// Per spec §6.3, this event signals downstream consumers to re-execute
    /// commitments from the affected anchor block. This can occur when:
    /// - The L1 chain reorganizes and the anchor block hash changes
    /// - The preconfirmation chain needs to be rebuilt from a new anchor point
    Reorg {
        /// The anchor block number that was affected by the reorg.
        anchor_block_number: u64,
        /// Human-readable reason for the reorg event.
        reason: String,
    },
}

/// Commands that can be sent to the P2P SDK client.
///
/// These commands allow the application to publish messages, request data,
/// and control the SDK lifecycle.
#[derive(Debug, Clone)]
pub enum SdkCommand {
    /// Publish a signed commitment to the network.
    PublishCommitment(Box<SignedCommitment>),
    /// Publish a raw txlist to the network.
    PublishRawTxList(Box<RawTxListGossip>),
    /// Request commitments starting from a block number.
    RequestCommitments {
        /// Starting block number.
        start_block: u64,
        /// Maximum number of commitments to request.
        max_count: u32,
    },
    /// Request a raw txlist by hash.
    RequestRawTxList {
        /// Hash of the raw txlist to request.
        hash: B256,
    },
    /// Request the current preconfirmation head.
    RequestHead,
    /// Update the local preconfirmation head and broadcast to network.
    UpdateHead {
        /// The new head block number.
        block_number: u64,
        /// The submission window end timestamp for the head.
        submission_window_end: u64,
    },
    /// Start catch-up sync from local head to network head.
    StartCatchup {
        /// Local head block number to start from.
        local_head: u64,
        /// Network head block number to sync to.
        network_head: u64,
    },
    /// Shutdown the SDK client.
    Shutdown,
    /// Notify the SDK of an L1 reorg affecting the anchor block.
    ///
    /// Per spec §6.3, this command signals that an L1 reorg was detected
    /// and downstream consumers need to re-execute commitments from the
    /// affected anchor block. The SDK will emit a corresponding `SdkEvent::Reorg`.
    NotifyReorg {
        /// The anchor block number that was affected by the reorg.
        anchor_block_number: u64,
        /// Human-readable reason for the reorg notification.
        reason: String,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sdk_event_covers_gossip_and_reqresp() {
        // Test that SdkEvent can represent peer connectivity events
        let _ = SdkEvent::PeerConnected { peer: libp2p::PeerId::random() };

        // Test that SdkEvent can represent gossip events
        let peer = libp2p::PeerId::random();
        let _ = SdkEvent::PeerDisconnected { peer };
    }

    #[test]
    fn sdk_event_covers_all_network_event_variants() {
        use preconfirmation_types::{
            GetCommitmentsByNumberResponse, GetRawTxListResponse, PreconfHead,
        };

        let peer = libp2p::PeerId::random();

        // Peer events
        let _ = SdkEvent::PeerConnected { peer };
        let _ = SdkEvent::PeerDisconnected { peer };

        // Gossip events
        let _ = SdkEvent::CommitmentGossip { from: peer, commitment: Box::default() };
        let _ = SdkEvent::RawTxListGossip { from: peer, msg: Box::default() };

        // Req/resp events
        let _ = SdkEvent::ReqRespCommitments {
            from: peer,
            msg: GetCommitmentsByNumberResponse::default(),
        };
        let _ = SdkEvent::ReqRespRawTxList { from: peer, msg: GetRawTxListResponse::default() };
        let _ = SdkEvent::ReqRespHead { from: peer, head: PreconfHead::default() };

        // Status events
        let _ = SdkEvent::HeadSyncStatus { synced: true };
        let _ = SdkEvent::Error { detail: "test error".to_string() };
    }

    #[test]
    fn sdk_command_covers_publish_and_request() {
        use alloy_primitives::B256;

        // Publish commands
        let _ = SdkCommand::PublishCommitment(Box::default());
        let _ = SdkCommand::PublishRawTxList(Box::default());

        // Request commands
        let _ = SdkCommand::RequestCommitments { start_block: 0, max_count: 10 };
        let _ = SdkCommand::RequestRawTxList { hash: B256::ZERO };
        let _ = SdkCommand::RequestHead;

        // Control commands - UpdateHead includes both block_number and submission_window_end
        // for constructing the full PreconfHead to send to the network
        let _ = SdkCommand::UpdateHead { block_number: 100, submission_window_end: 2000 };
        let _ = SdkCommand::StartCatchup { local_head: 0, network_head: 100 };
        let _ = SdkCommand::Shutdown;
    }

    #[test]
    fn update_head_command_has_required_fields() {
        // Verify UpdateHead has both fields needed to construct PreconfHead
        let cmd = SdkCommand::UpdateHead { block_number: 12345, submission_window_end: 1700000000 };

        if let SdkCommand::UpdateHead { block_number, submission_window_end } = cmd {
            assert_eq!(block_number, 12345);
            assert_eq!(submission_window_end, 1700000000);
        } else {
            panic!("Expected UpdateHead variant");
        }
    }
}

/// Tests for reorg handling hook (Task 8).
#[cfg(test)]
mod reorg {
    pub mod tests {
        use super::super::*;

        #[test]
        fn reorg_hook_records_anchor_reexec_request() {
            // Test that SdkEvent can represent a reorg event for downstream consumers
            // Reorg event signals L1 reorgs affecting anchor_block_number per spec §6.3
            let event = SdkEvent::Reorg {
                anchor_block_number: 12345,
                reason: "L1 chain reorganization detected".to_string(),
            };

            if let SdkEvent::Reorg { anchor_block_number, reason } = event {
                assert_eq!(anchor_block_number, 12345);
                assert!(reason.contains("reorganization"));
            } else {
                panic!("Expected Reorg variant");
            }
        }

        #[test]
        fn notify_reorg_command_exists() {
            // Test that SdkCommand has a NotifyReorg variant to signal L1 reorgs
            let cmd = SdkCommand::NotifyReorg {
                anchor_block_number: 12345,
                reason: "L1 reorg detected".to_string(),
            };

            if let SdkCommand::NotifyReorg { anchor_block_number, reason } = cmd {
                assert_eq!(anchor_block_number, 12345);
                assert!(reason.contains("reorg"));
            } else {
                panic!("Expected NotifyReorg variant");
            }
        }
    }
}
