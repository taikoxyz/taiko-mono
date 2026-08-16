//! Distinct-peer watermark and configured-peer protection state.

use std::collections::HashSet;

use libp2p::PeerId;

/// Tracks the distinct-peer high tide and peers exempt from pruning.
#[derive(Debug)]
pub(crate) struct PeerWatermarks {
    /// Maximum number of ordinary distinct peers retained by the runtime.
    high: usize,
    /// Configured peer IDs that high-tide pruning must retain.
    protected: HashSet<PeerId>,
    /// Peers whose asynchronous disconnect has already been requested.
    pending_disconnects: HashSet<PeerId>,
}

impl PeerWatermarks {
    /// Create watermark state with the configured distinct-peer high tide.
    pub(crate) fn new(high: usize) -> Self {
        Self { high, protected: HashSet::new(), pending_disconnects: HashSet::new() }
    }

    /// Create watermark state with peer identities protected before any connection events.
    pub(crate) fn with_protected(high: usize, protected: impl IntoIterator<Item = PeerId>) -> Self {
        let mut watermarks = Self::new(high);
        watermarks.protected.extend(protected);
        watermarks
    }

    /// Mark a configured peer as protected across future reconnects.
    pub(crate) fn protect(&mut self, peer_id: PeerId) {
        self.protected.insert(peer_id);
    }

    /// Exclude a peer from effective counts while its disconnect completes.
    pub(crate) fn mark_disconnecting(&mut self, peer_id: PeerId) {
        self.pending_disconnects.insert(peer_id);
    }

    /// Clear pending state after the peer's final connection closes.
    pub(crate) fn disconnected(&mut self, peer_id: &PeerId) {
        self.pending_disconnects.remove(peer_id);
    }

    /// Select an unprotected peer when effective distinct peers exceed high tide.
    pub(crate) fn peer_to_prune(
        &self,
        connected: impl IntoIterator<Item = PeerId>,
        new_peer: PeerId,
    ) -> Option<PeerId> {
        let active = connected
            .into_iter()
            .filter(|peer| !self.pending_disconnects.contains(peer))
            .collect::<Vec<_>>();
        if active.len() <= self.high {
            return None;
        }
        if !self.protected.contains(&new_peer) && !self.pending_disconnects.contains(&new_peer) {
            return Some(new_peer);
        }
        active.into_iter().find(|peer| !self.protected.contains(peer))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn peer() -> PeerId {
        PeerId::random()
    }

    #[test]
    fn keeps_peers_at_or_below_high_tide() {
        let manager = PeerWatermarks::new(2);
        let first = peer();
        let second = peer();
        assert_eq!(manager.peer_to_prune([first, second], second), None);
    }

    #[test]
    fn prunes_new_unprotected_peer_first() {
        let manager = PeerWatermarks::new(2);
        let first = peer();
        let second = peer();
        let newcomer = peer();
        assert_eq!(manager.peer_to_prune([first, second, newcomer], newcomer), Some(newcomer));
    }

    #[test]
    fn protected_new_peer_displaces_unprotected_peer() {
        let first = peer();
        let protected = peer();
        let mut manager = PeerWatermarks::new(1);
        manager.protect(protected);
        assert_eq!(manager.peer_to_prune([first, protected], protected), Some(first));
    }

    #[test]
    fn pending_and_protected_peers_are_not_selected() {
        let pending = peer();
        let protected = peer();
        let newcomer = peer();
        let mut manager = PeerWatermarks::new(1);
        manager.protect(protected);
        manager.mark_disconnecting(pending);
        assert_eq!(
            manager.peer_to_prune([pending, protected, newcomer], protected),
            Some(newcomer)
        );
    }

    #[test]
    fn allows_all_protected_overflow() {
        let first = peer();
        let second = peer();
        let mut manager = PeerWatermarks::new(1);
        manager.protect(first);
        manager.protect(second);
        assert_eq!(manager.peer_to_prune([first, second], second), None);
    }

    #[test]
    fn closed_peer_is_removed_from_pending_disconnects() {
        let first = peer();
        let newcomer = peer();
        let mut manager = PeerWatermarks::new(1);
        manager.mark_disconnecting(first);
        manager.disconnected(&first);
        assert_eq!(manager.peer_to_prune([first, newcomer], newcomer), Some(newcomer));
    }
}
