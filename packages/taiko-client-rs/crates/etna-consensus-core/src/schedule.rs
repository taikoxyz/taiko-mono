//! Checked epoch arithmetic. Adapters own serialization and method-specific panic diagnostics.

// Explicit Option branches avoid unmodeled Try/FromResidual externs in the pinned extractor.
#![allow(clippy::question_mark)]

/// Primitive schedule fields; all units and cutoffs match the serialized ABCI wrapper.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Schedule {
    /// L1 initialization block number.
    pub l1_0: u64,
    /// Epoch length in L2 blocks, validated at least three.
    pub epoch_len: u64,
    /// Epoch length in L1 blocks, validated positive.
    pub epoch_len_l1: u64,
    /// Explicit epoch-zero L1 snapshot cutoff.
    pub genesis_cutoff: u64,
}

/// Schedule validation failure, in consensus-visible validation order.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScheduleError {
    /// L2 epoch length is below three.
    EpochTooShort,
    /// L2 epoch length is below cap plus three, including overflowing cap plus three.
    EpochShorterThanCap,
    /// L1 epoch length is zero.
    ZeroEpochLenL1,
}

impl Schedule {
    /// Validates length, cap then L1 length, preserving error priority.
    pub fn validate(&self, cap: u64) -> Result<(), ScheduleError> {
        if self.epoch_len < 3 {
            return Err(ScheduleError::EpochTooShort);
        }
        match cap.checked_add(3) {
            None => return Err(ScheduleError::EpochShorterThanCap),
            Some(min) if self.epoch_len < min => return Err(ScheduleError::EpochShorterThanCap),
            Some(_) => (),
        }
        if self.epoch_len_l1 == 0 {
            return Err(ScheduleError::ZeroEpochLenL1);
        }
        Ok(())
    }

    /// Epoch containing a height; release-compatible saturation at height zero; None for L=0.
    pub fn epoch_of(&self, height: u64) -> Option<u64> {
        height.saturating_sub(1).checked_div(self.epoch_len)
    }

    /// First L2 height of an epoch, or None on multiplication/addition overflow.
    pub fn h_first(&self, epoch: u64) -> Option<u64> {
        match epoch.checked_mul(self.epoch_len) {
            Some(offset) => offset.checked_add(1),
            None => None,
        }
    }

    /// Last L2 height of an epoch, or None on epoch/height overflow.
    pub fn h_last(&self, epoch: u64) -> Option<u64> {
        let next = match epoch.checked_add(1) {
            Some(value) => value,
            None => return None,
        };
        match self.h_first(next) {
            Some(first) => first.checked_sub(1),
            None => None,
        }
    }

    /// Minimum L1 anchor of an epoch, or None on multiplication/addition overflow.
    pub fn checked_l1_first(&self, epoch: u64) -> Option<u64> {
        match epoch.checked_mul(self.epoch_len_l1) {
            Some(offset) => offset.checked_add(self.l1_0),
            None => None,
        }
    }

    /// Committed derivation parent H(epoch)-3; epoch zero has no runtime derivation parent.
    pub fn derivation_parent_height(&self, epoch: u64) -> Option<u64> {
        if epoch == 0 {
            return None;
        }
        match self.h_first(epoch) {
            Some(first) => first.checked_sub(3),
            None => None,
        }
    }

    /// Epoch starting exactly at height; None for non-boundary heights or zero length.
    pub fn epoch_starting_at(&self, height: u64) -> Option<u64> {
        if self.epoch_len == 0 {
            return None;
        }
        let offset = match height.checked_sub(1) {
            Some(value) => value,
            None => return None,
        };
        if offset % self.epoch_len == 0 { Some(offset / self.epoch_len) } else { None }
    }

    /// Incoming epoch at update height H(epoch)-2; epoch zero never switches.
    pub fn switch_target(&self, height: u64) -> Option<u64> {
        let activation = match height.checked_add(2) {
            Some(value) => value,
            None => return None,
        };
        match self.epoch_starting_at(activation) {
            Some(0) | None => None,
            target => target,
        }
    }

    /// First incoming epoch whose update height is at or after height, checked for overflow.
    pub fn next_switch_target(&self, height: u64) -> Option<u64> {
        let next = match height.checked_add(1) {
            Some(value) => value,
            None => return None,
        };
        match self.epoch_of(next) {
            Some(epoch) => epoch.checked_add(1),
            None => None,
        }
    }
}
