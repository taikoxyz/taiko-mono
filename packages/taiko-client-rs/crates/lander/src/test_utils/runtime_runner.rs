use crate::{
    LanderError, Result,
    batch::{BatchObservation, BatchSource},
    config::BatchPolicy,
    contracts::IEtnaInbox::LandInput,
    l1::{LandingSource, ParentContext},
    proof::{ProofError, ProofProvider, ProofRequest},
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
    snapshot_rpc: Option<Arc<crate::l1::RpcLandingSource>>,
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
    prepares: usize,
    proofs: usize,
    decided_height: u64,
    publishable_blocks: usize,
    force_backpressure: bool,
    force_epoch: bool,
    observation_error: bool,
    checkpoint_error: bool,
    prepare_empty: bool,
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
            snapshot_rpc: None,
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
            prepares: 0,
            proofs: 0,
            decided_height: 2,
            publishable_blocks: 2,
            force_backpressure: false,
            force_epoch: false,
            observation_error: false,
            checkpoint_error: false,
            prepare_empty: false,
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
        self.with_policy(BatchPolicy::default())
    }
    fn with_policy(&self, policy: BatchPolicy) -> Runner {
        self.with_policy_and_proofs(
            policy,
            Arc::new(CountingProof { control: self.control.clone() }),
        )
    }
    fn with_proofs(&self, proofs: Arc<dyn ProofProvider>) -> Runner {
        self.with_policy_and_proofs(BatchPolicy::default(), proofs)
    }
    fn with_policy_and_proofs(
        &self,
        policy: BatchPolicy,
        proofs: Arc<dyn ProofProvider>,
    ) -> Runner {
        let batches =
            Arc::new(MockBatch { request: self.request.clone(), control: self.control.clone() });
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
                batch_policy: policy,
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
    control: Arc<Mutex<Control>>,
}
#[async_trait]
impl BatchSource for MockBatch {
    async fn observe(&self, _: &LandingSnapshot) -> Result<BatchObservation> {
        let control = self.control.lock().unwrap();
        if control.observation_error {
            return Err(LanderError::Temporary("decided RPC temporarily unavailable".into()));
        }
        Ok(BatchObservation {
            decided_height: control.decided_height,
            publishable_blocks: control.publishable_blocks,
            force_backpressure: control.force_backpressure,
            force_epoch: control.force_epoch,
        })
    }
    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>> {
        let mut control = self.control.lock().unwrap();
        control.prepares += 1;
        if control.prepare_empty {
            return Ok(None);
        }
        Ok((snapshot.checkpoint_height == self.request.batch.snapshot.checkpoint_height)
            .then(|| self.request.clone()))
    }
    async fn validate_checkpoint(&self, _: &LandingSnapshot) -> Result<()> {
        if self.control.lock().unwrap().checkpoint_error {
            Err(LanderError::Temporary("checkpoint RPC temporarily unavailable".into()))
        } else {
            Ok(())
        }
    }
}
struct MockL1 {
    request: ProofRequest,
    control: Arc<Mutex<Control>>,
}
#[async_trait]
impl LandingSource for MockL1 {
    async fn snapshot(&self) -> Result<LandingSnapshot> {
        let rpc = self.control.lock().unwrap().snapshot_rpc.clone();
        if let Some(rpc) = rpc {
            rpc.snapshot().await
        } else {
            Ok(self.control.lock().unwrap().snapshot.clone())
        }
    }
    async fn parent_header(&self, _: &LandingSnapshot) -> Result<ParentContext> {
        Ok(ParentContext {
            header: self.request.batch.parent_header.clone(),
            grandparent_timestamp: 0,
        })
    }
    async fn execution_header(&self, _: u64) -> Result<alloy_consensus::Header> {
        unreachable!()
    }
    async fn parent_anchor(&self, _: &LandingSnapshot, _: &ParentContext) -> Result<AnchorState> {
        Ok(self.request.batch.parent_anchor.clone())
    }
    async fn starting_inbox_witness(&self, _: &AnchorState) -> Result<abci::AnchorWitness> {
        unreachable!()
    }
    async fn committee_witness(
        &self,
        _: &LandingSnapshot,
        _: &AnchorState,
        _: u64,
        _: u64,
    ) -> Result<abci::CommitteeWitness> {
        unreachable!("runner mock never derives a committee")
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

#[tokio::test(start_paused = true)]
async fn mined_nonce_waits_for_a_lagging_receipt_index_without_resending() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    }
    let transaction = pending_transaction(&runner);
    // The account nonce reflects the new block before the receipt is queryable by hash.
    fixture.control.lock().unwrap().nonce =
        NonceState { confirmed: transaction.nonce + 1, pending: transaction.nonce + 1 };
    for _ in 0..3 {
        assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
        tokio::time::advance(super::UNINDEXED_RECEIPT_GRACE / 4).await;
    }
    fixture.mine(&transaction, true);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert!(matches!(runner.state(), JournalState::Confirming { .. }));
    let control = fixture.control.lock().unwrap();
    assert_eq!((control.signs, control.broadcasts.len()), (1, 1));
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

#[tokio::test(start_paused = true)]
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
    assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
    tokio::time::advance(super::UNINDEXED_RECEIPT_GRACE).await;
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
                control.snapshot.committee_config_hash = B256::ZERO;
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

struct CountingProof {
    control: Arc<Mutex<Control>>,
}
#[async_trait]
impl ProofProvider for CountingProof {
    async fn prove(&self, _: &ProofRequest) -> std::result::Result<Bytes, ProofError> {
        self.control.lock().unwrap().proofs += 1;
        Ok(Bytes::from_static(&[0]))
    }
}

#[tokio::test(start_paused = true)]
async fn batch_waits_for_minimum_or_first_backlog_deadline_without_preparing() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    fixture.control.lock().unwrap().publishable_blocks = 1;
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    {
        let control = fixture.control.lock().unwrap();
        assert_eq!((control.prepares, control.proofs, control.signs), (0, 0, 0));
    }
    let original = disk_wait(&fixture).unwrap();
    tokio::time::advance(Duration::from_secs(20)).await;
    {
        let mut control = fixture.control.lock().unwrap();
        control.publishable_blocks = 2;
        control.decided_height = 3;
    }
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(disk_wait(&fixture), Some(original));
    tokio::time::advance(Duration::from_secs(9)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(1)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert!(matches!(runner.state(), JournalState::Prepared { .. }));
    assert_eq!(fixture.control.lock().unwrap().proofs, 1);
    assert!(disk_wait(&fixture).is_none());
}

fn disk_wait(fixture: &Fixture) -> Option<crate::store::BatchWait> {
    let journal: serde_json::Value = serde_json::from_slice(
        &std::fs::read(fixture.directory.path().join("lander-state.json")).unwrap(),
    )
    .unwrap();
    journal.get("waiting").map(|waiting| serde_json::from_value(waiting.clone()).unwrap())
}

#[tokio::test(start_paused = true)]
async fn minimum_is_sufficient_without_waiting_for_the_deadline() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 2, max_wait: Duration::from_secs(30) };
    fixture.control.lock().unwrap().publishable_blocks = 1;
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    fixture.control.lock().unwrap().publishable_blocks = 2;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert!(disk_wait(&fixture).is_none());
}

