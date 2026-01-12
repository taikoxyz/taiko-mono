//! JSON-RPC implementation of the [`DriverClient`] interface.

use std::{borrow::Cow, path::PathBuf, time::Duration};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, U256};
use alloy_provider::{Provider, RootProvider};
use async_trait::async_trait;
use bindings::inbox::Inbox::InboxInstance;
use protocol::shasta::DriverRpcMethod;
use rpc::client::{
    build_ipc_provider, build_jwt_http_provider, connect_http_with_timeout, read_jwt_secret,
};
use tokio::time::{Instant, sleep};
use tracing::{debug, error, info};
use url::Url;

use crate::metrics::PreconfirmationClientMetrics;

use super::{
    payload::build_taiko_payload_attributes,
    traits::{DriverClient, PreconfirmationInput},
};
use crate::{Result, error::PreconfirmationClientError};

/// Endpoint type for the driver JSON-RPC connection.
///
/// Supports HTTP (with JWT authentication) or IPC (using filesystem permissions).
#[derive(Clone, Debug)]
pub enum DriverEndpoint {
    /// HTTP JSON-RPC endpoint (requires JWT authentication).
    Http(Url),
    /// IPC socket path (no JWT; relies on filesystem permissions).
    Ipc(PathBuf),
}

impl DriverEndpoint {
    /// Returns `true` if this is an HTTP endpoint.
    pub fn is_http(&self) -> bool {
        matches!(self, Self::Http(_))
    }

    /// Returns `true` if this is an IPC endpoint.
    pub fn is_ipc(&self) -> bool {
        matches!(self, Self::Ipc(_))
    }
}

impl From<Url> for DriverEndpoint {
    /// Construct a `DriverEndpoint` from an HTTP URL.
    fn from(url: Url) -> Self {
        Self::Http(url)
    }
}

impl From<PathBuf> for DriverEndpoint {
    /// Construct a `DriverEndpoint` from an IPC path.
    fn from(path: PathBuf) -> Self {
        Self::Ipc(path)
    }
}

/// Default poll interval for `wait_event_sync`.
const DEFAULT_EVENT_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(6);

/// Configuration for [`JsonRpcDriverClient`].
#[derive(Clone, Debug)]
pub struct JsonRpcDriverClientConfig {
    /// Driver endpoint (HTTP with JWT or IPC with filesystem permissions).
    pub driver_endpoint: DriverEndpoint,
    /// Path to the JWT secret used by the driver JSON-RPC server.
    /// Required for HTTP endpoints; ignored for IPC.
    pub driver_jwt_secret: Option<PathBuf>,
    /// L1 HTTP JSON-RPC endpoint (used for inbox state queries).
    pub l1_rpc_url: Url,
    /// L2 HTTP JSON-RPC endpoint (used for safe/latest tips).
    pub l2_rpc_url: Url,
    /// Inbox contract address on L1.
    pub inbox_address: Address,
    /// Poll interval used when waiting for event sync.
    pub event_sync_poll_interval: Duration,
}

