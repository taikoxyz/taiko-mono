//! Shared mutable runtime state for whitelist preconfirmation flows.

use std::sync::Arc;

use alloy_primitives::B256;
use hashlink::LinkedHashMap;
use tokio::sync::Mutex;

/// Maximum number of EOS cache entries retained in the shared build/status state.
const MAX_END_OF_SEQUENCING_ENTRIES: usize = 768;

/// Shared runtime state used by build-path and status consumers.
#[derive(Clone)]
pub(crate) struct SharedDriverState {
    /// Highest unsafe L2 payload block ID observed by this node.
    pub(crate) highest_unsafe_l2_payload_block_id: Arc<Mutex<u64>>,
    /// End-of-sequencing block hashes retained per beacon epoch.
    pub(crate) end_of_sequencing_by_epoch: Arc<Mutex<LinkedHashMap<u64, B256>>>,
}

impl SharedDriverState {
    /// Update the shared highest-unsafe block marker without allowing regressions.
    pub(crate) async fn update_highest_unsafe(&self, block_number: u64) {
        let mut highest_unsafe = self.highest_unsafe_l2_payload_block_id.lock().await;
        *highest_unsafe = (*highest_unsafe).max(block_number);
    }

    /// Record an EOS block hash for the given epoch.
    pub(crate) async fn record_end_of_sequencing(&self, epoch: u64, block_hash: B256) {
        let mut entries = self.end_of_sequencing_by_epoch.lock().await;
        entries.insert(epoch, block_hash);
        if entries.len() > MAX_END_OF_SEQUENCING_ENTRIES {
            let _ = entries.pop_front();
        }
    }

    /// Return the stored EOS block hash for the given epoch, if present.
    pub(crate) async fn end_of_sequencing_for_epoch(&self, epoch: u64) -> Option<B256> {
        self.end_of_sequencing_by_epoch.lock().await.get(&epoch).copied()
    }

    /// Return the current highest-unsafe block number.
    pub(crate) async fn highest_unsafe_block_number(&self) -> u64 {
        *self.highest_unsafe_l2_payload_block_id.lock().await
    }
}
