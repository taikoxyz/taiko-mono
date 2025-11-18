//! Shasta inbox event indexer implementation.

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};

use alloy::{rpc::types::Log, sol_types::SolEvent};
use alloy_primitives::{Address, B256, U256, aliases::U48};
use alloy_provider::{IpcConnect, Provider, ProviderBuilder, RootProvider, WsConnect};
use bindings::{
    anchor::LibBonds::BondInstruction,
    codec_optimized::{
        CodecOptimized::{self, CodecOptimizedInstance},
        ICheckpointStore::Checkpoint,
        IInbox::{
            CoreState, Derivation, Proposal, ProposedEventPayload as InboxProposedEventPayload,
            ProvedEventPayload as InboxProvedEventPayload, Transition, TransitionMetadata,
            TransitionRecord,
        },
        LibBonds::BondInstruction as CodecBondInstruction,
    },
    i_inbox::IInbox::{self, Proposed, Proved},
};
use dashmap::DashMap;
use event_scanner::{EventFilter, ScannerMessage, ScannerStatus};
use protocol::{
    shasta::codec_optimized::{decode_proposed_event, decode_proved_event},
    subscription_source::SubscriptionSource,
};
use tokio::{spawn, sync::Notify, task::JoinHandle};
use tokio_retry::{Retry, strategy::ExponentialBackoff};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, trace, warn};

use crate::{
    error::{IndexerError, Result},
    interface::{ShastaProposeInput, ShastaProposeInputReader},
    metrics::IndexerMetrics,
};

/// The payload body of a Shasta protocol Proposed event.
#[derive(Clone)]
pub struct ProposedEventPayload {
    /// Proposal metadata emitted by the inbox contract.
    pub proposal: Proposal,
    /// Latest core state after the proposal.
    pub core_state: CoreState,
    /// Derivation data required to reproduce the proposal off-chain.
    pub derivation: Derivation,
    /// Bond instructions finalized while processing this proposal.
    pub bond_instructions: Vec<BondInstruction>,
    /// Raw log of the event.
    pub log: Log,
}

/// The payload body of a Shasta protocol Proved event.
#[derive(Clone)]
pub struct ProvedEventPayload {
    /// Proposal that the proof proves.
    pub proposal_id: U256,
    /// Transition details describing the state change being proven.
    pub transition: Transition,
    /// Additional transition metadata stored in the inbox ring buffer.
    pub transition_record: TransitionRecord,
    /// Prover metadata (designated and actual prover addresses).
    pub metadata: TransitionMetadata,
    /// Raw log of the event.
    pub log: Log,
}

/// Configuration for the Shasta event indexer.
#[derive(Debug, Clone)]
pub struct ShastaEventIndexerConfig {
    /// Source for L1 log streaming.
    pub l1_subscription_source: SubscriptionSource,
    /// Address of the Shasta inbox contract.
    pub inbox_address: Address,
    /// Whether to decode inbox events locally instead of calling the codec contract.
    pub use_local_codec_decoder: bool,
}

/// Maintains live caches of Shasta inbox activity and providing higher-level inputs
/// for downstream components such as the proposer.
pub struct ShastaEventIndexer {
    /// Configuration for the indexer instance.
    config: ShastaEventIndexerConfig,
    /// Contract codec used to decode inbox event payloads.
    inbox_codec: CodecOptimizedInstance<RootProvider>,
    /// Size of the inbox ring buffer for proposals.
    inbox_ring_buffer_size: u64,
    /// Maximum number of transitions allowed in a single proposal finalization.
    max_finalization_count: u64,
    /// Grace period that must elapse before a proved transition becomes finalizable.
    finalization_grace_period: u64,
    /// Whether local decoding is preferred over codec contract calls.
    use_local_codec_decoder: bool,
    /// Cache of recently observed `Proposed` events keyed by proposal id.
    proposed_payloads: DashMap<U256, ProposedEventPayload>,
    /// Cache of recently observed `Proved` events keyed by proposal id.
    proved_payloads: DashMap<U256, ProvedEventPayload>,
    /// Notifier for when historical indexing is finished.
    historical_indexing_finished: Notify,
    /// Tracks whether historical indexing has completed.
    historical_indexing_done: AtomicBool,
}

