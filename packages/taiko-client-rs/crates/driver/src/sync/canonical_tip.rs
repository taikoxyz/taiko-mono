//! Canonical L2 tip state shared by event sync and preconfirmation flows.

use std::sync::atomic::{AtomicU64, Ordering};

/// Explicit canonical tip state produced by event sync.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum CanonicalTipState {
    /// Event sync has not established a canonical tip yet.
    #[default]
    Unknown,
    /// Event sync has established a canonical tip at the given L2 block number.
    Known(u64),
}

/// Atomic wrapper for canonical tip state.
#[derive(Debug)]
pub struct AtomicCanonicalTip(AtomicU64);

impl Default for AtomicCanonicalTip {
    fn default() -> Self {
        Self::new(CanonicalTipState::Unknown)
    }
}

impl AtomicCanonicalTip {
    const UNKNOWN_SENTINEL: u64 = u64::MAX;

    /// Construct a new atomic canonical tip with the provided initial state.
    pub fn new(initial: CanonicalTipState) -> Self {
        let raw = match initial {
            CanonicalTipState::Unknown => Self::UNKNOWN_SENTINEL,
            CanonicalTipState::Known(block_number) => {
                assert!(
                    block_number != Self::UNKNOWN_SENTINEL,
                    "u64::MAX is reserved for CanonicalTipState::Unknown"
                );
                block_number
            }
        };
        Self(AtomicU64::new(raw))
    }

    /// Load the canonical tip state using the given memory ordering.
    pub fn load(&self, ordering: Ordering) -> CanonicalTipState {
        let raw = self.0.load(ordering);
        if raw == Self::UNKNOWN_SENTINEL {
            CanonicalTipState::Unknown
        } else {
            CanonicalTipState::Known(raw)
        }
    }

    /// Store the canonical tip state using the given memory ordering.
    pub fn store(&self, state: CanonicalTipState, ordering: Ordering) {
        let raw = match state {
            CanonicalTipState::Unknown => Self::UNKNOWN_SENTINEL,
            CanonicalTipState::Known(block_number) => {
                assert!(
                    block_number != Self::UNKNOWN_SENTINEL,
                    "u64::MAX is reserved for CanonicalTipState::Unknown"
                );
                block_number
            }
        };
        self.0.store(raw, ordering);
    }

    /// Swap the canonical tip state, returning the previous state.
    pub fn swap(&self, state: CanonicalTipState, ordering: Ordering) -> CanonicalTipState {
        let next_raw = match state {
            CanonicalTipState::Unknown => Self::UNKNOWN_SENTINEL,
            CanonicalTipState::Known(block_number) => {
                assert!(
                    block_number != Self::UNKNOWN_SENTINEL,
                    "u64::MAX is reserved for CanonicalTipState::Unknown"
                );
                block_number
            }
        };
        let previous_raw = self.0.swap(next_raw, ordering);
        if previous_raw == Self::UNKNOWN_SENTINEL {
            CanonicalTipState::Unknown
        } else {
            CanonicalTipState::Known(previous_raw)
        }
    }
}

/// Return true when a preconfirmation target block is stale against the canonical tip boundary.
#[inline]
pub(crate) fn is_stale_preconf(block_number: u64, canonical_block_tip: u64) -> bool {
    block_number <= canonical_block_tip
}

#[cfg(test)]
mod tests {
    use super::{AtomicCanonicalTip, CanonicalTipState, is_stale_preconf};
    use std::sync::atomic::Ordering;

    #[test]
    fn canonical_tip_state_roundtrip_unknown() {
        let state = AtomicCanonicalTip::new(CanonicalTipState::Unknown);
        assert_eq!(state.load(Ordering::Relaxed), CanonicalTipState::Unknown);
    }

    #[test]
    fn canonical_tip_state_roundtrip_known_zero() {
        let state = AtomicCanonicalTip::new(CanonicalTipState::Known(0));
        assert_eq!(state.load(Ordering::Relaxed), CanonicalTipState::Known(0));
    }

    #[test]
    fn canonical_tip_state_tracks_decreasing_values() {
        let state = AtomicCanonicalTip::new(CanonicalTipState::Known(100));
        let previous = state.swap(CanonicalTipState::Known(95), Ordering::Relaxed);

        assert_eq!(previous, CanonicalTipState::Known(100));
        assert_eq!(state.load(Ordering::Relaxed), CanonicalTipState::Known(95));
    }

    #[test]
    fn stale_preconf_comparison_matches_canonical_boundary() {
        assert!(is_stale_preconf(10, 10));
        assert!(is_stale_preconf(9, 10));
        assert!(!is_stale_preconf(11, 10));
    }
}
