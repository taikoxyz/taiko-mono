extern crate std;
use super::{forced::*, schedule::*, transition::*, *};

#[test]
fn quorum_handles_full_domain_and_strict_boundary() {
    for (signed, total, expected) in [
        (0, 0, false),
        (1, 0, true),
        (2, 3, false),
        (3, 3, true),
        (u128::MAX, u128::MAX, true),
        (u128::MAX / 3 * 2, u128::MAX, false),
    ] {
        assert_eq!(has_strict_quorum(signed, total), expected);
    }
}

#[test]
fn consumption_needs_completed_empty_singleton_and_exact_cursor() {
    assert_eq!(
        resolve_forced(ForcedDecision::NeedsSkip(7), SingletonOutcome::NotBuilt),
        Err(ForcedError::NeedsSingleton)
    );
    assert_eq!(
        resolve_forced(ForcedDecision::NeedsSkip(7), SingletonOutcome::Retained),
        Err(ForcedError::Retained)
    );
    assert_eq!(resolve_forced(ForcedDecision::NeedsSkip(7), SingletonOutcome::Empty), Ok(Some(7)));
    assert_eq!(advance_cursor(7, Some(7)), Ok(8));
    assert_eq!(advance_cursor(7, Some(8)), Err(ForcedError::WrongIndex { expected: 7, got: 8 }));
    assert_eq!(advance_cursor(u64::MAX, Some(u64::MAX)), Err(ForcedError::CursorOverflow));
    assert_eq!(advance_cursor(u64::MAX, None), Ok(u64::MAX));
}

#[test]
fn golden_original_authenticated_classifier_corpus() {
    for row in include_str!("../../abci/src/forced/behavior-corpus.csv").lines().skip(1) {
        let fields: std::vec::Vec<_> = row.split(',').collect();
        let canonical = fields[1] == "canonical";
        let empty = fields[1] == "empty";
        let omitted = fields[2] == "true";
        let first = fields[3] == "true";
        let len = if omitted || empty {
            0
        } else {
            match fields[1] {
                "8192" => 8192,
                "8193" => 8193,
                _ => 1,
            }
        };
        let facts = ForcedFacts {
            cursor: 7,
            timestamp: 100,
            delay: 20,
            anchor_timestamp: (120i64 + fields[4].parse::<i64>().unwrap()) as u64,
            preimage_len: len,
            preimage_hash_matches: !omitted || empty,
            preimage_canonical: canonical && !omitted,
            first_matches: first && canonical,
        };
        let outcome = match classify_forced(facts) {
            Ok(ForcedDecision::Ordinary) => "ordinary",
            Ok(ForcedDecision::Included(7)) => "included:7",
            Ok(ForcedDecision::SkippedInvalid(7)) => "invalid:7",
            Ok(ForcedDecision::NeedsSkip(7)) => "needs:7",
            Err(ForcedError::TooLarge(_)) => "too-large",
            Err(ForcedError::HashMismatch) => "hash-mismatch",
            other => panic!("{other:?}"),
        };
        assert_eq!(outcome, fields[5], "{row}");
    }
}

#[test]
fn committee_plan_orders_conflict_then_outgoing_then_incoming_and_overlays() {
    let s = Schedule { l1_0: 50, epoch_len: 3, epoch_len_l1: 4, genesis_cutoff: 49 };
    let facts = CommitteeFacts {
        derived: DerivedRelation::None,
        outgoing_known: false,
        incoming_known: false,
    };
    assert_eq!(
        transition_committee(
            &s,
            2,
            CommitteeFacts { derived: DerivedRelation::Conflicting(1), ..facts }
        ),
        Err(CommitteeError::Conflict(1))
    );
    assert_eq!(transition_committee(&s, 2, facts), Err(CommitteeError::Unknown(0)));
    assert_eq!(
        transition_committee(&s, 2, CommitteeFacts { outgoing_known: true, ..facts }),
        Err(CommitteeError::Unknown(1))
    );
    assert_eq!(
        transition_committee(
            &s,
            2,
            CommitteeFacts { derived: DerivedRelation::Absent(1), outgoing_known: true, ..facts }
        ),
        Ok(CommitteePlan {
            insert_epoch: Some(1),
            switch: Some(SwitchPlan { outgoing_epoch: 0, incoming_epoch: 1, prune_before: 0 })
        })
    );
    assert_eq!(
        transition_committee(&s, 1, facts),
        Ok(CommitteePlan { insert_epoch: None, switch: None })
    );
}

#[test]
fn due_presence_and_schedule_checked_boundaries() {
    assert!(!is_due(1, u64::MAX, u64::MAX));
    assert!(is_due(u64::MAX, 0, u64::MAX));
    assert!(!is_due(u64::MAX, 1, u64::MAX));
    assert_eq!(pending_entry(7, 8, None), Err(ForcedError::MissingWitness(7)));
    assert_eq!(pending_entry(7, 7, Some(8)), Err(ForcedError::UnexpectedWitness));
    assert_eq!(pending_entry(7, 8, Some(8)), Err(ForcedError::WrongIndex { expected: 7, got: 8 }));
    let s = Schedule { l1_0: 50, epoch_len: 3, epoch_len_l1: 4, genesis_cutoff: 49 };
    assert_eq!(s.derivation_parent_height(0), None);
    assert_eq!(s.derivation_parent_height(1), Some(1));
    assert_eq!(s.switch_target(2), Some(1));
    assert_eq!(s.h_first(1), Some(4));
    assert_eq!(s.h_first(u64::MAX), None);
    assert_eq!(s.checked_l1_first(u64::MAX), None);
    assert_eq!(s.next_switch_target(u64::MAX), None);
    assert_eq!(s.validate(u64::MAX), Err(ScheduleError::EpochShorterThanCap));
}

