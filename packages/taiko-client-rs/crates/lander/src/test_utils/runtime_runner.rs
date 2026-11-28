use crate::{
    LanderError, Result,
    batch::{BatchObservation, BatchPreview, BatchSource},
    config::BatchPolicy,
    contracts::IEtnaInbox::ReferenceBlockUnavailable,
    l1::{LandingSource, ParentContext},
    proof::{ProofError, ProofProvider, ProofRequest},
    runner::{Runner, RunnerConfig, StepOutcome},
    store::{JournalIdentity, JournalState, ProvedJob, Store},
    test_utils::runtime::{request, signed, signed_by, signer},
    tx::{
        FeeCaps, LandingReceipt, NonceState, RpcTransactionTransport, SignedTransaction,
        TransactionTransport,
    },
    types::LandingSnapshot,
};
use abci::{AnchorState, l1::header::RawL1Header};
use alloy::sol_types::SolError;
use alloy_primitives::{Address, B256, Bytes};
use async_trait::async_trait;
use serde_json::{Value, json};
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

struct Control {
    snapshot: LandingSnapshot,
    next_request: Option<ProofRequest>,
    snapshot_rpc: Option<Arc<crate::l1::RpcLandingSource>>,
    reference_current: bool,
    receipt: Option<LandingReceipt>,
    trace_transport: Option<RpcTransactionTransport>,
    canonical_receipt: B256,
    canonical_snapshot: Option<B256>,
    nonce: NonceState,
    known: bool,
    ambiguous_send: bool,
    estimate_revert: bool,
    compete_during_estimate: bool,
    signs: usize,
    prepares: usize,
    proofs: usize,
    decided_height: u64,
    publishable_blocks: usize,
    force_back_pressure: bool,
    /// The exact end the batch source reports (`--land-to`).
    land_to: Option<u64>,
    observation_error: bool,
    checkpoint_error: bool,
    prepare_empty: bool,
    corrupt_signature: bool,
    foreign_signer: bool,
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
            next_request: None,
            snapshot_rpc: None,
            reference_current: true,
            receipt: None,
            trace_transport: None,
            canonical_receipt: B256::repeat_byte(30),
            canonical_snapshot: None,
            nonce: NonceState { confirmed: 0, pending: 0 },
            known: false,
            ambiguous_send: false,
            estimate_revert: false,
            compete_during_estimate: false,
            signs: 0,
            prepares: 0,
            proofs: 0,
            decided_height: 2,
            publishable_blocks: 2,
            force_back_pressure: false,
            land_to: None,
            observation_error: false,
            checkpoint_error: false,
            prepare_empty: false,
            corrupt_signature: false,
            foreign_signer: false,
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
        let pair = &self.request.batch.blocks[height as usize - 1];
        control.snapshot.checkpoint_hash =
            abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap().block.header.hash_slow();
        control.snapshot.checkpoint_comet_hash =
            B256::from_slice(pair.block.header.hash().as_bytes());
    }
    fn mine(&self, transaction: &SignedTransaction, success: bool) {
        self.mine_at(transaction, success, 30);
    }
    fn mine_at(&self, transaction: &SignedTransaction, success: bool, block_number: u64) {
        let mut control = self.control.lock().unwrap();
        control.receipt = Some(LandingReceipt {
            transaction_hash: transaction.hash,
            block_number,
            block_hash: control.canonical_receipt,
            success,
        });
        control.nonce =
            NonceState { confirmed: transaction.nonce + 1, pending: transaction.nonce + 1 };
        control.snapshot.l1_block_number = block_number;
        control.snapshot.l1_block_hash = control.canonical_receipt;
        if success {
            control.snapshot.checkpoint_height = self.request.batch.input.lastHeight.to::<u64>();
            control.snapshot.checkpoint_hash = self.request.batch.input.lastBlockHash;
        }
    }
    async fn trace(
        &self,
        handler: impl Fn(&Value) -> Value + Send + Sync + 'static,
    ) -> crate::l1::tests::RpcFixture {
        let rpc = crate::l1::tests::rpc(handler).await;
        self.control.lock().unwrap().trace_transport = Some(
            RpcTransactionTransport::new(
                rpc.provider.clone(),
                signer(),
                FeeCaps {
                    max_fee_per_gas: 10,
                    max_priority_fee_per_gas: 1,
                    max_fee_per_blob_gas: 10,
                },
            )
            .unwrap(),
        );
        rpc
    }
}
struct MockBatch {
    request: ProofRequest,
    control: Arc<Mutex<Control>>,
}
#[async_trait]
impl BatchSource for MockBatch {
    async fn observe(&self, _: &LandingSnapshot) -> Result<BatchPreview> {
        let control = self.control.lock().unwrap();
        if control.observation_error {
            return Err(LanderError::Temporary("decided RPC temporarily unavailable".into()));
        }
        Ok(BatchPreview::from_observation(BatchObservation {
            decided_height: control.decided_height,
            publishable_blocks: control.publishable_blocks,
            force_back_pressure: control.force_back_pressure,
        }))
    }
    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>> {
        let mut control = self.control.lock().unwrap();
        control.prepares += 1;
        if control.prepare_empty {
            return Ok(None);
        }
        if let Some(request) = &control.next_request {
            return Ok(Some(request.clone()));
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
    fn land_to(&self) -> Option<u64> {
        self.control.lock().unwrap().land_to
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
    async fn origin_anchor(&self, _: &LandingSnapshot) -> Result<AnchorState> {
        Ok(self.request.batch.parent_anchor.clone())
    }
    async fn starting_inbox_witness(
        &self,
        _: &abci::RawL1Header,
        _: u64,
    ) -> Result<abci::AnchorWitness> {
        unreachable!()
    }
    async fn fallback_keys(
        &self,
        _: B256,
        _: B256,
        _: u64,
        _: u64,
    ) -> Result<abci::fallback::FallbackKeys> {
        unreachable!("runner mock never reads a fallback key list")
    }
    async fn staking_witness(&self, _: B256, _: &[B256]) -> Result<abci::AccountWitness> {
        unreachable!("runner mock never reads a staking proof")
    }
    async fn reference(&self, _: &LandingSnapshot, _: &[AnchorState]) -> Result<Vec<RawL1Header>> {
        Ok(vec![])
    }
    async fn deployment(&self, _: &LandingSnapshot) -> Result<crate::l1::Deployment> {
        unreachable!("the runner reads no deployment getters")
    }
    async fn canonical_hash(&self, number: u64) -> Result<B256> {
        let control = self.control.lock().unwrap();
        Ok(
            if number == 30 || control.receipt.is_some_and(|receipt| receipt.block_number == number)
            {
                control.canonical_receipt
            } else {
                control.canonical_snapshot.unwrap_or(control.snapshot.l1_block_hash)
            },
        )
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
                    control.snapshot.checkpoint_height = 12;
                    control.snapshot.checkpoint_hash = B256::repeat_byte(1);
                }
                return Err(LanderError::Reverted("estimation reverted".into()));
            }
        }
        let foreign = self.control.lock().unwrap().foreign_signer;
        let mut transaction = if foreign {
            let other = "0000000000000000000000000000000000000000000000000000000000000002";
            signed_by(&other.parse().unwrap(), request, proof, nonce).await
        } else {
            signed(request, proof, nonce).await
        };
        if self.control.lock().unwrap().corrupt_signature {
            transaction.hash = B256::ZERO;
        }
        Ok(transaction)
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
    async fn reference_unavailable_revert(&self, hash: B256) -> Result<bool> {
        let transport = self.control.lock().unwrap().trace_transport.clone();
        match transport {
            Some(transport) => transport.reference_unavailable_revert(hash).await,
            None => Ok(false),
        }
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

/// The pre-sign gate is the one check between signing and saving (BATCH-6.3-13): bytes that do
/// not bind the job, or that another account validly signed, never become durable.
#[tokio::test]
async fn invalid_signed_transport_result_leaves_prepared_journal_and_never_broadcasts() {
    for foreign in [false, true] {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
        let path = fixture.directory.path().join("lander-state.json");
        let prepared = std::fs::read(&path).unwrap();
        {
            let mut control = fixture.control.lock().unwrap();
            control.corrupt_signature = !foreign;
            control.foreign_signer = foreign;
        }
        let outcome = runner.step().await;
        assert!(matches!(outcome, Err(LanderError::Journal(_))), "{outcome:?}");
        if foreign {
            assert!(format!("{outcome:?}").contains("sender"), "{outcome:?}");
        }
        assert!(matches!(runner.state(), JournalState::Prepared { .. }));
        assert_eq!(std::fs::read(path).unwrap(), prepared);
        assert!(fixture.control.lock().unwrap().broadcasts.is_empty());
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

/// A landing whose sidecar `blob::build` already verified runs KZG once more, in the pre-sign
/// gate; saving Prepared, Signed, Pending, Confirming and Idle verifies nothing (BATCH-6.3-13).
#[tokio::test]
async fn happy_path_verifies_kzg_once_before_signing_and_never_on_save() {
    let fixture = Fixture::new();
    let before = crate::blob::kzg_verifications();
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
    assert_eq!(crate::blob::kzg_verifications() - before, 1);
}

/// A restart validates its non-Idle journal, KZG included, exactly once.
#[tokio::test]
async fn restart_verifies_the_restored_job_once() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    }
    assert!(matches!(runner.state(), JournalState::Pending { .. }));
    drop(runner);
    let before = crate::blob::kzg_verifications();
    let resumed = fixture.runner();
    assert_eq!(crate::blob::kzg_verifications() - before, 1);
    assert!(matches!(resumed.state(), JournalState::Pending { .. }));
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
        fixture.compete(12);
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Rebuild);
        assert_eq!(runner.state(), &JournalState::Idle);
        assert_eq!(fixture.control.lock().unwrap().broadcasts.len(), 0);
    }
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    fixture.compete(12);
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

/// A confirmed revert with the checkpoint unchanged, out-of-gas included, stops the runner once,
/// with the journal already Idle, so the next run builds a fresh job instead of re-reading the
/// receipt; a revert a competing landing caused settles.
#[tokio::test]
async fn unchanged_checkpoint_revert_stops_once_but_competing_revert_can_settle() {
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
            assert!(matches!(outcome, Err(LanderError::Reverted(_))), "{outcome:?}");
            assert!(matches!(runner.state(), JournalState::Idle));
            drop(runner);
            assert!(matches!(fixture.runner().state(), JournalState::Idle), "persisted");
        }
        assert_eq!(fixture.control.lock().unwrap().signs, 1);
    }
}

