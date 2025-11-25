// Lookahead is either Current or Next epoch's operator
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Lookahead {
    Current,
    Next,
}

// add display trait
impl std::fmt::Display for Lookahead {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Lookahead::Current => write!(f, "Current"),
            Lookahead::Next => write!(f, "Next"),
        }
    }
}

// Responsibility indicates which operator we are monitoring for a given epoch
// either the next, or the current.
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub struct Responsibility {
    pub epoch: u64,
    pub lookahead: Lookahead,
}

// responsibility_for_slot determines whether the current or next operator
// "owns" a given slot, taking the handover window into account
pub fn responsibility_for_slot(
    slot: u64,
    slots_per_epoch: u64,
    handover_slots: u64,
) -> Responsibility {
    assert!(slots_per_epoch > 0);
    let epoch = slot / slots_per_epoch;
    let slot_in_epoch = slot % slots_per_epoch;

    let handover = handover_slots.min(slots_per_epoch);
    let boundary = slots_per_epoch - handover;

    let lookahead = if slot_in_epoch >= boundary { Lookahead::Next } else { Lookahead::Current };
    Responsibility { epoch, lookahead }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn expect_window(slots_per_epoch: u64, handover: u64, slot: u64) -> Lookahead {
        let handover = handover.min(slots_per_epoch);
        let slot_in_epoch = slot % slots_per_epoch;
        let boundary = slots_per_epoch - handover;
        if slot_in_epoch >= boundary { Lookahead::Next } else { Lookahead::Current }
    }

    #[test]
    fn responsibility_covers_every_slot_in_epoch_for_various_handover_values() {
        // Try a few epoch sizes + handover configurations (including edges)
        let cases = [
            (8u64, 0u64), // no handover → all Current
            (8, 1),       // last slot Next
            (8, 2),       // last 2 slots Next
            (8, 7),       // all but first slot Next
            (8, 8),       // full handover → entire epoch Next
            (32, 0),
            (32, 1),
            (32, 4),
            (32, 16),
            (32, 32),
        ];

        for &(spe, handover) in &cases {
            // Check a couple epochs back-to-back to ensure epoch rollover is correct
            for epoch in 0..3 {
                for slot_in_epoch in 0..spe {
                    let slot = epoch * spe + slot_in_epoch;
                    let got = responsibility_for_slot(slot, spe, handover);
                    let want_lookahead = expect_window(spe, handover, slot);

                    assert_eq!(
                        got.epoch, epoch,
                        "epoch mismatch: spe={spe}, handover={handover}, slot={slot}"
                    );
                    assert_eq!(
                        got.lookahead, want_lookahead,
                        "lookahead mismatch: spe={spe}, handover={handover}, epoch={epoch}, slot_in_epoch={slot_in_epoch}"
                    );
                }
            }
        }
    }

    #[test]
    fn responsibility_edge_cases_exact_boundaries() {
        // When slot sits exactly at the boundary, it must switch to NEXT.
        let spe = 32;

        // handover = 4 → boundary = 28 → slots 28,29,30,31 => NEXT
        let handover = 4;
        let boundary = spe - handover;
        for s in [boundary - 1, boundary, boundary + 1, spe - 1] {
            let r = responsibility_for_slot(s, spe, handover);
            let expected = if s % spe >= boundary { Lookahead::Next } else { Lookahead::Current };
            assert_eq!(r.lookahead, expected, "boundary check failed at slot {s}");
        }

        // handover = 0 → boundary = 32 → no slot is >= 32 within epoch → all CURRENT
        let r = responsibility_for_slot(31, spe, 0);
        assert_eq!(r.lookahead, Lookahead::Current);

        // handover = 32 → boundary = 0 → all slots >= 0 → all NEXT
        let r = responsibility_for_slot(0, spe, 32);
        assert_eq!(r.lookahead, Lookahead::Next);
        let r = responsibility_for_slot(31, spe, 32);
        assert_eq!(r.lookahead, Lookahead::Next);
    }

    #[test]
    fn responsibility_monotonic_within_epoch_then_flips_on_boundary() {
        for handover in [0u64, 1, 5, 16, 32] {
            let spe = 32;
            let handover_capped = handover.min(spe);
            let boundary = spe - handover_capped;

            for s in 0..spe {
                let r = responsibility_for_slot(s, spe, handover);
                if s < boundary {
                    assert_eq!(
                        r.lookahead,
                        Lookahead::Current,
                        "slot {s} should be Current (handover {handover})"
                    );
                } else {
                    assert_eq!(
                        r.lookahead,
                        Lookahead::Next,
                        "slot {s} should be Next (handover {handover})"
                    );
                }
            }
        }
    }
}
