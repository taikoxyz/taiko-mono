use etna_core::schedule::Schedule;

#[test]
fn generation_zero_keeps_committee_zero_when_origin_discards_switches() {
    let schedule = Schedule { l1_0: 100, epoch_len: 7, genesis_cutoff: 99 };
    for (origin, height, expected) in [
        (8, 8, None),
        (8, 9, Some(0)),
        (8, 14, Some(0)),
        (8, 15, Some(2)),
        (13, 14, Some(0)),
        (13, 15, Some(0)),
        (13, 21, Some(0)),
        (13, 22, Some(3)),
    ] {
        assert_eq!(
            schedule.active_committee_epoch_with_initial(height, origin, 0),
            expected,
            "origin={origin} height={height}"
        );
    }
    // Recovery's initial set is floor(c/L); it does not reuse the generation-zero target.
    for height in [9, 14] {
        assert_eq!(schedule.active_committee_epoch(height, 8), Some(1));
    }
    assert_eq!(schedule.active_committee_epoch(15, 8), Some(2));
    // A pending update emitted at the origin is discarded, while a later switch is retained.
    assert_eq!(schedule.switch_target(13), Some(2));
    assert_eq!(schedule.switch_target(20), Some(3));
}
