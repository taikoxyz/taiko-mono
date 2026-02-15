//! Shared state for carrying beacon-sync checkpoint progress into event sync.

use std::sync::atomic::{AtomicU64, Ordering};

/// Sentinel value used to represent an unset checkpoint head.
const CHECKPOINT_HEAD_UNSET: u64 = u64::MAX;

/// Stores the L2 block number that beacon sync has confirmed as its catch-up head.
///
/// `u64::MAX` is reserved as "not set", allowing a single-atomic representation while preserving
/// `Option<u64>` semantics.
#[derive(Debug)]
pub struct CheckpointResumeHead {
    /// Stored checkpoint head block number.
    value: AtomicU64,
}

impl Default for CheckpointResumeHead {
    /// Initializes with no checkpoint head set.
    fn default() -> Self {
        Self { value: AtomicU64::new(CHECKPOINT_HEAD_UNSET) }
    }
}

impl CheckpointResumeHead {
    /// Clears the stored checkpoint head.
    pub fn clear(&self) {
        self.value.store(CHECKPOINT_HEAD_UNSET, Ordering::Release);
    }

    /// Stores a checkpoint head block number.
    pub fn set(&self, block_number: u64) {
        debug_assert_ne!(
            block_number, CHECKPOINT_HEAD_UNSET,
            "u64::MAX is reserved as an unset checkpoint-head sentinel"
        );
        self.value.store(block_number, Ordering::Release);
    }

    /// Returns the stored checkpoint head when present.
    pub fn get(&self) -> Option<u64> {
        let value = self.value.load(Ordering::Acquire);
        if value == CHECKPOINT_HEAD_UNSET { None } else { Some(value) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::mem::size_of;

    #[test]
    fn checkpoint_resume_head_uses_single_atomic_storage() {
        assert_eq!(size_of::<CheckpointResumeHead>(), size_of::<AtomicU64>());
    }

    #[test]
    fn checkpoint_resume_head_round_trip() {
        let head = CheckpointResumeHead::default();
        assert_eq!(head.get(), None);

        head.set(42);
        assert_eq!(head.get(), Some(42));

        head.clear();
        assert_eq!(head.get(), None);
    }
}
