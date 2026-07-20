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
    /// Hard ceiling on established connections (the high-tide peer count).
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
///
/// `max_peers` caps established connections (inbound and outbound combined), acting as
/// the high-tide bound of the peer-count band; excess connection attempts are denied.
pub(crate) fn build_behaviour(
    local_key: &identity::Keypair,
    topics: &Topics,
    max_peers: usize,
) -> Result<TaikoBehaviour> {
    let mut gossipsub = build_gossipsub()?;
    topics.subscribe(&mut gossipsub).map_err(WhitelistPreconfirmationDriverError::p2p)?;

    let limits = ConnectionLimits::default()
        .with_max_established(Some(u32::try_from(max_peers).unwrap_or(u32::MAX)));

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
