//! One-job, one-nonce polling loop with journal-first broadcast and canonical settlement.

use crate::{
    batch::BatchSource,
    config::BatchPolicy,
    error::{LanderError, Result},
    l1::LandingSource,
    metrics::{LanderMetrics, TransactionPhase},
    proof::{ProofError, ProofProvider},
    store::{BatchWait, JournalIdentity, JournalState, ProvedJob, Store},
    tx::{LandingReceipt, SignedTransaction, TransactionTransport},
    types::LandingSnapshot,
};
use std::{
    sync::Arc,
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tokio::time::{Instant, timeout};

/// Runtime deadlines and confirmation policy; transport reads also retain their HTTP deadlines.
#[derive(Clone, Copy, Debug)]
pub struct RunnerConfig {
    /// Minimum complete-prefix size or maximum first-backlog wait before preparing a batch.
    pub batch_policy: BatchPolicy,
    /// Normal polling interval, including idle and known-pending waits.
    pub poll_interval: Duration,
    /// One proof-provider invocation's deadline.
    pub proof_timeout: Duration,
    /// Signing or broadcast deadline; an expired broadcast is always ambiguous.
    pub broadcast_timeout: Duration,
    /// Receipt/nonce/transaction lookup deadline per reconciliation operation.
    pub receipt_timeout: Duration,
    /// Required canonical depth, counting the containing block as confirmation one.
    pub confirmations: u64,
    /// Upper bound of exponential transport retry delay.
    pub retry_max_delay: Duration,
}

impl RunnerConfig {
    /// Refuse unbounded, zero-duration loops or an undefined confirmation depth.
    pub fn validate(&self) -> Result<()> {
        self.batch_policy.validate()?;
        if self.poll_interval.is_zero() ||
            self.proof_timeout.is_zero() ||
            self.broadcast_timeout.is_zero() ||
            self.receipt_timeout.is_zero() ||
            self.retry_max_delay < self.poll_interval ||
            self.confirmations == 0
        {
            return Err(LanderError::Configuration(
                "runner requires nonzero deadlines/confirmations and retry cap >= poll interval"
                    .into(),
            ));
        }
        Ok(())
    }
}

/// Observable outcome of one durable state-machine increment.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StepOutcome {
    /// No complete batch or receipt is available yet.
    Waiting,
    /// Proof, signature, pending phase, or confirmation context became durable.
    Progress,
    /// Stale unbroadcast work was discarded after a competing checkpoint or reference change.
    Rebuild,
    /// One canonical transaction settled and the next job can start from L1.
    Settled,
}

/// Durable backlog identity plus monotonic age, independent of arrivals and RPC retries.
struct BatchWaiting {
    /// Checkpoint identity and wall time restored from the Idle journal.
    marker: BatchWait,
    /// Already elapsed wall time at startup; later clock changes cannot extend the wait.
    restored_elapsed: Duration,
    /// Monotonic start of this process's contribution to backlog age.
    started_at: Instant,
}

impl BatchWaiting {
    /// Elapsed age including downtime and this process's monotonic runtime.
    fn elapsed(&self) -> Duration {
        self.restored_elapsed.saturating_add(self.started_at.elapsed())
    }

    /// Check whether a coherent checkpoint can retain the existing first-backlog observation.
    fn matches(&self, snapshot: &LandingSnapshot) -> bool {
        self.marker.checkpoint_height == snapshot.checkpoint_height &&
            self.marker.checkpoint_hash == snapshot.checkpoint_hash &&
            self.marker.generation == snapshot.generation
    }
}

/// Independently runnable lander. Dropping `run` leaves the durable phase resumable.
pub struct Runner {
    /// I/O-free validation plus bounded collectors, behind an injectable builder interface.
    batches: Arc<dyn BatchSource>,
    /// Coherent checkpoint/ref ancestry source.
    l1: Arc<dyn LandingSource>,
    /// One configured signer; no automatic transaction replacement.
    transactions: Arc<dyn TransactionTransport>,
    /// The first implementation's dummy provider can later be replaced without changing inputs.
    proofs: Arc<dyn ProofProvider>,
    /// Exclusively owned atomic journal.
    store: Store,
    /// Current phase, mirrored on disk at every network mutation boundary.
    state: JournalState,
    /// First local backlog age; present only while the durable phase is Idle.
    waiting: Option<BatchWaiting>,
    /// Time and confirmation bounds.
    config: RunnerConfig,
}

