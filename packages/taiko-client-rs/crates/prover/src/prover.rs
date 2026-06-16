//! The prover service: subscribes to Shasta inbox events and drives the proof
//! pipeline (Go `prover/prover.go` + `prover/init.go`).

use std::{collections::HashMap, sync::Arc, time::Duration};

use alloy::{eips::BlockNumberOrTag, providers::Provider, sol_types::SolEvent};
use alloy_primitives::{Address, B256};
use bindings::inbox::Inbox::{Proposed, Proved};
use event_scanner::{EventFilter, EventScannerResult, Notification, ScannerMessage};
use rpc::{
    RpcClientError,
    client::{Client, ClientConfig, ClientWithWallet},
};
use tokio::sync::mpsc;
use tokio_stream::{StreamExt, wrappers::ReceiverStream};

use crate::{
    buffer::ProofBuffer,
    cache::ProofCache,
    config::ProverConfigs,
    error::{ProverError, Result},
    handler::{ProvingDecision, proving_window_status, route_proposal, should_prove},
    metrics::ProverMetrics,
    producer::{BatchProofs, ComposeProofProducer, ProofProducer, SgxGethProofProducer},
    raiko::{ProofType, RaikoClient, RaikoClientConfig},
    state::SharedState,
    submitter::{
        Pipeline, ProofRequestMeta, ProofSubmitter, SubmitterChannels, SubmitterConfig,
        monitor::{MONITOR_INTERVAL, spawn_monitors},
    },
};

/// Block-window size when walking `Proposed` logs back to the start cursor.
const START_SCAN_WINDOW: u64 = 10_000;

/// Maximum in-place retries of the submit op before re-requesting the proofs,
/// mirroring Go's `--backoff.maxRetries` default (`BackOffMaxRetries = 10`).
/// Transient pre-send read/build failures retry with the proofs still buffered;
/// only revert / unretryable send / exhaustion falls back to a full re-request.
const MAX_SUBMISSION_RETRIES: u32 = 10;

/// The prover service.
pub struct Prover {
    /// Static configuration.
    cfg: ProverConfigs,
    /// Wallet-bound RPC client.
    rpc: Arc<ClientWithWallet>,
    /// Proof request/aggregate/submit pipeline.
    submitter: Arc<ProofSubmitter>,
    /// Shared dedup cursor (highest handled proposal id).
    state: Arc<SharedState>,
    /// This prover's L1 address.
    prover_address: Address,
    /// Proving window in seconds (from `inbox.getConfig()`).
    proving_window_secs: u64,
    /// Proposals to prove (request enrichment + proving).
    proof_request_rx: mpsc::Receiver<ProofRequestMeta>,
    /// Aggregation-ready nudges per proof type.
    aggregation_notify_rx: mpsc::Receiver<ProofType>,
    /// Cache-flush nudges per proof type.
    flush_cache_rx: mpsc::Receiver<ProofType>,
    /// Completed aggregations awaiting submission.
    batch_proofs_rx: mpsc::Receiver<crate::producer::BatchProofs>,
}

