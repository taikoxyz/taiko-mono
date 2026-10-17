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
    let fixture = Arc::new(Fixture::new(Fault::None, false));
    assert!(!fixture.checkpoint);
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    let source = source.unwrap();
    let proof = source.prepare(identity().landing_tx, identity().batch_id).await.unwrap();
    assert_eq!(proof.receipt, receipt());
    assert_eq!(proof.anchor_timestamp, 1001);
    assert_ne!(
        proof.receipt.generation, 9,
        "historical receipts survive recovery generation changes"
    );
    let inclusion = LandingReceipt {
        transaction_hash: B256::repeat_byte(1),
        block_number: 8,
        block_hash: fixture.l2[&8].hash_slow(),
        success: true,
        gas_used: 1,
    };
    assert!(!source.transaction_finalized(&inclusion, &mut None).await.unwrap());
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
        let (source, _l1, _l2) = connect(Arc::new(Fixture::new(fault, false))).await;
        if let Ok(source) = source {
            assert!(source.prepare(identity().landing_tx, identity().batch_id).await.is_err());
        }
    }
}

#[tokio::test]
async fn finality_requires_proven_checkpoint_and_every_el_parent_link() {
    for fault in [Fault::None, Fault::Ancestry, Fault::EmptyAccount] {
        let fixture = Arc::new(Fixture::new(fault, true));
        let hash = fixture.l2[&8].hash_slow();
        let (source, _l1, _l2) = connect(fixture).await;
        let inclusion = LandingReceipt {
            transaction_hash: B256::repeat_byte(1),
            block_number: 8,
            block_hash: hash,
            success: true,
            gas_used: 1,
        };
        let result = source.unwrap().transaction_finalized(&inclusion, &mut None).await;
        if matches!(fault, Fault::None) {
            assert!(result.unwrap());
        } else {
            assert!(result.is_err());
        }
    }
}

#[tokio::test]
async fn bootstrap_rejects_unsupported_chain_zero_inbox_and_sanitizes_rpc_credentials() {
    for fault in [Fault::WrongChain, Fault::ZeroInbox, Fault::RpcLeak] {
        let (source, _l1, _l2) = connect(Arc::new(Fixture::new(fault, false))).await;
        let error = source.err().expect("invalid RPC configuration must stop").to_string();
        assert!(!error.contains("secret-"), "{error}");
    }
}

#[tokio::test]
async fn overwritten_ring_entry_retries_with_newer_finalized_root_for_same_historical_receipt() {
    let (expired, _l1, _l2) = connect(Arc::new(Fixture::new(Fault::Roots, false))).await;
    assert!(expired.unwrap().prepare(identity().landing_tx, identity().batch_id).await.is_err());
    let newer = Arc::new(Fixture::new(Fault::NewAnchor, false));
    assert_ne!(newer.l1[&10].state_root, newer.l1[&11].state_root);
    let (source, _l1, _l2) = connect(newer).await;
    let proof = source.unwrap().prepare(identity().landing_tx, identity().batch_id).await.unwrap();
    assert_eq!(proof.anchor_timestamp, 9192);
    assert_eq!(proof.receipt, receipt());
}

#[tokio::test]
async fn permissionless_forwarded_landing_uses_fixed_inbox_emitter_and_storage_proof() {
    let (source, _l1, _l2) = connect(Arc::new(Fixture::new(Fault::ForwardedLanding, false))).await;
    let proof = source.unwrap().prepare(identity().landing_tx, identity().batch_id).await.unwrap();
    assert_eq!(proof.receipt, receipt());
}

#[tokio::test]
async fn landing_newer_than_executed_anchor_is_retryable_before_proof_then_advances() {
    let fixture = Arc::new(Fixture::new(Fault::PendingAnchor, false));
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    let source = source.unwrap();
    let result = source.prepare(identity().landing_tx, identity().batch_id).await;
    assert!(matches!(result, Err(LanderError::Unavailable(_))));
    assert!(!fixture.requests.lock().unwrap().iter().any(|r| r["method"] == "eth_getProof"));
    fixture.pending_anchor.store(false, std::sync::atomic::Ordering::SeqCst);
    source.prepare(identity().landing_tx, identity().batch_id).await.unwrap();
}

