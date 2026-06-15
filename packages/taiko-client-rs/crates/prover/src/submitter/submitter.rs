//! The proof submitter pipeline: request proofs, route them into per-type
//! buffers/caches, aggregate, and submit `Inbox.prove` transactions
//! (Go `proof_submitter/proof_submitter.go`).
//!
//! The RPC-free routing/aggregation core lives in [`Pipeline`] so it can be
//! unit-tested without a live node; [`ProofSubmitter`] adds the RPC and
//! tx-manager touchpoints around it.

use std::{
    collections::HashMap,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy::{eips::BlockNumberOrTag, providers::Provider};
use alloy_primitives::{Address, B256, U256};
use base_tx_manager::{SimpleTxManager, TxManager};
use rpc::{RpcClientError, client::ClientWithWallet};
use tokio::sync::mpsc::Sender;

use crate::{
    buffer::ProofBuffer,
    cache::{CacheError, ProofCache},
    config::ProverConfigs,
    error::{ProverError, Result},
    metrics::ProverMetrics,
    producer::{BatchProofs, ProofProducer, ProofRequest, ProofResponse},
    raiko::{ProofType, RaikoError},
    submitter::transaction::{BuildProveTxInput, build_prove_batches_tx},
};

/// Maximum time a single proof request keeps trying the ZK path before it falls
/// back to SGX (Go `proof_submitter/interface.go` `maxProofRequestTimeout`).
const MAX_PROOF_REQUEST_TIMEOUT: Duration = Duration::from_secs(3_600);

/// Interval between core-state polls while waiting for a parent transition to
/// finalize (Go uses `chainiterator.DefaultRetryInterval` = 12s).
const TRANSITION_POLL_INTERVAL: Duration = Duration::from_secs(12);

/// Maximum time [`ProofSubmitter::wait_transition_verified`] blocks before
/// returning a transient error so the submit op re-validates the batch and then
/// waits again (Go bounds the wait with `rpc.DefaultRpcTimeout` = 1 minute).
const TRANSITION_WAIT_TIMEOUT: Duration = Duration::from_secs(60);

/// Minimal per-proposal info captured from a `Proposed` event; the submitter
/// enriches it into a full [`ProofRequest`] before proving.
#[derive(Debug, Clone)]
pub struct ProofRequestMeta {
    /// Proposal id.
    pub proposal_id: u64,
    /// Proposer (the designated prover under Shasta).
    pub proposer: Address,
    /// Timestamp of the L1 block containing the `Proposed` event.
    pub proposal_timestamp: u64,
    /// L1 block number containing the `Proposed` event.
    pub event_l1_block_number: u64,
    /// L1 block hash containing the `Proposed` event (reorg sentinel).
    pub event_l1_block_hash: B256,
}

impl ProofRequestMeta {
    /// Recover the originating meta from an enriched [`ProofRequest`] (used to
    /// re-queue a request after a failed submission).
    fn from_request(request: &ProofRequest) -> Self {
        Self {
            proposal_id: request.proposal_id,
            proposer: request.proposer,
            proposal_timestamp: request.proposal_timestamp,
            event_l1_block_number: request.event_l1_block_number,
            event_l1_block_hash: request.event_l1_block_hash,
        }
    }
}

/// Channel endpoints the submitter publishes to; the orchestrator owns the
/// matching receivers (Go's prover channel set, `prover.go:59-66`).
#[derive(Debug, Clone)]
pub struct SubmitterChannels {
    /// Completed aggregations ready for L1 submission.
    pub batch_proofs_tx: Sender<BatchProofs>,
    /// "Buffer ready" nudges, keyed by proof type.
    pub aggregation_notify_tx: Sender<ProofType>,
    /// Re-request channel for resends after failed submissions.
    pub proof_request_tx: Sender<ProofRequestMeta>,
    /// Cache-flush nudges, keyed by proof type.
    pub flush_cache_tx: Sender<ProofType>,
}

/// Runtime knobs the submitter needs (subset of [`ProverConfigs`]).
#[derive(Debug, Clone)]
pub struct SubmitterConfig {
    /// raiko polling interval.
    pub proof_polling_interval: Duration,
    /// Force aggregation of a non-empty buffer after this interval elapses.
    pub force_batch_proving_interval: Duration,
    /// Allowed proving range above last finalized (0 = unlimited).
    pub proposal_window_size: u64,
    /// Maximum proposal distance above last finalized for which a ZK proof is
    /// requested; beyond it the prover falls back to the base proof.
    pub max_zk_proof_proposal_distance: u64,
    /// Build proofs but skip L1 submission (rollout shadow gate).
    pub shadow_mode: bool,
    /// Inbox address (prove transaction destination).
    pub inbox_address: Address,
}

impl SubmitterConfig {
    /// Project a [`ProverConfigs`] onto the submitter's runtime knobs.
    #[must_use]
    pub fn from_prover_configs(cfg: &ProverConfigs) -> Self {
        Self {
            proof_polling_interval: cfg.proof_polling_interval,
            force_batch_proving_interval: cfg.force_batch_proving_interval,
            proposal_window_size: cfg.proposal_window_size,
            max_zk_proof_proposal_distance: cfg.max_zk_proof_proposal_distance,
            shadow_mode: cfg.shadow_mode,
            inbox_address: cfg.inbox_address,
        }
    }
}

/// Outcome of one proof-request attempt (Go `RequestProof` poll body).
#[derive(Debug)]
enum RequestAttempt {
    /// A proof was produced; route it with the captured `from_id`.
    Generated {
        /// The produced single proof.
        response: Box<ProofResponse>,
        /// `last_finalized + 1` captured at request time, for buffer routing.
        from_id: u64,
    },
    /// The proposal is already finalized; stop requesting.
    Finalized,
    /// No proof this round — outside the proving range, a transient producer
    /// error, or a ZK redraw. Sleep and poll again.
    Defer,
}

/// The RPC-free routing/aggregation core (buffers, caches, producers,
/// channels). Holds everything needed to classify, buffer, aggregate, and
/// re-queue proofs without touching the network.
pub struct Pipeline {
    /// Base (SGX) producer; covers `ProofType::Sgx`.
    base_producer: Arc<dyn ProofProducer>,
    /// Optional ZKVM producer; covers `ProofType::Risc0`/`Sp1`.
    zkvm_producer: Option<Arc<dyn ProofProducer>>,
    /// Per-type contiguous proof buffers.
    buffers: HashMap<ProofType, Arc<ProofBuffer>>,
    /// Per-type out-of-order caches.
    caches: HashMap<ProofType, Arc<ProofCache>>,
    /// Outgoing channel endpoints.
    channels: SubmitterChannels,
    /// Runtime knobs.
    cfg: SubmitterConfig,
}

impl Pipeline {
    /// Build the pipeline core.
    #[must_use]
    pub fn new(
        base_producer: Arc<dyn ProofProducer>,
        zkvm_producer: Option<Arc<dyn ProofProducer>>,
        buffers: HashMap<ProofType, Arc<ProofBuffer>>,
        caches: HashMap<ProofType, Arc<ProofCache>>,
        channels: SubmitterChannels,
        cfg: SubmitterConfig,
    ) -> Self {
        Self { base_producer, zkvm_producer, buffers, caches, channels, cfg }
    }

    /// Per-type buffers (orchestrator wires the monitor against these).
    #[must_use]
    pub fn buffers(&self) -> &HashMap<ProofType, Arc<ProofBuffer>> {
        &self.buffers
    }

    /// Per-type caches.
    #[must_use]
    pub fn caches(&self) -> &HashMap<ProofType, Arc<ProofCache>> {
        &self.caches
    }

    /// Clone the proof-request sender (orchestrator enqueues proposals here).
    #[must_use]
    pub fn proof_request_sender(&self) -> Sender<ProofRequestMeta> {
        self.channels.proof_request_tx.clone()
    }

    /// Clone the cache-flush sender (the cache monitor nudges flushes here).
    #[must_use]
    pub fn flush_cache_sender(&self) -> Sender<ProofType> {
        self.channels.flush_cache_tx.clone()
    }

    /// Map a drawn proof type to the producer that can aggregate it
    /// (Go `AggregateProofsByType`, `proof_submitter.go:438-445`).
    fn producer_for(&self, proof_type: ProofType) -> Result<&Arc<dyn ProofProducer>> {
        match proof_type {
            ProofType::Sgx | ProofType::SgxGeth => Ok(&self.base_producer),
            ProofType::Risc0 | ProofType::Sp1 | ProofType::ZkAny => {
                self.zkvm_producer.as_ref().ok_or_else(|| {
                    ProverError::Other(anyhow::anyhow!(
                        "no zkvm producer configured for {proof_type:?}"
                    ))
                })
            }
        }
    }

    /// Whether `proposal_id` is outside `(last_finalized, last_finalized +
    /// window]` (Go `isProposalOutOfRange`, `proof_submitter.go:268-278`).
    #[must_use]
    fn is_proposal_out_of_range(&self, proposal_id: u64, last_finalized: u64) -> bool {
        if self.cfg.proposal_window_size < 1 {
            return false;
        }
        proposal_id > last_finalized + self.cfg.proposal_window_size ||
            proposal_id <= last_finalized
    }

    /// Whether a ZK proof should be requested for `proposal_id`: false once it
    /// is more than `max_zk_proof_proposal_distance` ahead of the last finalized
    /// proposal, so the prover falls back to the faster base proof to catch up.
    ///
    /// Rust-only catch-up optimization with no Go equivalent: the Go prover has
    /// no proposal-distance gate (its ZK fallback is purely the 1h timeout plus
    /// `zk_any_not_drawn`). Disable by setting the distance high enough that it
    /// never triggers.
    #[must_use]
    fn should_use_zk_proof(&self, proposal_id: u64, last_finalized: u64) -> bool {
        proposal_id <= last_finalized + self.cfg.max_zk_proof_proposal_distance
    }

    /// Route a freshly produced proof into the buffer (when contiguous) or the
    /// cache (when ahead of the cursor), then nudge aggregation/flush
    /// (Go `handleProofResponse`, `proof_submitter.go:281-332`).
    fn route_proof_response(&self, from_id: u64, response: ProofResponse) -> Result<()> {
        let proof_type = response.proof_type;
        let buffer = self.buffer_for(proof_type)?;
        let cache = self.cache_for(proof_type)?;

        let to_be_inserted =
            if buffer.last_insert_id() > 0 { buffer.last_insert_id() + 1 } else { from_id };
        let proposal_id = response.proposal_id();

        if proposal_id == to_be_inserted {
            match buffer.write_or_return(response) {
                Ok(_) => {
                    cache.flush_contiguous(proposal_id, &buffer);
                    self.try_aggregate(&buffer, proof_type);
                }
                Err(response) => {
                    cache.insert(*response);
                    let _ = self.channels.flush_cache_tx.try_send(proof_type);
                    self.try_aggregate(&buffer, proof_type);
                }
            }
        } else {
            cache.insert(response);
            let _ = self.channels.flush_cache_tx.try_send(proof_type);
        }
        tracing::info!(
            proposal_id,
            buffer_len = buffer.len(),
            max_buffer = buffer.max_length,
            ?proof_type,
            aggregating = buffer.is_aggregating(),
            "proof generated successfully for proposal"
        );
        Ok(())
    }

    /// Trigger aggregation when the buffer is full or the force interval has
    /// elapsed since the last insertion (Go `TryAggregate`,
    /// `proof_submitter.go:415-427`).
    pub fn try_aggregate(&self, buffer: &ProofBuffer, proof_type: ProofType) -> bool {
        let full = buffer.len() as u64 >= buffer.max_length;
        let stale = buffer
            .last_item_at()
            .is_some_and(|at| at.elapsed() > self.cfg.force_batch_proving_interval);
        if !full && (buffer.is_empty() || !stale) {
            return false;
        }
        if buffer.mark_aggregating_if_not() {
            let _ = self.channels.aggregation_notify_tx.try_send(proof_type);
            return true;
        }
        false
    }

    /// Aggregate all buffered proofs of `proof_type` and forward the batch for
    /// submission, polling the producer through in-progress statuses
    /// (Go `AggregateProofsByType`, `proof_submitter.go:430-491`).
    pub async fn aggregate_proofs_by_type(&self, proof_type: ProofType) -> Result<()> {
        let buffer = self.buffer_for(proof_type)?;
        let producer = self.producer_for(proof_type)?.clone();
        let mut items = buffer.read_all();
        if items.is_empty() {
            return Ok(());
        }

        // Captured once so the recorded generation time spans the whole poll
        // loop, like Go's `requestAt` for the aggregation path.
        let request_at = Instant::now();
        loop {
            match producer.aggregate(&mut items, request_at).await {
                Ok(batch) => {
                    let _ = self.channels.batch_proofs_tx.send(batch).await;
                    return Ok(());
                }
                // Retry every non-success outcome with constant backoff, keeping
                // the buffered proofs (Go `AggregateProofsByType` wraps the
                // aggregation in `backoff.Retry`; the in-progress vs. error
                // distinction is logging-only). Dropping the buffer here would
                // lose already-generated proofs whose `Proposed` events are
                // already marked handled, so they would never be re-proven.
                Err(ProverError::Raiko(RaikoError::Pending(_))) => {
                    tokio::time::sleep(self.cfg.proof_polling_interval).await;
                }
                Err(err) => {
                    tracing::warn!(%err, ?proof_type, "aggregate proofs failed, retrying");
                    tokio::time::sleep(self.cfg.proof_polling_interval).await;
                }
            }
        }
    }

    /// Run one proof-request attempt: gate on finalization/range, then try the
    /// ZK producer first (falling back to SGX on a redraw or the 1h timeout)
    /// and finally the base producer (Go `RequestProof` poll body,
    /// `proof_submitter.go:177-250`). RPC-free: the caller supplies
    /// `last_finalized`.
    async fn request_proof_attempt(
        &self,
        request: &mut ProofRequest,
        use_zk: &mut bool,
        zk_started: &mut Instant,
        last_finalized: u64,
        request_at: Instant,
    ) -> Result<RequestAttempt> {
        let proposal_id = request.proposal_id;
        let from_id = last_finalized + 1;
        if from_id > proposal_id {
            tracing::info!(proposal_id, last_finalized, "proposal already finalized, skip request");
            return Ok(RequestAttempt::Finalized);
        }
        if self.is_proposal_out_of_range(proposal_id, last_finalized) {
            return Ok(RequestAttempt::Defer);
        }

        // Too far ahead of finalization for a slow ZK proof: fall back to the
        // base proof to keep catching up (Rust-only distance gate; see
        // `should_use_zk_proof`).
        if *use_zk && !self.should_use_zk_proof(proposal_id, last_finalized) {
            tracing::info!(
                proposal_id,
                last_finalized,
                max_zk_proof_proposal_distance = self.cfg.max_zk_proof_proposal_distance,
                "proposal too far from last finalized, skipping ZK proof"
            );
            *use_zk = false;
        }

        if let (true, Some(zkvm)) = (*use_zk, self.zkvm_producer.as_ref()) {
            match zkvm.request_proof(request, request_at).await {
                Ok(response) => {
                    return Ok(RequestAttempt::Generated { response: Box::new(response), from_id });
                }
                Err(ProverError::Raiko(RaikoError::ZkAnyNotDrawn)) => {
                    tracing::debug!(proposal_id, "zk proof not drawn, falling back to SGX");
                    *use_zk = false;
                    *zk_started = Instant::now();
                    return Ok(RequestAttempt::Defer);
                }
                Err(err) => {
                    if zk_started.elapsed() > MAX_PROOF_REQUEST_TIMEOUT {
                        tracing::warn!("zk retry exceeded max timeout, switching to SGX fallback");
                        *use_zk = false;
                        *zk_started = Instant::now();
                        return Ok(RequestAttempt::Defer);
                    }
                    return Err(err);
                }
            }
        }

        let response = self.base_producer.request_proof(request, request_at).await?;
        Ok(RequestAttempt::Generated { response: Box::new(response), from_id })
    }

    /// Clear submitted items from their buffer, optionally re-queuing proof
    /// requests (Go `ClearProofBuffers`, `proof_submitter.go:400-411`).
    pub async fn clear_proof_buffers(&self, batch: &BatchProofs, resend: bool) -> Result<()> {
        let buffer = self.buffer_for(batch.proof_type)?;
        buffer.clear_items(&batch.batch_ids);
        if resend {
            for response in &batch.responses {
                let _ = self
                    .channels
                    .proof_request_tx
                    .send(ProofRequestMeta::from_request(&response.request))
                    .await;
            }
        }
        Ok(())
    }

    /// RPC-free core of cache flushing (caller supplies `last_finalized`)
    /// (Go `FlushCache`, `proof_submitter.go:599-638`).
    pub fn flush_cache_with_finalized(
        &self,
        proof_type: ProofType,
        last_finalized: u64,
    ) -> Result<()> {
        let buffer = self.buffer_for(proof_type)?;
        let cache = self.cache_for(proof_type)?;

        let from_id = if buffer.last_insert_id() > 0 {
            buffer.last_insert_id() + 1
        } else {
            last_finalized + 1
        };
        let available = buffer.available_capacity();
        if available == 0 {
            self.try_aggregate(&buffer, proof_type);
            return Ok(());
        }
        let to_id = from_id + available - 1;
        if let Err(CacheError::CacheMiss(_)) = cache.flush_range(from_id, to_id, &buffer) {
            // A gap simply means "done for now" (Go ignores ErrCacheNotFound).
        }
        self.try_aggregate(&buffer, proof_type);
        Ok(())
    }

    /// Look up the buffer for a proof type.
    fn buffer_for(&self, proof_type: ProofType) -> Result<Arc<ProofBuffer>> {
        self.buffers.get(&proof_type).cloned().ok_or_else(|| unexpected_proof_type(proof_type))
    }

    /// Look up the cache for a proof type.
    fn cache_for(&self, proof_type: ProofType) -> Result<Arc<ProofCache>> {
        self.caches.get(&proof_type).cloned().ok_or_else(|| unexpected_proof_type(proof_type))
    }
}

/// Error for a proof type that has no configured buffer/cache.
fn unexpected_proof_type(proof_type: ProofType) -> ProverError {
    ProverError::Other(anyhow::anyhow!("unexpected proof type from raiko: {proof_type:?}"))
}

/// Requests proofs, buffers/aggregates them, and submits `Inbox.prove`.
/// Wraps the RPC-free [`Pipeline`] with the client and tx-manager.
pub struct ProofSubmitter {
    /// Wallet-bound RPC client.
    rpc: Arc<ClientWithWallet>,
    /// RPC-free routing/aggregation core (shared with the orchestrator's
    /// background monitors).
    pipeline: Arc<Pipeline>,
    /// L1 transaction manager for prove submissions.
    tx_manager: SimpleTxManager,
    /// This prover's address (`commitment.actualProver`).
    prover_address: Address,
}

impl ProofSubmitter {
    /// Assemble a submitter from its parts (the orchestrator builds these).
    #[must_use]
    pub fn new(
        rpc: Arc<ClientWithWallet>,
        pipeline: Arc<Pipeline>,
        tx_manager: SimpleTxManager,
        prover_address: Address,
    ) -> Self {
        Self { rpc, pipeline, tx_manager, prover_address }
    }

    /// Clone the shared RPC-free pipeline (monitor/consumer access).
    #[must_use]
    pub fn pipeline(&self) -> Arc<Pipeline> {
        self.pipeline.clone()
    }

    /// Read `inbox.getCoreState().lastFinalizedProposalId` as a `u64`.
    async fn last_finalized_proposal_id(&self) -> Result<u64> {
        Ok(self.rpc.core_state().await?.last_finalized_proposal_id)
    }

    /// Validate the corresponding L1 block is still canonical and the proposal
    /// is not already finalized (Go `ValidateProof`,
    /// `proof_submitter.go:532-569`).
    async fn validate_proof(&self, response: &ProofResponse, latest_verified: u64) -> Result<bool> {
        let block = self
            .rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Number(response.request.event_l1_block_number))
            .await
            .map_err(RpcClientError::from)?;
        let Some(block) = block else {
            // A momentarily-absent L1 block (lagging / pruned / load-balanced
            // backend) is transient, not a reorg. Surface it as an error so the
            // submit op retries with the proofs still buffered, matching Go
            // `ValidateProof` where `HeaderByNumber` returns `ethereum.NotFound`
            // as an error rather than a "skip this proof" signal. Returning
            // `Ok(false)` here would permanently drop a finished proof.
            return Err(ProverError::Other(anyhow::anyhow!(
                "L1 block {} for proposal {} not found yet; retrying",
                response.request.event_l1_block_number,
                response.proposal_id()
            )));
        };
        if block.header.hash != response.request.event_l1_block_hash {
            tracing::warn!(
                proposal_id = response.proposal_id(),
                "reorg detected, skip the current proof submission"
            );
            return Ok(false);
        }
        if latest_verified >= response.proposal_id() {
            tracing::info!(
                proposal_id = response.proposal_id(),
                latest_verified,
                "proposal already finalized, skip current proof submission"
            );
            return Ok(false);
        }
        Ok(true)
    }

    /// Identify proposals in the aggregation that are already proven or reorged
    /// out (Go `validateBatchProofs`, `proof_submitter.go:495-528`).
    async fn validate_batch_proofs(&self, batch: &BatchProofs) -> Result<Vec<u64>> {
        if batch.responses.is_empty() {
            return Err(ProverError::Other(anyhow::anyhow!("empty batch proof")));
        }
        let latest_verified = self.last_finalized_proposal_id().await?;
        let mut invalid = Vec::new();
        for response in &batch.responses {
            if !self.validate_proof(response, latest_verified).await? {
                invalid.push(response.proposal_id());
            }
        }
        Ok(invalid)
    }

    /// Block until the parent transition `transition_id` is finalized so prove
    /// submissions stay strictly ordered (Go `WaitTransitionVerified`,
    /// `proof_submitter.go:572-597`).
    async fn wait_transition_verified(&self, transition_id: u64) -> Result<()> {
        let deadline = std::time::Instant::now() + TRANSITION_WAIT_TIMEOUT;
        loop {
            let last_finalized = self.last_finalized_proposal_id().await?;
            if last_finalized >= transition_id {
                return Ok(());
            }
            if std::time::Instant::now() >= deadline {
                // Bounded like Go's `rpc.DefaultRpcTimeout`: give up waiting and
                // return a transient error so the caller re-validates the batch
                // (catching a reorg/finalization that happened while waiting)
                // before waiting again, instead of pinning the buffer forever.
                return Err(ProverError::Other(anyhow::anyhow!(
                    "transition {transition_id} not verified within {}s; retrying",
                    TRANSITION_WAIT_TIMEOUT.as_secs()
                )));
            }
            tracing::info!(transition_id, last_finalized, "waiting for transition to be verified");
            tokio::time::sleep(TRANSITION_POLL_INTERVAL).await;
        }
    }

    /// Submit an aggregated batch to `Inbox.prove` (Go `BatchSubmitProofs`,
    /// `proof_submitter.go:335-397`). Drops already-proven/reorged proposals as
    /// [`ProverError::InvalidProof`]; in shadow mode it builds the transaction
    /// and records the intent without sending.
    pub async fn batch_submit_proofs(&self, batch: &BatchProofs) -> Result<()> {
        let buffer = self.pipeline.buffer_for(batch.proof_type)?;

        let invalid = self.validate_batch_proofs(batch).await?;
        if !invalid.is_empty() {
            tracing::warn!(?invalid, "invalid proposals in an aggregation, ignoring them");
            buffer.clear_items(&invalid);
            return Err(ProverError::InvalidProof);
        }

        let lowest = batch.batch_ids.iter().copied().min().unwrap_or_default();
        let latest_proven_block = batch
            .responses
            .iter()
            .map(|response| response.request.end_block_number)
            .max()
            .unwrap_or_default();

        self.wait_transition_verified(lowest.saturating_sub(1)).await?;

        let candidate = build_prove_batches_tx(BuildProveTxInput {
            rpc: &self.rpc,
            inbox_address: self.pipeline.cfg.inbox_address,
            batch,
            actual_prover: self.prover_address,
        })
        .await?;

        if self.pipeline.cfg.shadow_mode {
            ProverMetrics::shadow_would_submit().inc();
            tracing::info!(
                ?batch.batch_ids,
                calldata_len = candidate.tx_data.len(),
                "shadow mode: would submit prove transaction"
            );
            return Ok(());
        }

        let receipt = match self.tx_manager.send(candidate).await {
            Ok(receipt) => receipt,
            Err(err) => {
                ProverMetrics::submission_errors().inc();
                return Err(ProverError::from(err));
            }
        };

        // base-tx-manager returns `Ok(receipt)` even for a transaction that reached
        // confirmation depth but reverted, so the status must be checked explicitly.
        // A revert means the proofs did not land; surface it so the caller resends
        // the requests rather than dropping them, matching Go `prover.go:302-314`
        // (reverted/unretryable -> `ClearProofBuffers(batchProof, true)`).
        if !receipt.status() {
            ProverMetrics::submission_reverted().inc();
            tracing::error!(
                tx_hash = %receipt.transaction_hash,
                ?batch.batch_ids,
                "prove transaction reverted on-chain; resending proof requests"
            );
            return Err(ProverError::SubmissionReverted);
        }

        ProverMetrics::proofs_sent().inc_by(batch.batch_ids.len() as u64);
        ProverMetrics::latest_proven_block_id().set(latest_proven_block as f64);
        Ok(())
    }

    /// Flush cached proofs into the buffer once the contiguous range is
    /// available, then try aggregation (Go `FlushCache`).
    pub async fn flush_cache(&self, proof_type: ProofType) -> Result<()> {
        let cache = self.pipeline.cache_for(proof_type)?;
        if cache.is_empty() {
            return Ok(());
        }
        let last_finalized = self.last_finalized_proposal_id().await?;
        self.pipeline.flush_cache_with_finalized(proof_type, last_finalized)
    }

    /// Enrich a `Proposed`-derived meta into a full [`ProofRequest`]: resolve
    /// the proposal's L2 block range and the previous proposal's anchor state
    /// (Go `RequestProof`, `proof_submitter.go:115-174`).
    async fn enrich_request(&self, meta: &ProofRequestMeta) -> Result<ProofRequest> {
        let proposal_id = meta.proposal_id;
        let last_block_id = self.wait_proposal_last_block_id(proposal_id).await?;
        let header = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(last_block_id))
            .await
            .map_err(RpcClientError::from)?
            .ok_or_else(|| {
                ProverError::Other(anyhow::anyhow!("L2 block {last_block_id} missing"))
            })?;

        // Go `ProposalLastBlockID` short-circuits proposal id 0 to block 0
        // without an engine call (`pkg/rpc/methods.go`).
        let prev_last_block_id = if proposal_id <= 1 {
            0
        } else {
            self.rpc
                .last_block_id_by_batch_id(U256::from(proposal_id - 1))
                .await?
                .map(|id| id.to::<u64>())
                .unwrap_or_default()
        };
        let l2_block_numbers: Vec<u64> = (prev_last_block_id + 1..=last_block_id).collect();

        // The genesis case reads anchor state at block number 0 (Go pins
        // `GetBlockState` to block 0); block hash 0x0 does not resolve.
        let last_anchor_block_number = if prev_last_block_id == 0 {
            self.rpc.shasta_anchor_state_by_number(0).await?.anchor_block_number
        } else {
            let prev_header = self
                .rpc
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(prev_last_block_id))
                .await
                .map_err(RpcClientError::from)?
                .ok_or_else(|| {
                    ProverError::Other(anyhow::anyhow!(
                        "prev L2 block {prev_last_block_id} missing"
                    ))
                })?;
            self.rpc.shasta_anchor_state_by_hash(prev_header.header.hash).await?.anchor_block_number
        };

        Ok(ProofRequest {
            proposal_id,
            proposer: meta.proposer,
            proposal_timestamp: meta.proposal_timestamp,
            event_l1_block_number: meta.event_l1_block_number,
            event_l1_block_hash: meta.event_l1_block_hash,
            prover_address: self.prover_address,
            l2_block_numbers,
            end_block_number: header.header.number,
            end_block_hash: header.header.hash,
            end_state_root: header.header.state_root,
            last_anchor_block_number,
            geth_proof_generated: false,
            reth_proof_generated: false,
            geth_aggregation_generated: false,
            reth_aggregation_generated: false,
        })
    }

    /// Poll the engine for the proposal's last L2 block id until it exists
    /// (Go `WaitProposalHeader` + `ProposalLastBlockID`).
    async fn wait_proposal_last_block_id(&self, proposal_id: u64) -> Result<u64> {
        loop {
            if let Some(id) = self.rpc.last_block_id_by_batch_id(U256::from(proposal_id)).await? {
                let id = id.to::<u64>();
                if id > 0 {
                    return Ok(id);
                }
            }
            tokio::time::sleep(self.pipeline.cfg.proof_polling_interval).await;
        }
    }

    /// Request (and poll for) a proof for one proposal, routing the result into
    /// the buffer/cache (Go `RequestProof`, `proof_submitter.go:115-264`).
    ///
    /// Like Go's inner constant backoff, this retries on **any** transient
    /// failure — raiko HTTP/status errors, L1/engine blips, and enrichment
    /// failures all sleep and retry rather than dropping the proposal — and
    /// only returns once the proof is produced and routed or the proposal is
    /// finalized. The spawning task is aborted on shutdown.
    pub async fn request_proof(&self, meta: ProofRequestMeta) -> Result<()> {
        let interval = self.pipeline.cfg.proof_polling_interval;

        // Enrich with retry so a transient L1/engine error does not drop the
        // proposal (Go enriches inside the retried operation).
        let mut request = loop {
            match self.enrich_request(&meta).await {
                Ok(request) => break request,
                Err(err) => {
                    tracing::warn!(
                        proposal_id = meta.proposal_id,
                        %err,
                        "failed to enrich proof request, retrying"
                    );
                    tokio::time::sleep(interval).await;
                }
            }
        };

        let mut use_zk = true;
        let mut zk_started = Instant::now();
        // Captured once so the recorded generation time spans the whole poll
        // loop (all raiko polls), like Go's `requestAt`.
        let request_at = Instant::now();
        loop {
            let last_finalized = match self.last_finalized_proposal_id().await {
                Ok(last_finalized) => last_finalized,
                Err(err) => {
                    tracing::warn!(%err, "failed to read core state during proof request, retrying");
                    tokio::time::sleep(interval).await;
                    continue;
                }
            };
            match self
                .pipeline
                .request_proof_attempt(
                    &mut request,
                    &mut use_zk,
                    &mut zk_started,
                    last_finalized,
                    request_at,
                )
                .await
            {
                Ok(RequestAttempt::Generated { response, from_id }) => {
                    return self.pipeline.route_proof_response(from_id, *response);
                }
                Ok(RequestAttempt::Finalized) => return Ok(()),
                Ok(RequestAttempt::Defer) => {}
                Err(err) => {
                    tracing::warn!(
                        proposal_id = meta.proposal_id,
                        %err,
                        "proof request attempt failed, retrying"
                    );
                }
            }
            tokio::time::sleep(interval).await;
        }
    }
}

