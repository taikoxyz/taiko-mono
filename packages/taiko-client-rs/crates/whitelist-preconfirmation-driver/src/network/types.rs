//! Core type definitions for the whitelist preconfirmation network runtime.

use std::sync::Arc;

use alloy_primitives::B256;
use libp2p::{PeerId, gossipsub, identify, ping, swarm::NetworkBehaviour};
use tokio::{sync::mpsc, task::JoinHandle};

use crate::{
    codec::{DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope},
    error::Result,
};

#[derive(Debug)]
/// Network event emitted by the whitelist preconfirmation gossipsub stack.
pub(crate) enum NetworkEvent {
    /// Incoming `preconfBlocks` payload.
    UnsafePayload {
        /// Peer that propagated the message.
        from: PeerId,
        /// Decoded payload.
        payload: DecodedUnsafePayload,
    },
    /// Incoming `responsePreconfBlocks` payload.
    UnsafeResponse {
        /// Peer that propagated the message.
        from: PeerId,
        /// Decoded envelope.
        envelope: WhitelistExecutionPayloadEnvelope,
    },
    /// Incoming `requestPreconfBlocks` message.
    UnsafeRequest {
        /// Peer that propagated the message.
        from: PeerId,
        /// Requested block hash.
        hash: B256,
    },
    /// Incoming `requestEndOfSequencingPreconfBlocks` message.
    EndOfSequencingRequest {
        /// Peer that propagated the message.
        from: PeerId,
        /// Requested epoch.
        epoch: u64,
    },
}

/// Outbound commands for the whitelist preconfirmation network.
#[derive(Debug)]
pub(crate) enum NetworkCommand {
    /// Publish an unsafe-block request to the `requestPreconfBlocks` topic.
    PublishUnsafeRequest {
        /// Requested block hash.
        hash: B256,
    },
    /// Publish an unsafe-block response to the `responsePreconfBlocks` topic.
    PublishUnsafeResponse {
        /// Envelope to publish.
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    },
    /// Publish a signed unsafe payload to the `preconfBlocks` topic.
    PublishUnsafePayload {
        /// 65-byte secp256k1 signature.
        signature: [u8; 65],
        /// Envelope to publish.
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    },
    /// Publish an end-of-sequencing request to the `requestEndOfSequencingPreconfBlocks` topic.
    PublishEndOfSequencingRequest {
        /// Epoch number.
        epoch: u64,
    },
    /// Shutdown the network loop.
    Shutdown,
}

/// Handle to the running whitelist network.
pub(crate) struct WhitelistNetwork {
    /// Local peer id.
    pub(crate) local_peer_id: PeerId,
    /// Inbound event stream.
    pub(crate) event_rx: mpsc::Receiver<NetworkEvent>,
    /// Outbound command sender.
    pub(crate) command_tx: mpsc::Sender<NetworkCommand>,
    /// Background task running the swarm.
    pub(crate) handle: JoinHandle<Result<()>>,
}

#[derive(Clone)]
/// Group of gossipsub topics used by the whitelist preconfirmation driver.
pub(super) struct Topics {
    /// Topic carrying signed unsafe payload gossip.
    pub(super) preconf_blocks: gossipsub::IdentTopic,
    /// Topic used to request a payload by block hash.
    pub(super) preconf_request: gossipsub::IdentTopic,
    /// Topic used to answer payload-by-hash requests.
    pub(super) preconf_response: gossipsub::IdentTopic,
    /// Topic used by peers requesting end-of-sequencing payloads.
    pub(super) eos_request: gossipsub::IdentTopic,
}

impl Topics {
    /// Build all whitelist preconfirmation topic names for the given chain id.
    pub(super) fn new(chain_id: u64) -> Self {
        Self {
            preconf_blocks: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/preconfBlocks"
            )),
            preconf_request: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/requestPreconfBlocks"
            )),
            preconf_response: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/responsePreconfBlocks"
            )),
            eos_request: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/requestEndOfSequencingPreconfBlocks"
            )),
        }
    }
}

#[derive(NetworkBehaviour)]
#[behaviour(to_swarm = "BehaviourEvent")]
/// Composite libp2p behaviour used by the whitelist preconfirmation network runtime.
pub(super) struct Behaviour {
    /// Gossip transport for whitelist preconfirmation topics.
    pub(super) gossipsub: gossipsub::Behaviour,
    /// Ping protocol for liveness.
    pub(super) ping: ping::Behaviour,
    /// Identify protocol for peer metadata exchange.
    pub(super) identify: identify::Behaviour,
}

#[derive(Debug)]
/// Event wrapper for the nested libp2p behaviour components.
pub(super) enum BehaviourEvent {
    /// Wrapped gossipsub event.
    Gossipsub(Box<gossipsub::Event>),
    /// Ping event marker.
    Ping,
    /// Identify event marker.
    Identify,
}

impl From<gossipsub::Event> for BehaviourEvent {
    /// Convert a gossipsub event into a behaviour event.
    fn from(value: gossipsub::Event) -> Self {
        Self::Gossipsub(Box::new(value))
    }
}

impl From<ping::Event> for BehaviourEvent {
    /// Convert a ping event into a behaviour event.
    fn from(_: ping::Event) -> Self {
        Self::Ping
    }
}

impl From<identify::Event> for BehaviourEvent {
    /// Convert an identify event into a behaviour event.
    fn from(_: identify::Event) -> Self {
        Self::Identify
    }
}