impl Runner {
    /// Resume a fully validated journal; no broadcast or signing occurs during construction.
    pub fn new(
        batches: Arc<dyn BatchSource>,
        l1: Arc<dyn LandingSource>,
        transactions: Arc<dyn TransactionTransport>,
        proofs: Arc<dyn ProofProvider>,
        store: Store,
        config: RunnerConfig,
    ) -> Result<Self> {
        config.validate()?;
        if transactions.sender() != store.identity().sender {
            return Err(LanderError::Journal(
                "configured signer differs from journal sender".into(),
            ));
        }
        let (state, marker) = store.load_with_wait()?;
        let waiting = if let Some(mut marker) = marker {
            let now_unix_ms = unix_milliseconds()?;
            if marker.first_seen_unix_ms > now_unix_ms {
                // Persist the clamp so a future timestamp cannot restart the full wait forever.
                marker.first_seen_unix_ms = now_unix_ms;
                store.save_with_wait(&state, Some(&marker))?;
            }
            Some(BatchWaiting {
                restored_elapsed: Duration::from_millis(now_unix_ms - marker.first_seen_unix_ms),
                marker,
                started_at: Instant::now(),
            })
        } else {
            None
        };
        observe_state(&state);
        Ok(Self { batches, l1, transactions, proofs, store, state, waiting, config })
    }

    /// Current durable phase, useful for supervision and deterministic crash tests.
    pub fn state(&self) -> &JournalState {
        &self.state
    }

    /// Run until the caller's shutdown handling drops this future, or a fatal safety error occurs.
    pub async fn run(&mut self) -> Result<()> {
        let mut retry_delay = self.config.poll_interval;
        loop {
            match self.step().await {
                Ok(outcome) => {
                    retry_delay = self.config.poll_interval;
                    if outcome != StepOutcome::Progress {
                        tokio::time::sleep(self.poll_delay()).await;
                    }
                }
                Err(error) if error.is_retryable() => {
                    LanderMetrics::retry(&error);
                    tracing::warn!(%error, retry_seconds=retry_delay.as_secs_f64(), "lander retrying classified temporary failure");
                    tokio::time::sleep(retry_delay).await;
                    retry_delay = retry_delay.saturating_mul(2).min(self.config.retry_max_delay);
                }
                Err(error) => return Err(error),
            }
        }
    }

    /// Poll no later than a pending backlog deadline, retaining ordinary polling once it expires.
    fn poll_delay(&self) -> Duration {
        if let Some(waiting) = &self.waiting {
            let remaining = self.config.batch_policy.max_wait.saturating_sub(waiting.elapsed());
            if !remaining.is_zero() {
                return self.config.poll_interval.min(remaining);
            }
        }
        self.config.poll_interval
    }

