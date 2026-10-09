//! Epoch schedule derived from the Etna activation record (spec §6.5).
//!
//! Heights are CometBFT heights, which equal L2 block numbers (D8). With `e_0 = 0`:
//! `H_0 = B* + 1`, `epoch_of(h) = (h - H_0) / L + e_0`, `h_first(e) = H_0 + (e - e_0)·L`,
//! `h_last(e) = h_first(e + 1) - 1`, `L1_first(e) = L1_0 + (e - e_0)·EPOCH_LEN_L1`. The validator
//! set of every epoch `e >= 1` is emitted from `FinalizeBlock` at the switch height
//! `h_first(e) - 2` (D20); epoch `e_0`'s set comes from genesis.
//!
//! Limits: every method panics when `epoch_len == 0` or `genesis_height == u64::MAX` (both
//! rejected by [`Schedule::validate`]), and methods taking an epoch panic when their result would
//! overflow `u64`. Each panic message names the method.

use crate::types::ActivationRecord;
use serde::{Deserialize, Serialize};

/// The epoch schedule: the four activation-record fields the epoch arithmetic needs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Schedule {
    /// `B*`: L2 block number of the genesis anchor; the first CometBFT height is `B* + 1`.
    pub genesis_height: u64,
    /// `L1_0`: L1 block number of the activation; the minimum anchor of epoch `e_0`.
    pub l1_0: u64,
    /// `L`: epoch length in L2 blocks (CometBFT heights); validated `>= 3` and `>= U + 3`.
    pub epoch_len: u64,
    /// `EPOCH_LEN_L1`: epoch length in L1 blocks, the step of the per-epoch minimum anchor;
    /// validated `>= 1`.
    pub epoch_len_l1: u64,
}

/// Schedule parameters rejected by [`Schedule::validate`].
#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ScheduleError {
    /// `epoch_len < 3`: the switch height `h_first(e) - 2` would not lie inside epoch `e - 1`.
    #[error("epoch_len ({epoch_len}) must be >= 3")]
    EpochTooShort {
        /// The rejected `L`.
        epoch_len: u64,
    },
    /// `epoch_len < unsettled_cap + 3` (review 5451940267's `N >= U + 3`).
    #[error("epoch_len ({epoch_len}) must be >= unsettled_cap ({unsettled_cap}) + 3")]
    EpochShorterThanCap {
        /// The rejected `L`.
        epoch_len: u64,
        /// `U = d_max - margin_v`, in L2 blocks.
        unsettled_cap: u64,
    },
    /// `epoch_len_l1 == 0`.
    #[error("epoch_len_l1 must be >= 1")]
    ZeroEpochLenL1,
    /// `genesis_height == u64::MAX`, so `H_0 = genesis_height + 1` overflows.
    #[error("genesis_height must be < u64::MAX")]
    GenesisHeightOverflow,
}

impl Schedule {
    /// `e_0`, the activation epoch.
    pub const E0: u64 = 0;

    /// Takes the schedule fields of the activation record.
    pub fn from_activation(a: &ActivationRecord) -> Self {
        Self {
            genesis_height: a.genesis_height,
            l1_0: a.l1_0,
            epoch_len: a.epoch_len,
            epoch_len_l1: a.epoch_len_l1,
        }
    }

    /// `H_0 = B* + 1`, the first CometBFT height and the first height of epoch `e_0`.
    ///
    /// # Panics
    ///
    /// If `genesis_height == u64::MAX`.
    pub fn h0(&self) -> u64 {
        self.genesis_height.checked_add(1).expect("h0: genesis_height + 1 overflows u64")
    }

    /// The epoch containing height `h`: `(h - H_0) / L + e_0`.
    ///
    /// `h` must be `>= H_0` (debug-asserted); release builds map lower heights to `e_0`.
    ///
    /// # Panics
    ///
    /// If `epoch_len == 0` or `genesis_height == u64::MAX`.
    pub fn epoch_of(&self, h: u64) -> u64 {
        let h0 = self.h0();
        debug_assert!(h >= h0, "epoch_of: height {h} is below H_0 = {h0}");
        h.saturating_sub(h0) / self.len("epoch_of") + Self::E0
    }

    /// `h_first(e) = H_0 + (e - e_0)·L`, the first height of epoch `e`.
    ///
    /// # Panics
    ///
    /// If the height overflows `u64` or `genesis_height == u64::MAX`.
    pub fn h_first(&self, e: u64) -> u64 {
        Self::offset(e, self.epoch_len)
            .and_then(|o| o.checked_add(self.h0()))
            .expect("h_first: height overflows u64")
    }

    /// `h_last(e) = h_first(e + 1) - 1`, the last height of epoch `e`.
    ///
    /// # Panics
    ///
    /// If `h_first(e + 1)` overflows `u64` or `genesis_height == u64::MAX`.
    pub fn h_last(&self, e: u64) -> u64 {
        let next = e.checked_add(1).expect("h_last: epoch + 1 overflows u64");
        // h_first(next) >= H_0 >= 1, so the subtraction cannot underflow.
        self.h_first(next) - 1
    }

