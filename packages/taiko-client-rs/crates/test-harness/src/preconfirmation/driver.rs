//! Mock driver client for preconfirmation integration tests.

use std::sync::Arc;

use alloy_primitives::U256;
use async_trait::async_trait;
use tokio::sync::{Mutex, Notify};

use preconfirmation_client::{DriverClient, PreconfirmationInput, Result};

/// A mock driver client that records submissions for test verification.
///
/// This client:
/// - Records all `PreconfirmationInput` submissions.
/// - Allows configuring event sync behavior.
/// - Provides accessors to verify submissions were made correctly.
///
/// # Example
///
/// ```ignore
/// let driver = MockDriverClient::new();
/// let submissions = driver.submissions().await;
/// assert!(submissions.is_empty());
/// ```
pub struct MockDriverClient {
    /// Recorded submissions for verification.
    submissions: Mutex<Vec<PreconfirmationInput>>,
    /// Event sync tip to return.
    event_sync_tip: Mutex<U256>,
    /// Preconf tip to return.
    preconf_tip: Mutex<U256>,
    /// Notify for new submissions.
    submission_notify: Notify,
    /// Notify for event sync completion.
    event_sync_notify: Notify,
    /// Whether event sync is complete.
    event_sync_complete: Mutex<bool>,
}

impl MockDriverClient {
    /// Create a new mock driver client.
    pub fn new() -> Self {
        Self {
            submissions: Mutex::new(Vec::new()),
            event_sync_tip: Mutex::new(U256::ZERO),
            preconf_tip: Mutex::new(U256::ZERO),
            submission_notify: Notify::new(),
            event_sync_notify: Notify::new(),
            event_sync_complete: Mutex::new(false),
        }
    }

    /// Create a new mock driver client that is already synced.
    pub fn new_synced() -> Self {
        Self { event_sync_complete: Mutex::new(true), ..Self::new() }
    }

    /// Create a new shared mock driver client.
    pub fn new_shared() -> Arc<Self> {
        Arc::new(Self::new())
    }

    /// Create a new shared mock driver client that is already synced.
    pub fn new_synced_shared() -> Arc<Self> {
        Arc::new(Self::new_synced())
    }

    /// Signal that event sync is complete.
    pub async fn complete_event_sync(&self) {
        *self.event_sync_complete.lock().await = true;
        self.event_sync_notify.notify_waiters();
    }

    /// Set the event sync tip.
    pub async fn set_event_sync_tip(&self, tip: U256) {
        *self.event_sync_tip.lock().await = tip;
    }

    /// Set the preconf tip.
    pub async fn set_preconf_tip(&self, tip: U256) {
        *self.preconf_tip.lock().await = tip;
    }

    /// Get all recorded submissions.
    pub async fn submissions(&self) -> Vec<PreconfirmationInput> {
        self.submissions.lock().await.clone()
    }

    /// Get the number of submissions.
    pub async fn submission_count(&self) -> usize {
        self.submissions.lock().await.len()
    }

    /// Clear recorded submissions.
    pub async fn clear_submissions(&self) {
        self.submissions.lock().await.clear();
    }

    /// Wait for a specific number of submissions.
    pub async fn wait_for_submissions(&self, count: usize) -> Vec<PreconfirmationInput> {
        loop {
            let notified = self.submission_notify.notified();
            let submissions = self.submissions.lock().await;
            if submissions.len() >= count {
                return submissions.clone();
            }
            drop(submissions);
            notified.await;
        }
    }
}

impl Default for MockDriverClient {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl DriverClient for MockDriverClient {
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        tracing::debug!(
            block_number = ?input.commitment.commitment.preconf.block_number,
            "mock driver received preconfirmation input"
        );
        self.submissions.lock().await.push(input);
        self.submission_notify.notify_waiters();
        Ok(())
    }

    async fn wait_event_sync(&self) -> Result<()> {
        loop {
            let notified = self.event_sync_notify.notified();
            if *self.event_sync_complete.lock().await {
                return Ok(());
            }
            notified.await;
        }
    }

    async fn event_sync_tip(&self) -> Result<U256> {
        Ok(*self.event_sync_tip.lock().await)
    }

    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip.lock().await)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn mock_driver_records_submissions() {
        let driver = MockDriverClient::new_synced();

        // Create a minimal input (we'd need preconfirmation-types for real inputs)
        // For now just verify the driver can be created
        assert_eq!(driver.submission_count().await, 0);
    }

    #[tokio::test]
    async fn mock_driver_event_sync_flow() {
        let driver = MockDriverClient::new();
        driver.complete_event_sync().await;
        driver.wait_event_sync().await.unwrap();
    }
}