fn inclusion(fixture: &Fixture) -> LandingReceipt {
    LandingReceipt {
        transaction_hash: B256::repeat_byte(1),
        block_number: 8,
        block_hash: fixture.l2[&8].hash_slow(),
        success: true,
        gas_used: 1,
    }
}

#[tokio::test]
async fn old_claim_uses_nearby_historical_landing_despite_distant_checkpoint_or_recovery_reset() {
    for fault in [Fault::FarCheckpoint, Fault::WrongBranch] {
        let fixture = Arc::new(Fixture::new(fault, true));
        let receipt = inclusion(&fixture);
        let (source, _l1, _l2) = connect(fixture.clone()).await;
        let source = source.unwrap();
        let mut progress = None;
        if matches!(fault, Fault::WrongBranch) {
            assert!(matches!(
                source.transaction_finalized(&receipt, &mut progress).await,
                Err(LanderError::Unavailable(_))
            ));
        }
        assert!(source.transaction_finalized(&receipt, &mut progress).await.unwrap());
        let requests = fixture.requests.lock().unwrap();
        assert!(requests.iter().filter(|r| r["method"] == "eth_getBlockByHash").count() <= 4);
        assert!(
            !requests
                .iter()
                .any(|r| r["method"] == "eth_getProof" &&
                    r["params"][1].as_array().unwrap().len() > 1)
        );
    }
}

#[tokio::test]
async fn forged_covering_receipt_is_fatal_and_wrong_claim_branch_never_finalizes() {
    let fixture = Arc::new(Fixture::new(Fault::ForgedCovering, true));
    let receipt = inclusion(&fixture);
    let (source, _l1, _l2) = connect(fixture).await;
    assert!(matches!(
        source.unwrap().transaction_finalized(&receipt, &mut None).await,
        Err(LanderError::Safety(_))
    ));
    let mut fixture = Fixture::new(Fault::WrongBranch, true);
    fixture.covering.truncate(1);
    let receipt = inclusion(&fixture);
    let (source, _l1, _l2) = connect(Arc::new(fixture)).await;
    let source = source.unwrap();
    let mut progress = None;
    for _ in 0..3 {
        assert!(matches!(
            source.transaction_finalized(&receipt, &mut progress).await,
            Ok(false) | Err(LanderError::Unavailable(_))
        ));
    }
}

#[tokio::test]
async fn paged_history_progress_survives_restart_and_omitted_logs_are_rescanned() {
    let mut fixture = Fixture::new(Fault::None, true);
    let root = fixture.l1[&11].state_root;
    fixture.covering_block = 20_000;
    fixture.l1.insert(20_000, Header { number: 20_000, state_root: root, ..Default::default() });
    fixture.l1.insert(30_000, Header { number: 30_000, state_root: root, ..Default::default() });
    let fixture = Arc::new(fixture);
    let receipt = inclusion(&fixture);
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    let source = source.unwrap();
    let mut progress = None;
    assert!(!source.transaction_finalized(&receipt, &mut progress).await.unwrap());
    assert_eq!(progress.as_ref().unwrap().next, 9 + 16 * 1024);
    assert_eq!(
        fixture.requests.lock().unwrap().iter().filter(|r| r["method"] == "eth_getLogs").count(),
        16
    );
    // Serialize exactly the untrusted hint that a journal restart would retain.
    progress = serde_json::from_slice(&serde_json::to_vec(&progress).unwrap()).unwrap();
    fixture.hide_logs.store(true, std::sync::atomic::Ordering::SeqCst);
    assert!(!source.transaction_finalized(&receipt, &mut progress).await.unwrap());
    assert_eq!(progress.as_ref().unwrap().next, 9);
    fixture.hide_logs.store(false, std::sync::atomic::Ordering::SeqCst);
    assert!(!source.transaction_finalized(&receipt, &mut progress).await.unwrap());
    assert!(source.transaction_finalized(&receipt, &mut progress).await.unwrap());
    // A corrupt inclusion binding restarts hints, never grants authority.
    progress.as_mut().unwrap().inclusion_hash = B256::ZERO;
    assert!(!source.transaction_finalized(&receipt, &mut progress).await.unwrap());
    assert_eq!(progress.unwrap().next, 9 + 16 * 1024);
}