impl ShastaEventIndexer {
    /// Construct a new indexer instance with the given configuration.
    #[instrument(skip(config), err)]
    pub async fn new(config: ShastaEventIndexerConfig) -> Result<Arc<Self>> {
        let inbox_address = config.inbox_address;
        let provider = match &config.l1_subscription_source {
            SubscriptionSource::Ipc(path) => {
                ProviderBuilder::new().connect_ipc(IpcConnect::new(path.clone())).await?
            }
            SubscriptionSource::Ws(url) => {
                ProviderBuilder::new().connect_ws(WsConnect::new(url.to_string())).await?
            }
        };

        let inbox = IInbox::new(inbox_address, provider.clone());
        let inbox_config = inbox.getConfig().call().await?;
        let ring_buffer_size = inbox_config.ringBufferSize.to();
        let max_finalization_count = inbox_config.maxFinalizationCount.to();
        let finalization_grace_period = inbox_config.finalizationGracePeriod.to();

        info!(
            ?inbox_address,
            ring_buffer_size,
            max_finalization_count,
            finalization_grace_period,
            "shasta inbox contract configuration"
        );

        let use_local_codec_decoder = config.use_local_codec_decoder;

        Ok(Arc::new(Self {
            config,
            inbox_codec: CodecOptimized::new(inbox_config.codec, provider.root().clone()),
            inbox_ring_buffer_size: ring_buffer_size,
            max_finalization_count,
            finalization_grace_period,
            use_local_codec_decoder,
            proposed_payloads: DashMap::new(),
            proved_payloads: DashMap::new(),
            historical_indexing_finished: Notify::new(),
            historical_indexing_done: AtomicBool::new(false),
        }))
    }

