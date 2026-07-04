use anyhow::Result;
use async_trait::async_trait;

use crate::{
    monitor_config::MonitorConfig,
    types::{Observation, StalledTransaction, Violation},
};

pub mod block_timeliness;
pub mod mempool_stagnation;
pub mod pending_tx_age;

pub use block_timeliness::BlockTimelinessCriterion;
pub use mempool_stagnation::MempoolStagnationCriterion;
pub use pending_tx_age::PendingTransactionAgeCriterion;

/// Shared context passed to each blacklist criterion during evaluation.
pub struct EvaluationContext<'a> {
    pub config: &'a MonitorConfig,
    pub observation: &'a Observation,
    pub stalled_transactions: &'a [StalledTransaction],
}

/// Trait that a Criteria must implement to evaluate blacklist conditions.
#[async_trait]
pub trait BlacklistCriterion: Send + Sync {
    /// Performs an evaluation and returns a violation when the criterion fails.
    async fn evaluate(&self, ctx: &EvaluationContext<'_>) -> Result<Option<Violation>>;

    /// Returns the human-readable identifier for the criterion.
    fn name(&self) -> &'static str;
}
