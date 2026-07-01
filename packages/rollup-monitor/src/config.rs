use std::{
    collections::{HashMap, HashSet},
    str::FromStr,
};

use alloy::primitives::{Address, B256};
use clap::Parser;

pub const DEFAULT_HTTP_PORT: u64 = 8080;
pub const DEFAULT_POLL_INTERVAL_SECONDS: u64 = 12;
pub const DEFAULT_CONFIRMATIONS: u64 = 3;
pub const DEFAULT_START_BLOCK_LOOKBACK: u64 = 7200;
pub const DEFAULT_OVERLAP_BLOCKS: u64 = 20;
pub const DEFAULT_MAX_BLOCK_RANGE: u64 = 2000;
pub const DEFAULT_SEEN_LOG_CACHE_SIZE: usize = 10_000;

#[derive(Parser, Debug, Clone)]
#[command(name = "rollup-monitor", version)]
pub struct Config {
    #[arg(long, env = "L1_HTTP_URL")]
    pub l1_http_url: String,

    #[arg(long, env = "L2_HTTP_URL")]
    pub l2_http_url: Option<String>,

    #[arg(long, env = "HTTP_PORT", default_value_t = DEFAULT_HTTP_PORT)]
    pub http_port: u64,

    #[arg(
        long,
        env = "POLL_INTERVAL_SECONDS",
        default_value_t = DEFAULT_POLL_INTERVAL_SECONDS
    )]
    pub poll_interval_seconds: u64,

    #[arg(long, env = "CONFIRMATIONS", default_value_t = DEFAULT_CONFIRMATIONS)]
    pub confirmations: u64,

    #[arg(long, env = "START_BLOCK")]
    pub start_block: Option<u64>,

    #[arg(
        long,
        env = "START_BLOCK_LOOKBACK",
        default_value_t = DEFAULT_START_BLOCK_LOOKBACK
    )]
    pub start_block_lookback: u64,

    #[arg(long, env = "OVERLAP_BLOCKS", default_value_t = DEFAULT_OVERLAP_BLOCKS)]
    pub overlap_blocks: u64,

    #[arg(long, env = "MAX_BLOCK_RANGE", default_value_t = DEFAULT_MAX_BLOCK_RANGE)]
    pub max_block_range: u64,

    #[arg(
        long,
        env = "SEEN_LOG_CACHE_SIZE",
        default_value_t = DEFAULT_SEEN_LOG_CACHE_SIZE
    )]
    pub seen_log_cache_size: usize,

    #[arg(
        long,
        env = "WATCHED_CONTRACTS",
        default_value = "",
        value_parser = parse_named_addresses
    )]
    pub watched_contracts: HashMap<String, Address>,

    #[arg(
        long,
        env = "ALLOWED_PROVERS",
        default_value = "",
        value_parser = parse_address_set
    )]
    pub allowed_provers: HashSet<Address>,

    #[arg(
        long,
        env = "ALLOWED_PROPOSERS",
        default_value = "",
        value_parser = parse_address_set
    )]
    pub allowed_proposers: HashSet<Address>,

    #[arg(
        long,
        env = "WATCHED_EOAS",
        default_value = "",
        value_parser = parse_address_set
    )]
    pub watched_eoas: HashSet<Address>,

    #[arg(
        long,
        env = "ALLOWED_EOA_DESTINATIONS",
        default_value = "",
        value_parser = parse_address_set
    )]
    pub allowed_eoa_destinations: HashSet<Address>,

    #[arg(
        long,
        env = "EXPECTED_PROXY_IMPLEMENTATIONS",
        default_value = "",
        value_parser = parse_named_addresses
    )]
    pub expected_proxy_implementations: HashMap<String, Address>,

    #[arg(
        long,
        env = "EXPECTED_OWNERS",
        default_value = "",
        value_parser = parse_named_addresses
    )]
    pub expected_owners: HashMap<String, Address>,

    #[arg(
        long,
        env = "EXPECTED_VERIFIERS",
        default_value = "",
        value_parser = parse_named_b256_sets
    )]
    pub expected_verifiers: HashMap<String, HashSet<B256>>,

    #[arg(
        long,
        env = "WITHDRAWAL_THRESHOLDS_WEI",
        default_value = "",
        value_parser = parse_named_u128s
    )]
    pub withdrawal_thresholds_wei: HashMap<String, u128>,
}

