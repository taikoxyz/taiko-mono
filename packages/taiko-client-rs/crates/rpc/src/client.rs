use std::path::PathBuf;

use alloy::{rpc::client::RpcClient, transports::http::reqwest::Url};
use alloy_primitives::{Address, B256};
use alloy_provider::{
    Provider, ProviderBuilder, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use alloy_rpc_types::engine::JwtSecret;
use alloy_transport_http::{AuthLayer, Http, HyperClient};
use anyhow::Result;
use bindings::{
    codec_optimized::CodecOptimized::CodecOptimizedInstance, i_inbox::IInbox::IInboxInstance,
};
use http_body_util::Full;
use hyper::body::Bytes;
use hyper_util::{client::legacy::Client as HyperService, rt::TokioExecutor};
use tower::ServiceBuilder;

use crate::{JoinedRecommendedFillersWithWallet, SubscriptionSource};

/// Type alias for a Client with a provider that includes a wallet.
pub type ClientWithWallet = Client<FillProvider<JoinedRecommendedFillersWithWallet, RootProvider>>;

/// Instances of Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct ShastaProtocolInstance<P: Provider + Clone> {
    pub inbox: IInboxInstance<P>,
    pub codec: CodecOptimizedInstance<P>,
}

/// A client for interacting with L1 and L2 providers and Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct Client<P: Provider + Clone> {
    pub l1_provider: P,
    pub l2_provider: RootProvider,
    pub l2_auth_provider: RootProvider,
    pub shasta: ShastaProtocolInstance<P>,
}

/// Configuration for the `Client`.
#[derive(Clone, Debug)]
pub struct ClientConfig {
    pub l1_provider_source: SubscriptionSource,
    pub l2_provider_url: Url,
    pub l2_auth_provider_url: Url,
    pub jwt_secret: PathBuf,
    pub inbox_address: Address,
}

impl Client<FillProvider<JoinedRecommendedFillers, RootProvider>> {
    /// Create a new `Client` without a wallet from the given configuration.
    pub async fn new(config: ClientConfig) -> Result<Self> {
        Self::new_with_l1_provider(config.l1_provider_source.to_provider().await?, config).await
    }
}

impl Client<FillProvider<JoinedRecommendedFillersWithWallet, RootProvider>> {
    /// Create a new `Client` with a wallet from the given configuration.
    pub async fn new_with_wallet(config: ClientConfig, private_key: B256) -> Result<Self> {
        Self::new_with_l1_provider(
            config.l1_provider_source.to_provider_with_wallet(private_key).await?,
            config,
        )
        .await
    }
}

impl<P: Provider + Clone> Client<P> {
    /// Create a new `Client` from the given L1 provider and configuration.
    async fn new_with_l1_provider(l1_provider: P, config: ClientConfig) -> Result<Self> {
        let l2_provider = ProviderBuilder::default().connect_http(config.l2_provider_url);
        let jwt_secret = read_jwt_secret(config.jwt_secret.clone())
            .ok_or_else(|| anyhow::anyhow!("Failed to read JWT secret"))?;
        let l2_auth_provider =
            build_l2_auth_provider(config.l2_auth_provider_url.clone(), jwt_secret);

        let inbox = IInboxInstance::new(config.inbox_address, l1_provider.clone());
        let codec =
            CodecOptimizedInstance::new(inbox.getConfig().call().await?.codec, l1_provider.clone());

        let shasta = ShastaProtocolInstance { inbox, codec };

        Ok(Self { l1_provider, l2_provider, l2_auth_provider, shasta })
    }
}

/// Builds a RootProvider for the L2 auth provider using the provided URL and JWT secret.
fn build_l2_auth_provider(url: Url, secret: JwtSecret) -> RootProvider {
    let hyper_client: HyperService<
        hyper_util::client::legacy::connect::HttpConnector,
        Full<Bytes>,
    > = HyperService::builder(TokioExecutor::new()).build_http::<Full<Bytes>>();

    let auth_layer = AuthLayer::new(secret);
    let service = ServiceBuilder::new().layer(auth_layer).service(hyper_client);

    let layer_transport = HyperClient::<Full<Bytes>, _>::with_service(service);
    let http_hyper = Http::with_client(layer_transport, url);

    ProviderBuilder::default().connect_client(RpcClient::new(http_hyper, true))
}

/// Returns the JWT secret for the engine API
/// using the provided [PathBuf]. If the file is not found, it will return [None].
pub fn read_jwt_secret(path: PathBuf) -> Option<JwtSecret> {
    if let Ok(secret) = std::fs::read_to_string(path) {
        return JwtSecret::from_hex(secret).ok();
    };

    None
}
