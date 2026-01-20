//! Driver clients for preconfirmation integration tests.
//!
//! This module provides:
//! - [`MockDriverClient`]: Records submissions for unit-style tests.
//! - [`SafeTipDriverClient`]: Wraps an embedded driver client with safe-tip fallback.
//! - [`RealDriverSetup`]: Full driver setup for E2E tests with actual block production.

use std::{sync::Arc, time::Duration};

use alloy_primitives::U256;
use alloy_provider::RootProvider;
use anyhow::Result as AnyhowResult;
use async_trait::async_trait;
use driver::{DriverConfig, EventSyncer, sync::SyncStage};
use preconfirmation_node::{
    DriverClient, PreconfirmationInput, Result,
    driver_interface::EmbeddedDriverClient,
    error::{DriverApiError, PreconfirmationClientError},
};
use preconfirmation_types::uint256_to_u256;
use rpc::client::{Client, ClientConfig, connect_http_with_timeout};
use tokio::{
    sync::{Mutex, Notify},
    task::JoinHandle,
};
use tracing::{info, warn};

use crate::{BeaconStubServer, ShastaEnv, fetch_block_by_number};

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
    /// Create a new mock driver client using default settings.
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl DriverClient for MockDriverClient {
    /// Record the submitted input for assertions.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        tracing::debug!(
            block_number = ?input.commitment.commitment.preconf.block_number,
            "mock driver received preconfirmation input"
        );
        self.submissions.lock().await.push(input);
        self.submission_notify.notify_waiters();
        Ok(())
    }

    /// Wait until the mock is marked as synced.
    async fn wait_event_sync(&self) -> Result<()> {
        loop {
            let notified = self.event_sync_notify.notified();
            if *self.event_sync_complete.lock().await {
                return Ok(());
            }
            notified.await;
        }
    }

    /// Return the configured event sync tip.
    async fn event_sync_tip(&self) -> Result<U256> {
        Ok(*self.event_sync_tip.lock().await)
    }

    /// Return the configured preconf tip.
    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip.lock().await)
    }
}

/// Wraps an embedded driver client with safe-tip fallback for event sync.
///
/// When `event_sync_tip` returns `MissingSafeBlock`, falls back to `preconf_tip`.
/// Also logs submission results for debugging.
#[derive(Clone)]
pub struct SafeTipDriverClient {
    /// Embedded driver client implementation.
    inner: Arc<EmbeddedDriverClient>,
}

impl SafeTipDriverClient {
    /// Create a new safe-tip driver client wrapper.
    pub fn new(inner: Arc<EmbeddedDriverClient>) -> Self {
        Self { inner }
    }
}

#[async_trait]
impl DriverClient for SafeTipDriverClient {
    /// Forward submission to the embedded driver client.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        let block_number =
            uint256_to_u256(&input.commitment.commitment.preconf.block_number).to::<u64>();

        let result = self.inner.submit_preconfirmation(input).await;
        match &result {
            Ok(()) => info!(block_number, "driver preconfirmation submission accepted"),
            Err(err) => {
                warn!(block_number, error = %err, "driver preconfirmation submission failed")
            }
        }
        result
    }

    /// Forward the sync wait to the embedded driver client.
    async fn wait_event_sync(&self) -> Result<()> {
        self.inner.wait_event_sync().await
    }

    /// Fetch safe tip with fallback to latest if unavailable.
    async fn event_sync_tip(&self) -> Result<U256> {
        match self.inner.event_sync_tip().await {
            Err(PreconfirmationClientError::DriverInterface(DriverApiError::MissingSafeBlock)) => {
                self.inner.preconf_tip().await
            }
            other => other,
        }
    }

    /// Return the latest tip from the embedded driver client.
    async fn preconf_tip(&self) -> Result<U256> {
        self.inner.preconf_tip().await
    }
}

// ============================================================================
// Real Driver Setup
// ============================================================================

/// Real driver setup for E2E tests with actual block production.
///
/// This bundles together all components needed to run a real driver:
/// - Beacon stub server (mock beacon for timestamp)
/// - Event syncer with preconfirmation enabled
/// - Embedded driver client for preconfirmation submission
/// - L2 provider for block queries
///
/// # Example
///
/// ```ignore
/// let setup = RealDriverSetup::start(env).await?;
///
/// // Use setup.driver_client for preconfirmation submission
/// let preconf_tip = setup.driver_client.preconf_tip().await?;
///
/// // After submission, query actual blocks
/// let block = wait_for_block(&setup.l2_provider, block_num, timeout).await?;
///
/// setup.stop().await;
/// ```
pub struct RealDriverSetup {
    /// Driver client for preconfirmation submission.
    pub driver_client: SafeTipDriverClient,
    /// L2 provider for block queries.
    pub l2_provider: RootProvider,
    /// Beacon stub server.
    beacon_server: BeaconStubServer,
    /// Event syncer background task.
    event_handle: JoinHandle<()>,
}

