use clap::Parser;

#[derive(Parser, Debug, Clone)]
#[command(name = "ejector", version)]
pub struct Config {
    // Address of preconfWhitelist
    #[arg(long, env = "PRECONF_WHITELIST_ADDRESS")]
    pub preconf_whitelist_address: String,

    // L1 RPC http url
    #[arg(long, env = "L1_HTTP_URL", default_value = "http://localhost:8545")]
    pub l1_http_url: String,

    // L2 WS url
    #[arg(long, env = "L2_WS_URL", default_value = "ws://localhost:8546")]
    pub l2_ws_url: String,

    // L2 HTTP url
    #[arg(long, env = "L2_HTTP_URL", default_value = "http://localhost:8547")]
    pub l2_http_url: String,

    // targe block time in seconds
    #[arg(long, env = "L2_TARGET_BLOCK_TIME_SECONDS", default_value_t = 2u64)]
    pub l2_target_block_time: u64,

    #[arg(long, env = "EJECT_AFTER_N_SLOTS_MISSED", default_value_t = 4u64)]
    pub eject_after_n_slots_missed: u64,

    // private key for sending L1 txs, must be set as an ejector on the preconf whitelist contract
    #[arg(long, env = "PRIVATE_KEY")]
    pub private_key: String,

    // address of the taiko wrapper contract
    #[arg(long, env = "TAIKO_WRAPPER_ADDRESS")]
    pub taiko_wrapper_address: String,

    // beacon client base URL
    #[arg(long, env = "BEACON_URL", default_value = "http://localhost:5052")]
    pub beacon_url: String,

    // handover slots
    #[arg(long, env = "HANDOVER_SLOTS", default_value_t = 4)]
    pub handover_slots: u64,

    // server port
    #[arg(long, env = "SERVER_PORT", default_value_t = 8080u64)]
    pub server_port: u64,

    // minimum number of operators to keep in the whitelist
    #[arg(long, env = "MIN_OPERATORS", default_value_t = 3u64)]
    pub min_operators: u64,

    // Address of preconfRouter
    #[arg(long, env = "PRECONF_ROUTER_ADDRESS")]
    pub preconf_router_address: String,
}

// tests
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_config_parsing() {
        let config = Config::parse_from([
            "ejector",
            "--preconf-whitelist-address",
            "0x1123",
            "--preconf-router-address",
            "0x789",
            "--l1-http-url",
            "http://test-l1-rpc.com",
            "--l2-ws-url",
            "ws://test-l2.com",
            "--l2-http-url",
            "http://test-l2.com",
            "--l2-target-block-time",
            "3",
            "--eject-after-n-slots-missed",
            "10",
            "--private-key",
            "0x1234",
            "--taiko-wrapper-address",
            "0x456",
            "--beacon-url",
            "http://test-beacon.com",
            "--handover-slots",
            "4",
            "--server-port",
            "8081",
            "--min-operators",
            "1",
        ]);

        assert_eq!(config.preconf_whitelist_address, "0x1123");
        assert_eq!(config.preconf_router_address, "0x789");
        assert_eq!(config.l1_http_url, "http://test-l1-rpc.com");
        assert_eq!(config.l2_ws_url, "ws://test-l2.com");
        assert_eq!(config.l2_target_block_time, 3);
        assert_eq!(config.eject_after_n_slots_missed, 10);
        assert_eq!(config.l2_http_url, "http://test-l2.com");
        assert_eq!(config.private_key, "0x1234");
        assert_eq!(config.taiko_wrapper_address, "0x456");
        assert_eq!(config.beacon_url, "http://test-beacon.com");
        assert_eq!(config.handover_slots, 4);
        assert_eq!(config.server_port, 8081);
        assert_eq!(config.min_operators, 1);
    }
}
