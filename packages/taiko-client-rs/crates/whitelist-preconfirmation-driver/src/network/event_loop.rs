//! Swarm and gossipsub event handling for the whitelist network.

use std::time::Instant;

use alloy_primitives::B256;
use libp2p::{Swarm, gossipsub};
use tokio::sync::mpsc;
use tracing::{debug, warn};

use super::{
    inbound::GossipsubInboundState,
    types::{Behaviour, BehaviourEvent, NetworkEvent, Topics},
};
use crate::{
    codec::{
        DecodedUnsafePayload, decode_envelope_ssz, decode_unsafe_payload_signature,
        decode_unsafe_response_message,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

/// Convert a gossipsub message acceptance decision into a metrics label.
fn acceptance_label(acceptance: &gossipsub::MessageAcceptance) -> &'static str {
    match acceptance {
        gossipsub::MessageAcceptance::Accept => "accepted",
        gossipsub::MessageAcceptance::Ignore => "ignored",
        gossipsub::MessageAcceptance::Reject => "rejected",
    }
}

/// Record a decode failure and return the standard inbound rejection tuple.
fn reject_decode_failure(topic: &'static str) -> (gossipsub::MessageAcceptance, &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_DECODE_FAILURES_TOTAL,
        "topic" => topic,
    )
    .increment(1);
    (gossipsub::MessageAcceptance::Reject, "decode_failed")
}

/// Handle one swarm event emitted by libp2p.
pub(super) async fn handle_swarm_event(
    event: libp2p::swarm::SwarmEvent<BehaviourEvent>,
    topics: &Topics,
    event_tx: &mpsc::Sender<NetworkEvent>,
    inbound_validation_state: &mut GossipsubInboundState,
    swarm: &mut Swarm<Behaviour>,
) -> Result<()> {
    match event {
        libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Gossipsub(event)) => {
            handle_gossipsub_event(*event, topics, event_tx, inbound_validation_state, swarm)
                .await?;
        }
        libp2p::swarm::SwarmEvent::NewListenAddr { address, .. } => {
            debug!(%address, "whitelist preconfirmation network listening");
        }
        libp2p::swarm::SwarmEvent::ConnectionEstablished { peer_id, .. } => {
            debug!(%peer_id, "peer connected");
        }
        libp2p::swarm::SwarmEvent::ConnectionClosed { peer_id, .. } => {
            debug!(%peer_id, "peer disconnected");
        }
        libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Ping | BehaviourEvent::Identify) => {}
        other => {
            debug!(event = ?other, "ignored swarm event");
        }
    }
    Ok(())
}