    /// One state transition; signing and broadcasting cannot precede their durable prerequisites.
    pub async fn step(&mut self) -> Result<StepOutcome> {
        let snapshot = self.l1.snapshot().await?;
        self.validate_identity(&snapshot)?;
        self.reconcile_wait_checkpoint(&snapshot)?;
        self.batches.validate_checkpoint(&snapshot).await?;
        tracing::debug!(
            landed_height = snapshot.checkpoint_height,
            l1_height = snapshot.l1_block_number,
            "lander coherent checkpoint"
        );
        match self.state.clone() {
            JournalState::Idle => {
                let observation = self.batches.observe(&snapshot).await?;
                if observation.decided_height <= snapshot.checkpoint_height {
                    self.clear_wait()?;
                    return Ok(StepOutcome::Waiting);
                }
                self.start_wait(&snapshot)?;
                let elapsed = self.waiting.as_ref().map_or(Duration::ZERO, BatchWaiting::elapsed);
                tracing::debug!(
                    decided_height = observation.decided_height,
                    publishable_blocks = observation.publishable_blocks,
                    wait_seconds = elapsed.as_secs_f64(),
                    minimum_blocks = self.config.batch_policy.min_blocks,
                    maximum_wait_seconds = self.config.batch_policy.max_wait.as_secs_f64(),
                    "lander observing batch backlog"
                );
                if observation.publishable_blocks == 0 ||
                    (observation.publishable_blocks < self.config.batch_policy.min_blocks &&
                        elapsed < self.config.batch_policy.max_wait &&
                        !observation.force_backpressure &&
                        !observation.force_epoch)
                {
                    return Ok(StepOutcome::Waiting);
                }
                let Some(request) = self.batches.prepare(snapshot).await? else {
                    self.clear_wait()?;
                    return Ok(StepOutcome::Waiting);
                };
                let elapsed = self.waiting.as_ref().map_or(Duration::ZERO, BatchWaiting::elapsed);
                if request.batch.blocks.len() < self.config.batch_policy.min_blocks &&
                    elapsed < self.config.batch_policy.max_wait &&
                    !observation.force_backpressure &&
                    !observation.force_epoch
                {
                    // The decided tip can regress between observation and full construction.
                    return Ok(StepOutcome::Waiting);
                }
                let trigger = if observation.force_backpressure {
                    "backpressure"
                } else if observation.force_epoch {
                    "epoch"
                } else if request.batch.blocks.len() >= self.config.batch_policy.min_blocks {
                    "minimum"
                } else {
                    "timeout"
                };
                tracing::info!(
                    trigger,
                    batch_blocks = request.batch.blocks.len(),
                    wait_seconds = elapsed.as_secs_f64(),
                    "lander batch collection threshold reached"
                );
                LanderMetrics::batch(
                    request.batch.blocks.len(),
                    request.batch.blobs.versioned_hashes.len(),
                    request.batch.blobs.payload_bytes,
                );
                tracing::info!(statement=%request.batch.statement_hash,batch_blocks=request.batch.blocks.len(),blob_count=request.batch.blobs.versioned_hashes.len(),"lander requesting configured proof provider");
                let proof = timeout(self.config.proof_timeout, self.proofs.prove(&request))
                    .await
                    .map_err(|_| LanderError::Temporary("proof provider deadline exceeded".into()))?
                    .map_err(proof_error)?;
                self.transition(JournalState::Prepared {
                    job: Box::new(ProvedJob { request, proof }),
                })?;
                Ok(StepOutcome::Progress)
            }
            JournalState::Prepared { job } => {
                if !self.unbroadcast_current(&snapshot, &job).await? {
                    return self.rebuild();
                }
                let signed = timeout(
                    self.config.broadcast_timeout,
                    self.transactions.sign(&job.request, &job.proof),
                )
                .await
                .map_err(|_| {
                    LanderError::Temporary("transaction signing deadline exceeded".into())
                })?;
                let transaction = match signed {
                    Ok(transaction) => transaction,
                    Err(error @ LanderError::Reverted(_)) => {
                        // A checkpoint can advance after the pre-sign check but before estimation.
                        // Refresh coherently before treating rejection of an obsolete job as fatal.
                        let fresh = self.l1.snapshot().await?;
                        self.validate_identity(&fresh)?;
                        self.batches.validate_checkpoint(&fresh).await?;
                        if !self.unbroadcast_current(&fresh, &job).await? {
                            return self.rebuild();
                        }
                        return Err(error);
                    }
                    Err(error) => return Err(error),
                };
                transaction.validate(&job.request, &job.proof)?;
                self.transition(JournalState::Signed { job, transaction })?;
                Ok(StepOutcome::Progress)
            }
            JournalState::Signed { job, transaction } => {
                if !self.unbroadcast_current(&snapshot, &job).await? {
                    return self.rebuild();
                }
                // The durable pending phase precedes even an attempted send, so a crash or timeout
                // cannot cause startup to treat an ambiguous send as unbroadcast work.
                self.transition(JournalState::Pending { job, transaction: transaction.clone() })?;
                self.broadcast(&transaction).await?;
                Ok(StepOutcome::Progress)
            }
            JournalState::Pending { job, transaction } => {
                self.pending(snapshot, job, transaction).await
            }
            JournalState::Confirming { job, transaction, receipt } => {
                self.confirming(snapshot, job, transaction, receipt).await
            }
        }
    }

    /// Persist before changing memory, so a failed fsync/rename stops all dependent operations.
    fn transition(&mut self, state: JournalState) -> Result<()> {
        self.store.save(&state)?;
        observe_state(&state);
        self.state = state;
        self.waiting = None;
        Ok(())
    }

