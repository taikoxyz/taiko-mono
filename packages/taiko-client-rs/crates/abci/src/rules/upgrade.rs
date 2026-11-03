//! Deployment-core ruleset selection and planned stops from authenticated Inbox slot 293.

use alloy_primitives::U256;

use crate::{l1::layout::word_u48, types::ParentInfo};

use super::RuleViolation;

/// Refuses a ruleset this binary does not implement. Selection uses the candidate block's
/// timestamp and its own carried or inherited anchor, never a newer local L1 observation.
/// Ruleset zero is the complete ruleset implemented by this release.
pub fn check_supported_rules(schedule: U256, timestamp: u64) -> Result<(), RuleViolation> {
    let offset = if timestamp >= word_u48(schedule, 96) { 48 } else { 0 };
    let rules = word_u48(schedule, offset);
    if rules != 0 {
        return Err(RuleViolation::UnsupportedRuleset { rules });
    }
    Ok(())
}

/// Applies the deployment-core stop and ruleset refusal before interpreting a block under
/// ruleset zero. The stop uses the committed parent's timestamp and S-relative height;
/// it permits the stopping grid block itself and refuses its successor.
pub fn check_rules_schedule(
    schedule: U256,
    parent: &ParentInfo,
    timestamp: u64,
    etna_start: u64,
) -> Result<(), RuleViolation> {
    let stop_time = word_u48(schedule, 144);
    let stop_grid = word_u48(schedule, 192);
    if stop_time != 0 &&
        parent.timestamp >= stop_time &&
        stop_grid != 0 &&
        parent.number.checked_sub(etna_start).is_some_and(|h| h.is_multiple_of(stop_grid))
    {
        return Err(RuleViolation::PlannedStop { parent_height: parent.number });
    }
    check_supported_rules(schedule, timestamp)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::Fixture;

    #[test]
    fn rules_time_is_inclusive_and_cancellation_keeps_active_rules() {
        let scheduled = (U256::from(1) << 48) | (U256::from(100) << 96);
        assert!(check_supported_rules(scheduled, 99).is_ok());
        assert_eq!(
            check_supported_rules(scheduled, 100),
            Err(RuleViolation::UnsupportedRuleset { rules: 1 })
        );
        assert!(
            check_supported_rules(
                (U256::from(1) << 48) | (U256::from((1u64 << 48) - 1) << 96),
                100
            )
            .is_ok()
        );
        assert_eq!(
            check_supported_rules(
                U256::from(2) | (U256::from(3) << 48) | (U256::from(100) << 96),
                99
            ),
            Err(RuleViolation::UnsupportedRuleset { rules: 2 })
        );
        assert!(check_supported_rules(U256::ZERO, 0).is_ok());
    }

    #[test]
    fn stop_uses_parent_time_and_start_relative_grid() {
        let mut parent = Fixture::genesis(1).expected_state().parent;
        let schedule = (U256::from(100) << 144) | (U256::from(6) << 192);
        parent.number = 105;
        parent.timestamp = 100;
        assert!(check_rules_schedule(schedule, &parent, 101, 100).is_ok());
        parent.number = 106;
        parent.timestamp = 99;
        assert!(check_rules_schedule(schedule, &parent, 100, 100).is_ok());
        parent.timestamp = 100;
        assert_eq!(
            check_rules_schedule(schedule, &parent, 101, 100),
            Err(RuleViolation::PlannedStop { parent_height: 106 })
        );
        assert!(check_rules_schedule(U256::ZERO, &parent, 101, 100).is_ok());
    }
}
