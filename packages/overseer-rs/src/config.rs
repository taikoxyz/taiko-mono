use std::net::SocketAddr;

use clap::Parser;

/// Overseer service configuration sourced from CLI arguments and environment variables.
#[derive(Debug, Clone, Parser)]
#[command(author, version, about = "Preconfirmer overseer service", long_about = None)]
pub struct Config {
    /// Ethereum execution layer RPC endpoint.
    #[arg(long = "rpc-url", env = "OVERSEER_RPC_URL")]
    pub rpc_url: String,

    /// Expected block production interval in seconds.
    #[arg(
        long = "expected-block-time",
        value_parser = clap::value_parser!(u64).range(1..),
        env = "OVERSEER_EXPECTED_BLOCK_TIME"
    )]
    pub expected_block_time: u64,

    /// Allowed delay past the expected block time before considering it a violation, in seconds.
    #[arg(
        long = "allowable-delay",
        default_value = "12",
        env = "OVERSEER_ALLOWABLE_DELAY"
    )]
    pub allowable_delay: u64,

    /// Maximum pending transactions tolerated before triggering mempool stagnation.
    #[arg(
        long = "allowable-mempool-transactions",
        default_value = "0",
        env = "OVERSEER_ALLOWABLE_MEMPOOL_TRANSACTIONS"
    )]
    pub allowable_mempool_transactions: u64,

    /// Frequency (in seconds) to poll the chain state.
    #[arg(
        long = "poll-interval",
        default_value = "10",
        env = "OVERSEER_POLL_INTERVAL"
    )]
    pub poll_interval: u64,

    /// Maximum age in seconds that a pending transaction may remain before flagging.
    #[arg(
        long = "pending-tx-max-age",
        default_value = "60",
        env = "OVERSEER_PENDING_TX_MAX_AGE"
    )]
    pub pending_tx_max_age: u64,

    /// Enables the block timeliness criterion when set to true.
    #[arg(
        long = "enable-block-timeliness",
        default_value_t = true,
        env = "OVERSEER_ENABLE_BLOCK_TIMELINESS"
    )]
    pub enable_block_timeliness: bool,

    /// Enables the mempool stagnation criterion when set to true.
    #[arg(
        long = "enable-mempool-stagnation",
        default_value_t = true,
        env = "OVERSEER_ENABLE_MEMPOOL_STAGNATION"
    )]
    pub enable_mempool_stagnation: bool,

    /// Enables the pending transaction age criterion when set to true.
    #[arg(
        long = "enable-pending-tx-age",
        default_value_t = true,
        env = "OVERSEER_ENABLE_PENDING_TX_AGE"
    )]
    pub enable_pending_tx_age: bool,

    /// Address for the Prometheus metrics HTTP endpoint (e.g. 0.0.0.0:9646).
    #[arg(
        long = "metrics-addr",
        default_value = "0.0.0.0:9646",
        env = "OVERSEER_METRICS_ADDR"
    )]
    pub metrics_addr: SocketAddr,

    /// Chain ID used when signing on-chain transactions.
    #[arg(long = "chain-id", default_value = "1", env = "OVERSEER_CHAIN_ID")]
    pub chain_id: u64,

    /// Hex-encoded private key used to sign blacklist transactions.
    #[arg(long = "private-key", env = "OVERSEER_PRIVATE_KEY")]
    pub private_key: String,

    /// Address of the on-chain blacklist contract.
    #[arg(long = "blacklist-contract", env = "OVERSEER_BLACKLIST_CONTRACT")]
    pub blacklist_contract: String,

    /// Address of the registry contract used for operator indexing.
    #[arg(long = "registry-address", env = "OVERSEER_REGISTRY_ADDRESS")]
    pub registry_address: String,

    /// Optional RPC URL for registry indexing (defaults to `rpc-url`).
    #[arg(long = "registry-rpc-url", env = "OVERSEER_REGISTRY_RPC_URL")]
    pub registry_rpc_url: Option<String>,

    /// Starting block for registry indexing.
    #[arg(
        long = "registry-start-block",
        default_value = "1",
        env = "OVERSEER_REGISTRY_START_BLOCK"
    )]
    pub registry_start_block: u64,

    /// Maximum L1 fork depth tolerated by the registry indexer.
    #[arg(
        long = "registry-max-fork-depth",
        default_value = "2",
        env = "OVERSEER_REGISTRY_MAX_FORK_DEPTH"
    )]
    pub registry_max_fork_depth: u64,

    /// Number of blocks to index per batch when catching up.
    #[arg(
        long = "registry-batch-size",
        default_value = "25",
        env = "OVERSEER_REGISTRY_BATCH_SIZE"
    )]
    pub registry_batch_size: u64,

    /// Optional filesystem path for the registry index database (SQLite fallback).
    #[arg(long = "registry-db-path", env = "OVERSEER_REGISTRY_DB_PATH")]
    pub registry_db_path: Option<String>,

    /// Optional MySQL connection string for the registry database.
    #[arg(long = "registry-db-url", env = "OVERSEER_REGISTRY_DB_URL")]
    pub registry_db_url: Option<String>,

    /// Lookahead store contract address.
    #[arg(
        long = "lookahead-store-address",
        env = "OVERSEER_LOOKAHEAD_STORE_ADDRESS"
    )]
    pub lookahead_store_address: String,

    /// Consensus layer (Beacon) RPC endpoint.
    #[arg(long = "consensus-rpc-url", env = "OVERSEER_CONSENSUS_RPC_URL")]
    pub consensus_rpc_url: String,

    /// Timeout in seconds for consensus layer RPC calls.
    #[arg(
        long = "consensus-rpc-timeout",
        default_value = "10",
        env = "OVERSEER_CONSENSUS_RPC_TIMEOUT"
    )]
    pub consensus_rpc_timeout_secs: u64,

    /// Genesis slot number for the slot clock.
    #[arg(
        long = "lookahead-genesis-slot",
        default_value = "0",
        env = "OVERSEER_LOOKAHEAD_GENESIS_SLOT"
    )]
    pub lookahead_genesis_slot: u64,

    /// Genesis timestamp (seconds) for the slot clock.
    #[arg(
        long = "lookahead-genesis-timestamp",
        env = "OVERSEER_LOOKAHEAD_GENESIS_TIMESTAMP"
    )]
    pub lookahead_genesis_timestamp: u64,

    /// Slot duration in seconds for the slot clock.
    #[arg(
        long = "lookahead-slot-duration",
        default_value = "12",
        env = "OVERSEER_LOOKAHEAD_SLOT_DURATION"
    )]
    pub lookahead_slot_duration: u64,

    /// Number of slots per epoch for the slot clock.
    #[arg(
        long = "lookahead-slots-per-epoch",
        default_value = "32",
        env = "OVERSEER_LOOKAHEAD_SLOTS_PER_EPOCH"
    )]
    pub lookahead_slots_per_epoch: u64,

    /// Heartbeat cadence in milliseconds for preconfirmation.
    #[arg(
        long = "lookahead-heartbeat-ms",
        default_value = "1000",
        env = "OVERSEER_LOOKAHEAD_HEARTBEAT_MS"
    )]
    pub lookahead_heartbeat_ms: u64,

    /// Preconfirmer slasher address used to resolve registration roots.
    #[arg(long = "preconf-slasher", env = "OVERSEER_PRECONF_SLASHER")]
    pub preconf_slasher: String,
}