    /// `L1_first(e) = L1_0 + (e - e_0)·EPOCH_LEN_L1`, the minimum L1 anchor number of epoch `e`.
    ///
    /// # Panics
    ///
    /// If the L1 block number overflows `u64`.
    pub fn l1_first(&self, e: u64) -> u64 {
        Self::offset(e, self.epoch_len_l1)
            .and_then(|o| o.checked_add(self.l1_0))
            .expect("l1_first: L1 block number overflows u64")
    }

    /// `Some(e)` iff `h` is the switch height of epoch `e >= 1`, i.e. `h == h_first(e) - 2`:
    /// the height whose `FinalizeBlock` emits epoch `e`'s validator set (D20). Never `H_0`.
    ///
    /// # Panics
    ///
    /// If `epoch_len == 0` or `genesis_height == u64::MAX`.
    pub fn switch_target(&self, h: u64) -> Option<u64> {
        let e = self.epoch_starting_at(h.checked_add(2)?)?;
        // Epoch e_0's set comes from genesis, so only e >= e_0 + 1 = 1 has a switch height.
        (e > Self::E0).then_some(e)
    }

    /// `Some(e)` iff `h == h_first(e)` for some epoch `e >= e_0` (so `Some(e_0)` at `H_0`).
    ///
    /// # Panics
    ///
    /// If `epoch_len == 0` or `genesis_height == u64::MAX`.
    pub fn epoch_starting_at(&self, h: u64) -> Option<u64> {
        let len = self.len("epoch_starting_at");
        let offset = h.checked_sub(self.h0())?;
        (offset % len == 0).then(|| offset / len + Self::E0)
    }

    /// Checks `epoch_len >= 3`, `epoch_len >= unsettled_cap + 3`, `epoch_len_l1 >= 1` and
    /// `genesis_height < u64::MAX`, returning the first violation. `InitChain` and every load
    /// of `AppState` must call this before using the schedule.
    pub fn validate(&self, unsettled_cap: u64) -> Result<(), ScheduleError> {
        if self.epoch_len < 3 {
            return Err(ScheduleError::EpochTooShort { epoch_len: self.epoch_len });
        }
        if unsettled_cap.checked_add(3).is_none_or(|min| self.epoch_len < min) {
            return Err(ScheduleError::EpochShorterThanCap {
                epoch_len: self.epoch_len,
                unsettled_cap,
            });
        }
        if self.epoch_len_l1 == 0 {
            return Err(ScheduleError::ZeroEpochLenL1);
        }
        if self.genesis_height == u64::MAX {
            return Err(ScheduleError::GenesisHeightOverflow);
        }
        Ok(())
    }

    /// `L`, asserted non-zero; `caller` names the public method in the panic message.
    ///
    /// # Panics
    ///
    /// If `epoch_len == 0`.
    fn len(&self, caller: &str) -> u64 {
        assert!(self.epoch_len != 0, "{caller}: epoch_len is zero");
        self.epoch_len
    }