#[cfg(test)]
mod tests {
    use std::{
        collections::{HashMap, VecDeque},
        sync::{Arc, Mutex},
        time::{Duration, Instant},
    };

    use alloy_primitives::{Address, B256, Bytes};
    use tokio::sync::{Mutex as AsyncMutex, mpsc};

    use super::{Pipeline, ProofRequestMeta, RequestAttempt, SubmitterChannels, SubmitterConfig};
    use crate::{
        buffer::ProofBuffer,
        cache::ProofCache,
        error::{ProverError, Result},
        producer::{BatchProofs, ProofProducer, ProofRequest, ProofResponse},
        raiko::{ProofType, RaikoError},
    };

    /// Pipeline plus retained channel receivers for assertions.
    struct Harness {
        pipeline: Pipeline,
        batch_rx: mpsc::Receiver<BatchProofs>,
        aggregation_rx: mpsc::Receiver<ProofType>,
        request_rx: mpsc::Receiver<ProofRequestMeta>,
        flush_rx: mpsc::Receiver<ProofType>,
    }

    /// Producer test double returning queued results in order.
    #[derive(Default)]
    struct MockProducer {
        single: AsyncMutex<VecDeque<Result<ProofType>>>,
        batch: AsyncMutex<VecDeque<Result<()>>>,
        single_calls: Mutex<u32>,
    }

