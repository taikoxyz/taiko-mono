use std::{str::FromStr, time::Duration};

use alloy_primitives::Address;
use clap::{Parser, ValueEnum};
use url::Url;

/// Runtime configuration parsed from CLI flags and environment variables.
#[derive(Clone, Debug, Parser)]
#[command(
    name = "blobindexer",
    author,
    version,
    about = "Taiko blob sidecar indexer"
)]
pub struct Config {
    /// Beacon node REST API endpoint (e.g. https://beacon.taiko:5052)
    #[arg(long, env = "BLOB_INDEXER_BEACON_URL")]
    pub beacon_api: Url,

    /// MySQL database connection string (e.g. mysql://user:pass@host:3306/blobindexer)
    #[arg(long, env = "BLOB_INDEXER_DATABASE_URL")]
    pub database_url: String,

    /// HTTP bind address for the public API
    #[arg(long, env = "BLOB_INDEXER_HTTP_BIND", default_value = "0.0.0.0:9000")]
    pub http_bind: std::net::SocketAddr,

    /// Polling interval for checking beacon head updates
    #[arg(long, env = "BLOB_INDEXER_POLL_INTERVAL", default_value = "6s", value_parser = parse_duration)]
    pub poll_interval: Duration,

    /// Request timeout for beacon API calls
    #[arg(long, env = "BLOB_INDEXER_HTTP_TIMEOUT", default_value = "20s", value_parser = parse_duration)]
    pub http_timeout: Duration,

    /// Maximum number of concurrent block/blob fetches
    #[arg(long, env = "BLOB_INDEXER_MAX_CONCURRENCY", default_value_t = 4)]
    pub max_concurrency: usize,

    /// Maximum number of slots to backfill per iteration when catching up
    #[arg(long, env = "BLOB_INDEXER_BACKFILL_BATCH", default_value_t = 32)]
    pub backfill_batch: u64,

    /// Optional starting slot override (useful for initial bootstrapping)
    #[arg(long, env = "BLOB_INDEXER_START_SLOT")]
    pub start_slot: Option<u64>,

    /// Number of slots to keep around canonical head when handling reorgs
    #[arg(long, env = "BLOB_INDEXER_REORG_LOOKBACK", default_value_t = 128)]
    pub reorg_lookback: u64,

    /// Number of confirmations required before considering data final
    #[arg(
        long,
        env = "BLOB_INDEXER_FINALITY_CONFIRMATIONS",
        default_value_t = 64
    )]
    pub finality_confirmations: u64,

    /// Log output format
    #[arg(long, env = "BLOB_INDEXER_LOG_FORMAT", value_enum, default_value_t = LogFormat::Pretty)]
    pub log_format: LogFormat,

    /// Contract addresses to filter blob transactions (0x-prefixed, comma separated when using env var)
    #[arg(
        long = "watch-address",
        env = "BLOB_INDEXER_WATCH_ADDRESSES",
        value_delimiter = ',',
        value_parser = parse_address,
    )]
    pub watch_addresses: Vec<Address>,
}

/// Supported tracing output formats
#[derive(Clone, Copy, Debug, Default, ValueEnum)]
pub enum LogFormat {
    #[default]
    Pretty,
    Json,
}

fn parse_duration(value: &str) -> Result<Duration, String> {
    humantime::parse_duration(value).map_err(|err| format!("invalid duration '{value}': {err}"))
}

fn parse_address(value: &str) -> Result<Address, String> {
    Address::from_str(value).map_err(|err| format!("invalid address '{value}': {err}"))
}
