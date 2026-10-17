use super::*;
use crate::{
    claim::{
        runner::{ClaimOutcome, step},
        source::ClaimSource,
        store::{ClaimJob, ClaimState, ClaimStore},
        tx::{ClaimTransport, SignedClaim},
    },
    tx::{LandingReceipt, NonceState},
};
use async_trait::async_trait;
use std::{
    sync::{
        Mutex,
        atomic::{AtomicUsize, Ordering},
    },
    time::Duration,
};

struct Chain {
    claimed: Mutex<bool>,
    receipt: Mutex<Option<LandingReceipt>>,
    canonical: Mutex<B256>,
    finalized: Mutex<bool>,
    nonce: Mutex<NonceState>,
    known: Mutex<bool>,
    broadcast_fails: Mutex<bool>,
    broadcast_hangs: Mutex<bool>,
    sends: Mutex<Vec<Bytes>>,
    prepares: AtomicUsize,
    directory: std::path::PathBuf,
    observations: Mutex<Vec<&'static str>>,
    snapshots: Mutex<std::collections::VecDeque<u64>>,
    nonces: Mutex<std::collections::VecDeque<NonceState>>,
    bits: Mutex<std::collections::VecDeque<bool>>,
    mine_after_nonce: std::sync::atomic::AtomicBool,
    mine_after_receipt: std::sync::atomic::AtomicBool,
    mined_receipt: Mutex<Option<LandingReceipt>>,
    reorg_on_bit: std::sync::atomic::AtomicBool,
    finality_delay: Mutex<Duration>,
    sign_error: Mutex<Option<LanderError>>,
}
impl Chain {
    fn new(path: &std::path::Path) -> Self {
        Self {
            claimed: Mutex::new(false),
            receipt: Mutex::new(None),
            canonical: Mutex::new(B256::repeat_byte(12)),
            finalized: Mutex::new(false),
            nonce: Mutex::new(NonceState { confirmed: 3, pending: 3 }),
            known: Mutex::new(false),
            broadcast_fails: Mutex::new(false),
            broadcast_hangs: Mutex::new(false),
            sends: Mutex::new(vec![]),
            prepares: AtomicUsize::new(0),
            directory: path.to_owned(),
            observations: Mutex::new(vec![]),
            snapshots: Mutex::new(Default::default()),
            nonces: Mutex::new(Default::default()),
            bits: Mutex::new(Default::default()),
            mine_after_nonce: std::sync::atomic::AtomicBool::new(false),
            mine_after_receipt: std::sync::atomic::AtomicBool::new(false),
            reorg_on_bit: std::sync::atomic::AtomicBool::new(false),
            mined_receipt: Mutex::new(None),
            finality_delay: Mutex::new(Duration::ZERO),
            sign_error: Mutex::new(None),
        }
    }
}
#[async_trait]
impl ClaimSource for Chain {
    async fn prepare(&self, _: B256, _: B256) -> Result<ClaimProof> {
        self.prepares.fetch_add(1, Ordering::SeqCst);
        Ok(proof())
    }
    async fn claimed(&self, _: B256) -> Result<bool> {
        Ok(*self.claimed.lock().unwrap())
    }
    async fn snapshot(&self) -> Result<crate::claim::source::ExecutionSnapshot> {
        self.observations.lock().unwrap().push("snapshot");
        Ok(crate::claim::source::ExecutionSnapshot {
            number: self.snapshots.lock().unwrap().pop_front().unwrap_or(9),
            hash: *self.canonical.lock().unwrap(),
        })
    }
    async fn claimed_at(&self, batch: B256, _: B256) -> Result<bool> {
        self.observations.lock().unwrap().push("claimed");
        if self.reorg_on_bit.swap(false, Ordering::SeqCst) {
            *self.canonical.lock().unwrap() = B256::repeat_byte(13);
        }
        let bit = self.bits.lock().unwrap().pop_front();
        match bit {
            Some(bit) => Ok(bit),
            None => self.claimed(batch).await,
        }
    }
    async fn canonical_hash(&self, _: u64) -> Result<B256> {
        Ok(*self.canonical.lock().unwrap())
    }
    async fn transaction_finalized(
        &self,
        _: &LandingReceipt,
        _: &mut Option<crate::claim::discovery::DiscoveryProgress>,
    ) -> Result<bool> {
        let delay = *self.finality_delay.lock().unwrap();
        tokio::time::sleep(delay).await;
        Ok(*self.finalized.lock().unwrap())
    }
}
#[async_trait]
impl ClaimTransport for Chain {
    async fn sign(&self, id: &ClaimIdentity, p: &ClaimProof) -> Result<SignedClaim> {
        if let Some(error) = self.sign_error.lock().unwrap().take() {
            return Err(error);
        }
        Ok(signed(id, p).await)
    }
    async fn broadcast(&self, tx: &SignedClaim) -> Result<()> {
        let record: serde_json::Value = serde_json::from_slice(
            &std::fs::read(self.directory.join("claim-state.json")).unwrap(),
        )
        .unwrap();
        assert_eq!(record["job"]["state"], "Pending", "broadcast intent must already be durable");
        let stored: Bytes =
            serde_json::from_value(record["job"]["transaction"]["bytes"].clone()).unwrap();
        assert_eq!(stored, tx.bytes, "signed bytes must already be durable");
        self.sends.lock().unwrap().push(tx.bytes.clone());
        let hangs = *self.broadcast_hangs.lock().unwrap();
        if hangs {
            std::future::pending::<()>().await;
        }
        if *self.broadcast_fails.lock().unwrap() {
            return Err(LanderError::Temporary("unknown send outcome".into()));
        }
        Ok(())
    }
    async fn receipt(&self, _: B256) -> Result<Option<LandingReceipt>> {
        self.observations.lock().unwrap().push("receipt");
        let result = *self.receipt.lock().unwrap();
        if self.mine_after_receipt.swap(false, Ordering::SeqCst) {
            *self.receipt.lock().unwrap() = *self.mined_receipt.lock().unwrap();
            *self.claimed.lock().unwrap() = true;
            *self.nonce.lock().unwrap() = NonceState { confirmed: 4, pending: 4 };
        }
        Ok(result)
    }
    async fn known(&self, _: B256) -> Result<bool> {
        Ok(*self.known.lock().unwrap())
    }
    async fn nonce_at(&self, _: B256) -> Result<NonceState> {
        self.observations.lock().unwrap().push("nonce");
        let result = self.nonce().await?;
        if self.mine_after_nonce.swap(false, Ordering::SeqCst) {
            *self.receipt.lock().unwrap() = *self.mined_receipt.lock().unwrap();
            *self.claimed.lock().unwrap() = true;
        }
        Ok(result)
    }
    async fn nonce(&self) -> Result<NonceState> {
        Ok(self.nonces.lock().unwrap().pop_front().unwrap_or(*self.nonce.lock().unwrap()))
    }
}
fn store(dir: &std::path::Path) -> ClaimStore {
    let mut id = identity();
    id.payer = signer().address();
    ClaimStore::open(dir, id).unwrap()
}
const DEADLINE: Duration = Duration::from_secs(1);

