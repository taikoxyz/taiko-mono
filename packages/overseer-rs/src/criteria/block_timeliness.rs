use std::time::SystemTime;

use anyhow::Result;

use super::{BlacklistCriterion, EvaluationContext};
use crate::types::Violation;

/// Checks whether the latest block arrival exceeds the configured time threshold.
#[derive(Debug, Default)]
pub struct BlockTimelinessCriterion;

impl BlockTimelinessCriterion {
    /// Creates a new block timeliness criterion instance.
    pub fn new() -> Self {
        Self
    }
}

#[async_trait::async_trait]
impl BlacklistCriterion for BlockTimelinessCriterion {
    /// Flags a violation when no valid block is observed within the allowed delay.
    async fn evaluate(&self, ctx: &EvaluationContext<'_>) -> Result<Option<Violation>> {
        let last_block_time = ctx.observation.latest_block.timestamp;
        let now = SystemTime::now();
        let Ok(delay) = now.duration_since(last_block_time) else {
            return Ok(None);
        };

        let threshold = ctx.config.expected_block_time + ctx.config.allowable_delay;
        if delay > threshold {
            let reason = format!(
                "latest block #{} delayed by {}s (threshold {}s)",
                ctx.observation.latest_block.number,
                delay.as_secs(),
                threshold.as_secs()
            );
            return Ok(Some(Violation::new(self.name(), reason)));
        }

        Ok(None)
    }

    /// Provides the stable identifier for the criterion.
    fn name(&self) -> &'static str {
        "block_timeliness"
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

    /// Creates a synthetic configuration, observation, and preconfirmer for testing.
    fn build_components(
        delay: Duration,
        expected_block_time: Duration,
    ) -> (
        MonitorConfig,
        Observation,
        Vec<crate::types::StalledTransaction>,
    ) {
        let block_time = SystemTime::now() - delay;

        let observation = Observation {
            latest_block: BlockSnapshot {
                number: 42,
                timestamp: block_time,
                transaction_count: 0,
            },
            pending_transaction_count: 0,
            pending_transactions: Vec::new(),
        };

        let config = MonitorConfig {
            rpc_url: "http://localhost".into(),
            expected_block_time,
            allowable_delay: Duration::from_secs(0),
            allowable_mempool_transactions: 0,
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

    /// Asserts that a delay beyond the threshold triggers a violation.
    #[tokio::test]
    async fn violation_when_delay_exceeds_threshold() {
        let threshold = Duration::from_secs(12);
        let (config, observation, stalled_transactions) =
            build_components(Duration::from_secs(20), threshold);
        let ctx = EvaluationContext {
            config: &config,
            observation: &observation,
            stalled_transactions: &stalled_transactions,
        };

        let criterion = BlockTimelinessCriterion::new();
        let result = criterion.evaluate(&ctx).await.unwrap();
        assert!(result.is_some());
    }

    /// Verifies that delays within the threshold do not trigger violations.
    #[tokio::test]
    async fn no_violation_within_threshold() {
        let threshold = Duration::from_secs(12);
        let (config, observation, stalled_transactions) =
            build_components(Duration::from_secs(5), threshold);
        let ctx = EvaluationContext {
            config: &config,
            observation: &observation,
            stalled_transactions: &stalled_transactions,
        };

        let criterion = BlockTimelinessCriterion::new();
        let result = criterion.evaluate(&ctx).await.unwrap();
        assert!(result.is_none());
    }
}
