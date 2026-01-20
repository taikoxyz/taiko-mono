//! HTTP JSON-RPC server for user-facing preconfirmation operations.

use std::{net::SocketAddr, sync::Arc, time::Duration};

use jsonrpsee::server::{Server, ServerHandle};
use preconfirmation_net::NetworkCommand;
use tokio::sync::mpsc;
use tracing::info;

use super::api::{PreconfRpcApiImpl, PreconfRpcApiServer};
use crate::{
    error::{PreconfirmationNodeError, Result},
    storage::CommitmentStore,
};

/// Configuration for the RPC server.
#[derive(Debug, Clone)]
pub struct RpcServerConfig {
    /// Address to bind the HTTP server.
    pub http_addr: SocketAddr,
    /// Timeout for P2P network requests when data is missing from cache.
    pub p2p_request_timeout: Duration,
}

impl Default for RpcServerConfig {
    /// Build the default RPC server configuration.
    fn default() -> Self {
        Self {
            http_addr: "127.0.0.1:8550".parse().expect("default RPC addr"),
            p2p_request_timeout: Duration::from_secs(5),
        }
    }
}

/// User-facing JSON-RPC server.
pub struct PreconfRpcServer {
    /// RPC server configuration.
    config: RpcServerConfig,
    /// API implementation consumed by the server.
    api: PreconfRpcApiImpl,
    /// Shared API handle for status updates.
    api_handle: Arc<PreconfRpcApiImpl>,
    /// Active server handle, if started.
    handle: Option<ServerHandle>,
}

impl PreconfRpcServer {
    /// Creates a new RPC server.
    pub fn new(
        config: RpcServerConfig,
        command_sender: mpsc::Sender<NetworkCommand>,
        store: Arc<dyn CommitmentStore>,
    ) -> Self {
        let api = PreconfRpcApiImpl::new(command_sender, store, config.p2p_request_timeout);
        let api_handle = Arc::new(api.clone());

        Self { config, api, api_handle, handle: None }
    }

    /// Returns a reference to the API implementation for status updates.
    pub fn api(&self) -> Arc<PreconfRpcApiImpl> {
        Arc::clone(&self.api_handle)
    }

    /// Starts the RPC server.
    pub async fn start(&mut self) -> Result<()> {
        let server = Server::builder()
            .build(self.config.http_addr)
            .await
            .map_err(|err| PreconfirmationNodeError::RpcServer(err.to_string()))?;

        info!("starting preconf RPC server on {}", self.config.http_addr);

        let handle = server.start(self.api.clone().into_rpc());
        self.handle = Some(handle);

        Ok(())
    }

    /// Stops the RPC server.
    pub async fn stop(&mut self) {
        if let Some(handle) = self.handle.take() {
            let _ = handle.stop();
            let _ = handle.stopped().await;
            info!("preconf RPC server stopped");
        }
    }
}
