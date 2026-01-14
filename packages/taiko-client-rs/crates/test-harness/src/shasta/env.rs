use std::{env, fmt, path::PathBuf, str::FromStr, time::Instant};

use crate::init_tracing;
use alloy::{eips::eip4844::BlobTransactionSidecar, transports::http::reqwest::Url as RpcUrl};
use alloy_primitives::{Address, B256};
use alloy_provider::RootProvider;
use anyhow::{Context, Result};
use rpc::{
    SubscriptionSource,
    client::{Client, ClientConfig, connect_http_with_timeout},
};
use test_context::AsyncTestContext;
use tracing::info;
use url::Url;

use super::helpers::{
    RpcClient, create_snapshot, ensure_preconf_whitelist_active, reset_head_l1_origin,
    reset_to_base_block, revert_snapshot,
};
use crate::BlobServer;

/// Environment configuration required to exercise Shasta fork integration tests against
/// the Docker harness started by `tests/entrypoint.sh`.
/// Holds resolved endpoints, credentials, and clients needed to drive Shasta integration flows.
pub struct ShastaEnv {
    pub l1_source: SubscriptionSource,
    pub l2_http: RpcUrl,
    pub l2_auth: RpcUrl,
    pub jwt_secret: PathBuf,
    pub inbox_address: Address,
    pub l2_suggested_fee_recipient: Address,
    pub l1_proposer_private_key: B256,
    pub taiko_anchor_address: Address,
    pub client_config: ClientConfig,
    pub client: RpcClient,
    cleanup_provider: RootProvider,
    snapshot_id: String,
    blob_server: Option<BlobServer>,
    /// Secondary L2 HTTP endpoint for dual-driver E2E tests.
    pub l2_http_1: RpcUrl,
    /// Secondary L2 WebSocket endpoint for dual-driver E2E tests.
    pub l2_ws_1: RpcUrl,
    /// Secondary L2 Auth endpoint for dual-driver E2E tests.
    pub l2_auth_1: RpcUrl,
}

impl fmt::Debug for ShastaEnv {
    /// Formats the `ShastaEnv` for debugging, omitting sensitive fields.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ShastaEnv")
            .field("l1_source", &self.l1_source)
            .field("l2_http", &self.l2_http)
            .field("l2_auth", &self.l2_auth)
            .field("jwt_secret", &self.jwt_secret)
            .field("inbox_address", &self.inbox_address)
            .field("l2_suggested_fee_recipient", &self.l2_suggested_fee_recipient)
            .field("l1_proposer_private_key", &self.l1_proposer_private_key)
            .field("taiko_anchor_address", &self.taiko_anchor_address)
            .field("client_config", &self.client_config)
            .field("client", &self.client)
            .field("blob_server", &self.blob_server.as_ref().map(|server| server.base_url()))
            .field("l2_http_1", &self.l2_http_1)
            .field("l2_ws_1", &self.l2_ws_1)
            .field("l2_auth_1", &self.l2_auth_1)
            .finish()
    }
}

impl ShastaEnv {
    fn load_l2_secondary_endpoints() -> Result<(RpcUrl, RpcUrl, RpcUrl)> {
        let l2_http_1 = env::var("L2_HTTP_1").context("L2_HTTP_1 env var is required")?;
        let l2_ws_1 = env::var("L2_WS_1").context("L2_WS_1 env var is required")?;
        let l2_auth_1 = env::var("L2_AUTH_1").context("L2_AUTH_1 env var is required")?;

        let l2_http_1_url =
            RpcUrl::parse(l2_http_1.as_str()).context("invalid L2_HTTP_1 endpoint")?;
        let l2_ws_1_url = RpcUrl::parse(l2_ws_1.as_str()).context("invalid L2_WS_1 endpoint")?;
        let l2_auth_1_url =
            RpcUrl::parse(l2_auth_1.as_str()).context("invalid L2_AUTH_1 endpoint")?;

        Ok((l2_http_1_url, l2_ws_1_url, l2_auth_1_url))
    }