    /// Begin streaming and decoding inbox events from the configured L1 upstream.
    #[instrument(skip(self), err)]
    async fn run_inner(self: Arc<Self>) -> Result<()> {
        let source = &self.config.l1_subscription_source;
        info!(
            connection_type = if source.is_ipc() { "IPC" } else { "WebSocket" },
            "subscribing to L1"
        );

        const HISTORICAL_EVENT_MULTIPLIER: usize = 2;
        let replay_count =
            self.ring_buffer_size().saturating_mul(HISTORICAL_EVENT_MULTIPLIER as u64);
        let mut event_scanner =
            source.to_event_scanner_sync_from_latest_scanning(replay_count as usize).await?;

        // Filter for inbox events.
        let filter = EventFilter::new()
            .contract_address(self.config.inbox_address)
            .event(Proposed::SIGNATURE)
            .event(Proved::SIGNATURE);

        let mut stream = event_scanner.subscribe(filter);

        // Start the event scanner in a separate task.
        tokio::spawn(async move {
            if let Err(err) = event_scanner.start().await {
                error!(?err, "event scanner terminated unexpectedly");
            }
        });

        // Process incoming event logs on this task so the indexer instance remains callable
        // elsewhere.
        while let Some(message) = stream.next().await {
            trace!(?message, "received scanner message");

            let logs = match message {
                ScannerMessage::Data(logs) => logs,
                ScannerMessage::Error(err) => {
                    error!(?err, "error receiving logs from event scanner");
                    continue;
                }
                ScannerMessage::Status(status) => {
                    info!(?status, "scanner status update");
                    if matches!(status, ScannerStatus::SwitchingToLive) &&
                        !self.historical_indexing_done.swap(true, Ordering::SeqCst)
                    {
                        self.historical_indexing_finished.notify_waiters();
                    }
                    continue;
                }
            };

            for log in logs {
                let Some(topic) = log.topic0() else {
                    debug!(?log.transaction_hash, "skipping log without topic0");
                    continue;
                };
                info!(?topic, block_number = ?log.block_number, "received inbox event log");

                // Retry handling the event with exponential backoff on failure.
                // Limit retries to avoid indefinite stalls on permanently bad logs.
                let retry_strategy =
                    ExponentialBackoff::from_millis(10).max_delay(Duration::from_secs(12)).take(50);

                let tx_hash = log.transaction_hash;
                let block_number = log.block_number;

                let result = Retry::spawn(retry_strategy, || {
                    let log = log.clone();
                    let indexer = self.clone();
                    async move {
                        if *topic == Proposed::SIGNATURE_HASH {
                            trace!(?log.transaction_hash, "received Proposed event log");
                            indexer.handle_proposed(log.clone()).await.map_err(|err| {
                                metrics::counter!(IndexerMetrics::PROPOSED_EVENT_ERRORS)
                                    .increment(1);
                                warn!(
                                    ?err,
                                    tx_hash = ?log.transaction_hash,
                                    block_number = log.block_number,
                                    "handling Proposed event failed; retrying"
                                );
                                err
                            })
                        } else if *topic == Proved::SIGNATURE_HASH {
                            trace!(?log.transaction_hash, "received Proved event log");
                            indexer.handle_proved(log.clone()).await.map_err(|err| {
                                metrics::counter!(IndexerMetrics::PROVED_EVENT_ERRORS).increment(1);
                                warn!(
                                    ?err,
                                    tx_hash = ?log.transaction_hash,
                                    block_number = log.block_number,
                                    "handling Proved event failed; retrying"
                                );
                                err
                            })
                        } else {
                            warn!(?topic, "skipping unexpected inbox event signature");
                            Ok(())
                        }
                    }
                })
                .await;

                if let Err(err) = result {
                    error!(
                        ?err,
                        ?topic,
                        tx_hash = ?tx_hash,
                        block_number = block_number,
                        "exhausted retries for inbox event; dropping"
                    );
                    metrics::counter!(IndexerMetrics::DROPPED_EVENTS).increment(1);
                }
            }
        }

        Ok(())
    }

    /// Start the indexer event processing loop on a background task.
    #[instrument(skip(self))]
    pub fn spawn(self: Arc<Self>) -> JoinHandle<Result<()>> {
        spawn(async move { self.run_inner().await })
    }

    /// Decode and cache a `Proposed` event payload.
    #[instrument(skip(self, log), err, fields(block_hash = ?log.block_hash, tx_hash = ?log.transaction_hash))]
    async fn handle_proposed(&self, log: Log) -> Result<()> {
        // Decode the event payload using the configured codec path.
        let proposed = Proposed::decode_log_data(log.data())?;
        let InboxProposedEventPayload {
            proposal,
            derivation,
            coreState,
            bondInstructions: codec_bond_instructions,
        } = if self.use_local_codec_decoder {
            decode_proposed_event(proposed.data.as_ref())
                .map_err(|err| IndexerError::Other(err.into()))?
        } else {
            self.inbox_codec.decodeProposedEvent(proposed.data.clone()).call().await?
        };

        // Convert codec-originated bond instructions into the anchor representation used
        // downstream.
        let bond_instructions = codec_bond_instructions
            .into_iter()
            .map(IntoAnchorBondInstruction::into_anchor)
            .collect();

        // Cache the payload keyed by proposal id.
        self.proposed_payloads.insert(
            proposal.id.to::<U256>(),
            ProposedEventPayload {
                proposal: proposal.clone(),
                core_state: coreState.clone(),
                derivation: derivation.clone(),
                bond_instructions,
                log: log.clone(),
            },
        );

        // Record metrics.
        metrics::counter!(IndexerMetrics::PROPOSED_EVENTS).increment(1);
        metrics::gauge!(IndexerMetrics::CACHED_PROPOSALS).set(self.proposed_payloads.len() as f64);
        if let Some(block_number) = log.block_number {
            metrics::gauge!(IndexerMetrics::LATEST_BLOCK).set(block_number as f64);
        }

        info!(?proposal, ?coreState, ?derivation, "cached propose input params");

        // Cleanup old data after caching the new proposal.
        self.cleanup_finalized_transition_records(coreState.lastFinalizedProposalId.to());
        self.cleanup_legacy_proposals(proposal.id.to());

        Ok(())
    }

