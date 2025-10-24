use anyhow::{bail, Context, Result};
use tokio::signal;
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
    let indexing = monitor.run_indexing_loop();
    tokio::pin!(indexing);

    tokio::select! {
        result = &mut indexing => {
            result.context("registry indexing loop exited with an error")?;
        }
        _ = signal::ctrl_c() => {
            tracing::info!("shutdown signal received; stopping registry indexing loop");
        }
    }

    Ok(())
}
