//! Command-line argument parsing and configuration
//! 
//! This module defines the CLI interface using clap, supporting both
//! command-line arguments and environment variables.

use clap::Parser;

/// Command-line arguments for the Taiko L1 Event Monitor
/// 
/// Arguments can be provided via command line flags or environment variables.
/// Environment variables take the form of the uppercase argument name
/// (e.g., RPC_URL for --rpc-url).
#[derive(Parser, Debug)]
#[command(name = "preconf-profit-calc")]
#[command(about = "Taiko L1 Event Monitor - Rust Implementation", long_about = None)]
pub struct Args {
    /// Ethereum RPC URL
    /// 
    /// The JSON-RPC endpoint for connecting to Ethereum.
    /// Examples: https://mainnet.infura.io/v3/YOUR-KEY
    #[arg(long, env = "RPC_URL")]
    pub rpc_url: String,

    /// TaikoInbox contract address
    /// 
    /// The address of the TaikoInbox contract on L1.
    /// This is where batch proposals and proofs are submitted.
    #[arg(long, env = "INBOX_ADDRESS")]
    pub inbox_address: String,

    /// Starting block number
    /// 
    /// The block to start monitoring from. If not provided,
    /// the program will prompt for a starting point.
    #[arg(long, env = "START_BLOCK")]
    pub start_block: Option<u64>,

    /// End block number (for historical processing)
    /// 
    /// If specified, the monitor will stop at this block.
    /// If not specified, it will catch up to latest and monitor live.
    #[arg(long)]
    pub end_block: Option<u64>,

    /// Start from latest block
    /// 
    /// Skip historical data and start monitoring from the current block.
    #[arg(long)]
    pub latest: bool,

    /// Find and start from contract deployment block
    /// 
    /// Automatically detect when the TaikoInbox contract was deployed
    /// and start monitoring from that block.
    #[arg(long)]
    pub find_deployment: bool,

    /// Batch size for historical processing
    /// 
    /// Number of blocks to fetch in a single RPC call.
    /// Larger values are faster but may hit RPC limits.
    #[arg(long, default_value = "500")]
    pub batch_size: u64,

    /// Poll interval for live monitoring (in seconds)
    /// 
    /// How often to check for new blocks when in live monitoring mode.
    /// Default is 12 seconds (Ethereum block time).
    #[arg(long, default_value = "12")]
    pub poll_interval: u64,
}