#[tokio::test]
async fn expired_reference_revert_settles_and_lands_fresh_job_with_next_nonce() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    }
    let expired = pending_transaction(&runner);
    let trace = fixture.trace(|_| reference_unavailable_trace()).await;
    let reference_number = fixture.request.batch.input.l1ReferenceBlockNumber.to::<u64>();
    let receipt_number = reference_number + 8192;
    fixture.mine_at(&expired, false, receipt_number);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert!(trace.requests.lock().unwrap().is_empty());
    fixture.control.lock().unwrap().snapshot.l1_block_number += 1;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Settled);
    assert_eq!(runner.state(), &JournalState::Idle);
    let journal = fixture.directory.path().join("lander-state.json");
    let saved: serde_json::Value =
        serde_json::from_slice(&std::fs::read(journal).unwrap()).unwrap();
    assert_eq!(saved["state"]["phase"], "idle");
    {
        let requests = trace.requests.lock().unwrap();
        assert_eq!(requests.len(), 1);
        assert_eq!(requests[0]["method"], "debug_traceTransaction");
        assert_eq!(
            requests[0]["params"],
            json!([expired.hash, {
                "tracer": "callTracer", "tracerConfig": {"onlyTopCall": true},
            }])
        );
    }

    let mut fresh = fixture.request.clone();
    let reference = RawL1Header::from(&alloy_consensus::Header {
        number: receipt_number,
        ..Default::default()
    });
    fresh.batch.input.l1ReferenceBlockNumber = alloy_primitives::U256::from(receipt_number);
    fresh.batch.reference_headers = vec![reference.raw().clone()];
    fresh.batch.statement_hash = crate::statement::hash(
        &fresh.batch.snapshot,
        &fresh.batch.input,
        reference.hash(),
        &fresh.batch.blobs.versioned_hashes,
        &fresh.batch.leaves,
    );
    fixture.control.lock().unwrap().next_request = Some(fresh.clone());
    for _ in 0..3 {
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    }
    let rebuilt = pending_transaction(&runner);
    assert_eq!(rebuilt.nonce, expired.nonce + 1);
    rebuilt.validate(&fresh, &Bytes::from_static(&[0])).unwrap();
    fixture.mine_at(&rebuilt, true, receipt_number + 2);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    fixture.control.lock().unwrap().snapshot.l1_block_number += 1;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Settled);
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.signs, 2);
    assert_eq!(control.broadcasts, [expired.network_bytes, rebuilt.network_bytes]);
}

