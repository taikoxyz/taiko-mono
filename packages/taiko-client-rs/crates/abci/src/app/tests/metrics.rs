//! The app's Prometheus metrics. The collectors are process-wide, so every test
//! runs alone in its process ([`in_own_process`]) and the exact values below hold.

use alloy_primitives::U256;

use super::{
    proposal::{
        bft_time, decide, judge, mid_epoch, next_height, prepare, prepare_req, process,
        process_req, propose,
    },
    signers::{MIN_STAKE, node, snapshot, step},
    *,
};
use crate::{
    l1::L1Error,
    metrics::AbciMetrics,
    store::FallbackReason,
    test_utils::{in_own_process, test_key},
};

/// `abci_process_rejected_total{reason = label}`.
fn rejected(label: &str) -> u64 {
    AbciMetrics::process_rejected().with_label_values(&[label]).get()
}

#[tokio::test]
async fn init_chain_publishes_the_genesis_head() {
    if !in_own_process(module_path!(), "init_chain_publishes_the_genesis_head") {
        return;
    }
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let app = initialized(&fx, dir.path()).await;
    let status = app.status().unwrap();
    assert_eq!(AbciMetrics::head().get(), i64::try_from(status.head).unwrap());
    assert_eq!(AbciMetrics::generation().get(), 0);
    assert_eq!(AbciMetrics::unsettled_depth().get(), 0);
}

#[tokio::test]
async fn a_committed_round_counts_and_publishes_the_new_head() {
    if !in_own_process(module_path!(), "a_committed_round_counts_and_publishes_the_new_head") {
        return;
    }
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let built = AbciMetrics::proposals_built().get();
    let accepted = AbciMetrics::process_accepted().get();
    let processed = AbciMetrics::process_seconds().get_sample_count();
    let finalized = AbciMetrics::finalize_seconds().get_sample_count();
    AbciMetrics::l1_finality_lag().set(-1);

    let env = propose(&mut app).await;
    let (resp, req) = judge(&mut app, &env).await;
    assert_eq!(resp, response::ProcessProposal::Accept);
    decide(&mut app, &req).await;

    assert_eq!(AbciMetrics::proposals_built().get(), built + 1);
    assert_eq!(AbciMetrics::process_accepted().get(), accepted + 1);
    assert_eq!(AbciMetrics::process_seconds().get_sample_count(), processed + 1);
    assert_eq!(AbciMetrics::finalize_seconds().get_sample_count(), finalized + 1);
    // The fixture L1 finalizes exactly the committed anchor block.
    assert_eq!(AbciMetrics::l1_finality_lag().get(), 0);
    let status = app.status().unwrap();
    assert_eq!(AbciMetrics::head().get(), i64::try_from(status.head).unwrap());
    assert_eq!(AbciMetrics::generation().get(), i64::try_from(status.generation).unwrap());
    assert_eq!(
        AbciMetrics::unsettled_depth().get(),
        i64::try_from(status.head - status.last_checkpoint_height).unwrap()
    );
    assert_eq!(AbciMetrics::halted().get(), 0);
}

/// The signing gauges: `abci_signing_source` of the `next` and `after` sets, the reasons
/// `abci_fallback_reason` raises for each, and `abci_candidate_total_stake` and
/// `abci_min_total_stake`.
#[derive(Debug, PartialEq)]
struct SigningGauges {
    sources: (i64, i64),
    reasons: (Vec<&'static str>, Vec<&'static str>),
    total: f64,
    min: f64,
}

/// The signing gauges as published now; every reason series is 0 or 1.
fn signing_gauges() -> SigningGauges {
    let source = |set: &str| AbciMetrics::signing_source().with_label_values(&[set]).get();
    let raised = |set: &str| -> Vec<&'static str> {
        FallbackReason::ALL
            .iter()
            .map(|reason| reason.label())
            .filter(|label| {
                let value = AbciMetrics::fallback_reason().with_label_values(&[set, label]).get();
                assert!(value == 0 || value == 1, "{set}/{label} = {value}");
                value == 1
            })
            .collect()
    };
    SigningGauges {
        sources: (source("next"), source("after")),
        reasons: (raised("next"), raised("after")),
        total: AbciMetrics::candidate_total_stake().get(),
        min: AbciMetrics::min_total_stake().get(),
    }
}

