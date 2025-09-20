use std::sync::Arc;

use alloy_network::Ethereum;
use alloy_primitives::{Address, Bytes};
use alloy_provider::RootProvider;
use alloy_rpc_client::RpcClient as AlloyRpcClient;
use alloy_rpc_types_engine::JwtSecret;
use alloy_transport_http::{
    AuthLayer, Http, HyperClient,
    hyper_util::{client::legacy::Client, rt::TokioExecutor},
};
use http_body_util::Full;
use protocol::contracts::InboxOptimized3;
use tower::ServiceBuilder;
use url::Url;

#[derive(Debug, Clone)]
pub struct ShastaClient {
    inbox_address: Address,
    l1_provider: RootProvider<Ethereum>,
}

impl ShastaClient {
    /// Creates the InboxOptimized3 contract instance
    pub fn inbox_contract(&self) -> impl Clone + std::fmt::Debug {
        InboxOptimized3::new(self.inbox_address, &self.l1_provider)
    }
}

/// A client for interacting with L1 / L2 nodes, including optional authenticated
/// access to the L2 execution engine.
#[derive(Debug, Clone)]
pub struct RpcClient {
    l1_provider: RootProvider<Ethereum>,
    l2_provider: RootProvider<Ethereum>,
    l2_engine: Option<RootProvider<Ethereum>>,
    l2_engine_client: Option<Arc<AlloyRpcClient>>,
    shasta_client: Option<ShastaClient>,
}

/// Configuration for the `RpcClient`.
#[derive(Debug, Clone)]
pub struct RpcClientConfig {
    pub l1_provider_url: Url,
    pub l2_provider_url: Url,
    pub l2_engine: Option<Url>,
    pub l2_engine_jwt: Option<JwtSecret>,
    pub shasta_inbox_address: Option<Address>,
}

impl RpcClient {
    /// Creates a new `RpcClient` instance with the given configuration.
    pub fn new(config: RpcClientConfig) -> Self {
        let l1_provider = RootProvider::new_http(config.l1_provider_url.clone());
        
        // Initialize ShastaClient if inbox address is provided  
        let shasta_client = if let Some(inbox_address) = config.shasta_inbox_address {
            Some(ShastaClient {
                inbox_address,
                l1_provider: l1_provider.clone(),
            })
        } else {
            None
        };
        
        let mut rpc_client = RpcClient {
            l1_provider: l1_provider.clone(),
            l2_provider: RootProvider::new_http(config.l2_provider_url),
            l2_engine: None,
            l2_engine_client: None,
            shasta_client,
        };

        // Creates a new auth RPC client for the given address and JWT secret.
        if let (Some(engine_url), Some(jwt)) = (config.l2_engine, config.l2_engine_jwt) {
            rpc_client.with_l2_engine(engine_url, jwt);
        }

        rpc_client
    }

    /// Returns a reference to the L1 provider.
    pub fn l1_provider(&self) -> &RootProvider<Ethereum> {
        &self.l1_provider
    }

    /// Returns a reference to the L2 provider.
    pub fn l2_provider(&self) -> &RootProvider<Ethereum> {
        &self.l2_provider
    }

    /// Returns a reference to the L2 execution engine, if configured.
    pub fn l2_engine(&self) -> Option<&RootProvider<Ethereum>> {
        self.l2_engine.as_ref()
    }

    /// Returns a reference to the raw L2 engine RPC client, if configured.
    pub(crate) fn l2_engine_client(&self) -> Option<&Arc<AlloyRpcClient>> {
        self.l2_engine_client.as_ref()
    }

    /// Returns a reference to the Shasta client, if configured.
    pub fn shasta_client(&self) -> Option<&ShastaClient> {
        self.shasta_client.as_ref()
    }

    // Configures the L2 execution engine client with authentication.
    fn with_l2_engine(&mut self, url: Url, jwt: JwtSecret) {
        let hyper_client = Client::builder(TokioExecutor::new()).build_http::<Full<Bytes>>();
        let auth_service = ServiceBuilder::new().layer(AuthLayer::new(jwt)).service(hyper_client);
        let http_client = Http::with_client(HyperClient::with_service(auth_service), url);

        let rpc_client = AlloyRpcClient::new(http_client, false);
        let rpc_client_arc = Arc::new(rpc_client.clone());
        self.l2_engine = Some(RootProvider::new(rpc_client));
        self.l2_engine_client = Some(rpc_client_arc);
    }
}
