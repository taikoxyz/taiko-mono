//! Catch-up pipeline for syncing with network head (spec §6.2, §11–§12).
//!
//! This module implements a state machine for catching up with the network's
//! preconfirmation head. The pipeline:
//! 1. Requests the current head from peers
//! 2. Pages through commitments from local head to network head
//! 3. Enqueues and requests missing txlists by hash
//! 4. Emits `SdkEvent::HeadSyncStatus` transitions

use std::{collections::VecDeque, time::Duration};

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
    /// Awaiting network head response before syncing.
    AwaitingHead {
        /// Local block number to sync from.
        local_head: u64,
    },
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
    /// Request the current network head from peers.
    RequestHead,
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
/// 1. Requesting the network head from peers
/// 2. Requesting commitments in pages
/// 3. Tracking missing txlists and requesting them
/// 4. Handling failures with exponential backoff
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
    /// Instant when the backoff period expires (None if not in backoff).
    backoff_until: Option<std::time::Instant>,
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
            backoff_until: None,
        }
    }

    /// Get the current state of the pipeline.
    pub fn state(&self) -> &CatchupState {
        &self.state
    }

    /// Start syncing from `start_block` to `target_block`.
    pub fn start_sync(&mut self, start_block: u64, target_block: u64) {
        self.state = CatchupState::Syncing { current_block: start_block, target_block };
        self.retries = 0;
        self.backoff = self.config.initial_backoff;
        self.backoff_until = None;
        self.pending_txlists.clear();
        self.waiting_for_response = false;
    }

    /// Start catch-up by first requesting the network head.
    ///
    /// This transitions to `AwaitingHead` state and will request the head
    /// before beginning the sync process.
    pub fn start_catchup(&mut self, local_head: u64) {
        self.state = CatchupState::AwaitingHead { local_head };
        self.retries = 0;
        self.backoff = self.config.initial_backoff;
        self.backoff_until = None;
        self.pending_txlists.clear();
        self.waiting_for_response = false;
    }

    /// Called when the network head is received.
    ///
    /// Transitions from `AwaitingHead` to `Syncing` if there are blocks to sync,
    /// or to `Live` if already at the head.
    pub fn on_head_received(&mut self, network_head: u64) {
        self.waiting_for_response = false;
        self.retries = 0;
        self.backoff = self.config.initial_backoff;
        self.backoff_until = None;

        if let CatchupState::AwaitingHead { local_head } = self.state {
            if local_head >= network_head {
                // Already synced
                self.state = CatchupState::Live;
            } else {
                // Need to sync
                self.state =
                    CatchupState::Syncing { current_block: local_head, target_block: network_head };
            }
        }
    }

    /// Get the next action the caller should perform.
    pub fn next_action(&mut self) -> CatchupAction {
        // Check if we're in backoff
        if self.is_in_backoff() {
            return CatchupAction::Wait;
        }

        // Check if we're waiting for a response
        if self.waiting_for_response {
            return CatchupAction::Wait;
        }

        match &self.state {
            CatchupState::Idle => CatchupAction::Wait,
            CatchupState::AwaitingHead { .. } => {
                // Request the network head
                self.waiting_for_response = true;
                CatchupAction::RequestHead
            }
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
    pub fn on_commitments_received(
        &mut self,
        highest_block: u64,
        missing_txlist_hashes: Vec<B256>,
    ) {
        self.waiting_for_response = false;
        self.retries = 0;
        self.backoff = self.config.initial_backoff;
        self.backoff_until = None;

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
        self.backoff_until = None;
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
            self.backoff_until = None;
            return;
        }

        // Exponential backoff with jitter (simplified - just double)
        self.backoff = std::cmp::min(self.backoff * 2, self.config.max_backoff);
        // Set backoff expiry time
        self.backoff_until = Some(std::time::Instant::now() + self.backoff);
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
        self.backoff_until = None;
    }

    /// Check if the pipeline is currently in a backoff period.
    pub fn is_in_backoff(&self) -> bool {
        self.backoff_until.map(|until| std::time::Instant::now() < until).unwrap_or(false)
    }

    /// Get the remaining backoff duration, if any.
    ///
    /// Returns `Some(duration)` if in backoff, `None` otherwise.
    pub fn remaining_backoff(&self) -> Option<Duration> {
        self.backoff_until.and_then(|until| {
            let now = std::time::Instant::now();
            if now < until { Some(until - now) } else { None }
        })
    }

    /// Check if the pipeline is currently synced.
    pub fn is_synced(&self) -> bool {
        matches!(self.state, CatchupState::Live)
    }

    /// Check if the pipeline is actively syncing (including awaiting head).
    pub fn is_syncing(&self) -> bool {
        matches!(self.state, CatchupState::Syncing { .. } | CatchupState::AwaitingHead { .. })
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

        // Next action should be requesting first txlist
        let action = catchup.next_action();
        assert!(
            matches!(action, CatchupAction::RequestTxList { hash } if hash == missing_hashes[0])
        );

        // Simulate first txlist received (clears waiting_for_response)
        catchup.on_txlist_received(&missing_hashes[0]);

        // Now request second txlist
        let action = catchup.next_action();
        assert!(
            matches!(action, CatchupAction::RequestTxList { hash } if hash == missing_hashes[1])
        );

        // Simulate second txlist received
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

    #[tokio::test]
    async fn catchup_requests_head_first() {
        let config = CatchupConfig::default();
        let mut catchup = CatchupPipeline::new(config);

        // Start catchup without knowing network head
        catchup.start_catchup(5);
        assert!(matches!(catchup.state(), CatchupState::AwaitingHead { local_head: 5 }));
        assert!(catchup.is_syncing());

        // First action should be RequestHead
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestHead));

        // While waiting for response, should return Wait
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::Wait));

        // Simulate receiving head that's ahead
        catchup.on_head_received(10);
        assert!(matches!(
            catchup.state(),
            CatchupState::Syncing { current_block: 5, target_block: 10 }
        ));

        // Now should request commitments
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestCommitments { start_block: 5, .. }));
    }

    #[tokio::test]
    async fn catchup_already_synced_on_head_received() {
        let config = CatchupConfig::default();
        let mut catchup = CatchupPipeline::new(config);

        // Start catchup from block 10
        catchup.start_catchup(10);

        // Request head
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestHead));

        // Receive head that's at or behind local head
        catchup.on_head_received(10);

        // Should transition directly to Live
        assert!(matches!(catchup.state(), CatchupState::Live));
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::SyncComplete));
    }

    #[tokio::test]
    async fn catchup_backoff_gating() {
        let config = CatchupConfig {
            initial_backoff: std::time::Duration::from_millis(20),
            max_backoff: std::time::Duration::from_millis(200),
            max_retries: 5,
            ..Default::default()
        };
        let mut catchup = CatchupPipeline::new(config);

        catchup.start_catchup(0);

        // Request head
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestHead));

        // Simulate failure - should set backoff (initial_backoff * 2 = 40ms due to exponential)
        catchup.on_request_failed();
        assert!(catchup.is_in_backoff());

        // Should return Wait while in backoff
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::Wait));

        // remaining_backoff should return Some
        assert!(catchup.remaining_backoff().is_some());

        // Wait for backoff to expire (40ms + margin)
        tokio::time::sleep(std::time::Duration::from_millis(60)).await;

        // Should no longer be in backoff
        assert!(!catchup.is_in_backoff());
        assert!(catchup.remaining_backoff().is_none());

        // Should now return RequestHead again (still in AwaitingHead state)
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestHead));
    }

    #[tokio::test]
    async fn catchup_head_request_failure_retries() {
        let config = CatchupConfig {
            initial_backoff: std::time::Duration::from_millis(10),
            max_backoff: std::time::Duration::from_millis(50),
            max_retries: 2,
            ..Default::default()
        };
        let mut catchup = CatchupPipeline::new(config);

        catchup.start_catchup(0);

        // First request
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestHead));

        // Fail (sets backoff to 20ms = initial * 2)
        catchup.on_request_failed();
        assert_eq!(catchup.retry_count(), 1);
        assert!(catchup.is_in_backoff());

        // Wait for backoff to expire (20ms + margin)
        tokio::time::sleep(std::time::Duration::from_millis(30)).await;

        // Should no longer be in backoff
        assert!(!catchup.is_in_backoff());

        // Retry - should return RequestHead
        let action = catchup.next_action();
        assert!(matches!(action, CatchupAction::RequestHead));

        // Fail again - should exceed max retries and go to Idle
        catchup.on_request_failed();
        assert!(matches!(catchup.state(), CatchupState::Idle));
    }
}
