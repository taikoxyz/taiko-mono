//! Constants and string helpers for topics, protocol IDs, and size caps.

/// Default maximum commitments returned per response (spec suggests ≤256; tune via config later).
pub const MAX_COMMITMENTS_PER_RESPONSE: usize = 256;

/// Maximum raw txlist size served in gossip/req-resp (align with chain BlockMaxTxListBytes).
pub const MAX_TXLIST_BYTES: usize = 2 * 1024 * 1024; // 2 MiB default cap

/// Maximum gossip frame size (aligned with eth gossip defaults; adjust per chain).
pub const MAX_GOSSIP_SIZE_BYTES: usize = 10 * 1024 * 1024; // 10 MiB

/// Domain separator for signing preconfirmation commitments (placeholder; set per chain/runtime).
pub const DOMAIN_PRECONF: [u8; 32] = *b"TAIKO_PRECONF_DOMAIN_PLACEHOLDER";

/// Build preconfirmation commitments gossip topic for a given chain ID.
pub fn topic_preconfirmation_commitments(chain_id: u64) -> String {
    format!("/taiko/{}/0/preconfirmationCommitments", chain_id)
}

/// Build raw txlists gossip topic for a given chain ID.
pub fn topic_raw_txlists(chain_id: u64) -> String {
    format!("/taiko/{}/0/rawTxLists", chain_id)
}

/// Protocol ID for get_head req/resp.
pub fn protocol_get_head(chain_id: u64) -> String {
    format!("/taiko/{}/preconf/1/get_head", chain_id)
}

/// Protocol ID for get_commitments_by_number req/resp.
pub fn protocol_get_commitments_by_number(chain_id: u64) -> String {
    format!("/taiko/{}/preconf/1/get_commitments_by_number", chain_id)
}

/// Protocol ID for get_raw_txlist req/resp.
pub fn protocol_get_raw_txlist(chain_id: u64) -> String {
    format!("/taiko/{}/preconf/1/get_raw_txlist", chain_id)
}
