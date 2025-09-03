use alloy_primitives::Bytes;
use alloy_provider::RootProvider;
use alloy_rpc_client::RpcClient as AlloyRpcClient;
use alloy_rpc_types_engine::JwtSecret;
use alloy_transport_http::{
    AuthLayer, Http, HyperClient,
    hyper_util::{client::legacy::Client, rt::TokioExecutor},
};
use http_body_util::Full;
use tower::ServiceBuilder;
use url::Url;

/// A client for interacting with L1 / L2 nodes, including optional authenticated
/// access to the L2 execution engine.
#[derive(Debug, Clone)]
pub struct RpcClient {
    l1_provider: RootProvider,
    l2_provider: RootProvider,
    l2_engine: Option<RootProvider>,
}

/// Configuration for the `RpcClient`.
#[derive(Debug, Clone)]
pub struct RpcClientConfig {
    pub l1_provider_url: Url,
    pub l2_provider_url: Url,
    pub l2_engine: Option<Url>,
    pub l2_engine_jwt: Option<JwtSecret>,
}

impl RpcClient {
    /// Creates a new `RpcClient` instance with the given configuration.
    pub fn new(config: RpcClientConfig) -> Self {
        let mut rpc_client = RpcClient {
            l1_provider: RootProvider::new_http(config.l1_provider_url),
            l2_provider: RootProvider::new_http(config.l2_provider_url),
            l2_engine: None,
        };

        // Creates a new auth RPC client for the given address and JWT secret.
        if let (Some(engine_url), Some(jwt)) = (config.l2_engine, config.l2_engine_jwt) {
            rpc_client.with_l2_engine(engine_url, jwt);
        }

        rpc_client
    }

    /// Returns a reference to the L1 provider.
    pub fn l1_provider(&self) -> &RootProvider {
        &self.l1_provider
    }

    /// Returns a reference to the L2 provider.
    pub fn l2_provider(&self) -> &RootProvider {
        &self.l2_provider
    }

    /// Returns a reference to the L2 execution engine, if configured.
    pub fn l2_engine(&self) -> Option<&RootProvider> {
        self.l2_engine.as_ref()
    }

    // Configures the L2 execution engine client with authentication.
    fn with_l2_engine(&mut self, url: Url, jwt: JwtSecret) {
        let hyper_client = Client::builder(TokioExecutor::new()).build_http::<Full<Bytes>>();
        let auth_service = ServiceBuilder::new().layer(AuthLayer::new(jwt)).service(hyper_client);
        let http_client = Http::with_client(HyperClient::with_service(auth_service), url);

        self.l2_engine = Some(RootProvider::new(AlloyRpcClient::new(http_client, false)))
    }
}
