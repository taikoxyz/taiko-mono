// std lib deps
use std::{path::PathBuf, str::FromStr};

use alloy::primitives::Address;
use alloy::signers::local::PrivateKeySigner;
// external deps
use clap::Parser;
use color_eyre::Result;
use dotenvy::{dotenv, from_path};
use tracing::info;
use tracing_subscriber::{EnvFilter, fmt};
use url::Url;

// project crates
use config::Config;
use monitor::Monitor;

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

    let block_watcher = Monitor::new(
        beacon_client,
        signer,
        l2_ws_url.clone(),
        l1_http_url.clone(),
        config.l2_target_block_time,
        config.eject_after_n_slots_missed,
        taiko_wrapper_address.clone(),
        whitelist_address.clone(),
        handover_slots,
    );

    block_watcher.run().await?;

    Ok(())
}
