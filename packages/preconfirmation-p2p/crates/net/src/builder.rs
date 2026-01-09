//! Constructs libp2p transport and combined behaviour for the preconfirmation P2P stack.

use futures::future::Either;
use libp2p::{
    Transport,
    core::{muxing::StreamMuxerBox, transport::Boxed, upgrade},
    identity, noise, tcp, yamux,
};

use crate::{behaviour::NetBehaviour, config::NetworkConfig};

/// Transport + behaviour bundle used by the driver to construct a libp2p swarm.
///
/// This struct holds all the necessary components configured for the libp2p swarm
/// before it is started.
pub struct BuiltParts {
    /// Identity keypair for the local node.
    pub keypair: identity::Keypair,
    /// Boxed transport (TCP + noise + yamux) used by the swarm.
    pub transport: Boxed<(libp2p::PeerId, StreamMuxerBox)>,
    /// Combined behaviour (ping/identify/gossipsub/req-resp/gating).
    pub behaviour: NetBehaviour,
    /// Gossip topics (commitments, raw tx lists).
    pub topics: (libp2p::gossipsub::IdentTopic, libp2p::gossipsub::IdentTopic),
}

/// Builds the transport (TCP and/or QUIC) and base behaviours for a network instance.
///
/// Derives protocol IDs and gossipsub topics from the configured `chain_id`, applies connection
/// limits from `cfg`, and wires noise + yamux on top of TCP (and QUIC when enabled).
///
/// # Arguments
///
/// * `cfg` - Network configuration controlling transports, limits, and timeouts.
///
/// # Returns
///
/// A `Result` which is `Ok(BuiltParts)` on successful construction, or an `anyhow::Error`
/// if any part of the setup fails (e.g., noise key generation).
pub fn build_transport_and_behaviour(cfg: &NetworkConfig) -> anyhow::Result<BuiltParts> {
    let keypair = identity::Keypair::generate_ed25519();
    let noise_config = noise::Config::new(&keypair)?;

    // Build multiplexers/transports based on config.
    let mut base: Option<Boxed<(libp2p::PeerId, StreamMuxerBox)>> = None;
    if cfg.enable_tcp {
        let tcp_transport = tcp::tokio::Transport::new(tcp::Config::default())
            .upgrade(upgrade::Version::V1Lazy)
            .authenticate(noise_config.clone())
            .multiplex(yamux::Config::default())
            .boxed();
        base = Some(match base {
            None => tcp_transport,
            Some(prev) => prev
                .or_transport(tcp_transport)
                .map(|either, _| match either {
                    Either::Left(v) => v,
                    Either::Right(v) => v,
                })
                .boxed(),
        });
    }
    #[cfg(feature = "quic-transport")]
    if cfg.enable_quic {
        let quic_transport =
            libp2p::quic::tokio::Transport::new(libp2p::quic::Config::new(&keypair))
                .map(|(peer, conn), _| (peer, StreamMuxerBox::new(conn)))
                .boxed();
        base = Some(match base {
            None => quic_transport,
            Some(prev) => prev
                .or_transport(quic_transport)
                .map(|either, _| match either {
                    Either::Left(v) => v,
                    Either::Right(v) => v,
                })
                .boxed(),
        });
    }

    let transport =
        base.ok_or_else(|| anyhow::anyhow!("no transports enabled (tcp/quic both disabled)"))?;

    let topics = (
        libp2p::gossipsub::IdentTopic::new(
            preconfirmation_types::topic_preconfirmation_commitments(cfg.chain_id),
        ),
        libp2p::gossipsub::IdentTopic::new(preconfirmation_types::topic_raw_txlists(cfg.chain_id)),
    );
    let protocols = crate::codec::Protocols {
        commitments: crate::codec::SszProtocol(
            preconfirmation_types::protocol_get_commitments_by_number(cfg.chain_id),
        ),
        raw_txlists: crate::codec::SszProtocol(preconfirmation_types::protocol_get_raw_txlist(
            cfg.chain_id,
        )),
        head: crate::codec::SszProtocol(preconfirmation_types::protocol_get_head(cfg.chain_id)),
    };
    let behaviour = NetBehaviour::new(keypair.clone(), topics.clone(), protocols, cfg)?;

    Ok(BuiltParts { keypair, transport, behaviour, topics })
}
