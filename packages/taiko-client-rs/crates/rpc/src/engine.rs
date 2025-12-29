//! Execution-engine abstraction for preconfirmation application.
//!
//! This module defines the `PreconfEngine` trait used by the P2P layer to
//! materialize validated preconfirmation commitments into the L2 execution
//! engine. The concrete implementation in `driver` will translate commitments
//! into Shasta payloads and submit them via the engine API.

use std::sync::{Arc, Mutex};

use alloy_primitives::B256;
use async_trait::async_trait;
use preconfirmation_types::SignedCommitment;

/// Snapshot of the execution engine head used by preconfirmation sync logic.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EngineHead {
    /// Head block number reported by the execution engine.
    pub block_number: u64,
    /// Head block hash reported by the execution engine.
    pub block_hash: B256,
}

impl Default for EngineHead {
    /// Return a zeroed head for tests or empty mocks.
    fn default() -> Self {
        Self { block_number: 0, block_hash: B256::ZERO }
    }
}

/// Result of applying a preconfirmation commitment to the execution engine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EngineApplyOutcome {
    /// Block number that was materialized by the engine.
    pub block_number: u64,
    /// Block hash returned by the engine after insertion.
    pub block_hash: B256,
}

/// Errors surfaced by the preconfirmation execution engine.
#[derive(Debug, Clone, thiserror::Error)]
pub enum EngineError {
    /// The engine is unavailable or cannot be reached.
    #[error("execution engine unavailable: {0}")]
    Unavailable(String),
    /// The commitment or derived payload was rejected by the engine.
    #[error("execution engine rejected payload: {0}")]
    Rejected(String),
    /// An unexpected error occurred when executing the commitment.
    #[error("execution engine error: {0}")]
    Other(String),
}

/// Abstraction for submitting preconfirmation payloads to the execution engine.
#[async_trait]
pub trait PreconfEngine: Send + Sync {
    /// Return the current execution engine head.
    async fn engine_head(&self) -> Result<EngineHead, EngineError>;
    /// Report whether the execution engine has finished syncing.
    async fn is_synced(&self) -> Result<bool, EngineError>;
    /// Apply a preconfirmation commitment with an optional txlist payload.
    async fn apply_commitment(
        &self,
        commitment: &SignedCommitment,
        txlist: Option<&[u8]>,
    ) -> Result<EngineApplyOutcome, EngineError>;
    /// Handle an L1 reorg that affects the given anchor block number.
    async fn handle_reorg(&self, anchor_block_number: u64) -> Result<(), EngineError>;
}

/// Recorded call metadata for mock engine apply invocations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MockApplyCall {
    /// Commitment passed to the engine.
    pub commitment: SignedCommitment,
    /// Raw txlist bytes passed to the engine (if any).
    pub txlist: Option<Vec<u8>>,
}

/// In-memory mock implementation of `PreconfEngine` for unit tests.
#[derive(Debug, Clone)]
pub struct MockPreconfEngine {
    /// Stored apply calls for inspection in tests.
    calls: Arc<Mutex<Vec<MockApplyCall>>>,
    /// Current engine head reported by the mock.
    head: Arc<Mutex<EngineHead>>,
    /// Sync flag reported by the mock engine.
    synced: Arc<Mutex<bool>>,
    /// Optional override for apply results.
    apply_result: Arc<Mutex<Option<Result<EngineApplyOutcome, EngineError>>>>,
    /// Recorded reorg notifications by anchor block number.
    reorgs: Arc<Mutex<Vec<u64>>>,
}

impl MockPreconfEngine {
    /// Create a new mock engine with the given head.
    pub fn with_head(head: EngineHead) -> Self {
        Self {
            calls: Arc::new(Mutex::new(Vec::new())),
            head: Arc::new(Mutex::new(head)),
            synced: Arc::new(Mutex::new(true)),
            apply_result: Arc::new(Mutex::new(None)),
            reorgs: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Return a snapshot of recorded apply calls.
    pub fn calls(&self) -> Vec<MockApplyCall> {
        self.calls.lock().expect("mock calls mutex poisoned").clone()
    }

    /// Return a snapshot of recorded reorg notifications.
    pub fn reorgs(&self) -> Vec<u64> {
        self.reorgs.lock().expect("mock reorgs mutex poisoned").clone()
    }

    /// Update the mock engine head.
    pub fn set_head(&self, head: EngineHead) {
        *self.head.lock().expect("mock head mutex poisoned") = head;
    }

    /// Update the mock sync flag.
    pub fn set_synced(&self, synced: bool) {
        *self.synced.lock().expect("mock synced mutex poisoned") = synced;
    }

    /// Override the apply result returned by the mock engine.
    pub fn set_apply_result(&self, result: Option<Result<EngineApplyOutcome, EngineError>>) {
        *self.apply_result.lock().expect("mock result mutex poisoned") = result;
    }
}

impl Default for MockPreconfEngine {
    /// Construct a mock engine with a zeroed head and sync enabled.
    fn default() -> Self {
        Self::with_head(EngineHead::default())
    }
}

#[async_trait]
impl PreconfEngine for MockPreconfEngine {
    /// Return the current mock head.
    async fn engine_head(&self) -> Result<EngineHead, EngineError> {
        Ok(self.head.lock().expect("mock head mutex poisoned").clone())
    }

    /// Return the mock sync status.
    async fn is_synced(&self) -> Result<bool, EngineError> {
        Ok(*self.synced.lock().expect("mock synced mutex poisoned"))
    }

    /// Record the commitment and return the configured apply result.
    async fn apply_commitment(
        &self,
        commitment: &SignedCommitment,
        txlist: Option<&[u8]>,
    ) -> Result<EngineApplyOutcome, EngineError> {
        let call = MockApplyCall {
            commitment: commitment.clone(),
            txlist: txlist.map(|bytes| bytes.to_vec()),
        };
        self.calls.lock().expect("mock calls mutex poisoned").push(call);

        if let Some(result) = self.apply_result.lock().expect("mock result mutex poisoned").clone()
        {
            return result;
        }

        Ok(EngineApplyOutcome {
            block_number: commitment_block_number(commitment),
            block_hash: B256::ZERO,
        })
    }

    /// Record the reorg notification for later inspection.
    async fn handle_reorg(&self, anchor_block_number: u64) -> Result<(), EngineError> {
        self.reorgs.lock().expect("mock reorgs mutex poisoned").push(anchor_block_number);
        Ok(())
    }
}

/// Convert a commitment's `Uint256` block number into a `u64`.
fn commitment_block_number(commitment: &SignedCommitment) -> u64 {
    let le_bytes = commitment.commitment.preconf.block_number.to_bytes_le();
    alloy_primitives::U256::from_le_slice(&le_bytes).to::<u64>()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Ensure the mock engine records an apply call.
    #[tokio::test]
    async fn mock_engine_records_apply_commitment() {
        let engine = MockPreconfEngine::default();
        let commitment = SignedCommitment::default();
        let result = engine.apply_commitment(&commitment, None).await;
        assert!(result.is_ok(), "expected mock apply to succeed");
        assert_eq!(engine.calls().len(), 1);
    }

    /// Ensure the mock engine records reorg notifications.
    #[tokio::test]
    async fn mock_engine_records_reorgs() {
        let engine = MockPreconfEngine::default();
        engine.handle_reorg(42).await.expect("reorg should succeed");
        assert_eq!(engine.reorgs(), vec![42]);
    }
}