#[tokio::test]
async fn unknown_send_restart_replays_same_bytes_without_fresh_proof_or_nonce() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    *chain.broadcast_fails.lock().unwrap() = true;
    let s = store(dir.path());
    assert!(step(&s, &chain, &chain, DEADLINE).await.is_err());
    let original = s.load().unwrap().unwrap();
    assert_eq!(original.state, ClaimState::Pending);
    drop(s);
    *chain.broadcast_fails.lock().unwrap() = false;
    let s = store(dir.path());
    assert_eq!(
        step(&s, &chain, &chain, DEADLINE).await.unwrap(),
        ClaimOutcome::State(ClaimState::Pending)
    );
    assert_eq!(chain.prepares.load(Ordering::SeqCst), 1);
    assert_eq!(chain.sends.lock().unwrap().len(), 2);
    {
        let sends = chain.sends.lock().unwrap();
        assert_eq!(sends[0], sends[1]);
    }
    assert_eq!(s.load().unwrap().unwrap().transaction, original.transaction);
}

#[tokio::test]
async fn reorg_retains_signed_bytes_then_finality_requires_checkpoint_verdict() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    let tx = s.load().unwrap().unwrap().transaction.unwrap();
    let receipt = LandingReceipt {
        transaction_hash: tx.hash,
        block_number: 8,
        block_hash: B256::repeat_byte(12),
        success: true,
        gas_used: 50000,
    };
    *chain.claimed.lock().unwrap() = true;
    *chain.receipt.lock().unwrap() = Some(receipt);
    assert_eq!(
        step(&s, &chain, &chain, DEADLINE).await.unwrap(),
        ClaimOutcome::State(ClaimState::Included)
    );
    *chain.canonical.lock().unwrap() = B256::repeat_byte(13);
    *chain.claimed.lock().unwrap() = false;
    assert_eq!(
        step(&s, &chain, &chain, DEADLINE).await.unwrap(),
        ClaimOutcome::State(ClaimState::Pending)
    );
    assert_eq!(s.load().unwrap().unwrap().transaction, Some(tx.clone()));
    assert_eq!(chain.prepares.load(Ordering::SeqCst), 1);
    *chain.canonical.lock().unwrap() = receipt.block_hash;
    *chain.claimed.lock().unwrap() = true;
    *chain.finalized.lock().unwrap() = true;
    assert_eq!(
        step(&s, &chain, &chain, DEADLINE).await.unwrap(),
        ClaimOutcome::State(ClaimState::Finalized)
    );
    assert_eq!(s.load().unwrap().unwrap().transaction, Some(tx));
    drop(s);
    let s = store(dir.path());
    let disk = std::fs::read(dir.path().join("claim-state.json")).unwrap();
    let requests = chain.observations.lock().unwrap().len();
    *chain.receipt.lock().unwrap() = None;
    *chain.claimed.lock().unwrap() = false;
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    assert_eq!(s.load().unwrap().unwrap().state, ClaimState::Finalized);
    assert_eq!(chain.observations.lock().unwrap().len(), requests);
    assert_eq!(std::fs::read(dir.path().join("claim-state.json")).unwrap(), disk);
}