fn reference_unavailable_trace() -> Value {
    json!({"error": "execution reverted", "output": Bytes::copy_from_slice(&ReferenceBlockUnavailable::SELECTOR)})
}

#[tokio::test]
async fn expired_reference_does_not_recover_unknown_or_out_of_gas_reverts() {
    for (age, trace_response, trace_called) in [
        (8191, reference_unavailable_trace(), false),
        (8192, json!({"error": "out of gas"}), true),
        (8192, json!({"error": "execution reverted", "output": "0x12345678"}), true),
        (
            8192,
            json!({"error": "execution reverted", "calls": [reference_unavailable_trace()]}),
            true,
        ),
        (8192, json!({"__rpc_error": {"code": -32601, "message": "unsupported method"}}), true),
        (
            8192,
            json!({"__rpc_error": {"code": -32000, "message": "historical state is not available"}}),
            true,
        ),
        (
            8192,
            json!({"__rpc_error": {"code": -32000, "message": "required historical state unavailable (reexec=128)"}}),
            true,
        ),
    ] {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        for _ in 0..3 {
            runner.step().await.unwrap();
        }
        let trace = fixture.trace(move |_| trace_response.clone()).await;
        let tx = pending_transaction(&runner);
        let reference_number = fixture.request.batch.input.l1ReferenceBlockNumber.to::<u64>();
        fixture.mine_at(&tx, false, reference_number + age);
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
        fixture.control.lock().unwrap().snapshot.l1_block_number += 1;
        assert!(matches!(runner.step().await, Err(LanderError::Reverted(_))));
        assert_eq!(runner.state(), &JournalState::Idle);
        assert_eq!(trace.requests.lock().unwrap().len(), usize::from(trace_called));
        assert_eq!(fixture.control.lock().unwrap().signs, 1);
    }
}

