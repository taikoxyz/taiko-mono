use std::fmt;

use alloy::primitives::B256;

use crate::ethereum::BlockSnapshot;

/// Identifier wrapper for a monitored preconfirmer.
#[derive(Clone, Debug)]
pub struct Preconfirmer {
    pub id: String,
    pub registration_root: B256,
}

impl fmt::Display for Preconfirmer {
    /// Formats the preconfirmer by returning its identifier.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.id)
    }
}

/// Snapshot of the on-chain and mempool state used during evaluation.
#[derive(Clone, Debug)]
pub struct Observation {
    pub latest_block: BlockSnapshot,
    pub pending_transaction_count: u64,
    pub pending_transactions: Vec<PendingTransaction>,
}

/// Metadata describing why a blacklist action was triggered.
#[derive(Clone, Debug)]
pub struct Violation {
    pub criterion: &'static str,
    pub reason: String,
}

impl Violation {
    /// Creates a new violation with a stable criterion name and human-readable reason.
    pub fn new(criterion: &'static str, reason: impl Into<String>) -> Self {
        Self {
            criterion,
            reason: reason.into(),
        }
    }
}

/// Minimal mempool transaction representation tracked between monitor cycles.
#[derive(Clone, Debug)]
pub struct PendingTransaction {
    pub hash: String,
}

/// Captures transactions that have lingered in the mempool beyond the allowed age.
#[derive(Clone, Debug)]
pub struct StalledTransaction {
    pub hash: String,
    pub age: std::time::Duration,
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::B256;

    #[test]
    fn preconfirmer_display_uses_identifier() {
        let preconfirmer = Preconfirmer {
            id: "node-01".into(),
            registration_root: B256::ZERO,
        };

        assert_eq!(preconfirmer.to_string(), "node-01");
    }

    #[test]
    fn violation_new_populates_fields() {
        let violation = Violation::new("criterion", "something went wrong");

        assert_eq!(violation.criterion, "criterion");
        assert_eq!(violation.reason, "something went wrong");
    }
}
