use anyhow::Result;

use super::{BlacklistCriterion, EvaluationContext};
use crate::types::Violation;

/// Detects when pending L2 transactions exceed the configured tolerance.
#[derive(Debug, Default)]
pub struct MempoolStagnationCriterion;

impl MempoolStagnationCriterion {
    /// Creates a new mempool stagnation criterion instance.
    pub fn new() -> Self {
        Self
    }
}

#[async_trait::async_trait]
impl BlacklistCriterion for MempoolStagnationCriterion {
    /// Flags a violation when pending transactions surpass the allowable threshold.
    async fn evaluate(&self, ctx: &EvaluationContext<'_>) -> Result<Option<Violation>> {
        let pending = ctx.observation.pending_transaction_count;
        let allowable = ctx.config.allowable_mempool_transactions;

        if pending > allowable {
            let included = ctx.observation.latest_block.transaction_count;
            let reason = format!(
                "pending tx count {} exceeds allowable {} (latest block included {})",
                pending, allowable, included
            );
            return Ok(Some(Violation::new(self.name(), reason)));
        }

        Ok(None)
    }

    /// Provides the stable identifier for the criterion.
    fn name(&self) -> &'static str {
        "mempool_stagnation"
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{ethereum::BlockSnapshot, monitor_config::MonitorConfig, types::Observation};
    use alloy::primitives::Address;
    use std::{
        path::PathBuf,
        time::{Duration, SystemTime},
    };
    use urc::monitor::config::DatabaseConfig;

    /// Creates a synthetic configuration, observation, and preconfirmer with a specified queue depth.
    fn build_context(
        pending: u64,
        allowable: u64,
    ) -> (
        MonitorConfig,
        Observation,
        Vec<crate::types::StalledTransaction>,
    ) {
        let observation = Observation {
            latest_block: BlockSnapshot {
                number: 42,
                timestamp: SystemTime::now(),
                transaction_count: 10,
            },
            pending_transaction_count: pending,
            pending_transactions: Vec::new(),
        };

        let config = MonitorConfig {
            rpc_url: "http://localhost".into(),
            expected_block_time: Duration::from_secs(12),
            allowable_delay: Duration::from_secs(0),
            allowable_mempool_transactions: allowable,
            poll_interval: Duration::from_secs(1),
            pending_tx_max_age: Duration::from_secs(60),
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

        (config, observation, Vec::new())
    }

    /// Asserts that exceeding the pending threshold returns a violation.
    #[tokio::test]
    async fn violation_when_pending_exceeds_allowable() {
        let (config, observation, stalled_transactions) = build_context(10, 5);
        let ctx = EvaluationContext {
            config: &config,
            observation: &observation,
            stalled_transactions: &stalled_transactions,
        };

        let result = MempoolStagnationCriterion::new()
            .evaluate(&ctx)
            .await
            .expect("evaluation should succeed");
        assert!(result.is_some());
    }

    /// Confirms that pending counts within the threshold do not trigger violations.
    #[tokio::test]
    async fn no_violation_when_within_allowable() {
        let (config, observation, stalled_transactions) = build_context(4, 5);
        let ctx = EvaluationContext {
            config: &config,
            observation: &observation,
            stalled_transactions: &stalled_transactions,
        };

        let result = MempoolStagnationCriterion::new()
            .evaluate(&ctx)
            .await
            .expect("evaluation should succeed");
        assert!(result.is_none());
    }
}
