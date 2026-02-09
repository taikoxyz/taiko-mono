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

    use crate::config::DEFAULT_REORG_HISTORY_DEPTH;

    use super::Config;

    #[test]
    fn test_config_parsing() {
        let config = Config::parse_from([
            "reorg-monitor",
            "--l2-ws-url",
            "ws://example.com:8546",
            "--http-port",
            "9090",
            "--reorg-history-depth",
            "1024",
        ]);

        assert_eq!(config.l2_ws_url, "ws://example.com:8546");
        assert_eq!(config.http_port, 9090);
        assert_eq!(config.reorg_history_depth, 1024);
    }

    #[test]
    fn test_config_defaults() {
        let config = Config::parse_from(["reorg-monitor"]);

        assert_eq!(config.l2_ws_url, "ws://localhost:8546");
        assert_eq!(config.http_port, 8080);
        assert_eq!(config.reorg_history_depth, DEFAULT_REORG_HISTORY_DEPTH);
    }
}
