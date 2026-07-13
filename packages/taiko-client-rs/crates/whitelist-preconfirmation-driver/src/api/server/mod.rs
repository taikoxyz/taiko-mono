//! REST/WS server for the whitelist preconfirmation driver.

use std::{net::SocketAddr, sync::Arc, time::Duration};

use tokio::{net::TcpListener, sync::oneshot, task::JoinHandle};
use tokio_util::{sync::CancellationToken, task::TaskTracker};
use tracing::{info, warn};

use super::WhitelistApi;
use crate::{
    Result, codec::MAX_COMPRESSED_TX_LIST_BYTES, error::WhitelistPreconfirmationDriverError,
};

/// Grace period for tracked WebSocket sessions to observe shutdown and flush their close frames
/// before teardown proceeds without them.
///
/// A peer that has stopped reading its socket cannot be preempted mid-`send().await`, so the wait
/// for outstanding sessions must be bounded — a single stalled subscriber must not hang shutdown.
const WEBSOCKET_DRAIN_TIMEOUT: Duration = Duration::from_secs(2);

mod auth;
mod handlers;
mod http;
mod router;
mod websocket;

#[cfg(test)]
mod tests;

/// `transactions` are hex-encoded in JSON (`0x` + 2 chars per byte), so payload limits must
/// account for expansion relative to compressed bytes on wire.
const PRECONF_BLOCKS_BODY_LIMIT_BYTES: usize = (MAX_COMPRESSED_TX_LIST_BYTES * 2) + (64 * 1024);

/// Shared state for REST/WS handlers.
#[derive(Clone)]
struct AppState {
    /// Shared API implementation used by all request handlers.
    api: Arc<dyn WhitelistApi>,
    /// Optional shared JWT validator; `None` disables auth checks.
    jwt_auth: Option<Arc<auth::JwtAuth>>,
    /// Force-cancellation signal for REST handlers after the drain deadline expires.
    force_shutdown: CancellationToken,
    /// Graceful cancellation signal for active WebSocket sessions.
    websocket_shutdown: CancellationToken,
    /// Tracks upgraded WebSocket sessions independently spawned by Axum.
    websocket_tasks: TaskTracker,
}

/// Configuration for the whitelist preconfirmation REST/WS server.
#[derive(Debug, Clone)]
pub struct WhitelistApiServerConfig {
    /// Socket address to listen on.
    pub listen_addr: SocketAddr,
    /// Optional shared secret used to validate `Authorization: Bearer <jwt>` on all routes.
    pub jwt_secret: Option<Vec<u8>>,
    /// Optional list of allowed CORS origins.
    pub cors_origins: Vec<String>,
}

impl Default for WhitelistApiServerConfig {
    /// Build the default server configuration (loopback bind, no JWT).
    fn default() -> Self {
        Self {
            listen_addr: "127.0.0.1:8552".parse().expect("valid default address"),
            jwt_secret: None,
            cors_origins: vec!["*".to_string()],
        }
    }
}

/// Running REST/WS server for whitelist preconfirmation operations.
///
/// The server serves REST routes and `/ws` notifications on one socket.
#[derive(Debug)]
pub struct WhitelistApiServer {
    /// Socket address bound by the server.
    addr: SocketAddr,
    /// Graceful-shutdown trigger for the running server.
    shutdown_tx: Option<oneshot::Sender<()>>,
    /// Background task running the axum server.
    task: JoinHandle<()>,
    /// Whether the task result has already been consumed.
    joined: bool,
    /// Force-cancellation signal retained for timeout fallback.
    force_shutdown: CancellationToken,
    /// Graceful cancellation signal retained for timeout fallback.
    websocket_shutdown: CancellationToken,
    /// Tracks upgraded WebSocket sessions until they exit.
    websocket_tasks: TaskTracker,
}

