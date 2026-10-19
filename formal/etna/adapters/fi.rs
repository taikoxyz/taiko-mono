//! Standalone conformance adapter: compiles the exact production reducer source.
// Mutations can intentionally make a production error variant unreachable.
#[allow(dead_code)]
#[path = "../../../packages/taiko-client-rs/crates/etna-consensus-core/src/forced.rs"]
mod forced;
use forced::*;
use std::io::{self, BufRead};

fn error(e: ForcedError) -> String {
    match e {
        ForcedError::MissingWitness(c) => format!("missing-witness:{c}"),
        ForcedError::UnexpectedWitness => "unexpected-witness".into(),
        ForcedError::WrongIndex { expected, got } => format!("wrong-index:{expected}:{got}"),
        ForcedError::TooLarge(n) => format!("too-large:{n}"),
        ForcedError::HashMismatch => "hash-mismatch".into(),
        ForcedError::NeedsSingleton => "needs-singleton".into(),
        ForcedError::Retained => "retained".into(),
        ForcedError::CursorOverflow => "cursor-overflow".into(),
    }
}
fn main() {
    for line in io::stdin().lock().lines() {
        let line = line.unwrap();
        let f: Vec<_> = line.split('\t').collect();
        let n = |i: usize| f[i + 2].parse::<u64>().unwrap();
        let b = |i: usize| f[i + 2].parse::<bool>().unwrap();
        let o = |i: usize| if f[i + 2] == "null" { None } else { Some(n(i)) };
        let actual = match f[1] {
            "pending" => pending_entry(n(0), n(1), o(2))
                .map(|v| v.to_string())
                .unwrap_or_else(error),
            "preimage" => check_preimage(n(0), b(1))
                .map(|_| "ok".into())
                .unwrap_or_else(error),
            "due" => is_due(n(0), n(1), n(2)).to_string(),
            "classify" => classify_forced(ForcedFacts {
                cursor: n(0),
                timestamp: n(1),
                delay: n(2),
                anchor_timestamp: n(3),
                preimage_len: n(4),
                preimage_hash_matches: b(5),
                preimage_canonical: b(6),
                first_matches: b(7),
            })
            .map(|d| match d {
                ForcedDecision::Ordinary => "ordinary".into(),
                ForcedDecision::Included(i) => format!("included:{i}"),
                ForcedDecision::SkippedInvalid(i) => format!("invalid:{i}"),
                ForcedDecision::NeedsSkip(i) => format!("needs:{i}"),
            })
            .unwrap_or_else(error),
            "resolve" => {
                let d = match f[2] {
                    "ordinary" => ForcedDecision::Ordinary,
                    "included" => ForcedDecision::Included(n(1)),
                    "invalid" => ForcedDecision::SkippedInvalid(n(1)),
                    "needs" => ForcedDecision::NeedsSkip(n(1)),
                    _ => panic!("invalid decision"),
                };
                let outcome = match f[4] {
                    "empty" => SingletonOutcome::Empty,
                    "retained" => SingletonOutcome::Retained,
                    "unavailable" => SingletonOutcome::NotBuilt,
                    _ => panic!("invalid scalar outcome"),
                };
                resolve_forced(d, outcome)
                    .map(|v| v.map_or("none".into(), |i| format!("consumed:{i}")))
                    .unwrap_or_else(error)
            }
            "advance" => advance_cursor(n(0), o(1))
                .map(|v| v.to_string())
                .unwrap_or_else(error),
            _ => panic!("invalid operation"),
        };
        println!("{}\t{}", f[0], actual);
    }
}
