//! One-job, one-nonce polling loop with journal-first broadcast and canonical settlement.

use crate::{
    batch::BatchSource,
    config::BatchPolicy,
    error::{LanderError, Result},
    l1::LandingSource,
    metrics::{LanderMetrics, TransactionPhase},
    proof::{ProofError, ProofProvider},
    store::{JournalIdentity, JournalState, ProvedJob, Store},
    tx::{LandingReceipt, SignedTransaction, TransactionTransport},
    types::LandingSnapshot,
};
use alloy_primitives::{B256, U256};
use std::{sync::Arc, time::Duration};
use tokio::time::{Instant, timeout};

/// How long a consumed nonce may lack its own transaction's receipt before the account is treated
/// as shared. Execution clients index receipts after importing a block (geth asynchronously), so
/// the account nonce can advance moments before the receipt becomes queryable by hash.
const UNINDEXED_RECEIPT_GRACE: Duration = Duration::from_secs(30);

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
    /// Stale unbroadcast work was discarded after a competing checkpoint or reference change; the
    /// next job is re-estimated.
    Rebuild,
    /// One canonical transaction settled and the next job can start from L1.
    Settled,
}

/// Exact checkpoint a batch wait or a reverted landing is measured against.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct CheckpointId {
    /// Inbox recovery generation; recovery cannot inherit an earlier checkpoint's wait.
    generation: u64,
    /// Checkpoint height.
    height: u64,
    /// Checkpoint block hash; a same-height competing block is a different checkpoint.
    hash: B256,
}