#[tokio::test]
async fn finality_timeout_preserves_candidate_hint_but_requires_fresh_proof_on_retry() {
    let fixture = Arc::new(Fixture::new(Fault::None, true));
    let receipt = inclusion(&fixture);
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    let source = source.unwrap().with_finality_timeout(Duration::from_secs(1)).unwrap();
    fixture.hang_ancestry.store(true, std::sync::atomic::Ordering::SeqCst);
    let mut progress = None;
    assert!(matches!(
        source.transaction_finalized(&receipt, &mut progress).await,
        Err(LanderError::Temporary(_))
    ));
    assert!(progress.as_ref().unwrap().candidate.is_some());
    let proofs =
        fixture.requests.lock().unwrap().iter().filter(|r| r["method"] == "eth_getProof").count();
    fixture.hang_ancestry.store(false, std::sync::atomic::Ordering::SeqCst);
    assert!(source.transaction_finalized(&receipt, &mut progress).await.unwrap());
    assert_eq!(
        fixture.requests.lock().unwrap().iter().filter(|r| r["method"] == "eth_getProof").count(),
        proofs + 1
    );
}

#[tokio::test]
async fn finality_rejects_forged_witness_slots_and_unfinalized_event_hint() {
    let fixture = Arc::new(Fixture::new(Fault::WrongSlot, true));
    let receipt = inclusion(&fixture);
    let (source, _l1, _l2) = connect(fixture).await;
    assert!(matches!(
        source.unwrap().transaction_finalized(&receipt, &mut None).await,
        Err(LanderError::Safety(_))
    ));
    let fixture = Arc::new(Fixture::new(Fault::Nonfinal, true));
    let receipt = inclusion(&fixture);
    let (source, _l1, _l2) = connect(fixture).await;
    assert!(!source.unwrap().transaction_finalized(&receipt, &mut None).await.unwrap());
}

#[tokio::test]
async fn discovery_and_ancestry_capacity_failures_are_actionable() {
    let mut fixture = Fixture::new(Fault::None, true);
    fixture.covering = vec![fixture.covering[0].clone(); 257];
    let receipt = inclusion(&fixture);
    let (source, _l1, _l2) = connect(Arc::new(fixture)).await;
    assert!(matches!(
        source.unwrap().transaction_finalized(&receipt, &mut None).await,
        Err(LanderError::Capacity(_))
    ));
    let mut fixture = Fixture::new(Fault::None, true);
    fixture.covering[0].lastHeight = 8 + MAX_ANCESTRY;
    let candidate = &fixture.covering[0];
    fixture.final_values.insert(
        rewards::receipt_slot(rewards::batch_id(candidate)),
        U256::from_be_bytes(rewards::commitment(candidate).0),
    );
    let (root, _) =
        witness(&fixture.final_values, &[rewards::receipt_slot(rewards::batch_id(candidate))]);
    fixture.l1.get_mut(&11).unwrap().state_root = root;
    let receipt = inclusion(&fixture);
    let fixture = Arc::new(fixture);
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    assert!(matches!(
        source.unwrap().transaction_finalized(&receipt, &mut None).await,
        Err(LanderError::Capacity(_))
    ));
    assert!(!fixture.requests.lock().unwrap().iter().any(|r| r["method"] == "eth_getBlockByHash"));
}

