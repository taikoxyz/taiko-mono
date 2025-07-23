//! Taiko L1 Event Monitor - Main entry point
//! 
//! This application monitors Taiko L1 events to track costs associated with
//! batch proposals and proofs. It provides real-time and historical analysis
//! of L1 gas costs for Taiko operators.

use anyhow::Result;
use clap::Parser;
use dotenv::dotenv;
use tracing_subscriber;

use preconf_profit_calc::{
    config::Args,
    monitor::EventMonitor,
};

#[tokio::main]
async fn main() -> Result<()> {
    // Load environment variables from .env file if present
    dotenv().ok();
    
    // Initialize logging/tracing with environment-based filter
    // Set LOG_LEVEL env var or use default info level
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("preconf_profit_calc=info".parse()?)
        )
        .init();
    
    // Parse command line arguments (also reads from env vars)
    let args = Args::parse();
    
    // Display welcome banner
    println!("=== Taiko L1 Event Monitor (Rust Implementation) ===");
    println!("High-performance event monitoring with batch processing\n");
    
    // Initialize the event monitor with RPC connection
    let mut monitor = EventMonitor::new(&args.rpc_url, &args.inbox_address).await?;
    
    // Determine starting block based on command line arguments
    let start_block = if args.find_deployment {
        // Option 1: Find deployment block automatically
        monitor.find_contract_deployment_block().await?.unwrap_or(19_773_965)
    } else if args.latest {
        // Option 2: Start from latest block
        use preconf_profit_calc::rpc::RpcClient;
        let client = RpcClient::new(&args.rpc_url)?;
        client.eth_block_number().await?
    } else if let Some(block) = args.start_block {
        // Option 3: Use explicitly provided start block
        block
    } else {
        // Option 4: Interactive mode - let user choose
        use preconf_profit_calc::rpc::RpcClient;
        let client = RpcClient::new(&args.rpc_url)?;
        let current = client.eth_block_number().await?;
        
        println!("Current block: {}", current);
        println!("Options:");
        println!("1. Start from current block");
        println!("2. Start from specific block");
        println!("3. Find and start from contract deployment");
        
        print!("\nYour choice (1-3): ");
        use std::io::{self, Write};
        io::stdout().flush()?;
        
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        
        match input.trim() {
            "2" => {
                // Get specific block number from user
                print!("Enter starting block number: ");
                io::stdout().flush()?;
                input.clear();
                io::stdin().read_line(&mut input)?;
                input.trim().parse::<u64>()?
            }
            "3" => {
                // Find deployment block
                monitor.find_contract_deployment_block().await?.unwrap_or(current)
            }
            _ => current, // Default to current block
        }
    };
    
    // Start monitoring with the determined parameters
    monitor.monitor_blocks_batch(start_block, args.end_block, args.batch_size, args.poll_interval).await?;
    
    Ok(())
}