impl WhitelistApiServer {
    /// Start the REST/WS server.
    pub async fn start(
        config: WhitelistApiServerConfig,
        api: Arc<dyn WhitelistApi>,
    ) -> Result<Self> {
        let force_shutdown = CancellationToken::new();
        let websocket_shutdown = CancellationToken::new();
        let websocket_tasks = TaskTracker::new();
        let state = AppState {
            api: Arc::clone(&api),
            jwt_auth: config
                .jwt_secret
                .as_ref()
                .map(|secret| Arc::new(auth::JwtAuth::new(secret.as_slice()))),
            force_shutdown: force_shutdown.clone(),
            websocket_shutdown: websocket_shutdown.clone(),
            websocket_tasks: websocket_tasks.clone(),
        };
        let app = router::build_router(state, &config.cors_origins);

        let listener = TcpListener::bind(config.listen_addr).await.map_err(|e| {
            WhitelistPreconfirmationDriverError::RestWsServerStartup(format!(
                "failed to bind {}: {e}",
                config.listen_addr
            ))
        })?;

        let addr = listener.local_addr().map_err(|e| {
            WhitelistPreconfirmationDriverError::RestWsServerStartup(format!(
                "failed to get local address: {e}"
            ))
        })?;

        let (shutdown_tx, shutdown_rx) = oneshot::channel();
        let websocket_shutdown_for_server = websocket_shutdown.clone();
        let websocket_tasks_for_server = websocket_tasks.clone();
        let task = tokio::spawn(async move {
            let server = axum::serve(listener, app).with_graceful_shutdown(async move {
                let _ = shutdown_rx.await;
                websocket_shutdown_for_server.cancel();
            });

            if let Err(err) = server.await {
                warn!(error = %err, "whitelist preconfirmation REST/WS server terminated with error");
            }
            websocket_tasks_for_server.close();
            if tokio::time::timeout(WEBSOCKET_DRAIN_TIMEOUT, websocket_tasks_for_server.wait())
                .await
                .is_err()
            {
                warn!("whitelist preconfirmation websocket drain timed out during shutdown");
            }
        });

        info!(
            addr = %addr,
            jwt_enabled = config.jwt_secret.is_some(),
            cors_origins = ?config.cors_origins,
            http_url = %format!("http://{addr}"),
            ws_url = %format!("ws://{addr}"),
            "started whitelist preconfirmation REST/WS server"
        );

        Ok(Self {
            addr,
            shutdown_tx: Some(shutdown_tx),
            task,
            joined: false,
            force_shutdown,
            websocket_shutdown,
            websocket_tasks,
        })
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

    /// Request graceful shutdown without relinquishing ownership of the server task.
    pub fn request_shutdown(&mut self) {
        if let Some(shutdown_tx) = self.shutdown_tx.take() {
            let _ = shutdown_tx.send(());
        }
    }

    /// Wait for the server task to stop after graceful shutdown has been requested.
    pub async fn wait_stopped(&mut self) {
        if self.joined {
            return;
        }
        if let Err(err) = (&mut self.task).await {
            warn!(error = %err, "whitelist preconfirmation REST/WS server task join failed");
        }
        self.joined = true;

        info!("whitelist preconfirmation REST/WS server stopped");
    }

    /// Abort the server task and wait until cancellation has completed.
    pub async fn abort(&mut self) {
        if self.joined {
            return;
        }
        self.request_shutdown();
        self.force_shutdown.cancel();
        self.websocket_shutdown.cancel();
        self.websocket_tasks.close();
        if tokio::time::timeout(WEBSOCKET_DRAIN_TIMEOUT, self.websocket_tasks.wait()).await.is_err()
        {
            warn!("whitelist preconfirmation websocket drain timed out during abort");
        }
        self.task.abort();
        if let Err(err) = (&mut self.task).await &&
            !err.is_cancelled()
        {
            warn!(error = %err, "whitelist preconfirmation REST/WS server abort failed");
        }
        self.joined = true;
    }

    /// Stop the server gracefully.
    pub async fn stop(&mut self) {
        self.request_shutdown();
        self.wait_stopped().await;
    }
}
