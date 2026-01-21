//! JSON-RPC driver client for E2E tests.
//!
//! This module provides a JSON-RPC client for communicating with
//! a driver RPC server in E2E test scenarios.

use std::{borrow::Cow, path::PathBuf, time::Duration};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, U256};
use alloy_provider::{Provider, RootProvider};
use async_trait::async_trait;
use bindings::inbox::Inbox::InboxInstance;
use preconfirmation_driver::{
    DriverClient, PreconfirmationInput, Result,
    driver_interface::payload::build_taiko_payload_attributes,
    error::{DriverApiError, PreconfirmationClientError},
};
use protocol::shasta::DriverRpcMethod;
use rpc::client::{
    build_ipc_provider, build_jwt_http_provider, connect_http_with_timeout, read_jwt_secret,
};
use tokio::time::sleep;
use tracing::{debug, error, info};
use url::Url;

/// Endpoint type for the driver JSON-RPC connection.
#[derive(Clone, Debug)]
pub enum DriverEndpoint {
    /// HTTP JSON-RPC endpoint (requires JWT authentication).
    Http(Url),
    /// IPC socket path (no JWT; relies on filesystem permissions).
    Ipc(PathBuf),
}

impl From<Url> for DriverEndpoint {
    fn from(url: Url) -> Self {
        Self::Http(url)
    }
}

impl From<PathBuf> for DriverEndpoint {
    fn from(path: PathBuf) -> Self {
        Self::Ipc(path)
    }
}

/// Default poll interval for `wait_event_sync`.
const DEFAULT_EVENT_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(6);

/// Configuration for [`RpcDriverClient`].
#[derive(Clone, Debug)]
pub struct RpcDriverClientConfig {
    /// Driver endpoint (HTTP with JWT or IPC with filesystem permissions).
    pub driver_endpoint: DriverEndpoint,
    /// Path to the JWT secret used by the driver JSON-RPC server.
    pub driver_jwt_secret: Option<PathBuf>,
    /// L1 HTTP JSON-RPC endpoint.
    pub l1_rpc_url: Url,
    /// L2 HTTP JSON-RPC endpoint.
    pub l2_rpc_url: Url,
    /// Inbox contract address on L1.
    pub inbox_address: Address,
    /// Poll interval used when waiting for event sync.
    pub event_sync_poll_interval: Duration,
}

impl RpcDriverClientConfig {
    /// Construct a config with an HTTP endpoint.
    pub fn with_http_endpoint(
        driver_rpc_url: Url,
        driver_jwt_secret: PathBuf,
        l1_rpc_url: Url,
        l2_rpc_url: Url,
        inbox_address: Address,
    ) -> Self {
        Self {
            driver_endpoint: DriverEndpoint::Http(driver_rpc_url),
            driver_jwt_secret: Some(driver_jwt_secret),
            l1_rpc_url,
            l2_rpc_url,
            inbox_address,
            event_sync_poll_interval: DEFAULT_EVENT_SYNC_POLL_INTERVAL,
        }
    }

    /// Construct a config with an IPC endpoint.
    pub fn with_ipc_endpoint(
        driver_ipc_path: PathBuf,
        l1_rpc_url: Url,
        l2_rpc_url: Url,
        inbox_address: Address,
    ) -> Self {
        Self {
            driver_endpoint: DriverEndpoint::Ipc(driver_ipc_path),
            driver_jwt_secret: None,
            l1_rpc_url,
            l2_rpc_url,
            inbox_address,
            event_sync_poll_interval: DEFAULT_EVENT_SYNC_POLL_INTERVAL,
        }
    }
}

/// JSON-RPC driver client for E2E tests.
///
/// This client communicates with a driver RPC server via HTTP or IPC.
/// Used for E2E tests that need out-of-process driver communication.
#[derive(Clone, Debug)]
pub struct RpcDriverClient {
    driver_provider: RootProvider,
    l2_provider: RootProvider,
    inbox: InboxInstance<RootProvider>,
    event_sync_poll_interval: Duration,
}

