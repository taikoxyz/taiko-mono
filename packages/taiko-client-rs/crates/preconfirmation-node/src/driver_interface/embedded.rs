//! Embedded driver client implementation.
//!
//! This module provides [`EmbeddedDriverClient`], which submits preconfirmation
//! payloads directly to an in-process driver event syncer instead of using
//! JSON-RPC.

use std::{sync::Arc, time::Duration};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use async_trait::async_trait;
use bindings::inbox::IInbox::Config;
use driver::{EventSyncer, production::PreconfPayload};
use metrics::{counter, histogram};
use rpc::client::Client;
use tokio::time::{Instant, sleep};
use tracing::{debug, error, info, warn};

use super::{
    payload::build_taiko_payload_attributes,
    traits::{DriverClient, PreconfirmationInput},
};
use crate::{
    error::{DriverApiError, Result},
    metrics::PreconfirmationClientMetrics,
};

/// Type alias for the embedded driver provider.
pub type EmbeddedDriverProvider = FillProvider<JoinedRecommendedFillers, RootProvider>;

/// Type alias for the embedded driver RPC client.
pub type EmbeddedDriverRpcClient = Client<EmbeddedDriverProvider>;

/// Default poll interval for `wait_event_sync`.
pub const DEFAULT_EVENT_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(6);

/// Default retry delay for fetching the inbox configuration.
pub const DEFAULT_CONFIG_RETRY_DELAY: Duration = Duration::from_millis(250);

/// Maximum number of attempts to fetch the inbox configuration.
pub const DEFAULT_CONFIG_RETRY_ATTEMPTS: usize = 5;

/// Embedded driver client for direct in-process communication.
///
/// This client builds payload attributes locally and submits them to the driver
/// event syncer without any JSON-RPC serialization.
pub struct EmbeddedDriverClient {
    /// Event syncer used to inject preconfirmation payloads.
    event_syncer: Arc<EventSyncer<EmbeddedDriverProvider>>,
    /// RPC client for L1/L2 queries and contract calls.
    rpc: EmbeddedDriverRpcClient,
    /// Poll interval used when waiting for event sync.
    event_sync_poll_interval: Duration,
}

impl EmbeddedDriverClient {
    /// Create a new embedded driver client with the default poll interval.
    pub fn new(
        event_syncer: Arc<EventSyncer<EmbeddedDriverProvider>>,
        rpc: EmbeddedDriverRpcClient,
    ) -> Self {
        Self::with_poll_interval(event_syncer, rpc, DEFAULT_EVENT_SYNC_POLL_INTERVAL)
    }

    /// Create a new embedded driver client with a custom poll interval.
    pub fn with_poll_interval(
        event_syncer: Arc<EventSyncer<EmbeddedDriverProvider>>,
        rpc: EmbeddedDriverRpcClient,
        event_sync_poll_interval: Duration,
    ) -> Self {
        Self { event_syncer, rpc, event_sync_poll_interval }
    }

    /// Fetch the last canonical proposal id reported by the driver.
    async fn last_canonical_proposal_id(&self) -> Result<u64> {
        let start = Instant::now();
        let last = self.event_syncer.last_canonical_proposal_id();

        histogram!(PreconfirmationClientMetrics::DRIVER_RPC_LAST_CANONICAL_DURATION_SECONDS)
            .record(start.elapsed().as_secs_f64());

        Ok(last)
    }

    /// Submit a payload to the embedded driver event syncer.
    async fn submit_payload(&self, payload: PreconfPayload) -> Result<()> {
        self.event_syncer.submit_preconfirmation_payload(payload).await?;
        Ok(())
    }

    /// Fetch the inbox configuration, retrying on transient failures.
    async fn fetch_inbox_config(&self) -> Result<Config> {
        let mut last_err = None;

        for attempt in 1..=DEFAULT_CONFIG_RETRY_ATTEMPTS {
            match self.rpc.shasta.inbox.getConfig().call().await {
                Ok(config) => return Ok(config),
                Err(err) => {
                    if attempt < DEFAULT_CONFIG_RETRY_ATTEMPTS {
                        warn!(attempt, error = %err, "failed to fetch inbox config; retrying");
                        sleep(DEFAULT_CONFIG_RETRY_DELAY).await;
                    }
                    last_err = Some(err);
                }
            }
        }

        let err = last_err.expect("inbox config retries exhausted");
        Err(DriverApiError::from(err).into())
    }
}

