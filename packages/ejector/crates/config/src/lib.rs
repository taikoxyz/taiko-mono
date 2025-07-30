use clap::Parser;


#[derive(Parser, Debug, Clone)]
#[command(name = "ejector", version)]
pub struct Config {
    // Address of preconfWhitelist
    #[arg(long, env = "PRECONF_WHITELIST_ADDRESS")]
    pub preconf_whitelist_address: String,

    // L1 RPC http url
    #[arg(long, env = "L1_RPC_URL", default_value = "http://localhost:8545")]
    pub l1_rpc_url: String,

    // L2 WS url
    #[arg(long, env = "L2_WS_URL", default_value = "ws://localhost:8546")]
    pub l2_ws_url: String,

    // targe block time in seconds
    #[arg(long, env = "L2_TARGET_BLOCK_TIME_SECONDS", default_value_t = 2u64)]
    pub l2_target_block_time: u64,

    #[arg(long, env = "EJECT_AFTER_N_SLOTS_MISSED", default_value_t = 20u64)]
    pub eject_after_n_slots_missed: u64,
}


// tests 
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_config_parsing() {
        let config = Config::parse_from([
            "ejector",
            "--preconf-whitelist-address", "0x1123",
            "--l1-rpc-url", "http://test-l1-rpc.com",
            "--l2-ws-url", "ws://test-l2.com",
            "--l2-target-block-time", "3",
            "--eject-after-n-slots-missed", "10"
        ]);

        assert_eq!(config.preconf_whitelist_address, "0x1123");
        assert_eq!(config.l1_rpc_url, "http://test-l1-rpc.com");
        assert_eq!(config.l2_ws_url, "ws://test-l2.com");
        assert_eq!(config.l2_target_block_time, 3);
        assert_eq!(config.eject_after_n_slots_missed, 10);
    }
}
