use std::path::PathBuf;

use clap::Parser;
use color_eyre::Result;
use dotenvy::{dotenv, from_path};
use reorg_monitor::{config::Config, monitor::ReorgMonitor, server::spawn_server};
use tokio::signal;
#[cfg(unix)]
use tokio::signal::unix::{SignalKind, signal as unix_signal};
use tracing::info;
use tracing_subscriber::{EnvFilter, fmt};
use url::Url;

fn load_env_for_dev() {
    if std::env::var_os("KUBERNETES_SERVICE_HOST").is_some() {
        return;
    }

    let crate_env = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(".env");
    let _ = from_path(&crate_env);
    let _ = dotenv();
}

#[tokio::main]
async fn main() -> Result<()> {
    color_eyre::install()?;

    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    fmt().with_env_filter(filter).init();

    load_env_for_dev();

    let config = Config::parse();
    let l2_ws_url = Url::parse(&config.l2_ws_url)
        .map_err(|error| eyre::eyre!("invalid L2_WS_URL '{}': {error}", config.l2_ws_url))?;

    info!(
        "Starting reorg-monitor with L2 websocket {} and history depth {}",
        l2_ws_url, config.reorg_history_depth
    );

    let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel::<()>();
    let http_port = config.http_port;

    let server_handle = tokio::spawn(async move {
        let shutdown = async move {
            let _ = shutdown_rx.await;
        };

        if let Err(error) = spawn_server(http_port, shutdown).await {
            tracing::error!("server exited with error: {error:?}");
        }
    });

    let monitor = ReorgMonitor::new(l2_ws_url, config.reorg_history_depth);
    let monitor_handle = tokio::spawn(async move {
        if let Err(error) = monitor.run().await {
            tracing::error!("reorg monitor exited with error: {error:?}");
        }
    });

    #[cfg(unix)]
    let term = async {
        if let Ok(mut signal) = unix_signal(SignalKind::terminate()) {
            signal.recv().await;
        }
    };
    #[cfg(not(unix))]
    let term = std::future::pending::<()>();

    tokio::select! {
        _ = signal::ctrl_c() => {
            tracing::warn!("Ctrl+C received; shutting down");
        }
        _ = term => {
            tracing::warn!("SIGTERM received; shutting down");
        }
    }

    let _ = shutdown_tx.send(());
    monitor_handle.abort();

    let _ = monitor_handle.await;
    let _ = server_handle.await;

    tracing::info!("Successfully shut down reorg-monitor gracefully");
    Ok(())
}