#[tokio::test]
async fn unavailable_old_branch_does_not_starve_later_proven_current_candidate() {
    let mut fixture = Fixture::new(Fault::WrongBranch, true);
    fixture.branch_headers.clear();
    let receipt = inclusion(&fixture);
    let fixture = Arc::new(fixture);
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    let source = source.unwrap();
    let mut progress = None;
    assert!(matches!(
        source.transaction_finalized(&receipt, &mut progress).await,
        Err(LanderError::Unavailable(_))
    ));
    assert!(source.transaction_finalized(&receipt, &mut progress).await.unwrap());
    assert_eq!(
        fixture
            .requests
            .lock()
            .unwrap()
            .iter()
            .filter(|r| r["method"] == "eth_getBlockByHash")
            .count(),
        3
    );
}

#[tokio::test]
async fn second_unavailable_candidate_is_revisited_after_bounded_complete_pass() {
    let mut fixture = Fixture::new(Fault::WrongBranch, true);
    fixture.branch_headers.clear();
    fixture.missing_hashes.lock().unwrap().push(fixture.l2[&9].hash_slow());
    let root = fixture.l1[&11].state_root;
    fixture.l1.insert(30_000, Header { number: 30_000, state_root: root, ..Default::default() });
    let receipt = inclusion(&fixture);
    let fixture = Arc::new(fixture);
    let (source, _l1, _l2) = connect(fixture.clone()).await;
    let source = source.unwrap();
    let mut progress = None;
    for index in 1..=2 {
        assert!(matches!(
            source.transaction_finalized(&receipt, &mut progress).await,
            Err(LanderError::Unavailable(_))
        ));
        assert_eq!(progress.as_ref().unwrap().page.as_ref().unwrap().next_event, index);
    }
    assert!(!source.transaction_finalized(&receipt, &mut progress).await.unwrap());
    assert_eq!(progress.as_ref().unwrap().next, 9 + 16 * 1024);
    assert!(matches!(
        source.transaction_finalized(&receipt, &mut progress).await,
        Err(LanderError::Unavailable(_))
    ));
    assert_eq!(
        progress.as_ref().unwrap().next,
        9,
        "complete pass resets before retained hint retry"
    );
    assert!(progress.as_ref().unwrap().page.is_none());
    fixture.missing_hashes.lock().unwrap().clear();
    assert!(matches!(
        source.transaction_finalized(&receipt, &mut progress).await,
        Err(LanderError::Unavailable(_))
    ));
    assert!(source.transaction_finalized(&receipt, &mut progress).await.unwrap());
}

#[tokio::test]
async fn permanently_slow_retained_candidate_cannot_starve_fast_later_candidate() {
    let mut fixture = Fixture::new(Fault::WrongBranch, true);
    fixture.hash_delay = Duration::from_millis(200);
    fixture
        .slow_hashes
        .lock()
        .unwrap()
        .extend(fixture.branch_headers.iter().map(Header::hash_slow));
    let claim = inclusion(&fixture);
    let fixture = Arc::new(fixture);
    let (source, _l1, _l2) = connect(fixture).await;
    let source = source.unwrap().with_finality_timeout(Duration::from_millis(300)).unwrap();
    let mut progress = None;
    assert!(matches!(
        source.transaction_finalized(&claim, &mut progress).await,
        Err(LanderError::Temporary(_))
    ));
    assert!(progress.as_ref().unwrap().candidate.is_some());
    assert_eq!(
        progress.as_ref().unwrap().page.as_ref().unwrap().next_event,
        1,
        "outer cancellation preserves the next candidate position"
    );
    progress = serde_json::from_slice(&serde_json::to_vec(&progress).unwrap()).unwrap();
    for _ in 0..4 {
        match source.transaction_finalized(&claim, &mut progress).await {
            Ok(true) => return,
            Ok(false) | Err(LanderError::Unavailable(_) | LanderError::Temporary(_)) => {}
            Err(error) => panic!("unexpected error: {error}"),
        }
        progress = serde_json::from_slice(&serde_json::to_vec(&progress).unwrap()).unwrap();
    }
    panic!("permanently slow retained ancestry starved a fully available later endpoint");
}