#[async_trait]
impl DriverClient for EmbeddedDriverClient {
    /// Submit a preconfirmation input for ordered processing.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        let preconf = &input.commitment.commitment.preconf;
        let block_number =
            preconfirmation_types::uint256_to_u256(&preconf.block_number).to::<u64>();
        let proposal_id = preconfirmation_types::uint256_to_u256(&preconf.proposal_id).to::<u64>();

        // Skip EOP-only preconfirmations without a txlist.
        if input.should_skip_driver_submission() {
            debug!(block_number, proposal_id, "skipping EOP-only preconfirmation without txlist");
            return Ok(());
        }

        let config = self.fetch_inbox_config().await?;
        let basefee_sharing_pctg = config.basefeeSharingPctg;

        // Build the payload with timing and error metrics.
        let payload_build_start = Instant::now();
        let payload_result =
            build_taiko_payload_attributes(&input, basefee_sharing_pctg, &self.rpc.l2_provider)
                .await;
        histogram!(PreconfirmationClientMetrics::PAYLOAD_BUILD_DURATION_SECONDS)
            .record(payload_build_start.elapsed().as_secs_f64());

        let payload = match payload_result {
            Ok(payload) => payload,
            Err(err) => {
                counter!(PreconfirmationClientMetrics::PAYLOAD_BUILD_FAILURES_TOTAL).increment(1);
                return Err(err);
            }
        };

        let submit_start = Instant::now();
        let result = self.submit_payload(PreconfPayload::new(payload)).await;
        histogram!(PreconfirmationClientMetrics::DRIVER_RPC_SUBMIT_DURATION_SECONDS)
            .record(submit_start.elapsed().as_secs_f64());

        match result {
            Ok(()) => {
                debug!(block_number, proposal_id, "submitted preconfirmation payload to driver");
                Ok(())
            }
            Err(err) => {
                counter!(PreconfirmationClientMetrics::DRIVER_RPC_SUBMIT_ERRORS_TOTAL).increment(1);
                error!(
                    block_number,
                    proposal_id,
                    error = %err,
                    "embedded driver submission failed"
                );
                Err(err)
            }
        }
    }

    /// Wait until the driver reports it has caught up with the L1 inbox.
    async fn wait_event_sync(&self) -> Result<()> {
        info!("starting wait for embedded driver to sync with L1 inbox events");
        let start = Instant::now();

        loop {
            let last = self.last_canonical_proposal_id().await?;
            let core_state =
                self.rpc.shasta.inbox.getCoreState().call().await.map_err(DriverApiError::from)?;
            let next = core_state.nextProposalId.to::<u64>();

            debug!(
                last_canonical_proposal_id = last,
                next_proposal_id = next,
                "checking embedded driver event sync progress"
            );

            if next == 0 {
                let elapsed = start.elapsed();
                histogram!(PreconfirmationClientMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS)
                    .record(elapsed.as_secs_f64());
                info!(
                    duration_secs = elapsed.as_secs_f64(),
                    "driver event sync complete (no proposals in inbox)"
                );
                return Ok(());
            }

            let target = next.saturating_sub(1);
            if last >= target {
                let elapsed = start.elapsed();
                histogram!(PreconfirmationClientMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS)
                    .record(elapsed.as_secs_f64());
                info!(
                    last_canonical_proposal_id = last,
                    target_proposal_id = target,
                    duration_secs = elapsed.as_secs_f64(),
                    "driver event sync complete"
                );
                return Ok(());
            }

            debug!(
                last_canonical_proposal_id = last,
                target_proposal_id = target,
                poll_interval_secs = self.event_sync_poll_interval.as_secs(),
                "driver not yet synced, waiting"
            );
            sleep(self.event_sync_poll_interval).await;
        }
    }

    /// Fetch the latest safe tip from the L2 execution engine.
    async fn event_sync_tip(&self) -> Result<U256> {
        let block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Safe)
            .await
            .map_err(DriverApiError::from)?
            .ok_or(DriverApiError::MissingSafeBlock)?;
        Ok(U256::from(block.number()))
    }

    /// Fetch the latest (unsafe) tip from the L2 execution engine.
    async fn preconf_tip(&self) -> Result<U256> {
        let block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(DriverApiError::from)?
            .ok_or(DriverApiError::MissingLatestBlock)?;
        Ok(U256::from(block.number()))
    }
}

#[cfg(test)]
mod tests {
    use super::EmbeddedDriverClient;
    use crate::driver_interface::DriverClient;

    /// Ensure `EmbeddedDriverClient` implements the `DriverClient` trait.
    #[test]
    fn embedded_driver_client_is_driver_client() {
        fn assert_trait<T: DriverClient>() {}
        assert_trait::<EmbeddedDriverClient>();
    }
}