    /// Decode and cache a `Proved` event payload.
    #[instrument(skip(self, log), err, fields(block_hash = ?log.block_hash, tx_hash = ?log.transaction_hash))]
    async fn handle_proved(&self, log: Log) -> Result<()> {
        // Decode the event payload using the configured codec path.
        let proved = Proved::decode_log_data(log.data())?;
        let InboxProvedEventPayload { proposalId, transition, transitionRecord, metadata } =
            if self.use_local_codec_decoder {
                decode_proved_event(proved.data.as_ref())
                    .map_err(|err| IndexerError::Other(err.into()))?
            } else {
                self.inbox_codec.decodeProvedEvent(proved.data.clone()).call().await?
            };

        // Cache the payload keyed by proposal id.
        let proposal_id = proposalId.to::<U256>();
        let payload = ProvedEventPayload {
            proposal_id,
            transition,
            transition_record: transitionRecord,
            metadata,
            log: log.clone(),
        };
        self.proved_payloads.insert(proposal_id, payload);

        // Record metrics.
        metrics::counter!(IndexerMetrics::PROVED_EVENTS).increment(1);
        metrics::gauge!(IndexerMetrics::CACHED_PROOFS).set(self.proved_payloads.len() as f64);
        if let Some(block_number) = log.block_number {
            metrics::gauge!(IndexerMetrics::LATEST_BLOCK).set(block_number as f64);
        }

        info!(?proposal_id, "cached proved event for proposal");

        Ok(())
    }

    /// Return the most recent proposal payload if one has been observed.
    pub fn get_last_proposal(&self) -> Option<ProposedEventPayload> {
        self.proposed_payloads
            .iter()
            .max_by_key(|entry| *entry.key())
            .map(|entry| entry.value().clone())
    }

    /// Return the cached proposal payload matching the provided identifier, if any.
    pub fn get_proposal_by_id(&self, proposal_id: U256) -> Option<ProposedEventPayload> {
        self.proposed_payloads.get(&proposal_id).map(|entry| entry.value().clone())
    }

    /// Determine which proved transitions are eligible for finalization at the moment, given the
    /// last finalized proposal id and transition hash.
    #[instrument(skip(self), fields(?last_finalized_proposal_id, ?last_finalized_transition_hash))]
    pub fn get_transitions_for_finalization(
        &self,
        last_finalized_proposal_id: U256,
        mut last_finalized_transition_hash: B256,
    ) -> Vec<ProvedEventPayload> {
        let mut transitions = Vec::new();

        if self.max_finalization_count() == 0 {
            debug!("max_finalization_count is zero; no transitions eligible");
            return transitions;
        }

        for offset in 1..=self.max_finalization_count() {
            let proposal_id = last_finalized_proposal_id.saturating_add(U256::from(offset));

            let Some(entry) = self.proved_payloads.get(&proposal_id) else {
                debug!(?proposal_id, "stopping finalization scan; no proved payload cached");
                break;
            };

            let payload = entry.value().clone();
            if payload.transition.parentTransitionHash != last_finalized_transition_hash {
                debug!(
                    ?proposal_id,
                    parent = ?payload.transition.parentTransitionHash,
                    expected = ?last_finalized_transition_hash,
                    "transition parent hash mismatch"
                );
                break;
            }

            last_finalized_transition_hash = payload.transition_record.transitionHash;
            info!(?proposal_id, "transition eligible for finalization");
            transitions.push(payload);
        }

        transitions
    }