/// The signing gauges for the sources and raised reasons of `next` and `after` and the total
/// stake and minimum that decided `after`.
fn gauges(
    sources: (i64, i64),
    next: &[&'static str],
    after: &[&'static str],
    total: u64,
    min: u64,
) -> SigningGauges {
    let (total, min) = (f64::from(U256::from(total)), f64::from(U256::from(min)));
    SigningGauges { sources, reasons: (next.to_vec(), after.to_vec()), total, min }
}

/// The signing gauges follow a switch to a candidate and back to the fallback keys, one height
/// apart for the set that signs the next height and the one after it (`abci_signing_source`:
/// 0 candidate, 1 fallback), with the reason each fallback set signs for. The candidate total
/// stake and the minimum that decided the later set are published whichever source won, so a
/// total below the minimum shows while the fallback keys sign. A restarted app publishes them
/// from its store.
#[tokio::test]
async fn gauges_follow_a_mode_switch() {
    if !in_own_process(module_path!(), "gauges_follow_a_mode_switch") {
        return;
    }
    let fx = Fixture::genesis(2);
    let dir = tempfile::tempdir().unwrap();
    let mut app = node(&fx, dir.path(), U256::from(MIN_STAKE)).await;
    let origin = &["generation_origin"];
    assert_eq!(signing_gauges(), gauges((1, 1), origin, origin, 0, 0), "nothing decided yet");

    let members = [(test_key(11), 5), (test_key(12), 7)];
    let h = next_height(&app);
    step(&mut app, Some(snapshot(h, 4_000, &members))).await;
    assert_eq!(signing_gauges(), gauges((1, 0), origin, &[], 4_000, MIN_STAKE));
    step(&mut app, Some(snapshot(h + 1, 5_000, &members))).await;
    assert_eq!(signing_gauges(), gauges((0, 0), &[], &[], 5_000, MIN_STAKE));
    step(&mut app, Some(snapshot(h + 2, MIN_STAKE - 1, &members))).await;
    let below = &["below_min_total_stake"];
    assert_eq!(signing_gauges(), gauges((0, 1), &[], below, MIN_STAKE - 1, MIN_STAKE));
    step(&mut app, None).await;
    let stale = &["stale_snapshot"];
    assert_eq!(signing_gauges(), gauges((1, 1), below, stale, 0, MIN_STAKE));
    step(&mut app, Some(snapshot(h + 4, 6_000, &members))).await;
    let expected = gauges((1, 0), stale, &[], 6_000, MIN_STAKE);
    assert_eq!(signing_gauges(), expected);

    drop(app);
    for set in ["next", "after"] {
        AbciMetrics::signing_source().with_label_values(&[set]).set(-1);
        for reason in FallbackReason::ALL {
            AbciMetrics::fallback_reason().with_label_values(&[set, reason.label()]).set(1);
        }
    }
    AbciMetrics::candidate_total_stake().set(-1.0);
    AbciMetrics::min_total_stake().set(-1.0);
    let _app = fx.app(dir.path());
    assert_eq!(signing_gauges(), expected, "the restarted app publishes its store's sets");
}

#[tokio::test]
async fn refusals_count_by_reason_and_raise_halted() {
    if !in_own_process(module_path!(), "refusals_count_by_reason_and_raise_halted") {
        return;
    }
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let placeholders = AbciMetrics::proposals_placeholder().get();
    let placeholder_proposals = rejected("placeholder_proposal");
    let processed = AbciMetrics::process_seconds().get_sample_count();

    app.l1().state().fail = Some(L1Error::Rpc("down".into()));
    let req = prepare_req(next_height(&app), bft_time(&app));
    assert!(prepare(&mut app, req).await.is_empty());
    assert_eq!(AbciMetrics::proposals_placeholder().get(), placeholders + 1);
    assert_eq!(AbciMetrics::halted().get(), 1);

    let req = process_req(&app, next_height(&app), bft_time(&app), vec![]);
    assert_eq!(process(&mut app, req).await, response::ProcessProposal::Reject);
    assert_eq!(rejected("placeholder_proposal"), placeholder_proposals + 1);
    assert_eq!(AbciMetrics::process_seconds().get_sample_count(), processed + 1);
    assert_eq!(AbciMetrics::halted().get(), 1);

    // The next accepted proposal clears the halt.
    app.l1().state().fail = None;
    let env = propose(&mut app).await;
    assert_eq!(AbciMetrics::halted().get(), 0);
    assert_eq!(judge(&mut app, &env).await.0, response::ProcessProposal::Accept);
    assert_eq!(AbciMetrics::halted().get(), 0);
}

/// CONS-3.4-16: a finalized anchor whose checkpoint conflicts with the local chain is counted
/// as a refusal of the proposer's build and of the validator's proposal alike; it is no longer
/// a fallback to the parent anchor.
#[tokio::test]
async fn checkpoint_conflicts_count_as_refusals_not_fallbacks() {
    if !in_own_process(module_path!(), "checkpoint_conflicts_count_as_refusals_not_fallbacks") {
        return;
    }
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let inbox = fx.inbox_at_checkpoint(3, alloy_primitives::B256::repeat_byte(0xc4));
    fx.advance_l1(app.l1(), 66, &inbox);
    let fallbacks =
        || AbciMetrics::proposal_fallbacks().with_label_values(&["checkpoint_conflict"]).get();
    let (fallen_back, conflicts) = (fallbacks(), rejected("checkpoint_conflict"));
    let placeholders = AbciMetrics::proposals_placeholder().get();

    let req = super::proposal::prepare_req(super::proposal::next_height(&app), bft_time(&app));
    assert!(super::proposal::prepare(&mut app, req).await.is_empty(), "nothing is proposed");
    assert_eq!(AbciMetrics::proposals_placeholder().get(), placeholders + 1);
    assert_eq!(fallbacks(), fallen_back);

    let env = super::proposal::hand_envelope(&app, Some(fx.anchor_witness(app.l1(), 66)));
    assert_eq!(judge(&mut app, &env).await.0, response::ProcessProposal::Reject);
    assert_eq!(rejected("checkpoint_conflict"), conflicts + 1);
    assert_eq!(AbciMetrics::halted().get(), 1);
}
