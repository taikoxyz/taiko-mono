// Each integration test file `#[path]`-includes this module as a private `mod
// helpers`, so a given test binary only uses a subset of the re-exports below;
// the union across all includers covers every symbol. Allow unused imports so
// each binary compiles without warnings.
#![allow(unused_imports)]
//! Test-only helpers for preconfirmation-driver integration tests.
//!
//! This module re-exports shared helpers from test-harness used by the
//! integration tests that `#[path]`-include it.

// Re-export the shared P2P helpers from test-harness used by the integration tests.
pub use test_harness::preconfirmation::{
    ExternalP2pNode, PreparedBlock, build_commitment_chain, build_publish_payloads, derive_signer,
    test_p2p_config, wait_for_commitment_and_txlist, wait_for_commitments_and_txlists,
    wait_for_peer_connected, wait_for_synced,
};