    impl MockProducer {
        fn with_single(results: Vec<Result<ProofType>>) -> Self {
            Self { single: AsyncMutex::new(results.into()), ..Self::default() }
        }
    }

    #[async_trait::async_trait]
    impl ProofProducer for MockProducer {
        async fn request_proof(
            &self,
            request: &mut ProofRequest,
            _request_at: Instant,
        ) -> Result<ProofResponse> {
            *self.single_calls.lock().unwrap() += 1;
            let outcome = self.single.lock().await.pop_front().unwrap_or_else(|| {
                Err(ProverError::Raiko(RaikoError::Pending("registered".to_owned())))
            })?;
            Ok(ProofResponse {
                request: request.clone(),
                proof: Bytes::from_static(&[0xaa]),
                proof_type: outcome,
            })
        }

        async fn aggregate(
            &self,
            items: &mut [ProofResponse],
            _request_at: Instant,
        ) -> Result<BatchProofs> {
            self.batch.lock().await.pop_front().unwrap_or(Ok(()))?;
            Ok(BatchProofs {
                responses: items.to_vec(),
                batch_proof: Bytes::from_static(&[0xbb]),
                sgx_geth_batch_proof: Bytes::from_static(&[0x11]),
                batch_ids: items.iter().map(ProofResponse::proposal_id).collect(),
                proof_type: items[0].proof_type,
                verifier_id: 4,
                sgx_geth_verifier_id: 1,
            })
        }
    }