#[tokio::test]
async fn expired_reference_trace_failure_or_reorg_keeps_the_pending_transaction() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let tx = pending_transaction(&runner);
    let reference_number = fixture.request.batch.input.l1ReferenceBlockNumber.to::<u64>();
    fixture.mine_at(&tx, false, reference_number + 8192);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    fixture.control.lock().unwrap().snapshot.l1_block_number += 1;
    let _unavailable = fixture
        .trace(|_| json!({"__rpc_error": {"code": -32000, "message": "temporarily unavailable"}}))
        .await;
    assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
    assert!(matches!(runner.state(), JournalState::Confirming { .. }));
    assert_eq!(pending_transaction(&runner), tx);

    let control = fixture.control.clone();
    let _reorg = fixture
        .trace(move |_| {
            control.lock().unwrap().canonical_receipt = B256::repeat_byte(31);
            reference_unavailable_trace()
        })
        .await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert!(matches!(runner.state(), JournalState::Pending { .. }));
    assert_eq!(pending_transaction(&runner), tx);
    assert_eq!(fixture.control.lock().unwrap().signs, 1);
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
async fn obsolete_pending_bytes_rebroadcast_after_restart_then_reverted_receipt_frees_nonce() {
    for before_first_send in [false, true] {
        for checkpoint in [0, 6, 12] {
            let fixture = Fixture::new();
            let (transaction, signs, previous_sends) = if before_first_send {
                let proof = Bytes::from_static(&[0]);
                let transaction = signed(&fixture.request, &proof, 0).await;
                let store = Store::open(fixture.directory.path(), fixture.identity()).unwrap();
                store
                    .save(&JournalState::Pending {
                        job: Box::new(ProvedJob { request: fixture.request.clone(), proof }),
                        transaction: transaction.clone(),
                    })
                    .unwrap();
                (transaction, 0, 0)
            } else {
                let mut runner = fixture.runner();
                for _ in 0..3 {
                    runner.step().await.unwrap();
                }
                (pending_transaction(&runner), 1, 1)
            };
            if checkpoint != 0 {
                fixture.compete(checkpoint);
            }
            {
                let mut control = fixture.control.lock().unwrap();
                control.reference_current = false;
                control.known = false;
                control.nonce =
                    NonceState { confirmed: transaction.nonce, pending: transaction.nonce };
                control.events.clear();
            }
            let journal = fixture.directory.path().join("lander-state.json");
            let original = std::fs::read(&journal).unwrap();
            let mut runner = fixture.runner();
            assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
            assert_eq!(pending_transaction(&runner), transaction);
            assert_eq!(std::fs::read(&journal).unwrap(), original);
            {
                let control = fixture.control.lock().unwrap();
                assert_eq!(control.events, vec!["receipt", "nonce", "known", "broadcast"]);
                assert_eq!(control.signs, signs);
                assert_eq!(control.broadcasts.len(), previous_sends + 1);
                assert!(control.broadcasts.iter().all(|bytes| bytes == &transaction.network_bytes));
            }
            fixture.mine(&transaction, false);
            assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
            fixture.control.lock().unwrap().snapshot.l1_block_number = 31;
            let outcome = runner.step().await;
            if checkpoint == 0 {
                assert!(matches!(outcome, Err(LanderError::Reverted(_))), "{outcome:?}");
            } else {
                assert_eq!(outcome.unwrap(), StepOutcome::Settled);
            }
            assert_eq!(runner.state(), &JournalState::Idle);
            drop(runner);
            assert_eq!(fixture.runner().state(), &JournalState::Idle);
            let control = fixture.control.lock().unwrap();
            assert_eq!(control.signs, signs);
            assert_eq!(control.nonce.confirmed, transaction.nonce + 1);
        }
    }
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
    for height in [6, 12] {
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
        assert_eq!(control.broadcasts.len(), 2);
    }
}