    /// `(e - e_0)·step`, or `None` if it underflows or overflows `u64`.
    fn offset(e: u64, step: u64) -> Option<u64> {
        e.checked_sub(Self::E0)?.checked_mul(step)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::B256;

    const L1_0: u64 = 50;
    const EPOCH_LEN_L1: u64 = 4;

    fn schedule(genesis_height: u64, epoch_len: u64) -> Schedule {
        Schedule { genesis_height, l1_0: L1_0, epoch_len, epoch_len_l1: EPOCH_LEN_L1 }
    }

    /// Every (genesis_height, L) combination the boundary tables run over.
    const CASES: [(u64, u64); 4] = [(0, 3), (0, 20), (100, 3), (100, 20)];

    #[test]
    fn from_activation_copies_the_schedule_fields() {
        let a = ActivationRecord {
            genesis_height: 7,
            l1_0: 9,
            epoch_len: 20,
            epoch_len_l1: 5,
            genesis_hash: B256::repeat_byte(1),
            genesis_state_root: B256::repeat_byte(2),
        };
        assert_eq!(
            Schedule::from_activation(&a),
            Schedule { genesis_height: 7, l1_0: 9, epoch_len: 20, epoch_len_l1: 5 }
        );
    }

    #[test]
    fn boundaries_table() {
        for (gh, l) in CASES {
            let s = schedule(gh, l);
            let h0 = gh + 1;
            let ctx = format!("genesis_height={gh} L={l}");
            assert_eq!(s.h0(), h0, "{ctx}");

            // (epoch, h_first, h_last, l1_first)
            for (e, first, last, l1) in [
                (0, h0, h0 + l - 1, L1_0),
                (1, h0 + l, h0 + 2 * l - 1, L1_0 + EPOCH_LEN_L1),
                (2, h0 + 2 * l, h0 + 3 * l - 1, L1_0 + 2 * EPOCH_LEN_L1),
                (7, h0 + 7 * l, h0 + 8 * l - 1, L1_0 + 7 * EPOCH_LEN_L1),
            ] {
                assert_eq!(s.h_first(e), first, "{ctx} h_first({e})");
                assert_eq!(s.h_last(e), last, "{ctx} h_last({e})");
                assert_eq!(s.l1_first(e), l1, "{ctx} l1_first({e})");
                assert_eq!(s.epoch_of(first), e, "{ctx} epoch_of(h_first({e}))");
                assert_eq!(s.epoch_of(last), e, "{ctx} epoch_of(h_last({e}))");
                assert_eq!(s.epoch_starting_at(first), Some(e), "{ctx}");
                assert_eq!(s.epoch_starting_at(last), None, "{ctx}");
                assert_eq!(s.epoch_starting_at(first + 1), None, "{ctx}");
            }

            // (height, switch_target)
            for (h, expected) in [
                (h0 + l - 2, Some(1)),
                (h0 + 2 * l - 2, Some(2)),
                (h0 + l - 3, None),
                (h0 + l - 1, None),
                (h0 + l, None),
                (h0, None),
                (gh, None),
                (u64::MAX, None),
                (u64::MAX - 1, None),
            ] {
                assert_eq!(s.switch_target(h), expected, "{ctx} switch_target({h})");
            }

            assert_eq!(s.epoch_starting_at(gh), None, "{ctx}");
            assert_eq!(s.epoch_starting_at(0), None, "{ctx}");
        }
    }

    #[test]
    fn exhaustive_cross_check_against_definitions() {
        for (gh, l) in CASES {
            let s = schedule(gh, l);
            let h0 = s.h0();
            for h in gh.saturating_sub(3)..h0 + 6 * l {
                if h >= h0 {
                    let e = s.epoch_of(h);
                    assert!(s.h_first(e) <= h && h <= s.h_last(e), "gh={gh} L={l} h={h}");
                }
                let starts = (0..8).find(|&e| s.h_first(e) == h);
                assert_eq!(s.epoch_starting_at(h), starts, "gh={gh} L={l} h={h}");
                let switches = (1..8).find(|&e| s.h_first(e) - 2 == h);
                assert_eq!(s.switch_target(h), switches, "gh={gh} L={l} h={h}");
            }
        }
    }

    #[test]
    fn switch_heights_never_equal_h0() {
        for (gh, l) in CASES {
            let s = schedule(gh, l);
            assert_eq!(s.switch_target(s.h0()), None, "gh={gh} L={l}");
            for e in 1..10 {
                assert!(s.h_first(e) - 2 > s.h0(), "gh={gh} L={l} e={e}");
            }
        }
    }

    #[test]
    fn validate_accepts_minimal_and_test_schedules() {
        schedule(0, 3).validate(0).unwrap();
        schedule(0, 20).validate(17).unwrap();
        schedule(100, 13).validate(10).unwrap();
        schedule(u64::MAX - 1, 3).validate(0).unwrap();
    }

    #[test]
    fn validate_rejects_short_epochs() {
        for l in [0, 1, 2] {
            assert_eq!(
                schedule(0, l).validate(0),
                Err(ScheduleError::EpochTooShort { epoch_len: l })
            );
        }
    }

    #[test]
    fn validate_rejects_epochs_shorter_than_cap_plus_three() {
        assert_eq!(
            schedule(0, 12).validate(10),
            Err(ScheduleError::EpochShorterThanCap { epoch_len: 12, unsettled_cap: 10 })
        );
        assert_eq!(
            schedule(0, 20).validate(u64::MAX),
            Err(ScheduleError::EpochShorterThanCap { epoch_len: 20, unsettled_cap: u64::MAX })
        );
    }

    #[test]
    fn validate_rejects_zero_epoch_len_l1() {
        let s = Schedule { epoch_len_l1: 0, ..schedule(0, 20) };
        assert_eq!(s.validate(10), Err(ScheduleError::ZeroEpochLenL1));
    }

    #[test]
    fn validate_rejects_genesis_height_overflow() {
        assert_eq!(schedule(u64::MAX, 20).validate(10), Err(ScheduleError::GenesisHeightOverflow));
    }

    #[test]
    #[should_panic(expected = "h_first")]
    fn h_first_panics_on_overflow() {
        schedule(100, 20).h_first(u64::MAX);
    }

    #[test]
    #[should_panic(expected = "epoch_starting_at: epoch_len is zero")]
    fn zero_epoch_len_panics_with_the_method_name() {
        schedule(0, 0).epoch_starting_at(1);
    }

    #[test]
    #[should_panic(expected = "l1_first")]
    fn l1_first_panics_on_overflow() {
        schedule(100, 20).l1_first(u64::MAX);
    }
}