impl Prover {
    /// Build a prover: client, producers, buffers, submitter, and channels
    /// (Go `InitFromConfig` + `initProofSubmitter`).
    pub async fn new(cfg: ProverConfigs) -> Result<Self> {
        let rpc = Arc::new(
            Client::new_with_wallet(
                ClientConfig {
                    l1_provider_source: cfg.l1_provider_source.clone(),
                    l2_provider_url: cfg.l2_provider_url.clone(),
                    l2_auth_provider_url: cfg.l2_auth_provider_url.clone(),
                    jwt_secret: cfg.jwt_secret.clone(),
                    inbox_address: cfg.inbox_address,
                },
                cfg.l1_prover_private_key,
            )
            .await?,
        );

        let prover_address = address_from_key(cfg.l1_prover_private_key)?;

        let inbox_config = rpc
            .shasta
            .inbox
            .getConfig()
            .call()
            .await
            .map_err(|err| RpcClientError::Contract(err.to_string()))?;
        let proving_window_secs = inbox_config.provingWindow.to::<u64>();
        let channel_cap = inbox_config.ringBufferSize.to::<u64>().max(1) as usize;

        // Producers: sgxgeth is always paired with the base SGX producer; the
        // optional ZKVM producer requests zk_any (Go `init.go:37-75`).
        let base_raiko = RaikoClient::new(raiko_client_config(&cfg, cfg.raiko_host.clone()));
        let sgx_geth = SgxGethProofProducer::new(base_raiko.clone(), cfg.dummy);
        let base_producer: Arc<dyn ProofProducer> =
            Arc::new(ComposeProofProducer::new_sgx(base_raiko, sgx_geth.clone(), cfg.dummy));
        let zkvm_producer: Option<Arc<dyn ProofProducer>> =
            cfg.raiko_zkvm_host.as_ref().map(|host| {
                Arc::new(ComposeProofProducer::new_zkvm(
                    RaikoClient::new(raiko_client_config(&cfg, host.clone())),
                    sgx_geth.clone(),
                    cfg.dummy,
                )) as Arc<dyn ProofProducer>
            });

        // Buffers/caches keyed exactly like Go `init.go:86-96`: SGX uses the
        // sgx batch size; risc0/sp1 share the zkvm batch size.
        let mut buffers: HashMap<ProofType, Arc<ProofBuffer>> = HashMap::new();
        let mut caches: HashMap<ProofType, Arc<ProofCache>> = HashMap::new();
        buffers.insert(ProofType::Sgx, Arc::new(ProofBuffer::new(cfg.sgx_batch_size)));
        caches.insert(ProofType::Sgx, Arc::new(ProofCache::new()));
        if zkvm_producer.is_some() {
            for proof_type in [ProofType::Risc0, ProofType::Sp1] {
                buffers.insert(proof_type, Arc::new(ProofBuffer::new(cfg.zkvm_batch_size)));
                caches.insert(proof_type, Arc::new(ProofCache::new()));
            }
        }

        let (batch_proofs_tx, batch_proofs_rx) = mpsc::channel(channel_cap);
        let (aggregation_notify_tx, aggregation_notify_rx) = mpsc::channel(channel_cap);
        let (proof_request_tx, proof_request_rx) = mpsc::channel(channel_cap);
        let (flush_cache_tx, flush_cache_rx) = mpsc::channel(channel_cap);

        let pipeline = Arc::new(Pipeline::new(
            base_producer,
            zkvm_producer,
            None,
            buffers,
            caches,
            SubmitterChannels {
                batch_proofs_tx,
                aggregation_notify_tx,
                proof_request_tx,
                flush_cache_tx,
            },
            SubmitterConfig::from_prover_configs(&cfg),
        ));

        let tx_manager = crate::submitter::tx_manager_adapter::build_tx_manager(
            &cfg,
            rpc.l1_provider.root().to_owned(),
        )
        .await?;

        let submitter = Arc::new(ProofSubmitter::new(
            rpc.clone(),
            pipeline.clone(),
            tx_manager,
            prover_address,
        ));

        Ok(Self {
            cfg,
            rpc,
            submitter,
            state: Arc::new(SharedState::new()),
            prover_address,
            proving_window_secs,
            proof_request_rx,
            aggregation_notify_rx,
            flush_cache_rx,
            batch_proofs_rx,
        })
    }

    /// Read `inbox.getCoreState().lastFinalizedProposalId` and `nextProposalId`.
    async fn core_state_ids(&self) -> Result<(u64, u64)> {
        let core_state = self.rpc.core_state().await?;
        Ok((core_state.last_finalized_proposal_id, core_state.next_proposal_id))
    }

    /// Resolve the L1 block to start the scanner from by walking `Proposed`
    /// logs backwards until the start proposal id is covered (Go `initL1Current`
    /// resolves the cursor from the proposal's inclusion block).
    async fn resolve_start_block(&self, starting_id: u64) -> Result<BlockNumberOrTag> {
        if starting_id == 0 {
            return Ok(BlockNumberOrTag::Earliest);
        }
        let head = self.rpc.l1_provider.get_block_number().await.map_err(RpcClientError::from)?;
        let mut to = head;
        loop {
            let from = to.saturating_sub(START_SCAN_WINDOW - 1);
            let logs = self
                .rpc
                .shasta
                .inbox
                .Proposed_filter()
                .from_block(from)
                .to_block(to)
                .query()
                .await
                .map_err(|err| RpcClientError::Contract(err.to_string()))?;
            let covering = logs
                .iter()
                .filter(|(event, _)| event.id.to::<u64>() <= starting_id)
                .filter_map(|(_, log)| log.block_number)
                .min();
            if let Some(block_number) = covering {
                return Ok(BlockNumberOrTag::Number(block_number));
            }
            if from == 0 {
                return Ok(BlockNumberOrTag::Earliest);
            }
            to = from - 1;
        }
    }