/// Handle one gossipsub event.
pub(super) async fn handle_gossipsub_event(
    event: gossipsub::Event,
    topics: &Topics,
    event_tx: &mpsc::Sender<NetworkEvent>,
    inbound_validation_state: &mut GossipsubInboundState,
    swarm: &mut Swarm<Behaviour>,
) -> Result<()> {
    let gossipsub::Event::Message { propagation_source, message_id, message, .. } = event else {
        return Ok(());
    };

    let topic = &message.topic;
    let from = propagation_source;
    let now = Instant::now();

    let mut report = |acceptance: gossipsub::MessageAcceptance| {
        // Explicitly report every decision so mesh scoring remains aligned with local validation.
        let _ = swarm.behaviour_mut().gossipsub.report_message_validation_result(
            &message_id,
            &from,
            acceptance,
        );
    };
    if *topic == topics.preconf_blocks.hash() {
        let (acceptance, inbound_label) = match decode_unsafe_payload_signature(&message.data) {
            Ok((wire_signature, payload_bytes)) => match decode_envelope_ssz(&payload_bytes) {
                Ok(envelope) => {
                    let payload = DecodedUnsafePayload { wire_signature, payload_bytes, envelope };
                    let acceptance = inbound_validation_state.validate_preconf_blocks(&payload);

                    if matches!(acceptance, gossipsub::MessageAcceptance::Accept) &&
                        let Err(err) = forward_event(
                            event_tx,
                            NetworkEvent::UnsafePayload { from, payload },
                        )
                        .await
                    {
                        // If forwarding to importer fails, reject to avoid silently accepting
                        // data that local consumers could not process.
                        report(gossipsub::MessageAcceptance::Reject);
                        return Err(err);
                    }

                    let inbound_label = acceptance_label(&acceptance);
                    (acceptance, inbound_label)
                }
                Err(err) => {
                    let (acceptance, inbound_label) = reject_decode_failure("preconf_blocks");
                    debug!(error = %err, "failed to decode unsafe payload");
                    (acceptance, inbound_label)
                }
            },
            Err(err) => {
                let (acceptance, inbound_label) = reject_decode_failure("preconf_blocks");
                debug!(error = %err, "failed to decode unsafe payload");
                (acceptance, inbound_label)
            }
        };

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            "topic" => "preconf_blocks",
            "result" => inbound_label,
        )
        .increment(1);
        report(acceptance);
        return Ok(());
    }

    if *topic == topics.preconf_response.hash() {
        let (acceptance, inbound_label) = match decode_unsafe_response_message(&message.data) {
            Ok(envelope) => {
                let acceptance = inbound_validation_state.validate_response(&envelope);
                if matches!(acceptance, gossipsub::MessageAcceptance::Accept) &&
                    let Err(err) =
                        forward_event(event_tx, NetworkEvent::UnsafeResponse { from, envelope })
                            .await
                {
                    report(gossipsub::MessageAcceptance::Reject);
                    return Err(err);
                }

                let inbound_label = acceptance_label(&acceptance);
                (acceptance, inbound_label)
            }
            Err(err) => {
                let (acceptance, inbound_label) = reject_decode_failure("response_preconf_blocks");
                debug!(error = %err, "failed to decode unsafe response");
                (acceptance, inbound_label)
            }
        };

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            "topic" => "response_preconf_blocks",
            "result" => inbound_label,
        )
        .increment(1);
        report(acceptance);
        return Ok(());
    }

    if *topic == topics.preconf_request.hash() {
        let Some(hash) = decode_request_hash_exact(&message.data) else {
            let (acceptance, inbound_label) = reject_decode_failure("request_preconf_blocks");
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
                "topic" => "request_preconf_blocks",
                "result" => inbound_label,
            )
            .increment(1);
            report(acceptance);
            return Ok(());
        };

        let acceptance = inbound_validation_state.validate_request(from, hash, now);
        if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
            // Requests are relayed only after inbound dedupe/rate checks pass.
            forward_event(event_tx, NetworkEvent::UnsafeRequest { from, hash }).await?;
        }

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            "topic" => "request_preconf_blocks",
            "result" => acceptance_label(&acceptance),
        )
        .increment(1);
        report(acceptance);
        return Ok(());
    }

    if *topic == topics.eos_request.hash() {
        let Some(epoch) = decode_eos_epoch_exact(&message.data) else {
            let (acceptance, inbound_label) = reject_decode_failure("request_eos_preconf_blocks");
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
                "topic" => "request_eos_preconf_blocks",
                "result" => inbound_label,
            )
            .increment(1);
            report(acceptance);
            return Ok(());
        };

        let acceptance = inbound_validation_state.validate_eos_request(from, epoch, now);
        if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
            // EOS requests follow the same acceptance gate as preconf requests.
            forward_event(event_tx, NetworkEvent::EndOfSequencingRequest { from, epoch }).await?;
        }

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            "topic" => "request_eos_preconf_blocks",
            "result" => acceptance_label(&acceptance),
        )
        .increment(1);
        report(acceptance);
    }

    Ok(())
}

/// Decode an end-of-sequencing request epoch from big-endian bytes.
#[cfg(test)]
pub(super) fn decode_eos_epoch(payload: &[u8]) -> u64 {
    let mut bytes = [0u8; 8];
    let to_copy = payload.len().min(8);

    if to_copy > 0 {
        let source_start = payload.len() - to_copy;
        bytes[8 - to_copy..].copy_from_slice(&payload[source_start..]);
    }

    u64::from_be_bytes(bytes)
}

/// Decode an end-of-sequencing epoch when the payload is exactly 8 bytes.
pub(super) fn decode_eos_epoch_exact(payload: &[u8]) -> Option<u64> {
    let bytes: [u8; 8] = payload.try_into().ok()?;
    Some(u64::from_be_bytes(bytes))
}

/// Decode a request hash from big-endian bytes with set-bytes compatibility semantics.
#[cfg(test)]
pub(super) fn decode_request_hash(payload: &[u8]) -> B256 {
    let mut bytes = [0u8; 32];
    let to_copy = payload.len().min(32);

    if to_copy > 0 {
        let source_start = payload.len() - to_copy;
        bytes[32 - to_copy..].copy_from_slice(&payload[source_start..]);
    }

    B256::from(bytes)
}

/// Decode a 32-byte request hash payload exactly (non-padded path).
pub(super) fn decode_request_hash_exact(payload: &[u8]) -> Option<B256> {
    let bytes: [u8; 32] = payload.try_into().ok()?;
    Some(B256::from(bytes))
}

/// Forward one decoded event to the importer with backpressure.
pub(super) async fn forward_event(
    event_tx: &mpsc::Sender<NetworkEvent>,
    event: NetworkEvent,
) -> Result<()> {
    event_tx.send(event).await.map_err(|err| {
        metrics::counter!(WhitelistPreconfirmationDriverMetrics::NETWORK_FORWARD_FAILURES_TOTAL)
            .increment(1);
        warn!(error = %err, "whitelist preconfirmation event channel closed");
        WhitelistPreconfirmationDriverError::p2p(format!(
            "whitelist preconfirmation event channel closed: {err}"
        ))
    })
}
