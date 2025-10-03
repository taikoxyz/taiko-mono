use std::path::PathBuf;

use alloy::rpc::client::RpcClient;
use alloy::transports::http::reqwest::Url;
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

use crate::SubscriptionSource;

/// Instances of Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct ShastaProtocolInstance {
    pub inbox: IInboxInstance<FillProvider<JoinedRecommendedFillers, RootProvider>>,
    pub codec: CodecOptimizedInstance<FillProvider<JoinedRecommendedFillers, RootProvider>>,
}

/// A client for interacting with L1 and L2 providers and Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct Client {
    pub l1_provider: FillProvider<JoinedRecommendedFillers, RootProvider>,
    pub l2_provider: FillProvider<JoinedRecommendedFillers, RootProvider>,
    pub l2_auth_provider: FillProvider<JoinedRecommendedFillers, RootProvider>,
    pub shasta: ShastaProtocolInstance,
}

/// Configuration for the `Client`.
#[derive(Clone, Debug)]
pub struct ClientConfig {
    pub l1_provider_source: SubscriptionSource,
    pub l2_provider_source: SubscriptionSource,
    pub l2_auth_provider_url: Url,
    pub l1_sender_private_key: Option<B256>,
    pub jwt_secret: PathBuf,
    pub inbox_address: Address,
}

impl Client {
    /// Create a new `Client` from the given configuration.
    pub async fn new(config: ClientConfig) -> Result<Self> {
        let l1_provider =
            config.l1_provider_source.to_provider(config.l1_sender_private_key).await?.clone();
        let l2_provider =
            config.l2_provider_source.to_provider(config.l1_sender_private_key).await?.clone();

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
fn build_l2_auth_provider(
    url: Url,
    secret: JwtSecret,
) -> FillProvider<JoinedRecommendedFillers, RootProvider> {
    let hyper_client = HyperService::builder(TokioExecutor::new()).build_http::<Full<Bytes>>();

    let auth_layer = AuthLayer::new(secret);
    let service = ServiceBuilder::new().layer(auth_layer).service(hyper_client);

    let layer_transport = HyperClient::<Full<Bytes>, _>::with_service(service);
    let http_hyper = Http::with_client(layer_transport, url);

    ProviderBuilder::new().connect_client(RpcClient::new(http_hyper, true))
}

/// Returns the JWT secret for the engine API
/// using the provided [PathBuf]. If the file is not found,
/// it will return the default JWT secret.
pub fn read_jwt_secret(path: PathBuf) -> Option<JwtSecret> {
    if let Ok(secret) = std::fs::read_to_string(path) {
        return JwtSecret::from_hex(secret).ok();
    };

    None
}
