//! Swarm bootstrap and main network loop orchestration.

use std::collections::HashSet;

use futures::StreamExt;
use libp2p::{
    Multiaddr, Swarm, Transport, core::upgrade, dns, identify, identity, noise, ping, tcp, yamux,
};
use preconfirmation_net::{P2pConfig, spawn_discovery};
use tokio::sync::mpsc;
use tracing::{debug, warn};

use super::{
    bootnodes::{classify_bootnodes, dial_once, recv_discovered_multiaddr},
    event_loop::{forward_event, handle_swarm_event, to_p2p_err},
    gossip::build_gossipsub,
    inbound::GossipsubInboundState,
    types::{Behaviour, NetworkCommand, NetworkEvent, Topics, WhitelistNetwork},
};
use crate::{
    codec::{
        DecodedUnsafePayload, encode_envelope_ssz, encode_eos_request_message,
        encode_unsafe_payload_message, encode_unsafe_request_message,
        encode_unsafe_response_message,
    },
    error::Result,
    metrics::WhitelistPreconfirmationDriverMetrics,
};

/// Record one outbound publish lifecycle outcome for the given network topic label.
fn record_outbound_publish(topic: &'static str, result: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
        "topic" => topic,
        "result" => result,
    )
    .increment(1);
}

impl WhitelistNetwork {
    /// Spawn the whitelist preconfirmation network task.
    pub(crate) fn spawn_with_whitelist_filter(cfg: P2pConfig) -> Result<Self> {
        Self::spawn_with_filter(cfg)
    }

