//! Shared state for carrying beacon-sync checkpoint progress into event sync.

use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};

/// Stores the L2 block number that beacon sync has confirmed as its catch-up head.
///
/// This value is only meaningful when `present` is true. We keep explicit presence tracking
/// because block number `0` is a valid value and cannot be used as a sentinel.
#[derive(Debug, Default)]
pub struct CheckpointResumeHead {
    /// Stored checkpoint head block number.
    value: AtomicU64,
    /// Tracks whether `value` is currently populated.
    present: AtomicBool,
}

impl CheckpointResumeHead {
    /// Clears the stored checkpoint head.
    pub fn clear(&self) {
        self.present.store(false, Ordering::Release);
    }

    /// Stores a checkpoint head block number.
    pub fn set(&self, block_number: u64) {
        self.value.store(block_number, Ordering::Relaxed);
        self.present.store(true, Ordering::Release);
    }

    /// Returns the stored checkpoint head when present.
    pub fn get(&self) -> Option<u64> {
        if self.present.load(Ordering::Acquire) {
            Some(self.value.load(Ordering::Relaxed))
        } else {
            None
        }
    }
}
