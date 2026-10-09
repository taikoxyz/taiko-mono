//! RPC client for interacting with L1 and L2 nodes.

use std::{
    fs, io,
    path::{Path, PathBuf},
    time::Duration,
};

use alloy::{rpc::client::RpcClient, transports::http::reqwest::Url};
use alloy_provider::{
    Provider, ProviderBuilder, RootProvider, WsConnect, fillers::FillProvider,
    utils::JoinedRecommendedFillers,
};
use alloy_rpc_types_engine::JwtSecret;
use alloy_transport_http::{AuthLayer, Http, HyperClient};
use http_body_util::Full;
use hyper::body::Bytes;
use hyper_util::{
    client::legacy::{Client as HyperService, connect::HttpConnector},
    rt::TokioExecutor,
};
use reqwest::Client as ReqwestClient;
use tower::{ServiceBuilder, timeout::TimeoutLayer};

use crate::{
    SubscriptionSource,
    error::{Result, RpcClientError},
};

/// L1 provider type used by [`Client`]: recommended fillers over an HTTP/WS root provider.
pub type DefaultProvider = FillProvider<JoinedRecommendedFillers, RootProvider>;

/// Default HTTP timeout for RPC and auxiliary HTTP clients.
pub const DEFAULT_HTTP_TIMEOUT: Duration = Duration::from_secs(12);

/// A client for interacting with the L1 and L2 providers.
///
/// The client is read-only towards L1: it never signs or submits transactions, so it
/// carries no wallet.
#[derive(Clone, Debug)]
pub struct Client {
    /// L2 chain ID, fetched from the L2 provider at startup.
    pub chain_id: u64,
    /// Walletless L1 provider used for reads.
    pub l1_provider: DefaultProvider,
    /// L2 public provider for read-only access.
    pub l2_provider: RootProvider,
    /// L2 authenticated provider for Engine API calls.
    pub l2_auth_provider: RootProvider,
}

/// Configuration for the `Client`.
#[derive(Clone, Debug)]
pub struct ClientConfig {
    /// Source describing how to build the L1 provider.
    pub l1_provider_source: SubscriptionSource,
    /// HTTP endpoint for the L2 public provider.
    pub l2_provider_url: Url,
    /// HTTP endpoint for the L2 authenticated provider.
    pub l2_auth_provider_url: Url,
    /// Path to the engine JWT secret.
    pub jwt_secret: PathBuf,
}

impl Client {
    /// Create a new `Client` from the given configuration.
    pub async fn new(config: ClientConfig) -> Result<Self> {
        let l1_provider = config.l1_provider_source.to_provider().await.map_err(|e| {
            RpcClientError::Connection(format!(
                "L1 provider source (l1.http or l1.ws) connection failed: {}",
                e
            ))
        })?;
        let l2_provider =
            connect_provider_with_timeout(config.l2_provider_url.clone()).await.map_err(|e| {
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
            RpcClientError::RpcMessage(format!(
                "L2 HTTP RPC (l2.http) failed to get chain id from {}: {}",
                config.l2_provider_url, e
            ))
        })?;

        Ok(Self { chain_id, l1_provider, l2_provider, l2_auth_provider })
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
            .connect_ws(WsConnect::new(url.as_str()))
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

    #[tokio::test]
    async fn connect_provider_rejects_unknown_scheme() {
        let url = Url::parse("ftp://localhost:1234").expect("invalid test URL");
        let err = connect_provider_with_timeout(url).await.unwrap_err();
        assert!(err.to_string().contains("unsupported RPC scheme"));
    }
}