    /// Discard an old timer before subsequent checkpoint/observation reads can fail transiently.
    fn reconcile_wait_checkpoint(&mut self, snapshot: &LandingSnapshot) -> Result<()> {
        if self.waiting.as_ref().is_some_and(|waiting| !waiting.matches(snapshot)) {
            self.clear_wait()?;
        }
        Ok(())
    }

    /// Persist the first nonempty local backlog observation before any batch construction.
    fn start_wait(&mut self, snapshot: &LandingSnapshot) -> Result<()> {
        if self.waiting.is_none() {
            let marker = BatchWait {
                checkpoint_height: snapshot.checkpoint_height,
                checkpoint_hash: snapshot.checkpoint_hash,
                generation: snapshot.generation,
                first_seen_unix_ms: unix_milliseconds()?,
            };
            self.store.save_with_wait(&self.state, Some(&marker))?;
            self.waiting = Some(BatchWaiting {
                marker,
                restored_elapsed: Duration::ZERO,
                started_at: Instant::now(),
            });
        }
        Ok(())
    }

    /// Clear a completed or replaced backlog timer without changing the transaction phase.
    fn clear_wait(&mut self) -> Result<()> {
        if self.waiting.is_some() {
            self.store.save(&self.state)?;
            self.waiting = None;
        }
        Ok(())
    }

    /// The fresh source must preserve every configured statement identity.
    fn validate_identity(&self, snapshot: &LandingSnapshot) -> Result<()> {
        let JournalIdentity { l1_chain_id, l2_chain_id, inbox, registry, .. } =
            self.store.identity();
        if snapshot.l1_chain_id != *l1_chain_id ||
            snapshot.l2_chain_id != *l2_chain_id ||
            snapshot.inbox != *inbox ||
            snapshot.registry != *registry
        {
            return Err(LanderError::Configuration(
                "fresh RPC snapshot differs from journal chain/contract identities".into(),
            ));
        }
        Ok(())
    }

    /// Recheck checkpoint and reference before signing or scheduling a first broadcast.
    async fn unbroadcast_current(
        &self,
        snapshot: &LandingSnapshot,
        job: &ProvedJob,
    ) -> Result<bool> {
        if !same_parent(snapshot, &job.request.batch.snapshot) {
            return Ok(false);
        }
        let batch = &job.request.batch;
        if snapshot.genesis != batch.snapshot.genesis ||
            snapshot.committee_config_hash != batch.snapshot.committee_config_hash
        {
            return Err(LanderError::Safety(
                "unchanged checkpoint has changed genesis or committee identity".into(),
            ));
        }
        let reference = batch
            .reference_headers
            .first()
            .ok_or_else(|| LanderError::Journal("job has no reference header".into()))?;
        let raw = abci::l1::header::RawL1Header::from_raw(reference.clone())
            .map_err(|e| LanderError::Journal(format!("reference header: {e}")))?;
        match self
            .l1
            .validate_reference(snapshot, batch.input.l1ReferenceBlockNumber, raw.hash())
            .await
        {
            Ok(()) => {
                self.crosscheck(snapshot, job, raw.hash()).await?;
                Ok(true)
            }
            Err(LanderError::Stale(_)) => Ok(false),
            Err(error) => Err(error),
        }
    }

    /// Detect contract implementation/configuration drift before signing or sending immutable
    /// bytes.
    async fn crosscheck(
        &self,
        snapshot: &LandingSnapshot,
        job: &ProvedJob,
        reference_hash: alloy_primitives::B256,
    ) -> Result<()> {
        let batch = &job.request.batch;
        let contract_hash = self
            .l1
            .statement_hash(snapshot, &batch.input, reference_hash, &batch.blobs.versioned_hashes)
            .await?;
        if contract_hash != batch.statement_hash {
            return Err(LanderError::Configuration(
                "fresh Inbox proxy statement helper differs from immutable job".into(),
            ));
        }
        Ok(())
    }

    /// Drop only work whose signed bytes have never been scheduled for broadcast.
    fn rebuild(&mut self) -> Result<StepOutcome> {
        self.transition(JournalState::Idle)?;
        Ok(StepOutcome::Rebuild)
    }