#[tokio::test]
async fn changed_checkpoint_config_hash_stops_before_signing() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    runner.step().await.unwrap();
    fixture.control.lock().unwrap().snapshot.config_hash = B256::ZERO;
    assert!(matches!(runner.step().await, Err(LanderError::Safety(_))));
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.signs, 0);
    assert_eq!(control.broadcasts.len(), 0);
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
    let original = waiting(&runner).unwrap();
    tokio::time::advance(Duration::from_secs(20)).await;
    {
        let mut control = fixture.control.lock().unwrap();
        control.publishable_blocks = 2;
        control.decided_height = 3;
    }
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(waiting(&runner), Some(original));
    tokio::time::advance(Duration::from_secs(9)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(1)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert!(matches!(runner.state(), JournalState::Prepared { .. }));
    assert_eq!(fixture.control.lock().unwrap().proofs, 1);
    assert!(waiting(&runner).is_none());
}

fn waiting(r: &Runner) -> Option<(super::CheckpointId, tokio::time::Instant)> {
    r.waiting
}

#[tokio::test(start_paused = true)]
async fn batch_wait_lives_in_memory_and_restarts_with_the_process() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    let mut first = fixture.with_policy(policy);
    assert_eq!(first.step().await.unwrap(), StepOutcome::Waiting);
    assert!(waiting(&first).is_some());
    tokio::time::advance(Duration::from_secs(25)).await;
    assert_eq!(first.step().await.unwrap(), StepOutcome::Waiting);
    drop(first);
    assert!(!fixture.directory.path().join("lander-state.json").exists(), "waiting writes nothing");
    let mut second = fixture.with_policy(policy);
    assert_eq!(second.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(29)).await;
    assert_eq!(second.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(1)).await;
    assert_eq!(second.step().await.unwrap(), StepOutcome::Progress);
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
    assert!(waiting(&runner).is_none());
}

#[tokio::test(start_paused = true)]
async fn incomplete_backlog_retains_its_timer_until_a_complete_prefix_is_available() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    fixture.control.lock().unwrap().publishable_blocks = 0;
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    let marker = waiting(&runner).unwrap();
    tokio::time::advance(Duration::from_secs(31)).await;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(fixture.control.lock().unwrap().prepares, 0);
    assert_eq!(waiting(&runner), Some(marker));
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
        let marker = waiting(&runner).unwrap();
        tokio::time::advance(Duration::from_secs(20)).await;
        {
            let mut control = fixture.control.lock().unwrap();
            control.observation_error = !checkpoint_error;
            control.checkpoint_error = checkpoint_error;
        }
        assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
        assert_eq!(waiting(&runner), Some(marker));
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
async fn empty_backlog_discards_the_prior_deadline() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 4, max_wait: Duration::from_secs(30) };
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    tokio::time::advance(Duration::from_secs(20)).await;
    fixture.control.lock().unwrap().decided_height = 0;
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert!(waiting(&runner).is_none());
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
            assert!(waiting(&runner).is_none());
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
async fn consensus_pressure_bypasses_high_threshold_and_long_wait() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 100, max_wait: Duration::from_secs(3600) };
    fixture.control.lock().unwrap().force_back_pressure = true;
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert!(matches!(runner.state(), JournalState::Prepared { .. }));
    assert_eq!(fixture.control.lock().unwrap().proofs, 1);
    assert!(waiting(&runner).is_none());
}

/// An exact end (`--land-to`) prepares at once below a threshold and wait it never reaches,
/// drops unsigned work that ends elsewhere, and `run` returns once its own landing settles at
/// the confirmation depth.
#[tokio::test(start_paused = true)]
async fn exact_end_skips_the_wait_drops_other_ends_and_run_returns_once_it_settles() {
    let fixture = Fixture::new();
    let end = fixture.request.batch.input.lastHeight.to::<u64>();
    let policy = BatchPolicy { min_blocks: 100, max_wait: Duration::from_secs(3600) };
    fixture.control.lock().unwrap().land_to = Some(end + 1);
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert!(matches!(runner.state(), JournalState::Prepared { .. }));
    // The prepared job ends at `end`, not at this run's exact end.
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Rebuild);
    assert_eq!(runner.state(), &JournalState::Idle);
    assert_eq!(fixture.control.lock().unwrap().signs, 0);
    fixture.control.lock().unwrap().land_to = Some(end);
    for _ in 0..3 {
        assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    }
    fixture.mine(&pending_transaction(&runner), true);
    fixture.control.lock().unwrap().snapshot.l1_block_number = 31;
    tokio::time::timeout(Duration::from_secs(60), runner.run())
        .await
        .expect("an exact run returns once its landing settles")
        .unwrap();
    assert_eq!(runner.state(), &JournalState::Idle);
    assert_eq!(fixture.control.lock().unwrap().broadcasts.len(), 1);
}

