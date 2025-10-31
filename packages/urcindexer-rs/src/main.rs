use anyhow::{bail, Context, Result};
use axum::{routing::get, Router};
use std::net::SocketAddr;
use tokio::{net::TcpListener, signal, sync::oneshot};
use tracing_subscriber::{fmt, EnvFilter};
use urc::monitor::{
    config::{Config, DatabaseConfig},
    registry_monitor::RegistryMonitor,
};

#[tokio::main]
async fn main() -> Result<()> {
    init_tracing();

    let config = Config::new().context("failed to load URC registry monitor configuration")?;
    ensure_mysql(&config)?;

    let mut monitor = RegistryMonitor::new(config)
        .await
        .context("failed to construct URC registry monitor")?;

    run_until_shutdown(&mut monitor).await
}

fn init_tracing() {
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    fmt()
        .with_env_filter(env_filter)
        .with_target(false)
        .compact()
        .init();
}

fn ensure_mysql(config: &Config) -> Result<()> {
    if !matches!(&config.database, DatabaseConfig::MySql { .. }) {
        bail!(
            "DATABASE_URL must be set to a MySQL connection string; DB_PATH/DB_FILENAME is reserved for sqlite"
        );
    }

    Ok(())
}

async fn run_until_shutdown(monitor: &mut RegistryMonitor) -> Result<()> {
    let health_addr = health_server_addr()?;
    let (shutdown_tx, shutdown_rx) = oneshot::channel();
    let mut health_server_handle = tokio::spawn(run_health_server(health_addr, shutdown_rx));
    let mut health_server_finished = false;

    let indexing = monitor.run_indexing_loop();
    tokio::pin!(indexing);

    let outcome = tokio::select! {
        result = &mut indexing => {
            result.context("registry indexing loop exited with an error")
        }
        result = &mut health_server_handle => {
            health_server_finished = true;
            let join_result = result.context("health server task panicked")?;
            match join_result {
                Ok(()) => bail!("health server exited unexpectedly"),
                Err(err) => Err(err).context("health server exited unexpectedly"),
            }
        }
        _ = signal::ctrl_c() => {
            tracing::info!("shutdown signal received; stopping registry indexing loop");
            Ok(())
        }
    };

    let _ = shutdown_tx.send(());

    if !health_server_finished {
        match health_server_handle.await {
            Ok(Ok(())) => {}
            Ok(Err(err)) => {
                tracing::error!(error = ?err, "health server did not shut down cleanly");
            }
            Err(err) => {
                tracing::error!(error = ?err, "health server task panicked");
            }
        }
    }

    outcome
}

fn health_server_addr() -> Result<SocketAddr> {
    let addr = std::env::var("HEALTH_SERVER_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_string());
    addr.parse()
        .with_context(|| format!("failed to parse HEALTH_SERVER_ADDR `{addr}`"))
}

async fn run_health_server(addr: SocketAddr, shutdown: oneshot::Receiver<()>) -> Result<()> {
    let router = Router::new().route("/healthz", get(health));

    let listener = TcpListener::bind(addr)
        .await
        .with_context(|| format!("failed to bind health server on {addr}"))?;

    tracing::info!(address = %addr, "starting health server");

    axum::serve(listener, router)
        .with_graceful_shutdown(async move {
            let _ = shutdown.await;
        })
        .await
        .context("health server encountered an error")?;

    Ok(())
}

async fn health() -> &'static str {
    "ok"
}