    /// Bounded submission of bytes that already exist in the committed pending journal.
    async fn broadcast(&self, transaction: &SignedTransaction) -> Result<()> {
        let hash = timeout(self.config.broadcast_timeout, self.transactions.broadcast(transaction))
            .await
            .map_err(|_| {
                LanderError::Temporary(format!(
                    "ambiguous broadcast timeout for {} nonce {}",
                    transaction.hash, transaction.nonce
                ))
            })??;
        if hash != transaction.hash {
            return Err(LanderError::Safety("broadcast hash differs from signed journal".into()));
        }
        tracing::info!(transaction_hash=%transaction.hash,pending_nonce=transaction.nonce,"lander broadcast persisted blob transaction");
        Ok(())
    }

    /// Reconcile a receipt first, then both nonce views, then exact transaction presence.
    async fn pending(
        &mut self,
        snapshot: LandingSnapshot,
        job: Box<ProvedJob>,
        transaction: SignedTransaction,
    ) -> Result<StepOutcome> {
        let receipt =
            timeout(self.config.receipt_timeout, self.transactions.receipt(transaction.hash))
                .await
                .map_err(|_| LanderError::Temporary("receipt lookup deadline exceeded".into()))??;
        if let Some(receipt) = receipt {
            if receipt.transaction_hash != transaction.hash {
                return Err(LanderError::Safety(
                    "receipt identifies a different transaction".into(),
                ));
            }
            if self.l1.canonical_hash(receipt.block_number).await? == receipt.block_hash {
                self.transition(JournalState::Confirming { job, transaction, receipt })?;
                return Ok(StepOutcome::Progress);
            }
            // A stale receipt returned after a reorg must not authorize nonce settlement.
            tracing::warn!(transaction_hash=%transaction.hash,"lander ignoring orphaned receipt");
        }
        let nonce =
            timeout(self.config.receipt_timeout, self.transactions.nonce_state()).await.map_err(
                |_| LanderError::Temporary("nonce reconciliation deadline exceeded".into()),
            )??;
        if nonce.confirmed > transaction.nonce {
            return Err(LanderError::Safety(format!(
                "nonce {} is mined but receipt {} is unavailable; stop to resolve shared-account nonce",
                transaction.nonce, transaction.hash
            )));
        }
        if nonce.confirmed < transaction.nonce {
            return Err(LanderError::Temporary(format!(
                "waiting for earlier account nonces before nonce {}",
                transaction.nonce
            )));
        }
        let known = timeout(self.config.receipt_timeout, self.transactions.known(transaction.hash))
            .await
            .map_err(|_| LanderError::Temporary("transaction lookup deadline exceeded".into()))??;
        if known || nonce.pending > transaction.nonce {
            tracing::info!(transaction_hash=%transaction.hash,pending_nonce=transaction.nonce,"lander waiting for outstanding nonce; no fee replacement");
            return Ok(StepOutcome::Waiting);
        }
        if !same_parent(&snapshot, &job.request.batch.snapshot) {
            // Already-attempted bytes may still exist at another peer. Allocate no new nonce and
            // avoid spending gas rebroadcasting a job that the current checkpoint made obsolete.
            tracing::warn!(transaction_hash=%transaction.hash,pending_nonce=transaction.nonce,"lander outstanding nonce unresolved after competing checkpoint; operator reconciliation may be required");
            return Ok(StepOutcome::Waiting);
        }
        let reference =
            job.request.batch.reference_headers.first().ok_or_else(|| {
                LanderError::Journal("pending job has no reference header".into())
            })?;
        let raw = abci::l1::header::RawL1Header::from_raw(reference.clone())
            .map_err(|e| LanderError::Journal(format!("pending reference: {e}")))?;
        if let Err(error) = self
            .l1
            .validate_reference(
                &snapshot,
                job.request.batch.input.l1ReferenceBlockNumber,
                raw.hash(),
            )
            .await
        {
            if matches!(error, LanderError::Stale(_)) {
                tracing::warn!(transaction_hash=%transaction.hash,pending_nonce=transaction.nonce,"lander dropped transaction has expired reference; outstanding nonce requires operator reconciliation");
                return Ok(StepOutcome::Waiting);
            }
            return Err(error);
        }
        self.crosscheck(&snapshot, &job, raw.hash()).await?;
        self.broadcast(&transaction).await?;
        Ok(StepOutcome::Waiting)
    }

