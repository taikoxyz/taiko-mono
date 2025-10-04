use std::{sync::Arc, time::SystemTime};

use alloy::{eips::BlockNumberOrTag, network::Ethereum, rpc::types::Log, sol_types::SolEvent};
use alloy_primitives::{Address, B256, U256, aliases::U48};
use alloy_provider::{IpcConnect, Provider, ProviderBuilder, RootProvider, WsConnect};
use bindings::{
    codec_optimized::{
        CodecOptimized::{self, CodecOptimizedInstance},
        ICheckpointStore::Checkpoint,
        IInbox::{
            CoreState, Derivation, Proposal, ProposedEventPayload as InboxProposedEventPayload,
            ProvedEventPayload as InboxProvedEventPayload, Transition, TransitionMetadata,
            TransitionRecord,
        },
    },
    i_inbox::IInbox::{self, Proposed, Proved},
};
use dashmap::DashMap;
use event_scanner::{
    EventFilter,
    event_scanner::EventScanner,
    types::{ScannerMessage, ScannerStatus},
};
use rpc::SubscriptionSource;
use tokio::{sync::Notify, task::JoinHandle};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, warn};

use crate::{
    error::Result,
    interface::{ShastaProposeInput, ShastaProposeInputReader},
};

/// The payload body of a Shasta protocol Proposed event.
#[derive(Debug, Clone)]
pub struct ProposedEventPayload {
    /// Proposal metadata emitted by the inbox contract.
    pub proposal: Proposal,
    /// Latest core state after the proposal.
    pub core_state: CoreState,
    /// Derivation data required to reproduce the proposal off-chain.
    pub derivation: Derivation,
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
    /// Cache of recently observed `Proposed` events keyed by proposal id.
    proposed_payloads: DashMap<U256, ProposedEventPayload>,
    /// Cache of recently observed `Proved` events keyed by proposal id.
    proved_payloads: DashMap<U256, ProvedEventPayload>,
    /// Notifier for when historical indexing is finished.
    historical_indexing_finished: Notify,
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