    fn response(proposal_id: u64, proof_type: ProofType) -> ProofResponse {
        ProofResponse {
            request: ProofRequest {
                proposal_id,
                proposer: Address::repeat_byte(0x11),
                proposal_timestamp: 1_000,
                event_l1_block_number: 42,
                event_l1_block_hash: B256::repeat_byte(0x22),
                prover_address: Address::repeat_byte(0x33),
                l2_block_numbers: vec![100 + proposal_id],
                end_block_number: 100 + proposal_id,
                end_block_hash: B256::repeat_byte(0x44),
                end_state_root: B256::repeat_byte(0x55),
                last_anchor_block_number: 40,
                geth_proof_generated: false,
                reth_proof_generated: false,
                geth_aggregation_generated: false,
                reth_aggregation_generated: false,
            },
            proof: Bytes::from_static(&[0xaa]),
            proof_type,
        }
    }

    fn harness(base: Arc<dyn ProofProducer>, force_interval: Duration, max: u64) -> Harness {
        harness_with(base, None, force_interval, max, 30)
    }

    /// Like [`harness`] but with an optional zkvm producer and configurable ZK
    /// proposal distance, for the SGX-fallback tests.
    fn harness_with(
        base: Arc<dyn ProofProducer>,
        zkvm: Option<Arc<dyn ProofProducer>>,
        force_interval: Duration,
        max: u64,
        max_zk_proof_proposal_distance: u64,
    ) -> Harness {
        let (batch_proofs_tx, batch_rx) = mpsc::channel(16);
        let (aggregation_notify_tx, aggregation_rx) = mpsc::channel(16);
        let (proof_request_tx, request_rx) = mpsc::channel(16);
        let (flush_cache_tx, flush_rx) = mpsc::channel(16);

        let pipeline = Pipeline::new(
            base,
            zkvm,
            HashMap::from([(ProofType::Sgx, Arc::new(ProofBuffer::new(max)))]),
            HashMap::from([(ProofType::Sgx, Arc::new(ProofCache::new()))]),
            SubmitterChannels {
                batch_proofs_tx,
                aggregation_notify_tx,
                proof_request_tx,
                flush_cache_tx,
            },
            SubmitterConfig {
                proof_polling_interval: Duration::from_millis(1),
                force_batch_proving_interval: force_interval,
                proposal_window_size: 0,
                max_zk_proof_proposal_distance,
                shadow_mode: false,
                inbox_address: Address::repeat_byte(0x11),
            },
        );
        Harness { pipeline, batch_rx, aggregation_rx, request_rx, flush_rx }
    }

