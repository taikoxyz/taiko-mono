//! Gossipsub event handling for the network driver.
//!
//! This module processes incoming gossip messages on the commitments and raw
//! transaction list topics, decoding SSZ payloads, validating them, reporting
//! gossip validation results, updating peer reputation, and emitting events.

use libp2p::gossipsub::{self, MessageAcceptance};
use preconfirmation_types::{RawTxListGossip, SignedCommitment, bytes32_to_b256, uint256_to_u256};

use super::*;

/// Identifies which gossip topic payload is being processed.
#[derive(Clone, Copy)]
enum GossipKind {
    /// Signed commitment payloads on the commitments topic.
    Commitment,
    /// Raw transaction list payloads on the raw txlists topic.
    RawTxList,
}

impl GossipKind {
    /// Returns the label used for metrics for this gossip kind.
    fn label(self) -> &'static str {
        match self {
            GossipKind::Commitment => "commitment",
            GossipKind::RawTxList => "raw_txlists",
        }
    }

    /// Returns the error string used when decoding fails.
    fn decode_error(self) -> &'static str {
        match self {
            GossipKind::Commitment => "invalid signed commitment gossip",
            GossipKind::RawTxList => "invalid raw txlist gossip",
        }
    }

    /// Returns the error string used when validation fails.
    fn validation_error(self) -> &'static str {
        match self {
            GossipKind::Commitment => "invalid signed commitment gossip",
            GossipKind::RawTxList => "invalid raw txlist gossip",
        }
    }
}

impl NetworkDriver {
    /// Report the gossipsub validation result for a message.
    fn report_gossip_result(
        &mut self,
        message_id: &gossipsub::MessageId,
        peer: &PeerId,
        acceptance: MessageAcceptance,
    ) {
        let _ = self
            .swarm
            .behaviour_mut()
            .gossipsub
            .report_message_validation_result(message_id, peer, acceptance);
    }

    /// Shared handler for decoding, validating, scoring, and emitting a gossip payload.
    fn handle_gossip_payload<T, E>(
        &mut self,
        kind: GossipKind,
        propagation_source: PeerId,
        message_id: &gossipsub::MessageId,
        decode: impl FnOnce() -> Result<T, E>,
        validate: impl FnOnce(&dyn ValidationAdapter, &PeerId, &T) -> Result<(), String>,
        on_valid: impl FnOnce(&mut Self, PeerId, T),
    ) {
        match decode() {
            Ok(msg) => {
                if validate(self.validator.as_ref(), &propagation_source, &msg).is_ok() {
                    self.report_gossip_result(
                        message_id,
                        &propagation_source,
                        MessageAcceptance::Accept,
                    );
                    metrics::counter!("p2p_gossip_valid", "kind" => kind.label()).increment(1);
                    self.apply_reputation(propagation_source, PeerAction::GossipValid);
                    on_valid(self, propagation_source, msg);
                } else {
                    self.report_gossip_result(
                        message_id,
                        &propagation_source,
                        MessageAcceptance::Reject,
                    );
                    metrics::counter!("p2p_gossip_invalid", "kind" => kind.label(), "reason" => "validation").increment(1);
                    self.apply_reputation(propagation_source, PeerAction::GossipInvalid);
                    self.emit_error(NetworkErrorKind::GossipValidation, kind.validation_error());
                }
            }
            Err(_) => {
                self.report_gossip_result(
                    message_id,
                    &propagation_source,
                    MessageAcceptance::Reject,
                );
                metrics::counter!("p2p_gossip_invalid", "kind" => kind.label(), "reason" => "decode")
                    .increment(1);
                self.apply_reputation(propagation_source, PeerAction::GossipInvalid);
                self.emit_error(NetworkErrorKind::GossipDecode, kind.decode_error());
            }
        }
    }

    /// Handles `gossipsub::Event`s.
    pub(super) fn handle_gossipsub_event(&mut self, ev: gossipsub::Event) {
        if let gossipsub::Event::Message { propagation_source, message_id, message, .. } = ev {
            if self.reputation.is_banned(&propagation_source) {
                self.report_gossip_result(
                    &message_id,
                    &propagation_source,
                    MessageAcceptance::Reject,
                );
                metrics::counter!("p2p_gossip_dropped_banned").increment(1);
                return;
            }

            let topic = message.topic.clone();
            if topic == self.topics.0.hash() {
                self.handle_gossip_payload(
                    GossipKind::Commitment,
                    propagation_source,
                    &message_id,
                    || SignedCommitment::deserialize(&message.data),
                    |validator, peer, msg| validator.validate_gossip_commitment(peer, msg),
                    |driver, peer, msg| {
                        let block_number = uint256_to_u256(&msg.commitment.preconf.block_number);
                        driver.storage.insert_commitment(block_number, msg.clone());
                        let _ = driver.events_tx.try_send(NetworkEvent::GossipSignedCommitment {
                            from: peer,
                            msg: Box::new(msg),
                        });
                    },
                );
            } else if topic == self.topics.1.hash() {
                self.handle_gossip_payload(
                    GossipKind::RawTxList,
                    propagation_source,
                    &message_id,
                    || RawTxListGossip::deserialize(&message.data),
                    |validator, peer, msg| validator.validate_gossip_raw_txlist(peer, msg),
                    |driver, peer, msg| {
                        let hash = bytes32_to_b256(&msg.raw_tx_list_hash);
                        driver.storage.insert_txlist(hash, msg.clone());
                        let _ = driver.events_tx.try_send(NetworkEvent::GossipRawTxList {
                            from: peer,
                            msg: Box::new(msg),
                        });
                    },
                );
            } else {
                self.report_gossip_result(
                    &message_id,
                    &propagation_source,
                    MessageAcceptance::Reject,
                );
            }
        }
    }
}
