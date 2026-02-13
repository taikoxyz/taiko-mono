//! RPC client for interacting with L1 and L2 nodes.

use std::{
    fs, io,
    path::{Path, PathBuf},
    time::Duration,
};

use alethia_reth_evm::handler::get_treasury_address;
use alloy::{eips::BlockNumberOrTag, rpc::client::RpcClient, transports::http::reqwest::Url};
use alloy_eips::{BlockId, eip1898::RpcBlockHash};
use alloy_primitives::{Address, B256};
use alloy_provider::{
    IpcConnect, Provider, ProviderBuilder, RootProvider, WsConnect, fillers::FillProvider,
    utils::JoinedRecommendedFillers,
};
use alloy_rpc_types::engine::JwtSecret;
use alloy_transport_http::{AuthLayer, Http, HyperClient};
use bindings::{anchor::Anchor::AnchorInstance, inbox::Inbox::InboxInstance};
use http_body_util::Full;
use hyper::body::Bytes;
use hyper_util::{
    client::legacy::{Client as HyperService, connect::HttpConnector},
    rt::TokioExecutor,
};
use reqwest::Client as ReqwestClient;
use tower::{ServiceBuilder, timeout::TimeoutLayer};
use tracing::info;

use crate::{
    JoinedRecommendedFillersWithWallet, SubscriptionSource,
    error::{Result, RpcClientError},
};

/// Type alias for a Client with a provider that includes a wallet.
pub type ClientWithWallet = Client<FillProvider<JoinedRecommendedFillersWithWallet, RootProvider>>;

/// Default HTTP timeout for RPC and auxiliary HTTP clients.
pub const DEFAULT_HTTP_TIMEOUT: Duration = Duration::from_secs(12);

/// Instances of Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct ShastaProtocolInstance<P: Provider + Clone> {
    /// Inbox contract instance on L1.
    pub inbox: InboxInstance<P>,
    /// Anchor contract instance on L2 (auth provider).
    pub anchor: AnchorInstance<RootProvider>,
}

/// Snapshot of anchor contract state at a given L2 block.
#[derive(Clone, Debug)]
pub struct AnchorState {
    /// Anchor block number advertised by the anchor contract.
    pub anchor_block_number: u64,
}

/// A client for interacting with L1 and L2 providers and Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct Client<P: Provider + Clone> {
    /// L1 provider (optionally with wallet) used for contract calls.
    pub l1_provider: P,
    /// L2 public provider for read-only access.
    pub l2_provider: RootProvider,
    /// L2 authenticated provider for engine/anchor interactions.
    pub l2_auth_provider: RootProvider,
    /// Shasta protocol contract bundle (Inbox/Anchor).
    pub shasta: ShastaProtocolInstance<P>,
}

/// Configuration for the `Client`.
#[derive(Clone, Debug)]
pub struct ClientConfig {
    /// Source describing how to build the L1 provider (WS/HTTP/etc).
    pub l1_provider_source: SubscriptionSource,
    /// HTTP endpoint for the L2 public provider.
    pub l2_provider_url: Url,
    /// HTTP endpoint for the L2 authenticated provider.
    pub l2_auth_provider_url: Url,
    /// Path to the engine JWT secret.
    pub jwt_secret: PathBuf,
    /// L1 address of the Inbox contract.
    pub inbox_address: Address,
}

impl Client<FillProvider<JoinedRecommendedFillers, RootProvider>> {
    /// Create a new `Client` without a wallet from the given configuration.
    pub async fn new(config: ClientConfig) -> Result<Self> {
        let l1_provider = config
            .l1_provider_source
            .to_provider()
            .await
            .map_err(|e| {
                RpcClientError::Connection(format!(
                    "L1 WebSocket (l1.ws) connection failed: {}",
                    e
                ))
            })?;
        Self::new_with_l1_provider(l1_provider, config).await
    }
}

impl Client<FillProvider<JoinedRecommendedFillersWithWallet, RootProvider>> {
    /// Create a new `Client` with a wallet from the given configuration.
    pub async fn new_with_wallet(config: ClientConfig, private_key: B256) -> Result<Self> {
        let l1_provider = config
            .l1_provider_source
            .to_provider_with_wallet(private_key)
            .await
            .map_err(|e| {
                RpcClientError::Connection(format!(
                    "L1 WebSocket (l1.ws) connection failed: {}",
                    e
                ))
            })?;
        Self::new_with_l1_provider(l1_provider, config).await
    }
}

impl<P: Provider + Clone> Client<P> {
    /// Create a new `Client` from the given L1 provider and configuration.
    async fn new_with_l1_provider(l1_provider: P, config: ClientConfig) -> Result<Self> {
        let l2_provider = connect_provider_with_timeout(config.l2_provider_url.clone())
            .await
            .map_err(|e| {
                RpcClientError::Connection(format!(
                    "L2 HTTP RPC (l2.http) connection failed for {}: {}",
                    config.l2_provider_url, e
                ))
            })?;
        let jwt_secret = read_jwt_secret(config.jwt_secret.as_path()).ok_or_else(|| {
            RpcClientError::JwtSecretReadFailed(config.jwt_secret.display().to_string())
        })?;
        let l2_auth_provider =
            build_jwt_http_provider(config.l2_auth_provider_url.clone(), jwt_secret);

        let chain_id = l2_provider.get_chain_id().await.map_err(|e| {
            RpcClientError::Rpc(format!(
                "L2 HTTP RPC (l2.http) failed to get chain id from {}: {}",
                config.l2_provider_url, e
            ))
        })?;

        let inbox = InboxInstance::new(config.inbox_address, l1_provider.clone());
        let anchor = AnchorInstance::new(
            get_treasury_address(chain_id),
            l2_auth_provider.clone(),
        );

        info!(
            inbox_address = ?config.inbox_address,
            anchor_address = ?anchor.address(),
            "Shasta protocol contract addresses"
        );

        let shasta = ShastaProtocolInstance { inbox, anchor };

        Ok(Self { l1_provider, l2_provider, l2_auth_provider, shasta })
    }