    #[tokio::test]
    async fn contiguous_proof_enters_buffer_and_full_buffer_triggers_aggregation_once() {
        let mut h = harness(Arc::new(MockProducer::default()), Duration::from_secs(3_600), 2);

        h.pipeline.route_proof_response(5, response(5, ProofType::Sgx)).unwrap();
        assert!(h.aggregation_rx.try_recv().is_err(), "buffer not full yet");
        h.pipeline.route_proof_response(5, response(6, ProofType::Sgx)).unwrap();

        assert_eq!(h.aggregation_rx.try_recv().unwrap(), ProofType::Sgx);
        assert!(h.aggregation_rx.try_recv().is_err(), "aggregation fires exactly once");
        let buffer = h.pipeline.buffers().get(&ProofType::Sgx).unwrap();
        assert_eq!(buffer.len(), 2);
        assert!(buffer.is_aggregating());
    }

    #[tokio::test]
    async fn gap_proof_goes_to_cache_and_nudges_flush() {
        let mut h = harness(Arc::new(MockProducer::default()), Duration::from_secs(3_600), 4);

        h.pipeline.route_proof_response(5, response(7, ProofType::Sgx)).unwrap();

        let buffer = h.pipeline.buffers().get(&ProofType::Sgx).unwrap();
        assert_eq!(buffer.len(), 0);
        assert_eq!(h.pipeline.caches().get(&ProofType::Sgx).unwrap().len(), 1);
        assert_eq!(h.flush_rx.try_recv().unwrap(), ProofType::Sgx);
    }