    /// Start the prover: resolve the cursor, spawn channel consumers and
    /// background monitors, then run the `Proposed`/`Proved` scanner loops.
    pub async fn start(self) -> Result<()> {
        let (last_finalized, next_id) = self.core_state_ids().await?;
        let starting_id =
            clamp_starting_proposal_id(self.cfg.starting_proposal_id, last_finalized, next_id);
        let start_tag = self.resolve_start_block(starting_id).await?;
        tracing::info!(starting_id, ?start_tag, "resolved prover start cursor");
        seed_start_cursor(&self.state, starting_id);

        let Prover {
            cfg,
            rpc,
            submitter,
            state,
            prover_address,
            proving_window_secs,
            mut proof_request_rx,
            mut aggregation_notify_rx,
            mut flush_cache_rx,
            mut batch_proofs_rx,
        } = self;

        // Background buffer/cache monitors.
        let pipeline = submitter.pipeline();
        spawn_monitors(pipeline.clone(), rpc.clone(), MONITOR_INTERVAL);

        // proof_request consumer: one proving task per proposal.
        let request_submitter = submitter.clone();
        tokio::spawn(async move {
            while let Some(meta) = proof_request_rx.recv().await {
                let submitter = request_submitter.clone();
                tokio::spawn(async move {
                    if let Err(err) = submitter.request_proof(meta).await {
                        tracing::error!(%err, "request proof failed");
                    }
                });
            }
        });

        // aggregation_notify consumer.
        let aggregate_pipeline = submitter.pipeline();
        tokio::spawn(async move {
            while let Some(proof_type) = aggregation_notify_rx.recv().await {
                if let Err(err) = aggregate_pipeline.aggregate_proofs_by_type(proof_type).await {
                    tracing::error!(%err, ?proof_type, "aggregate proofs failed");
                }
            }
        });

        // flush_cache consumer.
        let flush_submitter = submitter.clone();
        tokio::spawn(async move {
            while let Some(proof_type) = flush_cache_rx.recv().await {
                if let Err(err) = flush_submitter.flush_cache(proof_type).await {
                    tracing::error!(%err, ?proof_type, "flush cache failed");
                }
            }
        });

        // batch_proofs consumer: submit with the Go retry/clear contract
        // (`prover.go:225-228` `withRetry(submitProofAggregationOp, …)`).
        let submit_submitter = submitter.clone();
        let submit_pipeline = submitter.pipeline();
        let submit_retry_interval = cfg.proof_polling_interval;
        tokio::spawn(async move {
            while let Some(batch) = batch_proofs_rx.recv().await {
                submit_with_retry(
                    &submit_submitter,
                    &submit_pipeline,
                    &batch,
                    MAX_SUBMISSION_RETRIES,
                    submit_retry_interval,
                )
                .await;
            }
        });

        // Proved consumer: update the verified-id metric.
        let proved_rpc = rpc.clone();
        let proved_source = cfg.l1_provider_source.clone();
        let proved_inbox = cfg.inbox_address;
        tokio::spawn(async move {
            run_proved_scanner(proved_rpc, proved_source, proved_inbox, start_tag).await;
        });

        // Proposed scanner: drive the proving pipeline (runs on this task).
        let ctx = ProposedContext {
            rpc,
            state,
            prover_address,
            proving_window_secs,
            local_proposers: cfg.local_proposer_addresses.clone(),
            prove_unassigned: cfg.prove_unassigned_proposals,
            block_confirmations: cfg.block_confirmations,
            poll_interval: cfg.proof_polling_interval,
            proof_request_tx: pipeline.proof_request_sender(),
        };
        run_proposed_scanner(ctx, cfg.l1_provider_source.clone(), cfg.inbox_address, start_tag)
            .await;
        Ok(())
    }
}

