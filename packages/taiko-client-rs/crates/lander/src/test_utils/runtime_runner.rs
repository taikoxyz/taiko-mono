use crate::{
    LanderError, Result,
    batch::BatchSource,
    contracts::IEtnaInbox::LandInput,
    l1::{LandingSource, ParentContext},
    proof::{DummyProofProvider, ProofError, ProofProvider, ProofRequest},
    runner::{Runner, RunnerConfig, StepOutcome},
    store::{JournalIdentity, JournalState, ProvedJob, Store},
    test_utils::runtime::{request, signed, signer},
    tx::{LandingReceipt, NonceState, SignedTransaction, TransactionTransport},
    types::LandingSnapshot,
};
use abci::{AnchorState, l1::header::RawL1Header};
use alloy_primitives::{Address, B256, Bytes};
use async_trait::async_trait;
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

struct Control {
    snapshot: LandingSnapshot,
    reference_current: bool,
    receipt: Option<LandingReceipt>,
    canonical_receipt: B256,
    nonce: NonceState,
    known: bool,
    ambiguous_send: bool,
    helper_mismatch: bool,
    estimate_revert: bool,
    compete_during_estimate: bool,
    signs: usize,
    broadcasts: Vec<Bytes>,
    events: Vec<&'static str>,
}
struct Fixture {
    directory: tempfile::TempDir,
    request: ProofRequest,
    control: Arc<Mutex<Control>>,
}
impl Fixture {
    fn new() -> Self {
        let request = request();
        let control = Control {
            snapshot: request.batch.snapshot.clone(),
            reference_current: true,
            receipt: None,
            canonical_receipt: B256::repeat_byte(30),
            nonce: NonceState { confirmed: 0, pending: 0 },
            known: false,
            ambiguous_send: false,
            helper_mismatch: false,
            estimate_revert: false,
            compete_during_estimate: false,
            signs: 0,
            broadcasts: vec![],
            events: vec![],
        };
        Self {
            directory: tempfile::tempdir().unwrap(),
            request,
            control: Arc::new(Mutex::new(control)),
        }
    }
    fn identity(&self) -> JournalIdentity {
        let snapshot = &self.request.batch.snapshot;
        JournalIdentity {
            l1_chain_id: snapshot.l1_chain_id,
            l2_chain_id: snapshot.l2_chain_id,
            inbox: snapshot.inbox,
            registry: snapshot.registry,
            sender: signer().address(),
        }
    }
    fn runner(&self) -> Runner {
        self.with_proofs(Arc::new(DummyProofProvider))
    }
    fn with_proofs(&self, proofs: Arc<dyn ProofProvider>) -> Runner {
        let batches = Arc::new(MockBatch { request: self.request.clone() });
        let l1 = Arc::new(MockL1 { request: self.request.clone(), control: self.control.clone() });
        let tx = Arc::new(MockTx {
            control: self.control.clone(),
            directory: self.directory.path().to_owned(),
        });
        Runner::new(
            batches,
            l1,
            tx,
            proofs,
            Store::open(self.directory.path(), self.identity()).unwrap(),
            RunnerConfig {
                poll_interval: Duration::from_millis(10),
                proof_timeout: Duration::from_millis(50),
                broadcast_timeout: Duration::from_millis(50),
                receipt_timeout: Duration::from_millis(50),
                confirmations: 2,
                retry_max_delay: Duration::from_secs(1),
            },
        )
        .unwrap()
    }
    fn compete(&self, height: u64) {
        let mut control = self.control.lock().unwrap();
        control.snapshot.checkpoint_height = height;
        control.snapshot.checkpoint_hash = B256::repeat_byte(height as u8);
    }
    fn mine(&self, transaction: &SignedTransaction, success: bool) {
        let mut control = self.control.lock().unwrap();
        control.receipt = Some(LandingReceipt {
            transaction_hash: transaction.hash,
            block_number: 30,
            block_hash: control.canonical_receipt,
            success,
        });
        control.nonce =
            NonceState { confirmed: transaction.nonce + 1, pending: transaction.nonce + 1 };
        control.snapshot.l1_block_number = 30;
        if success {
            control.snapshot.checkpoint_height = self.request.batch.input.lastHeight;
            control.snapshot.checkpoint_hash = self.request.batch.input.lastBlockHash;
        }
    }
}
struct MockBatch {
    request: ProofRequest,
}
#[async_trait]
impl BatchSource for MockBatch {
    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>> {
        Ok((snapshot.checkpoint_height == self.request.batch.snapshot.checkpoint_height)
            .then(|| self.request.clone()))
    }
    async fn validate_checkpoint(&self, _: &LandingSnapshot) -> Result<()> {
        Ok(())
    }
}
struct MockL1 {
    request: ProofRequest,
    control: Arc<Mutex<Control>>,
}
#[async_trait]
impl LandingSource for MockL1 {
    async fn snapshot(&self) -> Result<LandingSnapshot> {
        Ok(self.control.lock().unwrap().snapshot.clone())
    }
    async fn parent_header(&self, _: &LandingSnapshot) -> Result<ParentContext> {
        Ok(ParentContext {
            header: self.request.batch.parent_header.clone(),
            grandparent_timestamp: 0,
        })
    }
    async fn parent_anchor(&self, _: &LandingSnapshot, _: &ParentContext) -> Result<AnchorState> {
        Ok(self.request.batch.parent_anchor.clone())
    }
    async fn committee_hash(&self, _: &LandingSnapshot, _: u64) -> Result<B256> {
        Ok(B256::ZERO)
    }
    async fn reference(&self, _: &LandingSnapshot, _: &[AnchorState]) -> Result<Vec<RawL1Header>> {
        Ok(vec![])
    }
    async fn statement_hash(
        &self,
        _: &LandingSnapshot,
        _: &LandInput,
        _: B256,
        _: &[B256],
    ) -> Result<B256> {
        Ok(if self.control.lock().unwrap().helper_mismatch {
            B256::ZERO
        } else {
            self.request.batch.statement_hash
        })
    }
    async fn canonical_hash(&self, _: u64) -> Result<B256> {
        Ok(self.control.lock().unwrap().canonical_receipt)
    }
    async fn validate_reference(&self, _: &LandingSnapshot, _: u64, _: B256) -> Result<()> {
        if self.control.lock().unwrap().reference_current {
            Ok(())
        } else {
            Err(LanderError::Stale("reference reorg".into()))
        }
    }
}
struct MockTx {
    control: Arc<Mutex<Control>>,
    directory: std::path::PathBuf,
}
#[async_trait]
impl TransactionTransport for MockTx {
    fn sender(&self) -> Address {
        signer().address()
    }
    async fn sign(&self, request: &ProofRequest, proof: &Bytes) -> Result<SignedTransaction> {
        let nonce = {
            let mut control = self.control.lock().unwrap();
            control.signs += 1;
            control.events.push("sign");
            control.nonce.pending
        };
        {
            let mut control = self.control.lock().unwrap();
            if control.estimate_revert {
                if control.compete_during_estimate {
                    control.snapshot.checkpoint_height = 1;
                    control.snapshot.checkpoint_hash = B256::repeat_byte(1);
                }
                return Err(LanderError::Reverted("estimation reverted".into()));
            }
        }
        Ok(signed(request, proof, nonce).await)
    }
    async fn broadcast(&self, transaction: &SignedTransaction) -> Result<B256> {
        let saved: serde_json::Value = serde_json::from_slice(
            &std::fs::read(self.directory.join("lander-state.json")).unwrap(),
        )
        .unwrap();
        assert_eq!(saved["state"]["phase"], "pending", "broadcast must follow durable Pending");
        let mut control = self.control.lock().unwrap();
        control.events.push("broadcast");
        control.broadcasts.push(transaction.network_bytes.clone());
        control.known = true;
        control.nonce.pending = transaction.nonce + 1;
        if control.ambiguous_send {
            control.ambiguous_send = false;
            Err(LanderError::Temporary("response lost after accepted send".into()))
        } else {
            Ok(transaction.hash)
        }
    }
    async fn receipt(&self, _: B256) -> Result<Option<LandingReceipt>> {
        let mut control = self.control.lock().unwrap();
        control.events.push("receipt");
        Ok(control.receipt)
    }
    async fn known(&self, _: B256) -> Result<bool> {
        let mut control = self.control.lock().unwrap();
        control.events.push("known");
        Ok(control.known)
    }
    async fn nonce_state(&self) -> Result<NonceState> {
        let mut control = self.control.lock().unwrap();
        control.events.push("nonce");
        Ok(control.nonce)
    }
}
fn pending_transaction(runner: &Runner) -> SignedTransaction {
    match runner.state() {
        JournalState::Pending { transaction, .. } |
        JournalState::Confirming { transaction, .. } => transaction.clone(),
        _ => panic!("expected outstanding transaction"),
    }
}

