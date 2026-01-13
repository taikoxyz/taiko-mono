use std::sync::Arc;

use alloy_primitives::{Address, B256};

use super::super::LookaheadSlot;

/// Cached lookahead data for a single epoch.
#[derive(Clone, Debug)]
pub struct CachedLookaheadEpoch {
    /// Ordered lookahead slots for an epoch as emitted by `LookaheadPosted`.
    pub slots: Arc<Vec<LookaheadSlot>>,
    /// Snapshot of the whitelist operator for this epoch at the block that emitted the
    /// `LookaheadPosted` event. Used as a deterministic fallback when lookahead is empty or a slot
    /// is later deemed unusable.
    pub fallback_whitelist: Address,
    /// Timestamp of the block that produced the cached lookahead (or synthetic epoch).
    pub block_timestamp: u64,
}

impl CachedLookaheadEpoch {
    /// Read-only view of ordered slots for this epoch.
    pub fn slots(&self) -> &[LookaheadSlot] {
        &self.slots
    }

    /// Blacklist flags are tracked separately via live events.
    /// Whitelist fallback captured for this epoch at ingest time.
    pub fn fallback_whitelist(&self) -> Address {
        self.fallback_whitelist
    }
}

/// Broadcast messages emitted by the resolver.
#[derive(Clone, Debug)]
pub enum LookaheadBroadcast {
    /// Newly cached epoch data.
    Epoch(LookaheadEpochUpdate),
    /// Operator registration root was blacklisted.
    Blacklisted { root: B256 },
    /// Operator registration root was removed from blacklist.
    Unblacklisted { root: B256 },
}

/// Epoch update broadcast structure.
#[derive(Clone, Debug)]
pub struct LookaheadEpochUpdate {
    /// Epoch start timestamp (seconds since UNIX_EPOCH).
    pub epoch_start: u64,
    /// Cached epoch data.
    pub epoch: CachedLookaheadEpoch,
}

/// Identifies which cached epoch supplies the slot for a timestamp.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SlotOrigin {
    /// Slot comes from the current epoch cache; carries index into `slots`.
    Current(usize),
    /// Slot comes from the next epoch cache; carries index into that epoch's `slots`.
    Next(usize),
}

/// Choose the first applicable lookahead slot for the timestamp, returning its origin and index.
///
/// Slots are ordered on-chain; pick the earliest slot with timestamp >= ts. If none in current
/// epoch, allow the first slot of next epoch if its timestamp is still ahead of ts; otherwise None
/// (caller should fall back to whitelist).
pub fn pick_slot_origin(
    ts: u64,
    current_slots: &[LookaheadSlot],
    next_slots: Option<&[LookaheadSlot]>,
) -> Option<SlotOrigin> {
    // If the current epoch has no lookahead slots, contract logic falls back to the whitelist for
    // the whole epoch (`_handleEmptyCurrentLookahead`); do not borrow from the next epoch.
    if current_slots.is_empty() {
        return None;
    }

    // Find the first current epoch slot >= ts.
    if let Some((idx, _)) =
        current_slots.iter().enumerate().find(|(_, slot)| ts <= slot.timestamp.to::<u64>())
    {
        return Some(SlotOrigin::Current(idx));
    }

    // No current epoch slot matched; check the first slot of the next epoch if available.
    if let Some(next) = next_slots &&
        let Some(first) = next.first() &&
        ts <= first.timestamp.to::<u64>()
    {
        return Some(SlotOrigin::Next(0));
    }

    // No suitable slot found.
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::U256;

    #[test]
    fn pick_slot_prefers_current_then_next_first() {
        let current = vec![
            LookaheadSlot {
                timestamp: U256::from(200),
                committer: Address::from([1u8; 20]),
                registrationRoot: B256::ZERO,
                validatorLeafIndex: U256::ZERO,
            },
            LookaheadSlot {
                timestamp: U256::from(240),
                committer: Address::from([2u8; 20]),
                registrationRoot: B256::ZERO,
                validatorLeafIndex: U256::ZERO,
            },
        ];

        let next_first = LookaheadSlot {
            timestamp: U256::from(400),
            committer: Address::from([3u8; 20]),
            registrationRoot: B256::ZERO,
            validatorLeafIndex: U256::ZERO,
        };

        let picked = pick_slot_origin(210, &current, Some(&[next_first.clone()])).expect("slot");
        assert_eq!(picked, SlotOrigin::Current(1));

        let picked_next =
            pick_slot_origin(300, &current, Some(&[next_first.clone()])).expect("next slot");
        assert_eq!(picked_next, SlotOrigin::Next(0));

        let none = pick_slot_origin(500, &current, Some(&[next_first.clone()]));
        assert!(none.is_none());
    }

    #[test]
    fn pick_slot_falls_back_when_current_empty_even_if_next_present() {
        let next_first = LookaheadSlot {
            timestamp: U256::from(400),
            committer: Address::from([3u8; 20]),
            registrationRoot: B256::ZERO,
            validatorLeafIndex: U256::ZERO,
        };

        let picked = pick_slot_origin(210, &[], Some(&[next_first]));
        assert!(picked.is_none());
    }
}