    /// Resolves required environment variables and builds a default RPC client bundle.
    pub async fn load_from_env() -> Result<Self> {
        let started = Instant::now();

        // Initialize tracing for the test harness.
        init_tracing("info");

        // Read all required endpoints, secrets, and addresses from the harness environment.
        let l1_ws = env::var("L1_WS").context("L1_WS env var is required")?;
        let l1_http =
            env::var("L1_HTTP").context("L1_HTTP env var is required for cleanup snapshots")?;
        let l2_http = env::var("L2_HTTP").context("L2_HTTP env var is required")?;
        let l2_auth = env::var("L2_AUTH").context("L2_AUTH env var is required")?;
        let jwt_secret = env::var("JWT_SECRET").context("JWT_SECRET env var is required")?;
        let inbox = env::var("SHASTA_INBOX").context("SHASTA_INBOX env var is required")?;
        let fee_recipient = env::var("L2_SUGGESTED_FEE_RECIPIENT")
            .context("L2_SUGGESTED_FEE_RECIPIENT env var is required")?;
        let proposer_key = env::var("L1_PROPOSER_PRIVATE_KEY")
            .context("L1_PROPOSER_PRIVATE_KEY env var is required")?;
        let anchor = env::var("TAIKO_ANCHOR").context("TAIKO_ANCHOR env var is required")?;

        // Parse raw strings into URLs, paths, and addresses.
        let l1_source = SubscriptionSource::Ws(
            RpcUrl::parse(l1_ws.as_str()).context("invalid L1_WS endpoint")?,
        );
        let l1_http_url = RpcUrl::parse(l1_http.as_str()).context("invalid L1_HTTP endpoint")?;
        let l2_http_url = RpcUrl::parse(l2_http.as_str()).context("invalid L2_HTTP endpoint")?;
        let l2_auth_url = RpcUrl::parse(l2_auth.as_str()).context("invalid L2_AUTH endpoint")?;
        let jwt_secret_path = PathBuf::from(jwt_secret);
        let inbox_address = Address::from_str(inbox.as_str()).context("invalid SHASTA_INBOX")?;
        let l2_suggested_fee_recipient = Address::from_str(fee_recipient.as_str())
            .context("invalid L2_SUGGESTED_FEE_RECIPIENT")?;
        let l1_proposer_private_key =
            proposer_key.parse().context("invalid L1_PROPOSER_PRIVATE_KEY hex value")?;
        let taiko_anchor_address =
            Address::from_str(anchor.as_str()).context("invalid TAIKO_ANCHOR address")?;
        let (l2_http_1, l2_ws_1, l2_auth_1) = Self::load_l2_secondary_endpoints()?;

        // Build shared RPC client bundle and a dedicated HTTP provider for snapshots.
        let client_config = ClientConfig {
            l1_provider_source: l1_source.clone(),
            l2_provider_url: l2_http_url.clone(),
            l2_auth_provider_url: l2_auth_url.clone(),
            jwt_secret: jwt_secret_path.clone(),
            inbox_address,
        };
        let client = Client::new(client_config.clone()).await?;

        // Reset both L2 nodes to a known base block before tests run.
        reset_to_base_block(&client).await?;
        reset_head_l1_origin(&client).await?;

        let secondary_config = ClientConfig {
            l1_provider_source: l1_source.clone(),
            l2_provider_url: l2_http_1.clone(),
            l2_auth_provider_url: l2_auth_1.clone(),
            jwt_secret: jwt_secret_path.clone(),
            inbox_address,
        };
        let secondary_client = Client::new(secondary_config).await?;
        reset_to_base_block(&secondary_client).await?;
        reset_head_l1_origin(&secondary_client).await?;

        // Take a fresh snapshot and activate preconf whitelist before tests run.
        let cleanup_provider = connect_http_with_timeout(l1_http_url.clone());
        let snapshot_id = create_snapshot("setup", &cleanup_provider).await?;
        ensure_preconf_whitelist_active(&client).await?;

        info!(elapsed_ms = started.elapsed().as_millis(), "loaded ShastaEnv");
        Ok(Self {
            l1_source,
            l2_http: l2_http_url,
            l2_auth: l2_auth_url,
            jwt_secret: jwt_secret_path,
            inbox_address,
            l2_suggested_fee_recipient,
            l1_proposer_private_key,
            taiko_anchor_address,
            client_config,
            client,
            cleanup_provider,
            snapshot_id,
            blob_server: None,
            l2_http_1,
            l2_ws_1,
            l2_auth_1,
        })
    }