#[tokio::test(start_paused = true)]
async fn incomplete_backlog_retains_its_timer_until_a_complete_prefix_is_available() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    fixture.control.lock().unwrap().publishable_blocks = 0;
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    let marker = disk_wait(&fixture).unwrap();
    tokio::time::advance(Duration::from_secs(31)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(fixture.control.lock().unwrap().prepares, 0);
    assert_eq!(disk_wait(&fixture), Some(marker));
    fixture.control.lock().unwrap().publishable_blocks = 1;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
}

#[tokio::test(start_paused = true)]
async fn transient_observation_and_checkpoint_errors_preserve_wait_age() {
    for checkpoint_error in [false, true] {
        let fixture = Fixture::new();
        let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
        let mut runner = fixture.with_policy(policy);
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
        let marker = disk_wait(&fixture).unwrap();
        tokio::time::advance(Duration::from_secs(20)).await;
        {
            let mut control = fixture.control.lock().unwrap();
            control.observation_error = !checkpoint_error;
            control.checkpoint_error = checkpoint_error;
        }
        assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
        assert_eq!(disk_wait(&fixture), Some(marker));
        tokio::time::advance(Duration::from_secs(10)).await;
        {
            let mut control = fixture.control.lock().unwrap();
            control.observation_error = false;
            control.checkpoint_error = false;
        }
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    }
}