/// What to do with a completed-aggregation buffer after a failed submit attempt,
/// per the Go submit contract (`prover.go:288-329`).
#[derive(Debug, PartialEq, Eq)]
enum SubmitErrorAction {
    /// Already proven / reorged (`InvalidProof`): drop without re-requesting; the
    /// invalid items were already cleared inside `batch_submit_proofs`.
    DropWithoutResend,
    /// On-chain revert or unretryable tx-manager send: clear and re-request the
    /// proofs now (Go's reverted / `ErrUnretryableSubmission` branch).
    ClearAndResend,
    /// Transient validate/wait/build read failure: retry the submit op with the
    /// proofs still buffered (Go's default branch, retried by `withRetry`).
    Retry,
}

/// Classify a submit-attempt error into its Go-equivalent action. A
/// [`ProverError::TxManager`] is treated as terminal/unretryable because the
/// base tx-manager already retries the send internally, mirroring Go's
/// `ErrUnretryableSubmission`.
fn classify_submission_error(err: &ProverError) -> SubmitErrorAction {
    match err {
        ProverError::InvalidProof => SubmitErrorAction::DropWithoutResend,
        ProverError::SubmissionReverted | ProverError::TxManager(_) => {
            SubmitErrorAction::ClearAndResend
        }
        _ => SubmitErrorAction::Retry,
    }
}

/// Submit one completed aggregation, mirroring Go
/// `withRetry(submitProofAggregationOp, clearProofBuffer(resend=true))`
/// (`prover.go:225-228`, `288-329`): success clears the buffer without
/// re-requesting; transient failures retry in place (proofs buffered) up to
/// `max_retries`; revert / unretryable send / retry exhaustion re-requests the
/// proofs; an `InvalidProof` aggregation is dropped without a resend.
async fn submit_with_retry(
    submitter: &ProofSubmitter,
    pipeline: &Pipeline,
    batch: &BatchProofs,
    max_retries: u32,
    retry_interval: Duration,
) {
    for attempt in 0..=max_retries {
        let err = match submitter.batch_submit_proofs(batch).await {
            Ok(()) => {
                let _ = pipeline.clear_proof_buffers(batch, false).await;
                return;
            }
            Err(err) => err,
        };
        match classify_submission_error(&err) {
            SubmitErrorAction::DropWithoutResend => return,
            SubmitErrorAction::ClearAndResend => {
                tracing::error!(%err, "prove submission reverted or unretryable; resending requests");
                let _ = pipeline.clear_proof_buffers(batch, true).await;
                return;
            }
            SubmitErrorAction::Retry => {
                if attempt == max_retries {
                    tracing::error!(
                        %err,
                        attempt,
                        "submit aggregation failed after retries; resending requests"
                    );
                    let _ = pipeline.clear_proof_buffers(batch, true).await;
                    return;
                }
                tracing::warn!(
                    %err,
                    attempt,
                    "submit aggregation failed; retrying with proofs buffered"
                );
                tokio::time::sleep(retry_interval).await;
            }
        }
    }
}

/// Inputs the `Proposed` scanner needs to route proposals.
struct ProposedContext {
    /// Wallet-bound RPC client.
    rpc: Arc<ClientWithWallet>,
    /// Dedup + cursor state.
    state: Arc<SharedState>,
    /// This prover's address.
    prover_address: Address,
    /// Proving window in seconds.
    proving_window_secs: u64,
    /// Extra proposer addresses we prove for.
    local_proposers: Vec<Address>,
    /// Whether to prove unassigned proposals after expiry.
    prove_unassigned: bool,
    /// L1 confirmations before handling an event.
    block_confirmations: u64,
    /// Poll interval for confirmation waits.
    poll_interval: Duration,
    /// Channel for enqueuing proof requests.
    proof_request_tx: mpsc::Sender<ProofRequestMeta>,
}

/// Clamp a configured starting proposal id against core state (Go
/// `initL1Current`, `init.go:135-154`): default to and never precede the last
/// finalized id, and never reach the next (unproposed) id.
#[must_use]
pub fn clamp_starting_proposal_id(starting: Option<u64>, last_finalized: u64, next_id: u64) -> u64 {
    match starting {
        None => last_finalized,
        Some(id) if id >= next_id => last_finalized,
        Some(id) if id < last_finalized => last_finalized,
        Some(id) => id,
    }
}

