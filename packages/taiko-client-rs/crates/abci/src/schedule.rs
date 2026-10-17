//! Epoch schedule of a chain starting at L2 genesis block 0.
//!
//! CometBFT heights equal L2 block numbers. With `e_0 = 0`, `H_0 = 1`,
//! `epoch_of(h) = (h - 1) / L`, `h_first(e) = 1 + e·L`,
//! `h_last(e) = h_first(e + 1) - 1` and `L1_first(e) = L1_0 + e·EPOCH_LEN_L1`.
//! `FinalizeBlock` emits epoch `e >= 1`'s validators at `h_first(e) - 2` because CometBFT
//! applies the updates two heights later. Epoch 0's validators come from genesis.
//!
//! Methods dividing by `L` panic when it is zero; [`Schedule::validate`] rejects it.
//! Epoch offsets and derivation-parent heights are checked for `u64` overflow, and
//! [`Schedule::validate`] keeps the first transition within the protocol's [`UINT48_MAX`]
//! height and anchor ranges, as `EtnaInbox.init` does.

use crate::types::GenesisRecord;
use serde::{Deserialize, Serialize};

/// `type(uint48).max`: the largest L2 height `land` accepts and the largest anchor L1 block
/// number the Etna `extraData` encodes. CometBFT's `int64` heights are wider.
pub const UINT48_MAX: u64 = (1 << 48) - 1;

/// The epoch schedule: the genesis-record fields the epoch arithmetic and the committee
/// snapshot cutoffs need.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Schedule {
    /// `L1_0`: L1 block number of initialization; the minimum anchor of epoch `e_0`.
    pub l1_0: u64,
    /// `L`: epoch length in L2 blocks (CometBFT heights); validated `>= 3`, `>= U + 3`,
    /// `< UINT48_MAX`, so `h_first(1)` is a `uint48` height.
    pub epoch_len: u64,
    /// `EPOCH_LEN_L1`: epoch length in L1 blocks, the step of the per-epoch minimum anchor;
    /// validated `>= 1` and `<= UINT48_MAX - l1_0`, so `L1_first(1)` is a `uint48` anchor.
    pub epoch_len_l1: u64,
    /// `genesisCutoff`: the explicit L1 block of epoch `e_0`'s registry snapshot; `< l1_0`
    /// for a verified genesis. Runtime epochs use the committed derivation parent anchor.
    pub genesis_cutoff: u64,
}

/// Schedule parameters rejected by [`Schedule::validate`].
#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ScheduleError {
    /// The existing minimum epoch length preserves a distinct H+2 activation boundary.
    #[error("epoch_len ({epoch_len}) must be >= 3")]
    EpochTooShort {
        /// The rejected `L`.
        epoch_len: u64,
    },
    /// `epoch_len < unsettled_cap + 3`. With `epoch_len >= unsettled_cap + 3`,
    /// back-pressure alone keeps `lastCheckpoint.height > h_first(e - 1)` at the switch height
    /// `h_first(e) - 2`.
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
    /// `h_first(1) = epoch_len + 1` exceeds [`UINT48_MAX`], the last height `land` accepts, so
    /// the first switch could never settle.
    #[error("epoch_len ({epoch_len}) puts h_first(1) above the uint48 height range")]
    FirstEpochBeyondHeightRange {
        /// The rejected `L`.
        epoch_len: u64,
    },
    /// `L1_first(1) = l1_0 + epoch_len_l1` exceeds [`UINT48_MAX`], the last anchor the
    /// `extraData` encodes, so no anchor could open epoch 1.
    #[error("l1_0 ({l1_0}) + epoch_len_l1 ({epoch_len_l1}) is above the uint48 anchor range")]
    FirstEpochBeyondAnchorRange {
        /// `L1_0`.
        l1_0: u64,
        /// The rejected `EPOCH_LEN_L1`.
        epoch_len_l1: u64,
    },
}

impl Schedule {
    /// `e_0`, the genesis epoch.
    pub const E0: u64 = 0;

    /// Takes the schedule fields of the genesis record.
    pub fn from_genesis(a: &GenesisRecord) -> Self {
        Self {
            l1_0: a.l1_0,
            epoch_len: a.epoch_len,
            epoch_len_l1: a.epoch_len_l1,
            genesis_cutoff: a.genesis_cutoff,
        }
    }

    /// `H_0 = 1`: the first consensus height after L2 genesis block 0.
    pub const fn h0(&self) -> u64 {
        1
    }