#[tokio::test]
async fn same_page_slow_prefix_cannot_starve_fast_later_candidate_across_timeouts() {
    let mut fixture = Fixture::new(Fault::None, true);
    fixture.hash_delay = Duration::from_millis(90);
    let actual = fixture.covering.pop().unwrap();
    for index in 0..8 {
        let mut old = actual.clone();
        old.lastBlockHash = B256::repeat_byte(40 + index);
        fixture.slow_hashes.lock().unwrap().push(old.lastBlockHash);
        fixture.final_values.insert(
            rewards::receipt_slot(rewards::batch_id(&old)),
            U256::from_be_bytes(rewards::commitment(&old).0),
        );
        fixture.covering.push(old);
    }
    fixture.covering.push(actual.clone());
    let (root, _) =
        witness(&fixture.final_values, &[rewards::receipt_slot(rewards::batch_id(&actual))]);
    fixture.l1.get_mut(&11).unwrap().state_root = root;
    let claim = inclusion(&fixture);
    let (source, _l1, _l2) = connect(Arc::new(fixture)).await;
    let source = source.unwrap().with_finality_timeout(Duration::from_millis(300)).unwrap();
    let mut progress = None;
    for _ in 0..12 {
        match source.transaction_finalized(&claim, &mut progress).await {
            Ok(true) => return,
            Ok(false) | Err(LanderError::Unavailable(_) | LanderError::Temporary(_)) => {}
            Err(error) => panic!("unexpected error: {error}"),
        }
        progress = serde_json::from_slice(&serde_json::to_vec(&progress).unwrap()).unwrap();
    }
    panic!("same-page prefix was repeated instead of reaching the available endpoint");
}

#[tokio::test]
async fn legitimate_long_candidate_keeps_the_remaining_configured_operation_budget() {
    let mut fixture = Fixture::new(Fault::None, true);
    fixture.hash_delay = Duration::from_millis(300);
    fixture.slow_hashes.lock().unwrap().extend(fixture.l2.values().map(Header::hash_slow));
    let claim = inclusion(&fixture);
    let (source, _l1, _l2) = connect(Arc::new(fixture)).await;
    let source = source.unwrap().with_finality_timeout(Duration::from_secs(1)).unwrap();
    assert!(
        source.transaction_finalized(&claim, &mut None).await.unwrap(),
        "a legitimate 600ms ancestry must not be cut to a fraction of the 1s budget"
    );
}

#[tokio::test]
async fn legacy_or_changed_page_context_restarts_untrusted_position_without_losing_intent() {
    for legacy in [true, false] {
        let fixture = Arc::new(Fixture::new(Fault::WrongBranch, true));
        let claim = inclusion(&fixture);
        let (source, _l1, _l2) = connect(fixture).await;
        let source = source.unwrap();
        let mut progress = None;
        assert!(matches!(
            source.transaction_finalized(&claim, &mut progress).await,
            Err(LanderError::Unavailable(_))
        ));
        assert_eq!(progress.as_ref().unwrap().page.as_ref().unwrap().next_event, 1);
        let mut value = serde_json::to_value(&progress).unwrap();
        if legacy {
            value.as_object_mut().unwrap().remove("page");
        } else {
            value["page"]["digest"] = serde_json::to_value(B256::ZERO).unwrap();
        }
        progress = serde_json::from_value(value).unwrap();
        assert!(matches!(
            source.transaction_finalized(&claim, &mut progress).await,
            Err(LanderError::Unavailable(_))
        ));
        assert_eq!(progress.as_ref().unwrap().page.as_ref().unwrap().next_event, 1);
        assert!(source.transaction_finalized(&claim, &mut progress).await.unwrap());
    }
}
