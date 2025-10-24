use std::{path::PathBuf, str::FromStr, time::Duration};

use alloy::primitives::Address;
use anyhow::{Context, Result};

use crate::config::Config;
use urc::monitor::config::DatabaseConfig;

/// Immutable runtime configuration used by the overseer monitor.
#[derive(Clone, Debug)]
pub struct MonitorConfig {
    pub rpc_url: String,
    pub expected_block_time: Duration,
    pub allowable_delay: Duration,
    pub allowable_mempool_transactions: u64,
    pub poll_interval: Duration,
    pub pending_tx_max_age: Duration,
    pub registry_settings: RegistrySettings,
    pub preconf_slasher: String,
    pub criteria: CriteriaToggles,
    pub lookahead: LookaheadSettings,
}

#[derive(Clone, Debug)]
#[allow(dead_code)]
pub struct RegistrySettings {
    pub database: DatabaseConfig,
    pub l1_rpc_url: String,
    pub registry_address: String,
    pub l1_start_block: u64,
    pub max_l1_fork_depth: u64,
    pub index_block_batch_size: u64,
}

#[derive(Clone, Debug)]
pub struct CriteriaToggles {
    pub block_timeliness: bool,
    pub mempool_stagnation: bool,
    pub pending_tx_age: bool,
}

#[derive(Clone, Debug)]
pub struct LookaheadSettings {
    pub store_address: Address,
    pub consensus_rpc_url: String,
    pub consensus_rpc_timeout_secs: u64,
    pub genesis_slot: u64,
    pub genesis_timestamp: u64,
    pub slot_duration_secs: u64,
    pub slots_per_epoch: u64,
    pub heartbeat_ms: u64,
}

impl MonitorConfig {
    /// Builds a monitor configuration from parsed configuration inputs, validating invariants.
    pub fn from_config(cfg: &Config) -> Result<Self> {
        Ok(Self {
            rpc_url: cfg.rpc_url.clone(),
            expected_block_time: Duration::from_secs(cfg.expected_block_time),
            allowable_delay: Duration::from_secs(cfg.allowable_delay),
            allowable_mempool_transactions: cfg.allowable_mempool_transactions,
            poll_interval: Duration::from_secs(cfg.poll_interval),
            pending_tx_max_age: Duration::from_secs(cfg.pending_tx_max_age),
            registry_settings: RegistrySettings {
                database: select_registry_database(
                    cfg.registry_db_url.clone(),
                    cfg.registry_db_path.clone(),
                ),
                l1_rpc_url: cfg
                    .registry_rpc_url
                    .clone()
                    .unwrap_or_else(|| cfg.rpc_url.clone()),
                registry_address: cfg.registry_address.clone(),
                l1_start_block: cfg.registry_start_block,
                max_l1_fork_depth: cfg.registry_max_fork_depth,
                index_block_batch_size: cfg.registry_batch_size,
            },
            preconf_slasher: cfg.preconf_slasher.clone(),
            criteria: CriteriaToggles {
                block_timeliness: cfg.enable_block_timeliness,
                mempool_stagnation: cfg.enable_mempool_stagnation,
                pending_tx_age: cfg.enable_pending_tx_age,
            },
            lookahead: LookaheadSettings {
                store_address: Address::from_str(&cfg.lookahead_store_address)
                    .with_context(|| "invalid lookahead store address".to_string())?,
                consensus_rpc_url: cfg.consensus_rpc_url.clone(),
                consensus_rpc_timeout_secs: cfg.consensus_rpc_timeout_secs,
                genesis_slot: cfg.lookahead_genesis_slot,
                genesis_timestamp: cfg.lookahead_genesis_timestamp,
                slot_duration_secs: cfg.lookahead_slot_duration,
                slots_per_epoch: cfg.lookahead_slots_per_epoch,
                heartbeat_ms: cfg.lookahead_heartbeat_ms,
            },
        })
    }
}

fn select_registry_database(url: Option<String>, path: Option<String>) -> DatabaseConfig {
    if let Some(url) = url {
        DatabaseConfig::MySql { url }
    } else {
        let path = PathBuf::from(path.unwrap_or_else(|| "registry_index.sqlite".to_string()));
        DatabaseConfig::Sqlite { path }
    }
}