#[tokio::test]
async fn consumed_nonce_stops_and_pending_or_known_transaction_waits() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    for state in [NonceState { confirmed: 4, pending: 4 }, NonceState { confirmed: 3, pending: 2 }]
    {
        *chain.nonce.lock().unwrap() = state;
        assert!(step(&s, &chain, &chain, DEADLINE).await.is_err());
    }
    *chain.nonce.lock().unwrap() = NonceState { confirmed: 3, pending: 4 };
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    *chain.nonce.lock().unwrap() = NonceState { confirmed: 3, pending: 3 };
    *chain.known.lock().unwrap() = true;
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    assert_eq!(chain.sends.lock().unwrap().len(), 1);
    assert_eq!(chain.prepares.load(Ordering::SeqCst), 1);
}

#[tokio::test]
async fn already_claimed_never_signs_and_unsigned_prepared_can_refresh_expired_roots() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    *chain.claimed.lock().unwrap() = true;
    assert_eq!(step(&s, &chain, &chain, DEADLINE).await.unwrap(), ClaimOutcome::AlreadyClaimed);
    assert!(s.load().unwrap().is_none());
    assert_eq!(chain.prepares.load(Ordering::SeqCst), 0);
    *chain.claimed.lock().unwrap() = false;
    let mut old = proof();
    old.anchor_timestamp = 1;
    s.save(&ClaimJob {
        state: ClaimState::Prepared,
        proof: old,
        transaction: None,
        inclusion: None,
        discovery: None,
    })
    .unwrap();
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    assert_eq!(s.load().unwrap().unwrap().proof.anchor_timestamp, 123);
}

