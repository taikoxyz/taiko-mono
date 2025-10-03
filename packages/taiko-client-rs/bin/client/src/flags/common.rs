use std::path::PathBuf;

use alloy_primitives::Address;
use clap::Parser;
use url::Url;

#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct CommonArgs {
    #[clap(
        long = "l1.ws",
        env = "L1_WS",
        required = true,
        help = "Websocket RPC endpoint of a L1 ethereum node"
    )]
    pub l1_ws_endpoint: Url,
    #[clap(
        long = "l2.http",
        env = "L2_HTTP",
        required = true,
        help = "HTTP RPC endpoint of a L2 taiko execution engine"
    )]
    pub l2_http_endpoint: Url,
    #[clap(
        long = "l2.auth",
        env = "L2_AUTH",
        required = true,
        help = "Authenticated HTTP RPC endpoint of a L2 taiko-geth execution engine"
    )]
    pub l2_auth_endpoint: Url,
    #[clap(
        long = "jwtSecret",
        env = "JWT_SECRET",
        required = true,
        help = "Path to a JWT secret to use for authenticated RPC endpoints"
    )]
    pub l2_auth_jwt_secret: PathBuf,
    #[clap(
        long = "shastaInbox",
        env = "SHASTA_INBOX",
        required = true,
        help = "Taiko Inbox contract address"
    )]
    pub shasta_inbox_address: Address,
}
