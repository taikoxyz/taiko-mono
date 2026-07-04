mod config;
mod contracts;
mod criteria;
mod ethereum;
mod metrics;
mod monitor;
mod monitor_config;
mod types;

use std::sync::Arc;

use anyhow::Context;
use clap::Parser;
use tracing_subscriber::{fmt, EnvFilter};

use crate::{
    config::Config,
    contracts::{BlacklistContract, OnchainBlacklistContract},
    criteria::{
        BlacklistCriterion, BlockTimelinessCriterion, MempoolStagnationCriterion,
        PendingTransactionAgeCriterion,
    },
    ethereum::{EthereumClient, RpcEthereumClient},
    metrics::Metrics,
    monitor::Monitor,
    monitor_config::MonitorConfig,
};
use alloy::primitives::Address;
use alloy::providers::{Provider, ProviderBuilder};
use common::l1::{consensus_layer::ConsensusLayer, slot_clock::SlotClock};
use reqwest::Url;
use std::{str::FromStr, time::Duration};
use urc::lookahead::lookahead_builder::LookaheadBuilder;
use urc::monitor::db::DataBase as UrcDataBase;

/// CLI entrypoint that wires dependencies and launches the monitor runtime.
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    init_tracing();

    let config_inputs = Config::parse();
    let config = MonitorConfig::from_config(&config_inputs)?;

    let rpc_url = Url::parse(&config.rpc_url).context("invalid execution rpc url")?;

    let lookahead_provider = ProviderBuilder::new()
        .with_chain_id(config_inputs.chain_id)
        .connect_http(rpc_url.clone())
        .erased();

    let slot_clock = Arc::new(SlotClock::new(
        config.lookahead.genesis_slot,
        config.lookahead.genesis_timestamp,
        config.lookahead.slot_duration_secs,
        config.lookahead.slots_per_epoch,
        config.lookahead.heartbeat_ms,
    ));

    let consensus_layer = Arc::new(ConsensusLayer::new(
        &config.lookahead.consensus_rpc_url,
        Duration::from_secs(config.lookahead.consensus_rpc_timeout_secs),
    )?);

    let preconf_slasher_address =
        Address::from_str(&config.preconf_slasher).context("invalid preconf slasher address")?;
    let lookahead_db = UrcDataBase::new(&config.registry_settings.database).await?;
    let lookahead_builder = LookaheadBuilder::new(
        lookahead_provider,
        Arc::clone(&slot_clock),
        Arc::clone(&consensus_layer),
        lookahead_db,
        config.lookahead.store_address,
        preconf_slasher_address,
    )
    .await?;

    let ethereum_client: Arc<dyn EthereumClient> =
        Arc::new(RpcEthereumClient::new(&config.rpc_url)?);
    let blacklist_contract: Arc<dyn BlacklistContract> = Arc::new(
        OnchainBlacklistContract::new(
            &config.rpc_url,
            &config_inputs.private_key,
            &config_inputs.blacklist_contract,
            config_inputs.chain_id,
        )
        .await?,
    );
    let metrics: Arc<Metrics> = Arc::new(Metrics::new()?);

    let metrics_addr = config_inputs.metrics_addr;
    let metrics_server = crate::metrics::serve(Arc::clone(&metrics), metrics_addr);
    tokio::spawn(async move {
        if let Err(err) = metrics_server.await {
            tracing::error!(target: "overseer::metrics", error = ?err, "metrics server exited with error");
        }
    });

    let mut criteria: Vec<Box<dyn BlacklistCriterion>> = Vec::new();
    if config.criteria.block_timeliness {
        criteria.push(Box::new(BlockTimelinessCriterion::new()));
    }
    if config.criteria.mempool_stagnation {
        criteria.push(Box::new(MempoolStagnationCriterion::new()));
    }
    if config.criteria.pending_tx_age {
        criteria.push(Box::new(PendingTransactionAgeCriterion::new()));
    }

    if criteria.is_empty() {
        tracing::warn!(
            target: "overseer::service",
            "no blacklist criteria enabled; monitor will run without enforcement"
        );
    }

    let monitor = Monitor::new(
        config,
        ethereum_client,
        blacklist_contract,
        lookahead_builder,
        criteria,
        metrics,
    );
    monitor.run().await
}

/// Sets up structured logging based on `RUST_LOG` or a sensible default.
fn init_tracing() {
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    fmt()
        .with_env_filter(env_filter)
        .with_target(false)
        .compact()
        .init();
}
