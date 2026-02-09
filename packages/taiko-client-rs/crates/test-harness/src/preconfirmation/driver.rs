//! Driver clients for preconfirmation integration tests.
//!
//! This module provides:
//! - [`MockDriverClient`]: Records submissions for unit-style tests.
//! - [`EventSyncerDriverClient`]: Submits directly to an in-process event syncer.
//! - [`SafeTipDriverClient`]: Wraps a driver client with safe-tip fallback.
//! - [`RealDriverSetup`]: Full driver setup for E2E tests with actual block production.

use std::{sync::Arc, time::Duration};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::{Provider, RootProvider};
use anyhow::Result as AnyhowResult;
use async_trait::async_trait;
use bindings::inbox::Inbox::InboxInstance;
use driver::{
    DriverConfig, PreconfPayload,
    sync::{SyncStage, event::EventSyncer},
};
use preconfirmation_driver::{
    DriverClient, PreconfirmationInput, Result,
    driver_interface::payload::build_taiko_payload_attributes,
    error::{DriverApiError, PreconfirmationClientError},
};
use preconfirmation_types::uint256_to_u256;
use rpc::client::{Client, ClientConfig};
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

/// Driver client that submits payloads directly to an in-process EventSyncer.
#[derive(Clone)]
pub struct EventSyncerDriverClient<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    event_syncer: Arc<EventSyncer<P>>,
    inbox: InboxInstance<P>,
    l2_provider: RootProvider,
}

impl<P> EventSyncerDriverClient<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new client backed by the driver event syncer.
    pub fn new(event_syncer: Arc<EventSyncer<P>>, client: Client<P>) -> Self {
        Self { event_syncer, inbox: client.shasta.inbox, l2_provider: client.l2_provider }
    }
}

#[async_trait]
impl<P> DriverClient for EventSyncerDriverClient<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        let preconf = &input.commitment.commitment.preconf;
        let block_number = uint256_to_u256(&preconf.block_number).to::<u64>();
        let proposal_id = uint256_to_u256(&preconf.proposal_id).to::<u64>();

        if input.should_skip_driver_submission() {
            tracing::debug!(block_number, proposal_id, "skipping EOP-only preconfirmation");
            return Ok(());
        }

        let config = self.inbox.getConfig().call().await.map_err(DriverApiError::from)?;
        let payload =
            build_taiko_payload_attributes(&input, config.basefeeSharingPctg, &self.l2_provider)
                .await?;

        self.event_syncer
            .submit_preconfirmation_payload(PreconfPayload::new(payload))
            .await
            .map_err(|err| {
                PreconfirmationClientError::DriverInterface(DriverApiError::ChannelClosed(
                    err.to_string(),
                ))
            })?;

        info!(block_number, proposal_id, "submitted preconfirmation payload");
        Ok(())
    }

    async fn wait_event_sync(&self) -> Result<()> {
        info!("starting wait for driver to sync with L1 inbox events");

        let mut rx = self.event_syncer.subscribe_proposal_id();
        loop {
            let last = *rx.borrow();
            let core_state =
                self.inbox.getCoreState().call().await.map_err(DriverApiError::from)?;
            let next = core_state.nextProposalId.to::<u64>();

            tracing::debug!(
                last_canonical_proposal_id = last,
                next_proposal_id = next,
                "checking sync"
            );

            if next == 0 {
                info!("sync complete (no proposals)");
                return Ok(());
            }

            let target = next.saturating_sub(1);
            if last >= target {
                info!("driver event sync complete");
                return Ok(());
            }

            if rx.changed().await.is_err() {
                return Ok(());
            }
        }
    }

    async fn event_sync_tip(&self) -> Result<U256> {
        let block = self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Safe)
            .await
            .map_err(DriverApiError::from)?
            .ok_or(DriverApiError::MissingSafeBlock)?;
        Ok(U256::from(block.number()))
    }

    async fn preconf_tip(&self) -> Result<U256> {
        let block = self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(DriverApiError::from)?
            .ok_or(DriverApiError::MissingLatestBlock)?;
        Ok(U256::from(block.number()))
    }
}

/// Wraps a driver client with safe-tip fallback for event sync.
///
/// When `event_sync_tip` returns `MissingSafeBlock`, falls back to `preconf_tip`.
/// Also logs submission results for debugging.
#[derive(Clone)]
pub struct SafeTipDriverClient {
    inner: Arc<dyn DriverClient>,
}

impl SafeTipDriverClient {
    /// Create a new safe-tip driver client wrapper.
    pub fn new(inner: Arc<dyn DriverClient>) -> Self {
        Self { inner }
    }
}

#[async_trait]
impl DriverClient for SafeTipDriverClient {
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

    async fn wait_event_sync(&self) -> Result<()> {
        self.inner.wait_event_sync().await
    }

    async fn event_sync_tip(&self) -> Result<U256> {
        match self.inner.event_sync_tip().await {
            Err(PreconfirmationClientError::DriverInterface(DriverApiError::MissingSafeBlock)) => {
                self.inner.preconf_tip().await
            }
            other => other,
        }
    }

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
/// - Driver client for preconfirmation submission
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

        let mut driver_config = DriverConfig::new(
            ClientConfig {
                l1_provider_source: env.l1_source.clone(),
                l2_provider_url: env.l2_ws_0.clone(),
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

        let rpc_client = Client::new(driver_config.client.clone()).await?;
        let event_syncer = Arc::new(EventSyncer::new(&driver_config, rpc_client.clone()).await?);
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

        let l2_provider = rpc_client.l2_provider.clone();
        let embedded_client =
            EventSyncerDriverClient::new(event_syncer.clone(), rpc_client.clone());
        let driver_client = SafeTipDriverClient::new(Arc::new(embedded_client));

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
        let base_timestamp = parent_block.header.inner.timestamp.saturating_add(1);
        let parent_gas_limit = parent_block.header.inner.gas_limit;

        Ok(StartingBlockInfo { block_number, base_timestamp, parent_gas_limit })
    }
}

/// Information about the starting block for preconfirmation tests.
#[derive(Debug, Clone, Copy)]
pub struct StartingBlockInfo {
    /// The first block number that should be preconfirmed.
    pub block_number: u64,
    /// Base timestamp for commitments (parent.timestamp + 1).
    pub base_timestamp: u64,
    /// Parent block's gas limit (useful for tests that inherit it).
    pub parent_gas_limit: u64,
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