#[tokio::test]
async fn happy_path_is_journal_first_and_waits_for_canonical_confirmation_depth() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    }
    let transaction = pending_transaction(&runner);
    fixture.mine(&transaction, true);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    fixture.control.lock().unwrap().snapshot.l1_block_number = 31;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Settled);
    assert_eq!(runner.state(), &JournalState::Idle);
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.signs, 1);
    assert_eq!(control.broadcasts.len(), 1);
}

#[tokio::test]
async fn lost_broadcast_response_and_restart_never_sign_or_allocate_a_second_nonce() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    runner.step().await.unwrap();
    runner.step().await.unwrap();
    fixture.control.lock().unwrap().ambiguous_send = true;
    assert!(runner.step().await.is_err());
    let original = pending_transaction(&runner);
    drop(runner);
    fixture.control.lock().unwrap().events.clear();
    let mut resumed = fixture.runner();
    assert_eq!(resumed.step().await.unwrap(), StepOutcome::Waiting);
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.signs, 1);
    assert_eq!(control.broadcasts.len(), 1);
    assert_eq!(control.events, vec!["receipt", "nonce", "known"]);
    assert_eq!(pending_transaction(&resumed).network_bytes, original.network_bytes);
}

#[tokio::test]
async fn crash_after_pending_commit_before_first_send_reconciles_then_resends_identical_bytes() {
    let fixture = Fixture::new();
    let proof = Bytes::from_static(&[0]);
    let transaction = signed(&fixture.request, &proof, 0).await;
    let store = Store::open(fixture.directory.path(), fixture.identity()).unwrap();
    store
        .save(&JournalState::Pending {
            job: Box::new(ProvedJob { request: fixture.request.clone(), proof }),
            transaction: transaction.clone(),
        })
        .unwrap();
    drop(store);
    let mut resumed = fixture.runner();
    assert_eq!(resumed.step().await.unwrap(), StepOutcome::Waiting);
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.events, vec!["receipt", "nonce", "known", "broadcast"]);
    assert_eq!(control.signs, 0);
    assert_eq!(control.broadcasts, vec![transaction.network_bytes]);
}