#[test]
fn golden_original_checked_schedule_corpus() {
    for row in include_str!("schedule-corpus.csv").lines().skip(1) {
        let f: std::vec::Vec<_> = row.split(',').collect();
        let length = f[0].parse().unwrap();
        let height = f[1].parse().unwrap();
        let epoch = f[2].parse().unwrap();
        let s = Schedule { l1_0: 50, epoch_len: length, epoch_len_l1: 4, genesis_cutoff: 49 };
        if height != 0 {
            assert_eq!(std::format!("{}", s.epoch_of(height).unwrap()), f[3], "{row}");
        }
        assert_eq!(
            s.h_first(epoch)
                .map_or_else(|| std::string::String::from("panic"), |v| std::format!("{v}")),
            f[4],
            "{row}"
        );
        assert_eq!(
            s.h_last(epoch)
                .map_or_else(|| std::string::String::from("panic"), |v| std::format!("{v}")),
            f[5],
            "{row}"
        );
        for (got, expected) in [
            (s.checked_l1_first(epoch), f[6]),
            (s.derivation_parent_height(epoch), f[7]),
            (s.switch_target(height), f[8]),
            (s.next_switch_target(height), f[9]),
            (s.epoch_starting_at(height), f[10]),
        ] {
            assert_eq!(std::format!("{got:?}"), expected, "{row}");
        }
    }
    assert_eq!(
        Schedule { l1_0: 50, epoch_len: 3, epoch_len_l1: 4, genesis_cutoff: 49 }.epoch_of(0),
        Some(0)
    );
}

#[test]
fn original_completed_resolution_and_cursor_corpus() {
    for row in include_str!("../../abci/src/forced/resolution-corpus.csv").lines().skip(1) {
        let f: std::vec::Vec<_> = row.split(',').collect();
        let decision = match f[0] {
            "ordinary" => ForcedDecision::Ordinary,
            "included" => ForcedDecision::Included(7),
            "invalid" => ForcedDecision::SkippedInvalid(7),
            "needs" => ForcedDecision::NeedsSkip(7),
            _ => panic!("{row}"),
        };
        // Failed/incomplete adapter operations supply no completed singleton evidence.
        let outcome = match f[1] {
            "empty" => SingletonOutcome::Empty,
            "retained" => SingletonOutcome::Retained,
            _ => SingletonOutcome::NotBuilt,
        };
        let consumed = resolve_forced(decision, outcome).ok().flatten();
        assert_eq!(consumed, if f[2] == "consumed:7" { Some(7) } else { None }, "{row}");
        assert_eq!(advance_cursor(7, consumed).unwrap(), f[3].parse::<u64>().unwrap(), "{row}");
    }
}

#[test]
fn strict_quorum_matches_original_bounded_multiplication_predicate() {
    for total in 0..=1000u128 {
        for signed in 0..=total + 1 {
            assert_eq!(
                has_strict_quorum(signed, total),
                signed * 3 > total * 2,
                "{signed}/{total}"
            );
        }
    }
}

#[test]
fn checked_configuration_and_runtime_boundaries() {
    use crate::schedule::{AnchorError, ScheduleError, UINT48_MAX};
    let s = Schedule { l1_0: 64, epoch_len: 20, epoch_len_l1: 1, genesis_cutoff: 63 };
    assert!(!crate::positive_unsettled_cap(2, 2));
    assert!(!crate::positive_unsettled_cap(1, 2));
    assert!(crate::positive_unsettled_cap(3, 2));
    assert_eq!(
        Schedule { epoch_len: UINT48_MAX, ..s }.validate(10),
        Err(ScheduleError::FirstEpochBeyondHeightRange)
    );
    assert_eq!(
        Schedule { epoch_len_l1: u64::MAX, ..s }.validate(10),
        Err(ScheduleError::FirstEpochBeyondAnchorRange)
    );
    assert_eq!(
        Schedule { epoch_len_l1: u64::MAX, ..s }.check_anchor_progress(64, u64::MAX, 21),
        Err(AnchorError::EpochNotOpen { epoch: 1, l1_first: u64::MAX })
    );
    assert_eq!(Schedule { epoch_len: 0, ..s }.force_epoch(1, 0), None);
    assert_eq!(s.force_epoch(19, 0), Some(true));
    assert_eq!(s.force_epoch(20, 19), Some(false));
    assert_eq!(Schedule { epoch_len: u64::MAX, ..s }.force_epoch(1, 0), Some(false));
}

#[test]
fn latest_startup_bounds_preserve_error_order() {
    use crate::schedule::{ScheduleError, UINT48_MAX};
    let s = Schedule { l1_0: 64, epoch_len: 20, epoch_len_l1: 1, genesis_cutoff: 63 };
    assert!(crate::committee_size_bounded(0));
    assert!(crate::committee_size_bounded(4096));
    assert!(!crate::committee_size_bounded(4097));
    // The removed proposer-score cap no longer bounds L.
    assert_eq!(Schedule { epoch_len: 429_497, ..s }.validate(10), Ok(()));
    assert_eq!(
        Schedule { epoch_len: 429_497, epoch_len_l1: 0, ..s }.validate(10),
        Err(ScheduleError::ZeroEpochLenL1)
    );
    assert_eq!(
        Schedule { epoch_len: UINT48_MAX, ..s }.validate(10),
        Err(ScheduleError::FirstEpochBeyondHeightRange)
    );
}