    #[tokio::test]
    async fn next_contiguous_proof_waits_in_cache_when_buffer_is_full() {
        let mut h = harness(Arc::new(MockProducer::default()), Duration::from_secs(3_600), 1);

        h.pipeline.route_proof_response(5, response(5, ProofType::Sgx)).unwrap();
        assert_eq!(h.aggregation_rx.try_recv().unwrap(), ProofType::Sgx);

        h.pipeline.route_proof_response(5, response(6, ProofType::Sgx)).unwrap();

        let buffer = h.pipeline.buffers().get(&ProofType::Sgx).unwrap();
        assert_eq!(buffer.len(), 1, "full buffer keeps only the aggregating proof");
        assert_eq!(buffer.last_insert_id(), 5);
        assert_eq!(h.pipeline.caches().get(&ProofType::Sgx).unwrap().len(), 1);
        assert_eq!(h.flush_rx.try_recv().unwrap(), ProofType::Sgx);
    }

    #[tokio::test]
    async fn flush_cache_drains_contiguous_then_aggregates() {
        let h = harness(Arc::new(MockProducer::default()), Duration::from_secs(3_600), 4);
        let cache = h.pipeline.caches().get(&ProofType::Sgx).unwrap();
        for id in [5, 6, 7] {
            cache.insert(response(id, ProofType::Sgx));
        }

        h.pipeline.flush_cache_with_finalized(ProofType::Sgx, 4).unwrap();

        let buffer = h.pipeline.buffers().get(&ProofType::Sgx).unwrap();
        assert_eq!(buffer.len(), 3);
        assert_eq!(cache.len(), 0);
    }

