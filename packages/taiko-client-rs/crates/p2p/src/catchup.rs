//! Catch-up pipeline for syncing with network head (spec §6.2, §11–§12).
//!
//! This module implements a state machine for catching up with the network's
//! preconfirmation head. The pipeline:
//! 1. Requests the current head from peers
//! 2. Pages through commitments from local head to network head
//! 3. Enqueues and requests missing txlists by hash
//! 4. Emits `SdkEvent::HeadSyncStatus` transitions

use std::collections::VecDeque;
use std::time::Duration;

use alloy_primitives::B256;

/// Configuration for the catch-up pipeline.
#[derive(Debug, Clone)]
pub struct CatchupConfig {
    /// Maximum number of commitments to request per page.
    pub max_commitments_per_page: u32,
    /// Initial backoff duration for retries.
    pub initial_backoff: Duration,
    /// Maximum backoff duration for retries.
    pub max_backoff: Duration,
    /// Maximum number of retry attempts before giving up.
    pub max_retries: u32,
}

impl Default for CatchupConfig {
    fn default() -> Self {
        Self {
            max_commitments_per_page: 100,
            initial_backoff: Duration::from_millis(500),
            max_backoff: Duration::from_secs(30),
            max_retries: 10,
        }
    }
}

/// State of the catch-up pipeline.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CatchupState {
    /// Not actively syncing; waiting for trigger.
    Idle,
    /// Actively syncing from `current_block` toward `target_block`.
    Syncing {
        /// Current block number we've synced up to.
        current_block: u64,
        /// Target block number to sync to.
        target_block: u64,
    },
    /// Fully synced with the network head.
    Live,
}

/// Actions the catch-up pipeline can request.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CatchupAction {
    /// Request commitments starting from a block number.
    RequestCommitments {
        /// Starting block number.
        start_block: u64,
        /// Maximum number of commitments to request.
        max_count: u32,
    },
    /// Request a raw txlist by hash.
    RequestTxList {
        /// Hash of the txlist to request.
        hash: B256,
    },
    /// No action needed right now (waiting for responses or backoff).
    Wait,
    /// Sync is complete.
    SyncComplete,
}

/// Catch-up pipeline state machine.
///
/// Manages the process of syncing from a local head to the network head by:
/// 1. Requesting commitments in pages
/// 2. Tracking missing txlists and requesting them
/// 3. Handling failures with exponential backoff
#[derive(Debug)]
pub struct CatchupPipeline {
    /// Pipeline configuration.
    config: CatchupConfig,
    /// Current state.
    state: CatchupState,
    /// Queue of missing txlist hashes to request.
    pending_txlists: VecDeque<B256>,
    /// Current retry count.
    retries: u32,
    /// Current backoff duration.
    backoff: Duration,
    /// Whether we're waiting for a response.
    waiting_for_response: bool,
}

impl CatchupPipeline {
    /// Create a new catch-up pipeline with the given configuration.
    pub fn new(config: CatchupConfig) -> Self {
        Self {
            backoff: config.initial_backoff,
            config,
            state: CatchupState::Idle,
            pending_txlists: VecDeque::new(),
            retries: 0,
            waiting_for_response: false,
        }
    }

    /// Get the current state of the pipeline.
    pub fn state(&self) -> &CatchupState {
        &self.state
    }

    /// Start syncing from `start_block` to `target_block`.
    pub fn start_sync(&mut self, start_block: u64, target_block: u64) {
        self.state = CatchupState::Syncing {
            current_block: start_block,
            target_block,
        };
        self.retries = 0;
        self.backoff = self.config.initial_backoff;
        self.pending_txlists.clear();
        self.waiting_for_response = false;
    }

    /// Get the next action the caller should perform.
    pub fn next_action(&mut self) -> CatchupAction {
        match &self.state {
            CatchupState::Idle => CatchupAction::Wait,
            CatchupState::Live => CatchupAction::SyncComplete,
            CatchupState::Syncing { current_block, target_block } => {
                // If we have pending txlists, request them first
                if let Some(hash) = self.pending_txlists.pop_front() {
                    self.waiting_for_response = true;
                    return CatchupAction::RequestTxList { hash };
                }

                // If we've reached or exceeded target, we're done
                if *current_block >= *target_block {
                    self.state = CatchupState::Live;
                    return CatchupAction::SyncComplete;
                }

                // Request next page of commitments
                self.waiting_for_response = true;
                CatchupAction::RequestCommitments {
                    start_block: *current_block,
                    max_count: self.config.max_commitments_per_page,
                }
            }
        }
    }

    /// Called when commitments are received.
    ///
    /// # Arguments
    ///
    /// * `highest_block` - The highest block number in the received commitments.
    /// * `missing_txlist_hashes` - Hashes of txlists that need to be fetched.
    pub fn on_commitments_received(&mut self, highest_block: u64, missing_txlist_hashes: Vec<B256>) {
        self.waiting_for_response = false;
        self.retries = 0;
        self.backoff = self.config.initial_backoff;

        // Add missing txlists to queue
        for hash in missing_txlist_hashes {
            self.pending_txlists.push_back(hash);
        }

        // Update current block
        if let CatchupState::Syncing { current_block, target_block } = &mut self.state {
            // Move to next block after highest received
            *current_block = highest_block + 1;

            // Check if we've reached target
            if *current_block > *target_block && self.pending_txlists.is_empty() {
                self.state = CatchupState::Live;
            }
        }
    }