    /// Wait till the historical indexing finished.
    pub async fn wait_historical_indexing_finished(&self) {
        if self.historical_indexing_done.load(Ordering::SeqCst) {
            return;
        }
        self.historical_indexing_finished.notified().await;
    }

    /// Return the Shasta inbox ring buffer size.
    pub fn ring_buffer_size(&self) -> u64 {
        self.inbox_ring_buffer_size
    }

    /// Return the Shasta inbox maximum finalization count for a single proposal.
    pub fn max_finalization_count(&self) -> u64 {
        self.max_finalization_count
    }

    /// Return the Shasta inbox finalization grace period in seconds.
    pub fn finalization_grace_period(&self) -> u64 {
        self.finalization_grace_period
    }

    /// Clean up transition records that are older than the last finalized proposal ID minus the
    /// buffer size. We keep two times the buffer size of transition records in cache for now.
    #[instrument(skip(self), fields(last_finalized_proposal_id))]
    fn cleanup_finalized_transition_records(&self, last_finalized_proposal_id: u64) {
        let threshold = last_finalized_proposal_id.saturating_sub(self.inbox_ring_buffer_size * 2);
        let mut removed_count = 0;

        self.proved_payloads.retain(|proposal_id, _| {
            let id = proposal_id.to::<u64>();
            if id < threshold {
                trace!(proposal_id = id, "cleaning up finalized transition record");
                removed_count += 1;
                false
            } else {
                true
            }
        });

        if removed_count > 0 {
            debug!(removed_count, threshold, "cleaned up finalized transition records");
            metrics::gauge!(IndexerMetrics::CACHED_PROOFS).set(self.proved_payloads.len() as f64);
        }
    }

    /// Clean up proposals that are older than the last proposal ID minus the buffer size. We keep
    /// two times the buffer size of proposals in cache for now.
    #[instrument(skip(self), fields(last_proposal_id))]
    fn cleanup_legacy_proposals(&self, last_proposal_id: u64) {
        let threshold = last_proposal_id.saturating_sub(self.inbox_ring_buffer_size * 2);
        let mut removed_count = 0;

        self.proposed_payloads.retain(|proposal_id, _| {
            let id = proposal_id.to::<u64>();
            if id < threshold {
                trace!(proposal_id = id, "cleaning up legacy proposal");
                removed_count += 1;
                false
            } else {
                true
            }
        });

        if removed_count > 0 {
            debug!(removed_count, threshold, "cleaned up legacy proposals");
            metrics::gauge!(IndexerMetrics::CACHED_PROPOSALS)
                .set(self.proposed_payloads.len() as f64);
        }
    }
}

impl ShastaProposeInputReader for ShastaEventIndexer {
    /// Assemble the input for proposing a Shasta inbox proposal.
    #[instrument(skip(self), level = "debug")]
    fn read_shasta_propose_input(&self) -> Option<ShastaProposeInput> {
        let Some(last_proposal) = self.get_last_proposal() else {
            warn!("no proposals cached yet; cannot assemble propose input");
            return None;
        };
        let mut proposals = vec![last_proposal.proposal.clone()];
        let ring_buffer_size = self.ring_buffer_size();
        let last_proposal_id = last_proposal.proposal.id.to::<u64>();

        if ring_buffer_size > 0 && last_proposal_id + 1 >= ring_buffer_size {
            let span = ring_buffer_size.saturating_sub(1);

            let Some(lookup_id) = last_proposal_id.checked_sub(span) else {
                warn!(
                    ring_buffer_size,
                    last_proposal_id, "unable to compute ring-buffer predecessor"
                );
                return None;
            };

            let key = U256::from(lookup_id);
            if let Some(payload) = self.proposed_payloads.get(&key) {
                proposals.push(payload.proposal.clone());
            } else {
                warn!(?key, "ring-buffer predecessor proposal missing; aborting input assembly");
                return None;
            }
        }

        let transitions = self.get_transitions_for_finalization(
            last_proposal.core_state.lastFinalizedProposalId.to::<U256>(),
            last_proposal.core_state.lastFinalizedTransitionHash,
        );
        let checkpoint =
            transitions.last().map(|t| t.transition.checkpoint.clone()).unwrap_or_else(|| {
                Checkpoint { blockNumber: U48::ZERO, blockHash: B256::ZERO, stateRoot: B256::ZERO }
            });

        debug!(
            proposal_count = proposals.len(),
            transition_count = transitions.len(),
            "built Shasta propose input"
        );

        Some(ShastaProposeInput {
            core_state: last_proposal.core_state,
            proposals,
            transition_records: transitions.iter().map(|t| t.transition_record.clone()).collect(),
            checkpoint,
        })
    }
}

