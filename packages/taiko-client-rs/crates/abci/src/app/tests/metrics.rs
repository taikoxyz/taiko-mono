//! The app's Prometheus metrics (spec §8.3). The collectors are process-wide, so every test
//! runs alone in its process ([`in_own_process`]) and the exact values below hold.

use super::{
    proposal::{
        bft_time, decide, judge, mid_epoch, next_height, prepare, prepare_req, process,
        process_req, propose,
    },
    *,
};
use crate::{l1::L1Error, metrics::AbciMetrics, test_utils::in_own_process};

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
    assert_eq!(AbciMetrics::epoch().get(), 0);
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
    assert_eq!(AbciMetrics::epoch().get(), i64::try_from(status.epoch).unwrap());
    assert_eq!(AbciMetrics::generation().get(), i64::try_from(status.generation).unwrap());
    assert_eq!(
        AbciMetrics::unsettled_depth().get(),
        i64::try_from(status.head - status.last_checkpoint_height).unwrap()
    );
    assert_eq!(AbciMetrics::halted().get(), 0);
}

#[tokio::test]
async fn refusals_count_by_reason_and_raise_halted() {
    if !in_own_process(module_path!(), "refusals_count_by_reason_and_raise_halted") {
        return;
    }
    let fx = Fixture::genesis(1);
    let dir = tempfile::tempdir().unwrap();
    let mut app = mid_epoch(&fx, dir.path(), 5).await;
    let empty = AbciMetrics::proposals_empty().get();
    let empty_proposals = rejected("empty_proposal");
    let processed = AbciMetrics::process_seconds().get_sample_count();

    app.l1().state().fail = Some(L1Error::Rpc("down".into()));
    let req = prepare_req(next_height(&app), bft_time(&app));
    assert!(prepare(&mut app, req).await.is_empty());
    assert_eq!(AbciMetrics::proposals_empty().get(), empty + 1);
    assert_eq!(AbciMetrics::halted().get(), 1);

    let req = process_req(next_height(&app), bft_time(&app), vec![]);
    assert_eq!(process(&mut app, req).await, response::ProcessProposal::Reject);
    assert_eq!(rejected("empty_proposal"), empty_proposals + 1);
    assert_eq!(AbciMetrics::process_seconds().get_sample_count(), processed + 1);
    assert_eq!(AbciMetrics::halted().get(), 1);

    // The next accepted proposal clears the halt.
    app.l1().state().fail = None;
    let env = propose(&mut app).await;
    assert_eq!(AbciMetrics::halted().get(), 0);
    assert_eq!(judge(&mut app, &env).await.0, response::ProcessProposal::Accept);
    assert_eq!(AbciMetrics::halted().get(), 0);
}
