use anyhow::Result;

use super::{BlacklistCriterion, EvaluationContext};
use crate::types::Violation;

/// Flags preconfirmers when transactions linger in the mempool beyond the allowed age.
#[derive(Debug, Default)]
pub struct PendingTransactionAgeCriterion;

impl PendingTransactionAgeCriterion {
    /// Creates a new pending transaction age criterion instance.
    pub fn new() -> Self {
        Self
    }
}

#[async_trait::async_trait]
impl BlacklistCriterion for PendingTransactionAgeCriterion {
    /// Emits a violation if any tracked transaction exceeds the configured maximum age.
    async fn evaluate(&self, ctx: &EvaluationContext<'_>) -> Result<Option<Violation>> {
        if let Some(oldest) = ctx.stalled_transactions.iter().max_by_key(|tx| tx.age) {
            let reason = format!(
                "{} pending transactions older than {}s (oldest {} aged {}s)",
                ctx.stalled_transactions.len(),
                ctx.config.pending_tx_max_age.as_secs(),
                oldest.hash,
                oldest.age.as_secs()
            );
            return Ok(Some(Violation::new(self.name(), reason)));
        }

        Ok(None)
    }

    /// Provides the stable identifier for the criterion.
    fn name(&self) -> &'static str {
        "pending_tx_age"
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        ethereum::BlockSnapshot,
        monitor_config::MonitorConfig,
        types::{Observation, StalledTransaction},
    };
    use alloy::primitives::Address;
    use std::{
        path::PathBuf,
        time::{Duration, SystemTime},
    };
    use urc::monitor::config::DatabaseConfig;

    fn build_context(
        stalled: Vec<StalledTransaction>,
        max_age: Duration,
    ) -> (MonitorConfig, Observation, Vec<StalledTransaction>) {
        let config = MonitorConfig {
            rpc_url: "http://localhost".into(),
            expected_block_time: Duration::from_secs(12),
            allowable_delay: Duration::from_secs(0),
            allowable_mempool_transactions: 0,
            poll_interval: Duration::from_secs(1),
            pending_tx_max_age: max_age,
            registry_settings: crate::monitor_config::RegistrySettings {
                database: DatabaseConfig::Sqlite {
                    path: PathBuf::from("./test-registry.db"),
                },
                l1_rpc_url: "http://localhost".into(),
                registry_address: "0x0000000000000000000000000000000000000000".into(),
                l1_start_block: 1,
                max_l1_fork_depth: 2,
                index_block_batch_size: 25,
            },
            preconf_slasher: "0x0000000000000000000000000000000000000000".into(),
            criteria: crate::monitor_config::CriteriaToggles {
                block_timeliness: true,
                mempool_stagnation: true,
                pending_tx_age: true,
            },
            lookahead: crate::monitor_config::LookaheadSettings {
                store_address: Address::ZERO,
                consensus_rpc_url: "http://localhost".into(),
                consensus_rpc_timeout_secs: 10,
                genesis_slot: 0,
                genesis_timestamp: 0,
                slot_duration_secs: 12,
                slots_per_epoch: 32,
                heartbeat_ms: 1000,
            },
        };

        let observation = Observation {
            latest_block: BlockSnapshot {
                number: 42,
                timestamp: SystemTime::now(),
                transaction_count: 10,
            },
            pending_transaction_count: 0,
            pending_transactions: Vec::new(),
        };

        (config, observation, stalled)
    }

    /// Asserts that aged transactions trigger a violation.
    #[tokio::test]
    async fn violation_when_stalled_transactions_exist() {
        let stalled = vec![StalledTransaction {
            hash: "0xabc".into(),
            age: Duration::from_secs(30),
        }];
        let (config, observation, stalled_transactions) =
            build_context(stalled, Duration::from_secs(10));

        let ctx = EvaluationContext {
            config: &config,
            observation: &observation,
            stalled_transactions: &stalled_transactions,
        };

        let result = PendingTransactionAgeCriterion::new()
            .evaluate(&ctx)
            .await
            .expect("evaluation should succeed");
        assert!(result.is_some());
    }

    /// Ensures that the absence of stalled transactions yields no violation.
    #[tokio::test]
    async fn no_violation_without_stalled_transactions() {
        let (config, observation, stalled_transactions) =
            build_context(Vec::new(), Duration::from_secs(10));

        let ctx = EvaluationContext {
            config: &config,
            observation: &observation,
            stalled_transactions: &stalled_transactions,
        };

        let result = PendingTransactionAgeCriterion::new()
            .evaluate(&ctx)
            .await
            .expect("evaluation should succeed");
        assert!(result.is_none());
    }
}
