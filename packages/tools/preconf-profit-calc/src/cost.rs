use anyhow::Result;
use ethereum_types::{Address, U256};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::decoder::{DecodedBatchProposed, DecodedBatchesProved, DecodedBatchesVerified};
use crate::types::Event;

/// Data structure to track all costs associated with a single batch
/// 
/// This struct captures the complete lifecycle of a batch from proposal
/// through verification, including all associated costs on L1. Note that
/// revenue (from L2 fees) cannot be tracked from L1 monitoring alone.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchCostData {
    /// Unique identifier for the batch
    pub batch_id: u64,
    /// Address that proposed the batch
    pub proposer: Address,
    /// Address that proved the batch (if proved)
    pub prover: Option<Address>,
    /// Address that verified the batch (if verified)
    pub verifier: Option<Address>,
    
    // Timestamps
    /// Unix timestamp when batch was proposed
    pub proposed_at: u64,
    /// Unix timestamp when batch was proved
    pub proved_at: Option<u64>,
    /// Unix timestamp when batch was verified
    pub verified_at: Option<u64>,
    
    // Blocks
    /// Block number where batch was proposed
    pub proposed_block: u64,
    /// Block number where batch was proved
    pub proved_block: Option<u64>,
    /// Block number where batch was verified
    pub verified_block: Option<u64>,
    
    // Transactions
    /// Transaction hash for the propose transaction
    pub propose_tx: String,
    /// Transaction hash for the prove transaction
    pub prove_tx: Option<String>,
    /// Transaction hash for the verify transaction
    pub verify_tx: Option<String>,
    
    // Gas costs (in wei)
    /// Gas used by the propose transaction
    pub propose_gas_used: Option<u64>,
    /// Gas used by the prove transaction
    pub prove_gas_used: Option<u64>,
    /// Gas price for the propose transaction
    pub propose_gas_price: Option<u64>,
    /// Gas price for the prove transaction
    pub prove_gas_price: Option<u64>,
    /// Total cost of proposing (gas_used * gas_price)
    pub propose_cost: Option<U256>,
    /// Total cost of proving (gas_used * gas_price)
    pub prove_cost: Option<U256>,
    /// Combined total cost (propose + prove)
    pub total_cost: Option<U256>,
    
    // Note: Revenue comes from L2 fees, which we cannot track from L1
}

/// Calculator for tracking L1 costs associated with Taiko batches
/// 
/// This struct maintains a collection of all batches and their associated
/// costs, providing methods to analyze spending by proposer and batch status.
pub struct CostCalculator {
    /// Map of batch ID to batch cost data
    batches: HashMap<u64, BatchCostData>,
}

impl CostCalculator {
    /// Creates a new empty CostCalculator
    pub fn new() -> Self {
        Self {
            batches: HashMap::new(),
        }
    }
    
    /// Processes a decoded event and updates batch cost tracking
    /// 
    /// This function updates the internal state based on the event type:
    /// - BatchProposed: Creates new batch entry or updates existing
    /// - BatchesProved: Updates batch with proof information
    /// - BatchesVerified: Updates batch with verification information
    /// 
    /// # Arguments
    /// * `event` - The raw event data
    /// * `decoded` - The decoded event data
    /// 
    /// # Returns
    /// * `Result<()>` - Success or error
    pub fn process_event(&mut self, event: &Event, decoded: &EventData) -> Result<()> {
        match decoded {
            EventData::BatchProposed(data) => {
                let batch_id = data.meta.batch_id;
                // Create new entry or get existing one
                let entry = self.batches.entry(batch_id).or_insert(BatchCostData {
                    batch_id,
                    proposer: data.meta.proposer,
                    prover: None,
                    verifier: None,
                    proposed_at: event.timestamp,
                    proved_at: None,
                    verified_at: None,
                    proposed_block: event.block_number,
                    proved_block: None,
                    verified_block: None,
                    propose_tx: event.transaction_hash.clone(),
                    prove_tx: None,
                    verify_tx: None,
                    propose_gas_used: None,
                    prove_gas_used: None,
                    propose_gas_price: None,
                    prove_gas_price: None,
                    propose_cost: None,
                    prove_cost: None,
                    total_cost: None,
                });
                
                // Update with latest data (in case of reorgs or duplicates)
                entry.proposer = data.meta.proposer;
                entry.proposed_at = event.timestamp;
                entry.proposed_block = event.block_number;
                entry.propose_tx = event.transaction_hash.clone();
            }
            EventData::BatchesProved(data) => {
                // Update all batches that were proved in this transaction
                for &batch_id in &data.batch_ids {
                    if let Some(entry) = self.batches.get_mut(&batch_id) {
                        entry.prover = Some(data.verifier);
                        entry.proved_at = Some(event.timestamp);
                        entry.proved_block = Some(event.block_number);
                        entry.prove_tx = Some(event.transaction_hash.clone());
                    }
                }
            }
            EventData::BatchesVerified(data) => {
                // Update the verified batch
                if let Some(entry) = self.batches.get_mut(&data.batch_id) {
                    entry.verified_at = Some(event.timestamp);
                    entry.verified_block = Some(event.block_number);
                    entry.verify_tx = Some(event.transaction_hash.clone());
                }
            }
            _ => {} // Ignore other event types
        }
        
        Ok(())
    }
    