    /// The epoch containing height `h`: `(h - H_0) / L + e_0`.
    ///
    /// `h` must be `>= H_0` (debug-asserted); release builds map lower heights to `e_0`.
    ///
    /// # Panics
    ///
    /// If `epoch_len == 0`.
    pub fn epoch_of(&self, h: u64) -> u64 {
        let h0 = self.h0();
        debug_assert!(h >= h0, "epoch_of: height {h} is below H_0 = {h0}");
        h.saturating_sub(h0) / self.len("epoch_of") + Self::E0
    }

    /// `h_first(e) = H_0 + (e - e_0)·L`, the first height of epoch `e`.
    ///
    /// # Panics
    ///
    /// If the height overflows `u64`.
    pub fn h_first(&self, e: u64) -> u64 {
        self.checked_h_first(e).expect("h_first: height overflows u64")
    }

    /// [`Schedule::h_first`], or `None` if the height overflows `u64`.
    pub fn checked_h_first(&self, e: u64) -> Option<u64> {
        Self::offset(e, self.epoch_len)?.checked_add(self.h0())
    }

    /// The committed L2 parent selecting `target_epoch` at its switch: `H(target_epoch) - 3`.
    ///
    /// Epoch zero uses its explicit genesis snapshot and returns `None`. Also returns `None`
    /// if any multiplication, addition or subtraction exceeds the `u64` height domain.
    pub fn derivation_parent_height(&self, target_epoch: u64) -> Option<u64> {
        if target_epoch == Self::E0 {
            return None;
        }
        Self::offset(target_epoch, self.epoch_len)?.checked_add(self.h0())?.checked_sub(3)
    }

