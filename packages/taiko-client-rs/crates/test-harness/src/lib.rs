//! Shared test utilities for Taiko workspace integration tests.
//!
//! This crate provides common utilities used across multiple test crates:
//!
//! ## Core Utilities
//! - [`ShastaEnv`]: Test environment with L1/L2 providers and contract addresses.
//! - [`BeaconStubServer`]: A stub beacon server for tests.
//! - [`PRIORITY_FEE_GWEI`]: Default priority fee constant.
//!
//! ## Block Utilities
//! - [`blocks::fetch_block_by_number`]: Fetches a block with full transactions.
//! - [`blocks::wait_for_block`]: Polls until a block appears.
//!
//! ## Transaction Utilities
//! - [`transactions::TransferPayload`]: A signed transfer for assertions.
//! - [`transactions::build_signed_transfer`]: Builds an EIP-1559 transfer.
//! - [`transactions::build_anchor_tx_bytes`]: Constructs anchor transactions.
//! - [`transactions::compute_next_block_base_fee`]: Calculates EIP-4396 base fee.
//!
//! ## Preconfirmation Utilities (feature-gated)
//! See [`preconfirmation`] module for P2P, event, and payload helpers.

use std::sync::OnceLock;

use tracing_subscriber::EnvFilter;

mod beacon_stub;
pub mod blocks;
mod helper;
pub mod shasta;
pub mod transactions;

#[cfg(feature = "preconfirmation")]
pub mod preconfirmation;

pub use beacon_stub::BeaconStubServer;
pub use blocks::{fetch_block_by_number, wait_for_block};
pub use helper::{PRIORITY_FEE_GWEI, evm_mine, mine_l1_block};
pub use shasta::{env::ShastaEnv, helpers::verify_anchor_block};
pub use transactions::{
    TransferPayload, build_anchor_tx_bytes, build_signed_transfer, compute_next_block_base_fee,
};

/// Initialise tracing for tests using a single global subscriber.
///
/// The `default_filter` is used when the `RUST_LOG` environment variable is not set.
pub fn init_tracing(default_filter: &str) {
    static INIT: OnceLock<()> = OnceLock::new();

    INIT.get_or_init(|| {
        let env_filter =
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(default_filter));
        let _ = tracing_subscriber::fmt().with_env_filter(env_filter).try_init();
    });
}
