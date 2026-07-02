use std::path::PathBuf;

use clap::Parser;
use color_eyre::Result;
use dotenvy::{dotenv, from_path};
use rollup_monitor::{
    config::Config,
    metrics,
    monitor::RollupMonitor,
    server::{HealthState, spawn_server},
};
use tokio::signal;
#[cfg(unix)]
use tokio::signal::unix::{SignalKind, signal as unix_signal};
use tracing::info;
use tracing_subscriber::{EnvFilter, fmt};

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
    metrics::init();

    let config = Config::parse();
    info!("Starting rollup-monitor");

    let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel::<()>();
    let http_port = config.http_port;
    let health = HealthState::new(std::time::Duration::from_secs(
        config.poll_interval_seconds.saturating_mul(3).max(1),
    ));
    let server_health = health.clone();
    let monitor_health = health.clone();

    let server_handle = tokio::spawn(async move {
        let shutdown = async move {
            let _ = shutdown_rx.await;
        };

        if let Err(error) = spawn_server(http_port, server_health, shutdown).await {
            tracing::error!("server exited with error: {error:?}");
        }
    });

    let monitor = RollupMonitor::with_health(config, monitor_health);
    let monitor_handle = tokio::spawn(async move {
        if let Err(error) = monitor.run().await {
            tracing::error!("rollup monitor exited with error: {error:?}");
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

    tokio::pin!(server_handle);
    tokio::pin!(monitor_handle);

    tokio::select! {
        _ = signal::ctrl_c() => {
            tracing::warn!("Ctrl+C received; shutting down");
        }
        _ = term => {
            tracing::warn!("SIGTERM received; shutting down");
        }
        result = &mut monitor_handle => {
            tracing::error!("monitor task exited unexpectedly: {result:?}");
            std::process::exit(1);
        }
        result = &mut server_handle => {
            tracing::error!("server task exited unexpectedly: {result:?}");
            std::process::exit(1);
        }
    }

    let _ = shutdown_tx.send(());
    monitor_handle.as_mut().abort();

    let _ = monitor_handle.await;
    let _ = server_handle.await;

    tracing::info!("Successfully shut down rollup-monitor gracefully");
    Ok(())
}
