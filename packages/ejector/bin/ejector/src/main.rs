// std lib deps
use std::{path::PathBuf, str::FromStr};

use alloy::primitives::Address;
use alloy::signers::local::PrivateKeySigner;
// external deps
use clap::Parser;
use color_eyre::Result;
use dotenvy::{dotenv, from_path};
use tokio::signal;
#[cfg(unix)]
use tokio::signal::unix::{SignalKind, signal as unix_signal};
use tracing::info;
use tracing_subscriber::{EnvFilter, fmt};
use url::Url;
// project crates
use config::Config;
use monitor::Monitor;
use server::spawn_server;

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
    color_eyre::install().expect("Failed to install color_eyre");

    let filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::from_env("RUST_LOG"));

    fmt().with_env_filter(filter).init();

    load_env_for_dev();

    info!("Starting Ejector...");

    let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel::<()>();

    let config = Config::parse();

    let l1_http_url = Url::parse(&config.l1_http_url).expect("Invalid L1 RPC URL");

    let signer = PrivateKeySigner::from_str(&config.private_key).expect("Invalid private key");

    let whitelist_address =
        Address::from_str(&config.preconf_whitelist_address).expect("Invalid whitelist address");

    info!("Whitelist Address: {:?}", whitelist_address);

    let taiko_wrapper_address =
        Address::from_str(&config.taiko_wrapper_address).expect("Invalid taiko wrapper address");

    let l2_ws_url = Url::parse(&config.l2_ws_url).expect("Invalid L2 WS URL");

    let beacon_url = Url::parse(&config.beacon_url).expect("Invalid Beacon URL");

    let beacon_client = beacon::BeaconClient::new(beacon_url.clone()).await?;

    let handover_slots = config.handover_slots;

    let server_handle = tokio::spawn(async move {
        // convert oneshot Receiver into a future (// TODO: why do i need to do this?)
        let shutdown = async move {
            let _ = shutdown_rx.await;
        };
        if let Err(e) = spawn_server(config.server_port, shutdown).await {
            tracing::error!("health server error: {e:?}");
        }
    });

    let monitor = Monitor::new(
        beacon_client,
        signer,
        l2_ws_url.clone(),
        l1_http_url.clone(),
        config.l2_target_block_time,
        config.eject_after_n_slots_missed,
        taiko_wrapper_address,
        whitelist_address,
        handover_slots,
        config.min_operators,
    );

    let monitor_handle = tokio::spawn(async move {
        if let Err(e) = monitor.run().await {
            tracing::error!("monitor exited with error: {e:?}");
        }
    });

    let term = async {
        if let Ok(mut sig) = unix_signal(SignalKind::terminate()) {
            sig.recv().await;
        }
    };

    tokio::select! {
        _ = signal::ctrl_c() => {
            tracing::warn!("Ctrl+C received — shutting down");
        }
        _ = term => {
            tracing::warn!("SIGTERM received — shutting down");
        }
    }

    let _ = shutdown_tx.send(());
    monitor_handle.abort();

    let _ = server_handle.await;

    tracing::info!("Successfully shut down ejector gracefully");
    Ok(())
}