fn parse_named_addresses(value: &str) -> Result<HashMap<String, Address>, String> {
    let mut parsed = HashMap::new();

    for item in split_csv(value) {
        let (name, address) = item
            .split_once('=')
            .ok_or_else(|| format!("expected name=address pair, got '{item}'"))?;
        let name = normalize_name(name)?;
        let address = Address::from_str(address.trim())
            .map_err(|error| format!("invalid address for '{name}': {error}"))?;
        parsed.insert(name, address);
    }

    Ok(parsed)
}

fn parse_address_set(value: &str) -> Result<HashSet<Address>, String> {
    let mut parsed = HashSet::new();

    for item in split_csv(value) {
        let address = Address::from_str(item)
            .map_err(|error| format!("invalid address '{item}': {error}"))?;
        parsed.insert(address);
    }

    Ok(parsed)
}

fn parse_named_u128s(value: &str) -> Result<HashMap<String, u128>, String> {
    let mut parsed = HashMap::new();

    for item in split_csv(value) {
        let (name, raw_amount) = item
            .split_once('=')
            .ok_or_else(|| format!("expected name=value pair, got '{item}'"))?;
        let name = normalize_name(name)?;
        let amount = raw_amount
            .trim()
            .parse::<u128>()
            .map_err(|error| format!("invalid integer for '{name}': {error}"))?;
        parsed.insert(name, amount);
    }

    Ok(parsed)
}

fn parse_named_b256_sets(value: &str) -> Result<HashMap<String, HashSet<B256>>, String> {
    let mut parsed: HashMap<String, HashSet<B256>> = HashMap::new();

    for item in split_csv(value) {
        let (name, raw_hash) = item
            .split_once('=')
            .ok_or_else(|| format!("expected name=value pair, got '{item}'"))?;
        let name = normalize_name(name)?;
        let hash = B256::from_str(raw_hash.trim())
            .map_err(|error| format!("invalid bytes32 for '{name}': {error}"))?;
        parsed.entry(name).or_default().insert(hash);
    }

    Ok(parsed)
}

fn split_csv(value: &str) -> impl Iterator<Item = &str> {
    value.split(',').map(str::trim).filter(|item| !item.is_empty())
}

fn normalize_name(name: &str) -> Result<String, String> {
    let name = name.trim();
    if name.is_empty() {
        return Err("name cannot be empty".to_string());
    }

    Ok(name.to_string())
}

#[cfg(test)]
mod tests {
    use std::str::FromStr;

    use alloy::primitives::{Address, B256};
    use clap::Parser;

    use super::Config;

    fn addr(value: &str) -> Address {
        Address::from_str(value).expect("test address should parse")
    }

    #[test]
    fn parses_defaults() {
        let config =
            Config::parse_from(["rollup-monitor", "--l1-http-url", "http://localhost:8545"]);

        assert_eq!(config.l1_http_url, "http://localhost:8545");
        assert_eq!(config.l2_http_url, None);
        assert_eq!(config.http_port, 8080);
        assert_eq!(config.poll_interval_seconds, 12);
        assert_eq!(config.confirmations, 3);
        assert_eq!(config.start_block, None);
        assert_eq!(config.start_block_lookback, 7200);
        assert_eq!(config.overlap_blocks, 20);
        assert_eq!(config.max_block_range, 2000);
        assert_eq!(config.seen_log_cache_size, 10000);
        assert!(config.watched_contracts.is_empty());
        assert!(config.allowed_provers.is_empty());
        assert!(config.allowed_proposers.is_empty());
        assert!(config.watched_eoas.is_empty());
        assert!(config.allowed_eoa_destinations.is_empty());
        assert!(config.expected_proxy_implementations.is_empty());
        assert!(config.expected_owners.is_empty());
        assert!(config.expected_verifiers.is_empty());
        assert!(config.withdrawal_thresholds_wei.is_empty());
    }

