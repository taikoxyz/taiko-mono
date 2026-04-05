//! Composite libp2p behaviour for the whitelist preconfirmation network.

use libp2p::{gossipsub, identify, identity, ping, swarm::NetworkBehaviour};

use super::config::build_gossipsub;
use super::topics::Topics;
use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Composite libp2p behaviour used by the whitelist preconfirmation network.
#[derive(NetworkBehaviour)]
#[behaviour(to_swarm = "BehaviourEvent")]
pub(crate) struct TaikoBehaviour {
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
    /// Ping event (ignored).
    Ping,
    /// Identify event (ignored).
    Identify,
}

impl From<gossipsub::Event> for BehaviourEvent {
    fn from(value: gossipsub::Event) -> Self {
        Self::Gossipsub(Box::new(value))
    }
}

impl From<ping::Event> for BehaviourEvent {
    fn from(_: ping::Event) -> Self {
        Self::Ping
    }
}

impl From<identify::Event> for BehaviourEvent {
    fn from(_: identify::Event) -> Self {
        Self::Identify
    }
}

/// Build the complete TaikoBehaviour with gossipsub subscribed to all topics.
pub(crate) fn build_behaviour(
    local_key: &identity::Keypair,
    topics: &Topics,
) -> Result<TaikoBehaviour> {
    let mut gossipsub = build_gossipsub()?;
    topics.subscribe(&mut gossipsub).map_err(WhitelistPreconfirmationDriverError::p2p)?;

    Ok(TaikoBehaviour {
        gossipsub,
        ping: ping::Behaviour::new(ping::Config::new()),
        identify: identify::Behaviour::new(identify::Config::new(
            "/taiko/whitelist-preconfirmation/1.0.0".to_string(),
            local_key.public(),
        )),
    })
}