    /// Fetch the L1 block hash for a given block number.
    pub async fn l1_block_hash_by_number(&self, block_number: u64) -> Result<Option<B256>> {
        self.l1_provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map(|origin_block| origin_block.map(|block| block.hash()))
            .map_err(|err| RpcClientError::Provider(err.to_string()))
    }

    /// Fetch the Shasta anchor state for the given parent block hash.
    pub async fn shasta_anchor_state_by_hash(&self, block_hash: B256) -> Result<AnchorState> {
        let block_id = BlockId::Hash(RpcBlockHash { block_hash, require_canonical: Some(false) });

        let block_state = self.shasta.anchor.getBlockState().block(block_id).call().await?;

        Ok(AnchorState { anchor_block_number: block_state.anchorBlockNumber.to::<u64>() })
    }
}

/// Build a reqwest HTTP client with a bounded timeout.
fn reqwest_client_with_timeout() -> ReqwestClient {
    ReqwestClient::builder().timeout(DEFAULT_HTTP_TIMEOUT).build().expect("http client")
}

/// Build a [`RootProvider`] backed by a reqwest client with a bounded timeout.
pub fn connect_http_with_timeout(url: Url) -> RootProvider {
    ProviderBuilder::default().connect_reqwest(reqwest_client_with_timeout(), url)
}

/// Build a [`RootProvider`] backed by either HTTP or WebSocket transport based on URL scheme.
pub async fn connect_provider_with_timeout(url: Url) -> Result<RootProvider> {
    match url.scheme() {
        "http" | "https" => Ok(connect_http_with_timeout(url)),
        "ws" | "wss" => ProviderBuilder::default()
            .connect_ws(WsConnect::new(url.to_string()))
            .await
            .map_err(|e| RpcClientError::Connection(e.to_string())),
        scheme => Err(RpcClientError::Connection(format!("unsupported RPC scheme: {scheme}"))),
    }
}

/// Builds a [`RootProvider`] backed by an HTTP transport that authenticates each request
/// using the Engine API JWT scheme.
pub fn build_jwt_http_provider(url: Url, secret: JwtSecret) -> RootProvider {
    let hyper_client: HyperService<HttpConnector, Full<Bytes>> =
        HyperService::builder(TokioExecutor::new()).build_http::<Full<Bytes>>();

    let auth_layer = AuthLayer::new(secret);
    let service = ServiceBuilder::new()
        .map_err(io::Error::other)
        .layer(TimeoutLayer::new(DEFAULT_HTTP_TIMEOUT))
        .layer(auth_layer)
        .service(hyper_client);

    let layer_transport = HyperClient::<Full<Bytes>, _>::with_service(service);
    let http_hyper = Http::with_client(layer_transport, url);

    ProviderBuilder::default().connect_client(RpcClient::new(http_hyper, true))
}

/// Builds a [`RootProvider`] backed by an IPC transport.
///
/// IPC does not require JWT authentication; security relies on filesystem permissions.
pub async fn build_ipc_provider(path: PathBuf) -> Result<RootProvider> {
    ProviderBuilder::default()
        .connect_ipc(IpcConnect::new(path))
        .await
        .map_err(|e| RpcClientError::Connection(e.to_string()))
}

/// Returns the JWT secret for the engine API
/// using the provided path. If the file is not found, it will return [None].
pub fn read_jwt_secret(path: &Path) -> Option<JwtSecret> {
    if let Ok(secret) = fs::read_to_string(path) {
        return JwtSecret::from_hex(secret).ok();
    };

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_read_jwt_secret() {
        let jwt_path =
            PathBuf::from(concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/docker/jwt.hex"));

        // Should successfully read the JWT secret
        let secret = read_jwt_secret(jwt_path.as_path());
        assert!(secret.is_some());

        // Verify the secret is a valid 32-byte key
        let secret = secret.unwrap();
        assert_eq!(secret.as_bytes().len(), 32);
    }

    #[test]
    fn test_read_jwt_secret_nonexistent() {
        let jwt_path = PathBuf::from("/nonexistent/path/jwt.hex");

        // Should return None for non-existent file
        let secret = read_jwt_secret(jwt_path.as_path());
        assert!(secret.is_none());
    }

    #[test]
    fn test_default_http_timeout_covers_preconfirmation_budget() {
        assert_eq!(
            DEFAULT_HTTP_TIMEOUT,
            Duration::from_secs(12),
            "DEFAULT_HTTP_TIMEOUT should default to 12 seconds"
        );
    }

    #[tokio::test]
    async fn connect_provider_rejects_unknown_scheme() {
        let url = Url::parse("ftp://localhost:1234").expect("invalid test URL");
        let err = connect_provider_with_timeout(url).await.unwrap_err();
        assert!(err.to_string().contains("unsupported RPC scheme"));
    }
}
