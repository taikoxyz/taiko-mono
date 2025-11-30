use libp2p::{
    Transport,
    core::{muxing::StreamMuxerBox, transport::Boxed, upgrade},
    identity, noise, tcp, yamux,
};

use crate::{behaviour::NetBehaviour, config::NetworkConfig};

/// Transport + behaviour bundle used by the driver to construct a libp2p swarm.
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

/// Build the TCP/noise/yamux transport and base behaviours for a network instance.
pub fn build_transport_and_behaviour(_cfg: &NetworkConfig) -> anyhow::Result<BuiltParts> {
    let keypair = identity::Keypair::generate_ed25519();
    let noise_config = noise::Config::new(&keypair)?;

    let transport = tcp::tokio::Transport::new(tcp::Config::default())
        .upgrade(upgrade::Version::V1Lazy)
        .authenticate(noise_config)
        .multiplex(yamux::Config::default())
        .boxed();

    let topics = (
        libp2p::gossipsub::IdentTopic::new(
            preconfirmation_types::topic_preconfirmation_commitments(_cfg.chain_id),
        ),
        libp2p::gossipsub::IdentTopic::new(preconfirmation_types::topic_raw_txlists(_cfg.chain_id)),
    );
    let protocols = crate::codec::Protocols {
        commitments: crate::codec::SszProtocol(
            preconfirmation_types::protocol_get_commitments_by_number(_cfg.chain_id),
        ),
        raw_txlists: crate::codec::SszProtocol(preconfirmation_types::protocol_get_raw_txlist(
            _cfg.chain_id,
        )),
        head: crate::codec::SszProtocol(preconfirmation_types::protocol_get_head(_cfg.chain_id)),
    };
    let behaviour = NetBehaviour::new(keypair.public(), topics.clone(), protocols);

    Ok(BuiltParts { keypair, transport, behaviour, topics })
}