    #[tokio::test]
    async fn aggregate_forwards_batch_to_submission_channel() {
        let mut h = harness(Arc::new(MockProducer::default()), Duration::from_secs(3_600), 2);
        let buffer = h.pipeline.buffers().get(&ProofType::Sgx).unwrap();
        buffer.write(response(5, ProofType::Sgx)).unwrap();
        buffer.write(response(6, ProofType::Sgx)).unwrap();

        h.pipeline.aggregate_proofs_by_type(ProofType::Sgx).await.unwrap();

        let batch = h.batch_rx.try_recv().unwrap();
        assert_eq!(batch.batch_ids, vec![5, 6]);
    }

    #[tokio::test]
    async fn aggregate_retries_error_without_dropping_buffer() {
        let producer = Arc::new(MockProducer::default());
        // First aggregation attempt fails; the retry (empty queue -> Ok) succeeds.
        producer
            .batch
            .lock()
            .await
            .push_back(Err(ProverError::Other(anyhow::anyhow!("raiko down"))));
        let mut h = harness(producer, Duration::from_secs(3_600), 2);
        let buffer = h.pipeline.buffers().get(&ProofType::Sgx).unwrap();
        buffer.write(response(5, ProofType::Sgx)).unwrap();
        buffer.write(response(6, ProofType::Sgx)).unwrap();

        // The transient error is retried, not surfaced, and the proofs are kept.
        h.pipeline.aggregate_proofs_by_type(ProofType::Sgx).await.unwrap();

        let batch = h.batch_rx.try_recv().unwrap();
        assert_eq!(batch.batch_ids, vec![5, 6], "buffered proofs aggregated on retry, not dropped");
        assert_eq!(buffer.len(), 2, "buffer retained until post-submission clear");
    }