impl RealDriverSetup {
    /// Starts a real driver connected to L2.
    ///
    /// This sets up:
    /// 1. Beacon stub server
    /// 2. Event syncer with preconfirmation enabled
    /// 3. Embedded driver client with safe-tip fallback
    pub async fn start(env: &ShastaEnv) -> AnyhowResult<Self> {
        let beacon_server = BeaconStubServer::start().await?;

        // Configure the driver for preconfirmation.
        let mut driver_config = DriverConfig::new(
            ClientConfig {
                l1_provider_source: env.l1_source.clone(),
                l2_provider_url: env.l2_http_0.clone(),
                l2_auth_provider_url: env.l2_auth_0.clone(),
                jwt_secret: env.jwt_secret.clone(),
                inbox_address: env.inbox_address,
            },
            Duration::from_millis(50),
            beacon_server.endpoint().clone(),
            None,
            None,
        );
        driver_config.preconfirmation_enabled = true;

        let driver_client_rpc = Client::new(driver_config.client.clone()).await?;
        let event_syncer =
            Arc::new(EventSyncer::new(&driver_config, driver_client_rpc.clone()).await?);
        let event_handle = tokio::spawn({
            let syncer = event_syncer.clone();
            async move {
                if let Err(err) = syncer.run().await {
                    warn!(?err, "event syncer exited");
                }
            }
        });

        event_syncer
            .wait_preconf_ingress_ready()
            .await
            .ok_or_else(|| anyhow::anyhow!("preconfirmation ingress disabled"))?;

        let embedded_driver = Arc::new(EmbeddedDriverClient::new(event_syncer, driver_client_rpc));
        let driver_client = SafeTipDriverClient::new(embedded_driver);

        let l2_provider = connect_http_with_timeout(env.l2_http_0.clone());

        Ok(Self { driver_client, l2_provider, beacon_server, event_handle })
    }

    /// Stops all background tasks and servers.
    pub async fn stop(self) -> AnyhowResult<()> {
        self.event_handle.abort();
        self.beacon_server.shutdown().await?;
        Ok(())
    }

    /// Computes the starting block number and base timestamp for preconfirmation.
    ///
    /// This is the common setup pattern used by E2E tests:
    /// 1. Gets the event sync and preconf tips from the driver
    /// 2. Computes the next block number (max tip + 1)
    /// 3. Fetches the parent block to derive the valid base timestamp
    ///
    /// # Returns
    ///
    /// A tuple of (starting_block_number, base_timestamp) where:
    /// - `starting_block_number` is the first block that should be preconfirmed
    /// - `base_timestamp` is parent.timestamp + 1, suitable for commitment timestamps
    pub async fn compute_starting_block_info(&self) -> AnyhowResult<(u64, u64)> {
        let info = self.compute_starting_block_info_full().await?;
        Ok((info.block_number, info.base_timestamp))
    }

    /// Computes full starting block info including parent gas limit.
    ///
    /// Use this when you need the parent's gas limit for the preconfirmation.
    /// For simpler tests that use a constant gas limit, use [`compute_starting_block_info`].
    pub async fn compute_starting_block_info_full(&self) -> AnyhowResult<StartingBlockInfo> {
        let event_sync_tip = self.driver_client.event_sync_tip().await?;
        let preconf_tip = self.driver_client.preconf_tip().await?;
        let starting_block = event_sync_tip.max(preconf_tip) + U256::ONE;
        let block_number = starting_block.to::<u64>();

        let parent_block =
            fetch_block_by_number(&self.l2_provider, block_number.saturating_sub(1)).await?;
        let parent_header = &parent_block.header.inner;

        let base_timestamp = parent_header.timestamp.saturating_add(1);
        let gas_limit = parent_header.gas_limit;

        Ok(StartingBlockInfo { block_number, base_timestamp, gas_limit })
    }
}

/// Starting block metadata used by preconfirmation tests.
#[derive(Clone, Debug)]
pub struct StartingBlockInfo {
    /// Next block number to preconfirm.
    pub block_number: u64,
    /// Base timestamp (parent timestamp + 1).
    pub base_timestamp: u64,
    /// Parent gas limit for block construction.
    pub gas_limit: u64,
}