/// Bridges ABI-decoded codec bond instructions to the anchor binding type expected elsewhere.
trait IntoAnchorBondInstruction {
    // Convert the codec bond instruction into the anchor representation.
    fn into_anchor(self) -> BondInstruction;
}

impl IntoAnchorBondInstruction for CodecBondInstruction {
    // Convert the codec bond instruction into the anchor representation.
    fn into_anchor(self) -> BondInstruction {
        BondInstruction {
            proposalId: self.proposalId,
            bondType: self.bondType,
            payer: self.payer,
            payee: self.payee,
        }
    }
}

#[cfg(test)]
mod tests {
    use std::{env, str::FromStr, sync::OnceLock};

    use super::*;
    use alloy::{
        network::Ethereum,
        primitives::{Address, B256, Bytes, Log as PrimitiveLog},
        providers::ProviderBuilder,
        transports::http::reqwest::Url,
    };
    use alloy_provider::{Identity, Provider, RootProvider};
    use alloy_signer_local::PrivateKeySigner;
    use anyhow::anyhow;
    use bindings::{
        codec_optimized::{
            ICheckpointStore::Checkpoint,
            IInbox::{
                CoreState, Derivation, Proposal as CodecProposal,
                ProposedEventPayload as CodecProposedEventPayload,
                ProvedEventPayload as CodecProvedEventPayload, Transition, TransitionMetadata,
                TransitionRecord,
            },
        },
        i_inbox::IInbox::IInboxInstance,
    };