    #[tokio::test]
    async fn out_of_range_proposal_defers_without_calling_producer() {
        let producer = Arc::new(MockProducer::with_single(vec![Ok(ProofType::Sgx)]));
        let calls = producer.clone();
        let mut h = harness(producer, Duration::from_secs(3_600), 2);
        h.pipeline.cfg.proposal_window_size = 3;

        let mut request = response(100, ProofType::Sgx).request;
        let mut use_zk = true;
        let mut started = std::time::Instant::now();
        let attempt = h
            .pipeline
            .request_proof_attempt(&mut request, &mut use_zk, &mut started, 4, Instant::now())
            .await
            .unwrap();
        assert!(matches!(attempt, RequestAttempt::Defer));
        assert_eq!(*calls.single_calls.lock().unwrap(), 0);
    }

    #[tokio::test]
    async fn finalized_proposal_skips_request() {
        let h = harness(
            Arc::new(MockProducer::with_single(vec![Ok(ProofType::Sgx)])),
            Duration::from_secs(3_600),
            2,
        );
        let mut request = response(3, ProofType::Sgx).request;
        let mut use_zk = true;
        let mut started = std::time::Instant::now();
        let attempt = h
            .pipeline
            .request_proof_attempt(&mut request, &mut use_zk, &mut started, 5, Instant::now())
            .await
            .unwrap();
        assert!(matches!(attempt, RequestAttempt::Finalized));
    }

    #[test]
    fn should_use_zk_proof_boundary() {
        // Rust-only distance gate (no Go equivalent): distance 30, last
        // finalized 10 → 40 ok, 41 falls back to the base proof.
        let h = harness(Arc::new(MockProducer::default()), Duration::from_secs(3_600), 2);
        assert!(h.pipeline.should_use_zk_proof(40, 10));
        assert!(!h.pipeline.should_use_zk_proof(41, 10));
    }

    #[test]
    fn should_use_zk_proof_honors_configured_distance() {
        // distance 5, last finalized 10 → 15 ok, 16 falls back to the base proof.
        let mut h = harness(Arc::new(MockProducer::default()), Duration::from_secs(3_600), 2);
        h.pipeline.cfg.max_zk_proof_proposal_distance = 5;
        assert!(h.pipeline.should_use_zk_proof(15, 10));
        assert!(!h.pipeline.should_use_zk_proof(16, 10));
    }

    #[tokio::test]
    async fn far_ahead_proposal_falls_back_to_base_producer() {
        let base = Arc::new(MockProducer::with_single(vec![Ok(ProofType::Sgx)]));
        let zkvm = Arc::new(MockProducer::with_single(vec![Ok(ProofType::Risc0)]));
        let base_calls = base.clone();
        let zkvm_calls = zkvm.clone();

        let h = harness_with(base, Some(zkvm), Duration::from_secs(3_600), 2, 5);

        // last finalized 10, distance 5 → allowed up to 15; proposal 100 is too far.
        let mut request = response(100, ProofType::Sgx).request;
        let mut use_zk = true;
        let mut started = std::time::Instant::now();
        let attempt = h
            .pipeline
            .request_proof_attempt(&mut request, &mut use_zk, &mut started, 10, Instant::now())
            .await
            .unwrap();

        assert!(matches!(attempt, RequestAttempt::Generated { .. }));
        assert!(!use_zk, "zk disabled for a far-ahead proposal");
        assert_eq!(*base_calls.single_calls.lock().unwrap(), 1, "base producer used");
        assert_eq!(*zkvm_calls.single_calls.lock().unwrap(), 0, "zkvm producer skipped");
    }

    #[tokio::test]
    async fn clear_proof_buffers_resends_requests() {
        let mut h = harness(Arc::new(MockProducer::default()), Duration::from_secs(3_600), 2);
        let batch = BatchProofs {
            responses: vec![response(5, ProofType::Sgx), response(6, ProofType::Sgx)],
            batch_proof: Bytes::new(),
            sgx_geth_batch_proof: Bytes::new(),
            batch_ids: vec![5, 6],
            proof_type: ProofType::Sgx,
            verifier_id: 4,
            sgx_geth_verifier_id: 1,
        };

        h.pipeline.clear_proof_buffers(&batch, true).await.unwrap();

        assert_eq!(h.request_rx.try_recv().unwrap().proposal_id, 5);
        assert_eq!(h.request_rx.try_recv().unwrap().proposal_id, 6);
        assert!(h.request_rx.try_recv().is_err());
    }
}
