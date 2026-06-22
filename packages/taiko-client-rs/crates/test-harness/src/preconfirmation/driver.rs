//! Driver clients for preconfirmation integration tests.
//!
//! This module provides:
//! - [`LoggingDriverClient`]: Wraps a driver client with submission logging.
//! - [`RealDriverSetup`]: Full driver setup for E2E tests with actual block production.

use std::{sync::Arc, time::Duration};

use alloy_primitives::U256;
use alloy_provider::RootProvider;
use anyhow::Result as AnyhowResult;
use async_trait::async_trait;
use driver::{
    DriverConfig,
    sync::{SyncStage, event::EventSyncer},
};
use preconfirmation_driver::{DriverClient, EventSyncerDriverClient, PreconfirmationInput, Result};
use preconfirmation_types::uint256_to_u256;
use rpc::client::{Client, ClientConfig};
use tokio::task::JoinHandle;
use tracing::{info, warn};
use url::Url;

use crate::{BeaconStubServer, ShastaEnv, fetch_block_by_number};

/// Fast event-sync poll interval used by the harness to keep E2E waits responsive.
const HARNESS_WAIT_EVENT_SYNC_POLL_INTERVAL: Duration = Duration::from_millis(200);

/// Wraps a driver client with logging for submission results.
#[derive(Clone)]
pub struct LoggingDriverClient {
    inner: Arc<dyn DriverClient>,
}

impl LoggingDriverClient {
    /// Create a new logging driver client wrapper.
    pub fn new(inner: Arc<dyn DriverClient>) -> Self {
        Self { inner }
    }
}

#[async_trait]
impl DriverClient for LoggingDriverClient {
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

    // Delegation only — fallback logic lives in the inner implementation via
    // `resolve_event_sync_tip`, so no logging or mutation is needed here.
    async fn event_sync_tip(&self) -> Result<U256> {
        self.inner.event_sync_tip().await
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
    pub driver_client: LoggingDriverClient,
    /// L2 provider for block queries.
    pub l2_provider: RootProvider,
    /// Beacon stub server.
    beacon_server: BeaconStubServer,
    /// Event syncer background task.
    event_handle: JoinHandle<()>,
}

impl RealDriverSetup {
    /// Starts a real driver connected to the environment's primary L2 node
    /// (`env.l2_ws_0` / `env.l2_auth_0`).
    ///
    /// This sets up:
    /// 1. Beacon stub server
    /// 2. Event syncer with preconfirmation enabled
    /// 3. Embedded driver client with logging wrapper
    pub async fn start(env: &ShastaEnv) -> AnyhowResult<Self> {
        Self::start_for_endpoints(env, &env.l2_ws_0, &env.l2_auth_0).await
    }

    /// Starts a real driver connected to the given L2 WebSocket and auth endpoints.
    ///
    /// Use this when a test needs drivers on distinct L2 nodes (for example,
    /// dual-driver gossip tests); [`start`] delegates here with the environment's
    /// primary endpoints.
    ///
    /// # Arguments
    ///
    /// * `env` - Test environment supplying L1 source, JWT secret, and inbox address.
    /// * `l2_ws` - L2 WebSocket provider URL the driver should connect to.
    /// * `l2_auth` - L2 engine-API (auth) provider URL the driver should drive.
    pub async fn start_for_endpoints(
        env: &ShastaEnv,
        l2_ws: &Url,
        l2_auth: &Url,
    ) -> AnyhowResult<Self> {
        let beacon_server = BeaconStubServer::start().await?;

        let mut driver_config = DriverConfig::new(
            ClientConfig {
                l1_provider_source: env.l1_source.clone(),
                l2_provider_url: l2_ws.clone(),
                l2_auth_provider_url: l2_auth.clone(),
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

        event_syncer.wait_preconf_ingress_ready().await?;

        let l2_provider = rpc_client.l2_provider.clone();
        let embedded_client = EventSyncerDriverClient::from_client_with_poll_interval(
            event_syncer.clone(),
            rpc_client.clone(),
            HARNESS_WAIT_EVENT_SYNC_POLL_INTERVAL,
        );
        let driver_client = LoggingDriverClient::new(Arc::new(embedded_client));

        Ok(Self { driver_client, l2_provider, beacon_server, event_handle })
    }

    /// Stops all background tasks and servers.
    pub async fn stop(self) -> AnyhowResult<()> {
        self.event_handle.abort();
        self.beacon_server.shutdown().await?;
        Ok(())
    }

    /// Computes the starting block info for preconfirmation.
    ///
    /// This is the common setup pattern used by E2E tests:
    /// 1. Gets the event sync and preconf tips from the driver
    /// 2. Computes the next block number (max tip + 1)
    /// 3. Fetches the parent block to derive the valid base timestamp and gas limit
    pub async fn compute_starting_block_info(&self) -> AnyhowResult<StartingBlockInfo> {
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