#[tokio::test(start_paused = true)]
async fn lower_prepared_tip_does_not_bypass_the_minimum_threshold() {
    let fixture = Fixture::new();
    let policy = BatchPolicy { min_blocks: 13, max_wait: Duration::from_secs(30) };
    fixture.control.lock().unwrap().publishable_blocks = 13;
    let mut runner = fixture.with_policy(policy);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(runner.state(), &JournalState::Idle);
    assert_eq!(fixture.control.lock().unwrap().proofs, 0);
    assert!(waiting(&runner).is_some());
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
    assert!(waiting(&runner).is_none());
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
async fn estimation_revert_discards_only_unsigned_work_so_restart_can_rebuild() {
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
            assert_eq!(runner.state(), &JournalState::Idle);
            let journal: serde_json::Value = serde_json::from_slice(
                &std::fs::read(fixture.directory.path().join("lander-state.json")).unwrap(),
            )
            .unwrap();
            assert_eq!(journal["state"]["phase"], "idle");
            drop(runner);
            fixture.control.lock().unwrap().estimate_revert = false;
            let mut resumed = fixture.runner();
            assert_eq!(resumed.step().await.unwrap(), StepOutcome::Progress);
            assert_eq!(fixture.control.lock().unwrap().prepares, 2);
            assert_eq!(resumed.step().await.unwrap(), StepOutcome::Progress);
            assert!(matches!(resumed.state(), JournalState::Signed { .. }));
        }
        assert_eq!(fixture.control.lock().unwrap().broadcasts.len(), 0);
    }
}

#[tokio::test]
async fn receipt_reconciliation_retries_an_orphaned_snapshot_without_discarding_signed_bytes() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let transaction = pending_transaction(&runner);
    fixture.mine(&transaction, true);
    runner.step().await.unwrap();
    let confirming = runner.state().clone();
    let path = fixture.directory.path().join("lander-state.json");
    let journal = std::fs::read(&path).unwrap();
    {
        let mut control = fixture.control.lock().unwrap();
        // The snapshot was read from the old block at height 31 before the receipt RPC observes
        // the replacement branch, where this transaction succeeded in block 30.
        control.snapshot.l1_block_number = 31;
        control.snapshot.l1_block_hash = B256::repeat_byte(31);
        control.snapshot.checkpoint_height = fixture.request.batch.snapshot.checkpoint_height;
        control.snapshot.checkpoint_hash = fixture.request.batch.snapshot.checkpoint_hash;
        control.canonical_snapshot = Some(B256::repeat_byte(32));
    }
    assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
    assert_eq!(runner.state(), &confirming);
    assert_eq!(std::fs::read(&path).unwrap(), journal);
    {
        let mut control = fixture.control.lock().unwrap();
        control.snapshot.l1_block_hash = B256::repeat_byte(32);
        control.snapshot.checkpoint_height = fixture.request.batch.input.lastHeight.to::<u64>();
        control.snapshot.checkpoint_hash = fixture.request.batch.input.lastBlockHash;
    }
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Settled);
    let control = fixture.control.lock().unwrap();
    assert_eq!((control.signs, control.broadcasts.len()), (1, 1));
}

#[tokio::test]
async fn successful_receipt_with_a_canonical_unchanged_checkpoint_remains_a_safety_stop() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let transaction = pending_transaction(&runner);
    fixture.mine(&transaction, true);
    runner.step().await.unwrap();
    {
        let mut control = fixture.control.lock().unwrap();
        control.snapshot.l1_block_number = 31;
        control.snapshot.checkpoint_height = fixture.request.batch.snapshot.checkpoint_height;
        control.snapshot.checkpoint_hash = fixture.request.batch.snapshot.checkpoint_hash;
    }
    assert!(matches!(runner.step().await, Err(LanderError::Safety(_))));
    assert!(matches!(runner.state(), JournalState::Confirming { .. }));
}

