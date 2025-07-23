use anyhow::Result;
use chrono::{DateTime, Utc};
use std::time::Duration;
use tracing::{error, info, warn};

use crate::decoder::{
    decode_batch_proposed,
};
use crate::events::{
    get_event_name, BATCH_PROPOSED_SIGNATURE,
};
use crate::cost::{EventData, CostCalculator};
use crate::rpc::RpcClient;
use crate::types::Event;

/// Main event monitoring struct that tracks Taiko L1 events and calculates costs
pub struct EventMonitor {
    /// RPC client for interacting with Ethereum
    client: RpcClient,
    /// TaikoInbox contract address (lowercase)
    inbox_address: String,
    /// Calculator for tracking L1 gas costs
    cost_calculator: CostCalculator,
}

impl EventMonitor {
    /// Creates a new EventMonitor instance
    /// 
    /// # Arguments
    /// * `rpc_url` - Ethereum RPC endpoint URL
    /// * `inbox_address` - TaikoInbox contract address
    /// 
    /// # Returns
    /// * `Result<Self>` - The EventMonitor instance or an error
    pub async fn new(rpc_url: &str, inbox_address: &str) -> Result<Self> {
        let client = RpcClient::new(rpc_url)?;
        let inbox_address = inbox_address.to_lowercase();
        
        // Verify connection and log initial information
        let client_version = client.eth_client_version().await?;
        let current_block = client.eth_block_number().await?;
        
        info!("Connected to Ethereum node: {}", client_version);
        info!("Monitoring TaikoInbox at: {}", inbox_address);
        info!("Current block: {}", current_block);
        info!("{}", "-".repeat(80));
        
        Ok(Self {
            client,
            inbox_address,
            cost_calculator: CostCalculator::new(),
        })
    }

    /// Finds the block where the TaikoInbox contract was deployed using binary search
    /// 
    /// This function performs a binary search between a reasonable starting block
    /// (19M for mainnet, as Taiko launched in May 2024) and the current block
    /// to find when the contract code first appeared on-chain.
    /// 
    /// # Returns
    /// * `Result<Option<u64>>` - The deployment block number if found, None otherwise
    pub async fn find_contract_deployment_block(&self) -> Result<Option<u64>> {
        info!("Searching for TaikoInbox deployment block...");
        
        // Taiko launched on mainnet in May 2024, so we start from block 19M
        let mut left = 19_000_000u64;
        let mut right = self.client.eth_block_number().await?;
        let mut deployment_block = None;
        
        // Binary search for the deployment block
        while left <= right {
            let mid = (left + right) / 2;
            
            match self.client.eth_get_code(&self.inbox_address, mid).await {
                Ok(code) => {
                    if code.len() > 4 { // More than just "0x" means contract exists
                        deployment_block = Some(mid);
                        right = mid - 1; // Search earlier blocks
                        info!("  Contract found at block {}, searching earlier...", mid);
                    } else {
                        left = mid + 1; // Search later blocks
                        info!("  No contract at block {}, searching later...", mid);
                    }
                }
                Err(e) => {
                    warn!("  Error checking block {}: {}", mid, e);
                    left = mid + 1; // Skip this block and continue
                }
            }
        }
        
        // If deployment block found, fetch and display its timestamp
        if let Some(block) = deployment_block {
            info!("✓ TaikoInbox deployed at block {}", block);
            
            // Get deployment timestamp for user reference
            if let Ok(block_data) = self.client.eth_get_block(block).await {
                if let Some(timestamp_hex) = block_data.timestamp {
                    let timestamp = u64::from_str_radix(&timestamp_hex[2..], 16).unwrap_or(0);
                    let dt = DateTime::<Utc>::from_timestamp(timestamp as i64, 0).unwrap_or_default();
                    info!("  Deployment timestamp: {}", dt.format("%Y-%m-%d %H:%M:%S"));
                }
            }
        }
        
        Ok(deployment_block)
    }