    #[test]
    fn parses_watchlists_and_thresholds() {
        let config = Config::parse_from([
            "rollup-monitor",
            "--l1-http-url",
            "https://l1.example",
            "--l2-http-url",
            "https://l2.example",
            "--http-port",
            "9090",
            "--poll-interval-seconds",
            "6",
            "--confirmations",
            "5",
            "--start-block",
            "123",
            "--start-block-lookback",
            "456",
            "--overlap-blocks",
            "7",
            "--max-block-range",
            "89",
            "--seen-log-cache-size",
            "321",
            "--watched-contracts",
            "inbox=0x0000000000000000000000000000000000000001,bridge=0x0000000000000000000000000000000000000002",
            "--allowed-provers",
            "0x0000000000000000000000000000000000000003,0x0000000000000000000000000000000000000004",
            "--allowed-proposers",
            "0x0000000000000000000000000000000000000005",
            "--watched-eoas",
            "0x0000000000000000000000000000000000000006",
            "--allowed-eoa-destinations",
            "0x0000000000000000000000000000000000000007",
            "--expected-proxy-implementations",
            "inbox=0x0000000000000000000000000000000000000008",
            "--expected-owners",
            "proxy_admin=0x0000000000000000000000000000000000000009",
            "--expected-verifiers",
            "risc0_verifier=0x1010101010101010101010101010101010101010101010101010101010101010,sp1_verifier=0x2020202020202020202020202020202020202020202020202020202020202020",
            "--withdrawal-thresholds-wei",
            "bridge=1000,erc20_vault=2000",
        ]);

        assert_eq!(config.l2_http_url.as_deref(), Some("https://l2.example"));
        assert_eq!(config.http_port, 9090);
        assert_eq!(config.poll_interval_seconds, 6);
        assert_eq!(config.confirmations, 5);
        assert_eq!(config.start_block, Some(123));
        assert_eq!(config.start_block_lookback, 456);
        assert_eq!(config.overlap_blocks, 7);
        assert_eq!(config.max_block_range, 89);
        assert_eq!(config.seen_log_cache_size, 321);
        assert_eq!(
            config.watched_contracts.get("inbox"),
            Some(&addr("0x0000000000000000000000000000000000000001"))
        );
        assert_eq!(
            config.watched_contracts.get("bridge"),
            Some(&addr("0x0000000000000000000000000000000000000002"))
        );
        assert!(
            config.allowed_provers.contains(&addr("0x0000000000000000000000000000000000000003"))
        );
        assert!(
            config.allowed_provers.contains(&addr("0x0000000000000000000000000000000000000004"))
        );
        assert!(
            config.allowed_proposers.contains(&addr("0x0000000000000000000000000000000000000005"))
        );
        assert!(config.watched_eoas.contains(&addr("0x0000000000000000000000000000000000000006")));
        assert!(
            config
                .allowed_eoa_destinations
                .contains(&addr("0x0000000000000000000000000000000000000007"))
        );
        assert_eq!(
            config.expected_proxy_implementations.get("inbox"),
            Some(&addr("0x0000000000000000000000000000000000000008"))
        );
        assert_eq!(
            config.expected_owners.get("proxy_admin"),
            Some(&addr("0x0000000000000000000000000000000000000009"))
        );
        assert!(
            config
                .expected_verifiers
                .get("risc0_verifier")
                .is_some_and(|hashes| hashes.contains(&B256::repeat_byte(0x10)))
        );
        assert!(
            config
                .expected_verifiers
                .get("sp1_verifier")
                .is_some_and(|hashes| hashes.contains(&B256::repeat_byte(0x20)))
        );
        assert_eq!(config.withdrawal_thresholds_wei.get("bridge"), Some(&1000));
        assert_eq!(config.withdrawal_thresholds_wei.get("erc20_vault"), Some(&2000));
    }
}
