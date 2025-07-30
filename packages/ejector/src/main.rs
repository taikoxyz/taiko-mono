// std lib deps
use std::path::PathBuf;

// external deps
use clap::Parser;
use dotenvy::{dotenv, from_path};
use alloy_provider::ProviderBuilder;
use url::Url;


// project crates
use config::Config;

fn load_env_for_dev() {
    if std::env::var_os("KUBERNETES_SERVICE_HOST").is_none() {
        dotenv().ok();
        // Load environment variables from the .env file in the crate directory
        let crate_env = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        from_path(crate_env.join(".env")).ok();
    }
}

#[tokio::main]
async fn main() {
    color_eyre::install().unwrap();

    load_env_for_dev();

    let config = Config::parse();

    // convert l1_rpc_url to url

    let l1_rpc_url = Url::parse(&config.l1_rpc_url)
        .expect("Invalid L1 RPC URL");

    let l1_http_provider = ProviderBuilder::new()
        .on_http(l1_rpc_url.clone());

    let l2_ws_url = Url::parse(&config.l2_ws_url)
        .expect("Invalid L2 WS URL");

    let l2_http_provider = ProviderBuilder::new()
        .on_ws(connector::Ws::new(l2_ws_url.clone()));

}