    /// Internal spawn path that wires transport, behaviour, and the event loop.
    fn spawn_with_filter(cfg: P2pConfig) -> Result<Self> {
        let local_key = identity::Keypair::generate_ed25519();
        let local_peer_id = local_key.public().to_peer_id();

        let topics = Topics::new(cfg.chain_id);
        let mut gossipsub = build_gossipsub()?;
        gossipsub.subscribe(&topics.preconf_blocks).map_err(to_p2p_err)?;
        gossipsub.subscribe(&topics.preconf_request).map_err(to_p2p_err)?;
        gossipsub.subscribe(&topics.preconf_response).map_err(to_p2p_err)?;
        gossipsub.subscribe(&topics.eos_request).map_err(to_p2p_err)?;

        let behaviour = Behaviour {
            gossipsub,
            ping: ping::Behaviour::new(ping::Config::new()),
            identify: identify::Behaviour::new(identify::Config::new(
                "/taiko/whitelist-preconfirmation/1.0.0".to_string(),
                local_key.public(),
            )),
        };

        let noise_config = noise::Config::new(&local_key).map_err(to_p2p_err)?;
        let base_tcp = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true));
        let tcp_with_dns = dns::tokio::Transport::system(base_tcp).map_err(to_p2p_err)?;
        let transport = tcp_with_dns
            .upgrade(upgrade::Version::V1Lazy)
            .authenticate(noise_config)
            .multiplex(yamux::Config::default())
            .boxed();

        let mut swarm = Swarm::new(
            transport,
            behaviour,
            local_peer_id,
            libp2p::swarm::Config::with_tokio_executor(),
        );

        if cfg.enable_tcp {
            let listen_addr = if cfg.listen_addr.is_ipv4() {
                format!("/ip4/{}/tcp/{}", cfg.listen_addr.ip(), cfg.listen_addr.port())
            } else {
                format!("/ip6/{}/tcp/{}", cfg.listen_addr.ip(), cfg.listen_addr.port())
            }
            .parse::<Multiaddr>()
            .map_err(to_p2p_err)?;
            swarm.listen_on(listen_addr).map_err(to_p2p_err)?;
        }

        let bootnodes = classify_bootnodes(cfg.bootnodes);
        let mut dialed_addrs = HashSet::new();

        for peer in cfg.pre_dial_peers {
            dial_once(&mut swarm, &mut dialed_addrs, peer, "static peer");
        }

        for addr in bootnodes.dial_addrs {
            dial_once(&mut swarm, &mut dialed_addrs, addr, "bootnode");
        }

        let mut discovery_rx = match (cfg.enable_discovery, bootnodes.discovery_enrs.is_empty()) {
            (true, false) => spawn_discovery(cfg.discovery_listen, bootnodes.discovery_enrs)
                .map_err(|err| {
                    warn!(error = %err, "failed to start whitelist preconfirmation discovery");
                })
                .ok(),
            (true, true) => {
                tracing::info!(
                    "discovery enabled but no ENR bootnodes provided; skipping discv5 bootstrap"
                );
                None
            }
            (false, false) => {
                warn!(
                    count = bootnodes.discovery_enrs.len(),
                    "discovery is disabled; skipping ENR bootnodes"
                );
                None
            }
            (false, true) => None,
        };

        let (event_tx, event_rx) = mpsc::channel(1024);
        let (command_tx, mut command_rx) = mpsc::channel(512);
        let local_peer_id_for_events = local_peer_id;

        let handle = tokio::spawn(async move {
            let mut inbound_validation_state = GossipsubInboundState::new_with_allow_all_sequencers(
                cfg.chain_id,
                cfg.sequencer_addresses,
                cfg.allow_all_sequencers,
            );

            loop {
                let has_discovery = discovery_rx.is_some();

                tokio::select! {
                    maybe_command = command_rx.recv() => {
                        let Some(command) = maybe_command else {
                            return Ok(());
                        };
                        match command {
                            NetworkCommand::PublishUnsafeRequest { hash } => {
                                let payload = encode_unsafe_request_message(hash);
                                if let Err(err) = swarm
                                    .behaviour_mut()
                                    .gossipsub
                                    .publish(topics.preconf_request.clone(), payload)
                                {
                                    record_outbound_publish(
                                        "request_preconf_blocks",
                                        "publish_failed",
                                    );
                                    warn!(
                                        hash = %hash,
                                        error = %err,
                                        "failed to publish whitelist preconfirmation request"
                                    );
                                } else {
                                    record_outbound_publish("request_preconf_blocks", "published");
                                }
                            }
                            NetworkCommand::PublishUnsafeResponse { envelope } => {
                                let hash = envelope.execution_payload.block_hash;
                                match encode_unsafe_response_message(&envelope) {
                                    Ok(payload) => {
                                        if let Err(err) = swarm
                                            .behaviour_mut()
                                            .gossipsub
                                            .publish(topics.preconf_response.clone(), payload)
                                        {
                                            record_outbound_publish(
                                                "response_preconf_blocks",
                                                "publish_failed",
                                            );
                                            warn!(
                                                hash = %hash,
                                                error = %err,
                                                "failed to publish whitelist preconfirmation response"
                                            );
                                        } else {
                                            record_outbound_publish(
                                                "response_preconf_blocks",
                                                "published",
                                            );
                                        }
                                    }
                                    Err(err) => {
                                        record_outbound_publish(
                                            "response_preconf_blocks",
                                            "encode_failed",
                                        );
                                        warn!(
                                            hash = %hash,
                                            error = %err,
                                            "failed to encode whitelist preconfirmation response"
                                        );
                                    }
                                }
                            }
                            NetworkCommand::PublishUnsafePayload { signature, envelope } => {
                                let hash = envelope.execution_payload.block_hash;
                                // Loop back locally-built payloads so importer caches can serve
                                // follow-up EOS catch-up requests even without peer echo.
                                let payload_bytes = encode_envelope_ssz(&envelope);
                                let local_event = NetworkEvent::UnsafePayload {
                                    from: local_peer_id_for_events,
                                    payload: DecodedUnsafePayload {
                                        wire_signature: signature,
                                        payload_bytes,
                                        envelope: (*envelope).clone(),
                                    },
                                };
                                forward_event(&event_tx, local_event).await?;

                                match encode_unsafe_payload_message(&signature, &envelope) {
                                    Ok(payload) => {
                                        if let Err(err) = swarm
                                            .behaviour_mut()
                                            .gossipsub
                                            .publish(topics.preconf_blocks.clone(), payload)
                                        {
                                            record_outbound_publish(
                                                "preconf_blocks",
                                                "publish_failed",
                                            );
                                            warn!(
                                                hash = %hash,
                                                error = %err,
                                                "failed to publish whitelist preconfirmation payload"
                                            );
                                        } else {
                                            record_outbound_publish("preconf_blocks", "published");
                                        }
                                    }
                                    Err(err) => {
                                        record_outbound_publish("preconf_blocks", "encode_failed");
                                        warn!(
                                            hash = %hash,
                                            error = %err,
                                            "failed to encode whitelist preconfirmation payload"
                                        );
                                    }
                                }
                            }
                            NetworkCommand::PublishEndOfSequencingRequest { epoch } => {
                                let payload = encode_eos_request_message(epoch);
                                if let Err(err) = swarm
                                    .behaviour_mut()
                                    .gossipsub
                                    .publish(topics.eos_request.clone(), payload)
                                {
                                    record_outbound_publish(
                                        "request_eos_preconf_blocks",
                                        "publish_failed",
                                    );
                                    warn!(
                                        epoch,
                                        error = %err,
                                        "failed to publish end-of-sequencing request"
                                    );
                                } else {
                                    record_outbound_publish(
                                        "request_eos_preconf_blocks",
                                        "published",
                                    );
                                }
                            }
                            NetworkCommand::Shutdown => {
                                return Ok(());
                            }
                        }
                    }
                    maybe_addr = recv_discovered_multiaddr(&mut discovery_rx), if has_discovery => {
                        match maybe_addr {
                            Some(addr) => {
                                dial_once(&mut swarm, &mut dialed_addrs, addr, "discovery");
                            }
                            None => {
                                discovery_rx = None;
                                debug!("whitelist preconfirmation discovery stream closed");
                            }
                        }
                    }
                    event = swarm.select_next_some() => {
                        handle_swarm_event(
                            event,
                            &topics,
                            &event_tx,
                            &mut inbound_validation_state,
                            &mut swarm,
                        )
                        .await?;
                    }
                }
            }
        });

        Ok(Self { local_peer_id, event_rx, command_tx, handle })
    }
}
