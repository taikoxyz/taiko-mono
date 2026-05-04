// std lib deps
use std::{path::PathBuf, str::FromStr};

use alloy::{primitives::Address, signers::local::PrivateKeySigner};
// external deps
use clap::Parser;
use color_eyre::Result;
use dotenvy::{dotenv, from_path};
// project modules
use ejector::{
    beacon::BeaconClient,
    config::Config,
    monitor::{Monitor, MonitorParams},
    server::spawn_server,
};
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

fn parse_preconfer_addresses(addresses: Option<&str>) -> Result<Vec<Address>> {
    addresses
        .unwrap_or_default()
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|addr| {
            Address::from_str(addr)
                .map_err(|err| color_eyre::eyre::eyre!("invalid preconfer address {addr}: {err}"))
        })
        .collect()
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
    let l2_http_url = Url::parse(&config.l2_http_url).expect("Invalid L2 HTTP URL");

    let signer = PrivateKeySigner::from_str(&config.private_key).expect("Invalid private key");

    let whitelist_address =
        Address::from_str(&config.preconf_whitelist_address).expect("Invalid whitelist address");

    info!("Whitelist Address: {:?}", whitelist_address);

    let taiko_wrapper_address =
        Address::from_str(&config.taiko_wrapper_address).expect("Invalid taiko wrapper address");

    let preconf_router_address =
        Address::from_str(&config.preconf_router_address).expect("Invalid preconf router address");

    let anchor_address = match &config.anchor_address {
        Some(addr) => Some(Address::from_str(addr).expect("Invalid anchor address")),
        None => {
            if config.enable_reorg_ejection {
                panic!("ANCHOR_ADDRESS is required when ENABLE_REORG_EJECTION is true");
            }
            None
        }
    };

    let beacon_url = Url::parse(&config.beacon_url).expect("Invalid Beacon URL");

    let beacon_client = BeaconClient::new(beacon_url).await?;

    let handover_slots = config.handover_slots;

    let preconfer_addresses = parse_preconfer_addresses(config.preconfer_addresses.as_deref())?;

    let server_handle = tokio::spawn(async move {
        // convert oneshot Receiver into a future (// TODO: why do i need to do this?)
        let shutdown = async move {
            let _ = shutdown_rx.await;
        };
        if let Err(e) = spawn_server(config.server_port, shutdown).await {
            tracing::error!("health server error: {e:?}");
        }
    });

    let monitor = Monitor::new(MonitorParams {
        beacon_client,
        l1_signer: signer,
        l1_http_url,
        l2_http_url,
        eject_after_seconds: config.eject_after_seconds,
        taiko_wrapper_address,
        whitelist_address,
        handover_slots,
        preconf_router_address,
        anchor_address,
        min_operators: config.min_operators,
        min_reorg_depth_for_eject: config.min_reorg_depth_for_eject,
        reorg_ejection_enabled: config.enable_reorg_ejection,
        preconfer_addresses,
    });

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_comma_separated_preconfer_addresses() {
        let first = Address::with_last_byte(0x11);
        let second = Address::with_last_byte(0x22);

        let parsed = parse_preconfer_addresses(Some(&format!("{first:#x}, {second:#x},")))
            .expect("preconfer addresses should parse");

        assert_eq!(parsed, vec![first, second]);
    }

    #[test]
    fn missing_preconfer_addresses_parse_as_empty_list() {
        let parsed =
            parse_preconfer_addresses(None).expect("missing preconfer addresses should parse");

        assert!(parsed.is_empty());
    }

    #[test]
    fn invalid_preconfer_address_returns_error() {
        let err = parse_preconfer_addresses(Some("0xnot-an-address"))
            .expect_err("invalid preconfer address should fail");

        assert!(err.to_string().contains("invalid preconfer address"));
    }
}
