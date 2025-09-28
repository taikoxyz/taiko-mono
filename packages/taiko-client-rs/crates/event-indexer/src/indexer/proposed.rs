use std::{
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};

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
use tracing::warn;

use crate::interface::{ShastaProposeInput, ShastaProposeInputReader};

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
    Ipc(PathBuf),
    Ws(Url),
}

/// Configuration for the Shasta event indexer.
#[derive(Debug, Clone)]
pub struct ShastaEventIndexerConfig {
    pub l1_subscription_source: SubscriptionSource,
    pub l2_rpc_provider: RootProvider,
    pub inbox_address: Address,
}

pub struct ShastaEventIndexer {
    config: ShastaEventIndexerConfig,
    inbox_address: Address,
    inbox_codec: CodecOptimizedInstance<RootProvider>,
    inbox_ring_buffer_size: u64,
    max_finalization_count: u64,
    finalization_grace_period: u64,
    proposed_payloads: DashMap<U256, ProposedEventPayload>,
    proved_payloads: DashMap<U256, ProvedEventPayload>,
}

impl ShastaEventIndexer {
    pub async fn new(config: ShastaEventIndexerConfig) -> Result<Self> {
        let inbox_address = config.inbox_address;
        let l2_rpc_provider = config.l2_rpc_provider.clone();

        let inbox_config =
            IInbox::new(inbox_address, l2_rpc_provider.clone()).getConfig().call().await?;

        Ok(Self {
            config,
            inbox_address,
            inbox_codec: CodecOptimized::new(inbox_config.codec, l2_rpc_provider),
            inbox_ring_buffer_size: inbox_config.ringBufferSize.to(),
            max_finalization_count: inbox_config.maxFinalizationCount.to(),
            finalization_grace_period: inbox_config.finalizationGracePeriod.to(),
            proposed_payloads: DashMap::new(),
            proved_payloads: DashMap::new(),
        })
    }

    pub async fn run(&mut self) -> Result<()> {
        let mut event_scanner = match &self.config.l1_subscription_source {
            SubscriptionSource::Ipc(path) => {
                let ipc_path = path.to_string_lossy().into_owned();
                EventScanner::new().connect_ipc(ipc_path).await
            }
            SubscriptionSource::Ws(url) => {
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
                eprintln!("event scanner failed: {err:?}");
            }
        });

        while let Some(Ok(logs)) = stream.next().await {
            for log in logs {
                // If the log does not have a topic0, skip it.
                let Some(topic) = log.topic0() else {
                    continue;
                };

                match *topic {
                    signature if signature == Proposed::SIGNATURE_HASH => {
                        self.handle_proposed(log).await?;
                    }
                    signature if signature == Proved::SIGNATURE_HASH => {
                        self.handle_proved(log).await?;
                    }
                    _ => {
                        warn!("unknown event topic: {:?}", topic);
                    }
                }
            }
        }
        Ok(())
    }

    pub async fn handle_proposed(&mut self, log: Log) -> Result<()> {
        let InboxProposedEventPayload { proposal, derivation, coreState } =
            self.inbox_codec.decodeProposedEvent(log.data().data.clone()).call().await?;
        let proposal_id = proposal.id.to::<U256>();
        let payload = ProposedEventPayload { proposal, core_state: coreState, derivation, log };

        self.proposed_payloads.insert(proposal_id, payload);

        Ok(())
    }

    pub async fn handle_proved(&mut self, log: Log) -> Result<()> {
        let InboxProvedEventPayload { proposalId, transition, transitionRecord, metadata } =
            self.inbox_codec.decodeProvedEvent(log.data().data.clone()).call().await?;

        let proposal_id = proposalId.to::<U256>();
        let transition_record = transitionRecord;
        let payload =
            ProvedEventPayload { proposal_id, transition, transition_record, metadata, log };

        self.proved_payloads.insert(proposal_id, payload);

        Ok(())
    }

    pub fn get_last_proposal(&self) -> Option<ProposedEventPayload> {
        self.proposed_payloads
            .iter()
            .max_by_key(|entry| *entry.key())
            .map(|entry| entry.value().clone())
    }

    pub fn get_transitions_for_finalization(
        &self,
        last_finalized_proposal_id: U256,
        mut last_finalized_transition_hash: B256,
    ) -> Vec<ProvedEventPayload> {
        let mut transitions = Vec::new();
        let now = current_unix_timestamp();

        if self.max_finalization_count() == 0 {
            return transitions;
        }

        for offset in 1..=self.max_finalization_count() {
            let proposal_id = last_finalized_proposal_id.saturating_add(U256::from(offset));

            let Some(entry) = self.proved_payloads.get(&proposal_id) else {
                break;
            };

            let payload = entry.value().clone();
            if payload.transition.parentTransitionHash != last_finalized_transition_hash {
                break;
            }
            let block_timestamp = match payload.log.block_timestamp {
                Some(ts) => ts,
                None => break,
            };
            if block_timestamp.saturating_add(self.finalization_grace_period()) > now {
                break;
            }

            last_finalized_transition_hash = payload.transition_record.transitionHash.into();
            transitions.push(payload);
        }

        transitions
    }

    pub fn ring_buffer_size(&self) -> u64 {
        self.inbox_ring_buffer_size
    }

    pub fn max_finalization_count(&self) -> u64 {
        self.max_finalization_count
    }

    pub fn finalization_grace_period(&self) -> u64 {
        self.finalization_grace_period
    }
}

impl ShastaProposeInputReader for ShastaEventIndexer {
    fn read_shasta_propose_input(&self) -> Option<ShastaProposeInput> {
        let Some(last_proposal) = self.get_last_proposal() else {
            return None;
        };
        let mut proposals = vec![last_proposal.proposal.clone()];
        let ring_buffer_size = self.ring_buffer_size();
        let last_proposal_id = last_proposal.proposal.id.to::<u64>();

        if ring_buffer_size > 0 && last_proposal_id + 1 >= ring_buffer_size {
            let span = ring_buffer_size.saturating_sub(1);

            let Some(lookup_id) = last_proposal_id.checked_sub(span) else {
                return None;
            };

            let key = U256::from(lookup_id);
            if let Some(payload) = self.proposed_payloads.get(&key) {
                proposals.push(payload.proposal.clone());
            } else {
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

        Some(ShastaProposeInput {
            core_state: last_proposal.core_state,
            proposals,
            transition_records: transitions.iter().map(|t| t.transition_record.clone()).collect(),
            checkpoint,
        })
    }
}

fn current_unix_timestamp() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|duration| duration.as_secs()).unwrap_or(0)
}
