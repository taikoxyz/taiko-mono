use clap::Parser;

pub const DEFAULT_REORG_HISTORY_DEPTH: usize = 768;

#[derive(Parser, Debug, Clone)]
#[command(name = "reorg-monitor", version)]
pub struct Config {
    // L2 RPC websocket URL used to subscribe to block headers.
    #[arg(long, env = "L2_WS_URL", default_value = "ws://localhost:8546")]
    pub l2_ws_url: String,

    // HTTP server port for health and metrics.
    #[arg(long, env = "HTTP_PORT", default_value_t = 8080u64)]
    pub http_port: u64,

    // Optional L1 RPC HTTP URL used to fetch current preconf operator from whitelist.
    #[arg(long, env = "L1_HTTP_URL")]
    pub l1_http_url: Option<String>,

    // Optional preconf whitelist contract address on L1.
    #[arg(long, env = "PRECONF_WHITELIST_ADDRESS")]
    pub preconf_whitelist_address: Option<String>,

    // Number of recent blocks to keep in memory for reorg detection.
    #[arg(
        long,
        env = "REORG_HISTORY_DEPTH",
        default_value_t = DEFAULT_REORG_HISTORY_DEPTH
    )]
    pub reorg_history_depth: usize,
}

#[cfg(test)]
mod tests {
    use clap::Parser;

    use super::Config;
    use crate::config::DEFAULT_REORG_HISTORY_DEPTH;

    #[test]
    fn test_config_parsing() {
        let config = Config::parse_from([
            "reorg-monitor",
            "--l2-ws-url",
            "ws://example.com:8546",
            "--http-port",
            "9090",
            "--l1-http-url",
            "https://l1.example.com",
            "--preconf-whitelist-address",
            "0x0000008f5dd9a790ffbe9142e6828a11c2cf51c0",
            "--reorg-history-depth",
            "1024",
        ]);

        assert_eq!(config.l2_ws_url, "ws://example.com:8546");
        assert_eq!(config.http_port, 9090);
        assert_eq!(config.l1_http_url.as_deref(), Some("https://l1.example.com"));
        assert_eq!(
            config.preconf_whitelist_address.as_deref(),
            Some("0x0000008f5dd9a790ffbe9142e6828a11c2cf51c0")
        );
        assert_eq!(config.reorg_history_depth, 1024);
    }

    #[test]
    fn test_config_defaults() {
        let config = Config::parse_from(["reorg-monitor"]);

        assert_eq!(config.l2_ws_url, "ws://localhost:8546");
        assert_eq!(config.http_port, 8080);
        assert!(config.l1_http_url.is_none());
        assert!(config.preconf_whitelist_address.is_none());
        assert_eq!(config.reorg_history_depth, DEFAULT_REORG_HISTORY_DEPTH);
    }
}