        Ok(Arc::new(Self {
            config,
            inbox_codec: CodecOptimized::new(inbox_config.codec, provider.root().clone()),
            inbox_ring_buffer_size: ring_buffer_size,
            max_finalization_count,
            finalization_grace_period,
            proposed_payloads: DashMap::new(),
            proved_payloads: DashMap::new(),
            historical_indexing_finished: Notify::new(),
        }))
    }

    /// Begin streaming and decoding inbox events from the configured L1 upstream.
    #[instrument(skip(self), err)]
    async fn run_inner(self: Arc<Self>) -> Result<()> {
        let mut event_scanner = match &self.config.l1_subscription_source {
            SubscriptionSource::Ipc(path) => {
                let ipc_path = path.to_string_lossy().into_owned();
                info!(path = %ipc_path, "subscribing to L1 via IPC");
                EventScanner::new().connect_ipc(ipc_path).await
            }
            SubscriptionSource::Ws(url) => {
                info!(url = %url, "subscribing to L1 via WebSocket");
                EventScanner::new().connect_ws::<Ethereum>(url.clone()).await
            }
        }?;

        let filter = EventFilter::new()
            .with_contract_address(self.config.inbox_address)
            .with_event(Proposed::SIGNATURE)
            .with_event(Proved::SIGNATURE);

        let mut stream = event_scanner.create_event_stream(filter);

        // Start the event scanner in a separate task.
        let scanner_handle = tokio::spawn(async move {
            if let Err(err) = event_scanner.start_scanner(BlockNumberOrTag::Number(0), None).await {
                error!(?err, "event scanner terminated unexpectedly");
            }
        });

        // Process incoming event logs on this task so the indexer instance remains callable
        // elsewhere.
        while let Some(message) = stream.next().await {
            let logs = match message {
                ScannerMessage::Data(logs) => logs,
                ScannerMessage::Error(err) => {
                    error!(?err, "error receiving logs from event scanner");
                    continue;
                }
                ScannerMessage::Status(status) => {
                    info!(?status, "scanner status update");
                    if matches!(status, ScannerStatus::ChainTipReached) {
                        self.historical_indexing_finished.notify_waiters();
                    }
                    continue;
                }
            };

            for log in logs {
                let Some(topic) = log.topic0() else {
                    debug!("skipping log without topic0");
                    continue;
                };

                info!(?topic, block_number = ?log.block_number, "received inbox event log");

                if *topic == Proposed::SIGNATURE_HASH {
                    debug!("received Proposed event log");
                    if let Err(err) = self.handle_proposed(log).await {
                        error!(?err, "failed to handle Proposed inbox event");
                    }
                } else if *topic == Proved::SIGNATURE_HASH {
                    debug!("received Proved event log");
                    if let Err(err) = self.handle_proved(log).await {
                        error!(?err, "failed to handle Proved inbox event");
                    }
                } else {
                    warn!(?topic, "skipping unexpected inbox event signature");
                }
            }
        }

        scanner_handle.abort();
        let _ = scanner_handle.await;

        Ok(())
    }

    /// Start the indexer event processing loop on a background task.
    #[instrument(skip(self))]
    pub fn spawn(self: Arc<Self>) -> JoinHandle<Result<()>> {
        tokio::spawn(async move { self.run_inner().await })
    }

    /// Decode and cache a `Proposed` event payload.
    #[instrument(skip(self, log), err, fields(block_hash = ?log.block_hash, tx_hash = ?log.transaction_hash))]
    async fn handle_proposed(&self, log: Log) -> Result<()> {
        let InboxProposedEventPayload { proposal, derivation, coreState } = self
            .inbox_codec
            .decodeProposedEvent(Proposed::decode_log_data(log.data())?.data)
            .call()
            .await?;

        self.proposed_payloads.insert(
            proposal.id.to::<U256>(),
            ProposedEventPayload {
                proposal: proposal.clone(),
                core_state: coreState.clone(),
                derivation: derivation.clone(),
                log,
            },
        );

        info!(?proposal, ?coreState, ?derivation, "cached propose input params");

        Ok(())
    }

    /// Decode and cache a `Proved` event payload.
    #[instrument(skip(self, log), err, fields(block_hash = ?log.block_hash, tx_hash = ?log.transaction_hash))]
    async fn handle_proved(&self, log: Log) -> Result<()> {
        let InboxProvedEventPayload { proposalId, transition, transitionRecord, metadata } = self
            .inbox_codec
            .decodeProvedEvent(Proved::decode_log_data(log.data())?.data)
            .call()
            .await?;

        let proposal_id = proposalId.to::<U256>();
        let payload = ProvedEventPayload {
            proposal_id,
            transition,
            transition_record: transitionRecord,
            metadata,
            log,
        };
        self.proved_payloads.insert(proposal_id, payload);

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

    /// Determine which proved transitions are eligible for finalization at the moment, given the
    /// last finalized proposal id and transition hash.
    #[instrument(skip(self), fields(?last_finalized_proposal_id, ?last_finalized_transition_hash))]
    pub fn get_transitions_for_finalization(
        &self,
        last_finalized_proposal_id: U256,
        mut last_finalized_transition_hash: B256,
    ) -> Vec<ProvedEventPayload> {
        let mut transitions = Vec::new();
        let now = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap().as_secs();

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
            let block_timestamp = match payload.log.block_timestamp {
                Some(ts) => ts,
                None => {
                    warn!(?proposal_id, "proved payload missing block timestamp; deferring");
                    break;
                }
            };
            if block_timestamp.saturating_add(self.finalization_grace_period()) > now {
                debug!(
                    ?proposal_id,
                    block_timestamp,
                    grace_period = self.finalization_grace_period(),
                    now,
                    "transition still within grace period"
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
}

impl ShastaProposeInputReader for ShastaEventIndexer {
    /// Assemble the input for proposing a Shasta inbox proposal.
    #[instrument(skip(self), level = "debug")]
    fn read_shasta_propose_input(&self) -> Option<ShastaProposeInput> {
        let Some(last_proposal) = self.get_last_proposal() else {
            debug!("no proposals cached yet; cannot assemble propose input");
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

        info!(
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