#[tokio::test(start_paused = true)]
async fn restart_restores_elapsed_age_and_keeps_the_existing_wall_marker() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    let mut first = fixture.with_policy(policy);
    assert_eq!(first.step().await.unwrap(), StepOutcome::Waiting);
    drop(first);
    let store = Store::open(fixture.directory.path(), fixture.identity()).unwrap();
    let (_, mut waiting) = store.load_with_wait().unwrap();
    let marker = waiting.as_mut().unwrap();
    marker.first_seen_unix_ms = super::unix_milliseconds().unwrap() - 25_000;
    store.save_with_wait(&JournalState::Idle, waiting.as_ref()).unwrap();
    drop(store);
    let marker = disk_wait(&fixture).unwrap();
    let mut resumed = fixture.with_policy(policy);
    assert_eq!(resumed.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(4)).await;
    assert_eq!(resumed.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(disk_wait(&fixture), Some(marker));
    tokio::time::advance(Duration::from_secs(1)).await;
    assert_eq!(resumed.step().await.unwrap(), StepOutcome::Progress);
}

#[tokio::test(start_paused = true)]
async fn future_wall_marker_is_clamped_once_and_monotonic_wait_remains_bounded() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    let store = Store::open(fixture.directory.path(), fixture.identity()).unwrap();
    let future = crate::store::BatchWait {
        checkpoint_height: fixture.request.batch.snapshot.checkpoint_height,
        checkpoint_hash: fixture.request.batch.snapshot.checkpoint_hash,
        generation: fixture.request.batch.snapshot.generation,
        first_seen_unix_ms: u64::MAX,
    };
    store.save_with_wait(&JournalState::Idle, Some(&future)).unwrap();
    drop(store);
    let mut runner = fixture.with_policy(policy);
    let clamped = disk_wait(&fixture).unwrap();
    assert!(clamped.first_seen_unix_ms < future.first_seen_unix_ms);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(30)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
}

#[tokio::test(start_paused = true)]
async fn empty_backlog_discards_the_prior_deadline() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(20)).await;
    fixture.control.lock().unwrap().decided_height = 0;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert!(disk_wait(&fixture).is_none());
    fixture.control.lock().unwrap().decided_height = 2;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(10)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(20)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
}

#[tokio::test(start_paused = true)]
async fn checkpoint_identity_change_discards_wait_even_when_following_rpc_fails() {
    for identity_field in ["height", "hash", "generation"] {
        for checkpoint_error in [false, true] {
            let fixture = Fixture::new();
            let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
            let mut runner = fixture.with_policy(policy);
            assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
            tokio::time::advance(Duration::from_secs(20)).await;
            {
                let mut control = fixture.control.lock().unwrap();
                match identity_field {
                    "height" => control.snapshot.checkpoint_height += 1,
                    "hash" => control.snapshot.checkpoint_hash = B256::repeat_byte(99),
                    "generation" => control.snapshot.generation += 1,
                    _ => unreachable!(),
                }
                control.observation_error = !checkpoint_error;
                control.checkpoint_error = checkpoint_error;
            }
            assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
            assert!(disk_wait(&fixture).is_none());
            {
                let mut control = fixture.control.lock().unwrap();
                control.snapshot = fixture.request.batch.snapshot.clone();
                control.observation_error = false;
                control.checkpoint_error = false;
            }
            assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
            tokio::time::advance(Duration::from_secs(10)).await;
            assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
            tokio::time::advance(Duration::from_secs(20)).await;
            assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
        }
    }
}

