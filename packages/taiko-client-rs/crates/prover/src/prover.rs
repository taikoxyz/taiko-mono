//! The prover service: subscribes to Shasta inbox events and drives the proof
//! pipeline (Go `prover/prover.go` + `prover/init.go`).

use std::{collections::HashMap, sync::Arc, time::Duration};

use alloy::{eips::BlockNumberOrTag, providers::Provider, sol_types::SolEvent};
use alloy_primitives::{Address, B256};
use bindings::inbox::Inbox::{Proposed, Proved};
use event_scanner::{EventFilter, Notification, ScannerMessage};
use rpc::{
    RpcClientError,
    client::{Client, ClientConfig, ClientWithWallet},
};
use tokio::sync::mpsc;
use tokio_stream::StreamExt;

use crate::{
    buffer::ProofBuffer,
    cache::ProofCache,
    config::ProverConfigs,
    error::{ProverError, Result},
    handler::{ProvingDecision, proving_window_status, route_proposal, should_prove},
    metrics::ProverMetrics,
    producer::{ComposeProofProducer, ProofProducer, SgxGethProofProducer},
    raiko::{ProofType, RaikoClient, RaikoClientConfig},
    state::SharedState,
    submitter::{
        Pipeline, ProofRequestMeta, ProofSubmitter, SubmitterChannels, SubmitterConfig,
        monitor::{MONITOR_INTERVAL, spawn_monitors},
    },
};

/// Block-window size when walking `Proposed` logs back to the start cursor.
const START_SCAN_WINDOW: u64 = 10_000;

/// The prover service.
pub struct Prover {
    /// Static configuration.
    cfg: ProverConfigs,
    /// Wallet-bound RPC client.
    rpc: Arc<ClientWithWallet>,
    /// Proof request/aggregate/submit pipeline.
    submitter: Arc<ProofSubmitter>,
    /// Shared RPC-free routing core (for monitors).
    pipeline: Arc<Pipeline>,
    /// Shared cursors (dedup + L1 cursor).
    state: Arc<SharedState>,
    /// This prover's L1 address.
    prover_address: Address,
    /// Proving window in seconds (from `inbox.getConfig()`).
    proving_window_secs: u64,
    /// Receivers paired with the submitter's senders.
    channels: ProverReceivers,
    /// `flush_cache` sender retained for the cache monitor.
    flush_cache_tx: mpsc::Sender<ProofType>,
}