    fn init_tracing() {
        static INIT: OnceLock<()> = OnceLock::new();

        INIT.get_or_init(|| {
            let env_filter = tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("debug"));
            let _ = tracing_subscriber::fmt().with_env_filter(env_filter).try_init();
        });
    }

    struct TestSetup {
        indexer: Arc<ShastaEventIndexer>,
        inbox: IInboxInstance<RootProvider>,
    }

    async fn setup() -> anyhow::Result<TestSetup> {
        init_tracing();
        let signer: PrivateKeySigner = env::var("L1_PROPOSER_PRIVATE_KEY")?.parse()?;
        let provider = ProviderBuilder::<Identity, Identity, Ethereum>::default()
            .with_recommended_fillers()
            .wallet(signer)
            .connect_http(Url::from_str(&env::var("L1_HTTP")?)?);

        let config = ShastaEventIndexerConfig {
            l1_subscription_source: SubscriptionSource::Ws(Url::from_str(&env::var("L1_WS")?)?),
            inbox_address: env::var("SHASTA_INBOX")?.parse()?,
            use_local_codec_decoder: true,
        };

        let indexer = ShastaEventIndexer::new(config).await?;

        Ok(TestSetup {
            indexer,
            inbox: IInboxInstance::new(env::var("SHASTA_INBOX")?.parse()?, provider.root().clone()),
        })
    }

    fn proposal_with_id(id: u64) -> CodecProposal {
        let mut proposal = CodecProposal::default();
        proposal.id = U48::from(id);
        proposal
    }

    fn empty_core_state() -> CoreState {
        CoreState {
            nextProposalId: U48::from(0u64),
            lastProposalBlockId: U48::from(0u64),
            lastFinalizedProposalId: U48::from(0u64),
            lastCheckpointTimestamp: U48::from(0u64),
            lastFinalizedTransitionHash: B256::ZERO.into(),
            bondInstructionsHash: B256::ZERO.into(),
        }
    }

    fn empty_derivation() -> Derivation {
        Derivation {
            originBlockNumber: U48::from(0u64),
            originBlockHash: B256::ZERO.into(),
            basefeeSharingPctg: 0,
            sources: Vec::new(),
        }
    }

    fn make_log(indexer: &ShastaEventIndexer, topic: B256, data: Bytes) -> Log {
        Log {
            inner: PrimitiveLog::new_unchecked(indexer.config.inbox_address, vec![topic], data),
            block_hash: None,
            block_number: Some(0),
            block_timestamp: Some(0),
            transaction_hash: None,
            transaction_index: None,
            log_index: None,
            removed: false,
        }
    }

    #[tokio::test]
    async fn handle_proposed_caches_payload() -> anyhow::Result<()> {
        let TestSetup { indexer, inbox: _inbox } = setup().await?;

        let binding_payload = CodecProposedEventPayload {
            proposal: proposal_with_id(1),
            derivation: empty_derivation(),
            coreState: empty_core_state(),
            bondInstructions: Vec::new(),
        };

        let encoded =
            indexer.inbox_codec.encodeProposedEvent(binding_payload.clone()).call().await?;

        // ABI encode the bytes data for the Proposed event
        use alloy::sol_types::SolValue;
        let abi_encoded = encoded.abi_encode();

        let log = make_log(&indexer, Proposed::SIGNATURE_HASH, Bytes::from(abi_encoded));

        indexer.handle_proposed(log).await?;

        let cached = indexer
            .proposed_payloads
            .get(&U256::from(1u64))
            .ok_or_else(|| anyhow!("proposal should be cached"))?;

        assert_eq!(cached.proposal.id, binding_payload.proposal.id);
        Ok(())
    }

    #[tokio::test]
    async fn handle_proved_caches_payload() -> anyhow::Result<()> {
        let TestSetup { indexer, inbox: _inbox } = setup().await?;

        let checkpoint = Checkpoint {
            blockNumber: U48::from(0u64),
            blockHash: B256::ZERO,
            stateRoot: B256::ZERO,
        };

        let binding_payload = CodecProvedEventPayload {
            proposalId: U48::from(1u64),
            transition: Transition {
                proposalHash: B256::from([1u8; 32]).into(),
                parentTransitionHash: B256::from([2u8; 32]).into(),
                checkpoint,
            },
            transitionRecord: TransitionRecord {
                span: 0,
                bondInstructions: Vec::new(),
                transitionHash: B256::from([3u8; 32]).into(),
                checkpointHash: B256::from([4u8; 32]).into(),
            },
            metadata: TransitionMetadata {
                designatedProver: Address::repeat_byte(1).into(),
                actualProver: Address::repeat_byte(2).into(),
            },
        };

        let encoded = indexer.inbox_codec.encodeProvedEvent(binding_payload.clone()).call().await?;

        // ABI encode the bytes data for the Proved event
        use alloy::sol_types::SolValue;
        let abi_encoded = encoded.abi_encode();

        let log = make_log(&indexer, Proved::SIGNATURE_HASH, Bytes::from(abi_encoded));

        indexer.handle_proved(log).await?;

        let cached = indexer
            .proved_payloads
            .get(&U256::from(binding_payload.proposalId.to::<u64>()))
            .ok_or_else(|| anyhow!("proved payload should be cached"))?;

        assert_eq!(cached.metadata.designatedProver, binding_payload.metadata.designatedProver);
        assert_eq!(
            cached.transition_record.transitionHash,
            binding_payload.transitionRecord.transitionHash
        );
        Ok(())
    }
}
