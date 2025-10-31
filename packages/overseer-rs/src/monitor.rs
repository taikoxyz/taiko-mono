use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
    time::Instant,
};

use alloy::primitives::{B256, U256};
use anyhow::{anyhow, Result};
use tokio::{sync::Mutex, time};
use tracing::{error, info, warn};

use crate::{
    contracts::BlacklistContract,
    criteria::{BlacklistCriterion, EvaluationContext},
    ethereum::{collect_observation, EthereumClient},
    metrics::Metrics,
    monitor_config::MonitorConfig,
    types::{PendingTransaction, StalledTransaction, Violation},
};
use urc::{
    bindings::ILookaheadStore::LookaheadData, lookahead::lookahead_builder::LookaheadBuilder,
};

/// Coordinates periodic evaluations of the active preconfirmer against blacklist criteria.
pub struct Monitor {
    config: MonitorConfig,
    ethereum: Arc<dyn EthereumClient>,
    blacklist_contract: Arc<dyn BlacklistContract>,
    lookahead_builder: Mutex<LookaheadBuilder>,
    criteria: Vec<Box<dyn BlacklistCriterion>>,
    pending_tracker: Mutex<HashMap<String, Instant>>,
    metrics: Arc<Metrics>,
}

impl Monitor {
    /// Creates a new monitor with the given configuration, clients, and criteria list.
    pub fn new(
        config: MonitorConfig,
        ethereum: Arc<dyn EthereumClient>,
        blacklist_contract: Arc<dyn BlacklistContract>,
        lookahead_builder: LookaheadBuilder,
        criteria: Vec<Box<dyn BlacklistCriterion>>,
        metrics: Arc<Metrics>,
    ) -> Self {
        Self {
            config,
            ethereum,
            blacklist_contract,
            lookahead_builder: Mutex::new(lookahead_builder),
            criteria,
            pending_tracker: Mutex::new(HashMap::new()),
            metrics,
        }
    }

    /// Runs the monitor loop until interrupted, periodically evaluating criteria.
    pub async fn run(&self) -> Result<()> {
        info!(
            target: "overseer::service",
            poll_interval = self.config.poll_interval.as_secs(),
            "starting monitor service"
        );

        self.execute_cycle().await?;

        let mut interval = time::interval(self.config.poll_interval);
        loop {
            tokio::select! {
                _ = interval.tick() => {
                    if let Err(err) = self.execute_cycle().await {
                        error!(target: "overseer::service", error = ?err, "cycle execution failed");
                    }
                }
                signal = tokio::signal::ctrl_c() => {
                    match signal {
                        Ok(()) => info!(target: "overseer::service", "shutdown signal received"),
                        Err(err) => error!(target: "overseer::service", error = ?err, "failed to listen for shutdown signal"),
                    }
                    break;
                }
            }
        }

        Ok(())
    }

    /// Executes a single evaluation cycle for the active preconfirmer, if one exists.
    async fn execute_cycle(&self) -> Result<()> {
        let observation = match collect_observation(self.ethereum.as_ref()).await {
            Ok(observation) => observation,
            Err(err) => {
                self.metrics.inc_observation_errors();
                error!(target: "overseer::service", error = ?err, "failed to collect observation");
                return Err(err);
            }
        };

        let stalled_transactions = self
            .identify_stalled_transactions(&observation.pending_transactions)
            .await;

        let ctx = EvaluationContext {
            config: &self.config,
            observation: &observation,
            stalled_transactions: &stalled_transactions,
        };

        for criterion in &self.criteria {
            match criterion.evaluate(&ctx).await {
                Ok(Some(violation)) => {
                    match self.resolve_preconfirmer().await? {
                        Some(preconfirmer) => {
                            let reason = violation.reason.clone();
                            warn!(
                                target: "overseer::service",
                                preconfirmer = %preconfirmer,
                                criterion = violation.criterion,
                                reason = %reason,
                                "blacklist criterion triggered"
                            );
                            if let Err(err) = self.execute_blacklist(&preconfirmer, violation).await
                            {
                                error!(
                                    target: "overseer::service",
                                    preconfirmer = %preconfirmer,
                                    error = ?err,
                                    "blacklist execution failed"
                                );
                            }
                        }
                        None => {
                            warn!(
                                target: "overseer::service",
                                "unable to resolve preconfirmer for violation; skipping blacklist"
                            );
                        }
                    }
                    break;
                }
                Ok(None) => {}
                Err(err) => {
                    self.metrics.inc_criterion_errors();
                    error!(
                        target: "overseer::service",
                        criterion = criterion.name(),
                        error = ?err,
                        "criterion evaluation failed"
                    );
                }
            }
        }

        Ok(())
    }

    async fn resolve_preconfirmer(&self) -> Result<Option<crate::types::Preconfirmer>> {
        let lookahead_result = {
            let mut builder = self.lookahead_builder.lock().await;
            builder.get_lookahead_data().await
        };

        let (slot_index_u256, curr_lookahead) = match lookahead_result {
            Ok((_, data)) => {
                let LookaheadData {
                    slotIndex,
                    currLookahead,
                    ..
                } = data;
                (slotIndex, currLookahead)
            }
            Err(err) => {
                error!(
                    target: "overseer::service",
                    error = ?err,
                    "failed to fetch lookahead data"
                );
                return Err(err);
            }
        };

        if curr_lookahead.is_empty() {
            warn!(
                target: "overseer::service",
                "lookahead data returned no slots"
            );
            return Ok(None);
        }

        if slot_index_u256 == U256::MAX {
            warn!(
                target: "overseer::service",
                "lookahead slot index is max value; skipping cycle"
            );
            return Ok(None);
        }

        let slot_index: usize = slot_index_u256
            .try_into()
            .map_err(|_| anyhow!("lookahead slot index exceeds usize bounds"))?;

        let lookahead_slot = match curr_lookahead.get(slot_index) {
            Some(slot) => slot,
            None => {
                warn!(
                    target: "overseer::service",
                    slot_index,
                    lookahead_len = curr_lookahead.len(),
                    "lookahead slot index out of bounds"
                );
                return Ok(None);
            }
        };

        let committer = lookahead_slot.committer;
        let committer_hex = format!("{committer:#x}");
        let registration_root = B256::from(lookahead_slot.registrationRoot);

        Ok(Some(crate::types::Preconfirmer {
            id: committer_hex,
            registration_root,
        }))
    }

    /// Dispatches a blacklist request for the provided violation using the contract client.
    async fn execute_blacklist(
        &self,
        preconfirmer: &crate::types::Preconfirmer,
        violation: Violation,
    ) -> Result<()> {
        match self
            .blacklist_contract
            .blacklist(preconfirmer, &violation)
            .await
        {
            Ok(()) => {
                self.metrics.inc_blacklist_calls();
                Ok(())
            }
            Err(err) => {
                self.metrics.inc_blacklist_errors();
                Err(err)
            }
        }
    }

    async fn identify_stalled_transactions(
        &self,
        pending: &[PendingTransaction],
    ) -> Vec<StalledTransaction> {
        let mut tracker = self.pending_tracker.lock().await;
        let now = Instant::now();
        let mut seen = HashSet::with_capacity(pending.len());
        let mut stalled = Vec::new();

        for tx in pending {
            let hash = tx.hash.clone();
            seen.insert(hash.clone());
            let entry = tracker.entry(hash.clone()).or_insert(now);
            let age = now.duration_since(*entry);
            if age >= self.config.pending_tx_max_age {
                stalled.push(StalledTransaction { hash, age });
            }
        }

        tracker.retain(|hash, _| seen.contains(hash));

        stalled
    }
}
