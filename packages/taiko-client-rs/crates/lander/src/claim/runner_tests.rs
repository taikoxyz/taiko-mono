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
    async fn canonical_hash(&self, _: u64) -> Result<B256> {
        Ok(*self.canonical.lock().unwrap())
    }
    async fn transaction_finalized(&self, _: &LandingReceipt) -> Result<bool> {
        Ok(*self.finalized.lock().unwrap())
    }
}
#[async_trait]
impl ClaimTransport for Chain {
    async fn sign(&self, id: &ClaimIdentity, p: &ClaimProof) -> Result<SignedClaim> {
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
        Ok(*self.receipt.lock().unwrap())
    }
    async fn known(&self, _: B256) -> Result<bool> {
        Ok(*self.known.lock().unwrap())
    }
    async fn nonce(&self) -> Result<NonceState> {
        Ok(*self.nonce.lock().unwrap())
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
    *chain.receipt.lock().unwrap() = None;
    *chain.claimed.lock().unwrap() = false;
    step(&s, &chain, &chain, DEADLINE).await.unwrap();
    assert_eq!(s.load().unwrap().unwrap().state, ClaimState::Pending);
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
    assert!(step(&s, &chain, &chain, DEADLINE).await.is_err());
    assert_eq!(chain.sends.lock().unwrap().len(), 1);
    assert_eq!(s.load().unwrap().unwrap().transaction, Some(tx));
}
