//! Constants and string helpers for topics, protocol IDs, and size caps.
//!
//! This module defines protocol-level constants that govern message sizes, domain separators,
//! and topic/protocol string builders for the preconfirmation P2P network.

/// Default maximum commitments returned per response.
///
/// This limits the number of `SignedCommitment` entries a peer can return in a single
/// `GetCommitmentsByNumberResponse`, preventing excessive memory usage.
pub const MAX_COMMITMENTS_PER_RESPONSE: usize = 256;

/// Maximum raw txlist size served in gossip/req-resp (align with chain BlockMaxTxListBytes).
///
/// This cap prevents excessively large transaction lists from consuming network resources.
/// The default is 2 MiB, which should be adjusted to match the chain's `BlockMaxTxListBytes`.
pub const MAX_TXLIST_BYTES: usize = 2 * 1024 * 1024; // 2 MiB default cap

/// Maximum gossip frame size (aligned with eth gossip defaults; adjust per chain).
///
/// This cap applies to the entire gossip frame, including headers and payload.
/// The default is 10 MiB, aligned with Ethereum gossip defaults.
pub const MAX_GOSSIP_SIZE_BYTES: usize = 10 * 1024 * 1024; // 10 MiB

/// Domain separator for signing preconfirmation commitments (placeholder; set per chain/runtime).
///
/// This 32-byte domain is prepended to SSZ-serialized commitments before hashing and signing,
/// ensuring signatures are scoped to the preconfirmation protocol and cannot be replayed
/// in other contexts.
pub const DOMAIN_PRECONF: [u8; 32] = *b"TAIKO_PRECONF_DOMAIN_PLACEHOLDER";

/// Build the gossipsub topic string for preconfirmation commitments.
pub fn topic_preconfirmation_commitments(chain_id: u64) -> String {
    format!("/taiko/{chain_id}/0/preconfirmationCommitments")
}

/// Build the gossipsub topic string for raw transaction lists.
pub fn topic_raw_txlists(chain_id: u64) -> String {
    format!("/taiko/{chain_id}/0/rawTxLists")
}

/// Build the protocol ID string for the `get_head` request/response protocol.
pub fn protocol_get_head(chain_id: u64) -> String {
    format!("/taiko/{chain_id}/preconf/1/get_head")
}

/// Build the protocol ID string for the `get_commitments_by_number` request/response protocol.
pub fn protocol_get_commitments_by_number(chain_id: u64) -> String {
    format!("/taiko/{chain_id}/preconf/1/get_commitments_by_number")
}

/// Build the protocol ID string for the `get_raw_txlist` request/response protocol.
pub fn protocol_get_raw_txlist(chain_id: u64) -> String {
    format!("/taiko/{chain_id}/preconf/1/get_raw_txlist")
}
