//! REST/WS server for the whitelist preconfirmation driver.

use std::{net::SocketAddr, sync::Arc};

use tokio::{net::TcpListener, sync::oneshot, task::JoinHandle};
use tracing::{info, warn};

use super::WhitelistApi;
use crate::{
    Result, error::WhitelistPreconfirmationDriverError, importer::MAX_COMPRESSED_TX_LIST_BYTES,
};

mod auth;
mod handlers;
mod http_utils;
mod router;
mod state;
mod websocket;

#[cfg(test)]
mod tests;

/// `transactions` are hex-encoded in JSON (`0x` + 2 chars per byte), so payload limits must
/// account for expansion relative to compressed bytes on wire.
const PRECONF_BLOCKS_BODY_LIMIT_BYTES: usize = (MAX_COMPRESSED_TX_LIST_BYTES * 2) + (64 * 1024);

/// Configuration for the whitelist preconfirmation REST/WS server.
#[derive(Debug, Clone)]
pub struct WhitelistApiServerConfig {
    /// Socket address to listen on.
    pub listen_addr: SocketAddr,
    /// Whether HTTP transport is enabled.
    pub enable_http: bool,
    /// Whether WebSocket transport is enabled.
    pub enable_ws: bool,
    /// Optional shared secret used to validate `Authorization: Bearer <jwt>` on all routes.
    pub jwt_secret: Option<Vec<u8>>,
    /// Optional list of allowed CORS origins.
    pub cors_origins: Vec<String>,
}

impl Default for WhitelistApiServerConfig {
    /// Build the default server configuration (loopback bind, HTTP+WS enabled, no JWT).
    fn default() -> Self {
        Self {
            listen_addr: "127.0.0.1:8552".parse().expect("valid default address"),
            enable_http: true,
            enable_ws: true,
            jwt_secret: None,
            cors_origins: vec!["*".to_string()],
        }
    }
}

/// Running REST/WS server for whitelist preconfirmation operations.
///
/// The server serves Go-compatible REST routes and `/ws` notifications on one socket.
#[derive(Debug)]
pub struct WhitelistApiServer {
    /// Socket address bound by the server.
    addr: SocketAddr,
    /// Graceful-shutdown trigger for the running server.
    shutdown_tx: Option<oneshot::Sender<()>>,
    /// Background task running the axum server.
    task: JoinHandle<()>,
}

impl WhitelistApiServer {
    /// Start the REST/WS server.
    pub async fn start(
        config: WhitelistApiServerConfig,
        api: Arc<dyn WhitelistApi>,
    ) -> Result<Self> {
        if !config.enable_http && !config.enable_ws {
            return Err(WhitelistPreconfirmationDriverError::RestWsServerNoTransportsEnabled);
        }

        let state = state::AppState {
            api: Arc::clone(&api),
            jwt_auth: config
                .jwt_secret
                .as_ref()
                .map(|secret| Arc::new(auth::JwtAuth::new(secret.as_slice()))),
        };
        let app =
            router::build_router(state, &config.cors_origins, config.enable_http, config.enable_ws);

        let listener = TcpListener::bind(config.listen_addr).await.map_err(|e| {
            WhitelistPreconfirmationDriverError::RestWsServerBind {
                listen_addr: config.listen_addr,
                reason: e.to_string(),
            }
        })?;

        let addr = listener.local_addr().map_err(|e| {
            WhitelistPreconfirmationDriverError::RestWsServerLocalAddr { reason: e.to_string() }
        })?;

        let (shutdown_tx, shutdown_rx) = oneshot::channel();
        let task = tokio::spawn(async move {
            let server = axum::serve(listener, app).with_graceful_shutdown(async move {
                let _ = shutdown_rx.await;
            });

            if let Err(err) = server.await {
                warn!(error = %err, "whitelist preconfirmation REST/WS server terminated with error");
            }
        });

        info!(
            addr = %addr,
            enable_http = config.enable_http,
            enable_ws = config.enable_ws,
            jwt_enabled = config.jwt_secret.is_some(),
            cors_origins = ?config.cors_origins,
            http_url = %format!("http://{addr}"),
            ws_url = %format!("ws://{addr}"),
            "started whitelist preconfirmation REST/WS server"
        );

        Ok(Self { addr, shutdown_tx: Some(shutdown_tx), task })
    }

    /// Return the bound socket address.
    pub const fn local_addr(&self) -> SocketAddr {
        self.addr
    }

    /// Return the HTTP URL for this server.
    pub fn http_url(&self) -> String {
        format!("http://{}", self.addr)
    }

    /// Return the WebSocket URL for this server.
    pub fn ws_url(&self) -> String {
        format!("ws://{}", self.addr)
    }

    /// Stop the server gracefully.
    pub async fn stop(mut self) {
        if let Some(shutdown_tx) = self.shutdown_tx.take() {
            let _ = shutdown_tx.send(());
        }

        if let Err(err) = self.task.await {
            warn!(error = %err, "whitelist preconfirmation REST/WS server task join failed");
        }

        info!("whitelist preconfirmation REST/WS server stopped");
    }
}