#[tokio::test]
async fn a_pending_nonce_below_confirmed_retries_without_rebroadcasting() {
    let fixture = Fixture::new();
    fixture.control.lock().unwrap().nonce = NonceState { confirmed: 4, pending: 4 };
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let pending = runner.state().clone();
    {
        let mut control = fixture.control.lock().unwrap();
        control.known = false;
        control.nonce.pending = 3;
    }
    assert!(matches!(runner.step().await, Err(LanderError::Temporary(_))));
    assert_eq!(runner.state(), &pending);
    let control = fixture.control.lock().unwrap();
    assert_eq!((control.signs, control.broadcasts.len()), (1, 1));
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

#[tokio::test]
async fn signed_restart_keeps_original_input_and_transaction_bytes() {
    for phase in 2..=4 {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        for _ in 0..phase.min(3) {
            runner.step().await.unwrap();
        }
        let original = match runner.state() {
            JournalState::Signed { transaction, .. } |
            JournalState::Pending { transaction, .. } => transaction.clone(),
            _ => panic!("signed phase"),
        };
        if phase == 4 {
            fixture.mine(&original, true);
            runner.step().await.unwrap();
        }
        drop(runner);
        let mut resumed = fixture.runner();
        resumed.step().await.unwrap();
        let (job, transaction) = match resumed.state() {
            JournalState::Pending { job, transaction } |
            JournalState::Confirming { job, transaction, .. } => (job, transaction),
            _ => panic!("retained signed phase"),
        };
        assert_eq!(job.request.batch.input, fixture.request.batch.input);
        assert_eq!(transaction, &original);
        assert_eq!(fixture.control.lock().unwrap().signs, 1);
    }
}

#[tokio::test]
async fn v1_partial_checkpoint_advance_retains_signed_bytes_across_restart() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    runner.step().await.unwrap();
    runner.step().await.unwrap();
    let original = match runner.state() {
        JournalState::Signed { job, transaction } => (job.clone(), transaction.clone()),
        _ => panic!("signed phase"),
    };
    drop(runner);
    {
        let mut control = fixture.control.lock().unwrap();
        control.snapshot.checkpoint_height = 6;
        control.snapshot.checkpoint_hash =
            abci::EtnaEnvelope::decode(&fixture.request.batch.blocks[5].block.data[0])
                .unwrap()
                .block
                .header
                .hash_slow();
        control.snapshot.checkpoint_comet_hash =
            B256::from_slice(fixture.request.batch.blocks[5].block.header.hash().as_bytes());
    }
    let mut runner = fixture.runner();
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    match runner.state() {
        JournalState::Pending { job, transaction } => {
            assert_eq!(job, &original.0);
            assert_eq!(transaction, &original.1);
        }
        _ => panic!("original signed overlapping job must become pending"),
    }
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.signs, 1);
    assert_eq!(control.proofs, 1);
    assert_eq!(control.broadcasts, vec![original.1.network_bytes]);
}

#[tokio::test]
async fn v1_completed_settlement_keeps_pending_nonce_across_restart_until_canonical_receipt() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let original = runner.state().clone();
    let transaction = match &original {
        JournalState::Pending { transaction, .. } => transaction.clone(),
        _ => panic!("pending"),
    };
    drop(runner);
    fixture.compete(12);
    {
        let mut control = fixture.control.lock().unwrap();
        control.known = false;
        control.nonce.pending = 0;
    }
    let mut runner = fixture.runner();
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(runner.state(), &original);
    assert_eq!(fixture.control.lock().unwrap().broadcasts.len(), 2);
    fixture.mine(&transaction, false);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    fixture.control.lock().unwrap().snapshot.l1_block_number = 31;
    runner.step().await.unwrap();
    assert_eq!(runner.state(), &JournalState::Idle);
    assert_eq!(fixture.control.lock().unwrap().signs, 1);
}

#[tokio::test]
async fn v1_overlap_identity_mutations_preserve_signed_journal_and_stop_broadcast() {
    for mutation in 0..3 {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        runner.step().await.unwrap();
        runner.step().await.unwrap();
        let original = runner.state().clone();
        let path = fixture.directory.path().join("lander-state.json");
        let bytes = std::fs::read(&path).unwrap();
        fixture.compete(6);
        {
            let mut control = fixture.control.lock().unwrap();
            match mutation {
                0 => control.snapshot.checkpoint_hash[0] ^= 1,
                1 => control.snapshot.checkpoint_comet_hash[0] ^= 1,
                2 => control.snapshot.forced_inclusion_head += 1,
                _ => unreachable!(),
            }
        }
        assert!(runner.step().await.is_err());
        assert_eq!(runner.state(), &original);
        assert_eq!(std::fs::read(&path).unwrap(), bytes);
        assert!(fixture.control.lock().unwrap().broadcasts.is_empty());
    }
}

/// Review focus 2 (LAND-6.1-4, ENC-A-34): a competing landing that moves c to p + 1, a height
/// never on the old grid, is checked against leaf index c - p - 1 = 0. The signed job still
/// overlaps, so it is broadcast unchanged instead of being rebuilt.
#[tokio::test]
async fn competing_landing_at_p_plus_1_keeps_the_signed_job() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    runner.step().await.unwrap();
    runner.step().await.unwrap();
    let JournalState::Signed { transaction, .. } = runner.state().clone() else {
        panic!("signed");
    };
    fixture.compete(1);
    runner.step().await.unwrap();
    assert_eq!(pending_transaction(&runner), transaction);
    let control = fixture.control.lock().unwrap();
    assert_eq!(control.signs, 1);
    assert_eq!(control.broadcasts, vec![transaction.network_bytes]);
}