impl CheckpointId {
    /// The checkpoint a coherent snapshot reads.
    fn of(snapshot: &LandingSnapshot) -> Self {
        Self {
            generation: snapshot.generation,
            height: snapshot.checkpoint_height,
            hash: snapshot.checkpoint_hash,
        }
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
    /// Checkpoint and monotonic start of this process's first backlog observation there; kept
    /// only in memory and only while the phase is Idle, so a restart starts the wait again.
    waiting: Option<(CheckpointId, Instant)>,
    /// Outstanding transaction whose nonce was first seen consumed without a receipt, and when.
    unindexed_receipt: Option<(B256, Instant)>,
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
        let state = store.load()?;
        observe_state(&state);
        Ok(Self {
            batches,
            l1,
            transactions,
            proofs,
            store,
            state,
            waiting: None,
            unindexed_receipt: None,
            config,
        })
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
                    if let LanderError::UnsupportedRuleset { rules } = &error {
                        tracing::warn!(
                            rules,
                            retry_seconds = retry_delay.as_secs_f64(),
                            "lander preparation paused; software upgrade required"
                        );
                    } else {
                        tracing::warn!(%error, retry_seconds=retry_delay.as_secs_f64(), "lander retrying classified temporary failure");
                    }
                    tokio::time::sleep(retry_delay).await;
                    retry_delay = retry_delay.saturating_mul(2).min(self.config.retry_max_delay);
                }
                Err(error) => return Err(error),
            }
        }
    }

    /// Poll no later than a pending backlog deadline, retaining ordinary polling once it expires.
    fn poll_delay(&self) -> Duration {
        if let Some((_, started)) = self.waiting {
            let remaining = self.config.batch_policy.max_wait.saturating_sub(started.elapsed());
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
        self.reconcile_wait_checkpoint(&snapshot);
        // A possibly broadcast transaction owns its nonce even while recovered Comet history
        // is unavailable. Its canonical receipt/account reconciliation precedes new work.
        let recovering_nonce = match &self.state {
            JournalState::Pending { job, .. } | JournalState::Confirming { job, .. } => {
                job.request.batch.snapshot.generation != snapshot.generation
            }
            _ => false,
        };
        if !recovering_nonce {
            self.batches.validate_checkpoint(&snapshot).await?;
        }
        tracing::debug!(
            landed_height = snapshot.checkpoint_height,
            l1_height = snapshot.l1_block_number,
            "lander coherent checkpoint"
        );
        match self.state.clone() {
            JournalState::Idle => {
                let preview = self.batches.observe(&snapshot).await?;
                let observation = preview.observation;
                if observation.decided_height <= snapshot.checkpoint_height {
                    self.clear_wait();
                    return Ok(StepOutcome::Waiting);
                }
                self.start_wait(&snapshot);
                let elapsed = self.wait_elapsed();
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
                let Some(request) = self.batches.prepare_observed(snapshot, preview).await? else {
                    self.clear_wait();
                    return Ok(StepOutcome::Waiting);
                };
                let elapsed = self.wait_elapsed();
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
                        // No signature or broadcast exists in Prepared. Persist the reset before
                        // stopping so corrected proof/batch settings can take effect on restart.
                        self.transition(JournalState::Idle)?;
                        return Err(error);
                    }
                    Err(error) => return Err(error),
                };
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
    fn reconcile_wait_checkpoint(&mut self, snapshot: &LandingSnapshot) {
        if self.waiting.is_some_and(|(checkpoint, _)| checkpoint != CheckpointId::of(snapshot)) {
            self.clear_wait();
        }
    }

    /// Start the wait at this process's first backlog observation at the current checkpoint.
    fn start_wait(&mut self, snapshot: &LandingSnapshot) {
        self.waiting.get_or_insert_with(|| (CheckpointId::of(snapshot), Instant::now()));
    }

    /// Age of the current wait, zero when none is running.
    fn wait_elapsed(&self) -> Duration {
        self.waiting.map_or(Duration::ZERO, |(_, started)| started.elapsed())
    }

    /// Clear a completed or replaced backlog timer without changing the transaction phase.
    fn clear_wait(&mut self) {
        self.waiting = None;
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

    /// Recheck checkpoint and reference before signing or scheduling a first broadcast. The job
    /// itself needs no recheck here: the builder checked it before proving, and the store reruns
    /// [`crate::types::PreparedBatch::verify_restored`] (shape, terminal Comet hash, reference
    /// number, statement hash and blob/KZG binding; not the proof witnesses) on every journal
    /// load and save.
    async fn unbroadcast_current(
        &self,
        snapshot: &LandingSnapshot,
        job: &ProvedJob,
    ) -> Result<bool> {
        let batch = &job.request.batch;
        if !overlapping_frontier(snapshot, batch)? {
            return Ok(false);
        }
        let (number, hash) = job_reference(batch)?;
        match self.l1.validate_reference(snapshot, number, hash).await {
            Ok(()) => Ok(true),
            Err(LanderError::Stale(_)) => Ok(false),
            Err(error) => Err(error),
        }
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
        if U256::from(snapshot.checkpoint_height) >= job.request.batch.input.lastHeight {
            tracing::info!(transaction_hash=%transaction.hash, pending_nonce=transaction.nonce,
                settlement_complete=true, "lander settlement complete; awaiting canonical nonce resolution");
        }
        let receipt =
            timeout(self.config.receipt_timeout, self.transactions.receipt(transaction.hash))
                .await
                .map_err(|_| LanderError::Temporary("receipt lookup deadline exceeded".into()))??;
        if let Some(receipt) = receipt {
            self.unindexed_receipt = None;
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
        nonce.validate()?;
        if nonce.confirmed > transaction.nonce {
            let first_seen = match self.unindexed_receipt {
                Some((hash, at)) if hash == transaction.hash => at,
                _ => {
                    let now = Instant::now();
                    self.unindexed_receipt = Some((transaction.hash, now));
                    now
                }
            };
            if first_seen.elapsed() < UNINDEXED_RECEIPT_GRACE {
                return Err(LanderError::Temporary(format!(
                    "nonce {} is mined but receipt {} is not indexed yet",
                    transaction.nonce, transaction.hash
                )));
            }
            return Err(LanderError::Safety(format!(
                "nonce {} is mined but receipt {} is still unavailable after {}s; stop to resolve shared-account nonce",
                transaction.nonce,
                transaction.hash,
                UNINDEXED_RECEIPT_GRACE.as_secs()
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
        if !overlapping_frontier(&snapshot, &job.request.batch)? {
            // Already-attempted bytes may still exist at another peer. Allocate no new nonce and
            // avoid spending gas rebroadcasting a job that the current checkpoint made obsolete.
            tracing::warn!(transaction_hash=%transaction.hash,pending_nonce=transaction.nonce,"lander outstanding nonce unresolved after competing checkpoint; operator reconciliation may be required");
            return Ok(StepOutcome::Waiting);
        }
        let (number, hash) = job_reference(&job.request.batch)?;
        if let Err(error) = self.l1.validate_reference(&snapshot, number, hash).await {
            if matches!(error, LanderError::Stale(_)) {
                tracing::warn!(transaction_hash=%transaction.hash,pending_nonce=transaction.nonce,"lander dropped transaction has expired reference; outstanding nonce requires operator reconciliation");
                return Ok(StepOutcome::Waiting);
            }
            return Err(error);
        }
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
        if self.l1.canonical_hash(snapshot.l1_block_number).await? != snapshot.l1_block_hash {
            return Err(LanderError::Temporary(
                "receipt reconciliation snapshot was reorganized; retry a coherent checkpoint"
                    .into(),
            ));
        }
        if receipt.success {
            if snapshot.generation == job.request.batch.snapshot.generation &&
                U256::from(snapshot.checkpoint_height) < job.request.batch.input.lastHeight
            {
                return Err(LanderError::Safety(
                    "successful canonical receipt did not advance the Inbox checkpoint".into(),
                ));
            }
        } else if CheckpointId::of(&snapshot) == CheckpointId::of(&job.request.batch.snapshot) {
            // The revert is canonical at the confirmation depth, so its nonce is spent and
            // nothing of this job can land any more. Every such revert, out-of-gas included,
            // stops the runner. Persist Idle first: a restart then rebuilds from the current
            // checkpoint (a deterministic revert stops again at gas estimation, before signing)
            // instead of re-reading this receipt forever.
            self.transition(JournalState::Idle)?;
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

/// Accept only an authenticated frontier on the immutable job's original proof interval.
/// Interior progress must equal the corresponding signed cut leaf; nothing is rewritten.
fn overlapping_frontier(
    current: &LandingSnapshot,
    batch: &crate::types::PreparedBatch,
) -> Result<bool> {
    let prepared = &batch.snapshot;
    if current.generation != prepared.generation ||
        current.checkpoint_height < prepared.checkpoint_height ||
        U256::from(current.checkpoint_height) >= batch.input.lastHeight
    {
        return Ok(false);
    }
    if current.genesis != prepared.genesis ||
        current.committee_config_hash != prepared.committee_config_hash
    {
        return Err(LanderError::Safety("landing genesis/config identity changed".into()));
    }
    if current.checkpoint_height == prepared.checkpoint_height {
        if current.checkpoint_hash != prepared.checkpoint_hash ||
            current.checkpoint_comet_hash != prepared.checkpoint_comet_hash ||
            current.checkpoint_val_state_hash != prepared.checkpoint_val_state_hash ||
            current.forced_inclusion_head != prepared.forced_inclusion_head
        {
            return Err(LanderError::Safety(
                "landing parent identity changed at the same height".into(),
            ));
        }
    } else {
        if !current.checkpoint_height.is_multiple_of(abci::GRID_INTERVAL) {
            return Err(LanderError::Safety("checkpoint is not a grid endpoint".into()));
        }
        let index =
            (current.checkpoint_height - prepared.checkpoint_height) / abci::GRID_INTERVAL - 1;
        let leaf = crate::statement::cut_leaf(
            current.checkpoint_height,
            current.checkpoint_hash,
            current.checkpoint_comet_hash,
            current.forced_inclusion_head,
            current.checkpoint_val_state_hash,
        );
        if batch.leaves.get(index as usize) != Some(&leaf) {
            return Err(LanderError::Safety(
                "overlapping checkpoint contradicts immutable cut leaf".into(),
            ));
        }
    }
    Ok(true)
}

/// The job's L1 reference: its input number and the hash of its newest reference header, which
/// the statement binds.
fn job_reference(batch: &crate::types::PreparedBatch) -> Result<(u64, B256)> {
    let reference = batch
        .reference_headers
        .first()
        .ok_or_else(|| LanderError::Journal("job has no reference header".into()))?;
    let raw = abci::l1::header::RawL1Header::from_raw(reference.clone())
        .map_err(|e| LanderError::Journal(format!("job reference header: {e}")))?;
    Ok((crate::types::protocol_u48(batch.input.l1ReferenceBlockNumber)?, raw.hash()))
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