#[tokio::test]
async fn actual_broadcast_deadline_retains_pending_bytes_for_identical_replay() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    *chain.broadcast_hangs.lock().unwrap() = true;
    assert!(step(&s, &chain, &chain, Duration::from_millis(100)).await.is_err());
    let job = s.load().unwrap().unwrap();
    assert_eq!(job.state, ClaimState::Pending);
    *chain.broadcast_hangs.lock().unwrap() = false;
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    assert_eq!(s.load().unwrap().unwrap().transaction, job.transaction);
    assert_eq!(chain.prepares.load(Ordering::SeqCst), 1);
    let sends = chain.sends.lock().unwrap();
    assert_eq!(sends.len(), 2);
    assert_eq!(sends[0], sends[1]);
}

#[tokio::test]
async fn reverted_receipt_and_claimed_without_matching_receipt_stop_without_replacement() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    let tx = s.load().unwrap().unwrap().transaction.unwrap();
    *chain.receipt.lock().unwrap() = Some(LandingReceipt {
        transaction_hash: tx.hash,
        block_number: 8,
        block_hash: B256::repeat_byte(12),
        success: false,
        gas_used: 1,
    });
    assert!(step(&s, &chain, &chain, DEADLINE).await.is_err());
    *chain.receipt.lock().unwrap() = None;
    *chain.claimed.lock().unwrap() = true;
    assert_eq!(step(&s, &chain, &chain, DEADLINE).await.unwrap(), ClaimOutcome::AlreadyClaimed);
    assert_eq!(chain.sends.lock().unwrap().len(), 1);
    assert_eq!(s.load().unwrap().unwrap().transaction, Some(tx));
}

async fn pending_job(s: &ClaimStore, chain: &Chain) -> LandingReceipt {
    step(s, chain, chain, DEADLINE).await.unwrap();
    let tx = s.load().unwrap().unwrap().transaction.unwrap();
    let r = LandingReceipt {
        transaction_hash: tx.hash,
        block_number: 8,
        block_hash: B256::repeat_byte(12),
        success: true,
        gas_used: 1,
    };
    *chain.mined_receipt.lock().unwrap() = Some(r);
    chain.observations.lock().unwrap().clear();
    r
}

#[tokio::test]
async fn mining_after_nonce_or_missing_receipt_refreshes_one_coherent_view() {
    for after_nonce in [true, false] {
        let dir = tempfile::tempdir().unwrap();
        let chain = Chain::new(dir.path());
        let s = store(dir.path());
        pending_job(&s, &chain).await;
        if after_nonce {
            chain.snapshots.lock().unwrap().extend([7, 9]);
            chain.mine_after_nonce.store(true, Ordering::SeqCst);
        } else {
            chain.mine_after_receipt.store(true, Ordering::SeqCst);
        }
        assert_eq!(
            step(&s, &chain, &chain, DEADLINE).await.unwrap(),
            ClaimOutcome::State(ClaimState::Included)
        );
        let calls = chain.observations.lock().unwrap();
        assert_eq!(&calls[..3], &["snapshot", "nonce", "receipt"]);
        assert_eq!(calls.iter().filter(|&&c| c == "snapshot").count(), 2);
        assert_eq!(chain.sends.lock().unwrap().len(), 1);
    }
}