impl RpcDriverClient {
    /// Create a new RPC driver client.
    pub async fn new(cfg: RpcDriverClientConfig) -> Result<Self> {
        let driver_provider = match cfg.driver_endpoint {
            DriverEndpoint::Http(url) => {
                let jwt_secret_path =
                    cfg.driver_jwt_secret.ok_or(DriverApiError::MissingJwtSecret)?;
                let jwt_secret = read_jwt_secret(jwt_secret_path.clone())
                    .ok_or_else(|| DriverApiError::JwtSecretReadError { path: jwt_secret_path })?;
                build_jwt_http_provider(url, jwt_secret)
            }
            DriverEndpoint::Ipc(path) => build_ipc_provider(path.clone())
                .await
                .map_err(|err| DriverApiError::IpcConnectionFailed { path, source: err })?,
        };

        let l1_provider = connect_http_with_timeout(cfg.l1_rpc_url);
        let l2_provider = connect_http_with_timeout(cfg.l2_rpc_url);
        let inbox = InboxInstance::new(cfg.inbox_address, l1_provider);

        Ok(Self {
            driver_provider,
            l2_provider,
            inbox,
            event_sync_poll_interval: cfg.event_sync_poll_interval,
        })
    }

    async fn last_canonical_proposal_id(&self) -> Result<u64> {
        self.driver_provider
            .raw_request(Cow::Borrowed(DriverRpcMethod::LastCanonicalProposalId.as_str()), ())
            .await
            .map_err(|err| {
                error!(error = %err, "driver RPC lastCanonicalProposalId failed");
                PreconfirmationClientError::from(DriverApiError::from(err))
            })
    }
}

#[async_trait]
impl DriverClient for RpcDriverClient {
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        let preconf = &input.commitment.commitment.preconf;
        let block_number =
            preconfirmation_types::uint256_to_u256(&preconf.block_number).to::<u64>();
        let proposal_id = preconfirmation_types::uint256_to_u256(&preconf.proposal_id).to::<u64>();

        if input.should_skip_driver_submission() {
            debug!(block_number, proposal_id, "skipping EOP-only preconfirmation without txlist");
            return Ok(());
        }

        let config = self.inbox.getConfig().call().await.map_err(DriverApiError::from)?;
        let basefee_sharing_pctg = config.basefeeSharingPctg;

        let payload =
            build_taiko_payload_attributes(&input, basefee_sharing_pctg, &self.l2_provider).await?;

        debug!(block_number, proposal_id, "submitting preconfirmation payload to driver");

        let result: std::result::Result<bool, _> = self
            .driver_provider
            .raw_request(
                Cow::Borrowed(DriverRpcMethod::SubmitPreconfirmationPayload.as_str()),
                (payload,),
            )
            .await;

        match result {
            Ok(_) => {
                debug!(block_number, proposal_id, "successfully submitted preconfirmation payload");
                Ok(())
            }
            Err(err) => {
                error!(block_number, proposal_id, error = %err, "driver RPC submit failed");
                Err(DriverApiError::from(err).into())
            }
        }
    }

    async fn wait_event_sync(&self) -> Result<()> {
        info!("starting wait for driver to sync with L1 inbox events");

        loop {
            let last = self.last_canonical_proposal_id().await?;
            let core_state =
                self.inbox.getCoreState().call().await.map_err(DriverApiError::from)?;
            let next = core_state.nextProposalId.to::<u64>();

            debug!(last_canonical_proposal_id = last, next_proposal_id = next, "checking sync");

            if next == 0 {
                info!("sync complete (no proposals)");
                return Ok(());
            }

            let target = next.saturating_sub(1);
            if last >= target {
                info!("driver event sync complete");
                return Ok(());
            }

            debug!(poll_interval_secs = self.event_sync_poll_interval.as_secs(), "waiting");
            sleep(self.event_sync_poll_interval).await;
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
