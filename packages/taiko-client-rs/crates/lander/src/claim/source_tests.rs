use super::*;
use crate as claim_library;
#[path = "../../tests/support/claim_rpc.rs"]
mod fixture;
use fixture::*;
use std::sync::Arc;

#[test]
fn real_mpt_proof_binds_fixed_inbox_slot_and_every_reward_field() {
    let id = identity();
    let r = receipt();
    let slot = rewards::receipt_slot(id.batch_id);
    let (root, w) = witness(&values(), &[slot]);
    verify_receipt(&id, &r, root, &w).unwrap();
    for case in 0..5 {
        let mut bad = w.clone();
        let mut forged = r.clone();
        match case {
            0 => bad.address = Address::repeat_byte(99),
            1 => bad.account_proof.clear(),
            2 => bad.storage[0].slot = B256::repeat_byte(3),
            3 => forged.baseFeeAmount += U256::from(1),
            _ => forged.l2RewardRecipient = Address::repeat_byte(33),
        }
        assert!(verify_receipt(&id, &forged, root, &bad).is_err(), "case {case}");
    }
    assert!(verify_receipt(&id, &r, B256::repeat_byte(9), &w).is_err());
}

#[tokio::test]
async fn prepare_authenticates_real_proof_at_canonical_h_without_checkpoint_covering_h() {
    let fixture = Arc::new(Fixture::new(Fault::None));
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    let source = source.unwrap();
    let proof = source.prepare(identity().landing_tx, identity().batch_id).await.unwrap();
    assert_eq!(proof.receipt, receipt());
    assert_eq!(proof.anchor_timestamp, 1001);
    assert_ne!(
        proof.receipt.generation, 9,
        "historical receipts survive recovery generation changes"
    );
}

#[tokio::test]
async fn source_rejects_forged_events_nonfinal_roots_wrong_slots_empty_proofs_and_reorgs() {
    for fault in [
        Fault::FakeEvent,
        Fault::WrongInbox,
        Fault::EmptyAccount,
        Fault::WrongSlot,
        Fault::Nonfinal,
        Fault::Roots,
        Fault::Reorg,
    ] {
        let (source, _l1, _l2) = connect(Arc::new(Fixture::new(fault))).await;
        if let Ok(source) = source {
            assert!(source.prepare(identity().landing_tx, identity().batch_id).await.is_err());
        }
    }
}

#[tokio::test]
async fn bootstrap_rejects_unsupported_chain_zero_inbox_and_sanitizes_rpc_credentials() {
    for fault in [Fault::WrongChain, Fault::ZeroInbox, Fault::RpcLeak] {
        let (source, _l1, _l2) = connect(Arc::new(Fixture::new(fault))).await;
        let error = source.err().expect("invalid RPC configuration must stop").to_string();
        assert!(!error.contains("secret-"), "{error}");
    }
}

#[tokio::test]
async fn overwritten_ring_entry_retries_with_newer_finalized_root_for_same_historical_receipt() {
    let (expired, _l1, _l2) = connect(Arc::new(Fixture::new(Fault::Roots))).await;
    assert!(expired.unwrap().prepare(identity().landing_tx, identity().batch_id).await.is_err());
    let newer = Arc::new(Fixture::new(Fault::NewAnchor));
    assert_ne!(newer.l1[&10].state_root, newer.l1[&11].state_root);
    let (source, _l1, _l2) = connect(newer).await;
    let proof = source.unwrap().prepare(identity().landing_tx, identity().batch_id).await.unwrap();
    assert_eq!(proof.anchor_timestamp, 9192);
    assert_eq!(proof.receipt, receipt());
}

#[tokio::test]
async fn permissionless_forwarded_landing_uses_fixed_inbox_emitter_and_storage_proof() {
    let (source, _l1, _l2) = connect(Arc::new(Fixture::new(Fault::ForwardedLanding))).await;
    let proof = source.unwrap().prepare(identity().landing_tx, identity().batch_id).await.unwrap();
    assert_eq!(proof.receipt, receipt());
}

#[tokio::test]
async fn landing_newer_than_executed_anchor_is_retryable_before_proof_then_advances() {
    let fixture = Arc::new(Fixture::new(Fault::PendingAnchor));
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    let source = source.unwrap();
    let result = source.prepare(identity().landing_tx, identity().batch_id).await;
    assert!(matches!(result, Err(LanderError::Unavailable(_))));
    assert!(!fixture.requests.lock().unwrap().iter().any(|r| r["method"] == "eth_getProof"));
    fixture.pending_anchor.store(false, std::sync::atomic::Ordering::SeqCst);
    source.prepare(identity().landing_tx, identity().batch_id).await.unwrap();
}
