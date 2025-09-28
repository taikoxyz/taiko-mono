use std::path::PathBuf;

use alloy::{
    eips::BlockNumberOrTag, network::Ethereum, rpc::types::Log, sol_types::SolEvent,
    transports::http::reqwest::Url,
};
use alloy_primitives::{Address, B256, U256, aliases::U48};
use alloy_provider::RootProvider;
use anyhow::Result;
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
use event_scanner::{EventFilter, event_scanner::EventScanner};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, warn};

use crate::interface::{ShastaProposeInput, ShastaProposeInputReader};

use super::util::current_unix_timestamp;

/// The payload body of a Shasta protocol Proposed event.
#[derive(Debug, Clone)]
pub struct ProposedEventPayload {
    pub proposal: Proposal,
    pub core_state: CoreState,
    pub derivation: Derivation,
    pub log: Log,
}

/// The payload body of a Shasta protocol Proved event.
#[derive(Clone)]
pub struct ProvedEventPayload {
    pub proposal_id: U256,
    pub transition: Transition,
    pub transition_record: TransitionRecord,
    pub metadata: TransitionMetadata,
    pub log: Log,
}

/// The source from which to subscribe to events.
#[derive(Debug, Clone)]
pub enum SubscriptionSource {
    /// Consume Ethereum logs from a local IPC endpoint.
    Ipc(PathBuf),
    /// Consume Ethereum logs from a remote WebSocket endpoint.
    Ws(Url),
}

/// Configuration for the Shasta event indexer.
#[derive(Debug, Clone)]
pub struct ShastaEventIndexerConfig {
    /// Source for L1 log streaming.
    pub l1_subscription_source: SubscriptionSource,
    /// Provider used to query L2 state.
    pub l2_rpc_provider: RootProvider,
    /// Address of the Shasta inbox contract.
    pub inbox_address: Address,
}

/// Maintains live caches of Shasta inbox activity and providing higher-level inputs
/// for downstream components such as the proposer.
pub struct ShastaEventIndexer {
    /// Configuration for the indexer instance.
    config: ShastaEventIndexerConfig,
    /// Shasta inbox address for filtering and log decoding.
    inbox_address: Address,
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
}

impl ShastaEventIndexer {
    /// Construct a new indexer instance with the given configuration.
    #[instrument(skip(config), err)]
    pub async fn new(config: ShastaEventIndexerConfig) -> Result<Self> {
        let inbox_address = config.inbox_address;
        let l2_rpc_provider = config.l2_rpc_provider.clone();

        let inbox_config =
            IInbox::new(inbox_address, l2_rpc_provider.clone()).getConfig().call().await?;

        let ring_buffer_size = inbox_config.ringBufferSize.to();
        let max_finalization_count = inbox_config.maxFinalizationCount.to();
        let finalization_grace_period = inbox_config.finalizationGracePeriod.to();

        debug!(
            ?inbox_address,
            ring_buffer_size,
            max_finalization_count,
            finalization_grace_period,
            "shasta inbox contract configuration"
        );

        Ok(Self {
            config,
            inbox_address,
            inbox_codec: CodecOptimized::new(inbox_config.codec, l2_rpc_provider),
            inbox_ring_buffer_size: ring_buffer_size,
            max_finalization_count,
            finalization_grace_period,
            proposed_payloads: DashMap::new(),
            proved_payloads: DashMap::new(),
        })
    }

    /// Begin streaming and decoding inbox events from the configured L1 upstream.
    #[instrument(skip(self), err)]
    pub async fn run(&mut self) -> Result<()> {
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
            .with_contract_address(self.inbox_address)
            .with_event(Proposed::SIGNATURE)
            .with_event(Proved::SIGNATURE);

        let mut stream = event_scanner.create_event_stream(filter);

        tokio::spawn(async move {
            if let Err(err) = event_scanner.start_scanner(BlockNumberOrTag::Earliest, None).await {
                error!(?err, "event scanner terminated unexpectedly");
            }
        });

        while let Some(Ok(logs)) = stream.next().await {
            for log in logs {
                // If the log does not have a topic0, skip it.
                let Some(topic) = log.topic0() else {
                    debug!("skipping log without topic0");
                    continue;
                };

                match *topic {
                    signature if signature == Proposed::SIGNATURE_HASH => {
                        debug!("received Proposed event log");
                        self.handle_proposed(log).await?;
                    }
                    signature if signature == Proved::SIGNATURE_HASH => {
                        debug!("received Proved event log");
                        self.handle_proved(log).await?;
                    }
                    _ => {
                        warn!(?topic, "skipping unexpected inbox event signature");
                    }
                }
            }
        }
        Ok(())
    }

    /// Decode and cache a `Proposed` event payload.
    #[instrument(skip(self, log), err, fields(block_hash = ?log.block_hash, tx_hash = ?log.transaction_hash))]
    pub async fn handle_proposed(&mut self, log: Log) -> Result<()> {
        let InboxProposedEventPayload { proposal, derivation, coreState } =
            self.inbox_codec.decodeProposedEvent(log.data().data.clone()).call().await?;
        let proposal_id = proposal.id.to::<U256>();
        let payload = ProposedEventPayload { proposal, core_state: coreState, derivation, log };

        self.proposed_payloads.insert(proposal_id, payload);
        info!(?proposal_id, "cached Proposed event payload");

        Ok(())
    }

    /// Decode and cache a `Proved` event payload.
    #[instrument(skip(self, log), err, fields(block_hash = ?log.block_hash, tx_hash = ?log.transaction_hash))]
    pub async fn handle_proved(&mut self, log: Log) -> Result<()> {
        let InboxProvedEventPayload { proposalId, transition, transitionRecord, metadata } =
            self.inbox_codec.decodeProvedEvent(log.data().data.clone()).call().await?;

        let proposal_id = proposalId.to::<U256>();
        let transition_record = transitionRecord;
        let payload =
            ProvedEventPayload { proposal_id, transition, transition_record, metadata, log };

        self.proved_payloads.insert(proposal_id, payload);
        info!(?proposal_id, "cached Proved event payload");

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
        let now = current_unix_timestamp();

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