    /// Fetches and processes events from a block range
    /// 
    /// This function retrieves logs from the specified block range, filters for
    /// known Taiko events, and enriches them with block timestamps. It uses a
    /// caching mechanism to avoid fetching the same block data multiple times.
    /// 
    /// # Arguments
    /// * `start_block` - Starting block number (inclusive)
    /// * `end_block` - Ending block number (inclusive)
    /// 
    /// # Returns
    /// * `Result<Vec<Event>>` - Vector of processed events with timestamps
    pub async fn get_events_in_blocks(&self, start_block: u64, end_block: u64) -> Result<Vec<Event>> {
        // Fetch all logs from the TaikoInbox contract in the specified range
        let logs = self.client.eth_get_logs(&self.inbox_address, start_block, end_block).await?;
        let mut events = Vec::new();
        
        // Cache for block timestamps to minimize RPC calls
        let mut block_timestamps = std::collections::HashMap::new();
        
        for log in logs {
            if let Some(topic0) = log.topics.first() {
                // Only process events we recognize (BatchProposed, BatchesProved, etc.)
                if let Some(event_name) = get_event_name(topic0) {
                    // Parse block number from hex string
                    let block_number = if let Some(bn) = &log.block_number {
                        u64::from_str_radix(&bn[2..], 16).unwrap_or(0)
                    } else {
                        0
                    };
                    
                    // Get block timestamp with caching to reduce RPC calls
                    let timestamp = if block_number > 0 {
                        if let Some(&ts) = block_timestamps.get(&block_number) {
                            ts
                        } else {
                            // Fetch block data if not cached
                            let ts = match self.client.eth_get_block(block_number).await {
                                Ok(block) => {
                                    if let Some(ts_hex) = block.timestamp {
                                        u64::from_str_radix(&ts_hex[2..], 16).unwrap_or(0)
                                    } else {
                                        0
                                    }
                                }
                                Err(_) => 0 // Default to 0 on error
                            };
                            block_timestamps.insert(block_number, ts);
                            ts
                        }
                    } else {
                        0
                    };
                    
                    // Create event with all necessary data
                    events.push(Event {
                        name: event_name.to_string(),
                        block_number,
                        transaction_hash: log.transaction_hash.unwrap_or_default(),
                        log_index: log.log_index.unwrap_or_default(),
                        topics: log.topics.clone(),
                        data: log.data.clone(),
                        timestamp,
                    });
                }
            }
        }
        
        Ok(events)
    }

    /// Prints event details and updates the cost calculator
    /// 
    /// This function displays human-readable event information and attempts to
    /// decode event-specific data. Successfully decoded events are tracked in
    /// the cost calculator for later analysis.
    /// 
    /// # Arguments
    /// * `event` - The event to print and process
    pub fn print_event(&mut self, event: &Event) {
        // Temporarily show all events for debugging
        // if event.name != "BatchProposed" {
        //     return;
        // }
        
        // Format timestamp for display
        let timestamp = DateTime::<Utc>::from_timestamp(event.timestamp as i64, 0)
            .unwrap_or_default();
        
        // Print basic event information
        println!("\n[{}] {} Event", timestamp.format("%Y-%m-%d %H:%M:%S"), event.name);
        println!("  Block: {}", event.block_number);
        println!("  Transaction: {}", event.transaction_hash);
        println!("  Log Index: {}", event.log_index);
        
        // Decode and display event-specific data based on event signature
        match event.topics.first().map(|s| s.as_str()) {
            Some(BATCH_PROPOSED_SIGNATURE) => {
                match decode_batch_proposed(&event.data, &event.topics, event.timestamp) {
                    Ok(decoded) => {
                        println!("  Decoded Data:");
                        println!("    Batch ID: {}", decoded.meta.batch_id);
                        println!("    Number of Blocks: {}", decoded.info.num_blocks);
                        println!("    Proposer: {:?}", decoded.meta.proposer);
                        println!("    Proposed At: {}", decoded.meta.proposed_at);
                        
                        // Track in cost calculator
                        let _ = self.cost_calculator.process_event(event, &EventData::BatchProposed(decoded));
                    }
                    Err(e) => {
                        warn!("    Failed to decode BatchProposed: {}", e);
                        self.print_raw_event_data(event);
                    }
                }
            }
            _ => {
                self.print_raw_event_data(event);
            }
        }
    }
    
    /// Prints raw event data when decoding fails
    /// 
    /// This helper function displays the raw topics and data for events that
    /// couldn't be decoded properly, which is useful for debugging.
    /// 
    /// # Arguments
    /// * `event` - The event whose raw data should be printed
    fn print_raw_event_data(&self, event: &Event) {
        println!("  Raw Topics:");
        for (i, topic) in event.topics.iter().enumerate() {
            println!("    [{}] {}", i, topic);
        }
        if event.data != "0x" && !event.data.is_empty() {
            // Truncate long data for readability
            if event.data.len() > 66 {
                println!("  Raw Data: {}...", &event.data[..66]);
            } else {
                println!("  Raw Data: {}", event.data);
            }
        }
    }

