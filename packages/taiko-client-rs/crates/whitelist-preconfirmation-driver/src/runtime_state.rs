//! Shared runtime state for RPC status and websocket notifications.

use std::sync::atomic::{AtomicU64, Ordering};

use alloy_primitives::B256;
use hashlink::LinkedHashMap;
use tokio::sync::{Mutex, broadcast};

use crate::rpc::types::EndOfSequencingNotification;

/// Maximum number of pending EOS notifications retained for `/ws` subscribers.
const EOS_NOTIFICATION_CHANNEL_CAPACITY: usize = 128;
/// Maximum retained epochs in the local EOS hash cache to avoid unbounded growth.
const MAX_END_OF_SEQUENCING_EPOCH_CACHE_ENTRIES: usize = 4096;

/// Runtime status/cache state shared across RPC and importer tasks.
#[derive(Debug)]
pub(crate) struct RuntimeStatusState {
    /// Highest unsafe payload block ID tracked by this node.
    highest_unsafe_l2_payload_block_id: AtomicU64,
    /// Total number of envelopes ever cached since startup.
    total_cached: AtomicU64,
    /// End-of-sequencing hash cache keyed by epoch.
    end_of_sequencing_by_epoch: Mutex<LinkedHashMap<u64, B256>>,
    /// Broadcast channel for REST `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
}

impl RuntimeStatusState {
    /// Build a new shared runtime state.
    pub(crate) fn new(initial_highest_unsafe_l2_payload_block_id: u64) -> Self {
        let (eos_notification_tx, _) = broadcast::channel(EOS_NOTIFICATION_CHANNEL_CAPACITY);
        Self {
            highest_unsafe_l2_payload_block_id: AtomicU64::new(
                initial_highest_unsafe_l2_payload_block_id,
            ),
            total_cached: AtomicU64::new(0),
            end_of_sequencing_by_epoch: Mutex::new(LinkedHashMap::with_capacity(
                MAX_END_OF_SEQUENCING_EPOCH_CACHE_ENTRIES,
            )),
            eos_notification_tx,
        }
    }

    /// Set highest unsafe payload block ID (supports monotonic advance and reorg rewind).
    pub(crate) fn set_highest_unsafe_l2_payload_block_id(&self, block_number: u64) {
        self.highest_unsafe_l2_payload_block_id.store(block_number, Ordering::Relaxed);
    }

    /// Read highest unsafe payload block ID.
    pub(crate) fn highest_unsafe_l2_payload_block_id(&self) -> u64 {
        self.highest_unsafe_l2_payload_block_id.load(Ordering::Relaxed)
    }

    /// Increment cumulative cached-envelope counter.
    pub(crate) fn increment_total_cached(&self) {
        let _ = self.total_cached.fetch_add(1, Ordering::Relaxed);
    }

    /// Read cumulative cached-envelope counter.
    pub(crate) fn total_cached(&self) -> u64 {
        self.total_cached.load(Ordering::Relaxed)
    }

    /// Store EOS block hash for an epoch with bounded retention.
    pub(crate) async fn set_end_of_sequencing_block_hash(&self, epoch: u64, block_hash: B256) {
        let mut cache = self.end_of_sequencing_by_epoch.lock().await;
        cache.remove(&epoch);
        cache.insert(epoch, block_hash);
        while cache.len() > MAX_END_OF_SEQUENCING_EPOCH_CACHE_ENTRIES {
            let _ = cache.pop_front();
        }
    }

    /// Read EOS block hash for an epoch.
    pub(crate) async fn end_of_sequencing_block_hash(&self, epoch: u64) -> Option<B256> {
        self.end_of_sequencing_by_epoch.lock().await.get(&epoch).copied()
    }

    /// Publish EOS notification to `/ws` subscribers.
    pub(crate) fn notify_end_of_sequencing(&self, epoch: u64) {
        let _ = self
            .eos_notification_tx
            .send(EndOfSequencingNotification { current_epoch: epoch, end_of_sequencing: true });
    }

    /// Subscribe to EOS `/ws` notifications.
    pub(crate) fn subscribe_end_of_sequencing(
        &self,
    ) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.eos_notification_tx.subscribe()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn end_of_sequencing_cache_prunes_oldest_epochs() {
        let state = RuntimeStatusState::new(0);
        let total = MAX_END_OF_SEQUENCING_EPOCH_CACHE_ENTRIES + 3;

        for epoch in 0..total {
            state
                .set_end_of_sequencing_block_hash(
                    epoch as u64,
                    B256::from_slice(&(epoch as u64).to_be_bytes().repeat(4)),
                )
                .await;
        }

        assert!(state.end_of_sequencing_block_hash(0).await.is_none());
        assert!(state.end_of_sequencing_block_hash(1).await.is_none());
        assert!(state.end_of_sequencing_block_hash((total - 1) as u64).await.is_some());
    }
}
