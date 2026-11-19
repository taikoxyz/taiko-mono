//! Deployment-core ruleset selection and planned stops from authenticated Inbox slot 293.

use alloy_primitives::U256;

use crate::{l1::layout::inbox::RulesSchedule, types::ParentInfo};

use super::RuleViolation;

/// Refuses a ruleset this binary does not implement. Selection uses the candidate block's
/// timestamp and its own carried or inherited anchor, never a newer local L1 observation.
/// Ruleset zero is the complete ruleset implemented by this release.
pub fn check_supported_rules(schedule: U256, timestamp: u64) -> Result<(), RuleViolation> {
    let rules = RulesSchedule::decode(schedule).rules_at(timestamp);
    if rules != 0 {
        return Err(RuleViolation::UnsupportedRuleset { rules });
    }
    Ok(())
}

/// Applies the deployment-core stop and ruleset refusal before interpreting a block under
/// ruleset zero. With `stopTime` set, a block whose committed parent's timestamp is at least
/// `stopTime` is invalid, at any height (START-10.1-14d).
pub fn check_rules_schedule(
    schedule: U256,
    parent: &ParentInfo,
    timestamp: u64,
) -> Result<(), RuleViolation> {
    let stop_time = RulesSchedule::decode(schedule).stop_time;
    if stop_time != 0 && parent.timestamp >= stop_time {
        return Err(RuleViolation::PlannedStop { parent_height: parent.number });
    }
    check_supported_rules(schedule, timestamp)
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
