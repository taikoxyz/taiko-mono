//! Common CLI flags shared across commands.

use std::path::PathBuf;

use alloy_primitives::Address;
use clap::Parser;
use tracing::Level;
use url::Url;

#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct CommonArgs {
    /// Websocket RPC endpoint of a L1 ethereum node.
    #[clap(
        long = "l1.ws",
        env = "L1_WS",
        required = true,
        help = "Websocket RPC endpoint of a L1 ethereum node"
    )]
    pub l1_ws_endpoint: Url,
    /// HTTP RPC endpoint of a L2 taiko execution engine.
    #[clap(
        long = "l2.http",
        env = "L2_HTTP",
        required = true,
        help = "HTTP RPC endpoint of a L2 taiko execution engine"
    )]
    pub l2_http_endpoint: Url,
    /// Authenticated HTTP RPC endpoint of a L2 taiko execution engine.
    #[clap(
        long = "l2.auth",
        env = "L2_AUTH",
        required = true,
        help = "Authenticated HTTP RPC endpoint of a L2 taiko-geth execution engine"
    )]
    pub l2_auth_endpoint: Url,
    /// Path to a JWT secret to use for authenticated RPC endpoints.
    #[clap(
        long = "jwt.secret",
        env = "JWT_SECRET",
        required = true,
        help = "Path to a JWT secret to use for authenticated RPC endpoints"
    )]
    pub l2_auth_jwt_secret: PathBuf,
    /// Taiko Shasta protocol Inbox contract address.
    #[clap(
        long = "shasta.inbox",
        env = "SHASTA_INBOX",
        required = true,
        help = "Taiko Shasta protocol Inbox contract address"
    )]
    pub shasta_inbox_address: Address,
    /// Verbosity level for logging.
    #[clap(
        short = 'v',
        long = "verbosity",
        env = "VERBOSITY",
        default_value = "2",
        help = "Set the minimum log level. 0 = error, 1 = warn, 2 = info, 3 = debug, 4 = trace"
    )]
    pub verbosity: u8,
    /// Enable Prometheus metrics server.
    #[clap(
        long = "metrics.enabled",
        env = "METRICS_ENABLED",
        default_value = "false",
        help = "Enable Prometheus metrics server"
    )]
    pub metrics_enabled: bool,
    /// Port for Prometheus metrics server.
    #[clap(
        long = "metrics.port",
        env = "METRICS_PORT",
        default_value = "9090",
        help = "Port for Prometheus metrics server"
    )]
    pub metrics_port: u16,
    /// Address to bind Prometheus metrics server.
    #[clap(
        long = "metrics.addr",
        env = "METRICS_ADDR",
        default_value = "0.0.0.0",
        help = "Address to bind Prometheus metrics server"
    )]
    pub metrics_addr: String,
}

impl CommonArgs {
    /// Convert verbosity level to tracing::Level
    pub fn log_level(&self) -> Level {
        match self.verbosity {
            0 => Level::ERROR,
            1 => Level::WARN,
            2 => Level::INFO,
            3 => Level::DEBUG,
            _ => Level::TRACE,
        }
    }
}