#[tokio::test(start_paused = true)]
async fn consensus_pressure_and_epoch_progress_bypass_high_threshold_and_long_wait() {
    for force_epoch in [false, true] {
        let fixture = Fixture::new();
        let policy = BatchPolicy { min_blocks: 100, max_wait: Duration::from_secs(3600) };
        {
            let mut control = fixture.control.lock().unwrap();
            control.force_backpressure = !force_epoch;
            control.force_epoch = force_epoch;
        }
        let mut runner = fixture.with_policy(policy);
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
        assert!(matches!(runner.state(), JournalState::Prepared { .. }));
        assert_eq!(fixture.control.lock().unwrap().proofs, 1);
        assert!(disk_wait(&fixture).is_none());
    }
}

#[tokio::test(start_paused = true)]
async fn lower_prepared_tip_does_not_bypass_the_minimum_threshold() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 3, max_wait: Duration::from_secs(30) };
    fixture.control.lock().unwrap().publishable_blocks = 3;
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(runner.state(), &JournalState::Idle);
    assert_eq!(fixture.control.lock().unwrap().proofs, 0);
    assert!(disk_wait(&fixture).is_some());
    tokio::time::advance(Duration::from_secs(30)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
}

#[tokio::test(start_paused = true)]
async fn empty_fresh_preparation_clears_an_expired_backlog_timer() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(30)).await;
    fixture.control.lock().unwrap().prepare_empty = true;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert!(disk_wait(&fixture).is_none());
    fixture.control.lock().unwrap().prepare_empty = false;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(29)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(1)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
}

#[tokio::test(start_paused = true)]
async fn run_wakes_at_the_remaining_batch_deadline_before_a_long_poll_interval() {
    for poll_interval in [Duration::from_secs(20), Duration::from_secs(3600)] {
        let fixture = Fixture::new();
        let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
        let mut runner = fixture.with_policy(policy);
        runner.config.poll_interval = poll_interval;
        runner.config.retry_max_delay = poll_interval;
        assert!(tokio::time::timeout(Duration::from_secs(31), runner.run()).await.is_err());
        assert_eq!(fixture.control.lock().unwrap().proofs, 1);
        assert!(matches!(runner.state(), JournalState::Pending { .. }));
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

#[tokio::test]
async fn latest_snapshot_reorg_preserves_pending_journal_and_signed_nonce_then_retries() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    }
    let pending = runner.state().clone();
    let transaction = pending_transaction(&runner);
    let journal = fixture.directory.path().join("lander-state.json");
    let journal_before = std::fs::read(&journal).unwrap();
    let rpc = crate::l1::tests::snapshot_rpc(true, false, false).await;
    fixture.control.lock().unwrap().snapshot_rpc = Some(rpc.source.clone());
    let error = runner.step().await.unwrap_err();
    assert!(error.is_retryable(), "ordinary snapshot reorg must retry: {error}");
    assert_eq!(runner.state(), &pending);
    assert_eq!(std::fs::read(&journal).unwrap(), journal_before);
    assert_eq!(pending_transaction(&runner), transaction);
    assert_eq!(fixture.control.lock().unwrap().signs, 1);
    assert_eq!(fixture.control.lock().unwrap().broadcasts.len(), 1);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(runner.state(), &pending);
    assert_eq!(std::fs::read(&journal).unwrap(), journal_before);
    assert_eq!(pending_transaction(&runner), transaction);
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.signs, 1);
    assert_eq!(control.broadcasts.len(), 1);
    assert_eq!(control.nonce, NonceState { confirmed: 0, pending: transaction.nonce + 1 });
}
