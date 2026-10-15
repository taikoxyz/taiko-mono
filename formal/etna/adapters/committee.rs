//! Exact production source; this adapter only parses arguments and renders results.
extern crate etna_consensus_core as production;
use production::{schedule, transition};
use schedule::{Schedule, ScheduleError};
use std::io::{self, BufRead};
fn opt(n: Option<u64>) -> String {
    n.map_or("none".into(), |n| n.to_string())
}
fn main() {
    for line in io::stdin().lock().lines() {
        let line = line.unwrap();
        let f: Vec<_> = line.split('\t').collect();
        let n = |i: usize| f[i + 2].parse::<u64>().unwrap();
        let actual = if f[1] == "quorum" {
            production::has_strict_quorum(f[2].parse().unwrap(), f[3].parse().unwrap()).to_string()
        } else {
            let s = Schedule {
                l1_0: n(0),
                epoch_len: n(1),
                epoch_len_l1: n(2),
                genesis_cutoff: n(3),
            };
            match f[1] {
                "validate" => match s.validate(n(4)) {
                    Ok(()) => "ok",
                    Err(ScheduleError::EpochTooShort) => "too-short",
                    Err(ScheduleError::EpochShorterThanCap) => "shorter-than-cap",
                    Err(ScheduleError::ZeroEpochLenL1) => "zero-l1",
                }
                .into(),
                "epoch" => opt(s.epoch_of(n(4))),
                "first" => opt(s.h_first(n(4))),
                "last" => opt(s.h_last(n(4))),
                "l1" => opt(s.checked_l1_first(n(4))),
                "parent" => opt(s.derivation_parent_height(n(4))),
                "starting" => opt(s.epoch_starting_at(n(4))),
                "switch" => opt(s.switch_target(n(4))),
                "next" => opt(s.next_switch_target(n(4))),
                "plan" => {
                    use transition::{CommitteeError, CommitteeFacts, DerivedRelation};
                    let derived = match f[7] {
                        "none" => DerivedRelation::None,
                        "absent" => DerivedRelation::Absent(n(6)),
                        "equal" => DerivedRelation::Equal(n(6)),
                        "conflict" => DerivedRelation::Conflicting(n(6)),
                        _ => panic!("relation"),
                    };
                    match transition::transition_committee(
                        &s,
                        n(4),
                        CommitteeFacts {
                            derived,
                            outgoing_known: f[9].parse().unwrap(),
                            incoming_known: f[10].parse().unwrap(),
                        },
                    ) {
                        Ok(p) => format!(
                            "{}/{}",
                            opt(p.insert_epoch),
                            p.switch.map_or("none".into(), |s| format!(
                                "{}:{}:{}",
                                s.outgoing_epoch, s.incoming_epoch, s.prune_before
                            ))
                        ),
                        Err(CommitteeError::Conflict(t)) => format!("conflict:{t}"),
                        Err(CommitteeError::Unknown(t)) => format!("unknown:{t}"),
                    }
                }
                _ => panic!("operation"),
            }
        };
        println!("{}\t{}", f[0], actual);
    }
}
