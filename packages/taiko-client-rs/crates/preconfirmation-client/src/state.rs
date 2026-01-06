//! State tracking for the preconfirmation client.

use preconfirmation_types::PreconfHead;

/// Snapshot of the client sync state and peer visibility.
#[derive(Clone, Debug, Default)]
pub struct PreconfirmationState {
    /// Latest known preconfirmation head information.
    pub head: Option<PreconfHead>,
    /// Whether the initial catch-up has completed.
    pub synced: bool,
    /// Count of currently connected peers.
    pub peer_count: usize,
}

impl PreconfirmationState {
    /// Mark the client as synced or not synced.
    pub fn set_synced(&mut self, synced: bool) {
        self.synced = synced;
    }

    /// Update the latest head snapshot.
    pub fn set_head(&mut self, head: PreconfHead) {
        self.head = Some(head);
    }

    /// Increment the peer count.
    pub fn increment_peers(&mut self) {
        self.peer_count = self.peer_count.saturating_add(1);
    }

    /// Decrement the peer count.
    pub fn decrement_peers(&mut self) {
        self.peer_count = self.peer_count.saturating_sub(1);
    }
}