#[tokio::test]
async fn transient_nonce_disagreement_refreshes_once_and_stable_conflict_stops() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    pending_job(&s, &chain).await;
    chain.nonces.lock().unwrap().push_back(NonceState { confirmed: 4, pending: 3 });
    assert_eq!(
        step(&s, &chain, &chain, DEADLINE).await.unwrap(),
        ClaimOutcome::State(ClaimState::Pending)
    );
    assert_eq!(chain.observations.lock().unwrap().iter().filter(|&&c| c == "snapshot").count(), 2);
    chain.observations.lock().unwrap().clear();
    *chain.nonce.lock().unwrap() = NonceState { confirmed: 4, pending: 4 };
    assert!(matches!(step(&s, &chain, &chain, DEADLINE).await, Err(LanderError::Safety(_))));
    assert_eq!(chain.observations.lock().unwrap().iter().filter(|&&c| c == "snapshot").count(), 2);
}

#[tokio::test]
async fn successful_receipt_false_bit_retries_once_but_stable_contradiction_is_safety() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    let r = pending_job(&s, &chain).await;
    *chain.receipt.lock().unwrap() = Some(r);
    chain.bits.lock().unwrap().extend([false, true]);
    assert_eq!(
        step(&s, &chain, &chain, DEADLINE).await.unwrap(),
        ClaimOutcome::State(ClaimState::Included)
    );
    assert!(matches!(step(&s, &chain, &chain, DEADLINE).await, Err(LanderError::Safety(_))));
}

#[tokio::test]
async fn changed_canonical_snapshot_retries_and_preserves_signed_intent() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    pending_job(&s, &chain).await;
    let original = s.load().unwrap().unwrap().transaction;
    chain.reorg_on_bit.store(true, Ordering::SeqCst);
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    assert_eq!(chain.observations.lock().unwrap().iter().filter(|&&c| c == "snapshot").count(), 2);
    assert_eq!(s.load().unwrap().unwrap().transaction, original);
}

#[tokio::test]
async fn finality_budget_is_not_truncated_by_ordinary_rpc_step_deadline() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    let r = pending_job(&s, &chain).await;
    *chain.receipt.lock().unwrap() = Some(r);
    *chain.claimed.lock().unwrap() = true;
    *chain.finalized.lock().unwrap() = true;
    *chain.finality_delay.lock().unwrap() = Duration::from_millis(300);
    assert_eq!(
        step(&s, &chain, &chain, Duration::from_millis(200)).await.unwrap(),
        ClaimOutcome::State(ClaimState::Finalized)
    );
}

#[tokio::test]
async fn third_party_payout_with_own_revert_or_missing_receipt_retains_journal_and_stops_sends() {
    for reverted in [true, false] {
        let dir = tempfile::tempdir().unwrap();
        let chain = Chain::new(dir.path());
        let s = store(dir.path());
        let mut r = pending_job(&s, &chain).await;
        let bytes = std::fs::read(dir.path().join("claim-state.json")).unwrap();
        r.success = false;
        *chain.receipt.lock().unwrap() = reverted.then_some(r);
        *chain.claimed.lock().unwrap() = true;
        assert_eq!(step(&s, &chain, &chain, DEADLINE).await.unwrap(), ClaimOutcome::AlreadyClaimed);
        assert_eq!(std::fs::read(dir.path().join("claim-state.json")).unwrap(), bytes);
        assert_eq!(chain.sends.lock().unwrap().len(), 1);
    }
}

#[tokio::test]
async fn already_claimed_selector_without_canonical_bit_cannot_authorize_success() {
    let dir = tempfile::tempdir().unwrap();
    let chain = Chain::new(dir.path());
    let s = store(dir.path());
    *chain.sign_error.lock().unwrap() =
        Some(LanderError::ClaimReverted(crate::claim::tx::VaultFailure::AlreadyClaimed));
    assert!(matches!(step(&s, &chain, &chain, DEADLINE).await, Err(LanderError::ClaimReverted(_))));
    assert_eq!(s.load().unwrap().unwrap().state, ClaimState::Prepared);
    assert!(chain.sends.lock().unwrap().is_empty());
}