/// Seed the handled cursor so log replay from an earlier L1 block cannot prove
/// proposals below the operator-selected starting proposal id.
fn seed_start_cursor(state: &SharedState, starting_id: u64) {
    state.mark_handled(starting_id.saturating_sub(1));
}

/// Build a raiko client config from the prover config and a host.
fn raiko_client_config(cfg: &ProverConfigs, host: url::Url) -> RaikoClientConfig {
    RaikoClientConfig {
        endpoint: host,
        api_key: cfg.raiko_api_key.clone(),
        request_timeout: cfg.raiko_request_timeout,
    }
}

/// Derive an L1 address from a private key.
fn address_from_key(key: B256) -> Result<Address> {
    use alloy::signers::local::PrivateKeySigner;
    let signer = PrivateKeySigner::from_bytes(&key)
        .map_err(|err| ProverError::Config(format!("invalid prover private key: {err}")))?;
    Ok(signer.address())
}

/// Build, subscribe, and start an event scanner for `event_signature`, retrying
/// the connect/start steps every 3s until they succeed, then return the live
/// event stream. `start()` consumes the scanner and spawns a detached fetch
/// task, so the returned stream stays live without keeping the scanner around.
async fn connect_scanner(
    source: &rpc::SubscriptionSource,
    inbox_address: Address,
    start_tag: BlockNumberOrTag,
    event_signature: &str,
    scanner_label: &str,
) -> ReceiverStream<EventScannerResult> {
    loop {
        let mut scanner = match source.to_event_scanner_from_tag(start_tag).await {
            Ok(scanner) => scanner,
            Err(err) => {
                tracing::warn!(%err, scanner = scanner_label, "failed to build event scanner; retrying");
                tokio::time::sleep(Duration::from_secs(3)).await;
                continue;
            }
        };
        let filter = EventFilter::new().contract_address(inbox_address).event(event_signature);
        let subscription = scanner.subscribe(filter);
        match scanner.start().await {
            Ok(proof) => {
                tracing::info!(scanner = scanner_label, "prover event scanner started");
                return subscription.stream(&proof);
            }
            Err(err) => {
                tracing::warn!(%err, scanner = scanner_label, "failed to start event scanner; retrying");
                tokio::time::sleep(Duration::from_secs(3)).await;
            }
        }
    }
}