/// Channel receivers owned by the orchestrator (the submitter holds the
/// senders).
struct ProverReceivers {
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
        let sgx_geth = SgxGethProofProducer::new(
            RaikoClient::new(raiko_client_config(&cfg, cfg.raiko_host.clone())),
            cfg.dummy,
        );
        let base_producer: Arc<dyn ProofProducer> = Arc::new(ComposeProofProducer::new_sgx(
            RaikoClient::new(raiko_client_config(&cfg, cfg.raiko_host.clone())),
            sgx_geth.clone(),
            cfg.dummy,
        ));
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
            buffers,
            caches,
            SubmitterChannels {
                batch_proofs_tx,
                aggregation_notify_tx,
                proof_request_tx,
                flush_cache_tx: flush_cache_tx.clone(),
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
            pipeline,
            state: Arc::new(SharedState::new()),
            prover_address,
            proving_window_secs,
            channels: ProverReceivers {
                proof_request_rx,
                aggregation_notify_rx,
                flush_cache_rx,
                batch_proofs_rx,
            },
            flush_cache_tx,
        })
    }

    /// Read `inbox.getCoreState().lastFinalizedProposalId` and `nextProposalId`.
    async fn core_state_ids(&self) -> Result<(u64, u64)> {
        let core_state = self
            .rpc
            .shasta
            .inbox
            .getCoreState()
            .call()
            .await
            .map_err(|err| RpcClientError::Contract(err.to_string()))?;
        Ok((core_state.lastFinalizedProposalId.to::<u64>(), core_state.nextProposalId.to::<u64>()))
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

        let Prover {
            cfg,
            rpc,
            submitter,
            pipeline,
            state,
            prover_address,
            proving_window_secs,
            channels,
            flush_cache_tx,
        } = self;

        let ProverReceivers {
            mut proof_request_rx,
            mut aggregation_notify_rx,
            mut flush_cache_rx,
            mut batch_proofs_rx,
        } = channels;

        // Background buffer/cache monitors.
        spawn_monitors(pipeline.clone(), rpc.clone(), flush_cache_tx, MONITOR_INTERVAL);

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
        let aggregate_submitter = submitter.clone();
        tokio::spawn(async move {
            while let Some(proof_type) = aggregation_notify_rx.recv().await {
                if let Err(err) = aggregate_submitter.aggregate_proofs_by_type(proof_type).await {
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

        // batch_proofs consumer: submit, then clear with the Go error contract
        // (`prover.go:288-329`).
        let submit_submitter = submitter.clone();
        tokio::spawn(async move {
            while let Some(batch) = batch_proofs_rx.recv().await {
                match submit_submitter.batch_submit_proofs(&batch).await {
                    Ok(()) => {
                        let _ = submit_submitter.clear_proof_buffers(&batch, false).await;
                    }
                    Err(ProverError::InvalidProof) => {
                        // Invalid items already cleared inside batch_submit_proofs.
                    }
                    Err(err) => {
                        tracing::error!(%err, "submit aggregation failed, resending requests");
                        let _ = submit_submitter.clear_proof_buffers(&batch, true).await;
                    }
                }
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

/// Run the `Proved` event scanner, updating the verified-id metric (Go
/// `proofs_received_handler.go`).
async fn run_proved_scanner(
    rpc: Arc<ClientWithWallet>,
    source: rpc::SubscriptionSource,
    inbox_address: Address,
    start_tag: BlockNumberOrTag,
) {
    loop {
        let mut scanner = match source.to_event_scanner_from_tag(start_tag).await {
            Ok(scanner) => scanner,
            Err(err) => {
                tracing::warn!(%err, "failed to build Proved scanner; retrying");
                tokio::time::sleep(Duration::from_secs(3)).await;
                continue;
            }
        };
        let filter = EventFilter::new().contract_address(inbox_address).event(Proved::SIGNATURE);
        let subscription = scanner.subscribe(filter);
        let proof = match scanner.start().await {
            Ok(proof) => proof,
            Err(err) => {
                tracing::warn!(%err, "failed to start Proved scanner; retrying");
                tokio::time::sleep(Duration::from_secs(3)).await;
                continue;
            }
        };
        let mut stream = subscription.stream(&proof);
        while let Some(message) = stream.next().await {
            if let Ok(ScannerMessage::Data(logs)) = message {
                for log in logs {
                    let decoded =
                        Proved::decode_raw_log(log.topics(), log.data().data.as_ref()).is_ok();
                    if let (true, Ok(core_state)) =
                        (decoded, rpc.shasta.inbox.getCoreState().call().await)
                    {
                        ProverMetrics::latest_verified_id()
                            .set(core_state.lastFinalizedProposalId.to::<u64>() as f64);
                    }
                }
            }
        }
        tracing::warn!("Proved scanner stream ended; reconnecting");
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
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
        let mut scanner = match source.to_event_scanner_from_tag(start_tag).await {
            Ok(scanner) => scanner,
            Err(err) => {
                tracing::warn!(%err, "failed to build Proposed scanner; retrying");
                tokio::time::sleep(Duration::from_secs(3)).await;
                continue;
            }
        };
        let filter = EventFilter::new().contract_address(inbox_address).event(Proposed::SIGNATURE);
        let subscription = scanner.subscribe(filter);
        let proof = match scanner.start().await {
            Ok(proof) => proof,
            Err(err) => {
                tracing::warn!(%err, "failed to start Proposed scanner; retrying");
                tokio::time::sleep(Duration::from_secs(3)).await;
                continue;
            }
        };
        let mut stream = subscription.stream(&proof);
        tracing::info!("prover Proposed scanner started");
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
    let core_state = ctx
        .rpc
        .shasta
        .inbox
        .getCoreState()
        .call()
        .await
        .map_err(|err| RpcClientError::Contract(err.to_string()))?;
    if proposal_id <= core_state.lastFinalizedProposalId.to::<u64>() {
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
    use super::clamp_starting_proposal_id;

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
}