    /// Called when a txlist is received.
    pub fn on_txlist_received(&mut self, _hash: &B256) {
        self.waiting_for_response = false;
        self.retries = 0;
        self.backoff = self.config.initial_backoff;
        // The txlist is removed from pending_txlists in next_action when popped
    }

    /// Called when a request fails.
    pub fn on_request_failed(&mut self) {
        self.waiting_for_response = false;
        self.retries += 1;

        if self.retries >= self.config.max_retries {
            // Give up and return to idle
            self.state = CatchupState::Idle;
            self.pending_txlists.clear();
            return;
        }

        // Exponential backoff with jitter (simplified - just double)
        self.backoff = std::cmp::min(self.backoff * 2, self.config.max_backoff);
    }

    /// Get the current retry count.
    pub fn retry_count(&self) -> u32 {
        self.retries
    }

    /// Get the current backoff duration.
    pub fn current_backoff(&self) -> Duration {
        self.backoff
    }

    /// Reset the pipeline to idle state.
    pub fn reset(&mut self) {
        self.state = CatchupState::Idle;
        self.pending_txlists.clear();
        self.retries = 0;
        self.backoff = self.config.initial_backoff;
        self.waiting_for_response = false;
    }

    /// Check if the pipeline is currently synced.
    pub fn is_synced(&self) -> bool {
        matches!(self.state, CatchupState::Live)
    }

    /// Check if the pipeline is actively syncing.
    pub fn is_syncing(&self) -> bool {
        matches!(self.state, CatchupState::Syncing { .. })
    }

    /// Update the target block number during sync.
    pub fn update_target(&mut self, new_target: u64) {
        if let CatchupState::Syncing { target_block, .. } = &mut self.state {
            *target_block = new_target;
        }
    }

    /// Get the number of pending txlist requests.
    pub fn pending_txlist_count(&self) -> usize {
        self.pending_txlists.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn catchup_requests_commitments_then_txlists() {
        // Create a catchup state machine
        let config = CatchupConfig::default();
        let mut catchup = CatchupPipeline::new(config);

        // Initially should be Idle
        assert!(matches!(catchup.state(), CatchupState::Idle));

        // Start catchup from block 0 to block 10
        catchup.start_sync(0, 10);
        assert!(matches!(catchup.state(), CatchupState::Syncing { .. }));

        // Get next action - should request commitments first
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestCommitments { start_block: 0, .. }));

        // Simulate receiving commitments with missing txlists
        let missing_hashes = vec![
            alloy_primitives::B256::from([0x11; 32]),
            alloy_primitives::B256::from([0x22; 32]),
        ];
        catchup.on_commitments_received(5, missing_hashes.clone());

        // Next actions should be requesting txlists
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestTxList { hash } if hash == missing_hashes[0]));

        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestTxList { hash } if hash == missing_hashes[1]));

        // Simulate txlists received
        catchup.on_txlist_received(&missing_hashes[0]);
        catchup.on_txlist_received(&missing_hashes[1]);

        // Should request more commitments since we're at block 6 but target is 10
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestCommitments { start_block: 6, .. }));

        // Simulate final commitments received with no missing txlists
        catchup.on_commitments_received(10, vec![]);

        // Should transition to Live
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::SyncComplete));
        assert!(matches!(catchup.state(), CatchupState::Live));
    }

    #[tokio::test]
    async fn catchup_handles_backoff_on_failure() {
        let config = CatchupConfig {
            initial_backoff: std::time::Duration::from_millis(10),
            max_backoff: std::time::Duration::from_millis(100),
            max_retries: 3,
            ..Default::default()
        };
        let mut catchup = CatchupPipeline::new(config);

        catchup.start_sync(0, 10);

        // Get initial action
        let _ = catchup.next_action();

        // Simulate failure
        catchup.on_request_failed();
        assert_eq!(catchup.retry_count(), 1);

        // Should apply backoff
        let backoff = catchup.current_backoff();
        assert!(backoff >= std::time::Duration::from_millis(10));

        // More failures should increase backoff
        catchup.on_request_failed();
        let backoff2 = catchup.current_backoff();
        assert!(backoff2 > backoff);

        // After max retries, should give up and return to Idle
        catchup.on_request_failed();
        assert!(matches!(catchup.state(), CatchupState::Idle));
    }

    #[tokio::test]
    async fn catchup_state_transitions() {
        let config = CatchupConfig::default();
        let mut catchup = CatchupPipeline::new(config);

        // Idle -> Syncing
        assert!(matches!(catchup.state(), CatchupState::Idle));
        catchup.start_sync(0, 5);
        assert!(matches!(catchup.state(), CatchupState::Syncing { .. }));

        // Process through sync
        let _ = catchup.next_action();
        catchup.on_commitments_received(5, vec![]);
        let _ = catchup.next_action();

        // Syncing -> Live
        assert!(matches!(catchup.state(), CatchupState::Live));

        // Can reset back to Idle
        catchup.reset();
        assert!(matches!(catchup.state(), CatchupState::Idle));
    }
}