#[tokio::test]
async fn partial_and_full_competing_progress_discards_only_unbroadcast_work() {
    for signed_phase in [false, true] {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        runner.step().await.unwrap();
        if signed_phase {
            runner.step().await.unwrap();
        }
        fixture.compete(1);
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Rebuild);
        assert_eq!(runner.state(), &JournalState::Idle);
        assert_eq!(fixture.control.lock().unwrap().broadcasts.len(), 0);
    }
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    fixture.compete(1);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert!(matches!(runner.state(), JournalState::Pending { .. }));
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.signs, 1);
    assert_eq!(control.broadcasts.len(), 1);
}

#[tokio::test]
async fn receipt_reorg_returns_to_pending_and_never_authorizes_false_progress() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let tx = pending_transaction(&runner);
    fixture.mine(&tx, true);
    runner.step().await.unwrap();
    {
        let mut control = fixture.control.lock().unwrap();
        control.canonical_receipt = B256::repeat_byte(31);
        control.receipt = None;
        control.nonce = NonceState { confirmed: 0, pending: 1 };
        control.snapshot = fixture.request.batch.snapshot.clone();
    }
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert!(matches!(runner.state(), JournalState::Pending { .. }));
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(fixture.control.lock().unwrap().signs, 1);
}

#[tokio::test]
async fn unchanged_checkpoint_revert_stops_but_competing_revert_can_settle() {
    for competition in [false, true] {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        for _ in 0..3 {
            runner.step().await.unwrap();
        }
        let tx = pending_transaction(&runner);
        fixture.mine(&tx, false);
        if competition {
            fixture.compete(1);
        }
        runner.step().await.unwrap();
        fixture.control.lock().unwrap().snapshot.l1_block_number = 31;
        let outcome = runner.step().await;
        if competition {
            assert_eq!(outcome.unwrap(), StepOutcome::Settled);
        } else {
            assert!(matches!(outcome, Err(LanderError::Reverted(_))));
            assert!(matches!(runner.state(), JournalState::Confirming { .. }));
        }
        assert_eq!(fixture.control.lock().unwrap().signs, 1);
    }
}

#[tokio::test]
async fn dropped_transaction_is_identically_rebroadcast_after_receipt_and_nonce_reads() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    {
        let mut control = fixture.control.lock().unwrap();
        control.known = false;
        control.nonce.pending = 0;
        control.events.clear();
    }
    runner.step().await.unwrap();
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.events, vec!["receipt", "nonce", "known", "broadcast"]);
    assert_eq!(control.broadcasts[0], control.broadcasts[1]);
    assert_eq!(control.signs, 1);
}

