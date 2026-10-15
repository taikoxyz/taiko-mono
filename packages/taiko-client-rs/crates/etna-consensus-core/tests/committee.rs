use etna_consensus_core::{
    schedule::Schedule,
    transition::{CommitteeError, CommitteeFacts, DerivedRelation, transition_committee},
};

#[test]
fn missing_pending_authority_fails_without_fallback() {
    let s = Schedule { l1_0: 64, epoch_len: 20, epoch_len_l1: 1, genesis_cutoff: 63 };
    let missing = CommitteeFacts {
        derived: DerivedRelation::None,
        outgoing_known: true,
        incoming_known: false,
    };
    assert_eq!(transition_committee(&s, 19, missing), Err(CommitteeError::Unknown(1)));
    let derived = CommitteeFacts { derived: DerivedRelation::Absent(1), ..missing };
    let planned = transition_committee(&s, 19, derived).unwrap();
    assert_eq!(planned.insert_epoch, Some(1));
    assert_eq!(planned.switch.unwrap().incoming_epoch, 1);
}

#[test]
fn checked_intermediates_do_not_imply_a_future_switch_exists() {
    let s = Schedule { l1_0: 64, epoch_len: 3, epoch_len_l1: 1, genesis_cutoff: 63 };
    let last_epoch = u64::MAX / 3;
    assert_eq!((last_epoch - 1 + 1) * 3, u64::MAX);
    assert_eq!(s.h_last(last_epoch - 1), None);
    assert_eq!(s.next_switch_target(u64::MAX - 1), Some(last_epoch));
    assert_eq!(s.switch_target(u64::MAX - 1), None);
}