    /// Gets a specific batch by ID
    /// 
    /// # Arguments
    /// * `batch_id` - The ID of the batch to retrieve
    /// 
    /// # Returns
    /// * `Option<&BatchCostData>` - The batch data if found
    pub fn get_batch(&self, batch_id: u64) -> Option<&BatchCostData> {
        self.batches.get(&batch_id)
    }
    
    /// Gets all batches sorted by batch ID
    /// 
    /// # Returns
    /// * `Vec<&BatchCostData>` - Vector of batch references sorted by ID
    pub fn get_all_batches(&self) -> Vec<&BatchCostData> {
        let mut batches: Vec<_> = self.batches.values().collect();
        batches.sort_by_key(|b| b.batch_id);
        batches
    }
    
    /// Calculates total costs for a specific proposer
    /// 
    /// This function aggregates all costs associated with batches proposed
    /// by a specific address, including both proposal and proving costs.
    /// 
    /// # Arguments
    /// * `proposer` - The proposer address to analyze
    /// 
    /// # Returns
    /// * `ProposerCosts` - Aggregated cost data for the proposer
    pub fn get_proposer_costs(&self, proposer: &Address) -> ProposerCosts {
        // Filter batches by proposer
        let batches: Vec<_> = self.batches.values()
            .filter(|b| &b.proposer == proposer)
            .collect();
        
        let total_batches = batches.len();
        let verified_batches = batches.iter()
            .filter(|b| b.verified_at.is_some())
            .count();
        
        // Sum proposal costs
        let total_cost = batches.iter()
            .filter_map(|b| b.propose_cost.as_ref())
            .fold(U256::zero(), |acc, cost| acc + cost);
        
        // Sum proving costs
        let prove_cost = batches.iter()
            .filter_map(|b| b.prove_cost.as_ref())
            .fold(U256::zero(), |acc, cost| acc + cost);
        
        ProposerCosts {
            proposer: *proposer,
            total_batches,
            verified_batches,
            propose_cost: total_cost,
            prove_cost,
            total_cost: total_cost + prove_cost,
        }
    }
    
    /// Prints a summary of all tracked costs
    /// 
    /// This function displays an overview of all batches and their costs,
    /// grouped by proposer address for easy analysis.
    pub fn print_summary(&self) {
        println!("\n=== L1 Cost Tracking Summary ===");
        println!("Total batches tracked: {}", self.batches.len());
        
        // Count verified batches
        let verified = self.batches.values()
            .filter(|b| b.verified_at.is_some())
            .count();
        println!("Verified batches: {}", verified);
        
        // Group batches by proposer for analysis
        let mut proposer_batches: HashMap<Address, Vec<&BatchCostData>> = HashMap::new();
        for batch in self.batches.values() {
            proposer_batches.entry(batch.proposer)
                .or_insert_with(Vec::new)
                .push(batch);
        }
        
        // Display batch counts by proposer
        println!("\nBy Proposer:");
        for (proposer, batches) in proposer_batches {
            println!("  {:?}: {} batches", proposer, batches.len());
        }
    }
}

/// Aggregated cost statistics for a specific proposer
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProposerCosts {
    /// The proposer's address
    pub proposer: Address,
    /// Total number of batches proposed
    pub total_batches: usize,
    /// Number of batches that have been verified
    pub verified_batches: usize,
    /// Total cost of proposing batches (in wei)
    pub propose_cost: U256,
    /// Total cost of proving batches (in wei)
    pub prove_cost: U256,
    /// Combined total cost (propose + prove, in wei)
    pub total_cost: U256,
}

/// Enum representing different types of decoded events
pub enum EventData {
    /// A batch was proposed
    BatchProposed(DecodedBatchProposed),
    /// One or more batches were proved
    BatchesProved(DecodedBatchesProved),
    /// A batch was verified
    BatchesVerified(DecodedBatchesVerified),
    /// Stats were updated (not currently used for cost tracking)
    StatsUpdated,
}