use libp2p::{Multiaddr, PeerId, multiaddr::Protocol};

use super::*;

impl NetworkDriver {
    /// Handles `DiscoveryEvent`s from the discovery layer.
    pub(super) fn handle_discovery_event(&mut self, event: DiscoveryEvent) {
        match event {
            DiscoveryEvent::MultiaddrFound(addr) => {
                if self.allow_dial_addr(&addr) {
                    // Discovery feed can surface many addresses; defer actual connect to libp2p
                    // dialer.
                    let _ = self.swarm.dial(addr);
                }
            }
            DiscoveryEvent::BootnodeFailed(err) => {
                let _ = self.events_tx.try_send(NetworkEvent::Error(NetworkError::new(
                    NetworkErrorKind::Discovery,
                    format!("discovery bootnode: {err}"),
                )));
            }
            DiscoveryEvent::PeerDiscovered(_) => {}
        }
    }

    /// Unified dial gating: consult Kona's connection gater first, then reputation bans/greylist
    /// via `ReputationBackend::allow_dial`. This keeps a single decision path for outbound dials.
    pub(super) fn allow_dial_addr(&mut self, addr: &Multiaddr) -> bool {
        if self.kona_gater.can_dial(addr).is_err() {
            metrics::counter!("p2p_dial_blocked", "source" => "kona_gater").increment(1);
            return false;
        }

        if let Some(peer) = Self::peer_id_from_multiaddr(addr) {
            if !self.reputation.allow_dial(&peer, Some(addr)) {
                metrics::counter!("p2p_dial_blocked", "source" => "reputation").increment(1);
                return false;
            }
        } else {
            metrics::counter!("p2p_dial_blocked", "source" => "missing_peer_id").increment(1);
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
