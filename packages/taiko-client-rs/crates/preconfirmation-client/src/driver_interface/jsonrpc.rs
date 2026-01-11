//! JSON-RPC implementation of the [`DriverClient`] interface.

use std::{borrow::Cow, path::PathBuf, time::Duration};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, U256};
use alloy_provider::{Provider, ProviderBuilder, RootProvider};
use async_trait::async_trait;
use bindings::inbox::Inbox::InboxInstance;
use rpc::client::{build_jwt_http_provider, read_jwt_secret};
use tokio::time::sleep;
use tracing::{debug, info};
use url::Url;

use super::{
    payload::build_taiko_payload_attributes,
    traits::{DriverClient, PreconfirmationInput},
};
use crate::{Result, error::PreconfirmationClientError};

/// Default poll interval for `wait_event_sync`.
const DEFAULT_EVENT_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(6);

/// Driver JSON-RPC method names.
#[derive(Debug, Clone, Copy)]
enum DriverRpcMethod {
    /// Submit a preconfirmation payload for injection.
    SubmitPreconfirmationPayload,
    /// Query the last canonical proposal id processed by the driver.
    LastCanonicalProposalId,
}

impl DriverRpcMethod {
    /// Return the JSON-RPC method name.
    const fn as_str(self) -> &'static str {
        match self {
            Self::SubmitPreconfirmationPayload => "preconf_submitPreconfirmationPayload",
            Self::LastCanonicalProposalId => "preconf_lastCanonicalProposalId",
        }
    }
}

/// Configuration for [`JsonRpcDriverClient`].
#[derive(Clone, Debug)]
pub struct JsonRpcDriverClientConfig {
    /// HTTP JSON-RPC endpoint of the driver server.
    pub driver_rpc_url: Url,
    /// Path to the JWT secret used by the driver JSON-RPC server.
    pub driver_jwt_secret: PathBuf,
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
    /// Construct a config with default poll interval.
    pub fn with_default_poll_interval(
        driver_rpc_url: Url,
        driver_jwt_secret: PathBuf,
        l1_rpc_url: Url,
        l2_rpc_url: Url,
        inbox_address: Address,
    ) -> Self {
        Self {
            driver_rpc_url,
            driver_jwt_secret,
            l1_rpc_url,
            l2_rpc_url,
            inbox_address,
            event_sync_poll_interval: DEFAULT_EVENT_SYNC_POLL_INTERVAL,
        }
    }
}

/// JSON-RPC driver client that authenticates via Engine JWT.
#[derive(Clone, Debug)]
pub struct JsonRpcDriverClient {
    /// JWT-authenticated driver RPC provider.
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
    pub fn new(cfg: JsonRpcDriverClientConfig) -> Result<Self> {
        let driver_provider = build_jwt_http_provider(
            cfg.driver_rpc_url,
            read_jwt_secret(cfg.driver_jwt_secret).ok_or_else(|| {
                PreconfirmationClientError::DriverClient("failed to read jwt secret".into())
            })?,
        );

        let l1_provider = ProviderBuilder::default().connect_http(cfg.l1_rpc_url);
        let l2_provider = ProviderBuilder::default().connect_http(cfg.l2_rpc_url);
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
        self.driver_provider
            .raw_request(Cow::Borrowed(DriverRpcMethod::LastCanonicalProposalId.as_str()), ())
            .await
            .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))
    }
}

#[async_trait]
impl DriverClient for JsonRpcDriverClient {
    /// Submit a preconfirmation payload to the driver over JSON-RPC.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        let config = self
            .inbox
            .getConfig()
            .call()
            .await
            .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?;
        let basefee_sharing_pctg = config.basefeeSharingPctg;

        let payload =
            build_taiko_payload_attributes(&input, basefee_sharing_pctg, &self.l2_provider).await?;

        let _ok: bool = self
            .driver_provider
            .raw_request(
                Cow::Borrowed(DriverRpcMethod::SubmitPreconfirmationPayload.as_str()),
                (payload,),
            )
            .await
            .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?;

        Ok(())
    }

    /// Wait until the driver reports it has caught up with the L1 inbox.
    async fn wait_event_sync(&self) -> Result<()> {
        info!("waiting for driver to sync with L1 inbox events");

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
                info!("driver event sync complete (no proposals in inbox)");
                return Ok(());
            }

            let target = next.saturating_sub(1);
            if last >= target {
                info!(
                    last_canonical_proposal_id = last,
                    target_proposal_id = target,
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
