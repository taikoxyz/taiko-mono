//! Event signatures and identification for Taiko L1 events
//! 
//! This module contains the Keccak-256 hashes of Taiko event signatures
//! and provides utilities to identify events by their topic[0] value.

// Event signatures (Keccak-256 hashes) based on actual events found on-chain
// These are the topic[0] values emitted by the TaikoInbox contract

/// BatchProposed event signature
/// Event: BatchProposed(BatchInfo info, BatchMetadata meta, bytes txList)
pub const BATCH_PROPOSED_SIGNATURE: &str = "0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c";

/// BatchesProved event signature
/// Event: BatchesProved(address indexed verifier, uint64[] batchIds, Transition[] transitions)
pub const BATCHES_PROVED_SIGNATURE: &str = "0x9eb7fc80523943f28950bbb71ed6d584effe3e1e02ca4ddc8c86e5ee1558c096";

/// BatchesVerified event signature
/// Event: BatchesVerified(uint64 indexed batchId, bytes32 indexed blockHash)
pub const BATCHES_VERIFIED_SIGNATURE: &str = "0x7156d026e6a3864d290a971910746f96477d3901e33c4b2375e4ee00dabe7d87";

/// StatsUpdated event signature (specifically Stats2Updated)
/// Event: Stats2Updated(Stats2 stats2)
pub const STATS_UPDATED_SIGNATURE: &str = "0xc99f03c7db71a9e8c78654b1d2f77378b413cc979a02fa22dc9d39702afa92bc";

/// Identifies an event by its topic[0] signature
/// 
/// # Arguments
/// * `topic0` - The first topic (event signature hash)
/// 
/// # Returns
/// * `Option<&'static str>` - The event name if recognized, None otherwise
pub fn get_event_name(topic0: &str) -> Option<&'static str> {
    match topic0 {
        BATCH_PROPOSED_SIGNATURE => Some("BatchProposed"),
        BATCHES_PROVED_SIGNATURE => Some("BatchesProved"),
        BATCHES_VERIFIED_SIGNATURE => Some("BatchesVerified"),
        STATS_UPDATED_SIGNATURE => Some("StatsUpdated"),
        _ => None,
    }
}