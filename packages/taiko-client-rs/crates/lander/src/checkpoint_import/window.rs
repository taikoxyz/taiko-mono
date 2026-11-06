//! Exact stock evidence age semantics and constant predecessor-header framing.
use super::*;

/// Stock v0.40 evaluates s+1 evidence against committed state s; expiry requires both strict
/// inequalities. Nanoseconds are retained, and future evidence is never considered expired.
pub fn evidence_expired(
    post_height: u64,
    post_time: tendermint::Time,
    evidence_height: u64,
    evidence_time: tendermint::Time,
) -> bool {
    post_height.checked_sub(evidence_height).is_some_and(|age| age > 100_000) &&
        post_time
            .duration_since(evidence_time)
            .is_ok_and(|age| age > std::time::Duration::from_secs(172_800))
}

/// Prove completeness with authenticated w time, then prove no unnecessary first block remains.
/// Only timestamps and heights are retained; no older block/set/commit is ever requested.
pub(super) fn verify_minimal_window(
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
        if *epoch == origin / schedule.epoch_len {
            continue;
        }
        let switch = schedule
            .checked_h_first(*epoch)
            .and_then(|h| h.checked_sub(2))
            .ok_or_else(|| candidate("switch height overflow"))?;
        if switch <= origin || switch > terminal {
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
    if first != w + 1 {
        return Err(candidate("window is not the shortest complete suffix"));
    }
    Ok(())
}

/// Independently authenticated generation/switch facts required to prove the shortest window.
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
