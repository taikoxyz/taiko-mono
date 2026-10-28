//! Pure authentication of the minimal execution history used by starting committees.

use crate::error::{LanderError, Result};
use abci::{Schedule, rules};
use alloy_consensus::Header;
use alloy_primitives::B256;
use std::collections::BTreeMap;

/// Conservative encoded size ceiling for a canonical execution header, including genesis.
const MAX_EXECUTION_HEADER_BYTES: u64 = 1024;
/// Reserve at most a quarter of the existing journal budget for execution ancestry.
const MAX_EXECUTION_HISTORY_HEADERS: u64 =
    crate::store::MAX_JOURNAL_BYTES / 4 / MAX_EXECUTION_HEADER_BYTES;

/// Reject noncanonical or oversized headers before retaining or encoding their variable data.
pub fn check_header_capacity(header: &Header) -> Result<()> {
    if header.extra_data.len() > 32 ||
        alloy_rlp::encode(header).len() as u64 > MAX_EXECUTION_HEADER_BYTES
    {
        return Err(LanderError::Capacity(
            "execution history header exceeds encoded size budget".into(),
        ));
    }
    Ok(())
}

/// Contract-bound checkpoint and schedule opening used to bound and authenticate history.
pub struct HistoryInput<'a> {
    /// Trusted checkpoint height in execution blocks.
    pub height: u64,
    /// Trusted checkpoint execution hash.
    pub hash: B256,
    /// Generation authenticated by Inbox state.
    pub generation: u64,
    /// Independently authenticated genesis schedule.
    pub schedule: &'a Schedule,
}

/// Minimal required epochs and oldest execution header, computed before any history RPC.
pub struct HistoryRequirements {
    /// Current and pending starting epochs whose derivation parent is already committed.
    pub epochs: Vec<u64>,
    /// Oldest required height, including the base-fee grandparent.
    pub oldest: u64,
}

/// Check schedule arithmetic and the epoch-sized ancestry bound before allocating headers.
pub fn requirements(height: u64, schedule: &Schedule) -> Result<HistoryRequirements> {
    if schedule.epoch_len < 3 {
        return Err(LanderError::Safety("invalid execution history epoch length".into()));
    }
    let future = height
        .checked_add(2)
        .ok_or_else(|| LanderError::Safety("checkpoint height overflow".into()))?;
    let current = schedule.epoch_of(height.max(1));
    let next = schedule.epoch_of(future);
    if next.saturating_sub(current) > 1 {
        return Err(LanderError::Safety("starting epochs are not adjacent".into()));
    }
    let mut epochs = vec![current];
    if next != current && schedule.derivation_parent_height(next).is_some_and(|d| d <= height) {
        epochs.push(next);
    }
    let mut oldest = height.saturating_sub(1);
    for epoch in &epochs {
        if let Some(d) = schedule.derivation_parent_height(*epoch) {
            if d > height {
                return Err(LanderError::Safety("uncommitted starting derivation parent".into()));
            }
            oldest = oldest.min(d);
        }
    }
    let bound = schedule
        .epoch_len
        .checked_add(2)
        .ok_or_else(|| LanderError::Safety("history bound overflow".into()))?;
    if height - oldest > bound {
        return Err(LanderError::Capacity("starting execution history exceeds epoch bound".into()));
    }
    if height - oldest >= MAX_EXECUTION_HISTORY_HEADERS {
        return Err(LanderError::Capacity("execution history exceeds journal header budget".into()));
    }
    Ok(HistoryRequirements { epochs, oldest })
}

/// Authenticate exact descending execution links and derive every starting snapshot from them.
///
/// Descendants of this checkpoint are deliberately absent: their committees require validated
/// outgoing certificates and embedded switch transitions before they can become authorities.
pub fn verify(
    input: HistoryInput<'_>,
    headers: &[Header],
) -> Result<BTreeMap<u64, Option<Header>>> {
    let required = requirements(input.height, input.schedule)?;
    let count = input.height - required.oldest + 1;
    if headers.len() as u64 != count {
        return Err(LanderError::Safety(format!(
            "execution history requires height {} through {}",
            required.oldest, input.height
        )));
    }
    if headers.first().is_none_or(|h| h.number != input.height || h.hash_slow() != input.hash) {
        return Err(LanderError::Safety("execution history checkpoint hash/height mismatch".into()));
    }
    for header in headers {
        check_header_capacity(header)?;
    }
    for pair in headers.windows(2) {
        if pair[0].number.checked_sub(1) != Some(pair[1].number) ||
            pair[0].parent_hash != pair[1].hash_slow()
        {
            return Err(LanderError::Safety(
                "execution history hash/height links are discontinuous".into(),
            ));
        }
    }
    for header in headers.iter().filter(|h| h.number > 0) {
        let (sharing, generation, number) = rules::decode_extra_data(&header.extra_data)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        if sharing != rules::BASEFEE_SHARING_PCTG ||
            generation != input.generation ||
            number < input.schedule.l1_0 ||
            header.parent_beacon_block_root.is_none_or(|r| r.is_zero())
        {
            return Err(LanderError::Safety(format!(
                "execution history height {} has invalid Etna generation/anchor fields",
                header.number
            )));
        }
    }
    required
        .epochs
        .into_iter()
        .map(|epoch| {
            let parent = input
                .schedule
                .derivation_parent_height(epoch)
                .map(|d| headers[(input.height - d) as usize].clone());
            Ok((epoch, parent))
        })
        .collect()
}