/// Run the `Proved` event scanner, updating the verified-id metric and logging
/// the checkpoint (Go `proofs_received_handler.go`).
async fn run_proved_scanner(
    rpc: Arc<ClientWithWallet>,
    source: rpc::SubscriptionSource,
    inbox_address: Address,
    start_tag: BlockNumberOrTag,
) {
    loop {
        let mut stream =
            connect_scanner(&source, inbox_address, start_tag, Proved::SIGNATURE, "Proved").await;
        while let Some(message) = stream.next().await {
            if let Ok(ScannerMessage::Data(logs)) = message {
                for log in logs {
                    handle_proved_log(&rpc, &log).await;
                }
            }
        }
        tracing::warn!("Proved scanner stream ended; reconnecting");
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

/// Handle one `Proved` log: set the verified-id gauge to the L2 block number of
/// the latest finalized checkpoint and log its context, matching Go
/// `ProofsReceivedEventHandler.Handle` (`proofs_received_handler.go:30-47`).
async fn handle_proved_log(rpc: &ClientWithWallet, log: &alloy::rpc::types::Log) {
    let event = match Proved::decode_raw_log(log.topics(), log.data().data.as_ref()) {
        Ok(event) => event,
        Err(err) => {
            tracing::warn!(%err, "failed to decode Proved event");
            return;
        }
    };
    let core_state = match rpc.core_state().await {
        Ok(core_state) => core_state,
        Err(err) => {
            tracing::warn!(%err, "failed to read core state for Proved event");
            return;
        }
    };

    // Go sets `prover_latestVerified_id` to the L2 BLOCK NUMBER of the finalized
    // checkpoint (resolved from `lastFinalizedBlockHash`), not the proposal id.
    match rpc.l2_provider.get_block_by_hash(core_state.last_finalized_block_hash).await {
        Ok(Some(block)) => ProverMetrics::latest_verified_id().set(block.header.number as f64),
        Ok(None) => tracing::warn!(
            checkpoint_block_hash = %core_state.last_finalized_block_hash,
            "finalized L2 checkpoint block not found yet; skipping verified-id update"
        ),
        Err(err) => tracing::warn!(%err, "failed to fetch finalized L2 checkpoint header"),
    }

    tracing::info!(
        first_proposal_id = event.firstProposalId.to::<u64>(),
        first_new_proposal_id = event.firstNewProposalId.to::<u64>(),
        last_proposal_id = event.lastProposalId.to::<u64>(),
        actual_prover = %event.actualProver,
        checkpoint_block_hash = %core_state.last_finalized_block_hash,
        "new valid proposal proofs received"
    );
}

/// Run the `Proposed` event scanner, routing each proposal into the pipeline
/// (Go `eventLoop` + `proveOp` + `handleProposal`).
async fn run_proposed_scanner(
    ctx: ProposedContext,
    source: rpc::SubscriptionSource,
    inbox_address: Address,
    start_tag: BlockNumberOrTag,
) {
    loop {
        let mut stream =
            connect_scanner(&source, inbox_address, start_tag, Proposed::SIGNATURE, "Proposed")
                .await;
        while let Some(message) = stream.next().await {
            match message {
                Ok(ScannerMessage::Data(logs)) => {
                    for log in logs {
                        if let Err(err) = handle_proposed_log(&ctx, &log).await {
                            tracing::error!(%err, "failed to handle Proposed log");
                        }
                    }
                }
                Ok(ScannerMessage::Notification(Notification::ReorgDetected {
                    common_ancestor,
                })) => {
                    tracing::info!(common_ancestor, "L1 reorg; cursor reset by replay");
                }
                Ok(ScannerMessage::Notification(_)) => {}
                Err(err) => {
                    tracing::error!(?err, "error receiving Proposed logs");
                }
            }
        }
        tracing::warn!("Proposed scanner stream ended; reconnecting");
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

/// Handle a single `Proposed` log: confirmations, dedup, finalized-skip, and
/// routing into the proof-request channel.
async fn handle_proposed_log(ctx: &ProposedContext, log: &alloy::rpc::types::Log) -> Result<()> {
    let event = Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())
        .map_err(|err| ProverError::Other(anyhow::anyhow!("decode Proposed: {err}")))?;
    let proposal_id = event.id.to::<u64>();
    if proposal_id == 0 {
        return Ok(());
    }
    let (Some(block_number), Some(block_hash)) = (log.block_number, log.block_hash) else {
        return Ok(());
    };

    tracing::info!(
        proposal_id,
        l1_block = block_number,
        proposer = %event.proposer,
        "prover received Proposed event"
    );

    wait_for_confirmations(ctx, block_number).await?;

    // Dedup early (without committing) so we skip already-handled proposals, but
    // do the fallible RPC reads before marking handled — a transient failure
    // returns an error (logged by the caller) and leaves the proposal eligible
    // for re-handling rather than silently dropping it.
    if proposal_id <= ctx.state.last_handled_proposal_id() {
        return Ok(());
    }

    // Skip already-finalized proposals cheaply, before any enrichment.
    let core_state = ctx.rpc.core_state().await?;
    if proposal_id <= core_state.last_finalized_proposal_id {
        return Ok(());
    }

    // The proposal timestamp drives the proving window: it is the L1 inclusion
    // block's timestamp (Go builds metadata with `header.Time`).
    let l1_block = ctx
        .rpc
        .l1_provider
        .get_block_by_hash(block_hash)
        .await
        .map_err(RpcClientError::from)?
        .ok_or_else(|| ProverError::Other(anyhow::anyhow!("L1 block {block_hash} missing")))?;
    let proposal_timestamp = l1_block.header.timestamp;

    // Commit the dedup cursor only once the fallible reads have succeeded.
    if !ctx.state.mark_handled(proposal_id) {
        return Ok(());
    }

    let now = current_unix_timestamp();
    let (window_expired, time_to_expire) =
        proving_window_status(proposal_timestamp, ctx.proving_window_secs, now);
    let designated_should_prove =
        should_prove(event.proposer, ctx.prover_address, &ctx.local_proposers);

    let meta = ProofRequestMeta {
        proposal_id,
        proposer: event.proposer,
        proposal_timestamp,
        event_l1_block_number: block_number,
        event_l1_block_hash: block_hash,
    };

    match route_proposal(
        designated_should_prove,
        window_expired,
        time_to_expire,
        ctx.prove_unassigned,
    ) {
        ProvingDecision::SubmitNow => {
            tracing::info!(proposal_id, "proposal is provable; requesting proof now");
            ProverMetrics::received_proposed_id().set(proposal_id as f64);
            ProverMetrics::proofs_assigned().inc();
            let _ = ctx.proof_request_tx.send(meta).await;
        }
        ProvingDecision::WaitForExpiry(delay) => {
            tracing::info!(
                proposal_id,
                delay_secs = delay.as_secs(),
                "proposal not assigned to this prover; waiting for proving-window expiry before proving"
            );
            ProverMetrics::received_proposed_id().set(proposal_id as f64);
            let tx = ctx.proof_request_tx.clone();
            tokio::spawn(async move {
                tokio::time::sleep(delay).await;
                let _ = tx.send(meta).await;
            });
        }
        ProvingDecision::Skip => {
            tracing::info!(proposal_id, "proposal not provable by this prover, skipping");
        }
    }
    Ok(())
}

/// Wait until the event block is at least `block_confirmations` deep, polling
/// the L1 head (Go iterator `BlockConfirmations`).
async fn wait_for_confirmations(ctx: &ProposedContext, block_number: u64) -> Result<()> {
    if ctx.block_confirmations == 0 {
        return Ok(());
    }
    loop {
        let head = ctx.rpc.l1_provider.get_block_number().await.map_err(RpcClientError::from)?;
        if head >= block_number + ctx.block_confirmations {
            return Ok(());
        }
        tokio::time::sleep(ctx.poll_interval).await;
    }
}

/// Current Unix timestamp in seconds.
fn current_unix_timestamp() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use base_tx_manager::TxManagerError;
    use rpc::RpcClientError;

    use super::{
        SubmitErrorAction, clamp_starting_proposal_id, classify_submission_error, seed_start_cursor,
    };
    use crate::{error::ProverError, state::SharedState};

    #[test]
    fn classify_submission_error_matches_go_submit_contract() {
        // Already proven / reorged -> drop without re-requesting.
        assert_eq!(
            classify_submission_error(&ProverError::InvalidProof),
            SubmitErrorAction::DropWithoutResend
        );
        // On-chain revert -> clear and re-request.
        assert_eq!(
            classify_submission_error(&ProverError::SubmissionReverted),
            SubmitErrorAction::ClearAndResend
        );
        // Unretryable tx-manager send (base tx-manager already retried) -> resend.
        assert_eq!(
            classify_submission_error(&ProverError::TxManager(TxManagerError::Rpc(
                "send failed".to_owned()
            ))),
            SubmitErrorAction::ClearAndResend
        );
        // Transient validate/wait/build read errors -> retry with proofs buffered.
        assert_eq!(
            classify_submission_error(&ProverError::Rpc(RpcClientError::Contract(
                "core state read blip".to_owned()
            ))),
            SubmitErrorAction::Retry
        );
        assert_eq!(
            classify_submission_error(&ProverError::Other(anyhow::anyhow!(
                "L1 block not found yet"
            ))),
            SubmitErrorAction::Retry
        );
    }

    #[test]
    fn clamp_matches_go_init_l1_current() {
        // None defaults to last finalized.
        assert_eq!(clamp_starting_proposal_id(None, 10, 15), 10);
        // >= next falls back to last finalized.
        assert_eq!(clamp_starting_proposal_id(Some(20), 10, 15), 10);
        assert_eq!(clamp_starting_proposal_id(Some(15), 10, 15), 10);
        // < last finalized snaps up to last finalized.
        assert_eq!(clamp_starting_proposal_id(Some(7), 10, 15), 10);
        // In-range value is honored.
        assert_eq!(clamp_starting_proposal_id(Some(12), 10, 15), 12);
    }

    #[test]
    fn seed_start_cursor_skips_replayed_events_before_starting_id() {
        let state = SharedState::new();

        seed_start_cursor(&state, 100);

        assert!(!state.mark_handled(99));
        assert!(state.mark_handled(100));
    }
}