#[tokio::test]
async fn expired_unbroadcast_reference_rebuilds_and_consumed_unknown_nonce_is_fatal() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    runner.step().await.unwrap();
    fixture.control.lock().unwrap().reference_current = false;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Rebuild);
    assert_eq!(fixture.control.lock().unwrap().signs, 0);
    fixture.control.lock().unwrap().reference_current = true;
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    fixture.control.lock().unwrap().nonce.confirmed = 1;
    assert!(matches!(runner.step().await, Err(LanderError::Safety(_))));
    assert_eq!(fixture.control.lock().unwrap().signs, 1);
}

#[tokio::test]
async fn partial_or_full_checkpoint_after_dropped_send_never_spends_a_new_nonce() {
    for height in [1, 2] {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        for _ in 0..3 {
            runner.step().await.unwrap();
        }
        fixture.compete(height);
        {
            let mut control = fixture.control.lock().unwrap();
            control.known = false;
            control.nonce.pending = 0;
        }
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
        assert!(matches!(runner.state(), JournalState::Pending { .. }));
        let control = fixture.control.lock().unwrap();
        assert_eq!(control.signs, 1);
        assert_eq!(control.broadcasts.len(), 1);
    }
}

#[tokio::test]
async fn changed_proxy_statement_or_unchanged_checkpoint_committee_stops_before_signing() {
    for committee_change in [false, true] {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        runner.step().await.unwrap();
        {
            let mut control = fixture.control.lock().unwrap();
            if committee_change {
                control.snapshot.start_committee_record_hash = B256::ZERO;
            } else {
                control.helper_mismatch = true;
            }
        }
        let result = runner.step().await;
        assert!(matches!(result, Err(LanderError::Safety(_)) | Err(LanderError::Configuration(_))));
        let control = fixture.control.lock().unwrap();
        assert_eq!(control.signs, 0);
        assert_eq!(control.broadcasts.len(), 0);
    }
}

struct DelayedProof;
#[async_trait]
impl ProofProvider for DelayedProof {
    async fn prove(&self, _: &ProofRequest) -> std::result::Result<Bytes, ProofError> {
        tokio::time::sleep(Duration::from_secs(60)).await;
        Ok(Bytes::from_static(&[0]))
    }
}
struct RejectingProof;
#[async_trait]
impl ProofProvider for RejectingProof {
    async fn prove(&self, _: &ProofRequest) -> std::result::Result<Bytes, ProofError> {
        Err(ProofError::Rejected("backend rejected immutable statement".into()))
    }
}
#[tokio::test(start_paused = true)]
async fn proof_deadline_and_backend_rejection_never_sign_or_broadcast() {
    let fixture = Fixture::new();
    let mut runner = fixture.with_proofs(Arc::new(DelayedProof));
    assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
    assert_eq!(runner.state(), &JournalState::Idle);
    drop(runner);
    let mut runner = fixture.with_proofs(Arc::new(RejectingProof));
    assert!(matches!(runner.step().await, Err(LanderError::Safety(_))));
    assert_eq!(fixture.control.lock().unwrap().signs, 0);
}

#[tokio::test]
async fn restart_confirming_reconciles_the_receipt_before_using_cached_success() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let transaction = pending_transaction(&runner);
    fixture.mine(&transaction, true);
    runner.step().await.unwrap();
    drop(runner);
    {
        let mut control = fixture.control.lock().unwrap();
        control.receipt = None;
        control.snapshot.l1_block_number = 31;
        control.events.clear();
    }
    let mut resumed = fixture.runner();
    assert_eq!(resumed.step().await.unwrap(), StepOutcome::Progress);
    assert!(matches!(resumed.state(), JournalState::Pending { .. }));
    assert_eq!(fixture.control.lock().unwrap().events, vec!["receipt"]);
}

#[tokio::test]
async fn estimation_revert_rechecks_checkpoint_races_but_stops_for_unchanged_job() {
    for competition in [false, true] {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        runner.step().await.unwrap();
        {
            let mut control = fixture.control.lock().unwrap();
            control.estimate_revert = true;
            control.compete_during_estimate = competition;
        }
        let result = runner.step().await;
        if competition {
            assert_eq!(result.unwrap(), StepOutcome::Rebuild);
            assert_eq!(runner.state(), &JournalState::Idle);
        } else {
            assert!(matches!(result, Err(LanderError::Reverted(_))));
            assert!(matches!(runner.state(), JournalState::Prepared { .. }));
        }
        assert_eq!(fixture.control.lock().unwrap().broadcasts.len(), 0);
    }
}