impl JsonRpcDriverClientConfig {
    /// Construct a config with an HTTP endpoint and default poll interval.
    ///
    /// This is the original constructor for backwards compatibility.
    pub fn with_default_poll_interval(
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

    /// Construct a config with an HTTP endpoint (requires JWT).
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

    /// Construct a config with an IPC endpoint (no JWT required).
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

/// JSON-RPC driver client for communicating with the driver.
///
/// Supports both HTTP (with JWT authentication) and IPC (with filesystem permissions).
#[derive(Clone, Debug)]
pub struct JsonRpcDriverClient {
    /// Driver RPC provider (HTTP+JWT or IPC).
    driver_provider: RootProvider,
    /// L2 provider used for safe/latest tip queries.
    l2_provider: RootProvider,
    /// Inbox contract instance bound to the L1 provider.
    inbox: InboxInstance<RootProvider>,
    /// Poll interval for event sync status checks.
    event_sync_poll_interval: Duration,
}

impl JsonRpcDriverClient {
    /// Create a new JSON-RPC driver client.
    ///
    /// For HTTP endpoints, JWT authentication is required.
    /// For IPC endpoints, security relies on filesystem permissions.
    pub async fn new(cfg: JsonRpcDriverClientConfig) -> Result<Self> {
        let driver_provider = match cfg.driver_endpoint {
            DriverEndpoint::Http(url) => {
                let jwt_secret_path = cfg.driver_jwt_secret.ok_or_else(|| {
                    PreconfirmationClientError::DriverClient(
                        "HTTP endpoint requires JWT secret path".into(),
                    )
                })?;
                let jwt_secret = read_jwt_secret(jwt_secret_path).ok_or_else(|| {
                    PreconfirmationClientError::DriverClient("failed to read JWT secret".into())
                })?;
                build_jwt_http_provider(url, jwt_secret)
            }
            DriverEndpoint::Ipc(path) => build_ipc_provider(path)
                .await
                .map_err(|e| PreconfirmationClientError::DriverClient(e.to_string()))?,
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

    /// Fetch the last canonical proposal id reported by the driver.
    async fn last_canonical_proposal_id(&self) -> Result<u64> {
        let start = Instant::now();
        let result = self
            .driver_provider
            .raw_request(Cow::Borrowed(DriverRpcMethod::LastCanonicalProposalId.as_str()), ())
            .await
            .map_err(|err| {
                metrics::counter!(
                    PreconfirmationClientMetrics::DRIVER_RPC_LAST_CANONICAL_ERRORS_TOTAL
                )
                .increment(1);
                error!(error = %err, "driver RPC lastCanonicalProposalId failed");
                PreconfirmationClientError::DriverClient(err.to_string())
            });

        metrics::histogram!(
            PreconfirmationClientMetrics::DRIVER_RPC_LAST_CANONICAL_DURATION_SECONDS
        )
        .record(start.elapsed().as_secs_f64());

        result
    }
}

#[async_trait]
impl DriverClient for JsonRpcDriverClient {
    /// Submit a preconfirmation payload to the driver over JSON-RPC.
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

        let config = self
            .inbox
            .getConfig()
            .call()
            .await
            .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?;
        let basefee_sharing_pctg = config.basefeeSharingPctg;

        // Build the payload with timing and error metrics.
        let payload_build_start = Instant::now();
        let payload_result =
            build_taiko_payload_attributes(&input, basefee_sharing_pctg, &self.l2_provider).await;
        metrics::histogram!(PreconfirmationClientMetrics::PAYLOAD_BUILD_DURATION_SECONDS)
            .record(payload_build_start.elapsed().as_secs_f64());

        let payload = match payload_result {
            Ok(payload) => payload,
            Err(err) => {
                metrics::counter!(PreconfirmationClientMetrics::PAYLOAD_BUILD_FAILURES_TOTAL)
                    .increment(1);
                error!(
                    block_number,
                    proposal_id,
                    error = %err,
                    "failed to build payload attributes"
                );
                return Err(err);
            }
        };

        // Submit to driver with timing and error metrics.
        debug!(block_number, proposal_id, "submitting preconfirmation payload to driver");

        let rpc_start = Instant::now();
        let result: std::result::Result<bool, _> = self
            .driver_provider
            .raw_request(
                Cow::Borrowed(DriverRpcMethod::SubmitPreconfirmationPayload.as_str()),
                (payload,),
            )
            .await;

        metrics::histogram!(PreconfirmationClientMetrics::DRIVER_RPC_SUBMIT_DURATION_SECONDS)
            .record(rpc_start.elapsed().as_secs_f64());

        match result {
            Ok(_) => {
                debug!(
                    block_number,
                    proposal_id, "successfully submitted preconfirmation payload to driver"
                );
                Ok(())
            }
            Err(err) => {
                metrics::counter!(PreconfirmationClientMetrics::DRIVER_RPC_SUBMIT_ERRORS_TOTAL)
                    .increment(1);
                error!(
                    block_number,
                    proposal_id,
                    error = %err,
                    "driver RPC submitPreconfirmationPayload failed"
                );
                Err(PreconfirmationClientError::DriverClient(err.to_string()))
            }
        }
    }

    /// Wait until the driver reports it has caught up with the L1 inbox.
    async fn wait_event_sync(&self) -> Result<()> {
        info!("starting wait for driver to sync with L1 inbox events");
        let start = Instant::now();

        loop {
            let last = self.last_canonical_proposal_id().await?;
            let core_state = self
                .inbox
                .getCoreState()
                .call()
                .await
                .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?;
            let next = core_state.nextProposalId.to::<u64>();

            debug!(
                last_canonical_proposal_id = last,
                next_proposal_id = next,
                "checking driver event sync progress"
            );

            if next == 0 {
                let elapsed = start.elapsed();
                metrics::histogram!(PreconfirmationClientMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS)
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
                metrics::histogram!(PreconfirmationClientMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS)
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
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Safe)
            .await
            .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?
            .ok_or_else(|| PreconfirmationClientError::DriverClient("missing safe block".into()))?;
        Ok(U256::from(block.number()))
    }

    /// Fetch the latest (unsafe) tip from the L2 execution engine.
    async fn preconf_tip(&self) -> Result<U256> {
        let block = self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?
            .ok_or_else(|| {
                PreconfirmationClientError::DriverClient("missing latest block".into())
            })?;
        Ok(U256::from(block.number()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn driver_endpoint_from_http_url() {
        let url: Url = "http://localhost:8545".parse().expect("url");
        let endpoint = DriverEndpoint::from(url.clone());
        assert!(matches!(endpoint, DriverEndpoint::Http(u) if u == url));
    }

    #[test]
    fn driver_endpoint_from_ipc_path() {
        let path = PathBuf::from("/tmp/driver.ipc");
        let endpoint = DriverEndpoint::from(path.clone());
        assert!(matches!(endpoint, DriverEndpoint::Ipc(p) if p == path));
    }

    #[test]
    fn driver_endpoint_is_http() {
        let http_endpoint = DriverEndpoint::Http("http://localhost:8545".parse().expect("url"));
        let ipc_endpoint = DriverEndpoint::Ipc(PathBuf::from("/tmp/driver.ipc"));

        assert!(http_endpoint.is_http());
        assert!(!http_endpoint.is_ipc());
        assert!(!ipc_endpoint.is_http());
        assert!(ipc_endpoint.is_ipc());
    }

    #[test]
    fn config_with_http_endpoint() {
        let url: Url = "http://localhost:8545".parse().expect("url");
        let jwt_secret = PathBuf::from("/tmp/jwt.hex");
        let config = JsonRpcDriverClientConfig::with_http_endpoint(
            url.clone(),
            jwt_secret.clone(),
            "http://l1:8545".parse().expect("l1 url"),
            "http://l2:8545".parse().expect("l2 url"),
            Address::ZERO,
        );

        assert!(matches!(config.driver_endpoint, DriverEndpoint::Http(u) if u == url));
        assert_eq!(config.driver_jwt_secret, Some(jwt_secret));
    }

    #[test]
    fn config_with_ipc_endpoint() {
        let path = PathBuf::from("/tmp/driver.ipc");
        let config = JsonRpcDriverClientConfig::with_ipc_endpoint(
            path.clone(),
            "http://l1:8545".parse().expect("l1 url"),
            "http://l2:8545".parse().expect("l2 url"),
            Address::ZERO,
        );

        assert!(matches!(config.driver_endpoint, DriverEndpoint::Ipc(p) if p == path));
        assert!(config.driver_jwt_secret.is_none());
    }

    #[test]
    fn config_with_default_poll_interval_is_http() {
        let url: Url = "http://localhost:8545".parse().expect("url");
        let jwt_secret = PathBuf::from("/tmp/jwt.hex");
        let config = JsonRpcDriverClientConfig::with_default_poll_interval(
            url.clone(),
            jwt_secret.clone(),
            "http://l1:8545".parse().expect("l1 url"),
            "http://l2:8545".parse().expect("l2 url"),
            Address::ZERO,
        );

        assert!(matches!(config.driver_endpoint, DriverEndpoint::Http(u) if u == url));
        assert_eq!(config.driver_jwt_secret, Some(jwt_secret));
    }
}
