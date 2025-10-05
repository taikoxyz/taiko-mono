//! Event sync logic.

use std::{
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::Duration,
};

use alloy::{eips::BlockNumberOrTag, primitives::U256};
use alloy_provider::Provider;
use metrics::gauge;
use tokio::{
    pin,
    time::{MissedTickBehavior, interval},
};
use tracing::{debug, info, warn};

use super::{SyncError, SyncStage};
use crate::derivation::manifest::{ManifestFetcher, ShastaManifestFetcher};
use crate::{
    config::DriverConfig,
    derivation::{DerivationOutcome, DerivationPipeline, ShastaDerivationPipeline},
    metrics::DriverMetrics,
};
use event_indexer::{
    indexer::{ShastaEventIndexer, ShastaEventIndexerConfig},
    interface::ShastaProposeInputReader,
};

/// Responsible for following inbox events and updating the execution engine accordingly.
pub struct EventSyncer<P>
where
    P: Provider + Clone,
{
    rpc: rpc::client::Client<P>,
    cfg: DriverConfig,
    last_processed_proposal: AtomicU64,
}

impl<P> EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    pub fn new(rpc: rpc::client::Client<P>, cfg: DriverConfig) -> Self {
        Self { rpc, cfg, last_processed_proposal: AtomicU64::new(0) }
    }

    async fn bootstrap_indexer(&self) -> Result<Arc<ShastaEventIndexer>, SyncError> {
        let config = ShastaEventIndexerConfig {
            l1_subscription_source: self.cfg.client.l1_provider_source.clone(),
            inbox_address: self.cfg.client.inbox_address,
        };

        ShastaEventIndexer::new(config).await.map_err(|err| SyncError::Event(err.to_string()))
    }
}

#[async_trait::async_trait]
impl<P> SyncStage for EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn run(&self) -> Result<(), SyncError> {
        let indexer = self.bootstrap_indexer().await?;
        let handle = indexer.clone().spawn();
        let manifest_fetcher: Arc<dyn ManifestFetcher> = Arc::new(ShastaManifestFetcher::default());
        let derivation: Arc<dyn DerivationPipeline> =
            Arc::new(ShastaDerivationPipeline::new(self.rpc.clone(), manifest_fetcher));

        // Wait for historical indexing to finish before we start deriving payloads.
        indexer.wait_historical_indexing_finished().await;

        if let Ok(block) = self.rpc.l2_provider.get_block_by_number(BlockNumberOrTag::Latest).await
        {
            if let Some(block) = block {
                info!(number = block.number(), "current L2 head before syncing");
            }
        }

        let poll_interval = if self.cfg.retry_interval.is_zero() {
            Duration::from_secs(5)
        } else {
            self.cfg.retry_interval
        };

        let mut ticker = interval(poll_interval);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);

        let mut last_processed = self.last_processed_proposal.load(Ordering::Relaxed);
        pin!(handle);

        loop {
            tokio::select! {
                result = &mut handle => {
                    match result {
                        Ok(Ok(())) => {
                            return Err(SyncError::Event("event indexer task terminated unexpectedly".into()));
                        }
                        Ok(Err(err)) => {
                            return Err(SyncError::Event(err.to_string()));
                        }
                        Err(join_err) => {
                            return Err(SyncError::Event(join_err.to_string()));
                        }
                    }
                }
                _ = ticker.tick() => {
                    if let Some(input) = indexer.read_shasta_propose_input() {
                        let next_proposal_id = input.core_state.nextProposalId.to::<u64>();
                        let finalized_id = input.core_state.lastFinalizedProposalId.to::<u64>();
                        gauge!(DriverMetrics::NEXT_PROPOSAL_ID).set(next_proposal_id as f64);
                        gauge!(DriverMetrics::LAST_FINALIZED_PROPOSAL_ID).set(finalized_id as f64);
                        gauge!(DriverMetrics::TRANSITION_QUEUE_DEPTH)
                            .set(input.transition_records.len() as f64);
                    }

                    if let Some(latest_payload) = indexer.get_last_proposal() {
                        let latest_id = latest_payload.proposal.id.to::<u64>();

                        while last_processed < latest_id {
                            let candidate = last_processed + 1;
                            let key = U256::from(candidate);

                            let Some(payload) = indexer.get_proposal_by_id(key) else {
                                break;
                            };

                            match derivation.process_proposal(&payload).await {
                                Ok(DerivationOutcome::Applied { .. }) | Ok(DerivationOutcome::Skipped { .. }) => {
                                    last_processed = candidate;
                                }
                                Ok(DerivationOutcome::Pending { .. }) => {
                                    break;
                                }
                                Err(err) => {
                                    warn!(proposal_id = candidate, ?err, "derivation pipeline failed");
                                    break;
                                }
                            }
                        }

                        self.last_processed_proposal.store(last_processed, Ordering::Relaxed);
                    } else {
                        debug!("no shasta proposals observed yet");
                    }
                }
            }
        }
    }
}
