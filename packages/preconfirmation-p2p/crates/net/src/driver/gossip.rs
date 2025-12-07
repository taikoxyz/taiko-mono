use libp2p::gossipsub::{self, MessageAcceptance};
use preconfirmation_types::{RawTxListGossip, SignedCommitment};

use super::*;

impl NetworkDriver {
    /// Handles `gossipsub::Event`s.
    pub(super) fn handle_gossipsub_event(&mut self, ev: gossipsub::Event) {
        if let gossipsub::Event::Message { propagation_source, message_id, message, .. } = ev {
            if self.reputation.is_banned(&propagation_source) {
                metrics::counter!("p2p_gossip_dropped_banned").increment(1);
                return;
            }

            let topic = message.topic.clone();
            if topic == self.topics.0.hash() {
                match SignedCommitment::deserialize(&message.data) {
                    Ok(msg) => {
                        if self
                            .validator
                            .validate_gossip_commitment(&propagation_source, &msg)
                            .is_ok()
                        {
                            // TODO: reintroduce lookahead/schedule gating and parent linkage
                            // checks.
                            let _ = self
                                .swarm
                                .behaviour_mut()
                                .gossipsub
                                .report_message_validation_result(
                                    &message_id,
                                    &propagation_source,
                                    MessageAcceptance::Accept,
                                );
                            metrics::counter!("p2p_gossip_valid", "kind" => "commitment")
                                .increment(1);
                            self.apply_reputation(propagation_source, PeerAction::GossipValid);
                            let _ = self.events_tx.try_send(NetworkEvent::GossipSignedCommitment {
                                from: propagation_source,
                                msg: Box::new(msg),
                            });
                        } else {
                            let _ = self
                                .swarm
                                .behaviour_mut()
                                .gossipsub
                                .report_message_validation_result(
                                    &message_id,
                                    &propagation_source,
                                    MessageAcceptance::Reject,
                                );
                            metrics::counter!("p2p_gossip_invalid", "kind" => "commitment", "reason" => "validation").increment(1);
                            self.apply_reputation(propagation_source, PeerAction::GossipInvalid);
                            self.emit_error(
                                NetworkErrorKind::GossipValidation,
                                "invalid signed commitment gossip",
                            );
                        }
                    }
                    Err(_) => {
                        let _ =
                            self.swarm.behaviour_mut().gossipsub.report_message_validation_result(
                                &message_id,
                                &propagation_source,
                                MessageAcceptance::Reject,
                            );
                        metrics::counter!("p2p_gossip_invalid", "kind" => "commitment", "reason" => "decode").increment(1);
                        self.apply_reputation(propagation_source, PeerAction::GossipInvalid);
                        self.emit_error(
                            NetworkErrorKind::GossipDecode,
                            "invalid signed commitment gossip",
                        );
                    }
                }
            } else if topic == self.topics.1.hash() {
                match RawTxListGossip::deserialize(&message.data) {
                    Ok(msg) => {
                        if self
                            .validator
                            .validate_gossip_raw_txlist(&propagation_source, &msg)
                            .is_ok()
                        {
                            let _ = self
                                .swarm
                                .behaviour_mut()
                                .gossipsub
                                .report_message_validation_result(
                                    &message_id,
                                    &propagation_source,
                                    MessageAcceptance::Accept,
                                );
                            metrics::counter!("p2p_gossip_valid", "kind" => "raw_txlists")
                                .increment(1);
                            self.apply_reputation(propagation_source, PeerAction::GossipValid);
                            let _ = self.events_tx.try_send(NetworkEvent::GossipRawTxList {
                                from: propagation_source,
                                msg: Box::new(msg),
                            });
                        } else {
                            let _ = self
                                .swarm
                                .behaviour_mut()
                                .gossipsub
                                .report_message_validation_result(
                                    &message_id,
                                    &propagation_source,
                                    MessageAcceptance::Reject,
                                );
                            metrics::counter!("p2p_gossip_invalid", "kind" => "raw_txlists", "reason" => "validation").increment(1);
                            self.apply_reputation(propagation_source, PeerAction::GossipInvalid);
                            self.emit_error(
                                NetworkErrorKind::GossipValidation,
                                "invalid raw txlist gossip",
                            );
                        }
                    }
                    Err(_) => {
                        let _ =
                            self.swarm.behaviour_mut().gossipsub.report_message_validation_result(
                                &message_id,
                                &propagation_source,
                                MessageAcceptance::Reject,
                            );
                        metrics::counter!("p2p_gossip_invalid", "kind" => "raw_txlists", "reason" => "decode").increment(1);
                        self.apply_reputation(propagation_source, PeerAction::GossipInvalid);
                        self.emit_error(
                            NetworkErrorKind::GossipDecode,
                            "invalid raw txlist gossip",
                        );
                    }
                }
            }
        }
    }
}
