//! Test utilities for preconfirmation integration tests.
//!
//! This module provides utilities for testing the preconfirmation client:
//!
//! ## Driver Implementations
//! - [`LoggingDriverClient`]: Wraps a real driver client with submission logging.
//! - [`RealDriverSetup`]: Full driver setup for E2E tests with actual block production.
//!
//! ## Lookahead Resolvers
//! - [`StaticLookaheadResolver`]: A static lookahead resolver for deterministic tests.
//!
//! ## P2P Testing
//! - [`test_p2p_config`]: Creates a local-only P2P config for isolated tests.
//! - [`ExternalP2pNode`]: A spawned P2P node for publishing gossip.
//!
//! ## Event Waiting
//! - [`wait_for_peer_connected`]: Waits for a P2P peer connection.
//! - [`wait_for_commitment_and_txlist`]: Waits for gossip to arrive.
//! - [`wait_for_synced`]: Waits for sync completion.
//!
//! ## Payload Building
//! - [`PreparedBlock`]: A txlist + commitment pair for publishing.
//! - [`build_publish_payloads`]: Assembles preconfirmation payloads.
//! - [`derive_signer`]: Creates deterministic test signers.

mod driver;
mod events;
mod lookahead;
mod p2p;
mod payloads;

pub use driver::{
    EventSyncerDriverClient, LoggingDriverClient, RealDriverSetup, StartingBlockInfo,
};
pub use events::{
    wait_for_commitment_and_txlist, wait_for_commitments_and_txlists, wait_for_peer_connected,
    wait_for_synced,
};
pub use lookahead::StaticLookaheadResolver;
pub use p2p::{ExternalP2pNode, test_p2p_config};
pub use payloads::{
    PreparedBlock, build_commitment_chain, build_empty_txlist, build_publish_payloads,
    build_publish_payloads_with_txs, build_txlist_bytes, compress_raw_txs, compute_txlist_hash,
    derive_signer,
};