    /// Start a per-test blob server for serving the given sidecar.
    pub async fn start_blob_server(&mut self, sidecar: BlobTransactionSidecar) -> Result<RpcUrl> {
        let server = BlobServer::start(sidecar).await?;
        let endpoint =
            RpcUrl::parse(server.base_url().as_str()).context("parsing blob server URL")?;
        self.blob_server = Some(server);
        Ok(endpoint)
    }

    /// Return the blob server URL if it has been started.
    pub fn blob_server_url(&self) -> Result<RpcUrl> {
        let server = self.blob_server.as_ref().context("blob server not started")?;
        RpcUrl::parse(server.base_url().as_str()).context("parsing blob server URL")
    }

    /// Return the blob server endpoint as a `url::Url`.
    pub fn blob_server_endpoint(&self) -> Result<Url> {
        let server = self.blob_server.as_ref().context("blob server not started")?;
        Ok(server.endpoint().clone())
    }

    /// Explicit async teardown to revert the L1 snapshot.
    pub async fn shutdown(self) -> Result<()> {
        if let Some(server) = self.blob_server {
            server.shutdown().await?;
        }
        revert_snapshot(&self.cleanup_provider, &self.snapshot_id).await
    }
}

impl AsyncTestContext for ShastaEnv {
    /// Setup the ShastaEnv before each test.
    async fn setup() -> Self {
        ShastaEnv::load_from_env()
            .await
            .unwrap_or_else(|err| panic!("failed to load ShastaEnv: {err:#}"))
    }

    /// Teardown the ShastaEnv after each test.
    async fn teardown(self) {
        self.shutdown().await.unwrap_or_else(|err| panic!("ShastaEnv teardown failed: {err:?}"));
    }
}

#[cfg(test)]
mod tests {
    use super::ShastaEnv;
    use once_cell::sync::Lazy;
    use std::{env, sync::Mutex};

    static ENV_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

    struct EnvGuard {
        key: &'static str,
        previous: Option<String>,
    }

    impl EnvGuard {
        fn set(key: &'static str, value: &str) -> Self {
            let previous = env::var(key).ok();
            // SAFETY: tests are serialized with ENV_LOCK and this only mutates
            // test-scoped environment variables.
            unsafe { env::set_var(key, value) };
            Self { key, previous }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            // SAFETY: tests are serialized with ENV_LOCK.
            unsafe {
                match &self.previous {
                    Some(value) => env::set_var(self.key, value),
                    None => env::remove_var(self.key),
                }
            }
        }
    }

    #[test]
    fn secondary_l2_endpoints_are_loaded_when_set() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _http = EnvGuard::set("L2_HTTP_1", "http://localhost:38545");
        let _ws = EnvGuard::set("L2_WS_1", "ws://localhost:38546");
        let _auth = EnvGuard::set("L2_AUTH_1", "http://localhost:38551");

        let result = ShastaEnv::load_l2_secondary_endpoints();

        assert!(result.is_ok());
        let (l2_http_1, l2_ws_1, l2_auth_1) = result.unwrap();
        assert_eq!(l2_http_1.as_str(), "http://localhost:38545/");
        assert_eq!(l2_ws_1.as_str(), "ws://localhost:38546/");
        assert_eq!(l2_auth_1.as_str(), "http://localhost:38551/");
    }

    #[test]
    fn secondary_l2_endpoints_fail_when_unset() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        unsafe {
            env::remove_var("L2_HTTP_1");
            env::remove_var("L2_WS_1");
            env::remove_var("L2_AUTH_1");
        }

        let result = ShastaEnv::load_l2_secondary_endpoints();

        assert!(result.is_err());
    }
}
