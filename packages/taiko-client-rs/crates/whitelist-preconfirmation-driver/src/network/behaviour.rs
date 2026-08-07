//! Composite libp2p behaviour for the whitelist preconfirmation network.

use libp2p::{
    connection_limits::{self, ConnectionLimits},
    gossipsub, identify, identity, ping,
    swarm::NetworkBehaviour,
};

use super::{config::build_gossipsub, topics::Topics};
use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Composite libp2p behaviour used by the whitelist preconfirmation network.
#[derive(NetworkBehaviour)]
#[behaviour(to_swarm = "BehaviourEvent")]
pub(crate) struct TaikoBehaviour {
    /// Hard ceiling of one established connection per peer.
    pub(crate) connection_limits: connection_limits::Behaviour,
    /// Gossip transport for whitelist preconfirmation topics.
    pub(crate) gossipsub: gossipsub::Behaviour,
    /// Ping protocol for liveness.
    pub(crate) ping: ping::Behaviour,
    /// Identify protocol for peer metadata exchange.
    pub(crate) identify: identify::Behaviour,
}

/// Event wrapper for the nested libp2p behaviour components.
#[derive(Debug)]
pub(crate) enum BehaviourEvent {
    /// Wrapped gossipsub event.
    Gossipsub(Box<gossipsub::Event>),
    /// Ping or identify event, both ignored by the runtime.
    Ignored,
}

impl From<gossipsub::Event> for BehaviourEvent {
    fn from(value: gossipsub::Event) -> Self {
        Self::Gossipsub(Box::new(value))
    }
}

impl From<ping::Event> for BehaviourEvent {
    fn from(_: ping::Event) -> Self {
        Self::Ignored
    }
}

impl From<identify::Event> for BehaviourEvent {
    fn from(_: identify::Event) -> Self {
        Self::Ignored
    }
}

impl From<std::convert::Infallible> for BehaviourEvent {
    fn from(event: std::convert::Infallible) -> Self {
        match event {}
    }
}

/// Build the complete TaikoBehaviour with gossipsub subscribed to all topics.
pub(crate) fn build_behaviour(
    local_key: &identity::Keypair,
    topics: &Topics,
) -> Result<TaikoBehaviour> {
    let mut gossipsub = build_gossipsub()?;
    topics.subscribe(&mut gossipsub).map_err(WhitelistPreconfirmationDriverError::p2p)?;

    let limits = ConnectionLimits::default().with_max_established_per_peer(Some(1));

    Ok(TaikoBehaviour {
        connection_limits: connection_limits::Behaviour::new(limits),
        gossipsub,
        ping: ping::Behaviour::new(ping::Config::new()),
        identify: identify::Behaviour::new(identify::Config::new(
            "/taiko/whitelist-preconfirmation/1.0.0".to_string(),
            local_key.public(),
        )),
    })
}

#[cfg(test)]
mod tests {
    use libp2p::{
        Multiaddr, PeerId,
        core::{ConnectedPoint, Endpoint},
        swarm::{ConnectionId, NetworkBehaviour, behaviour},
    };

    use super::*;

    #[test]
    fn limits_established_connections_per_peer() {
        let key = identity::Keypair::generate_secp256k1();
        let topics = Topics::new(1);
        let mut limits = build_behaviour(&key, &topics).expect("behaviour").connection_limits;
        let peer = PeerId::random();
        let local: Multiaddr = "/ip4/127.0.0.1/tcp/4001".parse().expect("local");
        let remote: Multiaddr = "/ip4/127.0.0.1/tcp/4002".parse().expect("remote");
        let endpoint = ConnectedPoint::Dialer {
            address: remote.clone(),
            role_override: Endpoint::Dialer,
            port_use: libp2p::core::transport::PortUse::Reuse,
        };
        let first = ConnectionId::new_unchecked(1);
        assert!(
            limits
                .handle_established_outbound_connection(
                    first,
                    peer,
                    &remote,
                    Endpoint::Dialer,
                    libp2p::core::transport::PortUse::Reuse,
                )
                .is_ok()
        );
        limits.on_swarm_event(behaviour::FromSwarm::ConnectionEstablished(
            behaviour::ConnectionEstablished {
                peer_id: peer,
                connection_id: first,
                endpoint: &endpoint,
                failed_addresses: &[],
                other_established: 0,
            },
        ));
        assert!(
            limits
                .handle_established_outbound_connection(
                    ConnectionId::new_unchecked(2),
                    peer,
                    &local,
                    Endpoint::Dialer,
                    libp2p::core::transport::PortUse::Reuse,
                )
                .is_err()
        );
    }
}
