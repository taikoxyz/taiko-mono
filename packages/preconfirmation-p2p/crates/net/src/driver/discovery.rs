//! Discovery integration for the network driver.
//!
//! This module handles multiaddrs discovered by the discv5 layer, applying
//! dial gating (Kona gater + reputation bans) before initiating connections.

use libp2p::{Multiaddr, PeerId, multiaddr::Protocol};

use super::*;

impl NetworkDriver {
    /// Handles multiaddrs surfaced by the discovery layer.
    pub(super) fn handle_discovered_addr(&mut self, addr: Multiaddr) {
        if self.allow_dial_addr(&addr) {
            // Discovery feed can surface many addresses; defer actual connect to libp2p dialer.
            let _ = self.swarm.dial(addr);
        }
    }

    /// Unified dial gating: consult Kona's connection gater first, then ban list from
    /// `PeerReputationStore`. This keeps a single decision path for outbound dials.
    pub(super) fn allow_dial_addr(&mut self, addr: &Multiaddr) -> bool {
        if self.kona_gater.can_dial(addr).is_err() {
            metrics::counter!("p2p_dial_blocked", "source" => "kona_gater").increment(1);
            return false;
        }

        let Some(peer) = Self::peer_id_from_multiaddr(addr) else {
            metrics::counter!("p2p_dial_blocked", "source" => "missing_peer_id").increment(1);
            return false;
        };

        if self.reputation.is_banned(&peer) {
            metrics::counter!("p2p_dial_blocked", "source" => "reputation").increment(1);
            return false;
        }

        true
    }

    /// Extracts the `PeerId` from a `Multiaddr` if present.
    pub(super) fn peer_id_from_multiaddr(addr: &Multiaddr) -> Option<PeerId> {
        addr.iter().find_map(|p| match p {
            Protocol::P2p(mh) => PeerId::from_multihash(mh.into()).ok(),
            _ => None,
        })
    }
}