/// A landed checkpoint c at any height inside the job's interval is accepted only when its
/// three-word record recomputes the job's cut leaf at index c - p - 1; at the job's own parent
/// height the record must be unchanged.
#[test]
fn overlap_recomputes_the_leaf_at_c() {
    let fixture = Fixture::new();
    let batch = &fixture.request.batch;
    for c in 1..12 {
        fixture.compete(c);
        let current = fixture.control.lock().unwrap().snapshot.clone();
        assert!(super::overlapping_frontier(&current, batch).unwrap(), "c = {c}");
        let mut changed = current.clone();
        changed.checkpoint_comet_hash[31] ^= 1;
        assert!(
            matches!(super::overlapping_frontier(&changed, batch), Err(LanderError::Safety(_))),
            "c = {c}"
        );
    }
    let mut parent = batch.snapshot.clone();
    assert!(super::overlapping_frontier(&parent, batch).unwrap());
    parent.checkpoint_comet_hash[31] ^= 1;
    assert!(matches!(super::overlapping_frontier(&parent, batch), Err(LanderError::Safety(_))));
}

#[tokio::test]
async fn recovery_reconciles_pending_nonce_before_new_comet_history() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let original = serde_json::to_vec(runner.state()).unwrap();
    {
        let mut c = fixture.control.lock().unwrap();
        c.snapshot.generation = 1;
        c.checkpoint_error = true;
        c.known = true;
    }
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
    assert_eq!(serde_json::to_vec(runner.state()).unwrap(), original);
    assert_eq!(fixture.control.lock().unwrap().signs, 1);
}

#[tokio::test]
async fn recovery_settles_old_canonical_success_after_checkpoint_rollback() {
    let fixture = Fixture::new();
    let mut runner = fixture.runner();
    for _ in 0..3 {
        runner.step().await.unwrap();
    }
    let tx = pending_transaction(&runner);
    fixture.mine(&tx, true);
    {
        let mut c = fixture.control.lock().unwrap();
        c.snapshot.generation = 1;
        c.snapshot.checkpoint_height = 0;
        c.snapshot.l1_block_number = 31;
    }
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Progress);
    assert_eq!(runner.step().await.unwrap(), StepOutcome::Settled);
}

#[tokio::test]
async fn recovery_preserves_each_journal_phase_and_single_sender_ownership() {
    for steps in 1..=4 {
        let fixture = Fixture::new();
        let mut runner = fixture.runner();
        for _ in 0..steps.min(3) {
            runner.step().await.unwrap();
        }
        if steps == 4 {
            let tx = pending_transaction(&runner);
            fixture.mine(&tx, true);
            runner.step().await.unwrap();
        }
        let original = serde_json::to_vec(runner.state()).unwrap();
        assert!(Store::open(fixture.directory.path(), fixture.identity()).is_err());
        drop(runner);
        let mut runner = fixture.runner();
        assert_eq!(serde_json::to_vec(runner.state()).unwrap(), original);
        {
            let mut c = fixture.control.lock().unwrap();
            c.snapshot.generation = 2;
            if steps == 4 {
                c.canonical_receipt = B256::repeat_byte(31);
            } else {
                c.receipt = None;
            }
            c.nonce = NonceState { confirmed: 0, pending: 1 };
        }
        let outcome = runner.step().await.unwrap();
        if steps <= 2 {
            assert_eq!(outcome, StepOutcome::Rebuild);
            assert!(matches!(runner.state(), JournalState::Idle));
        } else {
            if steps == 4 {
                assert_eq!(outcome, StepOutcome::Progress);
            }
            assert_eq!(runner.step().await.unwrap(), StepOutcome::Waiting);
            let restored_signed_bytes = pending_transaction(&runner).network_bytes;
            let saved: JournalState = serde_json::from_slice(&original).unwrap();
            let (original_job, original_tx) = match saved {
                JournalState::Pending { job, transaction } |
                JournalState::Confirming { job, transaction, .. } => (job, transaction),
                _ => unreachable!(),
            };
            let original_signed_bytes = original_tx.network_bytes;
            assert_eq!(restored_signed_bytes, original_signed_bytes);
            let JournalState::Pending { job, .. } = runner.state() else {
                panic!("nonce must remain owned")
            };
            assert_eq!(
                serde_json::to_vec(job).unwrap(),
                serde_json::to_vec(&original_job).unwrap()
            );
        }
        assert_eq!(fixture.control.lock().unwrap().prepares, 1);
        assert_eq!(fixture.control.lock().unwrap().signs, usize::from(steps > 1));
    }
}