/// Read the immutable derivation snapshot from a verified header, retaining genesis's exception.
pub fn snapshot_number(parent: Option<&Header>, schedule: &Schedule) -> Result<u64> {
    match parent {
        None => Ok(schedule.genesis_cutoff),
        Some(header) if header.number == 0 => Ok(schedule.l1_0),
        Some(header) => rules::decode_extra_data(&header.extra_data)
            .map(|(_, _, n)| n)
            .map_err(|e| LanderError::Safety(e.to_string())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn schedule() -> Schedule {
        Schedule { l1_0: 10, epoch_len: 10, genesis_cutoff: 1 }
    }
    fn headers(mutation: u8) -> Vec<Header> {
        let mut result = Vec::new();
        let mut parent = B256::repeat_byte(1);
        for number in 8..=15 {
            let header = Header {
                number,
                parent_hash: parent,
                extra_data: rules::encode_extra_data(
                    if mutation == 1 && number == 8 { 1 } else { 0 },
                    if mutation == 2 && number == 8 { 9 } else { 11 },
                )
                .unwrap(),
                parent_beacon_block_root: if mutation == 3 && number == 8 {
                    Some(B256::ZERO)
                } else {
                    Some(B256::repeat_byte(7))
                },
                timestamp: number + 100,
                ..Default::default()
            };
            parent = header.hash_slow();
            result.push(header);
        }
        result.reverse();
        result
    }
    fn verify_headers(headers: &[Header]) -> Result<BTreeMap<u64, Option<Header>>> {
        verify(
            HistoryInput {
                height: 15,
                hash: headers[0].hash_slow(),
                generation: 0,
                schedule: &schedule(),
            },
            headers,
        )
    }
    #[test]
    fn minimal_epoch_derives_from_first_block_anchor_not_bootstrap_cutoff() {
        let schedule = Schedule { l1_0: 10, epoch_len: 3, genesis_cutoff: 1 };
        assert_eq!(schedule.derivation_parent_height(1), Some(1));
        let parent = Header {
            number: 1,
            extra_data: rules::encode_extra_data(0, 11).unwrap(),
            ..Default::default()
        };
        assert_eq!(snapshot_number(Some(&parent), &schedule).unwrap(), 11);
        assert_eq!(snapshot_number(None, &schedule).unwrap(), 1);
    }

    #[test]
    fn minimal_starting_epochs_include_pending_set_at_switch_checkpoint() {
        for (p, epochs, oldest) in [
            (8, vec![0], 7),
            (9, vec![0, 1], 8),
            (10, vec![0, 1], 8),
            (11, vec![1], 8),
            (15, vec![1], 8),
            (18, vec![1], 8),
            (19, vec![1, 2], 8),
            (20, vec![1, 2], 8),
            (21, vec![2], 18),
        ] {
            let req = requirements(p, &schedule()).unwrap();
            assert_eq!(req.epochs, epochs);
            assert_eq!(req.oldest, oldest);
        }
        assert!(requirements(u64::MAX, &schedule()).is_err());
        let mut oversized = schedule();
        oversized.epoch_len = u64::MAX;
        assert!(requirements(0, &oversized).is_err());
    }
    #[test]
    fn history_binds_order_number_hash_generation_and_anchor_without_hints() {
        let valid = headers(0);
        let derived = verify_headers(&valid).unwrap();
        assert_eq!(derived[&1].as_ref().unwrap().number, 8);
        assert_eq!(snapshot_number(derived[&1].as_ref(), &schedule()).unwrap(), 11);
        assert_eq!(snapshot_number(None, &schedule()).unwrap(), 1);
        for mutation in 1..=3 {
            assert!(verify_headers(&headers(mutation)).is_err());
        }
        let mut changed = valid.clone();
        changed.swap(1, 2);
        assert!(verify_headers(&changed).is_err());
        let mut changed = valid.clone();
        changed[1].number -= 1;
        assert!(verify_headers(&changed).is_err());
        let mut changed = valid.clone();
        changed[1].parent_hash = B256::ZERO;
        assert!(verify_headers(&changed).is_err());
        assert!(verify_headers(&valid[..7]).is_err());
    }
}