    /// Confirm canonical inclusion and compatible checkpoint progress, including receipt reorgs.
    async fn confirming(
        &mut self,
        snapshot: LandingSnapshot,
        job: Box<ProvedJob>,
        transaction: SignedTransaction,
        receipt: LandingReceipt,
    ) -> Result<StepOutcome> {
        let observed =
            timeout(self.config.receipt_timeout, self.transactions.receipt(transaction.hash))
                .await
                .map_err(|_| {
                    LanderError::Temporary("confirming receipt lookup deadline exceeded".into())
                })??;
        let Some(observed) = observed else {
            self.transition(JournalState::Pending { job, transaction })?;
            return Ok(StepOutcome::Progress);
        };
        if observed.transaction_hash != transaction.hash {
            return Err(LanderError::Safety(
                "confirming lookup returned another transaction's receipt".into(),
            ));
        }
        if observed != receipt {
            if self.l1.canonical_hash(observed.block_number).await? == observed.block_hash {
                self.transition(JournalState::Confirming { job, transaction, receipt: observed })?;
            } else {
                self.transition(JournalState::Pending { job, transaction })?;
            }
            return Ok(StepOutcome::Progress);
        }
        if self.l1.canonical_hash(receipt.block_number).await? != receipt.block_hash {
            self.transition(JournalState::Pending { job, transaction })?;
            return Ok(StepOutcome::Progress);
        }
        let Some(required) = receipt.block_number.checked_add(self.config.confirmations - 1) else {
            return Err(LanderError::Configuration(
                "confirmation depth overflows block number".into(),
            ));
        };
        LanderMetrics::confirmations(
            snapshot.l1_block_number.saturating_sub(receipt.block_number).saturating_add(1),
        );
        if snapshot.l1_block_number < required {
            return Ok(StepOutcome::Waiting);
        }
        if receipt.success {
            if snapshot.checkpoint_height < job.request.batch.input.lastHeight {
                return Err(LanderError::Safety(
                    "successful canonical receipt did not advance the Inbox checkpoint".into(),
                ));
            }
        } else if same_parent(&snapshot, &job.request.batch.snapshot) {
            return Err(LanderError::Reverted(format!(
                "{} at nonce {} with unchanged checkpoint {}",
                transaction.hash, transaction.nonce, snapshot.checkpoint_height
            )));
        }
        tracing::info!(transaction_hash=%transaction.hash,landed_height=snapshot.checkpoint_height,success=receipt.success,"lander canonical transaction settled");
        self.transition(JournalState::Idle)?;
        Ok(StepOutcome::Settled)
    }
}

/// Capture a portable wall timestamp for restart continuity; in-process waiting is monotonic.
fn unix_milliseconds() -> Result<u64> {
    let elapsed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| LanderError::Journal(format!("wall clock precedes Unix epoch: {e}")))?;
    u64::try_from(elapsed.as_millis())
        .map_err(|_| LanderError::Journal("wall clock milliseconds exceed journal range".into()))
}

/// Publish restored as well as newly committed phases without exposing transaction identifiers.
fn observe_state(state: &JournalState) {
    let (phase, nonce) = match state {
        JournalState::Idle => (TransactionPhase::Idle, None),
        JournalState::Prepared { .. } => (TransactionPhase::Prepared, None),
        JournalState::Signed { transaction, .. } => {
            (TransactionPhase::Signed, Some(transaction.nonce))
        }
        JournalState::Pending { transaction, .. } => {
            (TransactionPhase::Pending, Some(transaction.nonce))
        }
        JournalState::Confirming { transaction, .. } => {
            (TransactionPhase::Confirming, Some(transaction.nonce))
        }
    };
    LanderMetrics::transaction(phase, nonce);
    if phase == TransactionPhase::Idle {
        LanderMetrics::confirmations(0);
    }
}

/// A changed generation, partial checkpoint advance, full advance, or rollback invalidates a job.
fn same_parent(current: &LandingSnapshot, prepared: &LandingSnapshot) -> bool {
    current.generation == prepared.generation &&
        current.checkpoint_height == prepared.checkpoint_height &&
        current.checkpoint_hash == prepared.checkpoint_hash
}

/// Preserve backend retryability without treating rejected proofs as temporary transport failures.
fn proof_error(error: ProofError) -> LanderError {
    match error {
        ProofError::Temporary(reason) => LanderError::Temporary(reason),
        ProofError::Rejected(reason) => {
            LanderError::Safety(format!("proof provider rejected immutable job: {reason}"))
        }
    }
}

#[cfg(test)]
#[path = "test_utils/runtime_runner.rs"]
mod tests;