    /// `h_last(e) = h_first(e + 1) - 1`, the last height of epoch `e`.
    ///
    /// # Panics
    ///
    /// If `h_first(e + 1)` overflows `u64`.
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
        self.checked_l1_first(e).expect("l1_first: L1 block number overflows u64")
    }

    /// [`Schedule::l1_first`], or `None` if the L1 block number overflows `u64`.
    pub fn checked_l1_first(&self, e: u64) -> Option<u64> {
        Self::offset(e, self.epoch_len_l1)?.checked_add(self.l1_0)
    }

    /// `Some(e)` iff `h` is the switch height of epoch `e >= 1`, i.e. `h == h_first(e) - 2`:
    /// the height whose `FinalizeBlock` emits epoch `e`'s validator set (CometBFT applies it two
    /// heights later). Never `H_0`.
    ///
    /// # Panics
    ///
    /// If `epoch_len == 0`.
    pub fn switch_target(&self, h: u64) -> Option<u64> {
        let e = self.epoch_starting_at(h.checked_add(2)?)?;
        // Epoch e_0's set comes from genesis, so only e >= e_0 + 1 = 1 has a switch height.
        (e > Self::E0).then_some(e)
    }

    /// The epoch `e >= 1` of the first switch height at or after `h`, i.e. the smallest `e` with
    /// `h_first(e) - 2 >= h`: `epoch_of(h + 1) + 1`. `None` on `u64` overflow.
    ///
    /// # Panics
    ///
    /// If `epoch_len == 0`.
    pub fn next_switch_target(&self, h: u64) -> Option<u64> {
        self.epoch_of(h.checked_add(1)?).checked_add(1)
    }

    /// `Some(e)` iff `h == h_first(e)` for some epoch `e >= e_0` (so `Some(e_0)` at `H_0`).
    ///
    /// # Panics
    ///
    /// If `epoch_len == 0`.
    pub fn epoch_starting_at(&self, h: u64) -> Option<u64> {
        let len = self.len("epoch_starting_at");
        let offset = h.checked_sub(self.h0())?;
        (offset % len == 0).then(|| offset / len + Self::E0)
    }

    /// Checks `epoch_len >= 3`, `epoch_len >= unsettled_cap + 3`, `epoch_len_l1 >= 1`, that
    /// the first transition fits the protocol's `uint48` ranges: `h_first(1) <= UINT48_MAX`
    /// (a `land` height) and `L1_first(1) <= UINT48_MAX` (an `extraData` anchor), as
    /// `EtnaInbox.init` requires. Returns the first violation.
    /// `InitChain` and every load of `AppState` must call this before using the schedule.
    ///
    /// Later epochs are not range-checked: an epoch whose `L1_first` exceeds the anchor range
    /// never opens on L1, which stops the chain with a rule violation rather than a panic.
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
        if self.checked_h_first(1).is_none_or(|h| h > UINT48_MAX) {
            return Err(ScheduleError::FirstEpochBeyondHeightRange { epoch_len: self.epoch_len });
        }
        if self.checked_l1_first(1).is_none_or(|n| n > UINT48_MAX) {
            return Err(ScheduleError::FirstEpochBeyondAnchorRange {
                l1_0: self.l1_0,
                epoch_len_l1: self.epoch_len_l1,
            });
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

    fn schedule(epoch_len: u64) -> Schedule {
        Schedule { l1_0: L1_0, epoch_len, epoch_len_l1: EPOCH_LEN_L1, genesis_cutoff: L1_0 - 1 }
    }

    /// Epoch lengths used by the boundary tables.
    const CASES: [u64; 2] = [3, 20];

    #[test]
    fn from_genesis_copies_the_schedule_fields() {
        let a = GenesisRecord {
            committee_config_hash: crate::committee::committee_config_hash(
                &crate::config::ChainParams::builtin(
                    protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID,
                )
                .unwrap(),
            ),
            genesis_height: 0,
            l1_0: 9,
            epoch_len: 20,
            epoch_len_l1: 5,
            genesis_hash: B256::repeat_byte(1),
            genesis_state_root: B256::repeat_byte(2),
            genesis_cutoff: 8,
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
        };
        assert_eq!(
            Schedule::from_genesis(&a),
            Schedule { l1_0: 9, epoch_len: 20, epoch_len_l1: 5, genesis_cutoff: 8 }
        );
    }

    #[test]
    fn boundaries_table() {
        for l in CASES {
            let s = schedule(l);
            let h0 = 1;
            let ctx = format!("L={l}");
            assert_eq!(s.h0(), h0, "{ctx}");

            // (epoch, h_first, h_last, l1_first)
            for (e, first, last, l1) in [
                (0, h0, h0 + l - 1, L1_0),
                (1, h0 + l, h0 + 2 * l - 1, L1_0 + EPOCH_LEN_L1),
                (2, h0 + 2 * l, h0 + 3 * l - 1, L1_0 + 2 * EPOCH_LEN_L1),
                (7, h0 + 7 * l, h0 + 8 * l - 1, L1_0 + 7 * EPOCH_LEN_L1),
            ] {
                assert_eq!(s.h_first(e), first, "{ctx} h_first({e})");
                assert_eq!(s.checked_h_first(e), Some(first), "{ctx} checked_h_first({e})");
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
                (0, None),
                (u64::MAX, None),
                (u64::MAX - 1, None),
            ] {
                assert_eq!(s.switch_target(h), expected, "{ctx} switch_target({h})");
            }

            assert_eq!(s.epoch_starting_at(0), None, "{ctx}");
            assert_eq!(s.epoch_starting_at(0), None, "{ctx}");
        }
    }

    #[test]
    fn exhaustive_cross_check_against_definitions() {
        for l in CASES {
            let s = schedule(l);
            let h0 = s.h0();
            for h in 0..h0 + 6 * l {
                if h >= h0 {
                    let e = s.epoch_of(h);
                    assert!(s.h_first(e) <= h && h <= s.h_last(e), "L={l} h={h}");
                }
                let starts = (0..8).find(|&e| s.h_first(e) == h);
                assert_eq!(s.epoch_starting_at(h), starts, "L={l} h={h}");
                let switches = (1..8).find(|&e| s.h_first(e) - 2 == h);
                assert_eq!(s.switch_target(h), switches, "L={l} h={h}");
                let upcoming = (h..).find_map(|x| s.switch_target(x));
                assert_eq!(s.next_switch_target(h), upcoming, "L={l} h={h}");
            }
        }
    }

    #[test]
    fn switch_heights_never_equal_h0() {
        for l in CASES {
            let s = schedule(l);
            assert_eq!(s.switch_target(s.h0()), None, "L={l}");
            for e in 1..10 {
                assert!(s.h_first(e) - 2 > s.h0(), "L={l} e={e}");
            }
        }
    }

    #[test]
    fn validate_accepts_minimal_and_test_schedules() {
        schedule(3).validate(0).unwrap();
        schedule(20).validate(17).unwrap();
        schedule(13).validate(10).unwrap();
        schedule(3).validate(0).unwrap();
    }

    #[test]
    fn validate_rejects_short_epochs() {
        for l in [0, 1, 2] {
            assert_eq!(schedule(l).validate(0), Err(ScheduleError::EpochTooShort { epoch_len: l }));
        }
    }

    #[test]
    fn validate_rejects_epochs_shorter_than_cap_plus_three() {
        assert_eq!(
            schedule(12).validate(10),
            Err(ScheduleError::EpochShorterThanCap { epoch_len: 12, unsettled_cap: 10 })
        );
        assert_eq!(
            schedule(20).validate(u64::MAX),
            Err(ScheduleError::EpochShorterThanCap { epoch_len: 20, unsettled_cap: u64::MAX })
        );
    }

    #[test]
    fn validate_rejects_zero_epoch_len_l1() {
        let s = Schedule { epoch_len_l1: 0, ..schedule(20) };
        assert_eq!(s.validate(10), Err(ScheduleError::ZeroEpochLenL1));
    }

    #[test]
    fn validate_accepts_epochs_above_the_removed_score_cap() {
        let old_score_cap = u64::from(u32::MAX) / 10_000;
        assert_eq!(schedule(old_score_cap + 1).validate(10), Ok(()));
    }

    #[test]
    fn validate_keeps_the_first_transition_in_the_uint48_ranges() {
        // h_first(1) = L + 1 may be the last height `land` accepts, not one above it.
        let s = Schedule { epoch_len: UINT48_MAX - 1, ..schedule(20) };
        assert_eq!(s.validate(10), Ok(()));
        assert_eq!(s.h_first(1), UINT48_MAX);
        for epoch_len in [UINT48_MAX, u64::MAX - 1, u64::MAX] {
            assert_eq!(
                Schedule { epoch_len, ..schedule(20) }.validate(10),
                Err(ScheduleError::FirstEpochBeyondHeightRange { epoch_len }),
                "L={epoch_len}"
            );
        }

        // L1_first(1) = L1_0 + EPOCH_LEN_L1 may be the last anchor extraData encodes.
        let s = Schedule { epoch_len_l1: UINT48_MAX - L1_0, ..schedule(20) };
        s.validate(10).unwrap();
        assert_eq!(s.l1_first(1), UINT48_MAX);
        for epoch_len_l1 in [UINT48_MAX - L1_0 + 1, u64::MAX - L1_0, u64::MAX] {
            assert_eq!(
                Schedule { epoch_len_l1, ..schedule(20) }.validate(10),
                Err(ScheduleError::FirstEpochBeyondAnchorRange { l1_0: L1_0, epoch_len_l1 }),
                "EPOCH_LEN_L1={epoch_len_l1}"
            );
        }
    }

    #[test]
    #[should_panic(expected = "h_first")]
    fn h_first_panics_on_overflow() {
        schedule(20).h_first(u64::MAX);
    }

    #[test]
    fn checked_h_first_reports_overflow() {
        assert_eq!(schedule(20).checked_h_first(u64::MAX), None);
        assert_eq!(Schedule { epoch_len: u64::MAX, ..schedule(20) }.checked_h_first(1), None);
        assert_eq!(
            Schedule { epoch_len: u64::MAX - 1, ..schedule(20) }.checked_h_first(1),
            Some(u64::MAX)
        );
    }

    #[test]
    #[should_panic(expected = "epoch_starting_at: epoch_len is zero")]
    fn zero_epoch_len_panics_with_the_method_name() {
        schedule(0).epoch_starting_at(1);
    }

    #[test]
    #[should_panic(expected = "l1_first")]
    fn l1_first_panics_on_overflow() {
        schedule(20).l1_first(u64::MAX);
    }
}

#[cfg(test)]
mod parent_height_tests {
    use super::*;

    #[test]
    fn derivation_parent_is_checked_before_switch_and_activation() {
        let schedule =
            Schedule { l1_0: 1000, epoch_len: 10, epoch_len_l1: 32, genesis_cutoff: 980 };
        for (epoch, height) in
            [(0, None), (1, Some(8)), (2, Some(18)), (3, Some(28)), (u64::MAX, None)]
        {
            assert_eq!(schedule.derivation_parent_height(epoch), height);
        }
        assert_eq!(Schedule { epoch_len: u64::MAX, ..schedule }.derivation_parent_height(1), None);
        assert_eq!(Schedule { epoch_len: 1, ..schedule }.derivation_parent_height(1), None);
        assert_eq!(Schedule { epoch_len: 3, ..schedule }.derivation_parent_height(1), Some(1));
    }
}
