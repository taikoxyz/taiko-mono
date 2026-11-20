//! Exact stock evidence age semantics and constant predecessor-header framing.
use super::*;

/// Stock v0.40 evaluates s+1 evidence against committed state s; expiry requires both strict
/// inequalities against START-10-21's limits, which every Etna genesis fixes. Nanoseconds are
/// retained, and future evidence is never considered expired.
pub fn evidence_expired(
    post_height: u64,
    post_time: tendermint::Time,
    evidence_height: u64,
    evidence_time: tendermint::Time,
) -> bool {
    use abci::genesis::{EVIDENCE_MAX_AGE_DURATION, EVIDENCE_MAX_AGE_NUM_BLOCKS};
    post_height.checked_sub(evidence_height).is_some_and(|age| age > EVIDENCE_MAX_AGE_NUM_BLOCKS) &&
        post_time.duration_since(evidence_time).is_ok_and(|age| age > EVIDENCE_MAX_AGE_DURATION)
}

/// Prove the window (w, s] holds every height DATA-5.4-2 requires: every current-generation
/// height x <= s still within either stock evidence age limit at s (`s - x <= MaxAgeNumBlocks`
/// or `Time(s) - Time(x) <= MaxAgeDuration`, by authenticated Comet header times), the latest
/// block carrying an anchor witness, and the S(t) and, above o, the D(t) of each non-initial
/// committee signing s + 1 or s + 2. The window stops at the origin (w = o) or at a w whose
/// header, linked by w + 1's LastBlockID (`verify_boundary`), establishes both strict
/// expiry inequalities; header times increase along the chain, so every lower height has expired
/// too. ACCEPTANCE 7.5 rejects only a shorter window, so a longer one is accepted: the caller
/// still checks w >= o. Only timestamps and heights are retained; no older block, set or commit
/// is ever requested.
pub(super) fn verify_complete_window(
    w: u64,
    heights: &[(u64, tendermint::Time)],
    boundary: Option<&tendermint::block::Header>,
    context: WindowContext<'_>,
) -> Result<(), ImportError> {
    let WindowContext { origin, terminal, schedule, future, latest_anchor } = context;
    let (_, time) = heights.last().ok_or_else(|| unavailable("empty evidence window"))?;
    if w > origin {
        let header = boundary.ok_or_else(|| unavailable("missing evidence boundary header"))?;
        if !evidence_expired(terminal, *time, w, header.time) {
            return Err(unavailable("window omits still-admissible evidence height w"));
        }
    }
    let mut first = heights
        .iter()
        .find(|(h, t)| !evidence_expired(terminal, *time, *h, *t))
        .map(|(h, _)| *h)
        .ok_or_else(|| candidate("terminal evidence context absent"))?;
    first = first.min(latest_anchor);
    for epoch in future {
        if *epoch == Schedule::E0 {
            continue;
        }
        let switch = schedule
            .checked_h_first(*epoch)
            .and_then(|h| h.checked_sub(2))
            .ok_or_else(|| candidate("switch height overflow"))?;
        // A generation's initial set has no retained switch, whether it is committee zero
        // at S or the recovery-selected committee whose global switch preceded c.
        if switch <= origin {
            continue;
        }
        if switch > terminal {
            return Err(candidate("future committee has no retained switch"));
        }
        first = first.min(switch);
        if let Some(d) = schedule.derivation_parent_height(*epoch) &&
            d > origin
        {
            first = first.min(d);
        }
    }
    if first <= w {
        return Err(unavailable("window omits required switch/derivation/anchor height"));
    }
    Ok(())
}

/// Independently authenticated generation/switch facts required to prove the window complete.
pub(super) struct WindowContext<'a> {
    /// Fixed generation origin, never a selected checkpoint.
    pub origin: u64,
    /// Selected landed height whose post-state evaluates s+1 evidence.
    pub terminal: u64,
    /// Immutable authenticated epoch schedule.
    pub schedule: &'a Schedule,
    /// Epochs signing s+1/s+2, with the recovery-discarded-switch rule applied.
    pub future: &'a [u64; 2],
    /// Latest retained block containing an anchor witness.
    pub latest_anchor: u64,
}
