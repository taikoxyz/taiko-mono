//! Checked epoch arithmetic. Adapters own serialization and method-specific panic diagnostics.

// Explicit Option branches avoid unmodeled Try/FromResidual externs in the pinned extractor.
#![allow(clippy::question_mark)]

/// Largest height and anchor encoded by the protocol uint48 fields.
pub const UINT48_MAX: u64 = 281_474_976_710_655;

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
    /// First L2 epoch height is unrepresentable or exceeds uint48.
    FirstEpochBeyondHeightRange,
    /// First L1 epoch anchor is unrepresentable or exceeds uint48.
    FirstEpochBeyondAnchorRange,
}

/// Checked anchor rule failure, preserving the adapter's consensus error priority.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AnchorError {
    /// The anchor precedes its authenticated parent anchor.
    Regressed,
    /// The anchor precedes chain activation.
    BeforeActivation,
    /// A zero epoch length prevents epoch selection; adapters retain their panic contract.
    InvalidSchedule,
    /// The selected epoch is closed; an overflowing minimum uses MAX only diagnostically.
    EpochNotOpen {
        /// Selected epoch.
        epoch: u64,
        /// Required minimum, or u64::MAX as the diagnostic overflow sentinel.
        l1_first: u64,
    },
}

impl Schedule {
    /// Validates length, cap, L1 length, first height then first anchor, preserving priority.
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
        match self.h_first(1) {
            Some(first) if first <= UINT48_MAX => (),
            _ => return Err(ScheduleError::FirstEpochBeyondHeightRange),
        }
        match self.checked_l1_first(1) {
            Some(first) if first <= UINT48_MAX => (),
            _ => return Err(ScheduleError::FirstEpochBeyondAnchorRange),
        }
        Ok(())
    }

    /// Total anchor progression check; overflow never admits an epoch, even at anchor MAX.
    pub fn check_anchor_progress(
        &self,
        parent: u64,
        anchor: u64,
        height: u64,
    ) -> Result<(), AnchorError> {
        if anchor < parent {
            return Err(AnchorError::Regressed);
        }
        if anchor < self.l1_0 {
            return Err(AnchorError::BeforeActivation);
        }
        let epoch = match self.epoch_of(height) {
            Some(epoch) => epoch,
            None => return Err(AnchorError::InvalidSchedule),
        };
        match self.checked_l1_first(epoch) {
            Some(first) if anchor >= first => Ok(()),
            Some(first) => Err(AnchorError::EpochNotOpen { epoch, l1_first: first }),
            None => Err(AnchorError::EpochNotOpen { epoch, l1_first: u64::MAX }),
        }
    }

    /// Checked publish urgency hint; None denotes a zero-length invalid schedule.
    /// It never authorizes committee activation. Height zero retains release saturation.
    pub fn force_epoch(&self, tip: u64, checkpoint: u64) -> Option<bool> {
        let epoch = match self.epoch_of(tip) {
            Some(epoch) => epoch,
            None => return None,
        };
        if self.switch_target(tip).is_some() {
            return Some(true);
        }
        let next = match epoch.checked_add(1) {
            Some(next_epoch) => match self.h_first(next_epoch) {
                Some(first) => {
                    let next = first.saturating_sub(2);
                    next <= tip && next > checkpoint
                }
                None => false,
            },
            None => false,
        };
        let current = if epoch > 0 {
            match self.h_first(epoch) {
                Some(first) => first.saturating_sub(2) > checkpoint,
                None => false,
            }
        } else {
            false
        };
        Some(next || current)
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