    /// Monitors blocks in batches for efficient historical data processing
    /// 
    /// This function processes blocks in configurable batches to efficiently
    /// scan historical data. It can process a specific range or catch up to
    /// the latest block and switch to live monitoring.
    /// 
    /// # Arguments
    /// * `start_block` - Starting block number
    /// * `end_block` - Optional ending block number (None means process until latest)
    /// * `batch_size` - Number of blocks to process in each RPC call
    /// * `poll_interval` - Seconds to wait between checks in live mode
    /// 
    /// # Returns
    /// * `Result<()>` - Success or error
    pub async fn monitor_blocks_batch(
        &mut self,
        start_block: u64,
        end_block: Option<u64>,
        batch_size: u64,
        poll_interval: u64,
    ) -> Result<()> {
        let mut current_block = start_block;
        let latest_block = self.client.eth_block_number().await?;
        
        info!("Starting batch event monitoring from block {}", current_block);
        if let Some(end) = end_block {
            info!("Processing until block {}", end);
        } else {
            info!("Processing until latest block {}, then monitoring live", latest_block);
        }
        info!("Batch size: {} blocks", batch_size);
        info!("Press Ctrl+C to stop\n");
        
        let mut total_events = 0;
        
        loop {
            let batch_start = current_block;
            let batch_end = (batch_start + batch_size - 1).min(end_block.unwrap_or(latest_block));
            
            match self.get_events_in_blocks(batch_start, batch_end).await {
                Ok(events) => {
                    if !events.is_empty() {
                        let event_count = events.len();
                        println!("\n{}", "=".repeat(80));
                        println!("Found {} event(s) in blocks {}-{}", event_count, batch_start, batch_end);
                        println!("{}", "=".repeat(80));
                        
                        for event in events {
                            self.print_event(&event);
                        }
                        
                        total_events += event_count;
                    } else {
                        let progress = ((batch_end - start_block) as f64 / 
                            ((end_block.unwrap_or(latest_block) - start_block) as f64)) * 100.0;
                        
                        if batch_end % 10_000 == 0 || progress >= 99.9 || (batch_end - batch_start) >= 100 {
                            info!("Processed blocks {}-{} ({:.1}% complete)", batch_start, batch_end, progress);
                        }
                    }
                }
                Err(e) => {
                    error!("Error processing blocks {}-{}: {}", batch_start, batch_end, e);
                    tokio::time::sleep(Duration::from_secs(2)).await;
                }
            }
            
            current_block = batch_end + 1;
            
            if let Some(end) = end_block {
                if current_block > end {
                    break;
                }
            } else if current_block > latest_block {
                info!("\n✓ Caught up to latest block! Total events found: {}", total_events);
                info!("Switching to live monitoring mode...\n");
                self.monitor_live(current_block, poll_interval).await?;
                break;
            }
        }
        
        info!("\nMonitoring complete. Total events found: {}", total_events);
        
        // Print cost summary
        self.cost_calculator.print_summary();
        
        Ok(())
    }

    /// Monitors new blocks in real-time as they are produced
    /// 
    /// This function continuously polls for new blocks and processes any events
    /// found. It includes error handling with retry logic and will exit after
    /// too many consecutive errors.
    /// 
    /// # Arguments
    /// * `current_block` - The block number to start monitoring from
    /// * `poll_interval` - Seconds to wait between checks for new blocks
    /// 
    /// # Returns
    /// * `Result<()>` - Success or error (exits on too many consecutive errors)
    pub async fn monitor_live(&mut self, mut current_block: u64, poll_interval: u64) -> Result<()> {
        let mut consecutive_errors = 0;
        const MAX_ERRORS: u32 = 5;
        
        loop {
            match self.client.eth_block_number().await {
                Ok(latest_block) => {
                    // Process any blocks we haven't seen yet
                    while current_block <= latest_block {
                        match self.get_events_in_blocks(current_block, current_block).await {
                            Ok(events) => {
                                if !events.is_empty() {
                                    let event_count = events.len();
                                    println!("\n{}", "=".repeat(80));
                                    println!("Found {} event(s) in block {}", event_count, current_block);
                                    println!("{}", "=".repeat(80));
                                    
                                    for event in events {
                                        self.print_event(&event);
                                    }
                                }
                                consecutive_errors = 0; // Reset error counter on success
                            }
                            Err(e) => {
                                error!("Error processing block {}: {}", current_block, e);
                            }
                        }
                        
                        current_block += 1;
                    }
                    
                    // Wait for new blocks
                    if current_block > latest_block {
                        info!("Caught up to block {}. Waiting for new blocks (checking every {}s)...", latest_block, poll_interval);
                        tokio::time::sleep(Duration::from_secs(poll_interval)).await;
                    }
                }
                Err(e) => {
                    consecutive_errors += 1;
                    error!("Error getting latest block: {} (error {}/{})", e, consecutive_errors, MAX_ERRORS);
                    
                    // Exit if too many consecutive errors
                    if consecutive_errors >= MAX_ERRORS {
                        return Err(anyhow::anyhow!("Too many consecutive errors"));
                    }
                    
                    // Wait before retrying
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    }
}